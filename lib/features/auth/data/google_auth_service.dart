import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

/// Web client ID of the Firebase project `chargi-b044b` (Authentication >
/// Sign-in method > Google > "Web SDK configuration"). It identifies the
/// project to Google and is NOT a secret (it is shipped inside every app).
///
/// To use another Firebase project, override it at build time:
///
///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
const String kGoogleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '52480821772-g4e0vkepis0o0dfsepr2doa4i2fiu1hs.apps.googleusercontent.com',
);

/// The Firebase user obtained through Google.
class GoogleAuthUser {
  const GoogleAuthUser({
    required this.uid,
    required this.isNewUser,
    this.email,
    this.displayName,
  });

  final String uid;
  final bool isNewUser;
  final String? email;
  final String? displayName;
}

/// Thin abstraction over the Google + Firebase calls, so the repository can
/// be tested without Google or Firebase.
abstract class GoogleAuthService {
  /// Whether this platform can offer Google sign-in at all.
  bool get isSupported;

  /// Whether the app has what it needs to attempt it (on Android: the Web
  /// client ID).
  bool get isConfigured;

  /// Signs in and returns the Firebase user.
  ///
  /// Throws `GoogleSignInException` (google_sign_in) or `FirebaseAuthException`.
  Future<GoogleAuthUser> signIn();
}

/// Production implementation.
///
/// - Web: Firebase's own popup (no extra client ID needed).
/// - Android: google_sign_in -> ID token -> Firebase credential.
class FirebaseGoogleAuthService implements GoogleAuthService {
  FirebaseGoogleAuthService({
    this._auth,
    this._serverClientId = kGoogleServerClientId,
  });

  final FirebaseAuth? _auth;
  final String _serverClientId;
  bool _initialized = false;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  @override
  bool get isSupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get isConfigured => kIsWeb || _serverClientId.isNotEmpty;

  @override
  Future<GoogleAuthUser> signIn() async {
    final UserCredential credential;

    if (kIsWeb) {
      credential = await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
    } else {
      if (!_initialized) {
        await gsi.GoogleSignIn.instance.initialize(
          serverClientId: _serverClientId,
        );
        _initialized = true;
      }
      final account = await gsi.GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-id-token',
          message: 'Google did not return an ID token.',
        );
      }
      credential = await _firebaseAuth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    }

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'No user returned after sign-in.',
      );
    }
    return GoogleAuthUser(
      uid: user.uid,
      isNewUser: credential.additionalUserInfo?.isNewUser ?? false,
      email: user.email,
      displayName: user.displayName,
    );
  }
}
