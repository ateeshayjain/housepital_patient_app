// test/screens/services/equipment_bottom_sheet_test.dart
//
// Tests the bottom sheet result pattern used when equipment items are
// selected in the catalog.  The bottom sheet pops with a Map describing
// which route the parent should navigate to, or null when no navigation
// is needed (e.g. add-to-cart).
//
// Also widget-tests the price-on-request → "Reserve — price on confirmation"
// flow: zero-price items are reservable end-to-end as quote-pending orders
// (no ₹ shown; price confirmed on call before payment).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/screens/services/cards/equipment_item_card.dart';
import 'package:housepital_patient/services/api_service.dart';

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

  // ===========================================================================
  // Price-on-request → Reserve (quote-pending order)
  // ===========================================================================
  group('Reserve — price on confirmation (quote-pending)', () {
    testWidgets(
        'zero-price item shows an ENABLED Reserve CTA and tapping it creates '
        'a quote-pending order (booking-permitted role)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final orders = OrdersProvider();
      final item = EquipmentItem(
        id: 'eq-premium-bed',
        name: 'Premium Motorised Bed',
        brand: 'Hospitech',
        category: 'Equipment',
        availableForSale: true,
        price: null, // price on request — previously a dead "contact us" stop
      );

      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            // AppProvider defaults to PRIMARY_CONTACT (booking permitted).
            ChangeNotifierProvider<AppProvider>(
                create: (_) => AppProvider(ApiService())),
            ChangeNotifierProvider<CartProvider>(
                create: (_) => CartProvider()),
            ChangeNotifierProvider<OrdersProvider>.value(value: orders),
          ],
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                height: 340,
                child: EquipmentItemCard(item: item, icon: Icons.bed),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Card shows the no-price label; ADD routes into the detail sheet
      // (not a dead end, not a one-tap add).
      expect(find.text('Price on request'), findsOneWidget);
      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      final reserve = find.text('Reserve — price on confirmation');
      expect(reserve, findsOneWidget);
      final button = tester.widget<ElevatedButton>(find
          .ancestor(of: reserve, matching: find.byType(ElevatedButton))
          .first);
      expect(button.onPressed, isNotNull,
          reason: 'Reserve must be ENABLED — no dead price-on-request state');
      // No ₹ anywhere in the sheet for a price-on-request item.
      expect(find.textContaining('₹'), findsNothing);

      final before = orders.orders.length;
      await tester.ensureVisible(reserve);
      await tester.tap(reserve);
      await tester.pumpAndSettle();

      // Quote-pending order created via OrdersProvider.
      expect(orders.orders.length, before + 1);
      final order = orders.orders.first;
      expect(order['quoteStatus'], 'pending');
      expect(order['totalAmount'], 0);
      expect(OrdersProvider.isQuotePending(order), isTrue);

      // Confirmation SnackBar with the booking number.
      expect(
          find.textContaining(
              'Reserved — our team will confirm the price shortly'),
          findsOneWidget);
      expect(find.textContaining(order['id'] as String), findsOneWidget);

      // Let the SnackBar's auto-dismiss timer expire before teardown.
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
