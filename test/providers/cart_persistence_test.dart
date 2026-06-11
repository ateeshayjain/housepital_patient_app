// test/providers/cart_persistence_test.dart
//
// Tests cart persistence via SharedPreferences:
// - Items persist after _persist() is called
// - Cart loads from SharedPreferences via loadFromStorage()
// - Saved-for-later items persist separately
// - Corrupt JSON handled gracefully
// - Empty SharedPreferences results in empty cart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/models/models.dart';

// -- Fixture helpers ----------------------------------------------------------

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

/// Helper to build a valid persisted cart JSON string using the new flat format.
Map<String, dynamic> _cartItemJson({
  String equipmentId = 'eq1',
  String name = 'Oxygen Concentrator',
  String brand = 'Philips',
  int unitPrice = 25000,
  bool isRental = false,
  int quantity = 1,
  int rentalMonths = 1,
}) =>
    {
      'equipmentId': equipmentId,
      'name': name,
      'brand': brand,
      'unitPrice': unitPrice,
      'isRental': isRental,
      'quantity': quantity,
      'rentalMonths': rentalMonths,
    };

// -- Tests --------------------------------------------------------------------

void main() {
  // =========================================================================
  // Cart items persist after adding
  // =========================================================================
  group('Cart persistence -- items persist after adding', () {
    test('adding an item persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();

      cart.addItem(_makeEquipment());
      // Flush the async persist without a wall-clock sleep (de-flaked)
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      final cartStr = prefs.getString('housepital_cart_items');
      expect(cartStr, isNotNull);

      final List<dynamic> decoded = json.decode(cartStr!);
      expect(decoded.length, 1);
      expect(decoded[0]['equipmentId'], 'eq1');
      expect(decoded[0]['quantity'], 1);
      expect(decoded[0]['isRental'], false);
    });

    test('updating quantity persists new value', () async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();

      cart.addItem(_makeEquipment());
      cart.updateQuantity(0, 5);
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      final cartStr = prefs.getString('housepital_cart_items');
      final List<dynamic> decoded = json.decode(cartStr!);
      expect(decoded[0]['quantity'], 5);
    });

    test('clearing cart persists empty list', () async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();

      cart.addItem(_makeEquipment());
      cart.clear();
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      final cartStr = prefs.getString('housepital_cart_items');
      final List<dynamic> decoded = json.decode(cartStr!);
      expect(decoded, isEmpty);
    });
  });

  // =========================================================================
  // Cart loads from SharedPreferences via loadFromStorage()
  // =========================================================================
  group('Cart persistence -- loads via loadFromStorage()', () {
    test('cart loads persisted items', () async {
      final cartData = json.encode([
        _cartItemJson(equipmentId: 'eq1', quantity: 3),
      ]);
      SharedPreferences.setMockInitialValues({
        'housepital_cart_items': cartData,
      });

      final cart = CartProvider();
      await cart.loadFromStorage();

      expect(cart.items.length, 1);
      expect(cart.items[0].equipmentId, 'eq1');
      expect(cart.items[0].quantity, 3);
    });

    test('cart loads multiple items from SharedPreferences', () async {
      final cartData = json.encode([
        _cartItemJson(equipmentId: 'eq1', quantity: 2),
        _cartItemJson(
          equipmentId: 'eq2',
          name: 'Wheelchair',
          isRental: true,
          rentalMonths: 3,
          unitPrice: 3000,
        ),
      ]);
      SharedPreferences.setMockInitialValues({
        'housepital_cart_items': cartData,
      });

      final cart = CartProvider();
      await cart.loadFromStorage();

      expect(cart.items.length, 2);
      expect(cart.items[0].equipmentId, 'eq1');
      expect(cart.items[1].equipmentId, 'eq2');
      expect(cart.items[1].isRental, isTrue);
    });
  });

  // =========================================================================
  // Saved-for-later items persist separately
  // =========================================================================
  group('Cart persistence -- saved-for-later persists separately', () {
    test('saved items are stored under a different key', () async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();

      cart.saveItemForLater(_makeEquipment(id: 'eq-saved'));
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('housepital_saved_items');
      expect(savedStr, isNotNull);

      final List<dynamic> decoded = json.decode(savedStr!);
      expect(decoded.length, 1);
      expect(decoded[0]['equipmentId'], 'eq-saved');

      // Cart items should be empty
      final cartStr = prefs.getString('housepital_cart_items');
      final List<dynamic> cartDecoded = json.decode(cartStr!);
      expect(cartDecoded, isEmpty);
    });

    test('saved items load from SharedPreferences via loadFromStorage()', () async {
      final savedData = json.encode([
        _cartItemJson(equipmentId: 'eq-saved'),
      ]);
      SharedPreferences.setMockInitialValues({
        'housepital_saved_items': savedData,
      });

      final cart = CartProvider();
      await cart.loadFromStorage();

      expect(cart.hasSavedItems, isTrue);
      expect(cart.savedCount, 1);
      expect(cart.savedItems[0].equipmentId, 'eq-saved');
      // Cart should be empty
      expect(cart.isEmpty, isTrue);
    });
  });

  // =========================================================================
  // Corrupt JSON is handled gracefully
  // =========================================================================
  group('Cart persistence -- corrupt JSON handling', () {
    test('corrupt cart JSON does not crash -- results in empty cart', () async {
      SharedPreferences.setMockInitialValues({
        'housepital_cart_items': 'this is not valid JSON!!!',
      });

      final cart = CartProvider();
      await cart.loadFromStorage();

      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
    });

    test('corrupt saved JSON does not crash -- no saved items', () async {
      SharedPreferences.setMockInitialValues({
        'housepital_saved_items': '{invalid json[',
      });

      final cart = CartProvider();
      await cart.loadFromStorage();

      expect(cart.hasSavedItems, isFalse);
      expect(cart.savedCount, 0);
    });

    test('partially corrupt cart entry is skipped', () async {
      // One valid entry, one with missing required fields
      final cartData = json.encode([
        _cartItemJson(equipmentId: 'eq1', quantity: 2),
        {'bad': 'entry', 'unitPrice': 'not_an_int'},
      ]);
      SharedPreferences.setMockInitialValues({
        'housepital_cart_items': cartData,
      });

      final cart = CartProvider();
      await cart.loadFromStorage();

      // Should load the valid entry and skip the corrupt one
      expect(cart.items.length, greaterThanOrEqualTo(1));
      expect(cart.items[0].equipmentId, 'eq1');
    });
  });

  // =========================================================================
  // Empty SharedPreferences results in empty cart
  // =========================================================================
  group('Cart persistence -- empty SharedPreferences', () {
    test('no persisted data results in empty cart', () async {
      SharedPreferences.setMockInitialValues({});

      final cart = CartProvider();
      await cart.loadFromStorage();

      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
      expect(cart.hasSavedItems, isFalse);
      expect(cart.savedCount, 0);
    });

    test('missing cart key results in empty cart', () async {
      // Only set an unrelated key -- cart key is absent
      SharedPreferences.setMockInitialValues({
        'some_other_key': 'value',
      });

      final cart = CartProvider();
      await cart.loadFromStorage();

      expect(cart.isEmpty, isTrue);
    });
  });
}
