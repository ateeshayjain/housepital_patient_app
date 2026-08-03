# Post-Launch Operations Checklist (App-Agnostic) — Audit vs commit `803124d`

**Date:** 2026-08-03 · **Auditor:** post-launch-ops agent · **Repo:** `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`

The app has **not launched**. Every item is therefore graded as *readiness to operate on day 1*, not
as operational history. "No crash reports reviewed yet" is not a failure; "no working way to review
them" is.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Release mechanics | 0 | 3 | 2 | 1 |
| 2. Monitoring cadence | 0 | 0 | 4 | 0 |
| 3. Incident response | 0 | 3 | 2 | 0 |
| 4. Support readiness | 0 | 1 | 3 | 1 |
| 5. Feedback → roadmap | 0 | 3 | 1 | 0 |
| 6. Data stewardship | 1 | 1 | 2 | 0 |
| **Total (28)** | **1** | **11** | **14** | **2** |

---

## Findings

### 1. Release mechanics (before pressing the button)

- ❌ **Phased release ON unless there is a written reason.** — evidence: no release automation of any
  kind in the repo (`.github/workflows/ci.yml` runs analyze/design-gate/test/coverage only; no
  `fastlane/`, no release job). More decisively, `android/app/build.gradle.kts:36-40` still signs
  release with the debug keystore:
  ```kotlin
  release {
      // TODO: Add your own signing config for the release build.
      signingConfig = signingConfigs.getByName("debug")
  }
  ```
  A debug-signed AAB cannot be uploaded to Play at all, so there is no phased rollout to switch on.
  **Impact:** the primary rollback lever named in `docs/DEPLOYMENT_GUIDE.md:§9` ("Use Google Play
  Console staged rollout, halt rollout") does not exist for the Android track.
  **Fix:** create `android/key.properties` + a real `signingConfigs.release`, then enable a 1%→100%
  staged rollout on the Play track and a phased release on App Store Connect. **BLOCKED-OWNER** for
  the store-side toggle.

- ⚠️ **Halt criteria decided IN ADVANCE.** — evidence: `docs/DEPLOYMENT_GUIDE.md:§7a.5` names
  numbers — "Velocity alerts: trigger when a fatal issue affects > 0.1% of users in 1h", "app start
  > 5s p95, HTTP > 3s p95". Those are *alerting* thresholds to be configured in the Firebase console,
  and they are written as future work ("Once builds are flowing crashes"). No document states *what
  pauses the rollout* — no report-count trigger, no data-loss signal.
  **Fix:** add a 4-line "Halt criteria" block to `DEPLOYMENT_GUIDE.md §9`: halt if crash-free
  sessions < 99.0%, or ≥3 independent reports of wrong medication/vitals display, or any payment
  captured without a backend record.

- ⚠️ **The rollback story for THIS release is named.** — evidence: `docs/DEPLOYMENT_GUIDE.md:§9`
  documents three generic rollbacks (Cloud Functions redeploy from git, MySQL manual restore,
  Play staged-rollout halt / iOS "submit a new version"). It is honest that iOS has no rollback.
  What is missing is the third option in the checklist's triad — **there is no flag to flip.** See
  §"Remote control" below: zero feature flags, zero kill switches, zero force-upgrade in the binary.
  So for every release the rollback story reduces to "halt the phase (Android only) or hotfix".
  **Fix:** name the story per release in the commit/PR description; add Remote Config (below) so the
  option actually exists.

- ❌ **Server-side prerequisites verified done — not remembered as done.** — evidence: three
  prerequisites are recorded in the repo as *pending*, not verified:
  - `docs/KNOWN_ISSUES.md:26` BUG-33 — hardened `firestore.rules` is "Resolved 2026-05-28 (file
    hardened — **deployment to console pending**)".
  - `docs/KNOWN_ISSUES.md:27` BUG-34 — Firebase API key restrictions "Open (console action required)".
  - `.firebaserc` is **empty** (`{"projects":{},"targets":{},"etags":{}}`) — every `firebase deploy`
    command in `DEPLOYMENT_GUIDE.md` §1.2/§1.3/§3.3 will fail from this repo without an explicit
    `--project housepital-patient`. The guide's own commands `cd` to a different repo path
    (`/Users/ateeshayjain/housepital-backend`) that is not in this working tree.
  **Impact:** the prerequisite list is remembered, not verified — exactly the red flag the checklist
  names ("a schema deploy done from memory").
  **Fix:** `firebase use --add housepital-patient` to populate `.firebaserc`; then run
  `firebase firestore:rules get --project housepital-patient` and paste the output + timestamp into
  BUG-33 before release.

- ⚠️ **Release notes are honest.** — evidence: `docs/CHANGELOG.md` is thorough and dated but is
  engineer-facing (commit SHAs, file paths, "`_priceMultiplier` in `service_booking_screen.dart`").
  No store-facing release-notes artifact exists in the repo, and no "update-together" callout — which
  matters here because the patient app pairs with a staff app and a backend (`SyncService` pulls
  attendance/vitals written by the staff app, `lib/services/sync_service.dart:46-62`).
  **BLOCKED-OWNER** for the actual store listing text. **Fix:** add a `docs/RELEASE_NOTES.md` with a
  user-language section per version.

