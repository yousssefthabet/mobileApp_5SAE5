import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chargi/features/auth/data/auth_repository.dart';
import 'package:chargi/features/auth/domain/auth_validators.dart';
import 'package:chargi/features/auth/domain/password_reset_failure.dart';
import 'package:chargi/features/auth/presentation/pages/reset_password_page.dart';
import 'package:chargi/features/auth/presentation/widgets/auth_ui.dart';

/// Step 4: confirmation screen with resend countdown.
class CheckEmailPage extends StatefulWidget {
  const CheckEmailPage({
    super.key,
    required this.email,
    required this.repository,
    this.resendDelaySeconds = 60,
  });

  final String email;
  final AuthRepository repository;
  final int resendDelaySeconds;

  @override
  State<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends State<CheckEmailPage> {
  Timer? _timer;
  late int _secondsLeft = widget.resendDelaySeconds;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = widget.resendDelaySeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    if (_resending || _secondsLeft > 0) return;
    setState(() => _resending = true);
    try {
      await widget.repository.sendPasswordResetEmail(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email sent again.')),
      );
      _startCountdown();
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      showAuthError(context, e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter reset code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Paste the link or the code from the email',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || !mounted) return;

    final code = AuthValidators.extractOobCode(input);
    if (code == null) {
      showAuthError(
        context,
        PasswordResetFailure.invalidCode.message,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ResetPasswordPage(code: code, repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0 && !_resending;
    return Scaffold(
      backgroundColor: AuthUi.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthBrandHeader(icon: Icons.mark_email_read_outlined),
              const SizedBox(height: 27),
              const Text(
                'Check your email',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: AuthUi.titleColor,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'If an account is associated with ${widget.email}, you will '
                'receive a link to reset your password.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: AuthUi.bodyColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your spam folder if you do not see it within a few '
                'minutes.',
                style: TextStyle(fontSize: 12, color: AuthUi.bodyColor),
              ),
              const SizedBox(height: 28),
              AuthPrimaryButton(
                label: _secondsLeft > 0
                    ? 'Resend Email (${_secondsLeft}s)'
                    : 'Resend Email',
                loading: _resending,
                onPressed: canResend ? _resend : null,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  // The email form is still below this page, with the
                  // previous address filled in.
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Use a different email'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _enterCode,
                  child: const Text('I have a reset code'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AuthUi.primaryGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
