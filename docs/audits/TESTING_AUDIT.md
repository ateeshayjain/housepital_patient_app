# Software Testing & Code Quality Checklist (App-Agnostic) — Audit **round 2** vs commit `820060b`

**Date:** 2026-08-03 · **Previous round:** commit `803124d` · **Branch:** `fix/five-tab-nav`
**Checklist:** `Testing Checklist - App Agnostic.txt` (sections 1–9)
**Method:** static read of the full test tree + `git diff 803124d..820060b` + `grep`/`rg` +
brace-matching scripts over `test/**/*_test.dart`. Per the brief I did **not** run `flutter test`,
`flutter build` or `flutter analyze`. Every verdict cites `file:LINE` or a command with output.

---

## Changed since round 1

`git diff 803124d..820060b --stat -- test/` touched exactly **three** test files:

```
 test/providers/patient_scope_isolation_test.dart | 189 +++++++++++++++++++  (new)
 test/screens/main_shell_test.dart                |  28 ++--
 test/services/payment_service_test.dart          |  42 +++--
```

Nine production files landed with **zero** accompanying tests. That asymmetry is the headline of
round 2: the fix commit added 189 lines of test for the PHI leak and 0 lines for the migrator that
will run against real user data.

| Round-1 finding | Status now | Evidence |
|---|---|---|
| 4 payment tests asserted the bug (`skippedDemo → onSuccess`) | **✅ 1 genuinely fixed, ⚠️ 1 over-loosened, ✅ 2 latch-only edits** | `test/services/payment_service_test.dart:474-523`, `:607-654`, `:779-785`, `:819-825` — see §8-M |
| PHI leak: patient switch cleared nothing | **⚠️ partially fixed, and the new tests do not guard the part that broke** | `lib/utils/session_scope.dart` untested; `test/providers/patient_scope_isolation_test.dart` — see §8-N |
| `main_shell_test` asserted six tabs incl. Calendar | **✅ fixed** | `test/screens/main_shell_test.dart:228,233,242` — now `hasLength(5)` + `expect(barLabel('Calendar'), findsNothing)` |
| `_priceMultiplier` untested | **❌ unchanged** | `grep -rn "ultiplier" test` → 1 unrelated hit (`billing_screen_test.dart:341`) |
| Live manpower pricing rule untested; dead rule encoded | **❌ unchanged** | `test/screens/services/service_booking_test.dart:182-278` untouched by the diff |
| Token refresh untestable (`FirebaseAuth.instance` direct) | **❌ unchanged** | `lib/providers/auth_provider.dart:93` still `FirebaseAuth.instance.currentUser` |
| 17 payment tests skipped on bare `flutter test` | **❌ unchanged** | `grep -rn "skip:" test` → still 8 groups, all `_skipReason` |
| 120 tests execute zero production code | **❌ unchanged** | 7 mirror files still 0 `testWidgets`, 0 (or 1 model-only) `housepital_patient` imports; 26+20+18+17+17+12+10 = **120** |
| 24 P0 tests guard orphan `booking_state_machine.dart` | **❌ unchanged** | `grep -rn "BookingStateMachine\|canTransition" lib` → only the file's own `:40,:51` |
| 3 tests with no assertion at all | **❌ unchanged** | `notification_router_test.dart:91,97`; `payment_service_test.dart:281` |
| 6 orphan `lib/` files | **❌ unchanged** | scripted re-check: all 6 still have zero importers outside themselves |
| 45% of widget tests inert | **❌ unchanged (94/215)** | recomputed below; round 1 said 97 — the 3-test delta is script tolerance, **not** improvement (no inert-heavy file was touched) |
| Docs assert six tabs | **❌ unchanged** | `docs/ARCHITECTURE.md:68`, `docs/SCREEN_MAP.md:6`, `README.md:166` |

**Nothing regressed in the sense of a previously-passing guard being deleted.** The one direction of
travel that got *worse* is assertion strictness in `payment_service_test.dart:649` (§8-M).

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Code Quality & Architecture (test-tree scope) | 3 | 4 | 3 | 0 |
| 2. Input Validation & Sanitization | 2 | 2 | 3 | 2 |
| 3. Concurrency / Resource Cleanup (test scope) | 2 | 3 | 1 | 1 |
| 4. Security (auth, secrets, API, data, deps) | 3 | 3 | 5 | 2 |
| 5. Database & Data Integrity | 0 | 1 | 3 | 4 |
| 6. Error Handling | 4 | 2 | 1 | 0 |
| 7. Logging & Observability | 3 | 1 | 2 | 0 |
| **8. Testing (primary scope)** | **12** | **10** | **15** | **1** |
| 9. Release Readiness | 3 | 2 | 2 | 0 |
| **TOTAL** | **32** | **28** | **35** | **10** |

Round 1 was 31 / 27 / 29 / 10. The ❌ column grew by six: five newly-shipped production files with
no tests (`store_migrator.dart`, `session_scope.dart`, `demo_mode.dart`, `delete_account_screen.dart`,
plus the untested `clearPatientScopedData` **wiring**), and one new data-integrity failure
(order persistence is not patient-scoped, §8-N.4).

---

## Where the mass sits vs where the risk sits (re-measured)

| Metric | Round 1 | Round 2 |
|---|---:|---:|
| Test files | 99 | **100** |
| `test(` + `testWidgets(` call sites | 1,372 | **1,380** |
| `testWidgets` | 215 | **215** |
| Test LOC | 23,530 | **24,093** |
| `lib/` LOC | 54,295 | **55,067** |

