// test/providers/cart_persistence_test.dart
//
// Tests cart persistence via SharedPreferences:
// - Items persist after _persistCart()
// - Cart loads from SharedPreferences on construction
// - Saved-for-later items persist separately
// - Corrupt JSON handled gracefully
// - Empty SharedPreferences results in empty cart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Helper to build a valid persisted cart JSON string.
String _buildCartJson(List<Map<String, dynamic>> items) => json.encode(items);

Map<String, dynamic> _cartEntryJson({
  String key = 'eq1_buy',
  String id = 'eq1',
  String name = 'Oxygen Concentrator',
  double? price = 25000,
  double? rentalPrice = 3000,
  bool isRental = false,
  int quantity = 1,
  int rentalMonths = 1,
}) =>
    {
      'key': key,
      'item': {
        'id': id,
        'name': name,
        'brand': 'Philips',
        'category': 'Equipment',
        'available_for_sale': true,
        'available_for_rent': true,
        'price': price,
        'rental_price': rentalPrice,
        'status': 'Active',
      },
      'isRental': isRental,
      'quantity': quantity,
      'rentalMonths': rentalMonths,
    };

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Cart items persist after _persistCart() is called
  // ═══════════════════════════════════════════════════════════════════════════
  group('Cart persistence — items persist after adding', () {
    test('adding an item persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();

      cart.addItem(_makeEquipment());
      // Wait for async persist to complete
      await Future.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      final cartStr = prefs.getString('housepital_cart_items');
      expect(cartStr, isNotNull);

      final List<dynamic> decoded = json.decode(cartStr!);
      expect(decoded.length, 1);
      expect(decoded[0]['key'], 'eq1_buy');
      expect(decoded[0]['quantity'], 1);
    });

    test('updating quantity persists new value', () async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();

      cart.addItem(_makeEquipment());
      cart.updateQuantity('eq1_buy', 5);
      await Future.delayed(const Duration(milliseconds: 100));

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
      await Future.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      final cartStr = prefs.getString('housepital_cart_items');
      final List<dynamic> decoded = json.decode(cartStr!);
      expect(decoded, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Cart loads from SharedPreferences on construction
  // ═══════════════════════════════════════════════════════════════════════════
  group('Cart persistence — loads on construction', () {
    test('cart loads persisted items on construction', () async {
      final cartData = _buildCartJson([
        _cartEntryJson(key: 'eq1_buy', quantity: 3),
      ]);
      SharedPreferences.setMockInitialValues({
        'housepital_cart_items': cartData,
      });

      final cart = CartProvider();
      // Wait for async load
      await Future.delayed(const Duration(milliseconds: 100));

      expect(cart.items.length, 1);
      expect(cart.items['eq1_buy']!.quantity, 3);
      expect(cart.itemCount, 3);
    });

    test('cart loads multiple items from SharedPreferences', () async {
      final cartData = _buildCartJson([
        _cartEntryJson(key: 'eq1_buy', id: 'eq1', quantity: 2),
        _cartEntryJson(
          key: 'eq2_rent',
          id: 'eq2',
          name: 'Wheelchair',
          isRental: true,
          rentalMonths: 3,
        ),
      ]);
      SharedPreferences.setMockInitialValues({
        'housepital_cart_items': cartData,
      });

      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(cart.items.length, 2);
      expect(cart.items.containsKey('eq1_buy'), isTrue);
      expect(cart.items.containsKey('eq2_rent'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Saved-for-later items persist separately
  // ═══════════════════════════════════════════════════════════════════════════
  group('Cart persistence — saved-for-later persists separately', () {
    test('saved items are stored under a different key', () async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();

      cart.saveForLater(_makeEquipment(id: 'eq-saved'));
      await Future.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('housepital_saved_items');
      expect(savedStr, isNotNull);

      final List<dynamic> decoded = json.decode(savedStr!);
      expect(decoded.length, 1);
      expect(decoded[0]['key'], 'eq-saved_buy');

      // Cart items should be empty
      final cartStr = prefs.getString('housepital_cart_items');
      final List<dynamic> cartDecoded = json.decode(cartStr!);
      expect(cartDecoded, isEmpty);
    });

    test('saved items load from SharedPreferences on construction', () async {
      final savedData = _buildCartJson([
        _cartEntryJson(key: 'eq-saved_buy', id: 'eq-saved'),
      ]);
      SharedPreferences.setMockInitialValues({
        'housepital_saved_items': savedData,
      });

      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(cart.hasSavedItems, isTrue);
      expect(cart.savedCount, 1);
      expect(cart.savedForLater.containsKey('eq-saved_buy'), isTrue);
      // Cart should be empty
      expect(cart.isEmpty, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Corrupt JSON is handled gracefully
  // ═══════════════════════════════════════════════════════════════════════════
  group('Cart persistence — corrupt JSON handling', () {
    test('corrupt cart JSON does not crash — results in empty cart', () async {
      SharedPreferences.setMockInitialValues({
        'housepital_cart_items': 'this is not valid JSON!!!',
      });

      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
    });

    test('corrupt saved JSON does not crash — no saved items', () async {
      SharedPreferences.setMockInitialValues({
        'housepital_saved_items': '{invalid json[',
      });

      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(cart.hasSavedItems, isFalse);
      expect(cart.savedCount, 0);
    });

    test('partially corrupt cart entry is skipped', () async {
      // One valid entry, one with missing 'item' field
      final cartData = json.encode([
        _cartEntryJson(key: 'eq1_buy', quantity: 2),
        {'key': 'bad_entry', 'item': 'not_a_map', 'isRental': false},
      ]);
      SharedPreferences.setMockInitialValues({
        'housepital_cart_items': cartData,
      });

      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Should load the valid entry and skip the corrupt one
      expect(cart.items.length, 1);
      expect(cart.items.containsKey('eq1_buy'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Empty SharedPreferences results in empty cart
  // ═══════════════════════════════════════════════════════════════════════════
  group('Cart persistence — empty SharedPreferences', () {
    test('no persisted data results in empty cart', () async {
      SharedPreferences.setMockInitialValues({});

      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
      expect(cart.hasSavedItems, isFalse);
      expect(cart.savedCount, 0);
    });

    test('missing cart key results in empty cart', () async {
      // Only set an unrelated key — cart key is absent
      SharedPreferences.setMockInitialValues({
        'some_other_key': 'value',
      });

      final cart = CartProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(cart.isEmpty, isTrue);
    });
  });
}
