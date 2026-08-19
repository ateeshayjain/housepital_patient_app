# Sync & Multi-Device — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-03 · **Auditor:** Sync & Multi-Device · **Scope:** source review (see Limitations)
**Checklist:** Sync & Multi-Device Checklist (App-Agnostic), control family SYNC, Suite v2.0 (49 controls)
**Prior rounds:** round 3 `9a80fe2` (`docs/audits/round3/SYNC_MULTIDEVICE_AUDIT.md`) · round 2 `820060b` · round 1 `803124d`
**Also read:** `/Users/ateeshayjain/WIPApps/Housepital/housepital-backend` (last commit `7417387`, 26 Mar 2026 — unchanged since round 3) and `/Users/ateeshayjain/WIPApps/Housepital/housepital-api`.

---

## Applicability

MASTER-3.xx trigger: the product is explicitly designed for **shared state across people and
devices** — one patient is watched by the patient, a primary contact, and family members
(`lib/utils/session_scope.dart:22-28`), and two server-side systems of record exist for the same
clinical nouns. The control family applies in full.

It applies with one honest qualifier that governs every grade below: **the app is currently pointed
at no reachable server.** `lib/config/constants.dart:3` is a plain
`const String apiBaseUrl = 'https://api.housepital.in/v1'` with no `String.fromEnvironment`, and
that host does not resolve. So the controls are graded against *what would happen the day the app
is pointed at a host*, plus the local-storage half of shared state, which is live today on any
shared phone. Nothing here is graded N/A merely because the network half is dormant — "not tested
is not N/A."

---

## Headline — which pattern the latest work fits

Round 1 → 2 found the fixes were **surfaces**. Round 2 → 3 found they were **half-wires**. Round 4
is a third distinct shape, and it is the most expensive one to detect:

> **The mechanism is complete and correct, and its only production trigger cannot fire in the build
> that ships.**

`AppProvider.onPatientChanged` + `SessionScope.install()` + `OrdersProvider.setPatient()` is a
well-built fan-out. I traced every line of it and the *logic* is right. But:

- `OrdersProvider` is constructed in production with **no patient id** (`lib/main.dart:214`), so
  `_patientId` is `null` and every order is written to the literal key
  **`housepital_orders__none`** (`lib/providers/orders_provider.dart:33`).
- The only production caller of `setPatient` is `SessionScope._adopt`
  (`lib/utils/session_scope.dart:76`), reached only from `_announcePatient`.
- Of the five sites that assign `_currentPatient`, the one that actually runs in a demo build —
  the seed at `lib/providers/app_provider.dart:151` — **does not announce**. The API-adoption
  announce at `:178` sits inside `if (apiPatients.isNotEmpty)` inside the `try`, so it requires a
  reachable host.

Net: **in the shipped demo build, `setPatient` is never called, `_patientId` is never non-null, and
the per-patient key scheme — the whole of commit `13e3656`'s storage fix — is inert.** The unit test
that certifies it (`test/providers/patient_scope_isolation_test.dart:270-308`) passes only because
it constructs `OrdersProvider(patientId: 'pat_a')` — a constructor argument that **no production
code passes** (`grep -rn "OrdersProvider(" lib/` → `main.dart:214` and the declaration).

This is the same species as the two defects I found in rounds 2 and 3 — a fix validated against the
implementation rather than against the wiring — but one level further out. Round 2's test asserted
the fields the implementation touched. Round 3's test asserted the one provider the guard cleared.
Round 4's test asserts a code path production never enters.

**One thing genuinely improved and deserves saying plainly:** round 3's BLOCKER 1 — the vitals chart
merging 180 days of `Random(42)` clinical readings with the patient's real ones — is **properly
fixed**. `lib/screens/reports/vitals_screen.dart:125-136` now never mixes the two, `:81` raises
`DemoMode.sourceVitals`, and `:129` lowers it when real data exists. That is a real repair that
survives adversarial reading.

---

## Prior-round status

### Round-3 blockers

| Round-3 finding | Status now | Evidence |
|---|---|---|
| **B1** Vitals chart fabricates 7–180 days of readings and merges them with the patient's real ones, unflagged | **Pass — genuinely fixed** | `vitals_screen.dart:125-136` `_mergedVitals` returns *only* real readings when any exist in the window ("REAL READINGS ARE NEVER MIXED WITH SAMPLE ONES", `:120-124`); `:81` raises `DemoMode.sourceVitals`; `:129` calls `markServingLiveData(sourceVitals)`; `demo_mode.dart:31` declares the constant. Residual: `_generateMockData()` still runs unconditionally in `initState` (`:45`) and raises the flag before build lowers it — a transient, not a defect. |
| **B2** `loadPatients()`'s guard clears `AppProvider` only | **Partly fixed; a third path is open and it is the DEFAULT path** | The guard now announces: `app_provider.dart:171-178`. `SessionScope.install` (`session_scope.dart:61-71`) fans out to seven providers plus prefs, cache and OS notifications. **But** the announce is unreachable without a host (see Headline), and the seed at `app_provider.dart:151` assigns `_currentPatient` with no announce and no clear. Also unfixed: the guard still compares against `apiPatients.first` (`:170`), so a user's switch-sheet selection is still silently reverted to the API list's head. |
| **B2b** The test institutionalises the gap | **Still open — the test is byte-identical** | `git diff 9a80fe2..HEAD -- test/providers/patient_scope_isolation_test.dart` shows **no change** to `loadPatients is a switch path too` (`:351-366`). It still asserts two fields (`currentPatient`, `activeDeployment`) and nothing about the fan-out. |
| **B3** Dose logged to nowhere | **Unchanged** | `medication_provider.dart:110-127`. See §"Dose-log-to-nowhere". |
| **B4** Two systems of record, structurally unmergeable | **Unchanged** | `housepital-backend` HEAD is `7417387`, 26 Mar 2026 — predates round 3. All six collisions re-verified below. |
| **B5** Firestore rules deny every direct call | **Unchanged** | `firestore.rules:67,70,72,90,94,99` still `request.auth.uid == patientId`; `grep -rn "\.uid" lib/` still returns zero. |

### Round-3 High / Medium

