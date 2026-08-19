# Documentation Checklist — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-03 (per brief; see Limitations — the commit under audit is dated 2026-08-11)
**Auditor:** Documentation module · **Scope:** source review (see Limitations)
**Repo:** `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`
**HEAD:** `9127713` on `fix/five-tab-nav` · R3: `9a80fe2` · R2: `820060b` · R1: `9c39dc1`

> Every verdict below cites a `file:LINE` or a command with its output. No verdict is taken
> from a document's self-description, and none from a commit message. `9127713`'s message is
> treated throughout as **a claim under test**, not as evidence.

---

## Applicability

MASTER-2.05 makes Documentation an always-required module; the checklist's own scope line is
"every project". No control in this family is N/A on applicability grounds. Section 8
(Ops/infra) is trigger-gated and the triggers fire: CI exists (`.github/workflows/ci.yml`),
there are deploy targets (Firebase Functions, Firestore, Storage), and there are two backend
services (`../housepital-backend`, `../housepital-api`).

---

## The round-4 headline

**`9127713` is the first commit in this repo that fixes documentation at paragraph depth, and
in four specific places it is excellent work that I could not break. It is also the third
consecutive commit to leave the *adjacent contradicting sentence* standing — this time inside
the very blocks it rewrote.**

The trajectory the brief asks me to name: round 1→2 found **surfaces**; round 2→3 found
**half-wires**. Round 3→4 is neither. It is a **partial rewrite with an unenforced blast
radius**: the author correctly identified the paragraph that was wrong, rewrote it properly,
and did not re-grep the file for the same claim expressed differently. The single clearest
proof is `docs/SCREEN_MAP.md`, the exact file whose self-contradiction the commit message
opens by apologising for:

```
$ sed -n '5,20p' docs/SCREEN_MAP.md
Bottom Tab Bar (MainShell -- 5 tabs, FLOATING liquid-glass pill)      ← line 5 (fence header)
  |-- [0] Home  … |-- [3] Billing … |-- [4] More                       ← five, correct
...
**Chrome:** the bar is a detached `GlassSurface` pill (16px side insets, radius 32,
floating above the home indicator), **not the fixed edge-to-edge orange bar of field
round 5.** …                                                          ← line 20 (NEW, correct)

**Nav bar:** FIXED full-width solid-orange bar anchored to the bottom edge (owner
iterated floating-glass → pill → fixed), white icons/labels, SafeArea-padded.
                                                                       ← line 22 (UNTOUCHED)
```

**Lines 20 and 22 are consecutive paragraphs in the same section, written and left by the same
commit, and they assert opposite facts about the same widget.** The pass wrote a sentence whose
job is to deny the claim two lines below it, and did not delete the claim. Round 3 named
`SCREEN_MAP.md:17` (now `:20`→`:22` after the insert) explicitly, in a numbered table, as one of
eight orange-bar lines to fix.

The same file's Screen Inventory still carries `### CALENDAR TAB (Index 3)` (`:76`) and
`### BILLING TAB (Index 4)` (`:83`). Billing is index 3. So `SCREEN_MAP.md` is **still
self-contradictory about the tab indices** — the contradiction moved from the tab tree
(fixed) to the section headings 70 lines down (untouched). Round 3 named `:73` and `:81`
explicitly too.

And `docs/ARCHITECTURE.md` — the file the commit message says was "**Rewritten, not
patched**" — still reads at `:206-208`:

```
- **Bottom nav** (`main_shell.dart`): FIXED full-width solid-orange bar, white
  icons, SafeArea-padded (owner iterated floating-glass → pill → fixed). Six root
  tabs (Calendar added at index 3 — indices 1/2 referenced externally).
```

Six root tabs and a fixed orange bar, 140 lines below `:68`'s "5 tabs" and 190 lines above the
genuinely new storage-contracts section. Ground truth: `lib/screens/main_shell.dart:37-43`
(five screens), `grep -c BottomNavigationBarItem lib/screens/main_shell.dart` → **5**,
`main_shell.dart:94-140` (`GlassSurface(borderRadius: 32, sigma: 36, opacity: 0.78)`).

**Was it real or another line-level patch? Both, in the same commit.** The four new
contract sections are real, verified, paragraph-level work. The corrections to *existing*
prose were applied to the sentence the round-3 report quoted and to nothing else — which is
the round-3 finding restated, one level up.

---

## Prior-round status — every round-3 finding

| Round-3 finding | Status now | Evidence |
|---|---|---|
| **B-1** No `PRIVACY_POLICY.md` / `DATA_HANDLING.md` | **Still open (4th round)** | `find . -name PRIVACY_POLICY.md -o -name DATA_HANDLING.md` → empty |
| **B-2** No `QA_CHECKLIST.md` | **Still open (4th round)** | `find . -name QA_CHECKLIST.md` → empty |
| **B-3** Dead pricing rule, 5 doc + 7 code/test sites | **Partial — 3 doc + 1 code fixed; 2 doc + 6 code remain** | Full recount at **V-2**. Commit message claims "the last doc sites are gone" — `docs/services-tab.md:154` and `:386` say otherwise |
| **H-1 REGRESSION** `ARCHITECTURE:382` documents deleted demo-banner shape | **RESOLVED ✅** | `docs/ARCHITECTURE.md:383` rewritten; verified against `lib/widgets/demo_data_banner.dart:10-53`. See **V-5** |
| **H-2 REGRESSION** 8 doc lines describe fixed orange nav bar | **1 of 8 fixed; 7 remain** | Only `SCREEN_MAP.md:6`. See **V-1**. `ARCHITECTURE:68`, `ARCHITECTURE:206`, `SCREEN_MAP:22`, `README:44`, `README:334`, `PROJECT:4`, `FEATURE_TRACKER:252` verbatim |
| **H-3** `SCREEN_MAP` self-contradicts on tab count | **Partial — tree fixed, headings not** | `:5-12` correct; `:76` "CALENDAR TAB (Index 3)", `:83` "BILLING TAB (Index 4)" untouched |
| **H-4** `TEST_MAP` untouched, 99 vs 101 files | **Partial → newly self-contradictory** | `:6` now "101 … 1,819"; `:4` still "~1,771 … 1,370 call sites … 37 screens". See **V-6** |
| **H-5** `FEATURE_TRACKER` blind to everything `820060b` shipped | **UNCHANGED ❌** | Not touched by `9127713` (`git log -1 --format=%cd -- docs/FEATURE_TRACKER.md` → 2026-08-04). Seven keyword greps → **0 each** |
| **H-6** `README.md` stale on nine counts | **UNCHANGED ❌** | `git log -1 --format=%cd -- README.md` → **2026-06-15**. All nine re-verified at **V-7** |
| **H-7** `ARCHITECTURE` "Ten providers" over a 10-row table | **RESOLVED ✅** | `:348` "Eleven"; table `:350-361` has 11 rows; `grep -c ChangeNotifierProvider lib/main.dart` → **11**; names match 1:1. See **V-3** |
| **H-8** `DEPLOYMENT_GUIDE` ships a release without storage rules | **Partial — pre-launch fixed, checklist not** | `:396` storage deploy now in §7a step 3 ✅; §8 checklist `:451-464` still has **no storage checkbox**. See **V-8** |
| **H-9** `orangeStrong`/`onError` undocumented; `onOrange` comment states reverse of value | **RESOLVED ✅ (with one artefact)** | `CLAUDE.md:102-106`, `app_colors.dart:58-72`, `theme.dart:48-53,106-111`. Every number re-derived independently — see **V-4**. Artefact: a dangling half-sentence at `app_colors.dart:67` |
| **H-10** Nav-pill occlusion in no issues log | **RESOLVED ✅** | `docs/KNOWN_ISSUES.md:26-28` |
| **M-1** "37 screens × 3 widths" stale in 8 places | **UNCHANGED ❌** | Actual **41** (21 `noArg` + 15 `argScreen` + 5 explicit). Still 37 at `TEST_MAP:4,119,208`, `CLAUDE.md:13`, `README:210,362,389,409`, `FEATURE_TRACKER:260` |
| **M-2** `CHANGELOG` newest entry `[2026-06-13]` | **RESOLVED ✅** | `docs/CHANGELOG.md:3-25` — new dated entry covering rounds 1–3 incl. account deletion. See **V-9** |
| **M-3** `PROJECT.md` stale | **UNCHANGED ❌** | Untouched since 2026-06-15; `:4` still "Calendar root tab, fixed solid-orange nav bar" |
| **M-4** `CONTRIBUTING.md` lists 3 of 8 CI steps | **UNCHANGED ❌** | `CONTRIBUTING.md:31-33` = 3 steps; `grep -c "name:" .github/workflows/ci.yml` → **11**; still no `--dart-define` |
| **M-5** `ENVIRONMENT_SETUP.md` no Storage step, no `dart-define` | **UNCHANGED ❌** | Untouched since 2026-05-28 |
| **M-6** No client-storage schema doc | **RESOLVED ✅** | `docs/ARCHITECTURE.md:397-436` — the new storage-contracts section. See **V-3** |
| **M-7** `SCREENS_IMPLEMENTATION.md` undated, stale | **Partial** | `:288` pricing rule fixed ✅; still undated, still `:5` "Total Screens: 33" vs 91 files under `lib/screens/`, `:717` pre-Calendar tab scheme |
| **M-8** Three Flutter versions | **UNCHANGED ⚠️** | `README:26` 3.16+ · `PROJECT:29` 3.41+ · `ci.yml:22` 3.41.2 |
| **M-9** `KNOWN_ISSUES` misstates its own date | **REGRESSED ❌** | `:5` now says "2026-08-03"; git says **2026-08-11**. Was 14 days wrong, is now 8 days wrong — and the file is otherwise the round's biggest improvement |
| **L-1/L-2/L-3** README stale steps, undated tab docs, root stub | **UNCHANGED ⚠️** | `grep -rn _loadMockData lib/` → still nothing; `my-care-tab.md`/`services-tab.md` still undated |
| **Process** — round directory as a record | **UNCHANGED ⚠️** | No `INDEX.md`, no `round1/`, no `round2/`. Round 3's 10-minute remediation not done. Now **worse by one level**. See **V-10** |

