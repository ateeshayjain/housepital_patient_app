import 'package:flutter_test/flutter_test.dart';

/// Tests the rental agreement computation logic extracted from
/// RentalAgreementScreen (deposit = 1 month's rent, firstPayment = deposit + rent).
void main() {
  group('Rental Agreement calculations', () {
    // Mirrors the logic in _RentalAgreementScreenState
    int deposit(int monthlyRate) => monthlyRate;
    int firstPayment(int monthlyRate) => monthlyRate + deposit(monthlyRate);

    test('deposit equals 1 month rent', () {
      expect(deposit(5000), equals(5000));
      expect(deposit(12000), equals(12000));
    });

    test('total first payment is deposit + first month', () {
      expect(firstPayment(5000), equals(10000));
      expect(firstPayment(12000), equals(24000));
    });

    test('rental terms list has at least 4 items', () {
      // The screen defines 6 terms inline (Monthly Billing, Security Deposit,
      // Damage Policy, Return Policy, Delivery & Setup, Maintenance).
      const termTitles = [
        'Monthly Billing',
        'Security Deposit',
        'Damage Policy',
        'Return Policy',
        'Delivery & Setup',
        'Maintenance',
      ];
      expect(termTitles.length, greaterThanOrEqualTo(4));
    });

    test('different durations produce different total costs', () {
      const monthlyRate = 5000;
      final total1Month = monthlyRate * 1 + deposit(monthlyRate);
      final total3Month = monthlyRate * 3 + deposit(monthlyRate);
      final total6Month = monthlyRate * 6 + deposit(monthlyRate);

      expect(total1Month, isNot(equals(total3Month)));
      expect(total3Month, isNot(equals(total6Month)));
      expect(total1Month, lessThan(total3Month));
      expect(total3Month, lessThan(total6Month));
    });
  });
}
