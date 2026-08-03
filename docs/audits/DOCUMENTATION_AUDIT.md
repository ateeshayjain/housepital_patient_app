# Documentation Checklist — Audit vs commit 803124d

**Date:** 2026-08-03 · **Auditor:** Documentation audit agent
**Repo:** `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`
**HEAD:** `803124d` (2026-06-15) · **Working tree:** 4 modified files (six-tab → five-tab nav change, uncommitted)

> Every verdict below was verified against the code or a command's output. No verdict
> was taken from a document's own self-description. Where a doc claims something, the
> claim was diffed against `lib/`, `test/`, `main.dart`, `pubspec.yaml`, or `git log`.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Project meta | 2 | 4 | 0 | 0 |
| 2. Living technical docs | 0 | 2 | 2 | 0 |
| 3. Product / UX | 0 | 2 | 4 | 0 |
| 4. Brand / design | 0 | 2 | 1 | 0 |
| 5. Quality & audits | 0 | 2 | 3 | 0 |
| 6. Compliance & ship | 0 | 1 | 4 | 0 |
| 7. Per-feature docs | 0 | 2 | 1 | 0 |
| 8. Ops / infra | 1 | 1 | 1 | 0 |
| **TOTAL (35 items)** | **3** | **16** | **16** | **0** |

---

## The headline finding

**Four code commits and one working-tree change have landed since the last
documentation refresh, and not one of them touched a single `.md` file.**

```
$ git log -8 --format='%h %cd %s' --date=short
803124d 2026-06-15 fix: staff profile identity, top toasts, sleep-study overnight slot, receipt PDF
bc73765 2026-06-15 fix: Nurse role is clinical-only — personal hygiene/diaper/sanitary/massage are caretaker tasks
4a37c2a 2026-06-15 feat: field round 7 — dead-tap fix, rental prices, diagnostics, needs-sheet reframe, polish
75162d5 2026-06-15 fix: service-detail staff rows — role as grey subtext, matching Home
db22f5f 2026-06-15 docs: refresh for field rounds 3-6; fix inverted manpower-pricing rule   ← last doc touch
```

Verified per commit — `git show --stat <sha> | grep -iE 'docs/|\.md'` returns nothing for
`75162d5`, `4a37c2a`, `bc73765`, `803124d`. `4a37c2a` alone is a 15-file, 729-insertion
"field round 7" that rewrote `staff_role_card.dart` (+170), `service_booking_screen.dart`
(+301), `catalog_seeds.dart` (+70) and the equipment catalog — with zero doc updates.
`docs/CHANGELOG.md` has **no entry for 2026-06-14 or 2026-06-15** (`grep -n "2026-06-1[45]"` → empty),
so field round 7, the nurse/caretaker task-scope correction, rental prices, diagnostics,
the needs-sheet reframe and the receipt PDF are entirely undocumented.

This is the third repetition of the failure this audit was commissioned to find.

---

## Findings

### Section 1 — Project meta

- ⚠️ **[R] README.md** — exists and is genuinely runnable (clone → `flutter pub get` →
  `flutter run --dart-define=RAZORPAY_KEY=…`, `README.md:61-90`), so the "new dev can
  clone and run" bar is met. But it carries five verified-false claims:
  - `README.md:44` — "**6 bottom tabs** (Home, My Care, Services, Calendar, Billing, More)" — **STALE**, nav is now five tabs (`lib/screens/main_shell.dart:36-42`).
  - `README.md:278-284` — an entire "### Tab 4 — Calendar (root tab)" section, incl. "Care Calendar is a root bottom-tab (index 3, between Services and Billing)" — **STALE**.
  - `README.md:148` — "# 10 providers" — actual is **11** registered in `lib/main.dart:186-267` (`RemindersProvider` at `lib/main.dart:207-209` is missing from the list at `README.md:149-158`).
  - `README.md:209` — "test/ # 86 test files, 1,550+ tests" — contradicts `README.md:43` in the *same file* ("99 test files | ~1,771 tests"). Actual: `find test -name '*_test.dart' | wc -l` → **99**.
  - `README.md:428` — "Wire Mock Data — AppProvider uses `_loadMockData()`" — `grep -rn "_loadMockData" lib/` returns **nothing**. The symbol does not exist.
  - Also `README.md:26` "Flutter 3.16+" vs `.github/workflows/ci.yml:22` pinned `3.41.2` vs `PROJECT.md:29` "Flutter 3.41+" — three different answers.
  - Accurate claims (verified): 149 Dart files ✓, 52 named routes ✓, 351 equipment items ✓, ~23,800 test LOC (actual 23,884) ✓. Lib LOC is 54,295 vs "~53,800" claimed — 1% drift, acceptable.
  - **Impact:** the front door misstates the app's own navigation and provider wiring.
  - **Fix:** update lines 44, 148, 209, 278-284, 428; delete the "Tab 4 — Calendar" section and re-number the Billing/More headings (currently ordered Tab 5, Tab 4, Tab 6).

