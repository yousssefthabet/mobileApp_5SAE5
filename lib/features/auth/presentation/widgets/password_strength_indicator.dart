import 'package:flutter/material.dart';

import 'package:chargi/features/auth/domain/auth_validators.dart';

/// Strength bar plus a checklist of the password rules.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = AuthValidators.strengthOf(password);
    final (label, color, filled) = switch (strength) {
      PasswordStrength.empty => ('', Colors.grey, 0),
      PasswordStrength.weak => ('Weak', Colors.red, 1),
      PasswordStrength.medium => ('Medium', Colors.orange, 2),
      PasswordStrength.strong => ('Strong', Colors.green, 3),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: label.isEmpty ? 'Password strength' : 'Password strength: $label',
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i < filled ? color : const Color(0xFFDCE3E0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final rule in AuthValidators.passwordRules)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Icon(
                  rule.isSatisfiedBy(password)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 15,
                  color: rule.isSatisfiedBy(password)
                      ? Colors.green
                      : const Color(0xFF8A9692),
                ),
                const SizedBox(width: 7),
                Text(
                  rule.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF596663),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