| Finding | Status now | Evidence |
|---|---|---|
| **H6** `logout()` no longer an atomic wipe; destroys `__quarantine_*` | **Unchanged in code, WORSE in impact** | `auth_provider.dart:232-239` is still the snapshot-then-remove loop over `prefs.getKeys().toList()` with `preserved` = two keys. `__quarantine_` is still absent. Commit `13e3656` made this materially worse: the v1→v2 migration (`store_migrator.dart:58-73`) now moves **every pre-v2 user's entire order and assessment history** into `__quarantine_v1_*`, and it is the *only* copy — `store_migrator.dart:70` calls `prefs.remove(key)` after quarantining. The first logout after upgrading destroys it. `grep -rn "__quarantine" lib/` → three hits, all inside `store_migrator.dart`; **zero readers**. |
| **H7** `DemoMode`: many raisers, one lowerer | **Marginally better, structurally unchanged** | `markServingLiveData` now has **2** call sites (`app_provider.dart:292`, `vitals_screen.dart:129`) against **13** `markServingDemoData` sites. `sourcePatientIdentity` is still raised at `app_provider.dart:156` and never lowered by the successful load at `:175`. `sourceCareTeam`, `sourceCareCalendar`, `sourceProfile` (`demo_mode.dart:27-29`) are still declared and never raised, while `care_team_screen.dart:31`, `care_calendar_screen.dart:1324` and `payment_screen.dart:64` still serve fabricated data unannounced. |
| **H9** `AssistantProvider` bound to `DemoData.patient.id` | **Unchanged, and now interacts badly with per-patient orders** | `main.dart:234` `final patientId = DemoData.patient.id;` and `:260` `deploymentId: DemoData.icuDeployment.id`. `:266` hands the executor `ctx.read<OrdersProvider>()`. After a switch to Sunita, an assistant booking is filed against `pat_demo_rajesh` server-side while being written to Sunita's local key. |
| **H10** `updateFromSync()` unguarded | **Unchanged, and now the only assignment site with neither guard nor announce** | `app_provider.dart:354-360`. Dormant: `grep -rn "SyncService" lib/ test/` → 9 hits, all inside `sync_service.dart` plus one comment at `app_provider.dart:341`. Zero importers. |
| **H11** `SessionScope` has zero tests | **Unchanged** | `grep -rn "SessionScope" test/` → **one hit, a comment** (`patient_scope_isolation_test.dart:12`). `test/screens/main_shell_test.dart` pumps `MainShell` — and therefore executes `install()` — but asserts nothing about it (`grep -n "install\|onPatientChanged" test/screens/main_shell_test.dart` → no hits). The round-4 fix is entirely unasserted. |
| **H12** Family sharing is a static mock | **Unchanged — and round 3 over-credited the backend** | `family_members_screen.dart:22,51`. Correction to round 3: `routes/family.ts:103` `POST .../family/invite` is a **stub** — it validates `phone`, then `res.json({ success: true })` with the comment *"In production, send an SMS/WhatsApp invite… For now, just record the invitation"*. Nothing is recorded. List/add/update/revoke are real; **invite is not**. |
| **H13** `verifyPatientAccess` passes through for un-onboarded users | **Unchanged** | `housepital-backend/functions/src/middleware/auth.ts:43-51` sets `patientId = ""`; `:104` guards `if (patientId && authReq.patientId && …)`. Empty string is falsy → pass-through to handlers that filter on the URL param. |
| **H14** Dead sync surface | **Unchanged** | `SyncService` zero importers; `firebase_service.dart:237,255,277` three listeners with zero subscribers; FCM at `main.dart:345-377` navigates and reloads nothing; `grep -rn "ApiService()" lib/screens/ \| wc -l` → **16**. |
| **M15** Fire-and-forget persists safe by accident | **Changed shape, still unguarded** | `orders_provider.dart:201-211` now reads *both* `_ordersKey` and `_orders` after the first `await`, which is safer — but see FAIL-3: it makes a mis-targeted write possible instead of an over-write. |
| **M16** `housepital_pending_deletion` has zero readers | **Unchanged** | `grep -rn "housepital_pending_deletion" lib/` → three hits: the write (`delete_account_screen.dart:83`), the preserve entry (`auth_provider.dart:235`), and a doc comment. |
| **M17** `profile_photo_path` survives a switch | **Unchanged** | Written at `app_provider.dart:121`; field nulled only in `clearSession()` (`:234`); the key is not in `SessionScope._patientScopedPrefsKeys` (`session_scope.dart:49-51`). A switch leaves both key and JPEG. |
| **M18** `CacheService.get()` has zero production callers | **Unchanged** | `cache_service.dart:22`; only the write at `app_provider.dart:293` is live. |
| **M19** `VitalReading` has no `toJson` | **Unchanged** | Wire body still hand-built at `api_service.dart:246-261`. A6/A5 cannot be tested until it exists. |
| **M20** Client ids clock-derived | **Unchanged** | `orders_provider.dart:72-76`, `:124`; `reminders_provider.dart:140`; `delete_account_screen.dart:80-81`; `vitals_screen.dart:727`. |
| **M21** `patient_log_${medicationId}_$timeSlot` carries no date | **Unchanged** | `medication_provider.dart:117`. |
| **M22** `address_selection_screen` mints records on first read | **Unchanged** | `address_selection_screen.dart:106-110,126`. |
| **M23** OTP minted in `initState`, written `merge: true` | **Unchanged** | `staff_otp_verification_screen.dart:52-55,83`. |
| **M24** `return_screen.dart:331` sends a local path as `photoUrl` | **Unchanged** | — |
| **M25** `submitDailyRating` zero callers, broken endpoint | **Unchanged** | `ratings.ts:37,54` still `family_member_id`; schema column is `rated_by` (`001_initial_schema.sql:388`). |
| **M26** Pull-to-refresh on 5 of 91 screens | **Unchanged** | `grep -rl RefreshIndicator lib/screens/ \| wc -l` → 5; `find lib/screens -name '*.dart' \| wc -l` → 91. |

**Round-3 tally: 1 fixed · 2 partly fixed · 22 unchanged · 2 escalated in impact (H6, and the orders-on-disk revert below).**

---

## Round-4 focus findings

### FAIL-1 — Both switch paths now fan out. Neither of them runs in the shipped build, and there is a third path that does.

**The fan-out is correct where it fires.** `session_scope.dart:61-71` installs
`app.onPatientChanged`; `_adopt` (`:73-77`) awaits `clearPatientData` — seven providers
(`:82-93`), OS-scheduled medication notifications (`:100`), `CacheService.clear()` (`:121`),
`housepital_saved_addresses` (`:50`) and every `daily_rating_*` (`:129-133`) — then re-points
`OrdersProvider` (`:76`). Both `switchPatient` (`app_provider.dart:195`) and the `loadPatients`
guard (`:178`) call it. On the narrow question round 3 asked, this is a genuine repair.

**The third path is `app_provider.dart:150-158`, and it is the only one a demo build reaches.**

```dart
if (_patients.isEmpty) {
  _currentPatient = DemoData.patient;     // :151 — assigns identity
  _patients = [DemoData.patient];
  DemoMode.markServingDemoData(DemoMode.sourcePatientIdentity);
  notifyListeners();                       // :157 — no _announcePatient
}
```

`_currentPatient` is assigned at five sites — `:151`, `:175`, `:193`, `:230`, `:355`. Three
announce (`:178`, `:195`, `:237`). **Two do not: `:151` and `:355`.**

- `:151` is reachable on every cold start, and again after `clearSession()` empties `_patients`
  (`:231`) — i.e. after every logout and every account deletion, on the next Home mount
  (`home_screen.dart:56-59`).
- `:355` (`updateFromSync`) is dormant — `SyncService` has zero importers — but it is now the only
  assignment site with neither an identity guard, a clear, nor an announce. It is one `import`
  away from being a live unguarded switch path.

**Consequence, and it is the report's central finding.** `OrdersProvider` is created at
`main.dart:214` as `OrdersProvider()` — no `patientId`. `setPatient` (`orders_provider.dart:53`) is
the only thing that ever sets a non-null `_patientId`, and its sole production caller is
`session_scope.dart:76`, reached only via an announce. In a build where the API is unreachable —
which CLAUDE.md states is the shipped condition — **no announce ever fires on the default path**,
so `_patientId` stays `null` and `_ordersKey` resolves to the literal string
`housepital_orders__none` (`orders_provider.dart:33`) for the life of the install.

**Impact:** the entire per-patient storage fix of commit `13e3656` does nothing in the build that
ships. Every order and assessment lands in one shared bucket, exactly as before, and the safety
argument that justified reverting the disk clear (below) does not hold.

