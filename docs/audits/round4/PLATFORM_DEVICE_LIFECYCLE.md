# Platform & Device Lifecycle — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** Platform & Device Lifecycle (control family PLAT) ·
**Scope:** source review of `ios/`, `android/`, `web/`, `pubspec.yaml`, `lib/` (see Limitations)

---

## Applicability

PLAT applies to "every client app, including mobile, desktop, TV, watch, spatial, and
web-installed experiences." This is a Flutter client shipping to iOS and Android with a
`web/` target present in-tree. Cadence trigger: **"full matrix before first release"** — the
app has not shipped, so the full matrix is due now. ALWAYS-REQUIRED under MASTER-2.06.

**This module has never been audited.** No round-3 report exists at
`docs/audits/round3/PLATFORM_DEVICE_LIFECYCLE.md`, so there is no prior-round status table.
Where a round-3 finding from another module overlaps my scope (Android debug keystore, no
dSYM phase, Dynamic Type clamp, demo-notice overlay) I re-verify it below rather than
inherit it.

### The declared platform contract, established from source

| Axis | Declared value | Where |
|---|---|---|
| iOS deployment target | **13.0** | `ios/Runner.xcodeproj/project.pbxproj:484, 614, 665` (Debug/Profile/Release) |
| iOS device family | **1,2 — iPhone AND iPad** | `project.pbxproj:488, 618, 671` |
| iOS orientations (iPhone) | Portrait, LandscapeLeft, LandscapeRight | `ios/Runner/Info.plist:56-61` |
| iOS orientations (iPad) | **all four**, incl. PortraitUpsideDown | `ios/Runner/Info.plist:62-68` |
| iOS multi-scene | disabled | `Info.plist:31` `UIApplicationSupportsMultipleScenes = false` |
| Android minSdk | **24** (Android 7.0) | `android/app/build.gradle.kts:27` → `flutter.minSdkVersion` = 24 (`$FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt:26`) |
| Android target/compileSdk | **36** (Android 16) | same, `FlutterExtension.kt:23,34` |
| Dart / Flutter SDK | `sdk: ^3.11.0`; toolchain pinned **Flutter 3.41.2 / Dart 3.11.0** | `pubspec.yaml:7`; `.github/workflows/ci.yml` `flutter-version: '3.41.2'` |
| Web | `web/index.html` + `manifest.json` present; `kIsWeb` branches in 9 lib files | `web/`, `lib/main.dart:113,178,269,287,337` |
| Locales | EN + HI | `assets/i18n/en.json`, `hi.json` |
| Text scaling | clamped **0.85×–1.4×** | `lib/main.dart:426-429` |

**Nowhere in the repo is this matrix written down.** `docs/` contains 15 markdown files;
the only platform-version string in any of them is `docs/TROUBLESHOOTING.md:279`
("Ensure `minSdkVersion` is at least 19 in `android/app/build.gradle`") — which is stale by
two SDK bumps, names a Groovy file that does not exist (the project uses
`build.gradle.kts`), and contradicts the actual floor of 24.

---

## Control results

### 1. Support matrix and platform contract

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PLAT-1.01 — supported devices, architectures, OS versions, orientations, window sizes, inputs, appearances, locales, a11y features explicitly listed | **Fail** | No support-matrix document exists. `grep -rln "minimum iOS\|iOS 13\|minSdk\|supported devices\|device matrix\|Android 7\|API 24" docs *.md` returns exactly one file, `docs/TROUBLESHOOTING.md`, whose only hit (line 279) is the stale `minSdkVersion 19` note. `CLAUDE.md` — the "living contract" — has no platform section. The table above had to be reconstructed from build files by this audit. | **Impact:** the team cannot say what it supports, so it cannot say what it broke. Every other PLAT control depends on this list; without it "tested" has no denominator. **Mitigation:** write the matrix (the table above is a starting draft) into `CLAUDE.md` and `docs/`. **Owner:** OWNER-TBD. **Due:** before first submission. |
| PLAT-1.02 — oldest supported, current, representative low-end, and beta environments included based on risk | **Fail** | The only size/version coverage in the repo is `test/screens/overflow_smoke_test.dart:102-104`, which pumps 37 screens at `Size(320,568)`, `Size(375,667)`, `Size(414,896)` with `devicePixelRatio = 1.0` (line 350). That is three iPhone **portrait** widths inside a widget-test harness. CI runs on `ubuntu-latest` (`.github/workflows/ci.yml`) and executes only `flutter pub get`, `flutter analyze`, the design gate, and `flutter test` — **no `flutter build ios`, no `flutter build apk`, no simulator or device run**. Nothing exercises iOS 13, Android 7 (API 24), a low-RAM device, or any beta OS. | **Impact:** the declared floors (iOS 13.0, API 24) are asserted, never demonstrated. A first-launch crash on the oldest supported OS would reach users. **Mitigation:** add build jobs for both platforms and a minimum-OS simulator/emulator smoke run. **Owner:** OWNER-TBD. |
| PLAT-1.03 — unsupported configurations fail clearly or are prevented from installing without risking user data | **Warning** | Store-level enforcement is automatic and correct: `LSRequiresIPhoneOS` (`Info.plist:27`) plus `IPHONEOS_DEPLOYMENT_TARGET = 13.0` and `minSdk = 24` mean the App Store and Play will not offer the build to older OSes. There is no in-app version check, which is acceptable given that. The unclear configuration is **web**: `web/index.html` and `web/manifest.json` ship, `lib/main.dart` and 8 other files carry `kIsWeb` branches, and `lib/screens/billing/payment_screen.dart:36` defaults to a `'web_sim'` payment method — yet web is not built in CI, not listed as a target, and `lib/services/firebase_service.dart:121` disables file upload there. It is a half-supported configuration with no declared status. | **Impact:** low for users (nobody can install an unbuilt web target), real for the audit — an undeclared target is untestable and its `kIsWeb` branches are dead-weight the analyzer will not flag. **Mitigation:** declare web as unsupported and delete the branches, or declare it supported and build it. **Owner:** OWNER-TBD. |
| PLAT-1.04 — minimum OS/device changes include user notice, upgrade path, accessibility, export, and support implications | **Fail** | No such plan exists in any file. The specific exposure asked about in the brief: **there is no documented answer to "what happens when iOS 27 / the next Android ships."** Concretely, three mechanisms that would normally absorb an OS bump are absent — (a) CI never builds either platform, so an SDK-breaking change surfaces only when a human runs a local build; (b) the Flutter toolchain is hard-pinned to 3.41.2 in `ci.yml` with a comment warning that minor bumps change `textScaler` semantics, so adopting a new OS requires an unplanned toolchain migration first; (c) `docs/KNOWN_ISSUES.md:CI-02` records the pin as "Resolved" with no review date. | **Impact:** OS adoption becomes an unbudgeted emergency rather than a scheduled task. Apple's annual SDK-minimum enforcement (built-with-current-SDK) has a hard date; missing it blocks all submissions including hotfixes. **Mitigation:** a one-page lifecycle policy — support floor rule (e.g. N-2 major), a named review date each September/August, and a toolchain-bump owner. **Owner:** OWNER-TBD. |

