# Upgrade Path Checklist (App-Agnostic) — Audit round 3 vs commit `9a80fe2`

**Date:** 2026-08-05 · **Round 2:** `820060b` · **Round 1:** `803124d` · **Branch:** `fix/five-tab-nav`
**Repo:** `housepital_patient_app` (`pubspec.yaml:4` → `version: 1.0.0+1`)
**Method:** read-only. No `flutter test` / `build` / `clean` run (brief §Rules). Central results cited:
`flutter analyze` clean, design gate passes, 1,813 tests pass. Test *quality* judged from sources.

> **Framing (unchanged from round 2).** The app has never shipped publicly, so N-1 → N cannot be run.
> The checklist is applied forward: *what must exist in v1 so the first upgrade over real patient data
> survives?* Every ❌ is cheap now and expensive-to-impossible after the first store build reaches a phone.

---

## Round-2 findings: status now

| Finding | R2 grade | Now | Evidence |
|---|---|---|---|
| **B1a** Frozen `_v1Keys` list wrong (9 of 14 live keys) | ❌ | **✅ FIXED** | List deleted. `store_migrator.dart:37-43` replaces it with a tombstone comment; `_hasAnyStoredData` (`:139-144`) iterates `prefs.getKeys()`. Cannot go stale. Pinned by `test/services/store_migrator_test.dart:57-70` using `housepital_reminders` — the exact key the old list missed |
| **B1b** Pre-versioning installs never stamped (`while (1 < 1)`) | ❌ | **✅ FIXED** | Unconditional `setInt(_versionKey, currentVersion)` at `store_migrator.dart:134`. Pinned by three tests (`store_migrator_test.dart:43, 57, 72`) that fail if `:134` is deleted — verified by tracing, see §Repairs 1 |
| **B1c** Failed step still advances the version | ❌ | **⚠️ CODE FIXED, ZERO TEST COVERAGE** | `store_migrator.dart:111-125`: catch → `setInt(_versionKey, version)` → **`return`** at `:124`. The logic is correct. But `_migrations` is empty (`:50-51`) and private, `currentVersion == 1` (`:33`), so the entire `while` body (`:105-129`) is unreachable in all 10 tests. Delete the `return` and every test still passes — §Repairs 2 |
| **B1d** `quarantine()` unreachable | ❌ | **❌ UNCHANGED in production** | `grep -rn quarantine lib --include="*.dart" \| grep -v store_migrator.dart` → **zero hits**. It now has 3 tests (`store_migrator_test.dart:131-173`) and still zero callers. Dead code with a test suite |
| **B1e / M25** `run()` can abort startup (documented "never throws") | ❌ | **✅ FIXED** | `store_migrator.dart:56-67` wraps `_run()` in try/catch. Analysed for self-throw: safe — §Repairs 3 |
| **B2** Silent wipe-then-overwrite of order history | ❌ | **❌ UNCHANGED — and now more reachable** | `orders_provider.dart:203-207` (catch → `_orders` stays empty) + `:163-173` (unconditional `setString` at `:167`). No backup, no quarantine call. §Blocker 2 shows how the round-2 `clearPatientScopedData` repair *widened* the adjacent demo-seed path |
| **B2b** Test certifies the loss | ❌ | **❌ UNCHANGED** | `test/providers/orders_persistence_test.dart:195` `expect(provider.orders, isEmpty)`; `:222` same; `:221` "This tests the actual behavior" |
| **B3** `logout()` calls `prefs.clear()` | ❌ | **⚠️ PARTIAL** | `auth_provider.dart:225-238` now iterates and preserves 2 keys. The schema stamp survives ✅. `__quarantine_v*` still destroyed ❌; `preferred_language` still destroyed, contradicting `session_scope.dart:40` ❌; **the preservation is untested and the one logout test asserts the OLD contract** — §Repairs 4 |
| **B4** Saved addresses → 3 fabricated demo addresses | ❌ | **❌ UNCHANGED** | `address_selection_screen.dart:119-121` `catch (_) { return List.from(_defaultAddresses); }`; defaults `:72-103`; `B-42, Sector 15, Noida 201301` at `:76-79` |
| **B5** No force-upgrade / minimum-version gate | ❌ | **❌ UNCHANGED** | `grep -rniE "force_?upgrade\|min_?supported\|remote_?config\|package_info\|426\|X-App-Version" lib pubspec.yaml` → **zero output** |
| **H6** Demo data served silently | ⚠️ | **✅ FIXED (for this checklist's purposes)** | `demo_mode.dart:21-60`: `DemoMode` is now a `Set<String>` of 11 named sources; `markServingLiveData(source)` may only clear its own. `sourcePatientIdentity` and `sourceArticles` now exist. The false all-clear is gone |
| **H7** 49 unguarded `DateTime.parse(json[…])` | ❌ | **❌ UNCHANGED at 49** | `grep -rn "DateTime.parse(" lib --include="*.dart" \| grep -E "json\[\|\['" \| wc -l` → **49** (51 total, 11 `tryParse`) |
| **H8** `as int?` on money throws | ❌ | **❌ UNCHANGED** | `billing_screen.dart:66, 73, 496`; `my_orders_screen.dart:234`; `models.dart:1155, 1496, 1497, 1499, 1500` |
| **H9** Lazy `.cast<Map<String,dynamic>>()` | ❌ | **❌ UNCHANGED** | `orders_provider.dart:183, 189` |
| **H10** Notification IDs from `String.hashCode` | ❌ | **❌ UNCHANGED** | `medication_reminder_service.dart:288, 292` |
| **H11** No archived installable, no tags | ❌ | **❌ UNCHANGED** | `git tag` → empty. No `releases/`. CI produces coverage only |
| **H14** Zero tests for `StoreMigrator` | ❌ | **⚠️ PARTIAL** | `test/services/store_migrator_test.dart` now exists, 10 tests. 7 cover `_run`'s branches; **3 cover a function no production code calls**; **0 cover the migration loop** — §Repairs 2 |
| **M12** `about_screen.dart:11` hardcodes `'1.0.0'` | ❌ | **❌ UNCHANGED** | `about_screen.dart:11` `static const _appVersion = '1.0.0'`, rendered at `:69` |
| **M17** `reminders_provider` all-or-nothing | ⚠️ | **⚠️ UNCHANGED** | `reminders_provider.dart:125-127` still `catch (_) { _items.clear(); }` |
| **M18/M19/M20/M21/M22/M23** billing unknown-status · `isQuotePending == 'pending'` · unbounded `daily_rating_*` · absolute photo path · no diagnostics · no release notes | ❌ | **❌ ALL UNCHANGED** | `billing_screen.dart:56-86`; `orders_provider.dart:27-28`; `my_care_screen.dart:588-594`; `app_provider.dart:106-107`; no diagnostics; `ls docs/ \| grep -i release` → empty |
| **M24** Stale six-tab / Calendar-at-index-3 doc lines | ❌ | **⚠️ PARTIAL** | `0f2729e` claimed to close this. Still present and present-tense: `docs/SCREEN_MAP.md:15` "**Calendar was added as a root tab at index 3**"; `docs/ARCHITECTURE.md:208` "Calendar added at index 3". (`docs/CHANGELOG.md:63-64` is arguably a historical entry and I do not grade it) |

**Net movement.** Four genuine fixes (B1a, B1b, B1e, H6) and one code-correct-but-untested fix (B1c). One
partial (B3). **Every one of blockers B2, B4, B5 is untouched**, as is the entire High tier except H6/H14.
Round 2's headline — "several round-1 fixes were surfaces" — does **not** repeat here for `StoreMigrator`:
the round-2 repair is real code, not a banner. The failure mode this round is different and quieter:
**the tests added alongside the repair pin the two easy defects and skip the dangerous one.**

---

## Round-2 repairs: adversarial review

### 1. The unconditional stamp at `_migrateFrom`'s end cannot mislabel — verified by trace ✅

The brief asks specifically: at a future `currentVersion = 3`, when step 1 fails, does `:134` stamp 1 or
fall through to 3?

Traced (`store_migrator.dart:103-135`), `stamped = 1`, `currentVersion = 3`:

1. `:105` `while (1 < 3)` → true. `:106` `step = _migrations[1]`, non-null.
2. `:112` `await step(prefs)` throws → `:113` catch.
3. `:123` `await prefs.setInt(_versionKey, 1)` — stamps the last **good** version.
4. `:124` **`return`** — exits the function.

The `return` at `:124` is what makes this correct. It exits *before* `:134`. **It stamps 1. It does not
fall through to 3.** ✅

**But the `return` is the only thing standing between correct and catastrophic, and nothing protects it.**
Change `return` (`:124`) to `break` — a one-character-class edit a future maintainer could make while
"tidying a loop" — and control reaches `:134`, which writes `currentVersion` (3), not `version` (1). That is
worse than the original defect: the original advanced one version per failed step; this would jump straight
from 1 to 3, skipping *two* migrations in one go. **No test would catch it** (§2).

**Second latent hazard in the same line.** `:134` writes `currentVersion`, not `version`. `_migrateFrom` has
no guard of its own against `from > currentVersion` — the entire downgrade protection lives in `_run`
(`:88-98`). Today `_migrateFrom` is called from exactly two sites (`:82` with a literal `1`, `:100` with a
`stamped` already proven `< currentVersion`), so it is unreachable. But a future caller — or a future
`_run` refactor — that reaches `_migrateFrom` with `from > currentVersion` gets a silent **downgrade of the
stamp**, which is precisely the "an older app must not claim data written by a newer one" property the
downgrade branch and its test (`store_migrator_test.dart:99-115`) exist to protect.

**Fix (cheap, both hazards):** write `version`, not `currentVersion`, at `:134`, and add
`if (from >= currentVersion) { await prefs.setInt(_versionKey, max(from, currentVersion)); return; }` as an
explicit early branch. Then `break` and `return` become equivalent and the function is safe in isolation.

### 2. The 10 new tests pin the two cheap defects and skip the dangerous one ⚠️

The brief asks two direct questions. Answers, with the trace:

**Q: Is there a test that would FAIL if the unconditional stamp were removed? — YES, three of them.**

`store_migrator_test.dart:43` (`housepital_orders: '[]'`), `:57` (`housepital_reminders: '[]'`), `:72`
(`theme_mode: 'dark'`). Each reaches `_run:73` (`stamped == null`) → `:74` `_hasAnyStoredData` true →
`:82` `_migrateFrom(prefs, 1)` → `:105` `while (1 < 1)` false → `:134`. Delete `:134` and all three
`expect(p.getInt(versionKey), StoreMigrator.currentVersion)` assertions fail. **Genuinely pinned.** ✅

**Q: Is there a test that would fail if the failed-step early-return were removed? — NO. Zero.**

`_migrations` is `static final Map<…>{}` — **empty** (`:50-51`) — and **private**. The only test seam on the
class is `versionKeyForTest` (`:172`). With `currentVersion == 1` (`:33`), the loop condition at `:105` is
false on every path in every one of the 10 tests. **The entire body `:106-129` is unexecuted by the suite** —
the `step == null` branch (`:107-109`), the `try` (`:111-112`), the `catch` (`:113-125`), the `version++`
(`:127`) and the in-loop stamp (`:128`).

Concretely, all ten tests still pass if you make **any** of these edits:
- delete the `return` at `:124`;
- delete the whole `catch` block `:113-125` (restoring the round-2 defect verbatim);
- change `:123` to `setInt(_versionKey, version + 1)`;
- delete the `version++` at `:127` (an infinite loop at v2 — a hung splash screen before `runApp`).

**So: the defect the round-2 report called "data loss with extra steps" is fixed in code and untested. The
file has tests; the fix does not.** This is the round-3 analogue of round 2's "surface" finding — not a fake
fix, but a fix whose protection expires the moment someone edits the file, which for a migration file is
*every single schema change forever*.

**Test-coverage arithmetic, which is its own finding.** Of 10 tests: 3 (`:131-173`) exercise `quarantine()`,
which has **zero production callers** (`grep -rn quarantine lib --include="*.dart" | grep -v store_migrator`
→ nothing). 30% of the new suite tests dead code; 0% tests the live failure path. The `quarantine` tests are
individually good — `:132` correctly asserts it **copies** rather than moves — but they are testing a
promise, not a behaviour.

**Fix:** add `@visibleForTesting static Map<int, …> get migrationsForTest => _migrations;` (or an
`overrideMigrationsForTest` seam) plus a `currentVersionForTest` override, then three tests:
`throwing step keeps the OLD stamp`, `throwing step at v1 of a 1→3 chain does not reach v3`, and
`a step that succeeds advances exactly one version`. Also cover the `double` arm of `quarantine`
(`:161-162`) — the "preserves non-string types" test (`:157`) covers int/bool/list only.

### 3. The try/catch in `run()` cannot itself throw ✅ — but the swallow is invisible in production

`store_migrator.dart:61-66`. `await _run()` inside `try` catches both synchronous and asynchronous throws.
The catch body is a single `Log.error` (`logger.dart:47-50` → `_log:52-70`), which does a `kReleaseMode`
check, string interpolation and `debugPrint`. The only theoretical escape is a thrown object whose
`toString()` itself throws; the realistic throw here is `TypeError` from `getInt`, whose `toString()` is
safe. **Verdict: the guard holds.** ✅

**But what the guard hides is a permanent dead end, and a test certifies it as acceptable.**

`prefs.getInt(key)` is `_preferenceCache[key] as int?`
(`shared_preferences-2.5.5/lib/src/shared_preferences_legacy.dart:121`) — a **non-int value at the version
key throws `TypeError`**. `store_migrator.dart:71` is therefore a real throw site. When it fires:

- `_run` aborts → `run()` catches → `Log.error` → app starts. Good.
- The stamp is never repaired. **Every subsequent launch throws at the same line.** The device is
  permanently unmigratable — it will silently skip every migration the app ever ships.
- `logger.dart:63-65` — Crashlytics forwarding is still a `TODO`, so in release this is a `debugPrint`
  nobody reads. **Nobody ever learns.**

`store_migrator_test.dart:118-129` is exactly this scenario (`versionKey: 'not-an-int'`) and asserts only
`expectLater(StoreMigrator.run(), completes)`. It certifies "doesn't crash" and stops there. It does not
assert that the store is left recoverable, which it is not.

**Fix:** read the stamp defensively — `final raw = prefs.get(_versionKey); final stamped = raw is int ? raw
: null;` — and when `raw != null && raw is! int`, `await quarantine(prefs, _versionKey, currentVersion)`
then fall into the pre-versioning path. That is ~4 lines, it gives `quarantine()` its **first production
caller**, and it converts a permanent dead end into a self-healing one.

### 4. `_hasAnyStoredData`'s version-key exclusion is correct — and unreachable ⚠️

`store_migrator.dart:139-144` skips `_versionKey` when deciding whether a device has data. Is that right?

The function has exactly one call site: `:74`, inside `if (stamped == null)`. `stamped` is `getInt(_versionKey)`
which, per the source above, returns `null` **only when the key is absent from `_preferenceCache`** (a present
non-int throws instead). So at `:74`, `_versionKey` is provably not in `prefs.getKeys()`, and the
`key != _versionKey` test at `:141` **can never be true**.

Not a bug — the exclusion is semantically right and costs nothing. But it is a tell: the author guarded the
case that cannot happen (a stamp present while `stamped == null`) and left unguarded the case that can (a
stamp present with the wrong *type*, §3). Worth one sentence of comment so a later reader does not conclude
the type case is handled because *something* about the stamp obviously was.

### 5. The downgrade branch still returns before any stamping ✅

`_run:88-98`: `stamped > currentVersion` → `Log.warn` (`:93-96`) → **`return`** (`:97`). No `setInt` executes
on this path, `_migrateFrom` is never entered, and the newer stamp survives byte-for-byte. Pinned by
`store_migrator_test.dart:100-115`, which asserts both the preserved stamp (`:111`) *and* the preserved data
(`:113`). ✅ Correct and tested. The `:134` hazard in §1 does not reach this path today — but see §1 for why
that safety is positional rather than structural.

### 6. `logout()` preserves the stamp — but the preservation is untested, and one omission is contradicted by the codebase's own rule ⚠️

`auth_provider.dart:216-241`. `prefs.clear()` is gone; the loop is `for (final key in prefs.getKeys().toList())
{ if (preserved.contains(key)) continue; await prefs.remove(key); }` with
`preserved = {'housepital_schema_version', 'housepital_pending_deletion'}` (`:231-234`).

**Can the iteration miss keys added during it? — Not by concurrent modification. Yes by timing.** ✅/⚠️

`SharedPreferences.getKeys()` is `Set<String>.from(_preferenceCache.keys)`
(`shared_preferences_legacy.dart:110`) — **already a defensive copy**, so `.toList()` is belt-and-braces and
`ConcurrentModificationError` is impossible. ✅

But the loop is not atomic: every `await prefs.remove(key)` yields, and `await _firebaseService.signOut()`
(`:219`) fires auth-state listeners *before* the snapshot is even taken. A key written after the snapshot
survives logout. In both real call sites this is currently benign — `SessionScope.clearSession` is awaited
**first** (`settings_screen.dart:460-461`; `delete_account_screen.dart:143-145`), and the only late writer is
`OrdersProvider.clearPatientScopedData` (`orders_provider.dart:212-219`), whose un-awaited
`_persistAndNotify()` (`:218`) writes `'[]'`. So the residue is an empty blob, not patient data. **Graded
⚠️-low, not ❌** — but nothing structural prevents a future provider from writing real data into that window,
and no test covers the ordering.

**Did anything else need preserving? Three things, checked against the 14-key persistence inventory:**

| Key | Preserved? | Verdict |
|---|---|---|
| `housepital_schema_version` | ✅ `:232` | Correct — this was the round-2 finding |
| `housepital_pending_deletion` | ✅ `:233` | Correct, and load-bearing: `delete_account_screen.dart:145` calls `logout()` immediately after writing it (`:60` defines the key) |
| **`__quarantine_v*`** | ❌ | **Round 2's complaint was that logout "defeats the recovery mechanism"; only half of it was fixed.** Quarantined bytes are, by the file's own contract (`store_migrator.dart:19-21`), how "a patient's order history is recoverable rather than gone". Logout destroys them — including the automatic `logout()` inside the *account-deletion* flow |
| **`preferred_language`** | ❌ | **Contradicts the codebase's own stated rule.** `session_scope.dart:40`: "State that belongs to the DEVICE or the ACCOUNT (theme, language, auth) must NOT be cleared here." `SessionScope` obeys it; `logout()` violates it two files away. A Hindi-preferring user logs out and gets an English login screen — the one moment they most need Hindi |
| `theme_mode` | ❌ | Same rule, lower stakes. Cosmetic reset on every logout |
| `notif_*` (9 keys) | ❌ | Missing key → per-key `defaultValue`, so a patient who switched **off** medication reminders has them switched back on by a logout. Low, but it is a clinical-adjacent toggle silently reverting |
| `has_onboarded` | ❌ | Correct to clear |

**Two more structural problems with the repair:**

- **The preserved names are hardcoded string literals.** `auth_provider.dart:232` duplicates
  `StoreMigrator._versionKey` (`store_migrator.dart:35`) with no compile-time link, even though
  `StoreMigrator.versionKeyForTest` (`:172`) exists and is public. `:233` duplicates
  `DeleteAccountScreen.pendingDeletionKey` (`delete_account_screen.dart:60`), which is a **public const that
  could simply have been referenced**. Rename either private constant and logout silently resumes wiping the
  stamp, with no analyzer error and no test failure.

- **The preservation has zero test coverage, and the one logout test asserts the OLD contract.**
  `test/providers/auth_provider_test.dart:279-304`: the fixture (`:281-285`) is
  `{has_onboarded, preferred_language, some_other_pref}` — **neither preserved key is present** — and the
  assertion at `:302` is `expect(prefs.getKeys(), isEmpty)`. Restore `await prefs.clear()` in place of the
  loop and **this test still passes.** Worse than untested: `getKeys() isEmpty` actively encodes the
  pre-repair contract, so a maintainer who later adds the stamp to the fixture will see the test break and be
  nudged toward deleting the *preservation* rather than the *assertion*.
  **Fix:** seed `{versionKey: 1, 'housepital_pending_deletion': '…', '__quarantine_v1_housepital_orders': '…',
  'housepital_orders': '…'}` and assert `getKeys()` equals exactly the preserved set.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A | BLOCKED-OWNER |
|---|---|---|---|---|---|
| 1. Local store migration | 2 | 1 | 3 | 0 | 0 |
| 2. Server schema lockstep | 0 | 2 | 2 | 0 | 0 |
| 3. Cross-version coexistence | 0 | 3 | 2 | 0 | 0 |
| 4. The upgrade QA protocol | 0 | 2 | 2 | 1 | 1 |
| 5. Build & versioning hygiene | 0 | 3 | 1 | 0 | 0 |
| **Total (25)** | **2** | **11** | **10** | **1** | **1** |

Round 1: 0 / 10 / 12 / 2 / 1. Round 2: 0 / 11 / 12 / 1 / 1. **Round 3: 2 / 11 / 10 / 1 / 1.**
The first two ✅ of this checklist's history, both in §1, both earned by the `StoreMigrator` repair.

---

## Findings

### 1. Local store migration — 2✅ / 1⚠️ / 3❌

#### ✅ The persistent store opens under an explicitly VERSIONED schema with a migration plan.

Upgraded from ⚠️. All three round-2 defects are fixed in code and the ordering still holds:
`main.dart:175` `await StoreMigrator.run();` sits between `ErrorWidget.builder` (`:140`) and
`runApp(MultiProvider(…))` (`:192-193`); every storage-reading provider is constructed inside that block, so
none can run before the `await` completes. `currentVersion` is a frozen `const int` (`:33`) — the checklist's
"a version guard that compares a value to itself" red flag remains avoided.
**Residual risks, all listed above:** the corrupt-stamp dead end (§Repairs 3), the positional-not-structural
safety of `:134` (§Repairs 1), and `quarantine()`'s continued zero callers (§Repairs 2).

#### ✅ Historical schema versions are FROZEN literals — never computed from the live model list.

Upgraded from ❌. The wrong frozen list is gone (`store_migrator.dart:37-43` is now a tombstone comment
explaining *why*, which is the right artifact to leave behind). `_hasAnyStoredData` (`:139-144`) reads
`prefs.getKeys()`, which is neither a curated list nor the model list — it cannot go stale and cannot
self-reference. `currentVersion` remains a literal.
**One caveat on the test that pins it:** `store_migrator_test.dart:57-70` proves the *one* key the old list
missed is now detected. It does not prove the *property*. A regression to a curated list that happened to
include `housepital_reminders` would still pass. A table-driven test over every persisted key literal in
`lib/` would pin the property; this pins an instance.

#### ⚠️ Additive + defaulted changes are verified to lightweight-migrate; anything else has a written migration stage BEFORE the change merges.

Upgraded from ❌ — verification now exists, but not of migration. `test/services/store_migrator_test.dart`
covers seven branch cases around the loop and zero cases inside it (§Repairs 2). There is still no golden
fixture: no test loads a frozen v1 blob and asserts an entity count survives. Since `_migrations` is empty,
"verified to lightweight-migrate" has nothing to verify yet — but the *harness* to verify the first one does
not exist either, and the private `_migrations` map means it cannot be built without editing the production
file. Build the seam now, while the cost is a getter.

#### ❌ A release build with a missing migration fails LOUDLY. The wipe-and-recreate fallback is compile-gated to debug builds only.

**Unchanged.** Six silent paths, and `quarantine()` — the function written to solve exactly this — still has
zero production callers:

1. `orders_provider.dart:203-206` — decode failure → `Log.warn` → `_orders` stays empty → the next
   `_persistAndNotify()` (`:163-173`) unconditionally `setString`s over the old blob at `:167`. No backup,
   no `assert`, no quarantine.
2. `address_selection_screen.dart:119-121` — `catch (_) { return List.from(_defaultAddresses); }`.
3. `reminders_provider.dart:125-127` — `catch (_) { _items.clear(); }`.
4. `cart_provider.dart:254-256` — "Ignore corrupt data — start fresh".
5. `store_migrator.dart:71` — a non-int stamp throws, is swallowed by `run()`, and the device is silently
   unmigratable forever (§Repairs 3). **New this round** — this replaces round 2's item 5 (the advancing
   version), which is fixed.
