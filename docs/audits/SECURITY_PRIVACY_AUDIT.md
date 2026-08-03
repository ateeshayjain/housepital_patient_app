# Security & Privacy Checklist (App-Agnostic) — Audit vs commit 803124d

**Date:** 2026-08-03 · **Auditor:** Security & Privacy agent · **Repo:** `housepital_patient_app`
**Scope:** Flutter/Dart client (`lib/`, `ios/`, `android/`), Firebase Cloud Function (`functions/`), Firestore rules, full git history (all refs).
**Method:** read-only. Every verdict below cites a file:line or a command with its output. No code was modified.
**Context:** healthcare app handling patient medical data in India → PHI leakage treated as top-severity; India DPDP Act 2023 obligations assessed alongside the checklist.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Data inventory & minimization | 1 | 2 | 1 | 0 |
| 2. Storage & encryption | 1 | 1 | 3 | 0 |
| 3. Data in transit | 2 | 2 | 0 | 0 |
| 4. Secrets management | 2 | 3 | 1 | 0 |
| 5. Permissions & access requests | 0 | 1 | 3 | 0 |
| 6. Authentication & access control | 1 | 2 | 2 | 1 |
| 7. Third-party SDKs & dependencies | 0 | 2 | 1 | 0 |
| 8. AI / LLM privacy | 1 | 2 | 2 | 0 |
| 9. Privacy policy & disclosure | 0 | 1 | 1 | 2 (BLOCKED-OWNER) |
| 10. Regulatory | 0 | 3 | 1 | 0 |
| 11. Deletion & retention | 0 | 0 | 4 | 0 |
| 12. Hardening & incident readiness | 0 | 2 | 2 | 0 |
| **TOTAL (49 items)** | **8** | **21** | **21** | **1 + 2 blocked** |

---

## Task-1 result: SECRET SCAN (highest priority) — verbatim command output

### ANTHROPIC_API_KEY — ✅ CLEAN. Confirmed server-side only.

```
$ grep -rn "ANTHROPIC_API_KEY\|anthropic" . (excl .git/build/.dart_tool)
functions/index.js:21:const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
functions/index.js:114:    secrets: [ANTHROPIC_API_KEY],
functions/index.js:153:      const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
functions/package.json:10:    "@anthropic-ai/sdk": "^0.71.0",
functions/README.md:46:firebase functions:secrets:set ANTHROPIC_API_KEY
+ 9 documentation-only mentions (PROJECT.md, README.md, CLAUDE.md, .env.example, docs/)

$ grep -rn "sk-ant-" .            # 3 hits, ALL doc placeholders:
functions/README.md:31:(`sk-ant-...`)
functions/README.md:47:#   → paste your sk-ant-... key when prompted
functions/README.md:87:echo "ANTHROPIC_API_KEY=sk-ant-..." > .env

$ git log -p --all | grep -oE "sk-ant-[A-Za-z0-9_-]{20,}" | sort -u
(NO OUTPUT — no real Anthropic key in any commit, on any ref)

$ grep -rni "anthropic|sk-ant" lib/ ios/
(no key material; 2 prose comments only — lib/main.dart:237, lib/config/constants.dart:9)

$ git log --oneline --all -S "ANTHROPIC" -- lib/ ios/
(NO OUTPUT — the string has never existed in lib/ or ios/ in any commit)
```

**Verdict: ✅ CONFIRMED.** `ANTHROPIC_API_KEY` exists only as a Firebase `defineSecret` (`functions/index.js:21`), resolved at `functions/index.js:153`, and has never appeared in `lib/`, `ios/`, or git history. The key cannot ship in the binary.

### Other credential classes — ✅ CLEAN

```
$ git log -p --all | grep -oE "(AKIA[0-9A-Z]{16}|sk_live_[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)" | sort -u
(NO OUTPUT — no AWS, Stripe, GitHub, Slack, or private-key material in any commit)

$ git grep -nIE "(password|secret|token|api[_-]?key)[\"' ]*[:=][\"' ]*[A-Za-z0-9_/+.-]{12,}" -- lib/ ios/ android/ functions/ web/
(NO OUTPUT after excluding examples/placeholders — no hardcoded credential literals)
```

Razorpay is correctly `--dart-define`-injected (`lib/config/constants.dart:23-26`) with the placeholder `rzp_test_XXXXXXXXXX` triggering simulated checkout by design (`lib/services/payment_service.dart:47-48`) — as documented, not a finding.

### ❌ Firebase config — the brief's premise is HALF WRONG. Correct the contract.

`CLAUDE.md:48` states *"Firebase plists are gitignored."* That is true for iOS only. **Android and Dart Firebase config are committed and tracked.**

```
$ git ls-files | grep -iE "GoogleService|google-services|firebase_options"
android/app/google-services.json          ← TRACKED
lib/config/firebase_options.dart          ← TRACKED

$ git check-ignore -v ios/Runner/GoogleService-Info.plist
.gitignore:57:**/GoogleService-Info.plist   ios/Runner/GoogleService-Info.plist   ← correctly ignored
$ git check-ignore -v android/app/google-services.json
NOT IGNORED                                                                       ← gitignore is inert here
$ git status --porcelain --ignored ios/Runner/GoogleService-Info.plist
!! ios/Runner/GoogleService-Info.plist      ← never committed. GOOD.

$ git log --all --oneline --diff-filter=A -- android/app/google-services.json lib/config/firebase_options.dart
5a0ca2e feat: add documentation, tests, utilities, and Firebase config

$ git log -p --all | grep -oE "AIza[A-Za-z0-9_-]{35}" | sort -u | wc -l
       3      ← 3 distinct Firebase Web API keys in history (web / android / ios)
```

Committed key locations: `lib/config/firebase_options.dart:23` (web), `:32` (android), `:44` (ios); `android/app/google-services.json:18`. Project: `housepital-patient`, sender `536139461614`.

**Why `.gitignore` did not help:** `.gitignore` never applies to already-tracked files. The rules at `.gitignore:56-57` were added *after* `5a0ca2e`; `android/app/google-services.json` was already in the index, so it stays tracked. The `.gitignore` comment at `.gitignore:50-51` even admits this ("google-services.json is currently COMMITTED — Agent F flagged this") — it was flagged in a prior audit and never actioned.

**Severity: Medium, not Critical.** Firebase API keys are client identifiers, not secrets — Google publishes them in every app bundle by design. Their safety depends entirely on (a) Firestore/Storage rules and (b) console-side key restrictions. Firestore rules are strong (§6). **Storage rules do not exist (see Blocker B-1)**, which is what turns this from cosmetic into real exposure.

---

## Findings

### 1. Data inventory & minimization

