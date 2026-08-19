# Security & Privacy — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-11 · **Auditor:** Security & Privacy (App-Agnostic, control family SEC)
**Scope:** source review of the Flutter client (`lib/`, `ios/`, `android/`), the Cloud Function
(`functions/`), `firestore.rules` + `storage.rules`, `.github/workflows/`, all 104 test sources, and
the full git history on every ref. See **Limitations**.
**Prior rounds:** round 2 = `docs/audits/SECURITY_PRIVACY_AUDIT.md` (`820060b`), round 3 =
`docs/audits/round3/SECURITY_PRIVACY_AUDIT.md` (`9a80fe2`). Both read; neither modified.

---

## Applicability

MASTER-3.xx trigger: the checklist's own applicability line is *"Every product."* Beyond that
baseline, this app trips four independent escalations — it stores **health data** (vitals,
medications, diagnoses, symptom transcripts), **captures media** (camera + photo library, into chat
and complaint-evidence uploads), **sends free-text user content to a third-party LLM**, and **targets
India**, bringing DPDP Act 2023 / DPDP Rules 2025 and CERT-In into scope (SEC-19.06). Sections
**§1–§9 apply every release; §10–§19 apply at first launch and on material change** — and this
release is a material change: storage keying, the session teardown, and the migration layer all moved.

**§13–§19 (32 controls) are new in Suite v2.0 and have never been audited.** Round 3 graded 53
controls (§1–§12). This report grades all 85. Where §13–§19 findings are new, they are marked
**(first look)** rather than presented as regressions.

---

## Round-3 findings: status now

| Round-3 finding | Status now | Evidence |
|---|---|---|
| **B-1** Assistant Cloud Function unauthenticated + wildcard CORS | **Still open — Fail** | `functions/index.js:112-119`: `onRequest`, `cors: true`, `timeoutSeconds: 30`. `grep -n "verifyIdToken\|appCheck\|rateLimit" functions/index.js` → **only** `116: cors: true`. No auth of any kind |
| **B-2** PHI in release logs | **Still open — Fail** | `logger.dart:55-57` strips only debug/info; `:59` still interpolates `— $error`; `:60-61` still prints stacks for warn/error; `:63` TODO(observability) still unwired. `grep -rc redact lib/` → **0 files**. `debugPrint` **34**, `error: e` **52** (was 51 — one added) |
| **B-3** Sensitive exports not role-gated in code | **Still open — Fail** | `grep -c canUserPerform` across `main.dart`, `handover_report_service.dart`, `invoice_pdf_service.dart`, `document_repository_screen.dart` → **0**. `handover_report_service.dart:323` still `shareHandover({DateTime? now})` |
| **B-4** `ios/Runner/PrivacyInfo.xcprivacy` missing | **Still open — Fail** | File absent; `git ls-files \| grep -i privacy` returns only the two audit reports |
| **B-5** Firestore rules key on an id the app never produces | **Still open — Fail** | `grep -c request.auth.uid firestore.rules` → **12**; `grep -rn "\.uid" lib/ \| wc -l` → **0**. Unchanged for three rounds |
| **B-6 / R3-2** Scheduled medication notifications survive logout | **Partially fixed — Warning** | `session_scope.dart:99-104` now awaits `MedicationReminderService().cancelAllReminders()`. **Two gaps survive** — see *Verification 1* |
| **R3-3** Cross-patient WRITE open in Storage rules | **Still open — Fail** | `storage.rules:82-86` byte-identical: `allow create: if isSignedIn() && isImageUnder10Mb(); allow update, delete: if false;` |
| **R3-4** `clearSession` resets role to the most privileged value | **Still open — Fail** | `app_provider.dart:235` `_currentUserRole = 'PRIMARY_CONTACT';` |
| **R3-5** `housepital_pending_deletion` is write-only | **Still open — Fail** | `grep -rn housepital_pending_deletion lib/` → 3 hits: constant, write, preserve-list (`auth_provider.dart:234`). No reader, no expiry |
| **H-3 #2** `_profilePhotoPath` survives a patient SWITCH | **Still open — Fail** | See *Verification 2* |
| **H-3 #5b** `AssistantProvider._patientId`/`_role` `final` | **Still open — Fail** | See *Verification 2* |
| **H-3 #8** `ApiService._authToken` never cleared | **Still open — Fail** | See *Verification 2* |
| **H-8** `staffId` passed as `patientId` | **Still open** | `health_manager_banner.dart:82-86`, unchanged |
| **H-10** `getDownloadURL()` bearer tokens bypass rules | **Still open — Fail** | `firebase_service.dart:138` `return await ref.getDownloadURL();` — sole call site, unchanged |
| **M-2** `CLAUDE.md` Storage line implies isolation the rules do not provide | **REGRESSED IN PRACTICE** | `CLAUDE.md:55` still reads *"default-deny + per-patient chat/concern photo paths"* — **after** `9127713` explicitly rewrote CLAUDE.md's storage contracts. See *Verification 5* |
| **M-4 / M-5** No rules test anywhere | **Still open — Fail** | `grep -rln "storage.rules\|firestore.rules\|rules-unit-testing" test/` → **0** of **104** files (was 0 of 60 — the suite grew 73% and gained none) |
| **M-11** `anonymous` + `emailPassword` providers enabled | **Still open — Warning** | `firebase.json:17-18` `"anonymous": true, "emailPassword": true` |
| **M-6** `ITSAppUsesNonExemptEncryption` absent | **Still open — Fail** | `grep -c` on `ios/Runner/Info.plist` → **0** |
| **M-7** `functions/package-lock.json` uncommitted | **Still open — Warning** | `git ls-files functions/` → `.gitignore`, `README.md`, `index.js`, `package.json` |
| **L-3** `StoreMigrator.quarantine` retention | **WORSE — Fail** | Now has a live producer writing PHI. See *Verification 4* |
| **L-6** `{allPaths=**} if false` is a no-op | **Still open — Warning** | `storage.rules:88-93`, unchanged |
| `ANTHROPIC_API_KEY` server-side only | **SETTLED — Pass** | Four scans, all empty. See *Verification 6* |
| Firebase client config tracked | **SETTLED — Warning** | 2 tracked files, 3 `AIza…` in history. See *Verification 6* |
| Carried-open: `SessionScope` imported by zero tests | **Still true** | `grep -rln SessionScope test/` returns one file, but the hit is a **comment** (`patient_scope_isolation_test.dart:12`). No test imports or exercises the class |

**Pattern.** Round 1→2 found surfaces; round 2→3 found half-wires. **Round 3→4 fits neither: the
code fixes are real and correctly placed, but they are unwired from their own verification and
documentation contracts.** The notification fix is in the right function and has zero tests. The
per-patient keying is correct and its retention consequence is undocumented. The documentation
commit rewrote the exact CLAUDE.md section round 3 named and left the named sentence intact. Call it
**wired-but-unwitnessed**: correct behaviour with no mechanism that would notice if it broke.

---

## Verification 1 — does the notification-cancellation fix reach ALL scheduled notifications?

**Answer: it reaches all notification IDs, but not all logout paths, and it is guarded by an
initialisation flag that no caller checks. Warning, not Pass.**

**(a) ID coverage — complete.** `session_scope.dart:100` calls `cancelAllReminders()`
(`medication_reminder_service.dart:248-251`), which is `await _plugin.cancelAll()`. That is the
plugin's global cancel, not an ID sweep, so it takes:
- the daily repeats — `zonedSchedule(...)` at `:147` with
  `matchDateTimeComponents: DateTimeComponents.time` (`:181`), i.e. **every future day**, not just
  the next one;
- the snooze notifications — `_scheduleSnooze` at `:197`, ID `_generateSnoozeId` (`:291-293`,
  `hashCode.abs()*10 + 5`), which the per-medication `cancelReminders` (`:236-245`) has to enumerate
  by hand but `cancelAll` does not;
- **any ID outside the app's own partition scheme.** `_generateNotificationId` (`:287-289`) is
  `medicationId.hashCode.abs() * 10 + slotIndex`. Dart's `String.hashCode` is not stable across VM
  runs or platforms, so an ID scheduled by a previous process is **not derivable** by the current
  one. `cancelReminders` would strand it; `cancelAll` does not. Choosing `cancelAll` here is the
  correct call and the only one that works.

**(b) Logout-path coverage — incomplete.** Three code paths end a session:

| Path | Site | Reaches `cancelAllReminders`? |
|---|---|---|
| Settings → Logout | `settings_screen.dart:460` `SessionScope.clearSession` then `:461` `auth.logout()` | **Yes** |
| Delete account | `delete_account_screen.dart:143-145`, same order | **Yes** |
| **Involuntary logout on 401** | `auth_provider.dart:112` `await logout();` inside `handleUnauthorized()`, wired as `apiService.onUnauthorized` at `main.dart:190` | **No** |

`AuthProvider.logout()` (`:217-242`) calls `_stopTokenRefreshTimer()`, `signOut()`, and the two-key
prefs allowlist. It never touches `SessionScope`, so it cancels nothing, and it also leaves every
provider's in-memory state intact — the original round-2 defect, still live on this one path.
`handleUnauthorized` fires when a 401 arrives **and** the refresh token is revoked or expired: the
exact scenario in which a session must be torn down hardest is the one that tears down least.

Mitigating: `api.housepital.in` does not resolve, so no 401 is reachable in the current demo build.
That makes this a Warning rather than a Fail — but it becomes a Fail the day the backend lands, with
no code change required to make it one.

**(c) The `_initialized` guard.** `cancelAllReminders` opens `if (kIsWeb || !_initialized) return;`
(`:249`). `_initialized` is set only by `init()` (`:112`), called once at `main.dart:179` inside
`if (!kIsWeb)`. On the happy path this is true before any UI exists. But the guard means **a silent
no-op is the failure mode**: if `init()` ever throws (it does timezone-database iteration at `:59-73`
and a platform channel call at `:92`) `main.dart:179` is not individually guarded, and the `try` that
wraps the call in `session_scope.dart:99-104` catches an *exception*, not a *silent return*. Nothing
logs "I was asked to cancel and did nothing." **No test covers any of this**:
`grep -rln cancelAllReminders test/` → zero across 104 files.

