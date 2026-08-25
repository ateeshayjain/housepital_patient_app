# Security & Privacy Checklist (App-Agnostic) — Audit round 3 vs commit `9a80fe2`

**Date:** 2026-08-05 · **Round 2:** `820060b` · **Round 1:** `803124d` · **Branch:** `fix/five-tab-nav`
**Scope:** Flutter/Dart client (`lib/`, `ios/`, `android/`), Cloud Function (`functions/`), Firestore +
Storage rules, full git history (all refs), `test/` sources.
**Method:** read-only. Every verdict cites `path:LINE` or a command with its output. No source file was
modified. `flutter test` / `build` / `clean` were **not** run, per the brief.

> **Path corrections carried into this report.** Round 2 cited three files at paths that do not exist
> at `9a80fe2`. The files were not moved by the round-2 diff — round 2 cited them wrong. Correct paths:
> `lib/screens/services/cards/staff_role_card.dart` (not `lib/widgets/`),
> `lib/screens/my_care/widgets/health_manager_banner.dart` (not `lib/widgets/`),
> `lib/screens/services/my_orders_screen.dart` (not `lib/screens/orders/`).
> All three findings survive; only the citations were wrong.

---

## Round-2 findings: status now

| Finding | R2 grade | Now | Evidence |
|---|---|---|---|
| **B-1** `storage.rules` unsatisfiable — would deny 100% of uploads | ⚠️ worse-shaped | ✅ **BLOCKER CLOSED** / ⚠️ residual: rules are now satisfiable and strictly tighter than the default, but **provide no per-patient isolation and say so** | `storage.rules:64-93`; header `:14-59` |
| **B-2** Assistant function unauthenticated + wildcard CORS | ❌ | ❌ **UNCHANGED** | `functions/index.js:112-119` — still `onRequest` + `cors: true`, no `verifyIdToken`, no App Check, no limiter; `assistant_service.dart:53` sends only `Content-Type` |
| **B-3** PHI in release logs | ❌ | ❌ **UNCHANGED** | `logger.dart:55-57` strips only debug/info; `:59` still interpolates `$error`; `:60-61` prints stacks in release; `grep -rn "redact" lib/` → 0 |
| **B-4** Sensitive exports not role-gated **in code** | ❌ | ❌ **UNCHANGED** | `handover_report_service.dart:323` still `shareHandover({DateTime? now})`; `invoice_pdf_service.dart:261` still zero `canUserPerform`; `document_repository_screen.dart` still zero; `main.dart:564-566` `/documents` still unguarded |
| **B-5** Deletion claims an erasure nothing performs | ⚠️ | ✅ **SUBSTANTIALLY FIXED** / ⚠️ one residual overclaim | `delete_account_screen.dart:78-93,126-138,148-168`; copy verified in `assets/i18n/en.json` — see **R3-1** |
| **B-6** `ios/Runner/PrivacyInfo.xcprivacy` missing | ❌ | ❌ **UNCHANGED** | `ls` → No such file or directory |
| **H-3** `SessionScope` is a partial wipe reading as complete | ⚠️ | ⚠️ **MAJOR PROGRESS, STILL PARTIAL** — 6 of 9 named stores closed, 3 open, **9 new stores found** | full audit below |
| **H-4** Handover PDF is all `DemoData` with no marking | ❌ | ✅ **FIXED** | `handover_report_service.dart:127-141` — red band in the `pw.MultiPage` `header:` callback (`:124`), so **every page**, unconditional |
| **M-13** Deletion screen hardcoded English | ❌ | ✅ **FIXED** | `grep -c delete_account assets/i18n/en.json` → 27; `hi.json` → 27 |
| **M-1** Firebase config tracked; 3 `AIza…` in history | ⚠️ | ⚠️ **RE-CONFIRMED** | commands below |
| `ANTHROPIC_API_KEY` server-side only | ✅ | ✅ **RE-CONFIRMED CLEAN** on every ref | 4 commands, all empty — below |
| **L-3** `StoreMigrator.quarantine` retention | ❌ latent | ❌ **UNCHANGED in substance, new angle** — now a tested public API, and **not covered by the patient-switch wipe** | `store_migrator.dart:151-169`; `test/services/store_migrator_test.dart:131-171` |
| **L-6** `{allPaths=**} if false` is a no-op | — | ⚠️ **UNCHANGED** (harmless; comment still overstates) | `storage.rules:88-93` |
| **H-8** `staffId` passed as `patientId` | ❌ | ❌ **UNCHANGED** | `lib/screens/my_care/widgets/health_manager_banner.dart:82-86` |
| **M-4** No rules test anywhere | ❌ | ❌ **UNCHANGED** | `grep -rln "storage.rules\|firestore.rules" test/` → 0 across 60 test files |
| — | — | 🆕 **R3-2: scheduled OS medication reminders are never cancelled on switch or logout** — patient A's drug name and dose fire on the lock screen under patient B | `medication_reminder_service.dart:248,256`; `medication_provider.dart:203`; no caller in `session_scope.dart` or `auth_provider.dart:217-242` |
| — | — | 🆕 **R3-3: cross-patient WRITE is open under the new storage rules** — evidence injection into another patient's concern record, and the record is immutable so it cannot be removed client-side | `storage.rules:82-86` |
| — | — | 🆕 **R3-4: `clearSession` resets the role to the MOST privileged value** | `app_provider.dart:217` `_currentUserRole = 'PRIMARY_CONTACT';` |
| — | — | 🆕 **R3-5: `housepital_pending_deletion` is a write-only key** — nothing in `lib/` ever reads it, so the "replay when a backend arrives" purpose has no implementation | `grep -rn housepital_pending_deletion lib/` → 3 hits: one constant, one write, one preserve-list entry |

---

## Round-2 repairs: adversarial review

Three of the four headline repairs are genuine. One is genuine but leaves a smaller version of the same
defect. None of them is a *surface* in round 2's sense — this is the first round where that sentence
can be written.

### 1. `storage.rules` — REVIEWED AS AN ATTACKER

**What it actually does.** `storage.rules:61-95`. Two `match` blocks — `chat/{patientId}/{fileName}`
(`:74-79`) and `concerns/{batch}/{fileName}` (`:82-86`) — each granting `read` to any signed-in
caller, `create` to any signed-in caller uploading a declared image under 10 MB (`:68-71`), and
`update, delete: if false`. Everything else denies (`:91-93`).

**Is it satisfiable by this app?** Yes — the B-1 blocker is genuinely gone.
`isSignedIn()` is true for any OTP-authenticated user, and both upload call sites match a rule:
`chat_screen.dart:135` writes `chat/${widget.patientId}/${ts}_$filename`,
`raise_concern_screen.dart:330` writes `concerns/${patientId}_$batchTs/${i}_$filename`. Neither
depends on a uid — and `grep -rn "\.uid" lib/` still returns **zero hits**, which the file's own
header states at `:20`. Size is comfortably inside 10 MB: every uploading picker downscales
(`chat_screen.dart:123-124` `maxWidth: 1024, imageQuality: 75`;
`raise_concern_screen.dart:98-99` `imageQuality: 80, maxWidth: 1200`).

**Can one authenticated patient read another's chat photo by guessing the path? — Direct answer.**

*By guessing: no, not in practice.* `allow read: if isSignedIn()` places **no ownership condition at
all**, so authorization is not what stops the attack — path entropy is. The attacker needs the exact
full object key: `patientId` + the exact `millisecondsSinceEpoch` + the original file basename
(`chat_screen.dart:132` `p.basename(picked.path)`). The timestamp alone is ~3×10¹⁰ values over a
one-year window, and the basename is unbounded. That is not brute-forceable.

*By enumerating: the rules appear to block it, but this is untested and should be confirmed.* A
`listAll()` on prefix `chat/{patientId}` is a **two**-segment path; `match /chat/{patientId}/{fileName}`
requires three, so the only rule that matches the prefix is `{allPaths=**}` (`:91-93`, deny). On that
reading, enumeration fails and the entropy argument holds. **But there is not a single rules test in
this repo** (`grep -rln "storage.rules\|firestore.rules" test/` → 0 of 60 files), so this is analysis,
not evidence. Confirm it in the emulator before relying on it — it is the load-bearing assumption of
the whole "read is safe in practice" argument.

*By the route that actually leaks: yes, and the rules are irrelevant to it.* `firebase_service.dart:138`
returns `getDownloadURL()`, and `chat_screen.dart:151-153` persists that URL into the message record.
A Firebase download URL carries a permanent bearer token and **bypasses Security Rules entirely** —
anyone holding the string fetches the object, signed in or not, forever, no matter what this file
says. So the confidentiality of every uploaded medical photo rests on the confidentiality of a URL
that is copied into a chat document, will appear in support tickets and screenshots, and is not
revocable without deleting the object. The file's mitigation advice at `:45-46` — *"do not put
anything in the FILENAME that is not already inside the file"* — addresses the wrong half of the
problem, and is not followed anyway: `chat_screen.dart:132` preserves the user's original basename,
so `mother_biopsy_report.jpg` goes into the path verbatim.

