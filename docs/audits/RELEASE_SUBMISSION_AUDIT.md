# Release & App Store Submission Checklist — Audit vs commit 803124d

**Date:** 2026-08-03 · **Auditor:** release-submission agent · **Repo HEAD:** `803124d` (2026-06-15)
**Scope:** iOS App Store submission. The app has **never been uploaded to App Store Connect**;
it installs to the owner's iPhone via a locally signed Release `xcodebuild`. This audit grades
against "shippable to the App Store", not "installs on my phone".

**Commands actually run:**
- `flutter analyze` → `No issues found! (ran in 6.4s)`
- `bash scripts/check_design_consistency.sh` → `✓ Design-consistency check passed`
- `git tag` → (empty)
- `curl`/`nslookup` against the app's hard-coded hosts (results in §3 and §5)
- **Not run** (per instruction, central suite in flight): `flutter test`, `flutter build`, `flutter clean`

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Version & build | 0 | 2 | 1 | 0 |
| 2. Flags & configuration | 0 | 2 | 2 | 0 |
| 3. Backend / services prod-ready | 0 | 0 | 4 | 0 |
| 4. Build provenance & signing | 0 | 1 | 2 | 0 |
| 5. Privacy & compliance | 0 | 0 | 4 | 0 |
| 6. Listing / launch assets | 0 | 0 | 4 | 1 |
| 7. Reviewer / stakeholder notes | 0 | 0 | 3 | 0 |
| 8. Build & package | 0 | 2 | 0 | 0 |
| 9. Pre-ship QA | 1 | 3 | 0 | 0 |
| 10. Staged rollout | 0 | 1 | 2 | 0 |
| 11. Submit / deploy & record | 1 | 0 | 3 | 0 |
| 12. Rollback / hotfix plan | 1 | 2 | 1 | 0 |
| **TOTAL (43 items)** | **3** | **13** | **26** | **1** |

**One-glance gate:** tests ⚠️ (not run here; 3 known failures open) · no QA flag on ⚠️ ·
prod backend ready ❌ (host is NXDOMAIN) · privacy URL + disclosure ❌ (in-app URL fails TLS) ·
build id bumped ⚠️ (1.0.0+1, never uploaded) · clean-install QA ❌ (fresh install shows fabricated
patient data; camera taps crash) → **DO NOT SHIP.**

---

## Findings

### 1. Version & build

- ⚠️ **Version bumped (user-facing version if there are user-facing changes)** — evidence:
  `pubspec.yaml:4` → `version: 1.0.0+1`. Correct *value* for a first release, but it has never
  moved and there is no process behind it. **Impact:** low now, guaranteed friction later — the
  first rejection forces a manual bump nobody has a routine for.
  **Fix:** adopt `1.0.0+N`, bump `+N` on every ASC upload (even rejected ones); add the bump to
  a release script.

- ⚠️ **Build/release identifier incremented (must increase for every upload/deploy)** — evidence:
  `ios/Flutter/Generated.xcconfig` → `FLUTTER_BUILD_NUMBER=1`; no CI step and no tag increments it.
  **Impact:** ASC rejects duplicate build numbers; a rejected build burns the number.
  **Fix:** `flutter build ipa --build-number=$(date +%Y%m%d%H%M)` or a CI counter.

- ❌ **Version strings consistent across all manifests/configs** — evidence: the version is
  hardcoded in **three** independent places that never read `pubspec.yaml`:
  `lib/screens/settings/about_screen.dart:11` (`static const _appVersion = '1.0.0'`),
  `lib/screens/settings/settings_screen.dart:257` (`subtitle: 'Housepital v1.0.0'`), and
  `pubspec.yaml:4`. Separately, **three different app identifiers** exist across the project:
  iOS `com.housepital.housepitalPatient` (`ios/Runner.xcodeproj/project.pbxproj:690`),
  Android `com.housepital.housepital_patient` (`android/app/build.gradle.kts:24`), and
  `in.housepital.patient` referenced as the Android package in
  `docs/KNOWN_ISSUES.md` BUG-34 (the Firebase key-restriction instruction).
  **Impact:** the About screen will lie about the version from v1.0.1 onward; the BUG-34 Firebase
  key restriction, if applied as written, would be scoped to a package that does not exist and
  would silently fail to protect the real one.
  **Fix:** read the version via `package_info_plus` in both screens; reconcile BUG-34 to the real
  Android `applicationId` before applying console restrictions.

### 2. Flags & configuration (the most-missed gate)

- ⚠️ **No QA/debug flag left enabled — review every feature flag's shipping value** — evidence:
  no debug menu, dev panel, or test-mode toggle exists (grep for
  `debug menu|devMode|testMode|Debug Tools|Developer Options` over `lib/` → no matches).
  The two `kDebugMode` guards are correct and inverted the right way
  (`lib/main.dart:113` production-only Crashlytics enable, `lib/main.dart:139`
  debug-only `FlutterError.presentError`). The `⚠️` is for the 28 unguarded `debugPrint`
  calls (next item) and for the absence of any flag layer at all (§12).

- ❌ **Demo/seed/sample-data mode is off by default** — evidence:
  `lib/providers/app_provider.dart:182` calls `_seedDemoDataIfEmpty()` **unconditionally** inside
  `loadDashboard()`, before the API is even attempted; the method
  (`lib/providers/app_provider.dart:222-233`) installs `DemoData.icuDeployment`,
  `DemoData.todayAttendance`, `DemoData.vitalsHistory.last`, `DemoData.todayReport` and a demo
  billing balance. `lib/data/demo_data.dart:28-59` is a fabricated 72-year-old patient
  **"Rajesh Kumar"** — post-stroke, hypertension, type-2 diabetes, five named prescription
  medications (incl. Insulin Glargine 10 units), sulfa allergy, "Bed-ridden", a named doctor at
  Fortis, a daughter's phone number and a Noida street address.
  **Impact:** the single worst finding in this audit. Every fresh install — including an App
  Review reviewer's — presents fabricated clinical records as the user's own care record. That is
  Guideline **2.1** (incomplete/demo app), **2.3.1** (misleading), and **1.4.1** (a medical app
  displaying invented patient data). The only mitigation in the code is the string
  `_lastUpdatedText = 'Demo data'` (`app_provider.dart:230`), which is a caption, not a gate.
  **Fix:** gate `_seedDemoDataIfEmpty()` behind `const bool.fromEnvironment('DEMO_DATA')`
  defaulting to `false`, and render honest empty states for a real user with no care plan yet.