- ✅ **[R] CLAUDE.md** — exists and does exactly what the item asks: it lists the
  project-specific traps (Ahem-font overflow pitfall `CLAUDE.md:109-111`, const-widget
  double-pump pitfall `:112-113`, DerivedData 0xe8008014 signing trap `:119-121`,
  demo-mode expected-log note `:4-5`). It is the **only** doc already correct on the
  five-tab nav (`CLAUDE.md:74-80`, updated in the working tree). One inaccuracy:
  `CLAUDE.md:13` says "37 screens × 320/375/414" — see the overflow-count finding below.

- ⚠️ **[+] CONTRIBUTING.md** — exists; branch/commit/PR/test workflow is clear and the
  conventions match reality (feature branches, conventional commits). But the CI
  description is stale: `CONTRIBUTING.md:31-34` lists three steps (analyze → test →
  build web), while `.github/workflows/ci.yml` runs **five** — it omits the *design
  consistency gate* (`ci.yml:40-41`) and the *coverage gate* (`ci.yml:66-79`). Its
  `flutter test` (`CONTRIBUTING.md:33`, `:56`) also omits
  `--dart-define=RAZORPAY_KEY=rzp_test_ci_dummy_key`, which `CLAUDE.md:11` and
  `ci.yml:55` both require to un-skip 8 payment groups. Copy-pasting from CONTRIBUTING
  gives you a silently weaker test run.

- ✅ **[R] LICENSE** — exists, names the holder explicitly: "Copyright (c) 2026
  Housepital Pvt Ltd (CIN: U85100DL2019PTC357830)" with registered office and a
  licensing contact (`LICENSE:1-19`).

- ⚠️ **[+] CHANGELOG.md** — exists with a real per-date entry format and a first-release
  history. But the newest entry is `## [2026-06-13]` (`docs/CHANGELOG.md:7`) while four
  commits shipped on 2026-06-15. `grep -n "2026-06-1[45]" docs/CHANGELOG.md` → no matches.
  **Fix:** add entries for `75162d5`, `4a37c2a`, `bc73765`, `803124d` and the five-tab change.

- ⚠️ **[+] STATE.md / STATUS.md** — `PROJECT.md` fills this role (Status / Stage /
  Last reviewed at `PROJECT.md:3-6`), but it does **not** reflect today's reality:
  - `PROJECT.md:4` — "six field-feedback rounds (3–6) shipped ... **Calendar root tab**" — stale on both counts (round 7 shipped; calendar is no longer a tab).
  - `PROJECT.md:101` — lists "Firebase Crashlytics + Performance Monitoring … currently no production observability" as a pre-launch TODO, but `docs/FEATURE_TRACKER.md:239,241` marks both **Done** and `lib/main.dart` wires them.
  - `PROJECT.md:105` — lists "Coverage gate in CI" as a pre-launch TODO; it already exists at `.github/workflows/ci.yml:66-79` (threshold 50%).
  - `PROJECT.md:86` says TEST_MAP is "currently inconsistent with README's count"; `PROJECT.md:92` says they were "reconciled" — the same file contradicts itself six lines apart.
  - `PROJECT.md:98` — "In flight: audit batches 1 → 3 (PRs #10, #11, #12)" — months stale.
  - `PROJECT.md:31` links `./README.md#-tech-stack`; the heading is `## Tech Stack` → anchor `#tech-stack`. Broken anchor.

### Section 2 — Living technical docs

