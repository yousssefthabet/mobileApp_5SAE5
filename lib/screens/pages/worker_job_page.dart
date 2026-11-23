import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';
import 'package:chargi/services/report_service.dart';
import 'worker_report_page.dart';

/// Worker portal: lists every user's reports so a worker can pick one,
/// change its status, edit it or delete it.
class WorkerJobPage extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  final VoidCallback? onNavigateToProfile;
  final bool showBottomNavBar;

  const WorkerJobPage({
    super.key,
    this.onNavigateToHome,
    this.onNavigateToProfile,
    this.showBottomNavBar = true,
  });

  @override
  State<WorkerJobPage> createState() => _WorkerJobPageState();
}

/// Filters shown as chips. `open` = everything that is not resolved.
enum _Filter { open, aiReview, sent, assigned, inProgress, resolved, all }

class _WorkerJobPageState extends State<WorkerJobPage> {
  _Filter _filter = _Filter.open;

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color cardBorderColor = Color(0xFFE8ECEB);
  static const Color onDutyBadgeBg = Color(0xFFDDF0EB);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);

  late final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _reportsStream =
      ReportService.instance.watchAllReports();

  int get _navIndex => _filter == _Filter.resolved ? 2 : 0;

  bool _matches(String status, Object? aiStatus) {
    switch (_filter) {
      case _Filter.open:
        return status != ReportStatus.resolved;
      case _Filter.sent:
        return status == ReportStatus.sent;
      case _Filter.assigned:
        return status == ReportStatus.assigned;
      case _Filter.inProgress:
        return status == ReportStatus.inProgress;
      case _Filter.resolved:
        return status == ReportStatus.resolved;
      case _Filter.aiReview:
        return status != ReportStatus.resolved && aiStatus == 'NEEDS_REVIEW';
      case _Filter.all:
        return true;
    }
  }

  String _filterLabel(_Filter f) {
    switch (f) {
      case _Filter.open:
        return 'To do';
      case _Filter.sent:
        return 'New';
      case _Filter.assigned:
        return 'Assigned';
      case _Filter.inProgress:
        return 'Work in progress';
      case _Filter.resolved:
        return 'Resolved';
      case _Filter.aiReview:
        return 'Needs review';
      case _Filter.all:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _reportsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildError(snapshot.error);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: primaryGreen));
            }

            final docs = snapshot.data!;
            final statuses =
                docs.map((d) => ReportStatus.normalize(d.data()['status'] as String?)).toList();
            final newCount = statuses.where((s) => s == ReportStatus.sent).length;
            final activeCount = statuses
                .where((s) => s == ReportStatus.assigned || s == ReportStatus.inProgress)
                .length;
            final doneCount = statuses.where((s) => s == ReportStatus.resolved).length;

            final visible = [
              for (var i = 0; i < docs.length; i++)
                if (_matches(statuses[i], docs[i].data()['aiStatus'])) docs[i],
            ];

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                const Text(
                  'WORKER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xFF7E8F8B),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reports to handle',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: onDutyBadgeBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'On duty',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    _buildStatCard(count: '$newCount', label: 'New'),
                    const SizedBox(width: 12),
                    _buildStatCard(count: '$activeCount', label: 'Active'),
                    const SizedBox(width: 12),
                    _buildStatCard(count: '$doneCount', label: 'Done'),
                  ],
                ),
                const SizedBox(height: 18),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _Filter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_filterLabel(f)),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                            selectedColor: primaryGreen,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: _filter == f ? primaryGreen : cardBorderColor,
                            ),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _filter == f ? Colors.white : textDark,
                            ),
                            showCheckmark: false,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (visible.isEmpty)
                  _buildEmpty()
                else
                  for (final doc in visible) ...[
                    _buildReportCard(doc),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: widget.showBottomNavBar
          ? CustomBottomNavigationBar(
              isWorker: true,
              currentIndex: _navIndex,
              onTap: (index) {
                if (index == 0) {
                  setState(() => _filter = _Filter.open);
                } else if (index == 1) {
                  widget.onNavigateToHome?.call();
                } else if (index == 2) {
                  setState(() => _filter = _Filter.resolved);
                } else if (index == 3) {
                  widget.onNavigateToProfile?.call();
                }
              },
            )
          : null,
    );
  }

  Widget _buildReportCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = ReportStatus.normalize(data['status'] as String?);
    final title = (data['problemTitle'] as String?)?.trim().isNotEmpty == true
        ? data['problemTitle'] as String
        : 'Report';
    final reference =
        (data['reference'] as String?) ?? '#${doc.id.substring(0, 6).toUpperCase()}';
    final location = (data['location'] as String?) ?? 'Unknown location';
    final description = (data['description'] as String?)?.trim() ?? '';
    final photos = (data['photosBase64'] as List?)?.whereType<String>().toList() ?? [];
    final firstPhoto = photos.isNotEmpty ? photos.first : data['photoBase64'] as String?;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WorkerReportPage(reportRef: doc.reference)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 70,
                height: 70,
                child: firstPhoto != null
                    ? Image.memory(
                        base64Decode(firstPhoto),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _photoPlaceholder(status),
                      )
                    : _photoPlaceholder(status),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _statusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$reference · ${_formatDate(data['createdAt'])}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ),
                      if (data['aiStatus'] == 'NEEDS_REVIEW') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEEE5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.manage_search, size: 12, color: Color(0xFFC05218)),
                              SizedBox(width: 3),
                              Text(
                                'AI: needs review',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC05218),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((data['aiReport'] as Map?)?['urgency'] is String) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Urgency: ${(data['aiReport'] as Map)['urgency']} · '
                      '${(data['aiReport'] as Map)['responsible_department'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3C4D48),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: textMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF3C4D48)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder(String status) {
    return Container(
      color: ReportStatus.background(status),
      child: Icon(ReportStatus.icon(status), color: ReportStatus.foreground(status)),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ReportStatus.background(status),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        ReportStatus.label(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ReportStatus.foreground(status),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 44, color: textMuted),
          const SizedBox(height: 10),
          Text(
            'No reports in "${_filterLabel(_filter)}"',
            style: const TextStyle(fontWeight: FontWeight.w700, color: textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object? error) {
    final denied = error is FirebaseException && error.code == 'permission-denied';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(denied ? Icons.lock_outline : Icons.error_outline,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              denied ? 'Worker access required' : 'Could not load reports',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
            ),
            const SizedBox(height: 6),
            Text(
              denied
                  ? "This account is not a worker. In the Firebase console, add the field role: 'worker' to this user's document in the users collection."
                  : '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: textMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: widget.onNavigateToHome,
              child: const Text('Back to the app'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required String count, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(dynamic ts) {
    if (ts is! Timestamp) return 'just now';
    final d = ts.toDate();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