**Mitigation:** announce from the seed at `:151` as well (it *is* an identity change: `null` →
`pat_demo_rajesh`), or construct `OrdersProvider` from `AppProvider.currentPatient` via
`ChangeNotifierProxyProvider` so the key can never be `_none`. Add an assertion that
`_ordersKey` never contains `_none` outside tests.
**Owner:** OWNER-TBD · **Due:** before any build is pointed at a host.

---

### FAIL-2 — A switch away and back does NOT preserve each patient's history in the app. It preserves it only in the test.

The brief asks me to verify this specifically. The answer is: the *provider* honours the contract;
the *app* does not, and the test cannot tell the difference.

**What the provider does (correct):** `clearPatientScopedData()` (`orders_provider.dart:258-263`)
empties memory and nulls `_patientId` and **never persists** — verified. `setPatient`
(`:53-60`) drops memory then reads the incoming patient's own key. Nothing in `OrdersProvider`
writes `[]` over a real key on the clear path.

**What the app does.** Take the reachable scenario: a demo-build user adds a second patient
(`add_patient_screen.dart:106`), places orders, then switches.

1. Cold start → `_patientId = null` → orders persist to `housepital_orders__none`
   (`main.dart:214`, `orders_provider.dart:33,205`).
2. Switch sheet → Sunita → announce → `setPatient('pat_other_sunita')` → reads
   `housepital_orders_pat_other_sunita`, which is empty → falls through to the demo seed at
   `orders_provider.dart:235-238`.
3. Switch back to Rajesh → `setPatient('pat_demo_rajesh')` → reads
   `housepital_orders_pat_demo_rajesh`, **which was never written**. Empty → demo seed again.

**Rajesh's real order history is not restored. It is sitting under `housepital_orders__none` and
nothing will ever read it again for him** — but it *will* be read again for the next person to hold
a null patient id, because `_patientId` is not persisted and the constructor
(`orders_provider.dart:43-45`) starts at `null` on **every** cold start. So:

> After a patient switch, killing and relaunching the app re-renders the *first* patient's real
> order history, under whatever name the seed at `app_provider.dart:151` supplies.

This is round 2's original defect — "a cold start restores the previous patient" — **live again**.
Round 3 graded it fixed (NEW-3 ✅, orders reach disk). Round 4 deliberately reverted the persist
(`orders_provider.dart:252-257`, and the CLAUDE.md storage contract) on the argument that
per-patient keys make the revert safe. **The argument is sound and the premise is false**, because
FAIL-1 means the keying is inert. Logout does clean it (`auth_provider.dart:235-238` removes every
unpreserved key) — but the switch sheet exists precisely so that families do *not* log out.

**Why the test does not catch it.** `patient_scope_isolation_test.dart:280` constructs
`OrdersProvider(patientId: 'pat_a')`. That named argument appears in exactly two places in the
repo: the declaration (`orders_provider.dart:43`) and this test. Production never passes it. Two
further weaknesses in the same test:

- `:306` `expect(bOrders, isNot(aCount), reason: "B must not inherit A's orders")` passes only
  because A has one *extra* order on top of the demo seed — **B does inherit the demo seed**
  (`orders_provider.dart:235-238`). The assertion reads far stronger than it is.
- `:299` `expect(orders.orders.length, aCount)` is satisfied by a disk blob that includes
  `DemoData.orders`, because `addOrder` → `_persistAndNotify()` (`:113`, `:205`) encodes the whole
  `_orders` list including the in-memory demo seed. This **contradicts the CLAUDE.md architecture
  note** that "demo orders are never written to storage (a test asserts this)" — the test that
  asserts it (`orders_persistence_test.dart:244`) only covers the seed *alone*, never the seed
  followed by a real checkout.

**Mitigation:** as FAIL-1, plus persist `_patientId` (or derive it) so a cold start cannot land in
`_none`; make the demo seed non-persistable by holding it in a separate `_demoOrders` list that
`_persistAndNotify` excludes.
**Owner:** OWNER-TBD · **Due:** before release.

---

### FAIL-3 — `install()` can be missed, cannot be re-installed, and pins a `BuildContext` for the process lifetime

`session_scope.dart:61-71`:

```dart
static void install(BuildContext context) {
  final app = context.read<AppProvider>();
  if (app.onPatientChanged != null) return;      // :63 — install-once
  app.onPatientChanged = (patientId) {
    if (!context.mounted) return;                // :65 — silent no-op when dead
    unawaited(_adopt(context, patientId));
  };
}
```

Assessed as the brief asks:

**Can it be missed?** Yes, in three ways.
1. `install` is called from exactly one place — `main_shell.dart:39-41`, a post-frame callback in
   `MainShellState.initState`. Any patient change before that frame is not fanned out. In practice
   `HomeScreen.initState` schedules `loadPatients()` on a `Future.microtask`
   (`home_screen.dart:56-59`), whose synchronous seed at `app_provider.dart:151` runs **before** the
   post-frame callback — and that seed does not announce anyway (FAIL-1).
2. Any presentation of a patient-bearing screen outside `MainShell` gets no hook. The `default:`
   arm of `onGenerateRoute` (`main.dart:772-773`) returns a **second** `MainShell` for any unknown
   route name; with the first popped, `install` on the second early-returns at `:63` because
   `onPatientChanged` is already non-null — and the surviving closure's `context` is the dead
   element, so `:65` returns and **the fan-out becomes a permanent silent no-op**.
3. The commented-out auth gate at `main.dart:418` (`home: Consumer<AuthProvider>(...)`, a documented
   pre-production TODO) would swap `MainShell` out on logout and back in on login. Re-enabling it
   makes case 2 the **normal** path: the first `MainShell` owns the hook forever, every subsequent
   one inherits a dead one, and `loadPatients()` silently reverts to round 3's `AppProvider`-only
   clear with no test and no log line to say so. `install`'s failure mode is silence, and `:65`'s
   early return is the checklist's own red flag — *"any error path that logs and returns"*, minus
   the log.

**Can it be double-installed?** No — `:63` prevents it. That guard is what creates hazard 2/3: it
is an install-**once**, not an install-**latest**. There is no `uninstall`; `MainShellState` has no
`dispose()` (`main_shell.dart` has none).

**Does it leak a BuildContext?** Yes, bounded. The closure is stored on `AppProvider`, which is
created above `MaterialApp` (`main.dart:196-198`) and never disposed, and it captures `MainShell`'s
`StatefulElement`. In today's single-`MainShell` app that retains one element for the process
lifetime — not a growing leak, but a real retained reference to a disposed widget tree in cases 2/3.

**Mitigation:** make it `install(BuildContext)` / `uninstall()` paired with `initState`/`dispose`,
or move the hook off `BuildContext` entirely — have `SessionScope` hold provider references passed
in once from `main.dart`'s `MultiProvider`, which is where the providers actually live. Add a test
that asserts `onPatientChanged` is non-null after `MainShell` mounts **and** that a remount rewires
it. **Owner:** OWNER-TBD · **Due:** before the auth gate is re-enabled.

---

### FAIL-4 — `_adopt` ordering and the double-tap race: still unguarded, and now with a second racer

`_adopt` (`session_scope.dart:73-77`) is `unawaited` from a synchronous callback
(`:69`) that is itself called synchronously from inside `switchPatient`
(`app_provider.dart:195`), which then immediately calls `loadDashboard()` (`:196`).