- ❌ **[R] ARCHITECTURE.md** — the "done when" is *the folder/module list matches the
  repo*. It does not.
  - `docs/ARCHITECTURE.md:68` — "main_shell.dart # Fixed solid-orange bottom nav bar (**6 tabs**: Home/My Care/Services/**Calendar**/Billing/More)" — **STALE**.
  - `docs/ARCHITECTURE.md:207-208` — "**Six root** tabs (Calendar added at index 3 — indices 1/2 referenced externally)" — **STALE**.
  - `docs/ARCHITECTURE.md:17` — "Provider (ChangeNotifier) -- **10 providers**" and `:348` "**Ten** `ChangeNotifierProvider` instances initialized in `main.dart`" — actual **11**. The provider table (`:350-361`) omits **`RemindersProvider`**, which *is* registered (`lib/main.dart:207-209`) and *does* have a test (`test/providers/reminders_provider_test.dart`). The provider file list (`:56-66`) also omits `reminders_provider.dart`.
  - `lib/utils/` list (`:162-169`) omits **`logger.dart`** and **`validators.dart`** (the latter has `test/utils/validators_test.dart`).
  - `lib/widgets/` list (`:170-175`) omits **`care_pulse_ring.dart`**, **`day_part_header.dart`**, **`empty_state.dart`** — all three have dedicated tests.
  - `lib/screens/` tree omits **`splash_screen.dart`**, **`settings/add_patient_screen.dart`**, **`assistant/assistant_local_actions.dart`**, and every `services/{cards,data,sheets,tabs,widgets}` subfolder.
  - Correct: models (9/9 ✓), services (13/13 ✓), config (5/5 ✓), data (3/3 ✓).
  - The file's own last line (`:371`) says "this file MUST be updated in the same session" — it was not.
  - **Fix:** correct lines 17, 68, 207-208, 348; add `RemindersProvider` to the table and file list; add the 5 missing util/widget files and 3 missing screens.

- ⚠️ **[+] DATA_MODEL.md / DATA_INFLOW.md** — no file by that name; `docs/DATABASE_SCHEMA.md`
  (20 tables) + `docs/API_REFERENCE.md` cover the entity/inflow ground in substance. But
  both are frozen at **2026-03-24** (`git log -1 --format=%cd -- docs/DATABASE_SCHEMA.md`
  → 2026-03-24) — four months and two pricing regime changes ago — and both still encode
  the **dead** manpower rule (see Blockers).

- ❌ **[+] SCREENS.md** — `docs/SCREEN_MAP.md` exists and is unusually thorough (its
  52-route table diffs **exactly clean** against `lib/main.dart` — verified by set
  comparison, zero routes missing in either direction). But it fails the "every screen
  in the app appears" bar and contains a phantom:
  - `docs/SCREEN_MAP.md:6` — "MainShell -- **6 tabs**"; `:10` "[3] Calendar → CareCalendarScreen"; `:15` "**Calendar was added as a root tab at index 3**"; `:73-77` an entire "### CALENDAR TAB (Index 3)" section — all **STALE**.
  - `docs/SCREEN_MAP.md:62` and `:217` list **`BookingHistoryScreen`** as the widget for `/booking-history`. **That class does not exist.** `grep -rn "BookingHistoryScreen" lib/` → no definition; `lib/main.dart:602-604` falls `/booking-history` through to `MyOrdersScreen` as "an alias for legacy in-app links". Class-set diff confirms it is the only widget named in the doc with no code behind it.
  - **`SplashScreen`** (`lib/screens/splash_screen.dart`) appears nowhere in the map.
  - `docs/SCREEN_MAP.md:81` labels Billing "(Index 4)" and `:133` labels More "(Index 4)" — two sections claim the same index, and both contradict the doc's own tree at `:11-12` ([4] Billing, [5] More). Pre-existing internal contradiction.
  - **Fix:** rewrite lines 6-15 for five tabs, fold the Calendar section into My Care (noting the `/care-calendar` app-bar action), replace `BookingHistoryScreen` with `MyOrdersScreen` at `:62`/`:217`, add `SplashScreen`, renumber Billing → Index 3.

- ⚠️ **[~] SETUP.md** — trigger met (Firebase + Razorpay + Cloud SQL + emulators).
  `docs/ENVIRONMENT_SETUP.md` covers prerequisites, clone, `flutterfire configure`,
  emulator setup and backend `.env`. Gap: every `flutter run` example
  (`:255`, `:258`, `:261`, `:370`) omits `--dart-define=RAZORPAY_KEY=…` and
  `ASSISTANT_API_URL`, and the doc never mentions `--dart-define` at all
  (`grep -n "dart-define" docs/ENVIRONMENT_SETUP.md` → no matches) even though
  `.env.example:1` and `README.md:72` both say that is how the key is passed. A fresh
  machine set up from this doc alone silently runs the placeholder-key demo path.

### Section 3 — Product / UX

- ❌ **[+] PERSONAS.md** — does not exist. `find . -name '*.md'` across the repo (30 files)
  contains no personas document. Personas are implied only by the role matrix in
  `lib/utils/permissions.dart` (patient-self / primary contact / family / caretaker).
- ❌ **[+] PROBLEM_STATEMENTS.md** — does not exist. The closest is one sentence at
  `README.md:5-6` ("Replaces phone-call-based monitoring…").
- ❌ **[+] USER_JOURNEYS.md** — does not exist.
- ⚠️ **[o] USER_FLOWS.md** — no file by that name, but `docs/services-tab.md` (19KB) and
  `docs/my-care-tab.md` (8.8KB) are per-feature step-flow docs in substance. Both are
  **undated, carry no status banner, and were last touched 2026-03-21** — and both still
  state the dead pricing rule as current (see Blockers).
