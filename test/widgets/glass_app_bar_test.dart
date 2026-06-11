// test/widgets/glass_app_bar_test.dart
//
// Guards the GlassAppBar NAVIGATION CONSISTENCY CONTRACT documented in
// lib/widgets/glass.dart — the rule that keeps chrome from "dancing" between
// screens:
//   • trailing action order is [custom actions…, search, home] — fixed;
//   • search is ON by default and routes to '/search';
//   • home is ON by default, pops to the first route (tab switch is a
//     null-safe no-op when no MainShell is mounted);
//   • showSearch/showHome: false remove the icons;
//   • the bar stays transparent inside its GlassSurface (fill comes from the
//     surface, not the AppBar — an opaque AppBar would kill the glass read).
//
// A screen that hand-rolls its own AppBar won't be caught here — but any
// regression to GlassAppBar itself (reordering, dropped tooltip, opaque
// background) fails this suite.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/widgets/glass.dart';

Widget _host({
  Widget? home,
  required Widget pushed,
}) {
  return MaterialApp(
    routes: {
      '/search': (_) => const Scaffold(body: Text('SEARCH SCREEN')),
    },
    home: home ??
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => pushed)),
                child: const Text('go'),
              ),
            ),
          ),
        ),
  );
}

Future<void> _push(WidgetTester tester) async {
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('defaults: search and home present, in order, after custom '
      'actions', (tester) async {
    await tester.pumpWidget(_host(
      pushed: Scaffold(
        appBar: GlassAppBar(
          title: const Text('Detail'),
          actions: [
            IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Filter',
                onPressed: () {}),
          ],
        ),
        body: const SizedBox(),
      ),
    ));
    await _push(tester);

    expect(find.byTooltip('Cart'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Home'), findsOneWidget);

    // Fixed trailing order: custom → cart → search → home (left to right).
    final filterX = tester.getCenter(find.byIcon(Icons.tune)).dx;
    final cartX =
        tester.getCenter(find.byIcon(Icons.shopping_cart_outlined)).dx;
    final searchX = tester.getCenter(find.byIcon(Icons.search)).dx;
    final homeX = tester.getCenter(find.byIcon(Icons.home_outlined)).dx;
    expect(filterX, lessThan(cartX),
        reason: 'custom actions must precede cart');
    expect(cartX, lessThan(searchX), reason: 'cart must precede search');
    expect(searchX, lessThan(homeX), reason: 'search must precede home');

    // Back button auto-implied on the pushed route.
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('search action routes to /search', (tester) async {
    await tester.pumpWidget(_host(
      pushed: Scaffold(
        appBar: const GlassAppBar(title: Text('Detail')),
        body: const SizedBox(),
      ),
    ));
    await _push(tester);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('SEARCH SCREEN'), findsOneWidget);
  });

  testWidgets('home action pops back to the first route', (tester) async {
    await tester.pumpWidget(_host(
      pushed: Scaffold(
        appBar: const GlassAppBar(title: Text('Detail')),
        body: const SizedBox(),
      ),
    ));
    await _push(tester);
    expect(find.text('go'), findsNothing);

    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    // Back on the root route; switchToTab was a null-safe no-op (no shell).
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('showSearch/showHome false remove the icons', (tester) async {
    await tester.pumpWidget(_host(
      pushed: Scaffold(
        appBar: const GlassAppBar(
          title: Text('Root tab'),
          showSearch: false,
          showHome: false,
        ),
        body: const SizedBox(),
      ),
    ));
    await _push(tester);

    expect(find.byTooltip('Search'), findsNothing);
    expect(find.byTooltip('Home'), findsNothing);
  });

  testWidgets('AppBar inside GlassSurface stays transparent', (tester) async {
    await tester.pumpWidget(_host(
      pushed: Scaffold(
        appBar: const GlassAppBar(title: Text('Detail')),
        body: const SizedBox(),
      ),
    ));
    await _push(tester);

    expect(
        find.descendant(
            of: find.byType(GlassSurface), matching: find.byType(AppBar)),
        findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, Colors.transparent);
    expect(appBar.elevation, 0);
    expect(appBar.surfaceTintColor, Colors.transparent);
  });

  testWidgets('preferredSize includes the bottom widget height',
      (tester) async {
    const bar = GlassAppBar(
      title: Text('T'),
      bottom: PreferredSize(
          preferredSize: Size.fromHeight(48), child: SizedBox(height: 48)),
    );
    expect(bar.preferredSize.height, kToolbarHeight + 48);
    const plain = GlassAppBar(title: Text('T'));
    expect(plain.preferredSize.height, kToolbarHeight);
  });
}
