/// Pure validation helpers for the authentication flows.
///
/// No Flutter or Firebase imports: everything here is unit-testable.
class AuthValidators {
  const AuthValidators._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  /// Returns an error message, or `null` when [value] is a valid email.
  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email address.';
    if (!_emailPattern.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Individual password rules, in display order.
  static const List<PasswordRule> passwordRules = [
    PasswordRule('At least 8 characters', _hasMinLength),
    PasswordRule('One uppercase letter', _hasUppercase),
    PasswordRule('One lowercase letter', _hasLowercase),
    PasswordRule('One number', _hasDigit),
    PasswordRule('One special character', _hasSpecial),
  ];

  static bool _hasMinLength(String v) => v.length >= 8;
  static bool _hasUppercase(String v) => RegExp(r'[A-Z]').hasMatch(v);
  static bool _hasLowercase(String v) => RegExp(r'[a-z]').hasMatch(v);
  static bool _hasDigit(String v) => RegExp(r'[0-9]').hasMatch(v);
  static bool _hasSpecial(String v) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(v);

  /// Returns an error message, or `null` when [value] meets every rule.
  static String? validateNewPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Please enter a new password.';
    for (final rule in passwordRules) {
      if (!rule.isSatisfiedBy(password)) {
        return 'Password must contain: ${rule.label.toLowerCase()}.';
      }
    }
    return null;
  }

  /// Returns an error message, or `null` when [confirmation] matches [password].
  static String? validateConfirmation(String? password, String? confirmation) {
    if (confirmation == null || confirmation.isEmpty) {
      return 'Please confirm your new password.';
    }
    if (password != confirmation) return 'Passwords do not match.';
    return null;
  }

  /// Strength from the number of satisfied rules.
  static PasswordStrength strengthOf(String password) {
    if (password.isEmpty) return PasswordStrength.empty;
    final score =
        passwordRules.where((r) => r.isSatisfiedBy(password)).length;
    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  /// Extracts the Firebase `oobCode` from a pasted reset link, or returns the
  /// trimmed input unchanged when it already looks like a bare code.
  /// Returns `null` when nothing usable is found.
  static String? extractOobCode(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    if (uri != null && uri.queryParameters.containsKey('oobCode')) {
      final code = uri.queryParameters['oobCode'];
      return (code == null || code.isEmpty) ? null : code;
    }

    // A bare code contains no whitespace, slash or query characters.
    if (RegExp(r'^[A-Za-z0-9_\-]{10,}$').hasMatch(text)) return text;
    return null;
  }
}

class PasswordRule {
  const PasswordRule(this.label, this._test);

  final String label;
  final bool Function(String) _test;

  bool isSatisfiedBy(String password) => _test(password);
}

enum PasswordStrength { empty, weak, medium, strong }