- N/A **Previous release's archive retained and installable.** — no prior release exists
  (`pubspec.yaml:4` `version: 1.0.0+1`, first build). **BLOCKED-OWNER** to confirm the App Store
  Connect / Play archive retention policy from build 1 onward.

---

### 2. Monitoring cadence (no telemetry required)

- ❌ **Crash reports checked DAILY for the first week, with a written trigger threshold.** — the
  *mechanism* is half-built and would under-report on the primary (iOS-first) platform.

  What is correctly wired, in `lib/main.dart`:
  - `main.dart:98` — whole app wrapped in `runZonedGuarded`, uncaught zone errors reach
    `main.dart:274-284` → `FirebaseCrashlytics.instance.recordError(error, stack, fatal: true)`.
  - `main.dart:114-115` — `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`
    (Flutter framework errors ✅).
  - `main.dart:116-119` — `PlatformDispatcher.instance.onError` → `recordError(..., fatal: true)`
    (async errors on the root isolate ✅).
  - `main.dart:110` — the web guard the repo history refers to is present and correct: the guard axis
    is `kIsWeb`, not `kDebugMode`, with the reason documented at `main.dart:104-109` (touching
    `FirebaseCrashlytics.instance` on web aborted `main()` before `runApp()` → blank white Chrome
    screen). The zone handler repeats the guard at `main.dart:278`. ✅ correct.
  - `main.dart:120-131` — collection explicitly enabled in release, disabled in debug.

  What is missing:
  1. **Background isolate errors are not captured.** There is no
     `Isolate.current.addErrorListener` anywhere (`grep -rn "addErrorListener" lib/` → no matches).
     Any crash inside a `compute()`/spawned isolate is lost.
  2. **iOS crash reports will be unsymbolicated.** `ios/Runner.xcodeproj/project.pbxproj` contains
     four `PBXShellScriptBuildPhase` entries (lines 280-390): Thin Binary, `[CP] Embed Pods
     Frameworks`, `[CP] Check Pods Manifest.lock`, `[CP] Copy Pods Resources`, and the Flutter build
     script. **There is no Crashlytics `upload-symbols` run script.** `DEBUG_INFORMATION_FORMAT =
     "dwarf-with-dsym"` is set (`pbxproj:472,653`) so dSYMs are produced but never uploaded.
     `DEPLOYMENT_GUIDE.md:§7a.5` even says "Verify Crashlytics dSYM upload is working on iOS (Run
     Script phase in Xcode). Without dSYMs, all iOS crash reports are obfuscated and useless" — the
     doc claims the check; the project file shows it was never done.
  3. **Android has no Crashlytics Gradle plugin.** `android/app/build.gradle.kts:1-6` applies only
     `com.android.application`, `kotlin-android`, `dev.flutter.flutter-gradle-plugin`. Neither
     `com.google.gms.google-services` nor `com.google.firebase.crashlytics` is applied, so no mapping
     /symbol upload happens on Android either.
  4. **Non-fatals are never reported.** `lib/utils/logger.dart:63-65` is an explicit unfinished hook:
     ```dart
     // TODO(observability): forward warn/error to FirebaseCrashlytics.recordError
     // here once a non-fatal reporting policy is decided.
     ```
     Every `Log.warn(...)` in the app — including *every backend outage* (`app_provider.dart:215`,
     `my_care_provider.dart:85`, `medication_provider.dart:205`, `sync_service.dart:69`,
     `payment_service.dart:195`) — goes to `debugPrint` and nowhere else. On a release build nobody
     sees it.
  5. No cadence document anywhere: `grep -rni "daily\|cadence" docs/DEPLOYMENT_GUIDE.md` finds no
     review schedule.
  **Fix (highest value, ~10 lines):** add the Crashlytics run-script phase in Xcode; apply the
  Crashlytics + google-services Gradle plugins; add `Isolate.current.addErrorListener` in `main()`;
  and complete the `logger.dart:63` TODO so `Log.warn`/`Log.error` call
  `FirebaseCrashlytics.instance.recordError(..., fatal: false)`.
  **BLOCKED-OWNER** for the console-side velocity/new-issue alert configuration
  (`DEPLOYMENT_GUIDE.md:§7a.5` steps 2-4) and for who reads them each morning.

- ❌ **Store reviews and beta feedback read on a schedule, triaged bug/confusion/request/noise.** —
  evidence: no triage doc, no review-response template, no reviewer rota in the repo.
  `docs/KNOWN_ISSUES.md` is an engineering defect list, not a feedback intake.
  **BLOCKED-OWNER:** needs a named owner + a weekly slot; nothing in code can substitute.

- ❌ **User-visible failure surfaces are treated as monitoring.** — **the app has no user-visible
  failure surface for a backend outage at all.** This is the finding that matters most; see the
  dedicated analysis in §"Demo mode vs a real outage" below.

- ❌ **A "first 48 hours" smoke pass on a production install (top three flows, real device, store
  build).** — evidence: `test/screens/overflow_smoke_test.dart` is a *widget* smoke test
  (37 screens × 320/375/414), not a device pass; `docs/TEST_STRATEGY.md` and `docs/TEST_MAP.md`
  describe the automated suite only. No manual smoke script exists naming the top-3 flows.
  **Fix:** add `docs/SMOKE_PASS.md` with the three flows that define this product — (1) SOS →
  dialer opens, (2) book a caretaker → cart → pay → order appears in My Orders, (3) open My Care →
  today's vitals + medication schedule — each with the expected result on a *store* build.
  **BLOCKED-OWNER** to run it.

