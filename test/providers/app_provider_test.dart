// test/providers/app_provider_test.dart
//
// Tests for AppProvider initial state and synchronous behavior.
// Uses SharedPreferences mock and a minimal ApiService stub.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/services/api_service.dart';

void main() {
  // Ensure Flutter bindings are initialised for SharedPreferences
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppProvider provider;

  setUp(() {
    // Seed empty SharedPreferences so _loadLanguage doesn't crash
    SharedPreferences.setMockInitialValues({});
    provider = AppProvider(ApiService());
  });

  // =========================================================================
  // Initial state
  // =========================================================================
  group('AppProvider — initial state', () {
    test('currentPatient is null', () {
      expect(provider.currentPatient, isNull);
    });

    test('patients list is empty', () {
      expect(provider.patients, isEmpty);
    });

    test('activeDeployment is null', () {
      expect(provider.activeDeployment, isNull);
    });

    test('latestVitals is null', () {
      expect(provider.latestVitals, isNull);
    });

    test('todayAttendance is null', () {
      expect(provider.todayAttendance, isNull);
    });

    test('todayReport is null', () {
      expect(provider.todayReport, isNull);
    });

    test('dashboardError is null', () {
      expect(provider.dashboardError, isNull);
    });

    test('isDashboardLoading starts false', () {
      expect(provider.isDashboardLoading, isFalse);
    });

    test('amountDue starts at 0', () {
      expect(provider.amountDue, 0);
    });

    test('dueDate is null', () {
      expect(provider.dueDate, isNull);
    });
  });

  // =========================================================================
  // Locale defaults
  // =========================================================================
  group('AppProvider — locale', () {
    test('locale defaults to "en"', () {
      // _loadLanguage is async and reads SharedPreferences.
      // With empty prefs, default is 'en'.
      expect(provider.locale.languageCode, 'en');
    });

    test('setLanguage changes locale to "hi"', () async {
      await provider.setLanguage('hi');
      expect(provider.locale.languageCode, 'hi');
    });

    test('setLanguage persists to SharedPreferences', () async {
      await provider.setLanguage('hi');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('preferred_language'), 'hi');
    });

    test('setLanguage back to "en"', () async {
      await provider.setLanguage('hi');
      await provider.setLanguage('en');
      expect(provider.locale.languageCode, 'en');
    });
  });

  // =========================================================================
  // Language loaded from SharedPreferences
  // =========================================================================
  group('AppProvider — language from prefs', () {
    test('loads saved language on construction', () async {
      SharedPreferences.setMockInitialValues({
        'preferred_language': 'hi',
      });
      final p = AppProvider(ApiService());
      // Give _loadLanguage a tick to complete
      await Future.delayed(Duration.zero);
      expect(p.locale.languageCode, 'hi');
    });
  });
}