6. The compound demo-orders path — see Blocker 2, which got *more* reachable this round.

No `assert(false, …)` anywhere on these paths, and `logger.dart:63-65` still carries the
`TODO(observability): forward warn/error to FirebaseCrashlytics.recordError`. In release, every one of the
six is a `debugPrint` into the void.

#### ❌ A migration test opens a store snapshot from the OLDEST supported release and asserts row counts per entity survive.

**Unchanged.** `test/providers/orders_persistence_test.dart:185-223` tests *corrupt* JSON
(`'this is not valid json {{{'`, `:188`) — a different thing from *older-shape* JSON — and `:195` and `:222`
both `expect(provider.orders, isEmpty)`, certifying the loss. `:221` documents the certification:
"This tests the actual behavior."

#### ❌ Aged-data snapshot exists.

**Unchanged.** No persisted-store fixture anywhere; `test/_mocks/` holds service fakes only. The three-line
fixtures in `store_migrator_test.dart` (`'[]'`, `'[{"id":"x"}]'`) are branch fixtures, not aged data — which
is precisely the checklist's "three fixture rows" red flag.

### 2. Server schema lockstep — 0✅ / 2⚠️ / 2❌

#### ⚠️ Production schema deployed BEFORE the build that needs it, with a date and an owner. — Unchanged.