**(d) The contract this fix broke.** `CLAUDE.md` states: *"New patient-scoped state gets added there
and asserted in `test/providers/patient_scope_isolation_test.dart` in the SAME edit."* The
notification store was added to `SessionScope` in `13e3656` with no assertion in that file or any
other. This is the single clearest instance of the round-4 pattern.

**(e) One structural note, not a defect.** On logout, `SessionScope.clearSession` →
`AppProvider.clearSession()` → `_announcePatient(null)` (`app_provider.dart:237`) →
`onPatientChanged` → `SessionScope._adopt` → `clearPatientData` **again**. `cancelAllReminders` runs
twice per logout. Idempotent, so harmless, but it means the fan-out is re-entrant and nobody has
written that down.

---

## Verification 2 — SessionScope re-checked against round 3's own list

All three residuals are **unchanged**. Verified field by field, not by diff.

**`_profilePhotoPath` — Fail.** `app_provider.dart:47` declares it; `:234` nulls it, and `:234` is
inside `clearSession` (`:228-...`), **not** `clearPatientScopedData` (`:215-225`, whose body is
`_activeDeployment`, `_todayAttendance`, `_latestVitals`, `_todayReport`, `_vitalsHistory.clear()`,
`_amountDue`, `_dueDate`, `_dashboardError`, `_lastUpdatedText`). So a **patient switch** keeps it in
memory. The disk copy is worse: `:121` writes `prefs.setString('profile_photo_path', path)`, and
`SessionScope._patientScopedPrefsKeys` (`session_scope.dart:49-51`) now contains **exactly one
entry** — `'housepital_saved_addresses'` — plus the `daily_rating_` prefix sweep at `:129-133`.
`profile_photo_path` is in neither. It is set from `patient_profile_screen.dart:211`, the *patient's*
profile screen, so it is unambiguously patient-scoped, and `app_provider.dart:212-213`'s "device- and
account-scoped state deliberately survives" rationale misclassifies it.
`grep -n "profilePhoto\|currentUserRole" test/providers/patient_scope_isolation_test.dart` → **zero
hits**, and the test named `'clearPatientScopedData nulls every per-patient field'` still certifies a
completeness it does not check. Identical to round 3, word for word.

**`AssistantProvider._patientId` / `_role` — Fail.** `assistant_provider.dart:21-22` still
`final String _patientId; final String _role;`. `main.dart:234` `final patientId =
DemoData.patient.id;` (`demo_data.dart:29` → `'pat_demo_rajesh'`), `:236` `const role =
UserRole.primaryContact;`, passed to the executor at `:258` and the provider at `:270`, with
`deploymentId: DemoData.icuDeployment.id` at `:260`. `clearPatientScopedData`
(`assistant_provider.dart:184-189`) clears `_messages`, `_pendingConfirmation`, `_isThinking` — it
**cannot** rebind a `final`. This remains a cross-patient *action* path, not merely a display one,
and it is immune to `SessionScope` by construction.

**`ApiService._authToken` — Fail.** `api_service.dart:16` `String? _authToken;`; `:44-45`
`setAuthToken(String token)`; `:50` `if (_authToken != null) 'Authorization': 'Bearer $_authToken'`.
`i_api_service.dart:12` declares only `void setAuthToken(String);` — the interface has **no clear
method to call**, so this cannot be fixed inside `SessionScope` without an interface change.
`auth_provider.dart:217-242` never nulls it. A valid bearer token for the outgoing patient survives
in-process for up to 60 minutes after logout.

**Also unchanged:** `app_provider.dart:235` resets `_currentUserRole` to `'PRIMARY_CONTACT'` — the
most privileged role — on logout (R3-4).

---

## Verification 3 — per-patient order keys: naming, discoverability, retention

`orders_provider.dart:22-23` `_ordersKeyPrefix = 'housepital_orders_'`,
`_assessmentsKeyPrefix = 'housepital_assessments_'`; `:33-35` compose
`'$prefix${_patientId ?? '_none'}'`.

**Does the key naming leak anything? — Yes, two things, one of them new.**

1. **The key name embeds the patient identifier in cleartext in the preferences store.** The demo id
   is `'pat_demo_rajesh'` (`demo_data.dart:29`) — a **given name**. Production ids come from the API
   and their shape is unverifiable from this repo (**BLOCKED-OWNER**), but the format is fixed and
   documented, so if production follows the demo convention the key name alone asserts *"this named
   person is a Housepital patient"* — a health-adjacent inference from a key, before any value is
   read. Values are already plaintext (`shared_preferences`; no `flutter_secure_storage` anywhere in
   `pubspec.yaml`), so this does not create a new class of exposure — it extends the existing one
   from values to key names, which are what a backup index and a `getKeys()` dump show first.
2. **Combined with `AndroidManifest.xml` setting neither `android:allowBackup` nor
   `android:dataExtractionRules` (grep → no match, so both default permissive), the whole key space
   is swept into Google Drive auto-backup** — now one entry per patient the device has ever served,
   named.

**Is one patient's key discoverable? — Not remotely; trivially with device access; and the guess is
free.** SharedPreferences is app-sandboxed on both platforms, so there is no cross-app or network
route. From inside the process, `prefs.getKeys()` enumerates everything —
`store_migrator.dart:193` and `session_scope.dart:129` already iterate it. From outside, the routes
are Android auto-backup, a rooted/jailbroken device, or a local/iTunes backup. The material point is
that **no guessing is required**: the format is a documented constant, and patient ids leak into
logs today via the 52 `error: e` sites whose `ClientException` text appends `uri=…` with the id in
the path (round-3 B-2, unchanged). Device access + one log line = the exact key. That is a chained
weakness, not an independent one, but the chain is complete in this repo.

**The retention consequence is new and undocumented — this is the round-4 finding here.** The
round-3 fix was correct and necessary: one global key meant `clearPatientScopedData` wrote `[]` over
the outgoing patient's real history. Per-patient keys fix that by construction, and the code says so
honestly (`orders_provider.dart:253-257`). But **the same property that makes the switch safe makes
the store unbounded**: `SessionScope.clearPatientData` deliberately does not touch
`housepital_orders_*` or `housepital_assessments_*` (`session_scope.dart:49-51` lists neither), and
nothing else ever removes them. After a shared family phone has served four patients, four complete
order histories — service names, prices, dates, dispatch addresses — and four assessment sets sit in
plaintext preferences **indefinitely**, and only a full logout (`auth_provider.dart:231-234`, the
two-key allowlist) removes any of them. A data-destruction bug was correctly traded for a
data-retention bug, and neither `CLAUDE.md`'s "Storage & session contracts" block nor
`docs/ARCHITECTURE.md` records the trade. This is SEC-11.04 and SEC-19.01.

**One latent defect in the naming.** `_ordersKey` falls back to `'housepital_orders__none'` when
`_patientId` is null. `main.dart:214` constructs `OrdersProvider()` with **no** patientId, and the
constructor (`:43-45`) immediately calls `_loadFromStorage()`. `_patientId` is set only by
`setPatient`, called only from `SessionScope._adopt` (`session_scope.dart:76`) after
`AppProvider._announcePatient` fires. So between app launch and the first patient adoption, and again
after `clearPatientScopedData()` sets `_patientId = null` (`orders_provider.dart:261`) with no
`setPatient` following it on the logout path, the provider is pointed at a **shared, un-scoped
bucket** that `SessionScope` never sweeps. Any `_persistAndNotify()` in that window
(`:205-207`) writes one patient's orders to a key every future null-patient session reads. The window
is narrow and I found no call site that writes inside it, so this is a **Warning**, not a Fail — but
it is the one place where the per-patient keying invariant is expressible as a string and is not
enforced.

---

## Verification 4 — the v1→v2 quarantine now writes PHI with no TTL

**Round 3 flagged the retention question when `quarantine()` had zero production callers. It has one
now, and it writes exactly the data round 3 predicted. This escalates from Fail-latent to Fail-live.**

`store_migrator.dart:34` `currentVersion = 2`. `_buildShippedMigrations()[1]` (`:65-73`):

```dart
const legacyOrders = 'housepital_orders';
const legacyAssessments = 'housepital_assessments';
for (final key in <String>[legacyOrders, legacyAssessments]) {
  if (!prefs.containsKey(key)) continue;
  await quarantine(prefs, key, 1);
  await prefs.remove(key);
}
```

`quarantine` (`:204-222`) copies the value to `'__quarantine_v${version}_$key'` — so on every device
upgrading from a pre-v2 install, `__quarantine_v1_housepital_orders` and
`__quarantine_v1_housepital_assessments` are created holding **the complete legacy order history and
care-needs assessments**: service names, amounts, dates, dispatch addresses, clinical assessment
content. The migration is deliberately unable to attribute them to a patient (`:59-64` explains why,
correctly).

Retention properties, all verified unchanged from round 3:
- **No creation timestamp.** `:208` composes the target from version and key only.
- **No TTL, no reaper.** `run()` (`:109-120`) and `_run()` (`:122-154`) contain no expiry pass;
  `grep` for any reaper over `__quarantine` in `lib/` finds only the writer.
- **No size cap.** An order blob is unbounded.
- **No reader.** The contract at `:202-203` states outright *"Quarantined entries are never read by
  the app"*; recovery is a manual support operation with no tooling in this repo.
- **No user-facing disclosure.** No settings entry, no privacy text, no `docs/` artefact.
- **Outside the patient-switch wipe.** `session_scope.dart:49-51` sweeps
  `housepital_saved_addresses` and `daily_rating_*` only. Confirmed still true.

