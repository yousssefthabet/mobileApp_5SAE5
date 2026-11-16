import 'package:firebase_auth/firebase_auth.dart';

/// Thin abstraction over the Firebase Auth calls used by password recovery.
///
/// Keeping this interface tiny lets the repository be tested with a fake,
/// without any extra mocking dependency.
abstract class AuthService {
  Future<void> sendPasswordResetEmail(
    String email, {
    String? continueUrl,
  });

  /// Returns the email address the [code] belongs to.
  Future<String> verifyPasswordResetCode(String code);

  Future<void> confirmPasswordReset(String code, String newPassword);
}

/// Production implementation backed by [FirebaseAuth].
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<void> sendPasswordResetEmail(
    String email, {
    String? continueUrl,
  }) {
    // `continueUrl` is only set when a redirect URL has been configured and
    // authorised in the Firebase console. Otherwise Firebase's default
    // behaviour is used.
    final settings = continueUrl == null
        ? null
        : ActionCodeSettings(url: continueUrl, handleCodeInApp: false);
    return _auth.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: settings,
    );
  }

  @override
  Future<String> verifyPasswordResetCode(String code) =>
      _auth.verifyPasswordResetCode(code);

  @override
  Future<void> confirmPasswordReset(String code, String newPassword) =>
      _auth.confirmPasswordReset(code: code, newPassword: newPassword);
}