- ❌ **Every piece of personal data the app stores is listed.** No data inventory exists. `git grep -lIi "data inventory|personal data|DPDP|GDPR" -- docs/ *.md` returns nothing; `docs/` holds 15 files (ARCHITECTURE, DATABASE_SCHEMA, KNOWN_ISSUES…) and none enumerates personal/health data. There is no `SECURITY_REVIEW.md` as the checklist's closing instruction requires. — **Impact:** DPDP §5 notice obligations and App Privacy answers cannot be completed accurately without one; nobody can state the blast radius of a breach. — **Fix:** add `docs/DATA_INVENTORY.md` listing each field, its store (SharedPreferences key / Firestore path / Storage path), purpose, and retention.
- ⚠️ **Each item has a reason to exist.** Mostly true, two exceptions found. `lib/screens/services/cards/staff_role_card.dart:303-311` collects a care-needs checklist that no API accepts — it is only `debugPrint`ed (see §2). `lib/models/assistant_models.dart:126` sends `patient_id` to the assistant endpoint, but `functions/index.js:173` never uses it in the prompt — collected, transmitted, unused.
- ✅ **Sensitive identifiers are optional, never required.** Genuinely strong. `git grep -nIi "aadhaar|pan|passport|bank|ifsc|account_number|abha" -- lib/` returns no patient-facing collection. The only Aadhaar reference is a *staff* vetting document type (`lib/models/models.dart:936`) and display copy about staff verification (`lib/screens/services/cards/staff_role_card.dart:587`). Phone number is the sole required identifier, used for OTP auth. No card data touches the app (Razorpay SDK handles it).
- ⚠️ **No data collected "just in case."** Same two exceptions as above; otherwise clean.

### 2. Storage & encryption

- ⚠️ **Sensitive data encrypted at rest.** All persistence is `shared_preferences` — **there is no `flutter_secure_storage`, no `EncryptedSharedPreferences`, no SQLCipher** (confirmed against `pubspec.yaml` dependency block). PHI/PII written in plaintext JSON:
  - `lib/providers/orders_provider.dart:166-167` — orders + **assessments** (`housepital_orders`, `housepital_assessments`)
  - `lib/screens/checkout/address_selection_screen.dart:126` — saved addresses incl. name, full address, phone (`housepital_saved_addresses`)
  - `lib/providers/reminders_provider.dart:179` — care reminders, free-text `title` (`housepital_reminders`)
  - `lib/providers/cart_provider.dart:209-214`, `lib/providers/app_provider.dart:106` (profile photo path)
  - `lib/services/cache_service.dart:19` — 30-min TTL API cache (only one live call site, `lib/providers/app_provider.dart:190`)
  On **iOS** this is acceptable: `NSUserDefaults` inherits Data Protection (`NSFileProtectionCompleteUntilFirstUserAuthentication`), so it is encrypted at rest while the device is off. On **Android** it is a plaintext XML in app-private storage — readable on a rooted/backed-up device. Graded ⚠️ not ❌ because iOS is the stated first target.
- ✅ **Secrets/tokens in a secure store, never plaintext prefs.** The app never persists a token itself. `ApiService._authToken` (`lib/services/api_service.dart:16`) is in-memory only; the Firebase refresh token is held by the Firebase SDK (iOS Keychain). `git grep "setString"` shows no token ever reaching prefs. Correct design — `flutter_secure_storage` is genuinely not needed.
- ❌ **No PII in logs (redact before logging).** **Worst finding in the audit.** 91 logging call sites; none guarded by `kDebugMode` or `assert`. `lib/utils/logger.dart:54-57` strips only `debug`/`info` in release — **`Log.warn`/`Log.error` survive release and interpolate `$error`** (`lib/utils/logger.dart:59`), and all 30 raw `debugPrint(...)` calls survive release unconditionally. Confirmed leaks:
  1. `lib/screens/services/cards/staff_role_card.dart:308-311` — writes the patient's **care-needs checklist** (feeding, toileting, catheter care…) plus recommended care level verbatim to logcat/os_log on every booking attempt. Functional health status, in the clear, in release.
  2. `lib/services/firebase_service.dart:129-130` — logs `$localPath` of a user-picked file. Basenames are preserved (`lib/screens/chat/chat_screen.dart:132`, `lib/screens/support/raise_concern_screen.dart:327`), so `mother_biopsy_report.jpg` is logged in full.
  3. ~28 sites logging `error: e` / `$e` where the exception carries a URL containing `patientId`. `package:http`'s `ClientException.toString()` appends `uri=…`, and every patient endpoint embeds the ID (`lib/services/api_service.dart:182,197,211,230,238,248,267,306,414,424,429,497,558`). Examples, all release-surviving: `lib/providers/app_provider.dart:151,216,255`; `lib/providers/medication_provider.dart:173,206,230`; `lib/providers/my_care_provider.dart:69`; `lib/services/sync_service.dart:70,93,98`; `lib/services/firebase_service.dart:247,269,289`; `lib/screens/assistant/assistant_executor.dart:310,340,367,397,407,441,463`; `lib/screens/reports/daily_report_screen.dart:39`.
  4. `lib/main.dart:278-283` — on **web release** (`kIsWeb && !kDebugMode`) the `else` branch fires: every uncaught async error **plus full stack** goes to the browser console in production.
  5. `lib/main.dart:115,117,279` — raw error + stack exported to Crashlytics (Google sub-processor) with no scrubbing. Widget-build exceptions carry the widget tree, which holds rendered patient names/vitals in `Text` constructors.
  6. `functions/index.js:192` — `console.error("assistant error:", err)` logs the whole error object; Anthropic SDK `BadRequestError` messages echo request content, which is the patient's symptom utterance.
  Note `lib/screens/rental/return_screen.dart:362` and `lib/screens/support/staff_replacement_screen.dart:222` carry a comment claiming raw exception text is not leaked — the redaction was applied to the **UI only**; the log still emits `$e`.
  **No token ever leaks** — verified `lib/providers/auth_provider.dart:100`, `lib/services/firebase_service.dart:151,325,336`, `lib/services/payment_service.dart:203` all log the error/code, never the credential. — **Fix:** (a) delete `staff_role_card.dart:308-311`; (b) drop `$localPath` from `firebase_service.dart:129`; (c) add a `redact()` helper in `lib/utils/logger.dart` that strips `uri=…`/paths from `error` before the `debugPrint` at `:59`; (d) change `main.dart:281` to a static string on web.
