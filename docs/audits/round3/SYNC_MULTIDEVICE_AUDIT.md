# Sync & Multi-Device Checklist (App-Agnostic) — Audit round 3 vs commit `9a80fe2`

**Date:** 2026-08-05 · **Round 2:** `820060b` (+ repairs at `5fa6d95`) · **Round 1:** `803124d`
**Branch:** `fix/five-tab-nav` · **Scope:** read-only. This file is the only write.
**New this round:** the two real backend repos were read —
`/Users/ateeshayjain/WIPApps/Housepital/housepital-backend` and
`/Users/ateeshayjain/WIPApps/Housepital/housepital-api`.

---

## Headline

**The PHI repair is, this time, mostly real.** `_vitalsHistory` is cleared, the cart no longer
re-persists the outgoing patient's wishlist, orders reach disk, reminders/addresses/ratings/cache
are in `SessionScope`, both call sites `await`, and the regression test now asserts the *stores*
rather than the fields the implementation happened to touch. Five of round 2's six PHI gaps are
genuinely closed. That is the first round where a fix survived adversarial reading largely intact.

**Three things spoil it, and all three are the same mistake one level up:**

1. **`loadPatients()` got a guard that clears the wrong scope.** Round 2 said the fix "needs the
   *cross-provider* clear." It got `clearPatientScopedData()` — `AppProvider`'s eight fields only
   (`app_provider.dart:157-159`). Medications, orders, cart, assistant transcript, reminders,
   saved addresses, daily ratings and the dashboard cache all survive that switch path. And the
   new test (`patient_scope_isolation_test.dart:293-308`) asserts exactly the one field the
   implementation clears — **the identical "test written from the implementation" pattern round 2
   caught, reproduced in the test written to prevent it.**
2. **`SessionScope` — the file that IS the contract — has zero test coverage.**
   `grep -rn "SessionScope" test/` returns one hit: a *comment*
   (`patient_scope_isolation_test.dart:12`). Every test drives providers directly. Delete a
   provider from `clearPatientData` and the suite stays green.
3. **`DemoMode`-as-a-set inverted its own bug instead of fixing it.** Ten sources can be raised;
   `markServingLiveData` has **one** call site (`app_provider.dart:273`, dashboard). The file's own
   doc comment names the defect it did not fix: *"`MyCareProvider` raised it and never lowered it,
   so a healthy backend showed a permanent false alarm."* Nine sources now do exactly that.

**And the round-3 headline finding is not in this repo at all.** There are two production
databases claiming the same six clinical facts, with incompatible identity, grain and vocabulary —
§B below. One of them contains two code-vs-schema drifts that would 500 on first contact. That is
the sync finding; the app's local wipe is a subplot.

**Unchanged and still the worst defect in the app:** the dose logged to nowhere (§0.2). Round 3
can now say *why* it is unfixable by client work alone: the backend table has no column for it.

---

## Round-2 findings: status now