### 2. Layout, windows, and scenes

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PLAT-2.01 — portrait, landscape, split screen, resizable windows, multitasking, multiple scenes, external displays, safe areas behave correctly where supported | **Fail** | **iPad and landscape are declared and structurally unimplemented.** (a) `TARGETED_DEVICE_FAMILY = "1,2"` (`project.pbxproj:488`) ships a universal binary; `UISupportedInterfaceOrientations~ipad` (`Info.plist:62-68`) permits all four orientations; `UISupportedInterfaceOrientations` (lines 56-61) permits landscape on iPhone too. (b) `grep -rn "setPreferredOrientations\|DeviceOrientation\|OrientationBuilder\|\.orientation" lib` returns **nothing** — there is no orientation lock and no orientation-aware layout anywhere. (c) There is **no tablet or width breakpoint in the app**: the only width comparison in `lib/` is `lib/screens/calendar/care_calendar_screen.dart:210` (`size.width < 360`), and the only other `constraints.maxWidth` uses are two grid-cell arithmetic sites in `lib/screens/services/tabs/equipment_tab.dart:210,396`. No `ConstrainedBox(maxWidth:)` caps page content — the largest is `maxWidth: 280` on an assistant chat bubble (`assistant_screen.dart:161`). (d) On Android, `resizeableActivity` is not declared in `android/app/src/main/AndroidManifest.xml`, so it defaults to true for targetSdk 24+ and the app is split-screen resizable, again untested. (e) No test in `test/` uses an iPad or landscape surface — the three files matching tablet-ish numbers (`test/providers/medication_provider_test.dart`, `test/models/medication_models_test.dart`, `test/screens/my_care/medication_schedule_screen_test.dart`) match on dosage/ID integers, not viewport sizes. | **What a reviewer or user actually sees:** on a 1024×1366pt iPad the entire UI is a phone layout stretched to full width — single-column lists spanning ~1000pt with no max-width cap, and the floating pill nav (`lib/screens/main_shell.dart:89-95`, 16pt side insets) rendered as a ~1000pt-wide pill with five icons clustered by `BottomNavigationBarType.fixed` spacing. In landscape on any device, the 28px/w800 display titles plus `GlassAppBar` plus the pill consume most of a ~390pt-tall viewport. **This is a store-rejection risk, not only a quality one:** App Store Review Guideline 2.4.1 requires iPad apps to make reasonable use of the display, and submission requires iPad screenshots that would show the stretched layout. **Mitigation (cheapest first):** set `TARGETED_DEVICE_FAMILY = "1"` and lock portrait via `SystemChrome.setPreferredOrientations`, reducing the claim to what is built and tested. Otherwise: build the adaptive layout and extend the overflow guard. **Owner:** OWNER-TBD. **Blocks release as currently declared.** |
| PLAT-2.02 — keyboard, system bars, cutouts, Dynamic Island, curvature, zoom, scaling do not obscure critical content | **Warning** | Positives, verified: `SafeArea` is used 22 times across 18 files; no hardcoded status-bar height constant exists in `lib/` (grep for numeric status-bar offsets found none — the codebase resolves insets via `MediaQuery.padding`, e.g. `main_shell.dart:95`); `android:windowSoftInputMode="adjustResize"` (`AndroidManifest.xml:16`) and the `configChanges` list including `screenSize|smallestScreenSize|density|uiMode|fontScale` are correct. Negatives: the overflow guard's largest surface is 414×896, which is **smaller than every Dynamic Island device** (iPhone 14 Pro 393×852 is narrower but taller; 15/16 Pro Max is 430×932) — so no test surface has the 59pt top inset or the 430pt width. The round-3 finding that the demo-notice overlay pill "absorbs touches and occludes the first content row on several screens" (`docs/KNOWN_ISSUES.md`, High) is **still open** — `DemoDataBannerHost` is installed above the Navigator at `lib/main.dart:434` and occludes by design at the top inset. | **Impact:** unverified occlusion on the most common current iPhones plus a known-open overlay defect on all of them. **Mitigation:** add 393×852 and 430×932 with realistic `viewPadding` to `overflow_smoke_test.dart`; close the overlay hit-test defect. **Owner:** OWNER-TBD. |
| PLAT-2.03 — window/scene state restores navigation, focus, selection, unsaved work, and active task after closure or relaunch | **Fail** | `grep -rn "restorationScopeId\|RestorationMixin\|RestorableProperty\|restorationId" lib` returns **nothing**. `MaterialApp` at `lib/main.dart:~410-440` sets no `restorationScopeId`. There is exactly **one** `WidgetsBindingObserver` in the entire app (`lib/screens/my_care/my_care_screen.dart:29`, `didChangeAppLifecycleState` at line 58); no app-level lifecycle handling exists. Android `MainActivity` is `launchMode="singleTop"` with `taskAffinity=""` (`AndroidManifest.xml:12-13`). | **Impact:** an OS kill under memory pressure (routine on 3–4 GB Android devices, which is most of the Delhi NCR target market) returns the user to `SplashScreen` (`main.dart:419`) with all navigation, cart contents, and in-progress booking-wizard state lost. For a checkout funnel that is a revenue defect as well as a lifecycle one. **Mitigation:** at minimum persist cart + active booking draft; ideally add `restorationScopeId`. **Owner:** OWNER-TBD. |
| PLAT-2.04 — multiple windows cannot produce unauthorized cross-account state, duplicate mutation, or destructive conflict | **N/A** | **Rationale:** the app cannot present two windows. `UIApplicationSupportsMultipleScenes` is `false` (`Info.plist:31`) and the single `UISceneConfiguration` (lines 35-47) is the Flutter default; Android declares one `MainActivity` with `launchMode="singleTop"` and no `documentLaunchMode` or multi-instance support. There is no code path that instantiates a second app window, so the failure mode this control describes cannot occur in this scope. (Split-screen resizing is a single window and is graded under PLAT-2.01.) |

