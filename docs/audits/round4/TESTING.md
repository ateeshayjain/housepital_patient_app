# Software Testing & Quality Verification — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-03 · **Auditor:** Testing module (4th audit) · **Scope:** source review of
`test/**` + the production code it claims to guard (see Limitations)
**Checklist:** `Testing Checklist - App Agnostic` — control family **TST**, Suite v2.0,
verified 8 August 2026, **12 families / 58 numbered controls**
**Prior:** round 3 = `docs/audits/round3/TESTING_AUDIT.md` vs `9a80fe2`; round 2 =
`docs/audits/TESTING_AUDIT.md` vs `820060b`; round 1 recoverable at `9c39dc1`
**Method:** `git diff 9a80fe2..9127713`, full read of every changed test file and the
production file it targets, `grep`/`rg`, and brace-matching scripts over `test/**/*_test.dart`
for every count in this report. Per the brief I did **not** run `flutter test`,
`flutter build` or `flutter analyze`.

---

## Applicability

MASTER-2.04 makes this module always-required; it is not conditional. It applies here with
extra force because the app is a **demo-data build with no reachable backend**
(`api.housepital.in` does not resolve — `CLAUDE.md`), so the automated suite is the *only*
verification layer that runs at all. There is no staging environment, no E2E harness, no
device matrix and no production traffic. Whatever the tests do not assert is not asserted by
anything.

**No TST control is graded N/A.** Every one applies, including the backend-facing controls:
`../housepital-backend` (Firebase Functions + MySQL) and `../housepital-api` (Laravel) are
in scope per MASTER-3.07, and "not tested is not N/A".

### Checklist-version note (requested)

I was given a **`.txt` export** of the checklist, not the `.docx` and not the `.pdf`, so I
**cannot diff the two source formats** — that comparison is unverified and I will not assert
it. What I *can* establish from the artifacts in the repo:

- Round 3 graded against a document titled **"Software Testing & Code Quality Checklist
  (App-Agnostic)"** with **nine unnumbered sections** (its own scorecard,
  `round3/TESTING_AUDIT.md:379-390`, names them: Code Quality & Architecture · Input
  Validation · Concurrency · Security · Database · Error Handling · Logging · Testing ·
  Release Readiness). **No TST-numbered control appears anywhere in round 3's report.**
- The v2.0 file supplied for round 4 is titled **"Software Testing & Quality Verification
  Checklist (App-Agnostic)"**, control family **TST**, 12 families, 58 controls, with a
  revision-history row: *"2.0 | 8 August 2026 | Standardized audit format; evidence and
  decision mechanics added; identified coverage gaps incorporated."*

**Consequence: all 58 TST controls are being graded for the first time.** The families with
no counterpart at all in round 3's nine sections — i.e. genuinely uncovered ground, which is
what the brief asks me to name — are:

| Never covered by any prior round | Controls |
|---|---|
| §1 Test strategy and traceability | TST-1.01 … 1.06 (6) |
| §6 Platform, device, and lifecycle | TST-6.01 … 6.04 (4) |
| §8 Accessibility, content, localization *(as a testing control)* | TST-8.01 … 8.04 (4) |
| §11 Exploratory, usability, recovery | TST-11.01 … 11.04 (4) |
| §12 Test infrastructure, evidence, release exit | TST-12.01 … 12.06 (6) |
| Individually new | TST-3.04 (property/fuzz/mutation), 4.02 (contract compat), 4.04 (third-party failure simulation), 7.03/7.04/7.05 (migration paths, backup/deletion, multi-device), 9.02 (load), 9.04 (failover), 10.05 (consent/deletion/retention) |

**32 of 58 controls (55%) had no prior-round grading.** Round 3's "Testing" section maps
roughly onto TST-3.x and TST-5.x only.

---

## Prior-round status

Round 3's own numbering (B = blocker, H = high, M = medium).

| Round-3 finding | Status now | Evidence |
|---|---|---|
| **B1** `StoreMigrator`'s failed-step repair untestable (`_migrations` private + empty) | **Closed in substance** (one residue, §R4-2) | `store_migrator.dart:90-104` `debugSetMigrations`/`debugResetMigrations`; three new tests `store_migrator_test.dart:183-236`. The advance-on-failure defect is now pinned |
| **B2** Order history destroyed, not scoped; a test asserted the destruction | **Fixed, and the test inverted** (§R4-1) | Keys now `housepital_orders_<id>` (`orders_provider.dart:22-23`); `clearPatientScopedData` is memory-only (`:258-263`); v1→v2 quarantine step (`store_migrator.dart:65-73`); the old assertion is gone, replaced by `patient_scope_isolation_test.dart:270-334` |
| **B3** `SessionScope` imported by zero tests | **STILL ZERO — fourth round, and now FOUR call sites** | `grep -rn "SessionScope" test/` → **1 hit, a comment** (`patient_scope_isolation_test.dart:12`). `grep -rn "session_scope" test/` → **0**. Sites: `main_shell.dart:40`, `home_screen.dart:1774`, `settings_screen.dart:460`, `delete_account_screen.dart:143` |
| **B4** `_priceMultiplier` untested | **Unchanged — fourth round** | `grep -rn "priceMultiplier" test/` → **0**. `service_booking_screen.dart:151-156` |
| **B5** 17 payment tests skip on a bare `flutter test` | **Unchanged** | Scripted count over the `skip: _skipReason` groups = **17**. No `dart_test.yaml`. CI *does* pass the dart-define (`ci.yml`), so this is a local-run gap, not a CI gap |
| **B6** Token-refresh recovery untestable | **Unchanged** | `auth_provider.dart:93` still `FirebaseAuth.instance.currentUser` |
| **H7/H11** `payment_service_test.dart:649` over-loosened | **Unchanged — and the justification was strengthened** | `:649` still `expect(successCalled \|\| failure != null, isTrue)`; the 30 ms sleep at `:643` remains; the comment at `:646-648` now reads "Any outcome is fine here" — the loosening is now documented as intentional while `:511` forbids the same outcome |
| **H8/12** `switchPatient` test cannot fail for its stated reason | **Unchanged, third round** | `patient_scope_isolation_test.dart:128-148` substantively identical; `_SwitchingApi` (`:71-85`) still pointed at `loadPatients` |
| **H9** `delete_account_screen.dart` destructive, 0 tests | **Unchanged** | 325 LOC; `user.delete()` at `:131`; gate is `_canSubmit` (`:72-76`); `grep -rln "delete_account" test/` → only an unrelated permission string |
| **H10** `payment_service.dart` demo branch structurally unreachable | **Unchanged** | `openCheckout` returns at `:113-123` when `isDemoPayments`, so `_handleSuccess` never runs in a demo build; the `if (isDemoPayments)` inside `skippedDemo` (`:175`) is dead |
| **H13** `DemoMode` set semantics untested; banner unrendered | **Unchanged, and the source list grew** | `grep -rln "DemoDataBanner" test/` → **0**. `DemoMode` referenced by exactly one test file. 12 source constants, of which **`sourceCareTeam`, `sourceCareCalendar`, `sourceProfile` are declared and never marked** — the precise failure `CLAUDE.md` warns about. `markServingLiveData` has **2 call sites for 12 sources** |
| **H14** `Cart`/`Orders` clears un-awaitable by `SessionScope` | **Half closed** | `OrdersProvider.clearPatientScopedData` (`:258`) no longer persists at all, so its race is gone. `CartProvider.clearPatientScopedData` (`:210-215`) is still `void` over a fire-and-forget `_persist()`, so `session_scope.dart:91-92`'s comment remains false for the cart |
| **H15** `loadPatients` same-identity guard untested in the negative | **Unchanged** | `app_provider.dart:171` `changed` guard; no test asserts a same-identity reload does *not* clear |
| **H16** 6 orphan `lib/` files; no security tests; no rules harness | **Unchanged** | Scripted: 6 files with zero importers — `booking_state_machine.dart`, `login_screen.dart`, `billing_summary_section.dart`, `quick_actions_row.dart`, `catalog_search_bar.dart`, `sync_service.dart`. `firestore.rules`, `storage.rules`, `functions/index.js` still have no harness |
| **M17** 93/216 widget tests inert | **Not reproducible; re-baselined** (§R4-5) | Round 3's rule is not stated and I cannot re-derive 93 from the source. Three defined measures given instead |
| **M18** 3 assertion-free tests | **Unchanged, exactly 3** | `notification_router_test.dart:91,97`; `payment_service_test.dart:281` |
| **M19** `TEST_MAP.md`/`TEST_STRATEGY.md` don't know the new files | **Partly fixed — genuinely** | `TEST_MAP.md:307-317` now lists both new test files *and* an explicit "Known test-quality gaps carried from round 3" block naming `SessionScope`, `demo_mode`, `demo_data_banner`, `delete_account`, the ~120 copy-tests and the 17 skips. `TEST_STRATEGY.md` still mentions none (grep → 0) |
| **M20** 20 ms sleeps as a sync primitive (4 in the isolation file) | **WORSE — now 8 in that file, 64 `.delayed(` sites suite-wide** | `patient_scope_isolation_test.dart:204, 260, 281, 287, 298, 313, 319, 325` |
| **M21** `hi.json` gate word identical to English | **Unchanged** | `en.json:339` and `hi.json:339` both `"DELETE"`, contradicting `delete_account_screen.dart:68-69` |
| **M22** Cross-file hardcoded key duplication guarding the deletion record | **Unchanged** | `auth_provider.dart:232-233` literals vs `delete_account_screen.dart:60` and `store_migrator.dart:36` |
| **M23** CI gate 50% vs documented 60% | **Unchanged** | `ci.yml` `COVERAGE_THRESHOLD: "50.0"`; `docs/TEST_STRATEGY.md:148` "Overall | 60%+" |

