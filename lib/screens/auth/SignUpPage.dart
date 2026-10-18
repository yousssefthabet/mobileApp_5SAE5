
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargi/screens/pages/main_navigation_page.dart';

// Smart City colors
const kPrimary = Color(0xFF0A5F4E);
const kInk = Color(0xFF10231D);
const kMuted = Color(0xFF51635C);
const kBorder = Color(0xFFD5DDD9);
const kBackground = Color(0xFFF6F8F7);

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _agreed = false;
  bool _termsError = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();

    setState(() {
      _termsError = !_agreed;
    });

    if (!valid || !_agreed) return;

    setState(() => _loading = true);

    try {
      // Create the account using Firebase Authentication.
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      // Save the full name in the Firebase user profile.
      await credential.user?.updateDisplayName(
        _nameCtrl.text.trim(),
      );

      // Save user profile to Firestore.
      if (credential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to the main app, clearing the auth stack.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationPage(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {

      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Please choose a stronger password.';
          break;
        case 'operation-not-allowed':
          message =
              'Email/password authentication is not enabled in Firebase.';
          break;
        case 'network-request-failed':
          message =
              'Network error. Check your internet connection.';
          break;
        case 'too-many-requests':
          message =
              'Too many attempts. Please try again later.';
          break;
        default:
          message =
              e.message ?? 'Could not create your account.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: kInk,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create your account',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join in a minute and start reporting, charging and exploring.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: kMuted,
                  ),
                ),
                const SizedBox(height: 24),

                // Full name
                _LabeledField(
                  label: 'Full name',
                  hint: 'Your name',
                  icon: Icons.person_outline,
                  controller: _nameCtrl,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Please enter your name'
                          : null,
                ),
                const SizedBox(height: 16),

                // Email
                _LabeledField(
                  label: 'Email',
                  hint: 'you@example.com',
                  icon: Icons.mail_outline,
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    final ok = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(value);

                    return ok
                        ? null
                        : 'Enter a valid email address';
                  },
                ),
                const SizedBox(height: 16),

                // Password
                _LabeledField(
                  label: 'Password',
                  hint: 'At least 8 characters',
                  icon: Icons.lock_outline,
                  controller: _passCtrl,
                  obscure: _hidePass,
                  textInputAction: TextInputAction.next,
                  onToggleObscure: () {
                    setState(() => _hidePass = !_hidePass);
                  },
                  validator: (v) =>
                      (v == null || v.length < 8)
                          ? 'Use at least 8 characters'
                          : null,
                ),
                const SizedBox(height: 16),

                // Confirm password
                _LabeledField(
                  label: 'Confirm password',
                  hint: 'Re-enter your password',
                  icon: Icons.lock_outline,
                  controller: _confirmCtrl,
                  obscure: _hideConfirm,
                  textInputAction: TextInputAction.done,
                  onToggleObscure: () {
                    setState(
                      () => _hideConfirm = !_hideConfirm,
                    );
                  },
                  validator: (v) =>
                      v != _passCtrl.text
                          ? 'Passwords do not match'
                          : null,
                ),
                const SizedBox(height: 16),

                // Terms and privacy policy
                _TermsRow(
                  value: _agreed,
                  hasError: _termsError,
                  onChanged: (v) {
                    setState(() {
                      _agreed = v ?? false;
                      _termsError = false;
                    });
                  },
                ),
                const SizedBox(height: 22),

                // Create account button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: const StadiumBorder(),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Login link
                Center(
                  child: Wrap(
                    crossAxisAlignment:
                        WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 15,
                          color: kMuted,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.maybePop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: kPrimary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label above a rounded text field.
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.validator,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  OutlineInputBorder _border(
    Color color, [
    double width = 2,
  ]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: color,
        width: width,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: const TextStyle(
            fontSize: 16,
            color: kInk,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kMuted),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18),
            prefixIcon: Icon(icon, color: kMuted),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    tooltip: obscure
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: kMuted,
                    ),
                    onPressed: onToggleObscure,
                  ),
            enabledBorder: _border(kBorder),
            focusedBorder: _border(kPrimary),
            errorBorder: _border(
              const Color(0xFF9A1B1B),
            ),
            focusedErrorBorder: _border(
              const Color(0xFF9A1B1B),
            ),
          ),
        ),
      ],
    );
  }
}

/// Terms checkbox with validation.
class _TermsRow extends StatelessWidget {
  const _TermsRow({
    required this.value,
    required this.hasError,
    required this.onChanged,
  });

  final bool value;
  final bool hasError;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: kPrimary,
            ),
            const Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: kMuted,
                  ),
                  children: [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kPrimary,
                      ),
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hasError)
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'Please accept the terms to continue',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9A1B1B),
              ),
            ),
          ),
      ],
    );
  }
}
