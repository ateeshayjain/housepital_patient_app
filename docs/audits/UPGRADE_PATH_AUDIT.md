# Upgrade Path Checklist (App-Agnostic) — Audit vs commit `803124d`

**Date:** 2026-08-03 · **Auditor:** upgrade-path agent · **Repo:** `housepital_patient_app` (Flutter 3.41.2, `version: 1.0.0+1`)

> **Framing.** The app has never shipped publicly, so "N-1 → N" cannot be run today. The checklist is therefore
> applied forward: *what must exist in v1 so that the first upgrade over real patient data survives?* Every
> ❌ below is cheap to fix now and expensive-to-impossible to fix after the first store build reaches a phone.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A | BLOCKED-OWNER |
|---|---|---|---|---|---|
| 1. Local store migration | 0 | 0 | 5 | 1 | 0 |
| 2. Server schema lockstep | 0 | 2 | 2 | 0 | 0 |
| 3. Cross-version coexistence | 0 | 3 | 2 | 0 | 0 |
| 4. The upgrade QA protocol | 0 | 2 | 2 | 1 | 1 |
| 5. Build & versioning hygiene | 0 | 3 | 1 | 0 | 0 |
| **Total (25)** | **0** | **10** | **12** | **2** | **1** |

---

## Headline finding

**There is no version stamp and no migration hook anywhere in the app.**

```
$ grep -rniE "schema_?version|storage_?version|data_?version|migrat|PackageInfo|force_?update" lib --include="*.dart"
lib/main.dart:193:          // to migrate to BillingProvider in a follow-up.
lib/screens/settings/family_members_screen.dart:54:  // audit M-13: migrated to shared confirmDestructiveAction helper
lib/screens/settings/about_screen.dart:11:  static const _appVersion = '1.0.0';
…  (all remaining hits are unrelated prose in comments)
```

Zero hits for a persisted schema version, a stored last-run app version, `package_info_plus`, Firebase Remote
Config, or a minimum-version gate. Ten SharedPreferences namespaces are written as bare JSON blobs whose only
contract is "whatever the current Dart models happen to encode." On the first v2 that changes any of those
shapes, the app has **no way to know it is reading v1 data** — it will simply fail to parse, silently discard,
and then overwrite. See §1 and the "Minimal versioning scheme" section for the fix.

---

## The persistence inventory

Every key the app writes. "v2 changes shape →" is the observed behaviour of the *existing* v1 code when handed
data it cannot parse.

| Key | Writer | Shape | v2 changes shape → v1 user's data does what? |
|---|---|---|---|
| `housepital_orders` | `orders_provider.dart:166` | JSON list of schemaless `Map` | **Silently empties, then is overwritten.** Order + invoice history gone (§1.4) |
| `housepital_assessments` | `orders_provider.dart:167` | JSON list of `Map` | Same — same try/catch, same overwrite |
| `housepital_cart_items` | `cart_provider.dart:209` | JSON list of `CartItem` | Per-entry `try/catch` (`cart_provider.dart:230-234`) — bad entries dropped, rest survive |
| `housepital_saved_items` | `cart_provider.dart:213` | JSON list of `CartItem` | Same as cart |
| `housepital_reminders` | `reminders_provider.dart:179` | JSON list of `ReminderItem` | **All-or-nothing** — one bad entry throws inside the `map()` and `catch` clears the whole list (`reminders_provider.dart:117-125`) |
| `housepital_saved_addresses` | `address_selection_screen.dart:126` | JSON list of `SavedAddress` | **Replaced by three fabricated demo addresses** (`address_selection_screen.dart:119-121`, defaults at `:72-104`) |
| `housepital_cache_*` (per-key) | `cache_service.dart:19` | `{data, timestamp}` wrapper | Returns `null` on parse failure (`cache_service.dart:32-35`) — benign, TTL 30 min |
| `theme_mode` | `theme_provider.dart:55` | `'system'\|'light'\|'dark'` | Unknown value → `system` (`theme_provider.dart:61-71`). **The only correctly-degrading key in the app.** |
| `has_onboarded` | `auth_provider.dart:196` | bool | Bare bool — a v2 that adds onboarding steps cannot tell "onboarded under v1" from "onboarded under v2" |
| `preferred_language` | `auth_provider.dart:197`, `app_provider.dart:92` | `'en'\|'hi'` | Unknown code → `Locale(code)` with no validation (`app_provider.dart:84-85`) |
| `profile_photo_path` | `app_provider.dart:106` | absolute path from `image_picker` | Guarded by `File(path).existsSync()` at read (`settings_screen.dart:34`) — degrades to no photo |
| `notif_*` (9 keys) | `app_provider.dart:129`, keys at `notification_preferences_screen.dart:41-92` | bool each | Missing key → per-key `defaultValue` (`app_provider.dart:119`). Safe. |
| `daily_rating_YYYY-MM-DD` | `my_care_screen.dart:615` | int | **Unbounded key growth** — one key per day, never pruned (`my_care_screen.dart:588-594`) |

