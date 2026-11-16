import 'package:flutter/material.dart';

import 'package:chargi/features/auth/data/auth_repository.dart';
import 'package:chargi/features/auth/domain/auth_validators.dart';
import 'package:chargi/features/auth/domain/password_reset_failure.dart';
import 'package:chargi/features/auth/presentation/pages/check_email_page.dart';
import 'package:chargi/features/auth/presentation/widgets/auth_ui.dart';

/// Step 1 of password recovery: ask for the account email and send the link.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.repository});

  /// Injectable for tests; defaults to the Firebase-backed repository.
  final AuthRepository? repository;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final AuthRepository _repository =
      widget.repository ?? AuthRepository();

  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_loading) return; // prevent double submission
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final email = _emailController.text.trim();
    try {
      await _repository.sendPasswordResetEmail(email);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              CheckEmailPage(email: email, repository: _repository),
        ),
      );
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthUi.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 23),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 25),
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 19,
                    color: Color(0xFF17322E),
                  ),
                ),
                const SizedBox(height: 20),
                const AuthBrandHeader(icon: Icons.key),
                const SizedBox(height: 27),
                const Text(
                  'Reset Your Password',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: AuthUi.titleColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Enter the email you signed up with. We will send you a '
                  'link to choose a new password.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AuthUi.bodyColor,
                  ),
                ),
                const SizedBox(height: 27),
                const Text(
                  'Email',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _sendResetLink(),
                  validator: AuthValidators.validateEmail,
                  decoration: AuthUi.inputDecoration(
                    hint: 'you@example.com',
                    icon: Icons.mail_outline,
                  ),
                ),
                const SizedBox(height: 21),
                AuthPrimaryButton(
                  label: 'Send Reset Link',
                  loading: _loading,
                  onPressed: _sendResetLink,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Return to Login',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AuthUi.primaryGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
