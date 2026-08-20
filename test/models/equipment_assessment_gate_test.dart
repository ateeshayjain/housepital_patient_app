// test/models/equipment_assessment_gate_test.dart
//
// `EquipmentItem.needsAssessment` decided whether a family can put a
// life-support device in a cart without a Housepital clinician seeing it
// first. Round 4 found it exactly inverted: its first line exempted every
// rentable item, and in this catalog every ventilator, BiPAP, CPAP, oxygen
// concentrator, suction machine and pump is rentable. What it DID gate was
// the rent=false remainder — BiPAP masks.
//
// These tests are written against product names taken verbatim from
// assets/equipment_catalog.json, so they fail if the rule stops matching real
// stock rather than only if it stops matching a hypothetical.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

EquipmentItem item(String name,
        {bool rent = true, bool sale = true, bool? override}) =>
    EquipmentItem(
      id: name,
      name: name,
      brand: 'Generic',
      category: 'Equipment',
      availableForRent: rent,
      availableForSale: sale,
      requiresAssessment: override,
    );

void main() {
  group('regulated devices need an assessment however they are supplied', () {
    // Every one of these is available_for_rent: true in the shipped catalog,
    // which is precisely why the old `if (availableForRent) return false`
    // cleared all of them.
    const names = <String>[
      'Stellar 100 Ventilator',
      'Stellar 150 Ventilator G2',
      'Floton ST25 Ventilation System',
      'BiPAP Machine',
      'DreamStation Auto BiPAP',
      'Nidek Bipap',
      'Airsense 10 Autoset CPAP',
      'Oxygen Concentrator 5L',
      'Oxygen Concentrator 10L',
      'Drive Devilbiss Oxygen Concentrator 5L',
      'Oxygen Concentrator Yu 300',
      'Suction Machine Electric',
      'Syringe Pump Acura S1',
      'Infusion Pump',
    ];

    for (final n in names) {
      test('"$n" is gated when rentable', () {
        expect(item(n, rent: true).needsAssessment, isTrue,
            reason: 'renting a ventilator does not make it safer than buying');
      });
      test('"$n" is gated when bought outright', () {
        expect(item(n, rent: false).needsAssessment, isTrue);
      });
    }
  });

  group('accessories for an already-prescribed device are not gated', () {
    // These are what the OLD rule actually caught. Requiring a clinical
    // assessment to reorder a mask is friction with no safety return.
    const names = <String>[
      'BiPAP Mask (M)',
      'BiPAP Mask (L) Vented',
      'BiPAP Mask (S) Non-Vented',
      'CPAP NOSE MASK',
      'Suction Connector',
      'Suction Jar',
      'Oxygen Mask',
    ];

    for (final n in names) {
      test('"$n" is NOT gated', () {
        expect(item(n, rent: false).needsAssessment, isFalse);
      });
    }
  });

  group('unrelated stock is untouched', () {
    for (final n in const ['Wheelchair', 'Air Bed Mattress', '3 Ply Mask']) {
      test('"$n" is not gated', () {
        expect(item(n).needsAssessment, isFalse);
      });
    }
  });

  group('the CRM has the final word', () {
    test('an explicit true gates something the name rule would not', () {
      expect(item('Wheelchair', override: true).needsAssessment, isTrue);
    });

    test('an explicit false releases something the name rule would gate', () {
      expect(item('BiPAP Machine', override: false).needsAssessment, isFalse);
    });

    test('null means "not stated" and defers to the name rule', () {
      expect(item('BiPAP Machine', override: null).needsAssessment, isTrue);
    });

    test('the override survives a JSON round trip', () {
      final round = EquipmentItem.fromJson(
          item('Wheelchair', override: true).toJson());
      expect(round.requiresAssessment, isTrue);
      expect(round.needsAssessment, isTrue);
    });

    test('a catalog entry with no requires_assessment key stays null', () {
      final e = EquipmentItem.fromJson(const {
        'id': 'x',
        'name': 'BiPAP Machine',
        'brand': 'b',
        'category': 'Equipment',
      });
      expect(e.requiresAssessment, isNull);
      expect(e.needsAssessment, isTrue, reason: 'falls back, fails closed');
    });
  });
}
