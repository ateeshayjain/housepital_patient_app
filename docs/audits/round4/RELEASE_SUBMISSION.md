# Release & App Store Submission — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-11 · **Auditor:** Release & Store Submission (REL) · **Scope:** source review (see Limitations)
**Prior rounds:** R3 `9a80fe2` · R2 `820060b` · R1 `803124d` · Branch `fix/five-tab-nav`

**Commands run this round, output cited inline:**
`git show --stat 13e3656 9127713` · `git log 820060b..HEAD -- ios/ android/` ·
`git log 9a80fe2..HEAD -- <appiconset>` · `git tag` · `gh run list --limit 100` +
`gh run view 27549359363` · `curl` on four apex/`www.` URLs · `nslookup api.housepital.in` ·
`find . -name PrivacyInfo.xcprivacy` · `find ios -name "*.entitlements"` ·
`sips` + a PIL bounding-box measurement of the 1024 icon · a Python pass over
`assets/equipment_catalog.json` (351 items) · a Python simulation of
`assistant_service.dart`'s intent regexes · a Python parse of `project.pbxproj`'s
`XCBuildConfiguration` blocks · targeted greps over `lib/`, `test/`, `ios/`, `android/`.
**Not run** (per brief): `flutter test`, `flutter build`, `flutter clean`, `pod install`.
Cited central results: `flutter analyze` clean · design gate passes · 1,819 tests pass locally.

---

## Applicability

MASTER-3 triggers, all met: this is a mobile application intended for public distribution
through the Apple App Store (iOS-first, per brief), it takes payment, it creates accounts, it
transmits health data, and it has never been uploaded. Every REL control family applies. The
Apple overlay (§13, §14) applies in full; the macOS overlay (REL-15.04) does not.

---

## The headline finding: this round did not target this module

The brief asked me to verify whether `13e3656` and `9127713` addressed any round-3 release
finding. They did not, and the evidence is a single command:

```
$ git log --oneline 820060b..HEAD -- ios/ android/
(no output)
```

**Not one byte under `ios/` or `android/` has changed since round 2's commit.** Every
submission-gating artefact lives there — `Info.plist`, `project.pbxproj`, the appiconset,
`build.gradle.kts`, `google-services.json`, the entitlements file that does not exist. So
`ITSAppUsesNonExemptEncryption`, `LSApplicationQueriesSchemes`, `CFBundleLocalizations`,
entitlements, the dSYM phase, `TARGETED_DEVICE_FAMILY`, the Android debug keystore and the app
icon are not merely "still open" — they are byte-identical across three audit rounds, and no
commit has ever attempted them. `13e3656` touched 16 files, all Dart or test. `9127713` touched
13 files, 10 of them Markdown.

**A round with no movement is itself the finding.** Rounds 1→2 produced surfaces; 2→3 produced
half-wires. Round 4 fits neither pattern, because round 4 did not reach this module at all. The
two commits were competent work on state management, payment typing and documentation. They were
aimed elsewhere. The submission gate has now been stationary for four rounds.

The one thing that *did* land here landed by accident: `13e3656` replaced the three placeholder
support numbers with `AppConstants.supportPhone`, as a side effect of fixing a payment-failure
routing bug. **That closes an in-app control, not a store-facing one** — see §"The support-number
question" below.

Against that stationary baseline, the parallel modules delivered material *new* evidence that
makes the submission posture **worse than round 3 recorded**, not better. Three of those findings
are, in my assessment, independently sufficient grounds for App Review rejection, and one of them
is a claim about a real person's criminal-background check.

---

## Prior-round status

Every round-3 finding, re-verified. **Nothing in this table improved except H15 and M21/§11.**