### 3. Input and accessibility modes

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PLAT-3.01 — touch, keyboard, pointer, trackpad, Pencil, remote, controller, voice, switch, gaze, assistive input work where available and relevant | **Warning** | Voice input is the one input mode with a genuinely correct availability path: `lib/services/voice_service.dart:44-60` returns the result of `SpeechToText.initialize()`, stores `_available`, and every subsequent call short-circuits on `if (kIsWeb || !_available) return` (lines 69, 84, 96); `NoopVoiceService` (line ~105) is injected on web (`main.dart:269`). Failures are caught and logged, not thrown. That is the pattern the rest of the app should follow. Touch is exercised by the widget suite. Keyboard, pointer/trackpad, and Pencil are **unverified on iPad — which the app claims to support** (PLAT-2.01); `UIApplicationSupportsIndirectInputEvents` is `true` (`Info.plist:50-51`), so pointer events are delivered but nothing consumes them specially. | **Impact:** scoped to the iPad claim. If iPad support is withdrawn per PLAT-2.01, this reduces to Pass for the shipped surface. **Mitigation:** decide the iPad question first. **Owner:** OWNER-TBD. |
| PLAT-3.02 — hardware keyboard shortcuts, focus, pointer hover, context menus, drag and drop, system gestures follow platform conventions | **Warning** | No `Shortcuts`, `Actions`, `CallbackShortcuts`, `MouseRegion` hover styling, `ContextMenu`, or `Draggable` usage governs app chrome. Android **predictive back** is the concrete exposure: `targetSdk = 36`, and predictive back is on by default for apps targeting API 35+; the manifest declares no `android:enableOnBackInvokedCallback` either way, and `grep -rn "PageTransitionsTheme\|PredictiveBack" lib` returns **nothing**, so `PredictiveBackPageTransitionsBuilder` is not configured. | **Impact:** on Android 15/16 the system back gesture may show the default cross-activity animation rather than an in-app predictive transition — a visible polish defect on the newest OS the app explicitly targets. **Mitigation:** set `PredictiveBackPageTransitionsBuilder` in the Android theme branch of `theme.dart`, or pin the manifest flag deliberately. **Owner:** OWNER-TBD. |
| PLAT-3.03 — IME changes, dictation, external keyboards, non-Latin IMEs, emoji, paste, autofill, password managers do not corrupt or block input | **Warning** | `grep -rn "autofillHints\|AutofillGroup" lib` returns **nothing**. The app is phone-OTP based (`lib/screens/auth/otp_screen.dart`, `pin_code_fields: ^8.0.1`), so the highest-value autofill hint — `AutofillHints.oneTimeCode`, which drives iOS SMS-code autofill above the keyboard and Android SMS Retriever — is absent, as is `AutofillHints.telephoneNumber` on the phone field. Non-Latin IME: Hindi is a shipped locale and `NotoSansDevanagari` is bundled (`pubspec.yaml:98-100`), but no test enters Devanagari text into a field. Paste/dictation unverified. | **Impact:** every user manually retypes the OTP they were just sent — measurable onboarding friction on the app's single mandatory gate. **Mitigation:** add `autofillHints: [AutofillHints.oneTimeCode]` to the OTP field and `telephoneNumber` to the login field; low effort, high return. **Owner:** OWNER-TBD. |
| PLAT-3.04 — system accessibility settings can change while the app runs without unsafe restart or lost state | **Warning** | Flutter rebuilds on `MediaQuery` change, so brightness, bold-text, and reduce-motion changes propagate without restart, and `lib/main.dart:426-429` re-derives `textScaler` inside `MaterialApp.builder` on every rebuild — structurally correct. Two gaps: no `didChangeAccessibilityFeatures` override exists anywhere (only one `WidgetsBindingObserver` in the app, in `my_care_screen.dart`), and the **1.4× clamp** (`main.dart:427-428`) silently discards user preference above 140% — round 3 recorded this as untested and it remains so. | **Impact:** users at iOS "Larger Accessibility Sizes" (up to 310%) get 140%. Documented as an accepted trade-off in the code comment ("WCAG 1.4.4"), but WCAG 1.4.4 asks for 200%, so the comment overstates the compliance. **Mitigation:** raise the ceiling toward 2.0× and extend the overflow guard to match, or record the 1.4× ceiling as an explicit accepted risk with an approver. **Owner:** OWNER-TBD. |

### 4. App and device lifecycle

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PLAT-4.01 — cold launch, warm launch, resume, background, suspension, termination, crash, reboot, lock/unlock, protected-data availability preserve integrity | **Fail** | Same evidence as PLAT-2.03: one `WidgetsBindingObserver` app-wide (`my_care_screen.dart:29`), no state restoration, no `AppLifecycleListener`. Cold-launch integrity is partly handled — `StoreMigrator.run()` is awaited before any provider constructor reads SharedPreferences (`lib/main.dart:175`, with the ordering rationale in the comment above it), which is correct and is the round-3 fix holding. Reboot is partly handled on Android via `RECEIVE_BOOT_COMPLETED` (`AndroidManifest.xml:2`) for `flutter_local_notifications` rescheduling. Termination and lock/unlock are unhandled; there is no protected-data (`NSFileProtection` / `isProtectedDataAvailable`) consideration despite the app holding health data. | **Impact:** as PLAT-2.03 — background kill loses the session. Additionally, notifications scheduled while the device is locked with data protection engaged have no guarded path. **Mitigation:** as PLAT-2.03. **Owner:** OWNER-TBD. |
| PLAT-4.02 — call/media interruption, audio route change, camera/mic interruption, scene handoff, multitasking preserve or clearly end work | **Warning** | The app has an audio surface: `speech_to_text: ^7.4.0` (mic) and `flutter_tts: ^4.2.5` (speaker) drive the Sahayak assistant. `PluginVoiceService` (`lib/services/voice_service.dart`) tracks `_listening` from the plugin's `onStatus`/`onError` callbacks (lines 47-53) and stops cleanly in `stopListening` (lines 81-92), so a plugin-level interruption resets the flag. But there is **no `AVAudioSession` category configuration and no interruption observer** — nothing in `ios/Runner/AppDelegate.swift` or Dart handles `AVAudioSessionInterruptionNotification`. Untested against a real inbound call. | **Impact:** an inbound call during a TTS reply or dictation may leave the assistant's mic button in a stale visual state, or fail to resume audio. Contained (voice is an assistant convenience, not a care-critical path). **Mitigation:** verify on device; the plugins may already handle it. Grade is Warning-unverified, not Fail. **Owner:** OWNER-TBD. |
| PLAT-4.03 — memory pressure, low storage, disk full, thermal, low-power mode, battery loss, network transition degrade safely | **Warning** | Network transition is the best-covered axis: the app is built to run entirely on `DemoData` when `api.housepital.in` is unreachable, and `lib/services/firebase_service.dart` wraps every call in try/catch with `Log.warn` (lines 149-213 passim). Low storage / disk full is unhandled: `SharedPreferences.setString` calls are not guarded against write failure, and on-device PDF generation (`invoice_pdf_service.dart`, `handover_report_service.dart` via `pdf` + `printing`) allocates and writes without a space check. Memory pressure has no `didHaveMemoryPressure` handler. No thermal or low-power-mode adaptation exists — relevant because `lib/screens/main_shell.dart:121` plus the glass chrome puts, per round 3, **four `BackdropFilter` surfaces on screen per frame (~22% of screen area)**, which is exactly the workload a device throttles first. | **Impact:** GPU-heavy blur on a mid-range Android device in a warm Delhi summer is a plausible thermal/battery complaint path, and it is unmeasured. **Mitigation:** measure frame cost on a representative low-end device; consider dropping blur under `MediaQuery.disableAnimations` or a low-power signal. **Owner:** OWNER-TBD. |
| PLAT-4.04 — time-zone, locale, DST, clock correction, calendar, region changes update scheduled and displayed behavior | **Warning** | Timezone handling exists and is thoughtful but has a real defect. `lib/services/medication_reminder_service.dart:59-72`: after `tz.initializeTimeZones()`, if `tz.local.name == 'UTC'` it iterates `tz.timeZoneDatabase.locations.values` and calls `tz.setLocalLocation(location)` on the **first location whose `currentTimeZone.offset` matches the device's current offset**, then breaks. Offset is not identity — dozens of zones share +05:30 and, more importantly, zones sharing an offset *today* diverge under different DST rules. India has no DST so the practical blast radius here is small, but the algorithm is wrong in general and would misfire for any user travelling or any future locale. Separately: `grep -rn "didChangeLocales" lib` returns **nothing**, so a mid-session system-language change is not observed (Flutter's `MaterialApp` will still re-resolve `localeResolutionCallback` on rebuild, so display text follows; app-managed `preferred_language` in `auth_provider.dart:197` does not). | **Impact:** medication reminders — a clinical-adjacent surface — can be scheduled against a wrong `tz.Location` for a user whose device reports UTC. **Mitigation:** use `flutter_timezone` to read the IANA zone name rather than offset-matching. **Owner:** OWNER-TBD. |

