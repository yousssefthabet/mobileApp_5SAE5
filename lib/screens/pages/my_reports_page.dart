import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';
import 'report_details_page.dart';
import 'report_trash_page.dart';

class MyReportsPage extends StatefulWidget {
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToReport;
  final VoidCallback? onNavigateToProfile;
  final bool showBottomNavBar;

  const MyReportsPage({
    super.key,
    this.onNavigateToMap,
    this.onNavigateToReport,
    this.onNavigateToProfile,
    this.showBottomNavBar = true,
  });

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  int _selectedTab = 0; // 0: Active, 1: Resolved

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color orangeBadgeBackground = Color(0xFFFDEEE5);
  static const Color orangeBadgeText = Color(0xFFC05218);
  static const Color greenBadgeBackground = Color(0xFFE4F3EE);
  static const Color greenBadgeText = Color(0xFF0D6855);
  static const Color mintBadgeBackground = Color(0xFFE2EFEA);
  static const Color mintBadgeText = Color(0xFF086B5B);
  static const Color blueBadgeBackground = Color(0xFFE8F1FC);
  static const Color blueBadgeText = Color(0xFF1E63B8);

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        if (diff.inMinutes <= 1) return 'just now';
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays == 1) {
        return 'yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    }
    return 'today';
  }

  IconData _iconForProblem(String problemTitle) {
    final title = problemTitle.toLowerCase();
    if (title.contains('dumping')) {
      return Icons.delete_sweep_outlined;
    } else if (title.contains('broken')) {
      return Icons.build_outlined;
    } else if (title.contains('lid')) {
      return Icons.handyman_outlined;
    }
    return Icons.delete_outline;
  }

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Title
              const Text(
                'My reports',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2926),
                ),
              ),

              const SizedBox(height: 16),

              // Segmented Tabs: Active / Resolved
              Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EDE9),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.w500,
                              color: _selectedTab == 0
                                  ? const Color(0xFF1E2926)
                                  : const Color(0xFF6B7B76),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Resolved',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.w500,
                              color: _selectedTab == 1
                                  ? const Color(0xFF1E2926)
                                  : const Color(0xFF6B7B76),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Stream of reports from Firestore
              if (user == null)
                _buildLoggedOutState()
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('reports')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(color: primaryGreen),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                            const SizedBox(height: 10),
                            const Text(
                              'Could not load reports',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E2926),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF7A8B86)),
                            ),
                          ],
                        ),
                      );
                    }

                    final allDocs = snapshot.data?.docs ?? [];
                    final activeReports = allDocs.where((doc) {
                      final status = (doc.data()['status'] as String? ?? '').toLowerCase();
                      return status != 'resolved';
                    }).toList();

                    final resolvedReports = allDocs.where((doc) {
                      final status = (doc.data()['status'] as String? ?? '').toLowerCase();
                      return status == 'resolved';
                    }).toList();

                    if (_selectedTab == 0) {
                      if (activeReports.isEmpty) {
                        return _buildEmptyState(
                          icon: Icons.check_circle_outline,
                          title: 'No active reports',
                          description:
                              'You have no ongoing reports. Help keep the city clean by reporting trash issues.',
                          buttonText: 'Report an issue',
                          onAction: () {
                            if (widget.onNavigateToReport != null) {
                              widget.onNavigateToReport!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReportTrashPage(),
                                ),
                              );
                            }
                          },
                        );
                      }

                      return Column(
                        children: activeReports.map((doc) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _buildRealActiveReportCard(doc),
                          );
                        }).toList(),
                      );
                    } else {
                      if (resolvedReports.isEmpty) {
                        return _buildEmptyState(
                          icon: Icons.cleaning_services_outlined,
                          title: 'No resolved reports yet',
                          description:
                              'Reports that have been cleaned and resolved by municipal workers will show up here.',
                          buttonText: null,
                          onAction: null,
                        );
                      }

                      return Column(
                        children: resolvedReports.map((doc) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _buildRealResolvedReportCard(doc),
                          );
                        }).toList(),
                      );
                    }
                  },
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNavBar
          ? CustomBottomNavigationBar(
              currentIndex: 2,
              onTap: (index) {
                if (index == 0 && widget.onNavigateToMap != null) {
                  widget.onNavigateToMap!();
                } else if (index == 1 && widget.onNavigateToReport != null) {
                  widget.onNavigateToReport!();
                } else if (index == 3 && widget.onNavigateToProfile != null) {
                  widget.onNavigateToProfile!();
                }
              },
            )
          : null,
    );
  }

  Widget _buildLoggedOutState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECEB)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.lock_outline, size: 44, color: primaryGreen),
            SizedBox(height: 12),
            Text(
              'Sign in to view reports',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2926),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Your submitted reports and their real-time cleaning progress will appear here once you sign in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF7A8B86)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    required String? buttonText,
    required VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECEB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE2EFEA),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: primaryGreen),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2926),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7A8B86),
              height: 1.35,
            ),
          ),
          if (buttonText != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 18),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Active Report Card loaded from Firestore
  Widget _buildRealActiveReportCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final docId = doc.id;
    final reference = (data['reference'] as String?) ?? '#${docId.substring(0, 6).toUpperCase()}';
    final problemTitle = (data['problemTitle'] as String?) ?? 'Trash report';
    final location = (data['location'] as String?) ?? 'Tunis';
    final dateStr = _formatDate(data['createdAt']);
    final status = (data['status'] as String? ?? 'sent').toLowerCase();
    final worker = (data['workerName'] as String?) ?? 'Unassigned';
    final eta = (data['estimatedArrival'] as String?) ?? 'Reviewing report';

    Color badgeBg;
    Color badgeText;
    String badgeLabel;
    int stepIndex;
    String bannerText;

    if (status == 'assigned') {
      badgeBg = blueBadgeBackground;
      badgeText = blueBadgeText;
      badgeLabel = 'Assigned';
      stepIndex = 1;
      bannerText = 'Assigned to $worker · $eta';
    } else if (status == 'in_progress') {
      badgeBg = orangeBadgeBackground;
      badgeText = orangeBadgeText;
      badgeLabel = 'In progress';
      stepIndex = 2;
      bannerText = '$worker is on the way · $eta';
    } else {
      badgeBg = mintBadgeBackground;
      badgeText = mintBadgeText;
      badgeLabel = 'Sent';
      stepIndex = 0;
      bannerText = 'Report received · Under municipal review';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailsPage(
              reportDocId: docId,
              reportId: reference,
              problemTitle: problemTitle,
              location: '$location · $dateStr',
              workerName: worker,
              estimatedArrival: eta,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8ECEB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Thumbnail
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE7E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconForProblem(problemTitle),
                    color: const Color(0xFF70857D),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        problemTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E2926),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$location · $dateStr',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7A8B86),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badgeText,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Stepper / Timeline
            _buildProgressStepper(currentStep: stepIndex),

            const SizedBox(height: 18),

            // Notification Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                bannerText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF283633),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Progress Stepper Widget (Sent -> Assigned -> In progress -> Resolved)
  Widget _buildProgressStepper({required int currentStep}) {
    final steps = ['Sent', 'Assigned', 'In progress', 'Resolved'];

    return Column(
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isEven) {
              final stepIndex = index ~/ 2;
              final isCompleted = stepIndex <= currentStep;
              final isCurrent = stepIndex == currentStep;

              return Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? primaryGreen : Colors.white,
                  border: Border.all(
                    color: isCompleted ? primaryGreen : const Color(0xFFCCD6D2),
                    width: isCurrent ? 3 : 2,
                  ),
                ),
                child: isCompleted && !isCurrent
                    ? const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      )
                    : null,
              );
            } else {
              final lineIndex = index ~/ 2;
              final isLineFilled = lineIndex < currentStep;

              return Expanded(
                child: Container(
                  height: 3,
                  color: isLineFilled ? primaryGreen : const Color(0xFFE2EBE7),
                ),
              );
            }
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps.map((step) {
            final isHighlight = step == 'In progress' || step == 'Sent';
            return SizedBox(
              width: 65,
              child: Text(
                step,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w400,
                  color: isHighlight ? const Color(0xFF1E2926) : const Color(0xFF8B9B96),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Resolved Report Card loaded from Firestore
  Widget _buildRealResolvedReportCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final docId = doc.id;
    final reference = (data['reference'] as String?) ?? '#${docId.substring(0, 6).toUpperCase()}';
    final problemTitle = (data['problemTitle'] as String?) ?? 'Trash report';
    final location = (data['location'] as String?) ?? 'Tunis';
    final dateStr = _formatDate(data['createdAt']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailsPage(
              reportDocId: docId,
              reportId: reference,
              problemTitle: problemTitle,
              location: '$location · $dateStr',
              workerName: (data['workerName'] as String?) ?? 'Municipal Crew',
              estimatedArrival: 'Resolved',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8ECEB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        problemTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E2926),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$location · $dateStr',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7A8B86),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: greenBadgeBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Resolved',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: greenBadgeText,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Before and After Containers
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 90,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3ECE8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Before',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B4844).withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 90,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6EADA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'After',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF245037).withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
