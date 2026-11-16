import 'package:flutter/material.dart';

import 'package:chargi/features/auth/presentation/widgets/auth_ui.dart';

/// Final step: the password has been updated.
class PasswordResetSuccessPage extends StatelessWidget {
  const PasswordResetSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthUi.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 23),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Password updated',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: AuthUi.titleColor,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Your password has been successfully updated.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: AuthUi.bodyColor,
                ),
              ),
              const SizedBox(height: 28),
              AuthPrimaryButton(
                label: 'Back to Login',
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