- ❌ **Build points at production endpoints/keys, not dev/staging** — evidence:
  `lib/config/constants.dart:3` → `apiBaseUrl = 'https://api.housepital.in/v1'`.
  `nslookup api.housepital.in` → **`NXDOMAIN`**; `curl https://api.housepital.in/v1/health` →
  exit 6 (could not resolve host). The production API host **does not exist in DNS at all.**
  Separately, the last recorded build configuration
  (`ios/Flutter/Generated.xcconfig`, `DART_DEFINES` base64) decodes to
  `RAZORPAY_KEY=rzp_test_dummy`, which `lib/services/payment_service.dart:46-48` lists in
  `_placeholderKeys` → `isDemoPayments == true` → **simulated checkout**.
  **Impact:** this is checklist §3's trap in its most severe form. It is not "prod client vs dev
  schema", it is "prod client vs no backend". Every API call in the app fails; the UI is 100%
  demo fallback. Shipping this is shipping a mockup.
  **Fix:** stand up `api.housepital.in` (or repoint `apiBaseUrl` at the deployed Cloud Functions
  URL `https://asia-south1-housepital-patient.cloudfunctions.net/api`, per
  `docs/DEPLOYMENT_GUIDE.md:319`) and pass a real `--dart-define=RAZORPAY_KEY=rzp_live_…`.

- ⚠️ **Logging level appropriate for production (no verbose/debug spew)** — evidence:
  `lib/utils/logger.dart:55` correctly drops `debug`/`info` under `kReleaseMode`. But **28 call
  sites bypass `Log` entirely** and call `debugPrint` directly — `debugPrint` is *not* stripped in
  release. Full list includes `lib/main.dart:282`, `lib/main.dart:755`,
  `lib/providers/blog_provider.dart:37,67`, `lib/services/assistant_service.dart:57,62,67`,
  `lib/services/voice_service.dart:58,77,88,101`,
  `lib/screens/assistant/assistant_executor.dart:310,340,367,397,407,441,463`,
  `lib/screens/orders/order_tracking_screen.dart:171`,
  `lib/screens/support/staff_profile_screen.dart:41`, and 8 more. Several interpolate raw
  exception objects (`'…failed: $e'`).
  **Impact:** device-console spew in release, and exception text (potentially containing IDs or
  request detail) is readable by anyone with the device connected to a Mac.
  **Fix:** replace all 28 with `Log.warn`/`Log.error`; the `TODO(observability)` at
  `logger.dart:63` is the right chokepoint to then forward to Crashlytics.

### 3. Backend / services prod-ready

- ❌ **Database/schema migration deployed to production (not just dev)** — evidence:
  `docs/DEPLOYMENT_GUIDE.md:62-127` documents a full Cloud SQL MySQL setup, but the API host is
  NXDOMAIN (§2), so no production deployment exists to have been migrated. **BLOCKED-OWNER** for
  live confirmation. **Fix:** deploy, then verify `GET /health` returns the shape documented at
  `docs/DEPLOYMENT_GUIDE.md:177`.

- ❌ **Prod credentials/keys in place and rotated from any shared dev values** — evidence:
  Razorpay is a placeholder (§2). `firestore.rules` was hardened in-repo but
  `docs/KNOWN_ISSUES.md` BUG-33 records it as *"Resolved — deployment to console pending"*.
  BUG-34 records the Firebase API-key console restrictions as **Open (console action required)**.
  **Impact:** unrestricted Firebase keys ship inside the binary; a stale/undeployed rules file
  means the live Firestore may still be running the previous ruleset.
  **Fix:** `firebase deploy --only firestore:rules`, then apply the bundle-ID/package restrictions
  in `docs/DEPLOYMENT_GUIDE.md:326` §7a.

- ❌ **Infra/scaling/quota headroom checked for the expected load** — **BLOCKED-OWNER.**
  Nothing in the repo can evidence this; there is no deployed infrastructure to measure.

- ❌ **⚠️ Trap: client/release pointing at prod while only a dev schema/endpoint exists** —
  evidence: the trap is present in its worst form — the client points at a hostname that does not
  resolve. Verified above. Every failure is silent by design: `app_provider.dart:218` catches and
  logs `'Dashboard API unavailable, using demo/cache data'` and leaves demo data in place.

### 4. Build provenance & signing

- ❌ **Release build is signed / integrity-checked with production credentials** — evidence:
  `ios/Runner.xcodeproj/project.pbxproj:651` (project-level **Release** config) →
  `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer"` — a *development* identity, not
  `Apple Distribution`. `DEVELOPMENT_TEAM = 3M5BRKQ345` is set on the Runner target
  (lines 683, 706) and `CODE_SIGN_STYLE` is unset for Runner (only `RunnerTests` declares
  `Automatic` at lines 520/538/554), so it inherits automatic signing — Xcode will *probably*
  substitute a distribution cert when archiving, but that path has never been exercised.
  **Android is unambiguously broken:** `android/app/build.gradle.kts:34-37` →
  `release { signingConfig = signingConfigs.getByName("debug") }` with the template
  `// TODO: Add your own signing config`.
  **Impact:** iOS archive signing is unproven; any Android release is unshippable.
  **Fix:** archive once via Xcode Organizer to prove distribution signing; for Android, create an
  upload keystore + `android/key.properties` before any Play submission.