The commit added **772 LOC of production code and 8 tests**, all 8 in one new file. Nine new/changed
production files, one new test file. `lib/services/`, `lib/utils/` and `lib/data/` each gained a file
that no test imports.

---

## Findings

### 8-M. The four rewritten payment tests — adversarial reading

The brief asked whether the rewrite pins the fail-closed contract or was loosened until it passed.
`git diff 803124d..820060b -- test/services/payment_service_test.dart` shows four edits. They are
not equivalent in quality.

**1. `openCheckout — unverifiable success (skippedDemo)` (`:474-523`) — ✅ genuinely fixed.**
This is the one that mattered and it was done properly. Old assertions:

```dart
expect(successCalled, isTrue, reason: 'demo-mode payments should still call onSuccess');
expect(failureMessage, isNull);
```

New (`:511-518`):

```dart
expect(successCalled, isFalse,
    reason: 'an unverifiable payment must NOT be confirmed when a real key is configured');
expect(failureMessage, isNotNull, reason: 'the user must be told verification is pending');
expect(fakeApi.verifyCalls, isEmpty);
```

All three are positive, specific, and falsifiable. If `payment_service.dart:171-182` were reverted to
unconditional `onSuccess`, `expect(successCalled, isFalse)` fails immediately. The group name and test
name were both corrected. This is a real regression guard, not a rename.

**2. `openCheckout() does not throw synchronously…` (`:607-654`) — ⚠️ over-loosened. This is the one
to push back on.** New assertion (`:649`):

```dart
expect(successCalled || failure != null, isTrue,
    reason: 'openCheckout must always resolve to one callback');
```

- **Is it a tautology?** Strictly, no. It is falsifiable: it fails when *neither* callback fires,
  which is exactly the silent-checkout failure mode documented in this test's own header
  (`:610-615`). As a liveness assertion it has content.
- **But it was loosened further than the code required.** The outcome here is *deterministic*, not
  ambiguous. The stub returns `_demoSuccessResponse()` (no `order_id`, no signature, `:481`/`:623`),
  the group is `skip: _skipReason` so it only ever runs with a non-placeholder key, therefore
  `isDemoPayments == false`, therefore `_handleSuccess` → `skippedDemo` → `else` branch →
  `onFailure` (`lib/services/payment_service.dart:163-182`). The tightest correct assertion —
  `expect(successCalled, isFalse); expect(failure, isNotNull);` — was available and would have
  passed. The comment at `:645-648` ("Any outcome is fine here") asserts an ambiguity that does not
  exist in this configuration.
- **What it now fails to catch:** a regression of the exact bug test #1 guards. If
  `payment_service.dart:171` were changed back to unconditional `_onSuccessCallback?.call()`, this
  test stays green (`successCalled` becomes true, disjunction still satisfied). The suite would lose
  one of its two witnesses. It is redundant coverage that was silently converted into non-coverage.
- **Two further defects in this test, both pre-existing and both untouched by the rewrite:**
  (a) the test is named *"even when channel will fail"* but the channel never fails — `openError` is
  not passed, and `:620-621` says so explicitly. The name describes a scenario the body does not
  create. (b) `:643` `await Future<void>.delayed(const Duration(milliseconds: 30))` is a wall-clock
  race in the one test whose entire job is to detect "no callback ever fires". A loaded CI runner
  that dispatches at 35 ms produces a false failure; the `_CallbackLatch` at `:845` exists precisely
  for this and is not used.
- **Verdict:** ⚠️. Not a tautology, but a strictly weaker assertion than the code supports, in a test
  whose name does not match its body. **Fix:** split it — keep `expect(returnsNormally)` as the
  synchronous contract, and assert `successCalled == false && failure != null` for the outcome;
  latch on `_CallbackLatch` instead of 30 ms.

**3 & 4. The two options-payload tests (`:779-785`, `:819-825`) — ✅ correct, mechanical.**
These only added `onFailure: (_) => completer.fire()` so the latch resolves under the fail-closed
contract. No assertion was weakened; the payload expectations (`:790-796`, `:830-833`) are unchanged
and still specific. One cosmetic wart: `:792` still carries `reason: 'order_id must be omitted in
demo mode'` — the suite is not in demo mode when this runs. Stale reason string, no functional
impact.

**5. ❌ The demo half of the contract is now covered by nothing.** `payment_service.dart:171-172`:

```dart
if (isDemoPayments) {
  _onSuccessCallback?.call();
```

is **structurally unreachable**. `openCheckout` returns at `:113-122` when `isDemoPayments` is true
and never calls `_razorpay.open`, so `_handleSuccess` can only fire when a real key is configured —
in which case `isDemoPayments` is false. The branch cannot execute in production or in any test.
Meanwhile every group that could probe it is `skip: _skipReason`, i.e. skipped in exactly the demo
configuration it describes. **Fix:** delete the dead branch (the fail-closed `else` is the only live
path), or, if it is retained as defence-in-depth, document that it is unreachable so nobody writes a
test expecting to hit it.

### 8-N. `test/providers/patient_scope_isolation_test.dart` — judged hard

New file, 8 tests, 189 LOC. It is better than most of the suite and it still does not guard the bug
it was written for.

**1. ✅ The five per-provider clear tests (`:63-84`, `:125-170`) are real.** They construct the
provider, load until non-empty (`expect(p.activeServices, isNotEmpty)` at `:128` is a genuine
precondition guard, not decoration), call `clearPatientScopedData()`, then assert emptiness field by
field. `AppProvider`'s test (`:63-84`) checks all seven fields including `amountDue == 0` with a
reason that explains why that field matters clinically. If a future edit adds a field to `AppProvider`
and forgets it in `clearPatientScopedData`, *this test will not catch it* (it asserts a fixed list),
but for the fields that exist today it is a correct contract test.

