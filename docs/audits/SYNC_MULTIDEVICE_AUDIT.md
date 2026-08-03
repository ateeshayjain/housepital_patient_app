# Sync & Multi-Device Checklist (App-Agnostic) — Audit vs commit `803124d`

**Date:** 2026-08-03 · **Auditor:** Sync & Multi-Device agent · **Repo:** `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`
**Scope:** read-only. No files under `lib/`, `test/`, or config were modified. (`git status` shows 4 files dirty — `CLAUDE.md`, `lib/screens/main_shell.dart`, `lib/screens/my_care/my_care_screen.dart`, `test/screens/main_shell_test.dart` — all pre-existing nav-tab work from another agent; `git diff` confirms none of it touches sync, persistence, or provider state.)

---

## Executive framing

The app has a genuinely multi-writer story — patient, primary contact, family members, and a separate staff app all touching one patient's record. **The code does not have a sync layer.** What exists is:

- a **read-only, best-effort fetch** layer (`ApiService` → providers) that silently falls back to `DemoData` on any failure,
- a set of **device-local SharedPreferences stores** that are never reconciled with a server and (with one exception) are **not scoped by patient**,
- **one real real-time surface** — Firestore chat — which is the only place in the app with a durable outbox, and it gets that for free from the Firestore SDK, not from app code,
- a `SyncService` with delta-sync, in-flight de-duplication and a 5-minute periodic timer that **is never instantiated anywhere in `lib/`** (dead code).

The result: for the checklist's central question — *"two devices will do the same thing at the same time"* — the honest answer for almost every record type is **neither device's write reaches the server, and both show success.** There is nothing to conflict over because nothing is written.

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

---

## Part 0 — Requested enumerations

### 0.1 What is actually persisted locally

Every `SharedPreferences` key the app writes, from `grep -rn "prefs.set" lib/`:

| Key | Written by | Contents | Patient-scoped? | Reaches server? |
|---|---|---|---|---|
| `housepital_cart_items` | `lib/providers/cart_provider.dart:8,209` | Full cart JSON (equipment + services + schedule + address + notes) | **No** | Never |
| `housepital_saved_items` | `lib/providers/cart_provider.dart:9,213` | Save-for-later list | **No** | Never |
| `housepital_orders` | `lib/providers/orders_provider.dart:10,166` | Every booking/order the user has ever placed | **No** | Never |
| `housepital_assessments` | `lib/providers/orders_provider.dart:11,167` | Assessment requests | **No** | Never |
| `housepital_reminders` | `lib/providers/reminders_provider.dart:99,179` | Care-calendar reminders | **No** | Never |
| `housepital_saved_addresses` | `lib/screens/checkout/address_selection_screen.dart:70,124` | Delivery addresses (name, phone, flat, street) | **No** | Never |
| `daily_rating_YYYY-MM-DD` | `lib/screens/my_care/my_care_screen.dart:592,614` | Daily care star rating | **No** | **Never — and the UI claims it was sent** |
| `housepital_cache_dashboard_<patientId>` | `lib/services/cache_service.dart:19` via `lib/providers/app_provider.dart:189,213` | Billing summary only, 30-min TTL | **Yes** (only key that is) | Read-only cache |
| `profile_photo_path` | `lib/providers/app_provider.dart:106` | Local device file path | No | Never uploaded |
| `preferred_language` | `lib/providers/app_provider.dart:92`, `auth_provider.dart:197` | `en`/`hi` | No | Sent once at onboarding |
| `has_onboarded` | `lib/providers/auth_provider.dart:196` | bool | No | n/a |
| `theme_mode` | `lib/providers/theme_provider.dart:17` | light/dark/system | No | Never |
| notification-pref booleans | `lib/providers/app_provider.dart:129` (keys from `notification_preferences_screen.dart:108`) | Per-channel toggles | No | Never |

**No file-based persistence exists** beyond `image_picker` temp paths — `grep -rn "getApplicationDocumentsDirectory" lib/` returns nothing.

Fetched per-session and held in memory only (lost on kill, no cache): active deployment, today's attendance, latest vitals, today's report, active services, health manager, medications, medication logs, notifications, invoices, transactions, equipment catalog, staff profiles, articles. All of these fall back to `DemoData` on failure.

**In-memory-only writes that are lost on app kill:**
- `AppProvider._vitalsHistory` (`app_provider.dart:40`) — manually entered vitals
- `MedicationProvider._takenDoseKeys`, `_todayLogs`, `_refillRequestedIds` (`medication_provider.dart:42,15,155`)
- `_FamilyMembersScreenState._members` (`family_members_screen.dart:46`)
- `_DocumentRepositoryScreenState._documents` (`document_repository_screen.dart:80`)

### 0.2 Conflict handling — the medication-dose scenario, answered plainly

> *A family member logs a medication dose on their phone while the caretaker logs the same dose in the staff app. What happens?*

**Neither last-write-wins, nor duplicates, nor a merge. The family member's write never leaves the phone, and is lost when the app is killed.**

The write path, in full:

`lib/screens/my_care/medications_screen.dart:299` → `MedicationProvider.logNextDoseToday()`
`lib/screens/my_care/medication_schedule_screen.dart:303` → `MedicationProvider.logDoseToday()`
`lib/screens/calendar/care_calendar_screen.dart:1746` → `MedicationProvider.logDoseToday()`

`lib/providers/medication_provider.dart:109-126`:

```dart
bool logDoseToday(String medicationId, String timeSlot) {
  if (isSlotLoggedToday(medicationId, timeSlot)) return false;
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

There is no API call. The provider's own comment at `medication_provider.dart:67-69` states it outright: *"IApiService has no patient-side dose-log endpoint … so the record is kept session-local — there is no API call to attempt or fail."* Confirmed against `lib/services/i_api_service.dart:197-202`: the only medication-log method is `getMedicationLogs` (read).

Consequences, all confirmed in code:
1. The button morphs to "Taken"/"Given" with `HapticFeedback.lightImpact()` (`medications_screen.dart:298`) — a strong success affordance for a write that was never attempted.
2. The staff app never sees it. The caretaker will log the dose again → the patient is recorded as having received it once (staff) while the family sees "already taken".
3. Two family members on two phones each see "Taken" and neither sees the other.
4. `_todayLogs` and `_takenDoseKeys` are plain in-memory fields — kill the app and the log is gone. Reopening the schedule shows the dose as pending again.
5. Adherence percentage (`medications_screen.dart:147-149`) is computed from `dosesMarkedTakenToday`, so the number shown to the family is a per-device fiction.

**Adjacent defect:** the log id `'patient_log_${medicationId}_$timeSlot'` (line 116) carries **no date component**, unlike `_doseKey` (line 45) which does. If this record is ever persisted or posted, day 2's 8am dose collides with day 1's.

### 0.3 Offline behaviour — what is queued, what is lost

**Queued (durably):** exactly one path — Firestore chat. `lib/screens/chat/chat_screen.dart:82` `_messagesRef.add({...})` uses the Firestore SDK's own offline persistence, which applies the write locally, surfaces it through the `snapshots()` listener at line 53 immediately, and retransmits across app restarts. This is the only genuine outbox in the app, and it is the SDK's, not the app's.

**Lost silently, with a success affordance shown:**

| Write | File:line | What the user sees | What actually happens |
|---|---|---|---|
| Medication dose logged | `medication_provider.dart:109` | Pill flips to "Taken", haptic | In-memory only; lost on kill |
| Manual vital reading | `vitals_screen.dart:720` `unawaited(app.addVitalReading(...))` | Sheet pops, chart updates | `app_provider.dart:252-257` catches everything → `Log.warn`; in-memory only |
| Daily care rating | `my_care_screen.dart:617-623` | *"Thanks for rating! We've shared your feedback with the team."* | Written to a SharedPreferences int. `submitDailyRating` exists in `i_api_service.dart:159` and is **called 0 times** |
| Document scan/upload | `document_repository_screen.dart:686-702` | *"Document saved successfully"* | `_documents.insert(...)` into widget state. No upload, no server write, gone on pop |
| Family member add/remove | `family_members_screen.dart:64-70, 243-249` | *"Suresh Kumar removed"* / *"… added"* | `setState` on a local copy of `_mockMembers`. `inviteFamilyMember`/`addFamilyMember`/`removeFamilyMember` called 0 times |
| Booking request to primary contact | `cart_screen.dart:530-552` | *"Booking request sent to your primary contact… They'll receive a notification"* | Method doc says *"Stub… No real persistence yet"*. Nothing is sent |
| Order / checkout | `cart_screen.dart:581` `ordersProvider.addOrder(...)` | Booking confirmation screen with a booking number | SharedPreferences only. `createBooking` (`i_api_service.dart:83`) called 0 times |
| Notification mark-as-read | `notifications_screen.dart:149` | Orange unread dot clears | `ApiService()` constructed fresh with **no auth token** (`setAuthToken` is only ever called on `AuthProvider`'s instance, `auth_provider.dart:55`) and **no `onUnauthorized`** → guaranteed 401 → `ApiException` thrown inside an un-caught `async` `onTap` |
| Staff-arrival OTP | `staff_otp_verification_screen.dart:55` | 4-digit OTP displayed, "waiting for staff" | `_storeOtp()` is called **unawaited and uncaught** from `initState`; `firestore.rules:134` is `allow write: if false` on `active_sessions` — the write is *designed to be rejected* |
| Equipment return photo | `return_screen.dart:330` `photoUrl: _photoPath` | "Return Scheduled" | A **local device path** is sent as a URL — the exact bug audit M-9 fixed for chat and concerns, still live here |

**The one place this is done right:** `lib/screens/support/raise_concern_screen.dart:353-366`. Evidence-photo upload failures produce a count, a plain sentence, and a next step: *"$failedCount photos couldn't be uploaded. Your concern was submitted without them — reply to the coordinator's message in chat to add photos."* That is exactly what the checklist asks for. It is one of one.

*(Minor ordering bug at the same site: the failure snackbar is shown at line 356, **before** `raiseConcern` is awaited at line 370. If the concern submission then throws, the user sees "your concern was submitted without them" followed by "Failed to submit".)*

### 0.4 Freshness — what `MyCareProvider.isStale` actually drives

`lib/providers/my_care_provider.dart:35-37`:
```dart
bool get isStale => _lastFetchedAt == null ||
    DateTime.now().difference(_lastFetchedAt!) > const Duration(seconds: 60);
