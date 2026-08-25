# Upgrade Path Checklist (App-Agnostic) — Audit round 2 vs commit `820060b`

**Date:** 2026-08-03 · **Previous round:** commit `803124d` · **Branch:** `fix/five-tab-nav`
**Repo:** `housepital_patient_app` (Flutter 3.41.2, `pubspec.yaml:4` → `version: 1.0.0+1`)

> **Framing (unchanged).** The app has never shipped publicly, so "N-1 → N" cannot be run today. The
> checklist is applied forward: *what must exist in v1 so that the first upgrade over real patient data
> survives?* Every ❌ is cheap now and expensive-to-impossible after the first store build reaches a phone.

---

## Changed since round 1

| Round-1 finding | Status now | Evidence |
|---|---|---|
| **B1** No version stamp, no migration hook anywhere | **⚠️ Partially fixed — the hook exists and is correctly ordered, but the design has three defects (below)** | `lib/services/store_migrator.dart` (new, 148 lines); invoked at `lib/main.dart:174`, *before* the `MultiProvider` block at `:191-278` |
| — 1a. Frozen `_v1Keys` list | **❌ NEW DEFECT — the frozen list is wrong** | `store_migrator.dart:40-50` omits `housepital_reminders` and 12 other live keys (table in §1.3) |
| — 1b. Pre-versioning installs are never stamped | **❌ NEW DEFECT — dead code path** | `store_migrator.dart:77` calls `_migrateFrom(prefs, 1)`; `:100` `while (version < currentVersion)` is `while (1 < 1)` → false → `:117` `setInt` never runs |
| — 1c. Version advances even when a step throws | **❌ NEW DEFECT — a failed migration is recorded as succeeded and never retried** | `store_migrator.dart:106-117` |
| — 1d. `quarantine()` is unreachable | **❌ Dead code** | `store_migrator.dart:126-144` — `grep -rn quarantine lib test` returns only the definition and its own doc comments; zero call sites |
| **B2** Silent wipe-then-overwrite of order history | **❌ UNCHANGED** | `orders_provider.dart:203-207` (catch → empty) + `:163-173` (unconditional `setString` over the old blob). No backup key |
| **B2b** Test certifies the loss | **❌ UNCHANGED** | `test/providers/orders_persistence_test.dart:195` `expect(provider.orders, isEmpty)`; `:221` "This tests the actual behavior" |
| **B3** `logout()` calls `prefs.clear()` | **❌ UNCHANGED, and now strictly worse** | `auth_provider.dart:222-223`. It now additionally destroys `housepital_schema_version` and every `__quarantine_v*` key — i.e. logout defeats the recovery mechanism round 1 asked for |
| **B4** Saved addresses replaced by 3 fabricated demo addresses | **❌ UNCHANGED** | `address_selection_screen.dart:119-121` `catch (_) { return List.from(_defaultAddresses); }`; defaults at `:72-104` |
| **B5** No force-upgrade / minimum-version gate | **❌ UNCHANGED** | `grep -rniE "force_?upgrade\|min_?supported\|remote_?config\|package_info\|426\|X-App-Version" lib pubspec.yaml` → **zero hits** |
| **H6** Demo data served silently as real clinical data | **⚠️ Partially fixed — banner added, but it has a false-all-clear bug and two uncovered fallbacks** | `lib/data/demo_mode.dart` + banner at `main_shell.dart:126-160`. **Regression:** `app_provider.dart:247` `DemoMode.reset()` — see §2.4 |
| **H7** 48 unguarded `DateTime.parse(json[…])` | **❌ REGRESSED — now 49** | `grep -rn "DateTime.parse(" lib \| grep -E "json\[\|\['" \| wc -l` → **49** (51 total sites, 11 `tryParse`) |
| **H8** `as int?` on money throws instead of defaulting | **❌ UNCHANGED** | `billing_screen.dart:67, 74, 511`; `my_orders_screen.dart:234`; `models.dart:1496, 1499, 1500` |
| **H9** Lazy `.cast<Map<String,dynamic>>()` throws outside the guard | **❌ UNCHANGED** | `orders_provider.dart:183, 189` |
| **H10** Notification IDs from `String.hashCode` | **❌ UNCHANGED** | `medication_reminder_service.dart:288, 292` |
| **H11** No archived installable of the release about to ship | **❌ UNCHANGED** | `git tag` → empty; no `releases/`; `.github/workflows/ci.yml` produces no IPA/AAB |
| **M12** `about_screen.dart:11` hardcodes `'1.0.0'` | **❌ UNCHANGED** | `about_screen.dart:11` |
| **M14** `reminders_provider` all-or-nothing load | **⚠️ Slightly better** | `reminders_provider.dart:117` now filters with `whereType<Map<String, dynamic>>()`, so non-map elements are dropped per-entry — but a `ReminderItem.fromJson` that *throws* still hits `:125-127` `catch (_) { _items.clear(); }` and clears the whole list |
| **M15/M16/M17/M18/M19/M20** billing unknown-status bucket · `isQuotePending == 'pending'` · unbounded `daily_rating_*` · absolute photo path · no entity-count diagnostics · no release notes | **❌ ALL UNCHANGED** | `billing_screen.dart:64-75`; `orders_provider.dart:27-28`; `my_care_screen.dart:588-594`; `app_provider.dart:106-107`; no diagnostics anywhere; `ls docs/` has no `RELEASE_NOTES.md` |