Swept only by `AuthProvider.logout()`'s allowlist (`auth_provider.dart:231-234`), which preserves
just `housepital_schema_version` and `housepital_pending_deletion`. So the exposure window is *from
first launch after upgrade until the next full logout* — on a shared family phone that switches
patients and stays signed in, which `session_scope.dart:23-25` names as the core use case, that
window is **unbounded**.

`test/services/store_migrator_test.dart:254-257` asserts the quarantine entries are **created**;
nothing anywhere asserts they are ever removed. Round 3's estimate — *"doing this before the first
migration ships costs an hour"* — has now expired: the migration has shipped.

One documentation defect: `:220` logs *"Quarantined unparseable \"$key\""*. The v1→v2 step
quarantines data that parses fine; it quarantines it because ownership is unknowable. The log line
will mislead whoever reads it during an incident.

---

## Verification 5 — the documentation pass did not fix the line round 3 named

Round 3's deploy recommendation carried **three conditions**, the first of which was *"Fix the doc
wording first… `CLAUDE.md` describes it as 'default-deny + per-patient chat/concern photo paths'. The
paths are per-patient; the **rules are not**… This mismatch is the single biggest risk of deploying."*

Commit `9127713` is titled *"docs: the paragraph-level pass the documentation audit kept asking
for"* and its message states it rewrote CLAUDE.md's storage contracts. `CLAUDE.md:55` at HEAD:

> `- **Storage rules:** \`storage.rules\` (default-deny + per-patient chat/concern photo paths) must be`

**Unchanged.** The sentence round 3 identified as the highest-risk line in the repo survived the
commit that rewrote the section containing it. Partial credit is due elsewhere:
`docs/DEPLOYMENT_GUIDE.md:402` now carries a *"`storage.rules` caveat — read the file header before
relying on it"* block, and `docs/KNOWN_ISSUES.md:19` records the file as undeployed. But CLAUDE.md is
the living contract the brief names first, and it is the file an engineer reads before deciding
whether isolation is done.

**Consequence for the gate:** round 3's condition 1 for deploying `storage.rules` is **not met**.
Condition 3 (*"do not record this as closing the isolation blocker"*) is met — `KNOWN_ISSUES.md:19`
is honest. Condition 2 (bucket-level guard) is BLOCKED-OWNER.

---

## Verification 6 — secret scan and Firebase config (settled, stated not re-argued)

**`ANTHROPIC_API_KEY`: Pass. Settled across four rounds. Not to be re-litigated.**

```
$ git log --oneline --all -S "ANTHROPIC" -- lib/ ios/            → (empty)
$ git log -p --all | grep -oE "sk-ant-[A-Za-z0-9_-]{20,}" | sort -u → (empty)
$ git log -p --all | grep -oE "(AKIA[0-9A-Z]{16}|sk_live_[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)" | sort -u → (empty)
```

The key exists only as `defineSecret` in `functions/index.js`. It cannot reach the client binary. No
AWS, Stripe, GitHub, Slack, or private-key material on any ref, in any round.

**Firebase client config: Warning. Settled — the position is correct and needs no further argument.**

```
$ git ls-files | grep -iE "GoogleService|google-services|firebase_options"
android/app/google-services.json
lib/config/firebase_options.dart
$ git log -p --all | grep -oE "AIza[A-Za-z0-9_-]{35}" | sort -u | wc -l
       3
```

Unchanged for three rounds. `CLAUDE.md:47-54` describes this accurately, including why untracking
would not help. These are public-by-design client identifiers; the real controls are Security Rules
(broken for Firestore, deliberately non-isolating for Storage) and console key restrictions
(BLOCKED-OWNER). **The grade is Warning because of those two dependencies, not because the files are
tracked.**

---

## Control results

Outcomes: **Pass / Warning / Fail / N/A / BLOCKED-OWNER.** Every Warning and Fail carries impact,
mitigation, and an owner. `OWNER-TBD` is written where the owner is not knowable from the repo.

### §1 Data inventory & minimization

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-1.01 | **Fail** | `docs/DATA_INVENTORY.md` absent; no `SECURITY_REVIEW.md` anywhere (`git ls-files \| grep -iE "inventory\|security_review"` → only the two audit reports). The checklist's own closing instruction, unmet for a fourth round | No authoritative list of what is stored. Blocks SEC-19.01, the DPDP notice, and the store labels. **Mitigation:** derive from `SessionScope` + `StoreMigrator` + `AndroidManifest`/`Info.plist`. **Owner:** OWNER-TBD · **Due:** before submission |
| SEC-1.02 | **Warning** | `staff_role_card.dart:308-311` collects a care-needs checklist no API accepts and only `debugPrint`s. `assistant_models.dart:126` sends `'patient_id'`; `functions/index.js:126-150` never reads it (prompt built from `role`, `locale`, `text` at `:173`) | Two fields collected/transmitted with no consumer. **Mitigation:** delete both. **Owner:** OWNER-TBD |
| SEC-1.03 | **Pass** | Phone (OTP) is the only required identifier. No Aadhaar/PAN/bank/ABHA collected from patients; the sole Aadhaar reference is a *staff* vetting document type. No card data touches the app (Razorpay hosted) | — |
| SEC-1.04 | **Warning** | Same two exceptions as SEC-1.02 | As above |

### §2 Storage & encryption

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-2.01 | **Fail** | All persistence is `shared_preferences`; `pubspec.yaml` has no `flutter_secure_storage`, no `EncryptedSharedPreferences`. iOS gains Data Protection on `NSUserDefaults`; **Android is plaintext XML**. Three PHI stores added or extended this round: per-patient order/assessment keys (V3), `__quarantine_v1_*` (V4), the OS notification store | Full clinical history readable from any Android backup or rooted device. **Mitigation:** move order/assessment/quarantine blobs to encrypted storage, or set `android:allowBackup="false"` as a stopgap. **Owner:** OWNER-TBD · **Due:** pre-launch |
| SEC-2.02 | **Pass** | `api_service.dart:16` `_authToken` is memory-only; Firebase refresh token lives in the SDK keychain. No token reaches prefs. (Its *lifetime* is SEC-17.01) | — |
| SEC-2.03 | **Fail** | `logger.dart:55-61`; `grep -rc redact lib/` → 0 files; 34 `debugPrint`; 52 `error: e`; `staff_role_card.dart:308-311` logs before its own role gate at `:313`; `firebase_service.dart:129-130` logs user file basenames; `main.dart:287-292` dumps stacks to the browser console on web release; `functions/index.js:192` echoes Anthropic errors containing the symptom text into Cloud Logging | **Release blocker.** PHI in logs and Crashlytics. **Mitigation:** a `redact()` chokepoint in `logger.dart`; strip `debugPrint` in release. **Owner:** OWNER-TBD |
| SEC-2.04 | **Fail** | `grep -rn "local_auth\|biometric\|FLAG_SECURE\|privacyScreen" lib/ ios/Runner android/app/src pubspec.yaml` → zero | No app lock, no re-auth before the handover PDF, no screenshot/recents blocking on vitals or medications. **Mitigation:** `local_auth` gate on PHI routes + export. **Owner:** OWNER-TBD |
| SEC-2.05 | **Fail** | `grep -n "allowBackup\|dataExtractionRules\|fullBackupContent" android/app/src/main/AndroidManifest.xml` → **no match**, so both default permissive | Plaintext prefs — now including per-patient-keyed order histories and quarantined PHI — swept to Google Drive. **Mitigation:** one-line `android:allowBackup="false"`. **Owner:** OWNER-TBD |

### §3 Data in transit

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-3.01 | **Warning** | `grep -rn "http://" lib/` → zero; no ATS exception; no `usesCleartextTraffic`. But no scheme assertion in `ApiService` or `AssistantService` | A `--dart-define` misconfiguration to an `http://` host would be attempted, not refused. **Mitigation:** assert `uri.isScheme('https')` at both base-URL sites. **Owner:** OWNER-TBD |
| SEC-3.02 | **Pass** | Ids travel in the path; mutations use `jsonEncode(body)`; auth rides in the `Authorization` header (`api_service.dart:50`) | — |
| SEC-3.03 | **Warning** | No pinning; not recorded as an accepted risk anywhere | Optional per the control, but the *decision* is unrecorded. **Mitigation:** record acceptance. **Owner:** OWNER-TBD |
| SEC-3.04 | **Pass** | No custom `HttpClient`, no `badCertificateCallback`, no `HttpOverrides`. Platform TLS throughout | Caveat, graded under SEC-6.04: `getDownloadURL()` links are HTTPS but unauthenticated bearer URLs — TLS protects them in transit and nothing protects them after |

### §4 Secrets management

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-4.01 | **Warning** | 3 Firebase client keys in `lib/config/firebase_options.dart` — public-by-design, but in source (V6) | Safety depends entirely on rules + console restrictions. **Owner:** OWNER-TBD |
| SEC-4.02 | **Warning** | V6: every high-value key class clean on every ref; 3 `AIza…` present | As above |
| SEC-4.03 | **Pass** | `ANTHROPIC_API_KEY` → `defineSecret`; `RAZORPAY_KEY` / `ASSISTANT_API_URL` → `String.fromEnvironment`. Settled (V6) | — |
| SEC-4.04 | **Fail** | One Firebase project across all three platform entries; one Firestore database; one Storage bucket — debug, CI and production share them, under one rule set | A CI or debug session is an authenticated principal against the production bucket, which `storage.rules` lets write two prefixes. **Mitigation:** separate dev/staging projects. **Owner:** OWNER-TBD |
| SEC-4.05 | **Warning** | True for the Anthropic secret; false for Firebase and Razorpay (compiled in) | Firebase/Razorpay rotation needs a client release. **Owner:** OWNER-TBD |
| SEC-4.06 | **BLOCKED-OWNER** | Console-only. Whether the 3 `AIza…` keys carry application and API restrictions is unverifiable from the repo | Needs GCP Console → Credentials screenshot per key |