- ❌ **Sensitive views gated behind auth/biometric/re-auth.** `git grep -nIi "local_auth|biometric|FLAG_SECURE|screenshot|privacyScreen" -- lib/ ios/ android/ pubspec.yaml` → **no output**. No app-lock, no biometric re-auth, no screenshot/recents-preview blocking on a screen showing vitals, medications and diagnoses. Exporting the full doctor handover PDF requires no re-auth. — **Fix:** add `local_auth` gate on My Care / Documents, and `FLAG_SECURE` (Android) + recents blur (iOS) on PHI screens.
- ❌ **Backups encrypted and don't leak sensitive data.** `android/app/src/main/AndroidManifest.xml` sets neither `android:allowBackup` nor `dataExtractionRules` → **defaults to `allowBackup="true"`**, so the plaintext SharedPreferences XML (orders, assessments, addresses, reminders) is swept into Google Drive auto-backup. No iOS `isExcludedFromBackup` on any written file. — **Fix:** set `android:allowBackup="false"` (or a `dataExtractionRules` XML excluding the PHI keys) on the `<application>` tag.

### 3. Data in transit

- ⚠️ **HTTPS/TLS only — insecure endpoints rejected in code, not just by convention.** Convention is clean: `git grep -nI "http://" -- lib/` returns **zero** results; every URL is `https://` (`lib/config/constants.dart:3`, `lib/screens/settings/about_screen.dart:98-110`, etc.). Platform enforcement is correct — no `NSAppTransportSecurity` exception block in `ios/Runner/Info.plist`, no `usesCleartextTraffic` / `networkSecurityConfig` in the Android manifest, so ATS/cleartext-blocking defaults apply. But **there is no code-level rejection**: `ApiService({this.baseUrl = AppConstants.apiBaseUrl, ...})` (`lib/services/api_service.dart:37-41`) accepts any string, and `git grep -nI "isScheme|scheme ==|startsWith('https" -- lib/` returns nothing. Same for `AssistantService.assistantUrl` (`lib/services/assistant_service.dart:33`). A misconfigured `--dart-define=ASSISTANT_API_URL=http://…` would be attempted, not refused. Graded ⚠️ because the OS would still block it — the code itself would not. — **Fix:** `assert(Uri.parse(baseUrl).isScheme('https'))` in both constructors.
- ✅ **No PII in URL query parameters.** Every `queryParams` map carries only pagination/period/date: `lib/services/api_service.dart:220,239,276,290,344,373,525`. Patient IDs travel in the path (unavoidable, and not logged by design — see §2 for where that assumption breaks); all mutations use `jsonEncode(body)` (`lib/services/api_service.dart:115,125`). Auth rides in the header (`lib/services/api_service.dart:50`).
- ⚠️ **Certificate pinning considered for high-value endpoints (optional).** Not implemented and not documented as a decision. Checklist marks this optional; for a PHI API it is worth an explicit accept/reject note.
- ✅ **Modern TLS; no deprecated ciphers/protocols.** No custom `HttpClient`, no `badCertificateCallback` override anywhere (`git grep` → no output), so platform TLS defaults hold. Nothing downgrades the connection.

> **Task-4 direct answer:** *Would `ApiService` silently accept a downgraded connection?* **No.** It has no `badCertificateCallback`, no custom `SecurityContext`, and no `HttpOverrides` — an invalid or MITM'd certificate throws `HandshakeException`, which surfaces as a failed request. The only gap is that it would *attempt* an `http://` base URL if one were injected at build time (ATS would then block it on iOS).

### 4. Secrets management

- ⚠️ **No credentials in source.** No real secrets (see scan above). Three Firebase client API keys are committed (`lib/config/firebase_options.dart:23,32,44`) — these are public-by-design identifiers, but they are in source.
- ⚠️ **No credentials in version-control history.** ✅ for all high-value classes (Anthropic, AWS, Stripe, GitHub, Slack, private keys — all confirmed absent from every ref). ⚠️ only for the 3 Firebase keys added in `5a0ca2e`.
- ✅ **Secrets loaded from env / secret manager, not bundled into the client.** `ANTHROPIC_API_KEY` → `defineSecret` (`functions/index.js:21`). `RAZORPAY_KEY` → `String.fromEnvironment` (`lib/config/constants.dart:23`). `ASSISTANT_API_URL` → `String.fromEnvironment` (`lib/config/constants.dart:9`). Exactly right.
- ❌ **Different credentials per environment.** One Firebase project (`housepital-patient`) across all three platform entries in `lib/config/firebase_options.dart:26,35,47` — no dev/staging/prod separation, no flavors. `firebase.json` defines a single default database. Debug builds, CI, and production share one datastore. — **Impact:** a developer test writes into the same Firestore/Storage as real patient data; a leaked key cannot be rotated per-environment. — **Fix:** add a `housepital-patient-dev` project + Flutter flavors before real patient data lands.
- ⚠️ **Keys rotatable without a client release.** True for `ANTHROPIC_API_KEY` (re-set secret + redeploy function). False for the Firebase keys and the Razorpay key — both are baked into the binary and need a store release.
- ⚠️ **BLOCKED-OWNER — Client-embedded keys assumed public, scoped/restricted accordingly.** Cannot verify from the repo. **Need from owner:** screenshots of (a) Google Cloud Console → APIs & Services → Credentials → each of the 3 `AIza…` keys → *Application restrictions* (must be iOS bundle `com.housepital.housepitalPatient` / Android package + SHA-1, not "None") and *API restrictions*; (b) Firebase Console → App Check status.

### 5. Permissions & access requests (least privilege)

