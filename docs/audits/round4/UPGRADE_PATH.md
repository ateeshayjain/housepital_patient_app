# Upgrade Path — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-03 · **Auditor:** Upgrade Path (control family UPG) · **Scope:** source review (see Limitations)
**Repo:** `housepital_patient_app`, branch `fix/five-tab-nav` · **Round 3:** `9a80fe2` · **Round 2:** `820060b`
**Checklist:** Upgrade Path Checklist (App-Agnostic), Suite v2.0, 39 controls across 8 sections.

> **Round-3 comparability note.** The round-3 report graded 25 controls (sections 1–5) under the
> ✅/⚠️/❌ vocabulary. Suite v2.0 adds sections 6–8 (interrupted migration, historical/staged
> evolution, platform support & EOL) — **14 controls audited here for the first time** — and
> replaces the symbols with Pass/Warning/Fail/N/A. Scorecard movement below is stated on the
> 25 comparable controls as well as the full 39.

---

## Applicability

**MASTER-3 trigger: applies, and applies harder than in round 3.**

Round 3 could argue this checklist forward-only ("the app has never shipped, so N-1 → N cannot be
run"). Commit `13e3656` removed that argument for section 1. The app now contains a **live,
executing storage migration**: `StoreMigrator.currentVersion` is `2` (`lib/services/store_migrator.dart:34`)
and the v1→v2 step at `:65-73` deletes two production keys off any device that carries them. That
is a destructive, one-directional, already-written store transform. Every device that has run an
earlier build of this app — the owner's, every internal tester's — is now a real upgrade population,
and the checklist's first principle ("data outlives code") is no longer hypothetical here.

Sections 2, 7 (server halves) apply because two real backends exist (`../housepital-backend`,
`../housepital-api`); the app points at neither, which changes the *evidence* available, not the
applicability. Section 8 applies because a forced-update gate is a v1 decision, not a v2 one.

---

## Prior-round status

| Round-3 finding | R3 grade | Status now | Evidence |
|---|---|---|---|
| **B1c** Failed-step guard code-correct but **zero test coverage** | ⚠️ | **Pass — genuinely closed** | `_buildShippedMigrations()` (`store_migrator.dart:54-74`) + `debugSetMigrations` (`:90-96`) make the loop reachable. Three loop tests exist (`store_migrator_test.dart:183-236`). Two of them fail if `return` (`:177`) becomes `break` — traced in §A below |
| **§Repairs 1** `return`-vs-`break` fragility is *positional*, protected by nothing | ❌ | **Structurally still positional; now behaviourally pinned** | `:177` `return` and `:187` `setInt(currentVersion)` are unchanged. But `store_migrator_test.dart:194` and `:217` both fail under the `break` mutation. The *code* hazard survives; the *regression* is now caught |
| **§Repairs 1** `:187` writes `currentVersion`, not `version`; `_migrateFrom` has no `from >= currentVersion` guard | ❌ | **Unchanged, still uncaught** | `store_migrator.dart:187`. Mutation M6 in §A passes all 15 tests |
| **B1d** `quarantine()` has zero production callers | ❌ | **Pass** | First production caller: `store_migrator.dart:70`. Dead code no longer |
| **H14** Zero/thin `StoreMigrator` tests | ⚠️ | **Warning — 15 tests, 3 mutation gaps** | `store_migrator_test.dart` grew 10 → 15. §A lists three surviving mutations |
| **§Repairs 3** Corrupt version stamp = permanent invisible dead end | ❌ | **Unchanged, and now more expensive** | `store_migrator.dart:124` is still `prefs.getInt(_versionKey)`; `shared_preferences-2.5.5/lib/src/shared_preferences_legacy.dart:121` is `_preferenceCache[key] as int?` → throws on a non-int. Such a device now also silently skips a **real** migration. Test `:121-130` still asserts only `completes` |
| **§Repairs 4 / §4.4** `logout()` destroys `__quarantine_v*` | ❌ | **REGRESSED IN EFFECT** | `auth_provider.dart:231-234` preserves exactly 2 keys, unchanged. In round 3 the quarantine keys were always empty. As of `13e3656` they hold the user's **only** copy of their pre-v2 order history, and logout deletes it |
| **§Repairs 4** logout preservation untested; test asserts the OLD contract | ❌ | **Unchanged** | `auth_provider_test.dart:281-285` fixture is `{has_onboarded, preferred_language, some_other_pref}` — no preserved key present — and `:302` is `expect(prefs.getKeys(), isEmpty)`. Restoring `prefs.clear()` still passes |
| **B2** Silent wipe-then-overwrite of order history on corrupt JSON | ❌ | **Unchanged** | `orders_provider.dart:241-244` (catch → `_orders` stays `[]`) + `:205` unconditional `setString`. No `quarantine()` call on this path |
| **B2b** Test certifies the loss | ❌ | **Unchanged** | `orders_persistence_test.dart:195`, `:222` `expect(provider.orders, isEmpty)`; `:221` "This tests the actual behavior" |
| **Blocker 2** demo-orders-persisted-as-real, made *more* reachable by round 2's repair | ❌ | **Amplifier changed, landmine unchanged — and the migration is the new amplifier** | `clearPatientScopedData` is memory-only again (`orders_provider.dart:258-263`), so the logout route is closed. But `:235-237` `if (_orders.isEmpty) _orders = DemoData.orders;` and `:104-113` `addOrder` → `_persistAndNotify` → `:205 jsonEncode(_orders)` are untouched. §D traces how the v1→v2 step now feeds it directly |
| **B4** Saved addresses → 3 fabricated demo addresses | ❌ | **Unchanged** | `lib/screens/checkout/address_selection_screen.dart:119-120` `catch (_) { return List.from(_defaultAddresses); }`; defaults `:70-102`; `B-42, Sector 15, Noida 201301` at `:73-82` |
| **B5** No force-upgrade / minimum-version gate | ❌ | **Unchanged (4th verification)** | `grep -rniE "force_?upgrade\|min_?supported\|minimum_?version\|remote_?config\|package_info\|426\|X-App-Version" lib pubspec.yaml` → **zero output** |
| **H7** 49 unguarded `DateTime.parse(json[…])` | ❌ | **Unchanged at 49** | `grep -rn "DateTime.parse(" lib --include="*.dart" \| grep -E "json\[\|\['" \| wc -l` → **49** (51 total) |
| **H8** `as int?` on money | ❌ | **Unchanged** | `billing_screen.dart:66, 73, 496`; `my_orders_screen.dart:234`; `models.dart:1155, 1496, 1497, 1499, 1500` |
| **H9** Lazy `.cast<Map<String,dynamic>>()` | ❌ | **Unchanged** | `orders_provider.dart:221, 227` |
| **H11** No archived installable, no tags | ❌ | **Unchanged** | `git tag \| wc -l` → **0**. No `releases/` |
| **M12** `about_screen.dart:11` hardcodes `'1.0.0'` | ❌ | **Unchanged** | `lib/screens/settings/about_screen.dart:11`, rendered `:69` |
| **M16** `reminders_provider` all-or-nothing clear | ⚠️ | **Unchanged** | `reminders_provider.dart:125-127` `catch (_) { _items.clear(); }` |
| **M22** No `docs/RELEASE_NOTES.md` | ❌ | **Unchanged** | `ls docs/ \| grep -i release` → empty |
| **M24** Stale nav docs after a doc-dedicated commit | ⚠️ | **Half fixed, half regressed in detail** | `docs/SCREEN_MAP.md:16` is now correct and past-tense. `docs/ARCHITECTURE.md:206-208` still says "**FIXED full-width solid-orange bar**… **Six root tabs** (Calendar added at index 3)" — two contradictions of `CLAUDE.md`, after a commit (`9127713`) whose stated purpose was the documentation pass |
| **M25** `_hasAnyStoredData`'s `key != _versionKey` guard unreachable | ⚠️ | **Unchanged** | `store_migrator.dart:194`; sole call site `:127` is inside `if (stamped == null)`, and `getInt` returns null only when the key is absent |

**Net movement.** Two genuine closures (`B1d`, `B1c`), both inside `StoreMigrator`, both real code
with real tests. **Nothing outside `store_migrator.dart` moved.** One finding regressed in effect
without a line of code changing (logout × quarantine). The round-2→3 pattern ("half-wires: correct
data structures, unwritten behaviour") **does not repeat for this module** — the migrator is now
whole. The round-4 pattern is narrower and is stated in §D: *the repair is correct in isolation and
routes state into an adjacent defect nobody fixed.*

---

## A. The migration loop: do the three new tests actually pin their guards?

This was round 3's specific criticism, so it gets a mutation table rather than a paragraph.
Guards under test, all in `store_migrator.dart:156-188`:

| # | Mutation | What it breaks |
|---|---|---|
| M1 | `return` (`:177`) → `break` | Falls through to `:187`, stamping `currentVersion` — skips *every* remaining migration in one jump |
| M2 | delete `await prefs.setInt(_versionKey, version)` (`:176`) | A failed step leaves no stamp at all on the pre-versioning path |
| M3 | delete the whole `catch` (`:166-178`) | Restores the round-2 defect's sibling: the throw escapes to `run()`'s guard |
| M4 | delete `version++` (`:180`) | Infinite loop **before `runApp`** (`main.dart:175` vs `:192`) — a frozen launch image, no crash report |
| M5 | delete the in-loop `setInt(_versionKey, version)` (`:181`) | Removes the per-step checkpoint; a kill mid-chain re-runs completed steps |
| M6 | `:187` writes `version` instead of `currentVersion` | (the round-3 recommended *fix*) |

Traced against the three loop tests plus the two v1→v2 tests:

| Mutation | `:183` failing-step | `:202` retry | `:221` in-order | v1→v2 `:240` | Caught? |
|---|---|---|---|---|---|
| **M1 break** | **FAIL** (`:194` expects 1, gets 2) | **FAIL** (`:217` expects 2 attempts, gets 1 — run 2 short-circuits at `:139`) | pass | pass | **YES — round 3's headline concern is now pinned, twice** |
| **M2** | pass — fixture stamp is already `1`, so writing `1` is indistinguishable from writing nothing | pass (same reason) | n/a | n/a | **NO** |
| **M3** | pass — throw escapes to `run():116`, stamp stays at the fixture's `1`, `step2_ran` still absent | pass — run 2 succeeds, `attempts == 2` | n/a | n/a | **NO** |
| **M4** | n/a (step throws first) | **hang → timeout** | **hang → timeout** | n/a | **YES**, as a timeout rather than an assertion |
| **M5** | n/a | pass | pass — `:235` asserts the *final* stamp, which `:187` supplies regardless | n/a | **NO** |
| **M6** | n/a | n/a | pass — after the loop `version == currentVersion == 2` | n/a | **NO** |

**Answer to the brief.** The tests are real and they close the exact hole round 3 named: **M1 is
caught by two independent tests.** But three mutations survive.

- **M2 and M3 survive for the same structural reason:** both loop tests seed `{versionKey: 1}`, and
  the guard's whole distinctive behaviour is *writing the last good version where none would
  otherwise be written*. That only diverges on the **pre-versioning path** (`store_migrator.dart:135`,
  `_migrateFrom(prefs, 1)` with no stamp on disk), and no test drives a failing step down that path.
  On a real pre-versioning device, M3 means the stamp is never written, the device re-enters the
  pre-versioning branch forever, and `Log.warn` at `:133` fires on every launch — round 2's **B1b
  defect, restored**, with a green suite.
- **M5 survives and matters more than it looks.** `:181` is the only checkpoint that makes a
  multi-step chain resumable across a process kill (UPG-6.01/6.03). Test `:221-236` is named
  *"steps run IN ORDER and **each one advances the stamp**"* but asserts only the order list (`:234`)
  and the terminal stamp (`:235`). It does not assert the second half of its own name. One-line fix:
  make the injected steps record `p.getInt(versionKey)` and assert `[0, 1]`.
- **M6 survives, which is the round-3 recommendation being untestable.** `:187` still writes
  `currentVersion`, and `_migrateFrom` still has no `from >= currentVersion` early branch, so the
  function remains unsafe *in isolation* — protected only by the two call sites (`:135` literal `1`,
  `:153` a `stamped` already proven `< currentVersion`).

**Credit where due, on the v1→v2 tests:** the copy-before-delete *ordering* is genuinely pinned.
Deleting `quarantine` (`:70`) fails `store_migrator_test.dart:254`; deleting `remove` (`:71`) fails
`:259`; and swapping the two lines also fails `:254`, because `quarantine` reads via `prefs.get`
(`:206`) and returns early on `null`. That is a well-constructed test.

---

## B. `_buildShippedMigrations()` as a function: does the reasoning hold?

The doc comment (`store_migrator.dart:47-49`) claims a **function** avoids a lazy-static capture
hazard that a field would have. **Verified — the reasoning is correct, and the hazard is real.**

The natural field form is `static final _shipped = <int, …>{…}; static final _migrations = _shipped;`
Both names would then reference **one** map object, so `debugSetMigrations`'s `..clear()` (`:93-95`)
would empty the "pristine" copy too, and `debugResetMigrations` would restore an empty table —
permanently, for the life of the isolate, with the shipped v1→v2 step silently gone. Because
`_buildShippedMigrations()` returns a **fresh map literal on every call**, `:82` and `:103` produce
independent objects and reset genuinely restores. The one live consequence is visible in the test
file: the `v1 -> v2` group (`:239-271`) runs *after* the loop group and depends on
`tearDown(StoreMigrator.debugResetMigrations)` (`:181`) having restored the shipped step. It does.

**Can the hooks corrupt production state? Not today, but nothing in the code prevents it.**

- Zero production callers: `grep -rn "debugSetMigrations\|debugResetMigrations" lib` → only the
  declarations at `store_migrator.dart:91, 100`. Safety is by *absence of callers*, not by construction.
- Neither hook is compile-gated. There is no `assert(() {…}())` wrapper, no `kDebugMode` check, no
  `if (!kDebugMode) return;`. Both methods are public API in a **release** binary and will mutate a
  `static final` map at any time, including after `run()` has begun.
- The only backstop is the `@visibleForTesting` annotation (`:90`, `:99`), whose diagnostic
  (`invalid_use_of_visible_for_testing_member`) is a **warning** — and CI runs
  `flutter analyze --no-fatal-warnings --no-fatal-infos` (`.github/workflows/ci.yml:34`), with no
  promotion to error in `analysis_options.yaml`. **A production call to `debugSetMigrations` would
  not fail this repo's CI.**
- `debugSetMigrations` mutates process-global state with no scoping construct. Within the one file
  that uses it the `tearDown` is correct, but any future test that calls it outside that group
  leaks a stubbed migration table into every later test in the same isolate.

Graded **Warning**, not Fail: the mechanism is right, the reasoning in the comment is sound, and the
residual risk is a maintenance hazard rather than a live defect. Cheapest hardening:
`assert(() { …mutate…; return true; }());` inside both hooks, so they are provably inert in release.

---

## C. The v1→v2 step reviewed: correctness, idempotency, and the two partial-failure cases

```dart
1: (prefs) async {
  const legacyOrders = 'housepital_orders';           // :66
  const legacyAssessments = 'housepital_assessments'; // :67
  for (final key in <String>[legacyOrders, legacyAssessments]) {
    if (!prefs.containsKey(key)) continue;            // :69
    await quarantine(prefs, key, 1);                  // :70
    await prefs.remove(key);                          // :71
  }
},
```

**Is quarantine-then-remove the right shape? Yes.** Copy before delete is the correct order, it is
the order that is written, and it is the order the test pins. The frozen-literal rule is *actually
obeyed*: `:66-67` re-declare the key names rather than referencing
`OrdersProvider.legacyOrdersKey` (`orders_provider.dart:26-27`), which is exactly what
`store_migrator.dart:23-26` demands. (Minor doc defect: `orders_provider.dart:25` says those consts
are "referenced by the migration" — `grep -rn "legacyOrdersKey\|legacyAssessmentsKey" lib test`
returns only their own declarations. Nothing references them. The comment invites a future
maintainer to keep two "linked" constants in sync that are not linked.)

**Is it idempotent? Yes, and it is re-entrant at both interruption points.** Traced:

| Interruption | Store state | Next launch |
|---|---|---|
| Killed between `:70` and `:71` | quarantine copy written, legacy key present, stamp still 1 | step re-runs: `containsKey` true → quarantine writes identical bytes → remove. Converges |
| Killed between `:71` and `:181` | legacy key gone, quarantine present, stamp still 1 | step re-runs: `containsKey` false → `continue` → stamp advances to 2. Converges |
| `run()` called twice in one process | stamp 2 | `:139` `stamped == currentVersion` → return. Pinned by `store_migrator_test.dart:74-83` (on the pre-versioning path) |

**What if it runs twice with the legacy key recreated in between?** `quarantine` (`:204-222`) has
**no collision guard** — `setString(target, value)` at `:210` overwrites
`__quarantine_v1_housepital_orders` unconditionally. Today no code writes the global key
(`grep` for `housepital_orders` in `lib` → only the two inert consts and the migration's own
literals), so this is latent, not live. It becomes live the moment a rollback-then-reupgrade cycle
or a restored device backup reintroduces the key.

**What if `quarantine` succeeds but `remove` fails?** Benign. `prefs.remove` returns `Future<bool>`
and the step ignores it (`:71`). A `false` leaves an orphaned global key that nothing reads
(`OrdersProvider` reads only `housepital_orders_<patientId>`, `:22-23, :32-35`), while the copy
exists. Wasted bytes, no loss.

**The reverse case is the dangerous one, and the code does not distinguish it.** `quarantine`
ignores the `bool` returned by every one of its five writes (`:210, 212, 214, 216, 218`), and
`shared_preferences-2.5.5/lib/src/shared_preferences_legacy.dart:175-186` (`_setValue`) writes the
in-memory cache **first** and returns the platform result **without reverting on failure**. So under
a disk-full, quota, or protected-data-locked condition — three of UPG-6.02's six named cases — the
sequence is: copy silently fails → `:71` removes the original → `:220` logs
*"Quarantined … as …"* (a **false success message**) → `:181` stamps 2 → never retried. The user's
order history is gone, and the log says it was saved. This is the single most defensible new
finding in this section.

**Latent type hole in `quarantine`.** `:217` tests `value is List<String>`. On a real device that
branch is **unreachable**: the cache is populated from `getAll()`, whose pigeon decoder casts only
the outer map (`shared_preferences_foundation-2.5.6/lib/src/messages.g.dart:406-407`
`(… as Map<Object?, Object?>?)!.cast<String, Object>()`), leaving list values as `List<Object?>` —
which is precisely why `getStringList` has to call `.cast<String>()` itself
(`shared_preferences_legacy.dart:136-139`). A string-list value read off disk therefore falls
through all five branches, `quarantine` writes nothing, and `:220` still logs success. The test that
would have caught this — `store_migrator_test.dart:159-174`, *"preserves non-string types"* — passes
only because `setMockInitialValues` (`shared_preferences_legacy.dart:272-286`) stores the Dart
`List<String>` literal straight into the cache. **The test is green on a type that cannot occur on a
device.** Not live for the shipped step (both keys hold Strings), but `quarantine` is public,
general-purpose API and the next step that uses it on a list key will lose data with a green suite.

---

## D. Per-patient keys as an upgrade story: quarantined ≠ migrated

**Is "quarantine, do not attribute" the right call? Yes — and the reasoning at `:58-64` is sound.**
The v1 keys were global. An account may have had several patients. Assigning the whole blob to
whichever patient happens to be active at migration time would silently attribute one person's
clinical order history to another, on a shared family phone, in an app whose entire round-3
patient-isolation work existed to prevent exactly that. Refusing to guess is correct.

**Is the history recoverable in practice? No. Only in principle.** The file's own contract promises
"support can retrieve a patient's order history" (`store_migrator.dart:21-22, 202-203`). Nothing
shipped can deliver on it:

1. **No read path exists.** `grep -rn "quarantine" lib --include="*.dart"` outside
   `store_migrator.dart` → one comment (`orders_provider.dart:19`) and zero code. No screen, no
   export, no upload, no diagnostics row. Round 3 asked for a hidden entity-count diagnostics screen;
   it was not built.
2. **No extraction path exists.** `ios/Runner/Info.plist` sets neither `UIFileSharingEnabled` nor
   `LSSupportsOpeningDocumentsInPlace`, so the app container is not user-reachable on iOS; on Android
   `/data/data` is not readable without root. Recovery would require a full encrypted device backup
   plus third-party tooling — not a support flow.
3. **The bytes are deleted by a routine action.** `auth_provider.dart:231-234` preserves exactly
   `{housepital_schema_version, housepital_pending_deletion}`; `__quarantine_v1_*` is removed by the
   loop at `:235-238`. So the recovery window closes at the user's **first logout** — including the
   `logout()` that `delete_account_screen` invokes. `SessionScope` does not touch them
   (`session_scope.dart:125-133` removes only `_patientScopedPrefsKeys` and the `daily_rating_`
   prefix), so logout is the sole destroyer. This is round-3 blocker 3 with new consequences: the
   keys it destroys were empty then and hold the user's only copy now.

**And the migration feeds the demo-orders landmine directly.** Round 3 found that
`clearPatientScopedData` persisting `[]` routed every logout into the demo seed. That amplifier is
gone (`orders_provider.dart:258-263` is memory-only again). The landmine is not. Trace for a tester
who upgrades with real orders under the global key:

1. `main.dart:175` → v1→v2 step removes `housepital_orders` (`store_migrator.dart:71`).
2. `OrdersProvider._loadFromStorage` (`:214`) reads `housepital_orders_<patientId>` — **never
   written**, because the per-patient scheme is new → `ordersJson == null`.
3. `:235-237` `if (_orders.isEmpty) { _orders = DemoData.orders; DemoMode.markServingDemoData(…); }`
   → the Billing tab now shows fabricated orders under this patient's name.
4. First real checkout: `addOrder` (`:104`) `_orders.insert(0, …)` on top of the demo list →
   `:113 _persistAndNotify()` → `:205 setString(_ordersKey, jsonEncode(_orders))` → **the demo
   history is written to disk as this patient's own, permanently.**

The test that is supposed to cover this — `orders_persistence_test.dart:230-247`, `:244-245`
`expect(prefs.getString('housepital_orders_$_kTestPatient'), isNull, reason: 'demo seed must not be
persisted')` — asserts only that **construction** writes nothing. It does not exercise
`addOrder`-after-seed, which is the path that persists it. `CLAUDE.md`'s claim that "demo orders are
never written to storage (a test asserts this)" is therefore true of the load path and false of the
app. (One hazard checked and **absent**: `DemoData.orders` is a getter returning a fresh literal
(`demo_data.dart:582`), so `_orders.insert` does not mutate shared demo state across providers.)

Net upgrade story for the population this migration exists to serve: **their history disappears from
the app, is preserved in a location nothing can read, is deleted by their next logout, and is
replaced on disk by fabricated demo orders at their next purchase.** Each step is individually
defensible; the composition is not.

---

## Control results

### 1. Local store migration

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| UPG-1.01 versioned store + migration plan | **Pass** | `store_migrator.dart:34` `static const int currentVersion = 2`; `run()` awaited at `main.dart:175`, before `runApp` `:192`, so no provider reads storage first; real step at `:65-73`; contract documented `:16-26` | — |
| UPG-1.02 additive/defaulted verified to lightweight-migrate; else a written stage BEFORE the change merges | **Warning** | The shape change (global → `housepital_orders_<patientId>`, `orders_provider.dart:22-23`) and its migration stage shipped in the **same** commit `13e3656`, and it is documented (`docs/CHANGELOG.md:16-19`). But the stage does not *migrate* — it quarantines and deletes (§C). No test asserts any entity count survives into the app | Impact: the only "migration" of real data is a copy to an unreadable key. Mitigation: none in place. Owner: OWNER-TBD. Due: before first store submission |
| UPG-1.03 frozen literals, never computed from the live model list | **Pass** | `:34` literal `const`; step re-declares `:66-67` rather than referencing `OrdersProvider.legacyOrdersKey` (`orders_provider.dart:26-27`, zero refs); `_hasAnyStoredData` (`:192-197`) uses `prefs.getKeys()`. No self-referencing guard | — |
| UPG-1.04 missing migration fails LOUDLY; wipe-and-recreate compile-gated to debug | **Fail** | Seven silent paths, no `assert(false, …)` on any: `orders_provider.dart:241-244` → `:205` overwrite; `address_selection_screen.dart:119-120`; `reminders_provider.dart:125-127`; `cart_provider.dart:264-267`; `store_migrator.dart:124` (corrupt stamp); `store_migrator.dart:160-162` (a **missing step** is a `Log.warn` and the loop skips forward); `quarantine`'s unchecked write bools `:210-218` with a success log at `:220`. `logger.dart:63` `TODO(observability)` means all of it is `debugPrint` in release | Blocks release |
| UPG-1.05 migration test over an oldest-supported snapshot asserts row counts survive | **Fail** | `store_migrator_test.dart:244-261` seeds two one-element blobs and asserts they are **quarantined** — i.e. that they do *not* survive into the app. `orders_persistence_test.dart:195, 222` assert emptiness. No golden v1 store fixture exists | Blocks release |
| UPG-1.06 aged-data snapshot under version control | **Fail** | No persisted-store fixture anywhere; `test/_mocks/` holds service fakes. `store_migrator_test.dart` fixtures are `'[]'` / one-element blobs — the checklist's named "three fixture rows" red flag | Blocks release. Cannot be recreated after v1 ships |

### 2. Server schema lockstep

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| UPG-2.01 schema deployed BEFORE the build, as a dated/owned checklist line | **Warning** (+ BLOCKED-OWNER sub-item) | `docs/DEPLOYMENT_GUIDE.md` and `docs/DATABASE_SCHEMA.md` exist; neither states an ordering constraint, date or named owner | Impact: the first backend-pointing release has no sequencing artifact. Owner: OWNER-TBD |
| UPG-2.02 new FIELDS re-arm the deploy gate | **Fail** | There is no deploy gate of any kind to re-arm | Blocks release once a backend is wired; today it is a v1 omission |
| UPG-2.03 app tolerates a server that knows LESS; writes queue and surface honestly | **Fail** | No write queue. `app_provider.dart` `addPatient` is an in-memory append with `// TODO(persistence)`; manual vitals are memory-only; `medication_provider` add/update/delete have no offline path | Blocks release |
| UPG-2.04 app tolerates a server that knows MORE; unknown fields ignored, never fatal | **Warning** | Improved half: `demo_mode.dart` is a tagged `Set` of sources, so a fallback announces itself. Unmoved half: 49 unguarded `DateTime.parse(json[…])` (count reproduced this round); `as int?` money casts (`billing_screen.dart:66, 73, 496`; `my_orders_screen.dart:234`; `models.dart:1155, 1496-1500`) | Impact: a widened or renamed field is fatal per call and lands in a demo fallback. Owner: OWNER-TBD |

### 3. Cross-version coexistence

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| UPG-3.01 unknown enum raw value degrades safely, tested per enum | **Warning** | `reminders_provider.dart:66` handles the one true Dart enum. String "enums" degrade via `default:` arms; no test asserts any fallback; `billing_screen.dart:56-86` has no unknown-status bucket, so a v2 status removes an order from **both** money columns | Impact: a wrong total, not a missing one. Owner: OWNER-TBD |
| UPG-3.02 semantics riding an existing raw value checked against the oldest receiver | **Warning** | `orders_provider.dart:65-66` `isQuotePending` is strict `== 'pending'`; a v2 `'revised'`/`'expired'` reads as not-quote-pending → v1 renders ₹0, which `CLAUDE.md` explicitly forbids | Owner: OWNER-TBD |
| UPG-3.03 new record types from a newer version ignored without crash, resurface after update | **Warning** | **Store level is genuinely correct and tested:** `store_migrator.dart:141-151` returns before any write on a newer stamp, pinned by `store_migrator_test.dart:102-117` asserting both the stamp and the data. **Element level is not:** `orders_provider.dart:221, 227` `decoded.cast<Map<String, dynamic>>()` is lazy, so a non-map element throws at *access* on the Billing tab, outside the `try` at `:215-245` | Impact: uncatchable crash on a tab, not a graceful ignore. Owner: OWNER-TBD |
| UPG-3.04 household-wide-update features listed in release notes | **Fail** | `ls docs/ \| grep -i release` → empty. The app is explicitly multi-user (patient-self / primary contact / family / caretaker) | Blocks release |
| UPG-3.05 version-skew QA pass (current on A, previous on B) | **Fail** | Not run and not runnable: `git tag \| wc -l` → 0, no archived build. Recorded as Fail, not N/A, per the master rule | Blocks release |

### 4. The upgrade QA protocol

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| UPG-4.01 installable archive of the previous release exists | **Fail** | `git tag` → 0 tags; no `releases/`; CI (`.github/workflows/ci.yml`) produces a coverage artifact only. Named checklist red flag | Blocks release |
| UPG-4.02 upgrade matrix run over the aged snapshot on a real device | **Fail** (round 3 graded this N/A) | **Reasoning, so a reviewer can contest it:** the v1→v2 step exists *because* devices carrying pre-per-patient data exist — otherwise `store_migrator.dart:65-73` and the `_hasAnyStoredData` pre-versioning branch (`:126-137`) are ceremony. An upgrade-in-place over a v1 store is therefore runnable **today** on the owner's own device, and no evidence of it exists in the repo | Blocks release. Mitigation: one manual run, recorded, before submission |
| UPG-4.03 before/after per-entity checksum | **Fail** | No debug screen, no export, no count logging. `store_migrator.dart:181, 187` now write a stamp that no shipped surface can display | Blocks release |
| UPG-4.04 files outside the database survive | **Fail** (was Warning in round 3 — **regressed in effect**) | `auth_provider.dart:231-234` preserves 2 keys; `__quarantine_v1_*` (now holding the user's only pre-v2 order history), `preferred_language` and `theme_mode` (device state that `session_scope.dart:42-43` says must NOT be cleared) and the nine `notif_*` toggles are all removed at `:235-238`. Untested: `auth_provider_test.dart:302` `expect(prefs.getKeys(), isEmpty)` passes with `prefs.clear()` restored. Also unchanged: absolute `image_picker` photo path (`app_provider.dart:106-107`); `String.hashCode` notification IDs (`medication_reminder_service.dart:288, 292`) | Blocks release |
| UPG-4.05 first launch timed; >2s shows progress UI | **Warning** | `StoreMigrator.run()` is awaited at `main.dart:175`, **before `runApp`** at `:192` — no Flutter UI exists at that moment, only the OS launch image, and iOS watchdog-kills a long enough launch. Real cost today is ~2 reads + ≤4 writes. But mutation M4 (§A) puts an infinite loop in exactly this slot | Impact: a frozen launch image with no crash report. Owner: OWNER-TBD |
| UPG-4.06 update tested via the SAME channel users get | **BLOCKED-OWNER** | Unverifiable from the repo. `CLAUDE.md` documents the cable-install path and its `0xe8008014` hazard and says nothing about in-place update testing | Need: App Store Connect / Play Console visibility of a prior build, or written confirmation of a TestFlight build distributed and then **updated in place** |

### 5. Build & versioning hygiene

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| UPG-5.01 one source of truth; a test fails if the built product disagrees | **Warning** | `pubspec.yaml:4` `version: 1.0.0+1` correctly feeds both platforms. But `lib/screens/settings/about_screen.dart:11` `static const _appVersion = '1.0.0'` is a second source rendered to the user at `:69`, with no agreement test | Owner: OWNER-TBD. Fix: `package_info_plus` + a pubspec-agreement test |
| UPG-5.02 generated files cannot silently revert version keys | **Warning** | Indirection through `$(FLUTTER_BUILD_NAME)` / `flutter.versionName` is the correct mechanism; nothing verifies a built artifact because CI never produces one | Owner: OWNER-TBD |
| UPG-5.03 build number increments on every upload | **Fail** | No automation; `git tag` → 0, so even a manual "greater than last tag" check has no baseline | Blocks release |
| UPG-5.04 changelog distinguishes user-visible from internal; names household-wide changes | **Warning** | **Improved:** `docs/CHANGELOG.md:16-19` explicitly names the storage versioning and the per-patient keying, so the "release notes that say 'bug fixes' over a store-format change" red flag is avoided *in the changelog*. **Not improved:** no `docs/RELEASE_NOTES.md`, no user-visible/internal split, and nothing tells a user their pre-upgrade order history will not appear. Trust signal: `docs/ARCHITECTURE.md:206-208` still describes a "FIXED full-width solid-orange bar" and "Six root tabs (Calendar added at index 3)" **after** the documentation-dedicated commit `9127713`, contradicting `CLAUDE.md` and `docs/SCREEN_MAP.md:16` | Owner: OWNER-TBD |

### 6. Interrupted and resource-constrained migration *(first audited this round)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| UPG-6.01 resume/safe restart after kill, crash, power loss, backgrounding, watchdog, reboot | **Warning** | Design is resumable: per-step checkpoint `store_migrator.dart:181`, failed-step last-good stamp `:176` + `return` `:177`, and the shipped step is re-entrant at both interruption points (§C table). **But nothing is tested for interruption**, and mutations M2 and M5 (§A) — deleting the failed-step stamp and deleting the checkpoint — pass the entire suite | Impact: resumability is real today and unprotected against the next edit of this file. Owner: OWNER-TBD |
| UPG-6.02 low disk / full / memory pressure / protected-data lock / corrupt input / no network fail without destroying the last usable state | **Fail** | `quarantine` ignores the `bool` from all five writes (`:210, 212, 214, 216, 218`) and `_setValue` does not revert the cache on platform failure (`shared_preferences_legacy.dart:175-186`); the step then removes the original at `:71` and `:181` stamps success, while `:220` logs *"Quarantined …"* — a false success under three of this control's six named conditions. Corrupt input separately: `orders_provider.dart:241-244` → `:205` overwrite; `store_migrator.dart:124` corrupt stamp is a permanent dead end | Blocks release |
| UPG-6.03 steps idempotent or checkpointed; partial completion cannot duplicate, skip, or apply twice | **Warning** | The shipped step is idempotent via `containsKey` (`:69`) and converges from either interruption point (§C). The loop checkpoints at `:181`. **Gaps:** `quarantine` has no collision guard (`:210` overwrites an existing `__quarantine_v1_*`), latent because nothing writes the legacy key today; the only "runs twice" test (`store_migrator_test.dart:74-83`) exercises the pre-versioning path, not the step; and the checkpoint at `:181` is unpinned (M5) | Owner: OWNER-TBD |
| UPG-6.04 preflight verifies storage, schema identity, key availability, prerequisites before irreversible work | **Fail** | No preflight of any kind. The schema-identity read (`:124`) *throws* instead of checking; there is no free-space check; and the first irreversible act — `prefs.remove` at `:71` — runs with no verification that the copy at `:70` landed | Blocks release. ~6 lines: check the `quarantine` write result before removing |
| UPG-6.05 failure preserves diagnostics and offers a safe recovery route without recommending destructive reinstall | **Fail** | `Log.error` at `:117` and `:167` reaches only `debugPrint` in release (`logger.dart:63` `TODO(observability)`, still unwired — confirmed by `docs/KNOWN_ISSUES.md:32-33`, which names "every `StoreMigrator` failure path"). No in-app diagnostics; quarantined bytes have no read path and no extraction path (§D); logout deletes them | Blocks release |

### 7. Historical paths and staged server evolution *(first audited this round)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| UPG-7.01 every sequential historical step exercised, not only an oldest→current shortcut | **Warning** | Real coverage now exists (`store_migrator_test.dart:221-236` runs 0→1→2 in order; `:240-261` runs the shipped step from a stamped v1). **But** the sequential test uses **synthetic** steps injected via `debugSetMigrations`, and the shipped table has exactly one step, so "sequential" is not yet meaningfully exercised. More pointedly, the **single most likely real device state — no stamp AND a legacy key present** — is untested: `:44-45` documents that the pre-versioning fixture deliberately avoids `housepital_orders` "because that key is now rewritten by the v1->v2 step", so the two conditions are never combined | Impact: the exact path a backup-restore or a first upgrade takes (§8.02) has no test. Owner: OWNER-TBD |
| UPG-7.02 server changes follow expand–migrate/backfill–contract with compatibility monitoring and a retirement point | **Fail** | `../housepital-backend/functions/src/config/cloudSql.ts:33-35` configures Knex `migrations: { directory: "../../sql" }`, but `housepital-backend/sql/` contains only `.sql` files (`001_initial_schema.sql` … `004_seed_coupons.sql`), which Knex does not load under its default `loadExtensions`; there is no `knexfile`, and `functions/package.json:6-16` has no migrate script. `../housepital-api` uses Laravel migrations (ordered, tracked) — a different schema for the same nouns. No expand/contract process, compatibility monitoring, or client-retirement point is documented anywhere | Blocks release once a backend is wired |
| UPG-7.03 backfills restartable, observable, rate-limited, validated before reads switch | **Fail** | No backfill tooling in either backend repo; **unverified against any deployed database** (see BLOCKED-OWNER). Graded Fail rather than N/A per the master rule | Owner: OWNER-TBD |
| UPG-7.04 dual-read/dual-write period defines source of truth, reconciliation, rollback, removal criteria | **Warning** | The v1→v2 change was a hard cutover with **no dual-read window at all**: `OrdersProvider` reads only `housepital_orders_<patientId>` (`:32-35`) and never the legacy key, even before migration — so a v1 device's history became unreadable at commit `13e3656` regardless of the migrator. Quarantine is a write-only mitigation, not a dual-read | Impact: no reconciliation is possible because nothing ever reads the old representation. Owner: OWNER-TBD |
| UPG-7.05 application rollback distinguished from data rollback; irreversible changes have forward-fix and containment | **Warning** | **Genuinely good half:** the downgrade branch (`:141-151`) is correct, returns before any write, and is pinned by `store_migrator_test.dart:102-117` asserting both stamp and data — real data-rollback discipline. **Missing half:** a user who migrates to v2 and is then rolled back to a v1 build holds a stamp of `2` and no orders under any key that build reads (`housepital_orders` was removed at `:71`). No forward-fix or containment plan is documented | Impact: TestFlight rollback silently empties order history. Owner: OWNER-TBD |

### 8. Platform support, encryption, and end of life *(first audited this round)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| UPG-8.01 min OS/device, extension compat, app-group data, keychain groups, encryption keys, protected files in upgrade QA | **Fail** | No upgrade QA exists at all (UPG-4.02), so none of these are in it. Specifically unconsidered: `main.dart:175` runs the migration unconditionally at every launch with no protected-data-availability check, which is the same missing preflight as UPG-6.04 | Blocks release |
| UPG-8.02 backup restore from an older app/OS/device into the current version tested | **Fail** | Not tested; unverified. This is not theoretical: `SharedPreferences`/`NSUserDefaults` are included in platform backups, so restoring a pre-`13e3656` store into a v2 build is exactly the untested no-stamp-plus-legacy-key path in UPG-7.01 | Blocks release |
| UPG-8.03 forced-update / minimum-version gates preserve data access, accessibility, purchase restoration, export, support routes | **Fail** | No gate exists to evaluate: the grep for `force_upgrade\|min_supported\|minimum_version\|remote_config\|package_info\|426\|X-App-Version` across `lib` and `pubspec.yaml` returns nothing, for the fourth consecutive round | Blocks release. A known-bad build showing wrong medication dosages cannot be stopped |
| UPG-8.04 deprecation notice, support window, compatibility cutoff, export, server retirement documented | **Fail** | Nothing in `docs/` addresses any of these; no `RELEASE_NOTES.md`, no support-window statement, no data-export route (which also blocks the UPG-6.05 recovery story) | Blocks release |

---

## Scorecard

**Pass 2 · Warning 15 · Fail 21 · N/A 0 · BLOCKED-OWNER 1** (39 controls).

| Section | Pass | Warning | Fail | N/A | BLOCKED-OWNER |
|---|---|---|---|---|---|
| 1. Local store migration | 2 | 1 | 3 | 0 | 0 |
| 2. Server schema lockstep | 0 | 2 | 2 | 0 | 0 |
| 3. Cross-version coexistence | 0 | 3 | 2 | 0 | 0 |
| 4. Upgrade QA protocol | 0 | 1 | 4 | 0 | 1 |
| 5. Build & versioning hygiene | 0 | 3 | 1 | 0 | 0 |
| 6. Interrupted / constrained migration *(new)* | 0 | 2 | 3 | 0 | 0 |
| 7. Historical paths / staged server *(new)* | 0 | 3 | 2 | 0 | 0 |
| 8. Platform support & EOL *(new)* | 0 | 0 | 4 | 0 | 0 |
| **Total** | **2** | **15** | **21** | **0** | **1** |

**On the 25 controls comparable to round 3:** Pass 2 · Warning 10 · Fail 12 · BLOCKED-OWNER 1,
against round 3's 2 ✅ / 11 ⚠️ / 10 ❌ / 1 N/A / 1 BLOCKED-OWNER. The two apparent losses are
**re-grades under v2.0's stricter rules, not new defects**: UPG-4.02 moves N/A → Fail ("not tested
is not N/A", plus the argument in the table), and UPG-4.04 moves Warning → Fail because the keys
logout destroys now contain real data. No control that was Pass or Warning in round 3 regressed
because of a code change.

---

## Release blockers (every Fail)

1. **UPG-6.02 / UPG-6.04 — `quarantine` cannot fail loudly, so the copy-before-delete guarantee is
   not actually enforced.** `store_migrator.dart:210-218` discards five `bool` results;
   `:71` then deletes the original; `:220` logs success either way. Under disk-full or a
   protected-data lock the user's order history is destroyed and the log says it was preserved.
   ~6 lines: return the write result from `quarantine`, and make `:70-71` `if (await quarantine(…)) { await prefs.remove(key); }`.
2. **UPG-4.04 — `logout()` deletes the quarantined history.** `auth_provider.dart:231-234` preserves
   2 keys; `__quarantine_v1_*` is not among them. This is the only copy of a pre-upgrade user's
   orders, and account deletion routes through the same `logout()`.
3. **UPG-1.04 — nothing fails loudly.** Seven silent destructive paths, zero `assert(false, …)`,
   and `logger.dart:63` still unwired, so in release every one is a `debugPrint` into the void.
4. **UPG-1.05 / UPG-1.06 — no golden v1 store and no aged snapshot.** The only migration test data is
   one-element blobs. This is the cheapest item on the list today and impossible to recreate after v1 ships.
5. **UPG-6.05 / UPG-8.04 — a migration failure has no recovery route.** No diagnostics surface, no
   export, no readable path to the quarantine keys, and no support-window documentation.
6. **UPG-8.03 / UPG-2.02 / UPG-2.03 — no force-upgrade gate, no deploy gate, no write queue.**
   Unchanged for four rounds.
7. **UPG-4.01 / UPG-4.02 / UPG-4.03 / UPG-5.03 — no archived build, no upgrade run, no
   before/after counts, no build-number discipline.** `git tag` → 0.
8. **UPG-3.04 / UPG-3.05 — no release notes and no version-skew pass** in an explicitly multi-user app.
9. **UPG-7.02 / UPG-7.03 — the backend migration mechanism is configured but inert.**
   `cloudSql.ts:33-35` points Knex at a directory of raw `.sql` files it will not load; no runner, no
   `knexfile`, no migrate script.
10. **UPG-8.01 / UPG-8.02 — no upgrade QA at all**, so backup-restore (the most likely real path
    into the untested no-stamp-plus-legacy-key state) has never been exercised.

## Warnings requiring risk acceptance

All 15 carry `Owner: OWNER-TBD` and are stated with impact in the tables above. The four that
should not be accepted quietly:

- **UPG-6.01/6.03 — three mutations still pass the suite** (§A: M2, M3, M5). The failed-step stamp
  at `:176`, the entire `catch` at `:166-178`, and the checkpoint at `:181` are each deletable with
  1,819 green tests. Two of the three are one-line test fixes.
- **§B — `debugSetMigrations`/`debugResetMigrations` ship in release binaries** and the only
  backstop is a warning that `.github/workflows/ci.yml:34` explicitly does not fail on.
- **§C — `quarantine`'s `List<String>` branch (`:217`) is unreachable on device**, and the test that
  claims to cover it (`store_migrator_test.dart:159-174`) is green only because of the mock.
- **UPG-5.04 — `docs/ARCHITECTURE.md:206-208` still misdescribes the shipped navigation** after a
  documentation-dedicated commit. A doc set that is wrong about something as visible as the tab bar
  is not yet trustworthy for describing a store-format change to users.

## BLOCKED-OWNER — needs access I do not have

- **UPG-4.06** — whether an update was ever tested through the channel users get. **Need:** App Store
  Connect / Play Console visibility of a prior build, or written confirmation that a TestFlight build
  was distributed and then updated **in place** (not cable-installed).
- **UPG-2.01 / UPG-7.03 (partial)** — the deployed migration state of the production database.
  **Need:** which backend v1 will point at, and that database's applied-schema state on submission day.
  `housepital-backend/sql/` and `housepital-api/database/migrations/` define incompatible schemas for
  the same nouns and I cannot tell which, if either, is deployed.

## Limitations of this audit

- **Source review only (MASTER-4.04).** No release artifact, no production-like environment, no
  device. Every runtime claim here is a trace through source plus pinned package sources
  (`shared_preferences-2.5.5`, `shared_preferences_foundation-2.5.6`), not an observation.
- **No test, build, or clean was run** (brief §Rules). Central results cited: `flutter analyze` clean,
  design gate passes, 1,819 tests pass across 101 files. **The mutation results in §A are derived by
  tracing, not by running the mutants.** They are reproducible in about ten minutes by anyone with a
  checkout; a reviewer who disagrees should run them rather than take my trace.
- **The device-vs-mock type claim in §C** (`List<Object?>` from `getAll` vs `List<String>` from
  `setMockInitialValues`) is read from the plugin sources cited. It is the one finding I would most
  want confirmed on a physical device before it is acted on.
- **The backend read was shallow** — configuration and directory listings, not the Cloud Functions
  data layer. UPG-7.02/7.03 are graded on absence of process artifacts, which is weaker evidence than
  a positive finding.
- **UPG-4.02's Fail rests on an inference** (that pre-per-patient devices exist because the migration
  targets them). The reasoning is stated inline so it can be contested directly.

---

## Updated minimal pre-launch list

Ordered by cost-to-fix-later. Items 1–4 are new or reshaped this round.

1. **Make `quarantine` report failure, and gate the delete on it.** Return the write `bool` from
   `store_migrator.dart:204-222`; change `:70-71` to delete only on a confirmed copy; move the
   success log below the check. *This is the difference between "we preserve your data" and "we log
   that we preserved your data".*
2. **Preserve `__quarantine_v*` across logout** (prefix match at `auth_provider.dart:235-238`), and
   rewrite `auth_provider_test.dart:281-302` so the fixture contains the preserved keys and the
   assertion is `getKeys() == preserved`. Add `preferred_language` and `theme_mode` per
   `session_scope.dart:42-43`. Reference `StoreMigrator.versionKeyForTest` and
   `DeleteAccountScreen.pendingDeletionKey` instead of retyping the literals.
3. **Close the three surviving mutations** (§A): (a) a failing step on the **pre-versioning** path
   (no stamp + a legacy key present) asserting the stamp lands at the last good version — this kills
   M2 and M3 and covers the untested state in UPG-7.01/8.02; (b) make the injected steps in
   `store_migrator_test.dart:221-236` read `getInt(versionKey)` and assert `[0, 1]`, killing M5 and
   making the test's name true.
4. **Harden `_migrateFrom` against its own callers** (round 3's item 2, still open): write `version`
   not `currentVersion` at `:187`, and add an explicit `from >= currentVersion` early branch, so
   `break` and `return` become equivalent and M6 stops being silent.
5. **Give a migrated user their history back, or tell them.** Either a read path for
   `__quarantine_v*` (a support/diagnostics screen behind a long-press on the version string,
   printing the stamp, per-entity counts and any quarantine keys — this also closes UPG-4.03) or a
   one-time notice on first v2 launch. Right now neither exists.
6. **Keep the demo order seed off disk.** `orders_provider.dart:235-237` + `:205` — hold the seed in
   a separate `_demoOrders` field the getter concatenates and `_persistAndNotify` never sees, and
   extend `orders_persistence_test.dart:230-247` to call `addOrder` after the seed and assert the
   persisted blob contains only the real order.
7. **Make a corrupt stamp self-healing.** Read via `prefs.get()` + `is int` at `store_migrator.dart:124`;
   on a wrong type, quarantine the stamp and fall into the pre-versioning path.
8. **Compile-gate the debug hooks.** Wrap the bodies of `:91-96` and `:100-104` in
   `assert(() { … return true; }());` so they are provably inert in release.
9. **Call `quarantine()` from the remaining destructive load paths** — `orders_provider.dart:241`,
   `address_selection_screen.dart:119`, `reminders_provider.dart:125`, `cart_provider.dart:264` —
   plus `assert(false, …)` for debug loudness and the Crashlytics forward `logger.dart:63` still TODOs.
10. **Stop fabricating a delivery address.** `address_selection_screen.dart:119-120` → empty list plus
    "we couldn't read your saved addresses". Never silently dispatch a nurse to `B-42, Sector 15, Noida`.
11. **Change `orders_persistence_test.dart:195, 222`** from asserting emptiness to asserting the
    quarantine key exists and holds the original bytes.
12. **Freeze `test/fixtures/store_v1_aged.json`** — 40+ orders over 8 months, 60 reminders, 3 real
    addresses, a full cart — with a counts-survive test. Costs nothing now; impossible after v1 ships.
13. **Widen the money casts** to `as num?` (`billing_screen.dart:66, 73, 496`,
    `my_orders_screen.dart:234`, `models.dart:1155, 1496-1500`) and make `orders_provider.dart:221, 227`
    eager `whereType`.
14. **Add the force-upgrade gate.** `package_info_plus` + `firebase_remote_config`
    (`{"min_supported_build": 1}`) checked on the splash with **SOS still reachable**, plus an
    `X-App-Version` header and HTTP 426 handling.
15. **`git tag v1.0.0+1`, archive the IPA + AAB** at submission, add a CI build-number check, and run
    one upgrade-in-place over a v1 store on a real device with per-entity counts recorded before and after.
16. **Read the version at runtime in About** (`about_screen.dart:11`) with a pubspec-agreement test.
17. **Wire the backend migration runner or delete the misleading config** (`cloudSql.ts:33-35`), and
    write the schema-deploy-before-submit line with a date and a named owner.
18. **Start `docs/RELEASE_NOTES.md`** — with the v1→v2 store change and its consequence for
    pre-upgrade history as its first entry — and correct `docs/ARCHITECTURE.md:206-208`.
