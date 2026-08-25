# Software Testing & Code Quality Checklist (App-Agnostic) — Audit **round 3** vs commit `9a80fe2`

**Date:** 2026-08-03 · **Round 2:** `820060b` · **Round 1:** `803124d` · **Branch:** `fix/five-tab-nav`
**Checklist:** `Testing Checklist - App Agnostic.txt` (sections 1–9)
**Method:** static read of the full test tree + `git diff 820060b..9a80fe2` + `grep`/`rg` +
brace-matching scripts over `test/**/*_test.dart`, plus reading `shared_preferences-2.5.5`
source to decide whether one new test exercises the path it claims. Per the brief I did **not**
run `flutter test`, `flutter build` or `flutter analyze`. Every verdict cites `file:LINE`.

---

## What changed in `test/` since round 2

```
 test/providers/patient_scope_isolation_test.dart | 121 ++++++++++++++++
 test/screens/main_shell_test.dart                |  62 +++++---
 test/screens/services/staff_role_sheet_test.dart |  10 +-
 test/services/store_migrator_test.dart           | 174 +++++++++++++++++++++++  (new)
 4 files changed, 346 insertions(+), 21 deletions(-)
```

Against 24 changed production files / 815 insertions in `lib/`. The asymmetry narrowed from
round 2 (772 prod LOC ↔ 8 tests) but did not close: **five production files that round 2 named
by name still have zero tests, and two of them got bigger and more dangerous this round.**

Suite metrics, re-measured:

| Metric | R1 | R2 | **R3** |
|---|---:|---:|---:|
| Test files | 99 | 100 | **101** |
| `test(` + `testWidgets(` call sites | 1,372 | 1,380 | **1,396** |
| `testWidgets` | 215 | 215 | **216** |
| Test LOC | 23,530 | 24,093 | **24,418** |
| `lib/` LOC | 54,295 | 55,067 | **55,591** |

---

## Round-2 findings: status now

| # | Round-2 finding | R2 | **Now** | Evidence |
|---|---|---|---|---|
| B1 | `StoreMigrator` never executed; 2 defects | ❌ | **⚠️ partial** | `test/services/store_migrator_test.dart` (10 tests). Defects 1 & 3 fixed *and* guarded; **Defect 2's repair is untested and untestable** — §R3-1 |
| B2 | Order history persistence not patient-scoped | ❌ | **❌ regressed in kind** | `orders_provider.dart:11-12` keys still global; `:212-219` now writes `[]` to disk, so the leak became **unconditional permanent data loss** — and `patient_scope_isolation_test.dart:273` *pins it as the contract*. §R3-3 |
| B3 | The PHI fix's wiring (`SessionScope`) is untested | ❌ | **❌ unchanged — and now 3 call sites** | `grep -rn "SessionScope" test/` → **one hit, a comment** (`patient_scope_isolation_test.dart:12`). `grep -rn "^import.*session_scope" test/` → **0**. Call sites `home_screen.dart:1774`, `settings_screen.dart:460`, `delete_account_screen.dart:143` |
| B4 | `_priceMultiplier` untested | ❌ | **❌ unchanged** | `grep -rn "ultiplier" test` → 1 unrelated hit (`billing_screen_test.dart:341`) |
| B5 | 17 payment tests skipped on bare `flutter test` | ❌ | **❌ unchanged** | 8 `skip: _skipReason` groups; scripted count = **17 tests**. No `dart_test.yaml`, no `tool/test.sh` |
| B6 | Token refresh untestable | ❌ | **❌ unchanged** | `auth_provider.dart:93` still `FirebaseAuth.instance.currentUser` |
| H7 | `payment_service_test.dart:649` over-loosened | ⚠️ | **❌ unchanged** | `git diff 820060b..9a80fe2 -- test/services/payment_service_test.dart` → **empty**. `:649` still `expect(successCalled \|\| failure != null, isTrue)`; still the 30 ms sleep at `:643`; still named "even when channel will fail" while `:620-621` says the channel does not fail |
| H8 | `switchPatient` test cannot fail for its stated reason | ⚠️ | **❌ unchanged, and now inexcusable** | `patient_scope_isolation_test.dart:121-141` byte-identical in substance. The file now *contains* the per-patient fake (`_SwitchingApi`, `:64-78`) that round 2 said would make it assertable — and it was pointed at `loadPatients` instead. Delete `app_provider.dart:175` and all three assertions still pass |
| H9 | `delete_account_screen.dart` destructive, 0 tests | ❌ | **❌ worse** | Still 0 tests (`grep -rn "DeleteAccount" test/` → one unrelated permission string). Screen grew 222 lines and now calls `FirebaseUser.delete()` (`:131`) — §R3-5 |
| H10 | `payment_service.dart:171` unreachable dead branch | ❌ | **❌ unchanged** | still `if (isDemoPayments) _onSuccessCallback?.call();` |
| H11 | `DemoMode` globally imprecise; banner unrendered by any test | ❌ | **⚠️ code fixed, tests not** | `demo_mode.dart` is now a per-source `Set` (`:36-54`) — the right fix. **Zero tests exercise the set semantics**; `demo_data_banner.dart` (136 LOC, new) is rendered by no test. §R3-4 |
| H12 | 120 tests execute zero production code | ❌ | **❌ unchanged, exactly 120** | 26+20+18+17+17+12+10; re-counted per file below |
| H13 | Orphan code, no security tests, no rules harness | ❌ | **❌ unchanged** | all 6 orphans still have 0 importers in `lib/`; `firestore.rules`/`storage.rules`/`functions/index.js` still have no harness |
| M14 | 94/215 widget tests inert | ⚠️ | **⚠️ 93/216 (43%)** | `my_care_widgets_test.dart` still 28 |
| M15 | 3 assertion-free tests | ⚠️ | **⚠️ unchanged** | `notification_router_test.dart:91,97`; `payment_service_test.dart:282` |
| M16 | Docs assert six tabs | ❌ | **✅ fixed** | `0f2729e` |
| M17 | `TEST_MAP.md`/`TEST_STRATEGY.md` not updated for new files | ❌ | **❌ unchanged** | `grep -c "store_migrator\|patient_scope_isolation\|session_scope\|demo_mode\|delete_account" docs/TEST_MAP.md docs/TEST_STRATEGY.md` → **0 and 0**. A whole new test file exists and the test inventory does not know it |
| M18 | 20 ms sleep as a sync primitive | ⚠️ | **❌ worse — now four** | `patient_scope_isolation_test.dart:197, 253, 266, 270` |
| M19 | `DemoMode` global-state leakage between test files | ⚠️ | **⚠️ unchanged** | only `patient_scope_isolation_test.dart:213` resets it |
| M20 | `settings_screen.dart` fires clear + logout unawaited | ⚠️ | **✅ fixed** | `settings_screen.dart:460` now `await SessionScope.clearSession(context)`; `delete_account_screen.dart:143-145` awaits both in order |
| M21 | `_isSubmitting` never reset | ⚠️ | **✅ fixed** | `delete_account_screen.dart:109` resets on the failure path |
| — | Five-tab nav contract | ✅ | **✅ still guarded, differently** | `main_shell_test.dart` rewritten for the pill — §R3-2 |