**Net:** one blocker moved from ❌ to ⚠️ (B1). One checklist item moved from N/A to ❌ (§1.3 — there is now a
frozen list to grade, and it is wrong). Two items regressed in substance (`DateTime.parse` count; the
`DemoMode.reset()` false all-clear). Blockers 2, 3, 4 and 5 are untouched.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A | BLOCKED-OWNER |
|---|---|---|---|---|---|
| 1. Local store migration | 0 | 1 | 5 | 0 | 0 |
| 2. Server schema lockstep | 0 | 2 | 2 | 0 | 0 |
| 3. Cross-version coexistence | 0 | 3 | 2 | 0 | 0 |
| 4. The upgrade QA protocol | 0 | 2 | 2 | 1 | 1 |
| 5. Build & versioning hygiene | 0 | 3 | 1 | 0 | 0 |
| **Total (25)** | **0** | **11** | **12** | **1** | **1** |

Round 1 was 0 / 10 / 12 / 2 / 1. The ❌ count is identical; the composition moved.

---

## The persistence inventory (refreshed)

Every literal key the app writes, and whether the new frozen `_v1Keys` list at `store_migrator.dart:40-50`
knows about it.

| Key | Writer | In `_v1Keys`? | v2 changes shape → v1 user's data does what? |
|---|---|---|---|
| `housepital_orders` | `orders_provider.dart:11, 167` | ✅ | **Silently empties, then is overwritten** (§1.4) |
| `housepital_assessments` | `orders_provider.dart:12, 168` | ✅ | Same catch, same overwrite |
| `housepital_cart_items` | `cart_provider.dart:8, 209` | ✅ | Per-entry `try/catch` (`:229-233`) — bad entries dropped, rest survive |
| `housepital_saved_items` | `cart_provider.dart:9, 213` | ✅ | Same as cart |
| `housepital_saved_addresses` | `address_selection_screen.dart:70, 126` | ✅ | **Replaced by 3 fabricated demo addresses** (`:119-121`) |
| `theme_mode` | `theme_provider.dart:17, 55` | ✅ | Unknown value → `system`. Still the only correctly-degrading key |
| `preferred_language` | `auth_provider.dart:197`, `app_provider.dart:93` | ✅ | Unknown code → `Locale(code)`, unvalidated |
| `profile_photo_path` | `app_provider.dart:107` | ✅ | `File(path).existsSync()`-guarded at read → degrades to no photo |
| `has_onboarded` | `auth_provider.dart:196` | ✅ | Bare bool |
| **`housepital_reminders`** | **`reminders_provider.dart:99, 179`** | **❌ MISSING** | **All-or-nothing** — one throwing entry clears the list (`:125-127`) |
| **`housepital_cache_*`** (per-key prefix) | `cache_service.dart:6, 19` | ❌ MISSING | Returns `null` on parse failure — benign, 30-min TTL |
| **`notif_*`** (9 keys) | `app_provider.dart:129-130`; names at `notification_preferences_screen.dart:39-95` | ❌ MISSING | Missing key → per-key `defaultValue`. Safe |
| **`daily_rating_YYYY-MM-DD`** | `my_care_screen.dart:588-594, 615` | ❌ MISSING | Unbounded key growth, never pruned |
| `housepital_schema_version` | `store_migrator.dart:35` | n/a (the stamp itself) | **Deleted by `prefs.clear()` on logout** (`auth_provider.dart:223`) |

**Files written outside SharedPreferences: still none.** No `path_provider`, no `writeAsBytes`/`writeAsString`
in `lib/`. The migration surface is exactly the 14 rows above.

---

## Findings

### 1. Local store migration — 0✅ / 1⚠️ / 5❌ / 0 N/A

#### ⚠️ The persistent store opens under an explicitly VERSIONED schema with a migration plan.

**What landed and is correct.** `lib/services/store_migrator.dart` exists. `currentVersion` is a frozen
`const int` (`:33`), not computed from the model list — the checklist's "a version guard that compares a value
to itself" red flag is avoided. The downgrade branch (`:83-93`) refuses to migrate backwards, which is right.
The doc comment at `:15-30` states the contract explicitly.

**Ordering is correct — verified, not assumed.** This was the whole ballgame and it passes:
`main.dart:174` `await StoreMigrator.run();` sits between `ErrorWidget.builder` (`:139`) and the
`runApp(MultiProvider(...))` block (`:191-278`). Every provider that reads storage is constructed inside that
block — `CartProvider()..loadFromStorage()` (`:207-208`), `OrdersProvider()` (`:213`, loads in its constructor
at `orders_provider.dart:20-22`), `RemindersProvider()..load()` (`:217`), `ThemeProvider()` (`:276`, loads in
its constructor). None of them can run before the `await` completes. ✅ on this sub-point.

**Three defects that make the scheme less than it claims:**

- ❌ **A pre-versioning install is never stamped.** `store_migrator.dart:67-79`: no stamp + legacy data →
  `_migrateFrom(prefs, 1)`. In `_migrateFrom` (`:98-119`), `version = from = 1` and the loop condition is
  `while (version < currentVersion)` → `while (1 < 1)` → **false**. The body never runs, so `:117`
  `prefs.setInt(_versionKey, version)` **never executes**. Every device that already has data — every existing
  TestFlight/dev install — re-enters this branch on every single launch, re-logs the warning at `:75`, and
  never acquires a stamp. The one thing the file exists to do is not done for the population that most needs it.
  **Fix:** stamp unconditionally after the loop — `await prefs.setInt(_versionKey, currentVersion);` at the end
  of `_migrateFrom`.

