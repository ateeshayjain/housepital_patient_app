// test/screens/cart/cart_screen_test.dart
//
// Tests CartScreen data/logic via CartProvider (no widget rendering).
// Validates: itemCount, subtotal, delivery charge, total, coupon, remove, clear.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/models/models.dart';

// -- Fixture helpers ----------------------------------------------------------

EquipmentItem _makeEquipment({
  String id = 'eq1',
  String name = 'Oxygen Concentrator',
  double? price = 25000,
  double? rentalPrice = 3000,
  double? mrp,
}) {
  return EquipmentItem(
    id: id,
    name: name,
    brand: 'Philips',
    category: 'Equipment',
    availableForSale: true,
    availableForRent: true,
    price: price,
    rentalPrice: rentalPrice,
    mrp: mrp,
  );
}

/// Simulates the WELCOME10 coupon logic from _CartScreenState._applyCoupon.
int applyWelcome10Discount(int subtotal) {
  int discount = (subtotal * 10 / 100).round();
  if (discount > 500) discount = 500;
  return discount;
}

// -- Tests --------------------------------------------------------------------

void main() {
  late CartProvider cart;

  setUp(() {
    cart = CartProvider();
  });

  // =========================================================================
  // Empty cart
  // =========================================================================
  group('Empty cart state', () {
    test('empty cart shows itemCount == 0', () {
      expect(cart.itemCount, 0);
    });

    test('empty cart isEmpty is true', () {
      expect(cart.isEmpty, isTrue);
    });

    test('empty cart subtotal is 0', () {
      expect(cart.subtotal, 0);
    });
  });

  // =========================================================================
  // After addItem
  // =========================================================================
  group('After addItem', () {
    test('after addItem, itemCount == 1', () {
      cart.addItem(_makeEquipment());
      expect(cart.itemCount, 1);
    });

    test('after addItem, isEmpty is false', () {
      cart.addItem(_makeEquipment());
      expect(cart.isEmpty, isFalse);
    });

    test('item name matches', () {
      cart.addItem(_makeEquipment(name: 'Wheelchair'));
      expect(cart.items[0].name, 'Wheelchair');
    });
  });

  // =========================================================================
  // Subtotal calculation
  // =========================================================================
  group('Subtotal calculation', () {
    test('single buy item subtotal', () {
      cart.addItem(_makeEquipment(price: 5000));
      expect(cart.subtotal, 5000);
    });

    test('multiple buy items subtotal', () {
      cart.addItem(_makeEquipment(id: 'eq1', price: 5000));
      cart.addItem(_makeEquipment(id: 'eq2', price: 3000));
      expect(cart.subtotal, 8000);
    });

    test('buy item with quantity > 1', () {
      cart.addItem(_makeEquipment(price: 2000));
      cart.updateQuantity(0, 4);
      // 2000 * 4 = 8000
      expect(cart.subtotal, 8000);
    });

    test('rental item subtotal includes months', () {
      cart.addItem(_makeEquipment(rentalPrice: 2000), isRental: true, rentalMonths: 3);
      // 2000 * 3 * 1 = 6000
      expect(cart.subtotal, 6000);
    });

    test('mixed buy + rental subtotal', () {
      cart.addItem(_makeEquipment(id: 'eq1', price: 5000), isRental: false);
      cart.addItem(_makeEquipment(id: 'eq2', rentalPrice: 2000), isRental: true, rentalMonths: 2);
      // 5000 + (2000 * 2) = 9000
      expect(cart.subtotal, 9000);
    });
  });

  // =========================================================================
  // Delivery charge
  // =========================================================================
  group('Delivery charge', () {
    test('free delivery above Rs.999', () {
      cart.addItem(_makeEquipment(price: 1000));
      expect(cart.deliveryCharge, 0);
    });

    test('free delivery at exactly Rs.999', () {
      cart.addItem(_makeEquipment(price: 999));
      expect(cart.deliveryCharge, 0);
    });

    test('Rs.49 delivery below Rs.999', () {
      cart.addItem(_makeEquipment(price: 500));
      expect(cart.deliveryCharge, 49);
    });

    test('Rs.49 delivery on empty cart (subtotal 0)', () {
      expect(cart.deliveryCharge, 49);
    });

    test('Rs.49 delivery at Rs.998', () {
      cart.addItem(_makeEquipment(price: 998));
      expect(cart.deliveryCharge, 49);
    });
  });

  // =========================================================================
  // Total = subtotal + deliveryCharge - discount
  // =========================================================================
  group('Total calculation (provider.total = subtotal + deliveryCharge)', () {
    test('total with delivery charge (small order)', () {
      cart.addItem(_makeEquipment(price: 500));
      expect(cart.total, 500 + 49);
    });

    test('total with free delivery (large order)', () {
      cart.addItem(_makeEquipment(price: 5000));
      expect(cart.total, 5000);
    });

    test('empty cart total = delivery charge', () {
      expect(cart.total, 49);
    });
  });

  group('Total with coupon discount (cart screen logic)', () {
    test('total = subtotal + deliveryCharge - discount', () {
      cart.addItem(_makeEquipment(price: 3000));
      final discount = applyWelcome10Discount(cart.subtotal); // 300
      final adjustedTotal = cart.subtotal - discount + cart.deliveryCharge;
      // 3000 - 300 + 0 = 2700
      expect(adjustedTotal, 2700);
    });

    test('total with discount and delivery charge', () {
      cart.addItem(_makeEquipment(price: 500));
      final discount = applyWelcome10Discount(cart.subtotal); // 50
      final adjustedTotal = cart.subtotal - discount + cart.deliveryCharge;
      // 500 - 50 + 49 = 499
      expect(adjustedTotal, 499);
    });
  });

  // =========================================================================
  // Coupon WELCOME10
  // =========================================================================
  group('Coupon WELCOME10: 10% off capped at Rs.500', () {
    test('10% on Rs.2000 = Rs.200', () {
      cart.addItem(_makeEquipment(price: 2000));
      expect(applyWelcome10Discount(cart.subtotal), 200);
    });

    test('10% on Rs.5000 = Rs.500 (at cap)', () {
      cart.addItem(_makeEquipment(price: 5000));
      expect(applyWelcome10Discount(cart.subtotal), 500);
    });

    test('10% on Rs.8000 = Rs.500 (capped)', () {
      cart.addItem(_makeEquipment(price: 8000));
      expect(applyWelcome10Discount(cart.subtotal), 500);
    });

    test('10% on Rs.100 = Rs.10', () {
      cart.addItem(_makeEquipment(price: 100));
      expect(applyWelcome10Discount(cart.subtotal), 10);
    });

    test('10% on Rs.0 = Rs.0', () {
      expect(applyWelcome10Discount(cart.subtotal), 0);
    });
  });

  // =========================================================================
  // Remove item
  // =========================================================================
  group('Remove item', () {
    test('remove item reduces count', () {
      cart.addItem(_makeEquipment(id: 'eq1'));
      cart.addItem(_makeEquipment(id: 'eq2'));
      expect(cart.itemCount, 2);

      cart.removeItem(0);
      expect(cart.itemCount, 1);
    });

    test('remove last item makes cart empty', () {
      cart.addItem(_makeEquipment());
      cart.removeItem(0);
      expect(cart.isEmpty, isTrue);
    });

    test('remove out-of-bounds is no-op', () {
      cart.addItem(_makeEquipment());
      cart.removeItem(5);
      expect(cart.itemCount, 1);
    });
  });

  // =========================================================================
  // Clear
  // =========================================================================
  group('Clear empties everything', () {
    test('clear empties cart', () {
      cart.addItem(_makeEquipment(id: 'eq1'));
      cart.addItem(_makeEquipment(id: 'eq2'));
      cart.addItem(_makeEquipment(id: 'eq3'));
      cart.clear();
      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
      expect(cart.subtotal, 0);
    });

    test('clear does not affect saved-for-later', () {
      cart.addItem(_makeEquipment(id: 'eq1'));
      cart.addItem(_makeEquipment(id: 'eq2'));
      cart.saveForLater(1);
      cart.clear();
      expect(cart.isEmpty, isTrue);
      expect(cart.savedCount, 1);
    });
  });
}
