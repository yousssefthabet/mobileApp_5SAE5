
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chargi/firebase_options.dart';
import 'package:chargi/screens/auth/login_screen.dart';
import 'package:chargi/screens/pages/main_navigation_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
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

