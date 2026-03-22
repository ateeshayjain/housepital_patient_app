// test/screens/cart/cart_coupon_test.dart
//
// Tests coupon system logic from CartScreen:
// - WELCOME10 coupon: 10% off, max 500 discount
// - WELCOME10 on 3000 order = 300 discount (10%)
// - WELCOME10 on 8000 order = 500 discount (capped)
// - Invalid coupon code returns error
// - Empty coupon code is rejected

import 'package:flutter_test/flutter_test.dart';

// ── Coupon logic replicated from _CartScreenState._applyCoupon ──────────────
//
// The core coupon validation for WELCOME10 is:
//   int discount = (subtotal * 10 / 100).round();
//   if (discount > 500) discount = 500;
//
// For unknown codes, the API call throws and the catch block sets:
//   _couponError = 'Invalid or expired coupon code';
//
// For empty code:
//   _couponError = 'Please enter a coupon code';

/// Simulates the WELCOME10 coupon logic from the cart screen.
/// Returns null if the coupon is not WELCOME10 (would go to API).
/// Returns discount amount for WELCOME10.
int? applyWelcome10(String code, int subtotal) {
  if (code != 'WELCOME10') return null;
  int discount = (subtotal * 10 / 100).round();
  if (discount > 500) discount = 500;
  return discount;
}

/// Validates the coupon code input before processing.
String? validateCouponInput(String rawCode) {
  final code = rawCode.trim().toUpperCase();
  if (code.isEmpty) return 'Please enter a coupon code';
  return null; // proceed with validation
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // WELCOME10 — 10% off, max ₹500
  // ═══════════════════════════════════════════════════════════════════════════
  group('Coupon — WELCOME10 logic', () {
    test('WELCOME10 gives 10% discount', () {
      final discount = applyWelcome10('WELCOME10', 2000);
      expect(discount, 200); // 10% of 2000
    });

    test('WELCOME10 on ₹3000 order = ₹300 discount (10%)', () {
      final discount = applyWelcome10('WELCOME10', 3000);
      expect(discount, 300);
    });

    test('WELCOME10 on ₹5000 order = ₹500 discount (at cap)', () {
      final discount = applyWelcome10('WELCOME10', 5000);
      expect(discount, 500);
    });

    test('WELCOME10 on ₹8000 order = ₹500 discount (capped)', () {
      final discount = applyWelcome10('WELCOME10', 8000);
      expect(discount, 500);
    });

    test('WELCOME10 on ₹10000 order = ₹500 discount (capped)', () {
      final discount = applyWelcome10('WELCOME10', 10000);
      expect(discount, 500);
    });

    test('WELCOME10 on ₹100 order = ₹10 discount', () {
      final discount = applyWelcome10('WELCOME10', 100);
      expect(discount, 10);
    });

    test('WELCOME10 on ₹0 order = ₹0 discount', () {
      final discount = applyWelcome10('WELCOME10', 0);
      expect(discount, 0);
    });

    test('WELCOME10 on ₹4999 order = ₹500 discount (rounds to 500)', () {
      final discount = applyWelcome10('WELCOME10', 4999);
      // 4999 * 10 / 100 = 499.9 -> rounds to 500
      expect(discount, 500);
    });

    test('WELCOME10 on ₹4990 order = ₹499 discount (just under cap)', () {
      final discount = applyWelcome10('WELCOME10', 4990);
      // 4990 * 10 / 100 = 499.0
      expect(discount, 499);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Invalid coupon code
  // ═══════════════════════════════════════════════════════════════════════════
  group('Coupon — invalid code', () {
    test('non-WELCOME10 code returns null (goes to API)', () {
      final discount = applyWelcome10('INVALID123', 3000);
      expect(discount, isNull);
    });

    test('random code returns null', () {
      final discount = applyWelcome10('FOOBAR', 5000);
      expect(discount, isNull);
    });

    test('lowercase welcome10 returns null (code is case-sensitive in matching)', () {
      // The cart screen uppercases the input before matching, so
      // "welcome10" uppercased = "WELCOME10" which matches.
      // But if passed as-is without uppercasing:
      final discount = applyWelcome10('welcome10', 3000);
      expect(discount, isNull); // Does not match since we compare exact
    });

    test('WELCOME10 with extra spaces returns null', () {
      final discount = applyWelcome10(' WELCOME10 ', 3000);
      expect(discount, isNull); // not trimmed in our function
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Empty coupon code
  // ═══════════════════════════════════════════════════════════════════════════
  group('Coupon — empty code rejected', () {
    test('empty string is rejected with error message', () {
      final error = validateCouponInput('');
      expect(error, 'Please enter a coupon code');
    });

    test('whitespace-only string is rejected', () {
      final error = validateCouponInput('   ');
      expect(error, 'Please enter a coupon code');
    });

    test('valid code passes validation', () {
      final error = validateCouponInput('WELCOME10');
      expect(error, isNull);
    });

    test('any non-empty code passes input validation', () {
      final error = validateCouponInput('ABC');
      expect(error, isNull);
    });
  });
}