---

### 3. Incident response

- ⚠️ **A severity ladder exists and is written down.** — evidence: `docs/KNOWN_ISSUES.md:19,31,47,63`
  provides four buckets — "Critical (Blocks Release)", "High (Fix Before Launch)", "Medium (Fix After
  Launch)", "Low (Nice to Have)". That is a *backlog priority* ladder keyed to launch, not an
  *incident* ladder keyed to user harm. Nothing maps a live symptom to a severity, and there is no
  S1 "data loss/corruption" tier — which for a healthcare app should read "wrong dosage, wrong
  vitals, or wrong patient displayed → drop everything".
  **Fix:** add a 5-line severity table to `KNOWN_ISSUES.md` with healthcare-specific S1 wording.

- ⚠️ **Each severity has a target response: acknowledge, workaround comms, fix.** — evidence: a real
  SLA exists but it is the *patient concern* SLA, not an engineering one:
  `lib/config/constants.dart:52-57` `concernSla = {emergency: 2, high: 12, medium: 24, low: 72}` (hours).
  And `docs/KNOWN_ISSUES.md:96` TD-11 says it is inert: "Concern SLA tracking exists in constants but
  is **not enforced or alerted on the backend**". So the SLA is a constant no clock enforces.
  **Impact:** a 2-hour emergency-concern promise with no timer behind it.

- ❌ **Known-issue communication path exists.** — evidence: no review-reply template, no TestFlight
  notes template, no support-reply template anywhere in `docs/`. `grep -rni "template" docs/` returns
  nothing relevant. Silence is the current default.

- ❌ **Expedited-review criteria known in advance.** — evidence: no mention of expedited review in
  `docs/DEPLOYMENT_GUIDE.md` or any other doc. **Fix:** one paragraph in `DEPLOYMENT_GUIDE.md §9`
  naming what qualifies (SOS broken, wrong dosage rendered, payment double-charge) and the Apple/Google
  request URLs.

- ⚠️ **Post-incident: the cause becomes a checklist line or a test.** — evidence: the *practice* is
  visibly real. Field-round regressions carry their cause into tests and comments, e.g.
  `lib/providers/my_care_provider.dart:82-95` documents the "tapping those cards opened nothing"
  field report and its fallback, and `docs/CHANGELOG.md` records each round. Test files reference
  their originating defects (`test/services/api_service_test.dart`, `test/providers/auth_provider_test.dart`,
  `test/screens/sos/sos_screen_test.dart` — 16 test files mention a BUG-/audit- id). But there is no
  written *policy*, and `docs/KNOWN_ISSUES.md:40` BUG-07 records 3 known-failing widget tests in
  `test/screens/my_care/my_care_widgets_test.dart` still "Open — cause unknown, needs triage", which
  erodes the signal a red suite is supposed to carry.

---

### 4. Support readiness

- ❌ **The support channel published in the store listing is real, monitored, and answered within a
  stated window.** — **BLOCKER.** Three in-app support entry points still carry placeholder numbers:
  - `lib/screens/settings/help_faq_screen.dart:352` — `_launchUrl('tel:+919999999999')` ("Call")
  - `lib/screens/settings/help_faq_screen.dart:364-365` — `https://wa.me/919999999999?text=…` ("WhatsApp")
  - `lib/screens/my_care/staff_otp_verification_screen.dart:352-353` — `tel:+918888888888`, with the
    comment `// NOTE: Support number to be updated with production contact details.`

  The real number exists two files away — `lib/config/constants.dart:17,19`
  `emergencyPhone = supportPhone = '9990911911'` — and is used correctly by SOS, Home and the
  assistant. Only the Help/FAQ screen and the staff-OTP fallback were missed. The email
  (`mailto:wecare@housepital.in`, `help_faq_screen.dart:358`) is plausible but unverified —
  **BLOCKED-OWNER** to confirm it is monitored and to state the answer window.

  **Compounding Android defect:** `android/app/src/main/AndroidManifest.xml` declares only a
  `PROCESS_TEXT` `<queries>` block (lines 39-46). On Android 11+ (API 30), `canLaunchUrl` for
  `tel:`, `mailto:` and `https:` returns **false** without matching `<queries>` entries, so every
  `canLaunchUrl`-guarded support path degrades to its failure branch:
  `help_faq_screen.dart:406-413` shows "Could not open link"; `sos_screen.dart:251-288` shows the
  "Could not auto-dial" dialog. SOS degrades gracefully (copy-number dialog — good design), but the
  *whole support surface* is a dead end on modern Android.
  **Fix:** replace the placeholders with `AppConstants.supportPhone`, and add to the main manifest:
  ```xml
  <queries>
    <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
    <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="mailto"/></intent>
    <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
  </queries>
  ```

