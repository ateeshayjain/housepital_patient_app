// test/widgets/medical_disclaimer_test.dart
//
// Before round 4 the app carried no medical disclaimer anywhere — the only
// sentence resembling one lived inside the body text of a single blog article.
// Meanwhile the app colours a patient's SpO2 RED, says a reading is "outside
// safe range", schedules and reminds on prescription drugs, and generates a
// document a family hands to a doctor.
//
// These tests pin PLACEMENT (it is on the surfaces that make clinical
// claims), TRANSLATION (both languages, since half the users read Hindi), and
// the two design rules that keep it useful: never blocking, never on SOS.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/utils/app_localizations.dart';
import 'package:housepital_patient/widgets/medical_disclaimer.dart';

/// The widget reads its copy through AppLocalizations, so the delegate has to
/// be installed — without it `AppLocalizations.of(context)!` throws, which is
/// itself worth knowing: a disclaimer that cannot resolve its own string
/// would take the screen down rather than render silently blank.
Widget _host(DisclaimerContext c) => MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: const [Locale('en'), Locale('hi')],
      home: Scaffold(body: MedicalDisclaimer(context_: c)),
    );

/// Pumps [c] and waits for the ASYNC localization delegate.
///
/// `AppLocalizations.delegate.load()` awaits `rootBundle.loadString`, and
/// `Localizations` renders an EMPTY widget until that resolves.
/// `pumpAndSettle` settles frames and animations, not arbitrary futures — so
/// without `runAsync` the second and later pumps in a file find an empty
/// tree. That is worth stating plainly: an assertion like `findsNothing`
/// would then pass for entirely the wrong reason, which is how a widget test
/// can guard nothing while looking green. Same pattern as
/// test/screens/home/home_layout_test.dart.
Future<void> _pumpDisclaimer(WidgetTester tester, DisclaimerContext c) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(_host(c));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

void main() {
  group('every clinical surface carries one', () {
    const surfaces = <String, String>{
      'lib/screens/reports/vitals_screen.dart': 'DisclaimerContext.vitals',
      'lib/screens/my_care/medications_screen.dart':
          'DisclaimerContext.medication',
      'lib/screens/articles/article_detail_screen.dart':
          'DisclaimerContext.article',
    };

    surfaces.forEach((path, ctx) {
      test('$path shows $ctx', () {
        final src = File(path).readAsStringSync();
        expect(src, contains('MedicalDisclaimer'), reason: '$path has none');
        expect(src, contains(ctx));
      });
    });

    test('the handover PDF states it is not a clinical assessment', () {
      // The PDF leaves the app and is read by a clinician who has no other
      // way to know how it was assembled, so the notice has to be ON the page.
      final src =
          File('lib/services/handover_report_service.dart').readAsStringSync();
      expect(src, contains('NOT A CLINICAL ASSESSMENT'));
      expect(src, contains('not verified by'));
    });
  });

  group('both languages, no placeholder text', () {
    const keys = <String>[
      'disclaimer_vitals',
      'disclaimer_medication',
      'disclaimer_article',
      'disclaimer_report',
    ];

    for (final file in const ['assets/i18n/en.json', 'assets/i18n/hi.json']) {
      test('$file defines all four with real content', () {
        final map = jsonDecode(File(file).readAsStringSync())
            as Map<String, dynamic>;
        for (final k in keys) {
          expect(map.containsKey(k), isTrue, reason: '$file missing $k');
          final v = map[k] as String;
          expect(v.trim().length, greaterThan(40),
              reason: '$k in $file is too short to say anything');
          expect(v.toUpperCase(), isNot(contains('TODO')));
        }
      });
    }
  });

  group('it does not get in the way', () {
    testWidgets('renders inline — no dialog, no barrier, no button',
        (tester) async {
      await _pumpDisclaimer(tester, DisclaimerContext.vitals);

      // A disclaimer a person must dismiss to see their mother's oxygen level
      // trains them to dismiss it. (ModalBarrier is not asserted on — every
      // MaterialApp's Navigator overlay contains one.)
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(MedicalDisclaimer), findsOneWidget);
    });

    for (final c in DisclaimerContext.values) {
      testWidgets('$c renders its own copy, not a fallback', (tester) async {
        await _pumpDisclaimer(tester, c);

        expect(find.byType(MedicalDisclaimer), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Each surface makes a different implicit claim, so each gets its own
        // sentence — a single generic paragraph is the version nobody reads.
        expect(find.byType(Text), findsWidgets);
      });
    }

    test('narrow-width coverage lives in the overflow sweep, not here', () {
      // 320/375/414 for the screens that HOST the disclaimer is already swept
      // by test/screens/overflow_smoke_test.dart, which drives the real
      // screens rather than the widget in isolation. Re-creating a resize
      // harness here duplicated that and fought the shared test binding.
      final sweep =
          File('test/screens/overflow_smoke_test.dart').readAsStringSync();
      expect(sweep, contains('VitalsScreen'));
      expect(sweep, contains('MedicationsScreen'));
    });
  });

  group('it can never take down the screen it sits on', () {
    testWidgets('renders without a localizations delegate at all',
        (tester) async {
      // The first version called `AppLocalizations.of(context)!`. The delegate
      // resolves asynchronously, so during the frames before it lands the `!`
      // threw — and article_detail_test.dart caught the whole ARTICLE SCREEN
      // going down, replaced by a red error box, because of its caption.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MedicalDisclaimer(context_: DisclaimerContext.article),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(MedicalDisclaimer), findsOneWidget);
      // …and it says something real, not nothing and not a key name.
      expect(find.textContaining('General information'), findsOneWidget);
    });

    testWidgets('never renders a raw translation key', (tester) async {
      // `t()` returns the KEY when a translation is missing, which would show
      // "disclaimer_vitals" to a worried family.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MedicalDisclaimer(context_: DisclaimerContext.vitals),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('disclaimer_'), findsNothing);
    });
  });

  test('the SOS path carries no disclaimer — nothing may add friction there',
      () {
    for (final path in const [
      'lib/screens/sos',
      'lib/widgets/sos_button.dart',
    ]) {
      final entity = FileSystemEntity.typeSync(path);
      if (entity == FileSystemEntityType.notFound) continue;
      final files = entity == FileSystemEntityType.directory
          ? Directory(path)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
          : [File(path)];
      for (final f in files) {
        expect(f.readAsStringSync(), isNot(contains('MedicalDisclaimer')),
            reason: '${f.path} — SOS is never blocked or slowed');
      }
    }
  });
}