**Regressions:** one real (B2 — the orders repair converted a restart-survivable leak into
unconditional on-disk destruction, and a *test now asserts the destruction*), one procedural
(M18, sleeps tripled).

---

## Round-2 repairs: adversarial review

### R3-1. `test/services/store_migrator_test.dart` — 10 tests against my 13 cases

The production repairs are real. `_migrateFrom` now always stamps (`:130-134`, killing the
`while (1 < 1)` hole), a failed step stamps the **last good** version and returns (`:113-125`),
`_v1Keys` is gone in favour of `prefs.getKeys()` (`:139-144`), and `run()` wraps `_run()` in
try/catch (`:56-67`). Reading the code, all three of round 2's defects are genuinely closed.

The **test file** is a different question. Case-by-case against §8-P's table:

| # | R2 case | Present? | Verdict |
|---|---|---|---|
| 1 | Fresh install: stamp, and *only* the stamp | ✅ `:30-39` | **✅ real.** `expect(p.getKeys(), {versionKey})` is a strong "wrote nothing else" assertion. Idempotence is covered separately (`:72-81`) |
| 2 | Pre-versioning install with data is stamped | ✅ `:43-55` | **⚠️ falsifiable but branch-blind** — see below |
| 3 | Detection is not a curated key list | ✅ `:57-70` | **❌ inert. Cannot fail.** See below |
| 4 | Already current performs **zero writes** | ⚠️ `:85-96` | **⚠️ cannot fail.** Asserts stamp + data unchanged, not write count. Delete the `if (stamped == currentVersion) return;` early-out at `store_migrator.dart:86` and control falls to `_migrateFrom(prefs, 1)` → `while(1<1)` → `setInt(1)` → identical observable state → **test still green.** R2 asked for a spy or a full before/after map for exactly this reason |
| 5 | Downgrade preserves the newer stamp | ✅ `:100-115` | **✅ real and falsifiable.** Remove `store_migrator.dart:88-98` and `_migrateFrom(prefs, 6)` runs `while(6<1)` → falls to `:134` → stamps **1**, clobbering a v6 store. The test fails. Best test in the file |
| 6 | Steps run once, in order | ❌ | **missing and unreachable** — `_migrations` (`:50`) is still `private static final` with no `@visibleForTesting` injection point |
| 7 | **A failing step must not advance the stamp** | ❌ | **MISSING. This is the one that pays for the file.** The repair at `:113-125` — the fix for the defect round 2 called "the exact silent data loss the file exists to prevent" — has **zero coverage** and *cannot* be covered while `_migrations` is private and empty. The header comment at `:9-11` advertises defect 2 as one of the three things "this file pins". It does not pin it |
| 8 | Missing step not silently skipped | ❌ | missing (same blocker) |
| 9 | Quarantine copies, never moves | ⚠️ `:132-146`, `:157-172` | **⚠️ partial.** The String test asserts both halves (copy present **and** original still in place, `:143`). The non-string test (`:157-172`) asserts **only the copy** — it never checks the originals survive, so a `quarantine` that became a *move* for int/bool/List would still pass. `double` is not covered at all (`store_migrator.dart:162` untouched by any test) |
| 10 | Quarantine of an absent key is a no-op | ✅ `:148-155` | **✅ real.** `expect(p.getKeys(), isEmpty)` |
| 11 | Unsupported type doesn't log a false success | ❌ | **N/A now** — `SharedPreferences` can only hold the five handled types, so the fall-through at `:167` is unreachable in practice. Withdrawn |
| 12 | `run()` never throws | ✅ `:119-128` | **✅ genuinely exercises a throwing path** — see below |
| 13 | Ordering vs providers (`main.dart:175`) | ❌ | missing. Still guaranteed only by line order in `main.dart` |

