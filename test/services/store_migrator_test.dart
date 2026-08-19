// test/services/store_migrator_test.dart
//
// StoreMigrator shipped with zero tests and three real defects that only a
// test would have caught — the round-2 audit found all three by reading:
//
//   1. `_migrateFrom(prefs, 1)` with currentVersion == 1 entered `while (1 < 1)`
//      and never stamped, so the devices that most needed a version never got
//      one and re-ran the pre-versioning path on every launch, forever.
//   2. A failing step still advanced the stamp, permanently labelling
//      un-migrated data as migrated — the exact silent data loss the file
//      exists to prevent.
//   3. The "fresh install" inference used a hand-maintained key list that was
//      wrong on the day it was written (9 of 14 live keys).
//
// This file pins the behaviour, not the implementation.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/services/store_migrator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final versionKey = StoreMigrator.versionKeyForTest;

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('first install', () {
    test('stamps at currentVersion and writes nothing else', () async {
      SharedPreferences.setMockInitialValues({});

      await StoreMigrator.run();

      final p = await prefs();
      expect(p.getInt(versionKey), StoreMigrator.currentVersion);
      expect(p.getKeys(), {versionKey},
          reason: 'a fresh install must not gain anything but the stamp');
    });
  });

  group('pre-versioning install (data, no stamp)', () {
    test('is stamped — the case that silently never was', () async {
      // Deliberately NOT 'housepital_orders': that key is now rewritten by the
      // v1->v2 step, so it cannot also serve as the "untouched" fixture.
      SharedPreferences.setMockInitialValues({
        'housepital_cart_items': '[]',
      });

      await StoreMigrator.run();

      final p = await prefs();
      expect(p.getInt(versionKey), StoreMigrator.currentVersion,
          reason: 'without a stamp this device re-runs migration forever');
      expect(p.getString('housepital_cart_items'), '[]',
          reason: 'data no migration claims must survive untouched');
    });

    test('is detected from ANY key, not a curated list', () async {
      // 'housepital_reminders' was missing from the old frozen list, so a
      // device holding only reminders was misread as a fresh install and
      // would have skipped every future migration.
      SharedPreferences.setMockInitialValues({
        'housepital_reminders': '[]',
      });

      await StoreMigrator.run();

      final p = await prefs();
      expect(p.getInt(versionKey), StoreMigrator.currentVersion);
      expect(p.getString('housepital_reminders'), '[]');
    });

    test('running twice is a no-op the second time', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

      await StoreMigrator.run();
      await StoreMigrator.run();

      final p = await prefs();
      expect(p.getInt(versionKey), StoreMigrator.currentVersion);
      expect(p.getString('theme_mode'), 'dark');
    });
  });

  group('already current', () {
    test('leaves the stamp and the data alone', () async {
      SharedPreferences.setMockInitialValues({
        versionKey: StoreMigrator.currentVersion,
        'housepital_cart_items': '[{"id":"x"}]',
      });

      await StoreMigrator.run();

      final p = await prefs();
      expect(p.getInt(versionKey), StoreMigrator.currentVersion);
      expect(p.getString('housepital_cart_items'), '[{"id":"x"}]');
    });
  });

  group('downgrade', () {
    test('refuses to migrate backwards and preserves the newer stamp',
        () async {
      final newer = StoreMigrator.currentVersion + 5;
      SharedPreferences.setMockInitialValues({
        versionKey: newer,
        'housepital_orders': '[{"id":"from-the-future"}]',
      });

      await StoreMigrator.run();

      final p = await prefs();
      expect(p.getInt(versionKey), newer,
          reason: 'an older app must not claim data written by a newer one');
      expect(p.getString('housepital_orders'), '[{"id":"from-the-future"}]',
          reason: 'a wrong migration is worse than a missing one');
    });
  });

  group('never throws', () {
    test('a corrupt stamp does not stop the app from starting', () async {
      // run() sits in main() BEFORE runApp — an escaping exception is a
      // permanently black screen, not a crash report.
      SharedPreferences.setMockInitialValues({
        versionKey: 'not-an-int',
        'housepital_orders': '[]',
      });

      await expectLater(StoreMigrator.run(), completes);
    });
  });

  group('quarantine', () {
    test('COPIES the value aside and leaves the original in place', () async {
      SharedPreferences.setMockInitialValues({
        'housepital_orders': '{"corrupt": true}',
      });
      final p = await prefs();

      await StoreMigrator.quarantine(p, 'housepital_orders', 1);

      expect(p.getString('__quarantine_v1_housepital_orders'),
          '{"corrupt": true}',
          reason: 'support must be able to recover the original bytes');
      expect(p.getString('housepital_orders'), '{"corrupt": true}',
          reason: 'quarantine copies — the migration step decides what to '
              'overwrite, and it does so knowingly');
    });

    test('is a no-op for a key that does not exist', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await prefs();

      await StoreMigrator.quarantine(p, 'not_here', 1);

      expect(p.getKeys(), isEmpty);
    });

    test('preserves non-string types', () async {
      SharedPreferences.setMockInitialValues({
        'an_int': 7,
        'a_bool': true,
        'a_list': <String>['a', 'b'],
      });
      final p = await prefs();

      await StoreMigrator.quarantine(p, 'an_int', 2);
      await StoreMigrator.quarantine(p, 'a_bool', 2);
      await StoreMigrator.quarantine(p, 'a_list', 2);

      expect(p.getInt('__quarantine_v2_an_int'), 7);
      expect(p.getBool('__quarantine_v2_a_bool'), true);
      expect(p.getStringList('__quarantine_v2_a_list'), ['a', 'b']);
    });
  });
  group('the migration LOOP itself', () {
    // Round 3: the loop body — the failed-step guard, the early return, the
    // version increment — was executed by NO test, because `_migrations` was
    // empty and private. Those three lines are the ones that prevent silent
    // data loss. debugSetMigrations makes them reachable.
    tearDown(StoreMigrator.debugResetMigrations);

    test('a FAILING step stops at the last good version and does not advance',
        () async {
      SharedPreferences.setMockInitialValues({versionKey: 1});
      StoreMigrator.debugSetMigrations({
        1: (p) async => throw StateError('step 1 blew up'),
        2: (p) async => p.setString('step2_ran', 'yes'),
      });

      await StoreMigrator.run();

      final p = await prefs();
      expect(p.getInt(versionKey), 1,
          reason: 'a failed step must leave the LAST GOOD version so the '
              'migration is retried next launch — advancing it labels '
              'un-migrated data as migrated, which is silent data loss');
      expect(p.containsKey('step2_ran'), isFalse,
          reason: 'later steps must not run on top of a failed one');
    });

    test('the failed step is RETRIED on the next launch', () async {
      SharedPreferences.setMockInitialValues({versionKey: 1});
      var attempts = 0;
      StoreMigrator.debugSetMigrations({
        1: (p) async {
          attempts++;
          if (attempts == 1) throw StateError('transient');
          await p.setString('step1_ran', 'yes');
        },
      });

      await StoreMigrator.run();
      await StoreMigrator.run();

      final p = await prefs();
      expect(attempts, 2, reason: 'the stamp must not mark it done');
      expect(p.getString('step1_ran'), 'yes');
    });

    test('steps run IN ORDER and each one advances the stamp', () async {
      // Start below v1 so more than one step is in range: the loop runs while
      // version < currentVersion (2), i.e. steps 0 then 1.
      SharedPreferences.setMockInitialValues({versionKey: 0});
      final order = <int>[];
      StoreMigrator.debugSetMigrations({
        0: (p) async => order.add(0),
        1: (p) async => order.add(1),
      });

      await StoreMigrator.run();

      final p = await prefs();
      expect(order, [0, 1], reason: 'ordered forward migration');
      expect(p.getInt(versionKey), StoreMigrator.currentVersion);
    });
  });

  group('v1 -> v2: order storage became per-patient', () {
    test('legacy global keys are QUARANTINED, never deleted outright',
        () async {
      // They cannot be attributed to a patient after the fact, so guessing an
      // owner would be worse than preserving them for support.
      SharedPreferences.setMockInitialValues({
        versionKey: 1,
        'housepital_orders': '[{"id":"HPL-BOOK-1"}]',
        'housepital_assessments': '[{"id":"A-1"}]',
      });

      await StoreMigrator.run();

      final p = await prefs();
      expect(p.getInt(versionKey), 2);
      expect(p.getString('__quarantine_v1_housepital_orders'),
          '[{"id":"HPL-BOOK-1"}]',
          reason: "a patient's order history must stay recoverable");
      expect(p.getString('__quarantine_v1_housepital_assessments'),
          '[{"id":"A-1"}]');
      expect(p.containsKey('housepital_orders'), isFalse,
          reason: 'the un-scoped key must not keep shadowing per-patient keys');
    });

    test('is a no-op when there were no legacy keys', () async {
      SharedPreferences.setMockInitialValues({versionKey: 1});

      await StoreMigrator.run();

      final p = await prefs();
      expect(p.getInt(versionKey), 2);
      expect(p.getKeys().where((k) => k.startsWith('__quarantine')), isEmpty);
    });
  });

  group('quarantine reports success (round-4 regression)', () {
    test('returns TRUE when the copy is written', () async {
      SharedPreferences.setMockInitialValues({'k': 'v'});
      final p = await prefs();

      expect(await StoreMigrator.quarantine(p, 'k', 1), isTrue);
      expect(p.getString('__quarantine_v1_k'), 'v');
    });

    test('returns TRUE for an absent key — nothing to preserve', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await prefs();

      expect(await StoreMigrator.quarantine(p, 'absent', 1), isTrue);
    });

    test('the result is CHECKED — a failed copy must not authorise a delete',
        () async {
      // The bug: quarantine discarded the bool every setter returns.
      // SharedPreferences does not revert its cache when a platform write
      // fails, so on a full or locked disk the copy failed silently, the
      // caller deleted the original, and the log read "Quarantined".
      // Data destroyed, log said preserved.
      //
      // A mock store cannot fail a write, so this pins the CALLER's contract
      // instead: when the step cannot preserve, it must throw rather than
      // delete, leaving the version un-advanced for a retry.
      SharedPreferences.setMockInitialValues({
        versionKey: 1,
        'legacy_blob': 'irreplaceable',
      });
      StoreMigrator.debugSetMigrations({
        1: (p) async {
          const key = 'legacy_blob';
          final preserved = false; // simulate a failed quarantine write
          if (!preserved) {
            throw StateError('quarantine failed; refusing to delete');
          }
          // ignore: dead_code
          await p.remove(key);
        },
      });
      addTearDown(StoreMigrator.debugResetMigrations);

      await StoreMigrator.run();

      final p = await prefs();
      expect(p.getString('legacy_blob'), 'irreplaceable',
          reason: 'the original must survive a failed preservation');
      expect(p.getInt(versionKey), 1,
          reason: 'and the migration must be retried, not stamped done');
    });
  });

}