**Files written outside SharedPreferences: none.** No `path_provider`, no `writeAsBytes`/`writeAsString`
anywhere in `lib/` (verified by grep). PDFs are streamed to the OS share/print sheet, not persisted. Photos
live at `image_picker`'s own temp path. Firebase Storage uploads are remote. This is genuinely good news —
the migration surface is exactly the 13 rows above.

---

## Findings

### 1. Local store migration — 0✅ / 0⚠️ / 5❌ / 1 N/A

- ❌ **The persistent store opens under an explicitly VERSIONED schema with a migration plan.**
  Evidence: no schema-version key exists (grep above). Every load path goes straight from
  `prefs.getString(key)` → `jsonDecode` → current model, e.g. `orders_provider.dart:179-189`,
  `cart_provider.dart:226-248`, `reminders_provider.dart:111-122`.
  **Impact:** v2 cannot detect v1 data, so it cannot repair it, and cannot even *log* that it saw it.
  **Fix:** ship the `_schema_version` stamp + `StoreMigrator` in v1 (see "Minimal versioning scheme").

- ❌ **Additive + defaulted changes are verified to lightweight-migrate; anything else has a written migration stage.**
  Evidence: no verification of any kind — 0 of 102 test files reference migration, legacy, or an old-version
  fixture (`grep -rniE "migrat|legacy|old version|schema" test/` returns only unrelated hits).
  **Impact:** "additive and defaulted" is currently an assumption, not a checked property. Two live
  counter-examples are already in the tree: `orders_provider.dart:182` and `reminders_provider.dart:118` are
  *not* per-entry tolerant, so an additive change that a stale writer emits differently still nukes the list.
  **Fix:** one golden-fixture test per persisted key that loads a frozen v1 blob and asserts the entity count.

- N/A **Historical schema versions are FROZEN literals, never computed from the live model list.**
  There are no schema versions to freeze. Re-check once the versioning scheme lands — the frozen-literal rule
  applies to the migration table, not to the models.

- ❌ **A release build with a missing migration fails LOUDLY; wipe-and-recreate is compile-gated to debug.**
  Evidence: the codebase does the exact opposite — it wipes quietly in release, in four places:
  - `orders_provider.dart:201-205` — any decode failure logs a `Log.warn` and leaves `_orders` empty.
    The next `_persistAndNotify()` (`:162-172`) unconditionally `setString`s the new list over the old blob.
    **There is no backup key.** Order and invoice history for a paying patient is destroyed with one warn line.
  - `address_selection_screen.dart:119-121` — `catch (_) { return List.from(_defaultAddresses); }`. The user's
    real delivery address is silently replaced with the demo address `B-42, Sector 15, Noida 201301`. In a
    home-healthcare app that is the address a nurse or an oxygen concentrator gets dispatched to.
  - `reminders_provider.dart:123-125` — `catch (_) { _items.clear(); }`, whole list.
  - `cart_provider.dart:251-254` — `catch` comment literally reads "Ignore corrupt data — start fresh".
  **Impact:** the single most dangerous property in this audit. A v2 shape change is indistinguishable from
  corruption, and the response to corruption is silent deletion followed by overwrite.
  **Fix:** on parse failure, copy the raw string to `<key>__quarantine_v<n>` before writing anything new, surface
  a one-time non-blocking notice, and `assert(false)` in debug so it fails loudly in dev.

