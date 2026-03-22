// test/screens/services/assessment_form_test.dart
//
// Tests static data integrity for the assessment request form and the
// service booking form. Since these lists are private static fields inside
// State classes, we replicate the canonical data here and verify invariants.

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Canonical data — replicated from assessment_request_screen.dart
// ---------------------------------------------------------------------------

const _basicCareNeeds = [
  'Bathing',
  'Feeding',
  'Medication reminders',
  'Walking support',
  'Diaper changing',
  'Companionship',
];

const _advancedCareNeeds = [
  'Wound dressing',
  'Injection (IV/IM)',
  'Catheter care',
  'RT feeding',
  'Sugar & BP monitoring',
  'Oxygen support',
];

const _criticalCareNeeds = [
  'Tracheostomy care',
  'Ventilator management',
  'Suctioning',
  'Bed sore care',
  'Post-ICU monitoring',
  'Central line care',
];

// Nurse level recommendation logic (replicated from _recommendedNurseLevel getter)
String recommendNurseLevel(Set<String> selectedNeeds) {
  if (selectedNeeds.any((n) => _criticalCareNeeds.contains(n))) {
    return 'critical';
  }
  if (selectedNeeds.any((n) => _advancedCareNeeds.contains(n))) {
    return 'advanced';
  }
  return 'basic';
}

// ---------------------------------------------------------------------------
// Canonical data — replicated from service_booking_screen.dart
// ---------------------------------------------------------------------------

const List<Map<String, String>> _ivInfusionTypes = [
  {'id': 'iv_push', 'label': 'Single IV Push', 'desc': 'Single medication push (~30 min)', 'level': 'basic', 'price': '900'},
  {'id': 'iv_drip_short', 'label': 'IV Drip — Short', 'desc': 'Hydration, antibiotics (1-2 hrs)', 'level': 'advanced', 'price': '1200'},
  {'id': 'iv_drip_extended', 'label': 'IV Drip — Extended', 'desc': 'Extended infusion (3-4 hrs)', 'level': 'advanced', 'price': '1200'},
  {'id': 'iv_multiple', 'label': 'Multiple IV Medications', 'desc': '2+ meds in one visit (2-4 hrs)', 'level': 'advanced', 'price': '1200'},
  {'id': 'iv_prolonged', 'label': 'Prolonged Infusion', 'desc': 'Iron, chemo supportive — up to 8 hrs', 'level': 'critical', 'price': '1500'},
  {'id': 'iv_central_line', 'label': 'Central Line / PICC Access', 'desc': 'Requires central line management', 'level': 'critical', 'price': '1500'},
];

