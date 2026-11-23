
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'forgot_password_screen.dart';
import 'SignUpPage.dart';
import 'package:chargi/screens/pages/main_navigation_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color borderColor = Color(0xFFD5DDDA);
  static const Color greyText = Color(0xFF777777);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Sign in using Firebase Authentication.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (credential.user == null) {
        throw Exception('No authenticated user was returned.');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful!'),
          backgroundColor: primaryGreen,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigationPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message = 'Incorrect email or password.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;
        case 'operation-not-allowed':
          message =
              'Email/password login is not enabled in Firebase.';
          break;
        default:
          message = e.message ?? 'Login failed. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      debugPrint('Login error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF888888),
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        size: 19,
        color: const Color(0xFF52625E),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primaryGreen,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 34),

                // Logo
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 27),

                // Title
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Log in to charge, find kiosks and report trash.',
                  style: TextStyle(
                    fontSize: 13,
                    color: greyText,
                  ),
                ),

                const SizedBox(height: 27),

                // Email
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),

                const SizedBox(height: 7),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }

                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(value.trim())) {
                      return 'Please enter a valid email';
                    }

                    return null;
                  },
                  decoration: _inputDecoration(
                    hint: 'you@example.com',
                    icon: Icons.mail_outline,
                  ),
                ),

                const SizedBox(height: 15),

                // Password
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),

                const SizedBox(height: 7),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }

                    if (value.length < 6) {
                      return 'Password must contain at least 6 characters';
                    }

                    return null;
                  },
                  decoration: _inputDecoration(
                    hint: 'Enter your password',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                        color: const Color(0xFF52625E),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(
                        top: 7,
                        bottom: 0,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 17),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          primaryGreen.withValues(alpha: 0.6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Log in',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 19),

                // Divider
                Row(
                  children: [
                    const Expanded(
                      child: Divider(
                        color: borderColor,
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      child: Text(
                        'or continue with',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(
                        color: borderColor,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Google and Apple buttons
                Row(
                  children: [
                    Expanded(
                      child: _socialButton(
                        text: 'Google',
                        icon: 'G',
                        onPressed: () {
                          _showNotImplemented('Google');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _socialButton(
                        text: 'Apple',
                        icon: '●',
                        onPressed: () {
                          _showNotImplemented('Apple');
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 80),

                // Create account
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        color: greyText,
                      ),
                      children: [
                        const TextSpan(text: 'New here? '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SignUpPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Create an account',
                              style: TextStyle(
                                color: primaryGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotImplemented(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$provider sign-in is not configured yet.',
        ),
      ),
    );
  }

  Widget _socialButton({
    required String text,
    required String icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: text == 'Google' ? Colors.red : Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
