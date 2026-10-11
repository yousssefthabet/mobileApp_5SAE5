import 'package:flutter/material.dart';
import 'package:chargi/screens/auth/login_screen.dart';

void main() {
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

      home: const LoginScreen(),
    );
  }
}