**Score: 4 real (1, 5, 10, 12) · 3 present-but-weak (2, 4, 9) · 1 present-but-inert (3) ·
4 missing (6, 7, 8, 13) · 1 withdrawn (11).**

**Does the pre-versioning test distinguish "stamped correctly" from "happened to already be
stamped"? Yes — but it cannot tell you *which branch* stamped, and that is the live risk.**
`:44-46` seeds `{'housepital_orders': '[]'}` with **no** stamp, so `getInt(versionKey) ==
currentVersion` at `:51` can only be true if `run()` wrote it. Delete `store_migrator.dart:134`
and this test fails. Good.

But at `currentVersion == 1` the fresh-install branch (`:74-77`) and the pre-versioning branch
(`:79-83`) produce **byte-identical stores** — stamp = 1, data untouched. Their only observable
difference is a `Log.warn`, which no test captures. Consequences:

- **Test 3 (`'is detected from ANY key, not a curated list'`, `:57-70`) asserts nothing about
  detection and cannot fail.** Replace `_hasAnyStoredData` with `=> false` — i.e. reintroduce
  exactly the misclassification the removed `_v1Keys` list caused, which the test's own comment
  at `:58-60` describes — and both its assertions still pass. The test named for defect 3 does
  not guard defect 3. It is the round-2 pattern repeating: a test written from the *narrative*
  of a bug rather than from a state the bug produces.
- It becomes a real test the moment `currentVersion` reaches 2 — but silently, and only if
  someone re-reads it then. A `Log` capture, or asserting `activeSources`-style observable
  branch evidence, would make it assertable today.

**Does the "never throws" test actually exercise a throwing path? Yes — verified against the
package source.** `shared_preferences-2.5.5/lib/src/shared_preferences_legacy.dart:121` is
`int? getInt(String key) => _preferenceCache[key] as int?` (the doc comment two lines up says
"throwing an exception if it's not an int"), and `setMockInitialValues` (`:272-286`) stores the
raw `String` in the in-memory store. So `store_migrator.dart:71`'s `prefs.getInt(_versionKey)`
throws a `TypeError` on the seeded `'not-an-int'`, and `run()`'s `catch` at `:63` is what makes
`expectLater(..., completes)` pass. Credit where due — this is a real exercise of a real guard,
and it is a *better* scenario than the `getInstance()`-throws case round 2 specified (that one
is unreachable under the mock).

Three caveats:
1. **No witness.** The test asserts only `completes`. If `getInt` ever became lenient the test
   would silently degrade to vacuous with nothing to notice. A `Log` spy, or asserting the catch
   branch's observable effect, would keep it honest.
2. **The aftermath is untested and it is bad.** After the catch, `'not-an-int'` is still the
   stamp. Every subsequent launch throws in the same place, `_run()` never completes, and the
   migrator is **permanently disabled on that device, silently**. Nothing repairs or quarantines
   the corrupt stamp. That is a defect the test walks past.
3. Defect 3 as round 2 stated it (`SharedPreferences.getInstance()` throwing) remains uncovered.
   Functionally the same `try` guards it, so I'll grade the contract ✅ and the case N/A.

**Test isolation:** clean. `setMockInitialValues` nulls `_completer` (`:285`), so every test gets
a fresh instance. No cross-test bleed here.

### R3-2. The rewritten nav-shape tests — do they assert the property that matters?

Two tests replaced one (`main_shell_test.dart:189-236`).

**Test 1, `'bottom nav is a FLOATING glass pill, inset from every edge'` — ⚠️ pure shape.**
`barRect.left > 0`, `right < width`, `bottom < height`, a `GlassSurface` ancestor, and
`navBar.backgroundColor == Colors.transparent`. Every assertion is a restatement of the owner's
aesthetic decision. It is a legitimate *shape lock* — it would catch a silent revert to the
round-5 orange bar — but it asserts nothing a patient can feel. Note the direction of travel:
this file has now been rewritten three times (floating → fixed orange → floating) and each
rewrite deleted the previous round's assertions wholesale. The test tracks the owner's taste,
not an invariant.

**Test 2, `'body extends under the pill, and the pill still reserves inset'` (`:220-236`) — ✅
this one asserts the property that matters, and it is falsifiable.**

```dart
expect(MediaQuery.of(homeContext).padding.bottom,
    greaterThanOrEqualTo(barRect.height),
    reason: 'Content must be able to clear the pill without knowing it exists.');
```