`docs/DEPLOYMENT_GUIDE.md` post-deployment checklist and `docs/DATABASE_SCHEMA.md` migration history both
exist; neither states an ordering constraint, a date or a named owner. **New context from the brief:** two
real backends exist (`housepital-backend` Firebase+MySQL for patients, `housepital-api` Laravel for staff)
with incompatible schemas for the same six nouns, and the app points at neither. That makes the missing
ordering line *more* urgent, not less: the first pointing-at-a-backend release is the first one where an app
build and a server schema must be sequenced, and there is no line to sequence them on.

#### ❌ New FIELDS on existing types re-arm the deploy gate. — Unchanged. There is no deploy gate.

#### ❌ The app tolerates the server knowing LESS: writes queue and surface honestly. — Unchanged.

No write queue. `app_provider.dart` `addPatient` is still an in-memory append with `// TODO(persistence)`;
manual vitals are memory-only; `medication_provider` add/update/delete have no offline path.

#### ⚠️ The app tolerates the server knowing MORE: unknown fields/types ignored gracefully, never fatal.

*The demo-honesty half improved genuinely; the parse half did not move.*

- **`DemoMode` is correctly rebuilt.** `demo_mode.dart:21-60`: a `Set<String>` of 11 named sources;
  `markServingLiveData(source)` removes only its own tag (`:52-54`); `activeSources` (`:43`) is an
  unmodifiable diagnostic view. Round 2's false all-clear is structurally impossible now, and the two
  silent fallbacks it named have tags (`sourcePatientIdentity`, `sourceArticles`, `:25, :30`). This is a
  real repair, not a surface. ✅ on this sub-point.