- ❌ **A failed step still advances the version.** `store_migrator.dart:106-117`: the `catch` logs and
  deliberately falls through, then `version++` and `setInt` commit the new version anyway. A migration that
  throws is therefore recorded as having succeeded and is **never retried**. The comment at `:112-113` justifies
  this with "quarantine (below) preserves the original bytes" — but nothing enforces that the step quarantined
  before it threw, and today no step quarantines anything at all (next bullet). So the honest description is:
  *unmigrated data, marked migrated, with no marker anyone can find later.* That is data loss with extra steps,
  and it is worse than a crash because it is silent and permanent.
  **Fix:** on failure, write `__migration_failed_v{n} = true` and do **not** advance the stamp; add a retry
  counter (3 attempts) that quarantines the whole affected key set and then advances, so there is no boot loop
  *and* no silent lie. At minimum, forward the failure to `FirebaseCrashlytics.recordError` — `Log.error`
  (`logger.dart:63-65`) only `debugPrint`s, and its own TODO says Crashlytics forwarding is not wired.

- ❌ **`quarantine()` is unreachable.** `store_migrator.dart:126-144` has **zero call sites**
  (`grep -rn "quarantine" lib test --include="*.dart"` returns only `:20`, `:62`, `:112` — comments — plus the
  definition at `:126` and `:130`). `_migrations` is an empty map (`:57-58`), so no step can call it. The
  quarantine guarantee in the class doc (`:19-21`) is currently aspirational. More importantly, the four
  *existing* load paths that actually destroy data (§1.4) do not call it either — quarantine was added to the
  migrator and not to the places that wipe.

- ❌ **`run()` can abort startup.** The doc at `:61-62` says "Never throws". It has no `try`/`catch`:
  `SharedPreferences.getInstance()` at `:64` can throw on a platform-channel failure, and `main.dart:174`
  `await`s it *before* `runApp`. The `runZonedGuarded` handler at `main.dart:282-292` would log it, but
  `runApp` is never reached — the user gets a permanently white screen instead of a degraded app.
  **Fix:** wrap the whole body in `try { … } catch (e, st) { Log.error(…); }`.

**Is the "no stamp + no legacy keys = fresh install" inference safe?** No — and the `_v1Keys` bug below is
exactly what makes it unsafe in practice. Two scenarios:

1. **"Only `theme_mode` is set"** (opened the app once, changed the theme, never logged in). `theme_mode` **is**
   on the list (`:46`), so `hasLegacyData` is `true` → `_migrateFrom(prefs, 1)` → the dead loop above → no
   stamp, warning logged forever. Harmless today (`currentVersion == 1`), self-correcting at v2. The inference
   is right here; the code path is broken.
2. **"Only unlisted keys are set"** — a user whose local data is reminders, notification prefs, cached API
   responses and daily ratings, but who never checked out. `hasLegacyData` is **`false`** → the branch at
   `:69-72` stamps them at `currentVersion` and returns, declaring a device with months of data to be a fresh
   install. Today `currentVersion == 1`, so the stamp happens to be truthful. **At v3 it is not:** a user who
   skips v1 and v2 (the normal store-update pattern) gets stamped `3` with v1-shaped data, and migration steps
   1→2 and 2→3 never run. Their reminders are then parsed by v3 code, and `reminders_provider.dart:125-127`
   responds to a shape error by clearing the entire list. That is the exact failure the file was written to
   prevent, reintroduced through the frozen list.

The inference is only as safe as the list is complete, and the list is a `containsKey` check — it can only be
made safe by being exhaustive. The cheaper and safer inference is **`prefs.getKeys().isEmpty`**: genuinely
zero keys means genuinely fresh, and it cannot go stale when a key is added.

#### ❌ Additive + defaulted changes are verified to lightweight-migrate; anything else has a written migration stage BEFORE the change merges.

Evidence: **zero verification of any kind, still.** `grep -rln "StoreMigrator" test/` → no matches (exit 1).
There is not one test for the new file: not the fresh-install branch, not the legacy branch, not the downgrade
branch, not the stamp. The dead-loop bug at `:100` would have been caught by a three-line test
(`setMockInitialValues({'theme_mode': 'dark'})` → `run()` → `expect(prefs.getInt(versionKeyForTest), 1)`);
the test-only accessor for exactly that assertion already exists at `:147`, unused.
**Fix:** `test/services/store_migrator_test.dart` covering all four branches, plus one golden-fixture test per
persisted key that loads a frozen v1 blob and asserts the entity count.

#### ❌ Historical schema versions are FROZEN literals — never computed from the live model list.

*Round 1 graded this N/A (nothing to freeze). There is now a frozen list, and it is wrong.*

Evidence: `store_migrator.dart:40-50` freezes 9 keys. The app writes **14**. Missing:
`housepital_reminders` (`reminders_provider.dart:99`), `housepital_cache_*` (`cache_service.dart:6`),
nine `notif_*` keys (`notification_preferences_screen.dart:39-95`), and `daily_rating_YYYY-MM-DD`
(`my_care_screen.dart:593`). The comment at `:39` — "FROZEN — do not update when a key is renamed; add a
migration instead" — makes this *harder* to fix later, because a future maintainer reading it will not add the
missing keys either.

**Impact:** as shown above, an incomplete list turns "fresh install" into a false positive that skips
migrations on a device that needs them. A wrong frozen list is worse than no list, because the wrongness is
now load-bearing and documented as immutable.
**Fix (do this before v1 ships, while it is still legitimately editable):** either complete the list —
`housepital_reminders`, the nine `notif_*` names, `daily_rating_` and `housepital_cache_` as **prefix** checks
(`prefs.getKeys().any((k) => k.startsWith(...))`) since neither is a fixed key — or replace the whole heuristic
with `prefs.getKeys().isEmpty`, which cannot go stale. Add a test that asserts every key literal in `lib/` is
covered.

#### ❌ A release build with a missing migration fails LOUDLY. Wipe-and-recreate is compile-gated to debug builds only.

Evidence: unchanged, and now with a fifth silent path. The codebase still does the opposite in four places, and
the migrator adds a fifth:

1. `orders_provider.dart:203-207` — decode failure → `Log.warn` → `_orders` stays empty. The next
   `_persistAndNotify()` (`:163-173`) unconditionally `setString`s over the old blob. **No backup key, no
   quarantine call, no `assert`.** Order and invoice history for a paying patient is destroyed with one warn line.
2. `address_selection_screen.dart:119-121` — `catch (_) { return List.from(_defaultAddresses); }`. The user's
   real delivery address becomes the demo address `B-42, Sector 15, Noida 201301` (`:73-81`). **This is the
   address a nurse or an oxygen concentrator is dispatched to.**
3. `reminders_provider.dart:125-127` — `catch (_) { _items.clear(); }`, whole list.
4. `cart_provider.dart:254-256` — `catch` comment reads "Ignore corrupt data — start fresh".
5. **NEW:** `store_migrator.dart:108-117` — a throwing migration step is swallowed and the version advanced.

**A sixth, compound path found this round.** `orders_provider.dart:197-200`: when `_orders` is empty after
load, the provider assigns `_orders = DemoData.orders` and flags demo mode. That is documented as in-memory
only, and `test/providers/orders_persistence_test.dart:236-240` asserts nothing is written **at load time**.
But `addOrder` (`:66-76`) inserts into that same `_orders` list and calls `_persistAndNotify()`, which
`jsonEncode`s the **whole list** — demo orders included. So the first real checkout after any empty/failed load
**writes the fabricated demo order history to storage as if it were the patient's own**, permanently and
indistinguishably. The existing test misses this because it calls `addOrder` synchronously at
`:84-88`, before the async `_loadFromStorage()` has resolved (`:80-101`) — a timing artifact. In production the
load resolves during the splash's 2-second delay, so by the time a user can check out, the seed is present.
**Fix:** keep the demo seed in a separate `_demoOrders` field that the getter concatenates but the persister
never sees.

**Impact:** the single most dangerous property in this audit, unchanged from round 1. A v2 shape change is
indistinguishable from corruption, and the response to corruption is silent deletion followed by overwrite —
now with a demo-data substitution on top.
**Fix:** in each of the six paths, `await StoreMigrator.quarantine(prefs, key, currentVersion)` before writing
anything new (the function exists and is free), `assert(false, …)` for debug loudness, and
`FirebaseCrashlytics.recordError(e, s, fatal: false)` for release loudness.

#### ❌ A migration test opens a store snapshot from the OLDEST supported release and asserts row counts per entity survive.

Evidence: unchanged. `test/providers/orders_persistence_test.dart:185-223` tests *corrupt* JSON
(`'this is not valid json {{{'` at `:188`), which is a different thing from *older-shape* JSON, and the
assertion at `:195` — `expect(provider.orders, isEmpty)` — **certifies the data loss as correct behaviour**.
`:221` documents it: "This tests the actual behavior."
**Fix:** add `test/migration/v1_fixture_test.dart` asserting counts survive; change the corrupt-JSON assertion
from "orders are empty" to "the quarantine key exists and contains the original bytes".

#### ❌ Aged-data snapshot exists (months of realistic records, under version control).

Evidence: unchanged. `test/_mocks/` contains service fakes only; no persisted-store fixture anywhere in the repo.
**Fix:** commit `test/fixtures/store_v1_aged.json` — 40+ orders spanning 8 months, 60 reminders, 3 real
addresses, a full cart — generated once from a real run and frozen. It costs nothing now and cannot be
recreated after v1 ships.

---

### 2. Server schema lockstep — 0✅ / 2⚠️ / 2❌ / 0 N/A

#### ⚠️ Production schema deployed BEFORE the build that needs it, as a checklist line with date and owner.

Evidence: unchanged. `docs/DEPLOYMENT_GUIDE.md:438-452` is a real post-deployment checklist and
`docs/DATABASE_SCHEMA.md:648-660` keeps a numbered migration history with a hard "Every migration = update this
file" rule. **Gap:** the checklist is titled *Post*-Deployment and states no ordering constraint; no line
carries a date or a named owner; and the last line is "Version number bumped in pubspec.yaml", which is the
weakest possible version guard.
**Fix:** one line — `[ ] Migration NNN applied to prod — date ___ / owner ___ — BEFORE app build NNN submitted`.

#### ❌ New FIELDS on existing types re-arm the deploy gate, not only new types.

Evidence: unchanged — there is no deploy gate to re-arm. `.github/workflows/ci.yml` runs analyze / design gate /
test / coverage; it pins `flutter-version: '3.41.2'` (`:22`) and nothing else version-related.
**Fix:** a contract test asserting each `fromJson`'s required key set against a checked-in fixture of the live
response, refreshed at deploy time.

#### ❌ The app tolerates the server knowing LESS: writes queue and surface honestly, they do not silently drop.

Evidence: unchanged. No write queue anywhere. `app_provider.dart:204` `addPatient` is still an in-memory append
with `// TODO(persistence)`; manually-entered vitals are kept in memory only; `medication_provider` add/update/
delete have no offline path.
**Impact:** in the window where v2's app writes a field v2's server does not yet accept, the write is lost with
no user-visible signal. For a manually-entered vital or a medication change, that is a clinical record.
**Fix:** a durable `housepital_outbox` list + a "Not yet synced" chip; at minimum, surface the failure.

#### ⚠️ The app tolerates the reverse window (server knows MORE): unknown fields/types are ignored gracefully, never fatal.

*Improved by the banner; regressed on the parse count; the banner itself has a new bug.*

- *Unknown extra fields are still correctly ignored* — every `fromJson` reads named keys; none iterate the map.
- *Missing or renamed required fields are still fatal per call.* **49** unguarded `DateTime.parse(json[…])`
  sites, up from 48 (`grep -rn "DateTime.parse(" lib --include="*.dart" | grep -E "json\[|\['" | wc -l` → 49).
  Worst for clinical models: `medication_models.dart:154` (MedicationLog.scheduledTime),
  `my_care_models.dart:87, 248, 358`, `models.dart:642, 701, 739-747, 867, 1273, 1345-1346`,
  `equipment_order.dart:37`, `payment_reminder_service.dart:114`.