**What it does NOT protect against — the plain list.**

1. **Cross-patient read of a known object path.** No ownership check exists. Any OTP-authenticated
   account reads any object under `chat/*/*` or `concerns/*/*` given the key.
2. **Cross-patient WRITE — new, and worse than the read.** Any authenticated user can `create`
   `chat/{anyPatientId}/{anything}` and `concerns/{anything}/{anything}`. Staff-side tooling reads
   these folders through the Admin SDK, which bypasses rules — so an outsider can plant fabricated
   photographs inside another patient's complaint evidence batch, and because `update, delete: if false`
   (`:85`), **neither the victim nor anyone else can remove it from the client**. This is an integrity
   attack on a record Housepital's own SLA acts on, and the immutability clause — written to protect
   the record — is what makes the injected object permanent.
3. **Cost / storage DoS.** No per-user quota, no path scoping. Unlimited 10 MB objects per
   authenticated account, billed to the owner.
4. **The type check is advisory, not real.** `request.resource.contentType.matches('image/.*')`
   (`:70`) validates a **client-asserted** header. `chat_screen.dart:136` and
   `raise_concern_screen.dart:331` both hardcode `contentType: 'image/jpeg'` regardless of the actual
   bytes. Any payload can be uploaded as an "image" — and the app's own PNG/HEIC uploads are
   mislabelled. The 10 MB size cap is real; "images only" is not.
5. **The `{allPaths=**} if false` block still does nothing it claims.** `:88-90` says any new path
   "must be added above… never left to fall through". Rules union their `allow`s; a `false` in one
   `match` never revokes an `allow` in another, and unmatched paths already default to deny. Harmless,
   but a reader will trust it to do work it does not do. (It *is* the rule that denies prefix listing —
   which the comment does not claim, and which default-deny would do identically.)

