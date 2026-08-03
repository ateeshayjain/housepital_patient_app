# Post-Launch Operations Checklist (App-Agnostic) — Audit round 2 vs commit `820060b`

**Date:** 2026-08-03 · **Previous round:** commit `803124d` · **Branch:** `fix/five-tab-nav`
**Auditor:** post-launch-ops agent · **Repo:** `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`

The app has **not launched**. Every item is graded as *readiness to operate on day 1*, not as
operational history. "No crash reports reviewed yet" is not a failure; "no working way to review
them" is.

---

## Changed since round 1

| Round-1 finding | Status now | Evidence |
|---|---|---|
| B1 · Clinical demo data silently substituted | ⚠️ **partially fixed — coverage is incomplete and the flag is racy** | `lib/data/demo_mode.dart:14-27` + banner `lib/screens/main_shell.dart:64,132-172`; 6 of 6 API providers mark, but **11 further demo-serving sites do not** and the banner does not render on pushed routes. See §A. |
| B2 · Placeholder support numbers | ❌ **unchanged** | `lib/screens/settings/help_faq_screen.dart:352` `tel:+919999999999`, `:365` `wa.me/919999999999`; `lib/screens/my_care/staff_otp_verification_screen.dart:352` `tel:+918888888888` |
| B3 · Android release signed with the DEBUG keystore | ❌ **unchanged (re-verified)** | `android/app/build.gradle.kts:33-37` `signingConfig = signingConfigs.getByName("debug")`; `android/key.properties` does not exist (`ls` → No such file) |
| B4 · Payments never verified server-side | ✅ **genuinely fixed** | `lib/screens/billing/payment_screen.dart:226-252` calls `createOrder` and **fails closed** when it returns null; `lib/services/payment_service.dart:163-180` `skippedDemo` only succeeds when `isDemoPayments` |
| B5 · Auth gate disabled | ❌ **unchanged (re-verified)** | `lib/main.dart:416-418` `// NOTE: Auth gate disabled for demo mode. Enable before production release.` → `home: const SplashScreen()`; `lib/screens/splash_screen.dart:15-18` pushes straight to `/home` |
| B6 · No iOS dSYM upload phase | ❌ **unchanged** | `ios/Runner.xcodeproj/project.pbxproj:280-390` — six `PBXShellScriptBuildPhase` entries, none is Crashlytics `upload-symbols` |
| B7 · iOS crashes on camera/photo | ✅ **fixed** | `ios/Runner/Info.plist:73-76` `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` now present |
| H8 · Zero analytics | ❌ **unchanged** | `grep -rniE "firebase_analytics\|logEvent\|amplitude\|mixpanel"` over `lib/ functions/ pubspec.yaml` → **no matches** |
| H9 · No flag / kill switch / force-upgrade | ❌ **unchanged** | `grep -rniE "remote_config\|killSwitch\|forceUpgrade\|minimumVersion\|maintenanceMode"` over `lib/ functions/ pubspec.yaml` → **no matches** |
| H10 · Non-fatals never reported (`logger.dart:63`) | ❌ **unchanged** | `lib/utils/logger.dart:63-65` TODO still verbatim. Every `Log.warn`/`Log.error` — including the new `StoreMigrator` failure paths — stops at `debugPrint` |
| H11 · Android `<queries>` missing for `tel:`/`mailto:`/`https:` | ❌ **unchanged** | `android/app/src/main/AndroidManifest.xml:43-48` — only the `PROCESS_TEXT` intent |
| H12 · Background-isolate errors uncaptured | ❌ **unchanged** | `grep -rn "addErrorListener" lib/` → no matches |
| H13 · No account/data deletion path | ⚠️ **screen shipped, obligation lands nowhere** | `lib/screens/settings/delete_account_screen.dart` + `lib/main.dart:745` + `lib/screens/settings/settings_screen.dart:276-278`. The 30-day promise is delivered by a `Future.delayed(600ms)`. See §C. |
| H14 · Server-side prerequisites unverified | ❌ **unchanged, and one more added** | `.firebaserc` still `{"projects":{},"targets":{},"etags":{}}`; `docs/KNOWN_ISSUES.md:25` BUG-33 rules deploy still pending; `:26` BUG-34 still Open; **new**: `storage.rules` + `firebase.json` `storage` block added but undeployed. See §D. |
| H15 · No user-symptom playbooks | ❌ **unchanged** | `docs/TROUBLESHOOTING.md` headings at `:9,99,129,180,226,251,316,384,420,435,482` are all developer-facing |
| M16 · Hardcoded version, no build number | ❌ **unchanged** | `lib/screens/settings/about_screen.dart:11,69`; `lib/screens/settings/settings_screen.dart:258`; `package_info_plus` absent from `pubspec.yaml` |
| M17 · No in-app "What's new" | ❌ **unchanged** | `grep -rni "what's new\|changelog"` over `lib/ assets/i18n/` → no matches |
| M18 · `KNOWN_ISSUES.md` stale | ❌ **unchanged** | `docs/KNOWN_ISSUES.md:5` still "Last updated: 2026-05-28 (audit batch 4)"; `:53` BUG-14 still claims the invoice PDF is a stub |
| M19 · `DEPLOYMENT_GUIDE.md` drift | ❌ **unchanged** | `docs/KNOWN_ISSUES.md:26` still instructs restricting package `in.housepital.patient`; real id is `com.housepital.housepital_patient` (`android/app/build.gradle.kts:23`) |
| M22 · Severity ladder / SLA inert | ❌ **unchanged** | `docs/KNOWN_ISSUES.md:90` TD-11; `lib/config/constants.dart:52-57` |
| §6.1(c) · No app-side schema stamp | ✅ **fixed** | `lib/services/store_migrator.dart:33,35` `currentVersion = 1` / `housepital_schema_version`, run at `lib/main.dart:174` — but see §B for its operational risk |

