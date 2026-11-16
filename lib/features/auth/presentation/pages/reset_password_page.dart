import 'package:flutter/material.dart';

import 'package:chargi/features/auth/data/auth_repository.dart';
import 'package:chargi/features/auth/domain/auth_validators.dart';
import 'package:chargi/features/auth/domain/password_reset_failure.dart';
import 'package:chargi/features/auth/presentation/pages/password_reset_success_page.dart';
import 'package:chargi/features/auth/presentation/widgets/auth_ui.dart';
import 'package:chargi/features/auth/presentation/widgets/password_strength_indicator.dart';

/// Step 5: verify the action code, then set the new password.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.code,
    required this.repository,
  });

  final String code;
  final AuthRepository repository;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _verifying = true;
  bool _submitting = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  String? _email;
  PasswordResetFailure? _codeFailure;

  @override
  void initState() {
    super.initState();
    _verifyCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    try {
      final email = await widget.repository.verifyResetCode(widget.code);
      if (!mounted) return;
      setState(() {
        _email = email;
        _verifying = false;
      });
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      setState(() {
        _codeFailure = e.failure;
        _verifying = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await widget.repository.confirmPasswordReset(
        code: widget.code,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const PasswordResetSuccessPage(),
        ),
        (route) => route.isFirst,
      );
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      if (e.failure.shouldRequestNewLink) {
        setState(() => _codeFailure = e.failure);
      } else {
        showAuthError(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthUi.backgroundColor,
      appBar: AppBar(
        backgroundColor: AuthUi.backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF17322E)),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_verifying) {
      return const Center(
        child: CircularProgressIndicator(color: AuthUi.primaryGreen),
      );
    }
    if (_codeFailure != null) return _buildCodeError(_codeFailure!);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthBrandHeader(icon: Icons.lock_reset),
            const SizedBox(height: 24),
            const Text(
              'Choose a new password',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AuthUi.titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Account: $_email',
              style: const TextStyle(fontSize: 13, color: AuthUi.bodyColor),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _passwordController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
              validator: AuthValidators.validateNewPassword,
              decoration: AuthUi.inputDecoration(
                hint: 'New password',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hidePassword ? Icons.visibility_off : Icons.visibility,
                    size: 19,
                  ),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PasswordStrengthIndicator(password: _passwordController.text),
            const SizedBox(height: 18),
            TextFormField(
              controller: _confirmController,
              obscureText: _hideConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => AuthValidators.validateConfirmation(
                _passwordController.text,
                v,
              ),
              decoration: AuthUi.inputDecoration(
                hint: 'Confirm new password',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  tooltip: _hideConfirm ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hideConfirm ? Icons.visibility_off : Icons.visibility,
                    size: 19,
                  ),
                  onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Update Password',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeError(PasswordResetFailure failure) {
    return Padding(
      padding: const EdgeInsets.all(23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 44, color: Colors.red),
          const SizedBox(height: 18),
          const Text(
            'Link not valid',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            failure.message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AuthUi.bodyColor,
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Request a new link',
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
    );
  }
}