```

`grep -rn "isStale" lib/` returns **exactly one production call site**: `lib/screens/my_care/my_care_screen.dart:62`, inside `didChangeAppLifecycleState`:

```dart
if (state == AppLifecycleState.resumed) {
  final myCare = context.read<MyCareProvider>();
  if (myCare.isStale) _loadData();
}
```

So `isStale` drives **one thing**: a refetch of the My Care tab when the app returns to the foreground more than 60s after the last fetch. It drives **no UI indicator anywhere** — there is no "last updated" chip, no stale banner, no dimming.

Note that `_lastFetchedAt` is also set when **demo data** is seeded (`my_care_provider.dart:50`), so `isStale` reports "fresh" for data that never came from a server. `test/providers/my_care_provider_test.dart:205` asserts this behaviour.

Other freshness machinery:
- `AppProvider.lastUpdatedText` (`app_provider.dart:60`) is set to `'Last updated: just now'` on success and `'Demo data'` on the demo path. `CacheService.getLastUpdatedText()` (`cache_service.dart:75-82`), which computes a *real* age from the cache timestamp, is **called 0 times in `lib/`** — only from `test/services/cache_service_test.dart`.
- **Pull-to-refresh: 5 of 92 screens.** `grep -rln "RefreshIndicator" lib/` → `home_screen.dart:108`, `my_care_screen.dart:108`, `medications_screen.dart:107`, `medication_schedule_screen.dart:80`, `service_detail_screen.dart:64` (plus the generic `widgets/paginated_list.dart`). **Not covered:** Billing, Transaction log, Invoice detail, Daily report, Vitals, Care team, Notifications, Documents, Order tracking, Family members, Attendance history.
- **Polling: none.** `SyncService.startPeriodicSync` (`sync_service.dart:85`) is the only polling implementation and `grep -rn "sync_service" lib/ test/` returns **no matches** — the file is imported nowhere. The only `Timer.periodic` that touches server state is `AuthProvider._tokenRefreshTimer` (50 min, token only). `home_screen.dart:70` polls a 1-minute timer but only to re-render a local duty-hours clock.

### 0.5 Multi-patient — PHI leak on patient switch (**BLOCKER**)

`lib/providers/app_provider.dart:157-161`:
```dart
void switchPatient(Patient patient) {
  _currentPatient = patient;
  notifyListeners();
  loadDashboard();
}
```

Nothing is reset. Then `loadDashboard()` (line 175):
```dart
_seedDemoDataIfEmpty();       // line 182
...
try { ...Future.wait([...]).timeout(5s); ... }
catch (e) { Log.warn(...); /* Demo data already loaded — no action needed */ }
```
and `_seedDemoDataIfEmpty()` (line 222) is guarded by `if (_activeDeployment == null)`, which is **false** after the first patient loaded.

**Therefore, when the API is unreachable (the app's documented default state), switching from patient A to patient B leaves on screen:** A's `_activeDeployment`, A's `_todayAttendance`, A's `_latestVitals`, A's `_todayReport`, A's `_amountDue` and `_dueDate` — now labelled with B's name. `_vitalsHistory` (line 40) is never cleared under any code path, so A's manually entered readings render inside B's vitals chart.

It is worse than that, because `switchPatient` touches only `AppProvider`. The other patient-scoped providers are never told:
- `MyCareProvider` — A's active services and health manager stay (`my_care_provider.dart:47` only seeds `if (_activeServices.isEmpty)`, and the catch at line 68 keeps the old list on failure).
- `MedicationProvider` — A's medication list, A's dose logs, A's `_takenDoseKeys` all persist (`medication_provider.dart:188` same `isEmpty` guard).
- `OrdersProvider` / `CartProvider` / `RemindersProvider` — global un-scoped keys, so B sees A's entire order history, cart, and care reminders by construction.
- `AssistantProvider` is constructed **once** at `lib/main.dart:225` with `final patientId = DemoData.patient.id` and never rebuilt. After a switch, any assistant-initiated `raiseConcern` / `createAssessmentRequest` is filed against the **demo patient's id**, not the selected one.

Blast radius is bounded today only because `addPatient` (`app_provider.dart:168-172`) is an in-memory append with a `TODO(persistence)` and `loadPatients` returns a single demo patient. The moment a real account has two patients, this ships PHI cross-contamination.

`logout()` (`auth_provider.dart:217-227`) calls `prefs.clear()` — good, storage is wiped — but **resets no provider in-memory state**. On a shared device, sign out → sign in as a different family member and the previous patient's vitals, orders, cart and medications are still on screen until each provider happens to refetch (and on API failure, they persist indefinitely).

### 0.6 Cart / session state across devices and restarts

- **Across restarts: works.** `CartProvider.loadFromStorage()` is kicked off at `lib/main.dart:200`, corrupt entries are skipped per-item (`cart_provider.dart:232`). `test/providers/cart_persistence_test.dart` covers it.
- **Across devices: does not exist.** The cart is a local JSON blob. `IApiService` has no cart endpoint at all. Add an item on the family member's phone; the primary contact who is expected to pay sees an empty cart.
- **Across patients: leaks.** Key `housepital_cart_items` has no patient prefix (`cart_provider.dart:8`).
- Same three verdicts apply to saved addresses (`address_selection_screen.dart:70`) and orders (`orders_provider.dart:10`).

### 0.7 Push / real-time — can a second device learn about a change it did not make?

Three mechanisms exist; two of them are wired to nothing.

**1. FCM — wired, but does not refresh state.** `lib/main.dart:349-382`. A foreground message calls `NotificationRouter.showForegroundSnackBar` (line 361) — a snackbar. A tapped message calls `NotificationRouter.handleNotification` (line 371) — navigation. **Neither invokes any provider reload.** A push saying "new vitals recorded" shows a snackbar over screens still displaying the old vitals. Contrast `MyCareProvider.refresh()` at `my_care_provider.dart:104`, whose doc comment claims *"Called by FCM handler or pull-to-refresh"* — `grep` confirms the FCM handler never calls it.

**2. Firestore real-time listeners — implemented and never subscribed.** `FirebaseService.listenToAttendance` (`firebase_service.dart:237`), `listenToVitals` (:255), `listenToNotifications` (:277). `grep -rn "listenToAttendance\|listenToVitals\|listenToNotifications" lib/ test/` matches **only their own declarations**. This is the single highest-leverage dead code in the repo: three working streams that would give exactly the cross-device freshness the product needs, plumbed to nothing.

**3. Firestore listeners that *are* live — three screens.**
- `chat_screen.dart:45-53` — chat, genuinely bidirectional and durable. The app's one working multi-device surface.
- `order_tracking_screen.dart:150-169` — `active_sessions/{bookingId}`, read-only, `onError` sets `_isLoading = false` and shows nothing (`onError: (_) {...}` at line 167 — a textbook checklist red flag).
- `staff_otp_verification_screen.dart:93-115` — `active_sessions/{deploymentId}`, read-only, **no `onError` handler at all**.

**Rules mismatch on the two `active_sessions` screens.** `firestore.rules:131-135`:
```
match /active_sessions/{sessionId} {
  allow read: if request.auth != null && resource.data.patientId == request.auth.uid;
  allow write: if false;
}
```
- The OTP screen's `_storeOtp()` (`staff_otp_verification_screen.dart:80-89`) writes to this path. It will be **rejected by the deployed rules, always**. Unawaited and uncaught, the rejection lands in the `runZonedGuarded` handler at `main.dart:274` → Crashlytics in release, nothing in the UI. The patient stares at an OTP the staff app can never validate.
- The doc `_storeOtp` creates contains only `otp`, `verified`, `generated_at` — no `patientId` — so it would also fail the read rule.
- More broadly, every rule in the file compares `request.auth.uid` to a `patientId` (`firestore.rules:67, 70, 90, 94, 99, 133`). Firebase Auth uids are opaque (`3xK9…`); patient ids in this app are of the form `pat_demo_rajesh` (`lib/main.dart:225`, `vitals_screen.dart:708`). The rules' own comment at line 62-64 admits this: *"We use a loose match (auth.uid == patientId) since the app currently keys threads by patientId; tighten when user→patient mapping (user_patients collection) is wired."* Until that mapping exists, **every direct-Firestore read and write in the app fails against the deployed rules** — including chat.

---

## Findings by section

### A. Schema & environments

- ❌ **Debug builds and store builds talk to DIFFERENT server environments.** `lib/config/constants.dart:3` — `static const String apiBaseUrl = 'https://api.housepital.in/v1';`. A plain `const`, not a `String.fromEnvironment`, with no flavor, no `kReleaseMode` branch. `lib/config/firebase_options.dart:26,35,47` — one project, `housepital-patient`, for web/android/ios alike. Debug builds on developer laptops write to production Firestore and production chat. — **Impact:** any dev-mode test message, OTP doc or FCM token registration lands in production; there is no staging to rehearse a schema change in. — **Fix:** `static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://staging-api.housepital.in/v1');` and add a second `firebase_options_dev.dart` behind a flavor; make the release build script pass the prod value explicitly.
- ❌ **A mechanical gate blocks release when the deployed production schema lags the app — and counts fields.** `.github/workflows/ci.yml` runs analyze → design gate → test+coverage → `flutter build web`. There is no step that reads live Firestore rules, diffs the repo `firestore.rules`, or compares `database/schema.sql` against the deployed DB. — **Impact:** the `active_sessions` write above is exactly the failure this gate would catch: app code depends on a rule shape that the deployed rules forbid, and CI is green. — **Fix:** add a CI job running `firebase firestore:rules get --project housepital-patient > live.rules && diff -q live.rules firestore.rules` (the command is already documented at `docs/DEPLOYMENT_GUIDE.md:394`), failing the build on drift.
- ⚠️ **The deploy step is in the release checklist as a named, dated action with an owner.** `docs/DEPLOYMENT_GUIDE.md:443` — `- [ ] **Firestore security rules deployed AND verified in console**`. It exists and points at the right command. It has **no owner and no date field**, and it is a human checkbox in a doc, not a gate. `firestore.rules:7-16` carries the same instruction as a comment. — **Fix:** add `Owner: ______  Date: ______` to the checklist line and make the CI diff above the enforcement.
- ⚠️ **All schema changes are additive with defaults; removals and renames forbidden.** `database/` contains a single file, `schema.sql`, headed `Version 1.0 | March 2026` (`database/schema.sql:3`), all `CREATE TABLE`. There is no migrations directory and no `ALTER` discipline — `docs/DEPLOYMENT_GUIDE.md:99` references `sql/001_initial_schema.sql`, a path that does not exist in this repo. `firestore.rules:18-25` does keep a proper dated history, which is the good half of this item. — **Fix:** create `database/migrations/` with numbered additive files and make `schema.sql` a generated snapshot.
- ❌ **Every synced field round-trips through an encode/apply unit test.** Only 8 of ~32 model classes have a `toJson` at all (`grep -c "Map<String, dynamic> toJson" lib/models/*` → `models.dart` 5, `medication_models.dart` 1, `article.dart` 1, `equipment_order.dart` 1, `assistant_models.dart` 1). Critically, `VitalReading` (`lib/models/models.dart:324`) — the one patient-authored record the app posts — has **no `toJson`**; the wire body is hand-built inline at `lib/services/api_service.dart:248-260`. A field added to `VitalReading.fromJson` will parse on read and silently not be sent on write, and no test can catch it. `VitalReading.fromJson` (line 353) also does unchecked `json['id']` into a non-nullable `String` and `DateTime.parse(json['recorded_at'])`, so a renamed server field is a hard throw, not a degrade. — **Fix:** give `VitalReading` a `toJson()`, call it from `submitVitalReading`, and add `fromJson→toJson→fromJson` tests alongside the existing ones in `test/models/patient_model_test.dart:137`.
- ✅ **Unknown enum raw values from newer versions degrade safely (fallback tested).** `lib/models/assistant_models.dart:48-73` — `AssistantAction.fromString` `switch` with `default: return AssistantAction.none`, explicitly tested at `test/models/assistant_models_test.dart:16-19` including `'launch_rockets'`, `null` and `''`. `lib/providers/reminders_provider.dart:66` — `ReminderCategory.values.asNameMap()[json['category']] ?? ReminderCategory.reminder`. All other wire-level status/category fields (`Booking.status`, `FamilyConcern.urgency`, `MedicationLog.status`) are plain `String`, so unknown values pass through without crashing.

