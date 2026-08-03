# Security & Privacy Checklist (App-Agnostic) — Audit round 2 vs commit `820060b`

**Date:** 2026-08-03 · **Previous round:** commit `803124d` · **Branch:** `fix/five-tab-nav`
**Scope:** Flutter/Dart client (`lib/`, `ios/`, `android/`), Cloud Function (`functions/`), Firestore + **Storage** rules, full git history (all refs).
**Method:** read-only. Every verdict cites a `file:LINE` or a command with its output. No source file was modified.
**Context:** healthcare app handling patient medical data in India → PHI leakage is top-severity; India DPDP Act 2023 assessed alongside the checklist.

> **Item count correction.** Round 1 labelled the checklist "49 items"; counting the boxes in the
> source checklist gives **53** (§1=4 §2=5 §3=4 §4=6 §5=4 §6=6 §7=3 §8=5 §9=4 §10=4 §11=4 §12=4).
> Round-2 totals below use 53. Round-1 per-section grades are otherwise comparable.

---

## Changed since round 1

| Round-1 finding | Status now | Evidence |
|---|---|---|
| **B-1** No Storage rules at all | ⚠️ **REPLACED BY A WORSE-SHAPED PROBLEM** — rules now exist but are **provably unsatisfiable by this app's own uploads**; deploying them breaks chat + concern photo upload 100% | `storage.rules:51-53,76,78` vs `chat_screen.dart:135`, `raise_concern_screen.dart:330`, `demo_data.dart:29` — see **B-1** |
| **B-2** Missing iOS camera/photo usage strings | ✅ **FIXED** | `ios/Runner/Info.plist:73-76` — both keys present, wording clinical and specific |
| **B-3** Assistant Cloud Function unauthenticated, wildcard CORS | ❌ **UNCHANGED** | `functions/index.js:107-114` — still `onRequest` + `cors: true`, no `verifyIdToken`, no App Check, no quota |
| **B-4** PHI in release logs | ❌ **UNCHANGED** | `logger.dart:55-59` still strips only debug/info and interpolates `$error`; `staff_role_card.dart:312-315` still `debugPrint`s the care-needs checklist; `main.dart:288-291` still dumps error+stack on web release |
| **B-5** No account deletion | ⚠️ **PARTIALLY FIXED** — an in-app flow now exists, but it transmits nothing and the success copy asserts a server-side deletion that no component performs | `delete_account_screen.dart:53-59` (`Future.delayed` + `TODO(backend)`) vs the claim at `:74-78` — see **B-5** |
| **B-6** Sensitive exports not role-gated in code | ❌ **UNCHANGED** | `handover_report_service.dart:302-305` still has no role param; `invoice_pdf_service.dart:261-264` still ungated and `my_orders_screen.dart:389-393` now comments the gap as intentional ("downloadable invoice (always)"); `document_repository_screen.dart` still has zero `canUserPerform` |
| **H-3** `logout()` leaves PHI in memory | ⚠️ **PARTIALLY FIXED** — `SessionScope` covers 5 providers and is correctly wired at both sites, but **6 PHI-bearing stores are outside it** and `ApiService._authToken` is still never cleared | `session_scope.dart:28-43`; misses listed in **H-3** |
| **M-1** `google-services.json` + `firebase_options.dart` tracked; `CLAUDE.md` claim wrong | ⚠️ **RE-CONFIRMED (files) / ✅ FIXED (doc)** | `git ls-files` still returns both files; 3 `AIza…` keys in history. `CLAUDE.md` now states this accurately |
| `ANTHROPIC_API_KEY` server-side only | ✅ **RE-CONFIRMED CLEAN** on every ref | 4 commands, all empty output — see Task-1 |
| — | 🆕 **NEW: doctor-handover PDF is built entirely from `DemoData` with no sample-data marking** — the demo banner covers screens but not the one artifact that leaves the app and reaches a clinician | `handover_report_service.dart:95,101-108`; no `DemoMode.markServingDemoData()` and no watermark anywhere in the file |
| — | 🆕 **NEW: `health_manager_banner.dart:83` passes a STAFF id as `patientId`** into `/chat`, so the Firestore thread key and the Storage ownership segment become a staff identifier | `health_manager_banner.dart:83` |
| — | 🆕 **CORRECTION to round 1: `firestore.rules` isolation model does not match the app's identifiers either.** Round 1 graded it "genuinely good"; tracing `patientId` shows it is never a Firebase uid, so `auth.uid == patientId` fails everywhere | `firestore.rules:67,70,72,90,94,99,133` vs `home_screen.dart:781` |
| — | 🆕 `StoreMigrator` quarantine has **zero call sites** — the retention risk is latent, not active | `grep -rn quarantine lib/ test/` → only `store_migrator.dart` |
| — | 🆕 The isolation test's name overclaims: *"clearPatientScopedData nulls **every** per-patient field"* asserts 7 fields and misses 2 that survive | `test/providers/patient_scope_isolation_test.dart:63-84` |

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A | Δ vs round 1 |
|---|---|---|---|---|---|
| 1. Data inventory & minimization | 1 | 2 | 1 | 0 | — |
| 2. Storage & encryption | 1 | 1 | 3 | 0 | — |
| 3. Data in transit | 2 | 2 | 0 | 0 | — |
| 4. Secrets management | 1 | 4 | 1 | 0 | — |
| 5. Permissions & access requests | 1 | 1 | 2 | 0 | **+1 ✅** (B-2 fixed) |
| 6. Authentication & access control | 1 | 1 | 3 | 1 | **−1 ⚠️ / +1 ❌** (isolation regraded) |
| 7. Third-party SDKs & dependencies | 0 | 2 | 1 | 0 | — |
| 8. AI / LLM privacy | 1 | 2 | 2 | 0 | — |
| 9. Privacy policy & store disclosure | 0 | 1 | 1 | 2 (BLOCKED-OWNER) | — |
| 10. Regulatory | 0 | 4 | 0 | 0 | **+1 ⚠️** (DPDP now cited in code) |
| 11. Deletion & retention | 0 | 1 | 3 | 0 | **+1 ⚠️** (B-5 partial) |
| 12. Hardening & incident readiness | 0 | 2 | 2 | 0 | — |
| **TOTAL (53 items)** | **8** | **23** | **19** | **1 + 2 blocked** | ✅ 8→8 · ⚠️ 21→23 · ❌ 21→19 |

Net: **two failures converted to partials, one failure converted to a pass, one partial regraded down.**
Nothing in the round-2 diff introduced a *new* code-level vulnerability — but the single most
important new artefact (`storage.rules`) is functionally wrong, and the second (`delete_account_screen.dart`)
makes a factual claim to the user that the code does not honour.

---

## Task-1 result: SECRET SCAN — re-run verbatim on `820060b`

### `ANTHROPIC_API_KEY` — ✅ **RE-CONFIRMED CLEAN.** Server-side only.

