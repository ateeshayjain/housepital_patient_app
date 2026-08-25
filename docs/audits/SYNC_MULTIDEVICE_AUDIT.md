# Sync & Multi-Device Checklist (App-Agnostic) — Audit round 2 vs commit `820060b`

**Date:** 2026-08-03 · **Previous round:** commit `803124d` · **Branch:** `fix/five-tab-nav`
**Scope:** read-only. No files under `lib/`, `test/` or config were modified; this report file is the only write.

---

## Headline

The PHI fix is **real but incomplete, and it is incomplete in the way that matters**: the wipe
clears what a reviewer sees on screen and leaves the copies on disk and the copies outside the
provider tree.

Five concrete gaps, each with a live blast radius:

1. **`_vitalsHistory` is not cleared** — the exact field round 1 named by line number
   (`app_provider.dart:41`). The new `clearPatientScopedData()` clears the seven fields around it
   and skips it, and the new regression test asserts those same seven and not this one.
2. **`CartProvider.clear()` re-writes patient A's saved-items list to disk** during the switch.
3. **`OrdersProvider.clearPatientScopedData()` never touches storage** — the order history comes
   back for the new patient on the next cold start.
4. **`RemindersProvider`, saved addresses, daily ratings and the dashboard cache blob are not in
   `SessionScope` at all.**
5. **The doctor handover PDF ignores the provider tree entirely** and is built from
   `DemoData.patient` — after any switch it exports the demo patient's name, medical history,
   medications and vitals into a document designed to be handed to a physician.

And the finding round 1 called worse than the leak is **unchanged**: a medication dose tapped
"Taken" is written to a plain in-memory list, is not sent anywhere, and is gone on app kill —
while the button gives haptic confirmation and the adherence percentage counts it.

**Checklist grades did not move.** 19 ❌ in round 1, 19 ❌ now. Ten repo-wide blockers were
closed at `820060b`; none of them was a sync-checklist item.

---

## Changed since round 1

| Round-1 finding | Status now | Evidence |
|---|---|---|
| **PHI leak on patient switch** (Blocker 1) | ⚠️ **Partially fixed** | `switchPatient` now calls `clearPatientScopedData(notify: false)` first (`lib/providers/app_provider.dart:158-167`); `SessionScope.clearPatientData` clears MyCare/Medication/Billing/Orders + cart (`lib/utils/session_scope.dart:28-36`), wired at `lib/screens/home/home_screen.dart:1771`. **Misses:** `_vitalsHistory`, `_savedItems`, all six unscoped SharedPreferences keys, `RemindersProvider`, `AssistantProvider`, the handover PDF. See NEW-1…NEW-6. |
| **PHI leak on logout** (Blocker 2) | ✅ **Fixed** for in-memory state | `SessionScope.clearSession` → `AppProvider.clearSession()` nulls `_currentPatient` and `_patients` (`app_provider.dart:189-194`), called before `AuthProvider.logout()` at `lib/screens/settings/settings_screen.dart:457-458` and `lib/screens/settings/delete_account_screen.dart:64-65`. `logout()` then `prefs.clear()`s the disk side (`auth_provider.dart:217-227`). The disk gaps in NEW-2…NEW-5 are covered on logout by `prefs.clear()` — they are switch-only. One ordering caveat: NEW-13. |
| `_seedDemoDataIfEmpty` no-op after first load | ✅ **Fixed as a side effect** | `_seedDemoDataIfEmpty`'s `if (_activeDeployment == null)` guard (`app_provider.dart:258`) now passes on a switch because the clear ran first, so patient B gets a fresh seed instead of A's data. |
| Demo data silently substituted | ⚠️ **Improved, three gaps** | `lib/data/demo_mode.dart` + banner at `lib/screens/main_shell.dart:64`. Gaps: banner absent on every pushed route (NEW-10); a single global flag reset by one provider (NEW-9); three fallback paths never set it (NEW-11). |
| Medication doses logged to nowhere (Blocker 3) | ❌ **Unchanged** | `lib/providers/medication_provider.dart:110-127` — still `_todayLogs.add(...)` with no API call; `getMedicationLogs` is still the only medication-log method in `lib/services/i_api_service.dart`. Restated in full at §0.2. |
| Every direct-Firestore call denied by deployed rules (Blocker 4) | ❌ **Unchanged** | `firestore.rules:67,70,90,94,99` still compare `request.auth.uid` to `patientId`; `:133-134` still `allow write: if false` on `active_sessions`, which `lib/screens/my_care/staff_otp_verification_screen.dart:80-89` writes to, unawaited, from `initState:55`. |
| `SyncService` is dead code (High 5) | ❌ **Unchanged** | `grep -rn "sync_service\|SyncService" lib/ test/` → one comment at `app_provider.dart:296`. The file is imported nowhere. |
| Three Firestore listeners subscribed by nobody (High 6) | ❌ **Unchanged** | `lib/services/firebase_service.dart:237,255,277` — still zero call sites. |
| FCM never refreshes state (High 7) | ❌ **Unchanged** | `lib/main.dart` FCM handlers still snackbar/navigate only; `MyCareProvider.refresh`'s "Called by FCM handler" comment (`my_care_provider.dart:103`) is still false. |
| 16 unauthenticated ad-hoc `ApiService()` instances (High 8) | ❌ **Unchanged** | `grep -rn "ApiService()" lib/screens/ \| wc -l` → **16**, including `notifications_screen.dart:33,149`. |
| Family-member sharing is a mock (High 9) | ❌ **Unchanged** | `lib/screens/settings/family_members_screen.dart:22` `static final _mockMembers`, `:51` `_members = List.from(_mockMembers)`. |
| Equipment return sends a local path as `photoUrl` (High 10) | ❌ **Unchanged** | `lib/screens/rental/return_screen.dart:331` — `photoUrl: _photoPath`. |
| No polling anywhere | ❌ **Unchanged** | Only `Timer.periodic`s are the 50-min token refresh (`auth_provider.dart:78`), a 1-min local duty clock (`home_screen.dart:71`), two OTP countdowns and a call timer. |
| Pull-to-refresh on 5 of 92 screens | ❌ **Unchanged** | Same five files. |
| No local store versioning | ✅ **Fixed (new, and good)** | `lib/services/store_migrator.dart` — version stamp, ordered steps, and a `quarantine()` that copies unparseable data aside instead of destroying it. Run from `main()` before providers read storage. One heuristic gap: NEW-14. |
| **Round-1 error of my own** | 🔧 **Corrected** | Round 1 said `CacheService` was read at `app_provider.dart:189,213`. Wrong: `CacheService.get()`, `.clear()` and `.remove()` are called **zero** times in `lib/`. The only call is the write at `app_provider.dart:248`. See NEW-8. |

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A | BLOCKED-OWNER |
|---|---|---|---|---|---|
| A. Schema & environments | 1 | 2 | 3 | 0 | 0 |
| B. Conflict & concurrency | 0 | 2 | 3 | 1 | 0 |
| C. Offline & the outbox | 0 | 1 | 4 | 1 | 0 |
| D. Sharing lifecycle | 0 | 0 | 6 | 1 | 0 |
| E. Two-phone QA matrix | 0 | 0 | 1 | 0 | 4 |
| F. Recovery & repair | 0 | 0 | 2 | 3 | 0 |
| **Total (35 items)** | **1** | **5** | **19** | **6** | **4** |