### B. Conflict & concurrency

- ❌ **Conflict policy is written down per record type, with a test per type.** `grep -rni "conflict\|last.writ\|lww\|merge polic" lib/ docs/` finds nothing. No document, no comment, no test. — **Impact:** the medication-dose scenario in §0.2 has no defined answer because no one has had to write one down. — **Fix:** add a `## Conflict policy` table to `docs/ARCHITECTURE.md` naming, per record type (vitals, dose logs, orders, concerns, chat, addresses), one of LWW / merge / append-only, and the field that decides.
- ❌ **Records mintable by two devices concurrently use deterministic IDs derived from stable inputs.** Every client-minted id in the app is clock-derived and therefore different on two devices for the same logical record:
  - `lib/screens/reports/vitals_screen.dart:707` — `id: 'manual_${now.microsecondsSinceEpoch}'`
  - `lib/providers/orders_provider.dart:33-36` — `'HPL-BOOK-' + last 7 digits of millisecondsSinceEpoch`
  - `lib/providers/orders_provider.dart:85` — `'HPL-ASR-' + millisecondsSinceEpoch.substring(5)`
  - `lib/providers/reminders_provider.dart:138` — `'rem_${DateTime.now().microsecondsSinceEpoch}'`
  - `lib/screens/documents/document_repository_screen.dart:690` — `'doc_${DateTime.now().millisecondsSinceEpoch}'`
  - `lib/screens/settings/family_members_screen.dart:225-226` — `'fm${...millisecondsSinceEpoch}'`, `'u${...}'`
  `generateUniqueBookingNumber` (`orders_provider.dart:41-49`) de-duplicates **only against the local in-memory list** — it cannot see the other phone's orders, and the booking-number space is 7 digits of a millisecond clock. — **Impact:** two family members booking the same nurse visit within the same millisecond can mint the same `HPL-BOOK-` id; two devices logging the same 8am BP reading mint two different ids and the server sees two readings. — **Fix:** derive ids from content — e.g. vitals `sha1(patientId|recordedAtMinute|vitalKey|value)`, dose logs `patientId|medicationId|slot|yyyy-mm-dd` — and let the server enforce a unique index.