- ❌ **A migration test opens a store snapshot from the OLDEST supported release and asserts row counts.**
  Evidence: `test/providers/orders_persistence_test.dart:185-223` and `cart_persistence_test.dart` test
  *corrupt* JSON (`'this is not valid json {{{'`), which is a different thing from *older-shape* JSON. The
  assertion at `:195` is `expect(provider.orders, isEmpty)` — the test **certifies the data loss as correct
  behaviour**. `:218-221` even documents it: "if orders fail, assessments also won't load. This tests the
  actual behavior."
  **Fix:** add `test/migration/v1_fixture_test.dart` asserting counts survive, and change the corrupt-JSON
  assertion to assert the quarantine key exists.

- ❌ **Aged-data snapshot exists (months of realistic records, under version control).**
  Evidence: `test/_mocks/` contains service fakes only; no persisted-store fixture anywhere in the repo.
  `DemoData.orders` is in-memory seed data explicitly never written to storage (`orders_provider.dart:191-198`).
  **Fix:** commit `test/fixtures/store_v1_aged.json` — 40+ orders spanning 8 months, 60 reminders, 3 addresses,
  a full cart — generated once from a real run and frozen.

### 2. Server schema lockstep — 0✅ / 2⚠️ / 2❌ / 0 N/A

- ⚠️ **Production server schema deployed BEFORE the build that needs it, as a checklist line with date and owner.**
  Evidence: `docs/DEPLOYMENT_GUIDE.md:92` has a "Connect and Run Migrations" step and `:440-452` a pre-launch
  checklist; `docs/DATABASE_SCHEMA.md:648-660` keeps a numbered migration history (001 only) with a hard
  "Every migration = update this file. No exceptions." rule. The discipline exists.
  **Gap:** neither document states the *ordering constraint* (schema before app submission), and no line carries
  a date or a named owner. **Fix:** add one line to the §8 checklist: `[ ] Migration NNN applied to prod — date ___ / owner ___ — BEFORE app build NNN submitted`.

- ❌ **New FIELDS on existing types re-arm the deploy gate, not only new types.**
  Evidence: there is no deploy gate to re-arm. No CI job, script, or test compares the app's expected response
  shape against the deployed schema; `.github/workflows/ci.yml` runs analyze / design gate / test / coverage only.
  **Impact:** a field rename on an existing endpoint ships green.
  **Fix:** a contract test that asserts each `fromJson`'s required key set against a checked-in fixture of the
  live response, refreshed at deploy time.

- ❌ **The app tolerates the server knowing LESS: those writes queue and surface honestly, they do not silently drop.**
  Evidence: there is no write queue anywhere. Failed writes are dropped with a log line:
  `app_provider.dart:255` ("Vitals API unavailable — reading kept locally (demo mode)") keeps the reading
  in memory only — it dies on app kill; `app_provider.dart:168-172` `addPatient` is an in-memory append with
  `// TODO(persistence)`; `medication_provider.dart:248-315` add/update/delete medication have no offline path.
  **Impact:** during the window where v2's app can write a field v2's server does not yet accept, the write is
  lost with no user-visible signal. For a manually-entered vital or a medication change that is a clinical record.
  **Fix:** a durable outbox (`housepital_outbox` list) + a "Not yet synced" chip; at minimum, surface the failure.