| Round-3 finding | R3 | Status now | Evidence |
|---|---|---|---|
| **B1** Icon a raster upscale, ~50 % fill | ⚠️ | **Still open, byte-identical** | `git log 9a80fe2..HEAD -- <appiconset>` → empty. Independent PIL bbox on the 1024: ink `x[255,769] y[185,839]` → **50.2 % width / 63.9 % height**. `sips`: 1024×1024, `hasAlpha: no`, `space: RGB`. `grep -c "appearances\|luminosity\|tinted" Contents.json` → **0** |
| **B2** Camera/photo usage strings | ✅ | **Still Pass** | `Info.plist` carries all four: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` |
| **B3** Demo patient seeds on every fresh install | ❌ | **Still open, untouched** | `grep -rn fromEnvironment lib/` → 2 hits (`constants.dart:11` `ASSISTANT_API_URL`, `:23` `RAZORPAY_KEY`). No `DEMO_DATA`. `app_provider.dart:150-152` still `_currentPatient = DemoData.patient` unconditionally |
| **B4** `/delete-account` write-only record, no re-auth | ⚠️ | **Still open, verbatim** | `grep -rn "housepital_pending_deletion" lib/ test/` → 3 hits: `delete_account_screen.dart:60` (constant), `:84` (the write), `auth_provider.dart:233` (preserve-list literal). **Zero readers.** `grep -rn "reauthenticate\|requires-recent-login" lib/` → **NONE** |
| **B5** Privacy/Terms fail TLS on apex | ❌ | **Still open** | `curl` this round: `https://housepital.in/privacy` → **000**, `https://www.housepital.in/privacy` → **200**; same split for `/terms`. Links: `about_screen.dart:98,104,110`, `referral_screen.dart:121` |
| **B6** `api.housepital.in` NXDOMAIN | ❌ | **Still open** | `nslookup` → `** server can't find api.housepital.in: NXDOMAIN` |
| **B7** Placeholder Razorpay key | ⚠️ | **Still open** | `constants.dart:23-26` `defaultValue: 'rzp_test_XXXXXXXXXX'` |
| **B8** `ITSAppUsesNonExemptEncryption` missing | ❌ | **Still open** | `grep -c` → **0** |
| **B9** No medical disclaimer in the UI | ❌ | **Still open** | `grep -rni "disclaimer\|not medical advice\|not a substitute" lib/ assets/i18n/` → **zero hits** (round 3's single hit was a paraphrase inside `demo_articles.dart`, not a disclaimer) |
| **H10** No `.entitlements`, Push dead | ❌ | **Still open** | `find ios -name "*.entitlements"` → empty. `grep -c UIBackgroundModes` → **0** |
| **H11** `LSApplicationQueriesSchemes` absent | ❌ | **Still open** | `grep -c` → **0** |
| **H12** No remote-config kill switch | ❌ | **Still open** | `grep -rn "remote_config\|RemoteConfig\|feature_flag\|killSwitch" lib/ pubspec.yaml` → **NONE** |
| **H13** iPad declared + landscape unlocked | ❌ | **Still open** | `TARGETED_DEVICE_FAMILY = "1,2"` in **all three** build configs (pbxproj:488 Profile, 618 Debug, 671 Release). `Info.plist` `UISupportedInterfaceOrientations` still lists both landscape orientations |
| **H14** Android signs with debug keys | ❌ | **Still open, TODO intact** | `android/app/build.gradle.kts:32-37`: `// TODO: Add your own signing config` / `signingConfig = signingConfigs.getByName("debug")` |
| **H15** Three placeholder support numbers | ❌ | **✅ CLOSED** | `grep -rn "9999999999\|8888888888" lib/` → only two *comments* recording the removal (`help_faq_screen.dart:353`, `staff_otp_verification_screen.dart:353`). All three sites now use `AppConstants.supportPhone = '9990911911'` (`constants.dart:19`). **The only round-3 finding this round closed** |
| **H16** Rules + key restrictions undeployed | ❌ | **Still open** | `storage.rules:6-11` still headed `!!  DEPLOY REQUIRED  !!`. `KNOWN_ISSUES.md:67` BUG-33 "deployment to console pending"; `:68` BUG-34 "Open (console action required)" |
| **M17** `debugPrint` in release | ⚠️ | **Still open, same count** | `grep -rn debugPrint lib/ \| wc -l` → **34** |
| **M19** Banner double-counts top inset | ✅ (fixed R3) | **Still Pass** | Not re-litigated |
| **M21** CHANGELOG behind HEAD | ❌ (14 behind) | **⚠️ materially improved** | `9127713` added `docs/CHANGELOG.md:3` "## 2026-08-03 — audit rounds 1–3 and the fixes they forced", narrating the round-3 repairs. Still date-keyed, not version-keyed, and no tag binds it |
| **§11 KNOWN_ISSUES stale** | ⚠️ | **⚠️ materially improved** | `KNOWN_ISSUES.md:5` now "Last updated: **2026-08-03** (audit round 3)" with an "Open — from the eleven-checklist audits" section. **But BUG-34 still names `in.housepital.patient`** — see the identity finding below |
| **§11 docs assert six tabs** | ❌→⚠️ | Documentation module's scope; not re-graded here | — |
| **§9 no `AuthProvider` test** | (R3 self-correction) | Correction stands | `test/providers/auth_provider_test.dart` exists |
| **R3 §(c)** handover PDF fabricated, 8 pt band, builder mutates global state | ❌ | **Still open — and worse than round 3 knew** | `handover_report_service.dart:105` still calls `markServingDemoData` from inside the builder; `:107-114` still assigns every section from `DemoData`; band still `fontSize: 8` (`:138`); no export guard. **New:** see the adherence finding |

**Regressions since round 3: none introduced by `13e3656`/`9127713`.** The deterioration this
round is in *knowledge*, not in code: the parallel modules found defects that were present at
`9a80fe2` and that round 3 did not detect.

---

## New evidence bearing on submission — assessed for App Review risk

### N1. `staff_profile_screen.dart` fabricates a police-verification claim on the shipping path — **highest review risk in the app**

```dart
// lib/screens/support/staff_profile_screen.dart:37-52
try {
  _staff = await ApiService().getStaffProfile(widget.staffId);
} catch (e) {
  debugPrint('Error loading staff profile: $e');
  // Mock data for preview
  _staff = StaffProfile.fromJson({
    'name': widget.staffName ?? 'Housepital Staff',
    'rating': 4.8,
    'total_reviews': 142,
    'id_verified': true,
    'training_complete': true,
    'police_verified': true,
```
…followed by `:59-60` an `'aadhaar'` / `'Aadhaar Card'` document entry and `:75` a
`'training_certificate'`, all rendered as verification badges (`:279-285`, `:348-361`) and a
4.8★ / "(142 reviews)" score (`:240-257`).

**This is not a fallback; it is the only path.** `ApiService().getStaffProfile` targets
`AppConstants.apiBaseUrl = 'https://api.housepital.in/v1'` (`constants.dart:3`), which returns
NXDOMAIN. The request cannot succeed. Therefore **100 % of users, on 100 % of staff profiles,
see an asserted police verification, an asserted Aadhaar document, and a fabricated 4.8/142
rating for whichever real caretaker or nurse is assigned to their elderly relative.**

**Review risk:** this is the app's single most rejectable artefact, on two independent grounds.
Guideline 2.3.1 (accurate metadata / no hidden or undocumented features) covers misrepresenting
what the app knows; but the sharper exposure is **1.4.1 and 5.1.2** — a health app asserting a
completed criminal-background check and a government-ID verification for a named individual, on
evidence it does not possess. `DemoMode` does not cover this screen (no `sourceStaffProfile`
constant exists), so it carries **no sample-data pill either**. It is the one fabrication in the
app with zero labelling of any kind.

It also renders a **reviews feed** (`:91-130`, `:1080-1160`) — see REL-14.06.

### N2. The equipment `needsAssessment` gate is inverted — it gates masks and exempts machines

```dart
// lib/models/models.dart:1047-1058
bool get needsAssessment {
  // Rentable items don't need assessment (rental agreement covers terms)
  if (availableForRent == true) return false;
  final n = name.toLowerCase();
  return n.contains('ventilator') || n.contains('bipap') || … n.contains('c-pap');
}
```

A Python pass over all **351** items in `assets/equipment_catalog.json`:

| | count |
|---|---|
| items whose name matches ventilator/BiPAP/CPAP | **31** |
| of those, **gated** (assessment required) | **11** — *every one of them a mask or nose mask* |
| of those, **exempt** (rentable) | **20** — *every actual machine* |
| Oxygen Concentrators in the catalog | **16** — `available_for_rent: true`, **all 16 exempt** |

The 11 gated items are `BiPAP Mask (S/M/L)`, `BiPAP Mask (M) Vented/Non-Vented`,
`CPAP NOSE MASK`, etc. The 20 exempt are `Stellar 150 Ventilator G2`, `DreamStation BiPAP AVAPS
30`, `BiPAP A-40`, `Airsense 10 Autoset CPAP`, and so on. The `availableForRent` early-return
inverts the intent exactly: the clinical assessment fires on the £-cheap consumable and is
skipped on the life-support device, because life-support devices are the ones you rent.

*(Note: the brief said 17 concentrators; my case-insensitive count over the shipped catalog is
**16**. I report my own number.)*

**Review risk:** moderate on its own — Apple does not audit clinical gating logic. But it becomes
material under **1.4.1** in combination with N1 and N5: the app dispenses respiratory support
equipment to home users with no clinical checkpoint, while asserting the staff who will operate
it are police-verified on no evidence.

### N3. The handover PDF's adherence percentage is arithmetic on the calendar date — printed to a physician

```dart
// lib/models/care_event.dart:44-45
int adherencePercentFor(DateTime day) =>
    80 + ((day.day * 7 + day.weekday * 3) % 21);
```
```dart
// lib/services/handover_report_service.dart:118-120, 205
final pct = weeklyAdherencePercent(now: generated);
final weekTotal = dosesPerDay() * 7;
final weekTaken = (weekTotal * pct / 100).round();
…
pw.Text('This week adherence: $pct% ($weekTaken/$weekTotal doses)',
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
```

The number is a function of the day-of-month and the day-of-week. It reads no medication log. It
is guaranteed to land in 80–100 %, so it always reports **good** adherence. It is then formatted
as a fraction of real dose slots — `($weekTaken/$weekTotal doses)` — which is the specific
presentation that makes a computed constant look like a count.

**And it is set at `fontSize: 10, bold`, while the "SAMPLE DATA — NOT A CLINICAL RECORD" band
that disclaims it is `fontSize: 8` (`:138`).** The fabricated clinical figure is rendered larger
and bolder than the warning about it, on a document whose entire purpose is
`Printing.sharePdf` to a treating doctor.

**Review risk:** high under **1.4.1**. Round 3 graded the handover PDF a blocker for being 100 %
`DemoData` behind a small band. This finding shows the document does not merely *contain* sample
values — it *computes* a clinically-shaped statistic that has never touched a medication record,
and typographically outranks its own disclaimer. A reviewer who exports one PDF has the exhibit.

### N4. CI has never executed a single step — 47 runs, 47 failures, all billing-locked

```
$ gh run list --limit 100 --json conclusion | …
total 47
Counter({'failure': 47})

$ gh run view 27549359363
X main CI · 27549359363   |   X test in 2s
ANNOTATIONS
X The job was not started because your account is locked due to a billing issue.
```

Every run since the workflow was added has failed **before starting the job**. Durations are 3–12
seconds. `.github/workflows/ci.yml` exists and is well-formed; it has never run.

**Consequence for this module:** REL-9.04 requires the suite green **in CI on the release
commit**. The 1,819-passing-tests figure is a developer's local claim with **zero independent
attestation**, and by construction has never been produced on a clean machine. It is also the
single number every other module in this suite cites as its evidence of health.

### N5. Android: no Firebase Gradle plugins, and `google-services.json` names a package that does not exist

```
$ grep -rn "google-services\|crashlytics\|firebase" android/ | grep -v google-services.json
(no output)
```

`android/build.gradle.kts` and `android/settings.gradle.kts` apply only
`com.android.application`, `org.jetbrains.kotlin.android` and `dev.flutter.flutter-plugin-loader`.
Absent: `com.google.gms.google-services`, `com.google.firebase.crashlytics`,
`com.google.firebase.firebase-perf`. Meanwhile `pubspec.yaml:34-35` declares
`firebase_crashlytics: ^4.3.5` and `firebase_performance: ^0.10.1+5`, and `main.dart:117-132`
initializes both.

And:

| source | identifier |
|---|---|
| `android/app/build.gradle.kts:24` `applicationId` (and `:9` `namespace`) | `com.housepital.housepital_patient` |
| `android/app/google-services.json:12` `package_name` | `com.housepital.patient` |
| `ios/…/project.pbxproj:690` `PRODUCT_BUNDLE_IDENTIFIER` | `com.housepital.housepitalPatient` |
| `docs/KNOWN_ISSUES.md:68` BUG-34, the package to restrict the Android API key to | `in.housepital.patient` |

**Four identifiers, no two alike.** The reason the `google-services.json` mismatch has never
broken a build is that the Google Services plugin — the thing that would fail it with *"No
matching client found for package name"* — is not applied. The file is inert; Firebase
initializes from `lib/config/firebase_options.dart` instead. So the mismatch is latent: **the day
anyone adds the Crashlytics plugin (which they must, to symbolicate Android crashes), the Android
build breaks immediately.** And BUG-34's remediation instruction — restrict the Android API key
to `in.housepital.patient` + release SHA1 — would restrict the key to a package that has never
existed, silently killing Firebase on Android.

Round 3 noted "three inconsistent app identifiers" as a Medium. With `google-services.json`
counted it is four, and it now has a mechanism: it is why Android crash reporting cannot be
turned on without a build break.

### N6. The Sahayak assistant routes "bleeding ho raha hai" to attendance

```dart
// lib/services/assistant_service.dart:169
if (RegExp(r'duty|din|aaya|attendance|haazri').hasMatch(t)) {
  return const AssistantResponse(
    action: AssistantAction.getDutyDays,
    replyText: 'Staff ki duty check kar raha hoon…');
}
```

`"blee**din**g"` contains `din`. Simulated against the full matcher in order:

```
book/service  False
call          False
duty          True   ← matched substring: "din"
bill          False
```

A patient typing *"bleeding ho raha hai"* is answered *"Staff ki duty check kar raha hoon…"* and
shown attendance days. There is **no emergency or medical-urgency intent in the local matcher at
all** — `sos` appears only at `:156` as a *call-target refinement* inside an intent that must
first match `call|phone|baat|dial`.

**Review risk:** this is the module's clearest **1.4.1** exhibit after N1 and N3, and it is
trivially reproducible by a reviewer who types one Hinglish phrase into the assistant. It also
sits badly beside CLAUDE.md's inviolable rule *"SOS is never blocked"* — SOS the button is never
blocked; SOS the *sentence* is routed to a timesheet.

---

## The support-number question

The brief asks whether fixing the three placeholder numbers closes a store-facing control or only
an in-app one. **Only an in-app one, and it does not move a single REL grade.**

- **What it closed:** round-3 finding H15. All three sites (`help_faq_screen.dart:352,365`,
  `staff_otp_verification_screen.dart:352`) now resolve `AppConstants.supportPhone = '9990911911'`.
  A user who taps "Call support" now reaches Housepital. That is a real user-facing repair.
- **What it does not close — REL-6.01.** The control requires *"support + marketing URLs"* as
  **App Store Connect metadata fields**. Apple requires a support **URL**, not a phone number;
  the URL is submitted in the listing, not compiled into the binary. No such URL exists —
  `https://housepital.in` fails TLS (000), and no metadata artefact exists anywhere in the repo
  (`find` for fastlane/metadata → nothing). REL-6.01 is unchanged **Fail**.
- **REL-14.06** requires *"published contact details"* for UGC moderation response. The real
  number is now *in the app*, which is a necessary ingredient — but the control also needs
  filtering, reporting and blocking, none of which exist. Unchanged **Fail**.
- **REL-7.01/7.02/7.03** (reviewer notes) are unaffected: no notes exist.

**Net: one round-3 High closed; zero REL controls moved.** That asymmetry is the shape of this
whole round — the fixes are real and they are aimed at the app's behaviour, while the submission
gate is a set of files nobody has opened.

---

## Control results

Graded against the 63 controls of the v2.0 REL checklist. (Round 3 used a bespoke 45-item basis;
the scorecards are therefore **not** directly comparable — the item-for-item comparison is the
Prior-round table above, and it shows one item moved.)

### 1. Version & build

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-1.01 | **Warning** | `pubspec.yaml:4` `version: 1.0.0+1` | No prior release exists, so there is nothing to bump *from*; but this value has been constant across four audit rounds and 30+ commits of material change. Must move before first upload. Owner: OWNER-TBD, due before submission |
| REL-1.02 | **Warning** | `pubspec.yaml:4` build `+1`; `git tag` → empty | Never uploaded, so `+1` is still valid for the first upload. Becomes a Fail the instant an upload is attempted twice. OWNER-TBD |
| REL-1.03 | **Fail** | Three sources of truth: `pubspec.yaml:4`; `about_screen.dart:11` `static const _appVersion = '1.0.0'`; `settings_screen.dart:258` `'Housepital v1.0.0'`. `grep package_info pubspec.yaml` → **NONE** | Bumping `pubspec.yaml` leaves two screens displaying a stale version to users and to a reviewer comparing About against the listing. Fix: add `package_info_plus`, delete both literals |

### 2. Flags & configuration

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-2.01 | **Fail** | No flag system exists. `grep -rn fromEnvironment lib/` → 2 hits, neither a mode gate | There is no flag to review the shipping value of, because the demo behaviour *is* the shipping behaviour |
| REL-2.02 | **Fail** | `app_provider.dart:150-152`: `_currentPatient = DemoData.patient; _patients = [DemoData.patient];` inside `if (_patients.isEmpty)`, unconditional. No `DEMO_DATA` define | **Demo mode is not off by default — it is the only mode.** Fourth consecutive round. Apple 2.1: a reviewer's fresh install opens on a fabricated 72-year-old post-stroke patient with five named prescriptions |
| REL-2.03 | **Fail** | `constants.dart:3` `apiBaseUrl = 'https://api.housepital.in/v1'` → NXDOMAIN; `:23-26` `razorpayKey` defaults `'rzp_test_XXXXXXXXXX'` → `payment_service.dart` simulates checkout | Points at a production endpoint that does not exist and a placeholder payment key |
| REL-2.04 | **Warning** | `grep -rn debugPrint lib/ \| wc -l` → **34** | `debugPrint` is **not** stripped in Flutter release builds. Several interpolate exception objects (e.g. `staff_profile_screen.dart:41`). Low severity, but it is production log spew. OWNER-TBD |

### 3. Backend / services prod-ready

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-3.01 | **Fail** | `storage.rules:6-11` `!!  DEPLOY REQUIRED  !!`; `KNOWN_ISSUES.md:67` BUG-33 "deployment to console pending" | Rules edited in-repo change nothing live. Live Firestore/Storage posture is **unknown**, and BUG-33 records that the previous live rule was an expired allow-all |
| REL-3.02 | **Fail** | `constants.dart:23-26` placeholder Razorpay key; `KNOWN_ISSUES.md:68` BUG-34 API-key restrictions "Open (console action required)" | No prod credential is in place or rotated |
| REL-3.03 | **Fail** (unverified) | No production service exists to have headroom; `nslookup` NXDOMAIN | Stated plainly as unverified rather than N/A, per the master rule |
| REL-3.04 | **Fail** | The checklist's own trap, met exactly: client hardcoded to `api.housepital.in/v1`; DNS does not resolve; `app_provider.dart:161-163` catches the failure and falls back to `DemoData` | **Silent failure by design.** The user sees a complete, plausible, entirely fabricated chart with no error. This is the single architectural decision from which most of this report follows |

### 4. Build provenance & signing

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-4.01 | **Fail** | Parsed `XCBuildConfiguration` blocks: the **Release** config (pbxproj:623-674) carries `CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"` — a *development* identity in the release configuration. No `ExportOptions.plist`, no `.mobileprovision` in repo. Android: `build.gradle.kts:32-37` `// TODO: Add your own signing config` + `signingConfig = signingConfigs.getByName("debug")` | iOS: automatic signing (`DEVELOPMENT_TEAM = 3M5BRKQ345` is present, which is the one positive signal) may override at archive time, but that is unverified and there is no recorded distribution path. **Android ships signed with the world-known Android debug keystore** — publicly available, identical on every developer machine on earth; any third party can sign a build that the Play Store and sideloaders will treat as an update to this app |
| REL-4.02 | **Fail** | `find ios -name "*.entitlements"` → **empty**. `grep -c UIBackgroundModes Info.plist` → **0** | No `aps-environment` entitlement ⇒ `firebase_messaging: ^15.2.5` (fully wired, `notification_router.dart` present) **cannot receive a push in production**. Capabilities do not match what is used, in the direction that silently disables a feature |
| REL-4.03 | **Fail** | `DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"` **is** set (pbxproj:472, 653) — so dSYMs are produced. But the 6 `shellScript` phases (pbxproj:295,311,333,350,366,387) are all Flutter/CocoaPods; **no `upload-symbols` phase**. Android: no Crashlytics Gradle plugin (N5) | *Round 3 reported "no dSYM, grep → 0"; that grep was case-sensitive. The correct statement is: symbols are **generated** and **never archived to the service that needs them**.* Every iOS crash arrives in Crashlytics unsymbolicated; Android arrives without mapping. Combined with REL-12.04 this means the first release is unobservable |

### 5. Privacy & compliance

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-5.01 | **Fail** | `curl` this round: `https://housepital.in/privacy` → **HTTP 000** (TLS failure); `https://www.housepital.in/privacy` → **200**. In-app links: `about_screen.dart:104` (privacy), `:98` (terms), `:110` (site), `referral_screen.dart:121`. `constants.dart:20` already holds the correct `www.housepital.in` | The in-app privacy link is dead on the apex host. Guideline 5.1.1 requires a functional privacy policy link; a reviewer tapping it gets a connection failure. **One-character fix in four files, using a constant already in the repo** |
| REL-5.02 | **Fail** (BLOCKED-OWNER) | No App Store Connect record exists (`git tag` empty, never uploaded) | App Privacy answers not submitted. Inventory needed: Health, Contact Info, User Content, Financial Info, Identifiers, Diagnostics |
| REL-5.03 | **Fail** | `grep -c ITSAppUsesNonExemptEncryption Info.plist` → **0** | **Every upload stalls in "Missing Compliance"** before review can begin. One plist key. Untouched for three rounds |
| REL-5.04 | **Fail** (BLOCKED-OWNER) | No age-rating questionnaire answered; no category set | Blocks submission mechanically |

### 6. Listing / launch assets

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-6.01 | **Fail** (BLOCKED-OWNER) | No metadata artefact anywhere: no `fastlane/`, no `metadata/`, no listing copy in `docs/`. Support **URL** does not exist (apex TLS 000) | See "The support-number question" — the in-app phone fix does not satisfy this |
| REL-6.02 | **Fail** (BLOCKED-OWNER) | `find . -ipath "*screenshot*"` → **nothing** | 6.7"/6.5" iPhone mandatory; 12.9" iPad also mandatory while `TARGETED_DEVICE_FAMILY = "1,2"`. Screenshots must not show the "Rajesh Kumar" record |
| REL-6.03 | **Warning** | All 15 PNGs present at correct dimensions; `sips`: `hasAlpha: no`, `space: RGB` → **passes ITMS-90717 upload validation**. But PIL bbox = **50.2 % / 63.9 %** canvas fill (typical marks 70–80 %); source is a crop of `assets/images/housepital_logo.png` (1200×312, i.e. a ~3.6× upscale of a 143×182 region); `grep -c appearances Contents.json` → 0 | The literal control is met — no missing asset. Graded Warning for the **4.0 (Design)** quality exposure on the most-scrutinised asset in the submission, not for a missing file. **BLOCKED-OWNER:** needs the designer's vector master. Full deliverable spec in round 3 §(d) |
| REL-6.04 | **N/A** | Control is marked "(Optional)" in the checklist; this release does not include a preview video | Rationale recorded |
| REL-6.05 | **Fail** | No "What's New" text exists. `docs/CHANGELOG.md` is developer-facing (it narrates audit rounds) | Authorable from the repo today; nobody has |

### 7. Reviewer / stakeholder notes

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-7.01 | **Fail** | No review-notes artefact in the repo | The app needs notes more than most: it is a **3.1.5(a) real-world-services** app taking payment outside IAP, and a reviewer needs that rationale stated |
| REL-7.02 | **Fail** | `splash_screen.dart:17` `pushReplacementNamed('/home')` with no auth gate — a reviewer gets in without credentials. But `firebase_service.dart:58` `verifyPhoneNumber` gates the real auth path and **no Firebase Auth test phone number is configured or documented** | A reviewer exercising sign-in hits a live Indian-SMS OTP flow they cannot complete. BLOCKED-OWNER (Firebase console) |
| REL-7.03 | **Fail** | No special-setup description; no second account documented for the family/caretaker role matrix that `lib/` implements | — |

### 8. Build & package

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-8.01 | **Fail** | Test/demo code is the **primary** shipping path, not a leftover: `lib/data/demo_data.dart`, `demo_articles.dart`, `staff_profile_screen.dart:43-130`'s `// Mock data for preview` block, `care_event.dart:44`'s synthetic adherence. `flutter analyze` clean (cited centrally) | The control's "no test/debug code shipped" is failed structurally, not incidentally |
| REL-8.02 | **Warning** (unverified) | `du -sh assets/` → **81 MB**, of which `assets/images/products` = **78 MB**. Carried-forward finding: ~40.3 MiB of that is unreferenced. No artifact has ever been produced, so "validates clean" is untested | Likely to approach the cellular-download threshold once linked. Cannot be measured without a build, which the brief forbids. OWNER-TBD |

### 9. Pre-ship QA

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-9.01 | **Fail** | Fresh install → `app_provider.dart:150-152` → `DemoData.patient` (Rajesh Kumar, 72, post-stroke, five named prescriptions incl. Insulin Glargine) | This is not "onboarding works". It is onboarding directly into a fabricated stranger's medical chart |
| REL-9.02 | **Warning** | Dark-mode and overflow guards exist (`test/widgets/dark_mode_test.dart`, `overflow_smoke_test.dart` at 320/375/414). Carried from the accessibility module: Dynamic Type clamped at 1.4×; white-on-orange 2.33:1 (**accepted owner risk**, not graded Fail per brief) | Largest-text and VoiceOver paths unverified on device. OWNER-TBD |
| REL-9.03 | **Fail** | The error path is `staff_profile_screen.dart:40-52` — on network failure it **synthesizes** `police_verified: true`, an Aadhaar document and a 4.8/142 rating (N1). Similarly `app_provider.dart:161+` synthesizes a patient | Error-path behaviour is not merely unacceptable, it is *affirmatively harmful*: the app's response to not knowing something is to assert it |
| REL-9.04 | **Fail** | `gh run list --limit 100` → **47 runs, 47 failures**, all annotated *"The job was not started because your account is locked due to a billing issue"* (N4). Durations 3–12 s | **The suite has never run in CI, on any commit, ever.** The 1,819-pass figure is a local claim with no independent attestation — and it is the number every other module in this suite leans on. BLOCKED-OWNER: unlock GitHub Actions billing |

### 10. Staged rollout

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-10.01 | **Fail** (BLOCKED-OWNER) | Never uploaded; no TestFlight build; no Play internal track (Android cannot be uploaded at all while signed with the debug keystore) | — |
| REL-10.02 | **Fail** | No release artifact has ever existed for a tester to install | — |
| REL-10.03 | **Fail** | The three prod-only features named by the control are precisely the three that cannot work: **payments** (placeholder key → simulated), **push** (no `aps-environment`), **sync** (NXDOMAIN) | Nothing in the app's networked behaviour has ever been exercised against production |

### 11. Submit / deploy & record

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-11.01 | **Fail** (BLOCKED-OWNER) | Never submitted | — |
| REL-11.02 | **Fail** | `git tag` → **empty**, four rounds running. No tagging process documented | Nothing binds a CHANGELOG entry, an audit, or a build number to a commit |
| REL-11.03 | **Warning** | **Improved.** `9127713` added `docs/CHANGELOG.md:3` "## 2026-08-03 — audit rounds 1–3 and the fixes they forced", narrating the round-3 repairs incl. the typed `PaymentFailure`. Still date-keyed; `git log --since=2026-08-03 \| wc -l` → 12; `9127713` itself is dated 2026-08-11, after the newest entry's date | Real movement from round 3's Fail (14 behind). Remaining gap: no version key and no tag, so the entry cannot be tied to an artifact. OWNER-TBD |
| REL-11.04 | **Warning** | **Improved.** `KNOWN_ISSUES.md:5` "Last updated: **2026-08-03** (audit round 3)" with an "Open — from the eleven-checklist audits" section; `9127713` added 44 lines | Documented, genuinely and for the first time since before round 1. **Not accepted** — no named authority has signed off, which v2.0 requires for any accepted risk. Also `:68` BUG-34 still names the non-existent `in.housepital.patient` (N5) |

### 12. Rollback / hotfix plan

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-12.01 | **Fail** | `grep -rn "remote_config\|RemoteConfig\|feature_flag\|killSwitch" lib/ pubspec.yaml` → **NONE** | No way to disable any feature without a full App Store release cycle (days). For an app that dials emergency numbers and takes payments, there is no way to turn either off |
| REL-12.02 | **Warning** | Store-level rollback (remove from sale / halt staged rollout) exists as a platform capability but is undocumented here, and there is no prior version to roll back **to** | First release has no rollback target by definition; the process should still be written down. OWNER-TBD |
| REL-12.03 | **Warning** | Client-side: `StoreMigrator` is at v2 with one shipped step, `quarantine()`-not-overwrite semantics, frozen literals, never stamps success on a failed step (CLAUDE.md contract), and `13e3656` added 106 lines of `test/services/store_migrator_test.dart`. **This is genuinely good work.** Server-side: `../housepital-backend` (Firebase+MySQL `housepital`) and `../housepital-api` (Laravel+MySQL `housepital_db`) define patients/staff/deployments/attendance/vitals with **mutually incompatible schemas**, and neither is deployed | Local-store rollback is sound and tested. Server schema rollback is unassessable because there is no deployed schema and two candidate schemas that disagree. OWNER-TBD |
| REL-12.04 | **Fail** | Crashlytics + Performance are initialized in Dart (`main.dart:117-132`, incl. `recordFlutterFatalError` and `PlatformDispatcher.instance.onError`) — the wiring is correct. But: no iOS `upload-symbols` phase (REL-4.03) ⇒ unsymbolicated iOS crashes; no Android Crashlytics/Perf Gradle plugin (N5) ⇒ no Android mapping upload; `google-services.json` package mismatch ⇒ adding the plugin breaks the build | The one observability control with real code behind it is defeated entirely by the two native build files nobody has opened. Post-release, nothing will be watchable |

### 13. Current Apple submission gate

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-13.01 | **Warning** (unverified) | No Xcode/SDK version pinned or recorded in the repo. `ENABLE_BITCODE = NO`, `SWIFT_VERSION = 5.0`, `IPHONEOS_DEPLOYMENT_TARGET` inherited from Flutter's xcconfigs | Cannot be verified from source; also "re-checked for this submission" is vacuously false since no submission is planned. Record the toolchain in `DEPLOYMENT_GUIDE.md`. OWNER-TBD |
| REL-13.02 | **Fail** | `find . -name PrivacyInfo.xcprivacy -not -path "./build/*"` → **only Pods'** (abseil, FirebaseCrashlytics, FirebaseMessaging, GoogleUtilities, gRPC, nanopb, leveldb, GTMSessionFetcher, …). **No app-target manifest** | The app itself uses required-reason APIs — `shared_preferences` → `NSUserDefaults` (category CA92.1) at minimum, plus file-timestamp APIs via `path_provider`/`pdf`. Undeclared ⇒ **ITMS-91053 at upload**. This is a mechanical upload blocker, like REL-5.03 |
| REL-13.03 | **Fail** | No privacy report generated or reviewed; no data inventory document exists to reconcile against | Depends on 13.02 and 5.02 |
| REL-13.04 | **Warning** | Third-party side looks satisfied: every Firebase/gRPC/Google pod observed carries a `PrivacyInfo.xcprivacy`. Signature verification is not possible from source | The gap is the app target (13.02), not the SDKs. Re-check on the first real archive. OWNER-TBD |
| REL-13.05 | **Fail** | No device-by-task accessibility test matrix exists anywhere in the repo | Accessibility Nutrition Label answers would be unsupported by evidence. Combined with the 1.4× Dynamic Type clamp, an honest label would have to decline several categories |
| REL-13.06 | **Fail** (BLOCKED-OWNER) | No questionnaire answered; no age-suitability URL | — |
| REL-13.07 | **Fail** (BLOCKED-OWNER) | EU DSA trader status not declared; territories not selected | If distribution is India-only this becomes narrower, but it is a decision nobody has made |
| REL-13.08 | **Warning** (BLOCKED-OWNER) | `DEVELOPMENT_TEAM = 3M5BRKQ345` is set in the Runner target for Debug, Release **and** Profile (pbxproj:683, 706, 500) — so an Apple Developer team **does** exist and is configured. Everything else (agreements, tax/banking, certificate validity, roles) is console state | The single most encouraging fact in this report: the account exists. OWNER-TBD to confirm agreements and banking are current |

### 14. Conditional App Review policy gates

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-14.01 | **Fail** | Re-verified verbatim from round 3: `delete_account_screen.dart:84` writes `housepital_pending_deletion` to `SharedPreferences`; three references in the whole tree (`:60` constant, `:84` write, `auth_provider.dart:233` preserve-list literal), **zero readers**. `grep -rn "reauthenticate\|requires-recent-login" lib/` → **NONE**, so `user.delete()` fails on any session older than ~5 minutes and the user is told to phone in a reference number that exists in no Housepital system | **5.1.1(v).** Round 3's characterisation stands unchanged: Apple's rejected contact-support pattern in the costume of a tracked request. Minimum fix, in order: (1) `reauthenticateWithCredential` retry on `requires-recent-login` — no backend needed, converts the common case from failure to success; (2) write to Firestore `deletion_requests/{uid}` (SDK already a dependency); (3) surface the record; (4) repoint `help_faq_screen.dart:157`'s conflicting "email us" story |
| REL-14.02 | **N/A** | Authentication is Firebase **phone OTP** only (`firebase_service.dart:58` `verifyPhoneNumber`, `:90` `signInWithCredential`). `grep -rn "google_sign_in\|GoogleAuthProvider\|facebook\|sign_in_with_apple" lib/ pubspec.yaml` → **NONE** | No qualifying third-party or social login is offered, so the Sign in with Apple equivalence requirement does not trigger. Rationale recorded |
| REL-14.03 | **Pass** | `grep -rn "firebase_analytics\|app_tracking\|AppTrackingTransparency\|NSUserTrackingUsageDescription" lib/ pubspec.yaml Info.plist` → **NONE** | No tracking, no attribution SDK, no ad SDK, no IDFA access. Nothing to consent to and nothing to mis-disclose. *(Crashlytics/Performance are diagnostics — they belong to REL-5.02's disclosure, not to tracking.)* **The only unqualified Pass in this audit** |
| REL-14.04 | **Warning** | Razorpay for home-healthcare services delivered in the physical world is permitted outside IAP under 3.1.5(a); no digital goods exist in the catalog. But the key is a placeholder (`constants.dart:23`) so the mechanism is simulated, and no review note states the rationale | Mechanism is *permitted* but *unproven*, and the reviewer is not told why IAP is absent. Pair with REL-7.01. OWNER-TBD |
| REL-14.05 | **N/A** | No StoreKit subscriptions. The ₹18,000–₹90,000/mo manpower packages are one-off cart purchases of a monthly service, not auto-renewing subscriptions (`service_booking_screen.dart` `_priceMultiplier`) | Rationale recorded |
| REL-14.06 | **Fail** | UGC exists and is user-submitted: `i_api_service.dart:92` `submitRating`, `:218` `submitEquipmentReview`, plus `chat_screen.dart` (patient↔staff messages) and concern photos (per `storage.rules` paths). `staff_profile_screen.dart:1080-1160` renders a reviews feed. `grep -rni "report abuse\|block user\|moderat" lib/` → **no true hits** | **1.2.** No filtering, no reporting, no blocking, no published moderation-response commitment. The one ingredient now present is published contact details — the real support number, courtesy of `13e3656`. Reviews about **named care workers**, with no report/block path, is the sharp end of this |
| REL-14.07 | **Warning** | `notification_preferences_screen.dart:59-62`: `notif_promotional`, `defaultValue: false`, toggleable ⇒ **opt-in with in-app opt-out satisfied**. But `:66-96` defines five `forced: true` prefs the user cannot disable, including `notif_vitals_red`. Lock-screen payload content is server-authored by a backend that does not exist | Marketing half: compliant, and well done. Sensitive-content half: unverifiable, and `notif_vitals_red` is by definition a clinical alert that cannot be turned off. OWNER-TBD once the backend exists |

### 15. Commercial and distribution readiness

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| REL-15.01 | **Fail** (BLOCKED-OWNER) | No price tier, tax category, availability, release method, phased-rollout or territory decision recorded anywhere | — |
| REL-15.02 | **Fail** | **(a) Regulated-service claims the app cannot support:** `staff_profile_screen.dart:52` `'police_verified': true` and `:59-60` an Aadhaar-Card document badge, fabricated on the shipping path for every staff member (N1). **(b) Trademarks/licensed media:** `assets/images/products` = 78 MB of product photography for third-party brands — `ResMed` ×29, `BPL` ×16, `Philips` ×12, `Tynor` ×153, `Vissco` ×7 — with no licensing record in the repo. **(c) Permits:** no documentation of the permissions required to dispense ventilators, BiPAP and oxygen concentrators to home users in Delhi NCR, and the clinical gate that exists is inverted (N2) | Three independent failures in one control. (a) is the most serious thing in this report: an unfounded criminal-background-check assertion about a named individual. (b) is a real IP exposure at 78 MB of scale. (c) is the regulated-domain module's territory but lands here for permits |
| REL-15.03 | **N/A** | No IAPs, subscriptions, in-app events, custom product pages or hosted assets are part of any submission | Rationale recorded; follows from 14.04/14.05 |
| REL-15.04 | **N/A** | Submission scope is iOS App Store. A `macos/` Flutter scaffold exists but no macOS artifact is built, notarized or distributed, and no macOS target exists in `Runner.xcodeproj` | Rationale recorded. Becomes applicable only if macOS distribution is ever chosen |
| REL-15.05 | **Fail** | No artifact, metadata snapshot, privacy answers, review notes, approval record or release decision has ever existed to archive | — |

---

## Scorecard

| Section | Pass | Warning | Fail | N/A |
|---|---|---|---|---|
| 1. Version & build | 0 | 2 | 1 | 0 |
| 2. Flags & configuration | 0 | 1 | 3 | 0 |
| 3. Backend / services prod-ready | 0 | 0 | 4 | 0 |
| 4. Build provenance & signing | 0 | 0 | 3 | 0 |
| 5. Privacy & compliance | 0 | 0 | 4 | 0 |
| 6. Listing / launch assets | 0 | 1 | 3 | 1 |
| 7. Reviewer / stakeholder notes | 0 | 0 | 3 | 0 |
| 8. Build & package | 0 | 1 | 1 | 0 |
| 9. Pre-ship QA | 0 | 1 | 3 | 0 |
| 10. Staged rollout | 0 | 0 | 3 | 0 |
| 11. Submit / deploy & record | 0 | 2 | 2 | 0 |
| 12. Rollback / hotfix plan | 0 | 2 | 2 | 0 |
| 13. Apple submission gate | 0 | 3 | 5 | 0 |
| 14. Conditional policy gates | 1 | 2 | 2 | 2 |
| 15. Commercial & distribution | 0 | 0 | 3 | 2 |
| **TOTAL (63 controls)** | **1** | **15** | **42** | **5** |

**BLOCKED-OWNER: 12** (5.02, 5.04, 6.01, 6.02, 6.03, 9.04, 10.01, 11.01, 13.06, 13.07, 13.08, 15.01)
— counted inside the grades above, not in addition.

**Comparability with round 3:** round 3 scored 3 ✅ / 16 ⚠️ / 25 ❌ / 1 N/A on a bespoke 45-item
basis. This round grades the **63 published v2.0 REL controls**, so the totals are not
comparable. The comparable measure is the Prior-round table: **of 22 tracked round-3 findings,
one closed (H15), two improved within Warning (CHANGELOG, KNOWN_ISSUES), nineteen are unchanged,
and none regressed.**

**One-glance gate:** tests **Fail** (1,819 pass locally; CI has never executed a step) · no QA
flag on **Fail** (demo mode is the only mode) · prod backend ready **Fail** (NXDOMAIN) · privacy
URL + disclosure **Fail** (apex TLS 000; nothing submitted) · build id bumped **Warning**
(`1.0.0+1`, four rounds) · clean-install QA **Fail** (fabricated patient + fabricated
police-verification) → **DO NOT SHIP.**

---

## Release blockers (every Fail)

**Tier A — mechanical upload blockers. The build cannot reach a human reviewer until these are fixed. Half a day, no decisions needed.**

1. **REL-5.03** `ITSAppUsesNonExemptEncryption` missing → every upload stalls in Missing Compliance. One plist key.
2. **REL-13.02** No app-target `PrivacyInfo.xcprivacy` → ITMS-91053 at upload. One file; `shared_preferences`/`path_provider` reasons are documented by Apple.
3. **REL-4.01** iOS Release config signs with `"iPhone Developer"`; Android Release signs with the **debug keystore**. Android cannot be uploaded at all.
4. **REL-4.02** No `.entitlements` ⇒ no `aps-environment` ⇒ push is dead in production despite being fully wired.

**Tier B — App Review rejection grounds. These get the build rejected after upload.**

5. **REL-2.02 / REL-9.01** Demo patient seeds on every fresh install, ungated (`app_provider.dart:150-152`). **2.1.** Fourth round untouched. This is still the single item that unblocks the most.
6. **REL-15.02(a) / REL-9.03** `staff_profile_screen.dart:52` fabricates `'police_verified': true` plus an Aadhaar document and a 4.8/142 rating on the **only reachable path**, with no `DemoMode` label. **1.4.1 / 5.1.2.** *New this round; in my assessment the most rejectable single line in the codebase.*
7. **REL-14.01** `/delete-account` initiates nothing and usually fails to delete the credential (no re-auth). **5.1.1(v).**
8. **REL-5.01** Privacy Policy and Terms links fail TLS on the apex host (`about_screen.dart:98,104,110`, `referral_screen.dart:121`). Four `www.` prefixes, using a constant already in the repo.
9. **1.4.1 bundle — the fabricated-clinical-content cluster.** The handover PDF's adherence figure is `80 + ((day * 7 + weekday * 3) % 21)` (`care_event.dart:44`) printed at 10 pt bold to a physician above an 8 pt disclaimer (`handover_report_service.dart:118,138,205`); the assistant routes "bleeding ho raha hai" to attendance (`assistant_service.dart:169`); no medical disclaimer exists anywhere in the UI (grep → zero hits).
10. **REL-14.06** User-submitted ratings and reviews about **named care workers** with no report, block, filter or moderation path. **1.2.**

**Tier C — process and safety-net Fails.**

11. **REL-9.04** CI has never executed a step: 47 runs, 47 billing-locked failures. No test result in this entire audit suite has independent attestation.
12. **REL-12.04 + REL-4.03** Crashlytics/Performance correctly initialized in Dart, then defeated by the absence of an iOS `upload-symbols` phase and the Android Gradle plugins. The first release would be unobservable.
13. **REL-12.01** No remote config or feature flag. No way to disable payments, the assistant, or anything else without a full store release.
14. **REL-3.01 / REL-3.02** `storage.rules` and `firestore.rules` undeployed; API-key restrictions Open; Razorpay key is a placeholder.
15. **REL-3.04** The client points at a production host that does not resolve, and the failure mode is silent fabrication.
16. **REL-1.03** Version string in three places; `package_info_plus` absent.
17. **REL-6.02 / REL-6.05 / REL-7.01–7.03 / REL-11.01 / REL-11.02 / REL-15.05** Listing assets, release notes, reviewer notes, tags and the submission archive: all absent.
18. **REL-15.02(b)** 78 MB of third-party-brand product photography (ResMed, Philips, BPL, Tynor, Vissco) with no licensing record.
19. **REL-13.03 / REL-13.05 / REL-13.06 / REL-13.07 / REL-5.02 / REL-5.04 / REL-15.01** Privacy report, accessibility label evidence, age rating, DSA trader status, App Privacy answers, category and commercial setup: all unanswered.
20. **REL-2.01 / REL-2.03 / REL-8.01 / REL-10.01–10.03** No flag hygiene; dev endpoints; demo code as the primary path; no beta channel and no prod-feature verification.

---

## Warnings requiring risk acceptance

Each needs impact, owner, due date, mitigation and a named approver before any ship decision.

| # | Control | Impact | Mitigation | Owner / due |
|---|---|---|---|---|
| W1 | REL-1.01, 1.02 | Version/build constant across four rounds | Bump both before first archive | OWNER-TBD / pre-upload |
| W2 | REL-2.04 | 34 `debugPrint` calls ship in release, some interpolating exceptions | Wrap in `kDebugMode` or route to a logger | OWNER-TBD / Phase 4 |
| W3 | REL-6.03 | Icon passes upload validation but is a ~3.6× raster upscale at 50.2 % canvas fill, no iOS 18 variants — a visible 4.0 quality signal | Designer's vector master; regenerate all 15 at ~72 % fill. **BLOCKED-OWNER** | Designer / Phase 2 |
| W4 | REL-8.02 | 81 MB assets (78 MB products, ~40.3 MiB unreferenced); artifact never validated | Prune unreferenced assets; measure a real archive | OWNER-TBD / Phase 4 |
| W5 | REL-9.02 | Dynamic Type clamped 1.4×; white-on-orange 2.33:1 (**accepted owner decision**) | Device pass with largest text + VoiceOver | OWNER-TBD / Phase 2 |
| W6 | REL-11.03 | CHANGELOG now current in substance but date-keyed with no tag to bind it | Version-key it; tag `v1.0.0` | OWNER-TBD / Phase 4 |
| W7 | REL-11.04 | Known issues genuinely documented; **not accepted by any named authority** | Owner signs the KNOWN_ISSUES open list | **Named approver required** / pre-ship |
| W8 | REL-12.02 | Rollback path undocumented; no prior version to roll back to | Write the runbook | OWNER-TBD / Phase 4 |
| W9 | REL-12.03 | Client `StoreMigrator` sound and tested; two backend schemas mutually incompatible and neither deployed | Pick one backend schema before any prod write | OWNER-TBD / Phase 3 |
| W10 | REL-13.01 | Toolchain not pinned or recorded | Record Xcode/SDK in `DEPLOYMENT_GUIDE.md` | OWNER-TBD / pre-upload |
| W11 | REL-13.04 | Pod privacy manifests present; signatures unverifiable from source | Re-check on first real archive | OWNER-TBD / pre-upload |
| W12 | REL-13.08 | Apple team `3M5BRKQ345` configured; agreements/tax/banking unverified | Console check. **BLOCKED-OWNER** | Owner / pre-upload |
| W13 | REL-14.04 | Razorpay-outside-IAP is permitted but unproven and unexplained to the reviewer | Live key + 3.1.5(a) rationale in review notes | OWNER-TBD / Phase 3 |
| W14 | REL-14.07 | Marketing push correctly opt-in; five forced prefs incl. `notif_vitals_red`; lock-screen content unverifiable | Verify payloads once the backend exists | OWNER-TBD / Phase 3 |
| W15 | **N5 (spans 4.03/12.04)** | `google-services.json` names `com.housepital.patient`; applicationId is `com.housepital.housepital_patient`; iOS is `com.housepital.housepitalPatient`; BUG-34 says `in.housepital.patient` | Reconcile to one Android identity **before** adding the Crashlytics plugin, or the build breaks | OWNER-TBD / Phase 0 |

---

## BLOCKED-OWNER — needs access I do not have

Nothing on round 3's list moved. Additions marked **NEW**.

1. **Apple Developer enrolment + App Store Connect app record** — bundle `com.housepital.housepitalPatient` (pbxproj:690). Team `3M5BRKQ345` exists, which is the one piece already in hand.
2. **Privacy policy live at `https://www.housepital.in/privacy`** covering phone, health data, prescription/report photographs, home address, Razorpay payment data, Crashlytics/Performance diagnostics, and — if `ASSISTANT_API_URL` is set — that assistant messages reach a third-party AI provider. **Plus: fix TLS on the apex host**, or accept `www.` everywhere.
3. **Support URL** (a URL, not a phone number) and **marketing URL**.
4. **App Store screenshots** — 6.7"/6.5" iPhone mandatory; 12.9" iPad also mandatory unless `TARGETED_DEVICE_FAMILY` drops to `"1"`. Must not show the Rajesh Kumar record.
5. **Listing copy** — name, subtitle, description, keywords, promotional text; no diagnostic or treatment claims.
6. **Age-rating questionnaire** — answer "Medical/Treatment Information" honestly.
7. **Category** — Primary: Medical; Secondary: Health & Fitness.
8. **App Privacy nutrition-label answers** — Health, Contact Info, User Content, Financial Info, Identifiers, Diagnostics, with linkage and purpose per category.
9. **Real Razorpay `rzp_live_…` key** via `--dart-define`, after KYC.
10. **Production backend** — stand up `api.housepital.in/v1` or repoint `apiBaseUrl`. Plus three console deploys: `firebase deploy --only firestore:rules`, `--only storage`, API-key restrictions. **Decide which of the two incompatible backend schemas is canonical first.**
11. **APNs `.p8` key** uploaded to Firebase, after Push is enabled in Xcode.
12. **Firebase Auth test phone number**, quoted in the review notes.
13. **Export-compliance decision** — confirm HTTPS-only standard encryption.
14. **Business decision: iPad and landscape in or out?** Two-line change.
15. **Business decision: does Sahayak ship in 1.0?** If yes it needs an AI disclaimer, a privacy disclosure, and an emergency/medical intent that fires before `din`.
16. **Designer's vector of the Housepital mark** — full spec in round 3 §(d).
17. **Deletion-request destination** — Firestore `deletion_requests/{uid}` needs no new infrastructure.
18. **Device check on `tel:` + `LSApplicationQueriesSchemes`** — or skip it and add the four plist strings.
19. **NEW — Unlock GitHub Actions billing.** 47 consecutive runs have failed before starting. Until this is fixed, no test claim in this audit suite — including the 1,819 figure — has any independent attestation. *This is a payment, not an engineering task, and it invalidates the evidence base of eleven other modules.*
20. **NEW — Ruling on the police-verification claim.** Does Housepital actually run police verification and hold Aadhaar copies for deployed staff? If yes, the data must come from a system, not a `catch` block. If no, `staff_profile_screen.dart:43-130` must be deleted, not labelled. **This is a legal question about a claim made concerning real named individuals, and it needs an owner's answer before either fix is written.**
21. **NEW — Licensing for third-party product photography** — 78 MB across ResMed, Philips, BPL, Tynor, Vissco. Confirm distribution rights or replace.
22. **NEW — Regulatory permits** for home dispensation of ventilators, BiPAP and oxygen concentrators in Delhi NCR (REL-15.02(c)).

---

## Ordered runway to submission (updated for round 4)

**Phase 0 — half a day, mechanical, no decisions. Every value already exists in the repo.**
Round 3 wrote this phase and none of it was done. It is unchanged, plus three additions:

`ITSAppUsesNonExemptEncryption` · **`PrivacyInfo.xcprivacy` in the app target (NEW — same class of
one-file upload blocker)** · `CFBundleLocalizations` (en, hi) · `LSApplicationQueriesSchemes`
(tel, sms, mailto) · `www.` on the four apex URLs (`about_screen.dart:98,104,110`,
`referral_screen.dart:121`) · `TARGETED_DEVICE_FAMILY = "1"` + portrait lock ·
`LaunchScreen.storyboard:22` → brand orange · `IgnorePointer` around the demo pill · move
`markServingDemoData` out of `buildHandoverPdf` · wire the three unwired `DemoMode` sources and
add `markServingLiveData` to the seven that latch · **reconcile the four app identities and fix
BUG-34's package name (NEW — must precede the Crashlytics plugin)** · **delete
`staff_profile_screen.dart:43-130`'s mock block and show an honest error state (NEW — one
deletion retires the report's worst finding).**

**Phase 1 — review-compliance work (a few days), in this order:**
1. **Gate the seed.** `const bool.fromEnvironment('DEMO_DATA')` defaulting `false` on `app_provider.dart:150-152` and the parallel site, plus honest empty states. *Still the one that unblocks the most.*
2. **Guard the handover export** — refuse when no real patient record has loaded; band conditional and ≥12 pt; **and remove the computed adherence figure entirely, or drive it from a real medication log.**
3. **Finish `/delete-account`** — `reauthenticateWithCredential` on `requires-recent-login`, then a Firestore `deletion_requests/{uid}` write with the local record demoted to an outbox that flushes.
4. **Medical disclaimer** on vitals and daily reports; AI notice on Sahayak; **an emergency/medical-urgency intent at the TOP of `assistant_service.dart`'s matcher, before `din` can eat "bleeding".**
5. **UGC controls** — report/block on reviews and chat, and a published moderation-response commitment (1.2).
6. Enable Push in Xcode + `UIBackgroundModes` + `.entitlements`; add the iOS `upload-symbols` phase and the Android Crashlytics/Perf Gradle plugins.
7. **Fix the `needsAssessment` inversion** — gate on device class, not on `availableForRent`.

**Phase 2 — assets and owner decisions (parallel with Phase 1).**
Designer's vector → regenerate all 15 icons at ~72 % fill (+ optional iOS 18 dark/tinted) ·
iPad/landscape decision · Sahayak decision · privacy-policy content · **the police-verification
ruling** · **product-photography licensing.**

**Phase 3 — the real dependencies (owner-led, longest lead time).**
**Unblock GitHub Actions billing — do this first; it costs money, not engineering, and everything
downstream is unattested without it.** Then: choose one backend schema and stand up
`api.housepital.in/v1` (or repoint `apiBaseUrl`) · `firebase deploy --only firestore:rules` and
`--only storage` · API-key restrictions (after the identity reconciliation) · a real Android
release keystore · Razorpay KYC and a live key · Firebase test phone number · APNs `.p8`.

**Phase 4 — release hygiene, then ship.**
`firebase_remote_config` with `assistant_enabled` / `payments_enabled` / `force_upgrade` ·
`package_info_plus` and delete the two hardcoded version literals · CHANGELOG version-keyed ·
KNOWN_ISSUES signed by a named approver · a widget test for the demo notice · tag `v1.0.0` ·
archive with distribution signing and a bumped build number · **TestFlight internal first** ·
then submit with review notes covering the 3.1.5(a) rationale, the test phone number, the
disclaimer placement, and the second account for role testing.

---

## Limitations of this audit

- **MASTER-4.04 is not met and cannot be met here.** This is a **source review**. No release
  artifact has ever been produced for this app, so no evidence comes from an artifact or a
  production-like environment. `flutter build`, `flutter test`, `flutter clean` and `pod install`
  are forbidden by the brief because concurrent agents corrupt each other's runs.
- **Twelve controls are BLOCKED-OWNER**, requiring App Store Connect, the Firebase console, the
  GitHub billing settings, a designer, or a physical device. They are graded Fail or Warning with
  the blocker named — never N/A.
- **The 1,819-test figure is cited, not verified**, and N4 shows it has never been verified by
  anyone: CI has failed 47/47 times before starting. I read test *sources* where relevant.
- **`LSApplicationQueriesSchemes` remains unresolved on the runtime question**, exactly as round 3
  left it. I did not run a device check and will not claim one. The fix is four plist strings and
  costs nothing; add it regardless of which way the runtime falls.
- **Android is graded but is not the stated submission target.** Its findings (debug keystore,
  missing Gradle plugins, `google-services.json` mismatch) are recorded because they defeat
  crash observability for the whole product and because REL-4.01 is platform-agnostic.
- **`../housepital-backend` and `../housepital-api` were consulted for REL-3.x and REL-12.03**
  only to the extent of confirming that two incompatible schemas exist and neither is deployed.
  A schema-level reconciliation is the Web/API module's ground.
- **Owner decisions are reported as accepted risk, never graded Fail:** white-on-orange (2.33:1),
  manpower prices shown and directly bookable, the floating glass pill nav.
- **`ANTHROPIC_API_KEY` re-verified absent** from `lib/` and from tracked config. Server-side only,
  as recorded.
- **Numeric discrepancy declared:** the brief cited 17 oxygen concentrators; my case-insensitive
  count over the shipped `assets/equipment_catalog.json` is **16**, all rentable and all exempt.
  I report my own measurement.
- **Round 3 correction:** round 3 recorded "no dSYM, `grep -cE` → 0". That grep was
  case-sensitive; `DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"` **is** set at pbxproj:472 and
  653. The finding survives in a sharper form (symbols are generated and never uploaded), but the
  round-3 evidence line was imprecise and is corrected here.