- ❌ **[~] ONBOARDING.md** — trigger met (`lib/screens/auth/onboarding_screen.dart` +
  `/onboarding` route at `lib/main.dart:436`). No first-run design doc exists.
- ⚠️ **[+] ROADMAP.md** — no file; `PROJECT.md:96-106` is a short roadmap with milestones
  and blocked items (`docs/FEATURE_TRACKER.md:264-272` lists blockers + owners, which is
  the "deferred and why" half). Both are stale — see the PROJECT.md findings above.

### Section 4 — Brand / design

- ⚠️ **[+] BRAND.md** — no file. The tokens *are* documented, in `CLAUDE.md:50-90`
  ("Design system contract") and `docs/ARCHITECTURE.md:182-218`, and they **match the
  code** — `#F39314` one-accent, `onOrange = white` app-wide, true-black tonal dark,
  `context.hc.*` resolver, 11px min text, ≥44pt targets. The "no drift" half of the
  done-when passes; the "there is a BRAND.md" half does not. Voice/tone and iconography
  rules are absent everywhere.
- ❌ **[~] Brand guidelines (PDF/source)** — trigger met (the app has a defined visual
  identity, `README.md:36` cites "Per Brand Guidelines"). `PROJECT.md:22` literally reads
  "Brand Guidelines | _TODO: add link to Drive/Notion_". The reference does not exist in
  or from this repo.
- ⚠️ **[o] Design-system / component reference** — no catalogue doc. `lib/widgets/glass.dart`
  is the single chrome source and is described prose-style in `docs/ARCHITECTURE.md:199-218`;
  `docs/VISUAL_CONSISTENCY_AUDIT.md:19-21` enumerates the shared kit (`HousepitalCard`,
  `SectionHeader`, `StatusBadge`, `LoadingWidget`, `ErrorRetryWidget`, `DetailRow`,
  `VitalCard`). No per-component usage reference.

### Section 5 — Quality & audits

- ❌ **[R] QA_CHECKLIST.md** — does not exist. There is no manual on-device test pass
  document. Automated guards exist (overflow smoke, dark-mode, i18n sync) but the
  checklist asks for the human/real-environment pass with a tick line per critical flow.
  For an app about to hit TestFlight with SOS, payments and medication logging, this is
  a Blocker-adjacent gap.
- ⚠️ **[+] TEST_RESULTS.md** — no file; `docs/TEST_MAP.md:3-6` carries the summary
  (99 files / ~1,771 runtime / 1,370 call sites). Verified:
  - **File count 99 — CORRECT** (`find test -name '*_test.dart' | wc -l` → 99).
  - **Call sites 1,370 — off by 2** (actual 1,372).
  - **The "complete inventory" table is a lie by omission.** `docs/TEST_MAP.md:156` is headed "complete inventory — **86 files**, 2026-06-11" and lists 86 rows while the header five lines earlier says 99. Set-diff against disk shows **13 test files that exist and are not in the inventory**: `test/providers/reminders_provider_test.dart`, `test/screens/dark_mode_sweep_test.dart`, `test/screens/main_shell_test.dart`, `test/screens/my_care/medication_schedule_screen_test.dart`, `test/screens/my_care/service_detail_screen_test.dart`, `test/screens/orders/quote_pending_surfaces_test.dart`, `test/screens/reports/vitals_screen_test.dart`, `test/screens/services/equipment_rail_classification_test.dart`, `test/screens/services/reserve_flow_negative_test.dart`, `test/utils/validators_test.dart`, `test/widgets/care_pulse_ring_test.dart`, `test/widgets/day_part_header_test.dart`, `test/widgets/glass_app_bar_test.dart`. Zero phantom entries (nothing listed that is missing from disk).
  - `docs/TEST_MAP.md:286` — "All **1336** tests now pass; 17 are skipped" — a stale number left three refreshes behind.
- ❌ **[+] ACCESSIBILITY_AUDIT.md** — does not exist. `grep -rliE "contrast ratio|WCAG|screen reader|dynamic type|touch target"` across all `.md` hits only BUILD_LOG, CHANGELOG, FEATURE_TRACKER and CLAUDE.md — passing mentions, no audit. `docs/FEATURE_TRACKER.md:237` itself grades "WCAG Accessibility — **In Progress** — Colors are AA compliant, semantic labels partial" with no measurement behind it.
- ⚠️ **[+] CODE_REVIEW / AUDIT_FINDINGS.md** — partial. `docs/VISUAL_CONSISTENCY_AUDIT.md`
  is a **model** point-in-time record: dated (`:11`), method stated (`:12-15`), and topped
  with a RESOLVED banner (`:3-9`) that says which parts were later superseded — exactly
  what this checklist section asks for. `docs/KNOWN_ISSUES.md` tracks findings with
  Found/Status columns. But there is no general code-review findings doc, and
  `docs/KNOWN_ISSUES.md:5` self-reports "**Last updated: 2026-05-28**" while its own git
  mtime is 2026-06-11 — the doc misstates its own currency.
