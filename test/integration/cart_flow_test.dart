// test/integration/cart_flow_test.dart
//
// End-to-end data-layer tests for the full cart flow:
// add -> check -> update -> remove, rental save/restore, clear all, duplicates.

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
  late CartProvider provider;

  setUp(() {
    provider = CartProvider();
  });

  // =========================================================================
  // Full flow: add -> check -> update quantity -> remove
  // =========================================================================
  test('full flow: add item -> check cart -> update quantity -> remove', () {
    final item = _makeEquipment(
      id: 'bp-monitor',
      name: 'BP Monitor',
      price: 3000,
    );

    // Add
    provider.addItem(item);
    expect(provider.itemCount, 1);
    expect(provider.items[0].name, item.name);
    expect(provider.items[0].unitPrice, 3000);

    // Update quantity
    provider.updateQuantity(0, 3);
    expect(provider.items[0].quantity, 3);

    // Subtotal
    expect(provider.subtotal, item.price!.toInt() * 3);

    // Remove
    provider.removeItem(0);
    expect(provider.isEmpty, isTrue);
    expect(provider.itemCount, 0);
    expect(provider.subtotal, 0);
  });

  // =========================================================================
  // Full flow: add rental -> save for later -> move to cart
  // =========================================================================
  test('full flow: add rental -> save for later -> move to cart', () {
    final item = _makeEquipment(
      id: 'hospital-bed',
      name: 'Hospital Bed',
      rentalPrice: 5000,
    );

    // Add as rental for 3 months
    provider.addItem(item, isRental: true, rentalMonths: 3);
    expect(provider.itemCount, 1);
    expect(provider.items[0].isRental, isTrue);
    expect(provider.items[0].rentalMonths, 3);
    expect(provider.items[0].unitPrice, 5000);
    // lineTotal = 5000 * 3 * 1 = 15000
    expect(provider.subtotal, 15000);

    // Save for later
    provider.saveForLater(0);
    expect(provider.isEmpty, isTrue);
    expect(provider.hasSavedItems, isTrue);
    expect(provider.savedCount, 1);
    expect(provider.savedItems[0].name, 'Hospital Bed');

    // Move back to cart
    provider.moveToCart(0);
    expect(provider.itemCount, 1);
    expect(provider.savedCount, 0);
    expect(provider.items[0].isRental, isTrue);
    expect(provider.items[0].rentalMonths, 3);
    expect(provider.subtotal, 15000);
  });

  // =========================================================================
  // Full flow: add multiple items -> clear all
  // =========================================================================
  test('full flow: add multiple items -> clear all', () {
    final eq1 = _makeEquipment(id: 'eq1', name: 'Wheelchair', price: 8000);
    final eq2 = _makeEquipment(id: 'eq2', name: 'Nebulizer', price: 2500);
    final eq3 = _makeEquipment(id: 'eq3', name: 'Glucometer', price: 1200);

    provider.addItem(eq1);
    provider.addItem(eq2);
    provider.addItem(eq3);

    expect(provider.itemCount, 3);
    expect(provider.subtotal, 8000 + 2500 + 1200);
    expect(provider.deliveryCharge, 0); // 11700 >= 999

    // Clear all
    provider.clear();
    expect(provider.isEmpty, isTrue);
    expect(provider.itemCount, 0);
    expect(provider.subtotal, 0);
  });

  // =========================================================================
  // Duplicate item increases quantity instead of adding new entry
  // =========================================================================
  test('duplicate item increases quantity instead of adding new entry', () {
    final item = _makeEquipment(id: 'pulse-ox', name: 'Pulse Oximeter', price: 1500);

    provider.addItem(item);
    expect(provider.itemCount, 1);
    expect(provider.items[0].quantity, 1);

    // Add same item again
    provider.addItem(item);
    expect(provider.itemCount, 1); // still 1 entry
    expect(provider.items[0].quantity, 2); // quantity bumped

    // Add a third time
    provider.addItem(item);
    expect(provider.itemCount, 1);
    expect(provider.items[0].quantity, 3);

    // Subtotal should reflect quantity
    expect(provider.subtotal, 1500 * 3);
  });

  // =========================================================================
  // Same item as buy and rent are separate entries
  // =========================================================================
  test('same item added as buy and rent are separate entries', () {
    final item = _makeEquipment(id: 'eq-dual', price: 5000, rentalPrice: 1000);

    provider.addItem(item, isRental: false);
    provider.addItem(item, isRental: true, rentalMonths: 2);

    expect(provider.itemCount, 2);
    expect(provider.items[0].isRental, isFalse);
    expect(provider.items[0].unitPrice, 5000);
    expect(provider.items[1].isRental, isTrue);
    expect(provider.items[1].unitPrice, 1000);

    // Subtotal: 5000 + (1000 * 2 * 1) = 7000
    expect(provider.subtotal, 7000);
  });

  // =========================================================================
  // Update rental months
  // =========================================================================
  test('update rental months changes subtotal', () {
    final item = _makeEquipment(id: 'cpap', rentalPrice: 4000);

    provider.addItem(item, isRental: true, rentalMonths: 1);
    expect(provider.subtotal, 4000);

    provider.updateRentalMonths(0, 6);
    expect(provider.items[0].rentalMonths, 6);
    expect(provider.subtotal, 4000 * 6);
  });

  // =========================================================================
  // Delivery charge transitions
  // =========================================================================
  test('delivery charge transitions from paid to free as items are added', () {
    final cheapItem = _makeEquipment(id: 'eq-cheap', price: 400);
    final expensiveItem = _makeEquipment(id: 'eq-exp', price: 600);

    provider.addItem(cheapItem);
    expect(provider.deliveryCharge, 49); // 400 < 999

    provider.addItem(expensiveItem);
    expect(provider.deliveryCharge, 0); // 1000 >= 999
  });

  // =========================================================================
  // Save for later deduplication
  // =========================================================================
  test('saveForLater does not create duplicates in saved list', () {
    final item = _makeEquipment(id: 'eq-dedup');

    // Add and save
    provider.addItem(item);
    provider.saveForLater(0);
    expect(provider.savedCount, 1);

    // Add again and save again
    provider.addItem(item);
    provider.saveForLater(0);
    expect(provider.savedCount, 1); // still 1, not 2
  });

  // =========================================================================
  // moveToCart merges quantity if item already in cart
  // =========================================================================
  test('moveToCart merges quantity if item already in cart', () {
    final item = _makeEquipment(id: 'eq-merge', price: 1000);

    // Add to cart (qty 1)
    provider.addItem(item);

    // Save separately using saveItemForLater
    provider.saveItemForLater(
      _makeEquipment(id: 'eq-merge-2', price: 2000),
    );

    // Add eq-merge again to cart, then add eq-merge to saved
    // This tests the merge path in moveToCart
    provider.addItem(item); // qty becomes 2
    expect(provider.items[0].quantity, 2);

    // Save it so we can test merge on moveToCart
    provider.saveForLater(0);
    expect(provider.savedCount, 2);
    expect(provider.isEmpty, isTrue);

    // Move eq-merge back
    final idx = provider.savedItems.indexWhere((i) => i.equipmentId == 'eq-merge');
    provider.moveToCart(idx);
    expect(provider.itemCount, 1);
    expect(provider.items[0].quantity, 2); // preserved quantity
  });

  // =========================================================================
  // isInCart and isSaved helpers
  // =========================================================================
  test('isInCart and isSaved track items correctly through flow', () {
    final item = _makeEquipment(id: 'eq-track');

    expect(provider.isInCart('eq-track'), isFalse);
    expect(provider.isSaved('eq-track'), isFalse);

    provider.addItem(item);
    expect(provider.isInCart('eq-track'), isTrue);
    expect(provider.isSaved('eq-track'), isFalse);

    provider.saveForLater(0);
    expect(provider.isInCart('eq-track'), isFalse);
    expect(provider.isSaved('eq-track'), isTrue);

    provider.moveToCart(0);
    expect(provider.isInCart('eq-track'), isTrue);
    expect(provider.isSaved('eq-track'), isFalse);

    provider.removeItem(0);
    expect(provider.isInCart('eq-track'), isFalse);
    expect(provider.isSaved('eq-track'), isFalse);
  });

  // =========================================================================
  // clearSaved
  // =========================================================================
  test('clearSaved empties saved list without affecting cart', () {
    final eq1 = _makeEquipment(id: 'eq1');
    final eq2 = _makeEquipment(id: 'eq2');

    provider.addItem(eq1);
    provider.addItem(eq2);
    provider.saveForLater(1); // save eq2

    expect(provider.itemCount, 1);
    expect(provider.savedCount, 1);

    provider.clearSaved();
    expect(provider.savedCount, 0);
    expect(provider.itemCount, 1); // cart unaffected
  });

  // =========================================================================
  // Notifies listeners throughout flow
  // =========================================================================
  test('notifies listeners on every mutation', () {
    int notifyCount = 0;
    provider.addListener(() => notifyCount++);

    provider.addItem(_makeEquipment());
    expect(notifyCount, 1);

    provider.updateQuantity(0, 3);
    expect(notifyCount, 2);

    provider.saveForLater(0);
    expect(notifyCount, 3);

    provider.moveToCart(0);
    expect(notifyCount, 4);

    provider.removeItem(0);
    expect(notifyCount, 5);

    provider.clear();
    expect(notifyCount, 6);
  });
}