**Ordering within one switch is correct but fragile.** `clearPatientData` runs its six synchronous
`clearPatientScopedData()` calls (`:82-89`) before its first `await` (`:93`), so the wipe lands in
the same microtask as the announce; `setPatient` then runs after `await clearPatientData` completes.
`OrdersProvider.clearPatientScopedData()` sets `_patientId = null` (`orders_provider.dart:261`)
before `setPatient` sets it to the incoming id — so no order write between them can target the
outgoing patient's key. Correct. **Not documented as load-bearing**, and one refactor (hoisting the
reminders `await` above the sync clears) breaks it silently.

**The switch sheet now clears twice.** `home_screen.dart:1774-1775`:

```dart
await SessionScope.clearPatientData(context);
app.switchPatient(patient);      // -> _announcePatient -> _adopt -> clearPatientData AGAIN
```

Round 3's call site was never removed when the hook was added, so `clearPatientData` — including
`MedicationReminderService().cancelAllReminders()`, two `SharedPreferences` sweeps and a
`CacheService.clear()` — runs twice per tap. It is idempotent, so this is not harmful today. It is
a contract violation: `session_scope.dart:19-20` claims to be *"one place that knows"*, and
CLAUDE.md says *"A third must use the hook, not clear by hand"* — while the **first** path still
clears by hand.

**The double-tap race round 3 found is unchanged, and the fan-out gave it a second racer.**
`home_screen.dart:1767` is still `onTap: () async {` with no busy flag, no `setState` disable, and
the sheet is not dismissed until `nav.pop()` **after** the `await` at `:1774`. Two taps on two
different rows produce two overlapping handlers. There is no generation token anywhere in
`AppProvider`, `SessionScope` or `OrdersProvider`, so nothing binds a `setPatient` completion to
the `switchPatient` that requested it. `settings_screen.dart:452-462` (logout) and
`delete_account_screen.dart:143-145` are likewise unguarded `async` handlers.

The interleaving that matters: if `_adopt(C)`'s `setPatient('C')` completes before `_adopt(B)`'s
`clearPatientData` — the two suspend across `MedicationReminderService().cancelAllReminders()`
(`session_scope.dart:100`), which is a platform-channel round trip
(`medication_reminder_service.dart:248-251` → `_plugin.cancelAll()`), and platform replies are
delivered in *completion* order, not call order — then `OrdersProvider` ends with `_patientId = null`
and an empty list while `AppProvider.currentPatient` is C. Every subsequent order for C is written
to `housepital_orders__none`.

**And FAIL-2's key hazard is reachable here too:** `_persistAndNotify` reads *both* `_ordersKey`
and `jsonEncode(_orders)` after `await SharedPreferences.getInstance()`
(`orders_provider.dart:204-206`). A checkout that begins persisting and is overtaken by a switch
resumes with `_patientId` already set to the **incoming** patient and `_orders` already emptied —
`prefs.setString('housepital_orders_<incoming>', '[]')`. That is the one interleaving in which the
app **does** write `[]` over a real key. Narrow, but structurally unprevented.

**Mitigation:** a `bool _switching` guard on both `onTap` handlers, plus a monotonically increasing
`_switchGeneration` on `AppProvider` captured by `_adopt` and re-checked before `setPatient` and
before every `prefs.setString`. **Owner:** OWNER-TBD · **Due:** before release.

---

### Store enumeration, re-run independently and diffed against `SessionScope`

Method: `grep -rn -E "\.(setString|setBool|setInt|setDouble|setStringList)\(" lib/` for keys, plus
every `ChangeNotifier` with a `clearPatientScopedData`, plus screen `State` holding patient data.
Built from the tree, then diffed against `session_scope.dart`.

| Key | Writer | Patient data? | Switch | Logout |
|---|---|---|---|---|
| `housepital_orders_<pid>` / `housepital_assessments_<pid>` | `orders_provider.dart:205,206` | yes | ⚠ memory only, by design — **but resolves to `_none` in production** (FAIL-1/2) | ✅ |
| `housepital_orders__none` (the real production key) | same | **yes** | ❌ **never cleared on a switch, re-read on every cold start** | ✅ |
| `housepital_cart_items` / `housepital_saved_items` | `cart_provider.dart:222,226` | yes | ✅ `session_scope.dart:89` | ✅ |
| reminders key | `reminders_provider.dart:181` | yes | ✅ `session_scope.dart:93` (memory + `prefs.remove`) | ✅ |
| `housepital_saved_addresses` | `address_selection_screen.dart:126` | yes | ✅ `session_scope.dart:50` | ✅ |
| `daily_rating_<YYYY-MM-DD>` | `my_care_screen.dart:615` | yes | ✅ `session_scope.dart:129-133` (prefix sweep) | ✅ |
| `housepital_cache_*` | `cache_service.dart:19` | yes | ✅ `session_scope.dart:121` | ✅ |
| `profile_photo_path` | `app_provider.dart:121` | identity | ❌ **key and JPEG survive a switch** (field nulled only in `clearSession`, `:234`) | ✅ key only |
| `__quarantine_v1_*` | `store_migrator.dart:208-218` | **yes — an upgrading user's entire order history** | ❌ not in scope | ❌ **destroyed** by `auth_provider.dart:235-238`; zero readers |
| `housepital_pending_deletion` | `delete_account_screen.dart:83` | contains `patientId` | ❌ by design | ❌ by design; zero readers |
| `housepital_schema_version` | `store_migrator.dart:129,176,181,187` | no | N/A ✅ | preserved ✅ |
| `preferred_language`, `theme_mode`, `has_onboarded`, notification booleans | `app_provider.dart:107,144`, `theme_provider.dart:55`, `auth_provider.dart:196,197` | no — device/account | N/A ✅ | correct |

**Providers:** all seven with patient state are reached — `MyCareProvider:114`,
`MedicationProvider:391`, `BillingProvider:68`, `OrdersProvider:258`, `AssistantProvider:184`,
`CartProvider:210`, `RemindersProvider:194` — from `session_scope.dart:82-93`. `AppProvider` is
deliberately outside `clearPatientData` (both switch paths clear it themselves at
`app_provider.dart:173,192`); that is correct and no path was found where it is missed.

**Round 3 named seven screens holding patient state outside `SessionScope`. Diff:**

| Screen | Round 3 | Now |
|---|---|---|
| `vitals_screen.dart` `_vitals` | Blocker | **Fixed** — no longer merged, flagged (`:125-136`, `:81`) |
| `family_members_screen.dart:22,51` `_mockMembers` | ❌ | **Unchanged** |
| `document_repository_screen.dart` (`lib/screens/documents/`) | ❌ | **Unchanged** |
| `address_selection_screen.dart:106-110` | ❌ | **Unchanged** — still writes three defaults on first read |
| `care_team_screen.dart:29,31` | ❌ | **Unchanged**, still unflagged |
| `care_calendar_screen.dart:1324` | ❌ | **Unchanged**, still unflagged |
| `payment_screen.dart:64,181-185` `_mockCoupon` | ❌ | **Unchanged**, still unflagged |

**Diff verdict:** `SessionScope`'s *enumeration* remains complete for providers and for every
prefs key it knows about — that credit stands from round 3. Three stores are outside it and one is
new-in-effect: `housepital_orders__none` (created by FAIL-1), `__quarantine_v1_*` (created by
`13e3656`), and `profile_photo_path` (carried). The first two both hold order history.

---

### The backend finding, restated under v2.0 grading

`housepital-backend` HEAD is `7417387`, dated **26 Mar 2026** — it has not been touched since round
3. `housepital-api` is not a git working copy. Every round-3 claim re-verified at source:

- **`family_members.user_id VARCHAR(128) NOT NULL UNIQUE`** — `sql/001_initial_schema.sql:45`.
- `middleware/auth.ts:39-41` — `db("family_members").where("user_id", uid).first()` → exactly one
  `patientId` on the request.
- `routes/patients.ts:33-45` — `GET /patients` maps memberships to ids and `whereIn`s them. The
  UNIQUE constraint caps that list at **one**.
- `middleware/auth.ts:104` — `verifyPatientAccess` 403s any other patient id.
- `medication_logs` has **no `patient_id` column** (schema at `001_initial_schema.sql`, ten columns:
  `id, medication_id, staff_id, staff_name, scheduled_time, actual_time, status, skip_reason, notes,
  created_at`) while `routes/medications.ts:218` queries `.where("patient_id", patientId)`.
- `routes/ratings.ts:37,54` use `family_member_id`; the column is `rated_by`
  (`001_initial_schema.sql:388`), unique key `uk_deployment_rater_date` (`:393`).

**Should the patient-switch feature be considered functional at all? No — and this is the honest
answer the owner needs before more client work is spent on it.**

Three independent reasons, any one of which is sufficient:

1. **Server-side it is impossible.** One Firebase user maps to at most one `family_members` row,
   therefore at most one patient. `GET /patients` cannot return a second patient, and if the
   constraint were dropped without touching `auth.ts`, `verifyPatientAccess` would 403 every call
   for the second one. Two full rounds of PHI repair have been built against a server that
   structurally denies the feature.
2. **Client-side it is inert on the default path.** FAIL-1: the announce that drives the whole
   fan-out is unreachable without a host, and the per-patient storage key it feeds resolves to
   `_none`.
3. **Where it does fire, it loses data.** FAIL-2: a switch away and back does not return the first
   patient's orders.

Under v2.0 this is not "a feature with bugs"; it is **a feature whose contract has never been
decided**. The client says one user → many patients; the server says one user → one patient; and
neither statement is written down as a requirement anywhere in either repo. That is the
BLOCKED-OWNER item below, and it should be resolved *before* FAIL-1 through FAIL-4 are fixed,
because the shape of the fix depends on the answer. If the server's model wins, `switchPatient`,
the switch sheet and most of `SessionScope`'s switch semantics should be **deleted**, and
`SessionScope` reduced to a logout teardown — which is the half that is genuinely needed on a
shared phone and the half that works.

The round-3 merge-not-sync recommendation stands unchanged and unactioned: two databases claiming
the same six clinical nouns, with no shared patient identity (staff DB has no `patients` table),
different `attendance` grain (`uk_deployment_date` vs `unique(['staff_id','date'])`), and three
divergent enum vocabularies. Zero production rows today makes this a schema exercise; it becomes a
live-patient migration later.

---

### Dose-log-to-nowhere — status

**Unchanged. Fourth consecutive round.** `medication_provider.dart:110-127`:
`logDoseToday` appends a `MedicationLog` to `_todayLogs`, calls `markDoseTakenToday` (which
notifies), and returns `true`. There is **no API call, no persistence, and no queue**. The UI
reports a successful dose administration for a fact that exists only in RAM until the next
`clearPatientScopedData()` (`:391-400`) or app kill. `id: 'patient_log_${medicationId}_$timeSlot'`
(`:117`) still carries no date, so day 2's 08:00 dose collides with day 1's the moment anything
does persist it.

Round 3 established *why* it is not fixable by client work alone, and that is still true: the
backend's `medication_logs` has no `patient_id`, no `logged_by`/`source`, and no unique key on
`(medication_id, scheduled_time)`; the staff DB has no medication table at all (meds are a JSON blob
on `deployments.medications`). This is the single most dangerous defect in the app and the only one
that has survived every round untouched.

---