**Verdict on the trajectory the brief asks about.** Round 1→2 found *surfaces*; round 2→3
found *half-wires*. Round 4 is **neither, and both**: the two defects that were given tests
this round were fixed properly *and* pinned properly — that is the first time in four rounds
that a repair and its guard both landed. But the other two defects fixed in the same commit
(`PaymentFailure`, `cancelAllReminders`) and the fan-out that carries all of them
(`SessionScope`) received **zero** tests, and the per-patient keying is **not reached at all
in the shipped build** (§R4-1c). So the pattern this round is: *correct repairs, correctly
guarded where a guard was written, wired to nothing that a test or the shipped build
exercises.* Half-wire, one layer down.

---

## R4-1. The replaced orders tests — do they pin the contract, or would they survive the bug?

Round 3's blocker: storage keyed globally, and `clearPatientScopedData()` calling
`_persistAndNotify()` so every patient switch wrote `[]` over the outgoing patient's real
history — with `patient_scope_isolation_test.dart:273` asserting the destruction.

Both replacement tests **fail if that bug is restored.** Judged individually:

### (a) `'a patient switch PRESERVES each patient's own order history'` (`:270-308`) — real, with two soft assertions

Restore the bug (global `housepital_orders`, clear persists):
`expect(prefs.getString('housepital_orders_pat_a'), isNotNull)` (`:304`) fails, because the
key would not exist; and `expect(bOrders, isNot(aCount))` (`:306`) fails, because both
patients would read the same key. **The test dies twice over.** The keying is genuinely
pinned.

Two assertions inside it, however, do not do what their comments claim:

1. **`:293` — `expect(orders.orders.any((o) => o['id'] == null), isFalse)`** sits under the
   comment *"Switch to B: A's orders must leave the screen"* and asserts nothing of the
   kind. After `setPatient('pat_b')`, `_loadFromStorage` finds nothing and re-seeds
   `DemoData.orders` (`orders_provider.dart:235-238`), all three of which have ids. The
   assertion is true whatever `setPatient` does. Make `setPatient` a no-op that keeps A's
   list in memory and `:293` still passes — only the count inequality at `:306` catches it.
   The direct assertion was available and one line long:
   `expect(orders.orders.any((o) => o['id'] == 'HPL-BOOK-A1'), isFalse)`. This is round 3's
   own criticism of `store_migrator_test.dart:57-70` — *a test written from the narrative of
   a bug rather than from a state the bug produces* — reappearing in the replacement for the
   test round 3 condemned.
2. **`:306` — `expect(bOrders, isNot(aCount))`** is identity asserted by arithmetic.
   `aCount == 4` (3 demo seeds + 1 real order) and `bOrders == 3` (the demo seeds again).
   The test says "B must not inherit A's orders" and checks `3 != 4`.

**And it certifies an unintended behaviour, exactly as its predecessor did — more mildly.**
`_persistAndNotify` (`:201-211`) writes the *whole* in-memory list, demo seed included. The
test waits 20 ms so the seed lands (`:281`), adds one real order (`:282-286`), and then, after
switching away and back, asserts `orders.orders.length == aCount` (`:299`) — an assertion
that **can only pass because the three `DemoData` orders round-tripped through disk**.
`docs/ARCHITECTURE.md` and `CLAUDE.md` both state "demo orders are never written to storage
(a test asserts this)"; the test that asserts it
(`orders_persistence_test.dart:244`) only covers the case where no real order was ever
placed. From the first real checkout onward, three fabricated ₹29,999-class rental orders are
persisted under the patient's own key and are indistinguishable from their real history.
That is a **new defect**, and a new test asserts its result as correct.

### (b) `'clearPatientScopedData does NOT write over stored orders'` (`:310-334`) — real, one assertion short

Restore the bug and `expect(stored, isNotNull)` (`:322`) fails at the seed step. Real.

It pins the *harmful* half but not the stated contract. `clearPatientScopedData` sets
`_patientId = null` **before** returning (`:261`). If a future edit re-adds
`_persistAndNotify()` at the natural place — the end of the method — the write lands on
`housepital_orders__none` and `housepital_orders_pat_a` is untouched, so **the test passes
while the clear persists again**. The method's doc comment says "Deliberately does NOT
persist" (`:253`); nothing asserts that. A `p.getKeys()` (or full key→value map) comparison
before and after would have covered it — which is precisely the fix round 3 asked for on
`store_migrator_test.dart:85-96` ("asserts state, not write count") and which was not carried
across.

### (c) The finding neither test can see: **the per-patient keying is unreached in the shipped build**

- `main.dart:214` constructs `OrdersProvider()` with **no** `patientId`, so `_ordersKey`
  resolves to `housepital_orders__none` (`orders_provider.dart:33`).
- The only thing that ever supplies one is `SessionScope._adopt` → `setPatient`
  (`session_scope.dart:76`), reached only from `AppProvider.onPatientChanged`
  (`app_provider.dart:63`), fired only by `_announcePatient` (`:64-68`).
- `_announcePatient` has two callers: `switchPatient` (`:194`), whose only call site in the
  whole app is the Home switch sheet (`home_screen.dart:1775`); and `loadPatients`
  (`:178`), **inside the `try` that the unreachable API throws out of** (`:151-183`).

So in the shipped demo build — the configuration `CLAUDE.md` says the app runs in — every
order is written under one key, `housepital_orders__none`, for every patient, unless and
until the user opens the switch sheet. The repair is correct in the provider and **inert at
runtime**. Every one of the six tests that exercises it constructs
`OrdersProvider(patientId: …)`, a form **no production call site uses**.

This is the round-3 half-wire pattern reproduced exactly: the store is right, the thing that
points it at a patient is untested (`SessionScope`, zero test imports, fourth round) and, in
the build that ships, never fires.

**Verdict:** Both tests pin the contract against the round-3 bug. Neither is airtight, one
certifies a new persistence defect, and the wiring that would make either matter in
production is verified by nothing.

---

## R4-2. `debugSetMigrations` and the three loop tests — do they pin the DEFECTS?

The question the brief asks is the right one: *would each fail if its guard were deleted?*
The guard is two statements inside the `catch` at `store_migrator.dart:166-178` —
`await prefs.setInt(_versionKey, version);` and `return;` — plus the per-step stamp at `:181`.

| Test | Pins the historical defect? | Pins the guard's own lines? |
|---|---|---|
| `'a FAILING step stops at the last good version and does not advance'` (`:183-200`) | **Yes.** Change the catch to `setInt(_versionKey, version + 1)`, or delete the `return` so the loop continues — `:194` or `:198` fails | **No.** The fixture seeds `versionKey: 1` and the guard writes `1`. **Delete `store_migrator.dart:176` and both assertions still pass**, because the seeded value is already the asserted value. Delete the whole try/catch and the exception escapes to `run()`'s catch (`:116`), the stamp stays `1`, and the test is still green |
| `'the failed step is RETRIED on the next launch'` (`:202-219`) | **Yes, and this is the strongest of the three.** Stamp `version + 1` on failure → run #2 early-returns at `:139` → `attempts` stays 1 → `:217` fails. This is the exact silent-data-loss defect, and this test is what closes round-3 blocker 1 | **No.** Same reason: remove the try/catch entirely and the stamp is untouched at `1`, run #2 retries, `attempts == 2`, green |
| `'steps run IN ORDER and each one advances the stamp'` (`:221-236`) | **Ordering: yes** (`:234`). If `version++` were removed the test hangs, which fails | **No — and the name overclaims.** "each one advances the stamp" is asserted by nothing: **delete the per-step `await prefs.setInt(_versionKey, version)` at `:181`** and the unconditional terminal stamp at `:187` still writes `2`, so `:235` passes. The per-step stamp is what makes a multi-step migration resumable after a crash. One line inside the injected step — `expect(p.getInt(versionKey), 0)` — would have covered it |

**The scenario none of the three covers, and it is the one that matters.** The catch's
`setInt(_versionKey, version)` is load-bearing in exactly one path: entry from the
*pre-versioning* branch, `_run` `:135` → `_migrateFrom(prefs, 1)` with **no stamp on disk**.
If step 1 throws there, deleting `:176` leaves the device with no version key at all, so it
re-enters the pre-versioning branch on **every launch, forever** — round 3's Defect 1
returning through Defect 2's door. All three tests seed an integer stamp first, so none can
see it. The fixture change is one line: `setMockInitialValues({'housepital_orders': '[]'})`
with no `versionKey`, then assert `p.getInt(versionKey)` is non-null after a failing step 1.

**Net:** round-3 blocker 1 is **closed in substance** — the loop is reachable, the
advance-on-failure defect is genuinely pinned by two independent tests, and that is the most
substantive test-quality gain in four rounds. One residue (above) is open, and two of the
three tests are one assertion short of guarding the lines they are named for.

### Can the `@visibleForTesting` hooks corrupt production state?

**Not today — and the only thing preventing it is a warning this project's CI explicitly
does not treat as fatal.**

- `_migrations` (`:81`) is `static final` but **mutable**: `debugSetMigrations` (`:93-95`)
  does `..clear()..addAll(steps)` **in place**, so any call permanently replaces the shipped
  migration table for the life of the process.
