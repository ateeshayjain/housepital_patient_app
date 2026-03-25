// test/providers/cart_provider_test.dart

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

// -- Tests --------------------------------------------------------------------

void main() {
  late CartProvider cart;

  setUp(() {
    cart = CartProvider();
  });

  // =========================================================================
  // Initial state
  // =========================================================================
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

  // =========================================================================
  // addItem
  // =========================================================================
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
      expect(cart.items[0].quantity, 2);
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
      // Manually add to cart then save, to get it into saved list
      cart.addItem(eq);
      cart.saveForLater(0);
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

  // =========================================================================
  // removeItem
  // =========================================================================
  group('removeItem', () {
    test('removes item by index', () {
      cart.addItem(_makeEquipment());
      expect(cart.itemCount, 1);

      cart.removeItem(0);
      expect(cart.itemCount, 0);
      expect(cart.isEmpty, isTrue);
    });

    test('removing out-of-bounds index is no-op', () {
      cart.addItem(_makeEquipment());
      cart.removeItem(5);
      expect(cart.itemCount, 1);
    });
  });

  // =========================================================================
  // updateQuantity
  // =========================================================================
  group('updateQuantity', () {
    test('updates quantity for existing item', () {
      cart.addItem(_makeEquipment());
      cart.updateQuantity(0, 5);
      expect(cart.items[0].quantity, 5);
    });

    test('setting quantity to 0 removes item', () {
      cart.addItem(_makeEquipment());
      cart.updateQuantity(0, 0);
      expect(cart.isEmpty, isTrue);
    });

    test('negative quantity removes item', () {
      cart.addItem(_makeEquipment());
      cart.updateQuantity(0, -1);
      expect(cart.isEmpty, isTrue);
    });

    test('no-op for out-of-bounds index', () {
      cart.updateQuantity(10, 10);
      expect(cart.isEmpty, isTrue);
    });
  });

  // =========================================================================
  // saveForLater / moveToCart
  // =========================================================================
  group('Save for Later operations', () {
    test('saveForLater adds to saved list and removes from cart', () {
      cart.addItem(_makeEquipment());
      expect(cart.itemCount, 1);

      cart.saveForLater(0);
      expect(cart.isEmpty, isTrue);
      expect(cart.hasSavedItems, isTrue);
      expect(cart.savedCount, 1);
    });

    test('moveToCart moves saved item into cart', () {
      cart.addItem(_makeEquipment());
      cart.saveForLater(0);
      expect(cart.savedCount, 1);

      cart.moveToCart(0);
      expect(cart.itemCount, 1);
      expect(cart.savedCount, 0);
    });

    test('moveToCart with out-of-bounds index is no-op', () {
      cart.moveToCart(5);
      expect(cart.isEmpty, isTrue);
      expect(cart.savedCount, 0);
    });

    test('saveForLater with out-of-bounds index is no-op', () {
      cart.saveForLater(5);
      expect(cart.isEmpty, isTrue);
      expect(cart.savedCount, 0);
    });
  });

  // =========================================================================
  // isInCart / isSaved helpers
  // =========================================================================
  group('isInCart / isSaved helpers', () {
    test('isInCart returns true when item is in cart', () {
      cart.addItem(_makeEquipment(id: 'bp-monitor'));
      expect(cart.isInCart('bp-monitor'), isTrue);
      expect(cart.isInCart('other-item'), isFalse);
    });

    test('isSaved returns true when item is saved for later', () {
      cart.addItem(_makeEquipment(id: 'bp-monitor'));
      cart.saveForLater(0);
      expect(cart.isSaved('bp-monitor'), isTrue);
      expect(cart.isSaved('other-item'), isFalse);
    });
  });

  // =========================================================================
  // Subtotal calculation
  // =========================================================================
  group('Subtotal calculation', () {
    test('purchase: subtotal = price * quantity', () {
      cart.addItem(_makeEquipment(price: 5000));
      expect(cart.subtotal, 5000);

      cart.updateQuantity(0, 3);
      expect(cart.subtotal, 15000);
    });

    test('rental: subtotal = rentalPrice * months * quantity', () {
      cart.addItem(_makeEquipment(rentalPrice: 2000), isRental: true, rentalMonths: 3);
      // 2000 * 3 * 1 = 6000
      expect(cart.subtotal, 6000);
    });

    test('mixed cart: purchase + rental', () {
      cart.addItem(_makeEquipment(id: 'eq1', price: 5000), isRental: false);
      cart.addItem(_makeEquipment(id: 'eq2', rentalPrice: 2000), isRental: true, rentalMonths: 2);
      // 5000 + (2000 * 2 * 1) = 9000
      expect(cart.subtotal, 9000);
    });
  });

  // =========================================================================
  // Delivery charge
  // =========================================================================
  group('Delivery charge', () {
    test('49 delivery when subtotal < 999', () {
      cart.addItem(_makeEquipment(price: 500));
      expect(cart.deliveryCharge, 49);
    });

    test('free delivery when subtotal >= 999', () {
      cart.addItem(_makeEquipment(price: 999));
      expect(cart.deliveryCharge, 0);
    });

    test('free delivery when subtotal = 1000', () {
      cart.addItem(_makeEquipment(price: 1000));
      expect(cart.deliveryCharge, 0);
    });

    test('free delivery for large orders', () {
      cart.addItem(_makeEquipment(price: 25000));
      expect(cart.deliveryCharge, 0);
    });
  });

  // =========================================================================
  // Total = subtotal + delivery
  // =========================================================================
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

  // =========================================================================
  // clear
  // =========================================================================
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
      cart.addItem(_makeEquipment(id: 'eq2'));
      cart.saveForLater(1); // save eq2
      cart.clear();
      expect(cart.isEmpty, isTrue);
      expect(cart.savedCount, 1);
    });
  });

  // =========================================================================
  // CartItem model
  // =========================================================================
  group('CartItem model', () {
    test('lineTotal for purchase = unitPrice * quantity', () {
      const item = CartItem(
        equipmentId: 'eq1', name: 'Test', brand: 'Brand',
        unitPrice: 500, quantity: 3,
      );
      expect(item.lineTotal, 1500);
    });

    test('lineTotal for rental = unitPrice * rentalMonths * quantity', () {
      const item = CartItem(
        equipmentId: 'eq1', name: 'Test', brand: 'Brand',
        unitPrice: 2000, isRental: true, rentalMonths: 3, quantity: 2,
      );
      expect(item.lineTotal, 12000);
    });

    test('copyWith preserves fields', () {
      const item = CartItem(
        equipmentId: 'eq1', name: 'Test', brand: 'Brand',
        unitPrice: 500, isRental: true, rentalMonths: 2, quantity: 1,
      );
      final updated = item.copyWith(quantity: 5, rentalMonths: 6);
      expect(updated.quantity, 5);
      expect(updated.rentalMonths, 6);
      expect(updated.equipmentId, 'eq1');
      expect(updated.unitPrice, 500);
    });

    test('toJson/fromJson round-trip', () {
      const item = CartItem(
        equipmentId: 'eq1', name: 'Oxygen Concentrator', brand: 'Philips',
        imageUrl: 'https://example.com/img.jpg',
        unitPrice: 3000, mrp: 5000,
        isRental: true, rentalMonths: 3, quantity: 2,
      );
      final json = item.toJson();
      final restored = CartItem.fromJson(json);
      expect(restored.equipmentId, item.equipmentId);
      expect(restored.name, item.name);
      expect(restored.brand, item.brand);
      expect(restored.imageUrl, item.imageUrl);
      expect(restored.unitPrice, item.unitPrice);
      expect(restored.mrp, item.mrp);
      expect(restored.isRental, item.isRental);
      expect(restored.rentalMonths, item.rentalMonths);
      expect(restored.quantity, item.quantity);
      expect(restored.lineTotal, item.lineTotal);
    });
  });
}