Identical to round 1. The ten blockers closed at `820060b` were release-hygiene items
(Info.plist, icons, payment gating, route stub, delete-account, store versioning) plus a partial
PHI fix; not one of them changes a line on this checklist.

---

## Part 1 — Adversarial verification of the PHI fix

### What the fix does correctly

`lib/utils/session_scope.dart` is a good piece of design: one file that names the providers
holding patient state, a doc comment explaining why device-level providers (theme, language,
auth) must *not* be cleared, and two entry points with distinct meanings — `clearPatientData`
(patient changes, stay signed in) and `clearSession` (logout, forget who the patient was).
`AppProvider.switchPatient` clears **before** adopting the new patient (`app_provider.dart:163-164`)
rather than after, which is the correct order and closes the window round 1 described.
`test/providers/patient_scope_isolation_test.dart` states the contract in prose and is honest
about what it can and cannot assert (`:97-104`). All of that is right.

### NEW-1 ❌ BLOCKER — `_vitalsHistory` is not cleared. Patient A's manually entered readings render in patient B's chart.

`lib/providers/app_provider.dart:176-186`:

```dart
void clearPatientScopedData({bool notify = true}) {
  _activeDeployment = null;
  _todayAttendance  = null;
  _latestVitals     = null;
  _todayReport      = null;
  _amountDue        = 0;
  _dueDate          = null;
  _dashboardError   = null;
  _lastUpdatedText  = null;
  if (notify) notifyListeners();
}
```

The field it omits is declared eleven lines above the doc comment that claims the method
"Clears every field that belongs to ONE patient":

- `app_provider.dart:41` — `final List<VitalReading> _vitalsHistory = [];`
- `app_provider.dart:75` — `List<VitalReading> get vitalsHistory => List.unmodifiable(_vitalsHistory);`
- `app_provider.dart:280` — `addVitalReading` appends to it and never removes.
- **`lib/screens/reports/vitals_screen.dart:121`** — `final vitals = _mergedVitals(context.watch<AppProvider>().vitalsHistory);`

Because it is `final`, it cannot be reassigned; clearing it requires `_vitalsHistory.clear()`,
which appears nowhere in `lib/`. Round 1 named this field explicitly — *"`_vitalsHistory`
(line 40) is never cleared under any code path, so A's manually entered readings render inside
B's vitals chart"* — and the fix went around it.

**Impact:** switch from Rajesh to Sunita and every BP/sugar/SpO2 reading a family member typed
in for Rajesh is merged into Sunita's vitals chart and trend line, indistinguishable from hers.
This is the highest-consequence surface in the app: the screen a family member opens to decide
whether to call a doctor.

**The regression guard institutionalises the gap.** `test/providers/patient_scope_isolation_test.dart:63-84`
asserts `activeDeployment`, `todayAttendance`, `latestVitals`, `todayReport`, `amountDue`,
`dueDate`, `lastUpdatedText` — the seven fields the implementation happens to clear. There is no
`expect(app.vitalsHistory, isEmpty)`. The test file's own header says *"If a provider gains new
patient-scoped state, add it to SessionScope AND add an assertion here — the point of this file
is that the next person cannot forget."* It was written from the implementation, not from the
field list, so it certifies the bug.

**Fix:** add `_vitalsHistory.clear();` to `clearPatientScopedData`, and
`expect(app.vitalsHistory, isEmpty)` to the test after seeding a reading via `addVitalReading`.

### NEW-2 ❌ BLOCKER — the switch *writes* patient A's saved-items list back to disk.

`lib/providers/cart_provider.dart:198-202`:

```dart
void clear() {
  _items.clear();
  _persist();          // ← writes BOTH keys
  notifyListeners();
}
```

`_persist()` (`cart_provider.dart:206-217`) writes `housepital_cart_items` **and**
`housepital_saved_items` from the current in-memory lists. `_savedItems` (`:12`) was not cleared,
so the switch actively re-serialises patient A's saved-for-later medical equipment to disk under
the incoming patient. `clearSaved()` exists at `cart_provider.dart:159-163` and `SessionScope`
does not call it (`session_scope.dart:35` calls `clear()` only).

**Impact:** the saved list is visible from the cart screen and equipment detail (`isSaved()` at
`:195` drives the filled bookmark). Patient B sees an oxygen concentrator and a hospital bed
"saved" that belong to patient A's care plan. Unlike the in-memory leaks, this one survives app
restart. The wipe is not merely incomplete here — it is a write.

**Fix:** `SessionScope.clearPatientData` should call `clearSaved()` as well as `clear()`, or
`CartProvider` should grow a single `clearAllForPatientSwitch()`.

### NEW-3 ❌ HIGH — `OrdersProvider` clears memory and leaves storage; the history returns on next launch.

`lib/providers/orders_provider.dart:212-217` sets `_orders = []` and `_assessments = []` and
calls `notifyListeners()`. It does **not** call the save path at `:167-168`
(`prefs.setString(_ordersKey, ...)`, `prefs.setString(_assessmentsKey, ...)`), so
`housepital_orders` and `housepital_assessments` keep patient A's records on disk. The
constructor at `:20-22` calls `_loadFromStorage()` (`:176`) on every app start.

**Impact:** the switch looks clean, the user backgrounds the app, iOS reclaims it, and patient
A's entire booking and assessment history reappears under patient B — with amounts, service
types and dates. This is precisely the shape the brief asked me to hunt for: a wipe that looks
complete in the UI and leaves the record on disk. (On logout this is covered, because
`AuthProvider.logout()` calls `prefs.clear()`.)