```
$ git log --oneline --all -S "ANTHROPIC" -- lib/ ios/
(NO OUTPUT — the string has never existed in lib/ or ios/ on any ref)

$ git log -p --all | grep -oE "sk-ant-[A-Za-z0-9_-]{20,}" | sort -u
(NO OUTPUT — no real Anthropic key in any commit, on any ref)

$ git log -p --all | grep -oE "(AKIA[0-9A-Z]{16}|sk_live_[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)" | sort -u
(NO OUTPUT — no AWS, Stripe, GitHub, Slack, or private-key material in any commit)
```

The key exists only as `defineSecret` (`functions/index.js:21`), attached at `:109`, resolved at
`:152`. It cannot ship in the binary. **Unchanged from round 1 and independently re-verified.**

### Firebase client config — ⚠️ **RE-CONFIRMED TRACKED.** Doc claim now correct.

```
$ git ls-files | grep -iE "GoogleService|google-services|firebase_options"
android/app/google-services.json          ← STILL TRACKED
lib/config/firebase_options.dart          ← STILL TRACKED

$ git log -p --all | grep -oE "AIza[A-Za-z0-9_-]{35}" | sort -u | wc -l
       3      ← 3 distinct Firebase Web API keys still in history (web / android / ios)
```

The iOS plist remains correctly untracked. `CLAUDE.md` now states this accurately (the round-1
"Firebase plists are gitignored" falsehood is gone) — **doc finding closed, file finding open.**
Severity stays **Medium**: these are public-by-design client identifiers whose safety rests on
(a) Security Rules and (b) console key restrictions. (a) is now *worse than absent* for Storage —
see B-1. (b) is still **BLOCKED-OWNER**.

---

## Findings

### 1. Data inventory & minimization

- ❌ **Every piece of personal data the app stores is listed.** Still no inventory. `ls docs/` shows 15 docs + `docs/audits/`; none enumerates personal/health data, and there is still no `SECURITY_REVIEW.md` as the checklist's closing instruction requires. `grep -rlIi "DPDP|GDPR|data inventory" docs/ *.md` matches only three **audit reports** — analysis, not a compliance artefact. — **Impact:** App Privacy answers and DPDP §5 notice cannot be completed accurately; blast radius of a breach is unknowable. — **Fix:** `docs/DATA_INVENTORY.md` listing field → store (prefs key / Firestore path / Storage path) → purpose → retention.
- ⚠️ **Each item has a reason to exist.** Two exceptions, both **unchanged**: `staff_role_card.dart:305-315` still collects a care-needs checklist that no API accepts and only `debugPrint`s (§2); `assistant_models.dart:124-129` still sends `patient_id`, and `functions/index.js:171-174` still never uses it — the prompt is built from `role`, `locale`, `text` only. Collected, transmitted off-device, unused.
- ✅ **Sensitive identifiers are optional, never required.** Re-verified. No patient-facing collection of Aadhaar/PAN/passport/bank/ABHA; the only Aadhaar reference is a *staff* vetting document type (`models.dart:936`). Phone is the sole required identifier (OTP auth). No card data touches the app.
- ⚠️ **No data collected "just in case."** Same two exceptions; otherwise clean.

### 2. Storage & encryption

