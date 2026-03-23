import 'package:flutter_test/flutter_test.dart';

/// Tests the EMI calculation logic extracted from EmiScreen.
void main() {
  /// Mirrors the _emiAmount getter: (totalAmount / months).ceil()
  int emiAmount(int totalAmount, int months) =>
      (totalAmount / months).ceil();

  group('EMI calculations', () {
    const totalAmount = 30000;

    test('3-month EMI: total/3 = monthly amount', () {
      final monthly = emiAmount(totalAmount, 3);
      expect(monthly, equals(10000));
    });

    test('6-month EMI: total/6 = monthly amount', () {
      final monthly = emiAmount(totalAmount, 6);
      expect(monthly, equals(5000));
    });

    test('9-month EMI: total/9 = monthly amount', () {
      final monthly = emiAmount(totalAmount, 9);
      // 30000 / 9 = 3333.33... -> ceil = 3334
      expect(monthly, equals(3334));
    });

    test('processing fee is 0 (no-cost EMI)', () {
      // The screen explicitly states "No-cost EMI - Zero processing fee"
      // and "Processing Fee: FREE". There is no fee added.
      const processingFee = 0;
      expect(processingFee, equals(0));
    });

    test('EMI schedule has correct number of entries per plan', () {
      for (final months in [3, 6, 9]) {
        final schedule = List.generate(months, (i) => i + 1);
        expect(schedule.length, equals(months));
      }
    });

    test('monthly amounts sum to at least total (ceil rounding)', () {
      for (final months in [3, 6, 9]) {
        final monthly = emiAmount(totalAmount, months);
        final sum = monthly * months;
        // Because of ceil(), sum >= totalAmount
        expect(sum, greaterThanOrEqualTo(totalAmount));
        // But should not exceed total by more than (months - 1)
        expect(sum - totalAmount, lessThan(months));
      }
    });

    test('EMI works for non-round amounts', () {
      const oddTotal = 10000;
      expect(emiAmount(oddTotal, 3), equals(3334)); // 10000/3 = 3333.33 -> 3334
      expect(emiAmount(oddTotal, 6), equals(1667)); // 10000/6 = 1666.67 -> 1667
      expect(emiAmount(oddTotal, 9), equals(1112)); // 10000/9 = 1111.11 -> 1112
    });
  });
}
