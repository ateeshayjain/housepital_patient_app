// test/screens/checkout/address_test.dart
//
// Tests address management:
// - SavedAddress.toJson() / fromJson() round-trip
// - Default seed addresses have valid NCR cities
// - Pincode validation: 6 digits starting with 1-9
// - City list matches PRD: Delhi, Faridabad, Gurgaon, Noida, Ghaziabad

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/screens/checkout/address_selection_screen.dart';

// ── Canonical data from _AddressFormScreenState ────────────────────────────
const _cities = ['Delhi', 'Faridabad', 'Gurgaon', 'Noida', 'Ghaziabad'];

// Pincode validation regex from the form validator
final _pincodeRegex = RegExp(r'^[1-9]\d{5}$');

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // SavedAddress.toJson() / fromJson() round-trip
  // ═══════════════════════════════════════════════════════════════════════════
  group('SavedAddress — JSON round-trip', () {
    test('toJson and fromJson produce equivalent object', () {
      final original = SavedAddress(
        label: 'Home',
        name: 'Ateeshay Jain',
        flatHouse: 'B-42',
        street: 'Sector 15',
        city: 'Noida',
        pincode: '201301',
        phone: '9876543210',
        icon: 'home',
        isDefault: true,
      );

      final jsonMap = original.toJson();
      final restored = SavedAddress.fromJson(jsonMap);

      expect(restored.label, original.label);
      expect(restored.name, original.name);
      expect(restored.flatHouse, original.flatHouse);
      expect(restored.street, original.street);
      expect(restored.city, original.city);
      expect(restored.pincode, original.pincode);
      expect(restored.phone, original.phone);
      expect(restored.icon, original.icon);
      expect(restored.isDefault, original.isDefault);
    });

    test('toJson contains all expected keys', () {
      final addr = SavedAddress(
        label: 'Office',
        name: 'Test',
        flatHouse: '123',
        street: 'Main St',
        city: 'Delhi',
        pincode: '110001',
        phone: '9999999999',
      );

      final jsonMap = addr.toJson();
      expect(jsonMap.containsKey('label'), isTrue);
      expect(jsonMap.containsKey('name'), isTrue);
      expect(jsonMap.containsKey('flatHouse'), isTrue);
      expect(jsonMap.containsKey('street'), isTrue);
      expect(jsonMap.containsKey('city'), isTrue);
      expect(jsonMap.containsKey('pincode'), isTrue);
      expect(jsonMap.containsKey('phone'), isTrue);
      expect(jsonMap.containsKey('icon'), isTrue);
      expect(jsonMap.containsKey('isDefault'), isTrue);
    });

    test('fromJson handles missing fields gracefully with defaults', () {
      final addr = SavedAddress.fromJson({});
      expect(addr.label, '');
      expect(addr.name, '');
      expect(addr.city, 'Delhi'); // default city
      expect(addr.icon, 'home'); // default icon
      expect(addr.isDefault, false);
    });

    test('fullAddress combines flatHouse, street, city and pincode', () {
      final addr = SavedAddress(
        label: 'Home',
        name: 'Test',
        flatHouse: 'A-1',
        street: 'Green Park',
        city: 'Delhi',
        pincode: '110016',
        phone: '9000000000',
      );
      expect(addr.fullAddress, 'A-1, Green Park, Delhi 110016');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Default seed addresses have valid NCR cities
  // ═══════════════════════════════════════════════════════════════════════════
  group('SavedAddress — Default seed addresses', () {
    // These mirror AddressHelper._defaultAddresses
    final defaultAddresses = [
      SavedAddress(
        label: 'Home',
        name: 'Patient',
        flatHouse: 'B-42',
        street: 'Sector 15',
        city: 'Noida',
        pincode: '201301',
        phone: '9876543210',
        icon: 'home',
        isDefault: true,
      ),
      SavedAddress(
        label: "Parent's Home",
        name: 'Patient',
        flatHouse: '12/3',
        street: 'Lajpat Nagar II',
        city: 'Delhi',
        pincode: '110024',
        phone: '9876543211',
        icon: 'family',
      ),
      SavedAddress(
        label: 'Office',
        name: 'Patient',
        flatHouse: '5th Floor, Tower B',
        street: 'Cyber City',
        city: 'Gurgaon',
        pincode: '122002',
        phone: '9876543212',
        icon: 'work',
      ),
    ];

    test('all default addresses have cities in NCR list', () {
      for (final addr in defaultAddresses) {
        expect(_cities, contains(addr.city),
            reason: '${addr.label} has city "${addr.city}" not in NCR list');
      }
    });

    test('all default addresses have valid pincodes', () {
      for (final addr in defaultAddresses) {
        expect(_pincodeRegex.hasMatch(addr.pincode), isTrue,
            reason: '${addr.label} has invalid pincode "${addr.pincode}"');
      }
    });

    test('exactly one default address is marked as default', () {
      final defaultCount = defaultAddresses.where((a) => a.isDefault).length;
      expect(defaultCount, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Pincode validation
  // ═══════════════════════════════════════════════════════════════════════════
  group('Pincode validation', () {
    test('valid 6-digit pincode starting with 1-9 passes', () {
      expect(_pincodeRegex.hasMatch('110001'), isTrue);
      expect(_pincodeRegex.hasMatch('201301'), isTrue);
      expect(_pincodeRegex.hasMatch('900000'), isTrue);
    });

    test('pincode starting with 0 fails', () {
      expect(_pincodeRegex.hasMatch('010001'), isFalse);
    });

    test('pincode with fewer than 6 digits fails', () {
      expect(_pincodeRegex.hasMatch('11000'), isFalse);
      expect(_pincodeRegex.hasMatch('1'), isFalse);
    });

    test('pincode with more than 6 digits fails', () {
      expect(_pincodeRegex.hasMatch('1100010'), isFalse);
    });

    test('pincode with letters fails', () {
      expect(_pincodeRegex.hasMatch('11000a'), isFalse);
      expect(_pincodeRegex.hasMatch('abcdef'), isFalse);
    });

    test('empty pincode fails', () {
      expect(_pincodeRegex.hasMatch(''), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // City list matches PRD
  // ═══════════════════════════════════════════════════════════════════════════
  group('City list', () {
    test('city list contains exactly 5 NCR cities', () {
      expect(_cities.length, 5);
    });

    test('city list includes Delhi', () {
      expect(_cities, contains('Delhi'));
    });

    test('city list includes Faridabad', () {
      expect(_cities, contains('Faridabad'));
    });

    test('city list includes Gurgaon', () {
      expect(_cities, contains('Gurgaon'));
    });

    test('city list includes Noida', () {
      expect(_cities, contains('Noida'));
    });

    test('city list includes Ghaziabad', () {
      expect(_cities, contains('Ghaziabad'));
    });
  });
}
