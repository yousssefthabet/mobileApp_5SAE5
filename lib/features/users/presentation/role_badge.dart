import 'package:flutter/material.dart';

import 'package:chargi/features/users/domain/user_role.dart';

/// Short, user-facing name of a role.
String roleLabel(UserRole role) {
  switch (role) {
    case UserRole.user:
      return 'User';
    case UserRole.worker:
      return 'Worker';
    case UserRole.admin:
      return 'Admin';
  }
}

/// Small pill showing the signed-in user's role (shown in the profile).
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (role) {
      UserRole.user => (const Color(0xFFEDEFEE), const Color(0xFF5F6D69)),
      UserRole.worker => (const Color(0xFFDDF1EB), const Color(0xFF086B5B)),
      UserRole.admin => (const Color(0xFFFDEEE5), const Color(0xFFC05218)),
    };

    return Semantics(
      label: 'Role: ${roleLabel(role)}',
      excludeSemantics: true, // announce the label once, not label + text
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          roleLabel(role),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