**2. ⚠️ `switchPatient clears before adopting the new patient` (`:86-106`) — the name is a promise the
body does not keep.** Its own comment (`:97-104`) admits this. What it actually asserts:

```dart
expect(app.currentPatient?.id, isNot(firstPatientId));
expect(app.currentPatient?.id, 'pat_other_sunita');
expect(app.lastUpdatedText, 'Demo data');
```

Delete `clearPatientScopedData(notify: false)` from `lib/providers/app_provider.dart:163` and **all
three assertions still pass** — `switchPatient` still assigns `_currentPatient`, and `loadDashboard`
→ `_seedDemoDataIfEmpty` still sets `lastUpdatedText = 'Demo data'` (`app_provider.dart:268`)
because the deployment field is non-null either way. The test cannot fail for the reason its name
gives.

Is the comment honest documentation or should the test be deleted? **Neither — it should be made
assertable, and the reason it isn't is the test harness, not the production code.** `_UnreachableApi`
(`:31-47`) makes *every* fetch throw, so both patients fall back to the same fixed `DemoData` blob and
become indistinguishable. Give the fake per-patient data and the test becomes the strongest test in
the file:

```dart
class _PerPatientApi extends ApiService {
  @override Future<Deployment?> getActiveDeployment(String id) async =>
      id == 'pat_demo_rajesh' ? _deploymentFor(id) : throw Exception('unreachable');
}
// switch to a patient whose fetch FAILS, then:
expect(app.activeDeployment?.patientId, isNot('pat_demo_rajesh'),
    reason: 'the outgoing patient must not survive a failed load for the incoming one');
```

That is the actual leak shape: patient A loads, patient B's fetch fails, A's record renders under B's
name. As written the file never constructs that scenario. Keeping the honest comment *and* the
misleading test name is the worst combination — the comment is buried in the body while the name is
what shows in the test report and in `docs/TEST_MAP.md`. At minimum rename to
`'switchPatient adopts the new patient and flags the reload as demo data'`.

**3. ❌ The wiring — which is where the bug actually was — has no test at all.**
`lib/utils/session_scope.dart` is imported by **no test file** (`grep -rl "SessionScope\|session_scope"
test` → nothing). The original defect was not "providers lack a clear method"; it was "the switch site
and the logout site clear nothing." Those sites are `lib/screens/home/home_screen.dart:1771` and
`lib/screens/settings/settings_screen.dart:457`. Delete either line and **all 8 new tests still pass.**
The regression guard does not guard the regression. A `MultiProvider` widget test that pumps the
patient-switch sheet, taps a patient, and asserts `MyCareProvider.activeServices` is empty would; so
would a direct `SessionScope.clearPatientData(context)` test under a `Builder`. `SessionScope` also
has an untested crash mode: it `context.read`s six providers (`:29-35`), so any screen that calls it
from a subtree missing one of them throws at runtime.

**4. ❌ And the leak is only half-fixed: order history is not patient-scoped in storage.**
`OrdersProvider.clearPatientScopedData()` (`lib/providers/orders_provider.dart:212-216`) clears
`_orders` and `_assessments` **in memory only** — it does not touch SharedPreferences, and the keys
are global singletons (`:11-12` `'housepital_orders'`, `'housepital_assessments'` — no patient id).
Two consequences, neither tested:
- **The PHI leak survives a restart.** Switch from patient A to B, force-quit, relaunch:
  `_loadFromStorage()` (`:175`) reads the same global key and patient A's order history renders under
  patient B. The in-memory clear is erased by the next cold start.
- **The fix introduced a data-loss path.** After the in-memory clear, the first order placed for
  patient B calls `_persistAndNotify()` (`:163-172`), which writes the now-one-element `_orders` over
  the global key — **destroying patient A's persisted order history**. Before the fix, `_orders` still
  held A's orders so the write was non-destructive.
  **Fix:** key persistence per patient (`housepital_orders_$patientId`) and add a migration step
  (see §8-P), or persist the clear explicitly and accept the loss knowingly.

**5. ⚠️ `demo data is announced, not silently substituted` (`:173-188`) is correct but the flag it
asserts is globally imprecise.** `DemoMode.isServingDemoData` is a process-wide static
`ValueNotifier` (`lib/data/demo_mode.dart:16`). `AppProvider.loadDashboard` calls `DemoMode.reset()`
on a *successful* live load (`app_provider.dart:247`) — which takes the banner down for the whole app
even if `MyCareProvider`, `MedicationProvider` or `OrdersProvider` are still serving sample records.
A false "all clear" on a clinical banner is worse than no banner. Untested. Also, five `DemoData`
fallback sites never set the flag at all: `lib/providers/blog_provider.dart`,
`lib/screens/calendar/care_calendar_screen.dart`, `lib/screens/settings/patient_profile_screen.dart`,
`lib/screens/my_care/widgets/doctor_advice_card.dart`, `lib/screens/care_team/care_team_screen.dart`
(compare `grep -rln "DemoData\." lib` — 16 files — against the 8 `markServingDemoData()` sites).
The care-team and doctor-advice screens are precisely where sample content reads as clinical fact.
- Test isolation note: `isServingDemoData` is mutable global state that only `:178` resets. Any test
  file that trips the flag leaks it into every later file in the same shard.
- **No test renders `_DemoDataBanner`** (`lib/screens/main_shell.dart:64,132-138`). The banner
  widget itself — the entire user-visible half of the fix — is unexercised.

