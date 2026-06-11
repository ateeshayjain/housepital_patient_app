// test/screens/orders/quote_pending_surfaces_test.dart
//
// Audit guard for the inviolable business rule: a quote-pending order
// (`quoteStatus: 'pending'`, no price yet — see OrdersProvider.isQuotePending)
// must NEVER render a rupee amount on any surface. Manpower prices are never
// shown; the copy is "Price will be confirmed on call" and ₹0 must never
// appear anywhere.
//
// Surfaces covered:
//   • MyOrdersScreen        — order card for a quote-pending order
//   • OrderTrackingScreen   — quote-pending banner variant
//   • BookingConfirmationScreen — quotePending: true variant
//
// Each quote assertion is paired with a PRICED control order so the "no ₹"
// check can never pass vacuously (if ₹ rendering broke globally, the priced
// assertions fail).
//
// Provider + pump pattern copied from test/screens/overflow_smoke_test.dart /
// test/screens/my_care/my_care_screen_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/screens/orders/order_tracking_screen.dart';
import 'package:housepital_patient/screens/services/booking_confirmation_screen.dart';
import 'package:housepital_patient/screens/services/my_orders_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';
import 'package:housepital_patient/utils/permissions.dart';
import 'package:housepital_patient/widgets/common_widgets.dart';

const _quoteOrderId = 'HPL-BOOK-Q000001';
const _pricedOrderId = 'HPL-BOOK-P000001';

class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());

  @override
  String get currentUserRole => UserRole.primaryContact;
  @override
  Patient? get currentPatient => DemoData.patient;

  @override
  Future<void> loadPatients() async {}
  @override
  Future<void> loadDashboard() async {}
}

/// OrdersProvider seeded synchronously with BOTH a quote-pending manpower
/// order (no unitPrice, totalAmount 0 — mirrors the shape addOrder() writes
/// for `quotePending: true`) AND a priced equipment order (the non-vacuous
/// control).
class _TestOrdersProvider extends OrdersProvider {
  @override
  List<Map<String, dynamic>> get orders => [
        {
          'id': _quoteOrderId,
          'items': [
            {
              'equipmentId': 'svc_caretaker',
              'name': 'Caretaker 12hr (15 days)',
              'brand': 'Housepital',
              'isService': true,
              'quantity': 1,
              // Deliberately NO unitPrice — quote-pending orders carry none.
            },
          ],
          'totalAmount': 0,
          'status': 'confirmed',
          'createdAt': DateTime(2026, 6, 1).toIso8601String(),
          'type': 'mixed',
          'quoteStatus': 'pending',
        },
        {
          'id': _pricedOrderId,
          'items': [
            {
              'equipmentId': 'eq_oxygen',
              'name': 'Oxygen Concentrator (5L)',
              'brand': 'Philips',
              'unitPrice': 3500,
              'isService': false,
              'quantity': 1,
            },
          ],
          'totalAmount': 3500,
          'status': 'confirmed',
          'createdAt': DateTime(2026, 6, 2).toIso8601String(),
          'type': 'equipment',
        },
      ];
}

Widget _wrap(Widget home) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: home,
      ),
    );

Widget _ordersHost() => _wrap(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(
              value: _TestAppProvider()),
          ChangeNotifierProvider<OrdersProvider>.value(
              value: _TestOrdersProvider()),
        ],
        child: const MyOrdersScreen(initialTab: 0),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget Function() build,
    {Size size = const Size(800, 1400)}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await tester.pumpWidget(build());
    // Async AppLocalizations delegate + provider futures resolve here.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