- **49 unguarded `DateTime.parse(json[…])` — no movement.** Worst for clinical models:
  `medication_models.dart:154`, `my_care_models.dart:87, 248, 358`, `models.dart:642, 701, 739-747, 867,
  1273, 1345-1346`, `equipment_order.dart:37`, `payment_reminder_service.dart:114`. A renamed or dropped
  required date field is fatal per call, absorbed by a `DemoData` fallback — which now at least *announces*
  itself. Announced-fabricated is better than silent-fabricated; it is not correct.

### 3. Cross-version coexistence — 0✅ / 3⚠️ / 2❌ — all unchanged

- ⚠️ **Enum fallbacks.** `reminders_provider.dart:66` handles the one true Dart enum correctly. String
  "enums" degrade via `default:` arms, but no test asserts any fallback, and `billing_screen.dart:56-86` has
  no unknown-status bucket — a v2 status makes an order vanish from **both** money columns. A wrong number,
  not a missing one.
- ⚠️ **`isQuotePending`** (`orders_provider.dart:27-28`) is still strict `== 'pending'`. A v2 `'revised'` or
  `'expired'` reads as not-quote-pending, so v1 renders ₹0 — which `CLAUDE.md` explicitly forbids for
  price-less items.
- ⚠️ **`as int?` on money and lazy `.cast()`.** `billing_screen.dart:66, 73, 496`;
  `my_orders_screen.dart:234`; `models.dart:1155, 1496, 1497, 1499, 1500` throw on a widened number (GST
  decimals). `orders_provider.dart:183, 189` `.cast<Map<String, dynamic>>()` is lazy — a non-map element
  throws at *access*, on the Billing tab, **outside** the `try/catch` at `:177-207`. The correct patterns
  already exist in the same repo (`orders_provider.dart:131` `as num?`; `reminders_provider.dart:117`
  `whereType`).
