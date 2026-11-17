import 'package:flutter/material.dart';

import 'package:chargi/features/auth/data/google_sign_in_repository.dart';
import 'package:chargi/features/auth/domain/google_sign_in_result.dart';
import 'package:chargi/features/auth/presentation/widgets/auth_ui.dart';

/// Runs the Google sign-in and tells the user what happened.
///
/// Returns true only when the user is signed in. A cancelled attempt is
/// silent; a failure shows a friendly message.
Future<bool> performGoogleSignIn(
  BuildContext context,
  GoogleSignInRepository repository,
) async {
  final result = await repository.signIn();
  if (!context.mounted) return false;

  switch (result) {
    case GoogleSignInSuccess():
      return true;
    case GoogleSignInCancelled():
      return false;
    case GoogleSignInFailed(:final failure):
      showAuthError(context, failure.message);
      return false;
  }
}