**Would these tests catch a regression of the PHI leak? Partially.** They catch a regression *inside*
any of the five `clearPatientScopedData` methods. They do not catch removal of the call sites, do not
catch a newly-added patient-scoped field, do not catch the storage-level leak, and the one test named
for `switchPatient` cannot fail for its stated reason.

### 8-O. Three new production files with zero tests

`grep -rl "StoreMigrator\|SessionScope\|DemoMode\|store_migrator\|session_scope\|demo_mode" test` →
**one** file, `patient_scope_isolation_test.dart`, and it only imports `DemoMode` to reset it.

| File | LOC | Tests | Failure mode if wrong |
|---|---:|---:|---|
| `lib/services/store_migrator.dart` | 148 | **0** | **silent, permanent loss of a patient's order history** |
| `lib/utils/session_scope.dart` | 44 | **0** | PHI leak (the bug it was written to fix) / runtime `ProviderNotFoundException` |
| `lib/data/demo_mode.dart` | 28 | **0** | sample clinical data presented as the patient's own |
| `lib/screens/settings/delete_account_screen.dart` | 247 | **0** | irreversible destruction of user data on a mis-tap |

### 8-P. ❌ `StoreMigrator` — the one that matters. Never executed, and it already has two defects.

This is code that runs on **every** launch, **before any provider reads storage**
(`lib/main.dart:174`), against **real user data on the first upgrade**, whose stated purpose is to
prevent silent data loss — and it has never been executed by a test. Reading it statically I found
two defects a first-hour test would have caught:

**Defect 1 — the pre-versioning path never writes the stamp.** `run()` (`:74-78`) calls
`_migrateFrom(prefs, 1)`. With `currentVersion == 1` (`:33`), `_migrateFrom` is
`while (version < currentVersion)` (`:100`) → `1 < 1` → **loop body never runs, `setInt` never
executes**. A device with pre-versioning data stays permanently unstamped: the
`Log.warn('Local store has data but no version stamp')` (`:75`) fires on every cold start forever,
and the store's actual state is indistinguishable from "never migrated". The fresh-install branch
(`:71`) stamps correctly; the branch that handles *real upgrading users* does not.

**Defect 2 — a failed migration step still advances the version stamp.** `_migrateFrom` `:106-117`:

```dart
try { await step(prefs); }
catch (e, st) { Log.error('Migration v$version → v${version+1} failed', …);
  // Deliberately continue…
}
version++;
await prefs.setInt(_versionKey, version);
```

The `setInt` is outside the `catch`, so a step that threw halfway leaves the data in the **old** shape
while the store is **labelled** as the new version. The next launch sees `stamped == currentVersion`
and returns at `:81` — the failed step is never retried, and the tolerant readers
(`orders_provider.dart:175-207`, which responds to a decode failure by logging and moving on) will
quietly serve an empty order list. The file's own contract says *"A migration NEVER deletes data it
cannot parse"* (`:22`) — but `quarantine()` (`:126`) is only ever called *by* a step, and the step is
the thing that failed. This is the exact silent-data-loss mode the file exists to prevent, and it is
reachable in the failure case only.

**Defect 3 (lower) — `run()` promises "Never throws" (`:61-62`) but is unguarded.**
`SharedPreferences.getInstance()` at `:64` can throw (platform-channel failure, corrupt store). It is
awaited at `lib/main.dart:174` inside the startup sequence; the `runZonedGuarded` boundary catches it,
but the app reaches the error screen rather than starting — which is precisely the boot loop the
comment at `:112-113` says it is avoiding.

**Defect 4 (lower) — logout deletes the stamp.** `AuthProvider.logout()` does `prefs.clear()`, which
removes `housepital_schema_version` along with everything else. Benign at v1; at v2+ combined with
Defect 1 it means a logged-out-then-logged-in device writes new data with no stamp and relies on the
frozen `_v1Keys` heuristic (`:40-50`) to re-detect it. That heuristic is FROZEN by design, so if all
future data lives under new key names, such a device is misclassified as a fresh install and its data
is stamped at `currentVersion` **without ever being migrated**.

**Exactly the tests it needs** (a new `test/services/store_migrator_test.dart`, all driven by
`SharedPreferences.setMockInitialValues`, no widget tree required — this is a 30-minute file):