- ❌ **No `docs/RELEASE_NOTES.md`.** `ls docs/ | grep -i release` → empty. The app is explicitly multi-user
  (patient-self / primary contact / family / caretaker), so the lagging-household case is real.
- ❌ **No version-skew QA pass** — impossible; no previous release exists (§4.1).

### 4. The upgrade QA protocol — 0✅ / 2⚠️ / 2❌ / 1 N/A / 1 BLOCKED-OWNER

- ❌ **No installable archive of the previous release.** `git tag` → **empty**. No `releases/`. CI produces a
  coverage artifact only. Named red flag on the checklist, currently true.
- N/A **Upgrade matrix** — nothing to upgrade from. Mandatory at v1.0.1.
- ❌ **No before/after entity-count checksum.** No debug screen, no export, no count logging. Note the
  irony this round: `StoreMigrator` now writes a stamp that *nothing can display*.
- ⚠️ **Files outside the database survive.** *Improved.* The schema stamp and the pending-deletion record now
  survive logout (`auth_provider.dart:225-238`). **Still gone on logout:** `__quarantine_v*` (the recovery
  mechanism), `preferred_language` and `theme_mode` (device state, which `session_scope.dart:40` explicitly
  says must not be cleared), and the nine `notif_*` toggles. Unchanged elsewhere: profile photo is still an
  absolute `image_picker` temp path (`app_provider.dart:106-107`), guarded at read so it degrades to
  no-photo; notification IDs are still `medicationId.hashCode.abs() * 10 + slotIndex`
  (`medication_reminder_service.dart:288, 292`) — Dart does not guarantee `String.hashCode` stability across
  SDK versions, so a future Flutter leaves **orphaned, uncancellable medication reminders firing for a
  medication the patient has stopped taking.**
