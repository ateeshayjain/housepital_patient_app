// test/screens/my_care/service_detail_screen_test.dart
//
// Widget tests for the Service Detail screen's owner-feedback fixes:
//  • Hero header is an INSET squircle-16 ribbon (16px horizontal margin,
//    RoundedSuperellipseBorder), not a full-bleed edge-to-edge rectangle.
//  • Staff rows no longer use green for identity: avatars are the orange
//    initials tile, shift duration is plain bold text; the only green left
//    is the tiny checked-in status dot.
//  • Medications actions are two EQUAL 44pt tonal pills ('Schedule' /
//    'Medications') that hold a single line even at 320px.
//  • Records row offers 'Invoice (PDF)' (matched via OrdersProvider) and
//    'Service history' (→ /attendance-history); the Invoice pill is hidden
//    when no order matches rather than erroring.
//
// Provider + pump pattern copied from test/screens/overflow_smoke_test.dart
// (SharedPreferences mocked before build, runAsync so the async
// AppLocalizations delegate resolves).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/config/theme.dart';
import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/models/my_care_models.dart';
import 'package:housepital_patient/providers/my_care_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/screens/my_care/service_detail_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';

class _TestMyCareProvider extends MyCareProvider {
  _TestMyCareProvider() : super(ApiService());

  @override
  ServiceDetail? get selectedServiceDetail => DemoData.icuServiceDetail;
  @override
  bool get isDetailLoading => false;
  @override
  String? get detailError => null;

  @override
  Future<void> loadServiceDetail(String deploymentId) async {}
}

/// Seeds demo orders synchronously (the real provider loads from
/// SharedPreferences asynchronously, leaving an empty list during a pump).
class _TestOrdersProvider extends OrdersProvider {
  _TestOrdersProvider({List<Map<String, dynamic>>? orders})
      : _testOrders = orders ?? DemoData.orders;

  final List<Map<String, dynamic>> _testOrders;

  @override
  List<Map<String, dynamic>> get orders => _testOrders;
}

/// Records pushNamed routes so navigation targets can be asserted without
/// building the destination screens (they'd need their own providers).
class _RouteLog {
  String? lastRoute;
  Object? lastArguments;
}

Widget _host({
  OrdersProvider? ordersProvider,
  _RouteLog? routeLog,
  ThemeMode themeMode = ThemeMode.light,
}) =>
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: HousepitalTheme.lightTheme,
        darkTheme: HousepitalTheme.darkTheme,
        themeMode: themeMode,
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        onGenerateRoute: (settings) {
          routeLog?.lastRoute = settings.name;
          routeLog?.lastArguments = settings.arguments;
          return MaterialPageRoute(
              builder: (_) => const Scaffold(body: SizedBox()),
              settings: settings);
        },
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<MyCareProvider>.value(
                value: _TestMyCareProvider()),
            ChangeNotifierProvider<OrdersProvider>.value(
                value: ordersProvider ?? _TestOrdersProvider()),
          ],
          child: ServiceDetailScreen(service: DemoData.activeServices[0]),
        ),
      ),
    );