- ⚠️ **Sensitive data encrypted at rest.** All persistence is still `shared_preferences` — no `flutter_secure_storage`, no `EncryptedSharedPreferences`, no SQLCipher (`pubspec.yaml`). PHI/PII in plaintext JSON: `orders_provider.dart:11-12` (orders + assessments), `address_selection_screen.dart:126`, `reminders_provider.dart:179`, `cart_provider.dart:209-214`, `app_provider.dart:100` (profile photo path), `cache_service.dart:19` (30-min API cache). **New surface in round 2:** `StoreMigrator` can write `__quarantine_v{n}_{key}` copies of the same blobs (`store_migrator.dart:130-141`) — dormant today (§11). iOS `NSUserDefaults` inherits Data Protection, so ⚠️ not ❌ given iOS-first; on Android this is plaintext XML.
- ✅ **Secrets/tokens in a secure store, never plaintext prefs.** Unchanged and still correct. `ApiService._authToken` (`api_service.dart:16`) is memory-only; the Firebase refresh token lives in the SDK's Keychain. No token ever reaches prefs.
- ❌ **No PII in logs (redact before logging).** ❌ **UNCHANGED — still the worst finding in the audit.** `logger.dart:55-57` strips only `debug`/`info` in release; `Log.warn`/`Log.error` survive and interpolate `$error` at `:59`, and every raw `debugPrint` survives release unconditionally. Confirmed leaks, all re-verified at `820060b`:
  1. `staff_role_card.dart:312-315` — writes the patient's **care-needs checklist** (feeding, toileting, catheter care…) plus recommended care level verbatim to logcat/os_log. Note it fires **before** the role gate at `:317`, so it logs even for a role that cannot book.
  2. `firebase_service.dart:129-130` — logs `$localPath` of a user-picked file; basenames are preserved (`chat_screen.dart:132`, `raise_concern_screen.dart:327`), so `mother_biopsy_report.jpg` is logged in full.
  3. ~28 sites logging `error: e` where the exception carries a URL containing `patientId` (`http`'s `ClientException.toString()` appends `uri=…`; every patient endpoint embeds the ID).
  4. `main.dart:288-291` — on **web release** (`!kDebugMode && kIsWeb` → `else` branch) every uncaught async error **plus full stack** goes to the browser console.
  5. `main.dart:117-121,286` — raw error + stack to Crashlytics, unscrubbed.
  6. `functions/index.js:191` — `console.error("assistant error:", err)` logs the whole error object; Anthropic SDK error messages echo request content, i.e. the patient's symptom utterance.
  — **Fix:** delete `staff_role_card.dart:312-315`; drop `$localPath` from `firebase_service.dart:129`; add a `redact()` in `logger.dart` stripping `uri=…`/paths before the `debugPrint` at `:59`; make `main.dart:290` a static string on web.
- ❌ **Sensitive views gated behind auth/biometric/re-auth.** ❌ **UNCHANGED.** `grep -rniE "local_auth|biometric|FLAG_SECURE|privacyScreen|secureWindow" lib/ ios/Runner android/app/src pubspec.yaml` → **no output**. No app-lock, no biometric re-auth, no screenshot/recents blocking on screens showing vitals, medications and diagnoses. Exporting the full handover PDF still requires no re-auth.
- ❌ **Backups encrypted and don't leak sensitive data.** ❌ **UNCHANGED.** `android/app/src/main/AndroidManifest.xml:5-9` sets neither `android:allowBackup` nor `dataExtractionRules` → defaults to `allowBackup="true"`, sweeping the plaintext prefs XML (orders, assessments, addresses, reminders — and any future quarantine blobs) into Google Drive auto-backup.

### 3. Data in transit

- ⚠️ **HTTPS/TLS only — rejected in code, not just by convention.** Convention still clean: `grep -rn "http://" lib/` → **zero**. Platform enforcement correct (no ATS exception in `Info.plist`, no `usesCleartextTraffic`). But `grep -rn "isScheme|startsWith('https" lib/` → **still no output**: `ApiService` (`api_service.dart:37-41`) and `AssistantService` (`assistant_service.dart:33`) accept any string, so a misconfigured `--dart-define=…=http://…` would be *attempted*, not refused.
- ✅ **No PII in URL query parameters.** Re-verified. Query maps carry only pagination/period/date; patient IDs travel in the path; all mutations use `jsonEncode(body)`; auth rides in the header.
- ⚠️ **Certificate pinning considered.** Still not implemented and still not documented as an accepted risk. Checklist marks it optional; for a PHI API an explicit written decision is worth having.
- ✅ **Modern TLS; no deprecated ciphers.** No custom `HttpClient`, no `badCertificateCallback`, no `HttpOverrides` anywhere — platform TLS defaults hold. A MITM'd certificate throws `HandshakeException`.

### 4. Secrets management

- ⚠️ **No credentials in source.** No real secrets. Three Firebase client keys committed (`firebase_options.dart:23,32,44`) — public-by-design, but in source.
- ⚠️ **No credentials in version-control history.** ✅ for every high-value class (re-verified above); ⚠️ only for the 3 Firebase keys.
- ✅ **Secrets loaded from env / secret manager.** `ANTHROPIC_API_KEY` → `defineSecret`; `RAZORPAY_KEY`, `ASSISTANT_API_URL` → `String.fromEnvironment` (`constants.dart:9,23`).
- ❌ **Different credentials per environment.** ❌ **UNCHANGED.** One Firebase project (`housepital-patient`) across all three platform entries; `firebase.json:9-14` defines a single default database. Debug builds, CI and production share one datastore — and now one **Storage bucket** governed by one set of rules.
- ⚠️ **Keys rotatable without a client release.** True for the Anthropic secret; false for the Firebase and Razorpay keys.
- ⚠️ **BLOCKED-OWNER — client-embedded keys scoped/restricted.** Unverifiable from the repo. Need GCP Console → Credentials → each `AIza…` key → Application + API restrictions, and Firebase Console → App Check status.

### 5. Permissions & access requests (least privilege)

- ❌ **App requests only the permissions it uses.** ❌ **UNCHANGED.** `android.permission.SCHEDULE_EXACT_ALARM` (`AndroidManifest.xml:3`) remains an orphan — both scheduling call sites are explicitly inexact (`medication_reminder_service.dart:178,228`, `AndroidScheduleMode.inexactAllowWhileIdle`), and nothing calls `requestExactAlarmsPermission()`. Play policy-restricted permission for zero functional benefit.
- ✅ **Every permission maps to a reachable shipping feature.** ✅ **FIXED — round-1 blocker B-2 closed.** `ios/Runner/Info.plist:73-74` `NSCameraUsageDescription`, `:75-76` `NSPhotoLibraryUsageDescription`. The 12 `image_picker` call sites no longer hard-crash the process on iOS. `RECORD_AUDIO` (`AndroidManifest.xml:4`) maps to `speech_to_text`. Verified against the full plist (`:1-78`).
- ⚠️ **Permission rationale strings are specific and honest.** The two new strings are genuinely good, not boilerplate — the camera string names *prescriptions and lab reports* (`Info.plist:74`), the photo string names *reports, prescriptions or a profile picture* (`:76`). One honest-disclosure gap survives: `voice_service.dart:48` calls `_speech.initialize(...)` without `onDevice: true`, so Apple may send audio off-device, and `NSSpeechRecognitionUsageDescription` (`:72`) does not say so. For a patient describing symptoms aloud, that omission matters.
- ❌ **App degrades gracefully when a permission is denied.** ❌ **UNCHANGED.** Handled: `raise_concern_screen.dart:104-112`, `document_repository_screen.dart:620-626,638-644`. Unhandled bare `await` (denial `PlatformException` propagates as an unhandled async error): `settings_screen.dart:69-70`, `patient_profile_screen.dart:205-206`, `return_screen.dart:315-319`, `chat_screen.dart:121-126`. None of the six distinguishes *cancelled* from *permanently denied*, so no screen offers an "Open Settings" path. Mic denial still fails silently (`assistant_provider.dart:165-166`, bare `if (!ok) return;`).

### 6. Authentication & access control

- ✅ **Auth implemented correctly for the model.** Unchanged and still strong. Firebase phone-OTP; proactive refresh at 50 min (`auth_provider.dart:30,76-81`), forced `getIdToken(true)` (`:95`), one-shot 401 recovery (`api_service.dart:92-100`), timer stopped before sign-out (`:219`), disposed defensively (`:231-235`).
- N/A **Passwords hashed.** No passwords — OTP-only. (`firebase.json:18` still enables an `emailPassword` provider no code path uses; disabling it shrinks the auth surface.)
- ❌ **Authorization checked server-side on every privileged action.** ❌ **UNCHANGED.** Role is still a client-side mutable string with a hardcoded default: `app_provider.dart:20` `String _currentUserRole = 'PRIMARY_CONTACT';` with a public setter at `:22`, never derived from a verified token claim. `main.dart:226` still hardcodes `const role = UserRole.primaryContact;` for the assistant. No custom claims, no server-side check.
- ❌ **Data isolation between users/tenants enforced and tested.** ❌ **REGRADED DOWN from ⚠️.** Round 1 called `firestore.rules` "genuinely good" and treated the `auth.uid == patientId` conflation as a future tightening. Tracing the identifier proves it is a **present defect**, and the new `storage.rules` inherits it verbatim:
  - `grep -rn "\.uid" lib/` → **zero hits.** The app never reads a Firebase uid, anywhere.
  - Every `patientId` handed to Firestore/Storage is a backend domain id: `home_screen.dart:781` and `:845` pass `app.currentPatient?.id ?? 'pat_demo_rajesh'`; `care_team_screen.dart:30,94,125,302` the same; `demo_data.dart:29` shows the shape — `'pat_demo_rajesh'`.
  - So `request.auth.uid == patientId` (`firestore.rules:67,70,72,90,94,99`; `storage.rules:52`) compares a 28-char Firebase uid to `pat_demo_rajesh`. It is **always false**. Chat reads/writes, attendance, vitals and `active_sessions` (`firestore.rules:133`) are all denied for the legitimate owner.
  - `health_manager_banner.dart:83` is worse still: it passes `manager.staffId` as `patientId` into `/chat` (its own comment admits it: *"FUTURE: Replace with actual patient ID"*), so depending on entry point the same conversation resolves to a **different thread key**, and the Storage ownership segment becomes a staff identifier.
  - There is still **no test proving absence of cross-leak** — `test/utils/permission_test.dart` tests the pure lookup table only, and there are no rules-emulator tests.
  - The rules files themselves flag the gap and defer it (`firestore.rules:151` `user_patients` TODO; `storage.rules:46-50`). It cannot be deferred any longer: it is the reason both rule sets deny their own app. **BLOCKED-OWNER** on what is live (`firestore.rules:9-17` says deploy happens from `housepital-backend`).
- ❌ **Role-based access enforced where the app has roles.** ❌ **UNCHANGED — still widget-visibility only.**
  - `handover_report_service.dart:302` — `Future<void> shareHandover({DateTime? now})` still takes no role and performs no check before `Printing.sharePdf` at `:305`. Still a zero-arg publicly constructible class, so there is no injection point for a central guard.
  - The three call sites still only hide the button: `my_care_screen.dart:168`, `medications_screen.dart:60`, `medication_schedule_screen.dart:50`. `medication_schedule_screen.dart:50-51` still reads the role with `context.read`, not `watch`, so a role change after that frame leaves a stale, fully functional allowed button on screen.
  - `invoice_pdf_service.dart:261-264` still ungated — and `my_orders_screen.dart:389-393` now **documents the gap as deliberate**: *"downloadable invoice (always)"*, with the `Cancel` button immediately below at `:394-397` gated on `UserAction.pay`. One `children:` list, two opposite policies.
  - `document_repository_screen.dart` still contains **zero** `canUserPerform` references, and `/documents` (`main.dart:560-562`) is registered as a plain `MaterialPageRoute` with no guard. No route in `main.dart` has any auth or role guard.
  - So a `CARETAKER` — the role `permissions.dart:66` says must not export medical history — still reaches the document repository and every invoice.
- ⚠️ **Session/token expiry + refresh-rotation; failed-login rate limiting.** Expiry/refresh solid; client resend cooldown 30 s (`otp_screen.dart:19,36-40`). **BLOCKED-OWNER** for server-side SMS abuse limits and App Check. **The logout/PHI half is materially better than round 1 but still incomplete — see H-3.**

> **Round-2 direct answer on SessionScope:** it is a genuine improvement — the two call sites are
> correctly placed (`home_screen.dart:1771` before `switchPatient`, `settings_screen.dart:457`
> before `logout`, plus `delete_account_screen.dart:64`) and the five covered providers clear
> thoroughly. But it is a **partial wipe that reads as complete**: the class docstring
> (`session_scope.dart:11-24`) and the test name (`patient_scope_isolation_test.dart:63`) both
> assert completeness that the code does not deliver. Enumerated in H-3.

### 7. Third-party SDKs & dependencies

- ⚠️ **No analytics/tracking/ads SDKs unless intended and disclosed.** Still genuinely good news: no `firebase_analytics`, no ads SDK, no Segment/Mixpanel/Amplitude/Facebook SDK in `pubspec.yaml` or `pubspec.lock`. But **Crashlytics + Performance are still forced on in every release build with no consent prompt and no opt-out** (`main.dart:115-131`), and `settings_screen.dart` still has no telemetry toggle. Under DPDP that is processing without notice or consent.
- ❌ **Each dependency's data collection is known and disclosed.** ❌ **UNCHANGED.** No disclosure artefact. **`ios/Runner/PrivacyInfo.xcprivacy` is still missing** (`ls` → *No such file or directory*); the 24 `PrivacyInfo.xcprivacy` files under `ios/Pods/` are pod-level, not app-level. Apple has required an app-level manifest since May 2024, and `shared_preferences` uses `NSUserDefaults`, required-reason API CA92.1. — **Impact:** App Store submission rejection. The round-2 additions make this *more* urgent, not less: camera and photo-library access are now actually granted.
  **Dependencies that transmit data off-device (re-verified against `pubspec.yaml`):** unchanged from round 1 — `firebase_auth`, `cloud_firestore` (PHI), `firebase_storage` (medical images), `firebase_messaging`, `firebase_crashlytics` (unscrubbed stacks), `firebase_performance` (URLs containing `patientId`), `razorpay_flutter`, `speech_to_text` (raw symptom audio, `onDevice` unset), `flutter_tts`, `cached_network_image`, `http`, `share_plus` (handover PDF + invoices), `printing` (full medical history).
- ⚠️ **Dependencies scanned; lockfile committed; no unnecessary deps.** `pubspec.lock` committed ✅. **`functions/package-lock.json` still NOT committed** (`git ls-files functions/` → `.gitignore`, `README.md`, `index.js`, `package.json`) — the Cloud Function holding the Anthropic key has an unpinned dependency tree. No `.github/dependabot.yml`; `.github/workflows/ci.yml` has no `npm audit` / `pub outdated` / OSV / Snyk step. **`dio: ^5.8.0+1` (`pubspec.yaml:39`) is still declared and still never imported** (`grep -rn "package:dio" lib/` → no output).

### 8. AI / LLM privacy

- ❌ **User content redacted of PII before being sent to any model.** ❌ **UNCHANGED — no redaction exists, built or called.** `assistant_provider.dart:91-100` passes the raw utterance straight into `AssistantRequest`; `assistant_models.dart:124-129` serialises `{text, patient_id, role, locale}`; `assistant_service.dart:53-58` POSTs it; `functions/index.js:171-174` embeds it verbatim. The feature's whole purpose is free-form Hinglish symptom description.
- ⚠️ **Cloud AI opt-in and off by default; endpoint disclosed/configurable.** Off by default ✅ (`assistant_service.dart:23,45`, activated only when `--dart-define=ASSISTANT_API_URL` is set). Still a **build-time** switch with no in-app toggle and no disclosure that a third-party LLM processes the user's words.
- ⚠️ **Model output sanitized before display or storage.** Structurally constrained ✅ (`functions/index.js:156-176`, `output_config.format` json_schema, `max_tokens: 512`, closed action enum). `reply_text` still rendered with no control-char strip and no client-side length cap. Low practical risk (Flutter `Text` is not an HTML/SQL sink).
- ✅ **Prompt-injection surface minimized.** Still well done: input capped at 1000 chars (`functions/index.js:127-128`), `role` validated against a hard allowlist (`:139-149`), structured JSON output, system prompt cached separately from user content (`:157-164`), app-side executor independently re-checks permissions.
- ❌ **Token/cost limits enforced per user.** ❌ **UNCHANGED.** `functions/index.js:107-114` is still `onRequest` with `cors: true` (wildcard), **no** `verifyIdToken`, no App Check, no API key, no rate limiter; the client still sends only `Content-Type` (`assistant_service.dart:55`). Anyone who learns the URL can POST unlimited requests billed to the owner's Anthropic account. Per-request cost is bounded; per-user and total cost are not bounded at all.

### 9. Privacy policy & store/site disclosure

- ⚠️ **Privacy policy exists at a stable URL, linked in-app.** In-app linking still done well: explicit un-prechecked consent gate before the CTA enables (`login_screen.dart:25,48-60,177-196,272-277`) with tappable Terms (`:218`) and Privacy Policy (`:238`), plus Settings → About (`about_screen.dart:102-104` → `https://housepital.in/privacy`). **BLOCKED-OWNER** on whether that URL resolves and is set in App Store Connect.
- **BLOCKED-OWNER** — **The policy describes the app's actual data flows.** Cannot assess without the text. When reviewing it, confirm it covers: Firebase Storage upload of chat/evidence photos, Crashlytics + Performance telemetry, off-device speech recognition, Anthropic LLM processing, **and the new deletion-request path with its 30-day claim (B-5)**.
- **BLOCKED-OWNER + ❌** — **Store/site disclosure matches reality.** App Privacy answers unverifiable from the repo. Independently ❌: `ios/Runner/PrivacyInfo.xcprivacy` still missing (§7) — the machine-readable half. Round 2 makes the answers *harder*: camera and photo-library are now functional, so "Photos" and "User Content" must be declared.
- ❌ **Encryption export-compliance answered.** ❌ **UNCHANGED.** `ITSAppUsesNonExemptEncryption` is absent from the full `ios/Runner/Info.plist:1-78` — the round-2 edit added the two usage strings and did not add this. Every upload will prompt manually and can stall a release. The app uses only standard HTTPS/TLS, so it qualifies for the exemption. — **Fix:** `<key>ITSAppUsesNonExemptEncryption</key><false/>`.

### 10. Regulatory

- ⚠️ **Applicable data-protection law considered.** ⚠️ **UPGRADED from ❌, narrowly.** DPDP is now cited *in code*: `delete_account_screen.dart:12-14` cites Guideline 5.1.1(v) and DPDP §12, and `settings_screen.dart:270-272` repeats it. That is evidence the law was considered for one obligation. It is not a compliance position: there is still no notice text, no lawful-basis record, no data-principal-rights matrix, no grievance officer, no breach runbook, and no `docs/` artefact of any kind (`grep -rlIi "DPDP|GDPR" docs/ *.md` matches only audit reports).
- ⚠️ **Lawful basis / consent obtained; most privacy-preserving default chosen.** Partial credit unchanged: the login consent gate is real and well-implemented. Still no **granular, purpose-specific** consent (DPDP §6) for Crashlytics/Performance telemetry (forced on, `main.dart:115-131`), cloud LLM processing (§8), or off-device speech recognition (§5). Defaults are not the most privacy-preserving.
  **New in round 2:** the entire account-deletion screen — the most legally operative copy in the app — is **hardcoded English** (`delete_account_screen.dart:72-78,96-98,136-206`); `grep -n "delete" assets/i18n/en.json` returns only unrelated keys. The app ships Hindi. DPDP §5(3) entitles the data principal to the notice in any Eighth Schedule language of their choice; an erasure flow the user cannot read is not informed consent.
- ⚠️ **Children: not directed at children, or age-gating handled.** Unchanged. No age gate (`grep -nIi "age_gate|dateOfBirth|COPPA|minor"` → none). The app is not *directed* at children, which is defensible, but DPDP §9 imposes verifiable-parental-consent duties for under-18s and nothing prevents adding a minor via `addPatient` (`app_provider.dart:196-203`).
- ⚠️ **Cross-border data transfer handled.** Unchanged. Good instincts by construction — Firestore pinned to `asia-south1` (`firebase.json:11`), function region `asia-south1` (`functions/index.js:110`). But data does leave India: Anthropic's API is US-hosted, Crashlytics/Performance land in Google's US infrastructure, Apple/Google speech recognition is off-device. None disclosed or contractually documented in the repo.

### 11. Deletion & retention

- ⚠️ **User can delete their data; deletion actually deletes.** ⚠️ **UPGRADED from ❌ — the store-rejection half is addressed; the erasure half is not, and the copy is not defensible.** Full assessment:
  - **What now exists.** `delete_account_screen.dart` + `/delete-account` (`main.dart:745-747`) + a Settings entry (`settings_screen.dart:273-279`). The flow has a real confirmation ladder — an "I understand" checkbox (`:185-194`), a typed `DELETE` confirmation (`:196-208`), and a second dialog (`:91-119`). That is better friction design than most apps ship.
  - **Guideline 5.1.1(v):** Apple requires deletion to be **initiated in-app**; apps in highly-regulated sectors (healthcare is enumerated) may add customer-service steps for confirmation. Initiation is now in-app, so the *structural* requirement is met and the automatic rejection risk is gone. **But the review risk is not.** A reviewer in airplane mode taps Delete and sees the same success dialog, because `_submitDeletionRequest` (`:53-59`) is `await Future<void>.delayed(const Duration(milliseconds: 600));` and a `TODO(backend)`. Nothing is sent, nothing is queued, nothing is stored. There is no ticket reference (the code's own comment at `:57` says it should surface one "once api.housepital.in exists").
  - **The copy is false as implemented.** The success dialog states *"Your Housepital records are scheduled for deletion and will be removed within 30 days"* (`:75-77`). Nothing is scheduled by anything. The class docstring's claim that the screen *"records a deletion request for Housepital to complete"* (`:20-21`) is also untrue — it records nothing. The docstring is admirably candid that the backend is missing; the **user-facing string is not**, and the user-facing string is the one that carries legal weight.
  - **DPDP §12:** §12(3) gives an enforceable right to erasure and §8(7) obliges the Data Fiduciary to erase when consent is withdrawn. A **request-only** flow *can* satisfy DPDP — the Act does not require instantaneous deletion, and §8(7) tolerates a retention carve-out for legal obligations (which the "What we must keep" card at `:160-177` correctly anticipates for tax invoices). What DPDP does **not** tolerate is a request that reaches no Data Fiduciary. Since the request is never transmitted, no §13 grievance clock starts and no §12 obligation is ever triggered. It is not a deletion request; it is a local logout with a deletion-shaped dialog.
  - **Compounding:** the flow signs the user out and `prefs.clear()`s (`auth_provider.dart:222-223`), so the user cannot revisit the screen, has no reference number, and the only recourse offered is a phone number (`:78`) that is not wired to anything in the repo either.
  - **Minimum honest fix, in order of cost:** (1) change the copy to say a request has been *raised on this device* and instruct the user to call/email to confirm — truthful today, zero backend; (2) better, write the request to the one backend that *is* reachable — `deletion_requests/{uid}` in Firestore with a matching create-only rule — before showing any 30-day claim; (3) localise the whole screen into `en.json`/`hi.json`.
- ❌ **No orphaned records/files after deletion (cascade verified).** ❌ **UNCHANGED, and now with a named orphan set.** With no server-side deletion the cascade cannot exist. The two stores most likely to orphan: Firebase Storage blobs (`firebase_service.dart:133-138`) and the `getDownloadURL()` token URLs (`:138`) persisted into chat records — those URLs remain fetchable by anyone holding them **regardless of rules**, so they survive any future cascade unless the objects themselves are deleted.
- ❌ **User can export their data.** ❌ **UNCHANGED.** No DPDP §11 portability path. The handover PDF (`handover_report_service.dart:302`) and invoice PDF (`invoice_pdf_service.dart:261`) are clinical/financial artefacts, not a data export — and the handover one is sourced entirely from `DemoData` (see the demo-honesty finding below).
- ❌ **Retention limits defined and enforced.** ❌ **UNCHANGED, plus one new latent liability.**
  - The only TTL in the codebase is still `CacheService._ttlMinutes = 30` (`cache_service.dart:7`). Orders, assessments, addresses, reminders, chat messages, vitals, attendance and uploaded medical images all persist indefinitely with no documented period. The delete screen's "What we must keep" card (`delete_account_screen.dart:170-175`) makes a retention *promise* that no retention *schedule* backs.
  - **`StoreMigrator` quarantine — direct answer to the round-2 question.** `quarantine()` (`store_migrator.dart:126-144`) copies an unparseable value to `__quarantine_v{n}_{key}` and never deletes it. **Today this is dormant, not active:** `grep -rn quarantine lib/ test/` returns only the definition file — **zero call sites** — and `_migrations` (`:57-58`) is empty with `currentVersion = 1` (`:33`), so `_migrateFrom` (`:98-119`) never executes a step. So it is **not a live DPDP retention breach**; it is a **design-time one, and the contract at `:19-21` makes it deliberate**: *"A migration NEVER deletes data it cannot parse."* The first real migration will therefore copy a PHI blob — `housepital_orders` and `housepital_assessments` carry service, patient and amount data — into an entry with no age stamp, no TTL, no reaper, no size cap, and no UI that mentions it exists. That is indefinite on-device retention of health-related personal data, contrary to DPDP §8(7) purpose-exhaustion and to the storage-limitation principle the checklist asks about.
  - **Partial mitigation that already exists:** `AuthProvider.logout()` calls `prefs.clear()` (`auth_provider.dart:222-223`), which removes `__quarantine_*` along with everything else, so quarantined PHI does not survive a logout or the delete-account flow. It survives an indefinitely signed-in session — which, for a family care app on a shared phone, is the normal state.
  - **Fix before the first migration ships:** stamp each quarantine entry with a creation timestamp; delete entries older than a stated window (30–90 days) at the top of `run()`; cap total quarantined bytes; and name the window in the privacy policy. Doing this now costs nothing; doing it after v2 data is on real phones is the same trap the file was written to avoid.

### 12. Hardening & incident readiness

- ⚠️ **Input validation / output encoding against injection.** Unchanged. Client-side validation present and reasonable (`login_screen.dart:157,171`; `onboarding_screen.dart:60`; `address_selection_screen.dart:540`; `vitals_screen.dart:834-840`). All requests `jsonEncode`d, never concatenated. Firestore writes type- and length-checked (`firestore.rules:74-75`). Storage writes now size- and type-checked (`storage.rules:55-58`) — but see B-1 on `contentType` being client-asserted. ⚠️ because the REST backend is out of repo (**BLOCKED-OWNER**).
- ⚠️ **Error responses don't leak internals.** UI clean (`api_service.dart:138-150` surfaces only `body['message']`; `ErrorWidget.builder` replaced at `main.dart:138-168`). One residual UI path unchanged: `paginated_list.dart:89` assigns `_error = e.toString()` into rendered state. The **logs** are not clean — §2.
- ❌ **Audit logging for security-relevant actions.** ❌ **UNCHANGED.** `grep -nIi "audit_log|auditLog|AuditEvent" lib/ functions/` → no output; `firestore.rules:149` still lists `audit_logs/{logId}` as a TODO. Nothing records who exported a handover PDF, who opened medical documents, when a role changed — **or who requested account deletion**, which is now a user-visible action with a legal clock attached and no record of it anywhere.
- ❌ **You know what a compromise would expose, and have a revoke/rotate plan.** ❌ **UNCHANGED.** No `SECURITY_REVIEW.md`, no incident runbook, no key-rotation procedure beyond the Anthropic note in `PROJECT.md`. Combined with the missing inventory (§1) and missing audit log, blast radius remains unknowable.

---

## Blockers (must fix before release)

### B-1. `storage.rules` is new, undeployed, and **cannot be satisfied by the app's own uploads**. Deploying it as written breaks all photo upload; the predictable rollback is to a posture worse than today.

Reviewed adversarially, as instructed. Three separate defects, in severity order.

**(a) The ownership key does not exist in this app.** `ownsPatient()` (`storage.rules:51-53`) requires
`request.auth.uid == patientId`. But `grep -rn "\.uid" lib/` returns **zero hits** — the app never
reads a Firebase uid anywhere. Every `patientId` it writes into a Storage path is a backend domain
id: `chat_screen.dart:135` uses `widget.patientId`, supplied by `home_screen.dart:781` / `:845` and
`care_team_screen.dart:30,94,125,302` as `app.currentPatient?.id ?? 'pat_demo_rajesh'`;
`demo_data.dart:29` shows the shape. Comparing a 28-char Firebase uid to `pat_demo_rajesh` is always
false. **Every chat photo upload and every concern-evidence upload is denied — for the patient
themselves, not just for family.** `uploadFile` returns null (`firebase_service.dart:140`) and the
user sees *"Couldn't send photo. Check your connection and try again."* (`chat_screen.dart:145-147`)
— a message that misattributes an authorization failure to the network, so the real cause will not
even be obvious in the field.

**(b) `batch.split('_')[0]` is structurally unsound, though not directly exploitable.** Direct answer
to the question asked:
- **Can a crafted path defeat it?** *Not for cross-tenant reads, given Firebase uids contain no
  underscore.* The rule (`storage.rules:76,78`) grants access to `concerns/{batch}/…` only when the
  substring before the first `_` equals the caller's own uid. An attacker with uid `X` can therefore
  only reach folders literally named `X` or `X_…` — folders in their own namespace. A victim folder
  `V_1754…` yields prefix `V`, and the attacker would need `uid == V`, i.e. to *be* the victim. An
  attacker holding a custom-token uid containing an underscore (`V_evil`) yields prefix `V` ≠ `V_evil`
  → **denied**. The failure mode is fail-closed. `split()` is a valid `rules.String` method and `'_'`
  is a literal regex, so the rule compiles and evaluates as intended.
- **Is it sound?** **No.** `_` is simultaneously a legal character *inside* the ownership key and the
  field delimiter. It is not a reserved separator, and the code that builds the path
  (`raise_concern_screen.dart:330`, `'concerns/${patientId}_$batchTs/…'`) uses the same character for
  both roles. Today every patient id contains underscores, so `'pat_demo_rajesh_1754…'.split('_')[0]`
  is `'pat'` — a value **shared by every patient in the system**. If the ownership model is ever
  fixed by issuing a claim (the `user_patients` mapping both rule files defer), and that claim ever
  carries a value like `pat…`, this single rule grants every patient's concern photographs at once.
  The check is one identifier-format change away from being a universal allow.
- **Fix:** stop parsing. Use two path segments — `concerns/{patientId}/{batchTs}/{fileName}` — and an
  equality check on the clean segment, matching the `chat/` rule's shape. That removes the delimiter
  question entirely and costs one line at `raise_concern_screen.dart:330`.

**(c) Two smaller defects.**
- `match /{allPaths=**} { allow read, write: if false; }` (`storage.rules:86-88`) is a **no-op**.
  Firebase Security Rules union their `allow`s; a `false` in one `match` never revokes an `allow` in
  another, and unmatched paths already default to deny. The comment at `:83-85` claims it ensures
  "any new upload path must be added above… not left to fall through" — it provides nothing the
  default does not. Harmless, but a reader will trust it to do work it does not do.
- `isImageUnder10Mb()` (`:55-58`) checks `request.resource.contentType`, which the **client asserts**:
  `uploadFile` passes a hardcoded `contentType: 'image/jpeg'` (`chat_screen.dart:136`,
  `raise_concern_screen.dart:331`) regardless of the actual bytes. The 10 MB size cap is real; the
  "images only" constraint is advisory.

**Does the ownership model hold for family caregivers?** No — and the file anticipates exactly this
in its own comment (`storage.rules:46-50`), treating it as a future problem. It is a present one, and
it is broader than family: under the current identifiers *nobody* passes `ownsPatient`, including the
patient. The correct fix is the `user_patients` → custom-claim mapping deferred at `firestore.rules:151`,
with rules checking `patientId in request.auth.token.patients`. Until that exists, deploying these
rules trades a silent over-permissive posture for a loud total outage — and the operational reflex
under a "chat photos are broken in production" ticket is to paste back
`allow read, write: if request.auth != null`, which is the exact posture these rules were written to
remove. **Do not deploy `storage.rules` until the identifier mismatch is resolved.** Coverage itself
is correct — both of the app's two `uploadFile` call sites are matched, and nothing else in `lib/`
touches Storage.

**Same defect in `firestore.rules`.** `:67,70,72,90,94,99,133` all key on `request.auth.uid == patientId`.
Chat, attendance, vitals and `active_sessions` are denied to their owners by the same mismatch. This
corrects a round-1 grade: the rules are well-structured and fail-closed, but the predicate they
fail-close on is wrong. **BLOCKED-OWNER** to confirm what is live — `firestore.rules:9-17` says the
deploy happens from `housepital-backend`, so the repo cannot prove the production posture. If the
live rules differ, the repo file is misleading documentation of the real boundary.

### B-2. Assistant Cloud Function is still unauthenticated with wildcard CORS. *(was B-3)*
`functions/index.js:107-114` — `onRequest` + `cors: true`, no `verifyIdToken`, no App Check, no rate
limit; the client sends no auth header (`assistant_service.dart:55`). Open proxy to a paid Claude
endpoint with unbounded cost. **Fix:** enforce App Check + verify the caller's ID token, add a
per-uid daily counter.

### B-3. PHI written to release logs. *(was B-4)*
`staff_role_card.dart:312-315` (care-needs checklist, logged *before* the role gate at `:317`),
`firebase_service.dart:129-130` (medical-document filenames), ~28 `error: e` sites leaking
patient-ID-bearing URLs — none stripped in release (`logger.dart:55-57` strips only debug/info;
`debugPrint` is never stripped). Plus `main.dart:288-291` dumping full stacks to the browser console
on web release.

### B-4. Sensitive exports are still not role-gated in code. *(was B-6)*
`handover_report_service.dart:302-305` has no role check; the three call sites only hide the button.
Invoice export (`my_orders_screen.dart:389-393`) is now explicitly commented as ungated-by-design,
and the entire document repository (`document_repository_screen.dart`, route `main.dart:560-562`) has
no gate at all — a `CARETAKER` reaches both. **Fix:** `shareHandover({required String role, …})` with
`if (!canUserPerform(role, UserAction.shareHandover)) return;` above `Printing.sharePdf` at `:305`;
the same in `invoice_pdf_service.dart:264`; a role guard on `/documents`.

### B-5. Account deletion claims a server-side erasure that no component performs.
`delete_account_screen.dart:53-59` is a 600 ms delay and a `TODO(backend)`; the success dialog at
`:74-78` tells the user their records are *"scheduled for deletion and will be removed within 30
days."* Nothing is scheduled, transmitted, queued or logged. The structural App Store requirement is
now met (initiation is in-app, and healthcare is an enumerated regulated sector), but the claim is
falsifiable by a reviewer in airplane mode, and under DPDP §12/§8(7) a request that never reaches the
Data Fiduciary starts no obligation and no §13 grievance clock. The whole screen is also hardcoded
English in a Hindi-shipping app. **Fix (cheapest honest version):** state that the request was raised
on this device and give a confirmation channel; or write `deletion_requests/{uid}` to Firestore
before making any 30-day claim.

### B-6. iOS `PrivacyInfo.xcprivacy` still missing — App Store rejection.
`ios/Runner/PrivacyInfo.xcprivacy` does not exist. Required since May 2024; `shared_preferences`
uses required-reason API CA92.1. Round 2 makes this worse, not better: camera and photo-library
access now actually function, so Photos and User Content must be declared.

## High

- **H-1.** Android `allowBackup` still defaults to true (`AndroidManifest.xml:5-9`, no `allowBackup`, no `dataExtractionRules`) → plaintext PHI prefs swept into Google Drive backup.
- **H-2.** Crashlytics + Performance still forced on in release with no consent and no opt-out (`main.dart:115-131`); raw errors + stacks exported unscrubbed (`:117-121,286`). The `TODO(observability)` at `logger.dart:63-65` would, if wired as written, additionally export every release-surviving `Log.warn`.
- **H-3.** **`SessionScope` is a partial wipe that reads as complete.** It correctly covers 5 providers and both call sites, but these PHI-bearing stores are outside it:
  1. `AppProvider._vitalsHistory` (`app_provider.dart:41`, getter `:75`, appended `:280`) — cleared by **neither** `clearPatientScopedData` (`:176-186`) **nor** `clearSession` (`:189-193`). Patient A's vitals readings render for patient B.
  2. `AppProvider._profilePhotoPath` (`:47`) — not cleared by either.
  3. `AppProvider._currentUserRole` (`:20`) — not reset on logout; the next session inherits the previous user's role.
  4. **`RemindersProvider`** (registered `main.dart:217`) — `_items` (`reminders_provider.dart:101`) persisted to `housepital_reminders` with free-text titles. **Not referenced by `SessionScope` at all**; survives a patient switch in memory *and* on disk, and `_loaded` (`:102`) stays true so nothing reloads.
  5. **`AssistantProvider`** — `_messages` (`assistant_provider.dart:44`) holds the full symptom conversation. **Not in `SessionScope`**; survives switch and logout. Worse, `_patientId`/`_role` (`:21-22`) are `final`, fixed at construction from `DemoData.patient.id` and `UserRole.primaryContact` (`main.dart:224-226`), so the executor acts on the demo patient regardless of who is active — a cross-patient *action* path, not just a display leak.
  6. **`CacheService`** — singleton (`cache_service.dart:9-11`) writing `housepital_cache_`-prefixed prefs (`:19`) from `app_provider.dart:223`. It has a `clear()` (`:38-44`) with **zero call sites**. Cached dashboard payloads (PHI) survive a patient switch for the full 30-minute TTL.
  7. `OrdersProvider.clearPatientScopedData` (`:212-216`) clears memory only; `housepital_orders`/`housepital_assessments` on disk are untouched. `_loadFromStorage()` runs only in the constructor (`:21`), so nothing resurfaces within a process — but kill the app while patient B is active and patient A's orders reload under B.
  8. `ApiService._authToken` (`api_service.dart:16`) is still never cleared; `IApiService` (`i_api_service.dart:12`) still exposes only `setAuthToken`. A valid bearer token lingers in memory for up to 60 min after logout.
  9. `settings_screen.dart:458` does not `await logout()` before `Navigator.pop`, and `CartProvider.clear()` fires an unawaited `_persist()` (`cart_provider.dart:198-202`) that races `prefs.clear()`. Benign today (the write is an empty list) but order-dependent.
  The test `patient_scope_isolation_test.dart:63` is named *"clearPatientScopedData nulls **every** per-patient field"* and asserts seven fields — it does not assert `vitalsHistory` or `profilePhotoPath`, both of which survive. A test whose name certifies completeness it does not check is worse than no test.
- **H-4.** **The doctor-handover PDF is built entirely from `DemoData` and carries no sample-data marking.** `handover_report_service.dart:95` says so in its own docstring, and `:101-108` sources patient, medical history, medications, vitals, today's report, services, staff and appointments from the demo layer unconditionally. It calls neither `DemoMode.markServingDemoData()` nor renders any watermark (`grep -n "SAMPLE|DEMO|demo|Sample"` on the file → the import and the docstring only). The round-2 banner (`main_shell.dart:136-168`) covers *screens*; the one artefact that leaves the app and reaches a clinician is uncovered. A family member can hand a doctor a clinically-formatted PDF of a different, fictional patient's chart with nothing on the page saying so.
- **H-5.** Role is still a client-side mutable string with a hardcoded default (`app_provider.dart:20,22`; `main.dart:226`) — no server-verified claim backs any authorization decision.
- **H-6.** No app-lock/biometric/screenshot protection on PHI screens; no re-auth before handover export.
- **H-7.** No PII redaction before the LLM call (`assistant_provider.dart:91-100` → `functions/index.js:171-174`).
- **H-8.** `health_manager_banner.dart:83` passes `manager.staffId` as `patientId` into `/chat` (its own comment flags it). The Firestore thread key and the Storage ownership segment become a **staff** identifier, so the same conversation resolves differently depending on entry point, and any future correct ownership rule will deny or mis-scope it.

## Medium / Low

- **M-1.** `android/app/google-services.json` + `lib/config/firebase_options.dart` still tracked; 3 `AIza…` keys in history. `CLAUDE.md` now describes this accurately — **doc half fixed**. Real control remains console key restriction (BLOCKED-OWNER) + working Security Rules (B-1).
- **M-2.** Orphan `SCHEDULE_EXACT_ALARM` (`AndroidManifest.xml:3`) while both schedules are inexact (`medication_reminder_service.dart:178,228`).
- **M-3.** `image_picker` denial unhandled in 4 of 6 screens (`settings_screen.dart:69`, `patient_profile_screen.dart:205`, `return_screen.dart:315`, `chat_screen.dart:121`); mic denial fails silently (`assistant_provider.dart:165-166`). *Now more reachable than in round 1, since the iOS permission prompts finally appear.*
- **M-4.** No rules-emulator test anywhere. `test/utils/permission_test.dart` tests the pure lookup table only. Neither `firestore.rules` nor `storage.rules` has a single test, which is why B-1 shipped.
- **M-5.** Missing `ITSAppUsesNonExemptEncryption` in `ios/Runner/Info.plist` — the round-2 plist edit added the two usage strings and skipped this.
- **M-6.** `functions/package-lock.json` still not committed; no Dependabot; no `npm audit`/`pub outdated`/OSV step in `.github/workflows/ci.yml`.
- **M-7.** `dio ^5.8.0+1` (`pubspec.yaml:39`) still declared, still never imported.
- **M-8.** No code-level HTTPS assertion on `ApiService.baseUrl` (`api_service.dart:37-41`) or `AssistantService.assistantUrl` (`assistant_service.dart:33`).
- **M-9.** Single Firebase project for all environments (`firebase_options.dart:26,35,47`) — dev/CI writes share the production datastore *and now the production Storage bucket*.
- **M-10.** `emailPassword` provider still enabled (`firebase.json:18`) with no code path using it.
- **M-11.** `NSSpeechRecognitionUsageDescription` (`Info.plist:72`) still does not disclose possible server-side recognition (`voice_service.dart:48` omits `onDevice`).
- **M-12.** Demo-fallback marking is incomplete: `app_provider.dart:135-139` (patients list) and `blog_provider.dart:38,68` fall back to `DemoData` without calling `DemoMode.markServingDemoData()`. The dashboard path (`app_provider.dart:260`) does mark, so the banner usually appears anyway — but the coverage is not what the `DemoMode` docstring (`demo_mode.dart:11-13`) claims ("*Every* provider that serves a demo fallback calls `markServingDemoData`").
- **M-13.** The account-deletion screen is hardcoded English (`delete_account_screen.dart:72-78,96-98,136-206`); no keys in `assets/i18n/en.json`/`hi.json`. DPDP §5(3) notice-language issue on the app's most legally operative screen.
- **L-1.** `paginated_list.dart:89` still puts `e.toString()` into rendered state.
- **L-2.** No audit logging; `firestore.rules:149` TODO never modelled — now also missing for account-deletion requests.
- **L-3.** No retention limits on any stored PHI; `StoreMigrator.quarantine` (`store_migrator.dart:126-144`) has no age stamp, TTL or reaper (dormant today — zero call sites).
- **L-4.** `patient_id` still sent to the assistant (`assistant_models.dart:126`) and still unused by `functions/index.js`.
- **L-5.** Still no `SECURITY_REVIEW.md` / data inventory / incident runbook — the checklist's own closing requirement.
- **L-6.** `storage.rules:86-88` catch-all deny is a no-op and its comment overstates what it does.
- **L-7.** Stale six-tab documentation persists (`docs/ARCHITECTURE.md:68`, `docs/SCREEN_MAP.md:6`, `docs/CHANGELOG.md:64`, `docs/FEATURE_TRACKER.md:143`) — already catalogued in `DOCUMENTATION_AUDIT.md:321-330`; noted here only because `SCREEN_MAP` is what a security reviewer would read to enumerate reachable surfaces.

## BLOCKED-OWNER

| # | Item | Exactly what is needed |
|---|---|---|
| 1 | **Live Firebase Storage rules** (gates B-1) | Firebase Console → Storage → Rules, full text. The repo file is undeployed and, as written, would deny the app's own uploads — so the live posture is genuinely unknown and may still be the permissive default |
| 2 | Live Firestore rules vs the repo | Console → Firestore → Rules (`firestore.rules:9-17` says deploy happens from `housepital-backend`) — needed to know whether chat/vitals are currently working, and if so, under what rule |
| 3 | Firebase API key restrictions | GCP Console → Credentials → each of the 3 `AIza…` keys → Application + API restrictions |
| 4 | App Check enforcement status | Firebase Console → App Check (gates B-2 and OTP abuse) |
| 5 | SMS/OTP abuse protection & quotas | Firebase Console → Authentication → Settings → SMS region policy |
| 6 | Privacy policy is live and accurate | `https://housepital.in/privacy` loading + its text, checked against §7's SDK table **and B-5's 30-day claim** |
| 7 | App Store Connect App Privacy answers | Screenshot of the App Privacy section (now must cover Photos + User Content) |
| 8 | Backend REST API authorization | `api.housepital.in` is out of repo — server-side authz, rate limiting and input validation cannot be audited |
| 9 | Anthropic account spend limit | Console budget cap (mitigates B-2's cost exposure) |
| 10 | **Whether a deletion request has any destination** | Confirm no queue/inbox/CRM currently receives one. If none exists, B-5's copy is unsupported and must change before submission |

---

*Round-2 read-only audit against commit `820060b`. No source file was modified.*