- ❌ **Capabilities/entitlements/permissions match what's used and target the prod environment** —
  evidence: **there is no `.entitlements` file anywhere under `ios/`**
  (`find ios -name "*.entitlements"` → empty). Yet `firebase_messaging` is a dependency
  (`pubspec.yaml:26`), `lib/services/firebase_service.dart:158` calls
  `messaging.requestPermission(...)`, `:149` calls `getToken()`, and `lib/main.dart:368` wires
  `onMessageOpenedApp`. Info.plist has no `UIBackgroundModes`/`remote-notification` either.
  **Impact:** the Push Notifications capability is not enabled, so no `aps-environment` entitlement
  is produced. Remote push **cannot work in production** — `getToken()` will fail or return a token
  APNs will never deliver to. An advertised, wired-up feature is dead on arrival. See also §5 for
  the missing camera/photo usage strings, which are the more urgent permission defect.
  **Fix:** in Xcode → Signing & Capabilities, add **Push Notifications**; add
  `UIBackgroundModes = [remote-notification]` to Info.plist; upload the APNs auth key to the
  Firebase console.

- ⚠️ **Source map / debug symbols generated and archived for crash symbolication** — evidence:
  dSYMs *are* generated — `project.pbxproj:653` (Release) → `DEBUG_INFORMATION_FORMAT =
  "dwarf-with-dsym"`. But grepping the whole `project.pbxproj` for
  `crashlytics|upload-symbols|dSYM` returns **only** those two format lines: there is **no
  Crashlytics `upload-symbols` run-script build phase**. `ios/Flutter/Generated.xcconfig` also
  shows `DART_OBFUSCATION=false` with no `--split-debug-info`.
  **Impact:** Crashlytics is enabled in release (`lib/main.dart:114-121`) and will collect crashes
  that are **unsymbolicated** — addresses, not stack frames. The one production observability tool
  wired up will produce unreadable output.
  **Fix:** add the Firebase `upload-symbols` run-script phase (Firebase iOS docs), or upload dSYMs
  from the ASC-processed archive manually after each upload.

### 5. Privacy & compliance

- ❌ **Privacy policy URL live and linked in the store/site + in-app** — evidence: the in-app link
  exists at `lib/screens/settings/about_screen.dart:104` → `https://housepital.in/privacy`.
  Verified live: `curl -L https://housepital.in/privacy` → **exit 60 (SSL certificate problem)**,
  HTTP code `000`. The **`www.` host works**: `curl -L https://www.housepital.in/privacy` → `200`.
  The certificate on `43.205.227.64` does not cover the bare apex domain.
  The same defect affects **four** hardcoded links:
  `about_screen.dart:98` (`https://housepital.in/terms`),
  `about_screen.dart:104` (privacy), `about_screen.dart:110` (website), and
  `lib/screens/settings/referral_screen.dart:121` (`https://housepital.in/app`, shared to friends).
  `https://www.housepital.in/terms` → `200`, so the content exists; only the host is wrong.
  **Impact:** every legal link in the app opens to a certificate warning on-device. A reviewer who
  taps Privacy Policy sees a browser security error — a straightforward rejection, and the ASC
  privacy-policy URL field would be broken too if the apex form is entered there.
  **Fix:** one-character change ×4 — prefix all four with `www.`. (Also fix the apex→www redirect
  or the cert SAN server-side so future links can't reintroduce this.)

- ❌ **Store/site data-disclosure (App Privacy / Play Data Safety) submitted and accurate** —
  **BLOCKED-OWNER**, never submitted. The disclosure is non-trivial for this app; see the
  BLOCKED-OWNER section for the exact category list derived from the code.

- ❌ **Export-compliance / encryption questions answered where required** — evidence:
  `ITSAppUsesNonExemptEncryption` is **absent** from `ios/Runner/Info.plist` (74 lines, verified in
  full). The app uses HTTPS only (standard exempt encryption).
  **Impact:** every single upload stalls in "Missing Compliance" in App Store Connect until the
  question is answered by hand, blocking TestFlight distribution each time.
  **Fix:** add `<key>ITSAppUsesNonExemptEncryption</key><false/>` to Info.plist.

- ❌ **Age rating / content rating set; correct category** — **BLOCKED-OWNER**, never set.

- ❌ **(App-specific, same section) Required permission usage strings are missing — the app will
  be terminated by iOS.** Evidence: `ios/Runner/Info.plist` declares **only**
  `NSMicrophoneUsageDescription` (line 70) and `NSSpeechRecognitionUsageDescription` (line 72).
  It has **no `NSCameraUsageDescription` and no `NSPhotoLibraryUsageDescription`**. Meanwhile
  `image_picker` (`pubspec.yaml:61`) is invoked with `ImageSource.camera` / `ImageSource.gallery`
  from **six** screens:
  `lib/screens/settings/settings_screen.dart:54,59` (profile photo),
  `lib/screens/settings/patient_profile_screen.dart:190,195`,
  `lib/screens/support/raise_concern_screen.dart:77,85` (concern evidence photo),
  `lib/screens/rental/return_screen.dart:316` (equipment return photo),
  `lib/screens/chat/chat_screen.dart:122` (chat photo),
  `lib/screens/documents/document_repository_screen.dart:614,632` (prescription/report capture).
  **Impact:** iOS **hard-terminates** an app that requests camera or photo-library access without
  the corresponding usage string. Six user-reachable taps crash the app instantly on a real
  device, and the missing strings are also an automatic App Review rejection (5.1.1).
  This is the highest-confidence functional blocker in the audit.
  **Fix:** add both keys with honest, specific copy, e.g.
  `NSCameraUsageDescription` → "Housepital uses the camera so you can photograph prescriptions,
  reports and equipment being returned."; `NSPhotoLibraryUsageDescription` → "Housepital accesses
  your photos so you can attach existing prescriptions and reports to your care record."

- ❌ **(App-specific, same section) No in-app account deletion — Guideline 5.1.1(v).** Evidence:
  the app creates accounts via Firebase phone OTP (`lib/services/firebase_service.dart:58`
  `verifyPhoneNumber`, `:90` `signInWithCredential`). `lib/screens/settings/settings_screen.dart`
  offers **Logout only** (line 264); the only deletion affordance is prose in
  `lib/screens/settings/help_faq_screen.dart:156`: *"Please contact support via email at
  wecare@housepital.in. Account deletion is processed within 7 working days…"*.
  **Impact:** Apple has required *in-app initiated* account deletion since June 2022 for any app
  that supports account creation. Email-only deletion is explicitly called out as non-compliant.
  Automatic rejection.
  **Fix:** add a "Delete my account" row in Settings that calls a backend endpoint (or
  `FirebaseAuth.currentUser.delete()` with re-auth), confirms destructively, and clears local
  `shared_preferences`.

### 6. Listing / launch assets

- ❌ **Name, subtitle/short description, full description, keywords, support + marketing URLs** —
  **BLOCKED-OWNER**, no ASC record exists. Note for the listing: `CFBundleDisplayName` is
  `Housepital Patient` (`Info.plist:10`) — 18 characters, which truncates on the iOS Home Screen;
  consider `Housepital`.

- ❌ **Screenshots for all required device sizes/locales** — **BLOCKED-OWNER**, none exist. Two
  code facts widen the requirement:
  (a) `ios/Runner.xcodeproj/project.pbxproj:672` → `TARGETED_DEVICE_FAMILY = "1,2"` — the app
  **declares iPad support**, so iPad screenshots are mandatory *and* the app must actually be
  usable on iPad. The only responsive coverage is
  `test/screens/overflow_smoke_test.dart` at 320/375/414 pt widths (iPhone only).
  (b) `Info.plist:56-61` permits `LandscapeLeft`/`LandscapeRight` on iPhone, and there is **no**
  `SystemChrome.setPreferredOrientations` call anywhere in `lib/` (grep → no matches), so
  landscape ships unlocked and untested.
  **Fix:** either set `TARGETED_DEVICE_FAMILY = "1"` and lock to portrait (cheap, honest — this is
  a one-hand-at-the-bedside app), or budget real iPad + landscape QA.

- ❌ **App icon / favicon at required resolutions (no missing-asset warnings)** — evidence:
  all 15 required PNGs are present in `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and the
  1024 is technically valid (`sips` → 1024×1024, `hasAlpha: no`, sRGB — it will pass upload
  validation). **But every one of them is the stock Flutter template icon** — I rendered
  `Icon-App-1024x1024@1x.png` and it is the blue Flutter "F" logo on white. All 15 files share the
  same 2026-02-23 timestamp as the template generation.
  The **launch screen is also stock**: `LaunchImage.png`/`@2x`/`@3x` are 68-byte
  **1×1 transparent** PNGs (`file` → `PNG image data, 1 x 1, 8-bit gray+alpha`), centred on a white
  background by `ios/Runner/Base.lproj/LaunchScreen.storyboard:22` — i.e. the app launches to a
  blank white screen before the orange `SplashScreen` (`lib/screens/splash_screen.dart`) paints.
  **Impact:** shipping a third-party framework's logo as your app icon is an immediate App Review
  rejection (4.0 Design / 2.3.8 accurate metadata) and would be embarrassing on TestFlight.
  This is the most visible blocker and also the easiest to fix.
  **Fix:** generate the full appiconset from the Housepital mark (orange `#F39314`, no alpha,
  no rounded corners — iOS masks them); replace `LaunchImage@{1,2,3}x.png` with the wordmark and
  set the storyboard background to the brand orange so launch→splash is seamless.

