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
  static const int currentVersion = 1;

  static const String _versionKey = 'housepital_schema_version';

  /// Keys that existed before versioning. Used only to tell a pre-versioning
  /// install (has data, no stamp) apart from a fresh one (no data at all).
  /// FROZEN — do not update when a key is renamed; add a migration instead.
  static const List<String> _v1Keys = <String>[
    'housepital_orders',
    'housepital_assessments',
    'housepital_cart_items',
    'housepital_saved_items',
    'housepital_saved_addresses',
    'theme_mode',
    'preferred_language',
    'profile_photo_path',
    'has_onboarded',
  ];

  /// Ordered migration steps. `_migrations[n]` upgrades version n → n+1.
  ///
  /// Empty today because v1 is the first stamped version. The value of this
  /// file before the first migration exists is the STAMP: without it, v2 has
  /// nothing to branch on.
  static final Map<int, Future<void> Function(SharedPreferences)> _migrations =
      <int, Future<void> Function(SharedPreferences)>{};

  /// Runs any pending migrations and records the resulting version.
  /// Never throws: a migration failure must not stop the app from starting —
  /// it quarantines and moves on.
  static Future<void> run() async {
    final prefs = await SharedPreferences.getInstance();
    final stamped = prefs.getInt(_versionKey);

    if (stamped == null) {
      final hasLegacyData = _v1Keys.any(prefs.containsKey);
      if (!hasLegacyData) {
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
          Log.error('Migration v$version → v${version + 1} failed',
              error: e, stack: st, tag: 'StoreMigrator');
          // Deliberately continue: a half-migrated store that starts is
          // better than a boot loop, and quarantine (below) preserves the
          // original bytes for support to recover.
        }
      }
      version++;
      await prefs.setInt(_versionKey, version);
    }
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