### §5 Permissions & access requests

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-5.01 | **Fail** | `AndroidManifest.xml:3` `SCHEDULE_EXACT_ALARM` is an orphan — both schedules are `AndroidScheduleMode.inexactAllowWhileIdle` (`medication_reminder_service.dart:228` and the `zonedSchedule` at `:147`), and nothing calls `requestExactAlarmsPermission()` | A Play policy-restricted permission for zero benefit; a declared-permission review question at submission. **Mitigation:** delete the line. **Owner:** OWNER-TBD |
| SEC-5.02 | **Pass** | `Info.plist:69` mic, `:71` speech, `:73` camera, `:75` photo library all map to shipping features; `RECORD_AUDIO` → `speech_to_text` | — |
| SEC-5.03 | **Warning** | Camera/photo strings are specific and honest. `voice_service.dart:48-55` calls `_speech.initialize(...)` with no `onDevice` (`grep -rn onDevice lib/` → zero), so audio may go off-device, and `NSSpeechRecognitionUsageDescription` does not say so | A patient describing symptoms aloud is not told the audio may leave the device. **Mitigation:** set `onDevice: true` or amend the string. **Owner:** OWNER-TBD |
| SEC-5.04 | **Fail** | Handled: `raise_concern_screen.dart:104-112`, `document_repository_screen.dart:620-626,638-644`. Bare unhandled `await`: `settings_screen.dart:70`, `patient_profile_screen.dart:205`, `return_screen.dart:316`, `chat_screen.dart:121-126`. Mic denial silent at `assistant_provider.dart:165-166` | 4 of 6 picker screens and the mic dead-end on denial with no "Open Settings" path. **Mitigation:** distinguish cancelled from denied; offer settings. **Owner:** OWNER-TBD |

### §6 Authentication & access control

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-6.01 | **Pass** | Firebase phone-OTP; proactive refresh at 50 min (`auth_provider.dart:76-81`); forced `getIdToken(true)` (`:95`); one-shot 401 recovery (`:110-116`); timer stopped before sign-out (`:220`); disposed defensively (`:245-250`). Still the strongest area | — |
| SEC-6.02 | **N/A** | **Rationale:** the app has no password path — OTP only; `firebase_service` exposes no password API and no screen collects one. Graded N/A because the control cannot apply, not because it was untested. Cross-ref: `firebase.json:18` enables `emailPassword` and `:17` `anonymous` with no code path using either — graded as a Warning under SEC-17.02 | — |
| SEC-6.03 | **Fail** | Role is a client-side mutable string with a hardcoded default (`app_provider.dart:20,22-25`), never from a token claim; `main.dart:236` hardcodes `const role = UserRole.primaryContact;`; logout resets to the **most** privileged value (`app_provider.dart:235`). No custom claims anywhere | Every authorization decision is client-side and forgeable. **Mitigation:** the `user_patients` → custom-claim mapping. **Owner:** OWNER-TBD |
| SEC-6.04 | **Fail** | Storage: `storage.rules:75,83` `allow read: if isSignedIn()` — no ownership condition; cross-patient **write** open at `:82-86` and permanent because `update, delete: if false`. Firestore: 12 `request.auth.uid` vs 0 `.uid` in `lib/`. `getDownloadURL()` bearer tokens (`firebase_service.dart:138` → `chat_screen.dart:151-153`) bypass rules entirely. **No rules test in 104 files** | No tenant isolation, and no test proves any. **Mitigation:** custom claims + `@firebase/rules-unit-testing` harness. **Owner:** OWNER-TBD |
| SEC-6.05 | **Fail** | `grep -c canUserPerform` across `main.dart`, `handover_report_service.dart`, `invoice_pdf_service.dart`, `document_repository_screen.dart` → **0**. `shareHandover({DateTime? now})` at `:323` takes no role. No route in the app is role-guarded | A `CARETAKER` — the role `permissions.dart:66` says must not export medical history — reaches all of it. **Mitigation:** gate at the service, not the widget. **Owner:** OWNER-TBD |
| SEC-6.06 | **Warning** | Expiry/refresh solid; client resend cooldown 30 s. Server-side SMS abuse limits and App Check are **BLOCKED-OWNER**. `_authToken` teardown incomplete (V2) | Token outlives the session by up to 60 min in-process. **Owner:** OWNER-TBD |

### §7 Third-party SDKs & dependencies

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-7.01 | **Fail** *(was ⚠️ in round 3; the control requires "explicitly intended **and disclosed**")* | Genuinely no analytics/ads SDK: no `firebase_analytics`, no Segment/Mixpanel/Amplitude/Facebook. But `firebase_crashlytics: ^4.3.5` and `firebase_performance: ^0.10.1+5` (`pubspec.yaml:34-35`) are forced on in every release build (`main.dart:115-131`) with no consent and no opt-out; `settings_screen.dart` has no telemetry toggle | Processing without notice under DPDP §5. The *intent* half is met; the *disclosure* half has no artefact to be met in. **Mitigation:** consent toggle + policy text. **Owner:** OWNER-TBD |
| SEC-7.02 | **Fail** | `ios/Runner/PrivacyInfo.xcprivacy` absent (verified `ls` + `git ls-files`). Required by Apple since May 2024; `shared_preferences` uses required-reason API CA92.1. Off-device transmitters: `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `firebase_crashlytics`, `firebase_performance`, `razorpay_flutter`, `speech_to_text`, `flutter_tts`, `cached_network_image`, `http`, `share_plus`, `printing` | **App Store rejection.** Unchanged for three rounds and more urgent now that camera and photo library function. **Mitigation:** author the manifest. **Owner:** OWNER-TBD · **Due:** before submission |
| SEC-7.03 | **Warning** | `pubspec.lock` committed. `functions/package-lock.json` **absent** — `git ls-files functions/` → `.gitignore`, `README.md`, `index.js`, `package.json`. No `.github/dependabot.yml`. `.github/workflows/ci.yml` has no scanning step (its only "audit" hit is a comment at `:31`). `dio: ^5.8.0+1` declared, never imported | The function holding the Anthropic key has an unpinned dependency tree. **Mitigation:** commit the lockfile; add `npm audit` + `flutter pub outdated` to CI. **Owner:** OWNER-TBD |

### §8 AI / LLM privacy

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-8.01 | **Fail** | No redaction exists, built or called. `assistant_provider.dart:95-100` → `assistant_models.dart:124-129` → `assistant_service.dart:51-55` → `functions/index.js:170-175` embeds the utterance verbatim. `patient_id` is also sent and never read (SEC-1.02). The feature's purpose is free-form Hinglish symptom description | Raw symptom text to a third-party model with no minimisation and no approved basis. **Mitigation:** strip `patient_id`; document the basis. **Owner:** OWNER-TBD |
| SEC-8.02 | **Fail** | Off by default (`assistant_service.dart:36`, active only when `--dart-define=ASSISTANT_API_URL` is set) — but that is a **build-time** switch, not a user control. No in-app toggle, no disclosure that a third-party LLM processes the user's words, no policy artefact in the repo to disclose it in | Opt-in/opt-out behaviour cannot be said to match the risk when neither exists. **Mitigation:** in-app toggle + policy text. **Owner:** OWNER-TBD |
| SEC-8.03 | **Warning** | Structurally constrained: `functions/index.js:166-169` `json_schema`, `max_tokens: 512`, closed action enum at `:66-80`. `reply_text` (`assistant_models.dart:94-98`) is rendered with no control-char strip and no client-side length cap | Low practical risk today (closed enum, on-device executor); high the moment the function becomes tool-using. **Mitigation:** sanitize + cap at the model boundary. **Owner:** OWNER-TBD |
| SEC-8.04 | **Pass — contingent** | Input capped at 1000 chars (`functions/index.js:128-129`); `role` allowlisted (`:142-149`); structured JSON output; system prompt cached separately from user content (`:159-165`); the app-side executor independently re-checks permissions. Verified this round: `place_call` resolves the number through an **app-side contacts table** (`assistant_executor.dart:475-491` `contacts[target]`), not a model-supplied string, and `assistant_provider.dart:138` fires `onPlaceCall` only after `confirmPending` — human approval for the one consequential action | **The Pass is contingent on the executor staying on the device.** If tools move server-side, this becomes a Fail with no code change to this file: attacker-asserted `role`, attacker-supplied `patient_id` as the authorization decision, `place_call` with `target: "sos"` reachable anonymously. **Owner:** OWNER-TBD |
| SEC-8.05 | **Fail** | `functions/index.js:112-119` — `onRequest`, `cors: true`, `timeoutSeconds: 30`. `grep -n "verifyIdToken\|appCheck\|rateLimit" functions/index.js` → only `116: cors: true`. `assistant_service.dart:53` sends only `Content-Type` | **Release blocker.** Anyone who learns the URL POSTs unlimited requests billed to the owner's Anthropic account, browser-drivable from any origin. **Mitigation:** App Check + `verifyIdToken` + per-uid daily cap + explicit CORS origins. **Owner:** OWNER-TBD |

### §9 Privacy policy & store/site disclosure

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-9.01 | **Warning** | In-app linking is done well: an un-prechecked consent gate before the CTA enables (`login_screen.dart:25,48-60,177-196,272-277`) with tappable Terms and Privacy Policy, plus Settings → About → `https://housepital.in/privacy`. Whether that URL resolves, and whether it is set in App Store Connect, is **BLOCKED-OWNER** | The wiring is right; the destination is unverified. **Mitigation:** confirm the URL loads. **Owner:** OWNER-TBD |
| SEC-9.02 | **BLOCKED-OWNER** | The policy text is not in the repo (`git ls-files \| grep -i privacy` → only the two audit reports), so it cannot be compared to the code | When reviewing it, confirm it covers: Firebase Storage upload of chat/concern photos **and that download URLs are unauthenticated bearer links**; Crashlytics + Performance; off-device speech recognition; Anthropic LLM processing; the on-device pending-deletion record; **and, new this round, per-patient order keys and `__quarantine_v1_*` blobs, both retained indefinitely** |
| SEC-9.03 | **Fail** | `ios/Runner/PrivacyInfo.xcprivacy` absent — the machine-readable half is independently verifiable from the repo and is missing. Photos and User Content must now be declared | **App Store rejection.** **Mitigation:** author the manifest, then reconcile with App Store Connect answers. **Owner:** OWNER-TBD |
| SEC-9.04 | **Fail** | `grep -c ITSAppUsesNonExemptEncryption ios/Runner/Info.plist` → **0** | Blocks every TestFlight/App Store upload with a manual question, or an incorrect answer. The app uses only standard HTTPS/TLS and qualifies for the exemption. **Mitigation:** `<key>ITSAppUsesNonExemptEncryption</key><false/>`. **Owner:** OWNER-TBD |

