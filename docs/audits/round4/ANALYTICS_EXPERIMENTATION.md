# Analytics & Experimentation — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** Analytics & Experimentation (control family ANL) ·
**Scope:** source review of `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`
at `9127713`, branch `fix/five-tab-nav` (see Limitations)

**Module status:** never audited in rounds 1–3. This is the first look. There is no
round-3 ANALYTICS report, so there is no prior-round status table; where a finding
overlaps a round-3 module I say so explicitly rather than restate it as new.

---

## Applicability

**This module APPLIES. It is not N/A.** The trigger is MASTER-3.06 — "analytics,
advertising, attribution, telemetry beyond operations, feature experiments, or
personalization."

The honest shape of the finding is unusual and worth stating up front, because it is
easy to mis-summarise in both directions:

**There is no product analytics in this app.** Verified, not assumed:

```
grep -c firebase_analytics pubspec.yaml   → 0
grep -r logEvent lib/ | wc -l             → 0
grep -r HttpMetric lib/ | wc -l           → 0
grep -r newTrace lib/ | wc -l             → 0
```

No Firebase Analytics, no Mixpanel/Amplitude/Segment/PostHog/Sentry, no AppsFlyer /
Adjust / Branch attribution, no ad SDK, no `firebase_remote_config`, no A/B or feature-flag
framework. `docs/FEATURE_TRACKER.md:238` records this deliberately: *"Analytics / Event
Tracking | Not Started"*. `ios/Runner/GoogleService-Info.plist:17-20` sets
`IS_ADS_ENABLED=false` and `IS_ANALYTICS_ENABLED=false` (note: that plist is gitignored at
`.gitignore:57` and exists only on this machine — an external reviewer cannot see it, and
it is inert anyway because no Analytics SDK is linked).

**But two Firebase telemetry SDKs are linked, initialised, and transmit off-device.**
`pubspec.yaml:34-35` declares `firebase_crashlytics: ^4.3.5` and
`firebase_performance: ^0.10.1+5`; `lib/main.dart:113-135` initialises both and
explicitly calls `setCrashlyticsCollectionEnabled(true)` and
`setPerformanceCollectionEnabled(true)` in every non-debug, non-web build. Firebase
Performance Monitoring collects more than crashes — app-start and foreground/background
traces plus device, OS, app-version, carrier, country and radio metadata, keyed to a
persistent Firebase installation identifier. That is telemetry beyond operations leaving
the device to a third-party processor (Google LLC), from a health app, with no consent
gate in front of it.

So the module is **activated, and the substantive finding is the absence** — an app that
collects the wrong thing (unconsented device telemetry) while collecting none of the right
thing (any signal that the booking funnel works).

---

## What actually leaves the device today

| Flow | Destination | Identifiers | Consent gate | Evidence |
|---|---|---|---|---|
| Crashlytics fatal reports (Flutter + platform errors) | Google (Firebase project `housepital-patient`) | Crashlytics install UUID, device model, OS, RAM/disk, orientation, jailbreak state | **none** | `lib/main.dart:117-124`, `:288` |
| Performance Monitoring automatic traces (app start, fg/bg, device metadata) | Google | Firebase installation ID | **none** | `lib/main.dart:125-126` |
| Firestore reads/writes (chat, attendance, active sessions) | Google | backend `patientId` in document paths | product function, not telemetry | `chat_screen.dart:45-48`, `firebase_service.dart:239-243` |
| Firebase Storage uploads (chat photos, concern evidence) | Google | backend `patientId` **in the object path** | product function, not telemetry | `firebase_service.dart:133-138`; paths built at `chat_screen.dart:135`, `raise_concern_screen.dart:330` |
| FCM token registration | Google + `api.housepital.in` | FCM token | none | `firebase_service.dart:146-152`, `api_service.dart:578` |
| App API traffic | `api.housepital.in` (does not resolve; app runs on `DemoData`) | `patientId` in **every** path | n/a | `api_service.dart:104`, `:182` etc. |
| Sahayak assistant utterances | Cloud Function, **only** when `--dart-define=ASSISTANT_API_URL` is set (default `''`) | free text | none | `constants.dart:10-11`, `assistant_service.dart:52` |

**Crashlytics payload minimisation is genuinely good and I want to credit it.**
`setUserIdentifier`, `setCustomKey` and `Crashlytics.log` have **zero** call sites in
`lib/`. The only calls are `recordError`/`recordFlutterFatalError` (`main.dart:118-120`,
`:288`). `ApiException.toString()` (`api_service.dart:897`) emits
`ApiException(<status>): <server message>` — it does not carry the request URL, so a
`/patients/<id>/vitals` path cannot ride into a crash message that way. This is a
deliberate-looking clean posture, not an accident.

### The Performance-Monitoring URL question, assessed carefully

The sharpest available hypothesis is: *Performance Monitoring's automatic network-request
traces record request URLs, and this app's URLs carry patient IDs
(`/patients/pat_demo_rajesh/vitals`), therefore patient identifiers are being shipped to
Google as telemetry.* I tested that hypothesis rather than asserting it, and **it does not
hold for the app's own API traffic.** Reporting it as a live leak would not survive an
external reviewer, so I am not going to.

Three facts decide it:

1. **The app's HTTP goes through Dart, not the platform networking stacks.**
   `lib/services/api_service.dart:4` imports `package:http`, which on both iOS and Android
   resolves to `dart:io`'s `HttpClient` — Dart's own socket implementation. Firebase
   Performance's automatic network instrumentation hooks `NSURLSession` (iOS) and
   `OkHttp`/`HttpURLConnection` (Android). Dart-originated requests pass through neither,
   so `/patients/<id>/...` is not captured. `dio` (`pubspec.yaml:39`) has the same property.
