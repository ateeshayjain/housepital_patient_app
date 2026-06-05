// test/screens/sos/sos_screen_test.dart
//
// Tests the SOS screen (audit M-4 changes):
//   - address card renders when patient.address is set
//   - empty-state CTA "Add your address in Profile" shows when missing
//   - 4 option tiles render (medical, staff, 112, ambulance)
//   - Ambulance tile routes to /raise-concern (soft fallback)
//   - Each call tile launches tel: with the right number (mocked launcher)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';

import 'package:housepital_patient/config/constants.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/screens/sos/sos_screen.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/utils/app_localizations.dart';

// Subclass that lets us set the patient without triggering loadDashboard().
class _TestAppProvider extends AppProvider {
  _TestAppProvider() : super(ApiService());

  Patient? _patient;
  @override
  Patient? get currentPatient => _patient;

  void setPatient(Patient? p) {
    _patient = p;
    notifyListeners();
  }
}

// ── Fake URL launcher — records launched URLs and answers canLaunch=true ────

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

Widget _host({
  required AppProvider app,
  Map<String, WidgetBuilder> routes = const {},
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    routes: {
      ...routes,
      '/patient-profile': (_) =>
          const Scaffold(body: Text('Patient profile route')),
      '/raise-concern': (_) =>
          const Scaffold(body: Text('Raise concern route')),
    },
    home: ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: const SOSScreen(),
    ),
  );
}

Patient _patient({String? address}) => Patient(
      id: 'p-1',
      name: 'Test Patient',
      address: address,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeUrlLauncher fakeLauncher;
  late _TestAppProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeLauncher;
    provider = _TestAppProvider();
    // Let AppProvider's constructor-fired async loads (_loadLanguage,
    // _loadProfilePhoto) settle so they don't fire notifyListeners
    // during the next test and disrupt the widget tree.
    await Future<void>.delayed(Duration.zero);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Address card
  // ───────────────────────────────────────────────────────────────────────────
  group('SOSScreen — address card', () {
    testWidgets('with patient address → address card + Copy button render',
        (tester) async {
      provider.setPatient(_patient(address: 'A-12, Sector 21, Noida'));
      await tester.runAsync(() async {
        await tester.pumpWidget(_host(app: provider));
        // Let async i18n delegate load complete inside runAsync.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('Dispatch address'), findsOneWidget);
      expect(find.text('A-12, Sector 21, Noida'), findsOneWidget);
      // Copy icon button is tooltipped.
      expect(find.byTooltip('Copy address'), findsOneWidget);
    });

    testWidgets('Copy button writes the address to the clipboard',
        (tester) async {
      provider.setPatient(_patient(address: 'B-14, DLF Phase 2, Gurgaon'));
      await tester.runAsync(() async {
        await tester.pumpWidget(_host(app: provider));
        // Let async i18n delegate load complete inside runAsync.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Intercept clipboard plugin calls.
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      final setData = calls.firstWhere(
        (c) => c.method == 'Clipboard.setData',
        orElse: () => const MethodCall('none'),
      );
      expect(setData.method, 'Clipboard.setData');
      expect(
          (setData.arguments as Map)['text'], 'B-14, DLF Phase 2, Gurgaon');

      // Cleanup
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets(
        'with NO address → empty-state CTA visible, taps route to /patient-profile',
        (tester) async {
      provider.setPatient(_patient(address: null));
      await tester.runAsync(() async {
        await tester.pumpWidget(_host(app: provider));
        // Let async i18n delegate load complete inside runAsync.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(
          find.text('Add your address in Profile so we can dispatch faster'),
          findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Patient profile route'), findsOneWidget);
    });

    testWidgets('empty-string address is treated as missing', (tester) async {
      provider.setPatient(_patient(address: '   '));
      await tester.runAsync(() async {
        await tester.pumpWidget(_host(app: provider));
        // Let async i18n delegate load complete inside runAsync.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(
          find.text('Add your address in Profile so we can dispatch faster'),
          findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Tiles
  // ───────────────────────────────────────────────────────────────────────────
  group('SOSScreen — option tiles', () {
    testWidgets('renders 4 SOS option tiles (medical/staff/112/ambulance)',
        (tester) async {
      provider.setPatient(_patient(address: 'addr'));
      await tester.runAsync(() async {
        await tester.pumpWidget(_host(app: provider));
        // Let async i18n delegate load complete inside runAsync.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // The 4 tiles, identified by their distinct subtitles.
      expect(find.textContaining('Call ${AppConstants.emergencyPhone}'),
          findsOneWidget);
      expect(find.text('Alert Housepital Ops'), findsOneWidget);
      expect(find.text('National Emergency Number'), findsOneWidget);
      expect(find.text('Request ACLS ambulance dispatch'), findsOneWidget);
      expect(find.text('Book Housepital Ambulance'), findsOneWidget);
    });

    testWidgets('ambulance tile tap routes to /raise-concern (soft fallback)',
        (tester) async {
      provider.setPatient(_patient(address: 'addr'));
      await tester.runAsync(() async {
        await tester.pumpWidget(_host(app: provider));
        // Let async i18n delegate load complete inside runAsync.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Ambulance tile sits at the bottom of a scroll view — bring it in-frame
      // so the tap target is reachable in the 800x600 test viewport.
      await tester.scrollUntilVisible(
        find.text('Book Housepital Ambulance'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Book Housepital Ambulance'));
      await tester.pumpAndSettle();

      expect(find.text('Raise concern route'), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // tel: launches
  // ───────────────────────────────────────────────────────────────────────────
  group('SOSScreen — tel: launches', () {
    testWidgets('medical emergency tile launches tel:emergencyPhone',
        (tester) async {
      provider.setPatient(_patient(address: 'addr'));
      await tester.runAsync(() async {
        await tester.pumpWidget(_host(app: provider));
        // Let async i18n delegate load complete inside runAsync.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      await tester.tap(find.textContaining('Call ${AppConstants.emergencyPhone}'));
      await tester.pump();

      expect(fakeLauncher.launchedUrls, contains('tel:${AppConstants.emergencyPhone}'));
    });

    testWidgets('staff emergency tile launches tel:supportPhone',
        (tester) async {
      provider.setPatient(_patient(address: 'addr'));
      await tester.runAsync(() async {
        await tester.pumpWidget(_host(app: provider));
        // Let async i18n delegate load complete inside runAsync.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      await tester.tap(find.text('Alert Housepital Ops'));
      await tester.pump();

      expect(fakeLauncher.launchedUrls,
          contains('tel:${AppConstants.supportPhone}'));
    });

    testWidgets('112 tile launches tel:112', (tester) async {
      provider.setPatient(_patient(address: 'addr'));
      await tester.runAsync(() async {
        await tester.pumpWidget(_host(app: provider));
        // Let async i18n delegate load complete inside runAsync.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      await tester.tap(find.text('National Emergency Number'));
      await tester.pump();

      expect(fakeLauncher.launchedUrls,
          contains('tel:${AppConstants.emergencyNumber112}'));
    });
  });
}
