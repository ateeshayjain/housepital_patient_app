# Documentation Checklist — Audit round 2 vs commit `820060b`

**Date:** 2026-08-03 · **Auditor:** Documentation audit agent
**Repo:** `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`
**HEAD:** `820060b` (2026-08-03) on `fix/five-tab-nav` · **Working tree:** clean (`git status --porcelain` → empty)
**Previous round:** commit `803124d` + dirty tree

> Every verdict is verified against code or a command's output. No verdict is taken from a
> document's own self-description.

---

## The round-2 headline

**Three commits have landed since round 1. Exactly one non-audit `.md` file was touched by any
of them, and it was `CLAUDE.md` both times.**

```
$ git log -4 --format='%h %cd %s' --date=short
820060b 2026-08-03 fix: close the ten release blockers from the 11-checklist audit
9c39dc1 2026-08-03 docs: add 11-checklist audit reports + synthesis
0a62955 2026-08-03 fix: five bottom tabs — move care calendar into the My Care app bar
803124d 2026-06-15 fix: staff profile identity, top toasts, sleep-study overnight slot, receipt PDF
```

Per-commit `.md` footprint (`git show --stat <sha> | grep '\.md'`):

| Commit | Scope | `.md` files touched |
|---|---|---|
| `0a62955` | five-tab nav change | `CLAUDE.md` only (+8/−3) |
| `9c39dc1` | audit reports | `docs/audits/*` only (12 new files) |
| `820060b` | **39 files, 1,107 insertions** — 5 new `lib/` files, a new route, `storage.rules`, `firebase.json`, `Info.plist`, app icons, a new test file | **`CLAUDE.md` only (+12/−…)** |

`820060b` is the largest single change in the repo's recent history and it updated **zero**
files under `docs/`. Git mtimes make the shape unmistakable:

```
$ for f in <20 live docs>; do git log -1 --format=%cd --date=short -- $f; done
CLAUDE.md                 2026-08-03   ← the only doc that moved
docs/ARCHITECTURE.md      2026-06-15
docs/SCREEN_MAP.md        2026-06-15
docs/TEST_MAP.md          2026-06-15
docs/FEATURE_TRACKER.md   2026-06-15
docs/CHANGELOG.md         2026-06-15
README.md / PROJECT.md    2026-06-15
docs/DEPLOYMENT_GUIDE.md  2026-06-11
CONTRIBUTING.md           2026-05-28
docs/ENVIRONMENT_SETUP.md 2026-05-28
docs/DATABASE_SCHEMA.md   2026-03-24
docs/API_REFERENCE.md     2026-03-24
docs/services-tab.md      2026-03-21
docs/my-care-tab.md       2026-03-21
SCREENS_IMPLEMENTATION.md 2026-03-21
```

This is the **fourth** repetition of the failure this audit was commissioned to find. Round 1
predicted the next feature drop would ship undocumented; it did, and it was the biggest one yet.

---

## Changed since round 1