- `@visibleForTesting` raises `invalid_use_of_visible_for_testing_member`, an analyzer
  **warning**. CI runs `flutter analyze --no-fatal-warnings --no-fatal-infos`
  (`.github/workflows/ci.yml`, with a written rationale about a ~284-item deprecation
  backlog). **A production call to `debugSetMigrations` would not fail CI.** That is the
  hole, and it is one CI flag wide.
- `versionKeyForTest` (`:225`) is a public getter with **no annotation at all** — same door,
  read-only, harmless in itself.
- Neither hook is guarded by `kDebugMode` or wrapped in an `assert(() { … }())`, so neither
  is structurally excluded from a release build; they survive only by having no callers
  (verified: `grep -rn "debugSetMigrations\|debugResetMigrations" lib/` → declarations only).
- **Credit where due:** `_buildShippedMigrations()` being a *function* rather than a field
  initialiser (`:46-55`, with the reason written down) is a correct and non-obvious
  precaution — it is what makes `debugResetMigrations` restore a genuinely fresh table
  instead of a mutated one.
- **Test-suite hygiene:** `tearDown(StoreMigrator.debugResetMigrations)` is registered at
  group scope (`:181`) and therefore runs after each of the three tests including on failure;
  the `v1 -> v2` group that follows depends on the shipped step and passes centrally, so the
  restore is transitively demonstrated. Nothing asserts it *directly*, and there is no
  tripwire if a future test calls `debugSetMigrations` from outside that group.

**Minimum fix (5 minutes):** drop `--no-fatal-warnings` from the CI analyze step, or guard
both hooks with `assert(() { … return true; }())`.

---

## R4-3. `SessionScope` — is it now imported by any test?

**No. Zero. Fourth round.**

```
$ grep -rn "SessionScope" test/
test/providers/patient_scope_isolation_test.dart:12:// If a provider gains new patient-scoped state, add it to SessionScope AND
$ grep -rn "session_scope" test/
(no output)
```

One hit, and it is a comment. **The criticism stands verbatim for a fourth consecutive
round, and the surface it guards grew from three call sites to four** —
`main_shell.dart:40` (`install`, new this round), `home_screen.dart:1774`,
`settings_screen.dart:460`, `delete_account_screen.dart:143`. Delete any one and all 1,819
tests stay green.

This round made it materially more load-bearing, not less:

- `install()` (`:61-71`) is the **only** thing that connects `AppProvider.onPatientChanged`
  to anything. It is called once, from `MainShell.initState` (`main_shell.dart:40`), behind
  an `if (mounted)`. If that line is deleted or the shell is not the first frame's root,
  every patient switch silently stops fanning out and `OrdersProvider` never learns the
  patient id. **No test mounts `MainShell` and asserts the hook is installed.**
- `_adopt` (`:73-77`) is invoked via `unawaited(...)` (`:69`) — fire-and-forget across an
  `await` boundary with a `context.mounted` check in between. Nothing tests the disposal
  race.
- `clearPatientData` (`:81-107`) makes **eight** `context.read` calls. Any subtree missing a
  provider throws `ProviderNotFoundException` — including `delete_account_screen`, a route
  pushed from Settings. A `MultiProvider` widget test per call site is the whole fix.
- `cancelAllReminders()` (`:100`) — the OS-notification leak fixed in `13e3656`, the only PHI
  leak in this workstream that escapes the app entirely — is called from here and **asserted
  by no test**.

`docs/TEST_MAP.md:313-314` now states this gap in the repo's own words, which is honest
documentation of an open defect, not a fix.

---

## R4-4. The still-untested files, ranked, with the minimum test for each

Ranked by *expected harm × likelihood a silent edit reaches production*.

| Rank | File / surface | LOC | Why here | Minimum test |
|---|---|---:|---|---|
| **1** | `lib/utils/session_scope.dart` | 139 | Promoted above `delete_account` this round. It is now the **single fan-out point for every patient switch**, it owns the OS-notification cancel, it makes 8 `context.read` calls that can throw, and its `install()` is one deletable line between a correct provider and an inert one (§R4-1c). Four call sites, zero tests, four rounds | One widget test: `MultiProvider` with all 11 providers → `MainShell` → assert `app.onPatientChanged != null`; then fire a switch and assert `OrdersProvider.patientId` changed **and** `MedicationReminderService.cancelAllReminders` was called (inject a fake). ~40 lines, closes rank 1 and half of rank 4 |
| **2** | `lib/screens/settings/delete_account_screen.dart` | 325 | Irreversible: `user.delete()` at `:131` destroys the Firebase credential; `:143` wipes local storage. The entire gate is one boolean (`_canSubmit`, `:72-76`) whose confirm word is a **localized JSON lookup** (`:70`) where `hi.json:339 == en.json:339 == "DELETE"`, contradicting the class doc at `:68-69`. The durable deletion record survives only because `auth_provider.dart:232-233` repeats two key literals owned elsewhere (`:60`, `store_migrator.dart:36`) | Two tests, ~20 lines total: (a) `expect(AuthProvider.preservedKeys, contains(DeleteAccountScreen.pendingDeletionKey))` — a constant-identity assertion that makes the rename impossible to get wrong; (b) a widget test that types the wrong word and asserts the destructive button stays disabled |
| **3** | `PaymentFailure` branch — `payment_service.dart:147/182/189/224` ↔ `payment_screen.dart:288` | ~45 | **New this round and completely untested.** `grep -rn "PaymentFailure" test/` → **0**. The typed enum is a genuinely correct fix for round 3's string coupling — and the test file changed *only* to widen every callback to `(m, _)` and `(_, _)`, discarding the kind in all 11 places. The branch decides whether a patient whose **card has already been debited** is shown a Retry button (`payment_screen.dart:292`, `:611-634`). Coverage before the fix: zero. After: zero | Three unit tests on the service, no widget needed: assert `openCheckout` failure carries `notStarted` when `_razorpay.open` throws; `declined` from `_handleError`; `unverified` from the `skippedDemo`-with-real-key path. Then one screen test: `unverified` → no Retry button. These land in `payment_service_test.dart`, so they also need `dart_test.yaml` (blocker 5) or they will not run locally |
| **4** | `lib/data/demo_mode.dart` | 68 | Gates a clinical warning. The per-source `Set` — the entire reason for the rewrite — has **no test**. Worse this round: **12 source constants, 3 of which are declared and never marked** (`sourceCareTeam`, `sourceCareCalendar`, `sourceProfile`), which `CLAUDE.md` names as the exact failure mode ("an unused constant … makes the list read complete when it isn't"); and `markServingLiveData` has **2 call sites for 12 sources**, so the banner is sticky for 10 of them | Four lines: `markServingDemoData(sourceDashboard); markServingDemoData(sourceMedications); markServingLiveData(sourceDashboard); expect(DemoMode.isServingDemoData.value, isTrue);`. Plus one guard test: assert every `source*` constant appears in at least one `markServingDemoData` call site (a reflection-free string scan of `lib/` is acceptable and would have caught all three) |
| **5** | `lib/widgets/demo_data_banner.dart` | 136 | The user-visible half of #4, rendered by **no test**. Unexercised: the `serving == false` short-circuit (`:38`), the `Positioned(top: padding.top + kToolbarHeight + 4)` overlay maths (`:45`) that is the known Settings occlusion, and `SemanticsService.sendAnnouncement` in `initState` — a `liveRegion` announcement wrapped around an `ExcludeSemantics` subtree, with an `l == null` early return that makes it conditional on localization-delegate timing | Two widget tests: pump with `DemoMode` empty → assert `_DemoDataPill` absent and **the child's rect is byte-identical** to the no-banner case (this is the layout-neutrality contract in `CLAUDE.md`); pump with a source set → assert the pill renders and a `SemanticsService` announcement fired once |

Rationale for promoting `session_scope` to #1 over round 3's ordering: `delete_account`'s
failure is unrecoverable *for one user who deliberately triggered it*; `session_scope`'s
failure is silent, affects every user on every switch, and — as §R4-1c shows — is now the
difference between a correct storage repair and an inert one.

---

## R4-5. Re-count: inert widget tests, zero-production-code tests, skipped groups, assertion-free tests

**Suite metrics** (all scripted over `test/**/*_test.dart` at `9127713`):

| Metric | R1 | R2 | R3 | **R4** |
|---|---:|---:|---:|---:|
| Test files (excl. 3 mock helpers) | 99 | 100 | 101 | **101** |
| `test(` + `testWidgets(` call sites | 1,372 | 1,380 | 1,396 | **1,402** |
| `testWidgets` | 215 | 215 | 216 | **216** |
| Test LOC | 23,530 | 24,093 | 24,418 | **24,586** |
| `lib/` LOC | 54,295 | 55,067 | 55,591 | **55,833** |
| `.delayed(` sites | — | — | — | **64** |
| `DateTime.now()` in tests | — | ~60 | ~60 | **60** |

### Inert widget tests — round 3's 93/216 is **not reproducible**; re-baselined

Round 3 reported "93/216 (43%) inert" and "`my_care_widgets_test.dart` alone is 28" without
stating the rule. I could not re-derive 93 under any rule I tried, and
`my_care_widgets_test.dart` in fact pumps three real production widgets
(`HealthManagerBanner`, `ActiveServiceCard`, `StaffAttendanceSection`, imported at `:14-17`),
so calling its 34 tests inert appears to be wrong. **A metric no one else can re-derive is
not evidence**, so I replace it with three stated, scripted measures:

| Measure | Count | Rule |
|---|---:|---|
| **A. No `pumpWidget` anywhere reachable** | **21 / 216 (9.7%)** | Body contains no `pumpWidget` and calls no file-local helper that does. `dark_mode_sweep_test.dart` 7, `overflow_smoke_test.dart` 7, `quote_pending_surfaces_test.dart` 6, `glass_app_bar_test.dart` 1. These are `testWidgets` used as a plain `test` |
| **B. No literal `pumpWidget` in the test body** | **102 / 216 (47%)** | The likely shape of round 3's number. Most of the 81 difference are legitimate — a `_host(...)`/`_pump(...)` helper — so B on its own overstates the problem |
| **C. Widget tests in files that import zero production code** | **0** | Every file containing `testWidgets` imports at least one `lib/` symbol |

**Measure A is the honest headline: 21 widget tests do not render anything.**

### Tests that execute zero production code — round 3's 120 is a **substantial undercount; the real figure is 140**

Round 3 listed 7 files totalling 120. My scan finds **13 files with zero
`package:housepital_patient/` imports** plus 2 more whose only import is `config/theme.dart`
or `models/models.dart` and whose logic is likewise re-implemented:

| File | Tests | Prod imports |
|---|---:|---|
| `test/screens/services/assessment_form_test.dart` | 26 | none |
| `test/screens/services/booking_history_test.dart` | 20 | `config/theme.dart` only |
| `test/screens/settings/notification_prefs_test.dart` | 18 | none |
| `test/screens/cart/cart_coupon_test.dart` | 17 | none |
| `test/screens/services/equipment_detail_test.dart` | 17 | none |
| `test/screens/settings/help_faq_test.dart` | 12 | none |
| `test/screens/orders/order_tracking_test.dart` | **10** | none — **not in round 3's list** |
| `test/screens/services/service_catalog_test.dart` | 10 | `models/models.dart` only |
| `test/screens/rental/rental_agreement_test.dart` | **9** | none — **not in round 3's list** |
| `test/screens/billing/emi_test.dart` | **7** | none — **not in round 3's list** |
| `test/screens/settings/referral_test.dart` | **7** | none — **not in round 3's list** |
| `test/screens/services/slot_availability_test.dart` | **6** | none — **not in round 3's list** |
| `test/widgets/paginated_list_test.dart` | **6** | none — **not in round 3's list** |
| `test/screens/rental/return_test.dart` | **5** | none — **not in round 3's list** |
| **Total** | **170** | |
| less `test/screens/services/catalog_navigation_test.dart` (10) and `test/utils/i18n_sync_test.dart` (3, legitimately tests the shipped JSON assets) and the 5 `test/models/*` files (92, legitimately test production model classes via `models/models.dart`) | | |
| **Tests asserting a re-implemented copy of production logic** | **≈140** | |

These files announce it themselves — `"replicated from assessment_request_screen.dart"`
(`assessment_form_test.dart:5`), `"extracted from EmiScreen"` (`emi_test.dart:3`),
`"extracted from ReferralScreen"`, `"extracted from ServiceBookingScreen"`.

**Many are worse than useless — they are tautologies.** `booking_history_test.dart:154-160`:

```dart
final refundPercent = hoursUntil > 24 ? 100 : 50;
expect(refundPercent, 100);
```

The expected value is computed by the same expression that is asserted. No change to any
file in `lib/` can make it fail. And **the policy it documents contradicts the shipped one**:
this group asserts 100%/50% based on *hours until service*, while
`OrdersProvider.cancelOrder` (`:165-198`) implements full-minus-₹100 / 50% based on *hours
since booking*. Round 3 said "a 24-hour policy that does not exist in `lib/`" — a 24-hour
policy *does* now exist; it is a **different** 24-hour policy. The suite therefore certifies
a refund rule the app does not implement, which is a traceability failure (TST-1.02), not
merely dead weight.

### Skipped groups — **17 tests, unchanged**

Scripted over the `skip: _skipReason` groups in `payment_service_test.dart`:
3 + 4 + 1 + 1 + 1 + 3 + 4 = **17** (lines 265, 294, 366, 418, 474, 528, 660). No
`dart_test.yaml` exists. **CI does un-skip them** (`ci.yml` passes
`--dart-define=RAZORPAY_KEY=rzp_test_ci_dummy_key`), so this is a *local*-run gap: a developer
running `flutter test` sees 1,802 pass and never learns that the one genuinely good
fail-closed guard (`:474-523`) did not run. Per TST-12.02 they are also *skipped by
configuration*, not quarantined: **no owner, no issue, no risk assessment, no removal
deadline.**

### Assertion-free tests — **3, unchanged**

`notification_router_test.dart:91`, `:97`; `payment_service_test.dart:281`. Same three for
three rounds.

---

