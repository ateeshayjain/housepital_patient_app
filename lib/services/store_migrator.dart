import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

/// Versions the app's local storage and migrates it forward on upgrade.
///
/// WHY THIS EXISTS
/// Until 2026-08-03 the app wrote JSON blobs to SharedPreferences with no
/// version stamp anywhere. That is free to fix before the first public
/// release and effectively impossible afterwards: once v1 data is on real
/// phones, a v2 that changes any stored shape has no way to know what it is
/// reading, and the existing code paths respond to a parse failure by
/// silently overwriting the user's orders (see OrdersProvider).
///
/// CONTRACT
///  • [run] is called once, early in startup, before providers read storage.
///  • Every stored shape change bumps [currentVersion] and adds a step to
///    [_migrations].
///  • A migration NEVER deletes data it cannot parse. It QUARANTINES it under
///    a `__quarantine_v{n}_{key}` entry, so a bad migration is recoverable and
///    support can retrieve a patient's order history.
///  • Migration literals are FROZEN. A migration must not reference the app's
///    model classes or key constants — those change under it, and a migration
///    that changes meaning over time is worse than no migration. Copy the key
///    names and shapes into the step and leave them alone forever.
///
/// FIRST INSTALL vs UPGRADE
/// A fresh install has no version key AND no data — that is stamped at
/// [currentVersion] with no work. A device with data but no version key is a
/// pre-versioning (v1) install and runs every step from 1.
abstract final class StoreMigrator {
  /// Bump when any persisted shape changes, and add the matching step below.
  static const int currentVersion = 2;

  static const String _versionKey = 'housepital_schema_version';

  // NOTE: an earlier version listed the pre-versioning keys explicitly to tell
  // a fresh install from a v1 one. That list was wrong on the day it was
  // written (9 of 14 live keys) and, worse, it was the kind of wrong that
  // fails silently: a device whose only data sat in an unlisted key was
  // treated as a fresh install, stamped at currentVersion, and skipped every
  // future migration. `prefs.getKeys().isEmpty` cannot go stale, so it is the
  // inference we use instead — see _hasAnyStoredData.

  /// Ordered migration steps. `_migrations[n]` upgrades version n → n+1.
  ///
  /// FROZEN LITERALS ONLY — see the contract above. A step must never
  /// reference a key constant or model class from the app; those change under
  /// it and a migration whose meaning drifts is worse than no migration.
  /// Builds the shipped step table. A FUNCTION, not a field initialiser, so
  /// the test hooks below cannot capture a mutated map through Dart's lazy
  /// static initialisation.
  static Map<int, Future<void> Function(SharedPreferences)>
      _buildShippedMigrations() =>
          <int, Future<void> Function(SharedPreferences)>{
            // v1 → v2: order and assessment storage became per-patient.
            //
            // The v1 keys were global, so their contents cannot be attributed
            // to a patient after the fact — this account may since have had
            // several. So we do NOT guess an owner and do NOT delete: the
            // blobs are quarantined, which is exactly what quarantine()
            // exists for. Support can recover a patient's order history from
            // `__quarantine_v1_*`.
            1: (prefs) async {
              const legacyOrders = 'housepital_orders';
              const legacyAssessments = 'housepital_assessments';
              for (final key in <String>[legacyOrders, legacyAssessments]) {
                if (!prefs.containsKey(key)) continue;
                await quarantine(prefs, key, 1);
                await prefs.remove(key);
              }
            },
          };

  /// Ordered migration steps. `_migrations[n]` upgrades version n → n+1.
  ///
  /// FROZEN LITERALS ONLY — see the contract above. A step must never
  /// reference a key constant or model class from the app; those change under
  /// it, and a migration whose meaning drifts is worse than no migration.
  static final Map<int, Future<void> Function(SharedPreferences)> _migrations =
      _buildShippedMigrations();

  /// Test-only hook so the migration LOOP itself is reachable.
  ///
  /// Round 3 found the loop body — the failed-step guard, the early return,
  /// the version increment — was executed by no test, because `_migrations`
  /// was empty and private. Those three lines are the ones that prevent
  /// silent data loss, so they must be exercisable.
  @visibleForTesting
  static void debugSetMigrations(
      Map<int, Future<void> Function(SharedPreferences)> steps) {
    _migrations
      ..clear()
      ..addAll(steps);
  }

  /// Test-only: restores the shipped steps after [debugSetMigrations].
  @visibleForTesting
  static void debugResetMigrations() {
    _migrations
      ..clear()
      ..addAll(_buildShippedMigrations());
  }