| # | Scenario | Setup | Assertions |
|---|---|---|---|
| 1 | **Fresh install** | `setMockInitialValues({})` | after `run()`: `getInt(versionKeyForTest) == currentVersion`; `prefs.getKeys()` contains *only* the version key (nothing else written); a second `run()` is idempotent and writes nothing new |
| 2 | **Pre-versioning install with data** | `{'housepital_orders': '[{"id":"o1"}]', 'theme_mode': 'dark'}`, no stamp | after `run()`: **`getInt(versionKeyForTest) == currentVersion`** (fails today — Defect 1); `getString('housepital_orders')` byte-identical to input; `theme_mode` untouched |
| 3 | **Pre-versioning detection uses the frozen key list** | one test per entry of `_v1Keys`, each alone | each is detected as legacy (not stamped as fresh); a store holding only an *unknown* key is treated as fresh |
| 4 | **Already current** | `{versionKey: currentVersion, 'housepital_orders': '…'}` | `run()` performs zero writes (assert via a `SharedPreferences` spy or by comparing the full key/value map before and after) |
| 5 | **Downgrade** | `{versionKey: currentVersion + 3, 'housepital_orders': '…'}` | stamp is left at `currentVersion + 3`, **not** rewritten downward; no key is modified or deleted; the warn is emitted |
| 6 | **Forward migration runs each step once, in order** | seed `_migrations` with two recording steps via an `@visibleForTesting` injection point (one is needed — the map is `private static final` today); stamp at 1, `currentVersion` 3 | steps run in order 1→2 then 2→3; stamp ends at 3; each step invoked exactly once |
| 7 | **Failing step must not advance the stamp** | step 1→2 throws | **assert `getInt(versionKey) == 1`, i.e. the failure is retried next launch** — fails today (Defect 2). If the "keep booting" behaviour is deliberate, the assertion becomes: stamp stays at 1 **and** a `__failed_v1` marker is written **and** the raw data is quarantined, so the state is recoverable rather than mislabelled |
| 8 | **Missing step is not silently skipped past data** | `_migrations` has no entry for the current version | the warn fires and the stamp advances only if the gap is intentional; assert the data is untouched |
| 9 | **Quarantine copies, never destroys** | `quarantine(prefs, 'housepital_orders', 1)` on a String, an int, a bool, a double and a `List<String>` | for each type: `__quarantine_v1_housepital_orders` holds the original value **and the original key still holds it too** (`quarantine` must not be a move); round-trip equality per type |
| 10 | **Quarantine of an absent key is a no-op** | key not present | no `__quarantine_*` key is created, no warn claiming a quarantine happened |
| 11 | **Quarantine of an unsupported type does not log a false success** | value whose runtime type falls through `:131-141` | either it is copied or the warn at `:142` is **not** emitted — today the log claims a quarantine that did not happen |
| 12 | **`run()` never throws** | a `SharedPreferences` stub whose `getInstance` throws | `expect(StoreMigrator.run(), completes)` — asserts the documented contract at `:61-62` (fails today, Defect 3) |
| 13 | **Ordering guarantee against providers** | integration-style: seed a v1 blob, run `main`'s startup order | the migrator's write happens strictly before `OrdersProvider._loadFromStorage` reads — today this is guaranteed only by the line ordering in `main.dart:174` and nothing asserts it |

Test 2 and test 7 are the two that pay for the file. Both fail against the current implementation.

### 8-Q. ❌ `delete_account_screen.dart` — destructive by design, zero tests

247 LOC, routed at `lib/main.dart:745-747`, reachable from Settings
(`settings_screen.dart:278`), and it calls `SessionScope.clearSession(context)` +
`AuthProvider.logout()` → `prefs.clear()` (`:64-65`). No test file references `DeleteAccountScreen`.
The suite has 215 widget tests, and none of them covers the one screen whose purpose is irreversible
destruction. Specifically untested:
- **The double gate holds.** `_canSubmit` (`:48-51`) requires the checkbox **and** the literal word
  `DELETE` (case-insensitive, trimmed). Assert the button is disabled for `''`, `'delete '` → enabled,
  `'DELET'` → disabled, checkbox off + correct word → disabled. Today a one-character edit to `:50`
  could arm the button on any input and nothing would fail.
- **Cancel is safe.** Tapping "Keep my account" (`:102`) must pop without calling `logout()` — assert
  against a spy `AuthProvider` that `logout` was never invoked and `SharedPreferences` is unchanged.
  This is the highest-value single test on the screen.
- **Confirm actually wipes.** Assert `SessionScope.clearSession` ran (all providers empty) *and*
  `prefs.getKeys()` is empty afterwards.
- **The copy does not overclaim.** The class doc (`:17-24`) is explicit that server data is *not*
  erased. Assert the dialog text (`:73-78`) still says "scheduled for deletion … within 30 days" and
  never "deleted" — a golden-string test is appropriate here because the honesty of this string is a
  legal position (DPDP Act §12 / App Store 5.1.1(v)), not cosmetic copy.
- **`_isSubmitting` is set at `:54` and never reset.** If the user backs out of the final dialog, the
  button is permanently a spinner. Untested, minor.
- **Async ordering hazard, untested:** `settings_screen.dart:457-458` calls
  `SessionScope.clearSession(context)` (which triggers `CartProvider.clear()` → async `_persist()`)
  and then `logout()` (async `prefs.clear()`) **without awaiting either**. The two writes race; a
  `_persist` that lands after `prefs.clear()` resurrects a key post-wipe. Harmless today (the cart is
  empty), latent once anything else persists on that path.

### 8-R. Coverage gaps ranked by risk — round 2, new code included