**Fix:** either persist the emptied lists, or — better, since both patients belong to one account —
prefix the keys with the patient id and let each patient's blob sit untouched under its own key.

### NEW-4 ❌ HIGH — four stores are not in `SessionScope` at all.

| Store | Written at | Contents | Cleared on switch? |
|---|---|---|---|
| `housepital_reminders` | `lib/providers/reminders_provider.dart:179` | Care-calendar reminders (medication, appointments, follow-ups) | **No** — `RemindersProvider` has no `clearPatientScopedData` and is absent from `session_scope.dart` |
| `housepital_saved_addresses` | `lib/screens/checkout/address_selection_screen.dart:126` | Name, phone, flat, street, pincode | **No** — a static helper, no provider |
| `daily_rating_YYYY-MM-DD` | `lib/screens/my_care/my_care_screen.dart:615` | Per-day care satisfaction score | **No** |
| `housepital_cache_dashboard_<patientId>` | `lib/services/cache_service.dart:19` via `app_provider.dart:248` | Billing summary (amount due, due date) | **No** — see NEW-8 |

`RemindersProvider` is the one that matters clinically: it is constructed at `lib/main.dart:217`
(`RemindersProvider()..load()`), it is the Care Calendar's backing store, and its reminders name
medications and appointments. It has no clear method of any kind.

**Fix:** add `clearPatientScopedData()` to `RemindersProvider` (clearing the list *and*
persisting), register it in `SessionScope`, and move the address/rating keys behind providers so
one file can still name everything that holds patient state.

### NEW-5 ❌ BLOCKER — the doctor handover PDF is hardcoded to the demo patient and cannot be fixed by any wipe.

`lib/services/handover_report_service.dart:97-108`:

```dart
Future<Uint8List> buildHandoverPdf({DateTime? now}) async {
  ...
  final patient      = DemoData.patient;
  final MedicalHistory mh = DemoData.medicalHistory;
  final medications  = DemoData.medications.where((m) => m.isActive).toList();
  final vitals       = DemoData.vitalsHistory;
  final report       = DemoData.todayReport;
  final services     = DemoData.activeServices;
  final staffOnDuty  = DemoData.icuServiceDetail.staffOnDuty;
  final appointments = DemoData.upcomingAppointments;
```

The method takes no patient argument and reads no provider. It is exposed as **"Share doctor
handover report"** from My Care (`lib/screens/my_care/my_care_screen.dart:550`, role-gated per
`:165`) and from the medications and schedule screens (`medications_screen.dart:12`,
`medication_schedule_screen.dart:9`).

**Impact:** this is worse than an on-screen leak. After switching to patient B — or on a device
where a family member is signed in at all — the exported PDF carries **patient Rajesh's name,
medical history, active medication list and vitals**, and the whole point of the artefact is to
hand it to a doctor. It is a cross-patient PHI disclosure to a third party, in a document with a
name on it, and `SessionScope` structurally cannot reach it because the service never consults
the provider tree. It also sets no `DemoMode` flag, so the PDF carries no "sample data" marking.

**Fix:** `buildHandoverPdf({required Patient patient, required List<VitalReading> vitals, ...})`,
fed from `AppProvider`/`MedicationProvider`; refuse to build when `currentPatient == null`; stamp
"SAMPLE DATA — NOT A MEDICAL RECORD" across the page whenever `DemoMode.isServingDemoData`.

### NEW-6 ❌ HIGH — `AssistantProvider` is still hard-bound to the demo patient, and its transcript survives logout.

`lib/main.dart:231-273`, unchanged from round 1:

- `:233` — `final patientId = DemoData.patient.id;`
- `:243` — `const role = UserRole.primaryContact;`
- `:259` — `deploymentId: DemoData.icuDeployment.id`
- `:257` / `:269` — that id is passed to both `AssistantExecutor` and `AssistantProvider`

The provider is created once and never rebuilt against `AppProvider.currentPatient`. Every
assistant-executed action — `raiseConcern`, `createAssessmentRequest`, cart adds via
`AssistantLocalActions` (`:264-265`) — is filed against `pat_demo_rajesh` regardless of who is
selected, and the assistant reasons about the wrong patient's context.

Separately, `AssistantProvider._messages` (`lib/providers/assistant_provider.dart:44`) is a
conversation transcript in which a family member types things like *"has papa's sugar been high
this week"*. It is not in `SessionScope`, so it survives both a patient switch **and a logout** —
`prefs.clear()` does not touch in-memory provider state, and this provider is never cleared.

**Fix:** make it a `ChangeNotifierProxyProvider<AppProvider, AssistantProvider>` keyed on
`currentPatient?.id`, and give it a `clearPatientScopedData()` that empties `_messages`.

### NEW-7 ⚠️ — screen-local `State` still holds patient data across a switch.

`SessionScope` clears providers; it cannot clear a `StatefulWidget`'s fields, and three screens
keep patient data there:

- `lib/screens/settings/family_members_screen.dart:46,51` — `_members`, seeded from a static mock
- `lib/screens/documents/document_repository_screen.dart:80` — `_documents`, a hardcoded list of
  medical documents, mutated by scan/upload at `:686`
- `lib/screens/checkout/address_selection_screen.dart` — addresses held in state after
  `loadAddresses()`

In practice these are disposed when the screen pops, so the switch (initiated from Home) will
usually have torn them down. It is bounded today, but it is the reason a `SessionScope` alone
cannot be the whole answer: the contract needs to be "no screen caches patient data in its own
State", enforced by review.

### NEW-8 ⚠️ — the dashboard cache is write-only PHI, never read and never cleared.

Correcting my round-1 claim: `CacheService.get()` is called **zero** times in `lib/`.
`grep -rn "CacheService" lib/ | grep -v cache_service.dart` returns exactly one line —
`app_provider.dart:223`, whose only use is the write at `:248` (`await cache.cache(cacheKey, billing)`).
`clear()` (`cache_service.dart:38`) and `remove()` (`:46`) are also called zero times.

So `housepital_cache_dashboard_pat_A` is written to disk on API success, never read back, and
never removed on a patient switch. The comment at `app_provider.dart:207` — *"Load dashboard data
from API with offline caching"* — describes a read path that does not exist.

Bounded today because the write only fires when the API succeeds and the API never succeeds. It
stops being bounded the day the backend comes up.