### 5. Permissions and system settings

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PLAT-5.01 — every permission requested in context with accurate purpose text and a useful denied/restricted/limited path | **Warning** | **Purpose strings: Pass on content.** `Info.plist:69-76` declares `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, and each names the actual feature ("so you can photograph prescriptions, lab reports…"). These are better than most. **Timing: Fail on notifications.** iOS notification permission is requested twice, both times out of context: (a) `MedicationReminderService().init()` is awaited at `lib/main.dart:179` — **before `runApp`** — with `DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true)` (`medication_reminder_service.dart:79-83`), so the system prompt can fire on a blank screen at first cold launch; (b) `_setupFCM()` runs in an `addPostFrameCallback` at `main.dart:331` and calls `requestNotificationPermission()` (`firebase_service.dart:317` → `:158`). The user is asked to accept notifications before being told what they are for. **Denied path:** `requestNotificationPermission` discards the returned `NotificationSettings` entirely (`firebase_service.dart:158-162` — the `await` result is not assigned), so the app never knows whether it was granted. | **Impact:** cold-open permission prompts are the single most reliable way to get a permanent denial, and the app cannot detect the denial once it happens — medication reminders then silently never appear. **Mitigation:** set the Darwin `request*Permission` flags to `false`, move the ask behind a pre-permission explainer on the medication or notification-settings screen, and capture `settings.authorizationStatus`. **Owner:** OWNER-TBD. |
| PLAT-5.02 — grant, deny, limited, provisional, one-time, parental restriction, MDM restriction, and later Settings changes handled | **Fail** | `grep -rn "permission_handler\|openAppSettings\|AppSettings" lib pubspec.yaml` returns **nothing**. There is no permission-state API in the app at all, therefore no handling of denied, limited-photo-library, provisional, one-time, or Settings-changed states, and **no "Open Settings" affordance anywhere** for a user who denied once and now wants to enable the camera or notifications. The single graceful case is voice, which degrades because `SpeechToText.initialize()` returns false (`voice_service.dart:46-60`) — that is availability handling, not permission handling. `image_picker` is called with no pre-check at 6 sites (`patient_profile_screen.dart:205`, `chat_screen.dart:121`, `raise_concern_screen.dart:96`, `document_repository_screen.dart:613,631`, `settings_screen.dart:~70`); on denial the picker returns null and, at `raise_concern_screen.dart:107`, the user gets a snackbar that does not distinguish "you cancelled" from "you denied camera access and must fix it in Settings". | **Impact:** a user who denies camera access once has no in-app route back — the button appears to do nothing forever. This is a support-load and abandonment defect on the document-upload and concern-photo flows. **Mitigation:** add `permission_handler`, branch on `permanentlyDenied`, and offer `openAppSettings()`. **Owner:** OWNER-TBD. |
| PLAT-5.03 — the app detects stale authorization without repeatedly nagging or requiring unrelated permission | **Warning** | It does not nag — verified: each permission is requested at most once per launch and there is no retry loop. It also does not detect. Because no permission state is ever read (PLAT-5.02), "stale authorization" is undetectable by construction rather than by omission. | **Impact:** the no-nag half is genuinely correct; the detect half is absent. Folded into the PLAT-5.02 mitigation. **Owner:** OWNER-TBD. |
| PLAT-5.04 — sensitive behavior stops promptly when permission, account access, subscription, sharing, or device trust is revoked | **Warning** | The account-revocation half is now **correct and is the round-3 fix holding**: `lib/utils/session_scope.dart:100` calls `await MedicationReminderService().cancelAllReminders()`, so OS-scheduled medication notifications — which outlive the process — are cancelled on logout and on patient switch. That was the specific defect round 3 found and it is closed. The permission-revocation half is absent: if the user revokes microphone or camera in Settings while the app is backgrounded, nothing re-checks on resume (no `didChangeAppLifecycleState` at app level, PLAT-4.01). | **Impact:** limited — the plugins fail closed rather than open, so revoked hardware yields a non-functional button, not a privacy leak. **Mitigation:** re-check availability on resume once an app-level lifecycle observer exists. **Owner:** OWNER-TBD. |

### 6. Installation, update, backup, and restore

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PLAT-6.01 — fresh install, update in place, beta-to-store transition, offload/reinstall, uninstall/reinstall, new-device restore tested as applicable | **Fail** | None of these are tested; more importantly one of them is **structurally impossible today**. `android/app/build.gradle.kts:36-39`: `release { signingConfig = signingConfigs.getByName("debug") }`, with the template TODO still present. A release APK/AAB signed with the debug keystore cannot be uploaded to Play, and cannot update in place over any differently-signed build — signature mismatch is a hard install failure. Round 3 recorded this; it is **still open**, unchanged at commit 9127713. Fresh-install behaviour is also unverified against the known-open "demo clinical data seeds on every fresh install" blocker in `docs/KNOWN_ISSUES.md`. | **Impact:** Android cannot ship at all. **Mitigation:** generate an upload keystore, wire `signingConfigs.release` from `key.properties`, and enrol in Play App Signing. **Owner:** OWNER-TBD. **Release blocker.** |
| PLAT-6.02 — app data, keychain/secure storage, app groups, files, widgets, notification tokens, cached credentials follow intended persistence rules | **Warning** | Persistence rules are documented and, where implemented, honoured — `CLAUDE.md` "Storage & session contracts" specifies per-patient keys (`housepital_orders_<patientId>`), memory-only clears, and `StoreMigrator` at v2, and `test/providers/patient_scope_isolation_test.dart` asserts the scope. Credentials: the auth token is held **in memory only** (`lib/services/api_service.dart:16` `String? _authToken`, set at `:45`, read at `:50`) and never written to disk — so there is no keychain misuse and no token to leak from a backup. The only SharedPreferences writes touching identity are `has_onboarded` and `preferred_language` (`auth_provider.dart:196-197`). No app groups, widgets, or extensions exist. The gap is the **FCM token**: `setupFCM` registers it to the server (`firebase_service.dart:320-327`) but no path clears or re-registers it on logout/patient switch, and `SessionScope` (which `CLAUDE.md` says "enumerates STORES") does not list it. | **Impact:** after logout, the server may still hold a token mapping this device to the previous account — a cross-account push-delivery risk. It is latent today only because push does not work at all (PLAT-7.01). **Mitigation:** add `deleteToken()` / re-register to `SessionScope`. **Owner:** OWNER-TBD. |
| PLAT-6.03 — backup exclusion and inclusion match data sensitivity, recoverability, size, and platform policy | **Fail** | Android: `grep -rn "allowBackup\|dataExtractionRules\|fullBackupContent" android/` returns **nothing**, and `android/app/src/main/res/xml/` **does not exist**. With `targetSdk = 36` and no declaration, `android:allowBackup` defaults to `true` and Auto Backup / Device-to-Device transfer includes the whole SharedPreferences store with **no exclusion rules whatsoever**. That store holds per-patient order and assessment history — health-adjacent data — under keys `housepital_orders_<patientId>`. iOS: no `NSURLIsExcludedFromBackupKey` usage and no file-protection class set on anything the PDF services write. | **Impact:** patient order/assessment history is silently copied to Google's cloud backup and restored onto any new device the account signs into, with no declaration, no user notice, and no exclusion for the health-relevant keys. This is a privacy-policy and data-residency exposure as much as a platform one, and it interacts with whatever the Security/Privacy module concludes. **Mitigation:** add `res/xml/data_extraction_rules.xml` + `backup_rules.xml`, exclude the patient-scoped prefs, and set `android:dataExtractionRules` / `android:fullBackupContent`. **Owner:** OWNER-TBD. |
| PLAT-6.04 — failed update or restore preserves the last usable data or provides a non-destructive recovery path | **Warning** | The migration path is genuinely well built and is the strongest lifecycle control in the app: `StoreMigrator` is at v2 with one shipped step, and `CLAUDE.md` records the invariants — frozen literals, `quarantine()` rather than overwrite, never stamp success on a failed step — with the v1→v2 step quarantining the legacy global order keys rather than deleting them. `main.dart:175` runs it before any provider reads. That is a correct non-destructive design. Unverified: no test simulates a *failed* migration mid-run, and `docs/KNOWN_ISSUES.md` records that `logger.dart:63` is an unwired TODO covering "every `StoreMigrator` failure path" — so a failure would be silent and unreported. | **Impact:** the recovery path exists but its failure mode is invisible. **Mitigation:** wire the logger sink; add a failed-step test. **Owner:** OWNER-TBD. |

### 7. System integrations and extensions

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PLAT-7.01 — notifications, deep/universal links, widgets, Live Activities, share/action extensions, intents, shortcuts, app clips, watch companions, background tasks tested where present | **Fail** | Three independent, individually-sufficient defects. **(a) iOS push cannot work.** `grep -n "CODE_SIGN_ENTITLEMENTS" ios/Runner.xcodeproj/project.pbxproj` returns **nothing** and no `.entitlements` file exists outside `Pods/` — so there is no `aps-environment` entitlement and the app has no Push Notifications capability. `UIBackgroundModes` is **absent** from `Info.plist`, so `remote-notification` is not declared either, and the background handler registered at `firebase_service.dart:190` (`FirebaseMessaging.onBackgroundMessage`) can never run on iOS. **(b) Android push is misconfigured at the identity level.** `android/app/google-services.json` declares `"package_name": "com.housepital.patient"`, but `android/app/build.gradle.kts:24,26` set `namespace` and `applicationId` to **`com.housepital.housepital_patient`** — a mismatch. It does not fail the build only because the `com.google.gms.google-services` Gradle plugin is **not applied** (`grep -rn "google-services\|com.google.gms" android/` → nothing), so the file is inert and never processed. A third spelling, `in.housepital.patient`, appears in `docs/KNOWN_ISSUES.md` BUG-34 as the package to restrict the API key to. Three package identities, no reconciliation. **(c) `tel:`/`mailto:`/`https:` launching is broken on Android 11+.** `url_launcher` 6.3.2's own README (lines 63-90 of `~/.pub-cache/hosted/pub.dev/url_launcher-6.3.2/README.md`) states: *"Add any URL schemes passed to `canLaunchUrl` as `<queries>` entries in your `AndroidManifest.xml`, otherwise it will return false in most cases starting on Android 11 (API 30) or higher."* The manifest's `<queries>` block (`AndroidManifest.xml:45-50`) contains **only** the Flutter-template `PROCESS_TEXT` intent — no `tel`, no `mailto`, no `https`. Five call sites gate on `canLaunchUrl` and will therefore take their failure branch on API 30+: `sos_screen.dart:251`, `assistant_screen.dart:40`, `help_faq_screen.dart:414`, `about_screen.dart:168`, and `staff_otp_verification_screen.dart:355`. **Deep links:** the manifest has one `intent-filter` (`AndroidManifest.xml:27-30`) containing only MAIN/LAUNCHER — no `VIEW`/`BROWSABLE`, no `https` host. `Info.plist` has no `CFBundleURLTypes` and no associated-domains entitlement. There are no widgets, Live Activities, extensions, app clips, or watch targets. | **The `staff_otp_verification_screen.dart:351-357` case is a dead control:** `if (await canLaunchUrl(uri)) { await launchUrl(uri); }` with **no `else`** — on Android 11+ the "Call Support" button does nothing at all, silently, on the screen where a patient is trying to verify a staff member at their door. **The SOS case is the one that was designed defensively and survives:** `sos_screen.dart:247-278` falls through to a "Could not auto-dial" dialog with a copy-number action, so the inviolable "SOS is never blocked" rule holds in outcome — but auto-dial, the fast path, is lost on Android. **Mitigation:** add the `<queries>` intents (3 lines each, per the README example); create `Runner.entitlements` with `aps-environment` and add `remote-notification` to `UIBackgroundModes`; reconcile the Android package identity and apply the google-services plugin. **Owner:** OWNER-TBD. **Release blocker.** |
| PLAT-7.02 — extensions handle independent launch, stale/shared data, memory/time limits, account changes, unavailable parent app, version mismatch | **N/A** | **Rationale:** the project contains no app extension, widget, app clip, watch companion, or share/action extension target. `ios/Runner.xcodeproj/project.pbxproj` declares two native targets only — `Runner` and `RunnerTests` (`PRODUCT_BUNDLE_IDENTIFIER` values at lines 507/690/713 and 524/542/558). Android declares one `<application>` with a single `MainActivity` and no `<provider>`/`<receiver>` of our own. There is no second executable that could exhibit the failure modes this control describes. |
| PLAT-7.03 — handoff, continuity, cloud documents, external files, printing, sharing, and default-app roles respect authorization and privacy | **Warning** | Printing and sharing are present and in scope: `printing: ^5.14.3` and `pdf: ^3.12.0` generate the invoice and doctor-handover PDFs on device, and `share_plus: ^11.0.0` exports them. Authorization is applied at the right layer — `CLAUDE.md` records that "Sensitive exports (doctor handover PDF) are role-gated" via the role/permission layer, and quote-pending invoices export PRO FORMA without amounts. External file opening is handled defensively at `document_repository_screen.dart:507-523`: `launchUrl` wrapped in try/catch with a user-visible fallback snackbar. No handoff, continuity, `NSUserActivity`, or default-app role is claimed. Unverified: whether the exported PDF lands in a location covered by the backup rules that PLAT-6.03 shows do not exist, and no test asserts the role gate blocks the export. | **Impact:** the design is right; the verification is missing, and the backup interaction is unknown. **Mitigation:** assert the role gate in a test; resolve PLAT-6.03 first. **Owner:** OWNER-TBD. |
| PLAT-7.04 — system search/indexing, suggestions, previews, thumbnails, and recent-items surfaces do not expose sensitive content unexpectedly | **Warning** | No Spotlight/`CoreSpotlight` indexing, no App Shortcuts, no `NSUserActivity` — so nothing is deliberately published to a system index, which is the right default. The unhandled surface is the **task-switcher snapshot**: `grep -rn "FLAG_SECURE\|secureScreen\|preventScreenshot" lib android ios` returns **nothing**, and there is no `applicationWillResignActive` blur/overlay in `AppDelegate.swift`. When the app is backgrounded from the vitals, medication, daily-report, or document screens, the OS captures and persists a snapshot showing that content, visible to anyone who opens the app switcher. | **Impact:** on a shared family device — the explicit usage model for this app, which has a multi-patient switcher and family-member roles — a patient's vitals or medication list is readable from the task switcher without unlocking the app. **Mitigation:** on Android, `FLAG_SECURE` on health screens; on iOS, cover the window in `applicationWillResignActive`. Note this may belong jointly to the Security/Privacy module. **Owner:** OWNER-TBD. |

### 8. Platform release readiness

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PLAT-8.01 — the release builds with the current required SDK and is exercised on current platform behavior, including design-system changes | **Fail** | **No release artifact is ever built by any automation.** `.github/workflows/ci.yml` runs on `ubuntu-latest` and its steps are `flutter pub get`, `flutter analyze --no-fatal-warnings --no-fatal-infos`, `bash scripts/check_design_consistency.sh`, `flutter test --coverage`, and a coverage gate. There is no `flutter build ios`, no `flutter build apk`/`appbundle`, and an Ubuntu runner cannot build iOS at all. The Xcode version used for local builds is not recorded anywhere in the repo, so **compliance with Apple's built-with-current-SDK requirement cannot be established from source** (see BLOCKED-OWNER). **Deployment-target spread in Pods** (the item the brief asked me to enumerate): parsing `ios/Pods/Pods.xcodeproj/project.pbxproj` and mapping each target's build-configuration list gives 117 configurations at 13.0, 66 at 12.0, 33 at 11.0, 18 at 9.0, and 6 at 10.0. By target: **9.0** — `PromisesObjC`, `PromisesSwift`, `abseil` (+ their `_Privacy`/`xcprivacy` resource bundles); **10.0** — `BoringSSL-GRPC` (+ `openssl_grpc`); **11.0** — `RecaptchaInterop`, `gRPC-C++`, `gRPC-Core`, `leveldb-library`, `razorpay-pod`, `razorpay-core-pod`, and the `flutter_local_notifications` privacy bundle; **12.0** — 22 targets including the `Firebase`/`CwlCatchException` aggregates. **Assessment:** these are *transitive* pods — every one arrives via `cloud_firestore` (gRPC/BoringSSL/abseil/leveldb), `firebase_auth` (RecaptchaInterop/Promises) or `razorpay_flutter`; none is directly chosen by this project. They produce Xcode build **warnings**, not errors, and do not lower the app's own floor: the Runner target is 13.0 (`project.pbxproj:484,614,665`) and that is what the store enforces. The real exposure is forward-looking — as Xcode raises its minimum supported deployment target (currently 12.0, rising annually), the 9.0/10.0/11.0 pods start emitting errors rather than warnings and force a Firebase/Razorpay major upgrade that PLAT-8.02 shows is already blocked. Note also the `Podfile:2` `platform :ios` line is **commented out**, so CocoaPods infers the platform from the project each run — a warning-generating configuration that should be pinned to `13.0` explicitly. **Design-system currency:** the checklist's own source baselines cite *Apple — Adopting Liquid Glass*; the app implements its own glass vocabulary (`lib/widgets/glass.dart`, `GlassSurface`, the pill nav) and has not been exercised against the current OS's native design-system change. | **Impact:** nobody can state that the shipping artifact builds, and no automation would notice if it stopped. Every build is a hand-run on one machine — which is also the condition that produces the `0xe8008014` signing collisions `CLAUDE.md` warns about. **Mitigation:** add a macOS CI job doing `flutter build ipa --no-codesign` and `flutter build appbundle`; pin `platform :ios, '13.0'` in the Podfile. **Owner:** OWNER-TBD. **Release blocker.** |
| PLAT-8.02 — deprecated APIs, entitlement changes, privacy manifests, required-reason APIs, background limits, and store-policy changes reviewed | **Fail** | **Privacy manifest:** `find ios -name "PrivacyInfo.xcprivacy" -not -path "*/Pods/*"` returns **nothing** — there is no app-level privacy manifest. 24 pods ship their own, so the SDK-side requirement is met by dependency, but the app target declares no `NSPrivacyAccessedAPITypes` of its own despite using UserDefaults (via `shared_preferences`) and file-timestamp APIs (via the PDF services). **Entitlements:** none exist at all (PLAT-7.01). `ITSAppUsesNonExemptEncryption` is absent from `Info.plist`, so every upload will stall on a manual export-compliance answer. **Store policy — the concrete one:** `AndroidManifest.xml:3` declares `android.permission.SCHEDULE_EXACT_ALARM`, but the app **never schedules an exact alarm** — both `zonedSchedule` call sites pass `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle` (`medication_reminder_service.dart:178` and `:228`). The permission is therefore gratuitous, and Google Play requires a Play Console declaration justifying `SCHEDULE_EXACT_ALARM` for apps that are not alarm/clock/calendar apps; an unjustifiable declaration is a review rejection. **Deprecations:** `docs/KNOWN_ISSUES.md` CI-03 records a **284-issue analyzer backlog** (unused imports, deprecations) that is the stated reason CI runs `--no-fatal-warnings --no-fatal-infos`. So "analyze is clean" is true only at the tolerance CI sets; deprecated-API usage is knowingly unreviewed. | **Impact:** two independent submission-blocking items (exact-alarm declaration; export compliance friction) plus an unreviewed deprecation backlog that is the mechanism by which the next Flutter/OS bump breaks the build. **Mitigation:** delete `SCHEDULE_EXACT_ALARM` (it is unused — a one-line removal that eliminates the Play risk entirely); add `PrivacyInfo.xcprivacy` and `ITSAppUsesNonExemptEncryption`; burn down the analyzer backlog and tighten CI. **Owner:** OWNER-TBD. **Release blocker.** |
| PLAT-8.03 — crash/hang, energy, memory, size, accessibility, and rendering regressions compared across the support matrix | **Fail** | There is no matrix to compare across (PLAT-1.01) and no artifact to measure (PLAT-8.01). Crash reporting is wired — `FlutterError.onError` and `PlatformDispatcher.instance.onError` route to Crashlytics with `fatal: true` in non-debug (`lib/main.dart:117-124`) — but **iOS crash reports will be unsymbolicated**: the Runner target's shell-script build phases are Thin Binary, `[CP] Embed Pods Frameworks`, `[CP] Check Pods Manifest.lock`, `[CP] Copy Pods Resources`, and `xcode_backend.sh build` (`project.pbxproj:280-390`) — there is **no Crashlytics `upload-symbols` / dSYM phase**. Round 3 recorded "no dSYM phase"; **still open, unchanged.** `DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"` is set for Release (`project.pbxproj:653`), so the dSYMs are produced and then never uploaded. No energy, memory, size, or rendering baseline exists. Also relevant: the unguarded `launchUrl` sites below will record as **fatal** Crashlytics events. | **Impact:** the first production iOS crash arrives as an unreadable address stack. Combined with the missing dSYM upload, the crash-reporting investment is currently inert on iOS. **Mitigation:** add the Crashlytics run-script phase with `${DWARF_DSYM_FOLDER_PATH}` inputs. **Owner:** OWNER-TBD. |
| PLAT-8.04 — known platform defects have documented scope, workaround, user/support communication, and retirement condition | **Warning** | The habit exists and is good where applied: `docs/KNOWN_ISSUES.md` CI-01 documents the `--tree-shake-icons` kernel-size assertion with scope, root cause, workaround, and status; CI-02 and CI-03 follow the same shape. What is missing is any **platform** defect entry — the file's Blockers list mentions the Android debug keystore and the absent dSYM phase in a single run-on line with no scope, no workaround, no user/support communication, and no retirement condition, and none of the findings in this report (iPad/landscape, `<queries>`, entitlements, backup rules, exact-alarm) appears at all because this module had never been audited. | **Impact:** support has no script for "why didn't my Call Support button work" or "why did I get no notifications". **Mitigation:** land this report's Fails into `KNOWN_ISSUES.md` in the CI-01 format, each with a retirement condition. **Owner:** OWNER-TBD. |