- ⚠️ **First launch after update is timed; >2s shows progress UI.** Unchanged and slightly sharpened by the
  new code. `StoreMigrator.run()` is awaited at `main.dart:175`, **before `runApp`** (`:192`) — at that
  moment there is no Flutter UI, only the OS launch image, and on iOS a long-enough migration is watchdog-
  killed. Cost is zero today (`_migrations` empty), so this is a design risk. **But note §Repairs 2:** delete
  the `version++` at `:127` and you get an infinite loop *in this exact pre-`runApp` slot* — a hung launch
  image with no crash report — and no test would catch it.
- **BLOCKED-OWNER — update tested via the same channel users get.** Unverifiable from the repo.
  **What I need:** App Store Connect / Play Console visibility showing a prior build, or the owner's written
  confirmation that a TestFlight build was distributed and then updated over **in place** (not
  cable-installed). `CLAUDE.md` documents the cable-install path and its `0xe8008014` hazard and says nothing
  about in-place update testing.

### 5. Build & versioning hygiene — 0✅ / 3⚠️ / 1❌ — all unchanged

- ⚠️ `pubspec.yaml:4` `version: 1.0.0+1` is correctly the single source for both platforms (iOS
  `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)`, Android `flutter.versionName`/`flutter.versionCode`).
  **But** `about_screen.dart:11` `static const _appVersion = '1.0.0'` is a hardcoded second source rendered
  to the user at `:69`, and no test asserts agreement.
- ⚠️ Generated files indirect through Flutter build variables (mechanism correct); nothing verifies the built
  artifact, because CI never produces one.
- ❌ Build number increments on every upload — no automation, and **no git tags at all**, so even a manual
  "greater than the last tag" check has no baseline.