- **The banner is real and is the right idea.** `lib/data/demo_mode.dart` + `main_shell.dart:126-160` render a
  persistent "Showing sample data — we can't reach Housepital right now" notice. Seven fallback sites set the
  flag (`billing_provider.dart:43`, `orders_provider.dart:199`, `app_provider.dart:260`,
  `my_care_provider.dart:50, 98`, `medication_provider.dart:191, 236`).
- **REGRESSION — the banner can give a false all-clear.** `app_provider.dart:247` calls `DemoMode.reset()` when
  *the dashboard* fetch succeeds. `DemoMode.isServingDemoData` is a single global `ValueNotifier`
  (`demo_mode.dart:16-17`). So one provider's success clears a flag that *other* providers set: if the
  dashboard endpoint recovers while `MedicationProvider` (`:191`) and `OrdersProvider` (`:199`) are still
  serving `DemoData`, **the banner disappears while sample medications and a sample order history remain on
  screen.** That is strictly more dangerous than no banner, because it is now an affirmative all-clear.
  **Fix:** make `DemoMode` a `Set<String>` of provider tags — `mark('orders')` / `clear('orders')` — and let the
  banner show while the set is non-empty.
- **Two fallbacks never set the flag at all.** `app_provider.dart:136-138` seeds `DemoData.patient` as the
  current patient and the whole patient list with no `markServingDemoData()` — the *patient's identity* can be
  the sample patient's with no notice. `blog_provider.dart:38` and `:67-68` fall back to `DemoData.articles`
  with only a `debugPrint`.

**Impact:** an old client against a newer API still renders fabricated vitals, attendance, medications and
billing. The banner converts most of that from silent to announced — real progress — but the reset bug and the
two gaps mean it cannot yet be relied on as *the* signal.

---

### 3. Cross-version coexistence — 0✅ / 3⚠️ / 2❌ / 0 N/A

#### ⚠️ Enum-backed fields: an UNKNOWN raw value degrades to a safe fallback, tested per enum.

Evidence: unchanged. The one true Dart enum is handled correctly (`reminders_provider.dart:66`,
`ReminderCategory.values.asNameMap()[…] ?? ReminderCategory.reminder`). Everything else is a raw `String`
"enum" with `default:` arms, so an unknown value degrades rather than crashes.
**Gaps, both unchanged:** (a) no test asserts the fallback for any of them; (b) filter/aggregate call sites use
bare equality with no unknown bucket — `billing_screen.dart:64-75` decides *outstanding* by
`o['status'] == 'confirmed' || 'in_progress'` and *paid* by `== 'completed'`, so a v2 status like
`'awaiting_confirmation'` makes that order vanish from **both** money columns. `_filteredOrders` (`:56-59`) and
`_overdueCount` (`:78-86`) have the same shape. A wrong number, not a missing one.
**Fix:** an explicit `else → count as outstanding` bucket, plus one test per string-enum family.

#### ⚠️ Semantics riding an existing raw value are checked against the oldest version that can receive them.

Evidence: unchanged. `OrdersProvider.isQuotePending` (`orders_provider.dart:27-28`) is still a strict
`order['quoteStatus'] == 'pending'`, and `billing_screen.dart:65, 73` gate both money sums on it.
**Gap:** a v2 that adds a second quote state (`'revised'`, `'expired'`) is read by v1 as *not* quote-pending,
so v1 sums a `totalAmount` of 0 into the paid/outstanding column and renders ₹0 — which
`CLAUDE.md` explicitly forbids for price-less items.
**Fix, before v1 ships:** make v1's check tolerant — `quoteStatus != null && quoteStatus != 'confirmed'`.

#### ⚠️ New record types syncing into an old app version are ignored without crash and resurface intact.

Evidence: additive **fields** on order maps still survive cleanly — readers are uniformly defensive and unknown
keys round-trip because the map is stored whole. Two verified crash paths, both **unchanged**:

1. **`as int?` is not tolerant of a widened number.** If v2 ever writes `totalAmount` with decimals (GST),
   `billing_screen.dart:67, 74, 511` and `my_orders_screen.dart:234` **throw** — they do not fall back to
   `?? 0`. Same hazard at `models.dart:1496` (`CartItem.unitPrice`), `:1499` (`rentalMonths`), `:1500`
   (`quantity`), `:1155` (`price`). Note `billing_screen.dart` gets it right elsewhere — `refundAmount` uses
   `as num?` — and `orders_provider.dart:131` uses `(order['totalAmount'] as num?)?.toInt()`. The correct
   pattern is already in the file; the money-display sites just do not use it.
2. **`.cast<Map<String, dynamic>>()` is lazy.** `orders_provider.dart:183, 189`. A v2 that writes a non-map
   element does not throw at load — it throws later, at element access in the Billing list, **outside** the
   `try/catch` at `:177-207`. That is an uncatchable crash on the Billing tab, not a caught load failure.
   `reminders_provider.dart:117` shows the right pattern (`whereType<…>()`), two files away.

**Fix:** `as num?` everywhere money or counts are read; replace `.cast()` with eager
`.whereType<Map<String, dynamic>>().toList()`.

#### ❌ Features requiring the whole household to update together are LISTED in release notes.

Evidence: unchanged. `ls docs/` shows no `RELEASE_NOTES.md`; `docs/CHANGELOG.md` is developer-facing and
organised by audit batch. The app is explicitly multi-user (patient-self / primary contact / family /
caretaker), so the lagging-household case is real.
**Fix:** start `docs/RELEASE_NOTES.md` at v1.0.0 with a mandatory "Requires everyone in the family to update"
section (empty is fine for v1).

