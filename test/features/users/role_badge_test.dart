import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/users/domain/user_role.dart';
import 'package:chargi/features/users/presentation/role_badge.dart';

void main() {
  test('roleLabel gives a readable name for each role', () {
    expect(roleLabel(UserRole.user), 'User');
    expect(roleLabel(UserRole.worker), 'Worker');
    expect(roleLabel(UserRole.admin), 'Admin');
  });

  for (final role in UserRole.values) {
    testWidgets('RoleBadge shows "${roleLabel(role)}" for $role', (tester) async {
      final semantics = tester.ensureSemantics(); // off by default in tests
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: RoleBadge(role: role)))),
      );

      expect(find.text(roleLabel(role)), findsOneWidget);
      expect(
        find.bySemanticsLabel('Role: ${roleLabel(role)}'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  }
}