- ❌ **App requests only the permissions it uses.** `android.permission.SCHEDULE_EXACT_ALARM` (`android/app/src/main/AndroidManifest.xml:3`) is an **orphan**. Both scheduling call sites explicitly use inexact mode: `lib/services/medication_reminder_service.dart:178` and `:228` — `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`. No `exactAllowWhileIdle`, no `alarmClock`, no `requestExactAlarmsPermission()` anywhere in `lib/`. — **Impact:** Google Play policy-restricted permission; declaring it forces a declaration form and review scrutiny for zero functional benefit. — **Fix:** delete `android/app/src/main/AndroidManifest.xml:3`.
- ❌ **Every permission maps to a reachable shipping feature.** The inverse failure is worse and is a **release blocker**. `ios/Runner/Info.plist` contains exactly two usage-description keys (lines 69-72) — **no `NSCameraUsageDescription`, no `NSPhotoLibraryUsageDescription`** — yet `image_picker` is called from six screens (12 call sites): `lib/screens/documents/document_repository_screen.dart:613,631`; `lib/screens/support/raise_concern_screen.dart:96`; `lib/screens/rental/return_screen.dart:316`; `lib/screens/chat/chat_screen.dart:121`; `lib/screens/settings/settings_screen.dart:69`; `lib/screens/settings/patient_profile_screen.dart:205`. On iOS a missing usage string is a **hard process crash**, not a denial. Every one of those taps kills the app on device. (Android is correct here — `image_picker` delegates to system intents, so no `CAMERA`/`READ_MEDIA_IMAGES` declaration is needed.)
- ⚠️ **Permission rationale strings are specific and honest.** The two that exist are genuinely good, not boilerplate: `NSMicrophoneUsageDescription` = *"Housepital uses the microphone so you can speak to the assistant."* (`ios/Runner/Info.plist:70`); `NSSpeechRecognitionUsageDescription` = *"Housepital uses speech recognition to understand your questions."* (`:72`). One honest-disclosure gap: `lib/services/voice_service.dart:48` calls `_speech.initialize(...)` without `onDevice: true`, so Apple's framework may send audio **off-device** — and the string does not say so. For a patient describing symptoms aloud, that omission matters. Two required strings are missing entirely (above).
- ❌ **App degrades gracefully when a permission is denied.** Inconsistent. Handled (catch + snackbar): `lib/screens/support/raise_concern_screen.dart:104-112`, `lib/screens/documents/document_repository_screen.dart:620-626,638-644`. **Unhandled — bare `await`, no try/catch, so a denial `PlatformException` propagates as an unhandled async error:** `lib/screens/settings/settings_screen.dart:69-70`, `lib/screens/settings/patient_profile_screen.dart:205-206`, `lib/screens/rental/return_screen.dart:315-319`, `lib/screens/chat/chat_screen.dart:121-126`. None of the six distinguishes *cancelled* from *permanently denied*, so no screen ever offers an "Open Settings" path. Microphone degrades safely but **silently** — `lib/providers/assistant_provider.dart:165-166` does `if (!ok) return;` with no snackbar and no UI state change, so the mic button appears dead.

### 6. Authentication & access control

- ✅ **Auth implemented correctly for the model.** Firebase phone-OTP, correctly wired. Proactive refresh at 50 min against Firebase's 60-min expiry (`lib/providers/auth_provider.dart:30,76-81`), forced refresh via `getIdToken(true)` (`:95`), one-shot 401 recovery with a single retry (`lib/services/api_service.dart:92-100`, `lib/providers/auth_provider.dart:109-116`), timer stopped before sign-out so a tick cannot race and re-set a stale token (`:220`), and disposed defensively (`:234`). Well covered by `test/providers/auth_provider_test.dart` (cold-start restore, sendOtp, verifyOtp, onboarding, logout).
- N/A **Passwords hashed with bcrypt/scrypt/Argon2.** No passwords — OTP-only. (`firebase.json:16` does enable an `emailPassword` provider, but no code path in `lib/` uses it; worth disabling to shrink the auth surface.)
- ❌ **Authorization checked server-side on every privileged action, not just hidden in the UI.** The role is a **client-side mutable string with a hardcoded default**: `lib/providers/app_provider.dart:19` — `String _currentUserRole = 'PRIMARY_CONTACT';` with a public setter at `:22`, never derived from a verified token claim. `lib/main.dart:227` hardcodes `const role = UserRole.primaryContact;` for the assistant. No Firebase custom claims, no server-side role check. See the next two items for the consequences.
- ⚠️ **Data isolation between users/tenants enforced and tested.** `firestore.rules` is genuinely good: default-deny at `firestore.rules:52-54`, then per-collection owner-scoped allows for `chat_messages` (`:74-85`), `patients/*/attendance|vitals` (`:93-107`), `users/*/notifications` (`:115-129`), `active_sessions` (`:137-141`), `fcm_tokens` (`:148-151`), with client writes denied where the backend owns them. Two real caveats: (a) every rule keys on `request.auth.uid == patientId`, conflating the auth user with the patient — the file's own comment (`:64-66`) admits this and defers the `user_patients` mapping, so the multi-patient feature (`lib/providers/app_provider.dart:167-172 addPatient`) has no isolation model; (b) **no test proves no cross-leak** — `test/utils/permission_test.dart` only asserts the pure `canUserPerform` lookup table, and there are no rules tests. Also note `firestore.rules:9-17`: the file must be deployed from a *different* repo, so the repo cannot prove what is live (**BLOCKED-OWNER**: need a screenshot of the live rules at console.firebase.google.com/project/housepital-patient/firestore/rules).
- ❌ **Role-based access enforced where the app has roles.** **The gate is widget-visibility only. Nothing is enforced at the service layer, anywhere.** Answering Task-7 directly:
  - `lib/services/handover_report_service.dart` does **not** import `lib/utils/permissions.dart` (imports are `:16-25`). `shareHandover({DateTime? now})` at `:302-307` calls `Printing.sharePdf` at `:305` with **no role parameter and no check**. The class is a publicly constructible zero-arg `class HandoverReportService {` (`:27`), so every call site does `HandoverReportService().shareHandover()` inline — there is no injection point where a guard could be centralised.
  - All three call sites are `if (canUserPerform(...)) <render widget>`: `lib/screens/my_care/my_care_screen.dart:168` (handler `_share()` at `:465-482` calls the service at `:469` with **no re-check**), `lib/screens/my_care/medications_screen.dart:60` (`onPressed` at `:64` is a bare call), `lib/screens/my_care/medication_schedule_screen.dart:50-52` (`onPressed` at `:56`, bare).
  - Concrete bypass window: `medication_schedule_screen.dart:51` reads the role with `context.read`, **not `watch`** — so if `AppProvider.setCurrentUserRole` (`lib/providers/app_provider.dart:22`) changes role after that frame is built, a stale allowed button stays on screen and fully functional. Routes offer no backstop (`lib/main.dart:563-568` registers `/medications` and `/medication-schedule` as plain `MaterialPageRoute`, no redirect, no guard), and the assistant can navigate a `CARETAKER` there because `lib/screens/assistant/assistant_executor.dart:480` gates navigation on `UserAction.view` only — which `CARETAKER` holds (`lib/utils/permissions.dart:69`).
  - **Worse, other sensitive exports have no gate at all — not even a hidden widget.** Invoice PDF: `lib/services/invoice_pdf_service.dart:261-265` ungated; the download button at `lib/screens/services/my_orders_screen.dart:390-394` has **no** `canUserPerform` wrapper while the *Cancel* button immediately below it at `:395-398` **is** gated — an inconsistency inside one `children:` list. Also ungated: `lib/screens/my_care/service_detail_screen.dart:551-553`, `lib/screens/billing/payment_screen.dart:101-119`. **Medical document repository**: `lib/screens/documents/document_repository_screen.dart` contains **zero** `canUserPerform` references; the share action at `:442-448` exports prescription/report metadata, and route `/documents` (`lib/main.dart:552-554`) is unguarded. So a `CARETAKER` — the exact role `lib/utils/permissions.dart:66` says "must not export the medical history" — has unrestricted access to the document repository and every invoice.
  - The policy table itself is sound and fail-closed (`lib/utils/permissions.dart:77-81`, unknown role → `false`) and well tested — but it tests the *table*, not the *enforcement*. — **Fix:** change the signature to `shareHandover({required String role, DateTime? now})` and put `if (!canUserPerform(role, UserAction.shareHandover)) return;` immediately above `Printing.sharePdf` at `lib/services/handover_report_service.dart:305`; do the same in `invoice_pdf_service.dart:264`; add a role guard to the `/documents` route.