**Net movement: 6 resolved outright, 5 partial, 1 regressed, 12 unchanged.** This is the
largest single-round movement in the audit's life, and it is still the case that **no `[R]`
required artifact has been created in four rounds**.

---

## Verification detail

### V-1 · The orange-bar regression — **1 of 8 fixed, and two of the seven survivors sit in blocks this commit rewrote**

```
$ grep -rniE "solid-orange|fixed full-width" --include="*.md" . | grep -v docs/audits | grep -v CHANGELOG
README.md:44:      - **6 bottom tabs** (…Calendar…) — fixed solid-orange nav bar
README.md:334:     - **Fixed full-width solid-orange bottom nav bar** (`MainShell`), white icons/labels,
PROJECT.md:4:      …six field-feedback rounds (3–6) shipped: fixed solid-orange nav bar, Calendar root tab…
docs/ARCHITECTURE.md:68:  # Fixed solid-orange bottom nav bar (5 tabs: Home/My Care/Services/Billing/More; …)
docs/ARCHITECTURE.md:206: - **Bottom nav** (`main_shell.dart`): FIXED full-width solid-orange bar, white
docs/SCREEN_MAP.md:20:    **Nav bar:** FIXED full-width solid-orange bar anchored to the bottom edge …
docs/FEATURE_TRACKER.md:252: | 20a| Fixed solid-orange bottom nav bar | Done (2026-06-11) | …
```

*(`VISUAL_CONSISTENCY_AUDIT.md:81` is about filter chips, not the nav — not a hit.
`docs/CHANGELOG.md:56,59,82,88` are dated historical entries — **legitimate, leave them**.)*

Two of these are the finding. `SCREEN_MAP.md:20` sits **two paragraphs below** the new
`:20` "Chrome:" text that exists to correct it. `ARCHITECTURE.md:206-208` sits in the file
the commit message says was rewritten, and carries the six-tab claim as well. Round 3
listed both by line number.

`ARCHITECTURE.md:68` is the round-3 pattern reproduced exactly: an earlier pass corrected
`6 tabs`→`5 tabs` inside the string and left `Fixed solid-orange` in the same string; this
pass did not return to it.

**Six-tab claims, recount:** `README:44`, `README:278` ("### Tab 4 — Calendar (root tab)"),
`README:279` ("index 3, between Services and Billing"), `README:285` ("### Tab 6 — More"),
`PROJECT:4`, `ARCHITECTURE:207` ("Six root tabs"), `SCREEN_MAP:76`, `SCREEN_MAP:83`,
`TEST_MAP:32`, `SCREENS_IMPLEMENTATION:717`. **10 remain of round 3's 14** — the four closed
are all in `SCREEN_MAP`'s tab tree and `:15`.

### V-2 · Dead "never show manpower prices" rule — **full recount, all sites**

Command (whole repo, excluding `docs/audits/` and `build/`):

```
$ grep -rniE "never (show|shown|display)|no price is ever|no prices shown|prices are never|never displayed" \
    --include="*.dart" --include="*.md" .
```

**Doc side — 2 of 5 round-3 sites remain, and the commit message asserts zero remain:**

| File:line | Text | Status |
|---|---|---|
| `SCREENS_IMPLEMENTATION.md:288` | now "**Manpower prices ARE shown and directly bookable**… must not be reintroduced" | **FIXED ✅** |
| `docs/my-care-tab.md:197` | now "ARE shown and directly bookable… *(previously said the opposite; owner reversed 2026-06-11)*" | **FIXED ✅** |
| `docs/services-tab.md:74` | now "rate-card prices ARE shown and directly bookable…" | **FIXED ✅** |
| `docs/services-tab.md:154` | "**Never show prices for manpower services** (nurse, caretaker, japa, nanny) — users reject without speaking to sales" | ❌ **verbatim since round 1** |
| `docs/services-tab.md:386` | same + "Physio is the exception (prices shown: 900/1200/1500)." | ❌ **verbatim since round 1** |

The commit message says: *"the last doc sites are gone (SCREENS_IMPLEMENTATION, my-care-tab,
**services-tab ×2**)"*. The two `services-tab` edits landed at `:74` and `:149`
(the `basePriceMin` line). **Round 3 named `:74`, `:154` and `:386`.** So the pass fixed one
line round 3 named, one line round 3 did not name, and left **both** of the two remaining
lines round 3 named by number — then declared the set empty.

Consequence: `docs/services-tab.md` is now **self-contradictory within itself** — `:74` says
prices are shown, `:154` and `:386` say never show them — and `:386` re-imports japa/nanny as
Housepital offerings, contradicting `CLAUDE.md:38`.

**Code/test side — 1 of 8 newly fixed, 6 remain:**

| # | File:line | Text | Status |
|---|---|---|---|
| 1 | `lib/screens/assistant/assistant_local_actions.dart:21` | "Business rule: manpower prices are NEVER shown" | ❌ verbatim |
| 2 | `lib/screens/my_care/widgets/doctor_advice_card.dart:8` | "never show prices (hard business rule)" | ❌ verbatim |
| 3 | `lib/services/invoice_pdf_service.dart:10` | "manpower prices are never displayed before the confirmation call" | ❌ verbatim |
| 4 | `lib/services/handover_report_service.dart:14` | "manpower prices are never displayed in any case" | ❌ verbatim |
| 5 | `test/screens/orders/quote_pending_surfaces_test.dart:5` | "Manpower prices are never…" | ❌ verbatim |
| 6 | `test/screens/assistant/assistant_executor_test.dart:476` | `expect(order['totalAmount'], 0); // manpower rule: no price, ever` | ❌ verbatim |
| 7 | `test/screens/services/staff_role_sheet_test.dart:169` | — | FIXED (round 3) ✅ |
| 8 | `lib/screens/assistant/assistant_executor.dart:379-384` | now "That rule is **DEAD**… Quote-pending applies only to items that genuinely lack a price" | **FIXED ✅** |

Site 8 is fixed to the round-3 gold standard — it names the old text, says it is dead, gives
the live rule, and dates the owner decision, so it cannot silently drift back. **This is the
model.** Sites 1–6 are one `sed` away from the same treatment and were not touched.

Sites 1 and 6 are in the *same subsystem* as the site that was fixed (`assistant_*`), which
means the author was reading adjacent files when they made the fix.

Not the dead rule — correctly describing the live quote-pending rule, **leave alone**:
`booking_confirmation_screen.dart:268`, `service_booking_screen.dart:589`,
`cards/diagnostic_card.dart:84`, `catalog_seeds.dart:11`, `empty_state.dart:18`,
`equipment_detail_sheet.dart:67`. Historical, **leave alone**: `CHANGELOG.md:59,473`.

### V-3 · `ARCHITECTURE`'s new contract sections — **accurate to the code; I could not break them**

I checked every falsifiable claim in the three new/rewritten blocks against source.

**Eleven providers (`:348-361`) — Pass.**

```
$ grep -c ChangeNotifierProvider lib/main.dart
11
```
`lib/main.dart:195-278` provides, in order: `AuthProvider`, `AppProvider`, `BillingProvider`,
`CartProvider`, `OrdersProvider`, `RemindersProvider`, `MyCareProvider`,
`MedicationProvider`, `BlogProvider`, `AssistantProvider`, `ThemeProvider`. The table lists
the same eleven names — **1:1, no omission, no phantom**. `RemindersProvider`, absent for
three rounds, is at `:352` with an accurate scope ("patient-scoped, persisted" —
`lib/main.dart:217` `RemindersProvider()..load()`). H-7 closes.

**Storage contracts (`:397-436`) — Pass, every clause verified.**

| Doc claim | Verified against |
|---|---|
| keys are `housepital_orders_<patientId>` / `housepital_assessments_<patientId>` | `orders_provider.dart:22-23` `_ordersKeyPrefix`/`_assessmentsKeyPrefix` |
| the legacy global keys existed and were destructive | `orders_provider.dart:26-27` `legacyOrdersKey`/`legacyAssessmentsKey` |
| `clearPatientScopedData()` is memory-only and must never persist | matches the round-3 defect description and the migrator's v1→v2 step |
| two switch paths; `AppProvider.onPatientChanged` is the hook | `app_provider.dart:63-66` |
| `SessionScope.install(context)` called once from `MainShell.initState` | `main_shell.dart:40`; idempotence guard at `session_scope.dart:63` |
| OS-scheduled notifications are part of the wipe | `session_scope.dart:98-100` → `medication_reminder_service.dart:248` |
| migrator: bump `currentVersion`, FROZEN literals, `quarantine()`, never stamp a failed step, `debugSetMigrations` for testability | `store_migrator.dart:34` (`currentVersion = 2`), `:55-70` (the one shipped step, with `const legacyOrders = 'housepital_orders'` inline literals), `:91-103`, `:129`, `:139-158` |

**Migrator recorded at v2 (`:383`) — Pass.** `store_migrator.dart:34` `static const int
currentVersion = 2`, one step in `_buildShippedMigrations()` quarantining the pre-per-patient
keys. The doc says exactly this.