**Net:** 3 of 23 tracked items genuinely fixed (payments, iOS camera strings, schema stamp).
1 partially fixed (demo banner). 1 new-code risk introduced (`StoreMigrator`). 1 new obligation
created with no receiver (account deletion). Nothing regressed in the sense of previously-working
code breaking.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Release mechanics | 0 | 3 | 2 | 1 |
| 2. Monitoring cadence | 0 | 1 | 3 | 0 |
| 3. Incident response | 0 | 3 | 2 | 0 |
| 4. Support readiness | 0 | 1 | 3 | 1 |
| 5. Feedback → roadmap | 0 | 3 | 1 | 0 |
| 6. Data stewardship | 1 | 2 | 1 | 0 |
| **Total (28)** | **1** | **13** | **12** | **2** |

Round 1 was 1 ✅ / 11 ⚠️ / 14 ❌ / 2 N/A. Two ❌ moved to ⚠️ (§2.3 demo signal now partially
exists; §6.3 deletion path now partially exists). Nothing moved to ✅.

---

## Findings

### 1. Release mechanics (before pressing the button)

- ❌ **Phased release ON unless there is a written reason.** — evidence: `android/app/build.gradle.kts:33-37`
  still signs release with the debug keystore and `android/key.properties` does not exist. A
  debug-signed AAB is rejected at upload, so there is no Play track to stage. No `fastlane/`, no
  release job in `.github/workflows/ci.yml` (analyze → design gate → test → coverage only).
  **Impact:** the rollback lever named at `docs/DEPLOYMENT_GUIDE.md:479` ("Use Google Play Console
  staged rollout, halt rollout") does not exist for Android. **Fix:** add `android/key.properties`
  + a real `signingConfigs.release`. **BLOCKED-OWNER** for the store-side toggle.

- ⚠️ **Halt criteria decided IN ADVANCE.** — evidence: `grep -n "halt\|Halt" docs/DEPLOYMENT_GUIDE.md`
  returns exactly one line, `:479`, and it names the *mechanism*, not a threshold. The alerting
  numbers in §7a.5 are console configuration written as future work. Nothing states what pauses a
  rollout. **Fix:** a 4-line block in §9 — halt if crash-free sessions < 99.0%, or ≥3 independent
  reports of wrong medication/vitals, or any payment captured without a backend record.

- ⚠️ **The rollback story for THIS release is named.** — unchanged from round 1 and now
  measurably worse in one respect: the release adds `StoreMigrator` (§B), which writes a version
  stamp on first run. A user who installs v1 and is then rolled back has a stamp the older binary
  handles correctly (`store_migrator.dart:83-93` leaves newer stores alone — good), but there is
  still **no flag to flip**: `grep -rniE "remote_config|killSwitch|forceUpgrade|maintenanceMode"`
  over `lib/`, `functions/`, `pubspec.yaml` → no matches. The triad reduces to "halt the phase
  (Android, once signing is fixed) or hotfix".

- ❌ **Server-side prerequisites verified done — not remembered as done.** — evidence: three
  prerequisites are recorded as pending and a fourth was added this round:
  - `docs/KNOWN_ISSUES.md:25` BUG-33 — hardened `firestore.rules` "deployment to console pending".
  - `docs/KNOWN_ISSUES.md:26` BUG-34 — API key restrictions "Open (console action required)".
  - **New:** `storage.rules` exists and `firebase.json` now carries `"storage": {"rules": "storage.rules"}`,
    but nothing in the repo shows a deploy. See §D.
  - `.firebaserc` is still `{"projects":{},"targets":{},"etags":{}}`, so every `firebase deploy`
    in this repo fails without an explicit `--project housepital-patient` — including the command
    `storage.rules:10` tells the operator to run.
  **Fix:** `firebase use --add housepital-patient`, then paste `firebase firestore:rules get` and
  the Storage rules console timestamp into `KNOWN_ISSUES.md` before release.

- ⚠️ **Release notes are honest.** — unchanged. `docs/CHANGELOG.md` is engineer-facing (its newest
  entry, `:7`, is dated 2026-06-13 and headed with a commit SHA). No `docs/RELEASE_NOTES.md`
  exists. No "update-together" callout, which matters because this app reads staff-app writes via
  `lib/services/sync_service.dart`. **BLOCKED-OWNER** for the store listing text.

- N/A **Previous release's archive retained and installable.** — no prior release
  (`pubspec.yaml:4` `version: 1.0.0+1`). **BLOCKED-OWNER** to confirm archive retention from
  build 1.

---

### 2. Monitoring cadence (no telemetry required)

- ❌ **Crash reports checked DAILY with a written trigger threshold.** — the capture matrix is
  unchanged from round 1 and still fails on the primary platform:

  | Error class | Captured? | Evidence |
  |---|---|---|
  | Flutter framework errors | ✅ | `lib/main.dart:115-116` |
  | Async errors, root isolate | ✅ | `lib/main.dart:117-120` |
  | Uncaught zone errors | ✅ | `lib/main.dart:100` `runZonedGuarded` |
  | Background/spawned isolate errors | ❌ | no `addErrorListener` in `lib/` |
  | Non-fatal handled failures | ❌ | `lib/utils/logger.dart:63-65` TODO |
  | iOS symbolication | ❌ | no `upload-symbols` phase in `ios/Runner.xcodeproj/project.pbxproj:280-390` |
  | Android mapping upload | ❌ | `com.google.firebase.crashlytics` absent from `android/app/build.gradle.kts:1-6` |
  | Web | N/A by design | `lib/main.dart:111` `if (!kIsWeb)` — correct axis |

  **Newly aggravated:** `StoreMigrator` (this release's riskiest new code, §B) reports failure
  exclusively through `Log.warn`/`Log.error` — `store_migrator.dart:75,88,103,109,142`. Every one
  of those lands in the dead chokepoint at `logger.dart:63`. A migration that quarantines or fails
  on a user's phone produces **zero** signal anywhere the team can see. The one-line fix in
  `logger.dart` is now worth strictly more than it was in round 1.
  **BLOCKED-OWNER** for console alert configuration and the person who reads it each morning.

- ❌ **Store reviews and beta feedback read on a schedule.** — unchanged: no triage doc, no
  reply template, no rota. `docs/` gained nothing this round (`ls docs/` shows the same 15 files
  plus `audits/`). **BLOCKED-OWNER.**

- ⚠️ **User-visible failure surfaces are treated as monitoring.** — upgraded from ❌. A failure
  surface now exists: the sample-data banner at `lib/screens/main_shell.dart:64,132-172`. It is
  correctly non-dismissible and its copy is honest ("Showing sample data — we can't reach
  Housepital right now, so this is not your live record."). It is **not yet trustworthy** as a
  monitoring signal because it both under- and over-reports — see §A. Week-one attention must
  include asking testers *when* they saw it, not just whether.

  Secondary risk on the same widget: the banner is a `Column` child above the `IndexedStack`
  (`main_shell.dart:58-70`) and takes the status-bar inset itself via `SafeArea(bottom: false)`.
  Each root screen below it still reserves `MediaQuery.padding.top + kToolbarHeight` per the
  glass-chrome contract, and `MediaQuery` is not re-scoped, so while the banner is visible every
  root tab is pushed down by roughly the status-bar height twice. Cosmetic, but it appears
  precisely when the app is already degraded — verify on a notched device before release.

- ❌ **A "first 48 hours" smoke pass on a production install.** — unchanged. No `docs/SMOKE_PASS.md`;
  `test/screens/overflow_smoke_test.dart` is a widget test, not a device pass. **BLOCKED-OWNER** to run.

---

### 3. Incident response

- ⚠️ **A severity ladder exists and is written down.** — unchanged. `docs/KNOWN_ISSUES.md:19,31,47,63`
  are launch-priority buckets, not incident severities keyed to user harm. No S1 "wrong dosage /
  wrong vitals / wrong patient displayed" tier — which §A shows is now a live class of incident.

- ⚠️ **Each severity has a target response.** — unchanged. `lib/config/constants.dart:52-57`
  `concernSla` is a constant no clock enforces (`docs/KNOWN_ISSUES.md:90` TD-11).

- ❌ **Known-issue communication path exists.** — unchanged. No review-reply, TestFlight-notes, or
  support-reply template anywhere in `docs/`.

- ❌ **Expedited-review criteria known in advance.** — unchanged. No mention in
  `docs/DEPLOYMENT_GUIDE.md`.

- ⚠️ **Post-incident: the cause becomes a checklist line or a test.** — the practice is real and
  visible in this round's commit: `lib/providers/my_care_provider.dart:91-98` still carries its
  field report, and `test/providers/patient_scope_isolation_test.dart:172-189` pins the demo-banner
  behaviour. But the practice was applied **thinly** to the new code: across the whole `test/` tree
  (103 files), `grep -rln "DemoMode\|StoreMigrator\|DeleteAccount"` returns exactly **one** file,
  and it exercises only `AppProvider`'s dashboard path. There is **no test at all** for
  `StoreMigrator` (a cold-start-blocking migration engine), **no test** for
  `DeleteAccountScreen`, and **no widget test** asserting `_DemoDataBanner` actually renders in
  `MainShell` — `test/screens/main_shell_test.dart` never mentions it.
  `docs/KNOWN_ISSUES.md:39` BUG-07 still lists 3 failing widget tests as "cause unknown" while the
  central result for this commit is 1,797 passing — the tracker entry is stale either way.

---

### 4. Support readiness

- ❌ **The support channel published in the store listing is real, monitored, and answered within a
  stated window.** — **re-verified unchanged, still a blocker.**
  - `lib/screens/settings/help_faq_screen.dart:352` — `_launchUrl('tel:+919999999999')`
  - `lib/screens/settings/help_faq_screen.dart:365` — `https://wa.me/919999999999?text=…`
  - `lib/screens/my_care/staff_otp_verification_screen.dart:352` — `tel:+918888888888`

  The real number is one import away — `lib/config/constants.dart:19` `supportPhone = '9990911911'`,
  used correctly by SOS (`sos_screen.dart:66`), Home (`home_screen.dart:821,874`), Care Team
  (`care_team_screen.dart:41,54,70`) and article footers (`article_detail_screen.dart:305`).
  **Compounding, also unchanged:** `android/app/src/main/AndroidManifest.xml:43-48` declares only a
  `PROCESS_TEXT` `<queries>` block, so on API 30+ `canLaunchUrl` returns false for `tel:`,
  `mailto:` and `https:` and the entire non-SOS support surface degrades to its failure branch.

  **New this round:** `delete_account_screen.dart:78` and `:181` publish `9990-911-911` as the
  contact for cancelling a deletion and for closing a running service — the correct number, but
  hand-typed in a third format rather than derived from `AppConstants.supportPhone`. Three
  literals now exist for one number.

- ❌ **Diagnostic playbooks exist for the top three failure symptoms of THIS app.** — unchanged;
  `docs/TROUBLESHOOTING.md` is entirely developer-facing. §A makes this worse, not better: the
  banner gives support a *question to ask* ("do you see an orange strip at the top?") but no
  document tells anyone to ask it, and §A.2 shows the answer can be "no" while the data on screen
  is still sample data.

- ⚠️ **A user can produce diagnostics without engineering.** — unchanged.
  `lib/screens/settings/about_screen.dart:11,69` and `lib/screens/settings/settings_screen.dart:258`
  hand-type `1.0.0` with no build number; `package_info_plus` is still absent from `pubspec.yaml`.
  With `StoreMigrator` now shipping, the *store schema version* becomes a second thing support will
  need to ask for, and it is not displayed anywhere either.

- N/A **Destructive advice appears only with its data consequences spelled out.** — still no
  user-facing playbook. Worth noting the one place destructive copy now exists in the app itself,
  `delete_account_screen.dart:136-183`, does this well: it lists what is deleted, what is retained
  (tax invoices), and tells the user to call before deleting if a service is running.

- ❌ **Household/multi-user playbooks cover the OTHER person's phone.** — unchanged. The app is
  squarely multi-user (`family_members_screen.dart`, `add_patient_screen.dart`,
  `lib/utils/permissions.dart` four-way roles, staff-app writes via `sync_service.dart`). No
  playbook. **New wrinkle:** §A.2's demo-flag race is *per device and per session*, so two family
  members on two phones can legitimately see different banner states for the same patient at the
  same moment — the exact scenario a household playbook has to handle, and it now has a
  non-obvious cause.

---

### 5. Feedback → roadmap loop

- ⚠️ **Every confirmed user-reported bug becomes a regression test before the fix ships.** —
  unchanged in policy (none written), and this round is the counter-example: five new
  operational surfaces landed with one test between them (§3.5).

- ⚠️ **User words are preserved in the tracker.** — unchanged. Verbatim reports survive in code
  comments (`my_care_provider.dart:91-97`) but `docs/KNOWN_ISSUES.md` remains engineer-paraphrased.

- ❌ **A visible changelog closes the loop.** — unchanged. `grep -rni "what's new\|changelog"` over
  `lib/` and `assets/i18n/` → no matches. `docs/CHANGELOG.md` never reaches a user.

- ⚠️ **Requests triaged against the roadmap on a cadence.** — worse than round 1 in staleness
  terms: `docs/KNOWN_ISSUES.md:5` still reads "Last updated: 2026-05-28" while HEAD is `820060b`
  (2026-08-03) and this commit closed ten items none of which are reflected. `:53` BUG-14 ("Invoice
  PDF download is a stub") remains false against `lib/services/invoice_pdf_service.dart`.
  BUG-33/34 status lines are now two release-gating console actions tracked in a document nobody
  has updated in ten weeks.

---

### 6. Data stewardship (standing duties)

- ⚠️ **The schema-deploy runbook is a living document.** — upgraded from ⚠️ with one genuine
  improvement. The round-1 gap "(c) there is no app-side schema stamp to bump" is **closed**:
  `lib/services/store_migrator.dart:33,35` defines `currentVersion` and `housepital_schema_version`,
  and the doc comment at `:15-30` is an unusually good contract (migration literals frozen, never
  delete unparseable data, quarantine instead). Still broken at midnight: `.firebaserc` is empty,
  every `DEPLOYMENT_GUIDE.md` command `cd`s to `/Users/ateeshayjain/housepital-backend` which is
  not in this tree, and `docs/KNOWN_ISSUES.md:26` names the wrong package id. And the migrator
  itself carries operational risk — §B.

- ✅ **Export/backup is verified WORKING in every release.** — unchanged and still true:
  `lib/services/invoice_pdf_service.dart` + `test/services/invoice_pdf_service_test.dart`,
  `lib/services/handover_report_service.dart` + `test/services/handover_report_service_test.dart`,
  both run by `.github/workflows/ci.yml` on every push. **Caveat that is now a finding, not a
  footnote:** the handover PDF's *contents* are 100% sample data — see §A.3.

- ⚠️ **Account/data deletion paths are re-verified each release, including server copies.** —
  upgraded from ❌ because a path now exists, but see §C: the server half of the promise is
  delivered by a 600 ms `Future.delayed` and reaches nobody.

- ❌ **Privacy labels and policy re-read whenever a release adds a data type.** — partially
  improved: `ios/Runner/Info.plist:73-76` now declares `NSCameraUsageDescription` and
  `NSPhotoLibraryUsageDescription`, closing round-1 blocker B7. Still failing:
  `find ios -name "PrivacyInfo.xcprivacy" -not -path "*/Pods/*"` → **no matches**, and the privacy
  policy remains a remote URL only (`about_screen.dart:98,103`) so drift cannot be detected from
  the repo. **This release adds a data type in the other direction** — a deletion *request* is now
  collected as a user action; the published policy must describe the 30-day commitment the app
  makes at `delete_account_screen.dart:75-77`. **BLOCKED-OWNER.**

---

## Directed analysis (as briefed)

### §A — The banner fix: is coverage complete?

**No.** The mechanism is sound; the coverage is not. Three distinct gaps.

#### A.1 · Eleven demo-serving sites never set the flag

Marked correctly (5 providers, 6 call sites): `app_provider.dart:260`, `my_care_provider.dart:50,98`,
`medication_provider.dart:191,236`, `billing_provider.dart:43`, `orders_provider.dart:199`.

Not marked — a patient can be on each of these screens seeing sample records with **no banner**:

| # | Site | What the user sees | Severity |
|---|---|---|---|
| 1 | `lib/providers/app_provider.dart:137-138` | `_currentPatient = DemoData.patient; _patients = [DemoData.patient]` — the seed runs before the API and the `catch` at `:151-154` only logs. The **patient identity in the header** is sample data with no mark. | High |
| 2 | `lib/services/handover_report_service.dart:100-108` | The **doctor handover PDF** — patient, medical history, active medications, vitals history, today's report, services, staff on duty, appointments — is built unconditionally from `DemoData`. Exported and handed to a clinician. See A.3. | **Blocker** |
| 3 | `lib/screens/settings/patient_profile_screen.dart:898` | `_buildMedicalHistory(DemoData.medicalHistory)` — **allergies and conditions**, unconditional, under a subtitle reading "Recorded by your supervisor at deployment · synced" (`:889`). | **Blocker** |
| 4 | `lib/models/care_event.dart:57,71,97,105-106,118` | The entire Care Calendar feed — dose counts, adherence percentages, staff-present rows, appointments — is computed from `DemoData` unconditionally, not as a fallback. | High |
| 5 | `lib/screens/calendar/care_calendar_screen.dart:1324` | Staff-on-duty list from `DemoData.icuServiceDetail`. | Medium |
| 6 | `lib/screens/care_team/care_team_screen.dart:29,31,162-164` | Supervisor and past-staff list always `DemoData`; `:29` falls back to `DemoData.patient` for the patient itself. | Medium |
| 7 | `lib/screens/my_care/widgets/doctor_advice_card.dart:46` | Doctor recommendations default to `DemoData.doctorRecommendations` — clinical advice, rendered inside the My Care tab. | High |
| 8 | `lib/providers/blog_provider.dart:38` | Article list falls back to `DemoData.articles` on API failure, marks nothing, and logs via bare `debugPrint` (`:37`) rather than `Log.warn`, so it is invisible even to the console policy. | Low |
| 9 | `lib/providers/blog_provider.dart:68` | Same for a single article (`:67` `debugPrint`). | Low |

Items 2, 3, 4, 5, 6 and 7 are all **clinical or identity** surfaces. Item 8/9 are content and are
low-risk, but they are the only two that were plausibly *forgotten* rather than *out of scope* —
`blog_provider` is the one API provider in `lib/providers/` with a demo fallback and no
`DemoMode` import.

#### A.2 · The banner does not render on pushed routes — including the screen that motivated it

`_DemoDataBanner` is a child of `MainShell`'s body `Column` (`lib/screens/main_shell.dart:58-70`).
Every screen reached by `Navigator.pushNamed` is a `MaterialPageRoute` on the root navigator
(`lib/main.dart:436-762`) and covers the shell completely. So the banner is **absent** from, among
others:

- `/medication-schedule` (`main.dart:580`) — **the exact screen in round 1's insulin scenario**,
  and the screen whose provider path `medication_provider.dart:236` was wired to set the flag.
  The flag is set; nothing draws it.
- `/medications` (`:577`), `/vitals` (`:464`), `/report-detail` (`:469`),
  `/attendance-history` (`:593`), `/report-history` (`:588`)
- `/care-calendar` (`:748`), `/care-team` (`:751`), `/patient-profile` (`:455`)

Home entry points push straight into these (`home_screen.dart:344,353` →
`/medication-schedule`). A family member checking today's insulin therefore takes the one path
where sample data is served *and* the banner is structurally unreachable.

**Fix:** move the banner out of `MainShell` — either into a `MaterialApp.builder` wrapper (it
already exists at `main.dart:420-433` for text scaling) so it sits above every route, or into
`GlassAppBar`'s bottom slot so every screen inherits it.

#### A.3 · `DemoMode.reset()` is called by one provider on behalf of six

`lib/providers/app_provider.dart:247` is the **only** reset call site, and it fires when the
*dashboard* `Future.wait` succeeds. Six independent sources can be on demo data. Two concrete
failure modes:

- **False negative (banner hidden while sample data is on screen).** Partial outage: dashboard
  endpoints healthy, medications endpoint down. `home_screen.dart:59-63` runs
  `loadPatients → loadDashboard → loadMedications`. `medication_provider.dart:189-192` seeds
  `DemoData.medications` and marks. Dashboard resolves, `app_provider.dart:247` calls
  `DemoMode.reset()`. The medications call then times out at 5 s (`:200`) and takes no action —
  the mark lives in the pre-API seed block, so it is never re-set. The user is left with the
  sample patient's medication list and **no banner**. Pull-to-refresh on Home
  (`home_screen.dart:111` `onRefresh: () => app.loadDashboard()`) reproduces this on demand.
- **False positive (banner shown while all data is live).** `my_care_provider.dart:48-53` marks
  during its pre-API seed and **never resets** on success; neither do medication, billing or
  orders. So a healthy backend + a visit to the My Care tab leaves the banner asserting "we can't
  reach Housepital" over live records until the next successful `loadDashboard`. A banner that
  cries wolf on the happy path is a banner users learn to ignore — which costs the fix its value
  in exactly the incident it was built for.

**Fix:** make the flag a set, not a boolean — `DemoMode.mark(source)` / `DemoMode.clear(source)`,
banner visible while the set is non-empty. Each provider clears only its own key on success.

#### A.4 · Test coverage of the fix

One test, `test/providers/patient_scope_isolation_test.dart:172-189`, covers `AppProvider`'s
dashboard path only. Nothing tests the other five marking providers, the reset race, or that
`MainShell` renders the banner at all (`test/screens/main_shell_test.dart` never mentions it).
Every gap in A.1–A.3 is invisible to the suite.

**Verdict on the round-1 blocker: ⚠️ partially fixed.** The honest, non-dismissible banner is the
right design and the copy is right. But a patient can still be on `/medication-schedule`,
`/patient-profile`, `/care-calendar` or a handover PDF reading sample clinical data with no
warning, and the flag can be cleared while five other providers are still serving demo.

---

### §B — `StoreMigrator` as an operational risk

`lib/services/store_migrator.dart`, run at `lib/main.dart:174`, **before** `runApp()` at `:191`.
The design is careful: frozen literals, quarantine-not-delete, refusal to downgrade
(`:83-93`), continue-on-step-failure (`:106-114`). The operational exposure is elsewhere.

**Blast radius: the whole app, on every cold start.** `run()` is not gated by version, platform
or build mode — every launch awaits at least one `SharedPreferences.getInstance()` (`:64`) before
`runApp()`. Anything that throws or hangs there means the user never reaches a first frame.

1. **The "never throws" contract is not enforced at the boundary.** The doc comment at `:60-62`
   says "Never throws", but only the *step* loop is wrapped (`:106-114`). `SharedPreferences.getInstance()`
   at `:64` is bare, and so is every `prefs.setInt` at `:71,117` and every `prefs.set*` in
   `quarantine()` (`:131-141`). A platform-channel failure or a corrupt `NSUserDefaults` plist —
   rare per device, certain across a user base — propagates out of `run()`, out of the `await` at
   `main.dart:174`, and `runApp()` never executes. The user gets a **blank screen on every launch,
   permanently**, with no in-app path to recovery. `runZonedGuarded` (`main.dart:100`) catches it
   and records a fatal to Crashlytics, so it is *visible* — but on iOS it is unsymbolicated (§2.1),
   and the app is a brick until a store update ships. There is no kill switch (§1.3).
2. **No timeout.** `getInstance()` awaits a platform channel with no `.timeout(...)`, unlike every
   API call in the app (`app_provider.dart:232`, `medication_provider.dart:200` all use 5 s). A
   hung channel is an indefinite splash, not a crash — and an indefinite splash produces **no**
   crash report at all, only ANRs and one-star reviews.
3. **Boot loop:** no. There is no restart-on-failure path, and the version stamp advances
   monotonically (`:117`). The realistic bad outcome is a *permanent blank screen* or a
   *permanent hang*, not a loop — arguably worse, because neither is self-healing.
4. **A failed step is still recorded as successful.** `:107-117` — when a step throws, the error is
   logged and `version` is incremented and stamped anyway. The store is then half-migrated and
   *labelled* fully migrated, so no later run will retry it. Combined with (5) this means a
   migration failure is silently permanent.
5. **Quarantine is aspirational.** `quarantine()` (`:126-144`) is a helper migrations must call;
   with `_migrations` empty (`:57-58`) nothing calls it. `grep -rn "StoreMigrator.quarantine" lib/`
   → no matches. The comment at `:111-113` ("quarantine (below) preserves the original bytes")
   describes a guarantee no code currently provides.
6. **Observability is zero.** Every failure path — `:75`, `:88`, `:103`, `:109`, `:142` — reports
   via `Log.warn`/`Log.error`, which stops at `debugPrint` (`logger.dart:63-65`). On a release
   build nobody ever learns that a migration was skipped, a store was quarantined, or a downgrade
   was detected. This is the single highest-leverage line in the audit: wiring `logger.dart:63`
   makes `StoreMigrator` observable for free.
7. **Zero tests.** `grep -rln "StoreMigrator" test/` → no matches, despite `:147` exposing
   `versionKeyForTest` specifically so it could be tested. Fresh install, legacy-data install,
   downgrade, and step-failure are four cheap unit tests that do not exist.

**Fix (≈8 lines):** wrap the whole body of `run()` in `try/catch` that swallows and logs; add
`.timeout(const Duration(seconds: 3))` to `getInstance()` and skip migration on timeout; only
stamp `version + 1` when the step did not throw; wire `logger.dart:63`. Grade: ⚠️ — good design,
unsafe boundary, unobservable, untested, on the critical path of every cold start.

---

### §C — The deletion flow's operational obligation: who receives the request?

**Nobody.** `lib/screens/settings/delete_account_screen.dart:53-89`:

```dart
// TODO(backend): POST /account/delete once api.housepital.in exists…
await Future<void>.delayed(const Duration(milliseconds: 600));
…
SessionScope.clearSession(context);
await context.read<AuthProvider>().logout();   // → prefs.clear()
```

The 600 ms delay is the entire "request". Then `:68-88` shows a dialog promising:

> "Your Housepital records are scheduled for deletion and will be removed within 30 days."

Traced end to end:
- **No network call.** `grep -rn "account/delete\|deleteAccount" lib/` matches only this file's
  TODO. `lib/services/api_service.dart` has no deletion endpoint.
- **No local record.** `AuthProvider.logout()` runs `prefs.clear()`, so even if a request had been
  queued to `SharedPreferences` it would be erased in the same breath.
- **No email, no ticket, no analytics event** — there is no analytics SDK at all (§H8).
- **No inbound path either.** The dialog's remedy — "call us on 9990-911-911" (`:78`) — reaches a
  phone line with no ticket system behind it (`docs/KNOWN_ISSUES.md:90` TD-11: the concern SLA is
  "not enforced or alerted on the backend").

So the app makes a dated, statutory-flavoured promise (DPDP Act 2023 §12 erasure, cited in the
file's own header at `:13-14`) to a recipient that does not exist. **Treating "nobody" as the
finding:** this is not a missing feature, it is an **unowned commitment**. Thirty days after the
first user taps Delete, Housepital is in breach of a promise it has no record of having made,
and cannot even enumerate who is owed what.

Credit where due: the screen is otherwise the most honest surface in the app. `:17-24` explicitly
refuses to overstate ("It does not claim the server data is gone"), `:146-177` separates what is
deleted from what is retained for tax law, `:185-208` uses a checkbox plus a typed `DELETE`
confirmation. The *UI* is right; the *operations* behind it are absent — and the user-facing copy
at `:74-77` is more confident than `:17-24` admits, which is exactly the gap.

**Fix, in order of cost:** (a) until a backend exists, make the request durable and reachable —
write it to Firestore (`deletion_requests/{uid}` with a timestamp, before `prefs.clear()`) so it
survives the wipe and lands somewhere a human can query; (b) name an owner and a weekly check in
`docs/` — a deletion queue nobody reads is the same failure with extra steps; (c) soften the copy
to what is actually guaranteed until (a) ships. **BLOCKED-OWNER** for who owns the 30-day clock.

---

### §D — `storage.rules`: repo state vs live posture

`storage.rules` (86 lines) and `firebase.json:6-8` `"storage": {"rules": "storage.rules"}` are new
and the rules themselves are well-constructed: default-deny at `:82-84`, two allowed prefixes
matching the two real `uploadFile` call sites, signed-in + own-patient + image + 10 MB checks,
`update, delete: if false` on both. The file even documents its own risk at `:7-11`
("!! CRITICAL !! THIS FILE MUST BE DEPLOYED").

**The gap between repo state and live posture is total, and the repo cannot close it:**
- Nothing in the repo records a deploy. `git log --oneline -3` shows `820060b` added the file; no
  deploy log, no console screenshot, no timestamp in `docs/`.
- `.firebaserc` is `{"projects":{},"targets":{},"etags":{}}`, so the very command the file
  prescribes at `:10` (`firebase deploy --only storage --project housepital-patient`) is the only
  form that can work from this tree — and there is no evidence anyone has run it.
- `docs/KNOWN_ISSUES.md` was not updated to track it (still "Last updated: 2026-05-28"), so this
  new console prerequisite joins BUG-33 and BUG-34 in an untracked state.
- Until it is deployed, the live posture is **whatever the console happens to hold**, which for a
  project that has never had Storage rules in the repo is most likely the default
  `allow read, write: if request.auth != null` — i.e. any authenticated user can read any other
  patient's chat and concern-evidence photographs.

**What would confirm it (BLOCKED-OWNER, none of it doable from the repo):**
1. `firebase deploy --only storage --project housepital-patient` and the CLI's success output
   pasted into `KNOWN_ISSUES.md` with a date.
2. The rules body and "Last published" timestamp read from
   `https://console.firebase.google.com/project/housepital-patient/storage/rules`, compared
   line-for-line against `storage.rules`.
3. A negative test from a second authenticated account: fetch a download URL for
   `chat/{otherPatientId}/…` and confirm a 403.

Same three-step confirmation applies to `firestore.rules` (BUG-33) and the API-key restrictions
(BUG-34), neither of which moved this round.

### §E — Re-verification of the two items that were *not* on the fix list

- ❌ **Android release is debug-signed.** `android/app/build.gradle.kts:33-37` is byte-identical to
  round 1, TODO comment included. `ls android/key.properties` → No such file or directory. No
  `signingConfigs { create("release") … }` block exists. **Unchanged.** Consequence for this
  checklist: §1.1 phased release and §1.3's "halt the phase" rollback remain unavailable on
  Android, and §1.6's "previous archive installable" cannot begin.
- ❌ **Auth gate disabled.** `lib/main.dart:416-418` — the commented-out `Consumer<AuthProvider>`
  gate and the note "Enable before production release" are unchanged; `home: const SplashScreen()`
  and `lib/screens/splash_screen.dart:15-18` `pushReplacementNamed('/home')` after 2 seconds.
  **Unchanged.** Consequence for this checklist: it silently invalidates §A and §C. With no
  session, `request.auth` is null on every device, so `storage.rules`/`firestore.rules`
  (`ownsPatient()`, `request.auth.uid == patientId`) deny **everything** — which is safe but means
  the demo-mode fallback is not a degraded state, it is the *only* state. And the deletion flow's
  `AuthProvider.logout()` signs out a user who was never signed in, so §C's "record the request
  against the uid" fix has no uid to use until this is re-enabled.

---

## Blockers (must fix before release)

1. **The sample-data banner does not cover the screens that matter** — `_DemoDataBanner` lives
   inside `MainShell` (`lib/screens/main_shell.dart:58-70`), so it is structurally absent from
   every pushed route, including `/medication-schedule` (`lib/main.dart:580`) — the exact screen
   in round 1's insulin scenario. Move it above the router.
2. **Six clinical/identity surfaces serve `DemoData` and never set the flag** —
   `handover_report_service.dart:100-108` (the doctor handover PDF, exported to a clinician),
   `patient_profile_screen.dart:898` (allergies/conditions, under a "synced" subtitle),
   `care_event.dart:57,71,97,105-106,118` (the whole Care Calendar),
   `doctor_advice_card.dart:46` (clinical advice), `app_provider.dart:137-138` (patient identity),
   `care_team_screen.dart:29,31`.
3. **`DemoMode.reset()` clears a global flag on behalf of five providers it does not own** —
   `app_provider.dart:247`. Produces both a hidden banner over sample medication data and a
   spurious banner over live data (§A.3).
4. **Support numbers are still placeholders** — `help_faq_screen.dart:352,365`,
   `staff_otp_verification_screen.dart:352`. Unchanged from round 1.
5. **Android release is debug-signed** — `android/app/build.gradle.kts:33-37`. Unchanged.
6. **Auth is disabled** — `lib/main.dart:416-418`, `splash_screen.dart:15-18`. Unchanged.
7. **iOS crash reports will be unsymbolicated** — no `upload-symbols` phase in
   `ios/Runner.xcodeproj/project.pbxproj:280-390`, on an iOS-first app. Unchanged.
8. **The 30-day deletion promise reaches nobody** — `delete_account_screen.dart:53-89` is a
   600 ms delay followed by `prefs.clear()`; the promise at `:75-77` has no recipient, no record
   and no owner.

## High

9. **`StoreMigrator` can brick a cold start** — unguarded `SharedPreferences.getInstance()`
   (`store_migrator.dart:64`) and unguarded `prefs.setInt` (`:71,117`) on the pre-`runApp()` path
   (`main.dart:174`), with no timeout. §B.
10. **`logger.dart:63` still unwired** — now the sole reporting path for `StoreMigrator`'s five
    failure branches as well as every backend outage. Highest value-per-line fix in the audit.
11. **`storage.rules` undeployed** — `.firebaserc` empty; no deploy evidence; live posture
    unknown and probably permissive. §D.
12. **No analytics** — the booking funnel remains unobservable.
13. **No flag / kill switch / force-upgrade** — a shipped dosage-display bug still has no remote
    remedy, and now neither does a bad `StoreMigrator`.
14. **Android `<queries>` missing** — `AndroidManifest.xml:43-48`; the whole non-SOS support
    surface fails `canLaunchUrl` on API 30+.
15. **Background-isolate errors uncaptured** — no `addErrorListener` in `lib/`.
16. **New operational code shipped untested** — zero tests for `StoreMigrator`, zero for
    `DeleteAccountScreen`, zero widget tests asserting the banner renders; one test covers one of
    six marking providers.
17. **No user-symptom diagnostic playbooks** — and now there is a diagnostic question worth
    asking ("do you see the orange strip?") that no document tells support to ask.
18. **Firestore rules + API-key restrictions still pending** — `KNOWN_ISSUES.md:25,26`.

## Medium / Low

19. `docs/KNOWN_ISSUES.md:5` ten weeks stale; BUG-14 (`:53`) still false; BUG-07 (`:39`)
    contradicts the current green suite. (Medium)
20. `docs/KNOWN_ISSUES.md:26` still names package `in.housepital.patient`; the real id is
    `com.housepital.housepital_patient` (`android/app/build.gradle.kts:23`) — a key restriction
    applied to the wrong package locks out the real app. (Medium)
21. Version string hardcoded in two places with no build number
    (`about_screen.dart:11,69`, `settings_screen.dart:258`); `package_info_plus` absent. The store
    schema version (`StoreMigrator.currentVersion`) is likewise invisible to support. (Medium)
22. No in-app "What's new". (Medium)
23. Halt criteria and expedited-review criteria still absent from `DEPLOYMENT_GUIDE.md`. (Medium)
24. Incident severity ladder and `concernSla` still inert (`constants.dart:52-57`,
    `KNOWN_ISSUES.md:90`). (Medium)
25. `blog_provider.dart:37,67` use bare `debugPrint` instead of `Log.warn`, bypassing even the
    console-level policy the rest of the app follows. (Low)
26. The support phone now has three separate literals — `constants.dart:19`,
    `delete_account_screen.dart:78`, `:181`. (Low)
27. Banner + `extendBodyBehindAppBar` double top inset while the banner is visible
    (`main_shell.dart:58-70`). (Low, verify on a notched device)
28. `android/app/src/main/AndroidManifest.xml:7` app label is still `housepital_patient`. (Low)
29. No `PrivacyInfo.xcprivacy` in `ios/`. (Medium — submission requirement)

## BLOCKED-OWNER

| Item | What is needed |
|---|---|
| Storage / Firestore rules live posture (§D) | `firebase deploy --only storage --project housepital-patient`, then the console "Last published" timestamp + a cross-account 403 test, pasted into `KNOWN_ISSUES.md` |
| API-key restrictions (BUG-34) | Console action against the **correct** package id, then verification output |
| Phased release ON (§1.1) | Play staged rollout + App Store Connect phased release — after the signing config is fixed |
| Store release-notes text (§1.5) | Owner-written user-facing notes for v1.0.0 |
| Crashlytics alerts + a daily reader (§2.1) | Console config per `DEPLOYMENT_GUIDE.md §7a.5`, plus a named person for week 1 |
| Store review / beta triage (§2.2) | Named owner, weekly slot, four-way rubric |
| First-48h smoke pass (§2.4) | Owner to run a to-be-written `docs/SMOKE_PASS.md` on a real device from the store build |
| Support channel monitored, window published (§4.1) | Confirm `wecare@housepital.in` is monitored; confirm `9990911911` staffing hours |
| **Deletion-request owner and 30-day clock (§C)** | Who receives a deletion request today, where it is recorded, and who is accountable on day 30 |
| Privacy policy vs shipped data set (§6.4) | Owner to check `housepital.in/privacy` covers vitals, medication names, photos, voice, phone, address — **and the new 30-day deletion commitment** |
| Expedited-review criteria (§3.4) | Owner sign-off on what qualifies |
| Previous-release archive retention (§1.6) | N/A for v1; confirm retention policy from build 1 |
