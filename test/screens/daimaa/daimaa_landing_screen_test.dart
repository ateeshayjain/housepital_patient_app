// test/screens/daimaa/daimaa_landing_screen_test.dart
//
// Tests the Dai Maa sub-brand landing screen:
//   - renders Japa Maid and Nanny service cards
//   - cards have plum border
//   - "Call Dai Maa Coordinator" launches tel:9050200183 (mocked)
//   - AppBar uses plum colour

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:housepital_patient/config/daimaa_theme.dart';
import 'package:housepital_patient/screens/daimaa/daimaa_landing_screen.dart';

// ── Fake URL launcher ───────────────────────────────────────────────────────

class _FakeUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }

  @override
  LinkDelegate? get linkDelegate => null;
}

Widget _host() {
  return MaterialApp(
    routes: {
      '/assessment-request': (_) =>
          const Scaffold(body: Text('Assessment request route')),
    },
    home: const DaiMaaLandingScreen(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeUrlLauncher fakeLauncher;

  setUp(() {
    fakeLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeLauncher;
  });

  group('DaiMaaLandingScreen — service cards', () {
    testWidgets('renders both Japa Maid and Nanny cards', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text('Japa Maid'), findsOneWidget);
      expect(find.text('Nanny'), findsOneWidget);
    });

    testWidgets('shows age ranges on each card', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text('0 – 7 months'), findsOneWidget);
      expect(find.text('7 months – 5 years'), findsOneWidget);
    });

    testWidgets('renders "Book Assessment" CTA on each card', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // 2 cards => 2 CTAs.
      expect(find.text('Book Assessment'), findsNWidgets(2));
    });

    testWidgets(
        'service cards have a plum-coloured border (DaiMaaColors.plum in light mode)',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // Find every Container that has a 1.5-wide plum border.
      final plumBorderContainers = find
          .byType(Container)
          .evaluate()
          .where((el) {
            final container = el.widget as Container;
            final deco = container.decoration;
            if (deco is! BoxDecoration) return false;
            final border = deco.border;
            if (border is! Border) return false;
            return border.top.color == DaiMaaColors.plum &&
                border.top.width == 1.5;
          })
          .toList();

      // 2 service cards + 1 coordinator-CTA container (which uses pink, not plum in light mode);
      // verify at least the 2 service cards bordered plum are present.
      expect(plumBorderContainers.length, greaterThanOrEqualTo(2),
          reason: 'Expected at least 2 plum-bordered Containers for the service cards.');
    });

    testWidgets('tapping a card navigates to /assessment-request', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Japa Maid'));
      await tester.pumpAndSettle();

      expect(find.text('Assessment request route'), findsOneWidget);
    });
  });

  group('DaiMaaLandingScreen — AppBar styling', () {
    testWidgets('AppBar background colour is DaiMaaColors.plum', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, DaiMaaColors.plum);
      expect(appBar.foregroundColor, Colors.white);
    });

    testWidgets('AppBar title reads "Dai Maa"', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // Strict: title is the literal "Dai Maa" — appears in AppBar and in the
      // brand lockup. Verify at least one matches.
      expect(find.text('Dai Maa'), findsOneWidget);
    });
  });

  group('DaiMaaLandingScreen — Call coordinator CTA', () {
    testWidgets('Call button launches tel:${DaiMaaColors.phone}', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // Bring the coordinator CTA into the viewport.
      final callBtn = find.text('Call ${DaiMaaColors.phoneDisplay}');
      await tester.scrollUntilVisible(
        callBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(callBtn);
      // Two pumps so the async canLaunchUrl → launchUrl chain completes.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fakeLauncher.launchedUrls, contains('tel:${DaiMaaColors.phone}'));
    });

    testWidgets('Call button uses plum background colour', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final callBtn = find.text('Call ${DaiMaaColors.phoneDisplay}');
      await tester.scrollUntilVisible(
        callBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );

      // Find the ElevatedButton ancestor of the call text.
      final btn = tester.widget<ElevatedButton>(
        find.ancestor(
          of: callBtn,
          matching: find.byType(ElevatedButton),
        ),
      );
      // ElevatedButton.styleFrom(backgroundColor: plum) resolves to a
      // WidgetStateProperty<Color>; verify it returns plum for the default state.
      final bg = btn.style?.backgroundColor?.resolve({});
      expect(bg, DaiMaaColors.plum);
    });
  });

  group('DaiMaaLandingScreen — brand lockup', () {
    testWidgets('displays the DAI MAA lockup at the bottom', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // The lockup string is "DAI MAA | A Housepital Company".
      // It appears in the brand header AND at the bottom — expect ≥ 1.
      expect(find.text(DaiMaaColors.lockup), findsWidgets);
    });

    testWidgets('displays the "Maa Jaisi Care" tagline', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text(DaiMaaColors.tagline), findsOneWidget);
    });
  });
}