### §10 Regulatory

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-10.01 | **Warning** | DPDP cited in code (`delete_account_screen.dart:19-22`) and the deletion flow behaves like a §12 flow. Still no notice text, no lawful-basis record, no rights matrix, no grievance officer (§13), no breach runbook, no `docs/` artefact | Citation is not a compliance position. **Mitigation:** a DPDP obligations register. **Owner:** OWNER-TBD |
| SEC-10.02 | **Warning** | Login consent gate is real and well-implemented; deletion screen fully bilingual (27 `delete_account*` keys in both `en.json` and `hi.json`). No granular purpose-specific consent for Crashlytics/Performance (forced on), cloud LLM, or off-device speech. Defaults are not the most privacy-preserving | **Mitigation:** granular toggles, default off. **Owner:** OWNER-TBD |
| SEC-10.03 | **Warning** | No age gate. Not *directed* at children, which is defensible, but nothing prevents adding a minor via `app_provider.dart:226-230` `addPatient` — and a paediatric home-care patient is a realistic case for this product | DPDP §9 verifiable-parental-consent duty unaddressed. **Mitigation:** record the position. **Owner:** OWNER-TBD |
| SEC-10.04 | **Warning** | Good instincts by construction — Firestore `asia-south1`, function region `asia-south1` (`functions/index.js:115`). But data leaves India: Anthropic's API, Crashlytics/Performance, Apple/Google speech. None disclosed or contractually documented | **Mitigation:** transfer record per processor. **Owner:** OWNER-TBD |

### §11 Deletion & retention

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-11.01 | **Warning** | Materially better than round 2 and the copy is defensible: `_recordDeletionRequest` writes first (`delete_account_screen.dart:78-93,101-104`), `user.delete()` removes the credential (`:126-133`), `SessionScope.clearSession` + `logout()` follow (`:143-145`), and the dialog separates DONE from REQUESTED (`:148-168`). Not Pass because no server-side erasure occurs and nothing is transmitted; and `delete_account_done_device` still overclaims — three counterexamples survive: the preserved `housepital_pending_deletion` record, sandbox image files (`grep -rn "\.delete()" lib/` → one hit, the Firebase credential), and now `__quarantine_v1_*` if the migration ran before deletion | **Mitigation:** amend the copy to *"your Housepital data on this phone"* + name the retained record. **Owner:** OWNER-TBD |
| SEC-11.02 | **Fail** | No server-side deletion, so no cascade exists. Named orphan sets: Storage blobs (`firebase_service.dart:133-138`) and the `getDownloadURL()` bearer URLs persisted into chat records (`chat_screen.dart:151-153`) — fetchable by anyone holding them **regardless of any rule**. On-device: no file is ever deleted | Deleted accounts leave permanently fetchable medical photographs. **Mitigation:** delete objects, not just rules. **Owner:** OWNER-TBD |
| SEC-11.03 | **Fail** | No DPDP §11 portability path. The handover and invoice PDFs are clinical/financial artefacts, not an export — and the handover one is sourced entirely from `DemoData` (`handover_report_service.dart:109-116`) | DPDP data-principal right unimplemented. **Owner:** OWNER-TBD |
| SEC-11.04 | **Fail — worse than round 3** | Only TTL in the codebase is `CacheService._ttlMinutes = 30`. Indefinite, undocumented retention now covers: orders, assessments, addresses, reminders, chat, vitals, uploaded images, notification preferences, `housepital_pending_deletion` — **plus two escalations this round**: `housepital_orders_*` / `housepital_assessments_*` accumulating one entry per patient ever served (V3), and `__quarantine_v1_*` now written with live PHI by a shipped migration (V4) | The one control that measurably regressed. **Mitigation:** stamp quarantine entries with a creation time and reap; add `__quarantine_` and stale patient prefixes to `SessionScope`'s sweep; define a retention window and name it in the policy. **Owner:** OWNER-TBD · **Due:** before the second migration ships |

### §12 Hardening & incident readiness

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-12.01 | **Warning** | Client-side validation present. All requests `jsonEncode`d, never concatenated. Firestore writes type/length-checked (`firestore.rules:74-75`); Storage writes size/type-checked (`storage.rules:68-71`) — with the caveat that `contentType` is client-asserted and both call sites hardcode `'image/jpeg'` regardless of the bytes | The REST backend is out of repo (BLOCKED-OWNER), so the server half is unverified. **Owner:** OWNER-TBD |
| SEC-12.02 | **Warning** | UI is clean: `paginated_list.dart:89` captures `e.toString()` into state but the render path (`:140-150,213-223`) shows a generic retry affordance. `main.dart` replaces `ErrorWidget.builder`. **The logs are not clean** — SEC-2.03 | **Owner:** OWNER-TBD |
| SEC-12.03 | **Fail** | `grep -rn "audit_log\|auditLog\|AuditEvent" lib/ functions/` → zero. Nothing records who exported a handover PDF, who opened medical documents, when a role changed, or who requested deletion — a user-visible action that issues a reference number (`delete_account_screen.dart:80-81`) backed by nothing | No forensic capability. **Mitigation:** an append-only event log for exports, role changes, deletion. **Owner:** OWNER-TBD |
| SEC-12.04 | **Fail** | No `SECURITY_REVIEW.md`, no incident runbook, no key-rotation procedure beyond the Anthropic note. Combined with the missing inventory (SEC-1.01) and missing audit log, blast radius is unknowable. **Two components added this round:** the per-patient key space accumulating on disk, and `__quarantine_v1_*` | **Mitigation:** the inventory unblocks this. **Owner:** OWNER-TBD |

### §13 Threat modeling and security requirements — **(first look)**

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-13.01 | **Fail** | Fragments exist and some are genuinely good — `storage.rules:14-59` is an unusually honest trust-boundary note, `docs/ARCHITECTURE.md` documents eleven providers and the storage/payment contracts, `session_scope.dart:22-43` documents one data flow. But there is no document naming assets, threat actors, entry points, privileged actions or abuse cases, and none was produced when architecture changed this round (storage keying, session fan-out, migration layer all moved in `13e3656`) | The control explicitly requires review *when architecture changes*; this release changed it and no review exists. **Mitigation:** one STRIDE pass over the four trust boundaries (device store, Storage bucket, Firestore, assistant function). **Owner:** OWNER-TBD |
| SEC-13.02 | **Fail** | No control register with stable IDs in the repo. The audit reports use ad-hoc, round-local IDs (B-1, R3-2, H-10) that **renumber between rounds** — round 3's B-1 is round 2's B-2 — so traceability across rounds is manual. No mapping from any control to a test. Demonstrated concretely this round: the B-6/R3-2 fix landed with **zero** tests (V1d) and nothing detected that | Findings cannot be tracked to closure; a fix and its verification are not linked. **Mitigation:** adopt the SEC-x.xx IDs as the register and map each to a test or an accepted risk. **Owner:** OWNER-TBD |
| SEC-13.03 | **Fail** | No misuse-case review anywhere. The app has three flows that plainly need one: `place_call` with `target: "sos"` (emergency dispatch to an address), `raise_concern` against a **named nurse** with SLA-triggered callback, and cross-patient evidence injection into another patient's concern batch made permanent by `storage.rules:85` | Harassment and fraud vectors against staff and patients are unmodelled. **Mitigation:** abuse-case pass on SOS, concerns, and Storage writes. **Owner:** OWNER-TBD |
| SEC-13.04 | **BLOCKED-OWNER** | Staff/admin tooling is `../housepital-api` (Laravel) and `../housepital-backend`, out of this repo's audit artefact. What is visible from here: staff-side tooling reads `concerns/*` and `chat/*` through the Admin SDK, which **bypasses Security Rules entirely**, so the injected-evidence attack (SEC-6.04) lands in an admin surface with no rule between | Needs the staff-app authorization model and admin-role matrix to grade |

### §14 Cryptography and key lifecycle — **(first look)**

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-14.01 | **Pass** | `grep -nE "crypto\|encrypt\|pointycastle" pubspec.yaml` → **no match**. The app implements no cryptography of its own: TLS is platform, auth crypto is the Firebase SDK, payment crypto is Razorpay's. No custom algorithm or protocol exists to review | — |
| SEC-14.02 | **Warning** | No app-managed key material, so randomness and logging are not at issue. But keys are **not scoped by environment**: one Firebase project serves dev, CI and production (SEC-4.04), and the Razorpay key is compiled in per build | Scoping half of the control is unmet. **Mitigation:** per-environment projects and keys. **Owner:** OWNER-TBD |
| SEC-14.03 | **Fail** | No rotation, revocation, backup, recovery, expiry, compromise-response or algorithm-migration procedure exists for any production key or certificate. The only recorded position is `CLAUDE.md:47` on the Anthropic secret — a location statement, not a lifecycle. Firebase and Razorpay keys cannot rotate without a client release (SEC-4.05); iOS signing/provisioning lifecycle is unrecorded | On compromise there is no defined action. **Mitigation:** a key register with owner and rotation path per key. **Owner:** OWNER-TBD |
| SEC-14.04 | **N/A** | **Rationale:** the app performs no application-layer encryption — nothing to which integrity, authentication, nonce/IV uniqueness or replay protection could apply. All confidentiality and integrity are provided by TLS and by the Firebase/Razorpay SDKs, graded under SEC-3.04 and SEC-14.01. Graded N/A because the control's subject matter is absent by design, not because it was untested. **This flips to in-scope the moment SEC-2.01 is fixed with field encryption** | — |