---

## Cross-cutting finding: unguarded `launchUrl` is a silent-failure class

Not a numbered control on its own, but it is the mechanism behind several grades above and
deserves to be stated once with full evidence, because it inverts the intuition.

`<queries>` (PLAT-7.01c) restricts **querying**, not **starting**, an Activity. So on
Android the *guarded* call sites break and the *unguarded* ones work. The unguarded ones
break elsewhere: on iPad and any device without a dialer, and they break worse.

Nine call sites call `launchUrl` with **no `await`, no `canLaunchUrl`, and no `try`**, from
inside a synchronous `onPressed`/`onTap` closure:

| Site | Scheme |
|---|---|
| `lib/screens/home/home_screen.dart:242` | `tel:` caregiver |
| `lib/screens/home/home_screen.dart:820-821` | `tel:` support |
| `lib/screens/home/home_screen.dart:1313` | `https:` Dai Maa cross-promo (`DaiMaaColors.exploreUrl`) |
| `lib/screens/home/home_screen.dart:1878` | `tel:` role |
| `lib/screens/home/home_screen.dart:1893-1894` | `https://wa.me/…` |
| `lib/screens/care_team/care_team_screen.dart:286` | `tel:` member |
| `lib/screens/care_team/care_team_screen.dart:380-381` | `tel:` emergency |
| `lib/screens/articles/article_detail_screen.dart:305` | `tel:` support |
| `lib/screens/my_care/widgets/health_manager_banner.dart:71` | `tel:` manager |