#### ❌ Version-skew QA pass: current build on device A, previous release on device B.

Evidence: still impossible — no previous release exists (§4.1). Recorded as ❌ rather than N/A because the
*precondition* (archive the build you are about to ship) is a v1 action, not a v2 one.

---

### 4. The upgrade QA protocol — 0✅ / 2⚠️ / 2❌ / 1 N/A / 1 BLOCKED-OWNER

#### ❌ An installable archive of the PREVIOUS release exists.

Evidence: unchanged and verified this round. `git tag` → **empty**. No `releases/` directory. `.gitignore`
excludes build output. CI produces a coverage artifact only.
This is a named **red flag** on the checklist ("No installable copy of the previous release anywhere") and it is
currently true. **Fix before v1 ships:** archive the exact v1 IPA + AAB and `git tag v1.0.0+1`, and make it a
line in the deployment checklist.

#### N/A Upgrade matrix run: N-1 → N and oldest-supported → N over the aged snapshot, on a real device.

Nothing to upgrade from. Becomes mandatory at v1.0.1.

#### ❌ Before/after data checksum: counts per entity recorded before the update and verified after.

Evidence: unchanged. No debug screen, no export, no count logging. To notice that v2 ate a v1 user's orders,
someone would have to remember how many they had.
**Fix:** a hidden diagnostics row (long-press the version string in `about_screen.dart:11`) printing
`schema=N orders=N assessments=N cart=N saved=N reminders=N addresses=N` plus any `__quarantine_v*` keys
present. ~30 lines, and it is the only way the upgrade matrix above can ever be checked.

#### ⚠️ Files outside the database survive: attachments, keychain, user defaults, notification registrations.

- *User defaults* — SharedPreferences survives an in-place upgrade by construction. ✅ mechanism; see §1 for
  what happens to the contents.
- *Attachments* — none stored locally. N/A.
- *Profile photo* — `app_provider.dart:107` still persists the raw `image_picker` absolute path, which lives in
  the app's purgeable tmp/Caches container. Reads are guarded by `File(path).existsSync()`, so it degrades to
  "no photo" rather than crashing. Survives a plain upgrade, not an OS cache purge or a device restore.
  **Fix:** copy the picked file into Documents and store a *relative* filename.
- *Keychain* — nothing uses `flutter_secure_storage`. Auth is Firebase-managed, so the session survives upgrade
  on its own. **But `auth_provider.dart:222-223` still calls `prefs.clear()`** — an unscoped wipe of every key
  in the inventory table: orders, cart, reminders, addresses, theme, language, notification prefs. **New this
  round:** it now also deletes `housepital_schema_version` and any `__quarantine_v*` entries, so the one
  recovery mechanism the migrator provides is destroyed by the same line. If v2 ever forces a re-auth on
  upgrade (a token-format change, or enabling the auth gate commented out at `main.dart:416-417`), that single
  line strands the user with an empty app *and* removes the evidence.
  **Fix:** replace `prefs.clear()` with an explicit allowlist of session keys (`has_onboarded` + auth-scoped
  keys). Never `clear()` a store you have just versioned.
- *Notification registrations* — unchanged. IDs derived from `medicationId.hashCode`
  (`medication_reminder_service.dart:288, 292` — `medicationId.hashCode.abs() * 10 + slotIndex`). Dart does not
  guarantee `String.hashCode` stability across SDK versions; if it shifts in a future Flutter, `cancel()`
  computes a different ID and misses, leaving **orphaned, uncancellable medication reminders firing for a
  medication the patient has stopped taking.** For a healthcare app that is a clinical-safety bug. (Adjacent:
  `hashCode.abs() * 10` can exceed the 32-bit Android notification-ID range.)
  **Fix:** persist an explicit `medId → notificationId` map and allocate from a monotonic counter.

#### ⚠️ First launch after update is timed; any migration longer than ~2s shows progress UI.

*Changed — a migration slot now exists, but it is in the worst possible place.*

Evidence: `StoreMigrator.run()` is `await`ed at `main.dart:174`, **before `runApp`** (`:191`). At that moment
there is no Flutter UI at all — only the OS launch image. A slow migration therefore presents as a frozen
launch screen with no progress affordance and no way to communicate, and on iOS a long-enough one is killed by
the watchdog. `splash_screen.dart:13-19` is still a hard `Future.delayed(2s)` → `pushReplacementNamed('/home')`
with no async work, i.e. the one place that *could* host a progress bar does nothing. Nothing times the
migration. Cost is zero today because `_migrations` is empty (`store_migrator.dart:57-58`), so this is a design
risk rather than a live defect.
**Fix:** keep the fast path in `main()` (read the stamp; if `stamped == currentVersion`, return immediately),
and move any *work* into the splash where it can `await` behind a determinate indicator if it exceeds 300 ms.

#### BLOCKED-OWNER — The update is tested via the SAME channel users get (TestFlight/store update in place).

Cannot be verified from the repo. **What I would need:** App Store Connect or Play Console visibility showing a
prior build, or the owner's written confirmation that a TestFlight build has been distributed and then updated
over *in place* (not cable-installed). `CLAUDE.md` documents the cable-install path and its `0xe8008014`
hazard but says nothing about testing an update in place.

---

### 5. Build & versioning hygiene — 0✅ / 3⚠️ / 1❌ / 0 N/A

#### ⚠️ Marketing version and build number come from ONE source of truth; a test fails if the built product disagrees.