**Payment-failure contract (`:438-452`) — Pass.** `payment_service.dart:246-255` defines
`enum PaymentFailure { notStarted, declined, unverified }`; the doc's three-row table
(money moved? / retry allowed?) matches the enum's own doc comments and the call sites at
`:147` (`notStarted`), `:182,:189` (`unverified`), `:224` (`declined`). The doc's warning —
that the branch used to be `message.contains('under verification')` and that localising it
would restore a Retry button on a paid invoice — is corroborated by `payment_service.dart:240`
and is the correct causal account. This section is the second-best thing in the repo's docs
after the round-3 five-artifact table.

**Demo-data honesty (`:454-462`) — Pass on the contract, and it flags its own open gap**
("several sources mark and never clear"), which is the honest disclosure the checklist's
§9.02 asks for.

### V-4 · The corrected contrast comments — **every number independently re-derived; all six correct**

I computed WCAG 2.x relative luminance from the hex literals in source rather than trusting
any comment (`scratchpad/contrast.py`, sRGB linearisation, `(L1+0.05)/(L2+0.05)`):

| Token | Source | Comment claims | I measure | Verdict |
|---|---|---|---|---|
| `orangeText` `#B86E00` on white | `theme.dart:74` | 3.99:1 (was 4.6:1) | **3.99:1** | ✅ correct |
| `orangeDark` `#CC6E00` on white | `theme.dart:76` | 3.62:1 (was 4.5:1) | **3.62:1** | ✅ correct |
| `warning` `#E65100` on white | `theme.dart:102` | 3.79:1 (was 4.6:1) | **3.79:1** | ✅ correct |
| `onOrange` `#FFFFFF` on `#F39314` | `theme.dart:32`, `:83`; `app_colors.dart:72` | 2.33:1, accepted | **2.33:1** | ✅ correct |
| `orangeStrong` `#9A5C00` on white | `theme.dart:110` | 5.38:1 | **5.38:1** | ✅ correct |
| `onError` light: `#FFFFFF` on `#D32F2F` | `theme.dart:106-107` | 4.98:1 | **4.98:1** | ✅ correct |
| `onError` dark: white on `#EF5350` | `theme.dart:48-53` | 3.49:1 (fails) | **3.49:1** | ✅ correct |
| `onError` dark: `#212121` on `#EF5350` | `theme.dart:53` | 4.62:1 | **4.62:1** | ✅ correct |
| dark `orangeStrong` = orange on `#000000` | `theme.dart:55` | 8.99:1 | **8.99:1** | ✅ correct |

**Nine for nine.** `CLAUDE.md:102-106`'s paired-foreground entry restates all of these and is
accurate to the decimal. H-9's dangerous half — `app_colors.dart` claiming `onOrange` was dark
ink at 6.3:1 when it is `#FFFFFF` in both palettes — is genuinely dead. **This is the single
most credible piece of work in the commit**, because it is the only part that was *measured*
rather than *reasoned*, and it survives independent measurement.

**Three defects remain in the same subject matter, all in `theme.dart`, none touched:**

1. **`theme.dart:7` (class docstring)** — "ON-orange text is WHITE by owner decision (brand
   look over the **~2.7:1** ratio)". Measured **2.33:1**. A stale contrast figure in the doc
   comment of the very class whose contrast comments this commit corrected.
2. **`theme.dart:347-348` — the more serious one.** The `darkTheme` docstring reads:
   > "Critical contrast decisions: • Buttons keep brand orange, but **use dark text** (white on
   > orange = 2.7:1 in dark mode, fails AA — see `HousepitalColorsDark.onOrange`)."

   `HousepitalColorsDark.onOrange` is `Color(0xFFFFFFFF)` (`theme.dart:83`), and the dark
   button at `:440` uses `foregroundColor: HousepitalColorsDark.onOrange` — i.e. **white**.
   The docstring states the reverse of the code, cites a wrong ratio, and points the reader at
   the token that disproves it. **This is defect-for-defect the same failure as the
   `app_colors.dart:67-68` comment that round 3 rated a blocker**, sitting 300 lines below the
   fix, in the same file, unfixed — and it carries the same hazard: it reads as a standing
   engineering justification to revert a durable owner decision (`CLAUDE.md:71`).
3. **`theme.dart:20`** — "Surface is intentionally `#1A1A1A` (true-dark) rather than pure
   black" — `theme.dart:17` is `static const Color surface = Color(0xFF000000)`. Self-refuting
   within four lines. `:352` likewise: "Cards sit on `#242424` over a `#1A1A1A` scaffold";
   actual `#1C1C1E` over `#000000` (`:17-18`).

Two further uncorrected contrast comments in the batch the pass was auditing:
`theme.dart:104` `error` "// 4.7:1" (measured **4.98:1**) and `:98` `success` "// 5.1:1"
(measured **5.13:1** — fine). The pass corrected three of five wrong figures in one file.

**One editing artefact.** `lib/config/app_colors.dart:67` — the old `//` line was left above
the new `///` block, so the field now reads:

```dart
  // Text/icons ON an orange fill. White on orange fails AA (~2.3:1), so both
  /// Text/icons ON an orange fill. WHITE in both appearances by explicit owner
  /// decision — measured 2.33:1, recorded as an accepted risk. …
  final Color onOrange;
```

A dangling half-sentence ending in "so both", and the first line a reader sees still leads
with "fails AA". Harmless to the compiler; it is precisely the line-level residue the commit
was written to eliminate.

### V-5 · The demo-notice row — **the round-3 regression is genuinely closed** ✅

`docs/ARCHITECTURE.md:383` now reads: *"Two earlier shapes both regressed: inside `MainShell`
it missed every pushed clinical screen, and as a full-width strip in a Column it stole the
status bar and pushed every glass app bar down. It is now a compact glass pill in a **Stack
overlay** — it displaces nothing, so adding or removing it cannot change any screen's layout.
Known open defect: it absorbs touches and occludes the first content row on several screens."*

