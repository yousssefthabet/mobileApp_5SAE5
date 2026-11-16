import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/auth/data/auth_repository.dart';
import 'package:chargi/features/auth/data/auth_service.dart';
import 'package:chargi/features/auth/domain/password_reset_failure.dart';

class FakeAuthService implements AuthService {
  String? errorCode;
  int sendCalls = 0;
  String? lastContinueUrl;
  String? lastEmail;
  String? lastConfirmedCode;
  String? lastConfirmedPassword;

  void _maybeThrow() {
    if (errorCode != null) throw FirebaseAuthException(code: errorCode!);
  }

  @override
  Future<void> sendPasswordResetEmail(String email,
      {String? continueUrl}) async {
    sendCalls++;
    lastEmail = email;
    lastContinueUrl = continueUrl;
    _maybeThrow();
  }

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    _maybeThrow();
    return 'user@example.com';
  }

  @override
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    _maybeThrow();
    lastConfirmedCode = code;
    lastConfirmedPassword = newPassword;
  }
}

Future<PasswordResetFailure?> failureOf(Future<void> Function() action) async {
  try {
    await action();
    return null;
  } on PasswordResetException catch (e) {
    return e.failure;
  }
}

void main() {
  late FakeAuthService service;
  late AuthRepository repo;

  setUp(() {
    service = FakeAuthService();
    repo = AuthRepository(service: service, continueUrl: '');
  });

  group('sendPasswordResetEmail', () {
    test('sends the trimmed email without inventing a redirect URL', () async {
      await repo.sendPasswordResetEmail('  user@example.com ');
      expect(service.sendCalls, 1);
      expect(service.lastEmail, 'user@example.com');
      expect(service.lastContinueUrl, isNull);
    });

    test('passes the configured redirect URL', () async {
      final configured = AuthRepository(
        service: service,
        continueUrl: 'https://example.test/done',
      );
      await configured.sendPasswordResetEmail('user@example.com');
      expect(service.lastContinueUrl, 'https://example.test/done');
    });

    test('rejects an invalid email without calling Firebase', () async {
      expect(await failureOf(() => repo.sendPasswordResetEmail('nope')),
          PasswordResetFailure.invalidEmail);
      expect(service.sendCalls, 0);
    });

    test('hides whether the account exists (user-not-found succeeds)',
        () async {
      service.errorCode = 'user-not-found';
      expect(await failureOf(() => repo.sendPasswordResetEmail('a@b.co')),
          isNull);
    });

    test('maps network, throttling and unknown errors', () async {
      service.errorCode = 'network-request-failed';
      expect(await failureOf(() => repo.sendPasswordResetEmail('a@b.co')),
          PasswordResetFailure.network);
      service.errorCode = 'too-many-requests';
      expect(await failureOf(() => repo.sendPasswordResetEmail('a@b.co')),
          PasswordResetFailure.tooManyRequests);
      service.errorCode = 'something-new';
      expect(await failureOf(() => repo.sendPasswordResetEmail('a@b.co')),
          PasswordResetFailure.unknown);
    });
  });

  group('verifyResetCode', () {
    test('returns the account email for a valid code', () async {
      expect(await repo.verifyResetCode('abc'), 'user@example.com');
    });

    test('maps expired, used/invalid and empty codes', () async {
      service.errorCode = 'expired-action-code';
      expect(await failureOf(() => repo.verifyResetCode('abc')),
          PasswordResetFailure.expiredCode);
      service.errorCode = 'invalid-action-code';
      expect(await failureOf(() => repo.verifyResetCode('abc')),
          PasswordResetFailure.invalidCode);
      expect(await failureOf(() => repo.verifyResetCode('  ')),
          PasswordResetFailure.invalidCode);
    });
  });

  group('confirmPasswordReset', () {
    test('rejects a weak password without calling Firebase', () async {
      expect(
        await failureOf(
            () => repo.confirmPasswordReset(code: 'abc', newPassword: 'weak')),
        PasswordResetFailure.weakPassword,
      );
      expect(service.lastConfirmedCode, isNull);
    });

    test('confirms with a valid password', () async {
      await repo.confirmPasswordReset(code: ' abc ', newPassword: 'Abcdef1!');
      expect(service.lastConfirmedCode, 'abc');
      expect(service.lastConfirmedPassword, 'Abcdef1!');
    });

    test('maps an already-used code', () async {
      service.errorCode = 'invalid-action-code';
      expect(
        await failureOf(() =>
            repo.confirmPasswordReset(code: 'abc', newPassword: 'Abcdef1!')),
        PasswordResetFailure.invalidCode,
      );
    });
  });

  test('user-facing messages never expose raw Firebase text', () {
    for (final f in PasswordResetFailure.values) {
      expect(f.message.toLowerCase(), isNot(contains('firebase')));
      expect(f.message, isNot(contains('auth/')));
    }
  });
}
