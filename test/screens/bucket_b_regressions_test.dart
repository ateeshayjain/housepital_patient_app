// test/screens/bucket_b_regressions_test.dart
//
// The round-4 findings that were not in the "money, harm, lie" set and so
// survived waves 1-3. Each is pinned against the specific behaviour that
// shipped, not against the shape of the fix.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/config/constants.dart';

/// Reads a source file with COMMENTS STRIPPED.
///
/// These tests assert on source text, and every fix here is documented with a
/// comment that quotes the defect it replaced. Asserting against the raw file
/// therefore fails on the documentation of the fix — which is exactly what
/// happened first time: `splash_screen.dart` no longer *contains*
/// `Duration(seconds: 2)` in any code path, only in the paragraph explaining
/// that it used to. A test that punishes explaining yourself is a test that
/// will get the explanations deleted.
String code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('environments — a build can be pointed somewhere other than prod', () {
    test('apiBaseUrl is a dart-define, not a baked constant', () {
      final src = code('lib/config/constants.dart');
      expect(src, contains("String.fromEnvironment(\n    'API_BASE_URL'"),
          reason: 'debug and store builds hit the same server otherwise, and '
              'QA has nowhere to run but production');
    });

    test('the default is unchanged, so an un-defined build behaves as before',
        () {
      expect(AppConstants.apiBaseUrl, 'https://api.housepital.in/v1');
      expect(AppConstants.isNonProductionApi, isFalse);
    });

    test('the assistant URL keeps its own override', () {
      final src = code('lib/config/constants.dart');
      expect(src, contains("String.fromEnvironment('ASSISTANT_API_URL'"));
    });
  });

  group('startup — nothing unnecessary blocks the first frame', () {
    final main = code('lib/main.dart');

    test('Crashlytics/Performance toggles are not awaited', () {
      // Four platform round-trips sat on the critical path before runApp.
      expect(main, isNot(contains('await FirebaseCrashlytics.instance\n'
          '            .setCrashlyticsCollectionEnabled')));
      expect(main, contains('unawaited(FirebaseCrashlytics.instance'));
      expect(main, contains('unawaited(FirebasePerformance.instance'));
    });

    test('the error HANDLERS are still installed synchronously', () {
      // The part that genuinely had to happen early must not have been moved.
      expect(main, contains('FlutterError.onError ='));
      expect(main, contains('PlatformDispatcher.instance.onError ='));
      expect(main, contains('Log.sink ='));
    });

    test('StoreMigrator is STILL awaited — it is a correctness barrier', () {
      // Providers read SharedPreferences in their constructors below it, so a
      // v1 blob would reach a v2 parser. This one must never be optimised.
      expect(main, contains('await StoreMigrator.run();'));
    });

    test('the reminder service is raced by the splash, not awaited', () {
      expect(main, isNot(contains('await MedicationReminderService().init()')));
      expect(main, contains('final Future<void> warmup'));
      expect(main, contains('SplashScreen(warmup:'));
    });
  });

  group('splash — races readiness instead of sleeping 2 seconds', () {
    final src = code('lib/screens/splash_screen.dart');

    test('the unconditional 2-second delay is gone', () {
      expect(src, isNot(contains('Duration(seconds: 2)')),
          reason: 'every awaited startup step had already finished, so those '
              'two seconds displayed a logo over a ready app');
    });

    test('it waits on the warmup future', () {
      expect(src, contains('widget.warmup'));
      expect(src, contains('Future.wait'));
    });

    test('a hung warmup cannot strand the user on a logo', () {
      expect(src, contains('_maxWait'));
      expect(src, contains('Future.any'));
    });

    test('reduced motion shortens the beat rather than removing the screen',
        () {
      expect(src, contains('disableAnimationsOf'));
      expect(src, contains('_reducedMotionBeat'));
    });
  });

  group('glass — an accessible, opaque path exists', () {
    final src = code('lib/widgets/glass.dart');

    test('high contrast or a screen reader drops the blur entirely', () {
      expect(src, contains('reduceTransparencyOf'));
      expect(src, contains('MediaQuery.highContrastOf'));
      expect(src, contains('MediaQuery.accessibleNavigationOf'));
    });

    test('the accessible boundary uses the measured tokens', () {
      // Default edge measures 1.03:1 light / 1.26:1 dark against what sits
      // behind it. WCAG 1.4.11 wants 3:1 to identify a UI component.
      expect(src, contains('glassEdgeAccessible'));
      final theme = code('lib/config/theme.dart');
      expect(theme, contains('Color(0xFF767680)')); // 4.26:1 on the light page
      expect(theme, contains('Color(0xFF8E8E93)')); // 5.22:1 on the dark card
    });

    test('the frosted default is untouched — the owner chose it', () {
      expect(src, contains('BackdropFilter'));
      expect(src, contains('ImageFilter.blur'));
    });
  });

  group('vitals — one reading no longer blanks four charts', () {
    final src = code('lib/screens/reports/vitals_screen.dart');

    test('the sample/real decision is per vital, not global', () {
      expect(src, contains('_mergedVitalsFor('));
      expect(src, contains('_isSampleFor('));
      expect(src, isNot(contains('List<VitalReading> _mergedVitals(')),
          reason: 'the global form made one blood-sugar reading empty the BP, '
              'temperature, SpO2 and pulse charts at once');
    });

    test('each chart is told whether it is showing sample data', () {
      for (final k in const [
        "'systolic'",
        "'temperature'",
        "'spo2'",
        "'sugar'",
        "'pulse'"
      ]) {
        expect(src, contains('isSample: _isSampleFor(manual, $k)'));
      }
    });

    test('the per-chart sample notice renders', () {
      expect(src, contains("t('vitals_sample_label')"));
      expect(src, contains('if (isSample)'));
    });

    test('the empty state is localized and actionable, not "No data"', () {
      expect(src, isNot(contains("Text('No data')")));
      expect(src, isNot(contains("Text('No data available')")));
      expect(src, contains("t('vitals_no_data_title')"));
      expect(src, contains("t('vitals_no_data_body')"));
    });

    test('regenerating the sample series no longer raises the demo flag', () {
      // It fired on every 7d/30d/90d/All tap, remounting the notice pill and
      // firing an ASSERTIVE screen-reader announcement — a false alarm, to
      // the users least able to dismiss it as a glitch.
      final gen = src.substring(src.indexOf('void _generateMockData()'));
      final body = gen.substring(0, gen.indexOf('\n  @override'));
      expect(body, isNot(contains('markServingDemoData')));
    });

    test('build decides the flag for the whole screen, from the data', () {
      expect(src, contains('_chartKeys.any((k) => _isSampleFor(manual, k))'));
      expect(src, contains('DemoMode.markServingLiveData'));
    });
  });

  group('no surface claims an action that did not happen', () {
    test('the daily-report rating does not say "submitted"', () {
      final src = code('lib/screens/reports/daily_report_screen.dart');
      expect(src, isNot(contains("Text('Rating submitted!')")),
          reason: 'that handler pops a dialog and writes nothing at all');
      expect(src, contains("t('feedback_saved_local')"));
    });

    test('the My Care rating does not claim it reached the team', () {
      final src = code('lib/screens/my_care/my_care_screen.dart');
      expect(src, isNot(contains("We've shared your feedback with the team")),
          reason: 'it is written to SharedPreferences and nowhere else');
      expect(src, contains("t('feedback_saved_local')"));
    });

    test('an equipment review does not imply publication', () {
      final src = code('lib/screens/services/equipment_detail_screen.dart');
      expect(src, isNot(contains("Text('Thank you for your review!')")),
          reason: 'inserted locally after the POST fails on a route that does '
              'not exist');
      expect(src, contains("t('review_saved_local')"));
    });

    test('both languages carry the honest strings', () {
      for (final f in const ['assets/i18n/en.json', 'assets/i18n/hi.json']) {
        final m = jsonDecode(File(f).readAsStringSync()) as Map<String, dynamic>;
        for (final k in const [
          'feedback_saved_local',
          'review_saved_local',
          'vitals_sample_label',
          'vitals_no_data_title',
          'vitals_no_data_body',
        ]) {
          expect(m.containsKey(k), isTrue, reason: '$f missing $k');
          expect((m[k] as String).trim(), isNotEmpty);
        }
      }
    });
  });

  group('legal links resolve', () {
    test('Terms/Privacy use www — the apex certificate does not cover it', () {
      final src = code('lib/screens/settings/about_screen.dart');
      expect(src, contains('https://www.housepital.in/terms'));
      expect(src, contains('https://www.housepital.in/privacy'));
      expect(src, isNot(contains("url: 'https://housepital.in/")),
          reason: 'the bare host fails TLS, so the link dies in the browser '
              'with a security warning');
    });
  });
}