**Is shipping it better or worse than shipping nothing? — Better, decisively.**
"Nothing" means the current live posture, which is **unknown** (BLOCKED-OWNER #1) and most plausibly
the Firebase console default template, `allow read, write: if request.auth != null` on
`/{allPaths=**}`. Against that baseline this file is strictly tighter on every axis: two path prefixes
instead of the whole bucket, a 10 MB cap, a content-type label check, immutability, and deny
everywhere else. It removes nothing and breaks nothing. Critically, it also cannot trigger the
rollback spiral the previous draft would have — that draft's total outage would have been "fixed" in
production by pasting back `if request.auth != null`, landing exactly on the permissive default.

**Recommendation: DEPLOY IT AS-IS**, with three conditions.
1. **Fix the doc wording first.** `CLAUDE.md` describes it as *"default-deny + per-patient chat/concern
   photo paths"*. The paths are per-patient; the **rules are not**. The next engineer will read that
   line as "Storage isolation is done" and stop looking. The rules file's own header (`:14-46`) is
   unusually honest about this; the surrounding documentation is not. This mismatch is the single
   biggest risk of deploying.
2. **Add a bucket-level guard for §2 and §3 above** — object lifecycle rules and/or a Cloud Monitoring
   alert on upload volume — because "any authenticated user may write anywhere in these two prefixes"
   is not a posture that should sit unmetered.
3. **Do not treat this as closing the isolation blocker.** It is deliberately not that, and it must not
   be recorded as that.

**Firestore, by contrast, still has the round-2 defect.** `grep -rn "request.auth.uid" firestore.rules`
→ **12 hits** (`:67,70,72,73,90,94,99,110,114,118,133,144`) against an app that reads no uid. Chat,
attendance, vitals and `active_sessions` are still keyed on a predicate that is always false. The
Storage file was repaired to match reality; the Firestore file was not, and now the two rule sets in
the same repo encode two different, contradictory beliefs about what an identifier is.

### 2. `SessionScope` completion claim — VERIFIED STORE BY STORE

The claim is **substantially true and materially better than round 2**, but it is not complete, and
the docstring at `session_scope.dart:36` (*"enumerate stores, not symptoms"*) is the right rule
applied to an incomplete enumeration.

**Round 2's six named stores + the two extras:**

| # | Store | Verdict | Evidence |
|---|---|---|---|
| 1 | `AppProvider._vitalsHistory` | ✅ **FIXED** | `app_provider.dart:201` `_vitalsHistory.clear(); // manually entered readings — PHI`; asserted `patient_scope_isolation_test.dart:115-119` |
| 2 | `AppProvider._profilePhotoPath` | ⚠️ **HALF-FIXED** | `app_provider.dart:216` nulls it — but **only in `clearSession`**, not in `clearPatientScopedData` (`:196-207`). A **patient switch** keeps it, in memory *and* on disk (`profile_photo_path`, written `:107`, is not in `_patientScopedPrefsKeys` at `session_scope.dart:46-48`). It is set from `patient_profile_screen.dart:209` — the **patient's** profile — so it is patient-scoped, and the class's "device- and account-scoped state survives" rationale (`:194-195`) misclassifies it |
| 3 | `AppProvider._currentUserRole` | ✅ **FIXED**, ⚠️ **but resets fail-OPEN** | `app_provider.dart:217` `_currentUserRole = 'PRIMARY_CONTACT';` — the **most** privileged role, not the least. Since role is a client-side string with no server claim (§6), the logout teardown hands the next person maximum permissions by default. `'PATIENT_SELF'` or an explicit unset would be the safe reset |
| 4 | `RemindersProvider` | ✅ **FIXED** | `session_scope.dart:67` (awaited); `reminders_provider.dart:194-204` clears `_items` **and** `prefs.remove(storageKey)` |
| 5a | `AssistantProvider._messages` | ✅ **FIXED** | `session_scope.dart:60`; `assistant_provider.dart:184-189` |
| 5b | `AssistantProvider._patientId` / `_role` final binding | ❌ **UNCHANGED — the sharpest surviving item** | `assistant_provider.dart:21-22` still `final`; `main.dart:234` `final patientId = DemoData.patient.id;`, `:236` `const role = UserRole.primaryContact;`, passed to the executor (`:258`) *and* the provider (`:270`), plus `deploymentId: DemoData.icuDeployment.id` (`:260`). `clearPatientScopedData` clears the transcript but **cannot** rebind the id. The executor then calls `api.getBillingSummary(patientId)` (`assistant_executor.dart:434`) and `api.getAttendanceHistory(patientId)` (`:453`) against the frozen demo patient, and `performConfirmed` (`:325-360`) submits concerns / bookings / staff replacements under it. This is a cross-patient **action** path that survives every wipe by construction |
| 6 | `CacheService` | ✅ **FIXED** | `session_scope.dart:84` `await CacheService.instance.clear();` — the round-2 zero-caller gap is closed |
| 7 | `OrdersProvider` disk copy | ✅ **FIXED** | `orders_provider.dart:212-219` — `_persistAndNotify()` with the reason written into the code |
| 8 | `ApiService._authToken` | ❌ **UNCHANGED** | `api_service.dart:16` `String? _authToken;`; `i_api_service.dart:12` declares only `setAuthToken(String)`. `auth_provider.dart:217-242` never nulls it. A valid bearer token for the previous patient survives in the process for up to 60 min |
| 9 | `settings_screen` un-awaited logout | ✅ **FIXED** | `settings_screen.dart:453-462` — `nav`/`auth` captured before the async gap, both calls awaited, `nav.pop()` last |

**Nine further stores found in round 3, all outside `SessionScope`.** Ordered by severity.

- **R3-2 · Scheduled OS medication notifications are never cancelled.** `medication_reminder_service.dart:248`
  `cancelAllReminders()` → `_plugin.cancelAll()`. Its **only** caller is `:256`, inside `rescheduleAll`,
  itself called only from `medication_provider.dart:203`. Neither `session_scope.dart` nor
  `auth_provider.dart:217-242` calls either. `MedicationProvider.clearPatientScopedData` (`:391-400`)
  clears in-memory lists only, and the service is a singleton, so the OS-level schedule outlives every
  provider reset. **Consequence:** patient A's "Insulin 10 units — 8:00 PM" fires on the lock screen
  after a switch *or a full logout*, to whoever is holding the phone, with no authentication in front of
  it. This is the most severe store still outside the wipe — it is PHI leaving the app's surface
  entirely. **Fix:** `await MedicationReminderService().cancelAllReminders();` inside
  `SessionScope.clearPatientData`.
- **R3-6 · FCM registration is never revoked.** `auth_provider.dart:200-203` registers the device token;
  `grep -rn "deleteToken" lib/` → **zero**. After logout the backend still pushes patient A's
  vitals-red and staff-check-in notifications to this handset.
- **R3-7 · `__quarantine_*` keys are outside the switch wipe.** `store_migrator.dart:155`. Round 2 noted
  `prefs.clear()` at logout swept them; that still holds because `auth_provider.dart:231-234` uses a
  two-key **allowlist** (a good rewrite — it stays correct as keys are added). But
  `SessionScope.clearPatientData` — the **patient switch** path — clears only
  `housepital_cache_*`, `housepital_saved_addresses` and `daily_rating_*`. A
  `__quarantine_v1_housepital_orders` blob would survive every switch indefinitely.
- **R3-8 · Screen-local State survives the switch.** `main_shell.dart:63`
  `IndexedStack(index: _currentIndex, children: _screens)` with `_screens` built once at `:38-44` — all
  five tabs stay mounted and nothing keys or disposes them. So `settings_screen.dart:25` `String? _profilePhotoPath`
  (loaded in `initState`) and `my_care_screen.dart:585` `int? _ratedToday` keep rendering the outgoing
  patient's values after `SessionScope` has deleted the underlying prefs keys. The wipe is correct; the
  view is stale.
- **R3-9 · Notification preference keys are an open-ended, unenumerated store.**
  `app_provider.dart:128-131` `setNotificationPreference(String key, bool value)` writes an
  arbitrary caller-supplied key; the current set is declared in
  `notification_preferences_screen.dart:41-92` (`notif_vitals_red`, `notif_payment_reminder`, …).
  These encode one patient's care preferences and survive a switch. Low PHI value, but the key set is
  not statically closed, so the file's own "enumerate stores" contract cannot be satisfied by
  inspection.
- **R3-10 · `SyncService` is orphaned but has no wipe hook.** `sync_service.dart:96` captures `patientId`
  in a `Timer.periodic` closure; `stopPeriodicSync` (`:110`) has zero external callers and the class is
  never instantiated. Not a live leak — but if it is ever wired, `updateFromSync`
  (`app_provider.dart:323-348`) will repopulate patient A's data seconds after the wipe, and
  `SessionScope` has nowhere to stop it.
- **R3-11 · `DemoMode._activeSources` is never reset.** `demo_mode.dart:36`; `reset()` at `:58` is
  `@visibleForTesting`. Stale sample-data flags carry across a switch. Not PHI, but it means the honesty
  banner's state is not patient-scoped either.
- **R3-12 · No file on disk is ever deleted.** `grep -rn "\.delete()" lib/` returns exactly **one** hit:
  `delete_account_screen.dart:131` `await user.delete()` — the Firebase credential. The image files
  `image_picker` copies into the app sandbox (profile photos, concern evidence, chat photos) are never
  removed by any path, including account deletion.
- **R3-13 · `blog_provider.dart`** has no `clearPatientScopedData` and is not in `SessionScope`. Content
  is public care-education material, so this is **not** a leak — noted only for completeness of the
  enumeration.

**Test quality.** The round-2 criticism is answered honestly. `patient_scope_isolation_test.dart` now
carries a `group('stores the first fix missed')` (`:224`) with four targeted tests — vitals (`:225`),
cart saved items *and their persistence* (`:242`), orders reaching disk (`:263`), reminders on memory
and disk (`:278`) — plus `:293` for the `loadPatients` switch path. The `switchPatient` test (`:121`)
even documents what it *cannot* assert (`:133-141`), which is exactly the right instinct.
**But the test at `:94` is still named `'clearPatientScopedData nulls every per-patient field'` and
still does not assert `profilePhotoPath`** (`grep -n "profilePhoto\|currentUserRole"` on the file →
zero hits) — the one field that genuinely survives that call. The name still certifies completeness
the assertions do not check. It is a much smaller version of the same defect round 2 named.

### 3. Deletion flow and the durable record — DIRECT ANSWERS

The repair is real. `_recordDeletionRequest` (`:78-93`) writes before anything else can fail
(`:101-104`); `user.delete()` (`:126-133`) actually removes the credential rather than merely signing
out; `SessionScope.clearSession` then `AuthProvider.logout()` (`:143-145`) wipe local data; and the
final dialog (`:148-168`) states DONE and REQUESTED as separate lines. The copy verified in
`assets/i18n/en.json` is honest — `delete_account_done_server` reads *"Requested — not yet done: your
records held by Housepital still need to be deleted by our team."* That is the truth. Round 2's B-5
is genuinely closed. Fully localized: 27 `delete_account*` keys in **both** `en.json` and `hi.json`.

**Q: Is retaining a patient identifier after an erasure request a DPDP problem in itself?**

**No — not in itself.** Three reasons, in order of weight:

1. **It is a record *of* the request, not a copy of the data to be erased.** DPDP §12 gives an
   enforceable right to erasure and §13 attaches a grievance mechanism to it. Neither is operable
   without knowing *whose* data. A Data Fiduciary that could not identify the subject of an erasure
   request could not honour it. Retaining `{reference, requestedAt, patientId, deliveredToServer}`
   (`:85-90`) is the minimum viable form of that record.
2. **It is held on the data principal's own device, in their own app sandbox** — not in the
   Fiduciary's systems, not transmitted, not aggregated. That does not put it outside DPDP (the app is
   the Fiduciary's software), but it materially changes the proportionality analysis.
3. **Minimisation is satisfied.** No name, no phone, no clinical content. The stored `patientId` is a
   backend domain id (`app_provider.dart` → `pat_demo_rajesh` shape), not a government or contact
   identifier.

**Two things about it are wrong, and neither is the retention itself:**

- **The comment is inaccurate in a way that will propagate.** `:56-59` says the record *"Holds no PHI —
  a timestamp, the patient id, and a locally generated reference."* A patient identifier **is**
  personal data under DPDP §2(t) (data about an individual identifiable *in relation to* it). The
  distinction the comment is reaching for is "no clinical content", which is true and materially
  different. As written it is the kind of sentence that gets lifted into a privacy notice.
- **R3-5 · There is no retention limit and no reader.** `grep -rn housepital_pending_deletion lib/`
  returns exactly three hits: the constant (`delete_account_screen.dart:60`), the write (`:84`), and
  the preserve-list entry (`auth_provider.dart:233`). **Nothing ever reads it.** The stated purpose —
  *"what a future backend replays"* (`:58-59`) — has no implementation, no expiry, no
  `deliveredToServer: true` transition, and no UI that mentions the record exists. So a patient
  identifier is written once and kept for the life of the install, in service of a replay path that
  does not exist. That is a §11 retention-limitation finding (indefinite retention with no stated
  end), not a §12 one. **Fix, cheap:** stamp an expiry and drop the record after it, and surface the
  pending request in Settings so the user can see the reference they were given.

**Q: Is preserving it through logout correct?**

**Yes — it is load-bearing, not optional.** The deletion flow *ends* in `logout()` (`:145`). If
`logout()` cleared the key, the record would exist for milliseconds and the whole repair would be
theatre. `auth_provider.dart:231-238` replacing `prefs.clear()` with a two-key allowlist loop is the
right shape: it is an allowlist, so it stays correct as new keys appear, and the comment at `:223-230`
explains both preserved keys accurately.

**One uncomfortable case the design does not handle.** The key is preserved on **every** logout, not
only the deletion one. On a shared family phone — which `session_scope.dart:20-22` names as the core
use case — person B's routine logout preserves person A's `patientId` and deletion reference, and
person B inherits both. Worse, by that point `user.delete()` has removed the credential, so there is
no authenticated identity left that could be used to scope the record to its owner. Practical fix:
keep preserving it, but clear it once `deliveredToServer` flips true, and expire it regardless after a
stated window.

**One residual honesty overclaim (R3-1).** `delete_account_done_device` states *"Done: everything
stored on this phone has been erased."* Three concrete counterexamples at `9a80fe2`:
1. `housepital_pending_deletion` itself remains, containing the patient id — the screen's own doing.
2. Scheduled OS medication notifications remain (**R3-2**), carrying drug names and doses.
3. Every image file `image_picker` copied into the sandbox remains — `grep -rn "\.delete()" lib/`
   finds no file deletion anywhere (**R3-12**).
This is a far smaller version of round 2's B-5 and it is in the same species: a categorical user-facing
claim slightly ahead of the code. **Fix:** *"Done: your Housepital data on this phone has been erased."*
plus a line naming the retained request record — and cancel the notifications, which is a one-line change.

### 4. `StoreMigrator` quarantine — retention question re-assessed

**Status: still latent, still worth fixing, and the retention answer has not improved.**

- **Production call sites: still zero.** `grep -rn quarantine lib/ test/` → the definition
  (`store_migrator.dart:151-169`), two docstring mentions, and **eleven hits in
  `test/services/store_migrator_test.dart:131-171`**. So the brief is right: it is now a *tested,
  exercised, public* API (`abstract final class` with a `static` method) rather than dead code. Nothing
  in `lib/` calls it, `_migrations` is still empty (`:50-51`) and `currentVersion` is still `1` (`:33`),
  so `_migrateFrom` never executes a step.
- **The retention properties are unchanged.** `:155` `'__quarantine_v${version}_$key'` — still no
  creation timestamp, no TTL, no reaper, no total-size cap, no UI disclosure. The contract at `:19-21`
  makes the indefinite retention deliberate: *"A migration NEVER deletes data it cannot parse."*
- **What changed for the worse:** round 2's mitigation was `prefs.clear()` at logout. That still holds
  under the allowlist rewrite (`auth_provider.dart:231-238` — quarantine keys are not preserved). But
  round 2 only considered logout. **The patient-switch path does not clear them** (`session_scope.dart:81-100`
  covers only `housepital_cache_*`, `housepital_saved_addresses`, `daily_rating_*`). On a shared
  family phone that switches patients and stays signed in — the normal state — a quarantined
  `housepital_orders` blob from patient A persists under patient B indefinitely.
- **What changed for the better:** the surrounding file is materially more correct. `run()` is
  throw-safe (`:56-67`) with a good reason written down (`:57-60`); a failed step no longer advances
  the stamp (`:113-125`); the `while (1 < 1)` unstamped path is closed (`:130-134`); and `_v1Keys` is
  replaced by `prefs.getKeys()` (`:37-43,139-144`) with an honest note about why the curated list was
  wrong. This is good work.
- **Verdict: ❌ unchanged on the checklist item, and the fix is still nearly free.** Stamp each entry
  with a creation time, reap entries older than a stated window at the top of `run()`, cap total
  quarantined bytes, add the `__quarantine_` prefix to `SessionScope`'s sweep, and name the window in
  the privacy policy. Doing this before the first migration ships costs an hour; doing it after v2 data
  is on real phones is the exact trap the file exists to avoid.

### 5. Demo-notice overlay — occlusion vs displacement

Out of scope for a security checklist except on one axis: the pill is the **only** in-app signal that
displayed clinical values are fabricated, so anything that hides it is a safety issue and anything it
hides is a usability cost. On the merits, the overlay is the right trade. `demo_data_banner.dart:44-49`
positions it at `MediaQuery.padding.top + kToolbarHeight + 4` in a `Stack`, so it displaces nothing and
`:24-27`'s invariant holds — adding or removing it cannot change any screen's layout, which is
precisely the property whose absence made both earlier shapes regress. It now covers pushed clinical
routes (`/vitals`, `/medication-schedule`) that the `MainShell` version structurally missed (`:14-17`),
and it is non-dismissible with a VoiceOver announcement on appearance (`:57-59,74-81`) — both correct
for a warning of this kind. **The occlusion it causes is bounded to the pill's own footprint** (a
centred `Positioned` child; only the pill paints and only the pill absorbs taps). Trading a permanent
quarter-screen of dead space on *every* screen for a small, temporary overlap on the *few* screens
whose content starts flush under the app bar is the right direction. Worth fixing eventually by giving
those screens `+pill height` of scroll padding *when serving demo data only*, which keeps the
zero-layout-impact invariant in the normal case.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A / Blocked | Δ vs round 2 |
|---|---|---|---|---|---|
| 1. Data inventory & minimization | 1 | 2 | 1 | 0 | — |
| 2. Storage & encryption | 1 | 1 | 3 | 0 | — |
| 3. Data in transit | 2 | 2 | 0 | 0 | — |
| 4. Secrets management | 1 | 4 | 1 | 0 | — |
| 5. Permissions & access requests | 1 | 1 | 2 | 0 | — |
| 6. Authentication & access control | 1 | 1 | 3 | 1 N/A | — |
| 7. Third-party SDKs & dependencies | 0 | 2 | 1 | 0 | — |
| 8. AI / LLM privacy | 1 | 2 | 2 | 0 | — |
| 9. Privacy policy & store disclosure | 0 | 1 | 2 | 1 blocked | **−1 blocked / +1 ❌** (regrade, below) |
| 10. Regulatory | 0 | 4 | 0 | 0 | — |
| 11. Deletion & retention | 0 | 1 | 3 | 0 | — |
| 12. Hardening & incident readiness | 0 | 2 | 2 | 0 | — |
| **TOTAL (53 items)** | **8** | **23** | **20** | **1 N/A + 1 blocked** | ✅ 8→8 · ⚠️ 23→23 · ❌ 19→20 |