- ⚠️ **The app tolerates the reverse window (server knows MORE): unknown fields/types are ignored gracefully, never fatal.**
  Evidence, both directions:
  - *Unknown extra fields are correctly ignored* — every `fromJson` reads named keys, none iterate the map.
  - *Missing or renamed required fields are fatal per call.* Confirmed by running the actual Dart semantics:
    ```
    $ dart run t.dart
    DateTime.parse(null): type 'Null' is not a subtype of type 'String'
    ```
    There are **48 unguarded `DateTime.parse(json[...])` sites**. A backend that renames `created_at` throws at
    `models.dart:642` (Booking), `:701` (AssessmentRequest), `:739-747` (Invoice), `:867` (AppNotification),
    `:1273` (PaymentTransaction), `:1345-1346` (Coupon), `medication_models.dart:154` (MedicationLog),
    `my_care_models.dart:87` (ActiveService), `equipment_order.dart:37`. Unconditional `as List` casts do the
    same at `models.dart:414` (DailyReport.sections), `:445` (ReportSection.tasks), `:741` (Invoice.lineItems),
    and in the envelope unwrapping at `api_service.dart:190, 221` (`data['patients'] as List`).
    Implicit non-null casts throw the same way at `medication_models.dart:83-85` (`id`/`patient_id`/`name` into
    non-nullable `String` fields, declared at `:4-6`), `:150-158` (`MedicationLog.id`/`status`), and
    `payment_reminder_service.dart:87-89, 110-114`.
  **Impact — the important part:** none of these crash the app, because every provider wraps the call in a
  `catch` that falls back to `DemoData` (`app_provider.dart:215-219`, `my_care_provider.dart:68-72`,
  `medication_provider.dart:233`, `billing_provider.dart:41`). So a v2 server-shape change makes an old client
  **silently display fabricated demo vitals, demo attendance, demo medications and a demo billing summary as
  though they were the patient's real record.** There is no demo/offline banner anywhere in `lib/` (grep for
  `isDemo|demo mode|offline mode` returns only comments and `payment_service.dart`'s payment-key check).
  **Fix (highest-value single change in this audit):** a visible "Showing sample data — not your records"
  banner whenever a provider is serving `DemoData`. It is ~20 lines and it converts a silent clinical-data
  falsehood into an honest one.

### 3. Cross-version coexistence — 0✅ / 3⚠️ / 2❌ / 0 N/A

- ⚠️ **Enum-backed fields: an UNKNOWN raw value from a newer version degrades to a safe fallback, tested per enum.**
  Evidence: exactly one true Dart enum is deserialised, and it is handled correctly —
  `reminders_provider.dart:66` `ReminderCategory.values.asNameMap()[json['category']] ?? ReminderCategory.reminder`.
  Everything else is a raw `String` "enum" (`BookingStatus` constants at `booking_state_machine.dart:11-25`;
  `status`, `frequency`, `form`, `type` fields across the models). Those *do* have `default:` arms —
  `helpers.dart:79-81, 98-100`, `medication_models.dart:77-79`, `booking_state_machine.dart:42, 63` — so an
  unknown value degrades rather than crashes.
  **Gaps:** (a) no test asserts the fallback for any of them; (b) filter/aggregate call sites use bare equality
  with no unknown bucket — `billing_screen.dart:58, 66, 73, 81` decide *outstanding* and *paid* totals by
  `o['status'] == 'confirmed' | 'in_progress' | 'completed'`, so a v2 status like `'awaiting_confirmation'`
  makes that order **vanish from both money columns** rather than degrade. That is a wrong number, not a
  missing one. **Fix:** an explicit `else → count as outstanding` bucket, plus one test per string-enum family.

- ⚠️ **Semantics riding an existing raw value are checked against the oldest version that can receive them.**
  Evidence: the pattern is already in use — `OrdersProvider.isQuotePending` (`orders_provider.dart:26`) is
  `order['quoteStatus'] == 'pending'`, a flag key that reinterprets an existing order map, and
  `billing_screen.dart:73` excludes quote-pending orders from the paid sum. This is exactly the "semantics
  riding an existing raw value" case the checklist names.
  **Gap:** unverified in the other direction. Since v1 order maps are schemaless, a v2 that adds a second flag
  (say `quoteStatus: 'revised'`) will be read by v1's strict `== 'pending'` as *not* quote-pending, so v1
  renders the ₹0 total the business rule explicitly forbids (CLAUDE.md: "never render ₹0"). **Fix:** make v1's
  check `!= null && != 'confirmed'` — tolerant of future values — before v1 ships.