2. **On Android, automatic network instrumentation is not installed at all.** The
   Performance Monitoring Gradle plugin performs the bytecode instrumentation, and it is
   absent: `android/app/build.gradle.kts:1-6` declares only `com.android.application`,
   `kotlin-android` and `dev.flutter.flutter-gradle-plugin`. `grep -rn "com.google.gms"
   android/` → **0 hits**; `grep -rc firebase-perf android/` → **0**.
3. **The residual exposure is Firebase Storage, and it is real but narrow.**
   `FirebaseStorage.instance.ref(...).putFile(...)` (`firebase_service.dart:133-137`) runs
   inside the native Firebase SDK, which on iOS *does* use `NSURLSession`. The object paths
   are `chat/{patientId}/{ts}_{filename}` (`chat_screen.dart:135`) and
   `concerns/{patientId}_{batchTs}/{i}_{filename}` (`raise_concern_screen.dart:330`) — the
   patient identifier is a path segment, and Performance strips the query string, not the
   path. On an iOS release build that uploads a chat photo, the patient ID plausibly
   appears in a Performance network-trace URL. I could not observe this: it needs a device
   release build and the Firebase console (see BLOCKED-OWNER).

**Net:** the exposure is smaller than the hypothesis, but it is not zero, and the reason
it is small is accidental — nobody chose `package:http` to keep patient IDs out of Google
Performance. The day someone adds `HttpMetric` instrumentation "so we can see API latency"
(which `docs/DEPLOYMENT_GUIDE.md:436` already asks for — *"Performance: alert on … HTTP >
3s p95"*), every patient-ID URL starts flowing, and nothing in the codebase would stop it.
Graded at **ANL-2.02 (Warning)** with that trajectory named, not at Fail.

### Consent: collection starts before the user has agreed to anything

The app *does* have a consent surface. `lib/screens/auth/login_screen.dart:25` holds
`_agreedToTerms`, `:49-60` bounces submission without it, `:177-196` renders the
checkbox, `:218`/`:238` link Terms and Privacy Policy. It is disabled and unticked by
default. That is good design, and it is **unreachable**:

- `lib/main.dart:417` — `// NOTE: Auth gate disabled for demo mode. Enable before production release.`
  with `home: Consumer<AuthProvider>(...)` commented out and `home: const SplashScreen()`
  in its place.
- `lib/screens/splash_screen.dart:15-18` — after two seconds,
  `pushReplacementNamed('/home')`. Unconditionally. No auth check.

So the default cold-start path is `main()` → Crashlytics + Performance enabled
(`main.dart:123-126`) → splash → home. Telemetry begins for a user who has not signed in,
not been shown a privacy policy, and not ticked anything. Even with the gate restored,
initialisation at `main.dart:113` still precedes the login screen by construction.

There is also no *withdrawal* path. `lib/screens/settings/notification_preferences_screen.dart`
has no telemetry toggle; `grep -rn "setCrashlyticsCollectionEnabled\|setPerformanceCollectionEnabled"
lib/` returns only the four lines in `main.dart`. And per Firebase's documented behaviour,
`setCrashlyticsCollectionEnabled(true)` **persists** the override to disk — so a future
build that ships with collection defaulted off would still collect on any device that ran
today's build once. Consent-off is therefore not merely missing; it is pre-emptively
overridden.

---

## Control results

### 1 · Purpose, inventory, and ownership

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| ANL-1.01 Documented decision purpose and owner per event / identity / metric | **Warning** | `docs/ARCHITECTURE.md:341` is the entire record: one table row, *"Crashlytics/Perf \| Crash + performance monitoring \| Active (guarded: mobile-only, release-only) \| main.dart"*. No owner, no enumeration of the data items either SDK sends, no statement of which decision the Performance data informs. | Impact: nobody can answer "why do we hold this?" for the only data the app transmits — the first question a DPDP notice or a store reviewer asks. Mitigation: one page listing each telemetry data item, its purpose, and a named owner. Owner: `OWNER-TBD`. Due: before first TestFlight build with real users. |
| ANL-1.02 Nothing collected outside an approved need | **Warning** | Crash reporting has a stated operational need (`docs/DEPLOYMENT_GUIDE.md:427-438`). Performance Monitoring was added in the same batch commit as Crashlytics (`pubspec.yaml:30-35` comment: *"Performance for HTTP / startup tracing"*) and **has never been instrumented** — 0 `newTrace`, 0 `HttpMetric`. It transmits device/app-start telemetry and returns nothing. | Impact: data collected with no decision attached — the definition of an unapproved need. Mitigation: either instrument it (see recommendation §"minimum event set") or drop `firebase_performance` from `pubspec.yaml`. Owner: `OWNER-TBD`. Due: before store submission. |
| ANL-1.03 Taxonomy (names, triggers, types, units, scope, version, deprecation) | **Warning** | No taxonomy artefact exists anywhere in `docs/`. `grep -rn "event" docs/*.md` surfaces no event dictionary. | Impact: the *next* engineer to add analytics has no naming or typing contract, which is how a taxonomy becomes unrecoverable within one quarter. Mitigation: land a taxonomy before the first `logEvent`, not after. Owner: `OWNER-TBD`. Due: with the analytics decision. |
| ANL-1.04 Data inventory covers client / server / SDK / network / model flows | **Warning** | No data inventory or processing record exists. The table I had to build in §"What actually leaves the device today" does not exist in the repo; it required reading seven files. `docs/ARCHITECTURE.md` documents 11 providers and the storage/payment contracts but not off-device data flows. | Impact: a DPDP notice and the App Store App Privacy answers both have to be derived from an inventory that has never been written; each will be guessed independently and they will disagree. Mitigation: promote the table above into `docs/` as the maintained inventory. Owner: `OWNER-TBD`. Due: before store submission. |

### 2 · Privacy, consent, and minimization

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| ANL-2.01 Consent / legal basis, tracking behaviour, age, territory, opt-out match actual SDK behaviour | **Fail** | Collection enabled at `lib/main.dart:123-126`, before any UI. `splash_screen.dart:15-18` routes straight to `/home`; `main.dart:417` records the auth gate as disabled — the T&C + Privacy checkbox at `login_screen.dart:177-196` is never reached. No telemetry opt-out anywhere (`grep -rn "setCrashlyticsCollectionEnabled" lib/` → 4 hits, all in `main.dart`). No age gate, while `Patient.age` (`models.dart:5`) is a free integer and `add_patient_screen.dart:196` accepts any validated age including a child's. | **Release blocker.** DPDP 2023 §5 (notice) and §6 (consent by clear affirmative action) are both engaged before the user has seen a single word; §9 (children) is engaged with no age check. Mitigation: default both SDKs off at build time and enable only after an affirmative in-app choice — see §Recommendation. Owner: `OWNER-TBD`. Due: blocks release. |
| ANL-2.02 PII / sensitive content / free text / stable identifiers excluded unless necessary | **Warning** | In-app payload is clean: 0 `setUserIdentifier`, 0 `setCustomKey`, 0 `Crashlytics.log`; `ApiException.toString()` (`api_service.dart:897`) omits the URL. Residual vector is Performance's automatic network traces over Firebase Storage object paths carrying `patientId` (`chat_screen.dart:135`, `raise_concern_screen.dart:330`). App API URLs are **not** exposed today because `package:http` (`api_service.dart:4`) bypasses `NSURLSession`/`OkHttp` and the Android perf Gradle plugin is absent (`android/app/build.gradle.kts:1-6`). Unverified against a device build or console. | Impact: today, narrow and probably iOS-only; tomorrow, wide — `DEPLOYMENT_GUIDE.md:436` already asks for an HTTP p95 alert, and satisfying it means adding `HttpMetric` around `/patients/<id>/…` calls. Mitigation: (a) re-path concern uploads to `concerns/{patientId}/{batchTs}/{filename}` as `storage.rules` already recommends, and prefer opaque upload keys over patient IDs; (b) write a rule into `CLAUDE.md` that no `HttpMetric` may wrap a URL containing a patient identifier. Owner: `OWNER-TBD`. Due: before Performance is instrumented. |
| ANL-2.03 Identifiers scoped / rotated / aggregated; no undisclosed cross-context linkage | **Warning** | `lib/utils/session_scope.dart:44-136` enumerates provider fields, prefs keys, cache entries and OS-scheduled notifications — but **not** telemetry identity. Neither `clearPatientData` (`:80-106`) nor `clearSession` (`:110-114`) touches Crashlytics/Performance or the Firebase installation ID. `grep -rn "installations\|deleteInstallation" lib/` → 0. | Impact: this is a deliberately shared device (CLAUDE.md: one patient watched by patient, primary contact and family; `SessionScope` exists precisely because the phone changes hands). The telemetry identifier does not change hands with it, so crash and performance records for patient A, patient B, and a caretaker are joined under one persistent ID at Google. That is exactly the cross-context linkage this control forbids, and it contradicts the isolation model the rest of the app enforces. Mitigation: add telemetry identity to `SessionScope`'s enumeration and to `test/providers/patient_scope_isolation_test.dart` in the same edit, per the CLAUDE.md contract. Owner: `OWNER-TBD`. Due: with the consent work. |
| ANL-2.04 Processors, purposes, retention, residency, policy, store labels, privacy manifests accurate | **Fail** | `ios/Runner/PrivacyInfo.xcprivacy` does not exist (`find . -name "*.xcprivacy" -not -path "./build/*"` returns only vendored Pods manifests). No App Store App Privacy answers recorded in-repo. Privacy policy is a remote URL only (`about_screen.dart:103-104` → `https://housepital.in/privacy`; `login_screen.dart:238`) — its contents are outside this repo and cannot be audited from source. | **Release blocker, but NOT a new one** — round 3 already blocks on it (`docs/audits/round3/SECURITY_PRIVACY_AUDIT.md:749` B-4, re-verified unchanged at `:27`). This module adds one requirement to that existing blocker: the manifest and the store labels must now also declare **Crash Data** and **Performance Data** as collected-and-linked-to-identifiers, and the privacy policy must name Google LLC as a processor for both. Owner: `OWNER-TBD` (inherits round-3 B-4's owner). Due: blocks submission. |
| ANL-2.05 Consent withdrawal and account deletion stop future collection and propagate | **Fail** | `delete_account_screen.dart:95-145`: records the request durably, deletes the Firebase credential, calls `SessionScope.clearSession`, logs out. It never calls `setCrashlyticsCollectionEnabled(false)` / `setPerformanceCollectionEnabled(false)` and never deletes the Firebase installation. There is no withdrawal control to exercise in the first place. Compounding it: `setCrashlyticsCollectionEnabled(true)` at `main.dart:123` writes a **persisted** override, so collection survives even a future build that defaults it off. | **Release blocker.** A user who completes the in-app deletion flow — the flow built to satisfy App Store 5.1.1(v) and DPDP §12, per `docs/ARCHITECTURE.md:387` — continues to be telemetered on the next launch under the same install identifier. The deletion promise the screen makes is not kept for the one data flow that is actually live today. Mitigation: route every enable/disable through one `TelemetryConsent` service, called from both the settings toggle and the deletion flow, and delete the Firebase installation on deletion. Owner: `OWNER-TBD`. Due: blocks release. |

### 3 · Instrumentation correctness

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| ANL-3.01 Every event fires once at the authoritative point | **Warning** | No event fires anywhere. There is no instrumentation at any authoritative completion point: `cart_screen.dart:555` `_checkout`, `payment_service` success/failure, `booking_confirmation_screen`, `assessment_request_screen`, `sos_screen` — all silent. `lib/utils/logger.dart:63-65` is the acknowledged chokepoint and remains a `TODO(observability)` with no wiring (round-3 known-open item, still open). | Impact: **the app cannot answer "did anyone complete a booking yesterday."** Nor "did any payment fail," "did SOS get used," "did anyone see the demo-data overlay." This is the concrete link to **MASTER-1.02** (critical journeys linked to monitoring): the journeys are documented in `docs/SCREEN_MAP.md`, but none of them terminates in a signal, so MASTER-1.02 cannot be satisfied by any evidence this repo can produce. Mitigation: the 12-event set in §Recommendation. Owner: `OWNER-TBD`. Due: with the analytics decision. |
| ANL-3.02 Retries / offline / app-kill / duplicates / clock skew do not double or misorder events | **N/A** | No app-authored event stream exists to double or misorder (0 `logEvent`, 0 `newTrace`). Crashlytics/Performance delivery buffering is SDK-internal and no product decision depends on its ordering. Rationale recorded; the absence itself is graded once, at ANL-3.01. | — |
| ANL-3.03 Client/server validation rejects malformed / oversized / privacy-violating events | **N/A** | No event ingestion path exists that this app controls. Same rationale as 3.02. | — |
| ANL-3.04 Schema evolution preserves metric meaning | **N/A** | No event schema exists to evolve. (`StoreMigrator` v2 versions *local storage*, not analytics schema — a different concern, audited under Upgrade Path.) | — |
| ANL-3.05 QA compares event stream, payload, consent state, identity scope, timestamp and downstream report for representative journeys | **Fail** | Zero verification of the telemetry that *is* live: `grep -ril crashlytics test/` → **0**; `grep -ril "firebase_performance\|FirebasePerformance" test/` → **0**, across 101 test files. And the build config suggests it does not work: (a) **Android** — no `com.google.gms.google-services`, no Crashlytics and no Performance Gradle plugin in `android/app/build.gradle.kts:1-6` or `android/settings.gradle.kts:20-24`, so R8-obfuscated mapping files are never uploaded and perf instrumentation is never applied; (b) **iOS** — `grep -c "upload-symbols" ios/Runner.xcodeproj/project.pbxproj` → **0** across six `PBXShellScriptBuildPhase` entries, so release dSYMs (`DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"`, `project.pbxproj:472`, `:653`) are built and never shipped to Crashlytics; (c) `android/app/google-services.json` declares `package_name: com.housepital.patient` while `android/app/build.gradle.kts:24` sets `applicationId = "com.housepital.housepital_patient"` — a mismatch nobody has noticed, because nothing consumes the file. | **Release blocker.** A crash reporter that produces unreadable reports is worse than no crash reporter: it converts "we are flying blind" into "we believe we are covered." The iOS dSYM half is round 3's finding (`docs/audits/round3/POST_LAUNCH_OPS_AUDIT.md:22` B6, `:390`); the **Android Gradle-plugin absence and the package-name mismatch are new in this round**. Mitigation: apply the three Gradle plugins, add the iOS `upload-symbols` run-script phase, regenerate `google-services.json` for the real application ID, then verify one deliberate test crash and one perf trace reach the console before submission. Owner: `OWNER-TBD`. Due: blocks release. |

### 4 · Metric definitions and data quality

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| ANL-4.01 Primary / secondary / guardrail / diagnostic / counter metrics fully specified | **Warning** | No metric definition exists in any document. `docs/FEATURE_TRACKER.md:238` — *"Analytics / Event Tracking \| Not Started"*. `docs/BUILD_LOG.md:135` lists *"Add analytics/event tracking (Firebase Analytics)"* as future work. | Impact: no funnel, no retention measurement, no guardrail metric — so no experiment could be evaluated even if one were run, and no regression in conversion, payment success or SOS usage would be detectable post-release. Mitigation: define ≤6 metrics alongside the 12-event set. Owner: `OWNER-TBD`. Due: with the analytics decision. |
| ANL-4.02 Data-quality monitoring (volume, nulls, freshness, duplication, schema drift, backfills) | **BLOCKED-OWNER** | No product data stream exists to monitor. For the two live SDKs, `docs/DEPLOYMENT_GUIDE.md:430-436` *prescribes* velocity alerts, new-issue alerts and p95 thresholds, and `:457` carries the checkbox **unticked**. Whether any of it is configured lives in the Firebase console, which I cannot reach. | Needs: `https://console.firebase.google.com/project/housepital-patient/crashlytics` and `/performance`. Deliverable: a screenshot of the configured alert set, or an explicit "not configured" so it can be graded. |
| ANL-4.03 Dashboard changes, query logic, filters and metric ownership versioned and reviewed | **Warning** | The only dashboards are the Firebase console defaults; nothing in the repo versions a query, a filter or a metric owner. `DEPLOYMENT_GUIDE.md:433-436` names thresholds in prose but they are applied — if at all — by hand in a console with no change record. | Impact: an alert threshold can be silently loosened with no reviewable trace, which is how a paging threshold ends up at a value nobody chose. Mitigation: keep the thresholds in `DEPLOYMENT_GUIDE.md` as the reviewed source of truth and record console changes against it. Owner: `OWNER-TBD`. Due: post-launch, week 1. |
| ANL-4.04 Known blind spots, sampling, consent bias, missing platforms and instrumentation changes disclosed | **Fail** | The documentation asserts a capability the build does not have. `docs/FEATURE_TRACKER.md:241` — *"App Performance Monitoring \| **Done**"*. `docs/DEPLOYMENT_GUIDE.md:436` — *"Performance: alert on app start > 5s p95, **HTTP > 3s p95**"*. There are no HTTP traces to alert on: 0 `HttpMetric` call sites, `package:http` bypasses the instrumented stacks, and the Android perf plugin is absent. `docs/ARCHITECTURE.md:341` likewise reports Crashlytics/Perf as *"Active"* without disclosing that neither has ever been observed working. | **Release blocker.** This is the one finding in this module that is not an absence but an active inaccuracy: three documents tell a reader that a monitoring capability exists, and the round-4 documentation pass at `9127713` reviewed them and left the claim standing. An auditor reading `FEATURE_TRACKER` would tick Performance Monitoring and move on. Mitigation: change "Done" to the truth, delete or qualify the HTTP p95 alert until traces exist, and add a blind-spot note to `ARCHITECTURE.md:341`. This is a documentation edit and costs nothing. Owner: `OWNER-TBD`. Due: blocks release. |

### 5 · Experiment design

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| ANL-5.01 Hypothesis, population, randomization unit, variants, exposure, MDE, duration, stopping rule defined pre-launch | **N/A** | No experimentation capability exists. `grep -rni "remote_config\|feature flag\|experiment\|abTest" lib/` returns only unrelated hits — product SKU `variantType`/`variantValue` (`models.dart:1004-1005`) and colour "variants" in theme comments. `pubspec.yaml` has no `firebase_remote_config` or equivalent. Nothing is randomized; no user is assigned to anything. | — |
| ANL-5.02 Randomization, bucketing persistence, mutual exclusion, SRM tested | **N/A** | No bucketing exists. Same evidence as 5.01. | — |
| ANL-5.03 Power, multiple comparisons, novelty, interference, peeking considered | **N/A** | No experiment has been designed or run. | — |
| ANL-5.04 Sensitive-trait / vulnerable-user / pricing / dark-pattern experiments get enhanced ethics review | **N/A** | No experiment exists. Recorded deliberately: this is the control that would bind hardest if experimentation is ever added here — the population is patients, elderly and post-operative users, and the manipulable surfaces include price presentation and the SOS path. Any future flag framework must route through this control before its first rollout. | — |
| ANL-5.05 No enrolment contrary to consent, territory, age, accessibility, entitlement or safety | **N/A** | Nobody is enrolled in anything. | — |

### 6 · Rollout, guardrails, and analysis

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| ANL-6.01 Flags have owner, default, targeting, start/end, halt criteria, audit log and kill switch | **Warning** | No flag system, but three **compile-time** switches change materially different behaviour with no governance and no remote control: `RAZORPAY_KEY` (`--dart-define`) decides simulated vs. real checkout (`payment_service.dart`); `ASSISTANT_API_URL` (`constants.dart:10-11`) decides local intent matcher vs. Cloud Function; `DemoMode` decides whether sample data is served. None has an owner record, a halt criterion, an audit log, or a kill switch — the app has no Remote Config, so **nothing shipped can be remotely disabled.** | Impact: if a release ships with the wrong Razorpay key or a broken booking path, the only remedy is a new store build — days, on a health-services app that takes payments. Scoped narrowly here (these are not measurement flags); the primary owner is the release/ops module. Mitigation: add `firebase_remote_config` with a single `booking_enabled` / `payments_enabled` kill switch before real money flows. Owner: `OWNER-TBD`. Due: before first live payment. |
| ANL-6.02 Health / crash / latency / payment / safety guardrails can stop exposure before statistical completion | **Warning** | No guardrail can stop anything: no kill switch (6.01), no crash-rate gate, and the crash signal itself is unverified (3.05). Whether App Store phased release / Play staged rollout is configured lives in the store consoles. | Impact: exposure is all-or-nothing and irreversible within a release cycle. Mitigation: enable App Store phased release and Play staged rollout for the first submission; unverifiable from source, so record the setting explicitly. Owner: `OWNER-TBD`. Due: at submission. |
| ANL-6.03 Analysis follows the prespecified population, exclusions, metric and correction strategy | **N/A** | No experiment has been analysed. | — |
| ANL-6.04 Results distinguish statistical from practical significance; negatives and inconclusives reported | **N/A** | No results exist. | — |
| ANL-6.05 Decision, limitations, follow-up and reproducible query archived | **N/A** | No experiment decisions exist to archive. | — |

### 7 · Personalization and models

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| ANL-7.01 Personalization inputs, inferred traits, eligibility, objective, sensitive-feature restrictions, user control and fallback documented | **Warning** | No personalization in the ML sense: no model, no inferred traits, no user profile feeding any ranking. `DoctorAdviceCard` renders clinician-authored `DemoData.doctorRecommendations` (`doctor_advice_card.dart:45-46`), which is content, not inference. But one real ranker exists: `assistant_local_actions.dart:51-100`, `findEquipment()`, a deterministic token-match scorer over the equipment catalog whose objective is documented only in a source comment (`:51-53`). No fallback policy, no eligibility rule, no user control. | Impact: low today — deterministic, non-personalized, no feedback loop. But it is the app's only ranking surface and it is undocumented outside code. Mitigation: document its objective and fallback in `docs/ARCHITECTURE.md` alongside the assistant. Owner: `OWNER-TBD`. Due: next assistant change. |
| ANL-7.02 Ranking avoids unsafe feedback loops, discriminatory exclusion, hidden pay-to-rank, manipulation | **Warning** | `assistant_local_actions.dart:95-99`, `_tieBreaksOver`: on equal keyword score the ranker **prefers a priced item over an unpriced one**, then a shorter name. The stated rationale (`:51-53`) is UX — a priced item is "sellable without the Reserve flow" — not revenue. The selected item is then offered with one-tap `addEquipmentToCart` (`:102`). No feedback loop (score is not learned), no exclusion by user attribute, no third-party paid placement. | Impact: a commercial preference sits inside the ranking of a health assistant's single suggestion, disclosed nowhere the user can see it. This is a mild pay-to-rank *shape*, not the substance — no one pays for it — but the control asks that commercial ranking inputs be visible, and this one is not. Mitigation: state the tie-break in user-facing assistant copy or in the published assistant behaviour doc; re-review if a supplier-margin term is ever added to `_tieBreaksOver`. Owner: `OWNER-TBD`. Due: next assistant change. |
| ANL-7.03 Model drift, fairness, privacy, quality and complaints monitored by segment | **N/A** | No model exists — nothing is trained, and `findEquipment()`'s scores are fixed constants in source. There is no drift surface. | — |

### 8 · Cleanup and governance

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| ANL-8.01 Ended experiments stop assigning; temporary events, flags, code paths and stores removed or deliberately retained | **Warning** | No experiments to end. Temporary code paths, however, ship: the whole `DemoData` layer serves every provider, `DemoMode` sources are live, and the demo-notice overlay is in the release path. `CLAUDE.md` documents the demo posture as intentional — which satisfies "deliberately retained" for *today* — but no removal trigger, owner or cutover date is recorded anywhere. | Impact: "deliberate retention" with no exit condition decays into permanent retention; the same overlay that round 3 found absorbing touches is still shipping. Mitigation: record the demo-mode removal trigger (backend cutover) with an owner. Owner: `OWNER-TBD`. Due: at backend cutover. Cross-ref: round-3 known-open overlay/`markServingLiveData` items. |
| ANL-8.02 Retention deletes raw high-risk data as soon as aggregate needs are met | **BLOCKED-OWNER** | Nothing in the repo configures or documents retention for Crashlytics or Performance data. Firebase defaults apply; both stores are US-resident. Retention settings and the data-region record live in the Firebase console. | Needs: Firebase console → project settings (data retention, data location) for `housepital-patient`. Deliverable: the configured retention period and storage region, so the DPDP §5 notice and the privacy policy can state them accurately rather than omit them. |
| ANL-8.03 SDKs, destinations, reports, access roles and stale metrics reviewed and decommissioned when unnecessary | **Warning** | `firebase_performance` has shipped since the batch-4 commit and has produced no instrumented measurement in the entire codebase (0 `newTrace`, 0 `HttpMetric`) while transmitting device telemetry on every release launch. That is precisely the "SDK that should be decommissioned or justified" case. Firebase IAM roles are console-side and unverifiable here. | Impact: an unused SDK is pure privacy cost with zero decision value, and it forces a "Performance Data" declaration onto the store labels and privacy policy for nothing. Mitigation: **decide in one direction** — instrument it per §Recommendation, or remove `firebase_performance` from `pubspec.yaml:35` and the init at `main.dart:125-126,132-133`. Removing it is the smaller change and shrinks the privacy surface. Owner: `OWNER-TBD`. Due: before store submission. |
| ANL-8.04 Analytics findings never override user rights, safety, accessibility, legal duties or trustworthy behaviour | **Pass** | Vacuously satisfied, and I want it read that way. No analytics-derived behaviour exists in the app: nothing is ranked, gated, priced or ordered by measured user behaviour. Verified negatively — 0 `logEvent`, no Remote Config, no experiment framework, and the only ranker (`findEquipment`) uses fixed constants, not observed data. The one safety-critical path is explicitly protected by product rule: SOS is never gated (CLAUDE.md; `sos_screen.dart`). | Recorded as a Pass because the requirement is met, not because it was engineered. It stops being free the moment the first event ships. |

---

## Scorecard

**Pass 1 · Warning 15 · Fail 5 · N/A 12 (+ BLOCKED-OWNER 2)** — 35 controls.

| Family | Pass | Warning | Fail | N/A | BLOCKED |
|---|---|---|---|---|---|
| 1 · Purpose, inventory, ownership | 0 | 4 | 0 | 0 | 0 |
| 2 · Privacy, consent, minimization | 0 | 2 | 3 | 0 | 0 |
| 3 · Instrumentation correctness | 0 | 1 | 1 | 3 | 0 |
| 4 · Metrics and data quality | 0 | 2 | 1 | 0 | 1 |
| 5 · Experiment design | 0 | 0 | 0 | 5 | 0 |
| 6 · Rollout and guardrails | 0 | 2 | 0 | 3 | 0 |
| 7 · Personalization and models | 0 | 2 | 0 | 1 | 0 |
| 8 · Cleanup and governance | 1 | 2 | 0 | 0 | 1 |
| **Total** | **1** | **15** | **5** | **12** | **2** |

On the twelve N/A grades: eleven of them (5.01–5.05, 6.03–6.05, 3.02–3.04, 7.03) rest on
verified absence of a *capability* — no randomization, no event stream, no model — not on
"I did not test it." The absence itself is graded, once each, as Warnings at ANL-3.01 and
ANL-4.01 rather than being smeared across a dozen controls to inflate the count.

---

## Release blockers (every Fail)

1. **ANL-2.01 — Telemetry collection begins before any consent, for a user who has not
   signed in.** `main.dart:123-126` enables Crashlytics and Performance in every release
   build; `splash_screen.dart:15-18` goes straight to `/home`; `main.dart:417` records the
   auth gate as disabled, so the consent checkbox at `login_screen.dart:177-196` is
   unreachable. DPDP §5/§6, and §9 with no age gate.
2. **ANL-2.04 — No `PrivacyInfo.xcprivacy`, no store privacy declarations, privacy policy
   unauditable.** *Not a new blocker* — round 3 `SECURITY_PRIVACY_AUDIT.md:749` (B-4) owns
   it. This module adds the requirement that the declarations must cover **Crash Data** and
   **Performance Data** and name Google LLC as processor.
3. **ANL-2.05 — Account deletion does not stop collection.** `delete_account_screen.dart:95-145`
   never disables either SDK and never deletes the Firebase installation; the
   `setCrashlyticsCollectionEnabled(true)` override at `main.dart:123` persists across
   launches and across future builds.
4. **ANL-3.05 — The live telemetry has never been verified and is very likely
   non-functional.** Android is missing `com.google.gms.google-services`, the Crashlytics
   plugin and the Performance plugin (`android/app/build.gradle.kts:1-6`); iOS has no
   `upload-symbols` phase (0 hits in `project.pbxproj`); `google-services.json`'s
   `package_name` does not match the `applicationId`; zero tests reference either SDK.
   The Android and package-name parts are **new in round 4**; the iOS dSYM part is round
   3's `POST_LAUNCH_OPS_AUDIT.md:22`.
5. **ANL-4.04 — Documentation claims a monitoring capability that does not exist.**
   `FEATURE_TRACKER.md:241` says Performance Monitoring is "Done";
   `DEPLOYMENT_GUIDE.md:436` prescribes an HTTP p95 alert with no HTTP traces to feed it;
   `ARCHITECTURE.md:341` reports both SDKs "Active" with no blind-spot note. Cheapest fix
   in this report — it is three documentation edits — and the most damaging if left,
   because it tells the next auditor the control is covered.

---

## Warnings requiring risk acceptance

All fifteen carry impact, mitigation, owner (`OWNER-TBD` throughout — no owner is
knowable from the repo) and a due date in the control tables above. The five that matter
most:

| # | Control | One-line risk |
|---|---|---|
| W-1 | ANL-3.01 | The app cannot answer "did anyone complete a booking yesterday" — **MASTER-1.02 (journeys linked to monitoring) has no evidence path**. |
| W-2 | ANL-2.03 | The telemetry identifier is device-scoped and survives patient switch and logout, joining several patients' records under one ID at Google — contradicting the isolation `SessionScope` enforces everywhere else. |
| W-3 | ANL-2.02 | Firebase Storage object paths carry `patientId`; Performance's automatic network traces on iOS plausibly capture them, and instrumenting the API per `DEPLOYMENT_GUIDE.md:436` would widen this to every patient URL. |
| W-4 | ANL-8.03 | `firebase_performance` transmits on every release launch and returns no measurement — remove it or instrument it, but do not keep paying its privacy cost for nothing. |
| W-5 | ANL-6.01 | Nothing shipped can be remotely disabled: no Remote Config, no kill switch, on an app that takes payments for home nursing. |

---

## BLOCKED-OWNER — needs access I do not have

| # | Control | Access needed | Deliverable |
|---|---|---|---|
| BO-1 | ANL-4.02 | Firebase console → Crashlytics and Performance for `housepital-patient` | Screenshot of configured velocity / new-issue / p95 alerts per `DEPLOYMENT_GUIDE.md:430-436`, or an explicit "not configured". The checkbox at `:457` is unticked, which is a hint, not evidence. |
| BO-2 | ANL-8.02 | Firebase console → project settings (data retention, data location) | The configured retention period and storage region for Crashlytics and Performance data, so the DPDP §5 notice and the privacy policy can state them instead of omitting them. |

Two further questions could not be closed from source and are recorded inside their
controls rather than here, because a device build — not console access — would settle them:
whether Performance actually captures Firebase Storage URLs containing `patientId` on an
iOS release build (ANL-2.02), and whether any Crashlytics report from a release build
arrives symbolicated (ANL-3.05).

---

## DPDP 2023 assessment

The brief's framing is right and worth stating precisely, because the common shortcut is
wrong. **DPDP 2023 has no "sensitive personal data" category** — unlike the SPDI Rules 2011
under IT Act §43A, which do classify health information as sensitive, and which have not
been repealed. So the correct statement is not "telemetry is sensitive under DPDP"; it is
that DPDP applies uniformly to all personal data, and that *identifiability by association*
is what bites here:

- **Association.** A crash or performance record from `com.housepital.housepitalPatient`
  carries the fact that its subject uses a home-healthcare app in Delhi NCR. Tied to a
  persistent installation ID, device model and carrier, that is personal data whose mere
  existence discloses a health-services relationship — before any clinical field is sent.
- **§5 (notice)** and **§6 (consent).** Consent must be free, specific, informed,
  unconditional, unambiguous, and given by a clear affirmative action. Collection here
  starts at `main.dart:123` before any screen renders, and the one affirmative-action
  surface (`login_screen.dart:177-196`) is unreachable behind a disabled auth gate. Even
  reachable, bundling telemetry consent into a T&C tick would fail "specific".
- **§9 (children).** `Patient.age` accepts a child's age (`add_patient_screen.dart:196`)
  and the product covers mother-and-baby care. No age determination, no verifiable parental
  consent, and telemetry runs regardless.
- **§8(5)/(6) (security and breach).** Reasonable safeguards and breach notification extend
  to processors. Google is a processor for both SDKs and is named in no repo artefact.
- **§11–§13 (rights).** Erasure is engaged by the deletion flow the app already ships, and
  ANL-2.05 shows it does not propagate to telemetry.
- **§16 (cross-border).** Transfer to the US is *permitted* by default under DPDP —
  restriction is by notified-country blacklist, not by whitelist — so this is a **notice**
  problem, not a legality problem. The residency is simply not disclosed anywhere (BO-2).

**Assessment:** the DPDP exposure is real but shallow and cheap to close. Nothing clinical
is in the telemetry payload — the Crashlytics minimisation is genuinely clean — so the
defect is procedural (no notice, no consent, no withdrawal, no propagation to deletion),
not substantive leakage. Fix the consent design and the deletion propagation and the DPDP
position becomes defensible.

---

## Recommendation — if analytics is added later

Short and concrete, as requested. This is what this checklist would require, minimum.

### Consent design (do this first — it is the blocker, and it is independent of any event)

1. **Default OFF at build time, not at runtime.** `FirebaseCrashlyticsCollectionEnabled=false`
   in `Info.plist`, `firebase_performance_collection_enabled=false` in `Info.plist`, the
   Android manifest equivalents. Delete the unconditional `setEnabled(true)` at
   `main.dart:123-126`. A runtime setter cannot un-collect what the first launch already
   sent, and the `true` override persists.
2. **One `TelemetryConsent` service is the only caller** of `setCrashlyticsCollectionEnabled`
   and `setPerformanceCollectionEnabled`. Enforce it with a line in the design gate
   (`scripts/check_design_consistency.sh`) the same way raw `Colors.*` is banned.
3. **Two independent switches in Settings, both default off:** "Crash reports" and "Product
   analytics". Separate from the T&C tick — bundling fails DPDP §6 "specific". Re-enable
   the auth gate (`main.dart:417`) so nothing is collected before sign-in.
4. **`SessionScope` clears telemetry identity** on patient switch and logout — add it to
   the store enumeration at `session_scope.dart:47-51` and assert it in
   `test/providers/patient_scope_isolation_test.dart` in the same edit, per the CLAUDE.md
   contract.
5. **`delete_account_screen` disables both SDKs and deletes the Firebase installation**
   before signing out.
6. **Ship `ios/Runner/PrivacyInfo.xcprivacy`** declaring Crash Data, Performance Data and
   Product Interaction, `NSPrivacyTracking = false`, and answer App Store App Privacy to
   match. Name Google LLC as processor in the published privacy policy.

### Minimum event set — 12 events, one per authoritative point

Named to the journeys in `docs/SCREEN_MAP.md`, so MASTER-1.02 has an evidence path.

| Event | Fires at | Properties |
|---|---|---|
| `app_open` | cold start, post-consent | `is_first_open` |
| `booking_started` | booking wizard step 1 committed | `service_category`, `entry_point` |
| `booking_confirmed` | `OrdersProvider` order created | `service_category`, `quote_pending`, `amount_bucket` |
| `cart_add` | `CartProvider.addItem` | `item_category` |
| `payment_attempted` | `PaymentService.openCheckout` | `method`, `amount_bucket` |
| `payment_result` | `onSuccess` / `onFailure` | `outcome` ∈ {success, declined, unverified, not_started} — reuse the typed `PaymentFailure` |
| `assessment_submitted` | assessment request persisted | `service_type` |
| `concern_raised` | concern written | `category`, `had_photo` |
| `sos_invoked` | SOS action taken | `resolution` ∈ {call_placed, dismissed} — **safety guardrail metric** |
| `medication_reminder_ack` | reminder acknowledged | `was_late` |
| `api_failure` | `ApiService` non-2xx / socket failure | `endpoint_template`, `status_bucket` |
| `demo_data_served` | `DemoMode` source raised | `source` — turns round 3's dead overlay signal into a real one |

**Property rules, enforced in review:** never a patient ID, phone, name, address, free
text, condition, diagnosis or medicine name; never a rupee-exact amount (bucket it); and
**`endpoint_template` means `/patients/{id}/vitals`, never the resolved path** — the same
rule must apply to any `HttpMetric` that is ever added.

**Metrics (6, max):** booking-start → booking-confirmed conversion; payment success rate;
`api_failure` rate by endpoint template (guardrail); crash-free sessions (guardrail);
SOS invocations per 1,000 sessions (guardrail, watched for *increase*); share of sessions
serving demo data (data-quality). Each needs numerator, denominator, window and exclusions
written down before the first event ships, per ANL-4.01.

**Do not add an experiment framework in the same change.** ANL-5.04 binds hard on this
population — patients, elderly, post-operative users, price presentation and the SOS path.
Get measurement honest first; earn experimentation separately.

---

## Limitations of this audit

- **Source-only review, per MASTER-4.04.** This is an honest constraint, not a failure. No
  release artefact was built, no device was instrumented, and no Firebase console was
  opened. Every verdict above is derived from files at commit `9127713`.
- **No commands were run that the brief prohibits.** No `flutter test`, `flutter build`,
  `flutter clean` or `pod install`. Central results cited where relevant: `flutter analyze`
  clean, design gate passes, 1,819 tests across 101 files. Test *sources* were read for
  coverage claims — the "0 tests reference Crashlytics/Performance" finding comes from
  `grep -ril` over `test/`, not from a run.
- **Two behaviours could not be observed and are graded on documented SDK semantics plus
  build configuration, with that stated in the control text:** (a) whether Firebase
  Performance captures Firebase Storage URLs containing `patientId` on an iOS release build
  (ANL-2.02); (b) whether any Crashlytics report arrives, and arrives symbolicated
  (ANL-3.05). Neither is graded Pass or N/A on the strength of an assumption.
- **`ios/Runner/GoogleService-Info.plist` is gitignored** (`.gitignore:57`) and exists only
  on this machine. I read it and cite it, but an external reviewer working from the
  repository cannot reproduce that specific evidence. Every other citation is reproducible
  from a clone.
- **The published privacy policy at `https://housepital.in/privacy` was not fetched.** Its
  adequacy under ANL-2.04 is therefore unverified, and stated as unverified rather than
  assumed either way.
- **`../housepital-backend` and `../housepital-api` were not audited for telemetry.** This
  module scopes client-side collection; the app is pointed at neither today
  (`api.housepital.in` does not resolve), so no server-side event pipeline can be exercised
  from this build. Server-side analytics, if any exists, is unassessed.
