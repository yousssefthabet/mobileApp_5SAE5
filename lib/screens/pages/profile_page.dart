// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';

class ProfilePage extends StatelessWidget {
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToReport;
  final VoidCallback? onNavigateToMyReports;
  final VoidCallback? onSwitchToWorkerMode;
  final bool showBottomNavBar;

  const ProfilePage({
    super.key,
    this.onNavigateToMap,
    this.onNavigateToReport,
    this.onNavigateToMyReports,
    this.onSwitchToWorkerMode,
    this.showBottomNavBar = true,
  });

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color cardBorderColor = Color(0xFFE8ECEB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // 1. User Profile Header
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '[Your name]',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2926),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '[email@example.com]',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7A8B86),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 2. Three Metric Cards Row
              Row(
                children: [
                  _buildMetricCard(count: '5', label: 'Reports sent'),
                  const SizedBox(width: 12),
                  _buildMetricCard(count: '3', label: 'Resolved'),
                  const SizedBox(width: 12),
                  _buildMetricCard(count: '8', label: 'Charges'),
                ],
              ),

              const SizedBox(height: 24),

              // 3. Settings / Options List
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      title: 'Charging history',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      title: 'Payment methods',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      title: 'Notifications',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      title: 'Language',
                      onTap: () {},
                    ),
                    if (onSwitchToWorkerMode != null) ...[
                      _buildDivider(),
                      _buildMenuItem(
                        title: "Worker portal (View Job Page)",
                        icon: Icons.badge_outlined,
                        textColor: primaryGreen,
                        onTap: onSwitchToWorkerMode!,
                      ),
                    ],
                    _buildDivider(),
                    _buildMenuItem(
                      title: 'Log out',
                      textColor: const Color(0xFFD32F2F),
                      hideTrailing: true,
                      onTap: () {
                        _showLogoutConfirmation(context);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: showBottomNavBar
          ? CustomBottomNavigationBar(
              currentIndex: 3,
              onTap: (index) {
                if (index == 0 && onNavigateToMap != null) {
                  onNavigateToMap!();
                } else if (index == 1 && onNavigateToReport != null) {
                  onNavigateToReport!();
                } else if (index == 2 && onNavigateToMyReports != null) {
                  onNavigateToMyReports!();
                }
              },
            )
          : null,
    );
  }

  Widget _buildMetricCard({required String count, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2926),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7A8B86),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    Color? textColor,
    IconData? icon,
    bool hideTrailing = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: textColor ?? const Color(0xFF1E2926)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? const Color(0xFF1E2926),
                ),
              ),
            ),
            if (!hideTrailing)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF9EAFA9),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF0F4F2),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out of your Chargi account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7A8B86))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully')),
              );
            },
            child: const Text('Log out', style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
  }
}
