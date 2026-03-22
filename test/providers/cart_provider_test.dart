// test/providers/cart_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/models/models.dart';

// ── Fixture helpers ──────────────────────────────────────────────────────────

EquipmentItem _makeEquipment({
  String id = 'eq1',
  String name = 'Oxygen Concentrator',
  double? price = 25000,
  double? rentalPrice = 3000,
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
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late CartProvider cart;

  setUp(() {
    cart = CartProvider();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Initial state
  // ═══════════════════════════════════════════════════════════════════════════
  group('Initial state', () {
    test('cart starts empty', () {
      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
      expect(cart.subtotal, 0);
      expect(cart.total, 49); // delivery charge when subtotal < 999
    });

    test('no saved items initially', () {
      expect(cart.hasSavedItems, isFalse);
      expect(cart.savedCount, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // addItem
  // ═══════════════════════════════════════════════════════════════════════════
  group('addItem', () {
    test('adds item to cart (purchase mode)', () {
      cart.addItem(_makeEquipment());
      expect(cart.itemCount, 1);
      expect(cart.isEmpty, isFalse);
    });

    test('adds item to cart (rental mode)', () {
      cart.addItem(_makeEquipment(), isRental: true, rentalMonths: 3);
      expect(cart.itemCount, 1);
    });

    test('same item added twice increments quantity', () {
      final eq = _makeEquipment();
      cart.addItem(eq);
      cart.addItem(eq);
      expect(cart.itemCount, 2); // quantity = 2
      expect(cart.items.length, 1); // only 1 unique entry
    });

    test('same item as buy and rent are separate entries', () {
      final eq = _makeEquipment();
      cart.addItem(eq, isRental: false);
      cart.addItem(eq, isRental: true);
      expect(cart.items.length, 2);
    });

    test('addItem removes from saved list if present', () {
      final eq = _makeEquipment();
      cart.saveForLater(eq);
      expect(cart.hasSavedItems, isTrue);

      cart.addItem(eq);
      expect(cart.hasSavedItems, isFalse);
      expect(cart.itemCount, 1);
    });

    test('notifies listeners on add', () {
      int notifyCount = 0;
      cart.addListener(() => notifyCount++);
      cart.addItem(_makeEquipment());
      expect(notifyCount, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // removeItem
  // ═══════════════════════════════════════════════════════════════════════════
  group('removeItem', () {
    test('removes item by cartKey', () {
      cart.addItem(_makeEquipment());
      expect(cart.itemCount, 1);

      cart.removeItem('eq1_buy');
      expect(cart.itemCount, 0);
      expect(cart.isEmpty, isTrue);
    });

    test('removing non-existent key is no-op', () {
      cart.addItem(_makeEquipment());
      cart.removeItem('nonexistent_buy');
      expect(cart.itemCount, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // updateQuantity
  // ═══════════════════════════════════════════════════════════════════════════
  group('updateQuantity', () {
    test('updates quantity for existing item', () {
      cart.addItem(_makeEquipment());
      cart.updateQuantity('eq1_buy', 5);
      expect(cart.itemCount, 5);
    });

    test('setting quantity to 0 removes item', () {
      cart.addItem(_makeEquipment());
      cart.updateQuantity('eq1_buy', 0);
      expect(cart.isEmpty, isTrue);
    });

    test('negative quantity removes item', () {
      cart.addItem(_makeEquipment());
      cart.updateQuantity('eq1_buy', -1);
      expect(cart.isEmpty, isTrue);
    });

    test('no-op for non-existent cartKey', () {
      cart.updateQuantity('nonexistent_buy', 10);
      expect(cart.isEmpty, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // saveForLater / moveToCart / moveToSaved
  // ═══════════════════════════════════════════════════════════════════════════
  group('Save for Later operations', () {
    test('saveForLater adds to saved list and removes from cart', () {
      final eq = _makeEquipment();
      cart.addItem(eq);
      expect(cart.itemCount, 1);

      cart.saveForLater(eq);
      expect(cart.isEmpty, isTrue);
      expect(cart.hasSavedItems, isTrue);
      expect(cart.savedCount, 1);
    });

    test('moveToCart moves saved item into cart', () {
      final eq = _makeEquipment();
      cart.saveForLater(eq);
      expect(cart.savedCount, 1);

      cart.moveToCart('eq1_buy');
      expect(cart.itemCount, 1);
      expect(cart.savedCount, 0);
    });

    test('moveToSaved moves cart item to saved list', () {
      cart.addItem(_makeEquipment());
      cart.moveToSaved('eq1_buy');
      expect(cart.isEmpty, isTrue);
      expect(cart.savedCount, 1);
    });

    test('moveToCart with non-existent key is no-op', () {
      cart.moveToCart('nonexistent_buy');
      expect(cart.isEmpty, isTrue);
      expect(cart.savedCount, 0);
    });

    test('moveToSaved with non-existent key is no-op', () {
      cart.moveToSaved('nonexistent_buy');
      expect(cart.isEmpty, isTrue);
      expect(cart.savedCount, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // isInCart / isSaved helpers
  // ═══════════════════════════════════════════════════════════════════════════
  group('isInCart / isSaved helpers', () {
    test('isInCart returns true when item is in cart', () {
      cart.addItem(_makeEquipment(id: 'bp-monitor'));
      expect(cart.isInCart('bp-monitor'), isTrue);
      expect(cart.isInCart('other-item'), isFalse);
    });

    test('isSaved returns true when item is saved for later', () {
      cart.saveForLater(_makeEquipment(id: 'bp-monitor'));
      expect(cart.isSaved('bp-monitor'), isTrue);
      expect(cart.isSaved('other-item'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Subtotal calculation
  // ═══════════════════════════════════════════════════════════════════════════
  group('Subtotal calculation', () {
    test('purchase: subtotal = price * quantity', () {
      cart.addItem(_makeEquipment(price: 5000));
      expect(cart.subtotal, 5000);

      cart.updateQuantity('eq1_buy', 3);
      expect(cart.subtotal, 15000);
    });

    test('rental: subtotal = rentalPrice * months * quantity', () {
      cart.addItem(_makeEquipment(rentalPrice: 2000), isRental: true, rentalMonths: 3);
      // 2000 * 1 * 3 = 6000
      expect(cart.subtotal, 6000);
    });

    test('mixed cart: purchase + rental', () {
      cart.addItem(_makeEquipment(id: 'eq1', price: 5000), isRental: false);
      cart.addItem(_makeEquipment(id: 'eq2', rentalPrice: 2000), isRental: true, rentalMonths: 2);
      // 5000 + (2000 * 1 * 2) = 9000
      expect(cart.subtotal, 9000);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Delivery charge
  // ═══════════════════════════════════════════════════════════════════════════
  group('Delivery charge', () {
    test('₹49 delivery when subtotal < ₹999', () {
      cart.addItem(_makeEquipment(price: 500));
      expect(cart.deliveryCharge, 49);
    });

    test('free delivery when subtotal >= ₹999', () {
      cart.addItem(_makeEquipment(price: 999));
      expect(cart.deliveryCharge, 0);
    });

    test('free delivery when subtotal = ₹1000', () {
      cart.addItem(_makeEquipment(price: 1000));
      expect(cart.deliveryCharge, 0);
    });

    test('free delivery for large orders', () {
      cart.addItem(_makeEquipment(price: 25000));
      expect(cart.deliveryCharge, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Total = subtotal + delivery
  // ═══════════════════════════════════════════════════════════════════════════
  group('Total calculation', () {
    test('total = subtotal + delivery charge (small order)', () {
      cart.addItem(_makeEquipment(price: 500));
      expect(cart.total, 500 + 49);
    });

    test('total = subtotal when delivery is free', () {
      cart.addItem(_makeEquipment(price: 5000));
      expect(cart.total, 5000);
    });

    test('empty cart total = delivery charge only', () {
      // subtotal = 0, delivery = 49 (since 0 < 999)
      expect(cart.total, 49);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // clear
  // ═══════════════════════════════════════════════════════════════════════════
  group('clear', () {
    test('clear empties the cart', () {
      cart.addItem(_makeEquipment());
      cart.addItem(_makeEquipment(id: 'eq2'));
      expect(cart.itemCount, 2);

      cart.clear();
      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
    });

    test('clear does not affect saved items', () {
      cart.addItem(_makeEquipment(id: 'eq1'));
      cart.saveForLater(_makeEquipment(id: 'eq2'));
      cart.clear();
      expect(cart.isEmpty, isTrue);
      expect(cart.savedCount, 1);
    });
  });
}
