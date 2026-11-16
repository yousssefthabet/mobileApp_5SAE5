/// User-facing failure categories for the password recovery flow.
///
/// Raw Firebase messages are never shown to the user: every error code is
/// mapped to one of these values and to a friendly message.
enum PasswordResetFailure {
  invalidEmail,
  expiredCode,
  invalidCode,
  weakPassword,
  network,
  tooManyRequests,
  userDisabled,
  notAllowed,
  unknown;

  /// Maps a Firebase Auth error [code] to a failure.
  ///
  /// `user-not-found` is intentionally **not** mapped to its own value: it must
  /// never be exposed when requesting a reset, so callers treat it as success.
  static PasswordResetFailure fromCode(String code) {
    switch (code) {
      case 'invalid-email':
      case 'missing-email':
        return PasswordResetFailure.invalidEmail;
      case 'expired-action-code':
        return PasswordResetFailure.expiredCode;
      case 'invalid-action-code':
        return PasswordResetFailure.invalidCode;
      case 'weak-password':
        return PasswordResetFailure.weakPassword;
      case 'network-request-failed':
        return PasswordResetFailure.network;
      case 'too-many-requests':
        return PasswordResetFailure.tooManyRequests;
      case 'user-disabled':
        return PasswordResetFailure.userDisabled;
      case 'operation-not-allowed':
        return PasswordResetFailure.notAllowed;
      default:
        return PasswordResetFailure.unknown;
    }
  }

  String get message {
    switch (this) {
      case PasswordResetFailure.invalidEmail:
        return 'Please enter a valid email address.';
      case PasswordResetFailure.expiredCode:
        return 'This reset link has expired. Please request a new one.';
      case PasswordResetFailure.invalidCode:
        return 'This reset link is invalid or has already been used. '
            'Please request a new one.';
      case PasswordResetFailure.weakPassword:
        return 'This password is too weak. Please choose a stronger one.';
      case PasswordResetFailure.network:
        return 'No internet connection. Check your network and try again.';
      case PasswordResetFailure.tooManyRequests:
        return 'Too many attempts. Please wait a few minutes and try again.';
      case PasswordResetFailure.userDisabled:
        return 'This account has been disabled. Please contact support.';
      case PasswordResetFailure.notAllowed:
        return 'Password reset is currently unavailable. Please try again later.';
      case PasswordResetFailure.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Whether asking for a new link can fix the problem.
  bool get shouldRequestNewLink =>
      this == PasswordResetFailure.expiredCode ||
      this == PasswordResetFailure.invalidCode;
}

/// Thrown by the repository; carries only the safe [failure] category.
class PasswordResetException implements Exception {
  const PasswordResetException(this.failure);

  final PasswordResetFailure failure;

  String get message => failure.message;

  @override
  String toString() => 'PasswordResetException(${failure.name})';
}