| Finding | R2 grade | Now | Evidence |
|---|---|---|---|
| **NEW-1** `_vitalsHistory` not cleared | ❌ BLOCKER | ✅ **Fixed** | `app_provider.dart:201` — `_vitalsHistory.clear(); // manually entered readings — PHI`. Asserted twice: `patient_scope_isolation_test.dart:115-118` and `:225-240`. |
| **NEW-2** cart `clear()` re-persists A's saved items | ❌ BLOCKER | ✅ **Fixed** | `cart_provider.dart:207-212` `clearPatientScopedData()` clears `_items` **and** `_savedItems` then `_persist()`s. `session_scope.dart:63` calls it, not `clear()`. Disk asserted: `patient_scope_isolation_test.dart:260` `expect(prefs.getString('housepital_saved_items'), '[]')`. |
| **NEW-3** orders cleared in memory, not on disk | ❌ HIGH | ✅ **Fixed** | `orders_provider.dart:212-219` now calls `_persistAndNotify()`. Asserted at `patient_scope_isolation_test.dart:273`. |
| **NEW-4** four stores outside `SessionScope` | ❌ HIGH | ✅ **Fixed** | `RemindersProvider.clearPatientScopedData()` clears memory **and** `prefs.remove(storageKey)` (`reminders_provider.dart:194-204`), awaited at `session_scope.dart:67`; `housepital_saved_addresses` at `session_scope.dart:47`; `daily_rating_*` swept by prefix at `:91-95`; `CacheService.clear()` at `:84`. |
| **NEW-5** handover PDF hardcoded to `DemoData` | ❌ BLOCKER | ⚠️ **Half** | `handover_report_service.dart:107-114` **still** reads `DemoData.patient` / `.medicalHistory` / `.vitalsHistory`; the method still takes no patient and consults no provider. What changed: `:105` marks `DemoMode.sourceHandover` and `:133` stamps `SAMPLE DATA - NOT A CLINICAL RECORD`. The *honesty* defect is fixed — nobody can now mistake it for a record. The *functional* defect is untouched: the "doctor handover report" cannot report on the patient. Cross-patient PHI risk is now nil (it is always fabricated data), so it drops from Blocker to a High correctness bug. **New side effect:** nothing ever calls `markServingLiveData(sourceHandover)`, so generating one PDF pins the sample-data pill up for the rest of the process. |
| **NEW-6** assistant bound to demo patient; transcript survives logout | ❌ HIGH | ⚠️ **Half** | Transcript ✅ — `assistant_provider.dart:184-189` clears `_messages`, wired at `session_scope.dart:60`. Binding ❌ — `main.dart:234` still `final patientId = DemoData.patient.id;` and `:260` still `deploymentId: DemoData.icuDeployment.id`. Still not a `ChangeNotifierProxyProvider`. Every assistant-executed action is still filed against `pat_demo_rajesh`. |
| **NEW-7** screen-local `State` holds patient data | ⚠️ | ❌ **Unchanged, and worse than described** | `family_members_screen.dart:22` `static final _mockMembers`; `document_repository_screen.dart:80` hardcoded `_documents`; **and `vitals_screen.dart:50` `_generateMockData()`** — see BLOCKER 1 below, which round 2 missed. |
| **NEW-8** dashboard cache write-only, never cleared | ⚠️ | ⚠️ **Half** | Cleared now (`session_scope.dart:84` → `CacheService.clear()`). Still write-only: `CacheService.get()` has zero callers; the only production use is the write at `app_provider.dart:274`. The comment at `:232` ("with offline caching") still describes a read path that does not exist. |
| **NEW-9** `DemoMode` one global flag lowered by one provider | ⚠️ REGRESSION RISK | ⚠️ **Different bug, same class** | Now a `Set` (`demo_mode.dart:35-65`) — the false all-clear is gone. But `markServingLiveData` has exactly **one** call site (`app_provider.dart:273`). Ten sources raise; one lowers. See HIGH 2. |
| **NEW-10** banner absent on pushed routes | ⚠️ | ✅ **Fixed** | `DemoDataBannerHost` installed from `MaterialApp.builder` (`main.dart:431`, "Above the Navigator"), so it covers every route. |
| **NEW-11** three demo fallbacks never set the flag | ⚠️ | ⚠️ **Partly; new ones found** | `blog_provider.dart:40,70` ✅ now marks; `app_provider.dart:142` ✅ now marks `sourcePatientIdentity`; handover ✅ marks. **Still unmarked:** `vitals_screen.dart:50` (no `sourceVitals` constant exists at all), `care_team_screen.dart:31`, `care_calendar_screen.dart:1324`, `document_repository_screen.dart:80`, `family_members_screen.dart:22`, `payment_screen.dart:64`. Three declared sources — `sourceCareTeam`, `sourceCareCalendar`, `sourceProfile` (`demo_mode.dart:32-34`) — are **never raised by anything**. |
| **NEW-12** `_currentUserRole` not reset by `clearSession` | ⚠️ Low | ✅ **Fixed** | `app_provider.dart:217` — `_currentUserRole = 'PRIMARY_CONTACT';` inside `clearSession()`. `_profilePhotoPath` nulled at `:216` too. |
| **NEW-13** `clearSession` not awaited before `logout()` | ⚠️ | ✅ **Fixed** — and the deeper race is closed too | `settings_screen.dart:460-461` now `await SessionScope.clearSession(context); await auth.logout();`. Full re-persist analysis in §"Ordering, re-examined" — no path re-writes patient data between the two. **But the mechanism chosen to preserve two keys introduced a new hazard: HIGH 3.** |
| **NEW-14** `StoreMigrator._v1Keys` misses key families | ⚠️ Low | ✅ **Fixed, well** | `_v1Keys` deleted; `_hasAnyStoredData` walks `prefs.getKeys()` (`store_migrator.dart:139-144`) with an honest note at `:37-43` about why the curated list was wrong. `run()` is throw-guarded (`:56-67`); a failed step stamps the last *good* version and returns (`:113-125`); `_migrateFrom` always stamps (`:134`), closing the `while (1 < 1)` hole. |
| **Part 1 · `loadPatients()` unguarded switch** | ❌ BLOCKER | ⚠️ **Guard added, wrong scope** | `app_provider.dart:156-160`. Correct as far as it goes; clears only `AppProvider`. See BLOCKER 2. |
| **Part 1 · `updateFromSync()` unguarded** | ⚠️ dormant | ❌ **Unchanged** | `app_provider.dart:335-341` — `if (patient != null) { _currentPatient = patient; … }`, still no identity check, still no clear. It is now the *only* patient-assignment site with no guard at all, which makes it more likely to be trusted, not less. |
| Dose logged to nowhere | ❌ BLOCKER | ❌ **Unchanged** | `medication_provider.dart:110-127`. See §0.2. |
| Firestore rules deny every direct call | ❌ | ❌ **Unchanged** | `firestore.rules:67,70,90,94,99,133` still `request.auth.uid == patientId`; `:134` still `allow write: if false` on `active_sessions`, which `staff_otp_verification_screen.dart:83` writes to. See HIGH 4 — the repo now contains a file that diagnoses this exact bug and does not fix it. |
| `SyncService` dead code | ❌ | ❌ **Unchanged** | `grep -rn "SyncService" lib/ test/` → only `sync_service.dart` itself + one comment at `app_provider.dart:322`. |
| Three Firestore listeners, no subscribers | ❌ | ❌ **Unchanged** | `firebase_service.dart:237,255,277` — zero call sites. |
| FCM never refreshes state | ❌ | ❌ **Unchanged** | `main.dart:345-377` — `Navigator.pushNamed` + `showSnackBar`, no provider reload. |
| 16 unauthenticated ad-hoc `ApiService()` | ❌ | ❌ **Unchanged** | `grep -rn "ApiService()" lib/screens/ \| wc -l` → **16**. |
| Family sharing is a mock | ❌ | ❌ **Unchanged — but no longer blocked** | `family_members_screen.dart:22,51`. The API contract round 2 requested from the owner **already exists**: `housepital-backend/functions/src/routes/family.ts:17,48,103,129,193,230`. Reclassified from BLOCKED-OWNER to actionable client work. |
| Equipment return sends local path as `photoUrl` | ❌ | ❌ **Unchanged** | `return_screen.dart:331`. |
| No polling · pull-to-refresh on 5 of 91 screens | ❌ | ❌ **Unchanged** | `grep -rln RefreshIndicator lib/screens/ \| wc -l` → **5**; `find lib/screens -name '*.dart' \| wc -l` → **91**. |
| `submitDailyRating` zero callers | ❌ | ❌ **Unchanged** | `i_api_service.dart:159`, `api_service.dart:506`, no call site in `lib/`. |

**Round-2 tally: 8 fixed ✅ · 5 half ⚠️ · 12 unchanged ❌ · 0 regressed.**
No round-2 finding regressed. That is worth saying plainly — it is the first round where that is true.

---

## Round-2 repairs: adversarial review

### The store enumeration, done independently

I built the list from the tree, not from `SessionScope`, then diffed. Method:
`grep -rn --include=\*.dart -E "\.(setString|setBool|setInt|setDouble|setStringList)\(" lib/`
plus every `ChangeNotifier` field and every `State` field holding patient data.

**SharedPreferences — every key written anywhere in `lib/`:**

