// test/models/equipment_catalog_gate_test.dart
//
// The unit tests next door pin the RULE. This one pins the rule against the
// SHIPPED CATALOG, because the round-4 failure was not a logic error you could
// see in isolation — the old rule read perfectly sensibly until you knew that
// every regulated device in this particular catalog is available_for_rent.
//
// A rule that is correct in the abstract and wrong on the data is still wrong.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

void main() {
  final raw = File('assets/equipment_catalog.json').readAsStringSync();
  final items = (jsonDecode(raw) as List)
      .map((e) => EquipmentItem.fromJson(e as Map<String, dynamic>))
      .toList();

  bool named(EquipmentItem i, String needle) =>
      i.name.toLowerCase().contains(needle);

  test('the catalog loads', () {
    expect(items.length, greaterThan(300));
  });

  test('EVERY oxygen concentrator is gated (all 17 were exempt before)', () {
    final concentrators =
        items.where((i) => named(i, 'oxygen concentrator')).toList();
    expect(concentrators, isNotEmpty);
    expect(concentrators.where((i) => !i.needsAssessment), isEmpty,
        reason: 'concentrators were not even in the old name list');
  });

  test('every ventilator, BiPAP and CPAP MACHINE is gated', () {
    final machines = items.where((i) =>
        (named(i, 'ventilator') ||
            named(i, 'ventilation') ||
            named(i, 'bipap') ||
            named(i, 'cpap')) &&
        !named(i, 'mask') &&
        !named(i, 'connector'));
    expect(machines, isNotEmpty);
    for (final m in machines) {
      expect(m.needsAssessment, isTrue, reason: '"${m.name}" must be gated');
    }
  });

  test('every suction machine and pump is gated', () {
    final devices = items.where((i) =>
        named(i, 'suction machine') ||
        named(i, 'syringe pump') ||
        named(i, 'infusion pump'));
    expect(devices, isNotEmpty);
    for (final d in devices) {
      expect(d.needsAssessment, isTrue, reason: '"${d.name}" must be gated');
    }
  });

  test('NO mask is gated — masks are what the old rule actually caught', () {
    final masks = items.where((i) => named(i, 'mask'));
    expect(masks, isNotEmpty);
    for (final m in masks) {
      expect(m.needsAssessment, isFalse,
          reason: '"${m.name}" is a spare for an existing prescription');
    }
  });

  test('rentability is not consulted: gated items exist on both sides', () {
    final gated = items.where((i) => i.needsAssessment).toList();
    expect(gated.where((i) => i.availableForRent), isNotEmpty);
    expect(gated.length, greaterThan(30),
        reason: 'the old rule gated a handful of masks and nothing else');
  });

  test('every bundled product image referenced by the catalog exists', () {
    // 235 orphaned photos (40 MiB) were deleted in the same change; this makes
    // sure the delete did not take a referenced one with it.
    final missing = <String>[];
    for (final i in items) {
      final u = i.imageUrl;
      if (u != null && u.startsWith('assets/') && !File(u).existsSync()) {
        missing.add('${i.name} -> $u');
      }
    }
    expect(missing, isEmpty);
  });
}