The round-5 objection to the pill was *occlusion*, and this is the correct structural answer:
`main_shell.dart:77` puts the `Padding` **inside** the `bottomNavigationBar` slot, so the
Scaffold reports the slot's full height as the body's bottom inset. Move the pill into a `Stack`
over the body — the obvious "make it float" refactor, and the shape the demo banner actually
uses — and `padding.bottom` collapses to the device inset, which is **0** in the test
environment (the deleted round-2 assertion at `:250` recorded "no home indicator in the test
env"). `0 >= ~56` fails. The test catches the regression it exists for.

Two honest limits:
- It compares against `BottomNavigationBar.height`, a **subset** of the pill's footprint, while
  its own comment (`:225-227`) claims the inset covers "the pill's full footprint (pill +
  margins)". The stronger assertion — against `tester.getRect(find.byType(GlassSurface))` or the
  slot widget — was available and cheaper to write than the comment.
- "The inset is reserved" is not "content clears the pill." Any screen with a padding-less
  nested scrollable (`CLAUDE.md` names this pitfall explicitly) still gets occluded, and this
  test checks one context on one screen. `overflow_smoke_test.dart` covers 37 screens for
  overflow but nothing checks bottom clearance per screen.

**The overlay-occlusion trade the brief asks about:** the *demo pill* — the other overlay
shipped this round — took the opposite structural choice. `demo_data_banner.dart:39-50` is a
`Stack` with a `Positioned(top: padding.top + kToolbarHeight + 4)`, deliberately "not a layout
participant" (`:24-27`). So the nav pill's regression is prevented by a test, and the banner's
identical failure mode is *documented as intentional* and has **no test at all** —
`grep -rln "DemoDataBanner" test/` → **0**. On the merits I'd take the overlay over the strip
(the strip's damage was global and permanent; the pill's is local, transient, and only on
screens whose content starts under the app bar), but the asymmetry is the finding: the same
team wrote a good structural test for the pill it cared about and none for the pill that sits
over clinical screens.

### R3-3. `patient_scope_isolation_test.dart` — five new tests, four of them real, one that
pins a data-loss bug as the contract

**✅ Genuinely new and genuinely falsifiable:**
- `'manually entered vitals do not survive a clear'` (`:225-240`) — closes round 2's named gap.
- `'cart clear drops SAVED items too, and persists that'` (`:242-261`) — asserts memory **and**
  `prefs.getString('housepital_saved_items') == '[]'`. Revert `cart_provider.dart:212` and it
  fails. Real.
- `'reminders are cleared from memory AND disk'` (`:278-290`) — asserts
  `prefs.containsKey(RemindersProvider.storageKey) == false`. Revert `reminders_provider.dart:199`
  and it fails. Real.
- `'loadPatients is a switch path too, and clears on identity change'` (`:293-308`) — **the
  strongest test added this round.** `_SwitchingApi` (`:64-78`) returns a *different* patient on
  the second call, and the test asserts `activeDeployment` is null afterwards. Delete
  `app_provider.dart:158` and it fails for exactly its stated reason. This is what round 2 asked
  for; it was simply pointed at the wrong method (see H8).
  - ⚠️ Only the positive half. Nothing asserts the `if (_currentPatient?.id != incoming.id)`
    guard at `:157` — i.e. that a **same-identity** reload does *not* clear. Drop the condition
    and every Home mount silently wipes the dashboard; the suite stays green.

**❌ `'orders clear reaches DISK, not just memory'` (`:263-276`) — the test is correct and the
behaviour it locks in is a data-loss bug.**

`orders_provider.dart:11-12` still keys storage globally (`'housepital_orders'`,
`'housepital_assessments'` — no patient id; unchanged from round 2). The repair at `:212-219`
makes `clearPatientScopedData()` call `_persistAndNotify()`, and the test asserts the result:

```dart
expect(prefs.getString('housepital_orders'), '[]',
    reason: 'an in-memory-only clear looked right and then '
        '_loadFromStorage restored the previous patient on next launch');
```

The PHI leak is closed. But `clearPatientScopedData` fires on **every patient switch**
(`home_screen.dart:1774` → `session_scope.dart:59`), so on a shared phone — the exact scenario
this whole workstream exists for — switching from Dad to Mum now **permanently destroys Dad's
order history on disk**, and switching back shows nothing. Round 2 flagged the destructive
overwrite as reachable on the *first new order*; round 3 made it unconditional and immediate.

The correct fix was in round 2's report (key per patient + a migration step) and would have
given `StoreMigrator` its first real migration and case 6/7 their first real subject. Instead
the leak was closed by deletion, with no quarantine — in an app that ships a file whose stated
contract is *"A migration NEVER deletes data it cannot parse"* (`store_migrator.dart:19-21`).
**And a test now certifies the deletion**, which means the next person to notice will have to
argue with a green assertion. That is the round-2 pattern — a surface that then *claims* the
problem is handled — reappearing one layer down.

**Unchanged and now harder to excuse:** `'switchPatient clears before adopting the new patient'`
(`:121-141`) is substantively untouched. The name, the honest-but-buried comment at `:132-139`,
and the three assertions that all pass with `app_provider.dart:175` deleted — all identical to
round 2. The file gained the per-patient fake that would fix it. Neither the two-line rename nor
the redirect was done.

