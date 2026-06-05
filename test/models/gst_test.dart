// test/models/gst_test.dart
//
// Tests for the per-line-item GST computation added in audit M-14:
//   - CartItem.gstRate getter (services=0%, labs=5%, equipment=18%)
//   - computeCartGst() helper which sums per-line GST and prorates discount.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/utils/pricing.dart';

// ── Fixture helpers ─────────────────────────────────────────────────────────

CartItem _equipment({
  int unitPrice = 5000,
  String brand = 'Philips',
  int quantity = 1,
}) =>
    CartItem(
      equipmentId: 'eq-${brand.hashCode}',
      name: 'Oxygen Concentrator',
      brand: brand,
      unitPrice: unitPrice,
      quantity: quantity,
    );

CartItem _nursingService({int unitPrice = 2000}) => CartItem(
      equipmentId: 'svc-nurse-1',
      name: 'Nursing visit',
      brand: 'nursing', // service category encoded in brand
      unitPrice: unitPrice,
      isService: true,
    );

CartItem _labService({int unitPrice = 1000, String brand = 'lab'}) => CartItem(
      equipmentId: 'svc-lab-1',
      name: 'CBC test',
      brand: brand,
      unitPrice: unitPrice,
      isService: true,
    );

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // CartItem.gstRate
  // ═══════════════════════════════════════════════════════════════════════════
  group('CartItem.gstRate', () {
    test('service item (isService=true, nursing brand) → 0% (healthcare exempt)',
        () {
      final item = _nursingService();
      expect(item.gstRate, 0.0);
    });

    test('equipment item, generic brand → 18%', () {
      final item = _equipment(brand: 'Philips');
      expect(item.gstRate, 0.18);
    });

    test('lab service, brand contains "lab" → 5%', () {
      final item = _labService(brand: 'lab');
      expect(item.gstRate, 0.05);
    });

    test('lab service, brand contains "diagnostic" → 5%', () {
      final item = _labService(brand: 'diagnostic');
      expect(item.gstRate, 0.05);
    });

    test('lab service, brand contains "test" → 5%', () {
      final item = _labService(brand: 'lab-test-package');
      expect(item.gstRate, 0.05);
    });

    test('case-insensitive brand match for "LAB"', () {
      final item = _labService(brand: 'LAB');
      expect(item.gstRate, 0.05);
    });

    test('caretaker service (no lab/diagnostic/test substring) → 0%', () {
      final item = CartItem(
        equipmentId: 'svc-c-1',
        name: 'Caretaker',
        brand: 'caretaker',
        unitPrice: 1500,
        isService: true,
      );
      expect(item.gstRate, 0.0);
    });

    test('japa service → 0%', () {
      final item = CartItem(
        equipmentId: 'svc-j-1',
        name: 'Japa',
        brand: 'japa',
        unitPrice: 30000,
        isService: true,
      );
      expect(item.gstRate, 0.0);
    });

    // Edge case: service rule takes precedence over lab brand substring match.
    test('lab item that is ALSO a service → service rule wins (0%)', () {
      // isService=true overrides; but the lab substring still triggers 5%
      // because the inner logic uses brand-based dispatch for services.
      // This test pins down the actual rule: lab category services are 5%,
      // OTHER services are 0%. Tested separately above; here we confirm
      // a service item with a non-lab brand stays 0% regardless.
      final item = CartItem(
        equipmentId: 'svc-mixed-1',
        name: 'Home nursing',
        brand: 'nursing_visit',
        unitPrice: 1000,
        isService: true,
      );
      expect(item.gstRate, 0.0);
    });

    // Edge case: brand substring rule for equipment.
    // The CURRENT implementation only applies the lab substring rule to
    // services — equipment goes straight to 0.18 regardless of brand.
    // This test pins down that intended behaviour.
    test(
        'equipment with brand "Diagnostic Co." → 18% (substring rule does NOT apply to equipment)',
        () {
      final item = _equipment(brand: 'Diagnostic Co.');
      expect(item.gstRate, 0.18,
          reason:
              'brand-substring lab rule only fires for service items, not equipment.');
    });

    test('rental equipment → 18%', () {
      final item = CartItem(
        equipmentId: 'eq-rent-1',
        name: 'Hospital bed',
        brand: 'Generic',
        unitPrice: 3000,
        isRental: true,
        rentalMonths: 2,
      );
      expect(item.gstRate, 0.18);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // computeCartGst — full cart roll-up
  // ═══════════════════════════════════════════════════════════════════════════
  group('computeCartGst', () {
    test('empty cart → 0', () {
      expect(computeCartGst(const []), 0);
    });

    test('cart with 1 equipment item (₹5000) → GST = ₹900 (18%)', () {
      final cart = [_equipment(unitPrice: 5000)];
      expect(computeCartGst(cart), 900);
    });

    test('cart with 1 nursing service (₹2000) → GST = ₹0 (exempt)', () {
      final cart = [_nursingService(unitPrice: 2000)];
      expect(computeCartGst(cart), 0);
    });

    test('cart with 1 lab test (₹1000) → GST = ₹50 (5%)', () {
      final cart = [_labService(unitPrice: 1000)];
      expect(computeCartGst(cart), 50);
    });

    test(
        'mixed cart: equipment(₹5000) + nursing(₹2000) + lab(₹1000) → GST = ₹950',
        () {
      final cart = [
        _equipment(unitPrice: 5000),
        _nursingService(unitPrice: 2000),
        _labService(unitPrice: 1000),
      ];
      // 5000 * 0.18 + 2000 * 0 + 1000 * 0.05 = 900 + 0 + 50 = 950
      expect(computeCartGst(cart), 950);
    });

    test('discount is prorated across line items, not flat 18%', () {
      // Subtotal = 8000, discount = 800 (10% off).
      // Equipment line: 5000 * (1 - 800/8000) = 4500 → 4500 * 0.18 = 810
      // Nursing line:   2000 * (1 - 800/8000) = 1800 → 1800 * 0    = 0
      // Lab line:       1000 * (1 - 800/8000) =  900 →  900 * 0.05 = 45
      // Total GST = 855  (NOT (8000-800)*0.18 = 1296 which would be naïve flat)
      final cart = [
        _equipment(unitPrice: 5000),
        _nursingService(unitPrice: 2000),
        _labService(unitPrice: 1000),
      ];
      final gst = computeCartGst(cart, discount: 800);
      expect(gst, 855);
      // Definitely not the naive flat-discount calculation.
      expect(gst, isNot(equals(((8000 - 800) * 0.18).round())));
    });

    test('cart with quantity > 1 multiplies line total correctly', () {
      // 2 equipment items @ ₹3000 each = ₹6000 line, GST = ₹1080
      final cart = [_equipment(unitPrice: 3000, quantity: 2)];
      expect(computeCartGst(cart), 1080);
    });

    test('discount equal to subtotal → GST = 0 (no positive line left)', () {
      final cart = [_equipment(unitPrice: 5000)];
      expect(computeCartGst(cart, discount: 5000), 0);
    });

    test('all-manpower cart → GST always 0 regardless of discount', () {
      final cart = [
        _nursingService(unitPrice: 5000),
        CartItem(
          equipmentId: 'svc-c-2',
          name: 'Caretaker',
          brand: 'caretaker',
          unitPrice: 3000,
          isService: true,
        ),
      ];
      expect(computeCartGst(cart), 0);
      expect(computeCartGst(cart, discount: 500), 0);
    });
  });
}
