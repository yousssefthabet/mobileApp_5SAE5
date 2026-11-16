import 'package:flutter_test/flutter_test.dart';

import 'package:chargi/features/auth/domain/auth_validators.dart';

void main() {
  group('validateEmail', () {
    test('rejects empty and whitespace', () {
      expect(AuthValidators.validateEmail(null), isNotNull);
      expect(AuthValidators.validateEmail(''), isNotNull);
      expect(AuthValidators.validateEmail('   '), isNotNull);
    });

    test('rejects malformed addresses', () {
      for (final bad in ['abc', 'a@b', 'a@b.', '@b.com', 'a b@c.com']) {
        expect(AuthValidators.validateEmail(bad), isNotNull, reason: bad);
      }
    });

    test('accepts valid addresses, trimming spaces', () {
      expect(AuthValidators.validateEmail('user@example.com'), isNull);
      expect(AuthValidators.validateEmail('  user@example.com  '), isNull);
    });
  });

  group('validateNewPassword', () {
    test('rejects each missing criterion', () {
      expect(AuthValidators.validateNewPassword(''), isNotNull);
      expect(AuthValidators.validateNewPassword('Ab1!'), isNotNull); // short
      expect(AuthValidators.validateNewPassword('abcdefg1!'), isNotNull); // upper
      expect(AuthValidators.validateNewPassword('ABCDEFG1!'), isNotNull); // lower
      expect(AuthValidators.validateNewPassword('Abcdefgh!'), isNotNull); // digit
      expect(AuthValidators.validateNewPassword('Abcdefg12'), isNotNull); // special
    });

    test('accepts a password meeting every rule', () {
      expect(AuthValidators.validateNewPassword('Abcdef1!'), isNull);
    });
  });

  group('validateConfirmation', () {
    test('requires a value and a match', () {
      expect(AuthValidators.validateConfirmation('Abcdef1!', ''), isNotNull);
      expect(AuthValidators.validateConfirmation('Abcdef1!', 'Other1!x'),
          isNotNull);
      expect(AuthValidators.validateConfirmation('Abcdef1!', 'Abcdef1!'),
          isNull);
    });
  });

  group('strengthOf', () {
    test('maps the number of satisfied rules', () {
      expect(AuthValidators.strengthOf(''), PasswordStrength.empty);
      expect(AuthValidators.strengthOf('abc'), PasswordStrength.weak);
      expect(AuthValidators.strengthOf('abcdefgh1'), PasswordStrength.medium);
      expect(AuthValidators.strengthOf('Abcdef1!'), PasswordStrength.strong);
    });
  });

  group('extractOobCode', () {
    test('reads the code from a full reset link', () {
      expect(
        AuthValidators.extractOobCode(
          'https://x.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=AbC123_xyz-9&apiKey=k',
        ),
        'AbC123_xyz-9',
      );
    });

    test('accepts a bare code and rejects junk', () {
      expect(AuthValidators.extractOobCode('  AbC123_xyz-9  '), 'AbC123_xyz-9');
      expect(AuthValidators.extractOobCode(''), isNull);
      expect(AuthValidators.extractOobCode('not a code!'), isNull);
      expect(AuthValidators.extractOobCode('https://x.com/?oobCode='), isNull);
    });
  });
}