/// The HousepitalCard subtree containing the order with [orderId].
Finder _cardOf(String orderId) => find.ancestor(
      of: find.text(orderId),
      matching: find.byType(HousepitalCard),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MyOrdersScreen', () {
    testWidgets(
        'quote-pending order card renders NO ₹ — quote copy + badge instead',
        (tester) async {
      await _pump(tester, _ordersHost);

      // Both cards are on screen (control precondition).
      expect(find.text(_quoteOrderId), findsOneWidget);
      expect(find.text(_pricedOrderId), findsOneWidget);

      // (a) Not a single ₹ inside the quote order's card subtree.
      expect(
        find.descendant(
            of: _cardOf(_quoteOrderId), matching: find.textContaining('₹')),
        findsNothing,
        reason: 'INVIOLABLE: a quote-pending (manpower) order must never '
            'render a rupee amount.',
      );

      // …and the quote copy IS present in that card.
      expect(
        find.descendant(
            of: _cardOf(_quoteOrderId),
            matching: find.text('Price will be confirmed on call')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: _cardOf(_quoteOrderId), matching: find.text('Quote pending')),
        findsOneWidget,
      );
      // Quote orders get a PRO FORMA document, never a priced Invoice.
      expect(
        find.descendant(
            of: _cardOf(_quoteOrderId), matching: find.text('Pro forma')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: _cardOf(_quoteOrderId), matching: find.text('Invoice')),
        findsNothing,
      );
    });

    testWidgets(
        'priced order card still shows its ₹ amount (guard is not vacuous)',
        (tester) async {
      await _pump(tester, _ordersHost);

      // (b) The priced equipment order DOES render ₹3,500.
      expect(
        find.descendant(
            of: _cardOf(_pricedOrderId), matching: find.text('₹3,500')),
        findsOneWidget,
        reason: 'Control failed: priced orders must keep showing their '
            'amount, otherwise the no-₹ assertions above prove nothing.',
      );
      expect(
        find.descendant(
            of: _cardOf(_pricedOrderId), matching: find.text('Quote pending')),
        findsNothing,
      );
      expect(
        find.descendant(
            of: _cardOf(_pricedOrderId), matching: find.text('Invoice')),
        findsOneWidget,
      );

      // (c) ₹0 must never appear anywhere on the screen.
      expect(find.textContaining('₹0'), findsNothing,
          reason: 'INVIOLABLE: never render ₹0 — quote-pending orders have '
              'no price, not a zero price.');
    });
  });

  group('OrderTrackingScreen', () {
    // The screen's Firestore listener throws "No Firebase App" in widget
    // tests; the screen catches it and renders the timeline — exactly the
    // surface under test. quotePending drives the banner.
    testWidgets('quote-pending variant shows the banner and NO ₹',
        (tester) async {
      await _pump(
        tester,
        () => _wrap(const OrderTrackingScreen(
          bookingId: _quoteOrderId,
          orderType: 'booking',
          quotePending: true,
        )),
      );

      expect(find.text('Quote pending'), findsOneWidget);
      expect(find.text('Price will be confirmed on call'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing,
          reason: 'INVIOLABLE: quote-pending tracking must never render ₹.');
      expect(find.textContaining('₹0'), findsNothing);
    });

    testWidgets('priced variant shows no quote banner', (tester) async {
      await _pump(
        tester,
        () => _wrap(const OrderTrackingScreen(
          bookingId: _pricedOrderId,
          orderType: 'equipment',
          quotePending: false,
        )),
      );

      expect(find.text('Quote pending'), findsNothing);
      expect(find.text('Price will be confirmed on call'), findsNothing);
    });
  });

  group('BookingConfirmationScreen', () {
    testWidgets(
        'quotePending: true renders quote copy, "On call" per item, and NO ₹',
        (tester) async {
      await _pump(
        tester,
        () => _wrap(const BookingConfirmationScreen(
          cartItems: [
            CartItem(
              equipmentId: 'svc_caretaker',
              name: 'Caretaker 12hr (15 days)',
              brand: 'Housepital',
              unitPrice: 0, // quote pending — confirmed on call
              isService: true,
            ),
          ],
          totalAmount: 0,
          bookingNumber: _quoteOrderId,
          quotePending: true,
        )),
      );

      expect(find.text('Order Confirmed!'), findsOneWidget);
      expect(find.text(_quoteOrderId), findsOneWidget);
      expect(find.text('Quote pending'), findsOneWidget);
      expect(find.text('Price will be confirmed on call'), findsOneWidget);
      // Per-item amount slot renders "On call" instead of a ₹ line.
      expect(find.text('On call'), findsOneWidget);
      // The quote-first next-steps copy leads with the price call.
      expect(find.text('Price Confirmation Call'), findsOneWidget);

      expect(find.textContaining('₹'), findsNothing,
          reason: 'INVIOLABLE: the quote-pending confirmation must never '
              'render a rupee amount (and never ₹0).');
    });

    testWidgets('priced variant still shows ₹ line + total (not vacuous)',
        (tester) async {
      await _pump(
        tester,
        () => _wrap(const BookingConfirmationScreen(
          cartItems: [
            CartItem(
              equipmentId: 'eq_oxygen',
              name: 'Oxygen Concentrator (5L)',
              brand: 'Philips',
              unitPrice: 3500,
            ),
          ],
          totalAmount: 3500,
          bookingNumber: _pricedOrderId,
          quotePending: false,
        )),
      );

      // Line amount + Total row both show ₹3,500.
      expect(find.text('₹3,500'), findsNWidgets(2));
      expect(find.text('Quote pending'), findsNothing);
      expect(find.text('On call'), findsNothing);
      expect(find.textContaining('₹0'), findsNothing);
    });
  });
}