**Fix:** either wire `CacheService.get` into `loadDashboard`'s catch branch and call
`CacheService.remove('dashboard_$outgoingId')` from `SessionScope`, or delete the write.

### NEW-9 ⚠️ REGRESSION RISK introduced by the fix — one provider's success takes the banner down for all of them.

`DemoMode` is a single global `ValueNotifier<bool>` (`lib/data/demo_mode.dart:15-16`). Six sites
raise it (`billing_provider.dart:43`, `app_provider.dart:260`, `my_care_provider.dart:50,98`,
`medication_provider.dart:191,236`, `orders_provider.dart:199`) and **exactly one** lowers it:

`lib/providers/app_provider.dart:246-247`
```dart
// Live data arrived — take the sample-data banner down.
DemoMode.reset();
```

**Impact:** the flag is a per-app boolean answering a per-provider question. If the dashboard
endpoint recovers while medications, active services, orders or billing are still on their demo
fallbacks — entirely plausible during a partial outage, and the ordering is a race between
independent `Future.wait`s — `AppProvider` lowers the banner and the sample medication schedule
is presented as the patient's own with no warning. No other provider can re-raise it afterwards
without a fresh load, and none re-marks on notify.

**Fix:** make it a set — `DemoMode.mark('medications')` / `DemoMode.clear('medications')` — with
the banner listening to `isNotEmpty`, and name the affected areas in the banner text.

### NEW-10 ⚠️ — the sample-data banner is absent on every clinical detail screen.

`lib/screens/main_shell.dart:58-68` puts `const _DemoDataBanner()` in a `Column` above the
`IndexedStack` of the five root tabs. Any pushed route covers the shell, so the banner is **not**
visible on: `vitals_screen`, `medication_schedule_screen`, `care_calendar_screen`,
`daily_report_screen`, invoice detail, `document_repository_screen`, `order_tracking_screen`.

The banner's own doc comment (`main_shell.dart:129-131`) states the risk it exists to prevent —
*"a patient must never be one dismissed snackbar away from mistaking sample vitals for their
own"* — and the vitals detail screen, where sample vitals are actually read in detail, is one
`Navigator.push` away from having no banner at all.

**Fix:** hoist it into a `builder:` on `MaterialApp` so it sits above every route, or add it to
`GlassAppBar`'s bottom so every screen inherits it.

### NEW-11 ⚠️ — three demo fallbacks never set the flag.

- `lib/providers/blog_provider.dart:38` and `:68` — `_articles = _filtered(DemoData.articles, ...)`
  in the catch, no `markServingDemoData()`. Low clinical weight.
- `lib/providers/app_provider.dart:137` — `_currentPatient = DemoData.patient` seeds the demo
  patient's identity; the catch at `:151` keeps it. No flag is set here (it is set later by
  `_seedDemoDataIfEmpty`, so in practice the banner appears — but the patient's own name, age and
  address are demo values before that runs).
- `lib/services/handover_report_service.dart:100-108` — the entire PDF, no flag (NEW-5).
- Screen-level demo data (`document_repository_screen.dart:80`, `family_members_screen.dart:22`,
  `address_selection_screen` defaults) sets no flag and is served unconditionally, not as a
  fallback — so the banner is off while the documents list is fabricated.

### NEW-12 ⚠️ Low — `_currentUserRole` is not reset by `clearSession`.

`app_provider.dart:20` — `String _currentUserRole = 'PRIMARY_CONTACT';` survives logout. It gates
`UserAction.editPatient` and `UserAction.manageFamily` (`settings_screen.dart:196,205`), the
handover export (`my_care_screen.dart:165`) and the role badge (`home_screen.dart:745`).

Harmless **today** only because `setUserRole` (`:22`) has zero call sites, so the value is a
constant. The moment sign-in sets it from the profile, a primary contact logging out and a
read-only family member logging in on the same phone inherits primary-contact permissions until
something overwrites it. `SessionScope`'s doc comment reasonably says account-level state must
not be cleared — but role is *per patient relationship*, not per account.

### NEW-13 ⚠️ — the ordering question: no re-persist between the two calls, but the sequence is unawaited.

The brief asked whether anything re-persists patient data between `SessionScope.clearSession` and
`AuthProvider.logout()`'s `prefs.clear()`. Tracing it:

`settings_screen.dart:453-459` runs `SessionScope.clearSession(context)` (fully synchronous — every
`clearPatientScopedData` is `void`), then `context.read<AuthProvider>().logout()` **un-awaited**,
then `Navigator.pop`. The `notifyListeners()` calls inside the clear trigger widget rebuilds only;
no listener writes to `SharedPreferences` on build. So there is no notify-driven re-persist.

There **is** a genuine, if narrow, race. `CartProvider.clear()` → `_persist()` is
`async` and fire-and-forget (`cart_provider.dart:200,206`); it does two awaited
`prefs.setString` platform round-trips. `AuthProvider.logout()` awaits
`_firebaseService.signOut()` before reaching `prefs.clear()`. Ordering is therefore
non-deterministic. In practice `signOut()` (a network call) is far slower than two `setString`s,
so `_persist` almost always lands first and `prefs.clear()` wipes it — but nothing enforces that.
If a cached/offline `signOut()` returns instantly, `_persist`'s second write restores
`housepital_saved_items` with patient A's list **after** the wipe.

`delete_account_screen.dart:64-65` gets this right — it `await`s `logout()`.

**Fix:** make `SessionScope.clearSession` return a `Future` that awaits each provider's persist,
and `await` it before `logout()` in `settings_screen.dart`. Low probability, trivial cost.

### NEW-14 ⚠️ Low — `StoreMigrator`'s pre-versioning detection misses four key families.

`lib/services/store_migrator.dart:41-50` — `_v1Keys` lists nine keys and omits
`housepital_reminders`, `daily_rating_*`, `housepital_cache_*` and the notification-preference
booleans. A device holding only those is classified as a fresh install and stamped at
`currentVersion` without running any step (`:68-72`).

Harmless today (`_migrations` is empty by design), and the file's "FROZEN literals" discipline is
correct. Worth fixing before the first real migration ships, since the list is frozen once used.

### Is there any path that switches patient without going through the wired `onTap`?

`grep -rn "switchPatient\|currentPatient =" lib/` gives three assignment sites. **Two bypass
`SessionScope`:**