## Control results

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **A.01** Debug vs store builds hit different servers | **Fail** | `constants.dart:3` plain `const` `https://api.housepital.in/v1`; no `String.fromEnvironment`. The pattern is used correctly 8 lines below for `assistantApiUrl` (`:10-11`). Host does not resolve. | One host for every build; a test order would hit production. Add `String.fromEnvironment('API_BASE_URL')` + a staging host. OWNER-TBD, before first host connection. |
| **A.02** Mechanical gate blocks release when deployed schema lags the app; counts **fields** | **Fail** | No gate in either repo. Two live field-level drifts prove a record-level check would not have sufficed: `medications.ts:218` queries `patient_id` on a table without it; `ratings.ts:37,54` query `family_member_id` where the column is `rated_by` (`001_initial_schema.sql:388`). | Both endpoints 500 on first contact. Add a CI step diffing handler column references against the SQL. OWNER-TBD. |
| **A.03** Deploy step named, dated, owned | **Warning** | `docs/DEPLOYMENT_GUIDE.md:386-399` names both rules deploys with a verification command; header dated 2026-08-03. **No named owner**, and neither rules file is confirmed deployed (`storage.rules:8` carries its own `!! DEPLOY REQUIRED !!`). The MySQL schema has no deploy step at all. | Ritual exists, accountability does not. Assign an owner and record the deploy date per environment. OWNER-TBD, pre-launch. |
| **A.04** All schema changes additive with defaults | **Fail** | Client half is good: `store_migrator.dart:58-73` quarantines rather than deletes, frozen literals, `currentVersion = 2`, never stamps a failed step. Server half: no migrations directory on the patient side (`grep -rn "ALTER TABLE" sql/` → nothing) and two handlers already reference columns that were never added. | Server schema evolution is undefined. OWNER-TBD. |
| **A.05** Every synced field round-trips through an encode/apply unit test | **Fail** | `VitalReading` has `fromJson` (`models.dart:355`) and **no `toJson`**; the wire body is hand-built at `api_service.dart:246-261`. No round-trip test exists for any model. | A field added to the model is silently dropped on the wire. Add `toJson` + a round-trip test per synced model. OWNER-TBD. |
| **A.06** Unknown enum raw values from newer versions degrade safely | **Fail** | `models.dart:288` `final String status;` with `status: json['status']` — an unchecked cast into a non-nullable `String`, throwing on null and passing anything else through to UI `switch`es. Three divergent vocabularies exist across the two DBs (`waiting`↔`pending`, `on_leave`↔`leave`, `12hr_day`↔`HD_DAY`). | Silent corruption or a crash on first cross-system read. Parse to a sealed enum with an `unknown` fallback, tested. OWNER-TBD. |
| **B.01** Conflict policy written per record type, test per type | **Fail** | No conflict-policy document in either repo; zero conflict tests. | The choice cannot be reviewed because it has not been made. Deliverable is the document. OWNER-TBD. |
| **B.02** Concurrently-mintable records use deterministic ids | **Fail** | `orders_provider.dart:72-76` (ms timestamp + `Random`), `:124`, `reminders_provider.dart:140`, `delete_account_screen.dart:80-81`, `vitals_screen.dart:727`. `medication_logs` has no unique key on `(medication_id, scheduled_time)`. | Two devices logging the same dose double it forever. Derive ids from stable inputs. OWNER-TBD. |
| **B.03** No screen mints a record on appear | **Fail** | `address_selection_screen.dart:106-110` writes three default addresses on first **read**, persisted at `:126`. `staff_otp_verification_screen.dart:52-55` mints an OTP in `initState` and writes it `merge: true` at `:83`. | Under LWW a blank record clobbers the other device. Create on first real edit. OWNER-TBD. |
| **B.04** Derived state computed from record existence, not a stored flag | **Fail** | `medication_provider.dart:391-400` clears `_takenDoseKeys` and `_refillRequestedIds` — both stored flags; `isSlotLoggedToday` reads them. `logDoseToday` (`:110-127`) never creates the record the flag stands for. | The flag is the only evidence a dose was given, and it is memory-only. OWNER-TBD. |
| **B.05** App suppresses echoes of its own writes | **N/A** | Rationale: no remote change stream is subscribed. `firebase_service.dart:237,255,277` define three listeners with zero call sites; `SyncService` has zero importers. There are no echoes because there is no delivery. **Re-grade the day any listener is subscribed.** | — |
| **B.06** Duplicate detection indexes fingerprint → list | **N/A** | Rationale: no reconciler exists anywhere in `lib/`. Nothing merges two sources of the same record. **Re-grade when one is written.** | — |
| **C.01** Durable outbox surviving kill and reboot | **Fail** | No queue. `app_provider.dart:333-338` posts a vital reading and on failure keeps it in an in-memory list only (`:41`, "never written to storage"). `housepital_pending_deletion` is a durable *record* with zero readers (`delete_account_screen.dart:83`). | Every offline write is lost on kill. OWNER-TBD. |
| **C.02** Failures classified transient / conflict / permanent | **Fail** | Every remote failure is `Log.warn` and continue: `app_provider.dart:180-183`, `:295-299`; `orders_provider.dart:207-210`, `:241-245`; `session_scope.dart:101-104`, `:134-137`; `cart_provider.dart:230`; `reminders_provider.dart:200`. | The checklist's first red flag, present pervasively. OWNER-TBD. |
| **C.03** Permanent failure → one human sentence with a count and a next step | **Fail** | No such surface exists. The only user-visible signal is the `DemoMode` pill, which says "sample data", not "your write failed". | Silence is the enemy. OWNER-TBD. |
| **C.04** Per-record retry caps or quarantine for poison records | **Fail** | `StoreMigrator.quarantine` (`store_migrator.dart:208-218`) covers *storage migration*, not sync, and has zero readers. No retry exists at all, so no cap can exist. | OWNER-TBD. |
| **C.05** Airplane-mode edits on both devices, reconnect, converge — tested this release | **Fail (unverified)** | Not tested. No two-device test exists; no offline reconciliation code exists to test. Stated plainly rather than graded N/A. | OWNER-TBD; requires E-matrix access. |
| **C.06** Killed mid-sync, queue resumes, nothing re-sent with a new identity | **Fail** | No queue. The *teardown* path additionally fails this control: `auth_provider.dart:235-238` is a snapshot-then-remove loop over an unordered `Set` with N platform yields, so a kill mid-logout leaves a nondeterministic partial wipe on a shared phone. | Round-3 H6, unchanged. Fix: read the two preserved values, `prefs.clear()`, write them back; add `__quarantine_` as a preserved prefix. OWNER-TBD, before release. |
| **D.01** Invite → accept, two real accounts, incl. app-not-installed and OS routing | **Fail** | `family_members_screen.dart:22,51` is `setState` over `static final _mockMembers`. Backend `routes/family.ts:103` `POST …/family/invite` is a **stub**: validates `phone`, then `res.json({success:true})` — comment says "For now, just record the invitation"; nothing is recorded. | Correction to round 3, which credited this endpoint as an existing contract. OWNER-TBD. |
| **D.02** Revoke detected, stated plainly, local state cleaned | **Fail** | `routes/family.ts:193` exists server-side; zero client callers. | OWNER-TBD. |
| **D.03** Leave: local + server departure both confirmed, queued and retried | **Fail** | `routes/family.ts:230` exists; zero client callers; no queue (C.01). | OWNER-TBD. |
| **D.04** Leave never deletes the owner's data | **Fail** | Not implemented — cannot be asserted. Not graded N/A: the product ships a family-members screen. | OWNER-TBD. |
| **D.05** Re-invite after leave works | **Fail** | Not implemented. Blocked twice: `family_members.user_id UNIQUE` (`001_initial_schema.sql:45`) means a re-invited user cannot join a second patient. | OWNER-TBD. |
| **D.06** Stop-sharing: participants handle orphaned state | **Fail** | Not implemented. | OWNER-TBD. |
| **D.07** Owner's later edit cannot resurrect a left workspace | **Fail** | Not implemented. | OWNER-TBD. |
| **E.01** Device A current build, Device B one behind | **BLOCKED-OWNER** | Two physical devices, two accounts, current + n-1 builds, a reachable host. | — |
| **E.02** Same record edited on both within seconds | **BLOCKED-OWNER** | As above. Additionally blocked: no documented winner exists (B.01). | — |
| **E.03** Create on A while B offline → B receives on reconnect | **BLOCKED-OWNER** | As above. | — |
| **E.04** Attachment sync while receiving device is LOCKED | **BLOCKED-OWNER** | As above; no attachment pipeline exists (`return_screen.dart:331` sends a local path as `photoUrl`). | — |
| **E.05** Every "it synced" claim verified by reading the other device | **Fail** | Zero multi-device tests. Every success affordance in the app fires from local state — `logDoseToday` returns `true` with no I/O (`medication_provider.dart:110-127`); `addOrder` shows confirmation off an in-memory insert (`orders_provider.dart:104-113`). | "It worked on my phone" is the app's only evidence model. OWNER-TBD. |
| **F.01** User-reachable re-sync reporting a real count | **Fail** | `grep -rl RefreshIndicator lib/screens/ \| wc -l` → 5 of 91 screens; none reports a count; no polling; `SyncService` unimported. | OWNER-TBD. |
| **F.02** Membership repair verifies server truth and reroutes transport | **N/A** | Rationale: no repair affordance exists anywhere in `lib/`. Vacuously clean — nothing to verify. **Re-grade when one ships.** | — |
| **F.03** Repair actions idempotent | **N/A** | Rationale: as F.02. | — |
| **F.04** Orphaned records healed by a sweep; the write path that creates them is guarded | **Fail** | `orders_provider.dart:33` — `'housepital_orders_' + (_patientId ?? '_none')` is an **unguarded write path that mints orphans by design**, and in production it is the *only* path taken (FAIL-1). No sweep, no reader, no assertion. `__quarantine_v1_*` is a second orphan family with zero readers. | Two on-disk stores of real order history that nothing will ever attribute to a patient. Guard the key (assert non-`_none`) and write a sweep. OWNER-TBD, before release. |
| **F.05** Cascade deletes mint explicit tombstones for every child | **N/A** | Rationale: no tombstone model and no cascade-delete path exists client-side; `cancelOrder` (`orders_provider.dart:165-198`) mutates in place. **Re-grade when deletion propagates.** | — |
| **G.01** Change tokens/cursors/checkpoints persist; expiry triggers idempotent resync | **Fail** | No cursor, token or checkpoint exists in `lib/`. `sync_service.dart` polls on a timer with no cursor and has zero importers. | First sync and full resync are the same operation, unbounded. OWNER-TBD. |
| **G.02** Conflict behaviour accounts for clock skew, server timestamps, causal ordering, duplicate delivery, out-of-order events | **Fail** | Every id and timestamp is device-clock `DateTime.now()` (B.02 sites). No server timestamp is read anywhere. No sequence or vector. | OWNER-TBD. |
| **G.03** Delete-vs-edit, parent-vs-child delete, move-vs-edit, simultaneous membership changes have explicit tested outcomes | **Fail** | None defined, none tested. Membership changes are not implemented (D.\*). | OWNER-TBD. |
| **G.04** Tombstone retention exceeds the max offline/skew window, or full reconciliation prevents resurrection | **Fail** | No tombstones. Deletion is local mutation (`orders_provider.dart:186-195`) or key removal (`session_scope.dart:126,131`). A resurrection is exactly what FAIL-2 describes on the `_none` key. | OWNER-TBD. |
| **G.05** Lists, counters, aggregates, append-only histories use type-appropriate merge semantics | **Fail** | Order history — an append-only log — is persisted as one whole-document `setString` blob (`orders_provider.dart:205`), i.e. whole-list LWW. Same for assessments, cart, saved items, reminders, addresses. | Any concurrent writer loses every entry it did not know about. OWNER-TBD. |
| **H.01** Login expiry, token refresh, logout, account switching, deletion, device removal, tenant changes cannot cross-link or leak cached data | **Fail** | The module's headline. `housepital_orders__none` survives a patient switch and is re-read on the next cold start (FAIL-1/FAIL-2). `app_provider.dart:151` adopts an identity without announcing. `auth_provider.dart:235-238` is a non-atomic wipe. `__quarantine_v1_*` — an upgrading user's whole order history — is destroyed by logout with zero readers. `profile_photo_path` and its JPEG survive a switch. | On a shared phone, a switch-then-relaunch renders the previous person's order history. Fix FAIL-1/2 and add `__quarantine_` to `preserved`. OWNER-TBD, before release. |
| **H.02** Large attachments: resumable, hashed, deduped, quota-handled, partials cleaned | **Fail** | No upload pipeline. `return_screen.dart:331` sends a local device path as `photoUrl`. `storage.rules` defines chat/concern photo paths and is undeployed (`storage.rules:8`). | OWNER-TBD. |
| **H.03** Large accounts: pagination, incremental fetch, batching, memory, disk growth, first-sync and full-resync duration | **Fail** | One paginated endpoint in the whole client (`api_service.dart:605-608`, `getTransactions` optional `limit`). Everything else fetches whole collections; `GET /patients` returns all rows unbounded (`routes/patients.ts:45`). Local stores are whole-blob JSON with no size bound. | Untested at any scale. OWNER-TBD. |
| **H.04** Push loss, delayed background execution, locked-device file protection, OS throttling do not prevent convergence | **Fail** | `main.dart:345-377` — the FCM handler calls `Navigator.pushNamed` and `showSnackBar` and reloads **no provider**. There is no background fetch and no catch-up on foreground. | A missed push is a permanently missed update. OWNER-TBD. |
| **H.05** Sync metadata and diagnostics expose no unnecessary sensitive data; safe for support export | **Warning** | `logger.dart:57-66` is a single chokepoint with no redaction and no allowlist; the `TODO(observability)` at `:64-66` is explicitly designed to make Crashlytics forwarding "a one-line change". Today nothing leaves the device, so exposure is nil — the risk is that enabling it ships whatever a `Log.warn` message happens to contain. | Add redaction **before** the forwarding line is uncommented. OWNER-TBD, before observability work starts. |
| **I.01** Every remote read and mutation verifies user, tenant, role, record scope, sharing auth on the server | **Fail** | `housepital-backend/functions/src/middleware/auth.ts:43-51` sets `patientId = ""` for an authenticated but un-onboarded user; `:104` guards `if (patientId && authReq.patientId && …)` — the empty string is falsy, so the request passes to handlers that filter on the URL param (`medications.ts:35,121,183,260`, `patients.ts`). Any authenticated phone number can read any patient by guessing an id. | Cross-patient PHI read. Change the guard to reject when `authReq.patientId` is empty. Cross-filed to the security audit. OWNER-TBD, blocker. |
| **I.02** Share links/invitations unguessable, scoped, expiring, revocable, forwarding-safe | **Fail** | `routes/family.ts:103-125` mints no token, records nothing and sends nothing — it returns `{success:true}`. There is no invitation artifact to make unguessable. | OWNER-TBD. |
| **I.03** Idempotency keys and deterministic identity avoid duplication without collision risk | **Fail** | No idempotency key on any request. `patient_log_${medicationId}_$timeSlot` (`medication_provider.dart:117`) has no date; `DEL-<ms.toRadixString(36)>` (`delete_account_screen.dart:80-81`); `HPL-BOOK-<last 7 digits of ms>` (`orders_provider.dart:72-76`) — a 7-digit window that repeats every ~2.8 hours. | Replay duplicates and same-millisecond collisions. OWNER-TBD. |
| **I.04** Downloaded records and payloads treated as untrusted, validated before storage or rendering | **Fail** | `models.dart:288,299` `status: json['status']` — unchecked cast. `orders_provider.dart:220-227` `jsonDecode(...) as List` then `.cast<Map<String, dynamic>>()` — a lazy cast that throws at read time, not parse time. `api_service.dart:240-242` `(data['vitals'] as List)`. Server-side Zod validation was added for POST bodies (`7417387`) but nothing validates responses on the client. | A malformed or hostile payload crashes or renders unchecked. Validate at the boundary. OWNER-TBD. |

