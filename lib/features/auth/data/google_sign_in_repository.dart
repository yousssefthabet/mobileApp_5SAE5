import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

import 'package:chargi/features/auth/data/google_auth_service.dart';
import 'package:chargi/features/auth/domain/google_sign_in_result.dart';
import 'package:chargi/features/users/data/user_profile_repository.dart';

/// "Continue with Google": signs in, then makes sure the user has a profile.
///
/// Every failure is translated into a [GoogleSignInResult]; this method never
/// throws and never exposes raw error text.
class GoogleSignInRepository {
  GoogleSignInRepository({
    GoogleAuthService? service,
    UserProfileRepository? profiles,
    this.profileTimeout = const Duration(seconds: 10),
  })  : _service = service ?? FirebaseGoogleAuthService(),
        _profiles = profiles ?? UserProfileRepository();

  final GoogleAuthService _service;
  final UserProfileRepository _profiles;

  /// How long to wait for the profile to be created before moving on. The
  /// user is already signed in; a slow or unreachable database must not keep
  /// the sign-in screen spinning.
  final Duration profileTimeout;

  /// Screens hide the Google button on platforms that cannot use it.
  bool get isSupported => _service.isSupported;

  Future<GoogleSignInResult> signIn() async {
    if (!_service.isSupported) {
      return const GoogleSignInFailed(GoogleSignInFailure.unsupported);
    }
    if (!_service.isConfigured) {
      return const GoogleSignInFailed(GoogleSignInFailure.notConfigured);
    }

    final GoogleAuthUser user;
    try {
      user = await _service.signIn();
    } on gsi.GoogleSignInException catch (e) {
      return _fromGoogle(e);
    } on FirebaseAuthException catch (e) {
      return _fromFirebase(e);
    } catch (_) {
      return const GoogleSignInFailed(GoogleSignInFailure.unknown);
    }

    // The user IS signed in now. A profile problem must not undo that: the
    // profile is created again on the next sign-in, and a missing profile is
    // treated as a plain "user" everywhere.
    try {
      await _profiles
          .ensureProfile(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
          )
          .timeout(profileTimeout);
    } catch (e) {
      debugPrint('Could not create the profile after Google sign-in: $e');
    }

    return GoogleSignInSuccess(isNewUser: user.isNewUser);
  }

  static GoogleSignInResult _fromGoogle(gsi.GoogleSignInException e) {
    switch (e.code) {
      case gsi.GoogleSignInExceptionCode.canceled:
        return const GoogleSignInCancelled();
      case gsi.GoogleSignInExceptionCode.clientConfigurationError:
      case gsi.GoogleSignInExceptionCode.providerConfigurationError:
        return const GoogleSignInFailed(GoogleSignInFailure.notConfigured);
      default:
        return const GoogleSignInFailed(GoogleSignInFailure.unknown);
    }
  }

  static GoogleSignInResult _fromFirebase(FirebaseAuthException e) {
    switch (e.code) {
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-canceled':
        return const GoogleSignInCancelled();
      case 'account-exists-with-different-credential':
        return const GoogleSignInFailed(
          GoogleSignInFailure.accountExistsWithPassword,
        );
      case 'network-request-failed':
        return const GoogleSignInFailed(GoogleSignInFailure.network);
      case 'user-disabled':
        return const GoogleSignInFailed(GoogleSignInFailure.userDisabled);
      case 'too-many-requests':
        return const GoogleSignInFailed(GoogleSignInFailure.tooManyRequests);
      case 'popup-blocked':
        return const GoogleSignInFailed(GoogleSignInFailure.popupBlocked);
      case 'operation-not-allowed':
        // The Google provider is not enabled in the Firebase console yet.
        return const GoogleSignInFailed(GoogleSignInFailure.notConfigured);
      default:
        return const GoogleSignInFailed(GoogleSignInFailure.unknown);
    }
  }
}