- ⚠️ **Session/token expiry + refresh-rotation; failed-login rate limiting.** Expiry/refresh is solid (above). Client-side resend cooldown is 30 s (`lib/screens/auth/otp_screen.dart:19,36-40`). **BLOCKED-OWNER** for server-side limits: Firebase Phone Auth has built-in per-number/per-IP quotas, but whether App Check and SMS-abuse protection are enabled is console state — **need:** Firebase Console → Authentication → Settings → SMS region policy + App Check enforcement status.
  Additional gap found: **`logout()` does not fully clear patient data from memory.** `lib/providers/auth_provider.dart:217-227` does `prefs.clear()` (good — wipes orders, assessments, addresses, reminders, cart from disk) and nulls `_currentUser`, but: (a) it never clears `ApiService._authToken`, so a valid bearer token lingers in memory for up to 60 min — `IApiService` (`lib/services/i_api_service.dart:12`) exposes only `setAuthToken`, no `clearAuthToken`; (b) `_phone` (`:22`) is not cleared; (c) providers are app-root singletons (`lib/main.dart:184-267`) and the logout UI at `lib/screens/settings/settings_screen.dart:440-443` only calls `logout()` then `Navigator.pop` — **no provider reset, no app restart**. So `AppProvider._currentPatient` (name, conditions, diagnosis, medications), `OrdersProvider._orders`, `MyCareProvider` and `MedicationProvider` all retain the previous patient's PHI in RAM and will render for the next user until the process is killed. The logout test (`test/providers/auth_provider_test.dart:278-300`) asserts only `signOutCalls`, `currentUser == null`, and `state == initial` — it does not assert that PHI-bearing providers were reset. — **Fix:** add `clearAuthToken()` to `IApiService`, and have `logout()` call `reset()` on every PHI-holding provider (or rebuild the provider tree on auth-state change).

> **Task-3 direct answer:** token storage ✅ (memory + Firebase Keychain, never in prefs); refresh ✅ (proactive 50-min + 401 one-shot); expiry handling ✅; **logout ⚠️ — clears disk fully, clears memory only partially.**

### 7. Third-party SDKs & dependencies

- ⚠️ **No analytics/tracking/ads SDKs unless explicitly intended and disclosed.** Genuinely good news: **no `firebase_analytics`, no ads SDK, no Segment/Mixpanel/Amplitude/Facebook SDK** anywhere in `pubspec.yaml` or `pubspec.lock`. But `firebase_crashlytics` and `firebase_performance` are enabled **unconditionally in every release build with no consent prompt and no opt-out**: `lib/main.dart:120-123` calls `setCrashlyticsCollectionEnabled(true)` / `setPerformanceCollectionEnabled(true)` inside `if (!kDebugMode)`. There is no settings toggle (`lib/screens/settings/settings_screen.dart` has rows for notifications, language, appearance — none for telemetry). Under DPDP that is telemetry processing without notice or consent.
- ❌ **Each dependency's data collection is known and disclosed.** No disclosure artefact exists. Worse, **`ios/Runner/PrivacyInfo.xcprivacy` is missing** — `find ios -name PrivacyInfo.xcprivacy` returns 24 hits, **all under `ios/Pods/`** (Firebase, Razorpay, gRPC…), none for the app target. Apple has required an app-level privacy manifest since May 2024, and `shared_preferences` uses `NSUserDefaults`, a required-reason API (CA92.1) that must be declared. — **Impact:** App Store submission rejection. — **Fix:** add `ios/Runner/PrivacyInfo.xcprivacy` declaring `NSPrivacyAccessedAPITypes` (UserDefaults CA92.1, File timestamp if used) and `NSPrivacyCollectedDataTypes` (health, name, phone, photos, crash data, performance data).
  **Task-8 — dependencies that transmit data off-device, and what each sees:**

  | Dependency | Transmits off-device | What it sees |
  |---|---|---|
  | `firebase_auth` ^5.7.0 | Google | Phone number, OTP, device/IP, Firebase UID |
  | `cloud_firestore` ^5.6.8 | Google | Chat messages, attendance, vitals, notifications — **PHI** |
  | `firebase_storage` ^12.4.0 | Google | Chat photos, concern evidence photos — **medical images** (`lib/services/firebase_service.dart:137`) |
  | `firebase_messaging` ^15.2.5 | Google | FCM token, device identifiers, push payloads |
  | `firebase_crashlytics` ^4.3.5 | Google | Exception messages + **full stack traces**, unscrubbed (`lib/main.dart:115,117,279`) — see §2 |
  | `firebase_performance` ^0.10.1+5 | Google | Network URLs (which contain `patientId`), latency, device/carrier |
  | `razorpay_flutter` ^1.3.7 | Razorpay (IN) | Payment amount, order ID, card/UPI data entered in its own sheet |
  | `speech_to_text` ^7.4.0 | Apple/Google | **Raw audio of spoken symptoms** — `onDevice` not set (`lib/services/voice_service.dart:48`) |
  | `flutter_tts` ^4.2.5 | Apple/Google | Text sent for synthesis (assistant replies) |
  | `cached_network_image` ^3.4.1 | image hosts | Image URLs requested |
  | `http` ^1.4.0 / `dio` ^5.8.0+1 | app backend | All API traffic. **`dio` is declared but `git grep "package:dio"` in `lib/` finds no import — an unused dependency; remove it.** |
  | `share_plus` ^11.0.0 | user-chosen app | Whatever is shared — **incl. the handover PDF and invoices** |
  | `printing` ^5.14.3 | user-chosen target | Rendered PDF bytes (full medical history) |
  | `image_picker`, `url_launcher`, `flutter_local_notifications`, `pdf`, `fl_chart`, `shimmer`, `flutter_svg`, `intl`, `timezone`, `pin_code_fields`, `flutter_markdown`, `path`, `provider`, `go_router`, `shared_preferences` | — | Local only |
- ⚠️ **Dependencies scanned for vulnerabilities; lockfile committed; no unnecessary deps.** `pubspec.lock` is committed ✅. **`functions/package-lock.json` is NOT committed** (`git ls-files functions/` → `.gitignore`, `README.md`, `index.js`, `package.json` only) — the Cloud Function that holds the Anthropic key has an unpinned dependency tree. No scanning of any kind: no `.github/dependabot.yml`, and `.github/workflows/ci.yml` has no `pub outdated` / `npm audit` / OSV / Snyk step. One unnecessary dep (`dio`, above).