- ⚠️ Changelog mixes user-visible and internal entries and flags nothing as household-wide.
  **`0f2729e` claimed to close the doc drift; two present-tense lines survive:** `docs/SCREEN_MAP.md:15`
  ("**Calendar was added as a root tab at index 3**") and `docs/ARCHITECTURE.md:208` ("Calendar added at
  index 3"), both contradicting the five-tab nav that `test/screens/main_shell_test.dart` asserts and that
  `CLAUDE.md` documents. A doc set that misdescribes the shipped navigation *after a commit dedicated to
  fixing exactly that* cannot be trusted to describe a store-format change — the checklist's "release notes
  that say 'bug fixes' over a store-format change" red flag, still in embryo.

---

## Blockers (must fix before v1 reaches a real patient)

1. **The failed-step fix is untested and one keyword away from reversing.** `store_migrator.dart:124` — the
   `return` is the entire protection; `:134` writes `currentVersion` behind it. `_migrations` is empty and
   private, `currentVersion == 1`, so `:105-129` never executes in the suite: delete the `return`, delete the
   `catch`, or delete the `version++`, and **all 1,813 tests still pass**. For a file whose whole purpose is
   to be edited at every future schema change, an unprotected invariant is a scheduled regression.
2. **Silent wipe-then-overwrite of order/invoice history — and the round-2 repair made the demo-seed path
   reachable on every logout.** `orders_provider.dart:203-206` + `:167`, certified by
   `orders_persistence_test.dart:195, 222`. The compound path is now *more* likely, not less:
   `clearPatientScopedData` (`:212-219`) correctly persists `'[]'` (round 2's fix — an in-memory-only clear
   used to let a cold start restore the previous patient's history). But `'[]'` loads as an **empty** list at
   `:180-184`, which falls into `if (_orders.isEmpty)` at `:197` and re-seeds `DemoData.orders` — and the
   first real checkout after that calls `addOrder` (`:60-76`) → `_persistAndNotify()` → `jsonEncode(_orders)`
   (`:167`), **writing the fabricated demo history to disk as the patient's own.** Before the repair, the
   stale blob was non-empty and the seed branch was skipped. The repair is correct for patient isolation and
   it routed the state straight into a pre-existing landmine. **Fix:** hold the seed in a separate
   `_demoOrders` field the getter concatenates and the persister never sees.
3. **`logout()` still destroys the quarantine keys, and the preservation is untested.**
   `auth_provider.dart:231-234` preserves 2 keys and not `__quarantine_v*`; `preferred_language` is wiped in
   direct contradiction of `session_scope.dart:40`. `auth_provider_test.dart:302`
   `expect(prefs.getKeys(), isEmpty)` passes identically with `prefs.clear()` restored.
4. **Saved addresses silently replaced by three fabricated demo addresses.**
   `address_selection_screen.dart:119-121`; defaults `:72-103`. This is the address a nurse or an oxygen
   concentrator is dispatched to.
5. **No force-upgrade / minimum-version gate.** Verified absent a third time: zero hits across `lib/` and
   `pubspec.yaml`. A known-bad build showing wrong dosages cannot be stopped.
6. **A corrupt version stamp is a permanent, invisible dead end.** `store_migrator.dart:71` +
   `logger.dart:63-65`. ~4 lines to make self-healing, and it would give `quarantine()` its first caller.

## High

7. **49 unguarded `DateTime.parse(json[…])`** — flat vs round 2.
8. **`as int?` on money throws instead of defaulting** — `billing_screen.dart:66, 73, 496`;
   `my_orders_screen.dart:234`; `models.dart:1155, 1496, 1497, 1499, 1500`.
9. **Lazy `.cast<Map<String,dynamic>>()`** — `orders_provider.dart:183, 189`; uncatchable Billing-tab crash.
10. **Notification IDs from `String.hashCode`** — `medication_reminder_service.dart:288, 292`.
11. **No archived installable and no git tags.** Named red flag.
12. **`quarantine()` still has zero production callers** — and now has 3 of the 10 new tests.
13. **The `StoreMigrator` class has no test seam for `_migrations` or `currentVersion`**, so nothing inside
    the migration loop is testable without editing the production file.

## Medium / Low

14. `about_screen.dart:11` hardcodes `'1.0.0'` — second source of truth, rendered to the user.
15. No build-number automation and no baseline tag.
16. `reminders_provider.dart:125-127` still clears the whole list when a `fromJson` throws.
17. `billing_screen.dart:56-86` has no unknown-status bucket.
18. `isQuotePending` (`orders_provider.dart:27-28`) is strict `== 'pending'`.
19. `daily_rating_YYYY-MM-DD` grows unbounded (`my_care_screen.dart:588-594`). Prune to 90 days.
20. `profile_photo_path` stores an absolute `image_picker` temp path (`app_provider.dart:106-107`).
21. No before/after entity-count diagnostics — and now a stamp that nothing can display.
22. No `docs/RELEASE_NOTES.md`.
23. Stale present-tense nav claims survive `0f2729e`: `docs/SCREEN_MAP.md:15`, `docs/ARCHITECTURE.md:208`.
24. `logout()` preserved-key literals duplicate `StoreMigrator._versionKey` and
    `DeleteAccountScreen.pendingDeletionKey` with no compile-time link (`auth_provider.dart:232-233`).
25. `_hasAnyStoredData`'s `key != _versionKey` guard (`store_migrator.dart:141`) is unreachable at its only
    call site — harmless, but it guards the impossible case while the possible one (§Repairs 3) is unguarded.
26. `quarantine()`'s `double` branch (`store_migrator.dart:161-162`) is uncovered.
27. `logout()`'s removal loop is non-atomic across `await` points (`auth_provider.dart:236-238`); benign
    today only because `SessionScope.clearSession` is awaited first at both call sites.

## BLOCKED-OWNER

- **§4.6** — update tested via the same channel users get. Needs App Store Connect / Play Console visibility
  of a prior build, or the owner's written confirmation of a TestFlight build distributed and then updated
  **in place**.
- **§2.1 (partial)** — whether a production MySQL migration has been applied ahead of any app build. Now
  ambiguous in a new way: the brief names *two* real backends with incompatible schemas for the same six
  nouns, and the app points at neither. **What I need:** which backend v1 will point at, and its deployed
  migration state on the day of submission.

---

## Updated minimal pre-launch list

Ordered by cost-to-fix-later. Items 1–4 are new or re-shaped this round; the rest carry forward.

1. **Pin the failed-step behaviour with a test.** Add a `@visibleForTesting` seam for `_migrations` (and a
   `currentVersion` override) to `store_migrator.dart`, then three tests: a throwing step keeps the OLD
   stamp; a throwing step at v1 of a 1→3 chain does not reach v3; a succeeding step advances exactly one.
   *Without this the round-2 repair is protected by nothing but the author's memory.*
2. **Harden `_migrateFrom` against its own callers.** Write `version`, not `currentVersion`, at `:134`, and
   add an explicit `from >= currentVersion` early branch, so `break` and `return` become equivalent.
3. **Make a corrupt stamp self-healing.** Read via `prefs.get()` + `is int` at `store_migrator.dart:71`;
   on a wrong type, `quarantine()` the stamp and fall into the pre-versioning path. Gives `quarantine()` its
   first production caller.
4. **Fix the logout repair properly.** Preserve `__quarantine_v*` (prefix match) and `preferred_language` /
   `theme_mode` per `session_scope.dart:40`; reference `StoreMigrator.versionKeyForTest` and
   `DeleteAccountScreen.pendingDeletionKey` instead of re-typing the literals; and rewrite
   `auth_provider_test.dart:279-304` so the fixture contains the preserved keys and the assertion is
   `getKeys() == preserved`.
5. **Keep the demo order seed out of the persisted list.** `orders_provider.dart:197-200` + `:167` — a
   separate `_demoOrders` field the persister never sees. Newly urgent: every logout now routes through the
   empty-load branch that seeds it.
6. **Call `quarantine()` from the destructive load paths** — `orders_provider.dart:203`,
   `address_selection_screen.dart:119`, `reminders_provider.dart:125`, `cart_provider.dart:254` — plus
   `assert(false, …)` for debug loudness and the Crashlytics forward that `logger.dart:63-65` still TODOs.
7. **Stop fabricating a delivery address.** `address_selection_screen.dart:119-121` → empty list plus
   "we couldn't read your saved addresses". Never silently dispatch a nurse to `B-42, Sector 15, Noida`.
8. **Change `orders_persistence_test.dart:195, 222`** from asserting emptiness to asserting the quarantine
   key exists and holds the original bytes.
9. **Freeze `test/fixtures/store_v1_aged.json`** — 40+ orders over 8 months, 60 reminders, 3 real addresses,
   a full cart — with a counts-survive test. Costs nothing now; cannot be recreated after v1 ships.
10. **Widen the money casts** to `as num?` (`billing_screen.dart:66, 73, 496`, `my_orders_screen.dart:234`,
    `models.dart:1155, 1496, 1497, 1499, 1500`) and make `orders_provider.dart:183, 189` eager `whereType`.
11. **Loosen `isQuotePending`** to `!= null && != 'confirmed'` and add an unknown-status bucket in
    `billing_screen.dart:56-86`.
12. **Add the force-upgrade gate.** `package_info_plus` + `firebase_remote_config`
    (`{"min_supported_build": 1}`) checked on the splash with **SOS still reachable**, plus `X-App-Version`
    from `api_service.dart` and HTTP 426 handling. Do both — Remote Config works when the API is down.
13. **`git tag v1.0.0+1`, archive the IPA + AAB** at submission, and add a CI build-number check.
14. **Read the version at runtime in About** (`about_screen.dart:11`) with a pubspec-agreement test.
15. **Add the hidden entity-count diagnostics row** (long-press the version string), printing the schema
    stamp, per-entity counts and any `__quarantine_v*` keys. Without it no future upgrade can be checked.
16. **Persist an explicit `medId → notificationId` map** (`medication_reminder_service.dart:288, 292`).
17. **Start `docs/RELEASE_NOTES.md`**, and correct `docs/SCREEN_MAP.md:15` and `docs/ARCHITECTURE.md:208`.

---

## Executive summary

1. **Round-3 counts: 2 ✅ / 11 ⚠️ / 10 ❌ / 1 N/A / 1 BLOCKED-OWNER** (round 2: 0 / 11 / 12 / 1 / 1). The
   first two ✅ in this checklist's three-round history, both earned by the `StoreMigrator` repair.
2. **Genuinely fixed, verified by reading:** the `while (1 < 1)` dead loop (unconditional stamp at
   `store_migrator.dart:134`, pinned by three tests that fail without it); the wrong frozen `_v1Keys` list
   (deleted, replaced by `prefs.getKeys()`); `run()`'s missing try/catch (`:61-66`, cannot itself throw); and
   — outside §1 — `DemoMode`'s false all-clear, now structurally impossible as a tagged `Set`.
3. **The failed-step fix is correct.** Traced at a hypothetical `currentVersion = 3`: step 1 throws → `:123`
   stamps **1** → `:124` **returns** before `:134`. It does not fall through to 3.
4. **But that fix is protected by a single `return` and zero tests.** `_migrations` is empty and private and
   `currentVersion == 1`, so `store_migrator.dart:105-129` never executes in any of the 10 new tests. Delete
   the `return`, the whole `catch`, or the `version++`, and all 1,813 tests still pass. **The most dangerous
   of the three round-2 defects is the one the new suite does not cover.**
5. **Is any round-2 repair itself a surface? No — but two are unprotected.** `StoreMigrator` and `DemoMode`
   are real code changes, not banners; round 2's pattern does not repeat. The new pattern is quieter: repairs
   whose tests pin the easy half. Both `logout()`'s key preservation and the migration loop have working code
   and no test — and `auth_provider_test.dart:302` `expect(prefs.getKeys(), isEmpty)` passes unchanged if
   `prefs.clear()` is restored, so it actively certifies the old contract.
6. **One repair made a pre-existing blocker MORE reachable.** `OrdersProvider.clearPatientScopedData` now
   correctly persists `'[]'` — which loads empty, hits `if (_orders.isEmpty)` at `orders_provider.dart:197`,
   re-seeds `DemoData.orders`, and lets the first real checkout persist the fabricated history as the
   patient's own. Right fix for patient isolation, straight into an old landmine.
7. **Nothing else in the blocker list moved.** The orders wipe-then-overwrite and the test that certifies it,
   the fabricated demo addresses, the absent force-upgrade gate, the 49 unguarded `DateTime.parse` sites
   (49 at round 2, 49 now), the `as int?` money casts, the lazy `.cast()`, the `hashCode` notification IDs,
   the empty `git tag` — all verified unchanged this round.
8. **`quarantine()` went from dead code to dead code with tests.** Zero production callers; 3 of the 10 new
   tests exercise it. Meanwhile the live failure path has none. That inversion is the single clearest signal
   of where this repair's attention went.
9. **Top 5 remaining:** (1) test the failed-step path and add a `_migrations` seam; (2) keep the demo order
   seed off disk and stop the wipe-then-overwrite; (3) finish `logout()` — quarantine keys, language, and a
   test that would fail if the preservation were removed; (4) stop fabricating delivery addresses; (5) ship
   a force-upgrade gate.
10. **Verdict: FAIL, but the first non-trivial pass in three rounds.** §1 is genuinely repaired at the code
    level and now carries the checklist's first two ✅. It cannot pass overall while the store's own
    destructive load paths still delete data silently, a test still certifies that deletion, and the one
    correct-but-uncovered branch sits in a file guaranteed to be edited at every future schema change.
