import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController =
      TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color borderColor = Color(0xFFD0D8D5);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetLink() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset link sent to your email'),
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
          padding: const EdgeInsets.symmetric(horizontal: 23),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),

            child: Form(
              key: _formKey,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const SizedBox(height: 25),

                  // =========================
                  // BACK BUTTON
                  // =========================

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },

                    padding: EdgeInsets.zero,

                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),

                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 19,
                      color: Color(0xFF17322E),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =========================
                  // KEY ICON
                  // =========================

                  Container(
                    width: 64,
                    height: 64,

                    decoration: BoxDecoration(
                      color: const Color(0xFFDDF1EB),
                      borderRadius: BorderRadius.circular(17),
                    ),

                    child: const Center(
                      child: Icon(
                        Icons.key,
                        size: 31,
                        color: primaryGreen,
                      ),
                    ),
                  ),

                  const SizedBox(height: 27),

                  // =========================
                  // TITLE
                  // =========================

                  const Text(
                    'Forgot your password?',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10201D),
                      height: 1.1,
                    ),
                  ),

                  const SizedBox(height: 9),

                  // =========================
                  // DESCRIPTION
                  // =========================

                  const Text(
                    'Enter the email you signed up with. We will '
                    'send you a link to choose a new password.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF5F6D69),
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
                      color: Color(0xFF101817),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // =========================
                  // EMAIL INPUT
                  // =========================

                  TextFormField(
                    controller: _emailController,

                    keyboardType:
                        TextInputType.emailAddress,

                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
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
                        color: Color(0xFF7D8583),
                        fontSize: 14,
                      ),

                      prefixIcon: const Icon(
                        Icons.mail_outline,
                        size: 19,
                        color: Color(0xFF52625E),
                      ),

                      filled: true,
                      fillColor: Colors.white,

                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),

                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(
                          color: borderColor,
                        ),
                      ),

                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(
                          color: primaryGreen,
                          width: 1.4,
                        ),
                      ),

                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(
                          color: primaryGreen,
                          width: 1.6,
                        ),
                      ),

                      errorBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(
                          color: Colors.red,
                        ),
                      ),

                      focusedErrorBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 21),

                  // =========================
                  // SEND RESET LINK
                  // =========================

                  SizedBox(
                    width: double.infinity,
                    height: 50,

                    child: ElevatedButton(
                      onPressed: _sendResetLink,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(25),
                        ),
                      ),

                      child: const Text(
                        'Send reset link',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =========================
                  // INFORMATION BOX
                  // =========================

                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),

                    child: const Text(
                      'Check your spam folder if you do not see the '
                      'email within a few minutes. The link works for '
                      '[XX] minutes.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF596663),
                      ),
                    ),
                  ),

                  

                  // =========================
                  // BACK TO LOGIN
                  // =========================

                 const SizedBox(height: 80),

Padding(
  padding: const EdgeInsets.only(bottom: 20),

                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF68736F),
                          ),

                          children: [
                            const TextSpan(
                              text: 'Remembered it? ',
                            ),

                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                },

                                child: const Text(
                                  'Back to log in',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primaryGreen,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}