/// Why a Google sign-in did not complete. Every failure has a safe,
/// user-facing message: raw errors are never shown.
enum GoogleSignInFailure {
  notConfigured,
  unsupported,
  network,
  accountExistsWithPassword,
  userDisabled,
  tooManyRequests,
  popupBlocked,
  unknown;

  String get message {
    switch (this) {
      case GoogleSignInFailure.notConfigured:
        return 'Google sign-in is not set up for this app yet. '
            'Please use your email and password for now.';
      case GoogleSignInFailure.unsupported:
        return 'Google sign-in is not available on this device.';
      case GoogleSignInFailure.network:
        return 'No internet connection. Check your network and try again.';
      case GoogleSignInFailure.accountExistsWithPassword:
        return 'An account with this email already exists. '
            'Please sign in with your email and password.';
      case GoogleSignInFailure.userDisabled:
        return 'This account has been disabled. Please contact support.';
      case GoogleSignInFailure.tooManyRequests:
        return 'Too many attempts. Please wait a few minutes and try again.';
      case GoogleSignInFailure.popupBlocked:
        return 'The sign-in window was blocked by your browser. '
            'Allow pop-ups for this site and try again.';
      case GoogleSignInFailure.unknown:
        return 'Google sign-in failed. Please try again.';
    }
  }
}

/// Outcome of a Google sign-in attempt.
sealed class GoogleSignInResult {
  const GoogleSignInResult();
}

/// The user is now signed in to Firebase.
class GoogleSignInSuccess extends GoogleSignInResult {
  const GoogleSignInSuccess({required this.isNewUser});

  /// True when this Google account had no Chargi account before.
  final bool isNewUser;
}

/// The user closed the Google window: not an error, nothing to show.
class GoogleSignInCancelled extends GoogleSignInResult {
  const GoogleSignInCancelled();
}

class GoogleSignInFailed extends GoogleSignInResult {
  const GoogleSignInFailed(this.failure);

  final GoogleSignInFailure failure;

  String get message => failure.message;
}