`launchUrl` throws a `PlatformException` when no handler exists. Because the returned
`Future` is discarded, that throw is an unhandled async error, which
`PlatformDispatcher.instance.onError` (`lib/main.dart:119-122`) records to Crashlytics as
**`fatal: true`**. The user sees nothing at all. So on an iPad — a device the app declares
support for — tapping any "Call" button produces no feedback and a false fatal-crash
report. Compare `sos_screen.dart:247-278` and `payment_methods_screen.dart:361-378`, which
do this correctly with `try`/`catch` and a visible fallback; the pattern to copy already
exists in the codebase.

---

## Dependency lifecycle debt (measured)

The brief cites "78 packages with newer incompatible versions". Measured at commit 9127713
with `flutter pub outdated`:

- **79** resolved packages are behind the latest published version.
- **22** are pinned to a version older than what is even *resolvable* — i.e. blocked behind
  a major-version wall, not merely un-upgraded.
- **34** are upgradable within existing constraints (`flutter pub upgrade` would move them).
- Direct dependencies at a major behind: `firebase_core` 3.15.2 → 4.13.0, `firebase_auth`
  5.7.0 → 6.5.7, `firebase_messaging` 15.2.10 → 16.5.0, `cloud_firestore` 5.6.12 → 6.8.0,
  `firebase_crashlytics` 4.3.10 → 5.2.7, `firebase_storage` 12.4.10 → 13.4.6,
  `firebase_performance` 0.10.1+10 → 0.11.4+6, `flutter_local_notifications` **18.0.1 →
  22.3.0 (four majors)**, `go_router` 15.1.3 → 17.5.0, `fl_chart` 0.70.2 → 1.2.0,
  `share_plus` 11.1.0 → 13.3.0, `pin_code_fields` 8.0.1 → 9.4.0, `timezone` 0.9.4 → 0.11.1.
