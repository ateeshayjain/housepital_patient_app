// test/models/cart_item_test.dart
//
// Tests for the flat CartItem model introduced in the cart rewrite.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

void main() {
  // =========================================================================
  // Constructor — all fields
  // =========================================================================
  group('CartItem constructor', () {
    test('constructor with all fields', () {
      const item = CartItem(
        equipmentId: 'eq-001',
        name: 'Oxygen Concentrator',
        brand: 'Philips',
        imageUrl: 'https://example.com/img.jpg',
        unitPrice: 25000,
        mrp: 35000,
        isRental: true,
        rentalMonths: 3,
        quantity: 2,
      );
      expect(item.equipmentId, 'eq-001');
      expect(item.name, 'Oxygen Concentrator');
      expect(item.brand, 'Philips');
      expect(item.imageUrl, 'https://example.com/img.jpg');
      expect(item.unitPrice, 25000);
      expect(item.mrp, 35000);
      expect(item.isRental, isTrue);
      expect(item.rentalMonths, 3);
      expect(item.quantity, 2);
    });

    test('constructor with defaults (quantity=1, isRental=false, rentalMonths=1)', () {
      const item = CartItem(
        equipmentId: 'eq-002',
        name: 'BP Monitor',
        brand: 'Omron',
        unitPrice: 3000,
      );
      expect(item.quantity, 1);
      expect(item.isRental, isFalse);
      expect(item.rentalMonths, 1);
      expect(item.imageUrl, isNull);
      expect(item.mrp, isNull);
    });
  });

  // =========================================================================
  // lineTotal
  // =========================================================================
  group('CartItem lineTotal', () {
    test('lineTotal for buy: unitPrice * quantity', () {
      const item = CartItem(
        equipmentId: 'eq1',
        name: 'Wheelchair',
        brand: 'Karma',
        unitPrice: 8000,
        quantity: 2,
        isRental: false,
      );
      expect(item.lineTotal, 16000);
    });

    test('lineTotal for buy single item', () {
      const item = CartItem(
        equipmentId: 'eq1',
        name: 'Glucometer',
        brand: 'Accu-Chek',
        unitPrice: 1200,
        quantity: 1,
        isRental: false,
      );
      expect(item.lineTotal, 1200);
    });

    test('lineTotal for rental: unitPrice * rentalMonths * quantity', () {
      const item = CartItem(
        equipmentId: 'eq1',
        name: 'Hospital Bed',
        brand: 'Medimek',
        unitPrice: 5000,
        isRental: true,
        rentalMonths: 3,
        quantity: 1,
      );
      expect(item.lineTotal, 15000);
    });

    test('lineTotal for rental with multiple quantity', () {
      const item = CartItem(
        equipmentId: 'eq1',
        name: 'Oxygen Cylinder',
        brand: 'BPL',
        unitPrice: 2000,
        isRental: true,
        rentalMonths: 6,
        quantity: 2,
      );
      // 2000 * 6 * 2 = 24000
      expect(item.lineTotal, 24000);
    });

    test('lineTotal for rental 1 month defaults', () {
      const item = CartItem(
        equipmentId: 'eq1',
        name: 'CPAP Machine',
        brand: 'ResMed',
        unitPrice: 3000,
        isRental: true,
      );
      // 3000 * 1 * 1 = 3000
      expect(item.lineTotal, 3000);
    });

    test('lineTotal is 0 when unitPrice is 0', () {
      const item = CartItem(
        equipmentId: 'eq1',
        name: 'Free Sample',
        brand: 'Generic',
        unitPrice: 0,
        quantity: 5,
      );
      expect(item.lineTotal, 0);
    });
  });

  // =========================================================================
  // copyWith
  // =========================================================================
  group('CartItem copyWith', () {
    test('copyWith creates new instance with changed field', () {
      const original = CartItem(
        equipmentId: 'eq1',
        name: 'Test',
        brand: 'Brand',
        unitPrice: 500,
        quantity: 1,
      );
      final updated = original.copyWith(quantity: 5);
      expect(updated.quantity, 5);
      expect(identical(original, updated), isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      const original = CartItem(
        equipmentId: 'eq-abc',
        name: 'Nebulizer',
        brand: 'Philips',
        imageUrl: 'https://img.com/neb.jpg',
        unitPrice: 2500,
        mrp: 4000,
        isRental: true,
        rentalMonths: 2,
        quantity: 3,
      );
      final updated = original.copyWith(quantity: 10);
      expect(updated.equipmentId, 'eq-abc');
      expect(updated.name, 'Nebulizer');
      expect(updated.brand, 'Philips');
      expect(updated.imageUrl, 'https://img.com/neb.jpg');
      expect(updated.unitPrice, 2500);
      expect(updated.mrp, 4000);
      expect(updated.isRental, isTrue);
      expect(updated.rentalMonths, 2);
      expect(updated.quantity, 10);
    });

    test('copyWith can change rentalMonths', () {
      const original = CartItem(
        equipmentId: 'eq1',
        name: 'Test',
        brand: 'Brand',
        unitPrice: 1000,
        isRental: true,
        rentalMonths: 1,
      );
      final updated = original.copyWith(rentalMonths: 6);
      expect(updated.rentalMonths, 6);
      expect(updated.quantity, 1); // unchanged
    });

    test('copyWith can change both quantity and rentalMonths', () {
      const original = CartItem(
        equipmentId: 'eq1',
        name: 'Test',
        brand: 'Brand',
        unitPrice: 1000,
        isRental: true,
        rentalMonths: 1,
        quantity: 1,
      );
      final updated = original.copyWith(quantity: 3, rentalMonths: 4);
      expect(updated.quantity, 3);
      expect(updated.rentalMonths, 4);
    });
  });

  // =========================================================================
  // toJson
  // =========================================================================
  group('CartItem toJson', () {
    test('toJson includes all fields', () {
      const item = CartItem(
        equipmentId: 'eq-001',
        name: 'Pulse Oximeter',
        brand: 'BPL',
        imageUrl: 'https://img.com/ox.jpg',
        unitPrice: 1500,
        mrp: 2500,
        isRental: false,
        rentalMonths: 1,
        quantity: 2,
      );
      final json = item.toJson();
      expect(json['equipmentId'], 'eq-001');
      expect(json['name'], 'Pulse Oximeter');
      expect(json['brand'], 'BPL');
      expect(json['imageUrl'], 'https://img.com/ox.jpg');
      expect(json['unitPrice'], 1500);
      expect(json['mrp'], 2500);
      expect(json['isRental'], isFalse);
      expect(json['rentalMonths'], 1);
      expect(json['quantity'], 2);
    });

    test('toJson includes null fields (imageUrl, mrp)', () {
      const item = CartItem(
        equipmentId: 'eq1',
        name: 'Test',
        brand: 'Brand',
        unitPrice: 500,
      );
      final json = item.toJson();
      expect(json.containsKey('imageUrl'), isTrue);
      expect(json['imageUrl'], isNull);
      expect(json.containsKey('mrp'), isTrue);
      expect(json['mrp'], isNull);
    });
  });

  // =========================================================================
  // fromJson
  // =========================================================================
  group('CartItem fromJson', () {
    test('fromJson restores all fields', () {
      final json = {
        'equipmentId': 'eq-100',
        'name': 'BiPAP Machine',
        'brand': 'ResMed',
        'imageUrl': 'https://img.com/bipap.jpg',
        'unitPrice': 8000,
        'mrp': 12000,
        'isRental': true,
        'rentalMonths': 6,
        'quantity': 1,
      };
      final item = CartItem.fromJson(json);
      expect(item.equipmentId, 'eq-100');
      expect(item.name, 'BiPAP Machine');
      expect(item.brand, 'ResMed');
      expect(item.imageUrl, 'https://img.com/bipap.jpg');
      expect(item.unitPrice, 8000);
      expect(item.mrp, 12000);
      expect(item.isRental, isTrue);
      expect(item.rentalMonths, 6);
      expect(item.quantity, 1);
    });

    test('fromJson with missing optional fields (imageUrl, mrp)', () {
      final json = {
        'equipmentId': 'eq-200',
        'name': 'Thermometer',
        'brand': 'Omron',
        'unitPrice': 500,
        'isRental': false,
        'rentalMonths': 1,
        'quantity': 1,
      };
      final item = CartItem.fromJson(json);
      expect(item.imageUrl, isNull);
      expect(item.mrp, isNull);
      expect(item.equipmentId, 'eq-200');
      expect(item.name, 'Thermometer');
    });

    test('fromJson with completely missing fields uses defaults', () {
      final json = <String, dynamic>{};
      final item = CartItem.fromJson(json);
      expect(item.equipmentId, '');
      expect(item.name, '');
      expect(item.brand, '');
      expect(item.imageUrl, isNull);
      expect(item.unitPrice, 0);
      expect(item.mrp, isNull);
      expect(item.isRental, isFalse);
      expect(item.rentalMonths, 1);
      expect(item.quantity, 1);
    });
  });

  // =========================================================================
  // fromJson/toJson round-trip
  // =========================================================================
  group('CartItem round-trip serialization', () {
    test('fromJson/toJson round-trip equality', () {
      const original = CartItem(
        equipmentId: 'eq-rt',
        name: 'Suction Machine',
        brand: 'Medela',
        imageUrl: 'https://img.com/suction.png',
        unitPrice: 6000,
        mrp: 9000,
        isRental: true,
        rentalMonths: 4,
        quantity: 2,
      );
      final json = original.toJson();
      final restored = CartItem.fromJson(json);
      expect(restored.equipmentId, original.equipmentId);
      expect(restored.name, original.name);
      expect(restored.brand, original.brand);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.unitPrice, original.unitPrice);
      expect(restored.mrp, original.mrp);
      expect(restored.isRental, original.isRental);
      expect(restored.rentalMonths, original.rentalMonths);
      expect(restored.quantity, original.quantity);
      expect(restored.lineTotal, original.lineTotal);
    });

    test('round-trip with null optional fields', () {
      const original = CartItem(
        equipmentId: 'eq-rt2',
        name: 'Bandage',
        brand: 'Hansaplast',
        unitPrice: 100,
      );
      final json = original.toJson();
      final restored = CartItem.fromJson(json);
      expect(restored.equipmentId, original.equipmentId);
      expect(restored.imageUrl, isNull);
      expect(restored.mrp, isNull);
      expect(restored.isRental, isFalse);
      expect(restored.quantity, 1);
      expect(restored.lineTotal, 100);
    });
  });
}
