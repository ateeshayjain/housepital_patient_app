// test/utils/vital_ranges_test.dart
//
// Tests that vital range constants in AppConstants are internally consistent
// and medically reasonable.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/config/constants.dart';

void main() {
  final ranges = AppConstants.vitalRanges;

  // =========================================================================
  // All expected vital types are present
  // =========================================================================
  group('Vital ranges — coverage', () {
    const expectedTypes = [
      'systolic',
      'diastolic',
      'pulse',
      'spo2',
      'temperature',
      'sugar',
    ];

    for (final type in expectedTypes) {
      test('$type range exists', () {
        expect(ranges.containsKey(type), isTrue,
            reason: 'Missing vital range for $type');
      });
    }
  });

  // =========================================================================
  // Internal ordering: low < normalLow < normalHigh < high
  // =========================================================================
  group('Vital ranges — ordering invariants', () {
    for (final entry in ranges.entries) {
      final type = entry.key;
      final r = entry.value;

      test('$type: low < normalLow', () {
        expect(r['low']!, lessThan(r['normalLow']!));
      });

      test('$type: normalLow < normalHigh', () {
        expect(r['normalLow']!, lessThan(r['normalHigh']!));
      });

      test('$type: normalHigh <= high', () {
        expect(r['normalHigh']!, lessThanOrEqualTo(r['high']!));
      });

      test('$type: has all four keys', () {
        expect(r.containsKey('low'), isTrue);
        expect(r.containsKey('normalLow'), isTrue);
        expect(r.containsKey('normalHigh'), isTrue);
        expect(r.containsKey('high'), isTrue);
      });
    }
  });

  // =========================================================================
  // Medically reasonable boundaries
  // =========================================================================
  group('Vital ranges — medically reasonable', () {
    test('systolic low >= 70 (alive patient)', () {
      expect(ranges['systolic']!['low']!, greaterThanOrEqualTo(70));
    });

    test('systolic high <= 200', () {
      expect(ranges['systolic']!['high']!, lessThanOrEqualTo(200));
    });

    test('diastolic low >= 40', () {
      expect(ranges['diastolic']!['low']!, greaterThanOrEqualTo(40));
    });

    test('diastolic high <= 120', () {
      expect(ranges['diastolic']!['high']!, lessThanOrEqualTo(120));
    });

    test('pulse low >= 30', () {
      expect(ranges['pulse']!['low']!, greaterThanOrEqualTo(30));
    });

    test('pulse high <= 200', () {
      expect(ranges['pulse']!['high']!, lessThanOrEqualTo(200));
    });

    test('spo2 low >= 80', () {
      expect(ranges['spo2']!['low']!, greaterThanOrEqualTo(80));
    });

    test('spo2 high == 100 (cannot exceed 100%)', () {
      expect(ranges['spo2']!['high']!, equals(100));
    });

    test('spo2 normalHigh == 100', () {
      expect(ranges['spo2']!['normalHigh']!, equals(100));
    });

    test('temperature low >= 90 F', () {
      expect(ranges['temperature']!['low']!, greaterThanOrEqualTo(90));
    });

    test('temperature high <= 106 F', () {
      expect(ranges['temperature']!['high']!, lessThanOrEqualTo(106));
    });

    test('sugar low >= 40', () {
      expect(ranges['sugar']!['low']!, greaterThanOrEqualTo(40));
    });

    test('sugar high <= 500', () {
      expect(ranges['sugar']!['high']!, lessThanOrEqualTo(500));
    });
  });

  // =========================================================================
  // All values are positive
  // =========================================================================
  group('Vital ranges — all positive', () {
    for (final entry in ranges.entries) {
      for (final kv in entry.value.entries) {
        test('${entry.key}.${kv.key} is positive', () {
          expect(kv.value, greaterThan(0));
        });
      }
    }
  });
}
