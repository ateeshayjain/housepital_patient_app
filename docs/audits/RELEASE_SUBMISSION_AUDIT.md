# Release & App Store Submission Checklist — Audit round 2 vs commit `820060b`

**Date:** 2026-08-03 · **Previous round:** commit `803124d` · **Branch:** `fix/five-tab-nav`
**Scope:** iOS App Store submission. The app has still **never been uploaded to App Store Connect**;
it installs to the owner's iPhone via a locally signed Release `xcodebuild`. Graded against
"shippable to the App Store", not "installs on my phone".

**Commands actually run this round (output cited inline):**
`sips` over all 15 appicon PNGs + the 3 launch images · `file` on the launch images ·
`nslookup api.housepital.in` · `curl -L https://housepital.in/privacy` and the `www.` form ·
`find ios -name "*.entitlements"` · `grep -c` over `Info.plist` and `project.pbxproj` ·
`git tag` · `git log d89c0b8..HEAD` · `base64 -d` over `DART_DEFINES` · `du -sh assets/`
**Not run** (per brief): `flutter test`, `flutter build`, `flutter clean`, `pod install`.
Cited central results: `flutter analyze` clean · design gate passes · 1,797 tests pass.

**Item count note:** round 1 printed a 43-item total while listing 45 graded items (§5 carried six
bullets against a scorecard row of four; §6 carried five). This round grades and counts all **45**.

---

## Changed since round 1