| Key | Writer | Patient data? | Switch | Logout |
|---|---|---|---|---|
| `housepital_cart_items` | `cart_provider.dart:222` | yes | ✅ `:207` | ✅ |
| `housepital_saved_items` | `cart_provider.dart:226` | yes | ✅ `:207` | ✅ |
| `housepital_orders` | `orders_provider.dart:167` | yes | ✅ `:218` | ✅ |
| `housepital_assessments` | `orders_provider.dart:168` | yes | ✅ `:218` | ✅ |
| `housepital_reminders` | `reminders_provider.dart:181` | yes | ✅ `:199` | ✅ |
| `housepital_saved_addresses` | `address_selection_screen.dart:126` | yes | ✅ `session_scope.dart:47` | ✅ |
| `daily_rating_<YYYY-MM-DD>` | `my_care_screen.dart:615` | yes | ✅ `session_scope.dart:91-95` | ✅ |
| `housepital_cache_dashboard_<id>` | `cache_service.dart:19` | yes | ✅ `session_scope.dart:84` | ✅ |
| `profile_photo_path` | `app_provider.dart:107` | identity | ⚠️ **key survives a switch** (field nulled only on logout, `:216`); the JPEG on disk survives both | ✅ key |
| `housepital_pending_deletion` | `delete_account_screen.dart:83` | contains `patientId` | ❌ by design | ❌ by design — §"Deletion flow" |
| `housepital_schema_version` | `store_migrator.dart:76,123,128,134` | no | N/A | ❌ by design ✅ correct |
| `preferred_language` | `app_provider.dart:93`, `auth_provider.dart:197` | no — device | N/A ✅ | ✅ |
| `theme_mode` | `theme_provider.dart:55` | no — device | N/A ✅ | ✅ |
| `has_onboarded` | `auth_provider.dart:196` | no — account | N/A ✅ | ✅ |
| notification-preference booleans | `app_provider.dart:130` (dynamic keys) | no — device | N/A ✅ | ✅ |
| `__quarantine_v*_*` | `store_migrator.dart:157-165` | **yes, by design** | ❌ | ⚠️ removed by the logout loop — **which defeats the purpose**: quarantine exists so support can recover a patient's order history, and a logout silently destroys it |

**Provider fields holding patient state — all reachable, none missed:**
`AppProvider` (`:196-207`, `:210-219`) ✅ · `MyCareProvider:114-124` ✅ · `MedicationProvider:391-401`
✅ · `BillingProvider:68-74` ✅ · `OrdersProvider:212-219` ✅ · `AssistantProvider:184-189` ✅ ·
`CartProvider:207-212` ✅ · `RemindersProvider:194-204` ✅. `BlogProvider` and `ThemeProvider` hold
no patient data — correctly absent.

**Screen-held `State` — `SessionScope` cannot reach any of it:**

| Screen | Field | Content |
|---|---|---|
| `vitals_screen.dart:50` | `_vitals` | **7–180 days of RNG-generated BP/pulse/SpO2/temp/sugar** — BLOCKER 1 |
| `family_members_screen.dart:22,51` | `_mockMembers` → `_members` | fabricated family roster |
| `document_repository_screen.dart:80` | `_documents` | fabricated prescriptions/discharge summaries |
| `address_selection_screen.dart:106-110` | addresses | writes three defaults on first **read** |
| `care_team_screen.dart:31` | `DemoData.supervisor` | unmarked |
| `care_calendar_screen.dart:1324` | `DemoData.icuServiceDetail.staffOnDuty` | unmarked |
| `payment_screen.dart:64` | `_mockCoupon` | unmarked |

**Diff verdict:** `SessionScope` now reaches **every provider field and every SharedPreferences key
that holds patient data.** That is a real, complete enumeration and it deserves the credit. What it
does not and structurally cannot reach is the seven screens above — and one of them fabricates
clinical measurements.

---

### Ordering, re-examined: can a persist scheduled BEFORE the wipe land AFTER it?

**No — but for a reason nobody wrote down, and it is one refactor away from breaking.**

`CartProvider._persist()` (`cart_provider.dart:219-233`) and `OrdersProvider._persistAndNotify()`
(`orders_provider.dart:163-173`) are both `async` and both fire-and-forget from a synchronous
`void clearPatientScopedData()`. So two of them can be in flight at once. The reason patient A's
data cannot land after the wipe:

- Both encode **after** their first `await`: `await SharedPreferences.getInstance();` comes before
  `json.encode(_items…)` / `jsonEncode(_orders)`. The encode is therefore deferred to a later
  microtask, by which time the clear has already run synchronously.
- `CartProvider` mutates `_items`/`_savedItems` **in place** (`final List`), so even a persist that
  is mid-way between its two `setString` calls encodes the emptied list for the second write.
- `OrdersProvider` **reassigns** `_orders = []`, but `jsonEncode(_orders)` is a field read at call
  time, so it also sees the new list.

Both are correct. **Neither is correct on purpose.** Change `_items.clear()` to `_items = []`, or
hoist the encode above the `await` for one fewer allocation, and round 2's NEW-13 race is live
again with no test to catch it. This deserves a comment in both files and an assertion that a
persist started before the clear cannot write non-empty JSON.

The `await` at `settings_screen.dart:460-461` closes the *other* half — `clearSession` no longer
races `logout()`. `delete_account_screen.dart:143-145` was already correct and still is.

---

### HIGH 3 — the logout wipe stopped being atomic

`auth_provider.dart:229-236`:

```dart
const preserved = <String>{'housepital_schema_version', 'housepital_pending_deletion'};
for (final key in prefs.getKeys().toList()) {
  if (preserved.contains(key)) continue;
  await prefs.remove(key);
}
```

This replaced `prefs.clear()`. Three problems the replacement introduced:

1. **The key list is a snapshot and each `remove` yields.** Any key written by a concurrent task
   after `getKeys()` is never visited. The fire-and-forget persists fired microseconds earlier by
   `SessionScope.clearPatientData` write four keys; for a user who had never used the cart, those
   keys did **not** exist at snapshot time, so the wipe *creates* them and then does not remove
   them. Values are `"[]"` — no PHI, so this is not a blocker — but the failure *shape* is now
   "a key written during the wipe survives", which `prefs.clear()` (atomic on the platform side)
   did not have.
2. **A kill mid-loop leaves a partial wipe.** N platform round-trips instead of one, over an
   unordered `Set`, so *which* patient keys survive a force-quit during logout is
   nondeterministic. On a shared phone, a partially wiped logout is precisely the failure
   `SessionScope` exists to prevent — reintroduced by the mechanism chosen to preserve two keys.
   Checklist C6 ("killed mid-sync, relaunch, nothing resumes wrong") fails on the *teardown* path
   now, not just the sync path.
3. **It destroys quarantined data.** `StoreMigrator.quarantine()` (`store_migrator.dart:151-169`)
   exists so *"a patient's order history is recoverable rather than gone"*. `__quarantine_v*_*` is
   not in `preserved`, so a logout deletes it. The two files disagree about what quarantine is for.

**Fix (three lines, strictly safer):** read the two preserved values into locals → `prefs.clear()`
→ write them back. One atomic platform call, no snapshot, no interleaving. Add
`__quarantine_` as a preserved *prefix*.

---

### BLOCKER 2 — `loadPatients()`'s new guard clears one provider out of eight

`app_provider.dart:150-162`:

```dart
final incoming = apiPatients.first;
if (_currentPatient?.id != incoming.id) {
  clearPatientScopedData(notify: false);   // ← AppProvider ONLY
}
_currentPatient = incoming;
```