| Risk area | Round 1 | Round 2 | Evidence |
|---|---|---|---|
| **`StoreMigrator` — runs against real data, fails silently** | *(did not exist)* | **❌ none** | `lib/services/store_migrator.dart`; 2 defects found by reading (§8-P) |
| **Order history persistence is not patient-scoped** | *(masked)* | **❌ none** | `orders_provider.dart:11-12,163-172,212-216` — restart-survivable PHI leak + destructive overwrite |
| **`SessionScope` wiring (the actual PHI fix)** | *(did not exist)* | **❌ none** | `session_scope.dart` imported by 0 tests; call sites `home_screen.dart:1771`, `settings_screen.dart:457` |
| **Account deletion (irreversible)** | *(did not exist)* | **❌ none** | `delete_account_screen.dart`; `grep -rl DeleteAccountScreen test` → 0 |
| **Demo-data banner + flag correctness** | *(did not exist)* | **⚠️ 1 flag test, 0 UI tests** | `patient_scope_isolation_test.dart:173`; `main_shell.dart:132` unrendered by any test; 5 fallback sites don't set the flag |
| Quote-vs-priced booking maths (`_priceMultiplier`) | ❌ | **❌ unchanged** | `service_booking_screen.dart:151`; `grep "ultiplier" test` → 1 unrelated hit |
| Priced manpower booking end-to-end | ❌ | **❌ unchanged** | no test builds a manpower `ServiceItem` with `basePriceMin` and pumps the wizard |
| Token refresh 401→refresh→retry | ❌ | **❌ unchanged** | `auth_provider.dart:93` still `FirebaseAuth.instance`; `api_service.dart:88-98` untested |
| Payment fail-closed (`skippedDemo`, real key) | ❌ asserted the bug | **✅ fixed** | `payment_service_test.dart:511-518` |
| Payment demo branch (`payment_service.dart:171`) | ⚠️ | **❌ unreachable + untestable** | §8-M.5 |
| `PaymentScreen` (900 LOC) | ❌ | **❌ unchanged** | `grep -rl "PaymentScreen" test` → 0 |
| 17 payment tests skipped on bare `flutter test` | ⚠️ | **⚠️ unchanged** | 8 `skip: _skipReason` groups |
| Firestore rules (156 LOC) / `storage.rules` (new) | ❌ | **❌ and now worse** | `storage.rules` shipped this commit; still no rules-test harness anywhere |
| Cloud Function `functions/index.js` | ❌ | **❌ unchanged** | no test script in `functions/package.json` |
| Four untested services + `BillingProvider` | ❌ | **⚠️ improved for `BillingProvider` only** | `billing_provider.clearPatientScopedData` now has one test (`patient_scope_isolation_test.dart:148`); `firebase_service`, `sync_service`, `payment_reminder_service`, `voice_service` still 0 |
| Role gates at 31 call sites | ⚠️ 3/31 | **⚠️ unchanged** | |
| PDF generation | ✅ | **✅ unchanged** | |
| SOS | ✅ | **✅ unchanged** | |
| Cart edge cases | ✅ | **✅ unchanged** | |
| Five-tab nav contract | *(six-tab, stale)* | **✅ fixed** | `main_shell_test.dart:233,242,247-251` |

### 8-A. Assertion quality (re-measured)

Scripted over all test bodies (brace-matched, comments stripped):

| Category | Round 1 | Round 2 |
|---|---:|---:|
| `testWidgets` total | 215 | **215** |
| **Inert** — no `tap`/`enterText`/`drag`/`longPress` **and** only `finds*` assertions | 97 | **94** (44%) |
| Tests with no `expect`/`verify` at all | 3 | **3** |

The 97→94 delta is script tolerance, not progress: `git diff --stat` shows only `main_shell_test.dart`
changed among widget-test files, and none of its tests are in either count. Largest inert
concentrations unchanged: `my_care_widgets_test.dart` **28**, `care_team_screen_test.dart` 7,
`quote_pending_surfaces_test.dart` 6, `staff_role_sheet_test.dart` 5,
`assistant_screen_test.dart`/`home_layout_test.dart`/`booking_confirmation_test.dart`/`day_part_header_test.dart` 4 each.

The three assertion-free tests are unchanged: `notification_router_test.dart:91`
(`'null type does not crash'`), `:97` (`'empty data does not crash'`), and
`payment_service_test.dart:281` (`'dispose() can be called across multiple constructions safely'`).
All three pass unconditionally.

### 8-B. Tests that assert a *copy* of production — unchanged, 120 tests

Re-verified per file (`test( count` / `testWidgets count` / `housepital_patient` import count):

```
assessment_form_test.dart      26 / 0 / 0
booking_history_test.dart      20 / 0 / 1   (model import only)
notification_prefs_test.dart   18 / 0 / 0
cart_coupon_test.dart          17 / 0 / 0
equipment_detail_test.dart     17 / 0 / 0
help_faq_test.dart             12 / 0 / 0
service_catalog_test.dart      10 / 0 / 0
                              ───
                              120 tests, 0 widget tests, ~0 production imports
```

Unchanged from round 1 and unaddressed. The refund-policy group
(`booking_history_test.dart:153-199`) still tests a 24-hour refund policy that does not exist in
`lib/` (`grep -rn "refundPercent\|hoursUntil" lib` → nothing), and `:172-180` still passes for the
wrong reason (`.inHours` truncates to 23).

### 8-C. Tests that guard code the app cannot reach — unchanged

Re-verified with a scripted importer check; all six orphans still have zero importers outside
themselves: `booking_state_machine.dart` (24 tests, `TEST_MAP.md:45` `Critical? YES`),
`sync_service.dart`, `login_screen.dart` (19 tests), `billing_summary_section.dart`,
`quick_actions_row.dart`, `catalog_search_bar.dart`. `grep -n "'/login'\|LoginScreen" lib/main.dart`
→ no match; the auth gate is still commented out.

### 8-F. Skipped / gated tests — unchanged

`grep -rn "skip:" test` → still **8**, all `payment_service_test.dart`, all `_skipReason`
(`:189-192`). 17 tests silently skip on a bare `flutter test`, including the M-2 regression **and the
newly-rewritten fail-closed test at `:474`**. That is the sharp edge of round 2: the single most
important new assertion in the commit does not run in the default local command. CI passes
`--dart-define=RAZORPAY_KEY=rzp_test_ci_dummy_key` and is correct.

### 8-G. Determinism — unchanged, one new sleep

`payment_service_test.dart:255` (1200 ms), `:643` (30 ms), `:685` (50 ms) remain wall-clock waits.
`patient_scope_isolation_test.dart:162` adds one more:
`await Future<void>.delayed(const Duration(milliseconds: 20))` to wait for `OrdersProvider`'s
constructor microtask, with a comment explaining it. 20 ms is generous today but it is a race against
a `SharedPreferences` platform-channel round trip on a loaded runner; exposing a
`Future<void> get ready` on the provider would make it deterministic. `api_service_test.dart` still
sleeps ~18 s of real time behind seven 30 s group timeouts.