## Control results

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **TST-1.01** Critical journeys/promises/obligations prioritized | **Fail** | No document in the repo names or prioritizes critical journeys (MASTER-1.02 Fail concurs). `docs/TEST_STRATEGY.md` lists layers, not journeys. The suite's actual priorities invert risk: ~140 tests assert re-implemented copies while `_priceMultiplier` (money), `session_scope` (PHI), `delete_account` (irreversible) have zero | Release-blocking. Owner: **OWNER-TBD**. Mitigation: ratify the Product Requirements module's candidate journey list and map each to a named test file |
| **TST-1.02** Requirements trace to verification incl. negative/recovery | **Fail** | No traceability artifact. Negative evidence: `booking_history_test.dart:153-199` asserts a refund policy contradicting `orders_provider.dart:165-198`; `service_booking_screen.dart:151` (`_priceMultiplier`) implements an inviolable business rule with no verification method at all | Release-blocking. **OWNER-TBD** |
| **TST-1.03** Scope states included/excluded platforms, layers, environments, limitations | **Warning** | `docs/TEST_STRATEGY.md` states layers and a coverage target; `docs/TEST_MAP.md:311-317` **now records the known test-quality gaps by name** — a real improvement this round. Still absent: platform/OS/device/locale/data-shape scope, and any statement that no E2E or device tier exists | Reviewers can mistake 1,819 passing tests for journey coverage. **OWNER-TBD**; one paragraph in `TEST_STRATEGY.md` |
| **TST-1.04** Entry/exit criteria: environments, data, suites, defect thresholds, evidence, approvals | **Fail** | No entry/exit criteria anywhere. The one numeric gate contradicts its own doc: `ci.yml` `COVERAGE_THRESHOLD: "50.0"` vs `docs/TEST_STRATEGY.md:148` "Overall 60%+". No defect thresholds, no approvals, no risk-exception process, no named authority (MASTER-1.05 Fail) | Release-blocking; there is no defined condition under which this app is "tested enough". **OWNER-TBD** |
| **TST-1.05** Pyramid/portfolio balance | **Fail** | 1,186 `test(` + 216 `testWidgets`; **0 E2E** (`integration_test/` does not exist; `test/integration/` is four provider-level files with no `pumpWidget`); ~140 tautological tests; 21 widget tests that render nothing. Static analysis and a design gate exist and are clean | The portfolio has a large layer that cannot detect any production change. **OWNER-TBD**: delete or rewrite the 14 copy-test files against real symbols |
| **TST-1.06** Production-like environments; differences and their risks identified | **Fail** | The suite never runs against either backend. `api.housepital.in` does not resolve; no Firebase emulator; `firestore.rules`, `storage.rules` and `functions/index.js` have **no harness**; `functions/` contains no test file. The material difference (`DemoData` fallbacks serve every provider) is documented in `CLAUDE.md` but its **risk** is assessed nowhere | Release-blocking. Everything the app will do against a real backend is unverified. Mitigation: Firebase emulator suite + `@firebase/rules-unit-testing` for the two rules files. **OWNER-TBD** |
| **TST-2.01** Architecture boundaries/dependency direction linted where practical | **Pass** | `flutter_lints` applied via `analysis_options.yaml`; `flutter analyze` reported clean centrally; `scripts/check_design_consistency.sh` is a bespoke cross-cutting gate wired into CI and reported passing. Layering (providers/screens/services/models/data) is consistent | — |
| **TST-2.02** Dead code, unused assets, unsafe debug paths, unreachable flags removed or justified | **Fail** | 6 `lib/` files with zero importers (scripted; `sync_service.dart`, `login_screen.dart`, `booking_state_machine.dart`, 3 widgets). 40.3 MiB unreferenced assets (carried). Unreachable branch: `payment_service.dart:175` `if (isDemoPayments)` inside `_handleSuccess`, which cannot run in a demo build because `openCheckout` returns at `:113-123`. **3 `DemoMode` source constants declared and never marked**. **Unsafe debug path shipped:** `store_migrator.dart:90-104` (see below) | Release-blocking as a family. Mitigation: delete or wire each; the `DemoMode` constants are the dangerous one — they make the source list read complete |
| **TST-2.03** Warnings/type errors/lint/static/secret scans/dep vulns meet approved thresholds | **Warning** | `flutter analyze` clean (central) at `--no-fatal-warnings --no-fatal-infos` with a documented ~284-item backlog (`ci.yml` rationale). **Secret scan re-verified this round:** `git grep -I "sk-ant" $(git rev-list --all)` returns only documentation prose in `functions/README.md:31` and two audit reports — no key on any ref. **No dependency-vulnerability check exists** (`dart pub outdated --mode=security` is in no script or workflow), and no secret scanning runs in CI | Thresholds are approved and met for lint; the dep-vuln half of the control is simply absent. **OWNER-TBD**: add one CI step |
| **TST-2.04** Error/cancellation/timeout/cleanup/concurrency/resource-lifecycle focused review | **Warning** | Real evidence exists: `run()` never-throws (`store_migrator_test.dart:121-130`, genuinely exercises a `TypeError`), corrupt-JSON tolerance (`orders_persistence_test.dart:190-222`), refund clamp (`orders_provider_refund_test.dart:158-186`). Against that: `CartProvider.clearPatientScopedData` (`:210-215`) is `void` over a fire-and-forget `_persist()`, so `session_scope.dart:91-92`'s claim that async stores are "awaited so a caller … cannot race the wipe" is false for the cart; `SessionScope._adopt` is `unawaited` (`:69`); the suite papers over both with 64 `.delayed(` sites | Race is real but narrow (cart contents, not PHI). Mitigation: make `clearPatientScopedData` return `Future<void>` and await it — 2 lines, and it deletes 4 sleeps |
| **TST-2.05** Generated code, schema artifacts, migrations, config, manifests in review + reproducible generation | **Warning** | **Migrations are now genuinely reviewed and tested** — the biggest gain this round (`store_migrator_test.dart`, 13 tests). No reproducible-generation check for any artifact; `lib/config/firebase_options.dart` and `android/app/google-services.json` are tracked with no regeneration test; no manifest assertions (`Info.plist`, `AndroidManifest.xml`) | Mitigation: a plist/manifest snapshot test is ~15 lines and would catch a permission-string regression before review. **OWNER-TBD** |
| **TST-3.01** Business rules, calculations, permissions, validation, state transitions, serialization cover normal/boundary/invalid/error | **Fail** | `_priceMultiplier` (`service_booking_screen.dart:151-156`) — the multiplier that turns a per-day rate-card price into a manpower booking total, an **inviolable business rule** per `CLAUDE.md` — has **zero tests for the fourth round**, and calls `int.parse(_servicePeriod)` unguarded. GST, EMI, coupon and refund arithmetic are "tested" against re-implemented copies (§R4-5). Genuine coverage does exist for `cancelOrder` refunds, `booking_state_machine`, validators and vital ranges | Release-blocking: a silent edit to `_priceMultiplier` mis-charges every manpower booking and nothing fails. Mitigation: 6 tests, ~30 lines, extract the getter or test via the screen |
| **TST-3.02** Tests describe observable behavior, not implementation copies | **Fail** | ~140 tests assert expressions the test file computes itself. Canonical: `booking_history_test.dart:154-160`. These are unfalsifiable by construction | Release-blocking as a quality signal: they inflate the count and the coverage denominator without adding verification |
| **TST-3.03** Time, randomness, locale, device state, storage, network controlled for determinism | **Fail** | **64 `.delayed(` sites** and **60 `DateTime.now()`** uses. `patient_scope_isolation_test.dart` now has **8** bare 20 ms sleeps (`:204,260,281,287,298,313,319,325`) — doubled since round 3 — in the file whose subject is a race between a wipe and a load. ~20 s wall-clock in `api_service_test.dart` (carried). No `fakeAsync`, no injected clock in the tests that need one | Flake risk on loaded CI runners; and per TST-12.02 an unexplained rerun-to-green would be indistinguishable from a fix. Mitigation: `fakeAsync` or return `Future`s from the void clears |
| **TST-3.04** Property-based, fuzz, mutation, combinatorial for parsers/financial/security/state machines | **Fail** | None anywhere. No `package:test`-based property library, no mutation tooling. The two surfaces the control names by example — the storage **migrator/parser** and the **pricing** engine — are exactly the two this report flags | Not release-blocking on its own, but it is why "1,819 tests pass" carries less assurance than it appears to. Mitigation: mutation-test `store_migrator.dart` alone; §R4-2 shows by hand that 3 lines survive deletion |
| **TST-3.05** Every escaped defect gets a regression test at the lowest useful layer, with the fix | **Warning** | **Two of the four defects fixed in `13e3656` got real tests with the fix** — orders (`patient_scope_isolation_test.dart:270-334`, provider layer) and the migration loop (`store_migrator_test.dart:183-236`, service layer). **First-time compliance, and it is genuine.** The other two got none: `PaymentFailure` (`grep -rn "PaymentFailure" test/` → 0) and `cancelAllReminders()` in `SessionScope` (0 tests). The `vitals_screen` `Random(42)` removal also got none (`grep -n "Random\|DemoMode" test/screens/reports/vitals_screen_test.dart` → 0) | 50% compliance on a control that was 0% for three rounds. Mitigation: the three tests in §R4-4 rank 3 |
| **TST-4.01** Client/service, service/DB, cache/source, external-provider boundaries tested with realistic contracts | **Fail** | `test/integration/` is four **provider-level** files (`checkout_flow_test.dart` imports only `cart_provider`, `orders_provider`, `models`) — misnamed, carried from round 1. `api_service_test.dart` tests against a hand-written mock, not a contract. `CacheService` boundary untested at the `SessionScope` call site | Release-blocking. Two incompatible backend schemas (per the brief) with zero contract verification is the single largest unverified surface in the product |
| **TST-4.02** Contract tests for backward/forward compat, unknown fields/enums, defaults, versioning, deprecation | **Fail** | No consumer/provider contract test of any kind. Local tolerance to malformed data *is* tested (corrupt JSON, corrupt version stamp) which is the right instinct; unknown-field/enum-default/deprecation behaviour is not | Release-blocking. When either backend ships, the first schema change is unguarded |
| **TST-4.03** Authn/authz, tenant isolation, idempotency, retries, timeouts, partial failure, duplicate/out-of-order | **Fail** | Auth gate commented out (carried); token refresh untestable (`auth_provider.dart:93`). "Tenant isolation" is the patient-scope suite, which is provider-level only and whose fan-out is untested (§R4-3). Idempotency partially covered — `generateUniqueBookingNumber`'s collision loop *is* tested (`orders_provider_test.dart:58-70`). Timeouts: `loadPatients` has a 5 s timeout (`app_provider.dart:167`) with no test | Release-blocking |
| **TST-4.04** Third-party sandbox + failure simulation (throttling, malformed, slow, revocation, outage) | **Warning** | Real: Razorpay sandbox keys, a `_ThrowingChannel`-style failure path, and one genuinely good fail-closed test (`payment_service_test.dart:474-523` — asserts `successCalled` false, `failureMessage` non-null **and** `fakeApi.verifyCalls` empty). Absent: throttling, slow responses, malformed responses, revocation. Firebase is not simulated at all. And 17 of these tests do not run on a bare `flutter test` | The best-tested integration in the app; the gaps are the failure *modes*, not the happy path. **OWNER-TBD** |
| **TST-4.05** DB constraints, transactions, concurrency, migrations, indexes, pagination, data repair at realistic volume | **Fail** | Local storage migrations now tested (genuine progress, TST-7.03). Nothing else: no backend DB test in either repo reachable from this suite, no volume test, no pagination test (`paginated_list_test.dart` asserts re-implemented constants), no data-repair procedure — note `store_migrator.dart` leaves a corrupt version stamp **unrepaired** in its own catch (`:116-119`), permanently disabling migration on that device | Release-blocking; the corrupt-stamp aftermath is a concrete, silent, permanent per-device failure that the "never throws" test walks past |
| **TST-5.01** E2E for first launch, onboarding, auth, primary journeys, settings, export/deletion, support, purchase | **Fail** | **No E2E harness exists.** `integration_test/` absent; `flutter_driver`/`integration_test` not in `pubspec`. Account deletion — named explicitly by this control — has zero tests of any kind | Release-blocking. Not one end-to-end journey is verified by anything |
| **TST-5.02** Loading, empty, error, offline, stale, permission-denied, partial, destructive, cancellation, interruption, recovery states | **Warning** | Covered: corrupt data, quote-pending surfaces, `reserve_flow_negative_test.dart`, demo fallbacks, `sos_screen_test.dart`. Not covered: offline/reconnect, permission-denied, interruption, and — pointedly — the app's own **stale-data** surface, `DemoDataBanner`, which has 0 tests | **OWNER-TBD**; the banner tests in §R4-4 rank 5 |
| **TST-5.03** Visual regression or reviewed screenshots across devices, appearances, orientations, text sizes, locales | **Fail** | **Zero `matchesGoldenFile` in the entire suite** (grep → 0 files). `overflow_smoke_test.dart` covers 37 screens × 3 widths for *overflow only*; `dark_mode_test.dart`/`dark_mode_sweep_test.dart` cover *tokens*. No orientation, no text-size, no locale, no appearance screenshot evidence. Tests render with Ahem, so nothing in CI has ever seen the real typeface | Release-blocking for a design-led app whose nav shell has been rewritten three times. Mitigation: golden tests for the 8 highest-traffic screens × {light,dark} |
| **TST-5.04** Focus, keyboard, deep links, navigation restoration, modal dismissal, unsaved work, background/foreground | **Fail** | Zero `AppLifecycleState` / `didChangeAppLifecycleState` / deep-link tests (grep → 0 files). The two tests nearest this control (`notification_router_test.dart:91,97`) are **two of the suite's three assertion-free tests**. MASTER-3.04 declares notifications and deep links in scope | Release-blocking. Notification routing is how a medication reminder reaches the right screen |
| **TST-5.05** E2E assertions verify durable outcomes at the authoritative layer | **Warning** | Genuine progress: the two new orders tests and `'reminders are cleared from memory AND disk'` (`:336-348`) assert `SharedPreferences` — the authoritative *local* layer — rather than screen text. But for a phone shared between a patient, a primary contact and family, the authoritative layer is the backend, which nothing reaches | The right instinct applied at the wrong tier. Depends on TST-1.06 |
| **TST-6.01** Risk-based device/OS matrix incl. oldest supported, current, low-end | **Fail** (unverified) | No matrix documented anywhere in the repo. Tests run headless at 320/375/414 logical widths with the Ahem font. `flutter-version: '3.41.2'` is pinned in CI (good), but that is a toolchain, not a device matrix | Release-blocking; unverified rather than known-bad. **OWNER-TBD** |
| **TST-6.02** Install, update, restore, uninstall/reinstall, device migration, account switching, backup restore | **Warning** | Two of the named behaviours now have **real** coverage: *update* (`store_migrator_test.dart` fresh-install / pre-versioning / already-current / downgrade / corrupt-stamp) and *account switching* (`patient_scope_isolation_test.dart`). Absent: restore, reinstall, device migration, backup restore, and any on-device verification of the above | Best-covered control in §6, entirely because of this round's migrator work. **OWNER-TBD** for the device-level half |
| **TST-6.03** Rotation, resizing, multitasking, keyboard, external display, lock/unlock, clock/time-zone, low storage, memory/thermal/battery | **Fail** | None tested. Notable given 60 `DateTime.now()` uses in the suite and a medication-reminder feature: a **time-zone or clock change** is a live hazard for scheduled doses and is verified by nothing | Release-blocking for the reminder feature. **OWNER-TBD** |
| **TST-6.04** Notifications, deep links, widgets, background work, permissions changed in Settings, system-initiated termination | **Fail** | `medication_reminder_test.dart` exists and covers scheduling; but `cancelAllReminders()`, newly wired into `SessionScope` this round to fix an escaping-PHI leak, has **zero tests**. Deep links, background work, permission revocation and system termination: none | Release-blocking. The PHI-escape fix is unverified — a lock-screen notification with a drug name after a handover is the failure mode |
| **TST-7.01** Aged and adversarial datasets: large accounts, sparse, duplicates, corrupted rows, unusual Unicode, deleted parents, legacy schemas | **Warning** | Genuinely present: corrupt orders/assessments JSON, a corrupt version stamp of the wrong *type*, negative and zero `totalAmount`, a legacy (pre-versioning) schema, a future schema. Absent: large accounts, duplicates, unusual Unicode (relevant — Devanagari input is a shipped locale), deleted parents | Meaningful partial coverage. **OWNER-TBD**: a Devanagari + emoji round-trip through orders is 5 lines |
| **TST-7.02** Offline create/edit/delete, reconnect, retry, cancellation, app kill, duplicate/out-of-order delivery converge | **Fail** | The app runs permanently offline and there is no sync layer under test: `lib/services/sync_service.dart` has **zero importers and zero tests**. No reconnect, retry, app-kill or convergence test exists | Release-blocking, and it is the control the orphaned `sync_service.dart` is evidence for |
| **TST-7.03** Migration tests cover every supported historical path, interrupted and resource-constrained execution, checksums/counts, files, settings, keychain | **Warning** | **The most improved control in this module.** Every supported path for a 2-version store is now covered — fresh install (`:30-39`), pre-versioning (`:43-57`), any-key detection (`:59-72`), idempotence (`:74-83`), already-current (`:87-98`), downgrade (`:102-117`), corrupt stamp (`:121-130`), v1→v2 quarantine (`:240-261`), v1→v2 no-op (`:263-271`). **Interrupted execution is now covered too** (`:183-219`) — this closes round-3 blocker 1. Residues: the interrupted **pre-versioning** entry is uncovered and its guard line is deletable (§R4-2); no checksum/count assertions; resource-constrained execution untested; scope beyond `SharedPreferences` (files, keychain) is neither covered nor declared out of scope | One test away from Pass. Mitigation is the one-line fixture change in §R4-2. **OWNER-TBD** |
| **TST-7.04** Backup, restore, export, import, account deletion, retention, DR executed and verified at authoritative storage | **Fail** | Account deletion (`delete_account_screen.dart`, 325 LOC, `user.delete()` at `:131`) has **zero tests**, and the durable deletion record survives only because `auth_provider.dart:232-233` repeats two key literals owned by other files (`delete_account_screen.dart:60`, `store_migrator.dart:36`) that nothing pins. PDF export (`invoice_pdf_service`, `handover_report_service`) *is* tested. No backup/restore/retention verification | Release-blocking with a legal edge (DPDP §12 — the evidence a user asked to be deleted). Mitigation: the 2 tests in §R4-4 rank 2, ~20 lines |
| **TST-7.05** Multi-device: simultaneous edits, version skew, sharing lifecycle, permission changes, conflict resolution, full resync | **Fail** | No multi-device test exists. Two backends with incompatible schemas (per the brief) and a separate staff app write the same entities; `sync_service.dart` is orphaned. MASTER-3.08 declares this in scope | Release-blocking |
| **TST-8.01** Device-by-task accessibility matrix (screen reader, Voice Control, Switch Control, keyboard, focus, larger text, contrast, reduced motion, captions) | **Fail** (unverified) | No matrix in the repo. Dynamic Type clamped at 1.4× (carried, unchanged) | **OWNER-TBD**; needs a device. See the Accessibility module's round-4 report |
| **TST-8.02** Automated a11y checks supplement manual AT testing | **Fail** | **Zero uses of `meetsGuideline` in the entire suite** — Flutter ships `textContrastGuideline`, `androidTapTargetGuideline`, `iOSTapTargetGuideline` and `labeledTapTargetGuideline` and none is called. The one a11y-critical new path this round, `SemanticsService.sendAnnouncement` in `demo_data_banner.dart:74-84` (a `liveRegion` wrapping an `ExcludeSemantics` subtree), is rendered by no test | Release-blocking and cheap to fix: 4 guideline calls in one widget test cover contrast, tap targets and labels across a pumped screen |
| **TST-8.03** Pseudolocalization, RTL, locale fallback, long strings, Unicode, dates, time zones, currency, pluralization, sorting, input methods | **Warning** | `i18n_sync_test.dart` (3 tests) enforces EN/HI key parity — real, and it is the guard that would catch a missing Hindi key. Structurally blind to strings that never became keys: `'Go Back'` / `'Retry Payment'` remain hardcoded in `payment_screen.dart` (carried). No pseudoloc, no long-string, no date/currency/pluralization tests. RTL is N/A for EN+HI but that is nowhere stated | **OWNER-TBD**. A "no hardcoded user-facing literal in `lib/screens`" grep gate would close the structural blind spot |
| **TST-8.04** User-visible copy, notifications, exports, legal text, store metadata proofread and consistent | **Warning** (unverified) | Only key-parity is machine-checked. `delete_account_screen.dart:68-69` documents a rationale that `hi.json:339` contradicts — a proofreading defect that survived three rounds because nothing reads the copy | **OWNER-TBD** |
| **TST-9.01** Startup, interaction, render, memory, energy, disk, network, bundle size, journey budgets measured on representative targets | **Fail** | No performance test, no measurement, no documented budget. `flutter build web --release` runs in CI but its output size is not gated. The suite itself spends ~20 s sleeping | Release-blocking as "unverified". See the Performance module's round-4 report |
| **TST-9.02** Load, spike, stress, soak, capacity, backpressure, cache stampede, quota, dependency degradation | **Fail** | None, in this repo or (per the brief's scope) reachable from it. Both backends are in scope via MASTER-3.07. **Not tested is not N/A** | **OWNER-TBD**; needs a backend environment |
| **TST-9.03** Crash, hang/ANR, watchdog, leak, race, deadlock, retry storm, resource exhaustion investigated and regression-tested | **Fail** | No leak, race or deadlock test. One known race is documented in the source and unguarded: `CartProvider.clearPatientScopedData` fire-and-forget vs `session_scope.dart:91-92`'s claim to have awaited it. `logger.dart:63` remains an unwired TODO, so there is no crash telemetry to regression-test against | Release-blocking. Mitigation: return the `Future`; then the sleeps that hide it can be deleted, which is also the TST-3.03 fix |
| **TST-9.04** Failover, restore, circuit-breaker, data corruption, vendor outage, recovery objectives | **Warning** | The app's entire demo-fallback design **is** an outage path, and it is partially tested: `'demo data is announced, not silently substituted'` (`:215-230`) asserts both the fallback and the honest label. Data-corruption recovery is tested at the storage layer (quarantine, corrupt JSON). **Recovery from the outage is not**: `markServingLiveData` has 2 call sites for 12 sources and 0 tests, so the app has no verified path back from "showing samples" to "showing your record" | The failure mode is a permanent false alarm or, worse, an affirmative all-clear. Mitigation: the 4-line `DemoMode` test in §R4-4 rank 4 |
| **TST-10.01** Threat-model controls verified by review, scanning, abuse tests, config review, independent testing | **Fail** | No threat model in the repo. **No security test of any kind exists in the suite** (carried, three rounds) | Release-blocking. See the Security & Privacy module's round-4 report |
| **TST-10.02** Auth bypass, recovery abuse, escalation, cross-tenant, session fixation/revocation, rate limit, sensitive-action reauth | **Fail** | Auth gate commented out; token refresh untestable. The role/permission layer *is* tested (`permission_test.dart`) — the one bright spot. Cross-tenant = patient isolation, provider-level only, fan-out untested. Sensitive-action reauth: `delete_account`'s gate is a typed word with no reauthentication and no test | Release-blocking |
| **TST-10.03** Injection, XSS, CSRF, SSRF, mass assignment, path traversal, unsafe file/archive, webhook spoofing, replay, unsafe redirects | **Fail** | Client surface is narrow (no HTML render, no SQL) but the backends are in scope and `functions/index.js` has no test harness; `firestore.rules` and `storage.rules` have none either, and `storage.rules` is **undeployed** (carried). File upload from six screens (MASTER-3.09) with no unsafe-file test | Release-blocking. `@firebase/rules-unit-testing` against the emulator is the standard, cheap fix |
| **TST-10.04** Secrets, logs, analytics, backups, notifications, screenshots, caches, pasteboard, deep links, error responses inspected for exposure | **Warning** | `ANTHROPIC_API_KEY` re-verified absent from every ref this round (evidence under TST-2.03). Against that: no test asserts PHI is absent from logs, and `Log.warn` calls carry patient-scoped context throughout; no screenshot-protection or pasteboard test; the OS-notification PHI path (`cancelAllReminders`) is fixed but unverified | **OWNER-TBD**. A log-redaction test is ~15 lines against a `Log` spy — which is also the "witness" round 3 asked for on the never-throws test |
| **TST-10.05** Consent, permission denial, privacy manifests/labels, export, correction, deletion, retention, breach playbooks match documented flows | **Fail** | No consent test, no permission-denial test, no privacy-manifest assertion, and the deletion path is entirely untested (TST-7.04). No `PRIVACY_POLICY.md` or `DATA_HANDLING.md` exists to match flows against (MASTER-1.03 Fail) | Release-blocking with regulatory exposure (DPDP 2023) |
| **TST-11.01** Time-boxed exploratory sessions targeting new risk and changed architecture | **Fail** | No exploratory session record exists in the repo. The nav shell has been rewritten three times and the storage layer twice — precisely the "changed architecture" trigger — with no charter, no session notes, no findings | Not tested is not N/A. **OWNER-TBD**: two 60-minute charters (patient switch on a shared phone; payment failure paths) |
| **TST-11.02** Representative users or domain experts validate comprehension, workflow fit, recovery, trust | **BLOCKED-OWNER** | The master gate records a Release build side-loaded to one device for field review; no record of who used it, what they were asked, or what they found exists in the repo. This is clinical/usability evidence I cannot generate from source | Needs the owner's field-review notes, or a session run. MASTER-3.11 makes specialist review mandatory here |
| **TST-11.03** Interruption, repetition, rapid navigation, stale screens, duplicate action, invalid order, cross-device, support-led recovery | **Fail** | None. Duplicate action is *partially* guarded in production (`generateUniqueBookingNumber`, tested at `orders_provider_test.dart:58-70`) and `_isSubmitting` re-entrancy exists in `delete_account_screen.dart:97,109` — untested. Rapid navigation and stale screens: nothing | Release-blocking for a shared-device app. **OWNER-TBD** |
| **TST-11.04** Findings record reproducible evidence, environment, data, expected/actual, severity, user impact, regression disposition | **Warning** | `docs/KNOWN_ISSUES.md` exists and the four audit rounds are unusually specific (file:line throughout). Missing per the control: no ticket ids, no owners, no severity field, and **no regression-test disposition** — which is why round-3 blockers 3, 4, 5, 6, 7 and 8 could pass a full round untouched with nothing tracking them | **OWNER-TBD**; blocked structurally by MASTER-1.05 (no issue tracker named) |
| **TST-12.01** Tests run in CI with protected required checks; parallelized and tiered without hiding slow high-value coverage | **Warning** | CI is genuinely good: analyze → design gate → `flutter test --coverage --reporter=expanded --dart-define=RAZORPAY_KEY=…` → coverage gate → `build web --release`, with artifact upload. **But the audited commit has never run it**: `ci.yml` triggers on `push: [main]` and `pull_request: [main]` only, and `9127713` is on `fix/five-tab-nav`, ahead of `main`, with no PR (master gate record). Branch protection is not verifiable from source. No tiering or parallelization | Every "the suite passes" claim for this commit rests on a **local** run, not a protected CI check. Mitigation: add `pull_request:` on all branches or open the PR. **OWNER-TBD** |
| **TST-12.02** Flaky tests quarantined only with owner, issue, risk assessment, removal deadline; reruns don't convert failures to passes | **Fail** | 17 tests sit behind `skip: _skipReason` in 7 groups with **no owner, no issue, no risk assessment and no removal deadline** — the control's four named requirements, none met. They are also not flaky; they are configuration-gated, which is a different and less defensible reason to skip. Separately, 64 timing-dependent `.delayed(` sites make an unexplained failure indistinguishable from a flake | Release-blocking as written. Mitigation: a `dart_test.yaml` with `define_platforms`/tags, or drop the gate and let the demo path assert |
| **TST-12.03** Test data synthetic or protected, isolated, reproducible, cleaned; no casual production personal data | **Warning** | Data is synthetic throughout (`DemoData`, fabricated Delhi NCR names and `+9198…` numbers); `SharedPreferences.setMockInitialValues` makes fixtures reproducible; files run in separate isolates. **Isolation is by convention, not by construction:** `DemoMode` is process-global mutable state reset by exactly one test (`patient_scope_isolation_test.dart:220`), and as of this round `StoreMigrator._migrations` is process-global mutable state too, restored only by a group-scoped `tearDown` (`store_migrator_test.dart:181`) with no tripwire if a future test mutates it from outside that group | **OWNER-TBD**. A global `setUp(DemoMode.reset)` in a shared test harness is one line |
| **TST-12.04** Coverage used to find gaps, not as proof; risk-based thresholds paired with mutation/defect/requirement evidence | **Fail** | The enforced gate (50%, `ci.yml`) is **below the project's own documented target** (60%, `TEST_STRATEGY.md:148`), so the green check certifies less than the doc claims. No per-file or risk-based thresholds: the four highest-risk files (`session_scope`, `delete_account_screen`, `demo_data_banner`, `demo_mode`) are at 0% by static inference and no threshold notices. No mutation evidence. Coverage is used as a floor, not as a gap-finder | Release-blocking as a governance defect. Mitigation: per-file minimums for the five files in §R4-4, which is the whole point of the control |
| **TST-12.05** Release record archives commit, artifact, environment, device matrix, automated results, manual evidence, open defects, accepted risks, approvals | **Fail** | No release record exists. `CHANGELOG.md` and `BUILD_LOG.md` exist but archive none of: artifact, environment, device matrix, manual evidence, accepted risks or approvals. No release artifact exists to record (MASTER-4.04) | Release-blocking by definition — the gate cannot be evidenced |
| **TST-12.06** No unresolved blocker, unexplained failing required test, unowned warning, or unsupported declaration at release exit | **Fail** | Eight release blockers are open below; six of round 3's eight are carried unchanged. **Every Warning in this report and in all three prior rounds is unowned** — no risk-acceptance authority is named anywhere in the repo (MASTER-1.05 Fail), so no Warning in this module can be formally accepted by anyone | Release-blocking, structurally. Naming an authority is the single unblocking action |

---

## Scorecard

**Pass 1 · Warning 18 · Fail 38 · N/A 0 (+ BLOCKED-OWNER 1) = 58 controls**

| Family | Pass | Warning | Fail | N/A | BLOCKED |
|---|---:|---:|---:|---:|---:|
| 1. Test strategy and traceability | 0 | 1 | 5 | 0 | 0 |
| 2. Code quality and static verification | 1 | 3 | 1 | 0 | 0 |
| 3. Unit and property-level tests | 0 | 1 | 4 | 0 | 0 |
| 4. Integration, contract, and API tests | 0 | 1 | 4 | 0 | 0 |
| 5. UI, end-to-end, and visual tests | 0 | 2 | 3 | 0 | 0 |
| 6. Platform, device, and lifecycle tests | 0 | 1 | 3 | 0 | 0 |
| 7. Data, offline, migration, and sync tests | 0 | 2 | 3 | 0 | 0 |
| 8. Accessibility, content, and localization tests | 0 | 2 | 2 | 0 | 0 |
| 9. Performance, resilience, and load tests | 0 | 1 | 3 | 0 | 0 |
| 10. Security and privacy tests | 0 | 1 | 4 | 0 | 0 |
| 11. Exploratory, usability, and recovery testing | 0 | 1 | 2 | 0 | 1 |
| 12. Test infrastructure, evidence, release exit | 0 | 2 | 4 | 0 | 0 |
| **Total** | **1** | **18** | **38** | **0** | **1** |

**This is not comparable to round 3's 40/29/33/10** — that was a different, nine-section
document with no TST ids (see Applicability). The comparable statement is the prior-round
status table above: of round 3's 8 blockers, **2 are closed** (B1 in substance, B2 fully),
**6 are carried unchanged** (B3, B4, B5, B6, plus H9 and H10 which round 3 also listed as
blocking-adjacent).

The low Pass count reflects the checklist's breadth, not a collapse in quality. Suite v2.0
grades a *verification programme* — strategy, environments, device matrices, exploratory
charters, release records, evidence archives — and this project has an automated unit/widget
suite and nothing else. The unit-and-widget layer is where all four rounds of work have gone,
and it is where this round produced real gains.

---

## Release blockers (every Fail, consolidated to the 8 that are actionable this week)

1. **`SessionScope` is imported by zero tests — fourth round, now four call sites.**
   `main_shell.dart:40`, `home_screen.dart:1774`, `settings_screen.dart:460`,
   `delete_account_screen.dart:143`. Delete any one and 1,819 tests stay green. Because
   `install()` is the only thing that supplies `OrdersProvider` with a patient id, this is
   now also what makes the per-patient storage repair inert in the shipped build (§R4-1c).
   *(TST-4.03, 10.02, 5.01)*
2. **The per-patient keying is never reached in the shipped demo build.** `main.dart:214`
   constructs `OrdersProvider()` with no id; `_announcePatient` fires only from
   `switchPatient` (one caller) or from inside the `try` that the unreachable API throws out
   of (`app_provider.dart:151-183`). Every order lands under `housepital_orders__none`. No
   test constructs the provider the way production does. *(TST-4.01, 7.05)*
3. **`_priceMultiplier` has no test — fourth round.** `service_booking_screen.dart:151-156`
   turns a per-day rate-card price into a manpower booking total — an inviolable business
   rule — and calls `int.parse` unguarded. *(TST-3.01, 1.02)*
4. **`delete_account_screen.dart` has no test.** 325 LOC, `user.delete()` at `:131` behind
   one boolean, a localized gate word that is identical in both locales, and two cross-file
   hardcoded key duplications guarding the DPDP deletion record. *(TST-7.04, 10.05)*
5. **The new `PaymentFailure` branch has zero coverage.** `grep -rn "PaymentFailure" test/`
   → 0. The test file changed only to discard the new argument (`(m, _)`, 11 sites). The
   branch decides whether an already-debited patient sees a Retry button. *(TST-3.05, 4.04)*
6. **17 payment tests do not run on a bare `flutter test`, and are skipped with no owner,
   issue or deadline.** CI un-skips them; local runs do not. No `dart_test.yaml`.
   *(TST-12.02)*
7. **No E2E, no visual regression, no automated accessibility check, no device matrix.**
   `integration_test/` absent; zero `matchesGoldenFile`; zero `meetsGuideline`; zero
   lifecycle/deep-link tests. *(TST-5.01, 5.03, 5.04, 6.01, 8.02)*
8. **~140 tests assert re-implemented copies of production logic, and one group certifies a
   refund policy the app does not implement.** `booking_history_test.dart:153-199` vs
   `orders_provider.dart:165-198`. *(TST-3.02, 1.02)*

---

## Warnings requiring risk acceptance

Every one is **unowned**, because no risk-acceptance authority is named anywhere in the repo
(MASTER-1.05). Owner field is `OWNER-TBD` throughout; due dates are proposals.

| # | Warning | Impact | Mitigation | Owner / due |
|---|---|---|---|---|
| W1 | Migrator failed-step guard: `store_migrator.dart:176` is deletable with the suite green; the interrupted **pre-versioning** path is uncovered | A device that fails step 1 with no prior stamp re-runs the pre-versioning branch forever | One-line fixture change (§R4-2) | OWNER-TBD / next commit |
| W2 | `debugSetMigrations` mutates the shipped table in place; `@visibleForTesting` is non-fatal under this CI's `--no-fatal-warnings` | A production call would silently replace the migration table and pass CI | Drop `--no-fatal-warnings`, or wrap both hooks in `assert(() {…}())` | OWNER-TBD / next commit |
| W3 | `orders_persistence` contract violated: `_persistAndNotify` writes the demo seed once a real order exists; a new test asserts the result as correct | 3 fabricated orders become indistinguishable from a patient's real history, per patient, permanently | Filter demo-seeded entries in `_persistAndNotify`, or mark them; fix the test | OWNER-TBD / this sprint |
| W4 | `clearPatientScopedData` "does NOT persist" is not asserted; a re-added persist after `_patientId = null` passes the new test | Silent regression to a writing clear, on a different key | `p.getKeys()` before/after comparison | OWNER-TBD / this sprint |
| W5 | 3 `DemoMode` sources declared and never marked; `markServingLiveData` has 2 call sites for 12 sources | Care-team, calendar and profile screens serve samples with no warning; 10 sources can never clear | Wire the three; add the call-site guard test | OWNER-TBD / this sprint |
| W6 | `CartProvider.clearPatientScopedData` un-awaitable; `session_scope.dart:91-92` claims otherwise | Cart contents can race a patient switch | Return `Future<void>`; delete 4 sleeps | OWNER-TBD / this sprint |
| W7 | Determinism: 64 `.delayed(` sites, 8 in the isolation file alone | Flake indistinguishable from regression under TST-12.02 | `fakeAsync` + W6 | OWNER-TBD / this quarter |
| W8 | `TEST_STRATEGY.md` mentions none of the new test files; documented 60% target vs enforced 50% gate | The strategy document no longer describes the suite | Update; reconcile the two numbers | OWNER-TBD / this sprint |
| W9 | The audited commit has never run CI (workflow triggers on `main` only; branch has no PR) | "Suite passes" for `9127713` is a local claim | Open the PR, or widen the trigger | OWNER-TBD / immediate |
| W10 | `DemoMode` and `StoreMigrator._migrations` are process-global mutable test state | Cross-test contamination is prevented by convention only | Global `setUp` reset in a shared harness | OWNER-TBD / this sprint |
| W11 | Adversarial data gaps: no Unicode/Devanagari round-trip, no large-account, no duplicate-row fixtures | Devanagari is a shipped locale | 5-line fixture | OWNER-TBD / this quarter |
| W12 | Third-party failure simulation covers declines but not throttling, slow or malformed responses; Firebase unsimulated | Gateway degradation untested | Extend `payment_service_test.dart` | OWNER-TBD / this quarter |
| W13 | Findings have no ticket, owner, severity or regression disposition; 6 round-3 blockers passed a full round untouched | Nothing tracks a blocker between rounds | Blocked by MASTER-1.05 | OWNER-TBD / immediate |
| W14 | No dependency-vulnerability or secret scanning step in CI | Unknown | One CI step each | OWNER-TBD / this sprint |
| W15 | i18n guard is structurally blind to strings that never became keys | Hardcoded English survives in `payment_screen.dart` | Grep gate in the design script | OWNER-TBD / this quarter |
| W16 | Copy is machine-checked only for key parity; a documented rationale is contradicted by the shipped data | `delete_account_screen.dart:68-69` vs `hi.json:339` | Proofreading pass | OWNER-TBD / this quarter |
| W17 | No reproducible-generation or manifest snapshot check | A permission-string regression reaches review unflagged | 15-line snapshot test | OWNER-TBD / this quarter |
| W18 | Only 2 of 4 defects fixed in `13e3656` received a regression test | Two fixes are verified by their author's reading only | §R4-4 ranks 1 and 3 | OWNER-TBD / this sprint |

---

## BLOCKED-OWNER — needs access I do not have

- **TST-11.02 (usability/domain validation)** — needs the owner's field-review notes from the
  side-loaded device, or a session run with representative users. MASTER-3.11 makes
  specialist clinical review mandatory and this audit cannot substitute for it.
- **Suite wall-clock time and coverage numbers** — I was instructed not to run
  `flutter test`. I need the central run's duration and `coverage/lcov.info`, specifically
  the per-file lines for `lib/utils/session_scope.dart`,
  `lib/screens/settings/delete_account_screen.dart`, `lib/widgets/demo_data_banner.dart`,
  `lib/data/demo_mode.dart` and `lib/services/store_migrator.dart` (the last is now non-zero;
  I need the number to confirm the three deletable lines in §R4-2 show as covered, which
  would be the clearest possible demonstration that line coverage is not verification).
- **Branch-protection status and whether required checks are enforced** (TST-12.01) — needs
  GitHub repository settings.
- **Backend/database verification** (TST-4.05, 9.02) — needs `housepital-backend` /
  `housepital-api` environments or a Firebase emulator run.
- **Whether `storage.rules` / `firestore.rules` are deployed** — needs the Firebase console.
- **Dependency vulnerabilities** — needs `dart pub outdated --mode=security`.
- **Device matrix and on-device behaviour** (TST-6.01–6.04) — needs physical devices.
- **The `.docx` vs `.pdf` checklist comparison the brief requests** — I was given a `.txt`
  export only. I have stated what round 3's report shows it graded instead, and I will not
  assert a format diff I could not perform.

---

## Limitations of this audit

1. **Source only.** Per MASTER-4.04, evidence should come from the release artifact in a
   production-like environment. There is no release artifact, and I audited source. Every
   verdict about runtime behaviour is inference from code, explicitly reasoned, with the
   file:line shown so a reviewer can check the inference rather than trust it.
2. **I did not execute the suite.** All counts are scripted over test *sources*. Where I
   claim a test "would still pass" if a line were deleted, that is a reading of the fixture
   and the control flow, stated with the reasoning, not an executed mutation. §R4-2's three
   deletion claims are the load-bearing ones and each is a two-step argument that a reviewer
   can falsify in about a minute by trying it.
3. **Round 3's 93/216 "inert widget test" metric is not reproducible** from the source under
   any rule I could construct, and its stated example (`my_care_widgets_test.dart`) does pump
   production widgets. I have re-baselined with three defined, scripted measures rather than
   carry a number I cannot defend.
4. **Round 3's "120 tests execute zero production code" was an undercount** — the same rule
   applied exhaustively yields ≈140 across 14 files. Both figures are in §R4-5 so the
   difference is auditable.
5. **The 58 TST controls have no prior-round grading**, so no outcome in this report is a
   delta against round 3's counts. The prior-round status table is the only valid
   comparison.
6. **`housepital-backend` and `housepital-api` were not read for this module.** Their testing
   posture matters for TST-4.x, 9.02 and 10.03; I graded those Fail on the basis that no test
   *in this repo's suite* reaches them and no harness exists here, and flagged the live-
   environment half BLOCKED-OWNER rather than asserting what those repos contain.

---

*Read-only audit. No file under `lib/`, `test/`, `docs/audits/` (round 2) or
`docs/audits/round3/` was modified. Only this report was written.*