1. **`lib/providers/app_provider.dart:146-150` — `loadPatients()`.** ❌
   ```dart
   final apiPatients = await _apiService.getPatients().timeout(...);
   if (apiPatients.isNotEmpty) {
     _patients = apiPatients;
     _currentPatient = apiPatients.first;   // ← no clear
     notifyListeners();
   }
   ```
   `_currentPatient` was already set to `DemoData.patient` at `:137`. If the API returns a list
   whose first entry is a different patient, the active patient changes with **no clear at all** —
   `_activeDeployment`, `_vitalsHistory` and every other provider keep the previous patient's
   data. This is live: `loadPatients()` is called from `home_screen.dart:59` on every Home mount.
   It is masked only by the backend being unreachable.
   **Fix:** `if (apiPatients.first.id != _currentPatient?.id) clearPatientScopedData(notify: false);`
   before the assignment — and it needs the *cross-provider* clear, which means `AppProvider` needs
   a callback or the call must move up into the widget layer.

2. **`lib/providers/app_provider.dart:309-315` — `updateFromSync()`.** ⚠️
   `if (patient != null) { _currentPatient = patient; ... }` with no clear. Dormant because its
   only caller is `sync_service.dart:57` and `SyncService` is never constructed — but it is a
   patient-switching path with no guard, waiting for the day someone wires `SyncService` up.

The wired site (`home_screen.dart:1771-1772`) is the only *correct* one, and it works only because
the widget layer calls `SessionScope.clearPatientData` before `app.switchPatient`. Nothing
prevents a future caller from invoking `switchPatient` directly and getting the `AppProvider`-only
clear. **`switchPatient` should not be callable without the cross-provider clear** — invert the
dependency so `SessionScope` owns the switch, or have `AppProvider` expose an
`onPatientChanged` callback that `main.dart` wires to the other providers.

---

## Part 0 — Requested enumerations (round-2 state)

### 0.1 What is persisted locally, and whether the new wipe reaches it

| Key | Written by | Patient-scoped key? | Cleared on **switch**? | Cleared on **logout**? |
|---|---|---|---|---|
| `housepital_cart_items` | `cart_provider.dart:209` | No | ✅ (`clear()`) | ✅ `prefs.clear()` |
| `housepital_saved_items` | `cart_provider.dart:213` | No | ❌ **re-written with A's data** (NEW-2) | ✅ |
| `housepital_orders` | `orders_provider.dart:167` | No | ❌ memory only (NEW-3) | ✅ |
| `housepital_assessments` | `orders_provider.dart:168` | No | ❌ memory only (NEW-3) | ✅ |
| `housepital_reminders` | `reminders_provider.dart:179` | No | ❌ **not in SessionScope** (NEW-4) | ✅ |
| `housepital_saved_addresses` | `address_selection_screen.dart:126` | No | ❌ (NEW-4) | ✅ |
| `daily_rating_YYYY-MM-DD` | `my_care_screen.dart:615` | No | ❌ (NEW-4) | ✅ |
| `housepital_cache_dashboard_<patientId>` | `cache_service.dart:19` | **Yes** | ❌ never removed (NEW-8) | ✅ |
| `profile_photo_path` | `app_provider.dart:107` | No | n/a (account-level) | ⚠️ key cleared, `_profilePhotoPath` field and the file on disk survive |
| `preferred_language`, `theme_mode`, `has_onboarded`, notification prefs | various | No | n/a — correctly excluded | ✅ |
| `housepital_schema_version` | `store_migrator.dart:71,117` | No | n/a | ⚠️ wiped by `prefs.clear()`, so a post-logout install re-runs the fresh-install path. Benign today. |

**In-memory-only, patient-scoped, and NOT cleared by `SessionScope`:**
`AppProvider._vitalsHistory` (NEW-1) · `AssistantProvider._messages` (NEW-6) ·
`RemindersProvider`'s list (NEW-4) · `_FamilyMembersScreenState._members` ·
`_DocumentRepositoryScreenState._documents` (NEW-7).

### 0.2 The dose-log-to-nowhere defect — restated, because it is unchanged and it is worse than the leak

A family member opens Medications, taps the pill for the 8 a.m. metformin, feels the haptic, and
watches the control flip to **"Taken"**. The adherence ring recalculates to include it. A second
family member's phone shows the dose still pending. The caretaker's staff app shows it still
pending. Kill the app and reopen it: the patient's own phone shows it pending too.

**No record of that dose exists anywhere.** The UI confirmed a write that was never attempted.

`lib/providers/medication_provider.dart:110-127`:

```dart
bool logDoseToday(String medicationId, String timeSlot) {
  if (isSlotLoggedToday(medicationId, timeSlot)) return false;
  final now = DateTime.now();
  ...
  _todayLogs.add(MedicationLog(
    id: 'patient_log_${medicationId}_$timeSlot',
    ...
    status: 'administered',
    notes: 'Logged by patient (quick action)',
  ));
  _schedule = _buildSchedule();
  markDoseTakenToday(medicationId, timeSlot); // notifies listeners
  return true;
}
```

There is no `await`, no `_apiService` call, no queue. `_todayLogs` and `_takenDoseKeys` are plain
in-memory fields. `lib/services/i_api_service.dart` still declares `getMedicationLogs` (read) as
its only medication-log method — there is no endpoint to call, which is why the provider's own
comment says the record "is kept session-local".

Call sites, all unchanged: `medications_screen.dart:299` (`logNextDoseToday`),
`medication_schedule_screen.dart:303`, `care_calendar_screen.dart:1746`.

**Why this outranks the PHI leak.** The leak shows the wrong patient's data to someone who is
already inside the family's account, and a competent reader may notice the name mismatch. This
one shows the *right* patient's name attached to a *fabricated* clinical fact, to a reader who has
no way to detect it. The specific harm is a double dose: the family sees "Taken", assumes the
caretaker gave it, and the caretaker — whose app shows pending — gives it again. Or the inverse:
the family sees "Taken" from their own tap, nobody actually administered it, and the miss is
invisible. For metformin or insulin in a geriatric patient, that is a clinical-safety defect
wearing a sync defect's clothes.

**Adjacent defect, unchanged:** the log id at `:117` — `'patient_log_${medicationId}_$timeSlot'`
— carries no date, while `_doseKey` (`:45`) does. The moment this record is persisted or posted,
day 2's 8 a.m. dose collides with day 1's.

**Minimum honest fix before the endpoint exists:** stop claiming success. Persist `_todayLogs` to
`SharedPreferences` so it at least survives an app kill, and label the state "Marked on this
phone" rather than "Taken" until a server acknowledges it.

