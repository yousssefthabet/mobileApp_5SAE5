import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/users/data/user_role_repository.dart';
import 'package:chargi/features/users/domain/user_role.dart';

void main() {
  group('UserRole.parse', () {
    test('known roles', () {
      expect(UserRole.parse('user'), UserRole.user);
      expect(UserRole.parse('worker'), UserRole.worker);
      expect(UserRole.parse('admin'), UserRole.admin);
    });

    test('tolerates case and spaces from a hand-edited console value', () {
      expect(UserRole.parse(' Worker '), UserRole.worker);
      expect(UserRole.parse('ADMIN'), UserRole.admin);
    });

    test('anything missing or unknown is a plain user (fail closed)', () {
      expect(UserRole.parse(null), UserRole.user);
      expect(UserRole.parse(''), UserRole.user);
      expect(UserRole.parse('superuser'), UserRole.user);
      expect(UserRole.parse('worker2'), UserRole.user);
      expect(UserRole.parse(1), UserRole.user);
      expect(UserRole.parse(true), UserRole.user);
      expect(UserRole.parse(['worker']), UserRole.user);
    });

    test('fromData: no document, no field, or a field', () {
      expect(UserRole.fromData(null), UserRole.user);
      expect(UserRole.fromData({'name': 'A'}), UserRole.user); // older account
      expect(UserRole.fromData({'role': 'worker'}), UserRole.worker);
    });
  });

  group('canUseWorkerPortal', () {
    test('only workers and admins', () {
      expect(UserRole.user.canUseWorkerPortal, isFalse);
      expect(UserRole.worker.canUseWorkerPortal, isTrue);
      expect(UserRole.admin.canUseWorkerPortal, isTrue);
    });
  });

  group('UserRoleRepository.watchRole', () {
    test('follows the document live, including promotion and demotion', () async {
      final controller = StreamController<Map<String, dynamic>?>();
      final repo = UserRoleRepository(documentSource: (_) => controller.stream);
      final roles = <UserRole>[];
      final sub = repo.watchRole('u1').listen(roles.add);

      controller
        ..add(null) // profile not created yet
        ..add({'name': 'A'}) // older account, no role
        ..add({'name': 'A', 'role': 'user'})
        ..add({'name': 'A', 'role': 'worker'}) // promoted from the console
        ..add({'name': 'A', 'role': 'user'}); // demoted
      await pumpEventQueue();

      expect(roles, [
        UserRole.user,
        UserRole.user,
        UserRole.user,
        UserRole.worker,
        UserRole.user,
      ]);
      await sub.cancel();
      await controller.close();
    });

    test('a read error (offline, permission denied) never grants access', () async {
      final controller = StreamController<Map<String, dynamic>?>();
      final repo = UserRoleRepository(documentSource: (_) => controller.stream);
      final roles = <UserRole>[];
      final sub = repo.watchRole('u1').listen(roles.add);

      controller.add({'role': 'worker'});
      await pumpEventQueue();
      controller.addError(Exception('permission-denied'));
      await pumpEventQueue();

      expect(roles, [UserRole.worker, UserRole.user]);
      await sub.cancel();
      await controller.close();
    });

    test('asks the source for the right user', () async {
      String? asked;
      final repo = UserRoleRepository(documentSource: (uid) {
        asked = uid;
        return Stream.value({'role': 'admin'});
      });
      expect(await repo.watchRole('abc').first, UserRole.admin);
      expect(asked, 'abc');
    });
  });
}