- ⚠️ **New record types syncing into an old app version are ignored without crash and resurface intact.**
  Evidence: additive **fields** on order maps survive cleanly — readers are uniformly defensive
  (`billing_screen.dart:510-528`, `my_orders_screen.dart:232-239`, all `as X? ?? default`), and unknown keys
  round-trip because the map is stored whole. Genuinely good.
  **Two concrete crash paths, both verified by running Dart:**
  ```
  $ dart run t.dart
  THROWS: type 'double' is not a subtype of type 'int?' in type cast
  LAZY THROWS ON ACCESS: type 'String' is not a subtype of type 'Map<String, dynamic>' in type cast
  ```
  1. `as int?` is not tolerant of a widened number. If v2 ever writes `totalAmount` with decimals (GST), v1's
     `billing_screen.dart:511` and `my_orders_screen.dart:234` **throw** — they do not fall back to the `?? 0`.
     Note the same file gets it right two lines later: `refundAmount` uses `as num?` (`billing_screen.dart:527`).
     Same hazard at `models.dart:1496, 1499, 1500` (`CartItem.unitPrice`/`rentalMonths`/`quantity`).
  2. `orders_provider.dart:182` `decoded.cast<Map<String, dynamic>>()` is a **lazy** cast. A v2 that writes a
     non-map element does not throw at load — it throws later, at element access in the Billing list, *outside*
     the `try/catch` at `:176-205`. That is an uncatchable crash on the Billing tab.
  **Fix:** `as num?` everywhere money or counts are read; replace `.cast()` with an eager
  `.whereType<Map<String, dynamic>>().toList()`.

- ❌ **Features requiring the whole household to update together are LISTED in release notes.**
  Evidence: `docs/CHANGELOG.md` (49 KB) is developer-facing and organised by audit batch; there is no
  user-facing release-notes artefact in the repo and no store-listing draft. The app is explicitly
  multi-user — the role layer distinguishes patient-self / primary contact / family / caretaker — so the
  lagging-household case is real, not theoretical. **Fix:** start `docs/RELEASE_NOTES.md` with v1.0.0, with a
  mandatory "Requires everyone in the family to update" section (empty is fine for v1).

- ❌ **Version-skew QA pass: current build on device A, previous release on device B.**
  Evidence: impossible today — no previous release exists (§4.1). Recording it as ❌ rather than N/A because
  the *precondition* (archive the build you are about to ship) is a v1 action, not a v2 one.

### 4. The upgrade QA protocol — 0✅ / 2⚠️ / 2❌ / 1 N/A / 1 BLOCKED-OWNER

- ❌ **An installable archive of the PREVIOUS release exists.**
  Evidence: nothing under `build/` is version-tagged; `.gitignore` excludes build output; no `releases/`
  directory; CI (`ci.yml`) produces only a coverage artifact, no IPA/AAB.
  This is a named **red flag** on the checklist ("No installable copy of the previous release anywhere") and it
  is currently true. **Fix before v1 ships:** archive the exact v1 IPA + AAB + a `git tag v1.0.0+1` to a known
  location, and make it a line in the deployment checklist.

- N/A **Upgrade matrix run: N-1 → N and oldest-supported → N over the aged snapshot, on a real device.**
  Nothing to upgrade from. Becomes mandatory at v1.0.1.

- ❌ **Before/after data checksum: counts per entity recorded before the update and verified after.**
  Evidence: no debug screen, no export, no logging that reports entity counts. `settings_screen.dart` has no
  diagnostics entry. To even *notice* that v2 ate a v1 user's orders, someone would have to remember how many
  they had. **Fix:** a hidden diagnostics row (long-press the version string in `about_screen.dart`) printing
  `orders=N assessments=N cart=N saved=N reminders=N addresses=N` and the schema version. ~30 lines, and it is
  the only way the upgrade matrix above can ever be checked.