**Is the guard correct when `currentPatient` is null?** Yes, and I traced it: `null?.id != 'x'`
evaluates true, so a null current patient clears — the safe direction. It is also effectively
unreachable: the only writer of `_currentPatient = null` is `clearSession()` (`:212`), which sets
`_patients = []` on the next line, so `loadPatients`'s `if (_patients.isEmpty)` seed at `:136-138`
always repopulates it first. Correct, defensive, dead. ✅ on the narrow question.

**The guard is wrong about scope, and that is the finding.** Round 2 wrote: *"it needs the
cross-provider clear, which means `AppProvider` needs a callback or the call must move up into the
widget layer."* Neither happened. `clearPatientScopedData()` clears eight `AppProvider` fields.
Everything else survives this switch path:

`MedicationProvider._medications` / `_todayLogs` / `_takenDoseKeys` · `OrdersProvider._orders` /
`_assessments` (memory **and** disk) · `CartProvider._items` / `_savedItems` (memory **and** disk) ·
`AssistantProvider._messages` · `RemindersProvider._items` (memory **and** disk) ·
`MyCareProvider._activeServices` / `_healthManager` · `BillingProvider` ·
`housepital_saved_addresses` · every `daily_rating_*` · every `housepital_cache_dashboard_*`.

The wired UI path (`home_screen.dart:1774`) gets the full `SessionScope` wipe. This path gets a
tenth of it. Two switch paths with two different definitions of "clear" is exactly the divergence
`SessionScope` was created to eliminate.

**And the test institutionalises it — again.** `patient_scope_isolation_test.dart:293-308` asserts:

```dart
expect(app.currentPatient?.id, 'pat_api_other');
expect(app.activeDeployment, isNull,
    reason: "the outgoing patient's dashboard must not survive");
```

One field. No `MedicationProvider`, no `CartProvider`, no disk. The test was written from the
implementation, so it certifies the gap — **the identical failure mode round 2 caught in this same
file, reproduced in the test added to prevent it.** The file's header (`:12-14`) says *"the point
of this file is that the next person cannot forget"*; it forgot within one commit.

**Second defect in the same three lines:** the guard compares only against `apiPatients.first`. A
user who picks Sunita from the switch sheet, then triggers a `loadPatients()`, is silently moved
back to `apiPatients.first` — a **partial wipe plus a reverted selection**, with no UI signal. The
comparison should be `_currentPatient` against *membership in* `apiPatients`, not against its head.

**Fix:** give `AppProvider` an `onPatientChanged` callback wired in `main.dart` to the same
providers `SessionScope` names — or, better, make `SessionScope` own both switch paths and forbid
`switchPatient` / `loadPatients` from reassigning `_currentPatient` directly.

---

### BLOCKER 1 (new) — the vitals chart fabricates 180 days of clinical readings and merges them with the patient's own

Round 2 fixed `_vitalsHistory` — the *real* readings. It did not look at what they are drawn
against. `vitals_screen.dart:50-70`:

```dart
void _generateMockData() {
  final rng = Random(42);
  _vitals = List.generate(days, (i) { … VitalReading.fromJson({
    'systolic': 120.0 + rng.nextInt(20) - 5,
    'diastolic': 75.0 + rng.nextInt(15) - 5,
    'pulse': 70.0 + rng.nextInt(15) - 3,
    'spo2': 95.0 + rng.nextInt(4),
    'temperature': 97.5 + rng.nextDouble() * 2,
    'sugar': 95.0 + rng.nextInt(35),
  }); });
}
```

`_mergedVitals` (`:106-115`) concatenates `_vitals` with the patient's real
`AppProvider.vitalsHistory`, sorts by timestamp, and returns one list. `build` at `:121` renders it
into the chart, the trend line, the stat cards and "Latest reading". A family member cannot tell
which points are theirs.

**It sets no demo flag.** There is no `DemoMode.sourceVitals` constant in `demo_mode.dart:24-34`,
so the sample-data pill — the whole demo-honesty layer this round rebuilt — is silent on the one
screen where sample data is read as a clinical trend. `:195` regenerates on every period change,
so switching 7d → 90d re-rolls the patient's "history".

This outranks everything the PHI work fixed. A cross-patient leak shows the *wrong patient's real
data* to a reader who might notice the name. This shows **numbers that describe nobody**, under
the right patient's name, on the screen a family opens to decide whether to call a doctor. It is
the same failure class as the dose-log defect (§0.2): the UI is confident about a clinical fact
that does not exist.

**Fix:** delete `_generateMockData` and render the real history, empty-state included; or gate it
behind `DemoMode.markServingDemoData(DemoMode.sourceVitals)` **and** visually distinguish
synthesised points from entered ones. A dashed series is not sufficient — the stat cards and the
trend arrow compute over the mix.

---

### HIGH 2 — `DemoMode` as a set: ten raisers, one lowerer

`grep -rn "markServingLiveData" lib/` → **two hits**: the definition
(`demo_mode.dart:52`) and one call (`app_provider.dart:273`, dashboard).
`grep -rn "markServingDemoData" lib/` → eleven raise sites across eight sources.

So `sourcePatientIdentity`, `sourceMedications`, `sourceMyCare`, `sourceBilling`, `sourceOrders`,
`sourceArticles` and `sourceHandover` can be raised and can never be lowered for the life of the
process. `app_provider.dart:142` raises `sourcePatientIdentity` on the seed at `:136-138`; the
successful API load twenty lines later at `:160` does not lower it. `MedicationProvider:191,236`
raises on fallback; a later successful `loadMedications` does not lower it.

The set fixed the false all-clear and created a permanent false alarm — which `demo_mode.dart:15-18`
explicitly names as the *other* bug it was fixing. A banner that is always up is a banner nobody
reads, and it will be the reason someone removes it.

Also dead: `sourceCareTeam`, `sourceCareCalendar`, `sourceProfile` (`:32-34`) are declared and
never raised by anything, while `care_team_screen.dart:31` and `care_calendar_screen.dart:1324`
serve `DemoData` unannounced. The constants were added; the call sites were not.

**Fix:** every provider's success branch calls `markServingLiveData(itsOwnSource)`, symmetric with
its fallback branch. A test that asserts, per provider, that a successful load lowers exactly its
own flag.

---

### HIGH 4 — `storage.rules` diagnoses the bug that `firestore.rules` still has

`storage.rules:18-29` is the best security comment in the repo:

> `grep -rn "\.uid" lib/` returns ZERO hits. … An earlier draft of this file used
> `request.auth.uid == patientId`, which is always false — deploying it would have denied 100% of
> chat and concern-evidence uploads.