| Round-1 finding | Status now | Evidence |
|---|---|---|
| **B-1** dead pricing rule in 6 live doc places | **UNCHANGED** — all 6 verbatim, +1 more found (9 lines / 5 files) | `SCREENS_IMPLEMENTATION.md:288`, `docs/API_REFERENCE.md:385`, `docs/DATABASE_SCHEMA.md:148,155,162`, `docs/services-tab.md:74,154,386`, `docs/my-care-tab.md:197` |
| **B-2** dead rule in 7 code/test sites incl. `'sheet shows no prices for manpower'` | **UNCHANGED — 0 of 7 fixed** | `assistant_local_actions.dart:21`, `doctor_advice_card.dart:8`, `invoice_pdf_service.dart:10`, `handover_report_service.dart:14`, `quote_pending_surfaces_test.dart:5`, `assistant_executor_test.dart:476`, `staff_role_sheet_test.dart:168` |
| **B-3** no PRIVACY_POLICY.md / DATA_HANDLING.md | **UNCHANGED** | `find . -name PRIVACY_POLICY.md -o -name DATA_HANDLING.md` → empty |
| **B-4** no QA_CHECKLIST.md | **UNCHANGED** | `find . -name QA_CHECKLIST.md` → empty |
| **H-1** 11 doc lines assert six tabs / Calendar tab | **UNCHANGED — 0 of 11 fixed**; 5 further stale lines found (16 total) | table in H-1 below |
| **H-2** `SCREEN_MAP` documents non-existent `BookingHistoryScreen` | **UNCHANGED** | `docs/SCREEN_MAP.md:62,217`; `grep -rn BookingHistoryScreen lib/` → no definition |
| **H-3** `ARCHITECTURE.md` says 10 providers, omits `RemindersProvider` | **UNCHANGED** | `docs/ARCHITECTURE.md:17,348`; `grep -c ChangeNotifierProvider lib/main.dart` → **11**; `RemindersProvider` at `lib/main.dart:217` |
| **H-4** `TEST_MAP` inventory 13 files short | **WORSE — now 14 short**, and the header count is wrong too | inventory = 86 files (`docs/TEST_MAP.md:156`); disk = **100** (`find test -name '*_test.dart' \| wc -l`); header claims 99 (`:6`) |
| **M-1** "37 screens" overflow figure stale in 8 places | **UNCHANGED** — actual still 39 screens / 117 tests | 20 `noArg` + 14 `argScreen` + 5 explicit `testWidgets` × 3 sizes (`overflow_smoke_test.dart:101-105`) |
| **M-2** `FEATURE_TRACKER` self-dates 2026-06-11, no round-7 entry | **WORSE** — now also blind to all of `820060b` | `docs/FEATURE_TRACKER.md:3`; `grep -ci 'delete account\|session scope\|demo banner\|storage rules\|migration'` → **0** |
| **M-6** `KNOWN_ISSUES.md` misstates its own date | **UNCHANGED** | `:5` says 2026-05-28, git says 2026-06-11 |
| **M-7** three Flutter versions | **UNCHANGED** | `README.md:26` 3.16+ · `PROJECT.md:29` 3.41+ · `ci.yml:22` 3.41.2 |
| **L-1/L-2/L-3** README + PROJECT.md stale steps, broken anchor, TODOs | **UNCHANGED** | `README.md:428` `_loadMockData` (still 0 hits in `lib/`), `PROJECT.md:31,68,86,92,98,101,105` |
| §5 `ACCESSIBILITY_AUDIT.md` missing | **FIXED** ✅ | `docs/audits/ACCESSIBILITY_AUDIT.md` — dated, method-stated, covers contrast (9 refs), touch targets (15), screen reader/Semantics (24), dynamic type (5) |
| §5 `SECURITY_REVIEW.md` missing | **PARTIALLY FIXED** ⚠️ | `docs/audits/SECURITY_PRIVACY_AUDIT.md` — real review (54 DPDP/PII/PHI/Razorpay/auth refs), but it is an audit snapshot, not a standing review, and is already one commit stale |
| §5 CODE_REVIEW / AUDIT_FINDINGS partial | **IMPROVED** ⚠️→ strong | `docs/audits/` now holds 11 dated reports + a synthesis |
| §8 `DEPLOYMENT_GUIDE.md` graded ✅ | **REGRESSED to ⚠️** | `storage.rules` landed in `820060b`; the guide's 8 `firebase deploy` lines never mention it — see R-2 |
| §2 `SCREEN_MAP` route table "diffs perfectly" (round 1's best find) | **REGRESSED** ❌ | `/delete-account` in code, absent from the doc — see R-1 |
| §2 `SCREEN_MAP:209` `/services` → "Scaffold (placeholder)" | **REGRESSED (doc now describes a fixed bug as live)** | `lib/main.dart:568-571` now returns `_RootTabRedirect(tabIndex: 2)` — see R-3 |

**Net movement: 2 items improved, 3 regressed, 16 unchanged.**

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Project meta | 2 | 4 | 0 | 0 |
| 2. Living technical docs | 0 | 2 | 2 | 0 |
| 3. Product / UX | 0 | 2 | 4 | 0 |
| 4. Brand / design | 0 | 2 | 1 | 0 |
| 5. Quality & audits | 1 | 3 | 1 | 0 |
| 6. Compliance & ship | 0 | 1 | 4 | 0 |
| 7. Per-feature docs | 0 | 2 | 1 | 0 |
| 8. Ops / infra | 0 | 2 | 1 | 0 |
| **TOTAL (35 items)** | **3** | **18** | **14** | **0** |

*(Round 1: 3 / 16 / 16. The two-point ❌ improvement is entirely `docs/audits/`; it is offset by
three regressions that the scorecard's granularity does not show.)*

---

## Findings

### Section 1 — Project meta

- ⚠️ **[R] README.md** — still runnable end-to-end (`README.md:61-90`), still carrying false
  claims, and now carrying more of them. Round-1 errors all survive; new ones since:
  - `README.md:44` — "**6 bottom tabs** (Home, My Care, Services, Calendar, Billing, More)" — **STALE** (`lib/screens/main_shell.dart:37-43` = five screens; `:93-113` = five `BottomNavigationBarItem`s).
  - `README.md:166` — "services/ # catalog (**6 tabs**)" — **NEW FINDING, and a different error**: the services catalog has **seven** sub-tabs (`service_catalog_screen.dart:65` `TabController(length: 7)`; labels at `:114-120` Manpower/Equipment/Consultations/Visits/Diagnostics/Lab Tests/Packages). The same wrong number is also in a code comment at `service_catalog_screen.dart:127` ("the TabBar + 6 tab bodies").
  - `README.md:278-284` — the "### Tab 4 — Calendar (root tab)" section — **STALE**. `:285` "### Tab 6 — More" — More is index **4**.
  - `README.md:148` — "# 10 providers" — actual **11** (`lib/main.dart`, `RemindersProvider` at `:217` absent from the list at `:149-158`).
  - `README.md:42` — "**149 Dart source files** | ~53,800 lines" — actual **153** files / **55,067** lines (`820060b` added 5). 2.7% and 2.4% drift.
  - `README.md:43` — "99 test files | ~1,771 tests" vs `README.md:209` "86 test files, 1,550+ tests" — the file still contradicts itself, and **both are now wrong**: actual **100** files (`patient_scope_isolation_test.dart` is new), **1,380** call sites, and the brief's central run reports **1,797** passing.
  - `README.md:45` — "**52 named routes**" — actual **53** (`/delete-account` added).
  - `README.md:428` — "AppProvider uses `_loadMockData()`" — `grep -rn _loadMockData lib/` → still **nothing**.
  - **Impact:** the front door misstates nav, sub-nav, providers, file counts, route count and test counts simultaneously.

- ✅ **[R] CLAUDE.md** — **both round-2 edits verified accurate.** This is the only doc that
  tracks the code, and it earns the grade twice over:
  - *Five-tab edit* (`CLAUDE.md:82-88`): "FIVE root tabs: Home (0), My Care (1), Services (2), Billing (3), More (4)… the care calendar is not a tab — moved to the My Care app bar (`'/care-calendar'`)". **Correct** against `main_shell.dart:37-43` (five screens, in that order), `:93-113` (five items), `my_care_screen.dart:93` (`Navigator.pushNamed(context, '/care-calendar')`), and `test/screens/main_shell_test.dart` (`expect(bar.items, hasLength(5))`).
  - *Firebase/storage-rules edit* (`CLAUDE.md:47-56`): every clause checks out —
    `git log --diff-filter=A -- ios/Runner/GoogleService-Info.plist` → **empty** (never committed, though the file is on disk) ✓; `git ls-files` shows `android/app/google-services.json` and `lib/config/firebase_options.dart` **tracked** ✓; the `.gitignore` rule at `:56-57` was added by `4bcaadb` (2026-05-28) while both files were committed by `5a0ca2e` (2026-03-22) — so "added after those files were committed, so they are inert" is **exactly right** ✓; `storage.rules` exists and `firebase.json` carries `"storage": {"rules": "storage.rules"}` ✓.
  - One inaccuracy survives: `CLAUDE.md:13` "37 screens × 320/375/414" — actual **39** (M-1).
  - **No other doc contradicts CLAUDE.md — because no other doc mentions any of this.** Zero `.md` outside `CLAUDE.md` contains `session_scope`, `demo_mode`, `store_migrator`, `delete_account`, `DeleteAccount`, `SessionScope`, `StoreMigrator`, `DemoMode` or `clearPatientScopedData`. `storage.rules` appears in exactly one doc: `CLAUDE.md:55`. The contradiction risk is not disagreement, it is **silence** — see D-1.

- ⚠️ **[+] CONTRIBUTING.md** — unchanged and still wrong on CI: `CONTRIBUTING.md:31-33` lists
  three steps (analyze → test → build web); `.github/workflows/ci.yml` has **seven named steps**,
  five of them gating — it omits *Design consistency* (`ci.yml:40`) and the *Coverage gate*
  (`ci.yml:66`). Its `flutter test` (`:33`, `:56`) still omits
  `--dart-define=RAZORPAY_KEY=rzp_test_ci_dummy_key`, which `CLAUDE.md:11` and `ci.yml:54` both
  require; copy-pasting from CONTRIBUTING silently skips the payment groups.

- ✅ **[R] LICENSE** — unchanged, still names the holder (`LICENSE:1-19`).

- ⚠️ **[+] CHANGELOG.md** — **worse.** Newest entry is still `## [2026-06-13]`
  (`docs/CHANGELOG.md:7`). Undocumented now: the four 2026-06-15 commits *plus* the five-tab
  change *plus* all ten blocker fixes in `820060b` — including account deletion, PHI session
  scoping, a storage-rules file, a persistent demo banner, a storage migrator and a payment
  fail-closed change. For a user-facing changelog on an app about to submit, the account-deletion
  feature alone is a required entry.

- ⚠️ **[+] STATE.md / STATUS.md** — `PROJECT.md` fills the role and is **more stale than in
  round 1**. Every round-1 defect survives (`:4` Calendar root tab, `:86` vs `:92` self-contradiction
  six lines apart, `:98` "In flight: PRs #10/#11/#12", `:101` Crashlytics listed as a pre-launch
  TODO while `docs/FEATURE_TRACKER.md:239,241` marks it Done, `:105` coverage gate listed as TODO
  while `ci.yml:66-79` enforces it, `:31` broken `#-tech-stack` anchor, `:68` credential-vault TODO).
  Added drift: nothing in `PROJECT.md` knows the app now has account deletion, a migration hook or
  storage rules — all three are launch-gating items its own "Pre-launch" list should carry.

### Section 2 — Living technical docs

- ❌ **[R] ARCHITECTURE.md** — the done-when is *the folder/module list matches the repo*. It
  matches less well than it did in round 1, because five files were added and none were recorded.
  - **New omissions (round 2):** `lib/utils/session_scope.dart` is absent from the `utils/` list (`:162-169`); `lib/data/demo_mode.dart` is absent from the `data/` list (`:176-179`, which lists only `care_packages.dart`, `demo_data.dart`, `demo_articles.dart`); `lib/services/store_migrator.dart` is absent from the `services/` list (`:148-161`); `lib/screens/settings/delete_account_screen.dart` is absent under `settings/` (`:136`). `grep -n "store_migrator\|session_scope\|demo_mode" docs/ARCHITECTURE.md` → **0 hits**.
  - `SessionScope` is a **cross-cutting state-lifecycle contract** — `session_scope.dart:26-46` coordinates five providers plus the cart, and its own doc comment says *"When a provider gains patient-scoped state, add it here."* That instruction is invisible to anyone reading ARCHITECTURE.md, which is the doc a new contributor opens to learn state flow. This is the single highest-consequence documentation gap in the repo right now.
  - **Round-1 omissions all survive:** `:17` "10 providers" and `:348` "Ten `ChangeNotifierProvider` instances" (actual 11); `RemindersProvider` absent from `:17`, `:56-66`, `:350-361`; `logger.dart` and `validators.dart` absent from `utils/`; `care_pulse_ring.dart`, `day_part_header.dart`, `empty_state.dart` absent from `widgets/`; `splash_screen.dart`, `settings/add_patient_screen.dart`, `assistant/assistant_local_actions.dart` and the `services/{cards,data,sheets,tabs,widgets}` subfolders absent from the screen tree.
  - `:68` "main_shell.dart # … (**6 tabs**: Home/My Care/Services/**Calendar**/Billing/More)" and `:207-208` "**Six root** tabs (Calendar added at index 3)" — **STALE**.
  - The file's own closing line (`:371`) says "this file MUST be updated in the same session". Two sessions running.

- ⚠️ **[+] DATA_MODEL.md / DATA_INFLOW.md** — no file by that name; `docs/DATABASE_SCHEMA.md`
  + `docs/API_REFERENCE.md` cover the ground in substance. Both still frozen at **2026-03-24**
  (`git log -1 --format=%cd`), both still encode the dead manpower rule (B-1). New for round 2:
  neither documents the **13 SharedPreferences namespaces** that `lib/services/store_migrator.dart`
  now versions and migrates — the app gained a client-side persistence schema with a migration
  hook (`lib/main.dart:174` `await StoreMigrator.run()`) and there is no data doc that mentions
  its existence, let alone its version contract.

- ❌ **[+] SCREENS.md** — `docs/SCREEN_MAP.md`. **This is the regression finding of round 2.**
  Round 1's single best result was that its 52-route table diffed *exactly clean* against
  `lib/main.dart`. That is no longer true:
  - **R-1 — route table has drifted.** Code has **53** routes, the doc **52**; set-diff:
    ```
    $ comm -23 <code routes> <doc routes>
    /delete-account
    ```
    `/delete-account` (`lib/main.dart:745-747` → `DeleteAccountScreen`, entered from
    `settings_screen.dart:278`) appears nowhere in the map. The doc's clean-diff property was
    broken by the very commit that fixed the App Store 5.1.1(v) blocker.
  - **R-3 — the doc now describes a fixed bug as live.** `docs/SCREEN_MAP.md:209` lists
    `/services` → widget "**Scaffold (placeholder)**". That was accurate at round 1 and is now
    false: `lib/main.dart:568-571` returns `_RootTabRedirect(tabIndex: 2)`. A doc that records a
    resolved defect as current is worse than one that is merely incomplete — it invites someone
    to "fix" it again.
  - Round-1 defects all survive: `:6` "MainShell -- **6 tabs**"; `:10` "[3] Calendar → CareCalendarScreen"; `:11-12` "[4] Billing / [5] More" (now 3 / 4); `:15` "Calendar was added as a root tab at index 3"; `:73-77` the "### CALENDAR TAB (Index 3)" section; `:81` "### BILLING TAB (Index 4)"; `:133` "### MORE TAB (Index 4)" — `:81` and `:133` still both claim index 4.
  - **`BookingHistoryScreen`** phantom unchanged at `:62` and `:217` (`grep -rn BookingHistoryScreen lib/` → no definition; `lib/main.dart` routes `/booking-history` to `MyOrdersScreen`).
  - **`SplashScreen`** and now **`DeleteAccountScreen`** appear nowhere in the map.

- ⚠️ **[~] SETUP.md** — `docs/ENVIRONMENT_SETUP.md`, unchanged since 2026-05-28.
  `grep -c dart-define docs/ENVIRONMENT_SETUP.md` → **0**, so every `flutter run` example
  (`:255,:258,:261,:370`) still silently sets up the placeholder-key demo path. New for round 2:
  the doc has no step for Firebase **Storage** at all, though `firebase.json` now declares a
  storage target and `storage.rules` exists — a fresh machine set up from this doc gets an
  emulator/console configuration that does not match the repo.

### Section 3 — Product / UX

- ❌ **[+] PERSONAS.md** — does not exist (`find . -name PERSONAS.md` → empty). Unchanged.
- ❌ **[+] PROBLEM_STATEMENTS.md** — does not exist. Unchanged.
- ❌ **[+] USER_JOURNEYS.md** — does not exist. Unchanged.
- ⚠️ **[o] USER_FLOWS.md** — `docs/services-tab.md` and `docs/my-care-tab.md` serve in substance.
  Both still undated, still no status banner, still last touched **2026-03-21**, still stating the
  dead pricing rule as current (B-1). Unchanged.
- ❌ **[~] ONBOARDING.md** — trigger met (`lib/screens/auth/onboarding_screen.dart`, `/onboarding`).
  No first-run design doc. Unchanged.
- ⚠️ **[+] ROADMAP.md** — no file; `PROJECT.md:96-106` substitutes and is stale (see §1).

### Section 4 — Brand / design

- ⚠️ **[+] BRAND.md** — no file. Tokens are documented in `CLAUDE.md:60-98` and
  `docs/ARCHITECTURE.md:182-218` and still **match the code** (`#F39314` one accent,
  `onOrange = white`, true-black tonal dark, `context.hc.*`, 11px floor, ≥44pt). The "no drift"
  half passes; the "there is a BRAND.md" half does not. Voice/tone and iconography rules absent.
  *Objective fact, owner override noted:* white `#FFFFFF` on `#F39314` measures **2.33:1**
  (orange relative luminance 0.39973); unselected nav labels at 70% alpha composite to `#FBDFB8`
  = **1.82:1**. Reported as measurement, not as a request to reverse the decision.
- ❌ **[~] Brand guidelines (PDF/source)** — `PROJECT.md:22` still literally reads
  "Brand Guidelines | _TODO: add link to Drive/Notion_". Unchanged. **BLOCKED-OWNER.**
- ⚠️ **[o] Design-system / component reference** — no catalogue. `lib/widgets/glass.dart` is the
  single chrome source, described prose-style at `docs/ARCHITECTURE.md:199-218`;
  `docs/VISUAL_CONSISTENCY_AUDIT.md:19-21` enumerates the shared kit. Unchanged.

### Section 5 — Quality & audits

- ❌ **[R] QA_CHECKLIST.md** — still does not exist. **This is now more serious than in round 1.**
  `820060b` shipped five new runtime-critical paths — account deletion, cross-provider session
  clearing on patient switch and logout, a SharedPreferences migration that runs before any
  provider reads storage (`lib/main.dart:174`), a payment path that now fails closed, and a
  persistent banner — and **not one of them has a recorded manual on-device pass**. A storage
  migrator that runs on every cold start on real patient data, with no human test record, is the
  highest-risk untested-by-hand change in the repo.

- ⚠️ **[+] TEST_RESULTS.md** — no file; `docs/TEST_MAP.md:3-6` carries the summary, now wrong in
  three of four numbers:
  - **File count 99 — now WRONG**, actual **100** (`patient_scope_isolation_test.dart` added by `820060b`).
  - **Call sites 1,370 — WRONG**, actual **1,380**.
  - **Runtime ~1,771 — WRONG**, the brief's central run reports **1,797 passing**.
  - **The "complete inventory" is now 14 files short.** `:156` is headed "complete inventory — **86 files**, 2026-06-11" and lists 86 rows while `:6` says 99 and disk says 100. Set-diff (basename, inventory rows `:156-250` only) gives 14 missing: `care_pulse_ring_test.dart`, `dark_mode_sweep_test.dart`, `day_part_header_test.dart`, `equipment_rail_classification_test.dart`, `glass_app_bar_test.dart`, `main_shell_test.dart`, `medication_schedule_screen_test.dart`, **`patient_scope_isolation_test.dart`**, `quote_pending_surfaces_test.dart`, `reminders_provider_test.dart`, `reserve_flow_negative_test.dart`, `service_detail_screen_test.dart`, `validators_test.dart`, `vitals_screen_test.dart`. **Zero phantoms** — re-verified; the entries at `:267-280` that look like phantoms are rows in the *"What's Missing"* gap table, correctly marked.
  - The 189-line `patient_scope_isolation_test.dart` is the regression guard for the PHI blocker — the most safety-relevant test added in months — and the test map does not know it exists.
  - `:286` — "All **1336** tests now pass" — four refreshes stale.

- ✅ **[+] ACCESSIBILITY_AUDIT.md** — **now exists** (`docs/audits/ACCESSIBILITY_AUDIT.md`,
  46 KB, `9c39dc1`). Meets the item: dated and method-stated in its header, and it covers all four
  named dimensions — contrast (9 references), touch targets (15), screen reader / Semantics (24),
  dynamic type / textScale (5). Round-1 ❌ → ✅.

- ⚠️ **[+] CODE_REVIEW / AUDIT_FINDINGS.md** — **substantially improved.** `docs/audits/` now
  holds 11 checklist reports plus `AUDIT_SYNTHESIS.md`. Assessed against the checklist's own bar
  for §5 — *"point-in-time records — date them, don't rewrite"* — and *"periodic review findings
  **+ resolution status**"*:
  - **Dating: passes.** All 12 carry `**Date:** 2026-08-03` and a named auditor in the first three lines; 10 of 12 also state their method (read-only, tools used, what was deliberately not run). `ACCESSIBILITY_AUDIT.md:5` even pins the dirty-tree state it audited. This is the `VISUAL_CONSISTENCY_AUDIT.md` template applied at scale, and it is the strongest documentation work in the repo.
  - **Resolution status: fails.** Of the 12, only this file (`DOCUMENTATION_AUDIT.md`) tracks whether findings were resolved. The other 11 have no "Status now" column, no RESOLVED banner, and no pointer to `820060b` — which closed ten of the blockers they raise. A reader opening `SECURITY_PRIVACY_AUDIT.md` or `RELEASE_SUBMISSION_AUDIT.md` today has no in-file way to learn that its top blockers are fixed.
  - **Commit-pinning is now wrong on all 12.** Eleven are headed "vs commit `803124d`" and the synthesis "vs `0a62955`". Both are superseded by `820060b`. That is legitimate for a dated snapshot *provided the snapshot is not read as current* — and nothing in the folder says which commit is current, so it will be.
  - **Process finding — the "don't rewrite" rule is being violated by the audit process itself.** This checklist explicitly says audit records are point-in-time and must not be rewritten; the round-2 brief instructs each agent to *"rewrite your report file in place."* Round 1's graded record no longer exists anywhere in the repo except as the "Changed since round 1" table above. **Fix:** keep rounds as separate dated files (`DOCUMENTATION_AUDIT_2026-08-03-r1.md`, `…-r2.md`) or add a RESOLVED banner to the round-1 file and write round 2 beside it.

- ⚠️ **[~] SECURITY_REVIEW.md** — trigger emphatically met (phone auth, Razorpay, PHI, medication
  data, on-device PDF export of medical records). No file of that name, but
  `docs/audits/SECURITY_PRIVACY_AUDIT.md` (53 KB) is a real review — 54 references across
  DPDP/PII/PHI/Razorpay/auth, full-git-history secret sweep, Firestore-rules assessment. Round-1
  ❌ → ⚠️. Held back from ✅ because: (a) it is a one-off snapshot, not a maintained review;
  (b) it is pinned to `803124d` and its findings on storage rules, account deletion and PHI
  scoping were addressed by `820060b` with no update; (c) the **live security posture of
  `storage.rules` is unknown** — the file exists and `firebase.json` declares it, but per the
  brief it is not deployed, and no doc records deploy state. *Positive verification retained:*
  `grep -rn ANTHROPIC lib/ assets/ android/ ios/` → **nothing**; the key is a Firebase secret at
  `functions/index.js:21,114,153`.

### Section 6 — Compliance & ship (the store gate)

- ❌ **[R] PRIVACY_POLICY.md** — still does not exist. The app still links out to
  `https://housepital.in/privacy` (`lib/screens/settings/about_screen.dart:103-104`). **Round 2
  adds two data flows the (nonexistent) policy would now have to cover:** account deletion
  (`delete_account_screen.dart` — what is erased, what is retained, over what period) and the
  demo-data disclosure (`lib/data/demo_mode.dart` — the app now formally admits it may show
  another patient's sample record). DPDP §12 (right to erasure) is precisely what
  `/delete-account` implements, and there is no policy text behind it.
- ❌ **[R] DATA_HANDLING.md (+ store privacy-label answers)** — still does not exist. Still the
  single most-missed item, still missed.
- ⚠️ **[R] RELEASE_CHECKLIST.md** — no file; `docs/DEPLOYMENT_GUIDE.md` substitutes for the
  deploy half (signing `:239,:258`, version bump `:242,:452`, schema `:92-110`, rules `:385`,
  store distribution `:308-311`, post-deploy checklist `:438-454`, rollback `:456-480`). Still
  missing for a store cut: screenshots, App Review notes, privacy-label answers, TestFlight
  sequence — **and now a `firebase deploy --only storage` step (R-2)** and an account-deletion
  review note, which Apple requires be described in App Review notes.
- ❌ **[~] THIRD_PARTY_LICENSES.md** — trigger met, no generated file. Unchanged.
- ❌ **[~] TERMS_OF_SERVICE.md** — trigger met, no in-repo terms; app links to
  `https://housepital.in/terms` (`about_screen.dart:97-98`). Unchanged. **BLOCKED-OWNER.**

### Section 7 — Per-feature docs

- ⚠️ **[R] Spec** — three specs, all in `docs/superpowers/specs/`, newest **2026-06-02**. The
  pattern is followed correctly where used. Ten blocker fixes shipped in `820060b` with no spec;
  at least three clear the "would a reviewer want the rationale written down?" bar on their own —
  **account deletion** (a legal-obligation feature with irreversible effects), **`SessionScope`**
  (a cross-provider lifecycle contract other code must now obey), and **`StoreMigrator`** (a
  persistence schema-versioning scheme that constrains every future storage change). Prior gaps
  unchanged: Care Calendar, Care Team, dark mode, Liquid Glass, the pricing reversal, catalog
  repricing, PDF services, field rounds 3–7.
- ⚠️ **[R] Plan** — four plans, newest **2026-06-02**. Same gap.
- ❌ **[R] Living docs updated when a feature lands** — **the failure, repeated at larger scale.**
  `820060b`: 39 files, 1,107 insertions, 5 new `lib/` files, 1 new route, 1 new test file, a new
  security-rules file — and **one** `.md` touched (`CLAUDE.md`). Every §2 doc is now behind by a
  full release-blocker sweep. Round 1 called this "the third repetition"; this is the fourth, and
  the first where the undocumented change is legally and clinically load-bearing.

### Section 8 — Ops / infra

- ⚠️ **[~] CI.md** — trigger met, no CI doc. `ci.yml` remains unusually self-commented
  (`:18-21,:28-32,:43-53,:57-65,:97-100`), carrying most of the weight; the only prose
  description (`CONTRIBUTING.md:31-33`) still lists 3 of 5 gating steps. Unchanged.
- ⚠️ **[~] DEPLOYMENT.md** — **DOWNGRADED from ✅.** `docs/DEPLOYMENT_GUIDE.md` is still
  thorough and end-to-end, but **R-2**: `820060b` added `storage.rules` (90 lines, default-deny
  + per-patient chat/concern photo paths) and a `storage` block to `firebase.json`, and the
  deployment guide — the document someone actually follows to ship — never mentions Firebase
  Storage. Its eight `firebase deploy` invocations (`:46,:57,:165,:168,:312,:391,:407,:467`)
  include `--only firestore:rules`, `--only firestore:indexes`, `--only functions`,
  `--only hosting`, and a bare `firebase deploy`, but **no `--only storage`**; the pre-launch
  hardening section at `:385-391` deploys `firestore:rules` alone. `CLAUDE.md:55-56` is the only
  place in the repo that says the rules must be deployed and that "editing the file alone changes
  nothing live" — and CLAUDE.md is not the release runbook. **Following DEPLOYMENT_GUIDE.md
  top-to-bottom today ships the app with undeployed storage rules.**
- ❌ **[~] RUNBOOK.md** — trigger met (live Cloud Function + Cloud SQL + Razorpay webhook). No
  incident-response, on-call, alerting or common-failure doc. `docs/TROUBLESHOOTING.md`
  (2026-03-25) is developer-machine troubleshooting. Unchanged.

---

## Is AUDIT_SYNTHESIS.md still current?

**No — it is materially out of date, and it is the most likely document to be read first.**
It is pinned to `0a62955` (`AUDIT_SYNTHESIS.md:3`), one commit before `820060b` closed the
blockers it ranks. Specifically:

| Synthesis claim | Status vs `820060b` |
|---|---|
| §1 "There is **no banner anywhere in `lib/`**" | **False** — `main_shell.dart:132-160` `_DemoDataBanner`, driven by `DemoMode.isServingDemoData` (`lib/data/demo_mode.dart:16`) |
| §2 "Money can be taken without being verified"; "`createOrder` has zero callers" | **Fixed** per brief item 3 (`payment_service.dart`, `payment_screen.dart`) |
| §3 "One patient's medical data renders under another patient's name" | **Fixed** — `SessionScope` + five `clearPatientScopedData()` implementations + `patient_scope_isolation_test.dart` |
| Blocker 1 (Info.plist keys) | **Fixed** — `ios/Runner/Info.plist:73,75` |
| Blocker 2 (stock Flutter icon) | **Fixed** — icon + launch assets replaced in `820060b` |
| Blocker 4 (`/services` blank Scaffold) | **Fixed** — `lib/main.dart:568-571` |
| Blocker 6 (Firebase config tracked, CLAUDE.md claim wrong) | **Claim corrected** — `CLAUDE.md:47-54` now states the tracked/inert facts accurately; the files remain tracked |
| Blocker 7 (no Storage rules) | **Partially** — `storage.rules` + `firebase.json` exist; **deployment unverified** |
| Blocker 8 (no account deletion) | **Fixed** — `/delete-account` + Settings entry |
| Blocker 10 (no schema version / migration hook) | **Fixed** — `store_migrator.dart`, `lib/main.dart:174` |
| "1,372 tests" | Now 1,380 call sites / 1,797 runtime |

Eight of its ten ranked blockers and three of its five cross-confirmed findings are stale, with
**no banner, no status column and no superseding note** anywhere in the file. Its own §"Documentation
drift" section — "six live docs and seven code/test sites… eleven doc lines still assert six tabs" —
is, ironically, the one part still perfectly accurate.

**Fix:** add a dated header banner to `AUDIT_SYNTHESIS.md` — *"Superseded in part by `820060b`
(2026-08-03): blockers 1–5, 8, 10 closed; 7 partially (rules written, deployment unverified)"* —
and a Status column on the blocker table. Do not rewrite the body; it is a valid point-in-time record.

---

## Blockers (must fix before release)

**B-1 · The dead "never show manpower prices" rule is still asserted as current — 9 lines / 5 live docs. 0 fixed since round 1.**

| File:line | Text | Verdict |
|---|---|---|
| `SCREENS_IMPLEMENTATION.md:288` | "NEVER shows prices for manpower services (nursing, caretaker, japa, nanny)." | Dead rule as current |
| `docs/API_REFERENCE.md:385` | "Prices are hidden (null) for manpower services where `hide_price = true`." | Dead rule, in the API contract |
| `docs/DATABASE_SCHEMA.md:148` | "`base_price_min` … NULL = hide price (manpower)" | Dead rule |
| `docs/DATABASE_SCHEMA.md:155` | "`hide_price` … DEFAULT FALSE -- Never show price to user" | Dead rule, in the schema |
| `docs/DATABASE_SCHEMA.md:162` | "When `hide_price = TRUE`… applies to caretaker, nursing, japa, and nanny services." | **NEW** — also re-imports Dai Maa offerings |
| `docs/services-tab.md:74` | "**Manpower** (all `bookingType: 'assessment'`, no prices shown)" | Dead rule |
| `docs/services-tab.md:154` | "Never show prices for manpower services… users reject without speaking to sales" | Dead rule |
| `docs/services-tab.md:386` | same, + "Physio is the exception" | Dead rule |
| `docs/my-care-tab.md:197` | "Never show prices for manpower services (caretaker, nursing, japa, nanny)" | Dead rule |

Correct and mutually consistent: `CLAUDE.md:23-32`, `docs/BUSINESS_RULES.md:7-11`, `PROJECT.md:115`,
`README.md:416`, `docs/SCREEN_MAP.md:65`, `docs/FEATURE_TRACKER.md:121`.
`docs/BUILD_LOG.md:311` and `docs/CHANGELOG.md:35,714` are dated historical records — **legitimate,
do not rewrite.**
**Fix:** correct the nine lines; add a "superseded 2026-06-11" banner to `SCREENS_IMPLEMENTATION.md`,
`docs/services-tab.md`, `docs/my-care-tab.md`.

**B-2 · The dead rule survives in 7 shipped code/test sites. 0 of 7 fixed.** Verbatim, unchanged:
- `lib/screens/assistant/assistant_local_actions.dart:21` — "Business rule: manpower prices are NEVER shown"
- `lib/screens/my_care/widgets/doctor_advice_card.dart:8` — "never show prices (hard business rule)"
- `lib/services/invoice_pdf_service.dart:10` — "manpower prices are never displayed before the confirmation call"
- `lib/services/handover_report_service.dart:14` — "manpower prices are never displayed in any case"
- `test/screens/orders/quote_pending_surfaces_test.dart:5` — "Manpower prices are never…"
- `test/screens/assistant/assistant_executor_test.dart:476` — `expect(order['totalAmount'], 0); // manpower rule: no price, ever`
- `test/screens/services/staff_role_sheet_test.dart:168` — `testWidgets('sheet shows no prices for manpower', …)`

The **behavior** at `staff_role_sheet_test.dart:168` remains correct and intentional —
`lib/screens/services/cards/staff_role_card.dart:19-20` documents that the sheet defers price to
the booking wizard ("owner rule re-confirmed 2026-06-11: manpower prices are shown"). The code is
right; the **names and comments** invoke a rule the owner killed. An active test asserting
`find.textContaining('₹')` finds nothing, under a name that states the dead rule, is exactly what
seeds a fifth regression. **Fix:** reword the four comments; rename the test to
`'needs sheet defers price to the booking wizard'`.

**B-3 · No PRIVACY_POLICY.md and no DATA_HANDLING.md.** Both `[R]`, both hard store gates, both
still absent — now with account deletion and demo-data disclosure added to the flows they must cover.

**B-4 · No QA_CHECKLIST.md.** `[R]`. No recorded manual pass over SOS, payment, medication logging,
staff-OTP — or over any of the five new runtime-critical paths in `820060b`, including a storage
migrator that runs on every cold start.

## High

**R-1 · REGRESSION — `docs/SCREEN_MAP.md`'s route table no longer matches the code.** Round 1's
best-verified property is gone: code 53 routes, doc 52, `/delete-account` missing
(`lib/main.dart:745-747`, `settings_screen.dart:278`). **Impact:** the one doc that could be
trusted structurally now cannot. **Fix:** add the `/delete-account` row and `DeleteAccountScreen`
to the widget table.

**R-2 · REGRESSION — `docs/DEPLOYMENT_GUIDE.md` will ship the app with undeployed Storage rules.**
`storage.rules` + the `firebase.json` storage block landed in `820060b`; the guide's eight
`firebase deploy` lines never include `--only storage`, and `:385-391` (pre-launch hardening)
deploys `firestore:rules` alone. Only `CLAUDE.md:55-56` knows. **Impact:** chat and concern-evidence
photos ship under the default Storage posture. **Fix:** add `firebase deploy --only storage` to
`:385-391` and to the post-deploy verification list at `:438-454`.

**R-3 · REGRESSION — `docs/SCREEN_MAP.md:209` documents a fixed bug as current.** `/services` is
listed as "Scaffold (placeholder)"; `lib/main.dart:568-571` now returns `_RootTabRedirect(tabIndex: 2)`.

**D-1 · Five new code artifacts are invisible to every doc.** `grep -rn` across all non-audit
`.md` returns **zero hits** for `session_scope`, `demo_mode`, `store_migrator`, `delete_account`,
`DeleteAccount`, `SessionScope`, `StoreMigrator`, `DemoMode`, `clearPatientScopedData`.
`storage.rules` has exactly one hit (`CLAUDE.md:55`).

| Artifact | SCREEN_MAP | ARCHITECTURE | TEST_MAP | FEATURE_TRACKER |
|---|---|---|---|---|
| `lib/utils/session_scope.dart` | n/a | ❌ absent (`:162-169`) | ❌ (`patient_scope_isolation_test.dart` absent) | ❌ |
| `lib/data/demo_mode.dart` | n/a | ❌ absent (`:176-179`) | ❌ | ❌ |
| `lib/services/store_migrator.dart` | n/a | ❌ absent (`:148-161`) | ❌ | ❌ |
| `lib/screens/settings/delete_account_screen.dart` | ❌ absent | ❌ absent (`:136`) | ❌ | ❌ |
| `/delete-account` route | ❌ absent (R-1) | n/a | n/a | ❌ |
| `storage.rules` | n/a | ❌ absent | n/a | ❌ |

`SessionScope` is the worst of these: `session_scope.dart:22-24` carries a standing instruction
("When a provider gains patient-scoped state, add it here") that no architecture reader will see.

**H-1 · 16 live doc lines still assert six tabs / a Calendar tab. All 11 from round 1 unchanged; 5 more found.**

| File:line | Claim | Round |
|---|---|---|
| `README.md:44` | "6 bottom tabs (Home, My Care, Services, Calendar, Billing, More)" | r1 |
| `README.md:278` | "### Tab 4 — Calendar (root tab)" (section :278-284) | r1 |
| `README.md:279` | "Care Calendar is a root bottom-tab (index 3, between Services and Billing)" | r1 |
| `README.md:285` | "### Tab 6 — More (Settings)" — More is index 4 | **r2** |
| `PROJECT.md:4` | "six field-feedback rounds (3–6) shipped: … Calendar root tab" | r1 |
| `docs/ARCHITECTURE.md:68` | "main_shell.dart … (6 tabs: Home/My Care/Services/Calendar/Billing/More)" | r1 |
| `docs/ARCHITECTURE.md:207` | "Six root" | r1 |
| `docs/ARCHITECTURE.md:208` | "tabs (Calendar added at index 3 — indices 1/2 referenced externally)" | r1 |
| `docs/SCREEN_MAP.md:6` | "Bottom Tab Bar (MainShell -- 6 tabs …)" | r1 |
| `docs/SCREEN_MAP.md:10` | "\|-- [3] Calendar -> CareCalendarScreen" | r1 |
| `docs/SCREEN_MAP.md:11` | "\|-- [4] Billing" — now index 3 | **r2** |
| `docs/SCREEN_MAP.md:12` | "\|-- [5] More" — now index 4 | **r2** |
| `docs/SCREEN_MAP.md:15` | "**Calendar was added as a root tab at index 3** (field round 4-5)" | r1 |
| `docs/SCREEN_MAP.md:73` | "### CALENDAR TAB (Index 3)" section (:73-77) | r1 |
| `docs/SCREEN_MAP.md:81` | "### BILLING TAB (Index 4)" — now 3 | **r2** |
| `docs/TEST_MAP.md:32` | "+fixed-nav shell contract, **calendar root tab**, …" | **r2** |
| `docs/FEATURE_TRACKER.md:143` | "Care Calendar added as root tab at index 3 (… = SIX tabs)" | r1 |

Ground truth: `lib/screens/main_shell.dart:37-43` (five screens), `:93-113` (five items),
`lib/screens/my_care/my_care_screen.dart:93` (`/care-calendar` app-bar action),
`test/screens/main_shell_test.dart` (`expect(bar.items, hasLength(5))`, `barLabel('Calendar')` →
`findsNothing`). `docs/CHANGELOG.md:56-64` is a dated historical entry — **leave it.**
`docs/SCREEN_MAP.md:81` and `:133` still both claim "Index 4".

**H-2 · `SCREEN_MAP` documents a screen class that does not exist.** `BookingHistoryScreen` at
`docs/SCREEN_MAP.md:62,217`; `docs/FEATURE_TRACKER.md:123,124,126` names it as the frontend for
three "Done" features (Booking Cancellation, Post-Service Rating, Booking History).
`lib/main.dart` routes `/booking-history` to `MyOrdersScreen` as a legacy alias. Unchanged.

**H-3 · `ARCHITECTURE.md` misstates provider wiring and now omits three more files.** 10 vs 11
(`:17`, `:348`); `RemindersProvider` absent from `:17,:56-66,:350-361`; plus `session_scope.dart`,
`demo_mode.dart`, `store_migrator.dart`, `delete_account_screen.dart` (D-1).

**H-4 · `TEST_MAP` is wrong in every headline number and 14 files short.** 99→100 files,
1,370→1,380 call sites, ~1,771→1,797 runtime, inventory 86 of 100. Includes the PHI regression
guard `patient_scope_isolation_test.dart`.

**H-5 · No audit report except this one carries resolution status, and all 12 are commit-stale.**
`AUDIT_SYNTHESIS.md` is the acute case — see the dedicated section above.

## Medium / Low

- **M-1 · The "37 screens × 3 widths" overflow figure is stale in 8 places.** Static count of
  `test/screens/overflow_smoke_test.dart`: 20 `noArg(` + 14 `argScreen(` + 5 explicit `testWidgets`
  (Home `:378`, My Care `:385`, Assistant `:425`, Onboarding `:440`, OTP `:455`; the other two
  `testWidgets` at `:396`/`:471` are inside the `noArg`/`argScreen` helpers) = **39 screens**,
  × 3 sizes (`_phoneSizes` `:101-105`) = **117 tests**, not 111. Stale at `CLAUDE.md:13`,
  `README.md:210,362,389,409`, `docs/TEST_MAP.md:4,119,208`, `docs/FEATURE_TRACKER.md:260`.
  (`docs/CHANGELOG.md:201` is historical — leave it.)
- **M-2 · `FEATURE_TRACKER.md` self-dates to 2026-06-11** (`:3`) while git says 2026-06-15 and
  **three** commits have landed since. `grep -ci` for "delete account", "session scope",
  "demo banner", "storage rules", "migration", "store migrator", "account deletion" → **0 each**;
  round-1's zero-hit list ("toast", "receipt", "sleep", "staff_otp", "AddPatient", "CarePulse")
  is unchanged. Account deletion in particular belongs in a feature tracker that a release manager
  reads before submission.
- **M-3 · `FEATURE_TRACKER.md` has an orphaned table** — Billing & Payments starts at `:153` with
  no `##` heading, reading as a continuation of "Care Calendar & Care Team". Unchanged.
- **M-4 · `SCREENS_IMPLEMENTATION.md:5` claims "Total Screens: 33"** against **91** Dart files
  under `lib/screens/` and README's "40+". Undated, last touched 2026-03-21, carries the dead
  pricing rule (B-1). Unchanged.
- **M-5 · Root `ARCHITECTURE.md` stub is correct** (`:1-8`, explicit redirect, consolidation dated
  2026-05-28) — but `PROJECT.md:81,90` still flags the duplication as an open TODO.
- **M-6 · `KNOWN_ISSUES.md:5` self-reports "Last updated: 2026-05-28"** while git says 2026-06-11.
- **M-7 · Three different Flutter versions** — `README.md:26` (3.16+), `PROJECT.md:29` (3.41+),
  `ci.yml:22` (pinned 3.41.2). `pubspec.yaml` constrains only Dart.
- **M-8 · NEW — `README.md:166` says the services catalog has 6 tabs; it has 7.**
  `service_catalog_screen.dart:65` `TabController(length: 7)`; labels at `:114-120`. The same
  wrong number sits in a code comment at `service_catalog_screen.dart:127`. Distinct from H-1 —
  this is sub-navigation, and it would have been wrong even before the five-tab change.
- **M-9 · NEW — README's own stat block is now wrong on five counts.** `:42` 149 files / ~53,800
  LOC (actual 153 / 55,067); `:43` 99 test files (actual 100); `:45` 52 routes (actual 53);
  `:209` "86 test files, 1,550+ tests" contradicting `:43` in the same file.
- **M-10 · NEW — nothing documents that the two new iOS usage-description strings exist.**
  `ios/Runner/Info.plist:73,75` (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`);
  `grep -rn "NSCameraUsageDescription\|usage description"` across non-audit `.md` → **0 hits**.
  These are App Review artifacts whose exact wording is submitted to Apple; they belong in the
  release checklist.
- **L-1 · `README.md:425-434` "Remaining Steps for Production" is stale** — `_loadMockData`
  (`:428`) does not exist; step 8 asks for booking/payment screen tests that have existed for months.
- **L-2 · `PROJECT.md:31` broken anchor** (`#-tech-stack` → `#tech-stack`).
- **L-3 · `PROJECT.md:22-23,68` unresolved TODOs** (brand guidelines link, master pricing Excel,
  credential vault) in the doc that markets itself as the meta layer.
- **L-4 · `docs/my-care-tab.md` and `docs/services-tab.md` carry no date and no status banner.**

## BLOCKED-OWNER

- **Liveness/currency of `https://housepital.in/privacy` and `https://housepital.in/terms`**
  (`lib/screens/settings/about_screen.dart:97-98,103-104`). I cannot fetch them. Needed:
  confirmation both resolve, and whether their content covers the app's real flows — now
  including account deletion and DPDP §12 erasure.
- **Whether `storage.rules` has been deployed** (`firebase deploy --only storage`). The file and
  the `firebase.json` block exist; live posture is unverifiable from the repo. This determines
  whether R-2 is a documentation gap or an open security hole.
- **App Store Connect / Play Console privacy-label answers** — whether any are already filled.
  Determines if DATA_HANDLING.md is transcription or from-scratch authoring.
- **Whether the brand guidelines PDF exists outside the repo** (`PROJECT.md:22` TODO).
- **CI green/red and current coverage %** — `ci.yml:66-79` enforces 50%; I was instructed not to
  run the suite and cannot read GitHub Actions.
- **Where credentials are vaulted** (`PROJECT.md:68`).

---

## What is genuinely good (so it doesn't get lost)

- **`CLAUDE.md` is now the only doc that tracks the code, and both round-2 edits are accurate to
  the line.** The Firebase correction in particular is unusually careful: it distinguishes
  tracked-vs-gitignored per platform, explains *why* the `.gitignore` entries are inert (verified:
  files committed `5a0ca2e` 2026-03-22, ignore rule added `4bcaadb` 2026-05-28), and states the
  real control (Security Rules + API-key restriction) rather than the comfortable one. It also
  pre-empts the recurrence: "Do not repeat the old claim…".
- **`docs/audits/` is the best documentation work in this repo.** Twelve reports, all dated, all
  method-stated, most declaring what they deliberately did not run. Add resolution status and
  this becomes a genuine review record.
- **`docs/VISUAL_CONSISTENCY_AUDIT.md:3-15`** remains the template: dated, method stated, RESOLVED
  banner, explicit note on superseded findings.
- **`docs/DEPLOYMENT_GUIDE.md:326-437` and `:456-480`** (console hardening, rollback per surface)
  are production-grade — which is exactly why the missing storage-rules step (R-2) matters.
- **`.github/workflows/ci.yml`** is self-documenting enough that the missing CI.md is low severity.
- **The `ANTHROPIC_API_KEY` server-side-secret claim is true and re-verified** —
  `grep -rn ANTHROPIC lib/ assets/ android/ ios/` → nothing; `functions/index.js:21,114,153`.
- **`lib/utils/session_scope.dart` and `lib/data/demo_mode.dart` are excellently self-documented**
  — both carry doc comments explaining *why* they exist in clinical terms
  (`demo_mode.dart:6-12`: "a family member checking whether insulin was given reads the sample
  patient's chart with full confidence"). The code documentation is better than the project
  documentation. The fix for D-1 is mostly copy-paste.
