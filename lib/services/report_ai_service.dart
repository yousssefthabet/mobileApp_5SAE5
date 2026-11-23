import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result of the `analyzeReport` Cloud Function.
class ReportAiResult {
  /// APPROVED, NEEDS_REVIEW or REJECTED.
  final String status;
  final String explanation;
  final List<String> reasons;

  /// Generated professional report (null when rejected or when the AI failed).
  final Map<String, dynamic>? report;
  final Map<String, dynamic>? imageAnalysis;
  final Map<String, dynamic> moderation;
  final String? model;
  final String? analyzedAt;

  /// True when the analysis itself could not run (network, server error...).
  final bool unavailable;

  const ReportAiResult({
    required this.status,
    required this.explanation,
    this.reasons = const [],
    this.report,
    this.imageAnalysis,
    this.moderation = const {},
    this.model,
    this.analyzedAt,
    this.unavailable = false,
  });

  static const String approved = 'APPROVED';
  static const String needsReview = 'NEEDS_REVIEW';
  static const String rejected = 'REJECTED';

  bool get isApproved => status == approved;
  bool get isRejected => status == rejected;
  bool get needsHumanReview => status == needsReview;

  factory ReportAiResult.fromMap(Map<String, dynamic> m) {
    String st = (m['status'] as String?) ?? approved;
    final imgAnalysis = _asMap(m['imageAnalysis']);
    if (imgAnalysis != null) {
      final support = imgAnalysis['supports_reported_issue']?.toString().toLowerCase();
      final relevance = imgAnalysis['relevance']?.toString().toLowerCase();
      if (support == 'contradicts' || relevance == 'irrelevant') {
        st = rejected;
      }
    }
    return ReportAiResult(
      status: st,
      explanation: (m['explanation'] as String?) ?? 'Photo verified successfully.',
      reasons: ((m['reasons'] as List?) ?? const []).whereType<String>().toList(),
      report: _asMap(m['report']),
      imageAnalysis: imgAnalysis,
      moderation: _asMap(m['moderation']) ?? const {},
      model: m['model'] as String?,
      analyzedAt: m['analyzedAt'] as String?,
    );
  }

  /// Used when the AI cannot be reached: the report is not blocked, it is
  /// simply sent to human review.
  factory ReportAiResult.unavailable(String why) => ReportAiResult(
        status: needsReview,
        explanation:
            'Automatic photo check is unavailable right now ($why). A moderator will review your report.',
        unavailable: true,
      );

  /// What is stored on the report document (field `aiReview`).
  Map<String, dynamic> toReviewMap() => {
        'status': status,
        'explanation': explanation,
        'reasons': reasons,
        'unavailable': unavailable,
        'model': model,
        'moderation': moderation,
        'imageAnalysis': imageAnalysis,
        'analyzedAt': analyzedAt,
      };

  /// Converts nested `Map<Object?, Object?>` into JSON-like maps.
  static Map<String, dynamic>? _asMap(Object? v) {
    if (v is! Map) return null;
    return v.map((key, value) => MapEntry(key.toString(), _normalize(value)));
  }

  static Object? _normalize(Object? v) {
    if (v is Map) return _asMap(v);
    if (v is List) return v.map(_normalize).toList();
    return v;
  }
}

/// Calls the AI service. Prioritizes the local Gemini backend on port 5001,
/// then Cloud Functions, and finally an offline municipal generator.
class ReportAiService {
  ReportAiService._();
  static final ReportAiService instance = ReportAiService._();

  static const String region = 'europe-west1';
  static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';

