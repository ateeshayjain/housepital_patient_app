// test/utils/vital_classification_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/utils/vital_classifier.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // BP SYSTOLIC
  // ═══════════════════════════════════════════════════════════════════════════
  group('BP Systolic', () {
    test('GREEN: normal range 90-130', () {
      expect(classifyVital('bp_systolic', 120), 'green');
      expect(classifyVital('bp_systolic', 90), 'green');
      expect(classifyVital('bp_systolic', 110), 'green');
      expect(classifyVital('bp_systolic', 129.9), 'green');
    });

    test('YELLOW: borderline 130-140 or 80-90', () {
      expect(classifyVital('bp_systolic', 135), 'yellow');
      expect(classifyVital('bp_systolic', 130), 'yellow');
      expect(classifyVital('bp_systolic', 139), 'yellow');
      expect(classifyVital('bp_systolic', 85), 'yellow');
      expect(classifyVital('bp_systolic', 80), 'yellow');
      expect(classifyVital('bp_systolic', 89), 'yellow');
    });

    test('RED: critical >140 or <80', () {
      expect(classifyVital('bp_systolic', 180), 'red');
      expect(classifyVital('bp_systolic', 60), 'red');
      expect(classifyVital('bp_systolic', 79), 'red');
    });

    test('RED: extreme boundary values', () {
      expect(classifyVital('bp_systolic', 250), 'red');
      expect(classifyVital('bp_systolic', 0), 'red');
    });

    test('boundary: 140 is RED (not yellow)', () {
      expect(classifyVital('bp_systolic', 140), 'red');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SpO2
  // ═══════════════════════════════════════════════════════════════════════════
  group('SpO2 (Blood Oxygen)', () {
    test('GREEN: 95-100%', () {
      expect(classifyVital('spo2', 98), 'green');
      expect(classifyVital('spo2', 100), 'green');
      expect(classifyVital('spo2', 95), 'green');
    });

    test('YELLOW: 92-94%', () {
      expect(classifyVital('spo2', 93), 'yellow');
      expect(classifyVital('spo2', 92), 'yellow');
      expect(classifyVital('spo2', 94), 'yellow');
    });

    test('RED: <92% — triggers mandatory notification', () {
      expect(classifyVital('spo2', 88), 'red');
      expect(classifyVital('spo2', 91), 'red');
      expect(classifyVital('spo2', 0), 'red');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PULSE
  // ═══════════════════════════════════════════════════════════════════════════
  group('Pulse', () {
    test('GREEN: 60-99 (boundary 100 goes to yellow)', () {
      expect(classifyVital('pulse', 72), 'green');
      expect(classifyVital('pulse', 60), 'green');
      expect(classifyVital('pulse', 99), 'green');
    });

    test('boundary: 100 is YELLOW (not green — boundary goes to more severe)', () {
      expect(classifyVital('pulse', 100), 'yellow');
    });

    test('YELLOW: 100-110 or 50-60', () {
      expect(classifyVital('pulse', 105), 'yellow');
      expect(classifyVital('pulse', 110), 'yellow');
      expect(classifyVital('pulse', 55), 'yellow');
      expect(classifyVital('pulse', 50), 'yellow');
    });

    test('RED: >110 or <50', () {
      expect(classifyVital('pulse', 130), 'red');
      expect(classifyVital('pulse', 111), 'red');
      expect(classifyVital('pulse', 40), 'red');
      expect(classifyVital('pulse', 49), 'red');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TEMPERATURE
  // ═══════════════════════════════════════════════════════════════════════════
  group('Temperature (Fahrenheit)', () {
    test('GREEN: 97-99', () {
      expect(classifyVital('temperature', 98.6), 'green');
      expect(classifyVital('temperature', 97), 'green');
      expect(classifyVital('temperature', 98), 'green');
    });

    test('YELLOW: 99-100.4 or 96-97', () {
      expect(classifyVital('temperature', 99.5), 'yellow');
      expect(classifyVital('temperature', 99), 'yellow');
      expect(classifyVital('temperature', 100), 'yellow');
      expect(classifyVital('temperature', 100.4), 'yellow');
      expect(classifyVital('temperature', 96.5), 'yellow');
      expect(classifyVital('temperature', 96), 'yellow');
    });

    test('RED: >100.4 or <96', () {
      expect(classifyVital('temperature', 103), 'red');
      expect(classifyVital('temperature', 100.5), 'red');
      expect(classifyVital('temperature', 95), 'red');
      expect(classifyVital('temperature', 94), 'red');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // BLOOD SUGAR
  // ═══════════════════════════════════════════════════════════════════════════
  group('Blood Sugar', () {
    test('GREEN: 70-139 (boundary 140 goes to yellow)', () {
      expect(classifyVital('sugar', 100), 'green');
      expect(classifyVital('sugar', 70), 'green');
      expect(classifyVital('sugar', 139), 'green');
    });

    test('boundary: 140 is YELLOW (not green — boundary goes to more severe)', () {
      expect(classifyVital('sugar', 140), 'yellow');
    });

    test('YELLOW: 140-200 or 60-70', () {
      expect(classifyVital('sugar', 160), 'yellow');
      expect(classifyVital('sugar', 200), 'yellow');
      expect(classifyVital('sugar', 65), 'yellow');
      expect(classifyVital('sugar', 60), 'yellow');
    });

    test('RED: >200 or <60', () {
      expect(classifyVital('sugar', 350), 'red');
      expect(classifyVital('sugar', 201), 'red');
      expect(classifyVital('sugar', 45), 'red');
      expect(classifyVital('sugar', 59), 'red');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // EDGE CASES / INVALID INPUT
  // ═══════════════════════════════════════════════════════════════════════════
  group('Edge cases', () {
    test('throws ArgumentError for unknown vital type', () {
      expect(
        () => classifyVital('unknown_vital', 100),
        throwsArgumentError,
      );
    });

    test('handles zero values', () {
      expect(classifyVital('bp_systolic', 0), 'red');
      expect(classifyVital('spo2', 0), 'red');
      expect(classifyVital('pulse', 0), 'red');
      expect(classifyVital('sugar', 0), 'red');
    });

    test('handles very large values', () {
      expect(classifyVital('bp_systolic', 300), 'red');
      expect(classifyVital('pulse', 250), 'red');
      expect(classifyVital('sugar', 500), 'red');
      expect(classifyVital('temperature', 110), 'red');
    });

    test('handles negative values (treated as critical)', () {
      expect(classifyVital('bp_systolic', -10), 'red');
      expect(classifyVital('spo2', -5), 'red');
      expect(classifyVital('pulse', -1), 'red');
      expect(classifyVital('temperature', -10), 'red');
      expect(classifyVital('sugar', -20), 'red');
    });
  });
}