### 0.3 Offline behaviour — unchanged

One durable outbox (Firestore chat, `chat_screen.dart:82`, and it belongs to the SDK, not the
app). Ten write paths still show success for writes that never leave the device; the full table
from round 1 stands, verified line by line — `medication_provider.dart:110`, `vitals_screen.dart:720`,
`my_care_screen.dart:617` (`submitDailyRating` still has **zero** call sites in `lib/`, declared at
`i_api_service.dart:159` and implemented at `api_service.dart:506`), `document_repository_screen.dart:686`,
`family_members_screen.dart:65,243`, `cart_screen.dart:530`, `orders_provider.dart` (checkout),
`notifications_screen.dart:149`, `staff_otp_verification_screen.dart:55`, `return_screen.dart:331`.

`raise_concern_screen.dart:353-366` remains the single correct failure-copy site in the app, and
its ordering bug is unchanged: the "submitted without them" snackbar at `:355` still fires before
`raiseConcern` is awaited at `:371`.

### 0.4 Freshness — unchanged

`isStale` still has one production call site (`my_care_screen.dart:62`) and drives no UI
indicator. Polling: none. Pull-to-refresh: 5 of 92 screens
(`home_screen`, `my_care_screen`, `medications_screen`, `medication_schedule_screen`,
`service_detail_screen`, plus generic `widgets/paginated_list.dart`).
`CacheService.getLastUpdatedText()` still has zero production callers.

### 0.7 Push / real-time — unchanged

FCM shows a snackbar or navigates and reloads nothing. `listenToAttendance` / `listenToVitals` /
`listenToNotifications` (`firebase_service.dart:237,255,277`) still have zero subscribers.
`firestore.rules` still compares `request.auth.uid` to `patientId` at `:67,70,90,94,99` and still
sets `allow write: if false` on `active_sessions` at `:134` while
`staff_otp_verification_screen.dart:80-89` writes there, unawaited, from `initState`.

---

## Findings by section — round-2 grades

### A. Schema & environments — ✅1 ⚠️2 ❌3

- ❌ **Debug and store builds talk to different environments.** `lib/config/constants.dart:3` —
  `static const String apiBaseUrl = 'https://api.housepital.in/v1';`, a plain `const` with no
  `String.fromEnvironment`, no flavor, no `kReleaseMode` branch. Note the file *does* use
  `String.fromEnvironment` correctly for `assistantApiUrl` (`:10-11`), so the pattern is present
  and simply not applied to the API host. One Firebase project for all platforms
  (`firebase_options.dart`). — **Fix:** `String.fromEnvironment('API_BASE_URL', defaultValue: <staging>)`.
- ❌ **A mechanical gate blocks release when the deployed schema lags, counting fields.**
  `.github/workflows/ci.yml` runs pub get → analyze → design gate → test+coverage → coverage gate
  → `flutter build web`. No step reads live Firestore rules or diffs `firestore.rules`.
  — **Fix:** `firebase firestore:rules get … > live.rules && diff -q live.rules firestore.rules`,
  the command already documented at `docs/DEPLOYMENT_GUIDE.md:394`.
- ⚠️ **Deploy step named, dated, owned.** `docs/DEPLOYMENT_GUIDE.md:443` has the checkbox and no
  owner/date fields. `storage.rules` and the `storage` block in `firebase.json` are new this
  round and, per the brief, **not deployed** — which is exactly the class of drift this item
  exists to catch. — **Fix:** add `Owner: __ Date: __` and make the CI diff the enforcement.
- ⚠️ **Additive schema changes with defaults.** Server side unchanged: `database/` holds one
  `schema.sql`, no migrations directory, and `docs/DEPLOYMENT_GUIDE.md:99` still references a
  non-existent `sql/001_initial_schema.sql`. **Client side is genuinely improved** —
  `lib/services/store_migrator.dart` adds a version stamp, ordered steps, frozen literals, and a
  `quarantine()` that preserves unparseable data instead of overwriting it. See NEW-14 for its
  one gap.
- ❌ **Every synced field round-trips through an encode/apply test.** `VitalReading` still has no
  `toJson` — the wire body is hand-built at `lib/services/api_service.dart:246-261`. A field added
  to `fromJson` parses on read and is silently not sent on write; no test can catch it.
- ✅ **Unknown enum raw values degrade safely.** `assistant_models.dart:48-73` +
  `test/models/assistant_models_test.dart:16-19`; `reminders_provider.dart:66` uses
  `?? ReminderCategory.reminder`.

### B. Conflict & concurrency — ⚠️2 ❌3 N/A1

- ❌ **Conflict policy written per record type with a test per type.** Still nothing in `lib/` or
  `docs/`. §0.2's question still has no documented answer.
- ❌ **Deterministic ids for concurrently mintable records.** Every client id is clock-derived:
  `vitals_screen.dart:707`, `orders_provider.dart:33-36,85`, `reminders_provider.dart:138`,
  `document_repository_screen.dart:690`, `family_members_screen.dart:225-226`.
  `generateUniqueBookingNumber` de-duplicates against the local list only.
- ❌ **No screen mints a record on appear.** `staff_otp_verification_screen.dart:52-55` still
  generates an OTP in `initState` and writes it with `SetOptions(merge: true)`, clobbering a code
  the staff member may be mid-way through typing. `address_selection_screen.dart:106-110` still
  writes three default addresses on first *read*.
- ⚠️ **Derived state from record existence, not a revertible flag.** `_buildSchedule()` derives
  correctly; `_takenDoseKeys` remains a parallel flag consulted first (`medication_provider.dart:42`).
  Small improvement: `clearPatientScopedData` now clears `_takenDoseKeys` and `_refillRequestedIds`
  together with the logs (`:391-401`), so the two cannot desynchronise across a switch.
- N/A **Echo suppression.** No bidirectional loop exists to echo.
- ⚠️ **Duplicate detection indexes fingerprint → list.** `medication_provider.dart:342-348`,
  `:82`, `:144` still use `firstWhere`, which returns one of N matches and hides the rest.

### C. Offline & the outbox — ⚠️1 ❌4 N/A1

- ❌ **Durable outbox.** None. `requestRefill` still logs "queued locally" while firing one call,
  swallowing every exception and returning `true` unconditionally.