That analysis is correct, and it applies verbatim to `firestore.rules`, which was not touched:
`:67, :70, :90, :94, :99` still compare `request.auth.uid` to `patientId`, and `:133` compares it
to `resource.data.patientId`. Every one is false for the same reason. The author identified the
pattern, wrote it down at length, and did not grep for the other instance. `active_sessions` at
`:134` is still `allow write: if false` while `staff_otp_verification_screen.dart:83` writes there,
unawaited, from `initState`.

Live posture for both files remains **unknown — neither is confirmed deployed** (`storage.rules:8`
carries its own `!! DEPLOY REQUIRED !!` banner).

---

### The deletion flow, assessed against this checklist

`housepital_pending_deletion` survives the wipe by design (`auth_provider.dart:233`) and contains
`{reference, requestedAt, patientId, deliveredToServer:false}` (`delete_account_screen.dart:83-91`).

**Proportionality: ✅.** A patient id is a pseudonymous identifier, not clinical content, and it is
the minimum necessary to service the erasure request — you cannot replay a deletion without
knowing what to delete. The comment at `:56-60` states this reasoning and states it correctly. The
alternative (drop the id) would make the record useless. Under DPDP 2023 §12 this is defensible
retention of processing metadata, not retention of personal data for its own sake. **Do not
"fix" this by deleting the id.**

**Against checklist C1 — "outgoing changes persist in a durable outbox": ⚠️ half.** There is a
durable *record*. There is no *outbox*. `grep -rn "housepital_pending_deletion" lib/ test/` returns
**three** hits: the constant, the write, and the preserve-list. **Zero readers.** Nothing drains it
on next launch, nothing retries, nothing flips `deliveredToServer`, and no test covers it. A user
who deletes their account has a JSON blob on their phone that no code will ever send.

**Against checklist C4 / F3 — idempotence and poison records: ❌.** It is a single-slot key, not a
list. A second deletion request overwrites the first; a device used by two patients keeps only the
last. `reference` is `DEL-<millisecondsSinceEpoch.toRadixString(36)>` — clock-derived, same class
as every other client-minted id (§B2), so two requests in the same millisecond collide.

**The real isolation defect: the record outlives the person it belongs to.** After deletion +
logout, a different family member signs in on the same phone and the previous patient's id sits in
storage, unreadable by the app but readable by anything with filesystem access on a jailbroken or
backed-up device, forever, because nothing ever removes it. The record needs a lifecycle: a reader
at startup, a send, a delete-on-ack, and a cap.

**Copy: ✅ good.** Step 4 (`:148-159`) states DONE and REQUESTED separately and is fully
localized. Compared with round 1's 600 ms `Future.delayed` under a 30-day promise, this is a
genuine repair.

---

## B. Two systems of record for the same six facts — **THE sync finding**

Neither is reachable from the app (`constants.dart:3` still points at `api.housepital.in/v1`,
which resolves to nothing, and is still a plain `const` with no `String.fromEnvironment`). Both are
real, both are provisioned, both define the same six nouns, and **they cannot be reconciled by a
sync layer.**

| | `housepital-backend` — patient API | `housepital-api` — staff API |
|---|---|---|
| Runtime | Firebase Functions (Express + Knex) | Laravel 11 |
| DB | MySQL **`housepital`**, Cloud SQL `housepital-patient:asia-south1:housepital-db` (`.env.example:6-7`) | MySQL **`housepital_db`** (`.env:26`) |
| Keys | `VARCHAR(36)` UUID | `BIGINT` auto-increment |
| Schema | one `sql/001_initial_schema.sql`, **no migrations, no ALTERs** | 7 versioned Laravel migrations |

### The six collisions, in severity order

**1. There is no shared patient identity — the staff DB has no `patients` table at all.**
`grep "Schema::create" database/migrations/` returns 30 tables; `patients` is not one of them. A
patient exists there only as denormalized columns on `deployments`: `patient_name`, `patient_age`,
`patient_gender`, `condition_summary`, `medications` JSON
(`2026_02_25_100000_create_housepital_tables.php:65-75`). The staff side cannot say "patient X" —
only "the patient of deployment 4417". Meanwhile the patient DB's `patients` table carries 30+
clinical columns including `diagnosis`, `iv_central_line`, `feeding_type`, `bp_sugar_insulin`
(`sql/001_initial_schema.sql:9-40`). **Any sync must first invent an identity on one side.** That
is a migration, not a mapping.

**2. `attendance` has a different GRAIN on each side — no total function exists in either
direction.**

- patient: `UNIQUE KEY uk_deployment_date (deployment_id, date)` (`001_initial_schema.sql:181`)
- staff: `$table->unique(['staff_id', 'date'])` (`…create_housepital_tables.php:117`)

One caretaker covering two deployments in a day = two rows on the patient side, **a unique-key
violation** on the staff side. One deployment covered by a replacement (the patient side models
this with `attendance.replacement_name`, `:178`) = one row on the patient side, two on the staff
side. The two stores cannot agree on how many records the fact *is*. This is checklist B2 —
*"records mintable by two devices concurrently need deterministic ids or the merge doubles them
forever"* — in its worst form: the writers disagree about the cardinality, so no id scheme helps.

**3. The same enum, spelled differently — the silent-corruption case.**

| Field | patient DB | staff DB |
|---|---|---|
| `attendance.status` | `checked_in, waiting, late, absent, on_leave, checked_out` | `pending, checked_in, checked_out, absent, leave, late` |
| `deployments.status` | `active, paused, completed, cancelled` | `active, completed, terminated, replaced` |
| `deployments.shift_type` | `12hr_day, 12hr_night, 24hr` | `HD_DAY, HD_NIGHT, FD` |

`waiting`↔`pending` and `on_leave`↔`leave` are the same clinical concept. A string-copy sync feeds
each a value its ENUM rejects: MySQL strict mode errors, non-strict silently stores `''`. And the
app has no defence — `models.dart` `Attendance.status` is a bare `final String` with `status:
json['status']`, an unchecked cast that throws on a null and passes anything else straight through
to UI `switch`es that fall to default. Checklist A6 drops from ✅ to ⚠️ on this evidence.

**4. `vitals` — different owner, different precision, different reference.**
patient: `patient_id` NOT NULL, `DECIMAL(5,1)` systolic/diastolic/pulse/spo2/sugar
(`001_initial_schema.sql:187-205`). staff: `staff_id` NOT NULL + nullable `deployment_id`, **no
patient reference at all**, `INTEGER` bp_systolic/bp_diastolic/pulse/spo2/blood_sugar, plus six
triage columns (`bp_status`, `pulse_status`, `temp_status`, `spo2_status`, `sugar_status`,
`overall_status` — green/yellow/red) the patient DB does not have
(`…create_housepital_tables.php:140-163`). Round-tripping loses the decimal in one direction and
the triage in the other, and both stores are internally valid holding different values for the
same reading.