- ❌ **No screen mints a record on appear.** Two violations:
  - `lib/screens/my_care/staff_otp_verification_screen.dart:52-55` — `initState` generates an OTP and immediately writes `active_sessions/{deploymentId}` with `SetOptions(merge: true)`, overwriting `otp` and resetting `verified: false`. Re-entering the screen while the staff member is mid-verification clobbers the code they are typing.
  - `lib/screens/checkout/address_selection_screen.dart:106-112` — `loadAddresses()` writes three hardcoded default addresses to storage on first *read*.
  — **Fix:** move OTP generation behind an explicit "Show code" action, or read the server-issued OTP rather than minting one client-side; make `loadAddresses` return the defaults without persisting them.
- ⚠️ **Derived state is computed from record existence, not a stored flag another writer can revert.** Mostly right: `MedicationProvider._buildSchedule()` (`medication_provider.dart:327-384`) derives every slot's state from the presence of a `MedicationLog`, and `isSlotLoggedToday` (line 75) checks logs before flags. But `_takenDoseKeys` (line 42) is a parallel stored flag consulted first, and `active_sessions.verified` is a boolean another writer can flip back. — **Fix:** drop `_takenDoseKeys` once dose logs are server-backed and derive purely from `_todayLogs`.
- N/A **The app suppresses echoes of its own writes.** There is no bidirectional sync loop that could echo — the only write-then-listen surface is Firestore chat, which is append-only, so a re-rendered own message is correct behaviour, not a loop. Re-evaluate this item the moment the dead `listenToVitals`/`listenToAttendance` streams are wired up.
- ⚠️ **Duplicate detection indexes fingerprint → list, never fingerprint → item.** There is no reconciler to grade, but the one place the app matches records by fingerprint has exactly the flaw the checklist names: `medication_provider.dart:342-348` uses `_todayLogs.cast<MedicationLog?>().firstWhere((l) => l.medicationId == med.id && l.scheduledTime.hour == hour && ...)` — `firstWhere` silently returns one of N duplicate logs for the same med+slot and hides the rest. `isSlotLoggedToday` (line 82) and `doseLoggedTimeToday` (line 144) have the same shape. If the staff app ever double-logs a dose, this UI will never show it. — **Fix:** collect matches into a list and surface `length > 1` as a conflict.

### C. Offline & the outbox

- ❌ **Outgoing changes persist in a durable outbox that survives app kill and reboot.** No outbox exists. `grep -rni "queue\|outbox\|pending_upload" lib/` returns only two log strings in `medication_provider.dart:162,173` describing a refill request as *"queued locally"* when in fact `requestRefill` (line 163-179) fires one API call, catches every exception, and returns `true` unconditionally. There is no photo retry queue in this codebase — `firebase_service.uploadFile` (`firebase_service.dart:116-143`) is a single `putFile` that returns `null` on failure with no persistence and no retry. — **Fix:** a `sqflite`/`Hive`-backed outbox table (`{id, endpoint, body, attempts, created_at}`) drained on connectivity change and at app start.
- ❌ **Failures are classified transient / conflict / permanent; unknown errors treated as permanent and surfaced.** Transport-level classification is decent — `ApiService._withRetry` (`api_service.dart:55-84`) retries 5xx, `SocketException` and `TimeoutException` twice with linear backoff, and `_withAuthRecovery` (line 91-100) does a one-shot 401 refresh, deliberately kept out of the retry loop. Above that layer, classification collapses. Every provider catch is `catch (e) { Log.warn(...) }` with a demo fallback: `app_provider.dart:150,215,254`, `my_care_provider.dart:68`, `medication_provider.dart:205,230`, `orders_provider.dart:168,201`. The worst is `medication_provider.dart:321-323` — `catch (_) { /* Silently fail — stock update is non-critical */ }`, a bare swallow. — **Impact:** a 403 from a mis-deployed rule, a 422 from a schema mismatch and a genuine offline are indistinguishable to the user; all three render as demo data. — **Fix:** introduce `SyncFailure { transient, conflict, permanent }`, map `ApiException.statusCode` onto it in one place, and make `permanent` mandatory to surface.
- ⚠️ **A permanent failure produces one human sentence with the count and a next step.** Exactly one site does this correctly: `raise_concern_screen.dart:353-366` (quoted in §0.3). Everything else either says nothing or claims success. `return_screen.dart:365-372` gives a good generic sentence with a phone-the-coordinator next step but no count. — **Fix:** adopt the raise-concern pattern as the house style for every write path once the outbox lands.
- N/A **A single poison record cannot re-alert on every launch forever (retry caps / quarantine).** Vacuously satisfied: there is no persistent queue, so there is no record to become poison. This item becomes live and unsatisfied the moment C1 is implemented — design the `attempts` column in from the start.
- ❌ **Airplane-mode edits on both devices, then reconnect: both converge, nothing doubles, nothing vanishes (tested this release).** No test exists (`find test -name "*sync*"` → nothing; 102 test files, none covering multi-device or offline reconciliation), and no mechanism exists to test. Per §0.2/§0.3 the actual behaviour is that both devices' edits vanish. — **Fix:** blocked on C1; then add a provider-level test that queues N writes with the client offline and asserts exactly N server calls with stable ids on drain.
- ❌ **The app is killed mid-sync and relaunched: the queue resumes; nothing is sent twice with a new identity.** No queue to resume. The nearest thing, `SyncService._inFlightSync` (`sync_service.dart:16-19,35-39`), correctly de-duplicates concurrent `syncAll` calls via a shared `Completer` — genuinely good code — but `SyncService` is never constructed (`grep -rn "sync_service" lib/ test/` → no matches), so it protects nothing. — **Fix:** either wire `SyncService` into `MultiProvider` in `lib/main.dart` and give it the outbox, or delete it so it stops implying a capability that isn't there.