- ❌ **Failures classified transient / conflict / permanent.** Transport layer is still decent
  (`api_service.dart` `_withRetry` / `_withAuthRecovery`); above it every provider catch is
  `catch (e) { Log.warn(...) }` with a demo fallback. `medication_provider.dart:321-323` is still
  a bare `catch (_)`.
- ⚠️ **One human sentence with a count and a next step.** Still exactly one site
  (`raise_concern_screen.dart:353-366`), with the ordering bug at `:355` vs `:371`.
- N/A **Poison-record retry caps.** Vacuous — no persistent queue exists.
- ❌ **Airplane-mode edits on both devices converge.** No mechanism, no test (`find test -name "*sync*"`
  → nothing; 103 test files, none covering offline reconciliation).
- ❌ **Killed mid-sync, queue resumes.** No queue. `SyncService._inFlightSync` is still correct
  code protecting nothing.

### D. Sharing lifecycle — ❌6 N/A1 — entirely unchanged

`family_members_screen.dart` remains a `setState` over a `static final _mockMembers`
(`:22,46,51,65,243`). `inviteFamilyMember` / `addFamilyMember` / `updateFamilyMember` /
`removeFamilyMember` / `getFamilyMembers` still have zero call sites. Invite ❌, revoke ❌,
leave ❌, no-tombstones N/A, re-invite ❌, stop-sharing ❌, resurrection ❌. The API contract
requested in round 1 is restated in BLOCKED-OWNER below.

### E. Two-phone QA matrix — ❌1 BLOCKED-OWNER 4

- BLOCKED-OWNER ×4 — version skew, same-record contention, offline create, locked-device
  attachment. All need two physical devices, two real accounts on one patient, two builds and a
  reachable backend.
- ❌ **Every "it synced" claim verified by reading the other device.** Graded on code: the app
  systematically does the opposite (§0.3). Credit unchanged for `payment_service.dart:150-174`,
  which refuses to confirm before `verifyPayment` returns.

### F. Recovery & repair — ❌2 N/A3

- ❌ **User-reachable re-sync reporting a real count.** Pull-to-refresh on 5 screens, no counts.
  `CacheService.clear()` still unreachable from the UI. `grep -rni "re-sync\|resync\|sync now" lib/screens/`
  → nothing.
- N/A **Membership repair** — no transport to repair.
- N/A **Idempotent repair actions** — none exist.
- ❌ **Orphaned records healed by a sweep; write path guarded.** Seven of eight app-data stores
  still carry no patient id (§0.1). `SessionScope` is a clear, not a sweep: it runs only at two
  call sites, misses four stores outright, and — per NEW-2/NEW-3 — leaves or re-writes the disk
  copies. No key prefixing, no startup sweep.
- N/A **Cascade-delete tombstones** — no cascading deletes exist. `delete_account_screen.dart`
  is new this round and does an on-device wipe with an explicit `TODO(backend)` at `:56-58`; its
  copy correctly promises only what it can deliver.

---

## Blockers (must fix before release)

1. **`_vitalsHistory` survives a patient switch into the new patient's chart.** NEW-1 —
   `app_provider.dart:41` vs `:176-186`; rendered at `vitals_screen.dart:121`. The regression
   test (`patient_scope_isolation_test.dart:63-84`) certifies the gap by asserting only the
   fields the implementation clears.
2. **The doctor handover PDF exports the demo patient's clinical record under any patient.**
   NEW-5 — `handover_report_service.dart:97-108`, shared from `my_care_screen.dart:550`.
   Cross-patient PHI disclosure to a third party, unreachable by `SessionScope` by construction.
3. **The patient switch re-writes patient A's saved-items to disk, and leaves orders,
   assessments, reminders, addresses, ratings and the dashboard cache blob behind.**
   NEW-2/NEW-3/NEW-4 — `cart_provider.dart:198-202` + `:206-217`; `orders_provider.dart:212-217`
   vs `:167-168`; `reminders_provider.dart:179`; `address_selection_screen.dart:126`;
   `my_care_screen.dart:615`; `cache_service.dart:19`.
4. **`loadPatients()` changes the active patient with no clear at all.** NEW-13/Part-1 —
   `app_provider.dart:146-150`, called from `home_screen.dart:59` on every Home mount. The wired
   `onTap` is not the only switch path.
5. **Medication doses are logged to nowhere while the UI reports success.** §0.2 —
   `medication_provider.dart:110-127`. Unchanged from round 1. Clinical-safety defect.
6. **Every direct-Firestore call is denied by the deployed rules; the OTP write is designed to
   fail.** `firestore.rules:67,70,90,94,99,134` vs `staff_otp_verification_screen.dart:55,80-89`.
   Unchanged from round 1.

## High

7. **`AssistantProvider` hard-bound to `DemoData.patient.id`; its transcript survives logout.**
   NEW-6 — `main.dart:233,243,257,259,269`; `assistant_provider.dart:44`.
8. **`SyncService` is dead code and there is no polling** — `lib/services/sync_service.dart`,
   zero importers.
9. **Three working Firestore real-time listeners have no subscribers** —
   `firebase_service.dart:237,255,277`.
10. **FCM never refreshes state** — snackbar/navigate only; `my_care_provider.dart:103`'s comment
    is still false.
11. **16 ad-hoc `ApiService()` instances carry no auth token and no `onUnauthorized`** —
    `grep -rn "ApiService()" lib/screens/ | wc -l` → 16, including `notifications_screen.dart:149`
    inside an uncaught `async` `onTap`.
12. **Family-member sharing is a mock** — section D in full.
13. **Equipment return sends a local device path as `photoUrl`** — `return_screen.dart:331`.

## Medium / Low

14. **`DemoMode` is one global flag lowered by one provider** (NEW-9) — `app_provider.dart:247`
    can take the banner down while medications/services/orders are still sample data. Medium; a
    fresh risk created by this round's fix.
15. **The sample-data banner is absent on every pushed route** (NEW-10) — `main_shell.dart:64`.
16. **Three demo fallbacks never set the flag** (NEW-11) — `blog_provider.dart:38,68`;
    `app_provider.dart:137`; `handover_report_service.dart:100-108`.
17. **`clearSession` is not awaited before `logout()`** (NEW-13) — `settings_screen.dart:457-458`;
    `delete_account_screen.dart:64-65` does it correctly.
18. **`_currentUserRole` is not reset by `clearSession`** (NEW-12) — `app_provider.dart:20`.
19. **The dashboard cache is write-only and never cleared** (NEW-8) — `cache_service.dart` read/clear/remove
    have zero production callers.
