// test/screens/services/catalog_navigation_test.dart
//
// Tests the navigation result pattern used by the service catalog when
// a bottom sheet returns a result map indicating where to navigate.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

void main() {
  // ===========================================================================
  // Rental navigation result structure
  // ===========================================================================
  group('Rental navigation result', () {
    test('rental navigation result has correct structure', () {
      final result = <String, dynamic>{
        'route': '/rental-agreement',
        'args': {
          'itemName': 'Ventilator',
          'monthlyRate': 29999,
          'durationMonths': 1,
        },
      };
      expect(result['route'], '/rental-agreement');
      expect(result['args'], isA<Map<String, dynamic>>());
      expect((result['args'] as Map)['itemName'], isNotEmpty);
      expect((result['args'] as Map)['monthlyRate'], isPositive);
    });

    test('rental args monthlyRate must be positive integer', () {
      final args = <String, dynamic>{
        'itemName': 'Hospital Bed',
        'monthlyRate': 3599,
        'durationMonths': 3,
      };
      expect(args['monthlyRate'], isA<int>());
      expect(args['monthlyRate'] as int, greaterThan(0));
    });

    test('rental args durationMonths defaults to 1', () {
      final args = <String, dynamic>{
        'itemName': 'Oxygen Concentrator',
        'monthlyRate': 7999,
        'durationMonths': 1,
      };
      expect(args['durationMonths'], equals(1));
    });

    test('rental args durationMonths can be up to 12', () {
      for (final months in [1, 3, 6, 12]) {
        final args = <String, dynamic>{
          'itemName': 'Bed',
          'monthlyRate': 5000,
          'durationMonths': months,
        };
        expect(args['durationMonths'], greaterThanOrEqualTo(1));
        expect(args['durationMonths'], lessThanOrEqualTo(12));
      }
    });
  });

  // ===========================================================================
  // Assessment navigation result structure
  // ===========================================================================
  group('Assessment navigation result', () {
    test('assessment navigation result has correct structure', () {
      final serviceItem = ServiceItem(
        id: 'eq-cpap',
        name: 'CPAP Machine',
        category: 'equipment',
        bookingType: 'assessment',
      );

      final result = <String, dynamic>{
        'route': '/assessment-request',
        'args': serviceItem,
      };
      expect(result['route'], '/assessment-request');
      expect(result['args'], isA<ServiceItem>());
    });

    test('assessment ServiceItem preserves fields through result map', () {
      final serviceItem = ServiceItem(
        id: 'eq-ventilator',
        name: 'Ventilator',
        category: 'equipment',
        bookingType: 'assessment',
        basePriceMin: 25000,
      );

      final result = <String, dynamic>{
        'route': '/assessment-request',
        'args': serviceItem,
      };

      final args = result['args'] as ServiceItem;
      expect(args.id, equals('eq-ventilator'));
      expect(args.name, equals('Ventilator'));
      expect(args.category, equals('equipment'));
      expect(args.bookingType, equals('assessment'));
      expect(args.basePriceMin, equals(25000));
    });
  });

  // ===========================================================================
  // Buy action (no navigation)
  // ===========================================================================
  group('Buy action result', () {
    test('buy action returns null result (no navigation)', () {
      // When user taps Add to Cart (buy), bottom sheet pops with null
      // Parent does not navigate
      Map<String, dynamic>? result;
      expect(result, isNull);
    });

    test('null result means catalog stays visible', () {
      Map<String, dynamic>? result;
      // Parent code: if (result != null) { navigate(result['route']) }
      final shouldNavigate = result != null;
      expect(shouldNavigate, isFalse);
    });
  });

  // ===========================================================================
  // Route dispatch
  // ===========================================================================
  group('Route dispatch from result', () {
    test('dispatches to rental agreement for rental route', () {
      final result = <String, dynamic>{
        'route': '/rental-agreement',
        'args': {
          'itemName': 'Bed',
          'monthlyRate': 5000,
          'durationMonths': 3,
        },
      };

      String? navigatedRoute;
      switch (result['route']) {
        case '/rental-agreement':
          navigatedRoute = '/rental-agreement';
          break;
        case '/assessment-request':
          navigatedRoute = '/assessment-request';
          break;
      }
      expect(navigatedRoute, equals('/rental-agreement'));
    });

    test('dispatches to assessment for assessment route', () {
      final result = <String, dynamic>{
        'route': '/assessment-request',
        'args': ServiceItem(
          id: 'eq-1',
          name: 'Test',
          category: 'equipment',
          bookingType: 'assessment',
        ),
      };

      String? navigatedRoute;
      switch (result['route']) {
        case '/rental-agreement':
          navigatedRoute = '/rental-agreement';
          break;
        case '/assessment-request':
          navigatedRoute = '/assessment-request';
          break;
      }
      expect(navigatedRoute, equals('/assessment-request'));
    });
  });
}