**Read this scorecard with care — it is misleading, and the reason matters.** Round 3 fixed four real
things (B-1's blocker, B-5's honesty, H-4's unmarked PDF, M-13's localization) and closed six of nine
`SessionScope` gaps. **None of it moves a checklist line**, because each was a sub-item of a line that
was already ⚠️ or ❌ for other reasons that persist. The checklist granularity is too coarse to register
this round's work. The one movement — §9 store-disclosure from BLOCKED to ❌ — is a bookkeeping
correction, not a regression: `ios/Runner/PrivacyInfo.xcprivacy` is independently verifiable from the
repo and is absent, so it does not need owner access to grade.

**Nothing in the round-3 diff introduced a new code-level vulnerability.** The three chrome commits
(`d439928`, `6d4abcb`, `9a80fe2`) are visual and touch no data path.

---

## Task-1 result: SECRET SCAN — re-run verbatim on `9a80fe2`

### `ANTHROPIC_API_KEY` — ✅ **RE-CONFIRMED CLEAN, third consecutive round.** Server-side only.

```
$ git log --oneline --all -S "ANTHROPIC" -- lib/ ios/
(NO OUTPUT — the string has never existed in lib/ or ios/ on any ref)

$ git log -p --all | grep -oE "sk-ant-[A-Za-z0-9_-]{20,}" | sort -u
(NO OUTPUT)

$ git log -p --all | grep -oE "(AKIA[0-9A-Z]{16}|sk_live_[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)" | sort -u
(NO OUTPUT — no AWS, Stripe, GitHub, Slack, or private-key material on any ref)
```

The key exists only as `defineSecret` (`functions/index.js:21`), attached at `:114`, resolved at
`:153`. It cannot ship in the binary. **This finding is now settled; it does not need a fourth pass.**

### Firebase client config — ⚠️ **RE-CONFIRMED TRACKED.** Doc claim still correct.

```
$ git ls-files | grep -iE "GoogleService|google-services|firebase_options"
android/app/google-services.json          ← STILL TRACKED
lib/config/firebase_options.dart          ← STILL TRACKED

$ git log -p --all | grep -oE "AIza[A-Za-z0-9_-]{35}" | sort -u | wc -l
       3      ← unchanged: web / android / ios
```

The iOS plist remains correctly untracked. `CLAUDE.md` still describes this accurately. Severity stays
**Medium**: these are public-by-design client identifiers whose safety rests on (a) Security Rules and
(b) console key restrictions. **(a) improved this round for Storage** — from "worse than absent" to
"authenticated-only, tight, honest" — and is **unchanged and still broken for Firestore**. (b) remains
BLOCKED-OWNER.

---

## Findings

### 1. Data inventory & minimization — ✅1 ⚠️2 ❌1

- ❌ **Personal data inventory.** Still none. `docs/DATA_INVENTORY.md` does not exist; no
  `SECURITY_REVIEW.md` anywhere in the repo (the checklist's own closing instruction, now unmet for a
  third round). `docs/audits/round3/` is analysis, not a compliance artefact.
- ⚠️ **Each item has a reason to exist.** Two exceptions, both unchanged.
  `lib/screens/services/cards/staff_role_card.dart:308-311` collects a care-needs checklist that no
  API accepts and only `debugPrint`s. `assistant_models.dart:126` still sends `'patient_id'`, and
  `functions/index.js:126-150` still never reads it — the prompt is built from `role`, `locale`, `text`
  only (`:173`). Collected, transmitted off-device, unused.
- ✅ **Sensitive identifiers optional.** Re-verified. Phone (OTP) is the only required identifier. No
  Aadhaar/PAN/bank/ABHA collection from patients; the sole Aadhaar reference is a *staff* vetting
  document type. No card data touches the app.
- ⚠️ **No data "just in case."** Same two exceptions.

### 2. Storage & encryption — ✅1 ⚠️1 ❌3

- ⚠️ **Encrypted at rest.** All persistence is still `shared_preferences` — no `flutter_secure_storage`,
  no `EncryptedSharedPreferences`. iOS-first mitigates via Data Protection on `NSUserDefaults`; on
  Android this is plaintext XML. New surface this round: **the OS notification store now also holds
  PHI** (R3-2) and is not covered by any of this.
