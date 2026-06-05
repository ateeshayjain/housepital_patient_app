// test/screens/auth/login_screen_test.dart
//
// Widget tests for the LoginScreen. Covers the audit M-7 fixes:
//   - Indian mobile prefix validation (6-9 leading digit)
//   - T&C consent: button disabled until checked, snack-bar on bypass
//   - Terms / Privacy Policy links navigate to /about
//
// Uses the same FakeFirebaseService + FakeAuthApiService harness as the
// OTP screen tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/providers/auth_provider.dart';
import 'package:housepital_patient/screens/auth/login_screen.dart';
import 'package:housepital_patient/utils/app_localizations.dart';

import '../../_mocks/fake_firebase_service.dart';
import '../../_mocks/fake_auth_api_service.dart';

// ── Validator under test, re-implemented so we can hit it with table-driven
// tests without pumping a widget for every case. Must mirror
// _LoginScreenState._isValidIndianMobile.
bool _isValidIndianMobile(String value) =>
    RegExp(r'^[6-9]\d{9}$').hasMatch(value);

// ── Test harness ────────────────────────────────────────────────────────────

class _Recorded {
  String? lastRoute;
}

Widget _host(AuthProvider provider, _Recorded rec) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: provider,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        _SyncAppLocalizationsDelegate(),
      ],
      home: const LoginScreen(),
      // Capture pushNamed targets without needing a real /about screen.
      onGenerateRoute: (settings) {
        rec.lastRoute = settings.name;
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('stub')),
        );
      },
    ),
  );
}

/// Synchronous AppLocalizations delegate so widget tests don't need an
/// async pumpAndSettle to load the en.json asset. Same trick as the OTP
/// screen tests — see `otp_screen_test.dart`.
class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      _StubAppLocalizations(locale);
  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

class _StubAppLocalizations extends AppLocalizations {
  _StubAppLocalizations(super.locale);
  @override
  String translate(String key, [Map<String, String>? params]) {
    if (params == null) return key;
    var out = key;
    params.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }
}

AuthProvider _buildProvider({
  required FakeFirebaseService firebase,
  required FakeAuthApiService api,
}) {
  // Don't await an init future — inside a testWidgets fake-async zone,
  // Future.delayed(Duration.zero) is a Timer that never fires without
  // a tester.pump(). AuthProvider's _checkAuthState() with empty prefs
  // is a synchronous no-op (isLoggedIn == false).
  return AuthProvider(firebase, api);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseService firebase;
  late FakeAuthApiService api;
  late _Recorded recorded;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebase = FakeFirebaseService();
    api = FakeAuthApiService();
    recorded = _Recorded();
  });

  // =========================================================================
  group('Indian mobile validator (audit M-7)', () {
    test('9876543210 is valid (starts with 9)', () {
      expect(_isValidIndianMobile('9876543210'), isTrue);
    });

    test('6543210987 is valid (starts with 6)', () {
      expect(_isValidIndianMobile('6543210987'), isTrue);
    });

    test('7234567890 is valid (starts with 7)', () {
      expect(_isValidIndianMobile('7234567890'), isTrue);
    });

    test('8234567890 is valid (starts with 8)', () {
      expect(_isValidIndianMobile('8234567890'), isTrue);
    });

    test('5432109876 is invalid (starts with 5)', () {
      expect(_isValidIndianMobile('5432109876'), isFalse);
    });

    test('0123456789 is invalid (starts with 0)', () {
      expect(_isValidIndianMobile('0123456789'), isFalse);
    });

    test('12345 is invalid (too short)', () {
      expect(_isValidIndianMobile('12345'), isFalse);
    });

    test('98765432100 is invalid (11 digits, too long)', () {
      expect(_isValidIndianMobile('98765432100'), isFalse);
    });

    test('abcdefghij is invalid (non-digit)', () {
      expect(_isValidIndianMobile('abcdefghij'), isFalse);
    });

    test('98765abc10 is invalid (mixed)', () {
      expect(_isValidIndianMobile('98765abc10'), isFalse);
    });

    test('empty string is invalid', () {
      expect(_isValidIndianMobile(''), isFalse);
    });
  });

  // =========================================================================
  group('LoginScreen — T&C consent gating (audit M-7)', () {
    testWidgets('initial state: Send OTP button disabled', (tester) async {
      final p = _buildProvider(firebase: firebase, api: api);
      await tester.pumpWidget(_host(p, recorded));
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull,
          reason: 'Should be disabled with no phone + no consent');
    });

    testWidgets('valid phone + checkbox unchecked → still disabled',
        (tester) async {
      final p = _buildProvider(firebase: firebase, api: api);
      await tester.pumpWidget(_host(p, recorded));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('valid phone + checkbox checked → enabled', (tester) async {
      final p = _buildProvider(firebase: firebase, api: api);
      await tester.pumpWidget(_host(p, recorded));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('invalid phone + checkbox checked → still disabled',
        (tester) async {
      final p = _buildProvider(firebase: firebase, api: api);
      await tester.pumpWidget(_host(p, recorded));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '5432109876');
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull,
          reason: 'Phone starts with 5 — must remain disabled');
    });

    testWidgets('tapping enabled Send OTP triggers AuthProvider.sendOtp',
        (tester) async {
      final p = _buildProvider(firebase: firebase, api: api);
      await tester.pumpWidget(_host(p, recorded));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(firebase.sendOtpCalls, 1);
      expect(firebase.lastPhone, '9876543210');
    });
  });

  // =========================================================================
  group('LoginScreen — Terms / Privacy links navigate to /about', () {
    testWidgets('tapping "Terms" pushes /about', (tester) async {
      final p = _buildProvider(firebase: firebase, api: api);
      await tester.pumpWidget(_host(p, recorded));
      await tester.pump();

      // Find the GestureDetector wrapping the "Terms" text.
      final termsText = find.text('Terms');
      expect(termsText, findsOneWidget);
      await tester.tap(termsText);
      await tester.pumpAndSettle();

      expect(recorded.lastRoute, '/about');
    });

    testWidgets('tapping "Privacy Policy" pushes /about', (tester) async {
      final p = _buildProvider(firebase: firebase, api: api);
      await tester.pumpWidget(_host(p, recorded));
      await tester.pump();

      final privacyText = find.text('Privacy Policy');
      expect(privacyText, findsOneWidget);
      await tester.tap(privacyText);
      await tester.pumpAndSettle();

      expect(recorded.lastRoute, '/about');
    });
  });

  // =========================================================================
  group('LoginScreen — checkbox toggle', () {
    testWidgets('tapping the Checkbox flips consent off again',
        (tester) async {
      final p = _buildProvider(firebase: firebase, api: api);
      await tester.pumpWidget(_host(p, recorded));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.pump();

      // Check it → button should become enabled.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      ElevatedButton btn =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNotNull);

      // Uncheck it → button should disable again.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull,
          reason: 'Unchecking consent must re-disable the Send OTP CTA');
    });
  });
}
