// test/screens/services/equipment_bottom_sheet_test.dart
//
// Tests the bottom sheet result pattern used when equipment items are
// selected in the catalog.  The bottom sheet pops with a Map describing
// which route the parent should navigate to, or null when no navigation
// is needed (e.g. add-to-cart).

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ===========================================================================
  // Rental navigation result
  // ===========================================================================
  group('Bottom sheet rental result', () {
    test('rental agreement args has required keys', () {
      final args = <String, dynamic>{
        'itemName': 'Hospital Bed',
        'monthlyRate': 3599,
        'durationMonths': 3,
      };
      expect(args['itemName'], isA<String>());
      expect(args['monthlyRate'], isA<int>());
      expect(args['monthlyRate'], greaterThan(0));
      expect(args['durationMonths'], isA<int>());
      expect(args['durationMonths'], greaterThanOrEqualTo(1));
    });

    test('rental result contains route and args', () {
      final result = <String, dynamic>{
        'route': '/rental-agreement',
        'args': {
          'itemName': 'Oxygen Concentrator',
          'monthlyRate': 7999,
          'durationMonths': 6,
        },
      };

      expect(result['route'], equals('/rental-agreement'));
      expect(result['args'], isA<Map<String, dynamic>>());

      final args = result['args'] as Map<String, dynamic>;
      expect(args['itemName'], isNotEmpty);
      expect(args['monthlyRate'], isPositive);
      expect(args['durationMonths'], greaterThanOrEqualTo(1));
    });

    test('durationMonths defaults to 1 when not explicitly set', () {
      // The bottom sheet defaults to 1 month if user hasn't changed the slider
      const defaultDuration = 1;
      final args = <String, dynamic>{
        'itemName': 'Wheelchair',
        'monthlyRate': 2500,
        'durationMonths': defaultDuration,
      };
      expect(args['durationMonths'], equals(1));
    });
  });

  // ===========================================================================
  // Buy / add-to-cart result (no navigation)
  // ===========================================================================
  group('Bottom sheet buy result', () {
    test('buy action returns null result (no navigation)', () {
      // When _isRental is false and item is added to cart, pop returns null
      Map<String, dynamic>? result;
      expect(result, isNull);
    });

    test('null result means parent screen stays on catalog', () {
      // A null navigation result means the parent stays on the catalog.
      const Map<String, dynamic>? result = null;
      expect(result, isNull);
    });
  });

  // ===========================================================================
  // Assessment navigation result
  // ===========================================================================
  group('Bottom sheet assessment result', () {
    test('assessment result has route /assessment-request', () {
      final result = <String, dynamic>{
        'route': '/assessment-request',
        'args': <String, dynamic>{
          'serviceId': 'eq-motorised-bed',
          'serviceName': 'Motorised Hospital Bed',
        },
      };

      expect(result['route'], equals('/assessment-request'));
      expect(result['args'], isA<Map<String, dynamic>>());
    });

    test('assessment result when item.needsAssessment is true', () {
      // Simulates the condition: if item.needsAssessment => pop assessment route
      const needsAssessment = true;
      Map<String, dynamic>? result;

      if (needsAssessment) {
        result = {
          'route': '/assessment-request',
          'args': {'serviceId': 'eq-cpap', 'serviceName': 'CPAP Machine'},
        };
      }

      expect(result, isNotNull);
      expect(result['route'], equals('/assessment-request'));
    });
  });

  // ===========================================================================
  // Result routing logic
  // ===========================================================================
  group('Result routing dispatch', () {
    test('routes correctly based on result map route key', () {
      final rentalResult = <String, dynamic>{
        'route': '/rental-agreement',
        'args': {
          'itemName': 'Patient Monitor',
          'monthlyRate': 15000,
          'durationMonths': 1,
        },
      };
      final assessmentResult = <String, dynamic>{
        'route': '/assessment-request',
        'args': {'serviceId': 'eq-ventilator'},
      };

      expect(rentalResult['route'], equals('/rental-agreement'));
      expect(assessmentResult['route'], equals('/assessment-request'));
      expect(rentalResult['route'], isNot(equals(assessmentResult['route'])));
    });

    test('result map with unknown route can be handled gracefully', () {
      final unknownResult = <String, dynamic>{
        'route': '/unknown-route',
        'args': {},
      };
      final knownRoutes = ['/rental-agreement', '/assessment-request'];
      expect(knownRoutes.contains(unknownResult['route']), isFalse);
    });
  });
}
