import 'package:flutter/material.dart';
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

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  // Main colors
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

  void _login() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationPage(),
        ),
      );
    }
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

                // =========================
                // LOGO
                // =========================

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

                // =========================
                // TITLE
                // =========================

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

                // =========================
                // EMAIL LABEL
                // =========================

                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),

                const SizedBox(height: 7),

                // =========================
                // EMAIL INPUT
                // =========================

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,

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

                  decoration: InputDecoration(
                    hintText: 'you@example.com',

                    hintStyle: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 13,
                    ),

                    prefixIcon: const Icon(
                      Icons.mail_outline,
                      size: 19,
                      color: Color(0xFF52625E),
                    ),

                    filled: true,
                    fillColor: Colors.white,

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: borderColor,
                      ),
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: borderColor,
                      ),
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
                      borderSide: const BorderSide(
                        color: Colors.red,
                      ),
                    ),

                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // =========================
                // PASSWORD LABEL
                // =========================

                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),

                const SizedBox(height: 7),

                // =========================
                // PASSWORD INPUT
                // =========================

                TextFormField(
                  controller: _passwordController,

                  obscureText: _obscurePassword,

                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }

                    if (value.length < 6) {
                      return 'Password must contain at least 6 characters';
                    }

                    return null;
                  },

                  decoration: InputDecoration(
                    hintText: 'Enter your password',

                    hintStyle: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 13,
                    ),

                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      size: 19,
                      color: Color(0xFF52625E),
                    ),

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

                    filled: true,
                    fillColor: Colors.white,

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: borderColor,
                      ),
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: borderColor,
                      ),
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
                      borderSide: const BorderSide(
                        color: Colors.red,
                      ),
                    ),

                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),

                // =========================
                // FORGOT PASSWORD
                // =========================

                Align(
                  alignment: Alignment.centerRight,

                  child: TextButton(
                   onPressed: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
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
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

                // =========================
                // LOGIN BUTTON
                // =========================

                SizedBox(
                  width: double.infinity,
                  height: 46,

                  child: ElevatedButton(
                    onPressed: _login,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),

                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 19),

                // =========================
                // DIVIDER
                // =========================

                Row(
                  children: [
                    const Expanded(
                      child: Divider(
                        color: Color(0xFFD5DDDA),
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
                        color: Color(0xFFD5DDDA),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // =========================
                // GOOGLE + APPLE
                // =========================

                Row(
                  children: [

                    Expanded(
                      child: _socialButton(
                        text: 'Google',
                        icon: 'G',
                        onPressed: () {
                          // TODO: Google login
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _socialButton(
                        text: 'Apple',
                        icon: '●',
                        onPressed: () {
                          // TODO: Apple login
                        },
                      ),
                    ),
                  ],
                ),

                // =========================
                // BOTTOM SIGN UP
                // =========================

                const SizedBox(height: 80),

                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        color: greyText,
                      ),

                      children: [
                        const TextSpan(
                          text: 'New here? ',
                        ),

                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {
                               Navigator.push(
                                context,
                                 MaterialPageRoute(builder: (context_) => const SignUpPage()),
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

  // =========================
  // SOCIAL BUTTON
  // =========================

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

          side: const BorderSide(
            color: borderColor,
          ),

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
                color: text == 'Google'
                    ? Colors.red
                    : Colors.black,
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