- N/A **(Optional) preview video** — optional; not required for a first submission.

- ❌ **"What's New" / release notes written** — **BLOCKED-OWNER.** `docs/CHANGELOG.md` is
  date-keyed (`## [2026-06-13] — Field Round 6b…`) and engineering-facing; it cannot be pasted as
  user-facing release notes. For a 1.0 the field is usually just a short description anyway.

### 7. Reviewer / stakeholder notes

- ❌ **Instructions explain what the app does** — **BLOCKED-OWNER**, no ASC record. One genuine
  positive to note when writing them: `lib/screens/splash_screen.dart:17` pushes
  `pushReplacementNamed('/home')` after 2s with **no auth gate**, so a reviewer can browse the
  entire catalog, cart and content without signing in.

- ❌ **Demo path / account provided if anything is gated** — evidence: sign-in is real Firebase
  phone OTP (`lib/services/firebase_service.dart:58`) with no bypass. Any flow behind
  authentication — checkout, staff OTP verification
  (`lib/screens/my_care/staff_otp_verification_screen.dart`), chat, documents — needs a working
  Indian mobile number the reviewer cannot have.
  **Fix:** add a Firebase Auth **test phone number** (Firebase Console → Authentication → Sign-in
  method → Phone → "Phone numbers for testing", e.g. `+91 99999 99999` / code `123456`) and put it
  in the App Review notes. This is the standard, Apple-accepted pattern.

- ❌ **Special setup (test data, second account for multi-user flows) described** — evidence: the
  app has a four-role permission model (`lib/utils/permissions.dart:19-26`: `PRIMARY_CONTACT`,
  `FAMILY_MEMBER`, `PATIENT_SELF`, `CARETAKER`) with role-gated actions including the doctor
  handover PDF export. A reviewer testing role behaviour needs a second account. Nothing documented.

### 8. Build & package

- ⚠️ **Release configuration, no build warnings, no test/debug code shipped** — evidence:
  `flutter analyze` → **`No issues found! (ran in 6.4s)`** (note: cleaner than CI expects — the
  workflow at `.github/workflows/ci.yml` still runs `--no-fatal-warnings --no-fatal-infos`
  citing a "284-issue backlog" recorded in `docs/KNOWN_ISSUES.md` CI-03, which now appears stale
  and could be tightened). `bash scripts/check_design_consistency.sh` → **passed**.
  Downgraded to ⚠️ for two reasons: the 28 shipping `debugPrint` calls (§2), and
  `ios/Flutter/Generated.xcconfig` contains
  `FLUTTER_APPLICATION_PATH=/Users/ateeshayjain/WIPApps/housepital_patient_app` and
  `PACKAGE_CONFIG=/Users/ateeshayjain/WIPApps/housepital_patient_app/.dart_tool/…` — a **stale
  path** (the repo now lives at `…/WIPApps/Housepital/housepital_patient_app`).
  **Impact:** a stale `Generated.xcconfig` is a classic source of the exact
  Xcode↔CLI DerivedData collisions `CLAUDE.md` warns about; the archive may compile against a
  path that no longer exists.
  **Fix:** `flutter pub get` (regenerates it) before the release archive; never commit it (it is
  correctly not in git).