- ✅ **Secrets/tokens in a secure store.** `ApiService._authToken` (`api_service.dart:16`) is
  memory-only; the Firebase refresh token lives in the SDK keychain. No token reaches prefs. (Its
  *lifetime* is a §6 problem — see H-3 #8 — not a storage one.)
- ❌ **No PII in logs.** **UNCHANGED — still the worst finding in this audit.** `logger.dart:55-57`
  strips only `debug`/`info` in release; `:59` interpolates `$error` for `warn`/`error`; `:60-61`
  prints full stacks for both; `grep -rn "redact" lib/` → **zero**; the `TODO(observability)` at `:63`
  would, if wired as written, additionally export every release-surviving `Log.warn` to Crashlytics.
  Confirmed leaks at `9a80fe2`:
  1. `lib/screens/services/cards/staff_role_card.dart:308-311` — the patient's care-needs checklist and
     recommended level, verbatim. **Still fires before the role gate at `:313`**, so it logs even for a
     role that cannot book.
  2. `firebase_service.dart:129-130` — `$localPath` of a user-picked file; `chat_screen.dart:132`
     preserves the basename, so `mother_biopsy_report.jpg` is logged in full.
  3. `grep -rn "error: e" lib/ | wc -l` → **51** sites logging exceptions whose `ClientException`
     text appends `uri=…`, and every patient endpoint embeds the id.
  4. `main.dart:287-292` — on **web release** (`!kDebugMode && !kIsWeb` false → `else`) every uncaught
     async error **plus full stack** goes to the browser console.
  5. `functions/index.js:192` — `console.error("assistant error:", err)`; Anthropic SDK errors echo
     request content, i.e. the patient's symptom utterance, into Cloud Logging.
  6. `grep -rn "debugPrint" lib/ | wc -l` → **34** raw sites, never stripped in release, including
     `voice_service.dart:58` and `assistant_service.dart:52,56,60`.
- ❌ **Sensitive views gated behind auth/biometric/re-auth.** `grep -rn "local_auth\|biometric\|FLAG_SECURE\|privacyScreen" lib/ ios/Runner android/app/src pubspec.yaml`
  → **zero output**. No app lock, no re-auth, no screenshot/recents blocking on vitals, medications or
  diagnoses. Exporting the handover PDF still requires nothing.
- ❌ **Backups encrypted and don't leak.** `android/app/src/main/AndroidManifest.xml:6-9` sets neither
  `android:allowBackup` nor `android:dataExtractionRules` → defaults to `true`, sweeping the plaintext
  prefs XML into Google Drive auto-backup.

### 3. Data in transit — ✅2 ⚠️2

- ⚠️ **HTTPS only, rejected in code.** `grep -rn "http://" lib/` → zero. No ATS exception, no
  `usesCleartextTraffic`. But no scheme assertion exists in `ApiService` or `AssistantService`, so a
  misconfigured `--dart-define=…=http://…` would be attempted, not refused.
- ✅ **No PII in query parameters.** Re-verified: ids travel in the path, mutations use
  `jsonEncode(body)`, auth rides in the header.
- ⚠️ **Certificate pinning considered.** Still absent and still not recorded as an accepted risk.
- ✅ **Modern TLS.** No custom `HttpClient`, no `badCertificateCallback`, no `HttpOverrides`.
  **One exception worth noting:** Firebase Storage download URLs (`firebase_service.dart:138`) are
  HTTPS but are unauthenticated bearer links — TLS protects them in transit and nothing protects them
  after.

### 4. Secrets management — ✅1 ⚠️4 ❌1

- ⚠️ **No credentials in source.** Three Firebase client keys in `firebase_options.dart` —
  public-by-design, but in source.
- ⚠️ **No credentials in history.** ✅ for every high-value class (re-verified above); ⚠️ only for the 3
  `AIza…`.
- ✅ **Secrets from env / secret manager.** `ANTHROPIC_API_KEY` → `defineSecret`; `RAZORPAY_KEY` /
  `ASSISTANT_API_URL` → `String.fromEnvironment`.
- ❌ **Different credentials per environment.** One Firebase project across all three platform entries;
  one Firestore database; one Storage bucket, now governed by one set of rules that debug, CI and
  production all share.
- ⚠️ **Rotatable without a client release.** True for the Anthropic secret; false for Firebase and
  Razorpay.
- ⚠️ **BLOCKED-OWNER — client keys scoped/restricted.** Unverifiable from the repo.

### 5. Permissions & access requests — ✅1 ⚠️1 ❌2

- ❌ **Only the permissions it uses.** `AndroidManifest.xml:3` `SCHEDULE_EXACT_ALARM` remains an
  orphan — both scheduling call sites are explicitly inexact
  (`medication_reminder_service.dart:178,228`, `AndroidScheduleMode.inexactAllowWhileIdle`) and nothing
  calls `requestExactAlarmsPermission()`. A Play policy-restricted permission for zero benefit.
- ✅ **Every permission maps to a reachable feature.** Re-verified: `Info.plist:69` mic, `:71` speech,
  `:73` camera, `:75` photo library; `RECORD_AUDIO` → `speech_to_text`.
- ⚠️ **Rationale strings specific and honest.** The camera/photo strings are genuinely good. One gap
  survives: `voice_service.dart:48-55` calls `_speech.initialize(...)` with no `onDevice`
  (`grep -rn "onDevice" lib/` → zero), so Apple may send audio off-device, and
  `NSSpeechRecognitionUsageDescription` (`:71`) does not say so. For a patient describing symptoms
  aloud, that omission matters.
- ❌ **Degrades gracefully when denied.** Handled: `raise_concern_screen.dart:104-112`,
  `document_repository_screen.dart:620-626,638-644`. Unhandled bare `await`:
  `settings_screen.dart:70`, `patient_profile_screen.dart:205`, `return_screen.dart:316`,
  `chat_screen.dart:121-126`. None distinguishes *cancelled* from *permanently denied*, so no screen
  offers an "Open Settings" path. Mic denial still fails silently (`assistant_provider.dart:165-166`).

### 6. Authentication & access control — ✅1 ⚠️1 ❌3 N/A1

- ✅ **Auth correct for the model.** Unchanged and still the strongest area: Firebase phone-OTP,
  proactive refresh at 50 min (`auth_provider.dart:30,76-81`), forced `getIdToken(true)` (`:95`),
  one-shot 401 recovery, timer stopped before sign-out (`:220`), disposed defensively (`:244-251`).
- N/A **Passwords hashed.** OTP-only. (`firebase.json:18` still enables `emailPassword`, and `:17`
  `anonymous`, that no code path uses — disabling both shrinks the auth surface and, for `anonymous`,
  directly widens who satisfies `isSignedIn()` in the new Storage rules.)
- ❌ **Authorization checked server-side.** Role is still a client-side mutable string with a hardcoded
  default (`app_provider.dart:20,22-25`), never derived from a token claim; `main.dart:236` still
  hardcodes `const role = UserRole.primaryContact;`. **New this round:** the logout teardown resets it
  to `'PRIMARY_CONTACT'` (`app_provider.dart:217`) — the most privileged value (**R3-4**). No custom
  claims exist anywhere.
- ❌ **Data isolation enforced and tested.**
  - **Storage:** the new rules **deliberately do not isolate** (`storage.rules:30-33`,
    `allow read: if isSignedIn()` at `:75,83`). Honest, but the checklist item is not met — and
    cross-patient *write* is open too (**R3-3**).
  - **Firestore:** `grep -rn "request.auth.uid" firestore.rules` → **12 hits**
    (`:67,70,72,73,90,94,99,110,114,118,133,144`) against `grep -rn "\.uid" lib/` → **zero**. Chat,
    attendance, vitals and `active_sessions` remain keyed on a predicate that is always false.
  - `health_manager_banner.dart:82-86` still passes `manager.staffId` as `'patientId'` into `/chat`,
    its own `FUTURE:` comment intact — so the thread key and the Storage ownership segment become a
    **staff** identifier depending on entry point.
  - **No rules test of any kind.** `grep -rln "storage.rules\|firestore.rules" test/` → 0 of 60 files;
    no `@firebase/rules-unit-testing`, no emulator harness. `test/utils/permission_test.dart` tests the
    pure Dart lookup table only. This is why B-1 shipped, and it is why this round's key claim about
    prefix listing cannot be proven from the repo.
- ❌ **Role-based access enforced.** Still widget-visibility only.
  `handover_report_service.dart:323` `shareHandover({DateTime? now})` — no role param, no check before
  `Printing.sharePdf` at `:327`; the three call sites only hide the button
  (`my_care_screen.dart:168`, `medications_screen.dart:60`, `medication_schedule_screen.dart:52`, the
  last still using `context.read`). `invoice_pdf_service.dart:261` has zero `canUserPerform` in the
  whole file, and **three** ungated callers: `my_orders_screen.dart:390-394` (still commented
  *"downloadable invoice (always)"* at `:381`, with the `Cancel` button gated immediately below at
  `:395-398`), `service_detail_screen.dart:511,553`, `payment_screen.dart:127`.
  `document_repository_screen.dart` has zero `canUserPerform` and shares unconditionally at `:442-448`;
  `main.dart:564-566` registers `/documents` as a plain `MaterialPageRoute`, and
  `grep -n "canUserPerform" lib/main.dart` → **zero** — no route in the app is role-guarded.
- ⚠️ **Session/token expiry; failed-login rate limiting.** Expiry/refresh solid; client resend cooldown
  30 s. **BLOCKED-OWNER** for server-side SMS abuse limits and App Check. Token teardown still
  incomplete (`api_service.dart:16` never cleared); the SessionScope half is materially better — see
  above.

### 7. Third-party SDKs & dependencies — ⚠️2 ❌1

- ⚠️ **No analytics/tracking/ads SDKs unless intended.** Still genuinely good: no `firebase_analytics`,
  no ads SDK, no Segment/Mixpanel/Amplitude/Facebook. But **Crashlytics + Performance are still forced
  on in every release build with no consent and no opt-out** (`main.dart:115-131`), and
  `settings_screen.dart` has no telemetry toggle. Under DPDP that is processing without notice.
- ❌ **Each dependency's data collection disclosed.** `ios/Runner/PrivacyInfo.xcprivacy` still does not
  exist; the 24 manifests under `ios/Pods/` are pod-level. Required by Apple since May 2024;
  `shared_preferences` uses required-reason API CA92.1. **App Store rejection risk, unchanged for two
  rounds, and more urgent now that camera and photo-library access actually function.**
  Off-device transmitters unchanged: `firebase_auth`, `cloud_firestore`, `firebase_storage`,
  `firebase_messaging`, `firebase_crashlytics`, `firebase_performance`, `razorpay_flutter`,
  `speech_to_text`, `flutter_tts`, `cached_network_image`, `http`, `share_plus`, `printing`.
- ⚠️ **Dependencies scanned; lockfile committed.** `pubspec.lock` ✅. **`functions/package-lock.json`
  still absent and untracked** — `git ls-files functions/` returns `.gitignore`, `README.md`,
  `index.js`, `package.json` only, so the function holding the Anthropic key has an unpinned dependency
  tree. No `.github/dependabot.yml`. `.github/workflows/ci.yml` has no `npm audit` / `flutter pub
  outdated` / OSV / Snyk step. `dio: ^5.8.0+1` (`pubspec.yaml:39`) still declared, still never imported.

### 8. AI / LLM privacy — ✅1 ⚠️2 ❌2

- ❌ **User content redacted before the model.** No redaction exists, built or called.
  `assistant_provider.dart:95-100` → `assistant_models.dart:124-129` → `assistant_service.dart:51-55`
  → `functions/index.js:170-175` embeds the utterance verbatim. The feature's purpose is free-form
  Hinglish symptom description.
- ⚠️ **Cloud AI opt-in and off by default.** Off by default ✅ (`assistant_service.dart:36`,
  activated only when `--dart-define=ASSISTANT_API_URL` is set). Still a **build-time** switch with no
  in-app toggle and no disclosure that a third-party LLM processes the user's words.
- ⚠️ **Model output sanitized.** Structurally constrained ✅ (`functions/index.js:166-169`
  `json_schema`, `max_tokens: 512`, closed action enum at `:66-80`). `reply_text` still rendered with
  no control-char strip and no client-side length cap. Low practical risk today; **high risk if the
  function becomes tool-using** — see below.
- ✅ **Prompt-injection surface minimized.** Still well done: input capped at 1000 chars (`:128-129`),
  `role` validated against a hard allowlist (`:142-149`), structured JSON output, system prompt cached
  separately from user content (`:159-165`), app-side executor independently re-checks permissions.
  **This grade is contingent on the executor staying on the device** — see below.
- ❌ **Token/cost limits per user.** `functions/index.js:112-119` — `onRequest`, `cors: true`, no
  `verifyIdToken`, no App Check, no API key, no rate limiter; `assistant_service.dart:53` sends only
  `Content-Type`. Anyone who learns the URL POSTs unlimited requests billed to the owner's Anthropic
  account.

#### New surface: the assistant function as the app's PRIMARY interface

**What it exposes today is bounded, and only because the function is a pure router.** It receives
`{text, patient_id, role, locale}`; `patient_id` is **never read** (`:126-150` uses only `text`, `role`,
`locale`), and the function returns an *action name*. The app then fetches the data on-device over the
authenticated `ApiService` — `assistant_executor.dart:434` `api.getBillingSummary(patientId)`, `:453`
`api.getAttendanceHistory(patientId)`. So today an anonymous attacker gets free Claude tokens on the
owner's account and nothing else. **The trust boundary is doing real work, and it is doing it by
accident of architecture, not by design.**

**Promote it to the primary, voice-driven, tool-using interface with `cors: true` and no auth, and that
boundary inverts completely.** The tools must move server-side. At that point:

- **Unauthenticated PHI read.** `curl -d '{"text":"mera bill kitna hai","patient_id":"pat_..."}'`
  returns a stranger's outstanding amount, duty days and staff names. The `patient_id` field that is
  harmlessly ignored today becomes **the authorization decision**, and it is attacker-supplied and
  unvalidated.
- **Unauthenticated writes.** `raise_concern`, `book_service`, `renew_service`, `replace_staff`
  (`functions/index.js:48-51`) become server-executed. An anonymous caller can file complaints against
  a **named nurse**, replace a patient's caretaker, or book chargeable services in someone else's
  name. Housepital's SLA triggers a callback on a concern, so this is also a real-world harassment
  vector against staff.
- **`place_call` with `target: "sos"`** (`:46`) would let an anonymous caller trigger emergency
  dispatch to a patient's address.
- **Role becomes attacker-asserted.** `:148-149` reads `body.role` and only allowlists it. The
  "defence-in-depth" comment at `:140-141` is explicit that the *app-side executor* re-checks against
  the real role — move the tools server-side and that second check disappears, leaving the attacker's
  own claim as the only role check in the system. Note the app has no server-verified role at all
  (§6), so there is nothing to fall back on.
- **`cors: true` makes it browser-drivable from any origin**, so a malicious page can drive it at scale
  from victims' browsers.
- **Prompt injection stops being theoretical.** Today the model picks from a closed enum and the device
  decides. With tools, model output becomes a side effect on real records; a 1000-char cap and a role
  allowlist are not sufficient controls for that.
- **Cost.** A voice-first primary interface means far more calls, longer inputs and tool loops.
  `max_tokens: 512` bounds one hop, not a loop, and there is still no per-caller cap.
- **Logging gets worse.** `:192` already logs Anthropic SDK errors that echo request content. With
  tools, error objects additionally carry tool arguments and fetched patient records — straight into
  Cloud Logging.

**Minimum bar before any tool executes server-side:** App Check + `verifyIdToken` on every request;
**derive `patient_id` from verified token claims, never from the body**; replace `cors: true` with an
explicit origin allowlist (or drop CORS for a native-only client); per-uid rate and spend caps;
re-derive role from claims and authorize each tool independently; validate tool arguments server-side;
scrub the catch-block log.

**Note the convergence.** The `user_patients` → custom-claim mapping deferred at `firestore.rules:151`
and `storage.rules:35-43` is the **same missing primitive** that blocks Storage isolation, Firestore
isolation, and a safe tool-using assistant. It is the single highest-leverage item in this audit.

### 9. Privacy policy & store/site disclosure — ⚠️1 ❌2 + 1 BLOCKED

- ⚠️ **Policy exists at a stable URL, linked in-app.** In-app linking is done well: an un-prechecked
  consent gate before the CTA enables (`login_screen.dart:25,48-60,177-196,272-277`) with tappable
  Terms and Privacy Policy, plus Settings → About → `https://housepital.in/privacy`. **BLOCKED-OWNER**
  on whether that URL resolves and is set in App Store Connect.
- **BLOCKED-OWNER — policy describes actual data flows.** When reviewing the text, confirm it covers:
  Firebase Storage upload of chat/concern photos **and the fact that download URLs are unauthenticated
  bearer links**; Crashlytics + Performance telemetry; off-device speech recognition; Anthropic LLM
  processing; the deletion-request path **and the pending-deletion record retained on device**.
- ❌ **Store/site disclosure matches reality.** Regraded from BLOCKED to ❌: the machine-readable half is
  independently verifiable and missing (`ios/Runner/PrivacyInfo.xcprivacy`, §7). Photos and User
  Content must now be declared — camera and photo-library access function.
- ❌ **Encryption export-compliance answered.** `ITSAppUsesNonExemptEncryption` still absent from
  `ios/Runner/Info.plist`. The app uses only standard HTTPS/TLS and qualifies for the exemption.
  **Fix:** `<key>ITSAppUsesNonExemptEncryption</key><false/>`.

### 10. Regulatory — ⚠️4

- ⚠️ **Applicable law considered.** DPDP is cited in code (`delete_account_screen.dart:19-22`) and the
  deletion flow now *behaves* like a DPDP §12 flow rather than merely citing it — real progress. Still
  not a compliance position: no notice text, no lawful-basis record, no data-principal-rights matrix,
  no grievance officer (DPDP §13), no breach runbook, no `docs/` artefact.
- ⚠️ **Lawful basis / consent; most privacy-preserving default.** The login consent gate is real and
  well-implemented, and **the deletion screen is now fully bilingual** (27 keys in both `en.json` and
  `hi.json`) — DPDP §5(3) notice-language finding **closed**. Still no granular, purpose-specific
  consent (§6) for Crashlytics/Performance (forced on), cloud LLM processing, or off-device speech.
  Defaults are not the most privacy-preserving.
- ⚠️ **Children.** No age gate. The app is not *directed* at children, which is defensible, but DPDP §9
  imposes verifiable-parental-consent duties for under-18s and nothing prevents adding a minor via
  `addPatient` (`app_provider.dart:226-230`).
- ⚠️ **Cross-border transfer.** Good instincts by construction — Firestore `asia-south1`, function
  region `asia-south1` (`functions/index.js:115`). But data does leave India: Anthropic's API,
  Crashlytics/Performance, Apple/Google speech recognition. None disclosed or contractually documented.

### 11. Deletion & retention — ⚠️1 ❌3

- ⚠️ **User can delete; deletion actually deletes.** **Materially better than round 2 and the copy is
  now defensible** — see the repair review. Remaining reasons this is not ✅:
  (a) no server-side erasure occurs and nothing is transmitted (the copy is honest about this, which is
  what closes B-5, but the checklist item asks whether deletion deletes);
  (b) `delete_account_done_device` overclaims — three counterexamples (**R3-1**);
  (c) `user.delete()` (`:131`) commonly requires a recent login, so `credentialDeleted` will often be
  false in practice and the user lands on the "call us" branch — worth measuring before submission.
- ❌ **No orphaned records after deletion.** With no server-side deletion the cascade cannot exist. Two
  named orphan sets: Firebase Storage blobs (`firebase_service.dart:133-138`) and the
  `getDownloadURL()` bearer URLs persisted into chat records (`chat_screen.dart:151-153`) — those
  remain fetchable by anyone holding them **regardless of any rule**, so they survive any future
  cascade unless the objects themselves are deleted. On-device: **R3-12** (no file is ever deleted) and
  **R3-2** (scheduled notifications).
- ❌ **User can export their data.** No DPDP §11 portability path. The handover PDF and invoice PDF are
  clinical/financial artefacts, not an export — and the handover one is still sourced entirely from
  `DemoData` (`handover_report_service.dart:109-116`), now correctly stamped as such.
- ❌ **Retention limits defined and enforced.** The only TTL in the codebase is still
  `CacheService._ttlMinutes = 30` (`cache_service.dart:7`). Orders, assessments, addresses, reminders,
  chat messages, vitals, uploaded images, notification preferences, quarantine blobs and the new
  `housepital_pending_deletion` record all persist indefinitely with no documented period. **Two new
  entries this round:** the pending-deletion record (**R3-5**, write-only, never read, never expired)
  and the quarantine sweep gap on the patient-switch path (§4 of the repair review).

### 12. Hardening & incident readiness — ⚠️2 ❌2

- ⚠️ **Input validation / output encoding.** Client-side validation present and reasonable. All
  requests `jsonEncode`d, never concatenated. Firestore writes type- and length-checked
  (`firestore.rules:74-75`). Storage writes now size- and type-checked (`storage.rules:68-71`) — with
  the caveat that `contentType` is client-asserted. ⚠️ because the REST backend is out of repo
  (BLOCKED-OWNER).
- ⚠️ **Error responses don't leak internals.** UI is clean and slightly improved:
  `paginated_list.dart:89` still captures `_error = e.toString()`, but the render path
  (`:140-150,213-223`) shows a generic retry affordance rather than painting the raw string. `main.dart`
  still replaces `ErrorWidget.builder`. **The logs are not clean** — §2.
- ❌ **Audit logging for security-relevant actions.** `grep -rn "audit_log\|auditLog\|AuditEvent" lib/ functions/`
  → zero. Nothing records who exported a handover PDF, who opened medical documents, when a role
  changed, or **who requested account deletion** — now a user-visible action with a reference number
  issued (`delete_account_screen.dart:80-81`) and no record of it anywhere but one unread prefs key.
- ❌ **You know what a compromise would expose.** No `SECURITY_REVIEW.md`, no incident runbook, no
  key-rotation procedure beyond the Anthropic note. Combined with the missing inventory (§1) and
  missing audit log, blast radius remains unknowable. **This round adds two components to that unknown
  blast radius:** the Storage bucket is now writable by any authenticated account across two prefixes,
  and the OS notification store holds PHI outside every wipe.

---

## Blockers (must fix before release)

### B-1. Assistant Cloud Function is unauthenticated with wildcard CORS. *(was B-2; promoted)*
`functions/index.js:112-119` — `onRequest` + `cors: true`, no `verifyIdToken`, no App Check, no rate
limit; the client sends no auth header (`assistant_service.dart:53`). An open proxy to a paid Claude
endpoint with unbounded cost **today**, and a full unauthenticated PHI read/write API **the moment it
becomes the tool-using primary interface** — see §8. **Fix:** App Check + verified ID token, patient id
derived from claims not the body, explicit CORS origins, per-uid daily counter, before any tool moves
server-side.

### B-2. PHI written to release logs. *(was B-3)*
`logger.dart:55-61` (strips only debug/info; interpolates `$error`; prints stacks),
`lib/screens/services/cards/staff_role_card.dart:308-311` (care-needs checklist, logged *before* the
role gate at `:313`), `firebase_service.dart:129-130` (medical-document filenames), **51** `error: e`
sites leaking patient-ID-bearing URLs, **34** raw `debugPrint` sites, and `main.dart:287-292` dumping
full stacks to the browser console on web release. No `redact()` exists.

### B-3. Sensitive exports still not role-gated in code. *(was B-4)*
`handover_report_service.dart:323` no role param; `invoice_pdf_service.dart:261` ungated with **three**
callers; `document_repository_screen.dart` zero `canUserPerform` with unconditional share at `:442-448`;
`main.dart:564-566` `/documents` unguarded and **no route in the app is role-guarded**. A `CARETAKER` —
the role `permissions.dart:66` says must not export medical history — still reaches all of it.

### B-4. `ios/Runner/PrivacyInfo.xcprivacy` missing — App Store rejection. *(was B-6)*
Required since May 2024; `shared_preferences` uses required-reason API CA92.1. Camera and photo-library
now function, so Photos and User Content must be declared.

### B-5. Firestore rules still key on an identifier the app never produces.
`grep -rn "request.auth.uid" firestore.rules` → 12 hits vs `grep -rn "\.uid" lib/` → 0. Chat,
attendance, vitals and `active_sessions` are denied to their owners. **BLOCKED-OWNER** on what is live
(`firestore.rules:9-17` says deploy happens from `housepital-backend`); if the live rules differ, the
repo file is misleading documentation of the real boundary. The Storage file was repaired to match
reality this round; this one was not, so the repo now holds two contradictory beliefs about identity.

### B-6. Scheduled medication notifications survive logout. *(new — R3-2)*
`medication_reminder_service.dart:248,256`; `medication_provider.dart:203`; no caller in
`session_scope.dart` or `auth_provider.dart:217-242`. Patient A's drug name and dose fire on the lock
screen under patient B, or after a full logout, with no authentication in front of it. **This is the
one round-3 finding that is both new and a one-line fix:** `await MedicationReminderService().cancelAllReminders();`
in `SessionScope.clearPatientData`.

## High

- **H-1.** Android `allowBackup` defaults to true (`AndroidManifest.xml:6-9`) → plaintext PHI prefs
  swept into Google Drive backup.
- **H-2.** Crashlytics + Performance forced on in release with no consent and no opt-out
  (`main.dart:115-131`); raw errors and stacks exported unscrubbed.
- **H-3.** `SessionScope` is now a **mostly** complete wipe — six of nine round-2 gaps closed — but
  three remain (`_profilePhotoPath` on switch; `AssistantProvider._patientId`;
  `ApiService._authToken`) and nine new stores were found (**R3-2, R3-6 … R3-13**). The test at
  `patient_scope_isolation_test.dart:94` still certifies "every per-patient field" without asserting
  the one field that survives.
- **H-4.** `AssistantProvider` / `AssistantExecutor` are frozen to `DemoData.patient.id` and
  `UserRole.primaryContact` at construction (`main.dart:234,236,258,270`;
  `assistant_provider.dart:21-22`). The executor **reads billing and attendance** and **submits
  concerns, bookings and staff replacements** against the demo patient regardless of who is active, and
  no wipe can change it. Cross-patient *action* path, not just display.
- **H-5.** Role is a client-side mutable string with no server claim, and the logout teardown resets it
  to the **most** privileged value (`app_provider.dart:217`).
- **H-6.** No app-lock / biometric / screenshot protection on PHI screens; no re-auth before handover
  export.
- **H-7.** No PII redaction before the LLM call.
- **H-8.** `health_manager_banner.dart:82-86` passes `manager.staffId` as `patientId` into `/chat`.
- **H-9.** *(new)* Cross-patient **write** is open under the new Storage rules (`storage.rules:82-86`) —
  evidence injection into another patient's concern batch, made permanent by `update, delete: if false`.
- **H-10.** *(new)* Firebase Storage `getDownloadURL()` bearer tokens are persisted into chat records
  (`firebase_service.dart:138` → `chat_screen.dart:151-153`) and bypass Security Rules entirely. No
  rule change can revoke them; only deleting the object can.

## Medium / Low

- **M-1.** `android/app/google-services.json` + `lib/config/firebase_options.dart` still tracked; 3
  `AIza…` in history. `CLAUDE.md` describes this accurately.
- **M-2.** `CLAUDE.md`'s Storage line — *"default-deny + per-patient chat/concern photo paths"* — reads
  as isolation the rules explicitly do not provide (`storage.rules:30-33`). **Fix this before
  deploying**, not after.
- **M-3.** Orphan `SCHEDULE_EXACT_ALARM` while both schedules are inexact.
- **M-4.** `image_picker` denial unhandled in 4 of 6 screens; mic denial fails silently.
- **M-5.** No rules-emulator test anywhere — 0 of 60 test files. The reason B-1 shipped, and the reason
  this round's prefix-listing analysis cannot be proven.
- **M-6.** Missing `ITSAppUsesNonExemptEncryption` in `ios/Runner/Info.plist`.
- **M-7.** `functions/package-lock.json` still uncommitted; no Dependabot; no `npm audit` /
  `pub outdated` / OSV step in `.github/workflows/ci.yml`.
- **M-8.** `dio ^5.8.0+1` declared, never imported.
- **M-9.** No code-level HTTPS assertion on `ApiService.baseUrl` or `AssistantService.assistantUrl`.
- **M-10.** Single Firebase project for all environments — dev/CI share the production datastore **and
  the production Storage bucket, now under one rule set**.
- **M-11.** `emailPassword` **and `anonymous`** providers enabled in `firebase.json:17-18` with no code
  path using either. `anonymous` matters more than it did: it directly widens who satisfies
  `isSignedIn()` in the new Storage rules. **Disable both before deploying `storage.rules`.**
- **M-12.** `NSSpeechRecognitionUsageDescription` does not disclose possible server-side recognition
  (`voice_service.dart:48-55` omits `onDevice`).
- **M-13.** Demo-fallback marking still incomplete: `blog_provider.dart:38,68` falls back to `DemoData`
  without `markServingDemoData`, against the `demo_mode.dart:11-13` docstring's "*Every* provider"
  claim. `app_provider.dart:142` now marks the patient-identity fallback correctly — improvement.
- **M-14.** The handover PDF's sample-data band is **unconditional** (`handover_report_service.dart:127-141`),
  which is the safe default today (the whole document is demo data) but will print "generated while the
  Housepital service was unreachable" on a live-data report once the backend lands. Gate it on
  `DemoMode` at the same time the data sources are swapped, or it becomes a false statement in the
  other direction.
- **L-1.** `paginated_list.dart:89` still captures `e.toString()` into state (no longer painted).
- **L-2.** No audit logging; `firestore.rules:149` TODO never modelled — including for the deletion
  request, which now issues a user-visible reference number backed by nothing.
- **L-3.** `StoreMigrator.quarantine` has no age stamp, TTL, reaper or cap, and is outside the
  patient-switch wipe. Zero production callers, eleven test call sites.
- **L-4.** `patient_id` still sent to the assistant and still unused by `functions/index.js`.
- **L-5.** Still no `SECURITY_REVIEW.md` / data inventory / incident runbook.
- **L-6.** `storage.rules:88-93` catch-all deny is a no-op and its comment overstates it.
- **L-7.** `DemoMode._activeSources` never reset outside tests.
- **L-8.** `settings_screen.dart` Logout / Cancel dialog strings are hardcoded English (`:450,468`)
  while the deletion screen it sits next to is fully bilingual.

## BLOCKED-OWNER

| # | Item | Exactly what is needed |
|---|---|---|
| 1 | **Live Firebase Storage rules** (gates the deploy recommendation) | Console → Storage → Rules, full text. The repo file is still undeployed. If live is the default `if request.auth != null` on `/{allPaths=**}`, deploying is a clear win; if live is fully locked, deploying loosens it *to the state the app needs to function* — either way, know before you deploy |
| 2 | Live Firestore rules vs the repo | Console → Firestore → Rules (`firestore.rules:9-17` says deploy happens from `housepital-backend`) — needed to know whether chat/vitals work today, and under what rule |
| 3 | Firebase API key restrictions | GCP Console → Credentials → each of the 3 `AIza…` keys → Application + API restrictions |
| 4 | App Check enforcement status | Firebase Console → App Check (gates B-1 and OTP abuse) |
| 5 | **Is anonymous auth actually enabled in the console?** | `firebase.json:17` enables it. Under the new Storage rules an anonymous session satisfies `isSignedIn()`, so it converts "any patient" into "anyone at all". Confirm and disable |
| 6 | SMS/OTP abuse protection & quotas | Console → Authentication → Settings → SMS region policy |
| 7 | Privacy policy is live and accurate | `https://housepital.in/privacy` loading + its text, checked against §7's SDK table, the download-URL exposure, and the on-device pending-deletion record |
| 8 | App Store Connect App Privacy answers | Screenshot of the App Privacy section (must now cover Photos + User Content) |
| 9 | Backend REST API authorization | `api.housepital.in` is out of repo — server-side authz, rate limiting and input validation cannot be audited |
| 10 | Anthropic account spend limit | Console budget cap (mitigates B-1's cost exposure) |
| 11 | **Does `user.delete()` succeed in practice?** | Firebase commonly requires a recent login. Run the deletion flow on a session older than ~5 minutes and record which branch the dialog takes (`delete_account_screen.dart:156`). If it usually fails, the "Done: your login has been deleted" line is rarely the one shown |
| 12 | **Whether a deletion request has any destination** | Confirm whether 9990-911-911 (`delete_account_done_server`) reaches anyone who can action an erasure, and whether a reference number issued by the app means anything to them |

---

## Executive summary

1. **Round-3 counts: ✅ 8 · ⚠️ 23 · ❌ 20 · 1 N/A · 1 BLOCKED-OWNER (53 items).** Effectively flat
   against round 2 — and the flatness is a measurement artefact, not a verdict. Real repairs landed;
   the checklist's granularity cannot see them.
2. **What genuinely got fixed.** `storage.rules` went from "would deny 100% of uploads" to satisfiable,
   tight, honest, and strictly better than the plausible default. The deletion flow now deletes the
   Firebase credential, records a durable request, separates DONE from REQUESTED in copy that is
   *true*, and is fully bilingual (27 keys × 2). The handover PDF carries an unconditional
   sample-data band on **every** page. `SessionScope` closed six of nine named gaps —
   `_vitalsHistory`, reminders, the assistant transcript, `CacheService`, the orders disk copy, and
   the un-awaited logout — with real tests behind each.
3. **Nothing regressed.** No round-3 change introduced a new code-level vulnerability; the three
   chrome commits touch no data path.
4. **Is any round-2 repair itself a surface? No — this is the first round where that can be said.**
   The closest call is `delete_account_done_device`'s *"everything stored on this phone has been
   erased"*, which is contradicted by the screen's own preserved record, by scheduled notifications,
   and by files never deleted. That is an overclaim in a true paragraph, not a fiction over a
   `Future.delayed`. The `SessionScope` docstring's "enumerate stores" rule is right and honestly
   applied — to an enumeration that is still incomplete.
5. **`storage.rules` — deploy it.** It is satisfiable, strictly tighter than the default, and cannot
   trigger the rollback spiral. It does **not** provide per-patient isolation and says so at `:30-33`.
   Reading another patient's photo needs the exact object key (not brute-forceable; prefix listing
   appears denied but **is untested**); the real leak is the `getDownloadURL()` bearer token, which
   bypasses rules entirely. Cross-patient **write** is wide open and permanent. Fix `CLAUDE.md`'s
   isolation-implying wording and disable anonymous auth first.
6. **`SessionScope` verdict: better, honest, still incomplete.** Three of round 2's gaps survive —
   `_profilePhotoPath` on the switch path, `ApiService._authToken`, and the frozen
   `AssistantProvider._patientId`. Nine further stores are outside it, led by **scheduled OS medication
   notifications**, which put a patient's drug name and dose on the lock screen after a full logout.
7. **The pending-deletion record is not a DPDP problem in itself** — it is a record *of* a request,
   minimised, held on the principal's own device, and §12/§13 are inoperable without an identifier.
   Preserving it through logout is correct and load-bearing (the flow ends in logout). Two real
   defects: the comment calls a patient id "no PHI", and the key is **write-only** — nothing reads it,
   nothing expires it, so the stated replay purpose has no implementation.
8. **`StoreMigrator` quarantine: unchanged in substance.** Still zero production callers, now
   eleven test call sites; still no timestamp, TTL, reaper or cap; and now demonstrably outside the
   **patient-switch** wipe, which round 2 did not test for. Logout still sweeps it, by the allowlist
   rewrite. Fix before the first migration ships; the cost only goes up.
9. **Top 5 remaining:** (1) the unauthenticated Cloud Function, urgently if it becomes the primary
   tool-using interface; (2) PHI in release logs; (3) the `user_patients` custom-claim mapping — one
   primitive that unblocks Storage isolation, Firestore isolation and a safe assistant simultaneously;
   (4) scheduled medication notifications surviving logout; (5) `PrivacyInfo.xcprivacy`.
10. **Verdict: FAIL for release.** Six blockers stand, four of them unchanged for three rounds. But the
    trajectory reversed this round: for the first time the repairs are repairs, the code says what it
    does, and the one file that was actively dangerous is now merely limited — and honest about it.
    `ANTHROPIC_API_KEY` is re-confirmed clean on every ref for the third time; that finding is settled.

---

*Round-3 read-only audit against commit `9a80fe2`. No source file was modified.*