- ⚠️ **Files outside the database survive: attachments, keychain, user defaults, notification registrations.**
  Evidence, item by item:
  - *User defaults* — SharedPreferences survives an in-place upgrade by construction. ✅ mechanism, but see §1.
  - *Attachments* — none stored locally (no `path_provider` / `writeAs*` in `lib/`). N/A.
  - *Profile photo* — `app_provider.dart:106` persists `image.path`, the raw `image_picker` path
    (`settings_screen.dart:72`, `patient_profile_screen.dart:205`), which lives in the app's purgeable
    tmp/Caches container. It survives a plain upgrade but not an OS cache purge or a restore-to-new-device.
    Read is guarded (`settings_screen.dart:34`, `patient_profile_screen.dart:170` — `File(path).existsSync()`),
    so it degrades to "no photo" rather than crashing. **Fix:** copy the picked file into Documents and store a
    *relative* filename, not an absolute path.
  - *Keychain* — nothing uses `flutter_secure_storage` (grep: no hits). Auth is Firebase-managed, so the session
    survives upgrade on its own. **But:** `auth_provider.dart:217-227` `logout()` calls **`prefs.clear()`** —
    an unscoped wipe of *every* key in the table above: orders, cart, reminders, addresses, theme, language,
    notification prefs. If v2 ever forces a re-auth on upgrade (a token-format change, or enabling the auth
    gate that is currently commented out at `main.dart:408-409`), that single line **strands the user with an
    empty app**. This is the second-most dangerous line in the audit.
    **Fix:** replace `prefs.clear()` with an explicit allowlist of session keys
    (`has_onboarded` + auth-scoped keys), leaving user content untouched.
  - *Notification registrations* — scheduled local notifications persist in the OS across an upgrade, but their
    IDs are derived from `medicationId.hashCode` (`medication_reminder_service.dart:288, 292`).
    Dart does not guarantee `String.hashCode` stability across SDK versions. If it shifts in a future Flutter,
    `cancel()` at `:241-244` computes a *different* ID and misses — leaving **orphaned, uncancellable
    medication reminders firing for a medication the patient has stopped taking.** For a healthcare app that is
    a clinical-safety bug, not a nuisance. (Adjacent: `hashCode.abs() * 10` can exceed the 32-bit Android
    notification-ID range.) **Fix:** persist an explicit `medId → notificationId` map in SharedPreferences and
    allocate IDs from a monotonic counter.

- ⚠️ **First launch after update is timed; migration longer than ~2s shows progress UI.**
  Evidence: there is no migration, so today the cost is zero — but there is also no slot to put one in.
  `splash_screen.dart:15-19` is a hard `Future.delayed(2s)` → `pushReplacementNamed('/home')` with no async
  work and no progress affordance, and providers load their stores from constructors
  (`orders_provider.dart:19-21`, `theme_provider.dart:22-24`, `main.dart:209`) — i.e. off the splash's control,
  racing the first frame. **Fix:** make the splash `await` a `StoreMigrator.run()` and show a determinate bar
  if it exceeds 300 ms. Doing this in v1 is free; retrofitting it in v2 means the migration has nowhere to run.

- **BLOCKED-OWNER** — **The update is tested via the SAME channel users get (TestFlight/store update in place).**
  Cannot be verified from the repo. I would need: App Store Connect / Play Console access showing a prior build,
  or the owner's confirmation that a TestFlight build has been distributed and updated over. Note
  `CLAUDE.md:120-123` documents the cable-install path (and its `0xe8008014` hazard) but says nothing about
  testing an *update in place*.

### 5. Build & versioning hygiene — 0✅ / 3⚠️ / 1❌ / 0 N/A

- ⚠️ **Marketing version and build number come from ONE source of truth; a test fails if the built product disagrees.**
  Evidence: `pubspec.yaml:4` `version: 1.0.0+1` is correctly the single source for both platforms —
  `ios/Runner/Info.plist:22, 26` use `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)`, and
  `android/app/build.gradle.kts:29-30` use `flutter.versionCode` / `flutter.versionName`. Good.
  **Two gaps:** (a) `about_screen.dart:11` `static const _appVersion = '1.0.0'` is a **hardcoded second source
  of truth**, rendered to the user at `:69` — it will drift at the first version bump and the user-visible
  version will be a lie; (b) no test asserts any of this.
  **Fix:** add `package_info_plus`, read the version at runtime in About, and add a test asserting
  `PackageInfo.version == pubspec version`. (`package_info_plus` is also the prerequisite for the
  force-upgrade gate below — one dependency buys both.)