- ⚠️ **Artifact validates clean; bundle/download size reasonable; no debug resources bundled** —
  evidence: never validated, because nothing has ever been uploaded. Size measured from source:
  `du -sh assets/` → **81M**, of which `assets/images/products` → **78M** (the bundled equipment
  photos), consistent with the ~148 MB iOS bundle recorded in `docs/CHANGELOG.md`.
  **Impact:** comfortably under the 4 GB app limit, but likely over the 200 MB cellular-download
  threshold once the Flutter engine and Firebase frameworks are added — meaning many users can
  only install on Wi-Fi. Not a blocker, but measure it on the first archive.
  **Fix:** after the first `flutter build ipa`, check the App Store Connect size report; if over
  200 MB, re-encode the product photos (they are almost certainly full-resolution PNG/JPEG that
  would survive an 80%-quality resize to ~1000 px).

### 9. Pre-ship QA (clean install / fresh session)

- ⚠️ **Fresh install/session → onboarding → core flows all work** — evidence: the owner installs
  and uses a signed Release build on a physical iPhone, so the happy path demonstrably runs. But
  "fresh install" is precisely the scenario that exposes the two worst defects: a brand-new user
  sees another person's fabricated medical record (§2), and any tap that opens the camera or photo
  library terminates the app (§5). Neither has been exercised as an App Store build.

- ⚠️ **Accessibility spot-check (largest text, screen reader, dark mode)** — evidence: dark mode
  has an automated token guard (`test/widgets/dark_mode_test.dart`) and layout has an overflow
  guard across 37 screens × 3 widths (`test/screens/overflow_smoke_test.dart`); i18n EN/HI are
  key-synced — verified independently: `en.json` 321 keys, `hi.json` 321 keys, symmetric
  difference empty. **No largest-text (`textScaler`) pass and no VoiceOver pass is recorded
  anywhere.** Related listing defect: `CFBundleLocalizations` is **absent** from Info.plist
  (grep count 0) even though `lib/main.dart:398-400` declares `supportedLocales: [Locale('en'),
  Locale('hi')]` — so the App Store will advertise the app as **English-only** and hide the full
  Hindi localisation from Hindi-speaking users browsing the store.
  **Fix:** add `<key>CFBundleLocalizations</key><array><string>en</string><string>hi</string></array>`;
  run one VoiceOver pass over Home → Services → Cart → Checkout and one at the largest Dynamic
  Type setting.

- ✅ **Offline / poor-network / error-path behavior acceptable** — evidence: `lib/main.dart:98`
  wraps the app in `runZonedGuarded`; `lib/main.dart:137-166` replaces the red error screen with a
  friendly `ErrorWidget.builder`; `lib/main.dart:755` catches route-resolution errors; API calls
  use a 5s timeout with cached/demo fallback (`lib/providers/app_provider.dart:196-220`).
  This is genuinely well built. The caveat is that it is *too* good — it makes "the backend does
  not exist" indistinguishable from "you're on a bad train", which is how §3 stayed invisible.

- ⚠️ **Automated test suite green in CI on the release commit** — evidence: CI exists and is
  serious — `.github/workflows/ci.yml` runs `flutter analyze`, the design gate, and
  `flutter test --coverage --reporter=expanded --dart-define=RAZORPAY_KEY=rzp_test_ci_dummy_key`
  behind a 50% line-coverage floor, on push/PR to `main`. 99 test files exist under `test/`.
  I did **not** run the suite (instructed; a central run is in flight). Marked ⚠️ not ✅ because
  `docs/KNOWN_ISSUES.md` BUG-07 records **3 open pre-existing widget-test failures** in
  `test/screens/my_care/my_care_widgets_test.dart` ("cause unknown, needs triage") and BUG-08
  records `AuthProvider` as untested — the login flow that gates every paid action.

### 10. Staged rollout

- ❌ **Beta/canary channel (TestFlight / Play internal track)** — evidence: never used; no ASC
  record exists; `git tag` is empty. **Fix:** TestFlight internal testing is the correct next step
  after the blockers below — it requires no App Review for internal testers and would surface the
  camera crash within minutes.

- ⚠️ **Real testers verify install/deploy → launch → core flows on the release artifact** —
  evidence: the owner tests on a real device with a Release configuration, which is meaningfully
  better than simulator-only. But it is a **locally signed development-provisioned install**, not
  the App Store artifact: no distribution signing, no App Store thinning/re-signing, one tester,
  one device model. **Fix:** treat the TestFlight build as the artifact of record.

- ❌ **Prod-only features (sync, push, payments) verified on the real build** — evidence: all three
  are unverifiable today. **Sync** — API host is NXDOMAIN (§3). **Push** — no entitlement, capability
  not enabled (§4). **Payments** — `isDemoPayments` is true under the recorded build config, so
  `openCheckout` simulates locally (`lib/services/payment_service.dart:38-52`); the real Razorpay
  path has never run on a device (the code comment at `payment_service.dart:40-42` notes the SDK
  rejected the placeholder key on-device 2026-06-11, which is the closest thing to a real-key test
  that exists).

### 11. Submit / deploy & record

- ❌ **Submitted for review / deployed** — never. This is the honest headline of the audit.

- ❌ **Tag the release in version control (vX.Y)** — evidence: `git tag` → empty. No release has
  ever been tagged. **Fix:** tag the exact commit you archive, `git tag -a v1.0.0 -m "…"`, before
  uploading — otherwise you cannot reproduce the binary a reviewer rejected.