- ❌ **[~] SECURITY_REVIEW.md** — trigger emphatically met (Firebase phone auth, Razorpay
  payments, patient PII, medication data, on-device PDF export of medical records). No
  security review document exists. Security content is scattered across
  `README.md:368-378` (a 7-row table), `docs/KNOWN_ISSUES.md` BUG-33/BUG-34, and
  `docs/DEPLOYMENT_GUIDE.md:326-437` (Firebase Console hardening). *Positive verification:*
  the `ANTHROPIC_API_KEY` claim holds — `grep -rn "ANTHROPIC" lib/ assets/ android/ ios/`
  returns **nothing**, and the key is a Firebase secret at `functions/index.js:21,114,153`.

### Section 6 — Compliance & ship (the store gate)

- ❌ **[R] PRIVACY_POLICY.md** — does not exist in the repo. The app links out to
  `https://housepital.in/privacy` (`lib/screens/settings/about_screen.dart:103-104`).
  There is no in-repo document enumerating what the code actually collects (phone number,
  patient PII, medical history, vitals, medication logs, addresses in SharedPreferences,
  FCM tokens, Firestore chat, Crashlytics, assistant transcripts to a Cloud Function).
  **Impact:** App Store / Play submission gate. **Fix:** author it from the real data
  flows in `api_service.dart`, `firebase_service.dart`, `cache_service.dart` and
  `functions/index.js`; publish at the URL the app already points to.
- ❌ **[R] DATA_HANDLING.md (+ store privacy-label answers)** — does not exist. No
  pre-filled App Store "Data Collected"/Play "Data safety" answers anywhere in the repo.
  This is the single most-missed item and it is missed here.
- ⚠️ **[R] RELEASE_CHECKLIST.md** — no file, but `docs/DEPLOYMENT_GUIDE.md` substitutes
  substantially: signing (`:239`, `:258`), version bump (`:242`, `:452`), schema deploy
  (`:92-110`), rules deploy (`:385`), store distribution (`:308-311`), a 13-line
  post-deployment checklist (`:438-454`) and a rollback procedure per surface (`:456-480`).
  Missing for a store cut: screenshots, App Review notes, privacy-label answers, and a
  TestFlight/internal-testing sequence. Not top-to-bottom cuttable yet.
- ❌ **[~] THIRD_PARTY_LICENSES.md** — trigger met (40 direct dependencies in
  `pubspec.yaml`, full `pubspec.lock` present). No generated license file;
  `grep -rn "THIRD_PARTY\|licenses" docs/ *.md` → nothing.
- ❌ **[~] TERMS_OF_SERVICE.md** — trigger met (accounts + payments). No in-repo terms;
  the app links to `https://housepital.in/terms` (`about_screen.dart:97-98`).
  **BLOCKED-OWNER** on whether those two URLs are live and current — see below.

### Section 7 — Per-feature docs

- ⚠️ **[R] Spec** (`specs/YYYY-MM-DD-<feature>-design.md`) — the pattern exists and is
  followed correctly *where used*: `docs/superpowers/specs/2026-03-21-my-care-tab-design.md`,
  `…/2026-03-23-unified-my-orders-design.md`, `…/2026-06-02-home-assistant-blogs-design.md`.
  Three specs total. Significant features shipped **without** one: Care Calendar, Care Team
  hub, true-black dark mode, the Liquid Glass chrome system, the manpower-pricing reversal,
  equipment catalog dedup/repricing, bundled product images, on-device PDF services, and
  field rounds 3–7. Each of those is well past "would a reviewer want the rationale
  written down?"
- ⚠️ **[R] Plan** (`plans/YYYY-MM-DD-<feature>.md`) — four plans exist
  (`2026-03-21-my-care-tab`, `2026-03-23-unified-my-orders`, `2026-06-02-ai-assistant`,
  `2026-06-02-home-layout-b`). Same coverage gap as specs; nothing after 2026-06-02.
- ❌ **[R] Living docs updated when a feature lands** — **this is the failure.** See "The
  headline finding". Four commits on 2026-06-15 (incl. a 729-line feature round) and the
  uncommitted five-tab nav change shipped with zero updates to the §2 docs. Every
  six-tab/Calendar-tab line catalogued in this report is a direct consequence.