Future<void> _pumpAt(
  WidgetTester tester,
  Size size, {
  OrdersProvider? ordersProvider,
  _RouteLog? routeLog,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await tester.pumpWidget(
        _host(ordersProvider: ordersProvider, routeLog: routeLog));
    // Async AppLocalizations delegate resolves during this delay.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

const _phone = Size(375, 812);
const _narrow = Size(320, 568);

void main() {
  group('Hero ribbon (issue 1)', () {
    testWidgets('header is an inset squircle ribbon, not full-bleed',
        (tester) async {
      await _pumpAt(tester, _phone);

      // The ribbon: solid orange ShapeDecoration with squircle-16 corners.
      final ribbon = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere((c) =>
              c.decoration is ShapeDecoration &&
              (c.decoration as ShapeDecoration).shape
                  is RoundedSuperellipseBorder &&
              (c.decoration as ShapeDecoration).color ==
                  HousepitalColors.orange);

      expect(ribbon.margin, const EdgeInsets.symmetric(horizontal: 16),
          reason: 'Ribbon must be inset 16px, not edge-to-edge.');

      // Inset on both sides: the painted (decorated) box is narrower than
      // the screen and starts 16px in. (The Container's own render box
      // includes the margin, so measure the inner DecoratedBox.)
      final ribbonFinder = find.byWidget(ribbon);
      final painted = find
          .descendant(of: ribbonFinder, matching: find.byType(DecoratedBox))
          .first;
      final rect = tester.getRect(painted);
      expect(rect.left, 16);
      expect(rect.width, 375 - 32);

      // Ribbon starts BELOW the glass app bar (not butted underneath it).
      expect(rect.top, greaterThanOrEqualTo(kToolbarHeight));

      // All header content survived the restyle.
      expect(find.text('Day 15 of 30'), findsOneWidget);
      expect(find.textContaining('Started '), findsOneWidget);
      expect(find.textContaining('/day'), findsOneWidget);
      expect(
          find.descendant(
              of: ribbonFinder,
              matching: find.byType(LinearProgressIndicator)),
          findsOneWidget);
    });
  });

  group('Staff on duty (issue 2)', () {
    testWidgets('avatars are orange initials tiles, not green', (tester) async {
      await _pumpAt(tester, _phone);

      final avatars = tester
          .widgetList<CircleAvatar>(find.byType(CircleAvatar))
          .toList();
      expect(avatars, isNotEmpty);
      for (final avatar in avatars) {
        expect(avatar.backgroundColor, isNot(HousepitalColors.success),
            reason: 'Green is reserved for good-status, not identity.');
        expect(avatar.backgroundColor,
            HousepitalColors.orange.withValues(alpha: 0.12),
            reason: 'Avatar uses the orange @0.12 initials-tile fill.');
        final initials = avatar.child as Text?;
        expect(initials?.style?.color, HousepitalColors.orangeText,
            reason: 'Initials use orangeText on the tinted tile.');
      }
    });

    testWidgets('shift duration is plain bold text; green only as status dot',
        (tester) async {
      await _pumpAt(tester, _phone);

      // Both demo staff are checked in → two duration labels ending in 'm'.
      final durations = tester
          .widgetList<Text>(find.textContaining(RegExp(r'^\d+h \d+m$')))
          .toList();
      expect(durations.length, 2);
      for (final t in durations) {
        expect(t.style?.color, isNot(HousepitalColors.success));
        expect(t.style?.color, HousepitalColors.black);
        expect(t.style?.fontWeight, FontWeight.w700);
      }

      // The literal checked-in status keeps a small green dot (6x6 — the
      // 12x12 circles belong to the 7-day attendance calendar).
      expect(find.textContaining('Checked in'), findsNWidgets(2));
      final dots = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).shape == BoxShape.circle &&
              (c.decoration as BoxDecoration).color ==
                  HousepitalColors.success &&
              c.constraints == BoxConstraints.tight(const Size(6, 6)));
      expect(dots.length, 2);
    });
  });

  group('Medications pills (issue 3)', () {
    testWidgets('two equal 44pt single-line pills at 320px', (tester) async {
      await _pumpAt(tester, _narrow);

      final schedule = find.widgetWithText(FilledButton, 'Schedule');
      final meds = find.widgetWithText(FilledButton, 'Medications');
      expect(schedule, findsOneWidget);
      expect(meds, findsOneWidget);

      final scheduleSize = tester.getSize(schedule);
      final medsSize = tester.getSize(meds);
      expect(scheduleSize.height, 44);
      expect(medsSize.height, 44);
      expect(scheduleSize.width, medsSize.width,
          reason: 'Expanded pills must be equal width.');
      expect(tester.takeException(), isNull);
    });
  });

  group('Records actions (issue 4)', () {
    testWidgets('Invoice + Service history pills render with demo orders',
        (tester) async {
      await _pumpAt(tester, _phone);

      expect(find.widgetWithText(FilledButton, 'Invoice (PDF)'),
          findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Service history'),
          findsOneWidget);
    });

    testWidgets('Service history navigates to /attendance-history with the '
        'deployment id', (tester) async {
      final log = _RouteLog();
      await _pumpAt(tester, _phone, routeLog: log);

      final pill = find.widgetWithText(FilledButton, 'Service history');
      await tester.ensureVisible(pill);
      await tester.pump();
      await tester.tap(pill, warnIfMissed: false);
      await tester.pump();

      expect(log.lastRoute, '/attendance-history');
      expect(log.lastArguments,
          DemoData.activeServices[0].deploymentIds.first);
    });

    testWidgets('Invoice pill is hidden when no order matches',
        (tester) async {
      await _pumpAt(tester, _phone,
          ordersProvider: _TestOrdersProvider(orders: []));

      expect(find.widgetWithText(FilledButton, 'Invoice (PDF)'),
          findsNothing);
      // History pill survives — it doesn't depend on orders.
      expect(find.widgetWithText(FilledButton, 'Service history'),
          findsOneWidget);
    });

    testWidgets('order matching prefers items overlapping the service name '
        'and falls back to a service-type order', (tester) async {
      // Demo data has no item literally named 'ICU Setup at Home', so the
      // fallback must pick the first order containing isService items
      // (HPL-BOOK-10002), never the equipment-only order.
      await _pumpAt(tester, _phone);
      expect(find.widgetWithText(FilledButton, 'Invoice (PDF)'),
          findsOneWidget);
    });
  });
}