- ❌ **CHANGELOG updated** — evidence: the newest entry in `docs/CHANGELOG.md` is
  `## [2026-06-13] — Field Round 6b…`, but **five commits landed on 2026-06-15** and none are
  recorded: `db22f5f` (docs refresh), `75162d5` (service-detail staff rows), `4a37c2a` (field
  round 7 — dead-tap fix, rental prices, diagnostics), `bc73765` (nurse role scope correction),
  `803124d` (HEAD — staff profile identity, top toasts, sleep-study slot, receipt PDF).
  **Impact:** the changelog under-reports the shipping build by five commits, including a
  business-rule change (nurse vs caretaker task scope) that matters for support and training.
  **Fix:** add a `## [2026-06-15] — Field Round 7` entry covering those five, and switch to
  version-keyed headings (`## [1.0.0] — 2026-08-xx`) so a release can cite one.

- ✅ **Known issues documented and accepted** — evidence: `docs/KNOWN_ISSUES.md` is a genuinely
  strong artefact — ID'd, dated, status-tracked, honest about what belongs to the backend repo
  (BUG-02/35), and it correctly flags the Razorpay key (BUG-01), the expired Firestore rule
  (BUG-33) and unrestricted Firebase keys (BUG-34). Graded ✅ on its own terms. Caveat: it was last
  updated 2026-05-28 and contains **none** of this audit's blockers.

### 12. Rollback / hotfix plan

- ❌ **A way to disable a broken feature (flag revert) without a full new release** — evidence:
  there is **no feature-flag or remote-config layer** — grep for
  `remoteconfig|featureFlag|feature_flag|enableExperimental` over `lib/` returns **no matches**
  (the `FirebaseRemoteConfig` pod is present only transitively, pulled in by
  `firebase_performance`; the Dart package is not a dependency).
  **Impact:** the most consequential structural gap. For a medical app that takes payments and
  runs an AI assistant, every defect — a mispriced service, an assistant giving bad guidance, a
  broken checkout — requires a full App Review cycle (1–3 days) to disable. There is no kill
  switch for anything.
  **Fix:** add `firebase_remote_config` and put at minimum three kill switches behind it before
  1.0: `assistant_enabled`, `payments_enabled`, and a `force_upgrade` minimum-version gate.

- ✅ **Rollback path known** — evidence: `docs/DEPLOYMENT_GUIDE.md:456` §9 "Rollback Procedure"
  covers Cloud Functions redeploy-from-git, database, and — correctly and explicitly —
  `docs/DEPLOYMENT_GUIDE.md:480`: *"iOS: App Store Connect does not support rollback — submit a
  new version with the fix."* That is the right answer, written down.

- ⚠️ **Data/schema rollback considered (additive-only)** — evidence:
  `docs/DEPLOYMENT_GUIDE.md:470-474` states MySQL has no migration rollback in this setup and that
  rollback SQL must be applied manually. Honest, but there is **no stated additive-only policy**
  (no field removal / no retype), which is what actually protects a shipped client from a schema
  change. **Fix:** write the additive-only rule into the deployment guide; a client in the App
  Store cannot be updated in lockstep with the schema.

- ⚠️ **Monitoring/alerting (or crash/error reporting) watched post-release** — evidence:
  Crashlytics + Performance are correctly wired and **release-only**
  (`lib/main.dart:110-131`: enabled when `!kDebugMode`, disabled in debug so test runs don't
  pollute the project; `!kIsWeb` guard with a good comment explaining the web assertion).
  Alert thresholds are pre-designed at `docs/DEPLOYMENT_GUIDE.md:416-424` (velocity >0.1%/1h, new
  issue email+Slack, app start >5s p95). But the pre-launch checklist at
  `docs/DEPLOYMENT_GUIDE.md:445-446` still has both **unchecked**, and per §4 the crashes will
  arrive **unsymbolicated**. **Fix:** configure the alerts and add the dSYM upload phase together —
  each is half of a working crash pipeline.

---

## App Review risks specific to THIS app

**Guideline 1.4.1 / 5.1.3 — Physical harm & health data.**
`lib/utils/vital_classifier.dart` classifies systolic BP, SpO₂, pulse, temperature and blood
sugar into **green / yellow / red** with documented clinical thresholds (`vital_classifier.dart:5-14`;
e.g. SpO₂ <92 → red, systolic ≥140 → red). That is triage-grade interpretation of vital signs.
A grep for `disclaimer|not a substitute|medical advice|consult (your|a) doctor|informational`
across `lib/` and `assets/i18n/` returns **exactly one hit — inside the prose body of a demo
article** (`lib/data/demo_articles.dart:192`). **There is no disclaimer in the app's UI at all.**
Compounding it: the vitals a first-time user sees are `DemoData.vitalsHistory` — invented numbers
presented as their own readings, colour-coded as if clinically meaningful.
**Fix:** (a) gate the demo data (§2); (b) add a persistent, non-dismissible disclaimer on the
vitals and daily-report screens — "Colour indicators are guidance only and are not a diagnosis.
For any concern, contact your doctor or call 112."; (c) repeat it in the App Review notes.

**Guideline 5.1.1(v) — Account deletion.** Missing entirely; see §5. Automatic rejection.

**Guideline 3.1.1 / 3.1.5(a) — In-App Purchase: NOT required. ✅**
I checked what the app actually sells: nurse/caretaker/physio day-rates and monthly packages from
the Delhi NCR rate card (`lib/data/catalog_seeds.dart`), equipment rental and purchase
(`assets/equipment_catalog.json`, 351 items), lab tests (`assets/lab_tests_catalog.json`),
consultations and ambulance dispatch. **Every one is a real-world service or physical good
delivered outside the app**, which is precisely the Guideline 3.1.5(a) "Goods and Services Outside
of the App" carve-out. Razorpay is the correct and permitted mechanism; IAP must **not** be used
(Apple would reject an attempt to sell home nursing through IAP).
**Two things to keep clean:** (1) do not add any digital-only unlock — premium care articles, a
"Sahayak Pro" subscription, an ad-free tier — without moving that specific item to IAP;
(2) "Refer & Earn ₹500" (`lib/screens/settings/referral_screen.dart`) is currently a real-world
credit, which is fine, but must not evolve into spendable in-app currency.
**Action:** state plainly in the App Review notes that all purchases are for in-home healthcare
services delivered physically in Delhi NCR, and cite 3.1.5(a).