Verified against `lib/widgets/demo_data_banner.dart:10-27` (the "TWO EARLIER SHAPES, BOTH
WRONG" comment) and `:38-53` (`Stack`, `Positioned(top: padding.top + kToolbarHeight + 4)`).
The doc now matches the code *and* names the open defect. H-1 closes cleanly. This is the one
place where the pass did exactly what round 3 asked, including carrying the known-issue
forward rather than quietly dropping it.

### V-6 · `TEST_MAP` — **corrected into a new self-contradiction**

```
$ sed -n '3,6p' docs/TEST_MAP.md
**Last updated:** 2026-06-15
**Total test count:** ~1,771 at runtime (1,370 `test()`/`testWidgets()` call sites;
  parameterized guard suites — e.g. overflow smoke 37 screens × 3 widths — expand at runtime)
**Pass rate:** …
**Test file count:** 101 (`find test -name "*_test.dart" | wc -l`) — 1,819 tests at runtime
```

Line 4 and line 6 are **two lines apart** and state two different runtime test counts. The
brief's authoritative figure is 1,819. Line 4 was not edited.

Independently derived:
- `find test -name "*_test.dart" | wc -l` → **101** ✅ (`:6` correct)
- `grep -rhoE "\b(test|testWidgets)\(" test/ | wc -l` → **1,402** call sites, not the 1,370
  at `:4`
- overflow smoke: `grep -c noArg( ` → 21, `argScreen(` → 15, `testWidgets(` → 7 →
  **41 screens × 3 widths**, not 37. Still "37" at `:4`, `:119`, `:208`
- `:156` "complete inventory — **86** files" — unchanged against 101 on disk
- `:3` "Last updated: **2026-06-15**" while the file was edited **2026-08-11** and a new
  "## 2026-08-03" section added at `:305`. **Three dates in one file, none the edit date.**

**Genuinely good:** the new `:305-316` block adds `patient_scope_isolation_test.dart` and
`store_migrator_test.dart` — the two regression guards for the PHI and storage-schema
blockers, invisible for three rounds — with a standing instruction ("Add an assertion here
whenever `SessionScope` gains a store"), *and* it records the test-quality gaps still open
rather than only the wins. That paragraph is right. The header four lines above it is wrong.

### V-7 · `README.md` — **the `[R]` front door, untouched for a fourth round**

`git log -1 --format=%cd --date=short -- README.md` → **2026-06-15**. All nine round-3 counts
re-verified against HEAD:

| `README` claim | Actual | Command |
|---|---|---|
| `:42` "149 Dart source files" | **154** | `find lib -name "*.dart" \| wc -l` |
| `:43` "99 test files \| ~1,771 tests" | **101 / 1,819** | brief + `find` |
| `:44` "6 bottom tabs (…Calendar…) — fixed solid-orange nav bar" | 5 tabs, glass pill | `main_shell.dart:37-43,94-140` |
| `:45` "52 named routes" | **53** | `grep -oE "'/[a-zA-Z0-9_/-]*'" lib/main.dart \| sort -u \| wc -l` |
| `:166` "services/ # catalog (6 tabs)" | 7 sub-tabs | `service_catalog_screen.dart:65` |
| `:209` "86 test files, 1,550+ tests" | contradicts `:43` in the same file | — |
| `:210,362,389,409` "37 screens × 3 widths" | **41** | V-6 |
| `:278-279` "### Tab 4 — Calendar (root tab) … index 3, between Services and Billing" | not a tab | `main_shell.dart:37-43` |
| `:285` "### Tab 6 — More" | index 4 | ditto |
| `:334-335` "Fixed full-width solid-orange bottom nav bar" | glass pill | V-1 |
| `:428` "AppProvider uses `_loadMockData()`" | **0 hits** | `grep -rn _loadMockData lib/` |

`PROJECT.md` (the `STATE.md` substitute, DOC-1.06) is in the same state — untouched since
2026-06-15, `:4` still advertising "Calendar root tab" and "fixed solid-orange nav bar" as
shipped achievements.

**This is the round's most consequential omission.** DOC-1.01's done-condition is "a new dev
can clone and run it from the README alone"; DOC-1.06's is "it reflects today's reality". A
documentation pass that rewrites four internal reference documents and does not open the two
files a newcomer opens first has optimised for the audit rather than for the reader.

### V-8 · `DEPLOYMENT_GUIDE` storage rules — **half of H-8 closed; the half that gives false assurance is open**

**Closed ✅:** `:394-396` puts `firebase deploy --only storage --project housepital-patient`
inside **§7a step 3, "Deploy the hardened firestore.rules"** — the pre-launch hardening block,
which is the actual release path. It is preceded by a comment naming the failure mode
("STORAGE RULES ARE A SEPARATE DEPLOY and are easy to forget — chat and concern-evidence
photos are unprotected until this runs"). Following the guide top to bottom now deploys them.

**The new caveat (`:402-406`) is accurate and is the most valuable sentence added to this
file.** It says the rules are authenticated-only, not per-patient, because the client never
reads a Firebase uid so `request.auth.uid == patientId` would deny 100% of uploads, and that
real isolation needs a `user_patients` custom claim. This matches `storage.rules`' own header
and `ARCHITECTURE.md:391-395`. It prevents the specific misreading — "storage rules are
deployed, therefore patients are isolated" — that the deploy step would otherwise create.
Documenting a control's *limit* alongside the control is the checklist's §11.01 standard, and
this clears it.

**Open ❌ — §8 Post-Deployment Checklist (`:451-464`) has no storage line:**

```
- [ ] **Firestore security rules deployed AND verified in console** (Section 7a step 3)
- [ ] **Firebase API key restrictions configured for all platforms** (Section 7a step 1)
- [ ] **App Check enabled in Monitor mode (7 days), then Enforce** (Section 7a step 2)
- [ ] **Crashlytics + Performance dashboard alerts configured** (Section 7a step 5)
```

Round 3 named `:441-450` (now `:451-464`) explicitly. A release manager who works the
checklist rather than the prose still ticks "rules deployed AND verified" with Storage
unverified. There is also still **no storage verify command** — `:398` verifies Firestore
only (`firebase firestore:rules get`), with no `firebase storage:rules get` counterpart,
so even the prose path confirms half of what it deploys.

Two further inaccuracies in this file, both bearing on claims other round-4 modules raised:

- **`:439` — "Without dSYMs, all iOS crash reports are obfuscated and useless."** False as
  written. `grep -rn "obfuscate\|split-debug-info" docs/ scripts/ .github/ ios/` returns
  **exactly one hit — this sentence.** No build path passes `--obfuscate`, so no Dart symbol
  is obfuscated; release-mode Dart frames reported through `FirebaseCrashlytics.recordError`
  (`main.dart:118-120,288`) stay readable. dSYMs govern *native* engine/Swift frames only.
  The sentence conflates missing symbolication of native frames with obfuscation of Dart
  frames and overstates the consequence to "all … useless". The *underlying* gap (no dSYM
  upload phase) is real and is correctly listed in `KNOWN_ISSUES`; the technical claim
  attached to it is wrong, and an external reviewer who checks it will discount the file.
- **`:458` — "Crashlytics + Performance dashboard alerts configured"** is a tickable
  post-deploy item for a product that cannot report on Android at all (see V-11).

### V-9 · `CHANGELOG` and `KNOWN_ISSUES` — **real improvements carrying verifiable false claims**

**`CHANGELOG.md:3-25` closes M-2 ✅.** A dated `## 2026-08-03` entry covering the nav change,
the payment fixes, the PHI/`SessionScope` work, storage versioning, demo-data honesty and
release hygiene — including **account deletion**, the App Store 5.1.1(v) gate that a
user-facing changelog is required to carry. I checked the entry's substantive claims against
code and found no false one. The date is the round-3 date, not the commit date (2026-08-11).

**`KNOWN_ISSUES.md` is the round's biggest single improvement and it is not trustworthy
line-by-line.** The new `:7-49` block finally makes this file know what the audits know —
blockers, high findings, and a clean three-item "Accepted risks (owner decisions, not
defects)" section that correctly declines to grade the white-on-orange, manpower-pricing and
pill-nav decisions as defects. H-10 closes here. But the content was transcribed from the
round-3 report rather than re-derived, so it is stale against code that `13e3656` had already
changed:

| `KNOWN_ISSUES` claim | Measured | Command |
|---|---|---|
| `:32` "`logger.dart:63` is an unwired TODO — **~45** warn/error sites reach no remote sink" | **57** | `grep -rn "Log\.warn(\|Log\.error(" lib/` → 58, minus 1 docstring example at `logger.dart:23` |
| `:30` "`DemoMode` has one `markServingLiveData` call site for **eleven** sources" | **2 call sites, 12 sources** | `grep -c "static const String source" lib/data/demo_mode.dart` → 12; live-data calls at `app_provider.dart:292` and `vitals_screen.dart:129` — the second added by `13e3656`, the commit immediately before this one |
| `:5` "Last updated: 2026-08-03" | committed **2026-08-11** | `git log -1 --format=%cd -- docs/KNOWN_ISSUES.md` |

The `~45`→57 gap is a **27% understatement of an observability blocker**, in the file a
responder reads. The `markServingLiveData` figure is wrong *because the previous commit fixed
part of it* — the doc pass wrote down the pre-fix number one commit after the fix landed,
which is the module's founding finding ("code lands and docs do not follow") operating at a
one-commit lag instead of a one-month lag.

*(Verified accurate in the same block: `sourceCareTeam`/`sourceCareCalendar`/`sourceProfile`
are indeed declared and never wired — `grep markServingDemoData(DemoMode.sourceCareTeam` etc.
→ 0 for all three.)*

**Two "Resolved" rows are false:**

- **`:96` BUG-15 — "~~Document repository screen is a placeholder~~ — search, share, open
  implemented | Resolved 2026-03-22".** The *save* path is not implemented and the screen
  tells the user it is. `document_repository_screen.dart:629-636`: `_uploadFromGallery()`
  picks an `XFile` and passes **only `image.name`** to `_showCategorizeDialog(String
  fileName)` — **the `XFile.path` is discarded and never stored**. `:684-702` then constructs
  `MedicalDocument(… fileType: 'scan', fileSizeBytes: 350000 …)` — a **hard-coded size** — and
  inserts it into the in-memory `_documents` list (the model has no path/URI field at all),
  followed by `SnackBar('Document saved successfully')`. Nothing is persisted, nothing is
  uploaded, and the file the user chose is unreachable the moment the dialog closes. In a
  medical-records screen this is a "resolved" marker on a data-loss path.
- **`:134` TD-13 — "~~No structured logging on backend~~ — RESOLVED: structured logging with
  correlation IDs".** Correlation IDs are **minted and never logged**.
  `housepital-backend/functions/src/middleware/correlationId.ts:15-17` sets
  `req.correlationId` and the `x-correlation-id` response header; its own docstring says "so
  it can be traced through **logs**". `grep -rni correlation` across the backend returns
  **four hits, all inside that middleware and its import** — no logger call site references
  it. Every one of the ~30 `logger.error(...)` calls (`routes/*.ts`, `middleware/auth.ts:68`,
  `middleware/errorHandler.ts:14`) passes only `{ error, stack }`. `utils/logger.ts:7-17` is a
  three-method `console.*` wrapper with no request context. Structured logging exists;
  correlation is a header the client can see and the operator cannot trace. The row claims
  the capability its own middleware comment defines and does not deliver.

### V-10 · The audit record as a record — **unchanged, and now one level worse**

```
$ ls docs/audits/
ACCESSIBILITY_AUDIT.md … UPGRADE_PATH_AUDIT.md   (12 files = round 2)
round3/  round4/
```

No `INDEX.md`. No `round1/`. No `round2/`. Round 3's concrete ~10-minute remediation
(`git checkout 9c39dc1 -- docs/audits/`, materialise `round1/` and `round2/`, leave an
`INDEX.md` naming the current round) was **not performed**, and `9127713` touched nothing in
`docs/audits/`.

The consequence round 3 predicted has arrived: the tree now reads **round 2 at the most
prominent path, rounds 3 and 4 buried beneath it**, so a reader who opens
`docs/audits/DOCUMENTATION_AUDIT.md` gets the *oldest on-disk* report of three, and the
current round is the least discoverable. Round 1 remains a git object recoverable only by
knowing `9c39dc1`, which nine of the twelve round-2 files still do not name.

**Is `9c39dc1`-only still acceptable?** Narrowly yes, on the same terms as round 3 — nothing
is lost, the loss is disclosed (`AUDIT_SYNTHESIS.md:3-13`), the branch is intact and unpushed.
It stops being acceptable at the first rebase, squash or force-push of `fix/five-tab-nav`.
Ten of the twelve round-2 reports still carry no resolution status header (H-5 of round 3,
unchanged).

### V-11 · Crashlytics / Performance documented as live; **Android cannot report at all**

Two documents assert this capability as delivered:

- `docs/FEATURE_TRACKER.md:239` — "Crash Reporting (Crashlytics) | **Done** | firebase_crashlytics dep + guarded init in main.dart"
- `docs/FEATURE_TRACKER.md:241` — "App Performance Monitoring | **Done** | firebase_performance dep + guarded init alongside Crashlytics"
- `docs/ARCHITECTURE.md:341` — "Crashlytics/Perf | Crash + performance monitoring | **Active** (guarded: mobile-only, release-only) | main.dart"

The Dart side is real: `pubspec.yaml:34-35` declares both packages and `lib/main.dart:108-133`
initialises them behind a `kIsWeb`/release guard. **The Android build cannot deliver either:**

```
$ cat android/settings.gradle.kts | grep -c "google-services\|crashlytics\|firebase-perf"
0
$ cat android/app/build.gradle.kts   # plugins { } block:
    id("com.android.application"); id("kotlin-android"); id("dev.flutter.flutter-gradle-plugin")
```

There is **no `com.google.gms.google-services` plugin, no
`com.google.firebase.crashlytics` plugin and no `com.google.firebase.firebase-perf`
plugin** in either Gradle file. Without the Crashlytics Gradle plugin no mapping file or NDK
symbol is uploaded and no `com.google.firebase.crashlytics` manifest wiring is generated;
without `firebase-perf` no bytecode instrumentation occurs.

And the config would fail even if the plugins were added:

```
$ grep package_name android/app/google-services.json
        "package_name": "com.housepital.patient"
$ grep applicationId android/app/build.gradle.kts
    applicationId = "com.housepital.housepital_patient"
```

**Mismatch.** The `google-services` plugin fails the build with "No matching client found for
package name 'com.housepital.housepital_patient'". So the Android target has neither the
plugins nor a usable `google-services.json`.

iOS is the primary platform and `ios/Runner/GoogleService-Info.plist` is present, so the
capability is *partly* real — but "Done" and "Active" are unqualified, and
`00_MASTER_APPLICABILITY_AND_GATE.md:17` declares Android a supported platform. A release
manager reading `FEATURE_TRACKER` sees a delivered feature; a responder reading
`ARCHITECTURE` sees an active monitoring channel. Neither exists on Android, and
`docs/DEPLOYMENT_GUIDE.md:458` offers a checkbox to tick for configuring its alerts.

Compounding: `docs/KNOWN_ISSUES.md:32` records that ~~45~~ **57** `Log.warn`/`Log.error` sites
reach no sink because `logger.dart:63` is an unwired TODO — so even on iOS the app's own
structured warnings never arrive at the Crashlytics the docs call Active.
`PROJECT.md:101` meanwhile still lists Crashlytics as a **TODO**, contradicting both files.
**Three documents, three different states for one capability.**

---

## Control results

### 1. Project meta

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-1.01 `README.md` | **Fail** | Untouched since 2026-06-15; eleven verified false statements (V-7) incl. file count, test count (self-contradicting at `:43` vs `:209`), route count, tab count, tab names, sub-tab count, nav design, and a `_loadMockData()` reference with 0 hits in `lib/` | A new dev cannot trust the front door. **Fix:** one pass over `README:42-45,166,209,210,278-285,334-335,362,389,409,428`. Owner: `OWNER-TBD`, due before any external contributor is onboarded |
| DOC-1.02 `AGENTS.md` equivalent (`CLAUDE.md`) | **Pass** | `CLAUDE.md` tracks the code for a fourth round. New "Storage & session contracts" (`:118-137`) and "Paired foregrounds" (`:102-106`) verified clause-by-clause at V-3/V-4. It is the only doc with no false statement found this round | — |
| DOC-1.03 `CONTRIBUTING.md` | **Warning** | `:31-33` lists 3 CI steps; `grep -c "name:" .github/workflows/ci.yml` → **11**. Omits the design gate and the coverage gate; `flutter test` line still lacks `--dart-define=RAZORPAY_KEY=…`, so copy-pasting it silently skips 17 payment tests | Contributors get a false green locally. Owner `OWNER-TBD`; ~15 min |
| DOC-1.04 `LICENSE` | **Pass** | `LICENSE` exists and names the holder | — |
| DOC-1.05 `CHANGELOG.md` | **Pass** | `:3-25` new dated entry covering rounds 1–3 incl. account deletion (V-9). M-2 closed | Self-dates 2026-08-03 vs commit 2026-08-11 — noted under DOC-9.05 |
| DOC-1.06 `STATE.md`/`PROJECT.md` | **Fail** | Untouched since 2026-06-15. `:4` advertises "Calendar root tab" and "fixed solid-orange nav bar" as shipped; `:101` lists Crashlytics as TODO while `FEATURE_TRACKER:239` says Done; `:105` coverage gate TODO while `ci.yml:66` enforces it; `:31` broken `#-tech-stack` anchor | The done-condition is "reflects today's reality"; it reflects June. `OWNER-TBD` |

### 2. Living technical docs

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-2.01 `ARCHITECTURE.md` | **Warning** | **Strong new work** — 11 providers correct 1:1 (V-3), storage contracts and payment-failure contract accurate to source, demo-banner regression closed (V-5). **But** `:206-208` still says "FIXED full-width solid-orange bar … **Six root** tabs" and `:68` still says "Fixed solid-orange", contradicting `:68`'s own "5 tabs" and the code; `:341` calls Crashlytics/Perf Active (V-11) | A reader of the nav section gets the reverted design and the wrong tab count. Two-line fix, named by line number in round 3. `OWNER-TBD` |
| DOC-2.02 `DATA_MODEL`/`DATABASE_SCHEMA` | **Warning** | Server schema documented well; the **client** storage schema is now covered by `ARCHITECTURE.md:397-436` (M-6 closed ✅), but the 13 SharedPreferences namespaces `StoreMigrator` versions are still not enumerated anywhere | A migration author has the rules but not the inventory. `OWNER-TBD` |
| DOC-2.03 `SCREENS.md`/`SCREEN_MAP.md` | **Warning** | Route table still perfect — 53 code routes vs 53 doc routes, `diff` empty (re-verified). Tab tree fixed. **But** `:22` asserts the fixed orange bar two paragraphs under `:20`'s correction, and `:76`/`:83` still head sections "CALENDAR TAB (Index 3)" / "BILLING TAB (Index 4)" | Self-contradictory in the file whose self-contradiction commissioned the commit. `OWNER-TBD` |
| DOC-2.04 `SETUP.md`/`ENVIRONMENT_SETUP.md` | **Warning** | Untouched since 2026-05-28; `grep -c dart-define docs/ENVIRONMENT_SETUP.md` → **0**; no Firebase Storage step though `firebase.json` and `storage.rules` now exist | A fresh machine gets a config that does not match the repo. `OWNER-TBD` |

### 3. Product / UX

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-3.01 `PERSONAS.md` | **Fail** | `find . -name PERSONAS.md` → empty. Four roles exist in `permissions.dart`; none is described as a person | 4th round. `OWNER-TBD` |
| DOC-3.02 `PROBLEM_STATEMENTS.md` | **Fail** | Absent | `OWNER-TBD` |
| DOC-3.03 `USER_JOURNEYS.md` | **Fail** | Absent. Corroborates `00_MASTER…:38` (MASTER-1.02 Fail) | Blocks traceability (DOC-10.03) |
| DOC-3.04 `USER_FLOWS.md` | **Warning** | No file, but `docs/my-care-tab.md`, `docs/services-tab.md` and `SCREENS_IMPLEMENTATION.md` carry per-feature flows — all undated, two still asserting the dead pricing rule (V-2) | Partial coverage from unowned, contradictory sources |
| DOC-3.05 `ONBOARDING.md` | **Fail** | Absent; an onboarding flow exists (`SCREENS_IMPLEMENTATION:715` "Login → OTP → Onboarding → Home") so the trigger fires | `OWNER-TBD` |
| DOC-3.06 `ROADMAP.md` | **Warning** | No file; `FEATURE_TRACKER.md` partially substitutes but is blind to everything shipped since `820060b` (7 keyword greps → 0) | `OWNER-TBD` |

### 4. Brand / design

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-4.01 `BRAND.md` / token no-drift | **Warning** | **Much improved:** `orangeStrong` and `onError` are now documented (`CLAUDE.md:102-106`) with nine independently-verified ratios (V-4). H-9's dangerous half is dead. **Residual drift:** `theme.dart:7` and `:347-348` still carry the pre-2026-06 dark-ink claim and a wrong 2.7:1 figure — `:348` states the reverse of `:83`/`:440`; `theme.dart:20` contradicts `:17`; `docs/services-tab.md:300-307`'s token table (2026-03-21) omits six live tokens | `theme.dart:347-348` carries the same revert-the-owner hazard round 3 rated a blocker. **Fix:** delete the two clauses. `OWNER-TBD`, ~10 min |
| DOC-4.02 Brand guidelines source | **BLOCKED-OWNER** | `PROJECT.md:22` TODO; cannot determine whether a PDF exists outside the repo | — |
| DOC-4.03 Design-system reference | **Warning** | `CLAUDE.md`'s design-system contract and `ARCHITECTURE:200-215` cover chrome/cards/glass well; no component catalogue, and `:206-208` is wrong (DOC-2.01) | `OWNER-TBD` |

### 5. Quality & audits

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-5.01 `QA_CHECKLIST.md` | **Fail** | Absent, 4th round. The untested-by-hand surface has grown again: `StoreMigrator` v2 (runs on every cold start), the `SessionScope` fan-out via `AppProvider.onPatientChanged`, `/delete-account`, the typed `PaymentFailure` paths, a third nav shape and a second demo-notice shape | No recorded manual pass exists for any release-blocking runtime path. Release-blocking. `OWNER-TBD` |
| DOC-5.02 `TEST_RESULTS.md` / `TEST_MAP.md` | **Warning** | `:6` corrected to 101 files / 1,819 ✅ and `:305-316` adds the two new guard files with a standing instruction ✅. **But** `:4` still says ~1,771 / 1,370 call sites / 37 screens two lines above it; actual call sites **1,402**, actual overflow screens **41**; `:156` inventory still 86 of 101; header self-dates 2026-06-15 (V-6) | A reader takes the first number they meet. `OWNER-TBD` |
| DOC-5.03 `ACCESSIBILITY_AUDIT.md` | **Pass** | `docs/audits/ACCESSIBILITY_AUDIT.md` + round3 + round4 exist and are dated | Content graded by the Accessibility module, not here |
| DOC-5.04 Audit findings + resolution status | **Warning** | `docs/KNOWN_ISSUES.md:7-49` now carries blockers, highs and accepted risks — a genuine close of H-10 ✅. **But** three verified false claims in that same new block (`:32` ~45 vs **57**; `:30` eleven sources/one call site vs **12/2**; `:96` BUG-15 and `:134` TD-13 marked Resolved when they are not — V-9), and 10 of 12 round-2 reports still carry no status header | A responder acts on understated numbers and two false "Resolved" markers, one on a data-loss path. `OWNER-TBD` |
| DOC-5.05 `SECURITY_REVIEW.md` | **Pass** | `docs/audits/SECURITY_PRIVACY_AUDIT.md` (+ round3) exists; trigger fires (auth, payments, PII) | — |

### 6. Compliance & ship

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-6.01 `PRIVACY_POLICY.md` | **Fail** | Absent, 4th round. `/delete-account` ships (`main.dart:745-747`) as a DPDP §12 erasure path with no policy behind it; `demo_mode.dart` is a formal admission the app may render another patient's sample record | Hard App Store gate. Release-blocking. `OWNER-TBD` |
| DOC-6.02 `DATA_HANDLING.md` + store labels | **Fail** | Absent. No app-level `PrivacyInfo.xcprivacy` (`find . -name PrivacyInfo.xcprivacy` returns Pods' own manifests only) | Hard App Store gate. Release-blocking. `OWNER-TBD` |
| DOC-6.03 `RELEASE_CHECKLIST.md` | **Warning** | No such file; `DEPLOYMENT_GUIDE` §8 substitutes and is now **half-correct**: storage deploy added to the pre-launch block ✅ with an accurate scope caveat ✅, but §8 still has no storage checkbox and no storage verify command, and `:439`'s obfuscation claim is false (V-8) | A release manager still ticks "rules deployed AND verified" with Storage unconfirmed. `OWNER-TBD` |
| DOC-6.04 `THIRD_PARTY_LICENSES.md` | **Fail** | Absent; `pubspec.lock` present, so the trigger fires and it is generatable | `OWNER-TBD` |
| DOC-6.05 `TERMS_OF_SERVICE.md` | **Fail** | Absent; accounts + payments + UGC all present | `OWNER-TBD` |

### 7. Per-feature docs

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-7.01 Spec | **Warning** | `docs/superpowers/specs/` has 3 specs, newest 2026-06-02. Nothing for the five-tab nav, the demo-mode/`SessionScope`/`StoreMigrator` work, `/delete-account`, or the typed `PaymentFailure` — all of which clear the "would a reviewer want the rationale written down?" bar | Rationale survives only in commit messages and code comments. `OWNER-TBD` |
| DOC-7.02 Plan | **Warning** | `docs/superpowers/plans/` — same 4 files, newest 2026-06-02 | `OWNER-TBD` |
| DOC-7.03 Living docs updated when a feature lands | **Warning** | **First round this is arguably met for §2 docs**: `ARCHITECTURE`, `SCREEN_MAP`, `CLAUDE.md`, `TEST_MAP`, `KNOWN_ISSUES`, `CHANGELOG`, `DEPLOYMENT_GUIDE` all moved with `13e3656`. **But** it lagged by one commit and copied pre-fix figures (V-9), `FEATURE_TRACKER` did not move at all, and `README`/`PROJECT` are four rounds behind | The practice now exists and is not yet reliable. `OWNER-TBD` |

### 8. Ops / infra

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-8.01 `CI.md` | **Warning** | No `CI.md`; `CONTRIBUTING.md:31-33` documents 3 of 11 `ci.yml` steps (DOC-1.03) | `OWNER-TBD` |
| DOC-8.02 `DEPLOYMENT.md` | **Warning** | `docs/DEPLOYMENT_GUIDE.md` is thorough and materially improved this round; defects at V-8 (§8 checklist gap, no storage verify, false `:439` obfuscation claim, a Crashlytics-alerts checkbox for a target that cannot report) | `OWNER-TBD` |
| DOC-8.03 `RUNBOOK.md` | **Fail** | Absent. Two backends exist; `docs/TROUBLESHOOTING.md` (2026-03-25) is a dev-environment FAQ, not incident response. No on-call, no escalation, no common-failure playbook | Trigger fires (there is a service). `OWNER-TBD` |

### 9. Documentation governance

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-9.01 Documentation index with purpose, location, owner, audience, cadence, last-verified | **Fail** | No index anywhere. `docs/` has 16 top-level files and no map; `docs/audits/` has no `INDEX.md` (V-10). **No document in this repo names an owner.** Four rounds have asked | This is the root cause of the family's other failures: with no owner and no cadence, drift has no one to catch it. Release-blocking for the family. `OWNER-TBD` |
| DOC-9.02 Normative vs current-state vs decisions vs procedures vs examples vs history distinguished | **Warning** | Best-in-class where it is done: `ARCHITECTURE:397-462`, `CLAUDE.md`'s "Inviolable business rules", `KNOWN_ISSUES`'s "Accepted risks (owner decisions, not defects)" block, and the `assistant_executor.dart:379-384` "that rule is DEAD" pattern all separate the categories explicitly. Not done in `README`, `PROJECT`, `SCREENS_IMPLEMENTATION`, `services-tab`, `my-care-tab` — which mix current state with history and carry no banner | `OWNER-TBD` |
| DOC-9.03 Conflicting sources removed or explicitly linked | **Fail** | Live conflicts, all verified this round: nav design (7 files vs code); tab count (`ARCHITECTURE:68` vs `:207`); tab indices (`SCREEN_MAP:5-12` vs `:76`/`:83`); pricing rule (`services-tab:74` vs `:154`/`:386`); test count (`TEST_MAP:4` vs `:6`; `README:43` vs `:209`); Crashlytics state (`FEATURE_TRACKER:239` Done vs `PROJECT:101` TODO vs `ARCHITECTURE:341` Active — none true on Android). No generated doc names its generator | This is the family's defining defect and it is **worse** than round 3 in two files, because corrections were added beside the errors rather than replacing them | 
| DOC-9.04 Material doc changes reviewed with the change they describe | **Warning** | `13e3656` (code) and `9127713` (docs) are separate commits 8 days apart, and the doc commit recorded pre-`13e3656` figures for `DemoMode` (V-9). No PR exists; branch is unpushed | The review coupling the control asks for is structurally absent. `OWNER-TBD` |
| DOC-9.05 Stale artifacts, broken links, missing owners, overdue reviews detected and tracked | **Fail** | No detection mechanism of any kind (no link check, no doc-freshness CI step in `ci.yml`'s 11 steps). Evidence it is needed: three files self-date **2026-08-03** while committed **2026-08-11**; `TEST_MAP:3` self-dates 2026-06-15 with a 2026-08-11 edit inside it; `README`/`PROJECT`/`CONTRIBUTING`/`ENVIRONMENT_SETUP` overdue by 2–6 months; `PROJECT.md:31` broken anchor; no owner on any document | Every finding in this report is an instance of this control failing. **The highest-leverage single fix in the family.** `OWNER-TBD` |

### 10. Decisions, contracts, traceability

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-10.01 ADRs with alternatives, consequences, owner, superseding decisions | **Warning** | No `adr/` directory. **But** decision records with rationale and superseded-by now exist inline and are good: `ARCHITECTURE:397-436` (why per-patient keys), `:438-452` (why typed `PaymentFailure`), `CLAUDE.md:23-32` (pricing lineage with date and commit), `app_colors.dart:58-72`, `assistant_executor.dart:379-384`. What is missing is the **owner** on each and a single place to find them | Consequential decisions are recoverable but only by someone who already knows where to look. `OWNER-TBD` |
| DOC-10.02 API/event/file contracts: schemas, authz, idempotency, errors, compatibility, limits, versions, deprecation | **Warning** | Materially improved: `docs/API_REFERENCE.md` + the new storage contract (versions via `StoreMigrator`, quarantine on parse failure, frozen literals, deprecation of the legacy global keys) + the payment-failure contract (errors + retry semantics) + `DEPLOYMENT_GUIDE:402-406`'s authorization-limits caveat. Missing: idempotency, rate limits, and the fact that the two backends define the same six nouns **incompatibly** is recorded only in `KNOWN_ISSUES:38-41`, not in any contract doc | `OWNER-TBD` |
| DOC-10.03 Requirements/acceptance criteria trace to implementation, tests, signals, release evidence | **Fail** | No journeys (DOC-3.03), no acceptance criteria, no operational signals to trace to (`logger.dart:63` unwired; V-11), no release evidence (no release). `TEST_MAP:305-316` newly traces two guards to the defects they guard — the only instance of this control being met anywhere | `OWNER-TBD` |
| DOC-10.04 Config and feature flags: defaults, environments, owners, expiry, safety impact, rollback, no secrets | **Warning** | `CLAUDE.md`'s secrets paragraph is exemplary — it corrects a previously-wrong claim, explains *why* Firebase client keys are not secrets, and names the real control. `--dart-define=RAZORPAY_KEY` semantics documented in three places consistently. **But** no flag inventory, no owners, no expiry; and the flag that matters most — a `DEMO_DATA` gate — **does not exist**, which `KNOWN_ISSUES:15-17` records honestly | `OWNER-TBD` |

### 11. Security, data, operations documentation

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-11.01 Threat model, security architecture, data-flow map, data inventory, retention, processors, privacy/store declarations | **Fail** | No threat model, no data inventory, no retention schedule, no processor list, no privacy policy, no store declarations, no `PrivacyInfo.xcprivacy`. `storage.rules`' header + `ARCHITECTURE:391-395` + `DEPLOYMENT_GUIDE:402-406` are a genuine, accurate slice of security architecture — one slice | Health data under DPDP 2023. Release-blocking. `OWNER-TBD` |
| DOC-11.02 SBOM, third-party notices, dependency exceptions, vulnerability policy, security contact, patch process | **Fail** | None present. `pubspec.lock` exists (SBOM is generatable); no `SECURITY.md`, no contact, no policy | `OWNER-TBD` |
| DOC-11.03 SLIs/SLOs, dashboards, alerts, on-call, incident roles, runbooks, backup/restore, RPO/RTO, DR | **Fail** | `DEPLOYMENT_GUIDE:430-437` names four alert thresholds (fatal >0.1%/1h, app start >5s p95, HTTP >3s p95) — the only SLO-shaped content in the repo, and it is attached to a Crashlytics/Performance channel that does not function on Android and receives none of the app's own 57 `Log.warn`/`Log.error` sites (V-11). No on-call, no incident roles, no runbook (DOC-8.03), no backup/restore, no RPO/RTO | `OWNER-TBD` |
| DOC-11.04 Migration, backfill, rollback/forward-fix, compatibility, deprecation executable by someone other than the author | **Pass** | `ARCHITECTURE:428-436` + `CLAUDE.md:133-137` state the migrator procedure as executable rules (bump `currentVersion`, add to `_buildShippedMigrations()`, FROZEN literals, `quarantine()` not overwrite, never stamp a failed step, `debugSetMigrations()` for testability), all verified against `store_migrator.dart:34,55-70,91-103,129,139-158`. `DEPLOYMENT_GUIDE` §9 documents Cloud Functions rollback. **The one control this round moved from nothing to met** | Client-side rollback (v2→v1) is not documented; forward-fix only |

### 12. User, accessibility, support documentation

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| DOC-12.01 In-product help, support articles, troubleshooting, export/deletion instructions, accessibility statement, known limitations match the released product | **Fail** | No user-facing help or support article set; no accessibility statement; no export/deletion instructions though `/delete-account` ships. In-product support routes to `AppConstants.supportPhone` and `wecare@housepital.in` (`document_repository_screen.dart:599`) with no documented procedure behind either. `docs/TROUBLESHOOTING.md` is developer-facing and dates to 2026-03-25 | DPDP §12 requires the user be told how to exercise erasure. Release-blocking. `OWNER-TBD` |
| DOC-12.02 Support procedures: identity verification, safe diagnostics, personal-data access, escalation, destructive-advice safeguards | **Fail** | Nothing. The app is shared by patient, primary contact, family members and staff across four roles, and a support agent has no documented identity-verification step before discussing a patient record | Direct PHI-disclosure risk at the support desk. `OWNER-TBD` |
| DOC-12.03 User/support docs localized, accessible, versioned, archived per market | **Fail** | The product is EN/HI (353 key pairs, `NotoSansDevanagari` bundled) and there is no user documentation in either language to localize. Not tested is not N/A — the requirement is unmet, not inapplicable | `OWNER-TBD` |

---

## Assessment of `docs/audits/round4/00_MASTER_APPLICABILITY_AND_GATE.md`

Assessed against the checklist's **Audit record**, **Outcome and evidence rules**, **Release
rule**, **Final sign-off** and **Revision history** sections.

**Audit record (checklist §"Audit record") — Pass.** All five required fields are present at
`:12-23`: app/project, release/build/artifact, platforms/environments/territories,
owner/auditor/reviewer, audit date/decision date. The artifact row is unusually honest — "No
release. Unsigned-for-distribution Release build side-loaded to one device… Never submitted to
App Store Connect" — which is the fact most audits fudge.

**Outcome and evidence rules — Pass.** `:27-31` restates Pass/Warning/Fail/N/A, quotes **"Not
tested is not N/A"** verbatim, and defines `BLOCKED-OWNER` for access it does not have. `:74`
states "**No trigger is N/A**" and justifies all twelve MASTER-3.xx triggers individually. I
spot-checked four and all hold: 3.02 (Razorpay + cart + EMI), 3.05 (`assistant_executor`
booking actions), 3.09 (`XFile` photo capture, PDF export), 3.12 (EN/HI, bundled Devanagari).
**The document uses N/A zero times.** That is the single best signal in it.

**Are its self-declared Fails honest? — Yes, verified.** I checked each against the repo
rather than accepting it:

| Self-declared | Verified |
|---|---|
| MASTER-1.02 Fail — no critical journeys documented | ✅ No `USER_JOURNEYS.md`; `FEATURE_TRACKER` lists features not journeys (my DOC-3.03 Fail, reached independently) |
| MASTER-1.03 Fail — no register, no owners, no privacy docs | ✅ `find` for `PRIVACY_POLICY.md`/`DATA_HANDLING.md` → empty (my DOC-6.01/6.02) |
| MASTER-1.05 Fail — no evidence store, tracker, risk authority or release approver named | ✅ No document in the repo names an owner (my DOC-9.01 Fail, same root cause) |
| MASTER-4.02 Fail (structural) — Warnings cannot carry approver/due-date until 1.05 is fixed | ✅ Correct and correctly *scoped* as structural rather than blamed on module authors |
| MASTER-4.04 Fail — all evidence is static source; no production, no release artifact | ✅ And note this is **stricter than the brief required** — the brief calls this "an honest constraint, not a failure". Erring against itself is evidence of good faith |
| MASTER-4.05 Fail — no privacy policy, no `PrivacyInfo.xcprivacy`, no store labels, no traffic capture | ✅ `find . -name PrivacyInfo.xcprivacy` returns Pods' manifests only; the app target has none |

**No Fail is softened and none is invented.** The §5 recommendation (**Reject** for public
release, **Hold** for internal field use) follows from its own findings, and its four
justifications are each independently supported — I verified justification 1 (demo-data
fallback with no `DEMO_DATA` flag) and justification 4's storage-rules and debug-keystore
items directly (`android/app/build.gradle.kts:34-37` signs release with the debug config).

**Is marking controls OWNER rather than guessing correct? — Yes, and it is the right call.**
The checklist requires the audit record to *name* owner, auditor and reviewer; it does not
permit the auditor to invent them. The document could have harvested "Ateeshay Jain" from
`git log` and filled the Owner cell — and that would have been a **fabricated
risk-acceptance authority**, the most damaging thing an audit record can contain, because
every accepted Warning would then trace to a signature nobody gave. Marking `OWNER — to
name` and grading **MASTER-1.01 Warning** (not Pass) records the gap instead of papering
over it, and never uses N/A to escape it. That is exactly the treatment the checklist's
"Not tested is not N/A" rule and the brief's `OWNER-TBD` convention prescribe. The only
nit is cosmetic: the doc writes `OWNER`/`OWNER — to name` where the brief specifies
`OWNER-TBD`.

**Two defects.**

1. **MASTER-1.04 is graded Pass and should be Warning.** The control is *"template changes do
   not rewrite prior audit records"*. The cell discloses, honestly, that round 2 rewrote round
   1 in place — and then grades the control **Pass**. A records-integrity control cannot pass
   in the same sentence that discloses a records-integrity failure whose remediation has not
   been performed. Round 3 graded this "⚠️ adequate going forward, not yet adequate as a
   record" and gave three reasons; **none has been addressed** (V-10): round 1 is still only a
   git object under a SHA that nine of twelve round-2 files never mention; there is still no
   `INDEX.md`; and the layout is now three-deep with the *oldest* on-disk round at the *most
   prominent* path. "Prospectively satisfied, retrospectively not" is the definition of
   Warning. This is my one substantive disagreement with the document, and it is the grade an
   independent reviewer is most likely to challenge, because it is self-refuting on its face.
2. **No revision history.** The checklist's audit record closes with `Revision history |
   Version | Date | Change`. The document has a "Source baselines" section (`:119-123`) but no
   revision-history table, so a reader cannot tell what changed between this gate document and
   any prior one. Minor, mechanical, ~5 minutes.

**Two accuracy notes, neither the document's fault to originate but both its to carry.**

- `:22` dates the audit **2026-08-03** while the commit under audit, `9127713`, was authored
  **2026-08-11** (`git log -1 --format=%cd 9127713`). The date comes from the round-4 brief's
  template, so it is inherited rather than invented — but an audit record dated eight days
  before the artifact it audits is the first thing an external reviewer will notice, and
  correcting it is free.
- `:66` (MASTER-3.06) says "Firebase Performance + Crashlytics transmit off-device" as the
  reason the analytics trigger fires. On Android neither transmits anything — the Gradle
  plugins are absent and `google-services.json`'s `package_name` does not match the
  `applicationId` (V-11). The trigger still fires correctly on iOS, so the *conclusion* is
  sound and the *rationale* is half-wrong.

**Verdict on the gate document: Pass with two Warnings** (MASTER-1.04 over-graded; revision
history absent). It is the most disciplined document in this repository. It states its own
material limitation plainly (MASTER-4.04), it refuses N/A entirely, it grades itself Fail six
times, and it declines to guess at authority it does not have. **An independent reviewer will
trust this document.** That is not something I can say about any other file I graded.

---

## Scorecard

| Section | Pass | Warning | Fail | N/A | BLOCKED-OWNER |
|---|---|---|---|---|---|
| 1. Project meta | 3 | 1 | 2 | 0 | 0 |
| 2. Living technical docs | 0 | 4 | 0 | 0 | 0 |
| 3. Product / UX | 0 | 2 | 4 | 0 | 0 |
| 4. Brand / design | 0 | 2 | 0 | 0 | 1 |
| 5. Quality & audits | 2 | 2 | 1 | 0 | 0 |
| 6. Compliance & ship | 0 | 1 | 4 | 0 | 0 |
| 7. Per-feature docs | 0 | 3 | 0 | 0 | 0 |
| 8. Ops / infra | 0 | 2 | 1 | 0 | 0 |
| 9. Governance | 0 | 2 | 3 | 0 | 0 |
| 10. Decisions & contracts | 0 | 3 | 1 | 0 | 0 |
| 11. Security / data / ops docs | 1 | 0 | 3 | 0 | 0 |
| 12. User / support docs | 0 | 0 | 3 | 0 | 0 |
| **TOTAL (51 controls)** | **6** | **22** | **22** | **0** | **1** |

**Pass 6 · Warning 22 · Fail 22 · N/A 0 · BLOCKED-OWNER 1**

*Comparability note:* rounds 1–3 graded only §1–8 (35 items) on a ✅/⚠️/❌ scale. On that
same 35-item subset this round is **5 Pass / 17 Warning / 12 Fail / 1 BLOCKED-OWNER**, against
r1 3/16/16 → r2 3/18/14 → r3 3/21/11. **The Pass column has moved for the first time in four
rounds** (`CLAUDE.md` DOC-1.02, `CHANGELOG` DOC-1.05, `SECURITY_REVIEW` DOC-5.05 formalised,
plus DOC-11.04 in the new sections). The Fail column rose from 11 to 12 on the subset because
`README.md` and `PROJECT.md`, previously graded Warning, are now four rounds stale against a
subject that changed three more times — under v2.0's stricter evidence rule that is a Fail,
not a Warning. §9–12 are graded here for the first time and account for 10 of the 22 Fails.

---

## Release blockers (every Fail)

1. **DOC-6.01 / DOC-6.02 — no `PRIVACY_POLICY.md`, no `DATA_HANDLING.md`, no app
   `PrivacyInfo.xcprivacy`.** Fourth round. Hard App Store gates; DPDP 2023 applies to health
   data; `/delete-account` ships as an erasure path with no policy behind it.
2. **DOC-5.01 — no `QA_CHECKLIST.md`.** Fourth round. No recorded manual pass exists for
   `StoreMigrator` v2 (every cold start), the `SessionScope` fan-out, `/delete-account`, the
   typed payment paths, or either of the two chrome shapes shipped in the last week.
3. **DOC-9.01 / DOC-9.05 — no documentation index, no owner on any document, no
   staleness detection.** This is the **root cause** of most other findings in this family
   and the highest-leverage fix available.
4. **DOC-9.03 — conflicting sources of truth, now including conflicts created by this very
   commit.** Nav design (7 files), tab count (`ARCHITECTURE:68` vs `:207`), tab indices
   (`SCREEN_MAP:5-12` vs `:76`/`:83`), pricing rule (`services-tab:74` vs `:154`/`:386`),
   test count (`TEST_MAP:4` vs `:6`), Crashlytics state (three docs, three answers, none
   true on Android).
5. **DOC-1.01 / DOC-1.06 — `README.md` and `PROJECT.md` untouched for four rounds**, eleven
   and seven verified false statements respectively.
6. **DOC-11.01 / DOC-11.02 / DOC-11.03 — no threat model, data inventory, retention
   schedule, processor list, SBOM, security contact, vulnerability policy, on-call, incident
   roles, backup/restore or RPO/RTO.**
7. **DOC-12.01 / DOC-12.02 / DOC-12.03 — no user-facing help, no accessibility statement, no
   erasure instructions, and no support procedure defining identity verification** before a
   support agent discusses a record on an app shared across four roles.
8. **DOC-3.01 / 3.02 / 3.03 / 3.05, DOC-6.04, DOC-6.05, DOC-8.03, DOC-10.03** — absent
   required artifacts (personas, problem statements, journeys, onboarding, third-party
   licenses, ToS, runbook, traceability).

**False claims standing in current documentation** — each verified in this report, each
correctable in minutes, each capable of causing a wrong decision:

| Claim | Location | Reality |
|---|---|---|
| Performance Monitoring "Done" | `FEATURE_TRACKER.md:241` | No `firebase-perf` Gradle plugin; `google-services.json` package_name ≠ applicationId (V-11) |
| Crash Reporting "Done" | `FEATURE_TRACKER.md:239` | No Crashlytics Gradle plugin on Android (V-11) |
| Crashlytics/Perf "Active" | `ARCHITECTURE.md:341` | Same; and 57 `Log.warn`/`Log.error` sites reach no sink |
| "~45 warn/error sites" | `KNOWN_ISSUES.md:32` | **57** |
| "eleven sources / one `markServingLiveData` call site" | `KNOWN_ISSUES.md:30` | **12 sources / 2 call sites** |
| Document repository "Resolved" | `KNOWN_ISSUES.md:96` | `XFile.path` discarded, `fileSizeBytes: 350000` hardcoded, nothing persisted, "saved successfully" shown (V-9) |
| TD-13 correlation IDs "RESOLVED" | `KNOWN_ISSUES.md:134` | Minted and returned as a header; **never written to a log line** (V-9) |
| "all iOS crash reports are obfuscated and useless" | `DEPLOYMENT_GUIDE.md:439` | No `--obfuscate` anywhere; Dart frames stay readable (V-8) |
| "FIXED full-width solid-orange bar" | `SCREEN_MAP.md:22`, `ARCHITECTURE.md:68,206` + 4 more | Floating glass pill since `d439928` (V-1) |
| "Six root tabs" | `ARCHITECTURE.md:207` + 9 more | Five (V-1) |
| "Never show prices for manpower services" | `services-tab.md:154,386` + 6 code/test sites | Rule reversed 2026-06-11 (V-2) |
| dark buttons "use dark text" | `theme.dart:348` | `HousepitalColorsDark.onOrange` is `#FFFFFF`; ratio is 2.33:1 not 2.7:1 (V-4) |
| "Surface is intentionally `#1A1A1A`" | `theme.dart:20` | `theme.dart:17` is `#000000` (V-4) |

## Warnings requiring risk acceptance

All 22 Warnings above carry impact and a proposed fix; every owner field is `OWNER-TBD`
because **no document in this repository names an owner** (DOC-9.01) and no risk-acceptance
authority exists (`00_MASTER…:41`, MASTER-1.05 Fail). Per the checklist, a Warning requires
impact, evidence, ticket, owner, due date, mitigation **and approver**; only impact, evidence
and mitigation can currently be supplied. **This is a structural blocker on the Warning
mechanism itself**, not a diligence gap in the module reports, and it is correctly identified
as such at `00_MASTER…:83`.

The three **accepted owner risks** are correctly documented as decisions rather than defects
and are **not** graded Fail anywhere in this report: white on Housepital orange (2.33:1 —
measured and confirmed at V-4), manpower prices shown and directly bookable, and the floating
glass pill nav. `docs/KNOWN_ISSUES.md:46-49` records all three under an explicit "Accepted
risks (owner decisions, not defects)" heading — the correct treatment, and new this round.

## BLOCKED-OWNER — needs access I do not have

- **Whether `storage.rules` has been deployed.** Needed: `firebase storage:rules get
  --project housepital-patient`, or a console screenshot. More urgent than in round 3 because
  `DEPLOYMENT_GUIDE` §8 still gives a green tick covering Firestore only (V-8).
- **Liveness and content of `https://housepital.in/privacy` and `/terms`**
  (`about_screen.dart:97-98,103-104`). Determines whether DOC-6.01 is authoring or linking.
- **App Store Connect / Play Console privacy-label answers** — whether any are filled.
- **Whether the brand guidelines PDF exists outside the repo** (`PROJECT.md:22`) — the one
  control graded BLOCKED-OWNER in the table above (DOC-4.02).
- **CI green/red and current coverage %** — `ci.yml:66-79` enforces 50%; I was instructed not
  to run the suite and cannot read GitHub Actions.
- **Owner, auditor-of-record, independent reviewer, risk-acceptance authority, release
  approver** — five names that unblock MASTER-1.01, MASTER-1.05, MASTER-4.02 and the entire
  Warning mechanism.

## Limitations of this audit

- **MASTER-4.04: this is a source review.** No release artifact exists; the app has never
  been built for distribution. No production environment exists — `api.housepital.in` does not
  resolve. I inspected no built IPA/APK, no App Store Connect record, no Firebase console, no
  production traffic and no device. **This is a material limitation, stated plainly, and it
  bounds every verdict above to "true of the source at `9127713`".**
- **Per the brief I did not run `flutter test`, `flutter build`, `flutter clean` or `pod
  install`.** Test counts are from `find`/`grep` over sources plus the brief's central figure
  (1,819 / 101 files). The 1,402 `test()`/`testWidgets()` call-site count is a static count
  and does not account for parameterized expansion.
- **Contrast ratios were computed by me** from the hex literals in `theme.dart` /
  `app_colors.dart` using the WCAG 2.x sRGB relative-luminance formula, not measured on a
  device and not taken from any comment. They verify the *specification*; they do not account
  for on-device rendering, opacity compositing over glass surfaces, or `BackdropFilter`.
- **Android findings are configuration-derived.** I read the Gradle files and
  `google-services.json`; I did not attempt an Android build (prohibited) and tested no
  Android device. The conclusion that Crashlytics/Performance cannot function on Android
  follows from the absence of the required Gradle plugins and the package-name mismatch, both
  of which are directly quotable from source.
- **Backend findings** come from reading `../housepital-backend/functions/src`. I did not
  execute it, and `../housepital-api` (Laravel) was not read for this module.
- I graded §9–12 of the v2.0 checklist, which rounds 1–3 did not cover; the headline
  Pass/Warning/Fail totals are therefore **not directly comparable** to prior rounds without
  the 35-item subset restated in the Scorecard.
- **No code changes were made.** The only file I wrote is this report.
