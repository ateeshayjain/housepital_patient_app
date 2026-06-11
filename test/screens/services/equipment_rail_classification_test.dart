// test/screens/services/equipment_rail_classification_test.dart
//
// Permanent guard for the Equipment rail's clinical taxonomy.
//
// `railCategoryForItem` folds the bundled catalog into the left rail buckets
// using name-keyword overrides first, then the catalog's `use_case`. The
// shipped catalog's `use_case` values are hand-entered and have misfiled
// items before (every wheelchair/walker/crutch was tagged 'Orthopaedic'),
// so this test pins ~20 well-known items to their expected bucket against
// the REAL bundled asset — future catalog edits can't silently misfile a
// BiPAP under Ortho Support again.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/screens/services/widgets/equipment_category_rail.dart';

void main() {
  late List<EquipmentItem> catalog;

  setUpAll(() {
    // `flutter test` runs with the project root as cwd, so the bundled
    // asset is readable directly from disk (no rootBundle / binding needed).
    final raw = File('assets/equipment_catalog.json').readAsStringSync();
    catalog = (json.decode(raw) as List)
        .map((e) => EquipmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(catalog, isNotEmpty,
        reason: 'bundled equipment catalog must load and parse');
  });

  EquipmentItem byName(String name) => catalog.firstWhere(
        (i) => i.name == name,
        orElse: () => throw StateError(
            '"$name" not found in assets/equipment_catalog.json — if the '
            'item was renamed, update this guard with the new name.'),
      );

  group('curated taxonomy guard (real bundled catalog)', () {
    const expected = <String, String>{
      // Respiratory therapy & oxygen
      'BiPAP Machine': 'Respiratory',
      'Airsense 10 Autoset CPAP': 'Respiratory',
      'Oxygen Concentrator 5L': 'Respiratory',
      'Stellar 100 Ventilator': 'Respiratory',
      'Nebulizer': 'Respiratory',
      'AMBU Bag': 'Respiratory', // catalog says 'General Care' — name wins
      // Mobility aids + patient beds/furniture
      'Wheelchair': 'Mobility & Patient Comfort',
      'Walker': 'Mobility & Patient Comfort',
      'Walking Stick': 'Mobility & Patient Comfort',
      'Quad Cane (Four Leg)': 'Mobility & Patient Comfort',
      'Commode Chair': 'Mobility & Patient Comfort',
      'Manual Hospital Bed with Mattress': 'Mobility & Patient Comfort',
      // Cardiac & vascular monitoring
      'BP Monitor Automatic': 'Cardiac & Vascular',
      'Pulse Oximeter': 'Cardiac & Vascular',
      // Wound care
      'Suction Machine': 'Respiratory', // airway suction (owner correction)
      // Hygiene
      'Urine Bed Pan': 'Hygiene & Sanitation',
      'SEAT RAISER 4 INCHES': 'Hygiene & Sanitation',
      // Ortho supports — incl. the 'walker boot' ≠ mobility-walker exception
      'Knee Brace Long Type (L)': 'Orthopaedic',
      'Lumbosacral Belt (L)': 'Orthopaedic',
      'Walker Boot Air Short Large': 'Orthopaedic',
    };

    for (final entry in expected.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(railCategoryForItem(byName(entry.key)), entry.value);
      });
    }
  });

  test('Other stays a small tail, not a dumping ground (≤25%)', () {
    final byCategory = <String, List<String>>{};
    for (final item in catalog) {
      byCategory.putIfAbsent(railCategoryForItem(item), () => []).add(item.name);
    }
    final other = byCategory[kEquipmentRailOther] ?? const <String>[];
    expect(
      other.length,
      lessThanOrEqualTo(catalog.length ~/ 4),
      reason: 'Too many items fold into "$kEquipmentRailOther" — the keyword/'
          'use_case mapping in railCategoryForItem needs more coverage. '
          'Other currently holds: ${other.join(', ')}',
    );
  });

  test('no mobility aid is filed under Orthopaedic', () {
    // The original catalog bug: wheelchairs/walkers/canes tagged Orthopaedic.
    final mobilityWords = ['wheelchair', 'walking stick', 'crutch'];
    for (final item in catalog) {
      final n = item.name.toLowerCase();
      if (mobilityWords.any(n.contains)) {
        expect(railCategoryForItem(item), 'Mobility & Patient Comfort',
            reason: '"${item.name}" is a mobility aid');
      }
    }
  });
}