- ❌ **Diagnostic playbooks exist for the top three failure symptoms of THIS app.** — evidence:
  `docs/TROUBLESHOOTING.md` is 14 KB and entirely developer-facing. Its section headings
  (lines 9, 99, 129, 180, 226, 251, 316, 384, 420, 435, 482) are: Flutter Build Failures, Firebase
  Auth Issues, Cloud Functions Deployment Errors, MySQL Connection Issues, Bottom Sheet Navigation,
  Razorpay Issues, Service Worker Caching (Web), Port Conflicts, Cart Issues, Test Failures,
  Environment-Specific Issues. Not one entry starts from a *user symptom*.
  **Impact:** when a family member says "my mother's vitals are from last week" or "the app says I
  have medicines I never had", there is no path from symptom to cause. Given the silent demo
  fallback (below), those are the two most likely first tickets.
  **Fix:** add a user-symptom section to `TROUBLESHOOTING.md` covering the three most probable:
  (a) "data looks wrong / not mine" → is the app on demo fallback? ask for the Last-updated string
  (once it is rendered — see below); (b) "staff didn't show as checked-in" → staff-app side, attendance
  sync; (c) "I paid but the order shows unpaid" → payment verification outcome.

- ⚠️ **A user can produce diagnostics without engineering.** — evidence: a version string is readable
  in two places, but both are hand-typed constants that will drift from the build:
  `lib/screens/settings/about_screen.dart:11` `static const _appVersion = '1.0.0';` (rendered at
  `about_screen.dart:69`) and `lib/screens/settings/settings_screen.dart:257` `'Housepital v1.0.0'`.
  Neither shows a **build number**, so "1.0.0" cannot distinguish build 1 from build 40 — the single
  most useful thing a caller can read aloud. `package_info_plus` is not a dependency
  (`pubspec.yaml` has no entry). There is no log export and no diagnostics screen.
  **Fix:** add `package_info_plus`, render `"$version ($buildNumber)"` from
  `PackageInfo.fromPlatform()` in both places, and delete the two constants.

- N/A **Destructive advice appears only with its data consequences spelled out.** — there is no
  user-facing playbook containing destructive advice, because there is no user-facing playbook at
  all (see above). The developer-facing `flutter clean` / "Clear all browsing data" instructions in
  `docs/TROUBLESHOOTING.md:20,331` are not user advice. Re-grade once 4.2 is written.

- ❌ **Household/multi-user apps: playbooks cover the OTHER person's phone too.** — this app is
  squarely multi-user: `lib/screens/settings/family_members_screen.dart`, `add_patient_screen.dart`,
  a four-way role model (`lib/utils/permissions.dart`, roles patient-self / primary contact / family
  / caretaker), and a companion staff app whose writes this app reads via
  `lib/services/sync_service.dart`. The reporter ("my daughter's phone doesn't show the report") is
  routinely not the affected device. No playbook covers this.

---

### 5. Feedback → roadmap loop