**Guideline 2.1 — Completeness / "demo app".** The combination that reviewers reject on sight is
all present at once: fabricated patient data on first launch, a backend hostname that does not
resolve, a placeholder Razorpay key that simulates a successful payment, the stock Flutter icon,
a blank launch screen, and a **placeholder support number** — `919999999999` in the WhatsApp help
link at `lib/screens/settings/help_faq_screen.dart:365`. Individually each is small; together they
read unmistakably as an unfinished app.

**Guideline 2.3.1 — Hidden/undocumented features.** A simulated payment that reports success to
the user (`payment_service.dart` demo path) while charging nothing is defensible in a demo build
and indefensible in a shipped one. Ship with a real key or with purchase disabled — never with the
simulator.

**AI assistant (Sahayak) — 5.1.2 and disclosure.** `lib/screens/assistant/assistant_screen.dart`
carries **no "AI-generated, may be inaccurate" notice** (its only preamble is the Hinglish greeting
at line 133). When `ASSISTANT_API_URL` is set (`lib/config/constants.dart:10`), user-typed text is
sent to a Cloud Function that calls Claude (`functions/index.js:114,153`). In a medical context an
assistant that can be asked health questions without a disclaimer invites 1.4.1 scrutiny, and the
data flow must appear in the privacy policy and the App Privacy labels.
**Good news, verified:** `ANTHROPIC_API_KEY` does **not** appear anywhere in `lib/`, `ios/` or
`assets/` (grep for `ANTHROPIC|sk-ant` → no matches); it exists only as a Firebase secret
(`functions/index.js:21` `defineSecret("ANTHROPIC_API_KEY")`). The secret-handling design is
correct. Likewise `GoogleService-Info.plist` and `google-services.json` are gitignored
(`.gitignore:44-46`) and untracked, while being correctly referenced by the Xcode project
(`project.pbxproj:16,69,146,274`).

---

## Blockers (must fix before any submission)

1. **App icon is the stock Flutter logo** — all 15 files in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
   Rejection under 4.0/2.3.8. (§6)
2. **`NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` missing** while six screens open
   the camera/photo library — iOS terminates the app on tap. (§5)
3. **Demo patient data seeds on every fresh install** — `app_provider.dart:182,222`; a reviewer
   sees fabricated clinical records for "Rajesh Kumar". 2.1 / 2.3.1 / 1.4.1. (§2)
4. **No in-app account deletion** — Guideline 5.1.1(v). (§5)
5. **Privacy Policy / Terms links fail TLS** — `https://housepital.in/privacy` (curl exit 60);
   `www.` works. Four hardcoded links affected. (§5)
6. **Production API host does not exist** — `api.housepital.in` is NXDOMAIN; the entire app runs on
   demo fallbacks. (§2, §3)
7. **Placeholder Razorpay key → simulated "successful" payments** in the recorded build config. (§2)
8. **`ITSAppUsesNonExemptEncryption` missing** — every upload stalls on Missing Compliance. (§5)
9. **No medical disclaimer anywhere in the UI** while the app colour-codes vital signs. (§App Review)

## High

10. **Push Notifications capability / entitlement absent** — no `.entitlements` file exists; FCM is
    wired and will not work in production. (§4)
11. **No Crashlytics dSYM upload phase** — every production crash arrives unsymbolicated. (§4)
12. **No feature-flag / remote-config kill switch** — no way to disable the assistant, payments, or
    any broken feature without a full App Review cycle. (§12)
13. **iPad declared supported (`TARGETED_DEVICE_FAMILY = "1,2"`) and landscape unlocked**, both
    untested — forces iPad screenshots and iPad review. Recommend dropping to iPhone portrait. (§6)
14. **Android release signs with debug keys** (`android/app/build.gradle.kts:34-37`) — unshippable
    if Android is ever in scope. (§4)
15. **Placeholder support number `919999999999`** in the WhatsApp help link
    (`help_faq_screen.dart:365`). (§App Review)
16. **Firestore rules + Firebase API-key restrictions not deployed** — KNOWN_ISSUES BUG-33, BUG-34
    both open at the console. (§3)

## Medium / Low

17. 28 raw `debugPrint` calls ship in release, several printing exception detail. (§2)
18. Version string hardcoded in `about_screen.dart:11` and `settings_screen.dart:257` — will drift
    from `pubspec.yaml`. (§1)
19. Three inconsistent app identifiers across iOS / Android / KNOWN_ISSUES BUG-34. (§1)
20. `CFBundleLocalizations` absent — the store will list the app as English-only despite a complete
    321-key Hindi localisation. (§9)
21. CHANGELOG is five commits behind HEAD and is date-keyed rather than version-keyed. (§11)
22. No git tags; no release-tagging process. (§11)
23. Stale `FLUTTER_APPLICATION_PATH` in `ios/Flutter/Generated.xcconfig` — run `flutter pub get`
    before archiving. (§8)
24. Launch screen is a 1×1 transparent PNG on white — blank flash before the orange splash. (§6)
25. `CFBundleDisplayName` "Housepital Patient" truncates on the Home Screen. (§6)
26. 81 MB of bundled assets (78 MB product photos) — likely over the 200 MB cellular threshold once
    frameworks are added; measure on the first archive. (§8)
27. CI still runs `analyze --no-fatal-warnings --no-fatal-infos` for a 284-issue backlog that
    `flutter analyze` now reports as zero — the gate can be tightened. (§8)