**Sleeps tripled.** `:197, :253, :266, :270` — four bare `Future.delayed(20ms)` waits on
`SharedPreferences` platform-channel round trips, in the file whose subject is a race between a
wipe and a load. Round 2 flagged one. `RemindersProvider` demonstrates the alternative in the
same file: `await reminders.clearPatientScopedData()` (`:285`) is deterministic because the
method returns a `Future`. `CartProvider.clearPatientScopedData` (`:210`) and
`OrdersProvider.clearPatientScopedData` (`:212`) are `void` wrapping fire-and-forget `_persist()`
— that is the defect the sleeps paper over, and it is also a production hazard: nothing in
`SessionScope.clearPatientData` (`:56-63`) can await those two writes, so a caller that
immediately loads the next patient races them. `SessionScope`'s own comment at `:65-66` claims
the async stores are "Awaited so a caller that immediately loads the next patient cannot race
the wipe" — that is true of the two it awaits and false of the two it doesn't.

### R3-4. `DemoMode` — the right redesign, still zero tests

`demo_mode.dart` is now a per-source `Set` with eleven named sources (`:24-34`), and
`markServingLiveData` can only remove *its own* source (`:52-54`). That is precisely the fix
round 2's H11 asked for, and the doc comment at `:11-20` is an unusually honest post-mortem.

**Coverage: one assertion, in one test.** `patient_scope_isolation_test.dart:221` asserts
`DemoMode.isServingDemoData.value == true` after a dashboard fallback. Nothing tests:
- that a source can only clear itself (**the entire point of the redesign**) — e.g. seed
  `{dashboard, medications}`, call `markServingLiveData(sourceDashboard)`, assert the notifier
  is **still true**. That is a four-line test and it is the regression guard for the bug the
  file was rewritten to fix;
- `activeSources` (`:43`) — exposed as "for diagnostics and tests", used by zero tests;
- that `reset()`'s early return at `:59` doesn't skip a needed `_sync()`;
- that every `DemoData` fallback site actually marks a source. Round 2 found five sites that
  never called `markServingDemoData`; sources now exist for `articles`, `care-team`,
  `care-calendar`, `profile` and `handover-report`, but no test asserts any site calls them, so
  the fix is verified only by the author's own grep.

`demo_data_banner.dart` (136 LOC, new): **0 tests.** Unexercised are the `serving == false`
short-circuit (`:38`), the `Positioned` maths (`:45`) that is the known Settings occlusion, the
`SemanticsService.sendAnnouncement` in `initState` (`:74-84`) — an a11y path that fires exactly
once, on a `Semantics(liveRegion: true)` node wrapping an `ExcludeSemantics` subtree, a
combination that is easy to get silently wrong — and the `l == null` early return at `:77`,
which makes the announcement conditional on localization delegate timing.

### R3-5. The new pending-verification payment state — untested, and coupled by a string

`payment_screen.dart:286`:

```dart
final unverified = message.contains('under verification');
```

The entire branch — warning icon instead of red X (`:478`), "pending verification" title
(`:491`), retained `_transactionId` (`:292`), **no Retry button** (`:611-634`) — hangs on a
substring match against a message literal produced two files away at
`payment_service.dart:180,186`. Zero tests. Three concrete hazards:

1. **Reword the message and the branch silently dies.** The screen falls back to red "Payment
   Failed" + "Retry Payment" (`:640`) for a patient whose card **has already been debited** —
   i.e. it re-creates, by copy edit, exactly the double-charge the state was added to prevent.
   Nothing anywhere ties the producer to the consumer.
2. **The literal is not localized.** `payment_service.dart:180` is a raw English string. A Hindi
   user is shown English today; and the moment anyone localizes it — which the project's own
   i18n rule requires — the match breaks and hazard 1 fires. This is a trap set for the next
   contributor.
3. `'Go Back'` (`:631`, `:649`) and `'Retry Payment'` (`:640`) are hardcoded English inside the
   new block. `i18n_sync_test` only checks EN/HI key parity, so it cannot see a string that
   never became a key.

The keys that *were* added are correctly paired: `payment_pending_verification_title` and
`payment_pending_contact_us` are present in both `en.json` and `hi.json`.

Note also that any test for this would land in `payment_service_test.dart`, all of whose
real-key groups are `skip: _skipReason` — so even a correct test would not run under
`flutter test`.

### R3-6. Risk ranking of the five still-untested files

The brief asks for a ranking. Mine, by *expected harm × likelihood a silent edit reaches
production*:

| Rank | File | LOC | Why here |
|---|---|---:|---|
| **1** | `lib/screens/settings/delete_account_screen.dart` | 325 | **Irreversible and now more so.** `:131` `await user.delete()` destroys the Firebase credential; `:143-145` wipes local storage. The whole gate is `_canSubmit` (`:72-76`) — one boolean expression, zero tests. **New this round:** the confirmation word is *localized* (`:70`, `l.t('delete_account_confirm_word')`), so an irreversible gate now depends on a JSON asset. It fails closed today (`app_localizations.dart:30` falls back to the key), but nothing asserts that, and the class doc's rationale for localizing it ("so a Hindi-preferring user is not asked to type a Latin word they may not read", `:68-69`) is **false in the shipped data** — `hi.json:339` is `"DELETE"`, identical to `en.json:339`. Worse: the "durable" deletion record's survival depends on a **hardcoded duplicate string** — `auth_provider.logout()` preserves `'housepital_pending_deletion'` as a literal, duplicated from `DeleteAccountScreen.pendingDeletionKey` (`:60`), and `'housepital_schema_version'` duplicated from `StoreMigrator._versionKey` (`:35`). Rename either constant and the logout that runs three lines later silently destroys the only evidence the user ever asked to be deleted, or the schema stamp. That is a 5-line test with a legal consequence (DPDP §12) and it does not exist |
| **2** | `lib/utils/session_scope.dart` | 101 | The PHI fix itself. **Three** call sites now; zero test imports; deleting any one leaves the suite green. Eight `context.read` calls (`:56-67`) mean a `ProviderNotFoundException` from any subtree missing one — including `delete_account_screen`, a route pushed from Settings. Round 2 called this the central criticism; it stands verbatim. **The primitives are guarded, the wiring is not** |
| **3** | *(new)* pending-verification state in `payment_screen.dart` | ~40 | Money already left the patient's account; the branch is held together by a substring match on an unlocalized English literal (§R3-5) |
| **4** | `lib/data/demo_mode.dart` | 67 | Gates a clinical warning. The set semantics — the specific thing the rewrite exists for — has no test. A regression here is an affirmative all-clear on someone else's chart |
| **5** | `lib/widgets/demo_data_banner.dart` | 136 | The user-visible half of #4, plus the known Settings occlusion and a fragile a11y announcement path |

`delete_account` outranks `session_scope` because its failure is *unrecoverable for the user*
rather than *recoverable by re-login*; `session_scope` outranks the rest because it is the fix
this entire workstream is named for and it is still, three rounds in, verified by nothing.

### R3-7. 120 tests executing zero production code — re-counted, unchanged

```
test/screens/services/assessment_form_test.dart      26 / 0 widgets / 0 prod imports
test/screens/services/booking_history_test.dart      20 / 0 / 1   (config/theme.dart only)
test/screens/settings/notification_prefs_test.dart   18 / 0 / 0
test/screens/cart/cart_coupon_test.dart              17 / 0 / 0
test/screens/services/equipment_detail_test.dart     17 / 0 / 0
test/screens/settings/help_faq_test.dart             12 / 0 / 0
test/screens/services/service_catalog_test.dart      10 / 0 / 1   (models/models.dart only)
                                                    ───
                                                    120
```

Untouched for three rounds. The refund-policy group (`booking_history_test.dart:153-199`) still
tests a 24-hour policy that does not exist in `lib/`.

### R3-8. The four rewritten payment tests — are they honest now?

**They are unchanged.** `git diff 820060b..9a80fe2 -- test/services/payment_service_test.dart`
is empty. So the round-2 verdicts carry forward unamended:

- `:474-523` **✅ still the one genuinely good rewrite** — `expect(successCalled, isFalse)` +
  `expect(failureMessage, isNotNull)` + `expect(fakeApi.verifyCalls, isEmpty)`. Falsifiable,
  specific, correctly named.
- `:607-654` **❌ still over-loosened.** `:649` still accepts the exact regression `:511` forbids;
  the deterministic assertion is still available and still not written; `:643`'s 30 ms sleep is
  still a wall-clock race in the one test whose job is detecting "no callback ever fires", while
  `_CallbackLatch` (`:845`) sits unused; the name still says "even when channel will fail" while
  `:620-621` states the channel does not fail. Round 2 graded this ⚠️; with a full round elapsed
  and no edit, I grade it **❌**.
- `:779-785`, `:819-825` **✅ still correct and mechanical**, still carrying the stale
  `reason: 'order_id must be omitted in demo mode'` at `:792`.
- The demo half (`payment_service.dart:171-172`) **is still structurally unreachable** and still
  covered by nothing.

And all four sit inside `skip: _skipReason` groups. Scripted count of tests inside the 8 skipped
groups: **3+4+1+1+1+3+1+3 = 17**, unchanged. No `dart_test.yaml` exists.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Code Quality & Architecture (test-tree scope) | 3 | 5 | 2 | 0 |
| 2. Input Validation & Sanitization | 2 | 2 | 3 | 2 |
| 3. Concurrency / Resource Cleanup (test scope) | 2 | 3 | 1 | 1 |
| 4. Security (auth, secrets, API, data, deps) | 3 | 3 | 5 | 2 |
| 5. Database & Data Integrity | 1 | 1 | 3 | 4 |
| 6. Error Handling | 4 | 2 | 1 | 0 |
| 7. Logging & Observability | 3 | 1 | 2 | 0 |
| **8. Testing (primary scope)** | **19** | **10** | **14** | **1** |
| 9. Release Readiness | 3 | 2 | 2 | 0 |
| **TOTAL** | **40** | **29** | **33** | **10** |

Round 2 was 32 / 28 / 35 / 10; round 1 was 31 / 27 / 29 / 10. Section 8's ✅ column grew by
seven — `StoreMigrator` acquiring a test file at all, four real new isolation tests, the nav
inset test, and the migrator's own three defects being genuinely closed in code. The ❌ column
shrank by one net: five round-2 failures closed, four new ones opened (`demo_data_banner`
untested, the pending-verification state untested, `store_migrator`'s Defect-2 repair untestable,
and the orders on-disk destruction).