### 8. AI / LLM privacy

- ❌ **User content redacted of PII before being sent to any model — and the redaction is actually wired in.** There is **no redaction at all**, built or called. `lib/providers/assistant_provider.dart:95-100` passes the raw user utterance straight through; `lib/models/assistant_models.dart:124-129` serialises `{text, patient_id, role, locale}`; `lib/services/assistant_service.dart:53-58` POSTs it; `functions/index.js:173` embeds it verbatim in the user turn. The whole point of the feature is free-form Hinglish ("mummy ko saans lene mein takleef ho rahi hai"), so symptom descriptions and names will routinely be in `text`. — **Fix:** add a redaction pass in `AssistantProvider.sendText` before constructing the request, and drop the unused `patient_id`.
- ⚠️ **Cloud AI is opt-in and off by default; endpoint disclosed/configurable.** Off by default and configurable ✅ — `AssistantService.useStub` defaults `true` (`lib/services/assistant_service.dart:23,45`) and the cloud path activates only when `--dart-define=ASSISTANT_API_URL` is set (`lib/config/constants.dart:9-11`). But that is a **build-time** switch, not a user choice: once a build ships with the URL set, every user's messages go to the cloud with no in-app toggle and no disclosure that a third-party LLM processes their words. DPDP requires notice.
- ⚠️ **Model output sanitized before display or storage.** Structurally constrained ✅ — `functions/index.js:157-176` uses `output_config.format = {type: "json_schema", schema: SCHEMA}` with `max_tokens: 512`, and `AssistantResponse.fromJson` maps to a closed `AssistantAction` enum, so an unknown action degrades rather than executes. But `reply_text` is rendered with no control-char strip and no length cap client-side. Low practical risk (Flutter `Text` is not an HTML/SQL sink), hence ⚠️ not ❌.
- ✅ **Prompt-injection surface minimized.** Well done. Input capped at 1000 chars (`functions/index.js:128-129`); `role` validated against a hard allowlist so a caller cannot inject prompt text through it (`functions/index.js:141-150`); structured `json_schema` output rather than free-form parsing; system prompt cached separately from user content (`functions/index.js:159-165`); and the app-side executor independently re-checks permissions.
- ❌ **Token/cost limits enforced per user.** **The Cloud Function is completely unauthenticated.** `functions/index.js:112-118` uses `onRequest` with `cors: true` (wildcard) and **no** `verifyIdToken`, no App Check, no API key, no rate limiter — and the client sends no `Authorization` header (`lib/services/assistant_service.dart:55` sets only `Content-Type`). Anyone who learns the URL can POST unlimited requests and bill them to the owner's Anthropic account. Per-request cost is bounded (1000 chars in, 512 tokens out) but per-user/total cost is not bounded at all. — **Impact:** unbounded financial exposure + an open proxy to a Claude endpoint. — **Fix:** enforce Firebase App Check on the function, verify the caller's ID token, and add a per-uid daily counter.

### 9. Privacy policy & store/site disclosure

- ⚠️ **Privacy policy exists at a stable URL, linked in store listing / site footer + in-app.** In-app linking is done well: the login screen requires an explicit consent checkbox before the CTA enables (`lib/screens/auth/login_screen.dart:25,48-60,177-196,272-277`) with tappable **Terms** (`:218`) and **Privacy Policy** (`:238`) links, plus a Settings → About entry (`lib/screens/settings/about_screen.dart:102-104` → `https://housepital.in/privacy`). **BLOCKED-OWNER** on whether that URL actually resolves to a published policy and whether it is set in App Store Connect — **need:** the live URL loading, plus the App Store Connect privacy-policy field.
- **BLOCKED-OWNER** — **The policy describes the app's actual data flows.** Cannot assess without the policy text. **Need:** the current policy. When reviewing it, confirm it covers: Firebase Storage upload of chat/evidence photos, Crashlytics + Performance telemetry, off-device speech recognition, and the Anthropic LLM processing — none of which are obvious from the app UI.
- **BLOCKED-OWNER + ❌** — **Store/site disclosure matches reality.** The App Privacy answers cannot be verified from the repo (**need:** App Store Connect → App Privacy screenshot). Independently ❌: the app-level `PrivacyInfo.xcprivacy` is missing (§7), which is the machine-readable half of this requirement.
- ❌ **Encryption export-compliance answered where the platform requires it.** `grep -n "ITSAppUsesNonExemptEncryption" ios/Runner/Info.plist` → **missing**. The full key list in `ios/Runner/Info.plist` (lines 5-72) has no export-compliance key, so every upload will prompt manually and can stall a release. The app uses only standard HTTPS/TLS, so it qualifies for the exemption. — **Fix:** add `<key>ITSAppUsesNonExemptEncryption</key><false/>`.

### 10. Regulatory

- ❌ **Applicable data-protection law considered (India DPDP 2023 · GDPR · HIPAA).** `git grep -lIi "DPDP|GDPR|HIPAA|data protection"` across `docs/` and all root `*.md` → **no output**. For an app processing Indian patients' health data — a category the DPDP Act treats with heightened obligation — there is no evidence anywhere in the repo that the law was considered. — **Fix:** produce a DPDP compliance note covering notice, consent, purpose limitation, data-principal rights, retention, and the breach-notification runbook.
- ⚠️ **Lawful basis / consent obtained; most privacy-preserving default chosen.** Partial credit: the explicit, un-prechecked T&C gate at `lib/screens/auth/login_screen.dart:177-196` (button disabled until ticked, `:272-277`) is real, well-implemented consent for the core service — better than most apps at this stage. But DPDP §6 requires **granular, purpose-specific** consent, and there is none for: Crashlytics/Performance telemetry (forced on, `lib/main.dart:120-123`), cloud LLM processing of utterances (§8), or off-device speech recognition (§5). Defaults are not the most privacy-preserving.
- ⚠️ **Children: not directed at children, or age-gating handled.** `git grep -nIi "age_gate|dateOfBirth|COPPA|minor"` → no age gate exists. The app is not *directed* at children (home care for adults/elderly is the clear framing: `lib/data/demo_data.dart` patient is a post-stroke adult), so this is defensible. But DPDP §9 imposes strict verifiable-parental-consent duties for under-18s, and nothing prevents a family member from adding a minor as a patient via `addPatient` (`lib/providers/app_provider.dart:167`). — **Fix:** either document the adults-only scope in the T&C, or capture patient DOB and branch on it.
- ⚠️ **Cross-border data transfer handled if data leaves its region.** Partly right by construction: Firestore is pinned to `asia-south1` (`firebase.json:8`) and the assistant function too (`functions/index.js:115`) — good instincts for Indian data residency. But data does leave India: Anthropic's API is US-hosted, Crashlytics/Performance telemetry lands in Google's US infrastructure, and Apple/Google speech recognition is off-device. None of this is disclosed or contractually documented in the repo.