28. KNOWN_ISSUES BUG-07 (3 failing widget tests) and BUG-08 (`AuthProvider` untested) still open. (§9)

---

## BLOCKED-OWNER — what only the owner can supply

Everything below requires an Apple Developer account action, a live service, or a business
decision. None can be produced from the repo.

1. **Apple Developer Program enrolment + App Store Connect app record.** Team `3M5BRKQ345` is
   already configured for signing, so the account likely exists; the **app record does not**.
   Needed: create the app in ASC with bundle ID `com.housepital.housepitalPatient` (must match
   `project.pbxproj:690` exactly), primary language English (India), SKU.
2. **Privacy policy URL** — use `https://www.housepital.in/privacy` (verified `200`; the bare-apex
   form currently in the code fails TLS). Content must be updated to cover, explicitly: phone
   number, health data (vitals, medications, conditions, allergies, doctor handover reports),
   photos of prescriptions and reports, home address, payment data via Razorpay, Firebase
   Crashlytics/Performance diagnostics, and — if `ASSISTANT_API_URL` is enabled — that assistant
   messages are processed by a third-party AI provider (Anthropic).
3. **Support URL** — a real page (e.g. `https://www.housepital.in/support`), plus a real support
   phone/WhatsApp number to replace the `919999999999` placeholder.
4. **Marketing URL** (optional) — `https://www.housepital.in`.
5. **App Store screenshots** — 6.7" (1290×2796) and 6.5" (1242×2688) iPhone are mandatory; **12.9"
   iPad (2048×2732) is also mandatory unless `TARGETED_DEVICE_FAMILY` is changed to `"1"`.**
   Screenshots must show real (or clearly labelled representative) content, not the "Rajesh Kumar"
   demo record.
6. **App name, subtitle (30 chars), description, keywords (100 chars), promotional text.**
   Description must not make diagnostic or treatment claims.
7. **Age rating questionnaire answers.** Expect 12+ or 17+ given medical/treatment information;
   answer the "Medical/Treatment Information" question honestly — under-rating is a rejection.
8. **Category** — recommend Primary: Medical, Secondary: Health & Fitness.
9. **App Privacy "nutrition label" answers** — at minimum declare collection of: Health & Fitness
   (Health), Contact Info (phone, name, physical address), User Content (photos), Financial Info
   (payment), Identifiers (user ID, device ID via Firebase), Diagnostics (crash + performance data).
   Declare linkage to identity and purpose (App Functionality) per category.
10. **Real Razorpay key** — a live `rzp_live_…` key ID, passed as
    `--dart-define=RAZORPAY_KEY=rzp_live_…` at build time (the secret must stay server-side).
    Requires completed Razorpay KYC for Housepital Pvt Ltd (CIN U85100DL2019PTC357830 per
    `about_screen.dart:15`).
11. **Production backend** — `api.housepital.in` must exist and serve `/v1`, or `apiBaseUrl` must be
    repointed at the deployed Cloud Functions URL. Also deploy `firestore.rules` and apply the
    Firebase console key restrictions (KNOWN_ISSUES BUG-33, BUG-34).
12. **APNs authentication key (.p8)** uploaded to the Firebase console, after the Push Notifications
    capability is enabled in Xcode.
13. **Firebase Auth test phone number** (Console → Authentication → Sign-in method → Phone → Phone
    numbers for testing) so App Review can sign in — plus the number and code written into the
    App Review notes.
14. **Export compliance decision** — confirm the app uses only standard HTTPS encryption (it does,
    from the code) so `ITSAppUsesNonExemptEncryption = false` is the correct answer.
15. **Business decision: iPad and landscape in or out?** Keeping them costs iPad screenshots plus a
    real iPad/landscape QA pass; dropping them is a two-line change.
16. **Business decision: does the demo/AI assistant ship in 1.0?** If yes it needs a disclaimer and
    privacy disclosure; if no, `ASSISTANT_API_URL` stays unset and the entry point should be hidden.

---

## Suggested ordered runway to submission

**Phase 1 — one afternoon, unblocks everything (do these first):**
Real app icon set · `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` ·
`ITSAppUsesNonExemptEncryption` · `CFBundleLocalizations` · `www.` on the four hardcoded URLs ·
`TARGETED_DEVICE_FAMILY = "1"` + portrait lock · replace the placeholder WhatsApp number.

**Phase 2 — the review-compliance work (a few days):**
Gate the demo data behind a dart-define and build honest empty states · add in-app account deletion ·
add the medical disclaimer on vitals/reports and an AI notice on Sahayak · enable Push
Notifications capability · add the Crashlytics dSYM upload phase.

**Phase 3 — the real dependencies (owner-led, longest lead time):**
Stand up the production API · deploy Firestore rules and Firebase key restrictions · complete
Razorpay KYC and obtain a live key · configure the Firebase test phone number.

**Phase 4 — release hygiene, then ship:**
Add a remote-config kill switch for assistant/payments/force-upgrade · update CHANGELOG and
KNOWN_ISSUES · tag `v1.0.0` · archive with distribution signing and a bumped build number ·
**TestFlight internal first** (it will catch the camera crash and the demo data immediately) ·
then submit with reviewer notes covering the 3.1.5(a) real-world-services rationale, the test
phone number, and the medical-disclaimer placement.

---

## Verdict

**The app does not pass this checklist — 26 ❌ / 13 ⚠️ / 3 ✅ across 43 items.**
That is the expected shape for an app that has never been submitted, and it is not a judgement on
the codebase: `flutter analyze` is clean, the design gate passes, 99 test files with a CI coverage
floor exist, error handling and offline fallbacks are better than most shipped apps, and the
secret-handling design (`ANTHROPIC_API_KEY` server-side only, plists gitignored) is correct.
What is missing is the entire *submission* layer — icon, permission strings, compliance answers,
store metadata, a live backend, a real payment key — plus three genuine product defects (demo data
on fresh install, no account deletion, no medical disclaimer) that would each independently fail
App Review for a health app.
