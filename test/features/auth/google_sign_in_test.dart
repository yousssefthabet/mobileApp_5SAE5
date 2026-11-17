import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

import 'package:chargi/features/auth/data/google_auth_service.dart';
import 'package:chargi/features/auth/data/google_sign_in_repository.dart';
import 'package:chargi/features/auth/domain/google_sign_in_result.dart';
import 'package:chargi/features/users/data/user_profile_repository.dart';
import 'package:chargi/screens/auth/SignUpPage.dart';
import 'package:chargi/screens/auth/login_screen.dart';

// ---------------------------------------------------------------- fakes

class FakeGoogleAuthService implements GoogleAuthService {
  FakeGoogleAuthService({
    this.supported = true,
    this.configured = true,
    this.user = const GoogleAuthUser(
      uid: 'u1',
      isNewUser: true,
      email: 'ada@example.com',
      displayName: 'Ada Lovelace',
    ),
  });

  bool supported;
  bool configured;
  GoogleAuthUser user;
  Object? error; // thrown by signIn when set
  int calls = 0;

  @override
  bool get isSupported => supported;

  @override
  bool get isConfigured => configured;

  @override
  Future<GoogleAuthUser> signIn() async {
    calls++;
    if (error != null) throw error!;
    return user;
  }
}

class FakeProfileStore implements ProfileStore {
  final Map<String, Map<String, Object?>> docs = {};
  int writes = 0;
  Object? error;

  @override
  Future<bool> createIfAbsent(String uid, Map<String, Object?> data) async {
    if (error != null) throw error!;
    if (docs.containsKey(uid)) return false;
    docs[uid] = data;
    writes++;
    return true;
  }
}

/// A database that never answers (emulator not running, no network...).
class HangingProfileStore implements ProfileStore {
  int calls = 0;

  @override
  Future<bool> createIfAbsent(String uid, Map<String, Object?> data) {
    calls++;
    return Completer<bool>().future; // never completes
  }
}

GoogleSignInRepository repoWith(FakeGoogleAuthService s, FakeProfileStore p) =>
    GoogleSignInRepository(service: s, profiles: UserProfileRepository(store: p));

