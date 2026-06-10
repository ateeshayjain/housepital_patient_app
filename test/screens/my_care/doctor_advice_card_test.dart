// test/screens/my_care/doctor_advice_card_test.dart
//
// Widget tests for the "Doctor's Advice" card on the My Care tab:
//  • renders all 3 demo recommendations (+ attribution + CTAs)
//  • tapping "Add to cart" on the lab item adds a line to CartProvider
//    (lab price resolved from assets/lab_tests_catalog.json — real asset
//    I/O, so the tap is driven inside tester.runAsync).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/screens/my_care/widgets/doctor_advice_card.dart';

Widget _host(CartProvider cart) => ChangeNotifierProvider<CartProvider>.value(
      value: cart,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: DoctorAdviceCard()),
        ),
      ),
    );

void main() {
  setUp(() {
    // CartProvider persists via SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(WidgetTester tester, CartProvider cart) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(cart));
    await tester.pump();
  }

  testWidgets('renders all 3 recommendations with notes and CTAs',
      (tester) async {
    final cart = CartProvider();
    await pump(tester, cart);

    expect(find.text("Doctor's Advice"), findsOneWidget);

    // Titles
    expect(find.text('Nebulizer (Rental)'), findsOneWidget);
    expect(find.text('CBC Blood Test'), findsOneWidget);
    expect(find.text('Physiotherapy (Basic)'), findsOneWidget);

    // Notes
    expect(find.text('Twice daily for chest congestion'), findsOneWidget);
    expect(find.text('Repeat after 1 week of antibiotics'), findsOneWidget);
    expect(find.text('2 weeks, post-bedrest mobility'), findsOneWidget);

    // Attribution per item
    expect(find.text('Recommended by Dr. Ananya Sharma · 2 days ago'),
        findsNWidgets(3));

    // CTAs: equipment + lab get "Add to cart"; service gets "Book".
    expect(find.text('Add to cart'), findsNWidgets(2));
    expect(find.text('Book'), findsOneWidget);
    expect(find.text('Add all to cart'), findsOneWidget);
  });

  testWidgets(
      'tapping Add to cart on the lab item adds it to CartProvider '
      'and flips the button to Added', (tester) async {
    final cart = CartProvider();
    await pump(tester, cart);
    expect(cart.itemCount, 0);

    // The lab catalog is loaded from a bundled asset (real I/O) — run the
    // tap + wait inside runAsync so the load can actually complete.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('advice-add-rec_cbc')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(cart.itemCount, 1);
    expect(cart.items.first.equipmentId, 'lab-cbc');
    expect(cart.items.first.isService, isTrue);

    // Button flipped to the session "Added" state.
    expect(find.text('Added'), findsOneWidget);
    expect(find.byKey(const Key('advice-add-rec_cbc')), findsNothing);

    // SnackBar confirmation.
    expect(find.text('Added to cart'), findsOneWidget);

    // Drain the SnackBar's display timer so the test ends clean.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
