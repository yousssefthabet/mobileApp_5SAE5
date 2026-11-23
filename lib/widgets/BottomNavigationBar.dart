// ignore_for_file: file_names, deprecated_member_use
import 'package:flutter/material.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isWorker;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isWorker = false,
  });

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color activePillColor = Color(0xFFDCEEE9);
  static const Color inactiveColor = Color(0xFF7A8985);

  @override
  Widget build(BuildContext context) {
    final List<_NavItem> items = isWorker
        ? const [
            _NavItem(
              label: 'Jobs',
              icon: Icons.format_list_bulleted,
              activeIcon: Icons.format_list_bulleted,
            ),
            _NavItem(
              label: 'Map',
              icon: Icons.location_on_outlined,
              activeIcon: Icons.location_on,
            ),
            _NavItem(
              label: 'Done',
              icon: Icons.check,
              activeIcon: Icons.check_circle_outline,
            ),
            _NavItem(
              label: 'Profile',
              icon: Icons.person_outline,
              activeIcon: Icons.person,
            ),
          ]
        : const [
            _NavItem(
              label: 'Map',
              icon: Icons.location_on_outlined,
              activeIcon: Icons.location_on,
            ),
            _NavItem(
              label: 'Report',
              icon: Icons.add_circle_outline,
              activeIcon: Icons.add_circle,
            ),
            _NavItem(
              label: 'Reports',
              icon: Icons.format_list_bulleted,
              activeIcon: Icons.format_list_bulleted,
            ),
            _NavItem(
              label: 'Profile',
              icon: Icons.person_outline,
              activeIcon: Icons.person,
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: const Border(
          top: BorderSide(
            color: Color(0xFFECEFEF),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = index == currentIndex;
              final item = items[index];

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? activePillColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isSelected ? item.activeIcon : item.icon,
                          size: 22,
                          color: isSelected ? primaryGreen : inactiveColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? primaryGreen : inactiveColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