void main() {
  group('GoogleSignInRepository', () {
    late FakeGoogleAuthService service;
    late FakeProfileStore store;

    setUp(() {
      service = FakeGoogleAuthService();
      store = FakeProfileStore();
    });

    test('success: signs in and creates the profile once, as a plain user', () async {
      final result = await repoWith(service, store).signIn();

      expect(result, isA<GoogleSignInSuccess>());
      expect((result as GoogleSignInSuccess).isNewUser, isTrue);
      final profile = store.docs['u1']!;
      expect(profile['role'], 'user');
      expect(profile['name'], 'Ada Lovelace');
      expect(profile['email'], 'ada@example.com');
      expect(profile['rewardPoints'], 0);
    });

    test('a returning user keeps their profile (and role): nothing is overwritten', () async {
      store.docs['u1'] = {'name': 'Old', 'role': 'worker'};
      service.user = const GoogleAuthUser(uid: 'u1', isNewUser: false, email: 'x@y.z');

      final result = await repoWith(service, store).signIn();

      expect(result, isA<GoogleSignInSuccess>());
      expect(store.writes, 0);
      expect(store.docs['u1']!['role'], 'worker');
      expect(store.docs['u1']!['name'], 'Old');
    });

    test('signing in twice creates the profile only once', () async {
      final repo = repoWith(service, store);
      await repo.signIn();
      await repo.signIn();
      expect(store.writes, 1);
    });

    test('a profile error does not undo the sign-in', () async {
      store.error = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
      final result = await repoWith(service, store).signIn();
      expect(result, isA<GoogleSignInSuccess>());
    });

    test('an unreachable database does not keep the sign-in waiting forever', () async {
      final hanging = HangingProfileStore();
      final repo = GoogleSignInRepository(
        service: service,
        profiles: UserProfileRepository(store: hanging),
        profileTimeout: const Duration(milliseconds: 50),
      );

      final result = await repo.signIn().timeout(const Duration(seconds: 5));

      expect(result, isA<GoogleSignInSuccess>()); // the user IS signed in
      expect(hanging.calls, 1);
    });

    test('unsupported platform and missing configuration never call Google', () async {
      service.supported = false;
      var r = await repoWith(service, store).signIn();
      expect((r as GoogleSignInFailed).failure, GoogleSignInFailure.unsupported);

      service
        ..supported = true
        ..configured = false;
      r = await repoWith(service, store).signIn();
      expect((r as GoogleSignInFailed).failure, GoogleSignInFailure.notConfigured);
      expect(service.calls, 0);
    });

    test('the user closing the Google window is a silent cancel, not an error', () async {
      service.error = const gsi.GoogleSignInException(code: gsi.GoogleSignInExceptionCode.canceled);
      expect(await repoWith(service, store).signIn(), isA<GoogleSignInCancelled>());

      service.error = FirebaseAuthException(code: 'popup-closed-by-user');
      expect(await repoWith(service, store).signIn(), isA<GoogleSignInCancelled>());
      expect(store.writes, 0);
    });

    test('Google configuration errors mean "not set up yet"', () async {
      for (final code in [
        gsi.GoogleSignInExceptionCode.clientConfigurationError,
        gsi.GoogleSignInExceptionCode.providerConfigurationError,
      ]) {
        service.error = gsi.GoogleSignInException(code: code);
        final r = await repoWith(service, store).signIn();
        expect((r as GoogleSignInFailed).failure, GoogleSignInFailure.notConfigured);
      }
    });

    test('Firebase errors are translated to safe failures', () async {
      final expected = {
        'account-exists-with-different-credential': GoogleSignInFailure.accountExistsWithPassword,
        'network-request-failed': GoogleSignInFailure.network,
        'user-disabled': GoogleSignInFailure.userDisabled,
        'too-many-requests': GoogleSignInFailure.tooManyRequests,
        'popup-blocked': GoogleSignInFailure.popupBlocked,
        'operation-not-allowed': GoogleSignInFailure.notConfigured, // provider off in the console
        'something-new': GoogleSignInFailure.unknown,
      };
      for (final e in expected.entries) {
        service.error = FirebaseAuthException(code: e.key, message: 'RAW SECRET TEXT');
        final r = await repoWith(service, store).signIn() as GoogleSignInFailed;
        expect(r.failure, e.value, reason: e.key);
        expect(r.message, isNot(contains('RAW')));
      }
    });

    test('any other error becomes a generic failure, never a crash', () async {
      service.error = StateError('boom');
      final r = await repoWith(service, store).signIn();
      expect((r as GoogleSignInFailed).failure, GoogleSignInFailure.unknown);
    });

    test('every failure has a readable message', () {
      for (final f in GoogleSignInFailure.values) {
        expect(f.message.length, greaterThan(10));
        expect(f.message.toLowerCase(), isNot(contains('exception')));
      }
    });
  });

  group('UserProfileRepository', () {
    test('new profile data: role is always "user", name falls back sensibly', () {
      final named = UserProfileRepository.newProfileData(email: 'a@b.co', displayName: '  Ada ');
      expect(named['name'], 'Ada');
      expect(named['role'], 'user');
      expect(named.containsKey('createdAt'), isTrue);
      expect(named['createdAt'], isA<FieldValue>());

      expect(UserProfileRepository.newProfileData(email: 'ada@b.co')['name'], 'ada');
      expect(UserProfileRepository.newProfileData(email: null, displayName: '')['name'], 'Chargi user');
    });

    test('ensureProfile reports whether it created the profile', () async {
      final store = FakeProfileStore();
      final repo = UserProfileRepository(store: store);
      expect(await repo.ensureProfile(uid: 'a', email: 'a@b.co'), isTrue);
      expect(await repo.ensureProfile(uid: 'a', email: 'a@b.co'), isFalse);
    });
  });

  group('FirebaseGoogleAuthService', () {
    test('on mobile it needs the Web client ID; without it, it is "not configured"', () {
      // flutter test runs as Android by default: supported, but it needs the ID.
      final s = FirebaseGoogleAuthService(serverClientId: '');
      expect(s.isSupported, isTrue);
      expect(s.isConfigured, isFalse);
      expect(FirebaseGoogleAuthService(serverClientId: 'abc.apps.googleusercontent.com').isConfigured, isTrue);
    });
  });

  group('buttons', () {
    Future<void> pump(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
    }

    for (final screen in ['login', 'signup']) {
      Widget build(FakeGoogleAuthService s, FakeProfileStore p, VoidCallback onDone) => screen == 'login'
          ? LoginScreen(googleSignIn: repoWith(s, p), onGoogleSignedIn: onDone)
          : SignUpPage(googleSignIn: repoWith(s, p), onGoogleSignedIn: onDone);
      final finder = screen == 'login' ? find.text('Google') : find.text('Continue with Google');

      testWidgets('$screen: the Google button signs in, creates the profile, then opens the app', (tester) async {
        final service = FakeGoogleAuthService();
        final store = FakeProfileStore();
        var done = 0;
        await pump(tester, build(service, store, () => done++));

        expect(finder, findsOneWidget);
        await tester.tap(finder);
        await tester.pumpAndSettle();

        expect(service.calls, 1);
        expect(store.docs['u1']!['role'], 'user');
        expect(done, 1);
      });

      testWidgets('$screen: a cancelled sign-in shows nothing and does not continue', (tester) async {
        final service = FakeGoogleAuthService()
          ..error = const gsi.GoogleSignInException(code: gsi.GoogleSignInExceptionCode.canceled);
        var done = 0;
        await pump(tester, build(service, FakeProfileStore(), () => done++));

        await tester.tap(finder);
        await tester.pumpAndSettle();

        expect(done, 0);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('$screen: a failure shows a friendly message, never the raw error', (tester) async {
        final service = FakeGoogleAuthService()
          ..error = FirebaseAuthException(code: 'account-exists-with-different-credential', message: 'RAW');
        var done = 0;
        await pump(tester, build(service, FakeProfileStore(), () => done++));

        await tester.tap(finder);
        await tester.pumpAndSettle();

        expect(done, 0);
        expect(find.textContaining('sign in with your email and password'), findsOneWidget);
        expect(find.textContaining('RAW'), findsNothing);
      });

      testWidgets('$screen: not configured yet gives a clear message and never calls Google', (tester) async {
        final service = FakeGoogleAuthService(configured: false);
        await pump(tester, build(service, FakeProfileStore(), () {}));

        await tester.tap(finder);
        await tester.pumpAndSettle();

        expect(find.textContaining('not set up'), findsOneWidget);
        expect(service.calls, 0);
      });

      testWidgets('$screen: the Google button is hidden where Google sign-in is unavailable', (tester) async {
        await pump(tester, build(FakeGoogleAuthService(supported: false), FakeProfileStore(), () {}));
        expect(finder, findsNothing);
      });
    }
  });
}