### 8-H/8-I/8-J/8-K — unchanged from round 1

`test/integration/` is still 4 files / 15 tests, all provider-level. No security tests of any kind
(auth bypass, authz escalation, injection, XSS, CSRF, rate limit) — and `storage.rules` shipping this
commit adds a second untested rules file next to `firestore.rules`. CI coverage gate still
`COVERAGE_THRESHOLD: "50.0"`, global-only, below the documented 60%.

### 8-L. Docs vs the actual test tree — one new class of staleness

Every round-1 item stands (`TEST_MAP.md` inventory says 86 files inside a document claiming 99 — now
100; 9 wrong per-file counts; the 17 skips misattributed to Firebase; `TEST_STRATEGY.md:154` states
the reversed manpower rule as fact; `TEST_STRATEGY.md:5-15` describes four testing tiers that do not
exist). New:
- ❌ `docs/ARCHITECTURE.md:68` — "main_shell.dart # Fixed solid-orange bottom nav bar (**6 tabs**:
  Home/My Care/Services/**Calendar**/Billing/More)" — stale, now five.
- ❌ `docs/SCREEN_MAP.md:6` — "MainShell -- **6 tabs**" — stale.
- ⚠️ `README.md:166` — "services/ # catalog (6 tabs)" — refers to the catalog's own tab bar, not the
  root nav; verify before editing.
- ✅ `docs/CHANGELOG.md:64` is a dated historical entry — correct as history, leave it.
- ❌ Neither `TEST_MAP.md` nor `TEST_STRATEGY.md` mentions `patient_scope_isolation_test.dart`, and
  neither records that `store_migrator.dart` / `session_scope.dart` / `demo_mode.dart` /
  `delete_account_screen.dart` are uncovered. The documents' own "MISSING / Critical? YES" columns
  are the right place for that and were not updated by the commit that created the gap.

---

## Sections 1–7 and 9 (secondary scope)

Unchanged from round 1 except where noted.

### 1. Code Quality & Architecture
- ✅ **`StoreMigrator`, `SessionScope` and `DemoMode` are good architecture** — each is a single
  `abstract final class` with one responsibility, no UI dependency (except `SessionScope`, which takes
  a `BuildContext` by necessity), and each carries a genuinely useful doc comment stating *why* it
  exists and what the failure mode is. `store_migrator.dart:20-25`'s "migration literals are FROZEN"
  rule is the kind of constraint most codebases learn the hard way. The problem is coverage, not design.
- ⚠️ **`SessionScope` couples a utility to `provider` and `BuildContext`** (`:1-2`), so it can only be
  called from a widget and can only be tested with a widget test. A `clearPatientData(List<Clearable>)`
  overload would make it unit-testable and would also let a future non-widget caller (a push handler,
  a deep link) use it.
- ❌ **New DRY violation:** `AppProvider.clearSession` (`app_provider.dart:189-194`) and
  `SessionScope.clearSession` (`session_scope.dart:40-43`) share a name and differ in scope — one
  clears one provider, the other clears six. `delete_account_screen.dart:64` and
  `settings_screen.dart:457` call the second; nothing prevents a future caller reaching for the first
  and clearing only `AppProvider`. Untested either way.
- ❌ Round-1 items stand: 6 orphan files; views hold the data layer (`_priceMultiplier`, coupon rule,
  catalog data inside `State` classes); `service_booking_screen.dart` 3,032 LOC.

### 5. Database & Data Integrity — **downgraded**
- ❌ **NEW: "Migrations are reversible" is now materially worse than "no migration tooling".** Round 1
  graded this ❌ because nothing existed. Round 2 has a migrator whose downgrade branch
  (`store_migrator.dart:83-93`) deliberately does nothing — a defensible choice, clearly reasoned —
  but which is untested, never exercised, and which advances its version stamp past failed steps
  (§8-P Defect 2). An untested migrator is a strictly larger liability than no migrator, because the
  app now *relies* on it having run.
- ❌ **NEW: no data isolation between patients at the storage layer** (§8-N.4).
- ❌ `database/schema.sql` and `firestore.rules` still have no harness; `storage.rules` joins them.

### 6. Error Handling
- ✅ `store_migrator.dart:106-114` catches per-step and keeps booting — correct instinct.
- ⚠️ …but the recovery is incomplete (stamp advances anyway) and untested (§8-P).
- ⚠️ `payment_service_test.dart:610-615` still documents the unfixed async-`open()` swallow.

### 9. Release Readiness
- ✅ **`delete_account_screen.dart` closes a genuine App Store 5.1.1(v) / DPDP §12 blocker** and its
  copy is honest about what it cannot do (`:17-27`, `:73-78`). Shipping the honest version rather
  than claiming server-side erasure is the right call.
- ⚠️ New TODO count: round 1 found 3 TODOs in 54,295 LOC; `delete_account_screen.dart:56`
  (`TODO(backend): POST /account/delete`) makes 4 in 55,067. Scoped and documented, not blocking —
  but it is a TODO on the one screen the App Store reviewer will exercise.
- ❌ Auth gate still commented out; demo payments still default; no test asserts either is off.
- ❌ `docs/TROUBLESHOOTING.md` still has no runbook entry for the two newest failure modes:
  "migration failed on upgrade" and "demo banner stuck on / off".

---

## Blockers (must fix before release)