---

## Scorecard

**Pass 0 · Warning 2 · Fail 38 · N/A 5 · BLOCKED-OWNER 4 — of 49 controls.**

| Section | Pass | Warning | Fail | N/A | BLOCKED-OWNER |
|---|---|---|---|---|---|
| A. Schema & environments (6) | 0 | 1 | 5 | 0 | 0 |
| B. Conflict & concurrency (6) | 0 | 0 | 4 | 2 | 0 |
| C. Offline & the outbox (6) | 0 | 0 | 6 | 0 | 0 |
| D. Sharing lifecycle (7) | 0 | 0 | 7 | 0 | 0 |
| E. Two-phone QA matrix (5) | 0 | 0 | 1 | 0 | 4 |
| F. Recovery & repair (5) | 0 | 0 | 2 | 3 | 0 |
| G. Change tracking / ordering / deletion (5) | 0 | 0 | 5 | 0 | 0 |
| H. Identity, storage, transport, scale (5) | 0 | 1 | 4 | 0 | 0 |
| I. Sync security & integrity (4) | 0 | 0 | 4 | 0 | 0 |
| **Total (49)** | **0** | **2** | **38** | **5** | **4** |

Round 3 scored 0 ✅ / 5 ⚠ / 20 ❌ / 6 N/A / 4 BLOCKED against a 35-item template. The counts are not
comparable — v2.0 adds sections G, H and I (14 controls, all new to this module and all Fail) and
tightens the N/A rule. On the 35 controls the two rounds share, the net movement is **one control
improved** (the vitals-chart evidence under B.03/A.06 is no longer a fabrication finding) and **two
controls degraded in evidence** (F.04 and H.01, both because of the `_none` key created this round).

**Zero Pass across 49 controls is a harsh number and it is the correct one.** This control family
presupposes a service that mediates shared state. The app is pointed at no host; the two hosts that
exist disagree about the schema; and the local half of shared state — the half that is live today —
fails on the finding in FAIL-2. I looked for a defensible Pass and did not find one. The vitals fix
is genuine but it is a demo-honesty repair, not a sync control.

---

## Release blockers (every Fail)

Ordered by what would hurt a real family first. All 38 Fails are listed in the control table; these
are the ones that must be answered before this module can be re-graded.