### 11. Deletion & retention

- ❌ **User can delete their data; deletion actually deletes.** `git grep -nIi "deleteAccount|delete_account|deleteMyData|erase" -- lib/ assets/i18n/en.json` → **no output**. The Settings screen (`lib/screens/settings/settings_screen.dart:185-264`) has 11 rows — orders, patient profile, add patient, family, documents, notifications, language, appearance, referral, help, about, logout — and **no delete-account row**. — **Impact:** two-fold. (1) DPDP §12(3) gives the data principal an enforceable right to erasure. (2) **Apple App Store Review Guideline 5.1.1(v) requires any app supporting account creation to offer in-app account deletion** — this is a hard rejection at submission. — **Fix:** add a "Delete my account" flow in Settings that calls a backend endpoint cascading across Firestore (`patients/*`, `chat_messages/*`, `users/*`), Firebase Storage, and Firebase Auth, then wipes SharedPreferences.
- ❌ **No orphaned records/files after deletion (cascade verified).** Vacuously failed — with no deletion path, the cascade cannot exist or be tested. Note the two stores most likely to orphan: Firebase Storage blobs (uploaded at `lib/services/firebase_service.dart:137`) and the download URLs persisted into chat messages, which remain publicly fetchable by anyone holding the URL even after the parent record is gone.
- ❌ **User can export their data.** No portability path. The handover PDF (`lib/services/handover_report_service.dart:302`) and invoice PDF (`lib/services/invoice_pdf_service.dart:261`) are clinical/financial artefacts, not a DPDP §11 data export (they do not include profile, addresses, chat history, or documents). — **Fix:** add a "Download my data" action producing a JSON bundle.
- ❌ **Retention limits defined and enforced.** The only TTL in the codebase is `CacheService._ttlMinutes = 30` (`lib/services/cache_service.dart:7`), which governs an API cache with exactly one call site (`lib/providers/app_provider.dart:190`) — not patient records. Orders, assessments, addresses, reminders, chat messages, vitals, attendance and uploaded medical images all persist indefinitely with no documented retention period.

### 12. Hardening & incident readiness

- ⚠️ **Input validation / output encoding against injection.** Client-side validation is present and reasonable: `Validators.indianMobile` + `FilteringTextInputFormatter.digitsOnly` on phone (`lib/screens/auth/login_screen.dart:157,171`), `Validators.name` (`lib/screens/auth/onboarding_screen.dart:60`), `Validators.pincode` (`lib/screens/checkout/address_selection_screen.dart:540`), bounded numeric vitals with `LengthLimitingTextInputFormatter` (`lib/screens/reports/vitals_screen.dart:834-840`). All requests are `jsonEncode`d, never string-concatenated (`lib/services/api_service.dart:115,125`), so no client-side injection sink. Firestore writes are type- and length-checked in rules (`firestore.rules:79-82`). Graded ⚠️ only because client validation is advisory — the REST backend is out of repo, so server-side validation is unverified (**BLOCKED-OWNER**).
- ⚠️ **Error responses don't leak internals.** The **UI** is clean: `_handleResponse` (`lib/services/api_service.dart:138-150`) surfaces only `body['message']`, and `ErrorWidget.builder` is replaced with a friendly fallback (`lib/main.dart:137`). One residual UI path: `lib/widgets/paginated_list.dart:89` assigns `_error = e.toString()` into rendered state. The **logs** are not clean — fully covered in §2.
- ❌ **Audit logging for security-relevant actions.** `git grep -nIi "audit_log|auditLog|AuditEvent" -- lib/ functions/` → **no output**. `firestore.rules:154` lists `audit_logs/{logId}` as a TODO that was never modelled. Nothing records who exported a handover PDF, who viewed medical documents, or when a role changed. Under DPDP breach-notification duties, there would be no way to establish what a compromised account actually accessed. — **Fix:** log export/view of PHI to a backend-write-only `audit_logs` collection.
- ❌ **You know what a device/account/server compromise would expose, and have a plan to revoke access / rotate keys.** No `SECURITY_REVIEW.md`, no incident runbook, no key-rotation procedure beyond the Anthropic key note in `PROJECT.md:66`. `docs/` contains a `DEPLOYMENT_GUIDE.md` and `TROUBLESHOOTING.md` but nothing security-operational. Combined with the missing data inventory (§1) and missing audit log (above), the blast radius of a compromise is currently unknowable.

---

## Blockers (must fix before release)

**B-1. Firebase Storage has no security rules in the repo — patient medical images may be readable by any signed-in user.**
`firebase.json` (read in full) configures `functions`, `firestore`, and `auth` — **there is no `storage` block**, and `git ls-files | grep storage.rules` returns nothing. Yet chat photos and concern-evidence photos are uploaded to Firebase Storage (`lib/services/firebase_service.dart:133-138`) from `lib/screens/chat/chat_screen.dart:133` and `lib/screens/support/raise_concern_screen.dart:328`. Firebase's default bucket rule is `allow read, write: if request.auth != null` — i.e. **any authenticated Housepital user could read every other patient's uploaded medical images**. Additionally `getDownloadURL()` (`lib/services/firebase_service.dart:138`) mints a permanent token URL that bypasses rules entirely once shared, and that URL is persisted into chat records. This is the single highest-severity PHI exposure found. **BLOCKED-OWNER to confirm live state** — need Firebase Console → Storage → Rules. **Fix:** add `storage.rules` scoped to `chat/{patientId}/**` and `concerns/{patientId}/**` with `request.auth.uid == patientId`, register it in `firebase.json`, and deploy.