- iOS native side: Firebase pods at **11.15.0** (`ios/Podfile.lock:1198-1236`), CocoaPods
  1.16.2.

**Assessment as lifecycle debt.** The seven Firebase packages move as a locked set — none
can advance alone — so the upgrade is a single large change, not seven small ones, and it
gets more expensive every month. `flutter_local_notifications` at four majors behind is the
sharpest edge, because that library's majors are exactly where Android exact-alarm and
Android 13/14 notification-permission behaviour changed; the app is running a 2024-era
notification model against `targetSdk = 36`. `timezone` 0.9.4 → 0.11.1 matters for
PLAT-4.04. None of this is a defect today. All of it is the mechanism by which the next OS
bump becomes unaffordable, which is precisely what PLAT-1.04 asks the team to have a plan
for and it does not.

---

## Scorecard

**Pass 0 · Warning 16 · Fail 14 · N/A 2 · BLOCKED-OWNER 2**

(32 controls graded; the 2 BLOCKED-OWNER items are recorded separately below and are *not*
double-counted — they are sub-questions inside PLAT-8.01 and PLAT-1.02.)

| Family | Pass | Warning | Fail | N/A |
|---|---|---|---|---|
| 1. Support matrix | 0 | 1 | 3 | 0 |
| 2. Layout / windows | 0 | 1 | 2 | 1 |
| 3. Input / accessibility | 0 | 4 | 0 | 0 |
| 4. App & device lifecycle | 0 | 3 | 1 | 0 |
| 5. Permissions | 0 | 3 | 1 | 0 |
| 6. Install / backup / restore | 0 | 2 | 2 | 0 |
| 7. Integrations / extensions | 0 | 2 | 1 | 1 |
| 8. Release readiness | 0 | 1 | 3 | 0 |

**Zero Passes is itself the headline.** It is not a scoring artefact: this module has never
been audited, PLAT-1.01 (the list everything else is measured against) does not exist, and
PLAT-8.01 (a built artifact) does not exist either — so no control can be evidenced to the
standard the suite requires. Several controls contain genuinely good work
(`voice_service.dart` availability handling, `StoreMigrator` quarantine semantics,
`SessionScope` reminder cancellation, the `Info.plist` purpose strings, the SOS fallback
dialog) and are graded Warning only because they are unverified on a device, not because
they are wrong.

**Round-3 pattern check.** The brief asks which pattern the latest work fits. For this
module: **neither "surfaces" nor "half-wires" — a third pattern, declaration without
implementation.** `Info.plist` declares iPad and four orientations; `build.gradle.kts`
declares `SCHEDULE_EXACT_ALARM`; `google-services.json` declares an Android Firebase
client; `AndroidManifest.xml` declares `POST_NOTIFICATIONS`. In each case the declaration
is the whole of the work — there is no adaptive layout, no exact alarm, no applied
google-services plugin, no permission-state handling behind it. Round 3's "half-wire" had a
correct data structure with the behaviour left unwritten; this is a correct *manifest entry*
with the behaviour left unwritten, one layer further out.