Evidence: `pubspec.yaml:4` `version: 1.0.0+1` is correctly the single source for both platforms —
`ios/Runner/Info.plist` uses `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` and
`android/app/build.gradle.kts` uses `flutter.versionCode` / `flutter.versionName`.
**Two gaps, both unchanged:** (a) `about_screen.dart:11` `static const _appVersion = '1.0.0'` is a hardcoded
second source of truth rendered to the user — it will drift at the first version bump and the user-visible
version will be a lie; (b) no test asserts any of this.
**Fix:** add `package_info_plus`, read the version at runtime in About, and test
`PackageInfo.version == pubspec version`. The same dependency is the prerequisite for the force-upgrade gate.

#### ⚠️ Generated files cannot silently revert version keys — regenerate, then verify against the built artifact.

Evidence: the mechanism is right (both platforms indirect through Flutter build variables, so regeneration
cannot hardcode a stale literal). **Gap:** nothing verifies the *built artifact*; CI never produces one.

#### ❌ Build number increments on EVERY upload, enforced by habit or automation.

Evidence: unchanged. `pubspec.yaml` sits at `+1`. No CI step reads or bumps it, no git hook, nothing in
`scripts/`. There are **no git tags at all**, so even a manual "greater than the last tag" check has no baseline.
**Fix:** a CI check on release branches that the build number is strictly greater than the last `v*` tag —
which requires creating the first tag.

#### ⚠️ The changelog distinguishes user-visible changes from internal ones, and names anything requiring household-wide update.

Evidence: `docs/CHANGELOG.md` is thorough but mixes user-visible and internal entries freely, and nothing flags
household-wide-update requirements. See §3.4. **Newly stale and worth fixing while you are in there:**
`docs/CHANGELOG.md:64` and `docs/FEATURE_TRACKER.md:143` still assert **SIX tabs with Calendar at index 3**;
`docs/ARCHITECTURE.md:68` and `docs/SCREEN_MAP.md:6, 73` say the same. Nav is now five tabs
(`test/screens/main_shell_test.dart:228` asserts "five tabs, no Calendar tab"). A changelog that misdescribes
the shipped navigation cannot be trusted to describe a store-format change either — which is the checklist's
"Release notes that say 'bug fixes' over a store-format change" red flag in embryo.

---

## Blockers (must fix before v1 reaches a real patient)

1. **The migration scheme does not actually stamp the devices that need it, and lies when a step fails.**
   `store_migrator.dart:100` (dead `while (1 < 1)` — pre-versioning installs never get a stamp);
   `:106-117` (a throwing step is swallowed and the version advanced, so the migration is never retried and no
   failure marker exists); `:126-144` (`quarantine()` has zero callers). Ordering vs providers is **correct**
   (`main.dart:174` before `:191`) — that part passes.
2. **The frozen `_v1Keys` list is wrong.** `store_migrator.dart:40-50` lists 9 of 14 live keys; missing
   `housepital_reminders`, `housepital_cache_*`, nine `notif_*`, `daily_rating_*`. It is the input to the
   "fresh install" inference, so an unlisted-keys-only device gets stamped at `currentVersion` and skips every
   migration step. Fix it now, while a frozen list is still legitimately editable — or replace the heuristic
   with `prefs.getKeys().isEmpty`.
3. **Silent wipe-then-overwrite of order/invoice history.** `orders_provider.dart:203-207` + `:163-173`, with
   `test/providers/orders_persistence_test.dart:195` certifying the loss. Plus the new compound path: an empty
   or failed load seeds `DemoData.orders` in memory (`orders_provider.dart:197-200`) and the next real checkout
   persists the fabricated history as the patient's own.
4. **`logout()` calls `prefs.clear()`.** `auth_provider.dart:222-223`. Nukes orders, cart, reminders,
   addresses, theme, language, notification prefs — and now the schema stamp and every quarantine key too.
5. **Saved addresses silently replaced by three fabricated demo addresses on parse failure.**
   `address_selection_screen.dart:119-121`, defaults at `:72-104`. Wrong dispatch address for a home visit.
6. **No force-upgrade / minimum-version gate.** Verified absent again this round: zero hits for
   `force_upgrade | min_supported | remote_config | package_info | 426 | X-App-Version` across `lib/` and
   `pubspec.yaml`. A known-bad build showing wrong dosages cannot be stopped.

## High

7. **`DemoMode.reset()` is a global clear triggered by one provider.** `app_provider.dart:247` +
   `demo_mode.dart:16-17`. The banner can go down while medications and orders are still sample data — a false
   all-clear, which is worse than no banner. **This is a new defect introduced by the round-1 fix.**
8. **Two demo fallbacks never raise the flag.** `app_provider.dart:136-138` (the *patient identity* itself) and
   `blog_provider.dart:38, 67-68`.
9. **49 unguarded `DateTime.parse(json[…])`** (was 48 — grew). Any renamed/missing required field is fatal per
   call, absorbed by a `DemoData` fallback. Worst: `medication_models.dart:154`, `my_care_models.dart:87`,
   `models.dart:642, 701, 739-747`.
10. **`as int?` on money throws instead of defaulting.** `billing_screen.dart:67, 74, 511`;
    `my_orders_screen.dart:234`; `models.dart:1155, 1496, 1499, 1500`. Use `as num?` — `orders_provider.dart:131`
    already does.
11. **Lazy `.cast<Map<String,dynamic>>()` throws outside the guard.** `orders_provider.dart:183, 189` — an
    uncatchable Billing-tab crash. `reminders_provider.dart:117` already shows the fix.
12. **Notification IDs derived from `String.hashCode`.** `medication_reminder_service.dart:288, 292`.
13. **No archived installable and no git tags.** `git tag` is empty. Named red flag.
14. **Zero tests for `StoreMigrator`.** `grep -rln StoreMigrator test/` → no matches. Every defect in blocker 1
    is a three-line test away; `versionKeyForTest` (`:147`) exists for exactly that and is unused.

