import 'package:flutter_test/flutter_test.dart';

/// Tests the referral code generation logic extracted from ReferralScreen.
void main() {
  /// Mirrors the _referralCode getter from ReferralScreen.
  String generateReferralCode(String? userId) {
    final id = userId ?? 'USER';
    final suffix = id.hashCode.abs().toString().padLeft(5, '0').substring(0, 5);
    return 'HOUSE-$suffix';
  }

  group('Referral code generation', () {
    test('referral code starts with "HOUSE-"', () {
      final code = generateReferralCode('user123');
      expect(code.startsWith('HOUSE-'), isTrue);
    });

    test('referral code has 5+ chars after prefix', () {
      final code = generateReferralCode('user123');
      final suffix = code.replaceFirst('HOUSE-', '');
      expect(suffix.length, greaterThanOrEqualTo(5));
    });

    test('same user ID generates same code (deterministic)', () {
      final code1 = generateReferralCode('user_abc');
      final code2 = generateReferralCode('user_abc');
      expect(code1, equals(code2));
    });

    test('different user IDs generate different codes', () {
      final code1 = generateReferralCode('user_1');
      final code2 = generateReferralCode('user_2');
      expect(code1, isNot(equals(code2)));
    });

    test('null userId falls back to "USER"', () {
      final code = generateReferralCode(null);
      expect(code.startsWith('HOUSE-'), isTrue);
      expect(code.length, greaterThan(6));
    });

    test('suffix is exactly 5 characters', () {
      final code = generateReferralCode('some_long_user_id_12345');
      final suffix = code.replaceFirst('HOUSE-', '');
      expect(suffix.length, equals(5));
    });

    test('suffix contains only digits', () {
      final code = generateReferralCode('test_user');
      final suffix = code.replaceFirst('HOUSE-', '');
      expect(int.tryParse(suffix), isNotNull);
    });
  });
}