---

## Release blockers (every Fail)

1. **PLAT-6.01 — Android release signs with the debug keystore.**
   `android/app/build.gradle.kts:36-39`. Cannot be uploaded to Play; cannot update in place.
   Carried unchanged from round 3.
2. **PLAT-7.01 — push notifications cannot be delivered on either platform.** iOS: no
   entitlements file, no `aps-environment`, no `UIBackgroundModes: remote-notification`.
   Android: `google-services.json` package `com.housepital.patient` ≠ `applicationId`
   `com.housepital.housepital_patient`, and the google-services Gradle plugin is not applied.
3. **PLAT-7.01 — Android `<queries>` block omits `tel`/`mailto`/`https`.** Five
   `canLaunchUrl` sites take their failure branch on API 30+; `staff_otp_verification_screen.dart:355`
   has no `else` and is a silently dead "Call Support" button.
4. **PLAT-2.01 — iPad and landscape declared, not implemented, not tested.** Universal
   binary + all-four-orientation plist + zero breakpoints + zero landscape/tablet tests.
   Store-rejection risk under Guideline 2.4.1.
5. **PLAT-6.03 — no Android backup rules; patient order/assessment history auto-backs-up.**
   No `res/xml/`, no `allowBackup`/`dataExtractionRules` declaration.
6. **PLAT-8.01 — no release artifact is built by any automation.** CI is `ubuntu-latest`,
   analyze + test only.
7. **PLAT-8.02 — `SCHEDULE_EXACT_ALARM` declared but never used** (both schedule calls are
   `inexactAllowWhileIdle`); no app privacy manifest; no `ITSAppUsesNonExemptEncryption`.
8. **PLAT-8.03 — no dSYM upload phase**; iOS production crashes will be unsymbolicated.
   Carried unchanged from round 3.
9. **PLAT-1.01 / 1.02 / 1.04** — no support matrix, no oldest-supported or low-end coverage,
   no OS-lifecycle plan.
10. **PLAT-2.03 / 4.01** — no state restoration and one app-wide lifecycle observer; an OS
    kill drops the user at the splash screen with cart and booking state lost.
11. **PLAT-5.02** — no permission-state handling and no "Open Settings" path anywhere.

**Cheapest high-value fixes**, for sequencing: deleting `SCHEDULE_EXACT_ALARM` (one line,
removes a Play-review risk), adding the three `<queries>` intents (≈12 lines, restores
`tel:`/`mailto:`/`https:` on Android), and setting `TARGETED_DEVICE_FAMILY = "1"` plus a
portrait `setPreferredOrientations` (two edits, converts blocker 4 from "build an iPad app"
to "stop claiming one") together close three release blockers for well under a day.

## Warnings requiring risk acceptance

Each requires impact, mitigation, owner, ticket, due date, and approver per the suite's
Warning rule. All are listed inline in the control table above with impact and mitigation
recorded; **owner is `OWNER-TBD` for every one** — the repository contains no CODEOWNERS
file, no ticket-tracker references, and no assignee metadata, so the owner is genuinely not
knowable from source. Summarised: PLAT-1.03 (undeclared web target), PLAT-2.02 (Dynamic
Island widths untested; demo-overlay occlusion still open), PLAT-3.01 (iPad input modes),
PLAT-3.02 (predictive back unconfigured), PLAT-3.03 (no `autofillHints`, incl. OTP),
PLAT-3.04 (1.4× text clamp), PLAT-4.02 (no audio-interruption handling), PLAT-4.03 (no
low-storage/thermal handling; 4 `BackdropFilter` surfaces/frame), PLAT-4.04 (offset-matching
timezone fallback), PLAT-5.01 (notification permission requested pre-`runApp` and result
discarded), PLAT-5.03 (stale authorization undetectable), PLAT-5.04 (permission revocation
on resume), PLAT-6.02 (FCM token not cleared on logout/patient switch), PLAT-6.04
(`StoreMigrator` failures unlogged), PLAT-7.03 (role-gated export unasserted), PLAT-7.04 (no
task-switcher snapshot protection on health screens), PLAT-8.04 (no platform-defect entries
in `KNOWN_ISSUES.md`).

## BLOCKED-OWNER — needs access I do not have

1. **Xcode / iOS SDK version used to build the shipping artifact.** Apple's built-with-current-SDK
   requirement (PLAT-8.01, PLAT-8.02) cannot be evidenced from source: the repo records no
   Xcode version, CI never builds iOS, and `flutter --version` reports only the Flutter
   toolchain (3.41.2 / Dart 3.11.0, engine revision `d96704abcce`). Needs the build machine
   or an App Store Connect upload record. **Not N/A — unverified.**
2. **Live device/OS distribution and crash-free rate.** PLAT-1.02 (representative low-end
   and oldest-supported selection "based on risk") and PLAT-8.03 (regression comparison
   across the matrix) both require real installed-base data. Needs App Store Connect /
   Play Console / Firebase Crashlytics access. **Not N/A — unverified.**

## Limitations of this audit

- **MASTER-4.04: this is a SOURCE review.** Evidence should come from the release artifact
  in a production-like environment; I audited files at commit `9127713`. No `.ipa`, `.aab`,
  or `.apk` was produced or inspected, and no build was run — per the audit brief I did not
  invoke `flutter build`, `flutter test`, `flutter clean`, or `pod install`, because
  concurrent agents share this working tree. `flutter analyze` **clean**, design gate
  **passes**, and **1,819 tests across 101 files pass** are cited from the central results
  the brief supplies, not re-run by me. Read-only commands I did run and whose output backs
  claims above: `flutter --version`, `flutter pub outdated`, `grep`/`find`/`plutil`, and a
  Python parse of `ios/Pods/Pods.xcodeproj/project.pbxproj`.
- **No device or simulator was used.** Every claim about *runtime* behaviour — iPad layout,
  landscape rendering, `canLaunchUrl` returning false on API 30+, the notification prompt
  firing on a blank screen, the task-switcher snapshot — is derived from configuration plus
  documented platform and plugin behaviour (notably `url_launcher` 6.3.2's README, quoted
  with line numbers) and is labelled **unverified** rather than observed. Several would flip
  to Pass on a single device pass; none would flip on argument alone.
- **Console-side configuration is invisible to me.** Firebase Console (whether an Android
  app for `com.housepital.housepital_patient` exists alongside the `com.housepital.patient`
  one, APNs key upload state, API-key restrictions), App Store Connect (Xcode version,
  capabilities, export compliance), and Play Console (signing enrolment, the
  `SCHEDULE_EXACT_ALARM` declaration) could each change a Fail above. Where that is the
  case I have said so rather than assumed the worst.
- **Scope boundaries.** Notification *content* and routing correctness belong to another
  module; I graded only whether notifications can be *delivered*. Contrast ratios,
  Dynamic-Type rendering, the demo-data build, backend schema incompatibility, and the
  owner-accepted decisions (white on orange, manpower pricing, the pill nav) are out of
  scope here and are treated as given, not re-litigated.
- **`ios/Pods/` is a build product, not source.** Its deployment targets reflect the last
  local `pod install` (CocoaPods 1.16.2) and would be regenerated on a clean build; the pod
  enumeration in PLAT-8.01 should be re-taken after any dependency change.