## Medium / Low

15. `about_screen.dart:11` hardcodes `'1.0.0'` — second source of truth, rendered to the user.
16. No build-number automation and no baseline tag to enforce against.
17. `reminders_provider.dart:125-127` still clears the whole list when a `fromJson` throws (per-entry filtering
    at `:117` only covers non-map elements).
18. `billing_screen.dart:56-86` has no unknown-status bucket — a future status drops an order from both money
    totals.
19. `OrdersProvider.isQuotePending` (`orders_provider.dart:27-28`) is a strict `== 'pending'` — a future quote
    state renders ₹0, which the business rule forbids.
20. `daily_rating_YYYY-MM-DD` grows unbounded (`my_care_screen.dart:588-594`). Prune to 90 days.
21. `profile_photo_path` stores an absolute `image_picker` temp path (`app_provider.dart:107`).
22. No before/after entity-count diagnostics.
23. No `docs/RELEASE_NOTES.md`.
24. Stale six-tab/Calendar-tab claims in `docs/CHANGELOG.md:64`, `docs/FEATURE_TRACKER.md:143`,
    `docs/ARCHITECTURE.md:68`, `docs/SCREEN_MAP.md:6, 73`.
25. `StoreMigrator.run()` has no top-level `try/catch` despite documenting "Never throws"
    (`store_migrator.dart:61-64`); a throw there aborts `main()` before `runApp` → white screen.

## BLOCKED-OWNER

- **§4.6 — update tested via the same channel users get.** Needs App Store Connect / Play Console visibility, or
  the owner's confirmation that a TestFlight build has been distributed and then updated over in place.
- **§2.1 (partial)** — whether a production MySQL migration has actually been applied ahead of any app build.
  `docs/DATABASE_SCHEMA.md:648-660` lists migration 001 only; the deployed database is not visible from the repo.

---

## Updated minimal pre-launch list

Everything below is editable now and frozen forever once v1 is on a phone. Ordered by cost-to-fix-later.

1. **Fix `_v1Keys` (or delete the heuristic).** `store_migrator.dart:40-50`. Add `housepital_reminders`, the
   nine `notif_*` names, and prefix checks for `daily_rating_` and `housepital_cache_` — or replace the whole
   inference with `prefs.getKeys().isEmpty`. *A wrong frozen list is worse than none; this is the only item
   whose window closes at the first install.*
2. **Stamp unconditionally.** Add `await prefs.setInt(_versionKey, currentVersion);` after the loop in
   `_migrateFrom` (`store_migrator.dart:98-119`), so pre-versioning devices actually acquire a version.
3. **Do not advance the version on a failed step.** `store_migrator.dart:106-117`. Write
   `__migration_failed_v{n}`, keep the old stamp, cap retries at 3, then quarantine-and-advance. Forward the
   error to Crashlytics (`logger.dart:63-65` currently only `debugPrint`s).
4. **Wrap `run()` in try/catch** so a `SharedPreferences` failure cannot abort `main()` before `runApp`.
5. **Call `quarantine()` from the six destructive load paths** — `orders_provider.dart:203`,
   `address_selection_screen.dart:119`, `reminders_provider.dart:125`, `cart_provider.dart:254`, plus an
   `assert(false, …)` for debug loudness. The function already exists; it just has no callers.
6. **Stop fabricating a delivery address.** `address_selection_screen.dart:119-121` → return an empty list and
   make the user re-enter, or surface "we couldn't read your saved addresses". Never silently dispatch a nurse
   to `B-42, Sector 15, Noida`.
7. **Replace `prefs.clear()` with a session-key allowlist.** `auth_provider.dart:223`.
8. **Keep the demo order seed out of the persisted list.** `orders_provider.dart:197-200` + `:163-173` — hold it
   in a separate field the persister never sees.
9. **Fix the demo banner's false all-clear.** Make `DemoMode` a tagged set (`demo_mode.dart:16-17`,
   `app_provider.dart:247`), and add `markServingDemoData()` at `app_provider.dart:136-138` and
   `blog_provider.dart:38, 67-68`.
10. **Add `test/services/store_migrator_test.dart`** covering fresh / legacy / downgrade / failed-step, and
    freeze `test/fixtures/store_v1_aged.json` with a counts-survive test. Change
    `orders_persistence_test.dart:195` from asserting emptiness to asserting the quarantine key exists.
11. **Widen the money casts** — `as num?` at `billing_screen.dart:67, 74, 511`, `my_orders_screen.dart:234`,
    `models.dart:1155, 1496, 1499, 1500` — and make `orders_provider.dart:183, 189` eager `whereType`.
12. **Loosen `isQuotePending`** to `!= null && != 'confirmed'` (`orders_provider.dart:27-28`) and add an
    unknown-status bucket in `billing_screen.dart:56-86`.
13. **Add the force-upgrade gate.** `package_info_plus` + `firebase_remote_config`
    (`{"min_supported_build": 1}`), checked on the splash, with **SOS still reachable** from the blocking
    screen. Second channel: send `X-App-Version` from `api_service.dart` and treat HTTP 426 as force-upgrade.
    Do both — Remote Config still works when the API is down, which is when you will need it.
14. **`git tag v1.0.0+1` and archive the IPA + AAB** at submission, and add a build-number CI check against the
    last tag.
15. **Read the version at runtime in About** (`about_screen.dart:11`) and add the pubspec-agreement test.
16. **Add the hidden entity-count diagnostics row** — without it, no future upgrade can ever be checked.
17. **Start `docs/RELEASE_NOTES.md`** with a "Requires everyone in the family to update" section, and correct
    the five stale six-tab doc lines.