### Section 8 — Ops / infra

- ⚠️ **[~] CI.md** — trigger met (`.github/workflows/ci.yml` exists). No CI doc; the
  workflow is unusually well self-commented (`ci.yml:18-21`, `:28-32`, `:43-53`, `:57-65`,
  `:97-100`), which carries most of the weight. The only prose description of the pipeline
  (`CONTRIBUTING.md:31-34`) is wrong — it lists 3 of the 5 steps.
- ✅ **[~] DEPLOYMENT.md** — trigger met; `docs/DEPLOYMENT_GUIDE.md` is thorough and
  end-to-end: Firebase setup, Cloud SQL provisioning + migrations, Cloud Functions deploy,
  Android/iOS builds, DNS, Razorpay webhooks, a 6-step pre-launch console-hardening
  checklist (`:326-437`), post-deploy verification and rollback. Last touched 2026-06-11.
- ❌ **[~] RUNBOOK.md** — trigger met (a live Cloud Function + Cloud SQL + Razorpay
  webhook receiver). No incident-response, on-call, alerting-threshold or
  common-production-failure document. `docs/TROUBLESHOOTING.md` is developer-machine
  troubleshooting (`Last updated: 2026-03-24`), not an ops runbook.

---

## Blockers (must fix before release)

**B-1 · The dead "never show manpower prices" rule is still asserted as current in 6 places.**
`CLAUDE.md:23-32`, `docs/BUSINESS_RULES.md:7-11`, `PROJECT.md:115`, `README.md:416`,
`docs/SCREEN_MAP.md:65` and `docs/FEATURE_TRACKER.md:121` all correctly state the live rule
(prices shown, directly bookable) — **CLAUDE.md and BUSINESS_RULES.md agree with each other
exactly**. But these contradict it outright:

| File:line | Text | Verdict |
|---|---|---|
| `SCREENS_IMPLEMENTATION.md:288` | "NEVER shows prices for manpower services (nursing, caretaker, japa, nanny)." | Dead rule, stated as current |
| `docs/API_REFERENCE.md:385` | "Prices are hidden (null) for manpower services where `hide_price = true`." | Dead rule, in the API contract |
| `docs/DATABASE_SCHEMA.md:155` | "`hide_price` … DEFAULT FALSE -- **Never show price to user**" | Dead rule, in the schema |
| `docs/DATABASE_SCHEMA.md:148` | "`base_price_min` … NULL = hide price (manpower)" | Dead rule |
| `docs/services-tab.md:154`, `:386`, `:74` | "**Never show prices for manpower services** (nurse, caretaker, japa, nanny) — users reject without speaking to sales" | Dead rule ×3, undated doc |
| `docs/my-care-tab.md:197` | "**Never show prices for manpower services** (caretaker, nursing, japa, nanny)" | Dead rule |

These also re-import the Japa/Nanny offerings that `CLAUDE.md:38-39` and `PROJECT.md:116`
say belong to Dai Maa, a separate business. `docs/BUILD_LOG.md:311` and
`docs/CHANGELOG.md:447-449,665,714` also contain the old rule, but those are dated
historical records and are **legitimate** — do not rewrite them.
**Fix:** correct the six live docs above; add a one-line "superseded 2026-06-11" banner to
`SCREENS_IMPLEMENTATION.md`, `docs/services-tab.md`, `docs/my-care-tab.md`.

**B-2 · The dead rule also survives in shipped code comments and one test name.**
- `lib/screens/assistant/assistant_local_actions.dart:21` — "Business rule: manpower prices are NEVER shown".
- `lib/screens/my_care/widgets/doctor_advice_card.dart:7-8` — "Manpower services must never show prices (**hard business rule**)".
- `lib/services/invoice_pdf_service.dart:10` — "manpower prices are never displayed before the confirmation call".
- `lib/services/handover_report_service.dart:14` — "manpower prices are never displayed in any case".
- `test/screens/orders/quote_pending_surfaces_test.dart:5` — "Manpower prices are never…".
- `test/screens/assistant/assistant_executor_test.dart:476` — `expect(order['totalAmount'], 0); // manpower rule: no price, ever`.
- `test/screens/services/staff_role_sheet_test.dart:168` — `testWidgets('sheet shows no prices for manpower', …)` asserting `find.textContaining('₹')` finds nothing.