**B-2. Missing iOS camera/photo-library usage strings — hard crash on six screens.**
`ios/Runner/Info.plist` has only `NSMicrophoneUsageDescription` (:69) and `NSSpeechRecognitionUsageDescription` (:71). `image_picker` is invoked from 12 call sites including the primary medical-record capture flow (`lib/screens/documents/document_repository_screen.dart:613,631`). On iOS this terminates the process. **Fix:** add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` with clinical-document-specific wording.

**B-3. Assistant Cloud Function is unauthenticated with wildcard CORS.**
`functions/index.js:112-118` — `onRequest` + `cors: true`, no token verification, no App Check, no rate limit; client sends no auth header (`lib/services/assistant_service.dart:55`). Open proxy to a paid Claude endpoint with unbounded cost. **Fix:** enforce App Check + `verifyIdToken`, add a per-uid quota.

**B-4. PHI written to release logs.**
`lib/screens/services/cards/staff_role_card.dart:308-311` (care-needs checklist), `lib/services/firebase_service.dart:129-130` (medical-document filenames), and ~28 `error: e` sites leaking patient-ID-bearing URLs — none stripped in release (`lib/utils/logger.dart:54-57` strips only debug/info; `debugPrint` is never stripped). Plus `lib/main.dart:278-283` dumping full stacks to the browser console on web release.

**B-5. No account deletion — App Store Guideline 5.1.1(v) rejection + DPDP §12 violation.**
No delete path anywhere in `lib/` or `assets/i18n/en.json`. Hard blocker for iOS submission.

**B-6. Sensitive exports are not role-gated in code.**
`lib/services/handover_report_service.dart:302-307` has no role check; the three call sites only hide the button. Invoice export (`lib/screens/services/my_orders_screen.dart:390-394`) and the entire document repository have no gate at all — a `CARETAKER` can reach both.

## High

- **H-1.** Android `allowBackup` defaults to true → plaintext PHI SharedPreferences swept into Google Drive backup (`android/app/src/main/AndroidManifest.xml`, no `allowBackup`/`dataExtractionRules`).
- **H-2.** Crashlytics + Performance forced on in release with no consent and no opt-out (`lib/main.dart:120-123`); raw errors + stacks exported unscrubbed (`:115,117,279`). The `TODO(observability)` at `lib/utils/logger.dart:63` would, if wired as written, additionally export all ~40 release-surviving `Log.warn` sites.
- **H-3.** `logout()` leaves patient PHI in memory — no `clearAuthToken` on `IApiService` (`lib/services/i_api_service.dart:12`), no provider reset (`lib/screens/settings/settings_screen.dart:440-443`), providers are app-root singletons (`lib/main.dart:184-267`).
- **H-4.** Missing `ios/Runner/PrivacyInfo.xcprivacy` (app target) — App Store rejection; `shared_preferences` uses required-reason API CA92.1.
- **H-5.** Role is a client-side mutable string with a hardcoded default (`lib/providers/app_provider.dart:19,22`; `lib/main.dart:227`) — no server-verified claim backs any authorization decision.
- **H-6.** No app-lock/biometric/screenshot protection on PHI screens; no re-auth before handover export.
- **H-7.** No PII redaction before the LLM call (`lib/providers/assistant_provider.dart:95-100` → `functions/index.js:173`).

## Medium / Low

- **M-1.** `android/app/google-services.json` + `lib/config/firebase_options.dart` committed despite the `.gitignore` rule (`.gitignore:56-57` is inert on tracked files); 3 `AIza…` keys in history from `5a0ca2e`. **Correct `CLAUDE.md:48`** — only the iOS plist is gitignored. Client keys are public-by-design; the real control is console restriction (BLOCKED-OWNER) + Storage rules (B-1).
- **M-2.** Orphan `SCHEDULE_EXACT_ALARM` (`android/app/src/main/AndroidManifest.xml:3`) while both schedules are inexact (`lib/services/medication_reminder_service.dart:178,228`) — Play policy-restricted for no benefit.
- **M-3.** `image_picker` denial unhandled in 4 of 6 screens (`lib/screens/settings/settings_screen.dart:69`, `lib/screens/settings/patient_profile_screen.dart:205`, `lib/screens/rental/return_screen.dart:315`, `lib/screens/chat/chat_screen.dart:121`); mic denial fails silently (`lib/providers/assistant_provider.dart:166`).
- **M-4.** `firestore.rules` conflates `auth.uid` with `patientId` (`:64-66`, and every rule) — the multi-patient path (`lib/providers/app_provider.dart:167`) has no isolation model. No rules test proves absence of cross-leak.
- **M-5.** Missing `ITSAppUsesNonExemptEncryption` in `ios/Runner/Info.plist` — manual export-compliance prompt on every upload.
- **M-6.** `functions/package-lock.json` not committed; no Dependabot, no `npm audit`/`pub outdated`/OSV step in `.github/workflows/ci.yml`.
- **M-7.** `dio ^5.8.0+1` declared in `pubspec.yaml` but never imported in `lib/` — remove.
- **M-8.** No code-level HTTPS assertion on `ApiService.baseUrl` (`lib/services/api_service.dart:37-41`) or `AssistantService.assistantUrl` (`lib/services/assistant_service.dart:33`).
- **M-9.** Single Firebase project for all environments (`lib/config/firebase_options.dart:26,35,47`) — dev/CI writes share the production datastore.
- **M-10.** `emailPassword` auth provider enabled (`firebase.json:16`) but unused by any code path — unnecessary auth surface.
- **M-11.** `NSSpeechRecognitionUsageDescription` (`ios/Runner/Info.plist:72`) does not disclose that recognition may be server-side (`lib/services/voice_service.dart:48` omits `onDevice`).
- **L-1.** `lib/widgets/paginated_list.dart:89` puts `e.toString()` into rendered state.
- **L-2.** No audit logging; `firestore.rules:154` TODO never modelled.
- **L-3.** No retention limits on any stored PHI.
- **L-4.** `patient_id` sent to the assistant (`lib/models/assistant_models.dart:126`) but unused by `functions/index.js` — collected without purpose.
- **L-5.** No `SECURITY_REVIEW.md` / data inventory / incident runbook (the checklist's own closing requirement).

## BLOCKED-OWNER

| # | Item | Exactly what is needed |
|---|---|---|
| 1 | **Live Firebase Storage rules** (blocks B-1) | Firebase Console → Storage → Rules tab, full text |
| 2 | Live Firestore rules match the repo | Console → Firestore → Rules (`firestore.rules:9-17` says deploy happens from another repo) |
| 3 | Firebase API key restrictions | GCP Console → Credentials → each of the 3 `AIza…` keys → Application + API restrictions |
| 4 | App Check enforcement status | Firebase Console → App Check (gates B-3 and OTP abuse) |
| 5 | SMS/OTP abuse protection & quotas | Firebase Console → Authentication → Settings → SMS region policy |
| 6 | Privacy policy is live and accurate | `https://housepital.in/privacy` loading + its text, to check against §7's SDK table |
| 7 | App Store Connect App Privacy answers | Screenshot of the App Privacy section |
| 8 | Backend REST API authorization | The `api.housepital.in` service is out of repo — server-side authz, rate limiting, and input validation cannot be audited (relevant to §6 and §12) |
| 9 | Anthropic account spend limit | Console budget cap (mitigates B-3's cost exposure) |

---

*Generated as a read-only audit. No source file was modified.*
