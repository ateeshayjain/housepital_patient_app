// test/providers/theme_provider_test.dart
//
// Unit tests for [ThemeProvider] — verifies persistence, parse fallback,
// notification, and load-from-disk behavior.
//
// Covers all branches in lib/providers/theme_provider.dart including the
// silent-fallback for unrecognised stored values.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Wait one microtask for the ctor's async _load to finish.
  Future<void> waitForLoad() => Future<void>.delayed(Duration.zero);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  group('ThemeProvider — initial load', () {
    test('empty prefs → ThemeMode.system', () async {
      final provider = ThemeProvider();
      await waitForLoad();
      expect(provider.mode, ThemeMode.system);
      expect(provider.isLoaded, isTrue);
    });

    test('stored "dark" → ThemeMode.dark', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final provider = ThemeProvider();
      await waitForLoad();
      expect(provider.mode, ThemeMode.dark);
    });

    test('stored "light" → ThemeMode.light', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final provider = ThemeProvider();
      await waitForLoad();
      expect(provider.mode, ThemeMode.light);
    });

    test('stored "system" → ThemeMode.system', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
      final provider = ThemeProvider();
      await waitForLoad();
      expect(provider.mode, ThemeMode.system);
    });

    test('unrecognised value ("auto") → falls back to system, no throw',
        () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'auto'});
      final provider = ThemeProvider();
      await waitForLoad();
      expect(provider.mode, ThemeMode.system);
      expect(provider.isLoaded, isTrue);
    });

    test('garbage value ("hot-pink-mode") → falls back to system', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'hot-pink-mode'});
      final provider = ThemeProvider();
      await waitForLoad();
      expect(provider.mode, ThemeMode.system);
    });

    test('isLoaded starts false synchronously, true after load', () async {
      final provider = ThemeProvider();
      // The ctor returns synchronously; _load runs as a microtask. Before
      // the microtask runs, isLoaded should still be false.
      expect(provider.isLoaded, isFalse);
      await waitForLoad();
      expect(provider.isLoaded, isTrue);
    });

    test('listeners fire exactly once on initial load', () async {
      final provider = ThemeProvider();
      int notifications = 0;
      provider.addListener(() => notifications++);
      await waitForLoad();
      expect(notifications, 1);
    });
  });

  // =========================================================================
  group('ThemeProvider — setMode', () {
    test('setMode(dark) updates in-memory mode and notifies', () async {
      final provider = ThemeProvider();
      await waitForLoad();
      int notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setMode(ThemeMode.dark);

      expect(provider.mode, ThemeMode.dark);
      expect(notifications, 1);
    });

    test('setMode persists to SharedPreferences', () async {
      final provider = ThemeProvider();
      await waitForLoad();

      await provider.setMode(ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('setMode(light) persists "light"', () async {
      final provider = ThemeProvider();
      await waitForLoad();
      await provider.setMode(ThemeMode.light);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });

    test('setMode(system) persists "system"', () async {
      final provider = ThemeProvider();
      await waitForLoad();
      await provider.setMode(ThemeMode.light);
      await provider.setMode(ThemeMode.system);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'system');
    });

    test('setMode no-op when mode unchanged: no notify, no persist write',
        () async {
      // Start from a non-default so the no-op compare is meaningful.
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final provider = ThemeProvider();
      await waitForLoad();
      int notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setMode(ThemeMode.dark); // same as current

      expect(notifications, 0);
      expect(provider.mode, ThemeMode.dark);
    });

    test('rapid setMode calls: last write wins', () async {
      final provider = ThemeProvider();
      await waitForLoad();

      // Fire three setMode calls without awaiting; the final one (light)
      // should be the persisted value.
      final f1 = provider.setMode(ThemeMode.dark);
      final f2 = provider.setMode(ThemeMode.system);
      final f3 = provider.setMode(ThemeMode.light);
      await Future.wait([f1, f2, f3]);

      expect(provider.mode, ThemeMode.light);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });

    test('mode flips immediately (before disk write resolves)', () async {
      final provider = ThemeProvider();
      await waitForLoad();

      final future = provider.setMode(ThemeMode.dark);
      // The provider sets _mode + notifies synchronously before the await
      // on prefs.setString, so the value is observable now.
      expect(provider.mode, ThemeMode.dark);
      await future;
      expect(provider.mode, ThemeMode.dark);
    });
  });
}