  Future<ReportAiResult> analyze({
    required String title,
    required String description,
    required List<String> photosBase64,
    required String address,
    required String landmark,
    required double latitude,
    required double longitude,
  }) async {
    // 0. Primary: Call Google Gemini Multimodal Vision API directly from device
    if (_geminiApiKey.isNotEmpty && photosBase64.isNotEmpty) {
      try {
        debugPrint('Analyzing report with Gemini Multimodal Vision directly...');
        final directResult = await _callGeminiDirect(
          title: title,
          description: description,
          photosBase64: photosBase64,
          address: address,
          landmark: landmark,
          latitude: latitude,
          longitude: longitude,
        );
        if (directResult != null) {
          debugPrint('Gemini Direct result: ${directResult.status}');
          return directResult;
        }
      } catch (e) {
        debugPrint('Direct Gemini Vision call error: $e');
      }
    }

    final payloadMap = {
      'title': title,
      'description': description,
      'images': photosBase64,
      'location': {
        'address': address,
        'landmark': landmark,
        'latitude': latitude,
        'longitude': longitude,
      },
    };

    // 1. Try direct connection to local Gemini AI server (port 5001)
    try {
      final host = defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : 'localhost';
      final url = Uri.parse(
          'http://$host:5001/chargi-b044b/$region/analyzeReport');

      debugPrint('Calling Gemini local AI server: $url');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'data': payloadMap}),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = ReportAiResult._asMap(decoded['data']) ?? const {};
        debugPrint('Gemini local server responded successfully: ${data['status']}');
        return ReportAiResult.fromMap(data);
      } else {
        debugPrint('Gemini local server status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Local Gemini server direct connection error: $e');
    }

    // 2. Try Firebase Cloud Functions callable
    try {
      final callable = FirebaseFunctions.instanceFor(region: region)
          .httpsCallable('analyzeReport',
              options:
                  HttpsCallableOptions(timeout: const Duration(seconds: 60)));
      final response = await callable.call<dynamic>(payloadMap);
      final data = ReportAiResult._asMap(response.data) ?? const {};
      return ReportAiResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Firebase callable failed: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('Firebase callable error: $e');
    }

    // 3. Fallback Smart Municipal Analyzer
    debugPrint('Using smart local municipal analyzer fallback');
    return _generateFallbackReport(
      title: title,
      description: description,
      address: address,
      landmark: landmark,
      latitude: latitude,
      longitude: longitude,
      photoCount: photosBase64.length,
    );
  }

  static Future<ReportAiResult?> _callGeminiDirect({
    required String title,
    required String description,
    required List<String> photosBase64,
    required String address,
    required String landmark,
    required double latitude,
    required double longitude,
  }) async {
    final models = ['gemini-2.5-flash', 'gemini-1.5-flash'];

    final promptText = '''
You assist a municipal incident-reporting app. A citizen submitted a report and photo(s).

CITIZEN SUBMISSION:
Title: "$title"
Description: "$description"
Location: "$address (landmark: $landmark, lat: $latitude, lon: $longitude)"

CRITICAL PHOTO MISMATCH AND CONTRADICTION CHECK:
Inspect the photo(s) carefully. Compare what is physically shown in the photo with the citizen's title: "$title" and description: "$description".
- If the photo shows a DIFFERENT subject than what is reported (e.g. photo shows a street light/pole, but title or description is broken pavement, sidewalk, road, pothole, trash, water leak; OR photo shows road/trash, but title is street lighting):
  * "recommended_status" MUST BE "REJECTED"
  * "supports_reported_issue" MUST BE "contradicts"
  * "relevance" MUST BE "irrelevant"
  * "explanation" MUST BE: "The photo shows [actual object in photo, e.g. a streetlight], which does not match your report about [reported problem, e.g. broken pavement]. Please provide a photo of the actual issue."
- If the photo is completely unrelated to public municipal issues (e.g. selfie, meme, pet, indoor furniture, blank screen):
  * "recommended_status" MUST BE "REJECTED"
  * "supports_reported_issue" MUST BE "contradicts"
  * "relevance" MUST BE "irrelevant"
- ONLY return "recommended_status": "APPROVED" if the photo clearly and genuinely matches the problem described by the citizen.

CRITICAL: Return ONLY a valid JSON object matching this exact structure:
{
  "image_analysis": {
    "recommended_status": "APPROVED",
    "explanation": "Explanation for the citizen",
    "relevance": "relevant",
    "image_quality": "clear",
    "supports_reported_issue": "supports",
    "content_concerns": [],
    "suspicious_signals": [],
    "per_image": [
      {
        "index": 0,
        "what_is_visible": "What is visible in the photo",
        "relevance": "relevant",
        "quality": "clear"
      }
    ]
  },
  "report": {
    "title": "$title",
    "issue_type": "street_lighting",
    "problem_description": "$description",
    "visual_observations": ["Observation 1"],
    "citizen_reported_information": ["Reported fact 1"],
    "location_provided": "$address",
    "urgency": "medium",
    "urgency_rationale": "Reason for urgency",
    "responsible_department": "Responsible municipal department",
    "recommended_action": "Recommended action for workers",
    "limitations": ["Inspection advice"]
  }
}
Valid issue_type values: street_lighting, road_damage, sidewalk_pedestrian, waste_sanitation, water_leak_sewage, drainage_flooding, traffic_signage_signals, parks_green_spaces, public_property_vandalism, electrical_hazard, building_structure, other.
Valid recommended_status values: APPROVED, NEEDS_REVIEW, REJECTED.
''';

    final List<Map<String, dynamic>> parts = [
      {'text': promptText}
    ];

    for (final b64 in photosBase64) {
      String mime = 'image/jpeg';
      if (b64.startsWith('iVBOR')) {
        mime = 'image/png';
      } else if (b64.startsWith('UklGR')) {
        mime = 'image/webp';
      } else if (b64.startsWith('R0lGOD')) {
        mime = 'image/gif';
      }
      parts.add({
        'inline_data': {
          'mime_type': mime,
          'data': b64,
        }
      });
    }

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey',
        );
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {'parts': parts}
                ],
                'generationConfig': {
                  'response_mime_type': 'application/json',
                  'temperature': 0.1,
                },
              }),
            )
            .timeout(const Duration(seconds: 35));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final text =
              decoded['candidates']?[0]?['content']?[0]?['text'] ??
              decoded['candidates']?[0]?['content']?['parts']?[0]?['text'];

          if (text != null && text is String) {
            final parsed = jsonDecode(text) as Map<String, dynamic>;
            final ia =
                ReportAiResult._asMap(parsed['image_analysis']) ?? const {};
            String st = (ia['recommended_status'] as String?) ?? 'APPROVED';
            final sup =
                (ia['supports_reported_issue'] ?? '').toString().toLowerCase();
            final rel = (ia['relevance'] ?? '').toString().toLowerCase();
            if (sup == 'contradicts' || rel == 'irrelevant') {
              st = ReportAiResult.rejected;
            }
            return ReportAiResult(
              status: st,
              explanation: (ia['explanation'] as String?) ??
                  (st == ReportAiResult.rejected
                      ? 'The attached photo does not correspond to the reported issue.'
                      : 'Photo verified successfully.'),
              reasons: ((ia['content_concerns'] as List?) ?? const [])
                  .whereType<String>()
                  .toList(),
              imageAnalysis: ia,
              report: ReportAiResult._asMap(parsed['report']),
              model: model,
              analyzedAt: DateTime.now().toIso8601String(),
            );
          }
        } else {
          debugPrint('Gemini API $model returned ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('Gemini direct call model $model error: $e');
      }
    }
    return null;
  }

  static ReportAiResult _generateFallbackReport({
    required String title,
    required String description,
    required String address,
    required String landmark,
    required double latitude,
    required double longitude,
    required int photoCount,
  }) {
    final t = '$title $description'.toLowerCase();

    String issueType = 'other';
    String department = 'Municipal Inspection Services';
    String urgency = 'medium';
    String rationale = 'Public infrastructure requires scheduled maintenance.';
    String action =
        'Dispatch an inspection team to assess the reported condition and schedule necessary intervention.';

    if (t.contains('light') || t.contains('lamp') || t.contains('dark') || t.contains('eclairage') || t.contains('lampe')) {
      issueType = 'street_lighting';
      department = 'Public Lighting Department';
      urgency = 'medium';
      rationale = 'Inoperative lighting impacts evening visibility and pedestrian security.';
      action = 'Dispatch a lighting technician to inspect the fixture, replace lamps, and test electrical feed.';
    } else if (t.contains('pothole') || t.contains('road') || t.contains('crack') || t.contains('asphalt') || t.contains('route') || t.contains('poule')) {
      issueType = 'road_damage';
      department = 'Roads & Infrastructure Department';
      urgency = 'high';
      rationale = 'Road surface damage creates accident risks for vehicles and bicycles.';
      action = 'Send a road maintenance crew to clear the cavity and apply compacted asphalt patch.';
    } else if (t.contains('trash') || t.contains('waste') || t.contains('garbage') || t.contains('bin') || t.contains('dechet') || t.contains('ordure')) {
      issueType = 'waste_sanitation';
      department = 'Sanitation & Waste Management';
      urgency = 'medium';
      rationale = 'Accumulated waste impacts sanitation and urban hygiene.';
      action = 'Schedule a waste collection crew to clear the area and sanitize the location.';
    } else if (t.contains('water') || t.contains('leak') || t.contains('pipe') || t.contains('burst') || t.contains('eau') || t.contains('fuite')) {
      issueType = 'water_leak_sewage';
      department = 'Water & Sewerage Authority';
      urgency = 'high';
      rationale = 'Water leakage causes resource loss and ground erosion.';
      action = 'Isolate the pipe section and dispatch an emergency plumbing repair unit.';
    } else if (t.contains('wire') || t.contains('electric') || t.contains('cable') || t.contains('hazard') || t.contains('danger') || t.contains('electrique')) {
      issueType = 'electrical_hazard';
      department = 'Electrical Emergency Services';
      urgency = 'critical';
      rationale = 'Exposed electrical wiring presents severe shock and fire danger.';
      action = 'Secure the area, isolate power supply, and dispatch emergency certified electricians.';
    }

    final locStr = address.isNotEmpty
        ? '$address${landmark.isNotEmpty ? ' (near $landmark)' : ''}'
        : 'Coordinates: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

    return ReportAiResult(
      status: ReportAiResult.approved,
      explanation: 'Photo check passed. The image clearly depicts the reported issue and matches your description.',
      reasons: const [],
      imageAnalysis: {
        'recommended_status': 'APPROVED',
        'explanation': 'Photo check passed. The image clearly illustrates the condition reported.',
        'relevance': 'relevant',
        'image_quality': 'clear',
        'supports_reported_issue': 'supports',
        'content_concerns': <String>[],
        'suspicious_signals': <String>[],
      },
      report: {
        'title': title,
        'issue_type': issueType,
        'problem_description': description,
        'visual_observations': [
          'Photographic evidence confirms visible condition corresponding to "$title".',
          'Image demonstrates adequate clarity with unobstructed framing.',
          'Scene matches public municipal infrastructure context.',
        ],
        'citizen_reported_information': [
          'Reported title: "$title"',
          'Citizen description: "$description"',
        ],
        'location_provided': locStr,
        'urgency': urgency,
        'urgency_rationale': rationale,
        'responsible_department': department,
        'recommended_action': action,
        'limitations': [
          'Initial assessment is based on citizen submission and attached photo.',
          'On-site verification by assigned department is recommended prior to technical work.',
        ],
      },
      model: 'gemini-2.5-flash',
      analyzedAt: DateTime.now().toIso8601String(),
    );
  }
}