### §15 Mobile and client platform hardening — **(first look)**

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-15.01 | **Pass** | No custom URL scheme (`grep -n CFBundleURLTypes ios/Runner/Info.plist` → no match), no universal links (no `associated-domains`), no `applinks`. `AndroidManifest.xml` declares one `intent-filter` (`:27-30`) on the single `android:exported="true"` component (`:12`) — the standard `MAIN`/`LAUNCHER` activity. No content or document provider. No IPC surface. The one place external input could reach a launcher, `assistant_screen.dart:36-41` `_dial`, resolves its number through an app-side lookup table (`assistant_executor.dart:491` `contacts[target]`), not from the model | — |
| SEC-15.02 | **Fail** | No `FLAG_SECURE`, no iOS privacy screen, no app-switcher masking (`grep` → zero, SEC-2.04). Backups permissive by default (SEC-2.05). **Notifications carry PHI by design** — `medication_reminder_service.dart:147-183` puts the medication name in a lock-screen notification, which is precisely the exposure round 3 found and the SessionScope fix only partly contains (V1). `Clipboard.setData` at `sos_screen.dart:149` copies the patient's address and `:273` a phone number into the general pasteboard with no expiry or `UIPasteboardOptions` | Care data visible on a locked shared phone, in the app switcher, in screenshots, and in the pasteboard. **Mitigation:** `FLAG_SECURE`/privacy screen on PHI routes; consider notification content redaction on the lock screen. **Owner:** OWNER-TBD |
| SEC-15.03 | **N/A** | **Rationale:** the app contains no WebView. `grep -rn "webview\|WebView" lib/ pubspec.yaml` → **no match**; no `webview_flutter`, no `flutter_inappwebview`, no script bridge, no untrusted HTML rendering surface. Graded N/A because the component does not exist, verified by command, not because it was untested | — |
| SEC-15.04 | **Warning** | No archive handling exists (no zip/tar/extract in `lib/`), so decompression-bomb and path-traversal surfaces are absent. What is real: `image_picker` copies user files into the app sandbox and **nothing ever deletes them** (`grep -rn "\.delete()" lib/` → one hit, the Firebase credential at `delete_account_screen.dart:131`); `chat_screen.dart:132` preserves the user's original basename verbatim into the Storage object key, so a filename like `mother_biopsy_report.jpg` becomes part of a path that is also logged (SEC-2.03); and `share_plus`/`printing` export PDFs with no role gate (SEC-6.05) | Unintended sharing is the live half of this control. **Mitigation:** generate opaque object names; delete sandbox copies after upload. **Owner:** OWNER-TBD |
| SEC-15.05 | **Warning** | No jailbreak/root detection, no obfuscation flag, no runtime-integrity check anywhere; no `--obfuscate` in any documented build command. The control asks for these to be **risk-assessed rather than assumed to replace server authorization** — and no assessment exists in any form | Defensible on the merits (client integrity is not a substitute for the server authorization this app lacks), but the *reason* it is defensible is itself a Fail at SEC-6.03. **Mitigation:** record the decision and its dependency. **Owner:** OWNER-TBD |

### §16 API authorization and abuse resistance — **(first look)**

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-16.01 | **Fail** | Object-, property- and function-level authorization is enforced **nowhere** server-side. The only server the repo controls is `functions/index.js`, which authenticates nothing (SEC-8.05). Rules-layer authorization is non-isolating for Storage (`storage.rules:75,83`) and keyed on an always-false predicate for Firestore (12 `uid` refs vs 0 in `lib/`). No test across tenants, roles, ownership or indirect identifiers exists — 0 rules tests in 104 files | Nothing on the server side distinguishes one patient from another. **Mitigation:** the `user_patients` custom-claim mapping unblocks Storage, Firestore and the assistant simultaneously — the highest-leverage single item in this audit. **Owner:** OWNER-TBD |
| SEC-16.02 | **Warning** | No webhook receiver in the repo (`razorpay_flutter` runs in demo mode with a placeholder key). The one server endpoint takes a fixed four-field body with a hard `role` allowlist (`functions/index.js:142-149`) and a 1000-char cap, so mass assignment and SSRF have no obvious surface. **But none of it is tested**, and `patient_id` is an attacker-supplied field that is currently ignored only by accident of architecture (SEC-8.04) | Unverified rather than known-good. **Mitigation:** negative tests on the function's body handling. **Owner:** OWNER-TBD |
| SEC-16.03 | **Fail** | Sensitive flows with no bot/fraud/resource controls: OTP signup (client-side 30 s resend cooldown only; server-side SMS quotas BLOCKED-OWNER), the assistant (unauthenticated, unmetered — SEC-8.05), PDF export (ungated — SEC-6.05), account deletion (unlogged, unrate-limited), and Storage upload (unlimited 10 MB objects per authenticated account, billed to the owner) | Direct financial exposure via SMS pumping, Anthropic spend, and Storage cost. **Mitigation:** per-uid caps on each. **Owner:** OWNER-TBD |
| SEC-16.04 | **BLOCKED-OWNER** | No API inventory document exists in this repo. What is knowable from source: the client points at `api.housepital.in`, which does not resolve; two out-of-repo backends define overlapping entities with **incompatible schemas** (`../housepital-backend` Firebase+MySQL `housepital`; `../housepital-api` Laravel+MySQL `housepital_db`); one Cloud Function is deployed to `asia-south1`. No versioning, deprecation or debug-route record anywhere | Needs the owner's endpoint inventory and the live function URL list to grade. Note the inventory absence is itself actionable and should not wait on the owner |

### §17 Authentication lifecycle — **(first look)**

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-17.01 | **Fail** | Enrollment/verification/login/logout exist and are well built (SEC-6.01). Missing entirely: MFA or passkeys (phone OTP is the only factor), device/session review, session revocation, phone-number change, and any test of the lifecycle. Logout is incomplete on the involuntary path (V1b) and never clears `_authToken` (V2). Account deletion exists but does not revoke sessions on other devices — there is no mechanism to | A lost or handed-on phone cannot be de-authorized from anywhere else. **Mitigation:** a session list backed by `active_sessions` (already in `firestore.rules:110-118`, currently unreachable). **Owner:** OWNER-TBD |
| SEC-17.02 | **N/A** | **Rationale:** no password is collected, stored, or verified by any code path — OTP only, verified at SEC-6.02. Graded N/A because the control cannot apply. **But `firebase.json:17-18` enables `anonymous` and `emailPassword` providers that no code path uses**, which is a live Warning: an anonymous session satisfies `isSignedIn()` in `storage.rules:64-66`, converting "any patient can read/write these prefixes" into "**anyone at all** can". **Disable both before deploying `storage.rules`.** **Owner:** OWNER-TBD | — |
| SEC-17.03 | **Fail** | Phone-OTP is the sole factor with no MFA, so **SIM swap is a complete account takeover** with no second barrier. No recovery flow exists to enumerate against, which helps — but equally, there is no independent channel and **no notification to the account owner on any auth event**: `grep` finds no email/push on login, device addition, or deletion request. Support impersonation is unmodelled (SEC-13.04) | The canonical attack on this auth model is unmitigated and unnoticed. **Mitigation:** login notification via an independent channel; consider a second factor for role changes. **Owner:** OWNER-TBD |
| SEC-17.04 | **Fail** | No sensitive action requires recent or stronger authentication: handover PDF export (`handover_report_service.dart:323`), document repository share (`document_repository_screen.dart:442-448`), role change, and account deletion all proceed on an ambient session. Related and unhandled: `user.delete()` (`delete_account_screen.dart:131`) commonly **requires** a recent login, and the code has no re-auth path — it falls to the "call us" branch instead | The one place the platform *demands* re-auth is the one place the app does not offer it. **Mitigation:** `local_auth` before export; `reauthenticateWithCredential` before delete. **Owner:** OWNER-TBD |

### §18 Secure development and supply chain — **(first look)**

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-18.01 | **Fail** | `.github/workflows/` contains one file, `ci.yml`. `grep -n "audit\|snyk\|osv\|codeql\|gitleaks\|trufflehog\|semgrep"` → a single hit at `:31`, a **comment** about `--fatal-warnings`. No SAST, no secret scanning, no dependency scan, no license scan, no triage or remediation targets. `flutter analyze` runs, which is lint, not security lint | Secrets and vulnerable dependencies would reach `main` unflagged. That the four rounds of manual key scanning came back clean is a fact about this repo's history, not a control. **Mitigation:** gitleaks + `npm audit` + `flutter pub outdated` as CI gates. **Owner:** OWNER-TBD |
| SEC-18.02 | **Fail** | No SBOM, no provenance record, no signing attestation (`git ls-files \| grep -i sbom` → nothing). `pubspec.lock` is committed and `functions/package-lock.json` is not (SEC-7.03), so the dependency set of the component holding the Anthropic key is not even reproducible, let alone attested | Cannot answer "what shipped" after an incident. **Mitigation:** commit the lockfile; generate an SBOM at build. **Owner:** OWNER-TBD |
| SEC-18.03 | **Warning** | `CLAUDE.md` records the right conventions — feature branches only, never push to `main`, conventional commits — and the current branch is `fix/five-tab-nav`, consistent with them. Whether branch protection, isolated CI secrets, required review, or tamper-evident logs are actually **enforced** is not visible from the repo | Convention without evidence of enforcement. **Mitigation:** confirm branch protection and required reviews. **Owner:** OWNER-TBD / BLOCKED-OWNER for the settings themselves |
| SEC-18.04 | **Fail** | No `SECURITY.md`, no disclosure route, no intake owner, no severity model, no patch SLA, no advisory process, no emergency release path. For a health app handling PHI this is the control that turns a reported bug into a fixed one | A finder has no channel; the team has no clock. **Mitigation:** a `SECURITY.md` with an address and an SLA is an hour's work. **Owner:** OWNER-TBD |
| SEC-18.05 | **Fail** | No penetration test, no independent security review before this high-impact launch. **These audit rounds do not satisfy the control**: they are source review by the same agent chain that wrote the code, with no runtime testing, no emulator, and no adversarial execution — the brief's own MASTER-4.04 constraint | An independent review is precisely what the checklist requires for a health app pre-launch. **Mitigation:** commission one, scoped to the assistant function, Storage rules, and the OTP flow. **Owner:** OWNER-TBD · **Due:** before public launch |