The *behavior* at `staff_role_sheet_test.dart:168` is actually intentional and current —
`lib/screens/services/cards/staff_role_card.dart:19-20` documents that the sheet defers the
price to the booking wizard ("owner rule re-confirmed 2026-06-11: manpower prices are shown").
So the code is right; the **names and comments** invoke a rule the owner killed, and are
exactly what would seed a fourth regression. **Fix:** reword the comments and rename the test
to `'needs sheet defers price to the booking wizard'`.

**B-3 · No PRIVACY_POLICY.md and no DATA_HANDLING.md / store privacy-label answers.**
Both are `[R]` on this checklist and both are hard store-submission gates for an app that
collects phone numbers, medical history, vitals, medication logs and addresses. See §6.

**B-4 · No QA_CHECKLIST.md.** `[R]`. There is no recorded manual pass over SOS, payment,
medication logging or staff-OTP on a real device.

## High

**H-1 · Nine live doc lines still assert six tabs / a Calendar tab.** Every one is now false:

| File:line | Claim |
|---|---|
| `README.md:44` | "6 bottom tabs (Home, My Care, Services, Calendar, Billing, More)" |
| `README.md:278` | "### Tab 4 — Calendar (root tab)" (section runs :278-284) |
| `README.md:279` | "Care Calendar is a root bottom-tab (index 3, between Services and Billing)" |
| `docs/ARCHITECTURE.md:68` | "main_shell.dart … (6 tabs: Home/My Care/Services/Calendar/Billing/More)" |
| `docs/ARCHITECTURE.md:207-208` | "Six root tabs (Calendar added at index 3 — indices 1/2 referenced externally)" |
| `docs/SCREEN_MAP.md:6` | "Bottom Tab Bar (MainShell -- 6 tabs …)" |
| `docs/SCREEN_MAP.md:10` | "\|-- [3] Calendar -> CareCalendarScreen" |
| `docs/SCREEN_MAP.md:15` | "**Calendar was added as a root tab at index 3** (field round 4-5)" |
| `docs/SCREEN_MAP.md:73-77` | "### CALENDAR TAB (Index 3)" section |
| `docs/FEATURE_TRACKER.md:143` | "Care Calendar added as root tab at **index 3** (… = SIX tabs)" |
| `PROJECT.md:4` | "six field-feedback rounds (3–6) shipped: … **Calendar root tab** …" |

Ground truth: `lib/screens/main_shell.dart:36-42` (five screens), `:81-105` (five
`BottomNavigationBarItem`s), `lib/screens/my_care/my_care_screen.dart:89-95` (calendar moved to
the My Care app-bar action → `/care-calendar`), `test/screens/main_shell_test.dart:234`
(`expect(bar.items, hasLength(5))`) and `:242` (`expect(barLabel('Calendar'), findsNothing)`).
`docs/CHANGELOG.md:56,64` also describes the six-tab change but is a dated historical entry — leave it.

**H-2 · SCREEN_MAP.md documents a screen class that does not exist.** `BookingHistoryScreen`
at `docs/SCREEN_MAP.md:62` and `:217`; `docs/FEATURE_TRACKER.md:123,124,126` names it as the
frontend for three "Done" features (Booking Cancellation, Post-Service Rating, Booking History).
`lib/main.dart:602-604` routes `/booking-history` to `MyOrdersScreen` as a legacy alias.
**Impact:** three features are marked Done against a widget that isn't there — the cancel and
rate flows need re-verification against `my_orders_screen.dart`.

**H-3 · ARCHITECTURE.md misstates the provider wiring** (10 vs 11; `RemindersProvider` absent
from `:17`, `:56-66`, `:348-361`). This is the exact doc a new contributor reads to learn state
flow, and it omits a registered, persisted, tested provider.

**H-4 · TEST_MAP.md's "complete inventory" is 13 files short** while its own header says 99.
See §5 for the list.

## Medium / Low

- **M-1 · The "37 screens × 3 widths" overflow-guard figure is stale in 8 places.** Static
  count of `test/screens/overflow_smoke_test.dart`: 20 `noArg(...)` calls + 14 `argScreen(...)`
  calls + 5 explicit `testWidgets` (Home, My Care, Assistant, Onboarding, OTP) = **39 screens**,
  × 3 sizes (`_phoneSizes` at `:101-105`) = **117 tests**, not 111. `4a37c2a` added entries
  without updating the count. Stale at: `CLAUDE.md:13`, `README.md:210`, `:362`, `:389`,
  `:409` (which also states "111"), `docs/TEST_MAP.md:4`, `:119`, `:208`,
  `docs/FEATURE_TRACKER.md:260`. (`docs/CHANGELOG.md:201` is historical — leave it.)