- ⚠️ **Every confirmed user-reported bug becomes a regression test before the fix ships.** —
  evidence for the practice: 102 test files (`find test -name "*.dart" | wc -l` → 102), with
  regression intent stated in-file, e.g. `test/services/payment_service_test.dart:14` ("createOrder
  happy path returns order_id; backend failure returns null"), and CI enforces the suite plus a
  coverage floor (`.github/workflows/ci.yml`, Test + coverage-gate steps, threshold 50%).
  Evidence against a *guarantee*: no written policy, and `docs/KNOWN_ISSUES.md:40` BUG-07 leaves 3
  widget tests failing with "cause unknown".

- ⚠️ **User words are preserved in the tracker.** — partially. `docs/CHANGELOG.md` and code comments
  do preserve some verbatim reports (`my_care_provider.dart:88` "so tapping those cards 'opened
  nothing' (field report)"; `payment_service.dart:39-40` quotes the on-device error text
  "Error" seen 2026-06-11). But `docs/KNOWN_ISSUES.md` entries are uniformly engineer-paraphrased
  ("Vitals chart Y-axis may not auto-scale for extreme edge cases"), which is exactly the phrasing
  that will fail to match the next duplicate report.

- ❌ **A visible changelog closes the loop.** — evidence: `grep -rni "what's new|changelog|release
  notes" lib/ assets/i18n/` returns **no matches**. `docs/CHANGELOG.md` (50 KB) never reaches a user.
  The About screen (`lib/screens/settings/about_screen.dart`) shows version, company, CIN, Terms and
  Privacy links — no "What's new". A reporter cannot see their bug fixed.

- ⚠️ **Requests triaged against the roadmap on a cadence.** — evidence: `docs/KNOWN_ISSUES.md`
  has dated priority buckets with `Found` dates — real triage structure. But its header says
  **"Last updated: 2026-05-28 (audit batch 4)"** while HEAD is `803124d` dated ~2026-08; five field
  rounds and a business-rule reversal landed since (see `docs/CHANGELOG.md` entries for 2026-06-13).
  The tracker is ~2 months stale, and several entries are already wrong — e.g. BUG-14 "Invoice PDF
  download is a stub" contradicts `lib/services/invoice_pdf_service.dart:96,261` and
  `test/services/invoice_pdf_service_test.dart`.

---

### 6. Data stewardship (standing duties)

- ⚠️ **The schema-deploy runbook is a living document, executable by a stressed human at midnight.**
  — evidence: `docs/DEPLOYMENT_GUIDE.md` §2.2/§2.3 gives literal, copy-pasteable commands
  (`cloud-sql-proxy housepital-patient:asia-south1:housepital-db --port=3306`, then
  `mysql -h 127.0.0.1 -u housepital -p housepital < sql/001_initial_schema.sql`) and §1 names the
  environment (`housepital-patient`, `asia-south1`). That is genuinely good. Three things break it
  at midnight: (a) every command `cd`s to `/Users/ateeshayjain/housepital-backend`, a path not in
  this repo and not guaranteed on the operator's machine; (b) `.firebaserc` is empty so no default
  project is set — the `firebase deploy` lines need `--project housepital-patient` appended;
  (c) there is **no app-side schema stamp to bump** — no schema/version constant exists in
  `lib/config/constants.dart`, so nothing in the app records which schema it expects.
  Header says "Last updated: 2026-05-28"; the pinned versions inside it
  (`firebase_crashlytics: 4.3.10`, `firebase_performance: 0.10.1+10`, §7a.5) already disagree with
  `pubspec.yaml` (`^4.3.5`, `^0.10.1+5`), and §7a step 1 restricts package
  `in.housepital.patient` while the actual id is `com.housepital.housepital_patient`
  (`android/app/build.gradle.kts:12,25`) — a key restriction applied to the wrong package would lock
  the real app out.

- ✅ **Export/backup is verified WORKING in every release.** — evidence: the two on-device export
  paths are real and covered by tests that run on every CI push —
  `lib/services/invoice_pdf_service.dart:96` `buildInvoicePdf(...)` / `:261` `shareInvoice(...)`
  with `test/services/invoice_pdf_service_test.dart`, and `lib/services/handover_report_service.dart`
  with `test/services/handover_report_service_test.dart`. `.github/workflows/ci.yml` runs the full
  suite on every push/PR to `main`, so these cannot silently rot. (Caveat, not a failure of this
  line: these are *document* exports; there is no full "export all my data" path — see 6.3.)

- ❌ **Account/data deletion paths are re-verified each release, including server copies.** —
  evidence: `grep -rni "delete account|deleteAccount|delete_account" lib/` → **no matches**. The
  Settings screen (`lib/screens/settings/settings_screen.dart:185-257`) offers My Orders, Add
  Patient, Medical Documents, Appearance, Refer & Earn, About — no account or data deletion. There
  is therefore nothing to re-verify, and no server-copy deletion story.
  **Impact:** beyond the standing duty, this is an App Store Guideline 5.1.1(v) rejection risk for
  an app that creates accounts (phone OTP, `lib/screens/auth/otp_screen.dart`), and a DPDP Act
  erasure gap for health data.
  **Fix:** add a "Delete my account" row in Settings that calls a backend endpoint deleting the
  MySQL rows + Firestore documents + Storage objects, with an in-app confirmation naming what is lost.

- ❌ **Privacy labels and policy re-read whenever a release adds a data type.** — evidence: the app
  collects a lot and declares little.
  - `ios/Runner/Info.plist` contains **only two** usage strings (`grep -n "NS[A-Za-z]*UsageDescription"`
    → lines 69 `NSMicrophoneUsageDescription`, 71 `NSSpeechRecognitionUsageDescription`). There is
    **no `NSCameraUsageDescription` and no `NSPhotoLibraryUsageDescription`**, yet `image_picker` is
    invoked from six places: `settings_screen.dart:54,59`, `patient_profile_screen.dart:190,195`,
    `rental/return_screen.dart:316`, `chat/chat_screen.dart:122`,
    `support/raise_concern_screen.dart:77,85`, `documents/document_repository_screen.dart:614`.
    iOS **terminates the app** when a camera/photo API is called without the string — so the primary
    support flow ("Raise a concern" with evidence photos) crashes on first use on iOS.
  - No `PrivacyInfo.xcprivacy` exists (`find ios -name "PrivacyInfo.xcprivacy" -not -path "*/Pods/*"`
    → no matches), required for App Store submission given `shared_preferences` (UserDefaults) usage.
  - The privacy policy is a remote URL only (`about_screen.dart:98,103` →
    `https://housepital.in/terms`, `/privacy`), so app/policy drift cannot be detected from the repo.
  **Fix:** add the two Info.plist strings and a `PrivacyInfo.xcprivacy` before the first submission.
  **BLOCKED-OWNER** to re-read the published policy against the current data set (health vitals,
  medication names, photos, voice, location-free address, phone).

---

## Directed analysis (as briefed)

### Crash reporting — is it real on all platforms?

| Error class | Captured? | Evidence |
|---|---|---|
| Flutter framework build/layout errors | ✅ | `lib/main.dart:114-115` `FlutterError.onError = recordFlutterFatalError` |
| Async errors on the root isolate | ✅ | `lib/main.dart:116-119` `PlatformDispatcher.instance.onError` |
| Uncaught zone errors (unawaited futures, timers) | ✅ | `lib/main.dart:98` `runZonedGuarded` → `:274-284` |
| Background/spawned isolate errors | ❌ | no `Isolate.current.addErrorListener` anywhere in `lib/` |
| Non-fatal handled failures (every API outage) | ❌ | `lib/utils/logger.dart:63` TODO — `Log.warn`/`Log.error` stop at `debugPrint` |
| iOS symbolication | ❌ | no `upload-symbols` run-script phase in `ios/Runner.xcodeproj/project.pbxproj` |
| Android symbol/mapping upload | ❌ | `com.google.firebase.crashlytics` plugin absent from `android/app/build.gradle.kts:1-6` |
| Web | N/A by design | `main.dart:110` `if (!kIsWeb)` — correct; Crashlytics has no web implementation |
| Debug builds | ✅ suppressed | `main.dart:113,124-131` collection off in debug |

The web guard referenced in the repo history is present, correct, and correctly reasoned
(`main.dart:104-109`) — it guards on platform, not build mode, in both the setup block and the zone
handler. That is the right axis.

**Net:** the app will report *crashes* on Android, will report crashes on iOS in an unreadable form,
and will report *nothing at all* about backend failures on either.

### Analytics — could the team answer "did anyone complete a booking yesterday?"

**No.** There is no analytics SDK and no event instrumentation of any kind:
`firebase_analytics` is absent from `pubspec.yaml`; `grep -rni "analytics|logEvent|amplitude|mixpanel|posthog|sentry" lib/`
returns only false positives (`_buildCareGuidesEntry` in `home_screen.dart`). `firebase_performance`
is initialised (`main.dart:122-123`) and will give automatic app-start and HTTP traces, but
`FirebasePerformance` records latency, not funnels — it cannot answer whether a booking completed.

Zero of the flows that define the business are instrumented: cart add, checkout start, payment
success/failure, booking confirmed, SOS tapped, concern raised, assistant used.

**Impact:** on day 1 the only feedback channels are crash reports (degraded, above) and phone calls.
A booking funnel that silently breaks — say `_priceMultiplier` mis-multiplying, or the payment
success path never firing — produces no signal until a customer calls.

**Fix (small):** add `firebase_analytics`, and log six events at the existing call sites:
`sos_opened` (`sos_screen.dart:56`), `booking_started` / `booking_confirmed`
(`service_booking_screen.dart`, `booking_confirmation_screen.dart`), `payment_succeeded` /
`payment_failed` (`payment_screen.dart:222,236`), `concern_raised`
(`raise_concern_screen.dart:342`). That is enough to answer the question above.

### Remote control — flags, kill switch, force upgrade

**None exist.** `grep -rni "remote_config|RemoteConfig|featureFlag|killSwitch|forceUpgrade|minimumVersion|maintenanceMode"`
across `lib/`, `functions/`, `android/`, `ios/` matches only transitive CocoaPods entries
(`ios/Podfile.lock:1271,1314-1329` — `FirebaseRemoteConfigInterop` pulled in by
`firebase_performance`, never used from Dart). There is no `firebase_remote_config` dependency in
`pubspec.yaml`, no minimum-version check, no maintenance screen, no per-feature toggle.

The only "switches" are **compile-time**: `String.fromEnvironment` for `RAZORPAY_KEY` and
`ASSISTANT_API_URL` (`lib/config/constants.dart:11,25`). Changing either requires a new binary and a
store review.

**For a healthcare app, the concrete answer to "what if a dosage-display bug ships":** today the
options are (1) halt the Android staged rollout — which does not exist yet, since the release build
is debug-signed; (2) hotfix and wait for review — 24h+ on iOS, with no expedited-review process
documented (§3.4); (3) phone every patient. Users already on the bad build keep seeing the bad
dosage the entire time. `lib/screens/my_care/medication_schedule_screen.dart` and
`medications_screen.dart` render dosage text with no server-side gate.

**Fix:** add `firebase_remote_config` with three keys — `min_supported_build` (force-upgrade wall),
`maintenance_mode` (message + read-only), and `feature_medications_enabled` (hide the medication
surface without a release). Fetch in `main()` next to the Crashlytics block, cache with a 1h
`minimumFetchInterval`, and default every key to the safe value so a Remote Config outage cannot
brick the app. This single change also gives §1.3 the missing rollback lever.

### Support — how does a distressed user reach a human, and how fast?

The **SOS path is the strongest thing in this audit** and should be protected:
- No permission gate and no confirmation friction (`lib/screens/sos/sos_screen.dart` — a tap on any
  row calls `_makeCall` directly at `:56,66,77`), honouring the CLAUDE.md inviolable rule.
- Four routes: Housepital medical emergency (`9990911911`), staff emergency → ops, national `112`,
  and ambulance → `/raise-concern` with the fallback honestly documented at `sos_screen.dart:186-194`.
- The dispatch address is shown up front with a copy action (`:101-155`), and prompts for one when
  missing — good under stress.
- Dialer failure does **not** fail silently: `:262-288` shows a dialog with the number in plain text
  plus a Copy Number action. That is exactly right for an emergency surface.

Time-to-human on the SOS path: one tap. ✅

**Everything below SOS is weaker.** The non-emergency support surface (`help_faq_screen.dart:337-373`
Call / Email / WhatsApp) points at placeholder numbers (§4.1) and, on Android 11+, cannot launch at
all for lack of `<queries>`. The in-app concern ticket (`raise_concern_screen.dart:342-420`) is
well-built — it surfaces failures honestly (`:406-413` "Failed to submit: ${e.message}") rather than
faking success, and it warns when photo upload fails but the concern went through (`:356-362`) — but
with `api.housepital.in` unreachable **every** concern submission fails today, and on iOS the photo
attach path crashes for the missing `NSCameraUsageDescription`. The Health Manager phone shortcut on
Home (`home_screen.dart:819-820,1870`) uses the correct `AppConstants.supportPhone`.

### Backend / ops dependencies — and what happens when each is down

| Dependency | Used for | Behaviour when down | Assessment |
|---|---|---|---|
| `api.housepital.in/v1` (`constants.dart:3`) | patients, dashboard, vitals, meds, orders, billing, concerns | Silent fallback to `DemoData` in ~25 places; `Log.warn` only | ❌ see below |
| Firebase Auth (phone OTP) | login | **Bypassed entirely** — `main.dart:408-410` "Auth gate disabled for demo mode. Enable before production release."; `splash_screen.dart:15-18` pushes straight to `/home` | ❌ blocker |
| Firestore | chat, attendance, vitals streams | `firestore.rules` hardened but **not deployed** (BUG-33); TD-05 records no listener-retry — "page refresh needed to reconnect" | ⚠️ |
| FCM | push notifications | `firebase_service.dart:217-222` catches and logs `subscribeToTopic` failure; app continues | ✅ degrades |
| Assistant Cloud Function | Sahayak AI | Best-in-repo degradation: `assistant_service.dart:56-69` returns `AssistantResponse.degraded(...)` on non-2xx, bad shape, or throw, with an honest Hinglish message ("Connection issue — abhi jawab nahi mil paya"); when `ASSISTANT_API_URL` is unset it uses the local intent matcher that really executes cart/booking offline (`main.dart:237-258`) | ✅ |
| Razorpay + payment verify | money | Verification correctly returns `failed` on backend error and surfaces "Payment under verification — we'll confirm in 24 hours" (`payment_service.dart:196-198`, `:167-171`) — good. **But** `createOrder` is dead code: `grep -rn "createOrder" lib/` finds only its definition (`payment_service.dart:70`) and doc comments — nothing calls it. `payment_screen.dart:220-224` calls `openCheckout` with **no `orderId`**, so `response.orderId` is always null → `_verifyPaymentOnBackend` returns `skippedDemo` (`:179-185`) → success callback fires **unverified**. With a live `rzp_live_` key this means real charges confirmed client-side with zero server record | ❌ blocker |
| `ANTHROPIC_API_KEY` | assistant | Server-side only — `functions/index.js:21` `defineSecret("ANTHROPIC_API_KEY")`, `:114` `secrets: [ANTHROPIC_API_KEY]`, `:153` used only inside the function. `grep -rn "ANTHROPIC_API_KEY\|sk-ant"` over `lib/` → **no matches**; only docs and `functions/`. Never in the binary | ✅ verified |

### Demo mode vs a real outage — the finding that matters

The demo-mode fallback is a deliberate, well-executed design decision for a pre-launch demo. The
problem is that **nothing in the shipped UI distinguishes it from live data**, so on launch day it
converts a backend outage into a silent data-integrity incident.

The mechanism, in the app's own words (`lib/providers/app_provider.dart:174-233`): seed demo first
so the UI is never blank, then try the API in the background and overwrite on success; on failure,
"Demo data already loaded — no action needed" (`:216`).

The provider *does* compute a signal — `app_provider.dart:232` sets `_lastUpdatedText = 'Demo data'`
versus `:212` `'Last updated: just now'`, exposed via the getter at `:60`. But
`grep -rn "lastUpdatedText" lib/` returns **only** `app_provider.dart:53,60,212,232`. **No screen
renders it.** The one distinguishing signal the codebase computes is dead.

The same silent-substitution pattern repeats for clinical data:
- `lib/providers/medication_provider.dart:189-208` — on API failure the patient's medication list
  becomes `DemoData.medications`; `:225-235` does the same for today's schedule, with the comment
  explaining a field bug where the real error ("Couldn't load data") was replaced by demo content.
- `lib/providers/app_provider.dart:228-231` — `_latestVitals = DemoData.vitalsHistory.last`,
  `_todayReport = DemoData.todayReport`.
- `lib/providers/my_care_provider.dart:82-95` — any unknown deployment id serves
  `DemoData.icuServiceDetail` and explicitly clears `_detailError = null`.

**Concrete failure story:** the backend has a 20-minute outage. A family member opens the app to
check whether today's insulin was given. They see a fully populated medication schedule and today's
vitals — belonging to the demo patient. Nothing on screen says otherwise; the `'Demo data'` string is
never drawn; `Log.warn` fires to a console nobody is watching (`logger.dart:63` TODO); and
Crashlytics is not told because non-fatals are not forwarded. The user acts on someone else's chart,
and ops learns nothing.

This does not require abandoning demo mode. Two small changes make it safe:
1. **Render the signal.** Show `AppProvider.lastUpdatedText` in the My Care / Home headers, and when
   it is `'Demo data'` render an unmissable banner ("Sample data — we can't reach Housepital right
   now") instead of a neutral timestamp.
2. **Gate clinical demo data on build type.** Let `DemoData` back catalogue/marketing surfaces
   anywhere, but for medications, vitals and daily reports fall back to demo **only** when
   `kDebugMode || AppConstants.razorpayKey` is a placeholder — i.e. in demo builds. A production
   build should show a real empty/error state, never another patient's chart.
3. Complete `logger.dart:63` so the outage itself is a non-fatal Crashlytics event.

---

## Blockers (must fix before release)

1. **Clinical demo data silently substitutes for real patient data during a backend outage** —
   `app_provider.dart:216,228-231`, `medication_provider.dart:189-208,225-235`,
   `my_care_provider.dart:82-95`; the one distinguishing signal (`app_provider.dart:232`
   `'Demo data'`) is computed and never rendered. Fix per the three steps above.
2. **Support numbers are placeholders** — `help_faq_screen.dart:352,364` (`+919999999999`),
   `staff_otp_verification_screen.dart:352` (`+918888888888`). Replace with
   `AppConstants.supportPhone`.
3. **Android release is debug-signed and cannot be uploaded, so the staged-rollout rollback lever
   does not exist** — `android/app/build.gradle.kts:36-40`.
4. **Payments are never verified server-side** — `createOrder` is dead code
   (`payment_service.dart:70`, zero callers); `payment_screen.dart:220` opens checkout with no
   `orderId`, forcing the `skippedDemo` branch (`payment_service.dart:179-185`). With a live key,
   real money is captured with no backend record.
5. **Auth is disabled** — `main.dart:408-410`, `splash_screen.dart:15-18`. Anyone who installs the
   app lands inside a patient's chart.
6. **iOS crash reports will be unsymbolicated** — no `upload-symbols` run-script phase in
   `ios/Runner.xcodeproj/project.pbxproj` (four script phases present, none Crashlytics), on an
   iOS-first app.
7. **iOS will crash on any camera/photo action** — no `NSCameraUsageDescription` /
   `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist` (only lines 69, 71 exist) against six
   `image_picker` call sites, including the Raise-a-Concern support flow.

## High

8. **No analytics at all** — the booking funnel is unobservable; a broken checkout produces no signal.
9. **No feature flag, kill switch, or force-upgrade** — for a healthcare app, a shipped dosage-display
   bug has no remote remedy.
10. **Non-fatal errors are never reported** — `logger.dart:63` TODO; every backend outage is invisible.
11. **Android `<queries>` missing** — `canLaunchUrl` fails for `tel:`/`mailto:`/`https:` on API 30+,
    breaking the entire non-SOS support surface.
12. **Background-isolate errors uncaptured** — no `Isolate.current.addErrorListener` in `main()`.
13. **No account/data deletion path** — `grep` finds none; standing duty impossible, plus store and
    DPDP exposure.
14. **Server-side prerequisites unverified** — `firestore.rules` deployment pending (BUG-33), API key
    restrictions pending (BUG-34), `.firebaserc` empty.
15. **No user-symptom diagnostic playbooks** — `docs/TROUBLESHOOTING.md` is entirely developer-facing.

## Medium / Low

16. **Version string is hardcoded twice and has no build number** — `about_screen.dart:11`,
    `settings_screen.dart:257`; add `package_info_plus`. (Medium — it is the diagnostic a caller reads aloud.)
17. **No in-app "What's new"** — reporters cannot see their bug fixed. (Medium)
18. **`KNOWN_ISSUES.md` is ~2 months stale** ("Last updated: 2026-05-28" vs HEAD ~2026-08) and
    contains at least one already-false entry (BUG-14 vs `invoice_pdf_service.dart:96`). (Medium)
19. **`DEPLOYMENT_GUIDE.md` drift** — pinned plugin versions disagree with `pubspec.yaml`; §7a step 1
    restricts package `in.housepital.patient` while the real id is `com.housepital.housepital_patient`
    (`android/app/build.gradle.kts:12,25`) — a restriction applied to the wrong package locks out the
    real app. (Medium)
20. **Android app label is `housepital_patient`** — `android/app/src/main/AndroidManifest.xml:7`;
    iOS is correct (`Info.plist:10` "Housepital Patient"). (Low)
21. **`INTERNET` permission is not declared in the main Android manifest** — present only in the
    `debug`/`profile` variants. Firebase's transitive manifests very likely merge it in, but this
    should be confirmed against a merged release manifest rather than assumed. (Low, verify)
22. **Incident severity ladder and concern SLA are inert** — `KNOWN_ISSUES.md` buckets are
    launch-priority not incident-severity; `constants.dart:52-57` `concernSla` has no enforcement
    (`KNOWN_ISSUES.md:96` TD-11). (Medium)
23. **3 known-failing widget tests left open** — `KNOWN_ISSUES.md:40` BUG-07; a suite that is allowed
    to be red stops being a signal. (Medium)

## BLOCKED-OWNER

| Item | What is needed |
|---|---|
| Phased release ON (§1.1) | Owner to enable staged rollout on the Play track and phased release in App Store Connect, and to confirm the halt percentages — after the signing config is fixed |
| Previous-release archive retained (§1.6) | N/A for v1; owner to confirm archive retention from build 1 onward in both consoles |
| Store release-notes text (§1.5) | Owner-written user-facing notes for v1.0.0 |
| Crashlytics velocity + new-issue alerts (§2.1) | Console access to configure `DEPLOYMENT_GUIDE.md §7a.5` steps 2-4, plus a named person who reads them daily for week 1 |
| Store review / beta feedback triage (§2.2) | Named owner + weekly slot + the four-way triage rubric |
| First-48h smoke pass (§2.4) | Owner to run the (to-be-written) `docs/SMOKE_PASS.md` on a real device from the store build |
| Support channel is monitored, with a stated answer window (§4.1) | Confirm `wecare@housepital.in` is a real monitored inbox; confirm `9990911911` staffing hours; publish the window in the store listing |
| Firestore rules deployed + API key restrictions (§1.4) | Console actions per BUG-33 / BUG-34, then paste the verification output into `KNOWN_ISSUES.md` |
| Privacy policy re-read against the shipped data set (§6.4) | Owner to check `housepital.in/privacy` covers vitals, medication names, photos, voice, phone, address |
| Expedited-review criteria (§3.4) | Owner sign-off on what qualifies as an expedited-review request |