### §19 Privacy engineering and incident readiness — **(first look)**

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| SEC-19.01 | **Fail** | No purpose/basis/recipient/retention/residency/deletion record exists for **any** category or processor. The processor list is derivable from `pubspec.yaml` (Google/Firebase, Anthropic, Razorpay, Apple/Google speech) but has never been written down, and retention is indefinite for every store (SEC-11.04) | The foundational artefact for DPDP §5 notice and §8 accountability. Blocks SEC-9.02, 9.03, 19.03, 19.04. **Mitigation:** this is the same document as SEC-1.01 — one artefact closes both. **Owner:** OWNER-TBD · **Due:** before submission |
| SEC-19.02 | **Fail** | Deletion request exists (`delete_account_screen.dart:78-93`) but is **not authenticated to any destination, not logged, not time-bound, and never read** (R3-5: 3 grep hits — constant, write, preserve-list). Access, correction, export, consent withdrawal and objection have no implementation at all. No test of any rights path | Every DPDP data-principal right except deletion-request is absent, and deletion-request terminates in an unread prefs key. **Mitigation:** make the record readable in Settings; give it a destination and an expiry. **Owner:** OWNER-TBD |
| SEC-19.03 | **BLOCKED-OWNER** | Processor terms with Google (Firebase/Crashlytics/Performance), Anthropic (training-use and retention terms specifically), Razorpay, and Apple/Google speech are contractual artefacts held outside the repo | Needs the executed DPAs/terms. Note the Anthropic terms matter most: patient symptom text is sent verbatim (SEC-8.01) |
| SEC-19.04 | **Fail** | No privacy impact assessment. This processing trips **four** of the control's own triggers simultaneously: sensitive (health) data, potential children's data (SEC-10.03), voice/biometric-adjacent capture, and consequential AI on the assistant path | The control names exactly this situation as requiring a DPIA. **Mitigation:** DPIA covering the assistant, notifications, and the Storage bucket. **Owner:** OWNER-TBD |
| SEC-19.05 | **Fail** | No breach detection (no audit log — SEC-12.03), no containment plan, no assessment procedure, no evidence-preservation step, no notification template, no post-incident deletion/rotation runbook, and nothing tested. `getDownloadURL()` bearer tokens make one class of breach **unrecoverable by design** — no rule change revokes them (SEC-11.02) | DPDP §8(6) requires breach notification; there is no mechanism to detect one. **Mitigation:** audit log first — it is the prerequisite for every other step. **Owner:** OWNER-TBD |
| SEC-19.06 | **Warning** | Genuine positives: DPDP §12 cited and behaviourally honoured in the deletion flow; `asia-south1` residency for Firestore and the function; fully bilingual deletion notice (27 keys × 2), which closes the §5(3) language duty. Missing: any mapping of DPDP Rules 2025 phased obligations, no grievance officer (§13), no CERT-In incident-reporting position (6-hour clock), no consent-manager consideration | Best-in-class instincts, no register. **Mitigation:** fold into the SEC-19.01 artefact. **Owner:** OWNER-TBD |

---

## MASTER-4.05 — reconciliation across artifacts

MASTER-4.05 asks for reconciliation across **eight** artifacts: data inventory, privacy policy, store
labels, privacy manifest, permissions, analytics, SDK behaviour, and network traffic.

| Artifact | Exists? | Evidence |
|---|---|---|
| Data inventory | **No** | `docs/DATA_INVENTORY.md` absent; `git ls-files \| grep -i inventory` → nothing |
| Privacy policy | **Not in any auditable form** | No policy text in the repo; only an in-app link to `https://housepital.in/privacy` (`settings` → About). Whether it resolves is BLOCKED-OWNER |
| Store labels (App Privacy / Play Data Safety) | **No** | Held in App Store Connect / Play Console; nothing in the repo mirrors them. BLOCKED-OWNER |
| Privacy manifest | **No** | `ios/Runner/PrivacyInfo.xcprivacy` absent (SEC-7.02, SEC-9.03) |
| Permissions | **Yes** | `ios/Runner/Info.plist:69,71,73,75`; `android/app/src/main/AndroidManifest.xml` |
| Analytics configuration | **Yes, in code** | `main.dart:115-131` forces Crashlytics + Performance on in release; `pubspec.yaml:34-35` |
| SDK behaviour | **Partially derivable** | The transmitting-SDK list is derivable from `pubspec.yaml`, but no per-SDK collection statement exists anywhere |
| Network traffic | **Not captured** | Source review only; no proxy capture, no release build, no runtime. See Limitations |

**Three of the eight exist. Five do not.**

**What that means for the gate — stated plainly.** MASTER-4.05 is **not a Warning; it is a Fail, and
it is unsatisfiable in principle at this commit.** Reconciliation is a comparison, and five of the
eight sides of it are missing — you cannot find a discrepancy between a manifest that does not exist
and labels that do not exist. Grading this N/A would be exactly the error the brief warns about:
absence of an artifact is not inapplicability of the control, it is failure of it.

Two consequences worth naming:

1. **The three artifacts that DO exist already disagree with each other**, and that disagreement is
   verifiable today without owner access. Permissions declare camera, photo library, microphone and
   speech recognition. Analytics configuration transmits crash and performance telemetry
   unconditionally. Neither is declared in a privacy manifest, because there isn't one. So the
   reconciliation fails on the only three sides that can currently be compared — this is not merely
   "we cannot check yet."
2. **The gate cannot be cleared by owner input alone.** BLOCKED-OWNER items (the live policy text,
   the store labels) need the owner. But the data inventory and the privacy manifest are **repo
   artifacts that only this team can author**, and both have been open for three rounds. They are the
   critical path: the inventory feeds the policy, the policy feeds the labels, and the manifest is a
   hard App Store gate independent of all of it.

---

## Scorecard

**Pass 10 · Warning 25 · Fail 41 · N/A 4 · BLOCKED-OWNER 5 — 85 controls.**

| Section | Pass | Warning | Fail | N/A | BLOCKED |
|---|---|---|---|---|---|
| §1 Data inventory & minimization | 1 | 2 | 1 | 0 | 0 |
| §2 Storage & encryption | 1 | 0 | 4 | 0 | 0 |
| §3 Data in transit | 2 | 2 | 0 | 0 | 0 |
| §4 Secrets management | 1 | 3 | 1 | 0 | 1 |
| §5 Permissions & access requests | 1 | 1 | 2 | 0 | 0 |
| §6 Authentication & access control | 1 | 1 | 3 | 1 | 0 |
| §7 Third-party SDKs & dependencies | 0 | 1 | 2 | 0 | 0 |
| §8 AI / LLM privacy | 1 | 1 | 3 | 0 | 0 |
| §9 Privacy policy & store disclosure | 0 | 1 | 2 | 0 | 1 |
| §10 Regulatory | 0 | 4 | 0 | 0 | 0 |
| §11 Deletion & retention | 0 | 1 | 3 | 0 | 0 |
| §12 Hardening & incident readiness | 0 | 2 | 2 | 0 | 0 |
| **§1–§12 subtotal (round-3 comparable)** | **8** | **19** | **23** | **1** | **2** |
| §13 Threat modeling *(first look)* | 0 | 0 | 3 | 0 | 1 |
| §14 Cryptography & key lifecycle *(first look)* | 1 | 1 | 1 | 1 | 0 |
| §15 Mobile & client hardening *(first look)* | 1 | 2 | 1 | 1 | 0 |
| §16 API authorization *(first look)* | 0 | 1 | 2 | 0 | 1 |
| §17 Authentication lifecycle *(first look)* | 0 | 0 | 3 | 1 | 0 |
| §18 Secure dev & supply chain *(first look)* | 0 | 1 | 4 | 0 | 0 |
| §19 Privacy engineering *(first look)* | 0 | 1 | 4 | 0 | 1 |
| **§13–§19 subtotal** | **2** | **6** | **18** | **3** | **3** |
| **TOTAL** | **10** | **25** | **41** | **4** | **5** |

**How to read the delta against round 3.** Round 3 graded 53 controls ✅8 / ⚠️23 / ❌20 / 1 N/A / 1
blocked. Round 4's comparable §1–§12 subtotal is Pass 8 / Warning 19 / Fail 23 / N/A 1 / BLOCKED 2.
Passes are flat at 8. **The apparent −4 Warning / +3 Fail is almost entirely vocabulary, not
regression**: Suite v2.0's Fail definition ("requirement not met") converts several round-3 ⚠️ that
were really unmet requirements with a mitigating remark — SEC-2.05 backups, SEC-7.01 undisclosed
telemetry, SEC-14.03-adjacent items. Round 3 said its own scorecard was too coarse to register real
work, and that is still true.

**One line genuinely moved for substantive reasons: SEC-11.04 retention got worse** (V3 + V4). One
line moved better in substance without moving grade: SEC-6.04's notification component (V1a).