Section 5 gains its first ✅ (a migrator that now demonstrably stamps and demonstrably refuses to
migrate backwards) while keeping ❌ on data isolation — the orders keys are still global and the
"fix" is deletion.

---

## Blockers

1. **The repair to `StoreMigrator`'s worst defect is untestable.** `store_migrator.dart:113-125`
   (a failed step must not advance the stamp) has **zero** coverage, and `_migrations` (`:50`)
   being private and empty makes it unreachable by any test. Add an `@visibleForTesting`
   injection point and write cases 6, 7 and 8. Round 2 said cases 2 and 7 were the two that pay
   for the file; case 2 landed, case 7 did not.
2. **Order history is destroyed, not scoped** (`orders_provider.dart:11-12, 212-219`). Every
   patient switch now writes `[]` over the global key — permanent, silent, unrecoverable, in an
   app that ships a quarantine facility it does not use here. **And
   `patient_scope_isolation_test.dart:273` asserts the destruction as the contract.** Key per
   patient, add a migration step (which would also give blocker 1 a real subject), and change
   that assertion.
3. **`SessionScope` is still imported by zero tests** — third round running, now three call
   sites (`home_screen.dart:1774`, `settings_screen.dart:460`, `delete_account_screen.dart:143`).
   Delete any one and the suite is green. A `MultiProvider` widget test per call site.
4. **`delete_account_screen.dart` still has no test** and now performs an irreversible
   `user.delete()` behind a single boolean, with a localized gate word and two cross-file
   hardcoded key duplications in `auth_provider.logout()` that nothing pins.
5. **The pending-verification payment state is untested and coupled by an unlocalized substring
   match** (`payment_screen.dart:286` ↔ `payment_service.dart:180,186`). Localizing that string —
   which the project's own i18n rule requires — breaks the branch.
6. **17 payment tests, including the one genuinely good fail-closed guard at `:474`, still skip
   on a bare `flutter test`.** Unchanged for two rounds. No `dart_test.yaml`.
7. **`_priceMultiplier` still has no test** (`service_booking_screen.dart:151-156`). Third round.
8. **Token-refresh recovery still untested and untestable** (`auth_provider.dart:93`).

## High

9. `store_migrator_test.dart:57-70` ("detected from ANY key") **cannot fail** — replace
   `_hasAnyStoredData` with `=> false` and it stays green. So does `:85-96` ("already current") if
   the early-out at `store_migrator.dart:86` is deleted. Two of ten tests are decoration.
10. The `'never throws'` test exercises a real throwing path (✅) but asserts no witness, and the
    aftermath it walks past is a device whose migrator is **permanently and silently disabled**
    by a corrupt stamp. Repair or quarantine the stamp in the catch; assert it.
11. `payment_service_test.dart:649` unchanged after a full round — downgraded ⚠️ → ❌.
12. `patient_scope_isolation_test.dart:121-141` unchanged after a full round; the fake that would
    fix it now lives 50 lines above it, pointed elsewhere. Downgraded ⚠️ → ❌.
13. `DemoMode`'s per-source semantics — the entire reason for the rewrite — have no test; a
    four-line test would guard it. `demo_data_banner.dart` (136 LOC) is rendered by no test,
    including the known Settings occlusion and the a11y announcement.
14. `CartProvider.clearPatientScopedData` and `OrdersProvider.clearPatientScopedData` are `void`
    over fire-and-forget `_persist()`, so `SessionScope.clearPatientData` **cannot** await them —
    contradicting its own comment at `session_scope.dart:65-66`. The four 20 ms sleeps in the
    test file are the symptom.
15. `loadPatients`'s same-identity guard (`app_provider.dart:157`) is untested in the negative
    direction — drop it and every Home mount silently wipes the dashboard.
16. 120 tests execute zero production code; 6 orphan `lib/` files; no security tests of any kind;
    `firestore.rules`, `storage.rules` and `functions/index.js` still have no harness.

## Medium / Low

17. 93/216 widget tests (43%) inert; `my_care_widgets_test.dart` alone is 28.
18. 3 assertion-free tests unchanged (`notification_router_test.dart:91,97`;
    `payment_service_test.dart:282`).
19. `TEST_MAP.md` and `TEST_STRATEGY.md` mention **none** of `store_migrator`,
    `patient_scope_isolation`, `session_scope`, `demo_mode` or `delete_account` — a new test file
    exists and the test inventory does not know it. Round-2 item, unchanged.
20. `quarantine`'s non-string test (`:157-172`) never asserts the originals survive, so a
    copy→move regression passes for int/bool/List; `double` (`store_migrator.dart:162`) is
    covered by nothing.
21. `main_shell_test.dart:230` compares the inset against `BottomNavigationBar.height`, a subset
    of the footprint its own comment claims to be checking.
22. `staff_role_sheet_test.dart:168-176` — the rename is honest and correct, but the assertion
    (`find.textContaining('₹') findsNothing`) is unchanged and still one-sided: nothing asserts
    the price **is** on the card, so a regression that removes manpower prices entirely — against
    an inviolable business rule — is invisible to this file.
