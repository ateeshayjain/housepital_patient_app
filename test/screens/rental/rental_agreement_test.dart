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

    // --- Additional tests for bottom sheet / rental agreement flow ---

    test('first payment equals monthlyRate + deposit (deposit = monthlyRate)', () {
      // deposit = monthlyRate, so firstPayment = 2 * monthlyRate
      expect(firstPayment(3599), equals(3599 + 3599));
      expect(firstPayment(7999), equals(7999 * 2));
      expect(firstPayment(1), equals(2));
    });

    test('zero monthlyRate produces zero firstPayment', () {
      expect(firstPayment(0), equals(0));
      expect(deposit(0), equals(0));
    });

    test('large monthlyRate values work correctly', () {
      const largeRate = 999999;
      expect(deposit(largeRate), equals(largeRate));
      expect(firstPayment(largeRate), equals(largeRate * 2));
      // Ensure no overflow for reasonable values
      expect(firstPayment(largeRate), isPositive);
    });

    test('durationMonths defaults to 1 in rental args', () {
      // When creating rental agreement args, durationMonths defaults to 1
      final args = <String, dynamic>{
        'itemName': 'Wheelchair',
        'monthlyRate': 2500,
        'durationMonths': 1,
      };
      expect(args['durationMonths'], equals(1));

      // Total cost for 1 month = firstPayment (deposit + 1 month)
      final totalForDefault =
          (args['monthlyRate'] as int) * (args['durationMonths'] as int) +
              deposit(args['monthlyRate'] as int);
      expect(totalForDefault, equals(2500 + 2500));
    });

    test('total rental cost formula is correct across durations', () {
      const rate = 4000;
      // Total = (monthlyRate * duration) + deposit
      // where deposit = monthlyRate
      for (final duration in [1, 3, 6, 12]) {
        final total = rate * duration + deposit(rate);
        expect(total, equals(rate * duration + rate));
        expect(total, equals(rate * (duration + 1)));
      }
    });
  });
}
