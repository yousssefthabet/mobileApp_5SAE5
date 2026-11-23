import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chargi/services/report_service.dart';
import 'package:chargi/widgets/ai_report_view.dart';

/// Worker view of one report: change its status (the author is notified),
/// edit its details, or delete it.
class WorkerReportPage extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> reportRef;

  const WorkerReportPage({super.key, required this.reportRef});

  @override
  State<WorkerReportPage> createState() => _WorkerReportPageState();
}

class _WorkerReportPageState extends State<WorkerReportPage> {
  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color cardBorder = Color(0xFFE8ECEB);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);

  final TextEditingController _workerCtrl = TextEditingController();
  final TextEditingController _etaCtrl = TextEditingController();

  String? _selectedStatus; // null until the worker taps a status
  bool _busy = false;
  bool _deleted = false;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream =
      widget.reportRef.snapshots();

  @override
  void initState() {
    super.initState();
    ReportService.instance.currentWorkerName().then((name) {
      if (mounted && _workerCtrl.text.isEmpty) _workerCtrl.text = name;
    });
  }

  @override
  void dispose() {
    _workerCtrl.dispose();
    _etaCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color color = primaryGreen}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _applyStatus(Map<String, dynamic> data) async {
    final status = _selectedStatus;
    if (status == null) return;
    setState(() => _busy = true);
    try {
      await ReportService.instance.setStatus(
        ref: widget.reportRef,
        currentData: data,
        newStatus: status,
        workerName: _workerCtrl.text,
        estimatedArrival: _etaCtrl.text,
      );
      _etaCtrl.clear();
      setState(() => _selectedStatus = null);
      _snack('Status set to "${ReportStatus.label(status)}". The reporter was notified.');
    } catch (e) {
      _snack('Could not update status: $e', color: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDetails(Map<String, dynamic> data) async {
    final titleCtrl = TextEditingController(text: (data['problemTitle'] as String?) ?? '');
    final descCtrl = TextEditingController(text: (data['description'] as String?) ?? '');
    final formKey = GlobalKey<FormState>();

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit report details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'The reporter will be notified of the change.',
                style: TextStyle(fontSize: 13, color: textMuted),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: titleCtrl,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Problem title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 3 ? 'At least 3 characters' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descCtrl,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 10 ? 'At least 10 characters' : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(sheetContext, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final newTitle = titleCtrl.text.trim();
    final newDesc = descCtrl.text.trim();
    if (save != true) return;

    setState(() => _busy = true);
    try {
      await ReportService.instance.workerEditReport(
        ref: widget.reportRef,
        currentData: data,
        fields: {'problemTitle': newTitle, 'description': newDesc},
      );
      _snack('Report updated. The reporter was notified.');
    } catch (e) {
      _snack('Could not update report: $e', color: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> data) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this report?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('It will be removed for the reporter too, and they will be notified.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Duplicate report',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text;
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      _deleted = true;
      await ReportService.instance.workerDeleteReport(
        ref: widget.reportRef,
        currentData: data,
        reason: reason,
      );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report deleted. The reporter was notified.'),
          backgroundColor: primaryGreen,
        ),
      );
    } catch (e) {
      _deleted = false;
      _snack('Could not delete report: $e', color: Colors.redAccent);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openInMaps(Map<String, dynamic> data) async {
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat is! num || lng is! num) {
      _snack('This report has no coordinates.', color: Colors.orange);
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$lat,$lng',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open maps.', color: Colors.redAccent);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _scaffold(
            body: Center(child: Text('Could not load report: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return _scaffold(
            body: const Center(child: CircularProgressIndicator(color: primaryGreen)),
          );
        }
        if (!snapshot.data!.exists) {
          return _scaffold(
            body: Center(
              child: Text(
                _deleted ? 'Deleting…' : 'This report no longer exists.',
                style: const TextStyle(color: textMuted),
              ),
            ),
          );
        }

        final data = snapshot.data!.data()!;
        return _scaffold(
          title: (data['reference'] as String?) ??
              '#${widget.reportRef.id.substring(0, 6).toUpperCase()}',
          actions: [
            IconButton(
              tooltip: 'Edit details',
              icon: const Icon(Icons.edit_outlined, color: textDark),
              onPressed: _busy ? null : () => _editDetails(data),
            ),
            IconButton(
              tooltip: 'Delete report',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _busy ? null : () => _delete(data),
            ),
          ],
          body: _buildBody(data),
        );
      },
    );
  }

  Widget _scaffold({required Widget body, String? title, List<Widget>? actions}) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title == null ? 'Report' : 'Report $title',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textDark),
        ),
        actions: actions,
      ),
      body: body,
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final status = ReportStatus.normalize(data['status'] as String?);
    final title = (data['problemTitle'] as String?) ?? 'Report';
    final description = (data['description'] as String?)?.trim() ?? '';
    final location = (data['location'] as String?) ?? 'Unknown location';
    final reporter = [
      (data['reporterName'] as String?)?.trim() ?? '',
      (data['reporterEmail'] as String?)?.trim() ?? '',
    ].where((s) => s.isNotEmpty).join(' · ');
    final photos = <String>[
      ...((data['photosBase64'] as List?) ?? const []).whereType<String>(),
    ];
    final legacy = data['photoBase64'] as String?;
    if (photos.isEmpty && legacy != null) photos.add(legacy);

    final aiReview = data['aiReview'] is Map
        ? Map<String, dynamic>.from(data['aiReview'] as Map)
        : null;
    final aiReport = data['aiReport'] is Map
        ? Map<String, dynamic>.from(data['aiReport'] as Map)
        : null;
    final aiAnalysis = aiReview?['imageAnalysis'] is Map
        ? Map<String, dynamic>.from(aiReview!['imageAnalysis'] as Map)
        : null;
    final aiSignals = <String>[
      ...((aiAnalysis?['suspicious_signals'] as List?) ?? const []).whereType<String>(),
      ...((aiAnalysis?['content_concerns'] as List?) ?? const []).whereType<String>(),
      ...(((aiReview?['moderation'] as Map?)?['flaggedCategories'] as List?) ?? const [])
          .whereType<String>()
          .map((c) => 'Safety filter: $c'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      children: [
        if (photos.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 190,
              child: PageView.builder(
                itemCount: photos.length,
                itemBuilder: (_, i) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(base64Decode(photos[i]), fit: BoxFit.cover),
                    if (photos.length > 1)
                      Positioned(
                        right: 12,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${i + 1}/${photos.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textDark),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ReportStatus.background(status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ReportStatus.label(status),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ReportStatus.foreground(status),
                ),
              ),
            ),
          ],
        ),
        if (reporter.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Reported by $reporter', style: const TextStyle(fontSize: 13, color: textMuted)),
        ],
        const SizedBox(height: 14),

        if (aiReview != null) ...[
          AiStatusBanner(
            status: (aiReview['status'] as String?) ?? 'NEEDS_REVIEW',
            explanation: (aiReview['explanation'] as String?) ?? '',
          ),
          if (aiSignals.isNotEmpty) ...[
            const SizedBox(height: 8),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('FLAGGED FOR REVIEW'),
                  const SizedBox(height: 6),
                  for (final s in aiSignals)
                    Text('• $s', style: const TextStyle(fontSize: 13, color: textDark)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (aiReport != null) ...[
          AiReportCard(report: aiReport, imageAnalysis: aiAnalysis),
          const SizedBox(height: 12),
        ],

        _card(
          child: Row(
            children: [
              const Icon(Icons.location_on, color: primaryGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(location, style: const TextStyle(fontSize: 14, color: textDark)),
              ),
              TextButton.icon(
                onPressed: () => _openInMaps(data),
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('Navigate'),
                style: TextButton.styleFrom(foregroundColor: primaryGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (description.isNotEmpty) ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('DESCRIPTION'),
                const SizedBox(height: 6),
                Text(description,
                    style: const TextStyle(fontSize: 14, color: textDark, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('CURRENT HANDLING'),
              const SizedBox(height: 6),
              Text('Worker: ${(data['workerName'] as String?) ?? 'Unassigned'}',
                  style: const TextStyle(color: textDark)),
              const SizedBox(height: 2),
              Text('Note / ETA: ${(data['estimatedArrival'] as String?) ?? '—'}',
                  style: const TextStyle(color: textDark)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _label('CHANGE STATUS'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in ReportStatus.all)
              ChoiceChip(
                avatar: Icon(
                  ReportStatus.icon(s),
                  size: 18,
                  color: (_selectedStatus ?? status) == s
                      ? Colors.white
                      : ReportStatus.foreground(s),
                ),
                label: Text(ReportStatus.label(s)),
                selected: (_selectedStatus ?? status) == s,
                onSelected: _busy ? null : (_) => setState(() => _selectedStatus = s),
                selectedColor: ReportStatus.foreground(s),
                backgroundColor: Colors.white,
                side: BorderSide(color: ReportStatus.foreground(s).withValues(alpha: 0.4)),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: (_selectedStatus ?? status) == s ? Colors.white : textDark,
                ),
                showCheckmark: false,
              ),
          ],
        ),

        if (_selectedStatus != null && _selectedStatus != status) ...[
          const SizedBox(height: 16),
          if (_selectedStatus != ReportStatus.sent) ...[
            TextField(
              controller: _workerCtrl,
              decoration: const InputDecoration(
                labelText: 'Worker name',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_selectedStatus == ReportStatus.assigned ||
              _selectedStatus == ReportStatus.inProgress) ...[
            TextField(
              controller: _etaCtrl,
              decoration: InputDecoration(
                labelText: 'Note for the reporter (optional)',
                hintText: _selectedStatus == ReportStatus.assigned
                    ? 'e.g. Planned for tomorrow morning'
                    : 'e.g. Repair in progress, done in ~2 h',
                prefixIcon: const Icon(Icons.schedule),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _applyStatus(data),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.notifications_active_outlined),
              label: Text('Set "${ReportStatus.label(_selectedStatus)}" & notify reporter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: child,
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Color(0xFF7E8F8B),
        ),
      );
}