20. **`StoreMigrator._v1Keys` omits four key families** (NEW-14) — `store_migrator.dart:41-50`.
21. **Screen-local `State` holds patient data** (NEW-7) — `family_members_screen.dart:46`,
    `document_repository_screen.dart:80`.
22. **Client-minted ids are clock-derived everywhere** — B2 list.
23. **`patient_log_${medicationId}_$timeSlot` has no date component** — `medication_provider.dart:117`.
24. **Local-notification id collisions** — `medication_reminder_service.dart:288,292`.
25. **`order_tracking` and OTP Firestore listeners swallow errors** —
    `order_tracking_screen.dart:166` (`onError: (_) {…}`); the OTP listener has no `onError`.
26. **`updateStock` swallows everything** — `medication_provider.dart:321-323`.
27. **Chat input does not clear until the server acks** — `chat_screen.dart:78-91`.
28. **`raise_concern` shows the photo-failure snackbar before the submission is awaited** —
    `:355` vs `:371`.
29. **Pull-to-refresh missing on 11 data-bearing screens.**
30. **`CacheService.getLastUpdatedText()` implemented, tested, never used.**
31. **`isStale` reports "fresh" for demo data** — `my_care_provider.dart:50`.
32. **`addPatient` has a `TODO(persistence)`** — `app_provider.dart:204`. Note this is what bounds
    the whole PHI blast radius today: `loadPatients` returns one demo patient, so the switch sheet
    usually has one row. That is not a control, it is a coincidence of the demo backend.

---

## BLOCKED-OWNER

| # | Item | What is needed |
|---|---|---|
| E1–E4 | Two-phone QA matrix | Two physical devices, two real accounts on one patient, current + n-1 builds, a reachable `api.housepital.in`, and a locked-device attachment test. Cannot be simulated. |
| D (all) | Sharing lifecycle | The invite/member API contract below, plus an owner decision on whether a removed family member keeps read access to historical reports (PHI retention). |
| §0.2 | Medication dose logging | `POST /patients/{patientId}/medication-logs` accepting `{ client_log_id, medication_id, scheduled_time, actual_time, status, logged_by_user_id, source: "patient"\|"staff", notes }`, `201` on create and `200` on replay of the same `client_log_id`. `GET …?date=` must return `logged_by` and `source`. **Clinical decision required:** when the family app and the staff app both log the same slot, is that one dose (dedupe on `medication_id + scheduled_time`) or two (a double-dose the app must warn about)? |
| §0.3 | Daily care rating | `submitDailyRating` exists at `i_api_service.dart:159` / `api_service.dart:506` with zero callers. Owner confirms the endpoint is live; the client change is two lines. |
| §0.6 | Cart across devices | `GET/PUT /patients/{patientId}/cart` with `updated_at` for LWW — **or** an explicit decision that the cart is device-local, in which case the "Booking request sent to your primary contact… They'll receive a notification" copy at `cart_screen.dart:542` must go, because it promises cross-device behaviour that does not exist. |
| A1 | Environment split | A staging `api.housepital.in` host and a second Firebase project. |
| A2/A3 | Rules deploy gate | A CI service-account credential with `firebaserules.releases.get` so the diff gate can run. Also: confirm whether `storage.rules` has actually been deployed — the repo says it has not. |
| NEW-5 | Handover PDF | Owner decision on what a handover PDF must contain when the backend is unreachable: refuse to generate, or generate with a visible "SAMPLE DATA" watermark. It must not silently emit another patient's record. |

**Member/invite contract (restated from round 1):**
```
POST   /patients/{patientId}/members/invite  { phone, relationship, role, notification_preferences }
         → 201 { invite_id, status: "pending", expires_at }     [idempotent on (patientId, phone)]
GET    /patients/{patientId}/members         → [{ member_id, user_id, name, phone, role,
                                                  status: invited|active|removed, joined_at, removed_at }]
POST   /invites/{inviteId}/accept            → 200 { member_id, patient_id }  [callable pre-install via deep link]
DELETE /patients/{patientId}/members/{memberId}   (owner revoke)      → 204  [idempotent]
DELETE /patients/{patientId}/members/self         (participant leave) → 204  [idempotent; MUST NOT cascade-delete patient data]
```
Plus an FCM `membership_changed` push so a removed participant's device learns without polling.

---

## Red flags present (checklist "stop the release" list)

| Red flag | Present? | Evidence |
|---|---|---|
| Any error path that logs and returns | **Yes, pervasively** | `app_provider.dart:151,251,291`; `my_care_provider.dart:70`; `medication_provider.dart:321`; `orders_provider.dart:203`; `blog_provider.dart:36,66`; `order_tracking_screen.dart:166`; `firebase_service.dart` throughout |
| "It worked on my phone" as sync evidence | **Yes** | 103 test files, zero multi-device or offline-reconciliation tests; every success affordance in §0.3 fires from local state |
| A schema change merged without a written deploy step | **Yes, and one more this round** | `active_sessions: allow write: if false` vs `staff_otp_verification_screen.dart:82`; **new:** `storage.rules` + the `firebase.json` storage block are in the repo and, per the brief, not deployed |
| A share/leave/revoke flow tested on one device only | **Worse** | Not tested on any device — the flow is `setState` on a static mock list |
| A repair button whose effect you cannot state in one sentence | **No** | Still vacuously clean: there is no repair button |

---

## Verdict

**FAIL.** 19 of 35 items fail, 5 partial, 1 passes, 6 N/A, 4 blocked on the owner — identical to
round 1.

The honest read of round 2: the PHI fix is a real architectural improvement — `SessionScope` is
the right shape, `switchPatient` clears in the right order, and `StoreMigrator` is a genuinely
well-designed piece of work that was cheap now and impossible later. But the fix was written
against the symptom list rather than the field list, and its own regression test was written
against the implementation rather than the contract, so the wipe stops precisely where a reviewer
stops looking: at the fields that render on the dashboard. What survives is the manually entered
vitals history, the saved-items list (actively re-written to disk by the wipe itself), the order
history on disk, the care reminders, the saved addresses, the assistant's conversation, and a
doctor-facing PDF that never consulted the provider tree in the first place.

The app remains a read-only demo-mode client with local convenience storage. It must not be
described to families as a shared care record until blockers 1–6 land — and blocker 5, the dose
log that goes nowhere while the button says "Taken", should be fixed before the PHI work, because
it is the one defect that can put a second dose of metformin into an eighty-year-old.