### D. Sharing lifecycle — every arrow, both directions

The entire section fails against a single fact: `lib/screens/settings/family_members_screen.dart` is a local mock. `_mockMembers` is a `static final` list of two hardcoded `FamilyMember`s (lines 22-45); `initState` copies it into `_members` (line 51); add and remove are `setState` on that copy (lines 65, 243) followed by a confirmation snackbar (lines 68-70, 245-249). `grep` confirms `inviteFamilyMember`, `addFamilyMember`, `updateFamilyMember`, `removeFamilyMember`, `removeFamilyMemberLegacy` and `getFamilyMembers` — all declared in `lib/services/i_api_service.dart:176-183` — are **called zero times** from `lib/`.

- ❌ **Invite → accept tested with two real accounts, including "app not installed" and OS routing.** No invite is ever sent. There is no deep-link/universal-link handler for an invite (`grep -rn "uni_links\|app_links\|onGenerateInitialRoutes" lib/` → nothing); the only external entry point is FCM tap routing (`main.dart:369`).
- ❌ **Revoke: participant's device detects it, says so plainly, cleans up local state.** No revoke transport, no detection, no cleanup.
- ❌ **Leave: local removal AND server-side departure both confirmed; server call queued and retried; owner's participant list checked afterwards.** The "Remove family member?" confirm dialog (`family_members_screen.dart:59-61`) does a local `removeWhere` and shows *"${member.name} removed"*. Nothing leaves the device.
- N/A **Leave never deletes the owner's data (zero tombstones for a departure).** Vacuously true — no departure reaches a server, so no tombstones can be minted. Recorded as N/A rather than ✅ so it is not read as evidence of a working flow.
- ❌ **Re-invite after leave works; the stale participant entry does not block it.** Untestable — the "removed" member reappears on next screen entry because `_members` is re-seeded from `_mockMembers` (line 51).
- ❌ **Stop-sharing by the owner: participants' devices handle orphaned state without crash or silent resurrection.** No such flow.
- ❌ **An owner's later edit cannot silently resurrect a workspace the participant left (detach confirmed server-side).** Local-only removal is precisely the "resurrection" case — the member is back after one screen re-entry.

**BLOCKED-OWNER — API contract needed** to implement any of D:
```
POST   /patients/{patientId}/members/invite   { phone, relationship, role, notification_preferences }
         → 201 { invite_id, status: "pending", expires_at }        [idempotent on (patientId, phone)]
GET    /patients/{patientId}/members          → [{ member_id, user_id, name, phone, role,
                                                   status: invited|active|removed, joined_at, removed_at }]
POST   /invites/{inviteId}/accept             → 200 { member_id, patient_id }   [callable pre-install via deep link]
DELETE /patients/{patientId}/members/{memberId}  (owner revoke)   → 204   [idempotent]
DELETE /patients/{patientId}/members/self        (participant leave) → 204   [idempotent; MUST NOT cascade-delete patient data]
```
Plus: an FCM `membership_changed` push so the removed participant's device learns without polling, and a decision on whether `removed` members retain read access to historical reports (a PHI-retention question only the owner can answer).

### E. The two-phone QA matrix

- **BLOCKED-OWNER** — **Device A on current build, Device B one version behind.** Requires two physical devices and two TestFlight/Play tracks. Needed to verify: two builds of the app, two real accounts on one patient, and confirmation of which build is on each.
- **BLOCKED-OWNER** — **Edit the same record on both within seconds → documented winner wins; loser's device shows the winner's value.** Requires a reachable backend and a written conflict policy (see B1). As of this commit there is no shared record two devices can both write, so the test has no subject.
- **BLOCKED-OWNER** — **Create on A while B is offline → B receives on reconnect.** Only chat could pass this today; needs a live Firestore with rules that permit the app's uid/patientId shape (see §0.7).
- **BLOCKED-OWNER** — **Attachment/file sync while the receiving device is LOCKED (file-protection classes; verify retry on unlock).** Requires a locked physical iPhone plus a working upload path. Note `firebase_service.uploadFile` has no unlock retry — on failure it returns `null` once (`firebase_service.dart:141`).
- ❌ **Every "it synced" claim verified by reading the other device, never by the absence of errors on the sender.** Graded on code, not devices: the app systematically does the opposite. `payment_service.dart:113-122` calls `_onSuccessCallback` after an 800ms `Future.delayed` with no network involved; `medications_screen.dart:299`, `my_care_screen.dart:617`, `document_repository_screen.dart:700`, `family_members_screen.dart:245` and `cart_screen.dart:536` all render success from local state alone. One counter-example deserves credit: `payment_service.dart:150-174` refuses to fire success until `verifyPayment` returns, and on failure says *"Payment under verification — we'll confirm in 24 hours"* rather than confirming the booking — that is the right shape.

### F. Recovery & repair