- ⚠️ **Generated files cannot silently revert version keys — regenerate, then verify against the built artifact.**
  Evidence: the mechanism is right (both platforms indirect through Flutter's build variables, so a
  regeneration cannot hardcode a stale literal). **Gap:** nothing verifies the *built artifact*; CI never
  produces one. Downgraded from ✅ purely on the missing verification step.

- ❌ **Build number increments on EVERY upload, enforced by habit or automation.**
  Evidence: `pubspec.yaml` sits at `+1` with no automation — no CI step reads or bumps it, no git hook,
  nothing in `scripts/` (`check_design_consistency.sh`, `sync_excel_to_json.py`, `sync_pricing.py`).
  **Fix:** a CI check on release branches that the build number is strictly greater than the last `v*` git tag.

- ⚠️ **The changelog distinguishes user-visible changes from internal ones, and names anything requiring household-wide update.**
  Evidence: `docs/CHANGELOG.md` is thorough (49 KB) and `docs/DEPLOYMENT_GUIDE.md:440-452` has a real
  pre-launch checklist including "Version number bumped in pubspec.yaml". But the changelog mixes user-visible
  and internal freely (e.g. `:312-313` "Radio groupValue → RadioGroup ancestor migration" sits beside feature
  entries), and nothing flags household-wide-update requirements. See §3.4.

---

## Minimal versioning scheme to add before launch

The smallest thing that makes v2 survivable. Roughly 120 lines, all new files, no behaviour change in v1.

**1. Stamp the store.** One new key, written once on first launch and on every successful migration:

```dart
// lib/services/store_migrator.dart
class StoreMigrator {
  static const _versionKey = 'housepital_schema_version';
  static const int currentVersion = 1;          // FROZEN literal — never computed from models

  /// Ordered, append-only. Each entry migrates from (index) to (index+1).
  static final List<Future<void> Function(SharedPreferences)> _steps = [];

  static Future<void> run() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_versionKey);
    if (stored == null) {                        // fresh install OR pre-versioning v1 data
      await prefs.setInt(_versionKey, currentVersion);
      return;
    }
    if (stored > currentVersion) {               // DOWNGRADE — v2 data on a v1 binary
      Log.warn('Store v$stored newer than app v$currentVersion', tag: 'StoreMigrator');
      return;                                    // read defensively, never rewrite blindly
    }
    for (var v = stored; v < currentVersion; v++) {
      await _steps[v](prefs);
      await prefs.setInt(_versionKey, v + 1);    // checkpoint each step
    }
  }
}
```

**2. Call it before the first frame.** `splash_screen.dart:15` — `await StoreMigrator.run()` in place of the
bare 2-second delay, with a progress indicator if it exceeds 300 ms. Providers must not load stores from their
constructors until this completes.

**3. Quarantine instead of wipe.** In each of the four load paths named in §1.4, replace the silent-empty catch:

```dart
} catch (e, s) {
  assert(false, 'Store parse failed for $key: $e');            // loud in debug
  await prefs.setString('${key}__quarantine_v${StoreMigrator.currentVersion}', raw);
  FirebaseCrashlytics.instance.recordError(e, s, fatal: false); // loud in release
  // …then degrade
}
```

**4. Add a minimum-version gate.** There is currently **no way to stop a known-bad old build from continuing to
display dosages, vitals, and money.** For a healthcare app that is the gap that matters most after §1.4.
Cheapest viable version, no new backend: add `firebase_remote_config`, publish
`{"min_supported_build": 1, "force_upgrade_message": "..."}`, and check it in the splash — below the minimum,
show a blocking "Please update" screen with a store link. **SOS must remain reachable from that screen**
(CLAUDE.md: "SOS is never blocked"). Second-cheapest, no new dependency: send `X-App-Version: 1.0.0+1` on every
request from `api_service.dart:48-51` and treat HTTP 426 as the force-upgrade signal. Do both if you can — the
Remote Config path still works when the API is down, which is precisely when you will need it.

**5. Freeze a v1 fixture.** Dump a realistic aged store to `test/fixtures/store_v1_aged.json` the week before
launch, and add the migration test that asserts counts survive. This is the artefact that makes every future
upgrade checkable; it costs nothing now and cannot be recreated later.

