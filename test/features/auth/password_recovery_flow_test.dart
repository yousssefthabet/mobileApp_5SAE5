import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/auth/data/auth_repository.dart';
import 'package:chargi/features/auth/presentation/pages/check_email_page.dart';
import 'package:chargi/features/auth/presentation/pages/reset_password_page.dart';
import 'package:chargi/screens/auth/forgot_password_screen.dart';

import 'auth_repository_test.dart' show FakeAuthService;

Widget _app(Widget home) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => home),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(_app(page));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeAuthService service;
  late AuthRepository repo;

  setUp(() {
    service = FakeAuthService();
    repo = AuthRepository(service: service, continueUrl: '');
  });

  group('ForgotPasswordScreen', () {
    testWidgets('shows an error for an empty email and sends nothing',
        (tester) async {
      await _open(tester, ForgotPasswordScreen(repository: repo));
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(service.sendCalls, 0);
    });

    testWidgets('shows an error for an invalid email', (tester) async {
      await _open(tester, ForgotPasswordScreen(repository: repo));
      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(service.sendCalls, 0);
    });

    testWidgets('sends the link and shows the confirmation page',
        (tester) async {
      await _open(tester, ForgotPasswordScreen(repository: repo));
      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();
      expect(service.sendCalls, 1);
      expect(find.text('Check your email'), findsOneWidget);
    });

    testWidgets('shows a friendly message on network error', (tester) async {
      service.errorCode = 'network-request-failed';
      await _open(tester, ForgotPasswordScreen(repository: repo));
      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No internet connection'), findsOneWidget);
      expect(find.text('Check your email'), findsNothing);
    });
  });

  group('CheckEmailPage', () {
    testWidgets('limits resending with a countdown, then allows it',
        (tester) async {
      await _open(
        tester,
        CheckEmailPage(
          email: 'user@example.com',
          repository: repo,
          resendDelaySeconds: 3,
        ),
      );
      expect(find.text('Resend Email (3s)'), findsOneWidget);

      await tester.tap(find.textContaining('Resend Email'));
      await tester.pump();
      expect(service.sendCalls, 0); // blocked while counting down

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Resend Email'), findsOneWidget);

      await tester.tap(find.text('Resend Email'));
      await tester.pump();
      await tester.pump();
      expect(service.sendCalls, 1);
      // Countdown restarted.
      expect(find.text('Resend Email (3s)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3)); // let the timer finish
    });
  });

  group('ResetPasswordPage', () {
    testWidgets('shows the expired-link message', (tester) async {
      service.errorCode = 'expired-action-code';
      await _open(tester, ResetPasswordPage(code: 'abc', repository: repo));
      expect(find.text('Link not valid'), findsOneWidget);
      expect(find.textContaining('expired'), findsOneWidget);
    });

    testWidgets('shows the invalid / already used message', (tester) async {
      service.errorCode = 'invalid-action-code';
      await _open(tester, ResetPasswordPage(code: 'abc', repository: repo));
      expect(find.textContaining('invalid or has already been used'),
          findsOneWidget);
    });

    testWidgets('rejects a weak password and a wrong confirmation',
        (tester) async {
      await _open(tester, ResetPasswordPage(code: 'abc', repository: repo));
      final fields = find.byType(TextFormField);

      await tester.enterText(fields.at(0), 'weak');
      await tester.enterText(fields.at(1), 'other');
      await tester.ensureVisible(find.text('Update Password'));
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      expect(find.textContaining('Password must contain'), findsOneWidget);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(service.lastConfirmedCode, isNull);

      await tester.enterText(fields.at(0), 'Abcdef1!');
      await tester.enterText(fields.at(1), 'Different1!');
      await tester.ensureVisible(find.text('Update Password'));
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(service.lastConfirmedCode, isNull);
    });

    testWidgets('updates the password and shows the success page',
        (tester) async {
      await _open(tester, ResetPasswordPage(code: 'abc', repository: repo));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Abcdef1!');
      await tester.enterText(fields.at(1), 'Abcdef1!');
      await tester.ensureVisible(find.text('Update Password'));
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();
      expect(service.lastConfirmedPassword, 'Abcdef1!');
      expect(find.text('Your password has been successfully updated.'),
          findsOneWidget);
    });
  });
}