- ❌ **A user-reachable re-sync exists and reports a real count of what it did.** Pull-to-refresh on 5 of 92 screens (§0.4), none of which report a count. `grep -rni "re-sync\|resync\|sync now\|clear cache" lib/screens/` → no matches. `CacheService.clear()` (`cache_service.dart:38-44`) exists and is unreachable from the UI. — **Fix:** a Settings → "Refresh all data" action that drains the outbox, refetches, and reports "Synced 3 doses, 1 vital reading. 1 item couldn't be sent."
- N/A **Ownership/membership repair verifies against server truth before offering itself, and reroutes transport when accepted.** No membership transport exists to repair (see D). Blocked behind the D contract.
- N/A **Repair actions are idempotent.** No repair actions exist.
- ❌ **Orphaned records (nil parent/scope) are healed by a sweep, and the write path that creates them is guarded.** Per §0.1, **seven of eight app-data stores are orphans by construction** — `housepital_orders`, `housepital_assessments`, `housepital_cart_items`, `housepital_saved_items`, `housepital_reminders`, `housepital_saved_addresses` and `daily_rating_*` carry no patient id and no account id. There is no sweep and the write paths are unguarded. Only `housepital_cache_dashboard_<patientId>` is scoped. — **Fix:** prefix every key with `${accountId}_${patientId}_`, and add a startup sweep that deletes keys whose scope does not match the signed-in account.
- N/A **Cascade deletes mint explicit tombstones for every child.** The app performs no cascading deletes. `deleteMedication` (`medication_provider.dart:294-309`) is a server-side soft delete with a local `removeWhere` and a local notification cancel; document/family/reminder deletes are local-only. Re-evaluate once any of those gain a server transport.

---

## Blockers (must fix before release)

1. **PHI leak on patient switch.** `lib/providers/app_provider.dart:157-161` + `:222` + `:40`. `switchPatient` resets nothing; `_seedDemoDataIfEmpty` is a no-op after the first load; the API failure path deliberately keeps the previous data. Patient A's deployment, attendance, vitals, report, amount due and manual vitals history render under patient B's name. `MyCareProvider`, `MedicationProvider`, `OrdersProvider`, `CartProvider` and `RemindersProvider` are never told about the switch at all, and `AssistantProvider` is hard-bound to `DemoData.patient.id` at `lib/main.dart:225`.
   **Fix:** add `void resetForPatient(String patientId)` to each patient-scoped provider (clear all state, clear `_vitalsHistory`, null `_lastFetchedAt`); have `switchPatient` call every one of them before `loadDashboard()`; make `AssistantProvider` a `ChangeNotifierProxyProvider` on `AppProvider.currentPatient`; prefix every SharedPreferences key with the patient id.

2. **PHI leak on logout.** `lib/providers/auth_provider.dart:217-227` clears `SharedPreferences` but resets no in-memory provider. Sign out → sign in as another family member on the same phone and the previous patient's data stays on screen. **Fix:** reset every provider from the logout path (same `resetForPatient(null)` entry point as blocker 1).

3. **Medication doses and vitals are logged to nowhere while the UI reports success.** `lib/providers/medication_provider.dart:109-126` (no endpoint exists), `lib/screens/reports/vitals_screen.dart:720` + `lib/providers/app_provider.dart:243-258` (fire-and-forget, failure swallowed). For a home-healthcare app where a caretaker and a family member both administer medication, a dose log that never reaches the server is a clinical-safety defect, not a sync defect. **Fix:** add `POST /patients/{id}/medication-logs` (contract below), route both writes through an outbox, and hold the "Taken" state behind an acknowledged write with a visible pending state.

4. **Every direct-Firestore call is denied by the deployed rules.** `firestore.rules:67,70,90,94,99,133` compare `request.auth.uid` to `patientId`; the app's patient ids are `pat_demo_rajesh`-shaped (`lib/main.dart:225`). Additionally `staff_otp_verification_screen.dart:80-89` writes to `active_sessions`, which is `allow write: if false` (`firestore.rules:134`) — unawaited and uncaught, so the patient waits forever on an OTP the staff app cannot see. **Fix:** ship the `user_patients` mapping the rules' own TODO (`firestore.rules:151`) calls for and rewrite the rules against it; move OTP minting server-side; at minimum `await` `_storeOtp()` in a `try/catch` and show a failure state.

## High

5. **`SyncService` is dead code and there is no polling.** `lib/services/sync_service.dart` — never imported (`grep -rn "sync_service" lib/ test/` → no matches). Its `_inFlightSync` de-duplication and `syncDashboardData(patientId, lastSyncAt)` delta contract (`i_api_service.dart:35`) are the right design; nothing uses either. Either wire it into `lib/main.dart` or delete it.
6. **Three working Firestore real-time listeners are subscribed by nobody.** `firebase_service.dart:237,255,277`. These are the cheapest possible fix for cross-device freshness on attendance, vitals and notifications.
7. **FCM never refreshes state.** `lib/main.dart:355-372` — a push shows a snackbar or navigates; no provider reload. `MyCareProvider.refresh`'s doc comment (`my_care_provider.dart:103`) claims the FCM handler calls it; it does not.
8. **Ad-hoc `ApiService()` instances have no auth token.** 16 call sites in `lib/screens/` (`grep -rn "ApiService()" lib/screens/ | wc -l` → 16). `setAuthToken` is only ever called on the `AuthProvider`-owned instance (`auth_provider.dart:55,97,160`), and `onUnauthorized` is only wired there (`main.dart:181`). So `notifications_screen.dart:149` (mark-read), `notifications_screen.dart:33` (mark-all-read), `return_screen.dart:325`, `staff_replacement_screen.dart:187`, `equipment_detail_screen.dart:1351` all issue unauthenticated writes that 401 with no recovery — and `notifications_screen.dart:149` does so inside an uncaught `async` `onTap`.
9. **Family-member sharing is a mock.** Section D in full. Six ❌ items, one API contract missing.
10. **Equipment return sends a local device path as `photoUrl`.** `return_screen.dart:330` — `photoUrl: _photoPath`. This is the audit-M-9 defect that was fixed for chat (`chat_screen.dart:133`) and concerns (`raise_concern_screen.dart:328`) but not here; the coordinator receives an unopenable `/var/mobile/...` string.

## Medium / Low

