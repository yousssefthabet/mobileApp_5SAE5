import 'package:firebase_auth/firebase_auth.dart';

import 'package:chargi/features/auth/data/auth_service.dart';
import 'package:chargi/features/auth/domain/auth_validators.dart';
import 'package:chargi/features/auth/domain/password_reset_failure.dart';

/// Redirect URL for reset emails, injected at build time:
/// `--dart-define=PASSWORD_RESET_CONTINUE_URL=https://...`
///
/// Empty by default: no URL is invented. The domain must also be added to
/// "Authorized domains" in the Firebase console.
const String kPasswordResetContinueUrl =
    String.fromEnvironment('PASSWORD_RESET_CONTINUE_URL');

/// Password recovery use cases. Validates input, calls [AuthService] and
/// translates every error into a [PasswordResetException].
class AuthRepository {
  AuthRepository({AuthService? service, String? continueUrl})
      : _service = service ?? FirebaseAuthService(),
        _continueUrl = (continueUrl ?? kPasswordResetContinueUrl).isEmpty
            ? null
            : (continueUrl ?? kPasswordResetContinueUrl);

  final AuthService _service;
  final String? _continueUrl;

  /// Sends the reset email.
  ///
  /// Completes normally even when no account exists for [email], so callers
  /// cannot tell whether an address is registered.
  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (AuthValidators.validateEmail(trimmed) != null) {
      throw const PasswordResetException(PasswordResetFailure.invalidEmail);
    }

    try {
      await _service.sendPasswordResetEmail(trimmed, continueUrl: _continueUrl);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return; // do not reveal account state
      throw PasswordResetException(PasswordResetFailure.fromCode(e.code));
    } catch (_) {
      throw const PasswordResetException(PasswordResetFailure.unknown);
    }
  }

  /// Checks that [code] is valid and unused. Returns the account email.
  Future<String> verifyResetCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw const PasswordResetException(PasswordResetFailure.invalidCode);
    }
    try {
      return await _service.verifyPasswordResetCode(trimmed);
    } on FirebaseAuthException catch (e) {
      throw PasswordResetException(PasswordResetFailure.fromCode(e.code));
    } catch (_) {
      throw const PasswordResetException(PasswordResetFailure.unknown);
    }
  }

  /// Sets a new password after validating it against the security rules.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    if (AuthValidators.validateNewPassword(newPassword) != null) {
      throw const PasswordResetException(PasswordResetFailure.weakPassword);
    }
    try {
      await _service.confirmPasswordReset(code.trim(), newPassword);
    } on FirebaseAuthException catch (e) {
      throw PasswordResetException(PasswordResetFailure.fromCode(e.code));
    } catch (_) {
      throw const PasswordResetException(PasswordResetFailure.unknown);
    }
  }
}
