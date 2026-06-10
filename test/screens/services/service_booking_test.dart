// test/screens/services/service_booking_test.dart
//
// 1. Tests IV infusion type -> nurse level mapping and doctor visit concern
//    categories from service_booking_screen.dart. Since these are private
//    static consts inside a State class, we replicate the canonical data here
//    and verify invariants.
// 2. Widget tests for the quote-first manpower contract (supersedes the old
//    audit M-1 manpower→assessment redirect): manpower services run the FULL
//    booking wizard with every ₹ suppressed and finish as a quote-pending
//    order — "Price confirmed on call before payment".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/screens/services/service_booking_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';
import 'package:housepital_patient/utils/helpers.dart';

// ---------------------------------------------------------------------------
// Canonical data — must mirror _ServiceBookingScreenState exactly.
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

// Helper to look up the nurse level for a given IV infusion type ID.
String _nurseLevelFor(String ivTypeId) {
  return _ivInfusionTypes.firstWhere((t) => t['id'] == ivTypeId)['level']!;
}

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // IV Infusion Types — nurse level mapping
  // =========================================================================
  group('IV infusion types — nurse level mapping', () {
    test('Single IV Push maps to "basic"', () {
      expect(_nurseLevelFor('iv_push'), 'basic');
    });

    test('IV Drip Short maps to "advanced"', () {
      expect(_nurseLevelFor('iv_drip_short'), 'advanced');
    });

    test('IV Drip Extended maps to "advanced"', () {
      expect(_nurseLevelFor('iv_drip_extended'), 'advanced');
    });

    test('Multiple IV Medications maps to "advanced"', () {
      expect(_nurseLevelFor('iv_multiple'), 'advanced');
    });

    test('Prolonged Infusion maps to "critical"', () {
      expect(_nurseLevelFor('iv_prolonged'), 'critical');
    });

    test('Central Line / PICC Access maps to "critical"', () {
      expect(_nurseLevelFor('iv_central_line'), 'critical');
    });
  });

  // =========================================================================
  // IV Infusion Types — required fields
  // =========================================================================
  group('IV infusion types — required fields', () {
    test('there are exactly 6 infusion types', () {
      expect(_ivInfusionTypes.length, 6);
    });

    for (final type in _ivInfusionTypes) {
      test('"${type['id']}" has all required fields (id, label, desc, level, price)', () {
        expect(type['id'], isNotNull);
        expect(type['id'], isNotEmpty);
        expect(type['label'], isNotNull);
        expect(type['label'], isNotEmpty);
        expect(type['desc'], isNotNull);
        expect(type['desc'], isNotEmpty);
        expect(type['level'], isNotNull);
        expect(type['level'], isNotEmpty);
        expect(type['price'], isNotNull);
        expect(type['price'], isNotEmpty);
      });
    }

    test('all infusion type IDs are unique', () {
      final ids = _ivInfusionTypes.map((t) => t['id']!).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('all levels are one of basic/advanced/critical', () {
      const validLevels = {'basic', 'advanced', 'critical'};
      for (final type in _ivInfusionTypes) {
        expect(validLevels, contains(type['level']),
            reason: '${type['id']} has invalid level "${type['level']}"');
      }
    });

    test('all prices are parseable as int', () {
      for (final type in _ivInfusionTypes) {
        expect(int.tryParse(type['price']!), isNotNull,
            reason: '${type['id']} price "${type['price']}" is not a valid int');
      }
    });
  });

  // =========================================================================
  // Doctor Visit concern categories — doctor type mapping
  // =========================================================================
  group('Doctor visit concern categories', () {
    test('all concern categories have required fields (id, label, type)', () {
      for (final cat in _concernCategories) {
        expect(cat['id'], isNotNull);
        expect(cat['id'], isNotEmpty);
        expect(cat['label'], isNotNull);
        expect(cat['label'], isNotEmpty);
        expect(cat['type'], isNotNull);
        expect(cat['type'], isNotEmpty);
      }
    });

    test('all concern category IDs are unique', () {
      final ids = _concernCategories.map((c) => c['id']!).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('all concern types are "gp" or "icu"', () {
      for (final cat in _concernCategories) {
        expect(['gp', 'icu'], contains(cat['type']),
            reason: '${cat['id']} has invalid type "${cat['type']}"');
      }
    });

    // GP concerns
    for (final id in ['fever', 'bp_sugar', 'stomach', 'skin', 'pain', 'elderly', 'medication', 'other']) {
      test('"$id" maps to "gp"', () {
        final cat = _concernCategories.firstWhere((c) => c['id'] == id);
        expect(cat['type'], 'gp');
      });
    }

    // ICU concerns
    for (final id in ['post_surgery', 'ventilator', 'icu_home', 'critical']) {
      test('"$id" maps to "icu"', () {
        final cat = _concernCategories.firstWhere((c) => c['id'] == id);
        expect(cat['type'], 'icu');
      });
    }
  });

  // =========================================================================
  // Manpower quote-first booking (replaces the audit M-1 forced redirect)
  // =========================================================================
  group('Manpower booking — quote-first wizard', () {
    Widget host(ServiceItem service, OrdersProvider orders,
        void Function(String?) onRoute) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>(
              create: (_) => AppProvider(ApiService())),
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ChangeNotifierProvider<OrdersProvider>.value(value: orders),
        ],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en')],
          home: ServiceBookingScreen(service: service),
          onGenerateRoute: (settings) {
            onRoute(settings.name);
            return MaterialPageRoute(
                builder: (_) => const Scaffold(body: SizedBox.shrink()));
          },
        ),
      );
    }

    testWidgets(
        'manpower runs the FULL wizard (no assessment redirect), shows no ₹ '
        'anywhere, and places a quote-pending order', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // Tall surface so all wizard sections lay out without scroll fights.
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final orders = OrdersProvider();
      final service = ServiceItem(
        id: 'mp-caretaker-basic-12',
        name: 'Caretaker (Basic) – 12 Hours',
        category: 'manpower',
        bookingType: 'scheduled',
      );
      String? pushedRoute;

      await tester.runAsync(() async {
        await tester.pumpWidget(
            host(service, orders, (r) => pushedRoute = r));
        // Let the async AppLocalizations delegate + slot fallback settle.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      // NOT redirected to /assessment-request — the wizard itself renders.
      expect(pushedRoute, isNull);
      expect(find.text('Select Slot'), findsWidgets);
      // Quote info row instead of any price, and explicitly NO ₹ on screen.
      expect(find.text('Price confirmed on call before payment'),
          findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);

      // Step 0 → 1 (ongoing manpower: start date + period).
      await tester.tap(find.text('Select Slot').last);
      await tester.pump();
      expect(find.text('Select Start Date'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);

      // Pick the first selectable start date (min 48 h ahead).
      final firstDate = DateTime.now().add(const Duration(hours: 48));
      await tester
          .tap(find.text(DateHelper.formatDateShort(firstDate)).first);
      await tester.pump();

      // Step 1 → 2.
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pump();

      // Review step: still no ₹; quote CTA replaces add-to-cart.
      expect(find.textContaining('₹'), findsNothing);
      expect(
          find.text('Price confirmed on call before payment'), findsWidgets);
      expect(find.text('Confirm Booking Request'), findsOneWidget);
      expect(find.text('Prefer a callback? Request an assessment'),
          findsOneWidget);

      // Confirm → order placed DIRECTLY via OrdersProvider (no cart/payment)
      // and routed to the existing booking-confirmation screen.
      final ordersBefore = orders.orders.length;
      await tester.ensureVisible(find.text('Confirm Booking Request'));
      await tester.tap(find.text('Confirm Booking Request'));
      await tester.pump();

      expect(orders.orders.length, ordersBefore + 1);
      final order = orders.orders.first;
      expect(order['quoteStatus'], 'pending');
      expect(order['totalAmount'], 0);
      expect(OrdersProvider.isQuotePending(order), isTrue);
      expect(pushedRoute, '/booking-confirmation');
    });
  });
}
