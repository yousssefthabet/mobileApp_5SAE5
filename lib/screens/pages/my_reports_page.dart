import 'package:flutter/material.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';
import 'report_details_page.dart';

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

  @override
  Widget build(BuildContext context) {
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
                                      color: Colors.black.withOpacity(0.06),
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
                                      color: Colors.black.withOpacity(0.06),
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

              // Reports List based on tab selection
              if (_selectedTab == 0) ...[
                // Card 1: Overflowing bin (In progress with timeline)
                _buildActiveReportCard(),
                const SizedBox(height: 18),
                // Card 2: Illegal dumping (Also visible in feed)
                _buildResolvedReportCard(),
              ] else ...[
                // When "Resolved" tab is selected
                _buildResolvedReportCard(),
                const SizedBox(height: 18),
                _buildSecondResolvedCard(),
              ],

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

  /// Card 1: Overflowing bin (Active with timeline stepper)
  Widget _buildActiveReportCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ReportDetailsPage(
              reportId: '#1042',
              problemTitle: 'Overflowing bin',
              location: 'Rue de la Liberté · today',
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
            color: Colors.black.withOpacity(0.03),
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
              // Photo Thumbnail / Placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE7E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFF70857D),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Overflowing bin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2926),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Rue de la Liberté · today',
                      style: TextStyle(
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
                  color: orangeBadgeBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'In progress',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: orangeBadgeText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Stepper / Timeline
          _buildProgressStepper(currentStep: 2),

          const SizedBox(height: 18),

          // Notification Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F6F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'A worker is on the way · about 15 min',
              style: TextStyle(
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

  /// Card 2: Illegal dumping (Resolved with Before/After image containers)
  Widget _buildResolvedReportCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECEB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                  children: const [
                    Text(
                      'Illegal dumping',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2926),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Avenue Habib Bourguiba · 3 days ago',
                      style: TextStyle(
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
                        color: const Color(0xFF3B4844).withOpacity(0.9),
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
                        color: const Color(0xFF245037).withOpacity(0.9),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Extra resolved report item for full preview
  Widget _buildSecondResolvedCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECEB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Broken bin lid',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2926),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Rue de Rome · 1 week ago',
                      style: TextStyle(
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
        ],
      ),
    );
  }
}