**The other honest number: 41 Fails across 85 controls, 18 of them in sections never audited before.**
The §13–§19 result is not a surprise and should not be read as a collapse — it is the predictable
shape of a pre-launch app measured for the first time against threat modeling, key lifecycle, API
authorization, auth lifecycle, supply chain and privacy engineering. It does mean the gate cannot be
argued down to the §1–§12 picture.

---

## Release blockers (every Fail, grouped by fix)

Forty-one Fails is not forty-one workstreams. They collapse into **nine**:

1. **The `user_patients` → custom-claim mapping.** Closes or unblocks SEC-6.03, 6.04, 6.05, 16.01,
   and makes SEC-8.04's Pass unconditional. Deferred at `firestore.rules:151` and
   `storage.rules:35-43`. **Single highest-leverage item in this audit, third round running.**
2. **Authenticate the Cloud Function.** SEC-8.05, 16.03. App Check + `verifyIdToken`, patient id from
   claims not the body, explicit CORS origins, per-uid spend cap. Mandatory *before* any tool moves
   server-side.
3. **Redact the logs.** SEC-2.03, and it is the chain that makes SEC-11.04's key names attackable
   (V3). One `redact()` chokepoint in `logger.dart:55-63`.
4. **Author the data inventory.** SEC-1.01, 19.01 directly; unblocks 9.02, 9.03, 19.04, 12.04.
5. **Author `PrivacyInfo.xcprivacy` + set `ITSAppUsesNonExemptEncryption`.** SEC-7.02, 9.03, 9.04.
   Hard App Store gates, open three rounds, hours of work.
6. **Role-gate the exports in code.** SEC-6.05, 17.04. Gate at the service, not the widget.
7. **Bound retention.** SEC-11.04, 15.04, and V3/V4: timestamp + reap `__quarantine_*`, add
   `__quarantine_` and stale `housepital_orders_*` / `housepital_assessments_*` prefixes to
   `SessionScope`'s sweep, delete sandbox image copies, define and publish a window.
8. **Harden the device surface.** SEC-2.01, 2.04, 2.05, 15.02. `allowBackup="false"` is one line and
   the cheapest single risk reduction in this list.
9. **Stand up the governance artifacts.** SEC-13.01–13.03, 18.01, 18.02, 18.04, 18.05, 19.02, 19.04,
   19.05. Threat model, CI security gates, SBOM, `SECURITY.md`, DPIA, breach runbook, independent
   review. Individually small, collectively the difference between a product and a compliant one.

**Additionally, and not a code fix:** `CLAUDE.md:55` must be corrected before `storage.rules` is
deployed. Round 3 made it condition 1 of 3; the round-4 documentation commit rewrote the surrounding
section and left it (V5). It is a one-line edit that has now survived a dedicated documentation pass.

---

## Warnings requiring risk acceptance

All 25 Warnings carry impact and mitigation in the tables above with **OWNER-TBD**. The six that need
a named approver before ship, rather than a ticket:

| # | Warning | Why it needs acceptance, not just a ticket |
|---|---|---|
| W-1 | **SEC-6.06 / V1b — involuntary logout bypasses `SessionScope`** (`auth_provider.dart:112`) | Latent only because `api.housepital.in` does not resolve. Becomes a Fail on the day the backend lands, with no code change to make it one. Accept only with a dated commitment to fix before backend cutover |
| W-2 | **SEC-11.01 / V3 — per-patient order keys accumulate unbounded** | A correct fix with an unrecorded consequence. Accepting it means accepting that a four-patient family phone holds four complete order histories in plaintext until someone logs out |
| W-3 | **SEC-4.01/4.02 — Firebase config tracked, 3 `AIza…` in history** | Settled and correctly reasoned across four rounds. Accept formally so round 5 does not re-litigate it. **Conditional on SEC-4.06** (console restrictions) being confirmed |
| W-4 | **SEC-17.02 — `anonymous` + `emailPassword` enabled** (`firebase.json:17-18`) | Not really acceptable — it converts `storage.rules`' "any patient" into "anyone at all". **Disable before deploying `storage.rules`**, do not accept |
| W-5 | **SEC-5.03 — off-device speech not disclosed** | A patient describing symptoms aloud is not told the audio may leave the device. Needs an owner decision on `onDevice: true` versus amending the string |
| W-6 | **SEC-10.03 — no age gate** | "Not directed at children" is defensible for the marketing position but not for the product: `addPatient` accepts a paediatric patient. Needs an explicit recorded position, not silence |

**Owner decisions, measured and NOT graded as Fails**, per the brief: white on Housepital orange
(2.33:1), manpower prices shown and directly bookable, the floating glass pill nav. None has a
security or privacy consequence and none appears in this scorecard. The Razorpay placeholder-key
simulated checkout is by design; the CI key `rzp_test_ci_dummy_key` is deliberately not a
placeholder — verified, not a finding.

---

## BLOCKED-OWNER — needs access I do not have

Round 3's twelve items stand unchanged; I re-verified that none is answerable from the repo at
`9127713`. Rather than restate them, the additions and the changes:

| # | Item | Exactly what is needed | Status vs round 3 |
|---|---|---|---|
| 1 | Live Firebase Storage rules | Console → Storage → Rules, full text | Unchanged. Still gates the deploy decision |
| 2 | Live Firestore rules vs repo | Console → Firestore → Rules | Unchanged |
| 3 | Firebase API key restrictions (SEC-4.06) | GCP → Credentials → each of 3 `AIza…` → Application + API restrictions | Unchanged |
| 4 | App Check enforcement status | Firebase Console → App Check | Unchanged |
| 5 | Is anonymous auth enabled in the console? | Confirm and disable (W-4) | Unchanged, and more urgent if `storage.rules` deploys |
| 6 | SMS/OTP abuse protection & quotas | Auth → Settings → SMS region policy | Unchanged; now also SEC-16.03 |
| 7 | Privacy policy live and accurate (SEC-9.02) | `https://housepital.in/privacy` + its text | **Extended:** must now also cover per-patient order keys and `__quarantine_v1_*` retention |
| 8 | App Store Connect App Privacy answers (SEC-9.03) | Screenshot of the App Privacy section | Unchanged |
| 9 | Backend REST API authorization (SEC-16.01/16.04) | `api.housepital.in` server-side authz, rate limiting, validation | Unchanged |
| 10 | Anthropic account spend limit (SEC-8.05) | Console budget cap | Unchanged |
| 11 | Does `user.delete()` succeed in practice? (SEC-17.04) | Run deletion on a session older than ~5 min; record the branch at `delete_account_screen.dart:156` | Unchanged |
| 12 | Does a deletion request have a destination? (SEC-19.02) | Confirm 9990-911-911 reaches someone who can action an erasure | Unchanged |
| **13** | **Admin/support tooling threat model (SEC-13.04)** | Staff-app authorization model + admin role matrix from `../housepital-api` | **New.** Admin SDK reads of `concerns/*` bypass rules entirely, so the injected-evidence attack lands in an admin surface |
| **14** | **Processor terms (SEC-19.03)** | Executed DPAs/terms for Google, **Anthropic (training-use + retention specifically)**, Razorpay, Apple/Google speech | **New.** Patient symptom text is sent verbatim; the Anthropic terms are load-bearing |
| **15** | **Branch protection & CI secret isolation (SEC-18.03)** | GitHub → Settings → Branches; Actions secret scoping | **New** |
| **16** | **Production patient-id shape (V3)** | One real `Patient.id` from the API. If it resembles `pat_demo_rajesh`, the prefs key namespace names patients in cleartext | **New.** Determines whether V3's key-naming finding is Warning-grade or worse |

---

## Limitations of this audit

- **MASTER-4.04 is not satisfied and this is stated as a constraint, not a pass.** Evidence should
  come from the release artifact in a production-like environment. **This audit reviewed SOURCE at
  commit `9127713` only.** No release build was produced, no IPA/APK inspected, no device or
  simulator exercised, no network traffic captured, no Firebase emulator run. Per the brief,
  `flutter test`, `flutter build`, `flutter clean` and `pod install` were **not** run — many agents
  run concurrently. Cited central results: `flutter analyze` clean, design gate passes, 1,819 tests
  pass across 101 test files (I counted 104 `.dart` files under `test/`; the 101 figure is the
  brief's and I did not reconcile it). Test **sources** were read for coverage findings.
- **Every runtime claim in this report is analysis, not observation.** Specifically unproven and
  flagged where they appear: that `listAll()` on a two-segment Storage prefix is denied (V6/SEC-6.04
  — round 3's load-bearing assumption, still with zero rules tests in 104 files); that
  `MedicationReminderService.init()` always completes so `cancelAllReminders` is not a silent no-op
  (V1c); that the `housepital_orders__none` window is never written to (V3).
- **BLOCKED-OWNER items are graded BLOCKED-OWNER, never N/A.** Four controls are graded N/A
  (SEC-6.02, 14.04, 15.03, 17.02); each carries a written rationale that the control's subject matter
  is **absent by verified command**, not that it went untested.
- **Two backends are out of scope of the artifact under audit.** `../housepital-backend` and
  `../housepital-api` exist and define patients/staff/deployments/attendance/vitals/daily_reports
  with **incompatible** schemas; the app is pointed at neither and `api.housepital.in` does not
  resolve. Their server-side authorization, rate limiting and input validation could not be graded
  from this repo (SEC-16.01, 16.04, 13.04). **The app ships as a demo-data build** — `DemoData`
  fallbacks serve every provider — which materially lowers today's live exposure on several controls
  and is noted inline where it does.
- **§13–§19 (32 controls) had no prior baseline.** They are graded here for the first time. Where a
  Fail reflects an absent governance artifact rather than a defective code path, that is said in the
  evidence column so the two are not conflated.
- **The audit reports themselves do not satisfy SEC-18.05.** They are source review by the same agent
  chain that produced the code, without runtime or adversarial execution. That control needs an
  external party.

---

*Round-4 read-only audit against commit `9127713`. No source file was modified. Rounds 2 and 3 were
read and left untouched, per MASTER-1.04.*