23. `delete_account_screen.dart:68-69` documents a localization rationale that `hi.json:339`
    contradicts (both locales are `"DELETE"`).
24. `'Go Back'` / `'Retry Payment'` hardcoded in `payment_screen.dart:631,640,649`; `i18n_sync_test`
    structurally cannot see them.
25. `DemoMode.isServingDemoData` is still mutable process-global state reset by exactly one test.
26. Round-1/2 Medium items stand: ~20 s of wall-clock sleeping in `api_service_test.dart`, 60
    `DateTime.now()` uses, `test/integration/` misnamed, `i18n_sync_test` cannot catch its own
    founding bug, `Validators.numberInRange` untested, cart rental-months clamp untested, 50%
    coverage gate below the documented 60%.

## BLOCKED-OWNER

- **Suite wall-clock time (<5 min target)** — instructed not to run `flutter test`. Need the
  central run's reported duration.
- **Coverage, global and per file** — need `coverage/lcov.info`. Specifically:
  `lib/services/store_migrator.dart` (now non-zero — I need the number to say whether the
  untested `_migrateFrom` failure branch shows as uncovered lines),
  `lib/utils/session_scope.dart` (I assert 0% on static grounds),
  `lib/widgets/demo_data_banner.dart` (0%), `lib/screens/settings/delete_account_screen.dart` (0%).
- **Backend/database (§5)** — schema constraints, indexes, pooling, server-side re-validation,
  CORS, rate limiting. Needs `housepital-backend` repo access or a Firebase emulator run.
- **Whether `storage.rules` / `firestore.rules` are deployed** — brief says storage rules are not;
  live posture unknown without console access.
- **Monitoring/alerting** — needs Crashlytics / Firebase console.
- **Dependency vulnerabilities** — needs `dart pub outdated --mode=security`.
- **Rollback plan validity** — needs a drill against App Store Connect / Play Console.

---

## Executive summary

1. Round 3 counts: **✅ 40 · ⚠️ 29 · ❌ 33 · N/A 10** (round 2: 32/28/35/10). Section 8 gained
   seven ✅ — the first real progress on test quality in three rounds.
2. **Genuinely fixed:** `StoreMigrator`'s three defects are closed *in code* and four of its ten
   new tests are real (fresh install, downgrade, absent-key quarantine, and a "never throws" test
   that — verified against `shared_preferences-2.5.5:121` — does exercise a genuine `TypeError`
   path, not a vacuous one).
3. **Also genuinely fixed:** four new patient-scope tests (vitals, cart saved items, reminders on
   disk, and the `loadPatients` switch path) are falsifiable and would catch their regressions.
   `loadPatients` is the strongest test added this round.
4. **The nav-shape rewrite is half good.** Test 1 is pure geometry. Test 2 asserts the property
   that actually matters — the pill reserves its own inset, so content cannot be occluded — and
   it fails if the pill is moved into a Stack. Credit it.
5. **REGRESSED:** order history. The in-memory-only clear became an on-disk `[]` write over a
   still-global key, so every patient switch now permanently destroys the outgoing patient's
   order history — and `patient_scope_isolation_test.dart:273` **asserts the destruction as the
   contract.** A test now certifies a data-loss bug.
6. **Is any round-2 repair itself a surface? Yes, two.** (a) `store_migrator_test.dart:57-70` is
   named for the curated-key-list defect and *cannot fail* if that defect is reintroduced —
   at `currentVersion == 1` both branches leave identical stores. (b) The repair to the worst
   migrator defect (a failed step must not advance the stamp) is advertised in the test file's
   own header as something this file "pins", and is covered by nothing — `_migrations` is private
   and empty, so it is not merely untested but untestable.
7. **The central round-2 criticism STANDS, unqualified.** `grep -rn "SessionScope" test/` returns
   **one hit and it is a comment**. Zero test files import `session_scope.dart`. There are now
   **three** call sites; deleting any one keeps all 1,813 tests green. The primitives are guarded;
   the wiring is not.
8. **Unchanged after a full round, so downgraded to ❌:** `payment_service_test.dart:649` (still
   accepts the regression its sibling forbids) and `patient_scope_isolation_test.dart:121`
   (still cannot fail for the reason its name gives — while the fake that would fix it now sits
   50 lines above, pointed at a different method).
9. **Top 5 remaining:** (1) the migrator's failed-step repair is untestable; (2) order history is
   destroyed rather than scoped, and a test pins it; (3) `SessionScope` still verified by nothing;
   (4) `delete_account_screen` — irreversible `user.delete()` behind one boolean, zero tests, with
   two cross-file hardcoded key duplications guarding the legal record; (5) the new
   pending-verification payment state, coupled by an unlocalized substring match that the
   project's own i18n rule will break.
10. **FAIL.** Real, measurable improvement — the first round where new tests mostly earn their
    place — but three release blockers from round 2 are untouched, one repair regressed into
    permanent data loss with a test certifying it, and the fix this entire workstream is named
    for is still guarded by nothing.

---

*Read-only audit. No files under `lib/` or `test/` were modified; only this report was written.
`docs/audits/TESTING_AUDIT.md` (round 2) is unchanged.*
