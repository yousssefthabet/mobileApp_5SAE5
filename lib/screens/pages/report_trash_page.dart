import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';
import 'package:chargi/services/report_service.dart';
import 'package:chargi/services/report_ai_service.dart';
import 'package:chargi/widgets/ai_report_view.dart';
import 'package:chargi/data/local/report_draft.dart';
import 'package:chargi/data/local/report_draft_db.dart';
import 'report_drafts_page.dart';
import 'report_sent_page.dart';
import 'map_location_picker_page.dart';

/// Free-form incident report: the user writes a title and a description,
/// attaches one or more photos, picks a location and submits.
///
/// Pass [editReportId] and [initialData] to open the same form in edit mode
/// for one of the user's existing reports. The page then pops with `true`
/// after a successful save.
class ReportTrashPage extends StatefulWidget {
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToMyReports;
  final VoidCallback? onNavigateToProfile;
  final void Function(MapLocationResult location, {bool navigateToHome})? onLocationSelected;
  final bool showBottomNavBar;
  final String? editReportId;
  final Map<String, dynamic>? initialData;

  const ReportTrashPage({
    super.key,
    this.onNavigateToMap,
    this.onNavigateToMyReports,
    this.onNavigateToProfile,
    this.onLocationSelected,
    this.showBottomNavBar = true,
    this.editReportId,
    this.initialData,
  });

  bool get isEditing => editReportId != null;

  @override
  State<ReportTrashPage> createState() => _ReportTrashPageState();
}

class _ReportTrashPageState extends State<ReportTrashPage> {
  // Form state
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  static const int _titleMaxLength = 80;
  static const int _descriptionMaxLength = 1000;

  // Photo state
  static const int _maxPhotos = 4;
  // Firestore documents are limited to 1 MiB; keep the photos well under it.
  static const int _maxTotalPhotoBytes = 700 * 1024;
  final List<Uint8List> _photos = [];
  bool _isPickingPhoto = false;
  bool _isSubmitting = false;
  bool _isAnalyzing = false; // waiting for the AI photo check

  // Local draft (SQLite) currently loaded in the form, if any.
  int? _draftId;
  int _draftCount = 0;

  // Location state
  MapLocationResult _selectedLocation = const MapLocationResult(
    address: 'Rue de la Liberté, near Central Square',
    landmark: 'Central Square Hub',
    latitude: 36.8065,
    longitude: 10.1815,
    mapOffsetRatio: Offset(0.48, 0.44),
  );
  bool _isLocationChangedFromMap = false;

  // Set after the first submit attempt so missing fields are highlighted.
  bool _showMissingErrors = false;

  bool get _photosMissing => _photos.isEmpty;
  bool get _locationMissing => !_isLocationChangedFromMap;

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color lightMintBackground = Color(0xFFE2EFEA);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _refreshDraftCount();
    final data = widget.initialData;
    if (widget.isEditing && data != null) {
      _titleController.text = (data['problemTitle'] as String?) ?? '';
      _descriptionController.text = (data['description'] as String?) ?? '';

      final stored = <String>[
        ...((data['photosBase64'] as List?) ?? const []).whereType<String>(),
      ];
      final legacy = data['photoBase64'] as String?;
      if (stored.isEmpty && legacy != null) stored.add(legacy);
      for (final b64 in stored.take(_maxPhotos)) {
        try {
          _photos.add(base64Decode(b64));
        } catch (_) {}
      }

      final lat = data['latitude'];
      final lng = data['longitude'];
      if (lat is num && lng is num) {
        _selectedLocation = MapLocationResult(
          address: (data['location'] as String?) ?? 'Selected location',
          landmark: (data['landmark'] as String?) ?? 'Selected location',
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
          mapOffsetRatio: Offset(
            (data['mapOffsetX'] as num?)?.toDouble() ?? 0.5,
            (data['mapOffsetY'] as num?)?.toDouble() ?? 0.5,
          ),
        );
        _isLocationChangedFromMap = true;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {Color? color, int seconds = 2}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  int get _totalPhotoBytes => _photos.fold(0, (sum, p) => sum + p.length);

  // ---------------------------------------------------------------------------
  // Photo Handling Methods
  // ---------------------------------------------------------------------------

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photos.length >= _maxPhotos) {
      _showSnack('You can attach up to $_maxPhotos photos.', color: Colors.orange);
      return;
    }

    setState(() => _isPickingPhoto = true);

    try {
      final List<XFile> picked;
      if (source == ImageSource.gallery) {
        picked = await _picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 60,
          limit: _maxPhotos - _photos.length,
        );
      } else {
        final photo = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 60,
        );
        picked = photo == null ? [] : [photo];
      }

