
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chargi/firebase_options.dart';
import 'package:chargi/screens/auth/login_screen.dart';
import 'package:chargi/screens/pages/main_navigation_page.dart';
import 'package:chargi/services/station_availability_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  _connectToEmulatorsIfRequested();

  // Automatically check and release expired reservations on app startup
  StationAvailabilityService.instance.releaseExpiredReservations();

  runApp(const MyApp());
}

/// Local testing without deploying anything:
///
///   flutter run --dart-define=USE_EMULATOR=true
///
/// Cloud Functions and Firestore then use the Firebase emulators (see
/// docs/FEATURES.md). Sign-in still uses the real Firebase project. On a
/// physical phone, also pass --dart-define=EMULATOR_HOST=YOUR_PC_IP.
/// Never active unless the flag is set, and ignored in release builds.
const bool _useEmulator = bool.fromEnvironment('USE_EMULATOR');
const String _emulatorHost = String.fromEnvironment('EMULATOR_HOST');

void _connectToEmulatorsIfRequested() {
  if (!_useEmulator || !kDebugMode) return;

  final host = _emulatorHost.isNotEmpty
      ? _emulatorHost
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2' // the Android emulator's alias for the PC
          : 'localhost');

  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8185);
  debugPrint('Using Firebase emulators at $host (functions 5001, firestore 8185)');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chargi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF086B5B),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Listens to Firebase auth state and routes to the correct screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still determining auth state — show a branded splash.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F9F8),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF086B5B),
              ),
            ),
          );
        }

        // User is signed in → main app.
        if (snapshot.hasData) {
          return const MainNavigationPage();
        }

        // Not signed in → login.
        return const LoginScreen();
      },
    );
  }
}