**5. Only the staff side holds the evidence the family most wants.** `check_in_lat`, `check_in_lng`,
`check_in_within_geofence`, `check_in_selfie_url`, `is_late` (`:105-113`); `sbar_handover`,
`checklist_completion_pct` (`:128-130`); `photo_logs`, `grievances`. The patient DB has
`check_in_selfie TEXT` and nothing else. **"Was the caretaker actually at the house" is provable
only in the staff DB and is not representable in the patient DB** — which is the patient app's
core promise.

**6. `medication_logs` exists on the patient side only, and cannot represent a patient-logged
dose.** `001_initial_schema.sql:444-460`: columns are `id, medication_id, staff_id, staff_name,
scheduled_time, actual_time, status, skip_reason, notes, created_at`. **No `patient_id`. No
`logged_by` / `source`. No unique key on `(medication_id, scheduled_time)`.** The staff DB has no
medication table at all (meds are a JSON blob on `deployments.medications`, `:69`).
So: the app cannot record a patient-logged dose because there is no column for who logged it;
two devices logging the same dose double it because there is no unique key; and the staff app —
where doses are actually administered — writes to a database that has no row for a dose. §0.2's
defect is four layers deep, not one.

### Two live code-vs-schema drifts in `housepital-backend` — the gate this checklist asks for would have caught both

- `functions/src/routes/medications.ts:217` — `db("medication_logs").where("patient_id", patientId)`.
  **`medication_logs` has no `patient_id` column.** `GET /patients/:id/medication-logs` 500s on
  first contact. Confirmed: `awk '/CREATE TABLE IF NOT EXISTS medication_logs/,/ENGINE=InnoDB/'`
  lists ten columns, none of them `patient_id`; `grep -rn "ALTER TABLE" sql/` → nothing.
- `functions/src/routes/ratings.ts:37,48` — queries and inserts `family_member_id`. **The schema
  column is `rated_by`** (`001_initial_schema.sql:388`). The insert also omits `date`, which is
  `DATE NOT NULL` with no default (`:389`), and dedupes on `DATE(created_at)` while the unique key
  is `uk_deployment_rater_date (deployment_id, rated_by, date)` (`:394`). Three faults in one
  handler. This is the endpoint `submitDailyRating` would call.

This is checklist A2 verbatim — *"a mechanical gate blocks release when the deployed schema lags
the app, and the gate counts FIELDS, not just record types."* Neither repo has one. Both bugs are
field-level; a record-type-level check would have passed both.

### An unrelated but load-bearing consequence: the backend cannot return two patients

`sql/001_initial_schema.sql:45` — `user_id VARCHAR(128) NOT NULL **UNIQUE**` on `family_members`.
`functions/src/middleware/auth.ts:38-40` — `db("family_members").where("user_id", uid).**first()**`
→ one `patientId` on the request. `verifyPatientAccess` (`:96-107`) 403s any URL patient id that
is not that one. `GET /patients` (`routes/patients.ts:33-39`) maps memberships to patient ids —
capped at one by the UNIQUE constraint.

**So the entire patient-switch feature — the switch sheet, `switchPatient`, `SessionScope`, two
rounds of PHI repair — is built against a server that structurally cannot return a second
patient, and would 403 every call for one if it did.** The work was still right to do (round 2's
`addPatient` note stands: the blast radius is bounded by a coincidence, not a control). But
"one user watches one patient" on the server versus "one user switches between patients" in the
client is a third system-of-record disagreement, and it needs an owner decision before either
side is built further.

**Also, an authorization hole in the same middleware:** `verifyPatientAccess` is
`if (patientId && authReq.patientId && patientId !== authReq.patientId)`. For an authenticated
Firebase user with **no** `family_members` row, `auth.ts:44-51` sets `patientId = ""`, the guard's
second conjunct is falsy, and the request passes through to handlers that filter on the **URL**
param (`medications.ts:217`, `patients.ts:63`). Any authenticated phone number can read any
patient's medications, vitals and reports by guessing an id. Flagging for the security audit; it is
a data-isolation failure, which is why it appears here.

---

### Merge or sync? **Merge. One database, two APIs.**

**Reasoning.** Sync is viable when two stores agree on *identity* and *grain* and disagree only on
*projection*. These disagree on all three: no shared patient identity (collision 1), different
cardinality for the same fact (collision 2), and three enum vocabularies for the same fields
(collision 3). A sync layer would have to own a permanent bidirectional id map across six tables, a
grain reconciler for attendance, and three translation tables — and every one of those is a place
where a caretaker's check-in silently becomes two check-ins or none. That is precisely the
checklist's stop-the-release red flag: *"a repair whose effect you cannot state in one sentence of
transport-level truth."*