      int added = 0;
      bool tooLarge = false;
      for (final file in picked) {
        if (_photos.length >= _maxPhotos) break;
        final bytes = await file.readAsBytes();
        if (_totalPhotoBytes + bytes.length > _maxTotalPhotoBytes) {
          tooLarge = true;
          break;
        }
        _photos.add(bytes);
        added++;
      }
      if (mounted) setState(() {});

      if (tooLarge) {
        _showSnack(
          'Photos are too large to attach more. Remove one or pick a smaller photo.',
          color: Colors.orange,
          seconds: 3,
        );
      } else if (added > 0) {
        _showSnack(
          added == 1 ? 'Photo added' : '$added photos added',
          color: primaryGreen,
        );
      }
    } catch (e) {
      _showSnack('Could not access camera or gallery: $e',
          color: Colors.redAccent, seconds: 3);
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DFDC),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Add photos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Clear photos help the team find and fix the problem faster.',
                  style: TextStyle(fontSize: 13, color: textMuted),
                ),
                const SizedBox(height: 20),
                _photoOptionTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take a photo',
                  subtitle: 'Use your device camera',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
                const Divider(height: 12),
                _photoOptionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from gallery',
                  subtitle: 'You can select several photos',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _photoOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: lightMintBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: primaryGreen),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, color: textDark),
      ),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _previewFullPhoto(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_photos[index], fit: BoxFit.contain),
            ),
            IconButton(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Location Map Handling Methods
  // ---------------------------------------------------------------------------

  Future<void> _openMapLocationPicker() async {
    final result = await Navigator.push<MapLocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPickerPage(
          initialLocation: _selectedLocation,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result;
        _isLocationChangedFromMap = true;
      });

      widget.onLocationSelected?.call(result, navigateToHome: result.viewOnHomeMap);

      if (mounted) {
        if (result.viewOnHomeMap && widget.onNavigateToMap != null) {
          widget.onNavigateToMap!();
        } else {
          _showSnack('Location selected: ${result.landmark}', color: primaryGreen);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Drafts (local SQLite database, see lib/data/local/report_draft_db.dart)
  // ---------------------------------------------------------------------------

  String get _draftUserId => FirebaseAuth.instance.currentUser?.uid ?? 'local';

  Future<void> _refreshDraftCount() async {
    if (widget.isEditing) return;
    try {
      final n = await ReportDraftDb.instance.countDrafts(_draftUserId);
      if (mounted) setState(() => _draftCount = n);
    } catch (e) {
      debugPrint('Could not count drafts: $e');
    }
  }

  ReportDraft _currentAsDraft() {
    final now = DateTime.now();
    return ReportDraft(
      id: _draftId,
      userId: _draftUserId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _isLocationChangedFromMap ? _selectedLocation.address : '',
      landmark: _isLocationChangedFromMap ? _selectedLocation.landmark : '',
      latitude: _isLocationChangedFromMap ? _selectedLocation.latitude : null,
      longitude: _isLocationChangedFromMap ? _selectedLocation.longitude : null,
      mapOffsetX: _selectedLocation.mapOffsetRatio.dx,
      mapOffsetY: _selectedLocation.mapOffsetRatio.dy,
      locationChosen: _isLocationChangedFromMap,
      createdAt: now,
      updatedAt: now,
      photos: List.of(_photos),
    );
  }

  /// Saves the form as a draft (insert the first time, update afterwards).
  /// Unlike submitting, a draft may be incomplete.
  Future<bool> _saveDraft({bool showMessage = true}) async {
    final draft = _currentAsDraft();
    if (draft.isEmpty) {
      if (showMessage) _showSnack('Nothing to save yet.', color: Colors.orange);
      return false;
    }
    try {
      if (_draftId == null) {
        final id = await ReportDraftDb.instance.insertDraft(draft);
        _draftId = id;
      } else {
        await ReportDraftDb.instance.updateDraft(draft);
      }
      await _refreshDraftCount();
      if (showMessage) _showSnack('Draft saved on this phone', color: primaryGreen);
      return true;
    } catch (e) {
      debugPrint('Could not save draft: $e');
      if (showMessage) _showSnack('Could not save draft: $e', color: Colors.redAccent);
      return false;
    }
  }

  /// When sending fails (e.g. no internet), keep the citizen's work locally.
  Future<void> _saveDraftAfterFailure(String error) async {
    final saved = !widget.isEditing && await _saveDraft(showMessage: false);
    _showSnack(
      saved ? '$error\nYour report was saved as a draft.' : error,
      color: Colors.redAccent,
      seconds: 4,
    );
  }

  Future<void> _openDrafts() async {
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const ReportDraftsPage()),
    );
    await _refreshDraftCount();
    if (id == null || !mounted) return;

    final draft = await ReportDraftDb.instance.getDraft(id);
    if (draft == null || !mounted) return;

    setState(() {
      _draftId = draft.id;
      _titleController.text = draft.title;
      _descriptionController.text = draft.description;
      _photos
        ..clear()
        ..addAll(draft.photos.take(_maxPhotos));
      _isLocationChangedFromMap =
          draft.locationChosen && draft.latitude != null && draft.longitude != null;
      if (_isLocationChangedFromMap) {
        _selectedLocation = MapLocationResult(
          address: draft.address,
          landmark: draft.landmark,
          latitude: draft.latitude!,
          longitude: draft.longitude!,
          mapOffsetRatio: Offset(draft.mapOffsetX, draft.mapOffsetY),
        );
      }
      _showMissingErrors = false;
    });
    _showSnack('Draft loaded: ${draft.displayTitle}', color: primaryGreen);
  }

  void _resetForm() {
    _draftId = null;
    _formKey.currentState?.reset();
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _photos.clear();
      _isLocationChangedFromMap = false;
      _showMissingErrors = false;
    });
  }

  Future<void> _submitReport() async {
    FocusScope.of(context).unfocus();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please log in before submitting a report.',
          color: Colors.redAccent);
      return;
    }

    if (_isSubmitting) return;

    // Every field is required: title, description, at least one photo and
    // a location chosen on the map.
    setState(() => _showMissingErrors = true);
    final textFieldsOk = _formKey.currentState?.validate() ?? false;
    final missing = <String>[
      if (_titleController.text.trim().length < 3) 'title',
      if (_descriptionController.text.trim().length < 10) 'description',
      if (_photosMissing) 'photo',
      if (_locationMissing) 'location',
    ];
    if (!textFieldsOk || missing.isNotEmpty) {
      _showSnack(
        missing.isEmpty
            ? 'Please complete every field before sending the report.'
            : 'Please complete every field before sending: ${missing.join(', ')}.',
        color: Colors.redAccent,
        seconds: 3,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final problemTitle = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final photosBase64 = _photos.map(base64Encode).toList();

      // AI check (Cloud Function): moderation + relevance + professional report.
      setState(() => _isAnalyzing = true);
      final ai = await ReportAiService.instance.analyze(
        title: problemTitle,
        description: description,
        photosBase64: photosBase64,
        address: _selectedLocation.address,
        landmark: _selectedLocation.landmark,
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
      );
      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      final confirmed = await _showAiResult(ai);
      if (confirmed != true || !mounted) return;

      final aiFields = <String, dynamic>{
        'aiStatus': ai.status,
        'aiReview': {...ai.toReviewMap(), 'checkedAt': FieldValue.serverTimestamp()},
        'aiReport': ai.report,
      };

      if (widget.isEditing) {
        await ReportService.instance.updateOwnReport(
          reportId: widget.editReportId!,
          fields: {
            ...aiFields,
            'problemTitle': problemTitle,
            'description': description,
            'location': _selectedLocation.address,
            'landmark': _selectedLocation.landmark,
            'latitude': _selectedLocation.latitude,
            'longitude': _selectedLocation.longitude,
            'mapOffsetX': _selectedLocation.mapOffsetRatio.dx,
            'mapOffsetY': _selectedLocation.mapOffsetRatio.dy,
            'hasPhoto': photosBase64.isNotEmpty,
            'photoCount': photosBase64.length,
            'photosBase64': photosBase64,
            'photoBase64': photosBase64.isNotEmpty ? photosBase64.first : FieldValue.delete(),
          },
        );
        if (!mounted) return;
        _showSnack('Report updated', color: primaryGreen);
        Navigator.pop(context, true);
        return;
      }

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reports')
          .doc();

      final displayRef = '#${docRef.id.substring(0, 6).toUpperCase()}';

      await docRef.set({
        'id': docRef.id,
        'reference': displayRef,
        'userId': user.uid,
        'reporterName': user.displayName ?? '',
        'reporterEmail': user.email ?? '',
        'problemTitle': problemTitle,
        'description': description,
        'location': _selectedLocation.address,
        'landmark': _selectedLocation.landmark,
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'mapOffsetX': _selectedLocation.mapOffsetRatio.dx,
        'mapOffsetY': _selectedLocation.mapOffsetRatio.dy,
        'status': 'sent',
        'workerName': 'Unassigned',
        'estimatedArrival': 'Reviewing report',
        'hasPhoto': photosBase64.isNotEmpty,
        'photoCount': photosBase64.length,
        if (photosBase64.isNotEmpty) 'photosBase64': photosBase64,
        // First photo kept under the old key so existing screens still show it.
        if (photosBase64.isNotEmpty) 'photoBase64': photosBase64.first,
        ...aiFields,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      final sentLocation = _selectedLocation.address;
      final sentDraftId = _draftId;
      _resetForm();
      // The draft has been sent: remove it from the local database.
      if (sentDraftId != null) {
        ReportDraftDb.instance.deleteDraft(sentDraftId).then((_) => _refreshDraftCount());
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportSentPage(
            reportId: displayRef,
            reportDocId: docRef.id,
            location: sentLocation,
            problemTitle: problemTitle,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint('Firestore submit error: ${e.code} - ${e.message}');
      await _saveDraftAfterFailure('Failed to submit report: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('Unexpected submit error: $e');
      await _saveDraftAfterFailure('Could not submit report: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isAnalyzing = false;
        });
      }
    }
  }

  /// Shows the AI verdict and the generated report.
  /// Returns true when the citizen confirms sending.
  Future<bool?> _showAiResult(ReportAiResult ai) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: ai.report == null ? 0.45 : 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6DFDC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ai.isRejected ? 'Your photos could not be accepted' : 'Check your report',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textDark),
            ),
            const SizedBox(height: 12),
            AiStatusBanner(status: ai.status, explanation: ai.explanation),
            if (ai.report != null) ...[
              const SizedBox(height: 14),
              const Text(
                'This is how your report will be presented to municipal workers:',
                style: TextStyle(fontSize: 13, color: textMuted),
              ),
              const SizedBox(height: 8),
              AiReportCard(report: ai.report!, imageAnalysis: ai.imageAnalysis),
            ],
            const SizedBox(height: 20),
            if (ai.isRejected)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Change my photos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.send),
                  label: Text(ai.isApproved
                      ? (widget.isEditing ? 'Save report' : 'Send report')
                      : (widget.isEditing ? 'Save for review' : 'Send for review')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                style: TextButton.styleFrom(foregroundColor: textDark),
                child: const Text('Go back and edit'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Form(
              key: _formKey,
              autovalidateMode: _showMissingErrors
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  if (widget.isEditing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_new, size: 16, color: textDark),
                              SizedBox(width: 6),
                              Text('Back',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600, color: textDark)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: _sectionLabel(widget.isEditing ? 'EDIT REPORT' : 'NEW REPORT'),
                      ),
                      if (!widget.isEditing)
                        TextButton.icon(
                          onPressed: _isSubmitting ? null : _openDrafts,
                          icon: const Icon(Icons.drafts_outlined, size: 18),
                          label: Text(_draftCount > 0 ? 'Drafts ($_draftCount)' : 'Drafts'),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryGreen,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isEditing ? 'Edit your report' : 'Report an incident',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Describe any problem in the city: trash, broken street light, pothole, water leak…',
                    style: TextStyle(fontSize: 13, color: textMuted, height: 1.3),
                  ),

                  const SizedBox(height: 22),

                  // 1. Title
                  _sectionLabel('PROBLEM TITLE'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    maxLength: _titleMaxLength,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      hint: 'e.g. Broken street light',
                      icon: Icons.title,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Please enter a title.';
                      if (text.length < 3) return 'The title is too short.';
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  // 2. Description
                  _sectionLabel('DESCRIPTION'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: _descriptionMaxLength,
                    minLines: 4,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      hint: 'What is the problem? Since when? Any details that help find it…',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Please describe the problem.';
                      if (text.length < 10) {
                        return 'Please give a bit more detail (at least 10 characters).';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  // 3. Photos
                  Row(
                    children: [
                      _sectionLabel('PHOTOS'),
                      const Spacer(),
                      Text(
                        '${_photos.length}/$_maxPhotos',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildPhotoSection(),
                  if (_showMissingErrors && _photosMissing)
                    _fieldError('Please add at least one photo of the problem.'),

                  const SizedBox(height: 22),

                  // 4. Location
                  _sectionLabel('LOCATION'),
                  const SizedBox(height: 8),
                  _buildLocationSection(),
                  if (_showMissingErrors && _locationMissing)
                    _fieldError('Please choose the location on the map.'),

                  const SizedBox(height: 28),

                  // 5. Submit
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primaryGreen.withValues(alpha: 0.6),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _isSubmitting
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_isAnalyzing) ...[
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Checking photos with AI…',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            )
                          : Text(
                              widget.isEditing ? 'Save changes' : 'Submit report',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  if (!widget.isEditing) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : () => _saveDraft(),
                        icon: const Icon(Icons.save_outlined, size: 20),
                        label: Text(_draftId == null ? 'Save as draft' : 'Update draft'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGreen,
                          side: const BorderSide(color: primaryGreen, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNavBar && !widget.isEditing
          ? CustomBottomNavigationBar(
              currentIndex: 1,
              onTap: (index) {
                if (index == 0 && widget.onNavigateToMap != null) {
                  widget.onNavigateToMap!();
                } else if (index == 2 && widget.onNavigateToMyReports != null) {
                  widget.onNavigateToMyReports!();
                } else if (index == 3 && widget.onNavigateToProfile != null) {
                  widget.onNavigateToProfile!();
                }
              },
            )
          : null,
    );
  }

  Widget _fieldError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: Colors.redAccent),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Color(0xFF7E8F8B),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, IconData? icon}) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA3B1AD), fontSize: 14),
      prefixIcon: icon == null ? null : Icon(icon, color: primaryGreen, size: 20),
      filled: true,
      fillColor: Colors.white,
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: border(const Color(0xFFE5EDE9)),
      focusedBorder: border(primaryGreen, 2),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, 2),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Photo Section (grid of thumbnails + "add" tile)
  // ---------------------------------------------------------------------------

  Widget _buildPhotoSection() {
    if (_photos.isEmpty) {
      return GestureDetector(
        onTap: _isPickingPhoto ? null : _showPhotoOptions,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: _showMissingErrors && _photosMissing
                ? Colors.redAccent
                : const Color(0xFFCCD7D3),
            strokeWidth: 1.5,
            dashWidth: 6,
            dashSpace: 4,
            radius: 18,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: lightMintBackground,
                    shape: BoxShape.circle,
                  ),
                  child: _isPickingPhoto
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                          ),
                        )
                      : const Icon(Icons.add_a_photo_outlined,
                          color: primaryGreen, size: 26),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add photos',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Up to $_maxPhotos photos from camera or gallery',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _smallPhotoButton(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onPressed: () => _pickPhoto(ImageSource.camera),
                    ),
                    const SizedBox(width: 10),
                    _smallPhotoButton(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final canAddMore = _photos.length < _maxPhotos;
    final tileCount = _photos.length + (canAddMore ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tileCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        if (index == _photos.length) {
          return _buildAddPhotoTile();
        }
        return _buildPhotoThumbnail(index);
      },
    );
  }

  Widget _smallPhotoButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _isPickingPhoto ? null : onPressed,
      icon: Icon(icon, size: 16, color: primaryGreen),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: const BorderSide(color: Color(0xFFCCD7D3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }

  Widget _buildPhotoThumbnail(int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => _previewFullPhoto(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(_photos[index], fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoTile() {
    return GestureDetector(
      onTap: _isPickingPhoto ? null : _showPhotoOptions,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: const Color(0xFFCCD7D3),
          strokeWidth: 1.5,
          dashWidth: 5,
          dashSpace: 4,
          radius: 14,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: _isPickingPhoto
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                    ),
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: primaryGreen, size: 26),
                      SizedBox(height: 2),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Location Section (Card + Mini-Map)
  // ---------------------------------------------------------------------------

  Widget _buildLocationSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _showMissingErrors && _locationMissing
              ? Colors.redAccent
              : const Color(0xFFE8ECEB),
          width: _showMissingErrors && _locationMissing ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Text Details Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: lightMintBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _isLocationChangedFromMap
                                ? 'Location from map'
                                : 'Choose a location',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          if (_isLocationChangedFromMap) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: lightMintBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'MAP',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isLocationChangedFromMap
                            ? _selectedLocation.address
                            : 'Tap "Map" to pin where the problem is',
                        style: const TextStyle(
                          fontSize: 13,
                          color: textMuted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Button to launch map picker
                ElevatedButton.icon(
                  onPressed: _openMapLocationPicker,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                  label: const Text(
                    'Map',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightMintBackground,
                    foregroundColor: primaryGreen,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Interactive Mini-Map Preview
          GestureDetector(
            onTap: _openMapLocationPicker,
            child: Container(
              height: 125,
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Stylized mini map vector canvas
                    CustomPaint(
                      painter: _MiniMapPreviewPainter(
                        pinRatio: _selectedLocation.mapOffsetRatio,
                      ),
                    ),

                    // Tap to pick on map overlay banner
                    Positioned(
                      bottom: 8,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCCD7D3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, size: 13, color: primaryGreen),
                            SizedBox(width: 4),
                            Text(
                              'Tap map to change location',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// -----------------------------------------------------------------------------
// Custom Painter: Mini-Map Preview with Pin
// -----------------------------------------------------------------------------

class _MiniMapPreviewPainter extends CustomPainter {
  final Offset pinRatio;

  _MiniMapPreviewPainter({required this.pinRatio});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background
    final backgroundPaint = Paint()..color = const Color(0xFFEEF2F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // 2. Parks
    final parkPaint = Paint()..color = const Color(0xFFE1EAE4);

    final p1 = Path()
      ..moveTo(0, size.height * 0.1)
      ..lineTo(size.width * 0.35, size.height * 0.25)
      ..lineTo(size.width * 0.3, size.height * 0.8)
      ..lineTo(0, size.height * 0.7)
      ..close();
    canvas.drawPath(p1, parkPaint);

    final p2 = Path()
      ..moveTo(size.width * 0.65, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.7)
      ..lineTo(size.width * 0.72, size.height * 0.6)
      ..close();
    canvas.drawPath(p2, parkPaint);

    // 3. Roads
    final roadBorder = Paint()
      ..color = const Color(0xFFDFE6E3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 24;

    final roadSurface = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;

    final roadA = Path()
      ..moveTo(-20, size.height * 0.35)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.45,
        size.width * 0.7,
        size.height * 0.25,
        size.width + 20,
        size.height * 0.35,
      );

    final roadB = Path()
      ..moveTo(size.width * 0.5, -20)
      ..lineTo(size.width * 0.45, size.height + 20);

    canvas.drawPath(roadA, roadBorder);
    canvas.drawPath(roadB, roadBorder);

    canvas.drawPath(roadA, roadSurface);
    canvas.drawPath(roadB, roadSurface);

    // 4. Pin at selected ratio
    final pinX = pinRatio.dx * size.width;
    final pinY = pinRatio.dy * size.height;

    // Pulse Ring
    final pulsePaint = Paint()
      ..color = const Color(0xFF086B5B).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pinX, pinY), 16, pulsePaint);

    // Pin shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pinX, pinY + 3), width: 14, height: 6),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    // Pin marker
    final pinPaint = Paint()..color = const Color(0xFF086B5B);
    canvas.drawCircle(Offset(pinX, pinY), 8, pinPaint);

    final pinInnerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(pinX, pinY), 3.5, pinInnerPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPreviewPainter oldDelegate) {
    return oldDelegate.pinRatio != pinRatio;
  }
}

// -----------------------------------------------------------------------------
// Custom Painter: Dashed Border
// -----------------------------------------------------------------------------

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length) ? dashWidth : metric.length - distance;
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
