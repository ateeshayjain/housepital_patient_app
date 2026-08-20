// test/utils/vital_classifier_test.dart
//
// Replaces test/utils/vital_ranges_test.dart, which validated that
// AppConstants.vitalRanges was internally consistent — and passed happily
// while that map disagreed with vital_classifier.dart about SpO2, sugar and
// systolic BP, under key names neither shared.
//
// A structure can be perfectly self-consistent and still be the app's second
// opinion. So the property this file pins is AGREEMENT: there is one
// classifier, both entry points give the same answer, and no key silently
// falls through.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/config/theme.dart';
import 'package:housepital_patient/utils/helpers.dart';
import 'package:housepital_patient/utils/vital_classifier.dart';

void main() {
  group('the two entry points cannot disagree', () {
    // The exact readings that used to get two different answers.
    const contested = <List<Object>>[
      ['spo2', 91.0], // was red here, borderline there
      ['spo2', 89.0],
      ['spo2', 94.0],
      ['sugar', 190.0], // was yellow here, alert there
      ['sugar', 175.0],
      ['bp_systolic', 95.0], // was green here, borderline there
      ['systolic', 95.0], // …and the alias the trend screen actually passes
    ];

    for (final c in contested) {
      final key = c[0] as String;
      final value = c[1] as double;
      test('$key $value gets ONE answer', () {
        final classifier = classifyVital(key, value);
        final helper = VitalHelper.getVitalStatus(key, value);
        const map = {
          'red': 'alert',
          'yellow': 'borderline',
          'green': 'normal',
          'unknown': 'unknown',
        };
        expect(helper, map[classifier],
            reason: 'VitalHelper must not hold its own thresholds');
      });
    }
  });

  group('key aliases all resolve — nothing falls through', () {
    // The trend screen passes 'systolic'; the entry sheet passes
    // 'bp_systolic'. Under the old code one of those matched nothing and was
    // counted as normal.
    const aliasGroups = <List<String>>[
      ['bp_systolic', 'systolic', 'bp'],
      ['bp_diastolic', 'diastolic'],
      ['spo2', 'oxygen'],
      ['pulse', 'heart_rate'],
      ['temperature', 'temp'],
      ['sugar', 'blood_sugar', 'glucose'],
    ];

    for (final group in aliasGroups) {
      test('${group.join(" / ")} classify identically', () {
        for (final value in const [50.0, 70.0, 95.0, 130.0, 200.0]) {
          final answers =
              group.map((k) => classifyVital(k, value)).toSet();
          expect(answers, hasLength(1),
              reason: 'aliases of ${group.first} disagreed at $value');
          expect(answers.single, isNot('unknown'));
        }
      });
    }
  });

  group('an unknown vital is never reassuring', () {
    test("classifyVital returns 'unknown', not 'green'", () {
      // It used to return 'green'. A typo'd or newly-added key rendered as a
      // reassuring green dot — the worst way to say "I don't know what this
      // is".
      expect(classifyVital('creatinine', 12.0), 'unknown');
      expect(classifyVital('', 1.0), 'unknown');
    });

    test('the colour is neutral grey, not the normal green', () {
      final c = VitalHelper.getVitalColor('creatinine', 12.0);
      expect(c, HousepitalColors.greyLight);
      expect(c, isNot(HousepitalColors.vitalNormal));
    });
  });

  group('the published table is what the code does', () {
    // Boundary convention: the boundary value belongs to the MORE SEVERE side.
    const cases = <List<Object>>[
      ['bp_systolic', 140.0, 'red'],
      ['bp_systolic', 139.0, 'yellow'],
      ['bp_systolic', 130.0, 'yellow'],
      ['bp_systolic', 129.0, 'green'],
      ['bp_systolic', 100.0, 'green'],
      ['bp_systolic', 99.0, 'yellow'],
      ['bp_systolic', 89.0, 'red'],
      ['bp_diastolic', 90.0, 'red'],
      ['bp_diastolic', 85.0, 'yellow'],
      ['bp_diastolic', 70.0, 'green'],
      ['bp_diastolic', 59.0, 'red'],
      ['spo2', 100.0, 'green'],
      ['spo2', 95.0, 'green'],
      ['spo2', 94.0, 'yellow'],
      ['spo2', 90.0, 'yellow'],
      ['spo2', 89.0, 'red'],
      ['pulse', 111.0, 'red'],
      ['pulse', 110.0, 'yellow'],
      ['pulse', 100.0, 'yellow'],
      ['pulse', 99.0, 'green'],
      ['pulse', 60.0, 'green'],
      ['pulse', 59.0, 'yellow'],
      ['pulse', 49.0, 'red'],
      ['temperature', 100.5, 'red'],
      ['temperature', 100.4, 'yellow'],
      ['temperature', 99.0, 'yellow'],
      ['temperature', 98.6, 'green'],
      ['temperature', 96.5, 'yellow'],
      ['temperature', 95.9, 'red'],
      ['sugar', 181.0, 'red'],
      ['sugar', 180.0, 'yellow'],
      ['sugar', 140.0, 'yellow'],
      ['sugar', 120.0, 'green'],
      ['sugar', 70.0, 'green'],
      ['sugar', 65.0, 'yellow'],
      ['sugar', 59.0, 'red'],
    ];

    for (final c in cases) {
      final key = c[0] as String;
      final value = c[1] as double;
      final want = c[2] as String;
      test('$key $value → $want', () {
        expect(classifyVital(key, value), want);
      });
    }
  });

  test('the ranges are contiguous — no reading is unclassifiable', () {
    for (final key in const [
      'bp_systolic',
      'bp_diastolic',
      'spo2',
      'pulse',
      'temperature',
      'sugar',
    ]) {
      for (var v = 0.0; v <= 400.0; v += 0.5) {
        final r = classifyVital(key, v);
        expect(['red', 'yellow', 'green'], contains(r),
            reason: '$key at $v returned "$r"');
      }
    }
  });
}