11. **Client-minted ids are clock-derived everywhere** (B2 list). Medium — becomes a duplication bug the day writes actually reach a server.
12. **`patient_log_${medicationId}_$timeSlot` has no date component** (`medication_provider.dart:116`) while `_doseKey` (line 45) does. Low today (in-memory), Medium once persisted.
13. **Local-notification id collisions.** `medication_reminder_service.dart:288` — `medicationId.hashCode.abs() * 10 + slotIndex`. A medication with ≥10 daily slots overruns into the next medication's id block, and `_generateSnoozeId` (line 292) uses `+5`, colliding with slot index 5. Dart's `String.hashCode` is also not contractually stable across SDK versions, so a Flutter upgrade can orphan every scheduled reminder.
14. **`orderTracking` and OTP Firestore listeners swallow errors.** `order_tracking_screen.dart:167` — `onError: (_) { setState(() => _isLoading = false); }` renders an empty timeline with no explanation. `staff_otp_verification_screen.dart:93-115` has no `onError` at all.
15. **`updateStock` swallows everything.** `medication_provider.dart:321-323` — `catch (_) { // Silently fail — stock update is non-critical }`. A checklist red flag verbatim.
16. **Chat input does not clear until the server acks.** `chat_screen.dart:78-91` — `_msgController.clear()` runs after `await _messagesRef.add(...)`. Offline, Firestore applies the write locally (so the bubble appears) but the future does not complete, leaving the user's text sitting in the box looking unsent.
17. **`raise_concern` shows the photo-failure snackbar before the concern submission is awaited.** `raise_concern_screen.dart:356` vs `:370`. On a submission failure the user sees "your concern was submitted without them" followed by "Failed to submit".
18. **Pull-to-refresh missing on 11 data-bearing screens** (§0.4 list) — Billing, Transaction log, Daily report, Vitals, Care team, Notifications, Documents, Family members, Order tracking, Invoice detail, Attendance history.
19. **`CacheService.getLastUpdatedText()` is implemented, tested, and never used** (`cache_service.dart:75`; only `test/services/cache_service_test.dart` calls it). `AppProvider.lastUpdatedText` hardcodes `'Last updated: just now'` (`app_provider.dart:212`) instead.
20. **`isStale` reports "fresh" for demo data** — `my_care_provider.dart:50` sets `_lastFetchedAt` when seeding `DemoData`, asserted at `test/providers/my_care_provider_test.dart:205`.
21. **`addPatient` has a `TODO(persistence)`** — `app_provider.dart:171`. A patient added on one phone exists only there, and only until app kill.

---

## BLOCKED-OWNER

| # | Item | What is needed |
|---|---|---|
| E1–E4 | Two-phone QA matrix | Two physical devices, two real accounts on one patient, two app builds (current + n-1), a reachable `api.housepital.in`, and a locked-device attachment test. Cannot be simulated. |
| D (all) | Sharing lifecycle | The member/invite API contract in §D above, plus an owner decision on whether a removed family member retains read access to historical reports (PHI retention). |
| §0.2 | Medication dose logging | **Contract needed:** `POST /patients/{patientId}/medication-logs` accepting `{ client_log_id, medication_id, scheduled_time, actual_time, status, logged_by_user_id, source: "patient"|"staff", notes }`, returning `201` on create and `200` on replay of the same `client_log_id` (idempotent). `GET /patients/{patientId}/medication-logs?date=` must return `logged_by` and `source` so the UI can show "given by caretaker" vs "logged by you". **Owner decision required:** when the family and the staff app both log the same slot, is that one dose (dedupe on `medication_id + scheduled_time`) or two (a genuine double-dose the app should warn about)? This is a clinical question, not an engineering one. |
| §0.3 | Daily care rating | `submitDailyRating` already exists in `i_api_service.dart:159`. Owner needs to confirm the backend endpoint is live; the client call is a two-line change from there. |
| §0.6 | Cart across devices | **Contract needed:** `GET/PUT /patients/{patientId}/cart` with an `updated_at` for LWW, or an explicit owner decision that the cart is intentionally device-local (which is defensible — but then the "Booking request sent to your primary contact" copy at `cart_screen.dart:544` must be removed, because it promises cross-device behaviour the design does not provide). |
| A1 | Environment split | Owner must provision a staging `api.housepital.in` host and a second Firebase project before the debug/release split can be implemented. |
| A2/A3 | Rules deploy gate | Owner must confirm CI has (or can be given) a Firebase service-account credential with `firebaserules.releases.get`, so the diff gate can run. |

---

## Red flags present (checklist "stop the release" list)

| Red flag | Present? | Evidence |
|---|---|---|
| Any error path that logs and returns | **Yes, pervasively** | `app_provider.dart:150,215,254`; `my_care_provider.dart:68`; `medication_provider.dart:205,230,321`; `orders_provider.dart:168,201`; `firebase_service.dart:101,130,140,151,166,175,184,192,204,213,221,229,247,269,289,365`; `order_tracking_screen.dart:167` |
| "It worked on my phone" as sync evidence | **Yes** | Zero multi-device tests among 102 test files; every success dialog in §0.3 fires from local state |
| A schema change merged without a written deploy step | **Yes** | `firestore.rules` shipped `active_sessions: allow write: if false` while `staff_otp_verification_screen.dart:82` writes to it. No CI gate; no dated deploy record |
| A share/leave/revoke flow tested on one device only | **Worse** | Not tested on any device — the flow is a `setState` on a static mock list |
| A repair button whose effect you cannot state in one sentence | **No** | Vacuously clean: there is no repair button |

---

## Verdict

**FAIL.** 19 of 35 items fail, 5 are partial, 1 passes, 6 are not applicable, and 4 require the owner. Four of the failures are release blockers, two of which (patient-switch and logout state leakage) are PHI-safety issues in an app whose whole premise is that several people watch one patient's care.

The gap is not a broken sync layer — it is the absence of one. The correct read of this audit is that the app is a well-built **read-only, demo-mode client** with local convenience storage, and it should not be described to families as a shared care record until items 1–4 land. The encouraging part: the pieces are half-built and correct where they exist — `SyncService`'s in-flight de-duplication, the three Firestore listeners, `syncDashboardData`'s delta contract, `raise_concern`'s failure copy, and `payment_service`'s refusal to confirm before verification are all the right shapes. They just aren't connected to anything.