  /// Runs any pending migrations and records the resulting version.
  /// Never throws: a migration failure must not stop the app from starting —
  /// it quarantines and moves on.
  static Future<void> run() async {
    // This runs in main() BEFORE runApp(). An escaping exception here is not a
    // crash report — it is a permanently black screen with no ErrorWidget to
    // catch it, so the whole body is guarded. The contract at the top of this
    // file says "never throws"; this is what makes that true.
    try {
      await _run();
    } catch (e, st) {
      Log.error('StoreMigrator aborted; continuing without migration',
          error: e, stack: st, tag: 'StoreMigrator');
    }
  }

  static Future<void> _run() async {
    final prefs = await SharedPreferences.getInstance();
    final stamped = prefs.getInt(_versionKey);

    if (stamped == null) {
      if (!_hasAnyStoredData(prefs)) {
        // Fresh install: nothing to migrate, just stamp it.
        await prefs.setInt(_versionKey, currentVersion);
        return;
      }
      // Pre-versioning install: treat as v1 and run forward from there.
      Log.warn('Local store has data but no version stamp — treating as v1',
          tag: 'StoreMigrator');
      await _migrateFrom(prefs, 1);
      return;
    }

    if (stamped == currentVersion) return;

    if (stamped > currentVersion) {
      // The user downgraded (TestFlight rollback, or a store rollback). Do
      // not attempt to "migrate backwards" — an older app cannot know what a
      // newer one wrote. Leave the data alone and let the tolerant readers
      // fall back; a wrong migration is worse than a missing one.
      Log.warn(
          'Local store is from a NEWER app version ($stamped > '
          '$currentVersion) — leaving it untouched',
          tag: 'StoreMigrator');
      return;
    }

    await _migrateFrom(prefs, stamped);
  }

  static Future<void> _migrateFrom(SharedPreferences prefs, int from) async {
    var version = from;
    while (version < currentVersion) {
      final step = _migrations[version];
      if (step == null) {
        Log.warn('No migration step for v$version — skipping to v${version + 1}',
            tag: 'StoreMigrator');
      } else {
        try {
          await step(prefs);
        } catch (e, st) {
          Log.error('Migration v$version → v${version + 1} failed — STOPPING '
              'at v$version so it is retried on the next launch',
              error: e, stack: st, tag: 'StoreMigrator');
          // Do NOT advance past a step that failed. The previous version of
          // this loop stamped success regardless, which permanently labelled
          // un-migrated data as migrated and guaranteed it was never retried
          // — silent data loss, which is the exact failure this file exists
          // to prevent. Stamping the last GOOD version leaves the app
          // working on old-shaped data and retries next launch.
          await prefs.setInt(_versionKey, version);
          return;
        }
      }
      version++;
      await prefs.setInt(_versionKey, version);
    }
    // Always leave a stamp, even when there was no work to do. Without this a
    // pre-versioning install whose `from` already equals currentVersion (the
    // `while (1 < 1)` case) fell through unstamped and re-ran this path,
    // re-warning, on every single launch — forever.
    await prefs.setInt(_versionKey, currentVersion);
  }

  /// True if ANY key is present. Deliberately not a curated list: see the note
  /// where the old `_v1Keys` list used to be.
  static bool _hasAnyStoredData(SharedPreferences prefs) {
    for (final key in prefs.getKeys()) {
      if (key != _versionKey) return true;
    }
    return false;
  }

  /// Copies [key]'s current value aside instead of destroying it.
  ///
  /// Call this from a migration step before overwriting anything it could not
  /// parse. Quarantined entries are never read by the app; they exist so a
  /// patient's order history is recoverable rather than gone.
  static Future<void> quarantine(
      SharedPreferences prefs, String key, int version) async {
    final value = prefs.get(key);
    if (value == null) return;
    final target = '__quarantine_v${version}_$key';
    if (value is String) {
      await prefs.setString(target, value);
    } else if (value is int) {
      await prefs.setInt(target, value);
    } else if (value is bool) {
      await prefs.setBool(target, value);
    } else if (value is double) {
      await prefs.setDouble(target, value);
    } else if (value is List<String>) {
      await prefs.setStringList(target, value);
    }
    Log.warn('Quarantined unparseable "$key" as "$target"',
        tag: 'StoreMigrator');
  }

  /// Test-only: the key the version stamp lives under.
  static String get versionKeyForTest => _versionKey;
}