1. **`StoreMigrator` has never been executed** (`lib/services/store_migrator.dart`) and reading it
   surfaces two defects: the pre-versioning path never writes the version stamp (`:74-78` +
   `:98-100`), and a failed migration step still advances the stamp (`:106-117`), permanently
   mislabelling un-migrated data as migrated. Add `test/services/store_migrator_test.dart` per the
   13-case table in §8-P; cases 2 and 7 fail today.
2. **Order history persistence is not patient-scoped** (`lib/providers/orders_provider.dart:11-12`).
   The PHI fix is in-memory only — patient A's orders return under patient B after a restart, and the
   first order B places overwrites A's history. Key per patient, migrate, and test both directions.
3. **The PHI fix's wiring is untested.** `lib/utils/session_scope.dart` is imported by no test;
   deleting `home_screen.dart:1771` or `settings_screen.dart:457` leaves all 8 new tests green. Add a
   `MultiProvider` widget test per call site.
4. **`_priceMultiplier` still has no test** (`service_booking_screen.dart:151-156`, applied `:2126`,
   `:2477`). Unchanged from round 1.
5. **17 payment tests — now including the newly-written fail-closed guard (`:474`) — are silently
   skipped on a bare `flutter test`.** The most valuable assertion added this commit does not run in
   the default local command. Add `dart_test.yaml` defaults or a `tool/test.sh` wrapper.
6. **Token-refresh recovery is still untested and untestable** (`auth_provider.dart:93`).

## High

7. **`payment_service_test.dart:649` was loosened further than the code required.**
   `expect(successCalled || failure != null, isTrue)` is not a tautology but it accepts the exact
   regression the sibling test forbids; the deterministic assertion was available. Split the test,
   assert `successCalled == false && failure != null`, drop the 30 ms sleep for `_CallbackLatch`, and
   fix the name ("even when channel will fail" — the channel never fails).
8. **`patient_scope_isolation_test.dart:86-106` cannot fail for the reason its name gives.** Rename
   it, and add the assertable version using a per-patient fake API (§8-N.2).
9. **`delete_account_screen.dart` has no test and is destructive by design.** Minimum: the double
   gate, the cancel path, the wipe, and the honesty of the dialog copy (§8-Q).
10. **`payment_service.dart:171-172` is unreachable dead code** — `openCheckout` returns early in demo
    mode, so `_handleSuccess` never runs with `isDemoPayments == true`. Delete or document.
11. **`DemoMode` is globally imprecise and five fallback sites don't set it** — `AppProvider` can take
    the banner down while other providers still serve sample data (`app_provider.dart:247`);
    `blog_provider`, `care_calendar_screen`, `patient_profile_screen`, `doctor_advice_card` and
    `care_team_screen` never call `markServingDemoData()`. The banner widget
    (`main_shell.dart:132`) is rendered by no test.
12. **120 tests still execute zero production code** (§8-B) — unchanged.
13. **The booking state machine is still enforced only in tests**; the refund policy still does not
    exist in `lib/`; four services + `firestore.rules` + the new `storage.rules` + `functions/index.js`
    still have no tests; no security tests of any kind.

## Medium / Low

14. 94 of 215 widget tests (44%) are inert; `my_care_widgets_test.dart` alone is 28.
15. 3 tests contain no assertion at all — unchanged.
16. `docs/ARCHITECTURE.md:68` and `docs/SCREEN_MAP.md:6` still assert six tabs / a Calendar tab.
17. `TEST_MAP.md` / `TEST_STRATEGY.md` were not updated for the new test file or the four new
    uncovered production files; all round-1 staleness stands.
18. `patient_scope_isolation_test.dart:162` adds a 20 ms sleep as a synchronisation primitive; expose
    a `ready` future on `OrdersProvider` instead.
19. `DemoMode.isServingDemoData` is mutable process-global state reset by only one test — cross-file
    leakage hazard.
20. `settings_screen.dart:457-458` fires `SessionScope.clearSession` and `logout()` without awaiting
    either; their `SharedPreferences` writes race. Harmless today, latent.
21. `delete_account_screen.dart:54` sets `_isSubmitting` and never clears it.
22. Round-1 Medium/Low items 15–24 all stand: ~20 s of wall-clock sleeping, 60 `DateTime.now()` uses,
    `test/integration/` misnamed, `i18n_sync_test` cannot catch its own founding bug (160 of 321 keys
    unused), `Validators.numberInRange` untested, cart rental-months clamp untested, 50% coverage gate
    below the 60% target, 6 orphan files.

## BLOCKED-OWNER

- **Suite wall-clock time (<5 min target)** — instructed not to run `flutter test`. Need the central
  run's reported duration.
- **Coverage percentage, global and per module** — needs `coverage/lcov.info` from the central run.
  Specifically needed now: the line coverage of `lib/services/store_migrator.dart`, which I assert is
  0% on static grounds (no test imports it) but cannot prove numerically.
- **Backend/database items (§5)** — schema constraints, indexes, migrations, pooling, server-side
  re-validation, CORS, rate limiting. Need backend repo access or a Firebase emulator run.
- **Whether `storage.rules` / `firestore.rules` are deployed** — the brief states storage rules are
  NOT yet deployed; live posture unknown without Firebase console access.
- **Monitoring/alerting** — needs Crashlytics / Firebase console access.
- **Dependency vulnerability status** — needs `dart pub outdated --mode=security` against the live
  advisory database.
- **Rollback plan validity** — needs a drill against App Store Connect / Play Console.

---

*Read-only audit. No files under `lib/` or `test/` were modified; only this report was rewritten.*