| Round-1 finding | Status now | Evidence |
|---|---|---|
| **B1** App icon is the stock Flutter logo (all 15) | **⚠️ Partially fixed** — now the Housepital mark, alpha-free, all 15 sizes correct; **but it is a ~3.6× raster upscale and visibly soft** | `sips` on all 15 → correct px, `hasAlpha: no`, sRGB; rendered `Icon-App-1024x1024@1x.png` + a 320 px native crop — see §6 |
| **B2** `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` missing | **✅ Fixed** | `ios/Runner/Info.plist:73-76`; both strings name real, specific uses |
| **B3** Demo patient seeds on every fresh install | **❌ Not fixed** — addressed with a banner, not a gate. Seed is unchanged and unconditional | `lib/providers/app_provider.dart:215` calls `_seedDemoDataIfEmpty()`; `:257-270` unchanged; `:137-138` seeds "Rajesh Kumar" **without** marking demo mode |
| **B4** No in-app account deletion (5.1.1(v)) | **⚠️ Partially fixed** — screen exists and is reachable, but **transmits nothing and does not delete the Firebase Auth user** | `lib/screens/settings/delete_account_screen.dart:53-89`; `lib/providers/auth_provider.dart:217-224` → `signOut()` only |
| **B5** Privacy/Terms links fail TLS on the apex domain | **❌ Unchanged** | `curl -L https://housepital.in/privacy` → exit **60**, HTTP `000`; `www.` → `200`. Four links still apex: `about_screen.dart:98,104,110`, `referral_screen.dart:121` |
| **B6** `api.housepital.in` NXDOMAIN | **❌ Unchanged** | `nslookup` → `** server can't find api.housepital.in: NXDOMAIN` |
| **B7** Placeholder Razorpay key → simulated success | **⚠️ Materially improved** — the *unverified-payment-reported-as-success* bug is genuinely fixed (fail-closed with a real key); the recorded build still carries no key | `payment_service.dart:161-181`; `Generated.xcconfig` `DART_DEFINES` decodes to Flutter metadata only — **no `RAZORPAY_KEY`**, so `constants.dart:24` falls back to `rzp_test_XXXXXXXXXX` → `isDemoPayments == true` |
| **B8** `ITSAppUsesNonExemptEncryption` missing | **❌ Unchanged** | `grep -c ITSAppUsesNonExemptEncryption ios/Runner/Info.plist` → `0` |
| **B9** No medical disclaimer in the UI | **❌ Unchanged** | Same grep as round 1 returns **exactly one hit**, still inside a demo article body (`lib/data/demo_articles.dart:192`) |
| **H10** No `.entitlements` → Push dead | **❌ Unchanged** | `find ios -name "*.entitlements"` → empty; `grep -c UIBackgroundModes Info.plist` → `0` |
| **H11** No Crashlytics dSYM upload phase | **❌ Unchanged** | `grep -cE "crashlytics\|upload-symbols\|dSYM" project.pbxproj` → `0` (the two `DEBUG_INFORMATION_FORMAT` lines are the only related hits, at `:472`, `:653`) |
| **H12** No remote-config kill switch | **❌ Unchanged** | grep over `lib/` + `pubspec.yaml` for `remoteconfig\|feature_flag\|killSwitch\|force_upgrade` → **no matches** |
| **H13** iPad declared + landscape unlocked, untested | **❌ Unchanged** | `project.pbxproj:488,618,671` → `TARGETED_DEVICE_FAMILY = "1,2"`; `Info.plist:56-68` still lists both landscape orientations; no `SystemChrome.setPreferredOrientations` in `lib/`; `test/` still has zero iPad/landscape coverage (`overflow_smoke_test.dart:102-104` = 320/375/414 only) |
| **H14** Android release signs with debug keys | **❌ Unchanged** | `android/app/build.gradle.kts:34-38` |
| **H15** Placeholder support number | **❌ Unchanged — and there are two, not one** | `help_faq_screen.dart:352` (`tel:+919999999999`) **and** `:365` (`wa.me/919999999999`), while `constants.dart:17,19` hold the real `9990911911` |
| **H16** Firestore rules + key restrictions undeployed | **❌ Unchanged, scope grew** | `docs/KNOWN_ISSUES.md:25` BUG-33 "deployment to console pending", `:26` BUG-34 "Open"; **new** `storage.rules` is also undeployed by the author's own header |
| **M23** Stale `FLUTTER_APPLICATION_PATH` | **✅ Fixed** (regenerated) | `ios/Flutter/Generated.xcconfig` now reads `…/WIPApps/Housepital/housepital_patient_app` |
| **M24** Launch screen is a 1×1 transparent PNG | **✅ Fixed** | `file` → `282 x 360, RGBA` at @3x; renders as a crisp Housepital mark. Storyboard background is still white while the Flutter splash is orange (`splash_screen.dart:24`) — a colour step, no longer a blank screen |
| **M17** `debugPrint` calls shipping in release | **⚠️ Unchanged — and round 1 undercounted it** | `grep -rn debugPrint lib/ \| wc -l` → **34** (3 of them are the logger's own sink in `logger.dart`, so **31 bypass `Log`**). `git grep -c debugPrint 803124d -- lib/` → **34** as well, so this did **not** regress; round 1's "28" was simply wrong |
| **M21** CHANGELOG behind HEAD | **❌ Worse** — was 5 commits behind, now **9** | newest entry `docs/CHANGELOG.md:7` `[2026-06-13]` = commit `d89c0b8`; `git log --oneline d89c0b8..HEAD \| wc -l` → **9** |
| **§11 KNOWN_ISSUES ✅** | **⚠️ Downgraded** | `docs/KNOWN_ISSUES.md:5` still "Last updated: **2026-05-28**". Two full audit rounds have produced ~50 findings and **none** are recorded; BUG-34 still instructs restricting a package (`in.housepital.patient`) that does not exist |

**New in round 2 (not present or not found in round 1):** the handover PDF is generated entirely
from `DemoData` (§ App Review risks), `LSApplicationQueriesSchemes` is absent while `canLaunchUrl`
gates the SOS dial path (§4), the sample-data banner double-counts the top safe-area inset on two
tabs (§9), and four docs still assert six bottom tabs (§11).

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Version & build | 0 | 2 | 1 | 0 |
| 2. Flags & configuration | 0 | 2 | 2 | 0 |
| 3. Backend / services prod-ready | 0 | 0 | 4 | 0 |
| 4. Build provenance & signing | 0 | 1 | 2 | 0 |
| 5. Privacy & compliance | 1 | 1 | 4 | 0 |
| 6. Listing / launch assets | 0 | 1 | 3 | 1 |
| 7. Reviewer / stakeholder notes | 0 | 0 | 3 | 0 |
| 8. Build & package | 0 | 2 | 0 | 0 |
| 9. Pre-ship QA | 1 | 3 | 0 | 0 |
| 10. Staged rollout | 0 | 1 | 2 | 0 |
| 11. Submit / deploy & record | 0 | 1 | 3 | 0 |
| 12. Rollback / hotfix plan | 1 | 2 | 1 | 0 |
| **TOTAL (45 items)** | **3** | **16** | **25** | **1** |

Round 1 (recounted on the same 45-item basis): **3 ✅ · 14 ⚠️ · 27 ❌ · 1 N/A**.
Net movement: **two ❌ → ⚠️/✅** (permission strings to ✅, account deletion to ⚠️),
**one ✅ → ⚠️** (KNOWN_ISSUES), **one ❌ → ⚠️** (app icon).

**One-glance gate:** tests ✅ (1,797 pass centrally) · no QA flag on ⚠️ ·
prod backend ready ❌ (still NXDOMAIN) · privacy URL + disclosure ❌ (apex still fails TLS) ·
build id bumped ⚠️ (still `1.0.0+1`) · clean-install QA ❌ (fresh install still shows a fabricated
patient) → **DO NOT SHIP.**

---

## Verification of the three claimed fixes

### (a) The app icon — ⚠️ ships, but not at submission quality

**What is objectively correct.** All 15 PNGs are present, every one is the exact required pixel
size (20/29/40/60/76/83.5 at their scales, plus 1024), every one reports `hasAlpha: no` and
`space: RGB`, and `Contents.json` maps all 19 slots with no missing filenames. **An icon with an
alpha channel is rejected at upload by App Store Connect (ERROR ITMS-90717); this one will pass.**
The mark itself is correct and on-brand — the Housepital "O" with the nurse cap, `#F39314`-family
orange on white — and it is no longer the Flutter logo. That part of the blocker is genuinely gone.

**Why I would still not submit it.** Being blunt, as asked: it is a low-resolution raster blown up
and it looks like one. The commit message says so itself (`820060b`: *"sourced from a 143x182
raster, so it is soft at 1024 — replace with the designer's vector before submission"*), and the
rendering confirms it. Cropping a 320×320 region of the 1024 at native resolution shows the
nurse-cap cross with rounded, mushy corners and an anti-alias ramp several pixels wide on every
edge — that is a ~3.6× upscale of a ~143×182 source, and the 1024 icon is the single largest,
most-scrutinised asset in the whole submission. It is what appears at full size on the App Store
product page.

Two secondary defects, both visible in the render:
- **The mark occupies roughly 50 % of the canvas width.** After iOS applies its squircle mask, the
  glyph reads noticeably small and lost in white space next to neighbouring icons. Typical
  single-glyph marks fill 70–80 %.
- **The source is a wordmark, not an icon.** `assets/images/housepital_logo.png` is 1200×312 with
  alpha — the "O" was cropped out of lettering that was never drawn to stand alone.

Apple will not reject on softness alone in most cases, but 4.0 (Design) and the "crisp, high-quality
artwork" requirement in the HIG give a reviewer standing to, and a 1024 this soft is a visible
quality signal on a first submission. Treat it as *unblocked but not done*.
**Fix:** re-export all 15 from the designer's vector (SVG/AI/PDF) at each target size — not by
resampling one PNG — and scale the mark to ~72 % of the canvas.

### (b) The usage strings — ✅ compliant, and nothing else is undeclared

`ios/Runner/Info.plist:73-76`:

- `NSCameraUsageDescription` → *"Housepital uses the camera so you can photograph prescriptions,
  lab reports and anything you need to show your care team."*
- `NSPhotoLibraryUsageDescription` → *"Housepital needs access to your photos so you can attach
  existing reports, prescriptions or a profile picture."*

**Are they specific enough for review?** Yes. App Review rejects purpose strings that are absent,
generic ("This app needs camera access"), or that do not match observable behaviour. These name the
concrete artefacts the user will actually photograph and attach, and they match all six call sites
(`settings_screen.dart:55,60`, `patient_profile_screen.dart:190,195`, `return_screen.dart:316`,
`chat_screen.dart:122`, `raise_concern_screen.dart:77,85`, `document_repository_screen.dart:614,632`).
The one omission is the equipment-return photo (`return_screen.dart:316`), which the camera string's
"anything you need to show your care team" covers loosely enough.

**Is any other permission still undeclared while used?** I checked every permission-gated iOS API
against the dependency list. The answer is **no** — with one adjacent defect that is not a usage
string and is graded in §4 instead:

| Permission | Used? | Declared? |
|---|---|---|
| Camera / Photo library | yes, 6 screens | ✅ now |
| Microphone / Speech recognition | `speech_to_text` | ✅ `Info.plist:69-72` |
| Photo library **add** (`NSPhotoLibraryAddUsageDescription`) | no — `Printing.sharePdf` / `SharePlus` hand off to the system share sheet, which saves under its own entitlement | N/A |
| Location | no `geolocator`/`permission_handler` anywhere in `lib/` | N/A |
| Contacts | "emergency contacts" are app-model fields, not `Contacts` framework | N/A |
| Calendar, Bluetooth, Face ID, Tracking/IDFA | not used | N/A |
| Notifications | `firebase_messaging` + `flutter_local_notifications` — runtime prompt, no plist key exists | N/A (but see the missing **entitlement** in §4) |

### (c) `/delete-account` and Guideline 5.1.1(v) — ⚠️ does not yet satisfy it

**Does Apple accept request-based deletion?** Sometimes, under narrow conditions. The rule since
June 2022 is that an app offering account creation must offer account **deletion initiated from
inside the app**. Apple's stated carve-out: apps in *highly regulated industries* (Apple's own
examples are banking and healthcare) that are legally required to perform additional identity
verification *may* provide an in-app flow that hands off to a support channel, provided the deletion
path is easy to find, is initiated in-app, and the app also explains what will happen. What Apple
explicitly does **not** accept is "email support to delete your account" — which is exactly what
`help_faq_screen.dart:156` still says, and which is now merely duplicated rather than replaced.

Housepital could plausibly stand on that carve-out. This implementation does not get there, for
three reasons that are all in the code:

1. **No request is ever made.** `_submitDeletionRequest()`
   (`delete_account_screen.dart:53-59`) is `await Future<void>.delayed(const Duration(milliseconds: 600))`
   and a `TODO(backend)`. Nothing is POSTed, nothing is written to Firestore, nothing is queued
   locally for retry, no email is composed. The 600 ms is a spinner.
2. **The success dialog then asserts something untrue.** Lines 74-78 tell the user *"Your Housepital
   records are scheduled for deletion and will be removed within 30 days."* No record of the request
   exists anywhere, on device or on any server, the instant that dialog is dismissed. A missing
   feature is a 5.1.1(v) rejection; a feature that tells the user their medical records are
   scheduled for erasure when nothing was scheduled is a **2.3.1** misrepresentation *and* a false
   DPDP 2023 §12 compliance claim. The file's own doc comment (lines 17-24) argues for honesty about
   what the screen can do — the dialog copy does not live up to it.
3. **The account itself is not deleted.** The flow calls `SessionScope.clearSession(context)` then
   `AuthProvider.logout()` (`:64-65`), and `logout()` reaches `FirebaseService.signOut()` →
   `auth.signOut()` (`firebase_service.dart:97-99`). `FirebaseAuth.currentUser.delete()` is never
   called anywhere in `lib/`. A reviewer who deletes and then signs back in with the same phone
   number lands in the same account. That is the specific test reviewers run, and it fails.

Everything *around* the flow is good and should be kept: it is reachable in two taps
(`settings_screen.dart:278` → `main.dart:745`), it uses type-`DELETE` plus a checkbox plus a
destructive dialog, it separates "what gets deleted" from "what we must keep (tax invoices)", and it
gives a real callback number. The gap is that it is a well-designed front end over a no-op.

**Fix, in the order that makes it compliant:** (1) call `FirebaseAuth.currentUser.delete()` with
re-auth-on-`requires-recent-login`, so the credential is actually destroyed even with no backend;
(2) persist the request (Firestore `deletion_requests/{uid}` works today and needs no new
infrastructure) and surface the resulting ID in the dialog; (3) until (2) exists, change the copy to
state only what happened — the device was wiped and sign-in destroyed — and drop the 30-day
promise; (4) delete the "email us" paragraph at `help_faq_screen.dart:156` or repoint it at this
screen, so there is one deletion story.

---

## The demo-data blocker: does the banner save it?

**No. A demo-data build is still a rejection, and the banner narrows the blast radius rather than
removing it.**

**What actually ships on a fresh install.** `home_screen.dart:59-60` calls `loadPatients()` then
`loadDashboard()`. `app_provider.dart:136-140` unconditionally sets the current patient to
`DemoData.patient` — `demo_data.dart:28-68`: **Rajesh Kumar, 72, male**, post-stroke / hypertension
/ type-2 diabetes, five named prescriptions including *Insulin Glargine 10 units at bedtime*, sulfa
allergy, "Bed-ridden", low-sodium diabetic diet, Dr. Ananya Sharma at Fortis with a phone number,
daughter Priya on `9876543210`, and the address `B-42, Sector 15, Noida 201301`.
`loadDashboard()` then calls `_seedDemoDataIfEmpty()` (`:215`, `:257-270`), still unconditional and
still before any API attempt, installing the deployment, attendance, vitals, daily report and a
billing balance. **No `bool.fromEnvironment` gate exists anywhere in `lib/`** (grep → no matches).
The code is byte-for-byte the code round 1 graded ❌; only a caption was added beside it.

**What the banner does and does not cover.** `DemoMode` (`lib/data/demo_mode.dart`) is a global
`ValueNotifier`; `main_shell.dart:132-170` renders a persistent, non-dismissible warning strip above
the tab content. It is well built — not a snackbar, not dismissible, honest wording, high contrast.
But it lives in **one widget, in `MainShell`'s `Column`**, so it covers exactly the five root tabs
and nothing else. Every pushed route renders full-screen above it. Concretely, all of these show
fabricated clinical data with **no** banner in view:

`/care-calendar`, `/vitals`, `/report-detail`, `/report-history`, `/medications`,
`/medication-schedule`, `/care-team`, `/patient-profile`, `/documents`, `/invoice-detail`,
`/attendance-history`, `/staff-profile`.

**Five demo sources never set the flag at all.** The brief asked whether every fallback path marks
demo mode. Five do (`my_care_provider.dart:50,98`, `medication_provider.dart:191,236`,
`billing_provider.dart:43`, `orders_provider.dart:199`, `app_provider.dart:260`). These do not:

| Site | What it serves | Marked? |
|---|---|---|
| `app_provider.dart:137-138` | **the patient's identity itself** — name, age, conditions, allergies, address, doctor | ❌ no |
| `patient_profile_screen.dart:898` | `DemoData.medicalHistory` — hardcoded, not even a fallback | ❌ no |
| `care_team_screen.dart:29,31,162-164` | supervisor + past staff — hardcoded | ❌ no |
| `models/care_event.dart:57,71,97,105,106,118` | the **entire care calendar** — medications, adherence %, deployments, appointments — hardcoded | ❌ no |
| `care_calendar_screen.dart:1324` | staff on duty — hardcoded | ❌ no |
| `blog_provider.dart:38,68` | articles (content, low risk) | ❌ no |

So a reviewer who fails the network can still reach `/care-team` or `/care-calendar` after live data
arrives and `DemoMode.reset()` fires (`app_provider.dart:247`), and see invented clinical content
with the banner explicitly *down*.

**The worst instance: the doctor handover PDF.** `handover_report_service.dart:101-108` builds the
entire report from `DemoData` — patient, medical history, active medications, the full vitals
series, today's report, services, staff on duty and appointments — with a hardcoded assignment, not
a fallback (its own comment at `:95-96` admits "All data comes from the demo layer today"). It is
rendered under the Housepital logo with a "Housepital Doctor Handover Report" footer
(`:121-143`) and shared via `Printing.sharePdf` (`:305`), filename derived from
`DemoData.patient.name` (`:287`). There is **no** "SAMPLE" watermark and **no** banner — a PDF
cannot carry one. This is a fabricated clinical document, branded as genuine, that the app
encourages the user to hand to a real doctor.

**Against the guidelines, as asked.**

- **2.1 (App Completeness).** Apple's language is that apps submitted with "placeholder content" or
  that "are not final" are rejected. A banner reading *"Showing sample data — we can't reach
  Housepital right now"* does not make the content final; it **confirms in writing, on the first
  screen, that the reviewer is looking at placeholder content and that the backend is unreachable.**
  It is, if anything, a stronger 2.1 signal than the silent version was. 2.1 is not a
  disclosure requirement that a label satisfies — it is a completeness requirement.
- **2.3.1 (Accurate Metadata / hidden or non-final functionality).** Improved but not cleared. The
  banner does defeat the *deception* reading for the five tabs it covers. It does nothing for the
  twelve pushed routes, the five unmarked sources, or the handover PDF.
- **1.4.1 (Physical Harm).** Materially improved on the tabs — a family member glancing at Home no
  longer reads sample vitals as their own — and **not improved at all** where it matters most.
  `/vitals` renders `DemoData.vitalsHistory` colour-coded by `vital_classifier.dart:5-14`
  (SpO₂ < 92 → red, systolic ≥ 140 → red) with no banner above it and, per §9, still no medical
  disclaimer anywhere in the app. The handover PDF is a 1.4.1 exhibit on its own.

**Verdict: still a blocker.** The banner is a real safety improvement and should stay — it is the
right thing to show a real user when the backend is genuinely down. It is not a substitute for the
fix. Ship this and the most likely outcome is a 2.1 rejection whose reviewer note quotes your own
banner text back at you.

**Fix:** gate the seed behind `const bool.fromEnvironment('DEMO_DATA')` defaulting to `false`, build
honest empty states for a signed-in user with no care plan, move the five unmarked sources behind
the same gate, and either drive the handover PDF from `AppProvider`/`MedicationProvider` or watermark
it `SAMPLE — NOT A CLINICAL RECORD` whenever `DemoMode.isServingDemoData` is true. Keep the banner
for genuine offline.

---

## Findings

### 1. Version & build

- ⚠️ **Version bumped** — `pubspec.yaml:4` → `version: 1.0.0+1`, unchanged since round 1 across nine
  commits. Correct value for a first release; still no process behind it.
- ⚠️ **Build/release identifier incremented** — `ios/Flutter/Generated.xcconfig` →
  `FLUTTER_BUILD_NUMBER=1`. No CI step, no tag, nothing increments it.
  **Fix:** `flutter build ipa --build-number=$(date +%Y%m%d%H%M)`.
- ❌ **Version strings consistent across all manifests/configs** — unchanged. Three independent
  hardcodings: `pubspec.yaml:4`, `lib/screens/settings/about_screen.dart:11`
  (`static const _appVersion = '1.0.0'`), `lib/screens/settings/settings_screen.dart:258`
  (`subtitle: 'Housepital v1.0.0'` — note the line moved from 257 to 258 when the delete-account row
  was inserted, which is itself a demonstration of the drift risk). Three app identifiers still
  disagree: iOS `com.housepital.housepitalPatient` (`project.pbxproj:507,690,713`), Android
  `com.housepital.housepital_patient` (`android/app/build.gradle.kts:24`), and
  `in.housepital.patient` in `docs/KNOWN_ISSUES.md:26`.
  **Impact:** the About screen will lie from v1.0.1; the BUG-34 Firebase key restriction, applied as
  written, protects a package that does not exist. **Fix:** `package_info_plus` in both screens;
  correct BUG-34 to the real `applicationId` before touching the console.

### 2. Flags & configuration

- ⚠️ **No QA/debug flag left enabled** — unchanged. No debug menu or dev panel exists. The two
  `kDebugMode` guards are still inverted correctly (`lib/main.dart` production-only Crashlytics
  enable; debug-only `FlutterError.presentError`). ⚠️ carries the `debugPrint` finding below and the
  total absence of a flag layer (§12).
- ❌ **Demo/seed/sample-data mode is off by default** — **unchanged in substance.** Full analysis in
  the dedicated section above. Evidence: `app_provider.dart:136-140`, `:215`, `:257-270`; no
  `bool.fromEnvironment` gate in `lib/`.
- ❌ **Build points at production endpoints/keys** — unchanged and re-verified.
  `lib/config/constants.dart:3` → `https://api.housepital.in/v1`; `nslookup` → **NXDOMAIN**.
  `Generated.xcconfig`'s `DART_DEFINES` now decodes to **six Flutter metadata entries and nothing
  else** — the `RAZORPAY_KEY=rzp_test_dummy` that round 1 found is gone, so `constants.dart:22-26`
  falls back to `rzp_test_XXXXXXXXXX`, which is in `_placeholderKeys`
  (`payment_service.dart:45-48`) → `isDemoPayments == true` → `openCheckout` simulates
  (`payment_service.dart:107-117`). Net: still a demo-payments build.
- ⚠️ **Logging level appropriate for production** — unchanged; round 1's count was wrong.
  `lib/utils/logger.dart:55` correctly drops `debug`/`info` under `kReleaseMode`, but **34**
  `debugPrint` calls exist in `lib/` (3 of them inside the logger's own sink, so **31 bypass `Log`**),
  concentrated in `assistant_executor.dart` (7), `voice_service.dart` (4), `assistant_service.dart`
  (3), `cart_provider.dart` (2), `blog_provider.dart` (2), `main.dart` (2) and 11 screens.
  `debugPrint` is not stripped in release. `git grep -c debugPrint 803124d -- lib/` also returns 34,
  so this did **not** regress — round 1 simply reported 28.

### 3. Backend / services prod-ready

- ❌ **Database/schema migration deployed to production** — **BLOCKED-OWNER**, unchanged. No
  production deployment exists to have been migrated (host is NXDOMAIN).
- ❌ **Prod credentials/keys in place and rotated** — unchanged, and the undeployed surface grew.
  Razorpay is a placeholder. `docs/KNOWN_ISSUES.md:25` BUG-33 (Firestore rules) still "deployment to
  console pending"; `:26` BUG-34 (API-key restrictions) still "Open". **New this round:**
  `storage.rules` is a genuinely good artefact — default-deny, per-patient `chat/` and `concerns/`
  prefixes, signed-in + owner check, image-only, 10 MB cap, and an honest note that the
  `uid == patientId` assumption breaks family sharing (`storage.rules:44-53`) — but its own header
  (`:7-14`) says it must be deployed, and `firebase.json:6-8` only wires the file. **Live posture
  remains unknown.** Until `firebase deploy --only storage` runs, chat photos and concern-evidence
  photos are governed by whatever the console holds.
- ❌ **Infra/scaling/quota headroom** — **BLOCKED-OWNER**, unchanged. Nothing deployed to measure.
- ❌ **Trap: client pointing at prod while only a dev endpoint exists** — unchanged, in its worst
  form: the client points at a hostname that does not resolve, and
  `app_provider.dart:250-254` catches, logs and leaves demo data in place. The round-2 banner is
  the first thing that makes this failure visible to a human, which is progress on *observability*
  and none on the underlying gap.

### 4. Build provenance & signing

- ❌ **Release build signed with production credentials** — unchanged.
  `project.pbxproj:470` (project-level Debug), `:594`, `:651` (Release) all →
  `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer"` — a development identity.
  `DEVELOPMENT_TEAM = 3M5BRKQ345` is set on Runner (`:500,683,706`); `CODE_SIGN_STYLE` is declared
  only for `RunnerTests` (`:520,538,554`), so Runner inherits automatic signing and Xcode will
  *probably* substitute a distribution cert on archive — a path never exercised.
  Android is unambiguously broken: `android/app/build.gradle.kts:34-38` →
  `signingConfig = signingConfigs.getByName("debug")` under the template TODO.
- ❌ **Capabilities/entitlements/permissions match what's used and target prod** — unchanged, and
  worse than round 1 recorded. `find ios -name "*.entitlements"` → **empty**. `firebase_messaging`
  is a dependency (`pubspec.yaml:26`), `firebase_service.dart` calls `requestPermission` and
  `getToken`, `main.dart` wires `onMessageOpenedApp`, and `grep -c UIBackgroundModes Info.plist`
  → `0`. No `aps-environment` entitlement will be produced; **remote push cannot work in
  production.**
  **New finding — `LSApplicationQueriesSchemes` is absent (`grep -c` → `0`) while eight sites gate a
  `tel:` launch on `canLaunchUrl`.** `url_launcher`'s documented iOS requirement is that any scheme
  other than `http`/`https` must be listed in `LSApplicationQueriesSchemes` for `canLaunchUrl` to
  return true, because it is a direct `-[UIApplication canOpenURL:]` call. Affected:
  `lib/screens/sos/sos_screen.dart:248-251` (**the emergency dial path** — CLAUDE.md's "SOS is never
  blocked" rule), `lib/screens/assistant/assistant_screen.dart:37-40`,
  `lib/screens/settings/help_faq_screen.dart:406-410` (`tel:` and `mailto:`),
  `lib/screens/my_care/staff_otp_verification_screen.dart:352-353`,
  `lib/screens/billing/payment_methods_screen.dart:363`. Sites that call `launchUrl` **without** the
  gate — `home_screen.dart:242,821,1875`, `care_team_screen.dart:286,381`,
  `health_manager_banner.dart:71`, `article_detail_screen.dart:305` — are unaffected, which is why
  this can hide: half the call button in the app works and half falls back to an error.
  SOS degrades gracefully (`sos_screen.dart:258-275` shows a "Could not auto-dial" dialog with
  copy-to-clipboard) rather than failing silently — good defensive work — but the emergency call
  still would not place itself.
  **I could not confirm this on a device** (no build/run permitted this round); it is a two-minute
  check and it is graded on the documented plugin contract.
  **Fix:** add Push Notifications in Xcode → Signing & Capabilities; add
  `UIBackgroundModes = [remote-notification]`; add
  `<key>LSApplicationQueriesSchemes</key><array><string>tel</string><string>mailto</string><string>sms</string><string>whatsapp</string></array>`;
  upload the APNs `.p8` to Firebase.
- ⚠️ **Source map / debug symbols archived** — unchanged. dSYMs are generated
  (`project.pbxproj:653` → `DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"` on Release) but
  `grep -cE "crashlytics|upload-symbols|dSYM"` over the whole `project.pbxproj` → **0**: there is
  still no Crashlytics `upload-symbols` run-script phase, and `DART_OBFUSCATION=false` with no
  `--split-debug-info`. Crashlytics is enabled in release and every crash will arrive
  unsymbolicated.

### 5. Privacy & compliance

- ❌ **Privacy policy URL live and linked in the store/site + in-app** — unchanged, re-verified
  today. `curl -L https://housepital.in/privacy` → **exit 60 (SSL certificate problem)**, HTTP
  `000`; `curl -L https://www.housepital.in/privacy` → **200**. Four hardcoded apex links remain:
  `about_screen.dart:98` (terms), `:104` (privacy), `:110` (website),
  `referral_screen.dart:121` (`https://housepital.in/app`, shared to friends). Note
  `constants.dart:20` already stores `website = 'www.housepital.in'` — the correct string is
  already in the codebase and simply is not used by these four call sites.
  **Fix:** four one-word edits, plus fix the apex→www redirect or the cert SAN server-side.
- ❌ **Store/site data-disclosure submitted and accurate** — **BLOCKED-OWNER**, never submitted.
  Category list in the BLOCKED-OWNER section.
- ❌ **Export-compliance / encryption questions answered** — unchanged.
  `grep -c ITSAppUsesNonExemptEncryption ios/Runner/Info.plist` → **0**. Every upload will stall in
  "Missing Compliance", blocking TestFlight each time.
  **Fix:** `<key>ITSAppUsesNonExemptEncryption</key><false/>`.
- ❌ **Age rating / content rating set; correct category** — **BLOCKED-OWNER**, unchanged.
- ✅ **(App-specific) Required permission usage strings** — **FIXED.** `Info.plist:73-76`; full
  analysis above, including the audit showing no other permission is used-but-undeclared.
- ⚠️ **(App-specific) In-app account deletion — 5.1.1(v)** — **partially fixed.** Screen, route and
  Settings entry exist and the UX is right; the flow transmits nothing
  (`delete_account_screen.dart:53-59`), never calls `FirebaseAuth.currentUser.delete()`, and then
  tells the user their records are scheduled for deletion within 30 days (`:74-78`). Full analysis
  above.

### 6. Listing / launch assets

- ❌ **Name, subtitle, description, keywords, support + marketing URLs** — **BLOCKED-OWNER**,
  unchanged. `CFBundleDisplayName` is still `Housepital Patient` (`Info.plist:10`), 18 characters,
  which truncates on the Home Screen; consider `Housepital`.
- ❌ **Screenshots for all required device sizes/locales** — **BLOCKED-OWNER**, and the requirement
  is still wider than it needs to be: `project.pbxproj:488,618,671` →
  `TARGETED_DEVICE_FAMILY = "1,2"` (iPad screenshots mandatory, iPad must actually work) and
  `Info.plist:56-68` still permits both landscape orientations on iPhone with no
  `SystemChrome.setPreferredOrientations` anywhere in `lib/`. Test coverage is still iPhone-portrait
  only (`test/screens/overflow_smoke_test.dart:102-104` → 320×568 / 375×667 / 414×896); a grep of
  `test/` for iPad or landscape returns nothing.
  **Fix (recommended):** `TARGETED_DEVICE_FAMILY = "1"` and portrait lock. This is a one-hand,
  at-the-bedside app; the two-line change removes a whole class of review risk.
- ⚠️ **App icon at required resolutions (no missing-asset warnings)** — **partially fixed.** All 15
  correct sizes, `hasAlpha: no`, complete `Contents.json` — it will pass upload validation and it is
  no longer the Flutter logo. It is a ~3.6× raster upscale, visibly soft at 1024, and fills only
  ~50 % of the canvas. Full analysis above.
  **Launch screen is genuinely fixed:** `LaunchImage@{1,2,3}x.png` are now 94×120 / 188×240 /
  282×360 RGBA renders of the mark (`file` output), replacing the 68-byte 1×1 transparent PNGs.
  Residual: `LaunchScreen.storyboard:22` still sets a **white** background while
  `splash_screen.dart:24` paints `HousepitalColors.orange`, so launch is now white-with-mark →
  orange rather than blank → orange. Cosmetic; set the storyboard background to the brand orange.
- N/A **(Optional) preview video** — not required for a first submission.
- ❌ **"What's New" / release notes written** — **BLOCKED-OWNER**, unchanged. `docs/CHANGELOG.md` is
  date-keyed and engineering-facing.

### 7. Reviewer / stakeholder notes

- ❌ **Instructions explain what the app does** — **BLOCKED-OWNER**, unchanged. Positive to reuse:
  `splash_screen.dart` still routes to `/home` with no auth gate, so a reviewer can browse the
  catalog, cart and content without signing in.
- ❌ **Demo path / account provided if anything is gated** — unchanged. Sign-in is real Firebase
  phone OTP (`firebase_service.dart:58`) with no bypass; checkout, staff OTP verification, chat and
  documents all need an Indian mobile number a reviewer cannot have.
  **Fix:** a Firebase Auth test phone number, quoted in the review notes.
- ❌ **Special setup described** — unchanged. Four-role permission model
  (`lib/utils/permissions.dart`) with role-gated actions including the handover PDF export; a
  reviewer testing roles needs a second account. Nothing documented.

### 8. Build & package

- ⚠️ **Release configuration, no build warnings, no test/debug code shipped** — improved.
  `flutter analyze` clean (central), design gate passes, and the **stale `FLUTTER_APPLICATION_PATH`
  is fixed** — `ios/Flutter/Generated.xcconfig` now correctly reads
  `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`. Still ⚠️ for the 31 `Log`-bypassing
  `debugPrint` calls, several interpolating raw exception objects.
- ⚠️ **Artifact validates clean; bundle size reasonable** — unchanged; never validated, nothing ever
  uploaded. `du -sh assets/` → **81 M**, of which `assets/images/products` → **78 M**. Fine against
  the 4 GB limit; likely over the 200 MB cellular-download threshold once the Flutter engine and
  Firebase frameworks are linked, which means Wi-Fi-only install for many users.
  **Fix:** measure on the first archive; re-encode product photos to ~1000 px / 80 % quality if over.

### 9. Pre-ship QA (clean install / fresh session)

- ⚠️ **Fresh install → onboarding → core flows all work** — **one of the two round-1 defects is
  genuinely gone.** The camera/photo-library hard-termination is fixed (§5): six previously fatal
  taps now work. The other is not: a brand-new user still lands on Rajesh Kumar's fabricated record,
  now captioned.
  **New, introduced by the banner fix:** `main_shell.dart:58-71` puts `_DemoDataBanner` in a `Column`
  above the `IndexedStack`. A sibling `SafeArea` does not consume `MediaQuery.padding.top` for the
  other children, and `MainShell`'s `Scaffold` has no `appBar`, so the tab screens still read the
  full device top inset. `my_care_screen.dart:141` and `billing_screen.dart:173` both compute
  `top: MediaQuery.of(context).padding.top + kToolbarHeight + N`. While the banner is visible —
  i.e. always, in demo mode — those two tabs reserve roughly one extra status-bar height (~47–59 pt)
  of dead space under their glass app bars. Cosmetic, but it lands on two of five tabs in the
  default state, and no widget test asserts the banner's layout (`test/` mentions `DemoMode` only in
  `test/providers/patient_scope_isolation_test.dart:178-187`).
  **Fix:** wrap the banner's sibling in `MediaQuery.removePadding(context, removeTop: true)`, or
  render the banner inside each screen's `Scaffold` rather than above it.
- ⚠️ **Accessibility spot-check** — unchanged. Dark-mode token guard and the 37-screen × 3-width
  overflow guard exist; EN/HI are key-synced. Still **no largest-text (`textScaler`) pass and no
  VoiceOver pass** recorded anywhere, and `grep -c CFBundleLocalizations ios/Runner/Info.plist` →
  **0**, so the store will advertise the app as English-only and hide a complete 321-key Hindi
  localisation from Hindi-speaking browsers. Reporting the owner-override measurement as instructed:
  white on Housepital orange remains **2.33:1** (`onOrange = #FFFFFF`) — an explicit owner decision,
  recorded as fact, not raised as a defect. The new banner is `context.hc.black` on
  `context.hc.warningLight`, measured by the fix author at 19.15:1 light / 11.98:1 dark.
- ✅ **Offline / poor-network / error-path behaviour acceptable** — unchanged and **improved.**
  `runZonedGuarded`, a friendly `ErrorWidget.builder`, route-resolution catch, 5 s API timeout with
  cached/demo fallback. Round 1's caveat was that the fallback was *too* seamless, making "no
  backend" indistinguishable from "bad train". The banner fixes exactly that, on the five root tabs.
  **New this round:** `lib/services/store_migrator.dart` adds local-storage versioning — a stamped
  schema version, ordered steps, frozen literals, and **quarantine-instead-of-wipe** on unparseable
  data — run from `main.dart:174` before providers read. That is unusually disciplined for a
  pre-1.0 app and closes a real data-loss path (`OrdersProvider` previously overwrote on parse
  failure).
- ⚠️ **Automated test suite green in CI on the release commit** — cited central result: **1,797
  tests pass**, `flutter analyze` clean, design gate green. Still ⚠️ because there is no release
  commit and CI runs on push/PR to `main` only (this is `fix/five-tab-nav`), and because
  `docs/KNOWN_ISSUES.md:39-40` still lists BUG-07 (3 failing widget tests) and BUG-08
  (`AuthProvider` untested) as **Open** — the first now appears stale given a green suite, the
  second is confirmed by inspection: no `test/providers/auth_provider_test.dart` exists.
  Good news on test quality: `test/screens/main_shell_test.dart:228` correctly asserts
  *"five tabs, no Calendar tab"*, so the test suite is not stale on the nav change — only the docs
  are (§11).

### 10. Staged rollout

- ❌ **Beta/canary channel** — unchanged. `git tag` → empty; no ASC record.
- ⚠️ **Real testers verify on the release artifact** — unchanged. The owner tests a locally signed,
  development-provisioned Release build on one device — better than simulator-only, not the App
  Store artifact.
- ❌ **Prod-only features verified on the real build** — unchanged, all three still unverifiable.
  **Sync:** NXDOMAIN. **Push:** no entitlement (§4). **Payments:** `isDemoPayments == true` under the
  recorded config, so `openCheckout` simulates. The one real improvement is that the *code* is now
  safe when a real key arrives (fail-closed), so the first live test will be meaningful.

### 11. Submit / deploy & record

- ❌ **Submitted for review / deployed** — never. Still the honest headline.
- ❌ **Tag the release in version control** — `git tag` → empty, unchanged.
- ❌ **CHANGELOG updated** — **worse than round 1.** Newest entry is `docs/CHANGELOG.md:7`
  `## [2026-06-13]` = commit `d89c0b8`; `git log --oneline d89c0b8..HEAD | wc -l` → **9**. Unrecorded:
  `51a0cd1`, `db22f5f`, `75162d5`, `4a37c2a`, `bc73765`, `803124d`, `0a62955` (the 6→5 tab change),
  `9c39dc1`, `820060b` (ten release blockers, including two user-visible behaviour changes: payments
  now fail closed, and a permanent sample-data banner).
- ⚠️ **Known issues documented and accepted** — **downgraded from ✅.** `docs/KNOWN_ISSUES.md` is
  still a well-structured register (IDs, dates, statuses, honest about backend-repo ownership), but
  `:5` still reads "Last updated: **2026-05-28**" and it contains **none** of the ~50 findings from
  two audit rounds; BUG-34 (`:26`) still instructs restricting `in.housepital.patient`, a package
  that does not exist. A known-issues list that does not know the blockers is not performing the
  checklist's function.
  **Also stale — four live doc lines still assert six bottom tabs**, contradicting
  `main_shell.dart:37-43`: `docs/ARCHITECTURE.md:68` ("6 tabs: Home/My Care/Services/Calendar/
  Billing/More"), `docs/SCREEN_MAP.md:6` ("MainShell -- 6 tabs") and `:73` ("### CALENDAR TAB
  (Index 3)"), `docs/FEATURE_TRACKER.md:143` ("root tab at index 3 … = SIX tabs").
  `docs/CHANGELOG.md:56,64` also say six but are dated historical entries and are correct as history.

### 12. Rollback / hotfix plan

- ❌ **A way to disable a broken feature without a full release** — unchanged and still the most
  consequential structural gap. Grep over `lib/` and `pubspec.yaml` for
  `remoteconfig|remote_config|featureFlag|feature_flag|killSwitch|force_upgrade` → **no matches.**
  For a medical app that takes payments and runs an AI assistant, every defect needs a full App
  Review cycle to disable.
  **Fix:** add `firebase_remote_config` with at minimum `assistant_enabled`, `payments_enabled`, and
  a `force_upgrade` minimum-version gate before 1.0.
- ✅ **Rollback path known** — unchanged. `docs/DEPLOYMENT_GUIDE.md` §9 covers Cloud Functions and
  database rollback and states correctly that App Store Connect has no rollback — submit a fix.
- ⚠️ **Data/schema rollback considered (additive-only)** — **improved on the client side.**
  `store_migrator.dart` is the right shape: version stamp, ordered steps, frozen literals,
  quarantine rather than delete, downgrade-safe, and it distinguishes a fresh install from a
  pre-versioning one. The server side is unchanged — the deployment guide still says MySQL rollback
  is manual, and there is still **no written additive-only policy** (no field removal / no retype),
  which is the actual protection for a client already in the App Store.
- ⚠️ **Monitoring/alerting watched post-release** — unchanged. Crashlytics + Performance correctly
  wired and release-only; alert thresholds pre-designed in `docs/DEPLOYMENT_GUIDE.md` but both
  pre-launch boxes still unchecked, and per §4 crashes arrive unsymbolicated.

---

## App Review risks specific to THIS app

**Guideline 1.4.1 / 5.1.3 — physical harm and health data.** Unchanged and now sharper.
`lib/utils/vital_classifier.dart:5-14` still classifies systolic BP, SpO₂, pulse, temperature and
blood sugar into green/yellow/red at documented clinical thresholds — triage-grade interpretation.
The disclaimer grep (`disclaimer|not a substitute|medical advice|consult (your|a) doctor|
informational`) across `lib/` and `assets/i18n/` still returns **exactly one hit, inside the prose
body of a demo article** (`demo_articles.dart:192`). **There is still no disclaimer in the app's UI
at all.** The vitals a first-time user sees are still `DemoData.vitalsHistory`, and `/vitals` is a
pushed route, so the new banner is not on screen when they are read.

**New: the doctor handover PDF is a fabricated clinical document.**
`handover_report_service.dart:101-108` builds every section from `DemoData` by hardcoded assignment,
renders it under the Housepital logo with a "Housepital Doctor Handover Report" page footer
(`:121-143`), names the file after `DemoData.patient.name` (`:287`) and shares it via
`Printing.sharePdf` (`:305`). No watermark, no sample marking, and a PDF cannot carry the in-app
banner. This is the single highest-risk artefact in the app under 1.4.1 and 2.3.1: a document
designed to be handed to a treating physician, containing invented conditions, medications and
vitals, branded as authentic. It is also role-gated to the primary contact — i.e. reserved for the
person most likely to act on it.
**Fix:** drive it from live providers, or stamp `SAMPLE — NOT A CLINICAL RECORD` across every page
whenever `DemoMode.isServingDemoData` is true, and refuse to export at all if no real patient record
has ever loaded.

**Guideline 5.1.1(v) — account deletion.** Now ⚠️ rather than ❌; see the dedicated section. The
deletion UI exists and is easy to find; it does not yet delete anything server-side or in Firebase
Auth, and it claims that it does.

**Guideline 3.1.1 / 3.1.5(a) — IAP not required. ✅ Unchanged.** Everything the app sells is a
real-world service or physical good delivered in Delhi NCR — manpower day-rates and monthly packages
(`catalog_seeds.dart`), equipment rental/purchase, lab tests, consultations, ambulance. That is the
3.1.5(a) "Goods and Services Outside of the App" carve-out; Razorpay is correct and permitted, and
IAP must **not** be used. Keep it clean: no digital-only unlock (premium articles, a "Sahayak Pro"
tier, ad-free) without moving that item to IAP, and "Refer & Earn ₹500" must stay a real-world
credit rather than becoming spendable in-app currency. State the 3.1.5(a) rationale in the review
notes.

**Guideline 2.1 — completeness.** The cluster that gets rejected on sight is still mostly intact,
with two members removed and one added. Still present: fabricated patient data on first launch (now
*announced*, which arguably worsens the 2.1 read), a backend hostname that does not resolve, a
placeholder Razorpay key that simulates success, no export-compliance answer, and the placeholder
support number `919999999999` in **two** places (`help_faq_screen.dart:352` and `:365`) while the
real number sits unused in `constants.dart:17,19`. Removed: the stock Flutter icon and the blank
launch screen. Added: an account-deletion screen whose only action is a 600 ms delay.

**Guideline 2.3.1 — hidden/undocumented behaviour.** Improved. The simulated payment can no longer
confirm an unverified real-money transaction: `payment_service.dart:161-181` treats
`_VerificationOutcome.skippedDemo` as success **only** when `isDemoPayments`, and otherwise logs and
fails closed with "Payment under verification". `createOrder` is now called before real checkout so
a verifiable `order_id` exists. This is the cleanest fix in the batch. It remains true that shipping
with the placeholder key would mean shipping a simulator, so ship with a real key or with purchase
disabled.

**Sahayak (AI assistant) — 5.1.2 and disclosure.** Unchanged. `assistant_screen.dart` still carries
no "AI-generated, may be inaccurate" notice. When `ASSISTANT_API_URL` is set
(`constants.dart:10-11`, default empty) user text goes to a Cloud Function calling Claude.
Re-verified this round: `ANTHROPIC_API_KEY` appears nowhere in `lib/`, `ios/` or `assets/` — it is a
Firebase secret only. The secret-handling design remains correct.

---

## Blockers (must fix before any submission)

1. **Demo patient data seeds on every fresh install** — `app_provider.dart:136-140`, `:215`,
   `:257-270`. The banner does not clear 2.1, does not reach twelve pushed routes, and five demo
   sources never set the flag. (§2, dedicated section)
2. **The doctor handover PDF is built entirely from `DemoData`** and is exportable/shareable with no
   sample marking — `handover_report_service.dart:101-108,287,305`. (§App Review)
3. **`/delete-account` transmits nothing, does not delete the Firebase Auth user, and tells the user
   it did** — `delete_account_screen.dart:53-59,74-78`. 5.1.1(v) + 2.3.1. (§5)
4. **Privacy Policy / Terms links fail TLS** — apex `curl` exit 60; `www.` returns 200. Four links:
   `about_screen.dart:98,104,110`, `referral_screen.dart:121`. (§5)
5. **Production API host does not exist** — `api.housepital.in` NXDOMAIN; the entire app runs on
   demo fallbacks. (§2, §3)
6. **Placeholder Razorpay key in the recorded build config** — no `RAZORPAY_KEY` in `DART_DEFINES`,
   so `constants.dart:24` falls back to `rzp_test_XXXXXXXXXX` → simulated checkout. (§2)
7. **`ITSAppUsesNonExemptEncryption` missing** — every upload stalls on Missing Compliance. (§5)
8. **No medical disclaimer anywhere in the UI** while `vital_classifier.dart:5-14` colour-codes vital
   signs. (§App Review)
9. **App icon is a ~3.6× raster upscale, visibly soft at 1024 and filling ~50 % of the canvas** —
   passes validation, but should not be the artwork on a first submission. (§6)

## High

10. **No `.entitlements` file; Push capability absent** — FCM is fully wired and dead in production.
    (§4)
11. **`LSApplicationQueriesSchemes` absent while `canLaunchUrl('tel:')` gates the SOS dial path** —
    `sos_screen.dart:248-251` plus four more sites; verify on device, it is a two-minute check. (§4)
12. **No Crashlytics dSYM upload phase** — every production crash arrives unsymbolicated. (§4)
13. **No feature-flag / remote-config kill switch** — nothing can be disabled without an App Review
    cycle. (§12)
14. **iPad declared (`TARGETED_DEVICE_FAMILY = "1,2"`) and landscape unlocked**, both untested and
    untestable from the current suite. (§6)
15. **`storage.rules`, `firestore.rules` and the Firebase API-key restrictions are all undeployed** —
    live posture unknown for patient chat and concern photographs. (§3)
16. **Android release signs with debug keys** — `android/app/build.gradle.kts:34-38`. (§4)
17. **Placeholder support number `919999999999` in two places** — `help_faq_screen.dart:352,365`,
    while the real number is already in `constants.dart:17,19`. (§App Review)

## Medium / Low

18. 31 `debugPrint` calls bypass `Log` and ship in release, several printing exception detail. (§2)
19. Sample-data banner double-counts the top safe-area inset on My Care and Billing —
    `main_shell.dart:58-71` vs `my_care_screen.dart:141`, `billing_screen.dart:173`. (§9)
20. Version string hardcoded in `about_screen.dart:11` and `settings_screen.dart:258`. (§1)
21. Three inconsistent app identifiers across iOS / Android / `KNOWN_ISSUES.md:26`. (§1)
22. `CFBundleLocalizations` absent — the store will list the app English-only. (§9)
23. CHANGELOG is nine commits behind HEAD and is date-keyed rather than version-keyed. (§11)
24. `KNOWN_ISSUES.md` last updated 2026-05-28 and records none of two audit rounds' findings. (§11)
25. Four live doc lines still assert six bottom tabs — `ARCHITECTURE.md:68`, `SCREEN_MAP.md:6,73`,
    `FEATURE_TRACKER.md:143`. (§11)
26. No git tags; no release-tagging process. (§11)
27. `LaunchScreen.storyboard:22` background is white while the Flutter splash is orange — a colour
    step at launch. (§6)
28. `CFBundleDisplayName` "Housepital Patient" truncates on the Home Screen. (§6)
29. 81 MB of bundled assets (78 MB product photos) — likely over the 200 MB cellular threshold once
    frameworks are linked. (§8)
30. CI still runs `analyze --no-fatal-warnings --no-fatal-infos` for a backlog that `flutter analyze`
    now reports as zero — the gate can be tightened. (§8)
31. `AuthProvider` still has no test file (BUG-08). (§9)
32. `storage.rules:44-53` assumes `auth.uid == patientId`, which will deny legitimate family members
    the moment family sharing is real — flagged honestly in the file itself. (§3)

---

## BLOCKED-OWNER — what only the owner can supply

Unchanged from round 1 in substance; nothing on this list moved. Each requires an Apple Developer
account action, a live service, or a business decision, and none can be produced from the repo.

1. **Apple Developer Program enrolment + App Store Connect app record.** Team `3M5BRKQ345` is already
   configured for signing, so the account likely exists; **the app record does not.** Create it with
   bundle ID `com.housepital.housepitalPatient` (must match `project.pbxproj:690` exactly), primary
   language English (India), and an SKU.
   *What I would need to verify:* App Store Connect access, or a screenshot of the app record.
2. **Privacy policy URL** — use `https://www.housepital.in/privacy` (verified `200` today; apex fails
   TLS). Content must explicitly cover: phone number, health data (vitals, medications, conditions,
   allergies, handover reports), photographs of prescriptions and reports, home address, payment data
   via Razorpay, Firebase Crashlytics/Performance diagnostics, and — if `ASSISTANT_API_URL` is set —
   that assistant messages are processed by a third-party AI provider (Anthropic).
3. **Support URL** (e.g. `https://www.housepital.in/support`) and a **real support phone/WhatsApp
   number** to replace `919999999999` in both `help_faq_screen.dart:352` and `:365`.
4. **Marketing URL** (optional) — `https://www.housepital.in`.
5. **App Store screenshots** — 6.7" (1290×2796) and 6.5" (1242×2688) iPhone mandatory; **12.9" iPad
   (2048×2732) also mandatory unless `TARGETED_DEVICE_FAMILY` drops to `"1"`.** Must not show the
   "Rajesh Kumar" record.
6. **App name, subtitle (30 chars), description, keywords (100 chars), promotional text.** No
   diagnostic or treatment claims.
7. **Age-rating questionnaire answers.** Expect 12+ or 17+; answer "Medical/Treatment Information"
   honestly — under-rating is a rejection.
8. **Category** — recommend Primary: Medical, Secondary: Health & Fitness.
9. **App Privacy "nutrition label" answers** — at minimum: Health & Fitness (Health), Contact Info
   (phone, name, physical address), User Content (photos), Financial Info (payment), Identifiers
   (user ID, device ID via Firebase), Diagnostics (crash + performance). Declare linkage to identity
   and purpose (App Functionality) per category.
10. **Real Razorpay key** — a live `rzp_live_…` key ID passed as `--dart-define=RAZORPAY_KEY=…` at
    build time (the secret stays server-side). Requires completed Razorpay KYC for Housepital Pvt Ltd
    (CIN U85100DL2019PTC357830 per `about_screen.dart:15`).
11. **Production backend** — stand up `api.housepital.in` serving `/v1`, or repoint `apiBaseUrl` at
    the deployed Cloud Functions URL. **Plus three console deploys that are all still pending:**
    `firebase deploy --only firestore:rules`, `firebase deploy --only storage`, and the API-key
    restrictions (KNOWN_ISSUES BUG-33, BUG-34).
    *What I would need to verify:* Firebase console access, or `firebase deploy` output.
12. **APNs authentication key (.p8)** uploaded to the Firebase console, after Push Notifications is
    enabled in Xcode.
13. **Firebase Auth test phone number** (Console → Authentication → Sign-in method → Phone → Phone
    numbers for testing) plus the number and code written into the App Review notes.
14. **Export-compliance decision** — confirm HTTPS-only standard encryption (it is, from the code) so
    `ITSAppUsesNonExemptEncryption = false` is correct.
15. **Business decision: iPad and landscape in or out?** Keeping them costs iPad screenshots plus a
    real iPad/landscape QA pass; dropping them is a two-line change.
16. **Business decision: does the Sahayak assistant ship in 1.0?** If yes it needs a disclaimer and a
    privacy disclosure; if no, leave `ASSISTANT_API_URL` unset and hide the entry point.
17. **New — a designer's vector of the Housepital mark** (SVG/AI/PDF). The 1024 icon cannot be made
    crisp by re-processing the 143×182 raster it came from.
18. **New — deletion-request destination.** Even without the API, decide where a deletion request
    lands (a Firestore collection is enough) so `/delete-account` stops promising something nothing
    records.

---

## Ordered runway to submission (updated)

**Phase 0 — half a day, mechanical, no decisions needed.** All are one- or two-line edits with the
correct value already present in the repo:
`ITSAppUsesNonExemptEncryption` · `CFBundleLocalizations` (en, hi) ·
`LSApplicationQueriesSchemes` (tel, mailto, sms) · `www.` on the four apex URLs in
`about_screen.dart:98,104,110` and `referral_screen.dart:121` · the real support number in
`help_faq_screen.dart:352,365` · `TARGETED_DEVICE_FAMILY = "1"` + portrait lock ·
`LaunchScreen.storyboard` background → brand orange · fix the banner's top-inset double-count in
`main_shell.dart`.

**Phase 1 — the review-compliance work (a few days).**
Gate `_seedDemoDataIfEmpty()` and `loadPatients()`'s seed behind `--dart-define=DEMO_DATA`, plus
honest empty states · watermark or re-source the handover PDF · make `/delete-account` real
(`currentUser.delete()` + a persisted request + honest copy) · add the medical disclaimer on vitals
and daily reports and an AI notice on Sahayak · enable Push Notifications and add
`UIBackgroundModes` · add the Crashlytics `upload-symbols` build phase.

**Phase 2 — assets and owner decisions (parallel with Phase 1).**
Designer's vector → regenerate all 15 icons at ~72 % canvas fill · iPad/landscape in-or-out
decision · Sahayak in-or-out decision · privacy-policy content covering health data, photos,
payments and the AI provider.

**Phase 3 — the real dependencies (owner-led, longest lead time).**
Stand up the production API or repoint `apiBaseUrl` · `firebase deploy --only firestore:rules` and
`--only storage` · apply the API-key restrictions (fixing BUG-34's package name first) · complete
Razorpay KYC and obtain a live key · configure the Firebase test phone number.

**Phase 4 — release hygiene, then ship.**
Add `firebase_remote_config` with `assistant_enabled` / `payments_enabled` / `force_upgrade` ·
bring `CHANGELOG.md` up to date (nine commits) and version-key it · refresh `KNOWN_ISSUES.md` with
both audit rounds and fix the four six-tab doc lines · read the version from `package_info_plus` ·
tag `v1.0.0` · archive with distribution signing and a bumped build number ·
**TestFlight internal first** · then submit with review notes covering the 3.1.5(a) real-world-services
rationale, the test phone number, the medical-disclaimer placement, and the second account for role
testing.

---

## Verdict

**Still does not pass — 25 ❌ / 16 ⚠️ / 3 ✅ / 1 N/A across 45 items** (round 1, recounted on the same
basis: 27 ❌ / 14 ⚠️ / 3 ✅). Two blockers closed, two downgraded to partial, nothing regressed.

The engineering in commit `820060b` is good work and should be said so plainly: the payment
fail-closed fix is exactly right, `SessionScope` closes a real PHI leak, `StoreMigrator` is more
disciplined than most pre-1.0 apps manage, the camera crash is gone, `storage.rules` is a properly
reasoned artefact, and the launch screen is genuinely fixed. The pattern in what did **not** close is
consistent and worth naming: three of the four incomplete fixes stop at the point where they would
need something outside the repo — a backend to POST to, a designer's vector, a deployed rules file —
and each was finished with a plausible-looking surface instead. A banner instead of a gate, a
600 ms delay instead of a request, an upscaled raster instead of a re-export. Each of those surfaces
now *says* the thing is handled, which is why round 2 matters more than round 1 did: the remaining
defects are harder to see than the ones that were fixed.

The submission layer itself has barely moved. No ASC record, no screenshots, no privacy disclosure,
no live backend, no real payment key, no tag, no TestFlight build. That is where the calendar time
is, and none of it starts until the owner-blocked items above are unblocked.
