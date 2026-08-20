// test/services/money_units_test.dart
//
// The single highest-harm defect round 4 found: `PaymentScreen.amount` was
// read as rupees by everything that DISPLAYED it and as paise by everything
// that CHARGED it.
//
//   • Cart      → pushed rupees. Screen showed ₹5,000, gateway got 5000 paise
//                 = ₹50. A hundredth of the bill, and the receipt agreed with
//                 the screen, so nobody could see it from the app.
//   • Billing   → pushed `totalDue * 100` to compensate at ITS end. Screen
//                 showed ₹5,00,000 for a ₹5,000 bill; the CHARGE was right.
//
// Two entry points, wrong in opposite directions, each locally consistent.
// This file pins the contract in one place so it cannot drift again:
// **every caller passes rupees; exactly one conversion exists.**

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mirrors PaymentScreen's only conversion. Kept here rather than reaching
/// into the widget so the arithmetic is assertable without pumping a screen.
int rupeesToPaise(int rupees) => rupees * 100;

void main() {
  group('the gateway boundary is the only conversion', () {
    test('₹5,000 becomes 5,00,000 paise', () {
      expect(rupeesToPaise(5000), 500000);
    });

    test('a rupee amount passed straight through would undercharge 100x', () {
      const displayed = 5000; // what formatCurrency renders
      const wrongCharge = displayed; // the old openCheckout(amount:) argument
      expect(wrongCharge, isNot(rupeesToPaise(displayed)));
      expect(rupeesToPaise(displayed) / wrongCharge, 100);
    });

    test('pre-multiplying at the caller overcharges the DISPLAY 100x', () {
      const bill = 5000;
      const oldBillingArg = bill * 100; // billing_screen's `totalDue * 100`
      // PaymentScreen renders its `amount` with formatCurrency (rupees):
      expect(oldBillingArg, 500000); // rendered as ₹5,00,000
      expect(oldBillingArg, isNot(bill));
    });
  });

  group('the contract holds across realistic amounts', () {
    for (final rupees in const [0, 1, 99, 800, 1500, 18000, 90000, 250000]) {
      test('₹$rupees round-trips', () {
        final paise = rupeesToPaise(rupees);
        expect(paise % 100, 0, reason: 'whole rupees only — no lost paise');
        expect(paise ~/ 100, rupees);
      });
    }
  });

  // ── Wiring guard ────────────────────────────────────────────────────
  //
  // The arithmetic above cannot fail; the WIRING is what failed. These read
  // the source directly. That is a blunt instrument and it is stated as such:
  // it pins that the conversion sits at the gateway boundary and nowhere
  // else, which is the only property that was ever wrong. It does not verify
  // the screen renders correctly — a widget test would, and this is not a
  // substitute for one.
  group('the conversion lives at the gateway boundary and nowhere else', () {
    final paymentScreen =
        File('lib/screens/billing/payment_screen.dart').readAsStringSync();
    final billingScreen =
        File('lib/screens/billing/billing_screen.dart').readAsStringSync();

    test('openCheckout is handed paise', () {
      expect(paymentScreen, contains('openCheckout(\n      amount: _totalAmountPaise'),
          reason: 'passing _totalAmount here charges a hundredth of the bill');
    });

    test('createOrder is handed paise', () {
      expect(paymentScreen, contains('amount: _totalAmountPaise,\n              paymentType'),
          reason: 'the backend passes this straight to razorpay.orders.create');
    });

    test('_totalAmount itself is never handed to the gateway', () {
      final gatewayCalls = RegExp(r'amount: _totalAmount,').allMatches(paymentScreen);
      expect(gatewayCalls, isEmpty,
          reason: 'every gateway call must use the Paise getter');
    });

    test('billing does not pre-multiply', () {
      expect(billingScreen, isNot(contains("'amount': totalDue * 100")),
          reason: 'compensating at the caller broke the DISPLAY instead');
      expect(billingScreen, contains("'amount': totalDue,"));
    });

    test("the invoice route uses the key main.dart actually reads", () {
      final invoice = File('lib/screens/billing/invoice_detail_screen.dart')
          .readAsStringSync();
      expect(invoice, contains("'invoice_id': invoice.id"));
      expect(invoice, isNot(contains("'invoiceId': invoice.id")),
          reason: "main.dart reads 'invoice_id'; the camelCase key silently "
              'dropped the invoice so the payment was recorded against no bill');
    });
  });

  test('the Delhi NCR rate card survives the conversion exactly', () {
    // Real numbers from the official card (CLAUDE.md): a month of nursing
    // must not lose or gain a rupee on the way to Razorpay.
    const monthly = 90000;
    expect(rupeesToPaise(monthly), 9000000);
    expect(rupeesToPaise(monthly) ~/ 100, monthly);
  });
}