- **M-2 · FEATURE_TRACKER.md self-dates to 2026-06-11** (`:3`) while its git mtime is
  2026-06-15 and four commits have landed since. It has **no entry** for field round 7
  (`4a37c2a`), the nurse/caretaker scope correction (`bc73765`), or the receipt-PDF / top-toast
  / sleep-study-slot work (`803124d`). `grep -ci` for "toast", "receipt", "sleep", "staff_otp",
  "AddPatient", "CarePulse" → **0 hits each**.
- **M-3 · FEATURE_TRACKER.md has an orphaned table.** The Billing & Payments table starts at
  `:153` with no `##` heading above it — it reads as a continuation of "Care Calendar & Care Team".
- **M-4 · SCREENS_IMPLEMENTATION.md:5 claims "Total Screens: 33"** against 91 Dart files under
  `lib/screens/` and README's own "40+ screens". Undated, last touched 2026-03-21, and it carries
  the dead pricing rule (B-1). It is a trap for anyone who opens it.
- **M-5 · Root `ARCHITECTURE.md` stub is correct** (`:1-8`, explicitly a redirect to
  `docs/ARCHITECTURE.md`, consolidation dated) — but `PROJECT.md:81,90` still flags the
  duplication as an open TODO. The TODO is resolved; the doc doesn't know it.
- **M-6 · KNOWN_ISSUES.md:5 self-reports "Last updated: 2026-05-28"** while git says 2026-06-11.
- **M-7 · Three different Flutter versions** across `README.md:26` (3.16+), `PROJECT.md:29`
  (3.41+), `ci.yml:22` (pinned 3.41.2). `pubspec.yaml:7` only constrains Dart (`sdk: ^3.11.0`).
- **L-1 · README.md's "Remaining Steps for Production" (`:425-434`) is stale beyond
  `_loadMockData`:** step 8 asks to "Add screen-level tests for critical flows (booking,
  payment)" — `test/screens/services/service_booking_test.dart` and
  `test/services/payment_service_test.dart` have existed for months.
- **L-2 · `PROJECT.md:31` broken anchor** (`#-tech-stack` → should be `#tech-stack`).
- **L-3 · `PROJECT.md:68` and `:22-23` unresolved TODOs** (credential vault, brand guidelines
  link, master pricing Excel link) sitting in a doc that markets itself as the meta layer.
- **L-4 · `docs/my-care-tab.md` and `docs/services-tab.md` carry no date and no status banner** —
  the one thing `docs/VISUAL_CONSISTENCY_AUDIT.md:3-9` gets right and these two get wrong.

## BLOCKED-OWNER

- **Liveness/currency of `https://housepital.in/privacy` and `https://housepital.in/terms`**
  (linked from `lib/screens/settings/about_screen.dart:98,104`). I cannot fetch them. Needed:
  confirmation that both resolve, and whether their content matches the app's real data flows —
  the checklist requires the privacy policy be "publishable as a URL" *and* cover every flow
  the code performs.
- **App Store Connect / Play Console privacy-label answers** — whether any have already been
  filled in the consoles (the repo has none). Needed to know if DATA_HANDLING.md is a
  transcription job or a from-scratch authoring job.
- **Whether the brand guidelines PDF exists outside the repo** (`PROJECT.md:22` TODO). If it
  lives in Drive/Notion, the fix is a link; if not, it's a deliverable.
- **CI green/red status and the current coverage percentage** — `.github/workflows/ci.yml:66-79`
  enforces a 50% line-coverage gate, but I was instructed not to run the suite and cannot read
  GitHub Actions. Needed to confirm `docs/TEST_MAP.md:5`'s "all passing" claim.
- **Where credentials are vaulted** (`PROJECT.md:68`: "_TODO: confirm + link (1Password? Doppler?)_").

---

## What is genuinely good (so it doesn't get lost)

- `docs/SCREEN_MAP.md`'s 52-row route table diffs **perfectly** against `lib/main.dart` — zero
  drift in either direction. Whoever maintains that table is doing it right.
- `docs/VISUAL_CONSISTENCY_AUDIT.md:3-15` is the template every other audit doc in this repo
  should copy: dated, method stated, RESOLVED banner, explicit note on which findings were later
  superseded.
- `CLAUDE.md` is the single most accurate document in the repo and the only one already correct
  on the five-tab nav. Its "Inviolable business rules" and "Widget-test pitfall" sections are
  real, specific, hard-won traps.
- `docs/DEPLOYMENT_GUIDE.md:326-437` (Firebase Console hardening) and `:456-480` (rollback per
  surface) are production-grade.
- `.github/workflows/ci.yml` is self-documenting to a degree that makes the missing CI.md a
  low-severity gap rather than a real one.
- The `ANTHROPIC_API_KEY` server-side-secret claim is **true** and verified.