1. **I.01 — cross-patient PHI read on the patient API.** `auth.ts:43-51` + `:104`. Any authenticated
   phone number can read any patient's medications, vitals and reports by guessing an id. A
   two-token change; no reason to carry it another round.
2. **The dose logged to nowhere.** `medication_provider.dart:110-127`. Fourth round unchanged. The
   UI asserts a clinical fact that exists only in RAM. Client-unfixable without the schema change in
   §backend item 4.
3. **H.01 / FAIL-2 — a patient switch followed by a relaunch renders the previous person's order
   history.** `orders_provider.dart:33,43-45` + `main.dart:214`. This is round 2's defect, live
   again, on a shared phone, in an app whose switch sheet exists so families do not log out.
4. **FAIL-1 — the round-4 fix is inert in the shipped build.** The announce that drives the whole
   fan-out requires a reachable host; the seed at `app_provider.dart:151` — the only identity
   assignment a demo build reaches — does not announce.
5. **A.02 / A.04 — two backend handlers query columns that do not exist**
   (`medications.ts:218`, `ratings.ts:37,54`). They 500 on first contact, and no gate would catch
   them because both faults are field-level.
6. **C.06 / H.01 — logout is not an atomic wipe and destroys quarantined data.**
   `auth_provider.dart:235-238`. Now compounded: `__quarantine_v1_*` is the sole home of every
   upgrading user's order history (`store_migrator.dart:58-73`) and is not preserved.
7. **B.05 red flag — every remote error path logs and returns.** Twelve sites listed under C.02.
8. **D.01–D.07 — the entire sharing lifecycle is unimplemented**, and the backend invite endpoint is
   a stub that returns success without doing anything (`routes/family.ts:103-125`).
9. **Firestore rules deny every direct call.** `firestore.rules:67,70,72,90,94,99` compare
   `request.auth.uid` to `patientId` while `grep -rn "\.uid" lib/` returns zero. `storage.rules:18-29`
   diagnoses this exact bug for the sibling file and it was still not applied here.

---

## Warnings requiring risk acceptance

| # | Control | Impact | Mitigation | Owner / due |
|---|---|---|---|---|
| W1 | **A.03** — rules deploy documented but unowned and unconfirmed | Editing a rules file changes nothing live; nobody is accountable for noticing | Assign an owner; record deploy date per environment; run `firebase firestore:rules get` as the release evidence | OWNER-TBD · pre-launch |
| W2 | **H.05** — no redaction at the log chokepoint, with a one-line Crashlytics TODO | Zero exposure today; enabling forwarding would ship unredacted `Log.warn` message contents off-device | Add an allowlist/redactor to `logger.dart:57-66` **before** uncommenting `:64-66` | OWNER-TBD · before observability work |

Additionally recorded as accepted risk, not graded: the switch-sheet **double clear**
(`home_screen.dart:1774` plus the hook) is redundant but idempotent; the **fire-and-forget persist
ordering** is correct today only because `_ordersKey` and `jsonEncode(_orders)` are both evaluated
after the first `await` (`orders_provider.dart:204-206`) — undocumented and untested, and FAIL-4
shows the one interleaving where it breaks.

---

## BLOCKED-OWNER — needs access or a decision I do not have

| # | Item | What is needed |
|---|---|---|
| 1 | **Is the patient-switch feature in scope at all?** | The server says one user → one patient (`family_members.user_id UNIQUE`, `001_initial_schema.sql:45`; `auth.ts:39-41`; `verifyPatientAccess:104`). The client says one user → many. **Decide before FAIL-1..4 are fixed** — if the server model wins, `switchPatient`, the switch sheet and most of `SessionScope`'s switch semantics should be deleted and `SessionScope` kept as a logout teardown. Three rounds of PHI repair have been built without this decision. |
| 2 | **Merge vs. one-way replication** (round 3, unchanged) | One fact I still cannot determine from the repos: **does `housepital_db` already hold real staff data in production?** If no → merge into one database with two APIs. If yes → one-way replication with a declared owner per noun. Either way the conflict policy must be written per record type (B.01). |
| 3 | **Medication dose logging** | The `medication_logs` schema change — `patient_id`, `logged_by_type`/`logged_by_id`, `client_log_id`, `UNIQUE(medication_id, scheduled_time)` — plus the clinical decision: when the family app and the staff app both log the same slot, is that one dose or a double-dose to warn about? |
| 4 | **E.01–E.04 two-phone QA matrix** | Two physical devices, two real accounts on one patient, current + n-1 builds, a reachable host, a locked-device attachment test. Blocked twice over: item 1 means two accounts cannot currently watch one patient. |
| 5 | **A.01 environment split** | A staging host per environment, so `constants.dart:3` can become `String.fromEnvironment('API_BASE_URL', …)` — the pattern already used correctly at `:10-11`. |
| 6 | **A.02/A.03 rules deploy gate** | A CI credential with `firebaserules.releases.get`, plus confirmation of whether `firestore.rules` and `storage.rules` are deployed. Both remain unknown across four rounds. |
| 7 | **Pending-deletion lifecycle** | Which endpoint replays `housepital_pending_deletion`, what acknowledges it, what the user sees while pending. Today it has zero readers (`delete_account_screen.dart:83`). |

---

## Limitations of this audit

- **MASTER-4.04: this is a SOURCE review.** No release artifact was built, no device was run, no
  production traffic was observed. Per the round-4 brief I did not run `flutter test`,
  `flutter build`, `flutter clean` or `pod install`. Where I cite central results — `flutter analyze`
  clean, design gate passes, 1,819 tests across 101 files pass — those are the brief's figures, not
  mine. Every claim about test *content* comes from reading test sources.
- **The FAIL-1/FAIL-2 behaviour is derived by static trace, not observed.** The chain is:
  `main.dart:214` (no `patientId`) → `orders_provider.dart:43` → `:33` (`_none`) →
  `session_scope.dart:76` as the sole `setPatient` caller → `app_provider.dart:178` as the sole
  demo-build-relevant announce, inside a `try` requiring a reachable host. Each link is cited and
  checkable; the composite has not been executed. A single instrumented run — log `_ordersKey` on
  every `_persistAndNotify` — would confirm or refute it in minutes and should be done before the
  fix is designed.
- **Live posture of `firestore.rules` and `storage.rules` is unknown.** Neither is confirmed
  deployed; `storage.rules:8` carries its own deploy banner. I graded the file contents, not the
  live rules.
- **Concurrency claims in FAIL-4 are structural, not empirical.** I assert the *absence* of a busy
  flag and of a generation token — both directly verifiable at `home_screen.dart:1767-1776` and by
  the absence of any such field in `app_provider.dart` / `session_scope.dart` / `orders_provider.dart`.
  I do not assert that a specific interleaving reproduces on a specific device; Dart's ordering
  across a platform-channel reply is not a guarantee I can test from source.
- **`housepital-api` (Laravel) is not a git working copy**, so I could not confirm whether it has
  changed since round 3; I re-read its migrations directly. `housepital-backend` HEAD is `7417387`
  (26 Mar 2026), which predates round 3, so its findings are re-verified rather than re-derived.
- **Re-verified per the brief:** `ANTHROPIC_API_KEY` does not appear in `lib/`; it remains
  server-side. Not re-litigated.
- **Owner decisions were measured, never graded Fail:** white-on-orange, manpower pricing, and the
  floating glass pill nav are out of this module's scope and were not assessed.
