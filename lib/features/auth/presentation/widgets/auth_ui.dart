import 'package:flutter/material.dart';

/// Visual constants and small builders shared by the recovery screens, taken
/// from the existing Chargi login / forgot-password look.
class AuthUi {
  const AuthUi._();

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color borderColor = Color(0xFFD0D8D5);
  static const Color titleColor = Color(0xFF10201D);
  static const Color bodyColor = Color(0xFF5F6D69);

  static InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF7D8583), fontSize: 14),
      prefixIcon: Icon(icon, size: 19, color: const Color(0xFF52625E)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: border(borderColor),
      enabledBorder: border(primaryGreen, 1.4),
      focusedBorder: border(primaryGreen, 1.6),
      errorBorder: border(Colors.red),
      focusedErrorBorder: border(Colors.red),
    );
  }
}

/// Chargi brand mark shown at the top of the recovery screens.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFDDF1EB),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, size: 31, color: AuthUi.primaryGreen),
        ),
        const SizedBox(width: 14),
        const Text(
          'Chargi',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AuthUi.primaryGreen,
          ),
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthUi.primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AuthUi.primaryGreen.withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Shows a red error snackbar.
void showAuthError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
}