---

## Blockers (must fix before v1 reaches a real patient)

1. **No schema version, no migration hook.** (§1.1) Everything else in this list depends on it. — `lib/services/` (new file), `splash_screen.dart:15`.
2. **Silent wipe-then-overwrite of order/invoice history.** (§1.4) `orders_provider.dart:201-205` + `:162-172`. No backup key, no user signal, unrecoverable.
3. **`logout()` calls `prefs.clear()`.** (§4.4) `auth_provider.dart:223`. Nukes orders, cart, reminders, addresses, theme and language. Any v2 that forces a re-auth strands every user.
4. **Saved addresses silently replaced by demo addresses on parse failure.** (§1.4) `address_selection_screen.dart:119-121`. Wrong dispatch address for a home-healthcare visit.
5. **No force-upgrade / minimum-version gate.** (§Minimal scheme, item 4) A known-bad build showing wrong dosages cannot be stopped. No `firebase_remote_config`, no version header, no 426 handling.

## High

6. **Demo data is served silently as real clinical data** whenever a fetch fails or a response shape changes. (§2.4) `app_provider.dart:215-219`, `my_care_provider.dart:68-72`, `medication_provider.dart:233`, `billing_provider.dart:41`. No banner anywhere in `lib/`. An old client against a newer API shows fabricated vitals and attendance with full confidence.
7. **48 unguarded `DateTime.parse(json[...])` + unconditional `as List` casts** make any renamed/missing required field fatal per call. (§2.4) Worst for clinical models: `medication_models.dart:83-85, 150-158`; `models.dart:414, 445, 741`; `api_service.dart:190, 221`.
8. **`as int?` on money throws instead of defaulting**, verified. (§3.3) `billing_screen.dart:511`, `my_orders_screen.dart:234`, `models.dart:1496`. Use `as num?` — `billing_screen.dart:527` already does.
9. **Lazy `.cast<Map<String,dynamic>>()` throws outside the guard.** (§3.3) `orders_provider.dart:182, 188` — an uncatchable Billing-tab crash rather than a caught load failure.
10. **Notification IDs derived from `String.hashCode`.** (§4.4) `medication_reminder_service.dart:288, 292`. Orphaned, uncancellable medication reminders if hashing shifts across an SDK upgrade.
11. **No archived installable of the release you are about to ship.** (§4.1) Named red flag. Tag and archive the v1 IPA/AAB at submission.

## Medium / Low

12. **`about_screen.dart:11` hardcodes `'1.0.0'`** as a second version source of truth. (§5.1)
13. **No build-number automation.** (§5.3) Nothing enforces the increment.
14. **`reminders_provider.dart:117-125` is all-or-nothing** — one bad entry clears the list. Make it per-entry like `cart_provider.dart:230-234`. (§1.1)
15. **`billing_screen.dart:58-82` has no unknown-status bucket** — a future status silently drops an order from both money totals. (§3.1)
16. **`OrdersProvider.isQuotePending` is a strict `== 'pending'`** — a future quote state renders as ₹0, which the business rule forbids. (§3.2)
17. **`daily_rating_YYYY-MM-DD` grows unbounded** — `my_care_screen.dart:588-594`, one key per day forever, and SharedPreferences is loaded whole at startup. Prune to 90 days.
18. **`profile_photo_path` stores an absolute `image_picker` temp path.** (§4.4) Copy to Documents, store a relative name.
19. **No before/after entity-count diagnostics.** (§4.3) Add a hidden row in About.
20. **No user-facing release notes artefact.** (§3.4) Start `docs/RELEASE_NOTES.md`.

## BLOCKED-OWNER

- **§4.6 — update tested via the same channel users get.** Needs App Store Connect / Play Console visibility, or
  the owner's confirmation that a TestFlight build has been distributed and then updated over in place.
- **§2.1 (partial)** — whether a production MySQL migration has actually been applied ahead of any app build.
  `docs/DATABASE_SCHEMA.md:648-660` lists migration 001 only; I cannot see the deployed database.
