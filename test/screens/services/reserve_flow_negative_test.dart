// test/screens/services/reserve_flow_negative_test.dart
//
// Negative-space tests for the equipment Reserve flow (price-on-request).
//
// Representation (see EquipmentItemCard / EquipmentDetailSheet): a
// price-on-request item has `price == null` (or 0) — the card renders
// "Price on request" with no ₹, the ADD pill must NOT one-tap add (it opens
// the detail sheet instead), and the sheet's CTA is
// "Reserve — price on confirmation" with the
// "Price confirmed on call before payment" notice and no ₹ anywhere.
// A normally priced item is the mirror image: ₹ price + working one-tap ADD,
// "Add to Cart" CTA in the sheet, and no Reserve affordance.
//
// Host setup follows test/screens/services/equipment_bottom_sheet_test.dart.

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

EquipmentItem _priceOnRequestItem() => EquipmentItem(
      id: 'eq-premium-bed',
      name: 'Premium Motorised Bed',
      brand: 'Hospitech',
      category: 'Equipment',
      availableForSale: true,
      price: null, // price on request — Reserve flow, never a fabricated ₹
    );

EquipmentItem _pricedItem() => EquipmentItem(
      id: 'eq-oxygen-5l',
      name: 'Oxygen Concentrator 5L',
      brand: 'Philips',
      category: 'Equipment',
      availableForSale: true,
      price: 3500,
      mrp: 5000, // MRP strikethrough + % off (Blinkit-style)
    );

Widget _host(EquipmentItem item, {required CartProvider cart}) => MaterialApp(
      home: MultiProvider(
        providers: [
          // AppProvider defaults to PRIMARY_CONTACT (booking permitted).
          ChangeNotifierProvider<AppProvider>(
              create: (_) => AppProvider(ApiService())),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider<OrdersProvider>(
              create: (_) => OrdersProvider()),
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
    );

Future<void> _pump(WidgetTester tester, EquipmentItem item,
    {required CartProvider cart}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_host(item, cart: cart));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('price-on-request item (price == null)', () {
    testWidgets('card shows "Price on request" and NO ₹ amount',
        (tester) async {
      await _pump(tester, _priceOnRequestItem(), cart: CartProvider());

      expect(find.text('Price on request'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing,
          reason: 'INVIOLABLE: no fabricated price for price-on-request '
              'equipment — and never ₹0.');
    });

    testWidgets(
        'ADD is NOT a one-tap add — it opens the detail sheet with the '
        'Reserve affordance, still no ₹', (tester) async {
      final cart = CartProvider();
      await _pump(tester, _priceOnRequestItem(), cart: cart);

      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      // Nothing went into the cart, no "added to cart" toast.
      expect(cart.items, isEmpty,
          reason: 'One-tap ADD must not add a price-on-request item — '
              'there is no price to add it at.');
      expect(find.textContaining('added to cart'), findsNothing);

      // The detail sheet opened with the Reserve flow instead.
      final reserve = find.text('Reserve — price on confirmation');
      expect(reserve, findsOneWidget);
      final button = tester.widget<ElevatedButton>(find
          .ancestor(of: reserve, matching: find.byType(ElevatedButton))
          .first);
      expect(button.onPressed, isNotNull,
          reason: 'Reserve must be ENABLED — no dead price-on-request state.');
      expect(find.text('Price confirmed on call before payment'),
          findsOneWidget);

      // And the mirror negatives: no Add to Cart CTA, no ₹ anywhere.
      expect(find.text('Add to Cart'), findsNothing);
      expect(find.text('Add Rental to Cart'), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
    });
  });

  group('normal priced item (price set)', () {
    testWidgets('card shows ₹ price + MRP strikethrough and NO Reserve copy',
        (tester) async {
      await _pump(tester, _pricedItem(), cart: CartProvider());

      expect(find.text('₹3,500'), findsOneWidget);
      expect(find.text('₹5,000'), findsOneWidget); // struck-through MRP
      expect(find.text('30% off'), findsOneWidget);
      expect(find.text('Price on request'), findsNothing);
      expect(find.text('Reserve — price on confirmation'), findsNothing);
      expect(find.text('Price confirmed on call before payment'),
          findsNothing);
    });

    testWidgets('ADD one-tap adds the priced item to the cart',
        (tester) async {
      final cart = CartProvider();
      await _pump(tester, _pricedItem(), cart: cart);

      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      expect(cart.items.length, 1);
      expect(cart.items.single.equipmentId, 'eq-oxygen-5l');
      expect(cart.items.single.unitPrice, 3500);
      expect(find.textContaining('added to cart'), findsOneWidget);

      // No detail sheet opened for a simple sale item.
      expect(find.text('Reserve — price on confirmation'), findsNothing);
      expect(find.text('Add to Cart'), findsNothing);

      // Let the SnackBar's auto-dismiss timer expire before teardown.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets(
        'detail sheet shows ₹ price + "Add to Cart" and NO Reserve flow',
        (tester) async {
      await _pump(tester, _pricedItem(), cart: CartProvider());

      // Tap the card body (item name) to open the detail sheet.
      await tester.tap(find.text('Oxygen Concentrator 5L'));
      await tester.pumpAndSettle();

      final addToCart = find.text('Add to Cart');
      expect(addToCart, findsOneWidget);
      final button = tester.widget<ElevatedButton>(find
          .ancestor(of: addToCart, matching: find.byType(ElevatedButton))
          .first);
      expect(button.onPressed, isNotNull);

      // Sheet shows the real price…
      expect(find.text('₹3,500'), findsWidgets);
      // …and none of the quote-flow affordances.
      expect(find.text('Reserve — price on confirmation'), findsNothing);
      expect(find.text('Price confirmed on call before payment'),
          findsNothing);
      expect(find.text('On request'), findsNothing);
    });
  });
}