**The cost asymmetry decides it.** There are zero production rows today — `api.housepital.in` does
not resolve and the app is pointed at neither backend. Merging now is a schema exercise; merging
after go-live is a data migration with live patients on both sides. This is the identical argument
the team already accepted for `StoreMigrator` (*"free to fix before the first public release and
effectively impossible afterwards"*, `store_migrator.dart:8-13`) applied one layer down. **Confirm
first whether `housepital_db` already carries real staff data** — that is the one fact that could
change this recommendation, and I cannot determine it from the repos.

**Concretely:**

1. **Keep `housepital_db` (Laravel) as the system of record for the six operational nouns.** It
   holds the evidence-bearing columns — geofence, selfie, `is_late`, SBAR, checklist % — that the
   patient DB cannot represent and that the patient app's value proposition depends on showing.
   Migrating those *into* the patient DB is a bigger change than the reverse.
2. **Add a real `patients` table there**; replace `deployments.patient_name/_age/_gender/…` with
   `patient_id`. Backfill is trivial at zero rows.
3. **Pick one grain for `attendance`** and write it down. `UNIQUE(deployment_id, staff_id, date)`
   satisfies both readings and lets a replacement be a second row rather than a lost fact.
4. **Add `medication_logs`** with `UNIQUE(medication_id, scheduled_time)`,
   `logged_by_type ENUM('staff','family','patient')`, `logged_by_id`, and a client-supplied
   `client_log_id` for idempotent replay. This one table is what makes §0.2 fixable.
5. **Keep BOTH APIs.** Firebase Functions is a legitimate patient edge (phone-OTP auth, FCM,
   Razorpay); Laravel is a legitimate staff/ops edge. Two APIs over one database is boring and
   correct. Two databases claiming the same facts is not.
6. **Reconcile the three enum pairs once**, at merge time, in a migration — not forever, in a
   translator.

**If merge is refused**, the only other defensible shape is **one-way replication with a declared
owner per noun, never bidirectional**: staff DB owns `attendance`/`vitals`/`daily_reports`/
`deployments`/`staff`; patient DB owns `patients`/`bookings`/`payments`/`invoices`/
`family_members`/`medications`. The patient API then *reads* staff-owned nouns through a view or
read replica and never writes them. That eliminates conflict by eliminating the second writer —
which is the only conflict policy this team can currently test, because neither repo contains a
single conflict test.

**Either way, checklist B1 requires the choice be written down per record type with a test per
type.** Neither repo has a line of it. That document is the deliverable, and it should be written
before the app is pointed at either host.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A | BLOCKED-OWNER |
|---|---|---|---|---|---|
| A. Schema & environments | 0 | 2 | 4 | 0 | 0 |
| B. Conflict & concurrency | 0 | 2 | 3 | 1 | 0 |
| C. Offline & the outbox | 0 | 1 | 4 | 1 | 0 |
| D. Sharing lifecycle | 0 | 0 | 6 | 1 | 0 |
| E. Two-phone QA matrix | 0 | 0 | 1 | 0 | 4 |
| F. Recovery & repair | 0 | 0 | 2 | 3 | 0 |
| **Total (35 items)** | **0** | **5** | **20** | **6** | **4** |

Round 2 was ✅1 ⚠️5 ❌19. **The app did not regress — the evidence base grew.** Two items moved:

- **A6** ✅ → ⚠️. The ✅ rested on `assistant_models_test.dart:16-19` and
  `reminders_provider.dart:66`. Now that the two backends' status vocabularies are visible, the six
  clinical status fields have no fallback at all: `models.dart` `Attendance.status` is
  `status: json['status']`, an unchecked cast into a non-nullable `String`.
- **A4** ⚠️ → ❌. The client half (`StoreMigrator`) got *better*. The server half now has
  demonstrable, non-additive drift: two handlers query columns that do not exist
  (`medications.ts:217`, `ratings.ts:37,48`).

**Reclassified, not re-graded:** section D's six ❌ were partly blocked on "the owner must define
an invite/member API." That contract **exists** — `housepital-backend/functions/src/routes/family.ts`
lines 17 (list), 48 (add), 103 (invite), 129 (update), 193 (owner revoke), 230 (self remove).
Sharing is now ordinary unstarted client work, not a blocked dependency. Net BLOCKED-OWNER count
is unchanged only because E1–E4 still need two physical devices.

---

## Findings

### Blockers

1. **The vitals chart fabricates 7–180 days of BP, pulse, SpO2, temperature and blood sugar and
   merges them with the patient's real readings, unlabelled.** `vitals_screen.dart:50-70`,
   `:106-115`, rendered `:121`, re-rolled on every period change at `:195`. No `DemoMode` source
   exists for it. New this round; round 2 fixed the real readings and never looked at what they
   are plotted against.
2. **`loadPatients()`'s new guard clears `AppProvider` only** — `app_provider.dart:156-160`.
   Medications, orders, cart, assistant, reminders, addresses, ratings and the dashboard cache
   survive that switch path, on disk as well as in memory. The test at
   `patient_scope_isolation_test.dart:293-308` asserts one field and certifies the gap. It also
   silently reverts a user's switch-sheet selection to `apiPatients.first`.
3. **Medication doses are logged to nowhere while the UI reports success** —
   `medication_provider.dart:110-127`. Unchanged since round 1. §0.2.
4. **Two systems of record for six clinical nouns, structurally unmergeable by a sync layer** —
   §B. Plus two live code-vs-schema drifts (`medications.ts:217`, `ratings.ts:37,48`).
5. **Every direct-Firestore call is still denied by the deployed rules** —
   `firestore.rules:67,70,90,94,99,133`; the OTP write at `staff_otp_verification_screen.dart:83`
   is designed to fail against `:134`. The repo now contains a file (`storage.rules:18-29`) that
   diagnoses this exact bug for the sibling rules file and did not fix it.

### High

6. **`logout()` is no longer an atomic wipe** — `auth_provider.dart:229-236`. Snapshot-then-remove
   over an unordered `Set` with N yields; a kill mid-loop leaves a nondeterministic partial wipe on
   a shared phone; it also deletes `__quarantine_*`, defeating `store_migrator.dart:146-150`.
7. **`DemoMode` has ten raisers and one lowerer** — `markServingLiveData` is called once
   (`app_provider.dart:273`). Seven sources latch permanently, including
   `sourcePatientIdentity` (`:142`) which a successful load at `:160` does not clear. Three
   declared sources are never raised at all.
8. **The handover PDF still cannot report on the patient** —
   `handover_report_service.dart:107-114` reads `DemoData`, takes no patient argument, consults no
   provider. Honest now (`:105`, `:133`), still non-functional. Generating one latches the demo
   pill for the process lifetime.
9. **`AssistantProvider` is still bound to `DemoData.patient.id`** — `main.dart:234,260`. Transcript
   clearing was fixed; the binding was not.
10. **`updateFromSync()` is the last unguarded patient-assignment path** —
    `app_provider.dart:335-341`. Dormant, but now the only one without a check, which makes it
    more likely to be trusted.
11. **`SessionScope` has no test.** `grep -rn "SessionScope" test/` → one comment.
12. **Family sharing is a `setState` over a static mock** — `family_members_screen.dart:22,51` —
    against a backend contract that already exists (`routes/family.ts`).
13. **`verifyPatientAccess` passes through for un-onboarded users** —
    `housepital-backend/functions/src/middleware/auth.ts:96-107` vs `:44-51`. Cross-patient read
    access by id guessing. Cross-filed to the security audit.
14. **Dead sync surface, unchanged** — `SyncService` (zero importers), three Firestore listeners
    with zero subscribers (`firebase_service.dart:237,255,277`), FCM that navigates and reloads
    nothing (`main.dart:345-377`), 16 unauthenticated `ApiService()` instances in `lib/screens/`.

### Medium / Low

15. Fire-and-forget persists are safe **by accident** — correct only because both providers mutate
    in place and encode after their first `await`. Undocumented, untested, one refactor from
    regressing (§"Ordering, re-examined").
16. `housepital_pending_deletion` is a durable record with **zero readers** and a single slot;
    `deliveredToServer` is never flipped; `reference` is clock-derived.
17. `profile_photo_path` survives a patient **switch** (key and file); the file survives logout too.
18. `CacheService.get()` / `getLastUpdatedText()` still have zero production callers;
    `app_provider.dart:232`'s "with offline caching" describes a read path that does not exist.
19. `VitalReading` still has no `toJson`; the wire body is hand-built at `api_service.dart:246-261`.
    A6/A5 cannot be tested until it exists.
20. Client-minted ids remain clock-derived everywhere — `vitals_screen.dart:707`,
    `orders_provider.dart:33-36`, `reminders_provider.dart:138`,
    `delete_account_screen.dart:80-81`.
21. `patient_log_${medicationId}_$timeSlot` still carries no date —
    `medication_provider.dart:117`. Day 2's 08:00 dose collides with day 1's the moment it is
    persisted or posted.
22. `address_selection_screen.dart:106-110` still writes three default addresses on first **read**
    (checklist B3, "no screen mints a record on appear").
23. `staff_otp_verification_screen.dart:52-55` still mints an OTP in `initState` and writes it
    `merge: true`, clobbering a code the staff member may be mid-way through typing.
24. `return_screen.dart:331` still sends a local device path as `photoUrl`.
25. `submitDailyRating` still has zero callers — and the endpoint it would call is broken
    (`ratings.ts:37,48`).
26. Pull-to-refresh on 5 of 91 screens; no polling anywhere; no user-reachable re-sync.
27. `document_repository_screen.dart:80`, `care_team_screen.dart:31`,
    `care_calendar_screen.dart:1324`, `payment_screen.dart:64` serve fabricated data with no
    `DemoMode` mark.

---

## BLOCKED-OWNER

| # | Item | What is needed |
|---|---|---|
| E1–E4 | Two-phone QA matrix | Two physical devices, two real accounts on one patient, current + n-1 builds, a reachable host, a locked-device attachment test. Cannot be simulated. **Blocked twice over:** the backend's `family_members.user_id UNIQUE` means two accounts cannot currently watch one patient. |
| §B | **Merge vs. replicate** | An owner decision, and one fact I cannot determine: **does `housepital_db` already hold real staff data in production?** If no → merge (recommended). If yes → one-way replication with a declared owner per noun. Either way the conflict policy must be written per record type. |
| §B | Patient-switch data model | Server says one user → one patient (`family_members.user_id UNIQUE`, `auth.ts:38`). Client says one user → many. Decide which is true before either side is built further. |
| §0.2 | Medication dose logging | The schema change in §B item 4, plus the clinical decision: when the family app and the staff app both log the same slot, is that one dose (dedupe on `medication_id + scheduled_time`) or two (a double-dose to warn about)? |
| BLOCKER 1 | Vitals mock data | Does the demo need a populated chart at all? If yes, the synthesised series must be visually and statistically separated from entered readings, not merged. If no, delete `_generateMockData` and ship the empty state. |
| §Deletion | Pending-deletion lifecycle | Confirm the intended replay: which endpoint, what ack, and what the user sees while it is pending. Today nothing reads the record. |
| A1 | Environment split | `constants.dart:3` is a plain `const` while two real hosts exist. Needs a staging host per environment and `String.fromEnvironment('API_BASE_URL', …)` — the pattern is already used correctly for `assistantApiUrl` at `:10-11`. |
| A2 | Rules deploy gate | CI credential with `firebaserules.releases.get`, plus confirmation of whether `firestore.rules` and `storage.rules` are deployed. Both are currently unknown. |

---

## Red flags (checklist "stop the release" list)

| Red flag | Present? | Evidence |
|---|---|---|
| Any error path that logs and returns | **Yes, pervasively** | `app_provider.dart:163-166,276-280`; `session_scope.dart:96-99`; `medication_provider.dart:321`; `orders_provider.dart:169-172`; `cart_provider.dart:230`; `reminders_provider.dart:200` |
| "It worked on my phone" as sync evidence | **Yes** | Zero multi-device or offline-reconciliation tests; `SessionScope` itself has none; every success affordance fires from local state |
| A schema change merged without a written deploy step | **Yes — and now provably shipped broken** | `medications.ts:217` and `ratings.ts:37,48` query columns that do not exist in `001_initial_schema.sql`; no migrations directory on the patient side; `storage.rules` + `firestore.rules` both undeployed |
| A share/leave/revoke flow tested on one device only | **Worse** | Not tested on any device — `setState` over `static final _mockMembers`, against a backend contract that already exists |
| A repair button whose effect you cannot state in one sentence | **No** | Still vacuously clean: there is no repair button |

---

## Verdict — executive summary

**FAIL.** 20 ❌ · 5 ⚠️ · 0 ✅ · 6 N/A · 4 BLOCKED-OWNER, of 35.

1. **This round's repairs are the first that mostly survive adversarial reading.** Eight of round
   2's thirteen findings are genuinely closed — `_vitalsHistory`, the cart's re-persist, orders on
   disk, four unscoped stores, the banner on pushed routes, `_currentUserRole`, the unawaited
   `clearSession`, and `StoreMigrator`'s detection heuristic. **Nothing regressed.**
2. **`SessionScope` now reaches every provider field and every SharedPreferences key that holds
   patient data.** I enumerated the stores independently and the diff is empty. Credit where due.
3. **But the same mistake repeated one level up.** `loadPatients()` got the narrow clear instead of
   the cross-provider one, and the test written to stop that pattern asserts one field — the exact
   "written from the implementation" failure round 2 named.
4. **One round-2 repair is itself a surface:** `DemoMode`-as-a-set. Ten raisers, one lowerer. It
   swapped a false all-clear for a permanent false alarm, which its own doc comment names as the
   other bug it was fixing.
5. **One repair made a failure mode worse:** `logout()`'s snapshot-then-remove loop is
   non-atomic, kill-vulnerable, and destroys quarantined data. `prefs.clear()` bracketed by two
   reads/writes is strictly safer and shorter.
6. **The handover PDF became honest without becoming correct** — it carries a SAMPLE DATA band and
   still cannot report on the patient.
7. **New blocker round 2 missed:** the vitals chart generates 180 days of RNG clinical readings,
   merges them with the patient's own, and raises no demo flag.
8. **The dose-log-to-nowhere defect is unchanged, and round 3 can now say why it is not a client
   bug:** the backend's `medication_logs` table has no `patient_id`, no `logged_by`, and no unique
   key on `(medication_id, scheduled_time)`; the staff DB has no medication table at all.
9. **Top five remaining:** (1) the fabricated vitals chart; (2) `loadPatients()`'s partial wipe and
   the test that certifies it; (3) the dose log; (4) two systems of record — **merge, don't sync**,
   while there are still zero production rows; (5) the Firestore rules that deny everything, next
   to a file that explains why.
10. **The app remains a demo-mode client with local convenience storage.** The local-privacy work is
    now genuinely close to done. The sync work has not started, and the decision that gates it — one
    database or two — should be made this week, because it is a schema exercise today and a
    migration with live patients later.