const List<Map<String, String>> _concernCategories = [
  {'id': 'fever', 'label': 'Fever / Cold / Flu', 'type': 'gp'},
  {'id': 'bp_sugar', 'label': 'BP / Sugar / Thyroid check-up', 'type': 'gp'},
  {'id': 'stomach', 'label': 'Stomach / Digestion issues', 'type': 'gp'},
  {'id': 'skin', 'label': 'Skin / Allergy / Infection', 'type': 'gp'},
  {'id': 'pain', 'label': 'Body pain / Joint pain', 'type': 'gp'},
  {'id': 'elderly', 'label': 'Elderly general check-up', 'type': 'gp'},
  {'id': 'post_surgery', 'label': 'Post-surgery / Post-discharge follow-up', 'type': 'icu'},
  {'id': 'ventilator', 'label': 'Ventilator / Tracheostomy patient', 'type': 'icu'},
  {'id': 'icu_home', 'label': 'ICU-at-home patient review', 'type': 'icu'},
  {'id': 'critical', 'label': 'Critical care / Bed-ridden patient', 'type': 'icu'},
  {'id': 'medication', 'label': 'Medication review / Adjustment', 'type': 'gp'},
  {'id': 'other', 'label': 'Other', 'type': 'gp'},
];

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Care needs lists are non-empty
  // =========================================================================
  group('Assessment form — care needs lists', () {
    test('basicCareNeeds is non-empty', () {
      expect(_basicCareNeeds, isNotEmpty);
    });

    test('advancedCareNeeds is non-empty', () {
      expect(_advancedCareNeeds, isNotEmpty);
    });

    test('criticalCareNeeds is non-empty', () {
      expect(_criticalCareNeeds, isNotEmpty);
    });

    test('all three care need lists have at least 5 items', () {
      expect(_basicCareNeeds.length, greaterThanOrEqualTo(5));
      expect(_advancedCareNeeds.length, greaterThanOrEqualTo(5));
      expect(_criticalCareNeeds.length, greaterThanOrEqualTo(5));
    });

    test('no duplicate care needs across all three lists', () {
      final all = [..._basicCareNeeds, ..._advancedCareNeeds, ..._criticalCareNeeds];
      expect(all.toSet().length, all.length,
          reason: 'Duplicate care needs found across lists');
    });

    test('no empty strings in care needs', () {
      final all = [..._basicCareNeeds, ..._advancedCareNeeds, ..._criticalCareNeeds];
      for (final item in all) {
        expect(item.trim(), isNotEmpty, reason: 'Empty care need found');
      }
    });
  });

  // =========================================================================
  // Nurse level recommendation logic
  // =========================================================================
  group('Assessment form — nurse level recommendation', () {
    test('returns "basic" when only basic needs selected', () {
      expect(recommendNurseLevel({'Bathing', 'Feeding'}), 'basic');
    });

    test('returns "advanced" when advanced need selected', () {
      expect(recommendNurseLevel({'Bathing', 'Wound dressing'}), 'advanced');
    });

    test('returns "critical" when critical need selected', () {
      expect(recommendNurseLevel({'Feeding', 'Ventilator management'}), 'critical');
    });

    test('critical overrides advanced', () {
      expect(
        recommendNurseLevel({'Wound dressing', 'Tracheostomy care'}),
        'critical',
      );
    });

    test('returns "basic" when no needs selected', () {
      expect(recommendNurseLevel({}), 'basic');
    });

    test('returns "basic" for unknown care need', () {
      expect(recommendNurseLevel({'Something custom'}), 'basic');
    });
  });

  // =========================================================================
  // IV infusion types
  // =========================================================================
  group('Service booking — IV infusion types', () {
    test('all IV types have required keys', () {
      for (final type in _ivInfusionTypes) {
        expect(type.containsKey('id'), isTrue, reason: 'Missing id in $type');
        expect(type.containsKey('label'), isTrue, reason: 'Missing label in $type');
        expect(type.containsKey('level'), isTrue, reason: 'Missing level in $type');
        expect(type.containsKey('price'), isTrue, reason: 'Missing price in $type');
      }
    });

    test('all IV types have unique IDs', () {
      final ids = _ivInfusionTypes.map((t) => t['id']).toList();
      expect(ids.toSet().length, ids.length, reason: 'Duplicate IV type IDs');
    });

    test('nurse levels are valid (basic, advanced, or critical)', () {
      const validLevels = {'basic', 'advanced', 'critical'};
      for (final type in _ivInfusionTypes) {
        expect(validLevels, contains(type['level']),
            reason: '${type['id']} has invalid nurse level ${type['level']}');
      }
    });

    test('prices are parseable positive integers', () {
      for (final type in _ivInfusionTypes) {
        final price = int.parse(type['price']!);
        expect(price, greaterThan(0),
            reason: '${type['id']} has non-positive price');
      }
    });

    test('iv_push maps to basic nurse level', () {
      final push = _ivInfusionTypes.firstWhere((t) => t['id'] == 'iv_push');
      expect(push['level'], 'basic');
    });

    test('iv_central_line maps to critical nurse level', () {
      final cl = _ivInfusionTypes.firstWhere((t) => t['id'] == 'iv_central_line');
      expect(cl['level'], 'critical');
    });
  });

  // =========================================================================
  // Doctor concern categories
  // =========================================================================
  group('Service booking — concern categories', () {
    test('all categories have required keys (id, label, type)', () {
      for (final cat in _concernCategories) {
        expect(cat.containsKey('id'), isTrue, reason: 'Missing id in $cat');
        expect(cat.containsKey('label'), isTrue, reason: 'Missing label in $cat');
        expect(cat.containsKey('type'), isTrue, reason: 'Missing type in $cat');
      }
    });

    test('all categories have unique IDs', () {
      final ids = _concernCategories.map((c) => c['id']).toList();
      expect(ids.toSet().length, ids.length, reason: 'Duplicate concern IDs');
    });

    test('all type values are "gp" or "icu"', () {
      const validTypes = {'gp', 'icu'};
      for (final cat in _concernCategories) {
        expect(validTypes, contains(cat['type']),
            reason: '${cat['id']} has invalid type ${cat['type']}');
      }
    });

    test('at least one GP concern exists', () {
      expect(_concernCategories.where((c) => c['type'] == 'gp'), isNotEmpty);
    });

    test('at least one ICU concern exists', () {
      expect(_concernCategories.where((c) => c['type'] == 'icu'), isNotEmpty);
    });

    test('fever maps to GP', () {
      final fever = _concernCategories.firstWhere((c) => c['id'] == 'fever');
      expect(fever['type'], 'gp');
    });

    test('ventilator maps to ICU', () {
      final vent = _concernCategories.firstWhere((c) => c['id'] == 'ventilator');
      expect(vent['type'], 'icu');
    });

    test('"other" category exists and maps to GP', () {
      final other = _concernCategories.firstWhere((c) => c['id'] == 'other');
      expect(other['type'], 'gp');
    });
  });
}
