import 'package:flutter/material.dart';

const Color _textDark = Color(0xFF1E2926);
const Color _textMuted = Color(0xFF7A8B86);
const Color _border = Color(0xFFE8ECEB);

/// Colored banner for the AI photo check: APPROVED / NEEDS_REVIEW / REJECTED.
class AiStatusBanner extends StatelessWidget {
  final String status;
  final String explanation;
  final bool compact;

  const AiStatusBanner({
    super.key,
    required this.status,
    required this.explanation,
    this.compact = false,
  });

  static String label(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Photo check passed';
      case 'REJECTED':
        return 'Photo rejected';
      default:
        return 'Needs human review';
    }
  }

  static Color color(String status) {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFF0D6855);
      case 'REJECTED':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFC05218);
    }
  }

  static IconData icon(String status) {
    switch (status) {
      case 'APPROVED':
        return Icons.verified_outlined;
      case 'REJECTED':
        return Icons.block;
      default:
        return Icons.manage_search;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = color(status);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon(status), color: c, size: compact ? 18 : 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI · ${label(status)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c, fontSize: compact ? 13 : 14),
                ),
                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    explanation,
                    style: TextStyle(fontSize: compact ? 12 : 13, color: _textDark, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The professional report generated for municipal workers.
/// Visual observations and citizen claims are shown in separate sections.
class AiReportCard extends StatelessWidget {
  final Map<String, dynamic> report;

  /// Optional `aiReview.imageAnalysis` map, to show photo quality etc.
  final Map<String, dynamic>? imageAnalysis;

  const AiReportCard({super.key, required this.report, this.imageAnalysis});

  static const _issueLabels = {
    'street_lighting': 'Street lighting',
    'road_damage': 'Road damage',
    'sidewalk_pedestrian': 'Sidewalk / pedestrian area',
    'waste_sanitation': 'Waste and sanitation',
    'water_leak_sewage': 'Water leak / sewage',
    'drainage_flooding': 'Drainage / flooding',
    'traffic_signage_signals': 'Traffic signs and signals',
    'parks_green_spaces': 'Parks and green spaces',
    'public_property_vandalism': 'Public property / vandalism',
    'electrical_hazard': 'Electrical hazard',
    'building_structure': 'Building / structure',
    'other': 'Other',
  };

  static Color urgencyColor(String? u) {
    switch (u) {
      case 'critical':
        return const Color(0xFFB71C1C);
      case 'high':
        return const Color(0xFFC05218);
      case 'medium':
        return const Color(0xFF1E63B8);
      default:
        return const Color(0xFF0D6855);
    }
  }

  List<String> _list(String key) =>
      ((report[key] as List?) ?? const []).whereType<String>().where((s) => s.trim().isNotEmpty).toList();

  String _s(String key) => (report[key] as String?)?.trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final urgency = _s('urgency');
    final issue = _issueLabels[_s('issue_type')] ?? _s('issue_type');
    final visual = _list('visual_observations');
    final citizen = _list('citizen_reported_information');
    final limitations = _list('limitations');
    final quality = imageAnalysis?['image_quality'] as String?;
    final support = imageAnalysis?['supports_reported_issue'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF086B5B)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'AI-GENERATED REPORT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xFF7E8F8B),
                  ),
                ),
              ),
              if (urgency.isNotEmpty) _chip('Urgency: $urgency', urgencyColor(urgency)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _s('title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (issue.isNotEmpty) _chip(issue, const Color(0xFF086B5B)),
              if (_s('responsible_department').isNotEmpty)
                _chip(_s('responsible_department'), const Color(0xFF1E63B8)),
              if (quality != null && quality != 'clear')
                _chip('Photo: ${quality.replaceAll('_', ' ')}', const Color(0xFFC05218)),
              if (support == 'contradicts')
                _chip('Photo contradicts description', const Color(0xFFC62828)),
            ],
          ),
          _section('Problem description', [_s('problem_description')]),
          _section('Visible in the photos (AI observation)', visual,
              empty: 'Nothing relevant could be identified in the photos.'),
          _section('Reported by the citizen (not verified)', citizen),
          _section('Location provided by the citizen', [_s('location_provided')]),
          _section('Why this urgency', [_s('urgency_rationale')]),
          _section('Recommended action', [_s('recommended_action')]),
          if (limitations.isNotEmpty) _section('Could not be determined', limitations),
          const SizedBox(height: 12),
          const Text(
            'AI analysis helps triage reports. It is not proof that the incident occurred '
            'and must be confirmed on site.',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _textMuted),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _section(String heading, List<String> lines, {String? empty}) {
    final items = lines.where((l) => l.trim().isNotEmpty).toList();
    if (items.isEmpty && empty == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            Text(empty!, style: const TextStyle(fontSize: 13, color: _textMuted))
          else if (items.length == 1)
            Text(items.first, style: const TextStyle(fontSize: 13, color: _textDark, height: 1.4))
          else
            for (final line in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(color: _textMuted)),
                    Expanded(
                      child: Text(line,
                          style: const TextStyle(fontSize: 13, color: _textDark, height: 1.4)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
