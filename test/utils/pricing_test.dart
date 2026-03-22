// test/utils/pricing_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/utils/pricing.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // calculateCommission
  // ═══════════════════════════════════════════════════════════════════════════
  group('calculateCommission', () {
    // ── Monthly plan ───────────────────────────────────────────────────────
    group('monthly plan', () {
      test('returns ₹12,000 commission for nursing_visit', () {
        final result = calculateCommission(
          serviceType: 'nursing_visit',
          planType: 'monthly',
        );
        expect(result.commission, 12000);
        expect(result.isEmi, isFalse);
      });

      test('returns ₹12,000 commission for physio_visit', () {
        final result = calculateCommission(
          serviceType: 'physio_visit',
          planType: 'monthly',
        );
        expect(result.commission, 12000);
      });
    });

    // ── 3-month plan (one-time) ───────────────────────────────────────────
    group('3-month plan (one-time)', () {
      test('returns ₹30,000 one-time commission', () {
        final result = calculateCommission(
          serviceType: 'nursing_visit',
          planType: '3_month',
        );
        expect(result.commission, 30000);
        expect(result.isEmi, isFalse);
        expect(result.emiCount, 0);
      });
    });

    // ── 3-month plan with EMI ─────────────────────────────────────────────
    group('3-month plan with EMI', () {
      test('returns ₹10,000 × 3 EMI structure', () {
        final result = calculateCommission(
          serviceType: 'nursing_visit',
          planType: '3_month_emi',
        );
        expect(result.commission, 30000);
        expect(result.isEmi, isTrue);
        expect(result.emiCount, 3);
        expect(result.emiAmount, 10000);
        expect(result.emiAmount * result.emiCount, result.commission);
      });
    });

    // ── Manpower services — NO commission ─────────────────────────────────
    group('manpower services — direct salary, NO commission', () {
      test('caretaker: zero commission regardless of plan', () {
        for (final plan in ['monthly', '3_month', '3_month_emi']) {
          final result = calculateCommission(
            serviceType: 'caretaker',
            planType: plan,
          );
          expect(result.commission, 0,
              reason: 'caretaker on $plan should have 0 commission');
        }
      });

      test('nursing_deployment: zero commission', () {
        final result = calculateCommission(
          serviceType: 'nursing_deployment',
          planType: 'monthly',
        );
        expect(result.commission, 0);
      });

      test('japa: zero commission', () {
        final result = calculateCommission(
          serviceType: 'japa',
          planType: '3_month',
        );
        expect(result.commission, 0);
      });

      test('nanny: zero commission', () {
        final result = calculateCommission(
          serviceType: 'nanny',
          planType: '3_month_emi',
        );
        expect(result.commission, 0);
      });
    });

    // ── Unknown plan type ─────────────────────────────────────────────────
    group('error handling', () {
      test('throws ArgumentError for unknown plan type', () {
        expect(
          () => calculateCommission(
            serviceType: 'nursing_visit',
            planType: 'weekly',
          ),
          throwsArgumentError,
        );
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // calculateGst
  // ═══════════════════════════════════════════════════════════════════════════
  group('calculateGst', () {
    test('18% GST on ₹1,000 = ₹180', () {
      expect(calculateGst(1000), 180);
    });

    test('18% GST on ₹12,000 = ₹2,160', () {
      expect(calculateGst(12000), 2160);
    });

    test('18% GST on ₹0 = ₹0', () {
      expect(calculateGst(0), 0);
    });

    test('handles fractional results (₹999 → ₹179.82)', () {
      expect(calculateGst(999), 179.82);
    });

    test('throws ArgumentError for negative price', () {
      expect(() => calculateGst(-100), throwsArgumentError);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // calculateEquipmentDiscount
  // ═══════════════════════════════════════════════════════════════════════════
  group('calculateEquipmentDiscount', () {
    test('30% off for 3-month customer: ₹10,000 → ₹7,000', () {
      final result = calculateEquipmentDiscount(
        originalPrice: 10000,
        isThreeMonthCustomer: true,
      );
      expect(result, 7000);
    });

    test('no discount for non-3-month customer: ₹10,000 → ₹10,000', () {
      final result = calculateEquipmentDiscount(
        originalPrice: 10000,
        isThreeMonthCustomer: false,
      );
      expect(result, 10000);
    });

    test('30% off ₹1,500 → ₹1,050', () {
      final result = calculateEquipmentDiscount(
        originalPrice: 1500,
        isThreeMonthCustomer: true,
      );
      expect(result, 1050);
    });

    test('zero price stays zero', () {
      final result = calculateEquipmentDiscount(
        originalPrice: 0,
        isThreeMonthCustomer: true,
      );
      expect(result, 0);
    });

    test('throws ArgumentError for negative price', () {
      expect(
        () => calculateEquipmentDiscount(
          originalPrice: -500,
          isThreeMonthCustomer: true,
        ),
        throwsArgumentError,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // calculateRefund
  // ═══════════════════════════════════════════════════════════════════════════
  group('calculateRefund', () {
    test('full plan unused: refund = totalPaid - minimumNonRefundable', () {
      final refund = calculateRefund(
        totalPaid: 30000,
        totalDays: 90,
        consumedDays: 0,
      );
      // proportional = 30000, max = 30000 - 500 = 29500
      expect(refund, 29500);
    });

    test('half consumed: proportional refund', () {
      final refund = calculateRefund(
        totalPaid: 30000,
        totalDays: 90,
        consumedDays: 45,
      );
      // remaining = 45, proportional = (45/90)*30000 = 15000
      // max = 30000-500 = 29500; 15000 < 29500 → 15000
      expect(refund, 15000);
    });

    test('fully consumed: zero refund', () {
      final refund = calculateRefund(
        totalPaid: 30000,
        totalDays: 90,
        consumedDays: 90,
      );
      expect(refund, 0);
    });

    test('over-consumed: zero refund', () {
      final refund = calculateRefund(
        totalPaid: 30000,
        totalDays: 90,
        consumedDays: 100,
      );
      expect(refund, 0);
    });

    test('small total: below minimum non-refundable → zero', () {
      final refund = calculateRefund(
        totalPaid: 400,
        totalDays: 30,
        consumedDays: 0,
      );
      // max = 400 - 500 = -100 → 0
      expect(refund, 0);
    });

    test('throws for negative totalPaid', () {
      expect(
        () => calculateRefund(totalPaid: -1, totalDays: 30, consumedDays: 0),
        throwsArgumentError,
      );
    });

    test('throws for zero totalDays', () {
      expect(
        () => calculateRefund(totalPaid: 1000, totalDays: 0, consumedDays: 0),
        throwsArgumentError,
      );
    });
  });
}
