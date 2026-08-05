# Documentation Checklist — Audit round 3 vs commit `9a80fe2`

**Date:** 2026-08-05 · **Auditor:** Documentation audit agent
**Repo:** `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`
**HEAD:** `9a80fe2` on `fix/five-tab-nav` · **Round 2:** `820060b` · **Round 1:** `803124d`

> Every verdict cites a file:line or a command with its output. No verdict is taken from a
> document's own self-description, and none from a commit message — `0f2729e`'s message is
> treated as a *claim to be tested*, not as evidence.

---

## The round-3 headline

**`0f2729e` is the first commit in this repo's recent history that actually updates docs when
code changes. It is real work and it is not a surface. But it is a *line-level* fix applied to
a *paragraph-level* problem: in three of the six documents it touched, it corrected the number
the audit quoted and left the sentence around it false.**

The clearest instance is `docs/SCREEN_MAP.md`. Round 2 quoted `:6` ("MainShell -- 6 tabs").
`0f2729e` changed that token to `5`. The six-item list immediately beneath it was not touched:

```
$ sed -n '6,15p' docs/SCREEN_MAP.md
Bottom Tab Bar (MainShell -- 5 tabs, FIXED full-width solid-orange bar)
  |-- [0] Home        -> HomeScreen (Dashboard)
  |-- [1] My Care     -> MyCareScreen (Active services hub)
  |-- [2] Services    -> ServiceCatalogScreen (Marketplace)
  |-- [3] Calendar    -> CareCalendarScreen (Day/Week/Month care calendar)
  |-- [4] Billing     -> BillingScreen (Payments & invoices)
  |-- [5] More        -> SettingsScreen (Profile, settings, support)
...
**Calendar was added as a root tab at index 3** (field round 4-5)
```

The document now declares five tabs and then enumerates six. Before `0f2729e` it was merely
wrong; it is now **self-contradictory**, which is a worse failure mode — a reader who trusts
the header and a reader who trusts the list reach different conclusions from the same page.

The second theme is timing. `0f2729e` landed **2026-08-04 07:36**. `d439928` — which reversed
the nav back to a floating glass pill and reshaped the demo notice — landed **08:19**, 43
minutes later. So three of the lines `0f2729e` carefully edited were made false by the very
next commit, and nothing followed up:

```
$ for c in 0f2729e d439928 6d4abcb 9a80fe2; do git log -1 --format='%h %cd %s' --date=iso $c; done
0f2729e 2026-08-04 07:36:24 docs: close the drift the documentation audit found twice
d439928 2026-08-04 08:19:56 feat: floating liquid-glass pill nav; demo notice becomes an overlay
6d4abcb 2026-08-04 08:32:35 fix: give the nav pill a visible material (it was white on white)
9a80fe2 2026-08-05 08:26:01 style: frost the nav pill instead of outlining it

$ for c in d439928 6d4abcb 9a80fe2; do git show --stat $c | grep '\.md'; done
CLAUDE.md | 19 +++++-        # d439928
(6d4abcb: none)
(9a80fe2: none)
```

**Three chrome commits, one `.md` touched, and it was `CLAUDE.md` — the exact pattern rounds 1
and 2 flagged, reproducing itself within an hour of the commit that was supposed to end it.**

---

## Round-2 findings: status now

| Finding | R2 grade | Now | Evidence |
|---|---|---|---|
| **R-1** `SCREEN_MAP` route table drifted (`/delete-account` missing) | ❌ REGRESSION | **FIXED ✅** | `comm`/`diff` of 53 code routes vs 53 doc routes → **identical**; see V-1 |
| **R-2** `DEPLOYMENT_GUIDE` ships undeployed storage rules | ❌ REGRESSION | **PARTIAL ⚠️** | `--only storage` added at `:47` only; the two places R-2 named (`:386-395`, `:441-450`) still have no storage step — see V-4 |
| **R-3** `SCREEN_MAP:209` documents `/services` as a live placeholder | ❌ REGRESSION | **FIXED ✅** | `docs/SCREEN_MAP.md:209` now `-> root tab 2 (redirect)`; matches `lib/main.dart:568-571` |
| **B-1** dead pricing rule, 9 doc lines | ❌ 0/9 | **4 of 9 fixed ⚠️** | API_REFERENCE + all 3 DATABASE_SCHEMA lines genuinely fixed; 5 remain — see V-2 |
| **B-2** dead pricing rule, 7 code/test sites | ❌ 0/7 | **1 of 7 fixed, +1 new found ⚠️** | only `staff_role_sheet_test` renamed; 6 comments verbatim; **new:** `assistant_executor.dart:377` — see V-2 |
| **B-3** no PRIVACY_POLICY / DATA_HANDLING | ❌ | **UNCHANGED ❌** | `find . -name PRIVACY_POLICY.md -o -name DATA_HANDLING.md` → empty |
| **B-4** no QA_CHECKLIST.md | ❌ | **UNCHANGED ❌** | `find . -name QA_CHECKLIST.md` → empty |
| **H-1** 16 doc lines assert six tabs | ❌ 0/17 rows | **3 of 17 fixed ⚠️** | 14 rows verbatim, incl. the whole SCREEN_MAP tab tree — see V-3 |
| **H-2** `BookingHistoryScreen` phantom | ❌ | **UNCHANGED ❌** | `docs/SCREEN_MAP.md:62,218`; `grep -rn "class BookingHistoryScreen" lib/` → no definition |
| **H-3** `ARCHITECTURE` says 10 providers | ❌ | **PARTIAL ⚠️** | `:17` now "11 providers" ✅; `:348` still "**Ten** `ChangeNotifierProvider` instances" and the table `:350-361` still lists 10 — `RemindersProvider` still absent |
| **H-4** `TEST_MAP` 14 files short, every headline wrong | ❌ | **WORSE ❌** | file untouched (`git log -1 --format=%cd -- docs/TEST_MAP.md` → **2026-06-15**); disk now **101** files vs doc's 99 |
| **M-1** "37 screens" overflow figure stale in 8 places | ❌ | **WORSE ❌** | actual now **41** screens (21 `noArg` + 15 `argScreen` + 5 explicit `testWidgets`); was 39 in r2 |
| **M-2** `FEATURE_TRACKER` blind to `820060b` | ❌ | **UNCHANGED ❌** | one row edited; `grep -ci` for "delete account", "session scope", "demo mode", "storage rules", "migrat", "sample data" → **0 each** |
| **M-6** `KNOWN_ISSUES` misstates its own date | ⚠️ | **UNCHANGED ⚠️** | `:5` says 2026-05-28, git says 2026-06-11 |
| **M-7** three Flutter versions | ⚠️ | **UNCHANGED ⚠️** | `README.md:26` 3.16+ · `PROJECT.md:29` 3.41+ · `ci.yml:22` 3.41.2 |
| **M-8/M-9** README stat block wrong on 5+ counts | ⚠️ | **WORSE ⚠️** | README untouched (2026-06-15); drift grew — see V-5 |
| **D-1** five new artifacts invisible to every doc | ❌ | **PARTIAL ⚠️** | ARCHITECTURE covers all five well; TEST_MAP and FEATURE_TRACKER cover **none** — see V-6 |
| **H-5** no audit report carries resolution status; synthesis stale | ⚠️ | **IMPROVED ⚠️** | `AUDIT_SYNTHESIS.md:3-13` now carries a SUPERSEDED banner naming `820060b`, `5fa6d95` and `9c39dc1`; the other 11 still have no status header |
| **Process** — round 2 rewrote reports in place, destroying r1 | flagged | **ADDRESSED ⚠️** | `docs/audits/round3/` created; r1 verified intact at `9c39dc1` — see the dedicated section |
| **L-1/L-2/L-3** README + PROJECT stale steps, broken anchor, TODOs | ⚠️ | **UNCHANGED ⚠️** | both files untouched since 2026-06-15 |
| **CONTRIBUTING** lists 3 of 5 gating CI steps | ⚠️ | **UNCHANGED ⚠️** | `CONTRIBUTING.md:31-33` = 3 steps; `ci.yml` has **8** named steps, 5 gating; still no `--dart-define` |

**Net movement: 2 regressions repaired outright, 1 repaired partially, 4 items improved,
3 got worse, 11 unchanged. Zero new blockers closed.**

---

## Round-2 repairs: adversarial review

### V-1 · `SCREEN_MAP` route table — **genuine fix, verified independently** ✅

I did not take the commit message's word for it. Extracted both sets and diffed:

```
$ grep -oE "'/[a-zA-Z0-9_/-]*'" lib/main.dart | tr -d "'" | sort -u > /tmp/code_routes_all.txt
$ wc -l < /tmp/code_routes_all.txt
53
$ grep -oE "\`/[a-z0-9/-]+\`" docs/SCREEN_MAP.md | tr -d '`' | sort -u > /tmp/doc_routes.txt
$ wc -l < /tmp/doc_routes.txt
53
$ diff /tmp/code_routes_all.txt /tmp/doc_routes.txt
(no output)
```

**Round 1's perfect-diff property is restored.** `/delete-account` is present at
`docs/SCREEN_MAP.md:210` and maps to `DeleteAccountScreen`, which exists at
`lib/screens/settings/delete_account_screen.dart:44`. `/services` at `:209` now reads
`-> root tab 2 (redirect)`, matching `lib/main.dart:568-571`. Both R-1 and R-3 are closed,
and this is the single best result of the round.

**But the same file's *navigation* block was not fixed** — see V-3. The route table is one
section; the header, the tab tree, the `:15` prose and three section headings are another,
and only the route table was brought current.

### V-2 · The dead "never show manpower prices" rule — **full recount**

**Doc side: 4 of 9 fixed. The four that were fixed were fixed properly, not cosmetically.**

The replacement text is substantive and matches `CLAUDE.md:23-32` and `docs/BUSINESS_RULES.md:9`:

| File:line | R2 text | Now | Verdict |
|---|---|---|---|
| `docs/API_REFERENCE.md:385` | "Prices are hidden (null) for manpower services where `hide_price = true`." | "**Manpower prices ARE returned and are directly bookable** … the old `hide_price` / 'never show' behaviour is DEAD" | **FIXED ✅** |
| `docs/DATABASE_SCHEMA.md:148` | "NULL = hide price (manpower)" | "NULL = no price yet -> quote-pending" | **FIXED ✅** |
| `docs/DATABASE_SCHEMA.md:155` | "DEFAULT FALSE -- Never show price to user" | "DEAD COLUMN -- ignored by the client since 2026-06" | **FIXED ✅** |
| `docs/DATABASE_SCHEMA.md:162` | "When `hide_price = TRUE`… applies to caretaker, nursing, japa, and nanny" | "**Business rule (current):** manpower prices **ARE shown and directly bookable**…" | **FIXED ✅** |

**Still asserting the dead rule as current — 5 lines, 3 files, verbatim since round 1:**

| File:line | Text |
|---|---|
| `SCREENS_IMPLEMENTATION.md:288` | "NEVER shows prices for manpower services (nursing, caretaker, japa, nanny)." |
| `docs/services-tab.md:74` | "**Manpower** (all `bookingType: 'assessment'`, no prices shown):" |
| `docs/services-tab.md:154` | "**Never show prices for manpower services** (nurse, caretaker, japa, nanny) — users reject without speaking to sales" |
| `docs/services-tab.md:386` | same + "Physio is the exception (prices shown: 900/1200/1500)." |
| `docs/my-care-tab.md:197` | "**Never show prices for manpower services** (caretaker, nursing, japa, nanny)" |

All three files are still undated, still carry no superseded banner, and are still frozen at
**2026-03-21** (`git log -1 --format=%cd`). These are also the three files that re-import
japa/nanny as Housepital offerings, which `CLAUDE.md:38` says they are not.

Legitimately historical, **do not touch**: `docs/BUILD_LOG.md:311`, `docs/CHANGELOG.md:35,447,714`.
Correct and mutually consistent: `CLAUDE.md:23-32`, `docs/BUSINESS_RULES.md:7-11`, `README.md:416`,
`docs/SCREEN_MAP.md:65`, `docs/FEATURE_TRACKER.md:121`, `lib/screens/services/data/catalog_seeds.dart:11`.

**Code/test side: 1 of 7 fixed. One new site found that round 2 missed.**

The one fix is excellent and is the opposite of a surface — `0f2729e` did not just rename the
test, it left a nine-line comment explaining what the assertion actually proves
(`test/screens/services/staff_role_sheet_test.dart:168-176`), so the name cannot silently drift
back. That is the standard the other six should be held to.

| # | File:line | Text | Status |
|---|---|---|---|
| 1 | `lib/screens/assistant/assistant_local_actions.dart:21` | "Business rule: manpower prices are NEVER shown" | ❌ verbatim |
| 2 | `lib/screens/my_care/widgets/doctor_advice_card.dart:8` | "never show prices (hard business rule)" | ❌ verbatim |
| 3 | `lib/services/invoice_pdf_service.dart:10` | "manpower prices are never displayed before the confirmation call" | ❌ verbatim |
| 4 | `lib/services/handover_report_service.dart:14` | "manpower prices are never displayed in any case" | ❌ verbatim |
| 5 | `test/screens/orders/quote_pending_surfaces_test.dart:5` | "Manpower prices are never…" | ❌ verbatim |
| 6 | `test/screens/assistant/assistant_executor_test.dart:476` | `expect(order['totalAmount'], 0); // manpower rule: no price, ever` | ❌ verbatim |
| 7 | `test/screens/services/staff_role_sheet_test.dart:168` | was `'sheet shows no prices for manpower'` | **FIXED ✅** → `'tier sheet carries tasks only — price stays on the card'` |
| **8** | `lib/screens/assistant/assistant_executor.dart:377` | "quote-first booking flow creates. **No price is ever shown (manpower rule).**" | ❌ **NEW — missed by round 2** |

Site 8 is in shipped `lib/` code, not a test, and it is worse than the comments: it attaches
the dead rule to the assistant's booking path, which is the same subsystem as site 1 and site 6.
Rounds 1 and 2 both under-counted; the true figure is **8 code/test sites, 7 remaining**.

Not the dead rule — correctly describing the *live* quote-pending rule, leave them alone:
`lib/screens/services/service_booking_screen.dart:589`, `lib/screens/services/cards/diagnostic_card.dart:84`.

### V-3 · Six tabs — **3 of 17 rows fixed; the SCREEN_MAP fix is the self-contradiction described in the headline**

Fixed: `docs/SCREEN_MAP.md:6` (token only), `docs/ARCHITECTURE.md:68` (token only, but the
sentence around it is now false for a different reason — see V-7), and
`docs/FEATURE_TRACKER.md:143`, which is the **only** properly rewritten one:

> `| 0 | Care Calendar entry point | MyCareScreen app bar | -- | Done (2026-08-03) | Owner moved
> the calendar OUT of the bottom nav ('five icons below'): tabs are Home (0) / My Care (1) /
> Services (2) / Billing (3) / More (4) … Side effect: home_screen's 'Pay Now' … call
> switchToTab(3) and land on Billing again — they had been silently opening the Calendar tab. |`

That row records the *reason* and the *side effect*, which is what a tracker is for.

**Still asserting six tabs / a Calendar root tab — 14 rows:**

| File:line | Claim | First flagged |
|---|---|---|
| `README.md:44` | "**6 bottom tabs** (Home, My Care, Services, Calendar, Billing, More)" | r1 |
| `README.md:278` | "### Tab 4 — Calendar (root tab)" (section `:278-284`) | r1 |
| `README.md:279` | "Care Calendar is a root bottom-tab (index 3, between Services and Billing)" | r1 |
| `README.md:285` | "### Tab 6 — More (Settings)" — More is index 4 | r2 |
| `PROJECT.md:4` | "six field-feedback rounds (3–6) shipped: fixed solid-orange nav bar, **Calendar root tab**" | r1 |
| `docs/ARCHITECTURE.md:207-208` | "**Six root** tabs (Calendar added at index 3 — indices 1/2 referenced externally)" | r1 |
| `docs/SCREEN_MAP.md:10` | "\|-- [3] Calendar -> CareCalendarScreen" | r1 |
| `docs/SCREEN_MAP.md:11` | "\|-- [4] Billing" — now index 3 | r2 |
| `docs/SCREEN_MAP.md:12` | "\|-- [5] More" — now index 4 | r2 |
| `docs/SCREEN_MAP.md:15` | "**Calendar was added as a root tab at index 3** (field round 4-5)" | r1 |
| `docs/SCREEN_MAP.md:73` | "### CALENDAR TAB (Index 3)" section (`:73-77`) | r1 |
| `docs/SCREEN_MAP.md:81` | "### BILLING TAB (Index 4)" — now 3 | r2 |
| `docs/TEST_MAP.md:32` | "+fixed-nav shell contract, **calendar root tab**, …" | r2 |
| `SCREENS_IMPLEMENTATION.md` | undated, `:717` "Tab 1 or Home banner" — index scheme predates both nav changes | r3 |

*(`docs/SCREEN_MAP.md:133` "### MORE TAB (Index 4)" was wrong in round 2 and is now
**accidentally correct** — More really is index 4 today. It was not edited; the code moved
under it.)*

Ground truth re-verified: `lib/screens/main_shell.dart:37-43` — five screens, in order
Home / MyCare / ServiceCatalog / Billing / Settings; `grep -c BottomNavigationBarItem
lib/screens/main_shell.dart` → **5**; `lib/screens/main_shell.dart:31-36` carries the
"FIVE tabs" comment and the do-not-reorder warning.

`docs/CHANGELOG.md:56-64` is a dated historical entry — **leave it.**

### V-4 · `DEPLOYMENT_GUIDE` storage rules — **partial, and it missed both places the finding named** ⚠️

`0f2729e` added exactly one line:

```
$ git show 0f2729e -- docs/DEPLOYMENT_GUIDE.md | grep -E "^\+" | grep -v '^+++'
+firebase deploy --only storage          # storage.rules — chat + concern photos
```

It landed at `docs/DEPLOYMENT_GUIDE.md:47`, inside **§1.2, whose heading is "Firestore Security
Rules"** — a one-time initial-setup section. R-2 named two other locations, and neither got it:

- **§7a step 3 "Deploy the hardened firestore.rules" (`:386-395`)** — the pre-launch hardening
  block. Still `firebase deploy --only firestore:rules --project housepital-patient` alone,
  followed by `firebase firestore:rules get` to verify. No storage equivalent, no storage verify.
- **§8 Post-Deployment Checklist (`:441-450`)** — has
  `- [ ] **Firestore security rules deployed AND verified in console** (Section 7a step 3)`.
  **There is no storage-rules checkbox.**

So: someone doing a *fresh* Firebase setup now deploys storage rules; someone cutting a
*release* — following the pre-launch hardening section and ticking the post-deploy checklist,
which is the actual release path — still ships without them, and the checklist gives them a
green tick that says rules are deployed and verified. **R-2's impact statement still holds.**
Additionally, filing a storage command under a heading that reads "Firestore Security Rules"
means a reader scanning headings for "Storage" finds nothing.

### V-5 · What `0f2729e` did *not* touch, with the git evidence

```
$ for f in <live docs>; do printf "%-38s %s\n" $f "$(git log -1 --format=%cd --date=short -- $f)"; done
CLAUDE.md                              2026-08-04   ← tracks the code
docs/ARCHITECTURE.md                   2026-08-04
docs/SCREEN_MAP.md                     2026-08-04
docs/FEATURE_TRACKER.md                2026-08-04
docs/API_REFERENCE.md                  2026-08-04
docs/DATABASE_SCHEMA.md                2026-08-04
docs/DEPLOYMENT_GUIDE.md               2026-08-04
README.md                              2026-06-15   ← subject changed 3× since
PROJECT.md                             2026-06-15
docs/TEST_MAP.md                       2026-06-15   ← 2 new test files since
docs/CHANGELOG.md                      2026-06-15
docs/BUSINESS_RULES.md                 2026-06-15
docs/KNOWN_ISSUES.md                   2026-06-11
CONTRIBUTING.md                        2026-05-28
docs/ENVIRONMENT_SETUP.md              2026-05-28
ARCHITECTURE.md (root stub)            2026-05-28
docs/TROUBLESHOOTING.md                2026-03-25
docs/BUILD_LOG.md                      2026-03-25
docs/TEST_STRATEGY.md                  2026-03-24
SCREENS_IMPLEMENTATION.md              2026-03-21
docs/services-tab.md                   2026-03-21
docs/my-care-tab.md                    2026-03-21
```

**`README.md` is the acute case.** It is the checklist's `[R]` front door, it is stale on every
count round 2 listed, and its nav description is now wrong *twice over* — six tabs **and** an
orange bar:

- `:42` "149 Dart source files | ~53,800 lines" — actual **154** files / **55,591** lines.
- `:43` "99 test files | ~1,771 tests" — actual **101** files; the brief's central run reports **1,813**.
- `:44` "6 bottom tabs (… Calendar …) — **fixed solid-orange nav bar**" — five tabs, floating glass pill.
- `:45` "52 named routes" — actual **53**.
- `:166` "services/ # catalog (6 tabs)" — the catalog has **7** sub-tabs (`service_catalog_screen.dart:65` `TabController(length: 7)`).
- `:209` "86 test files, 1,550+ tests" — contradicts `:43` in the same file.
- `:210,:362,:389,:409` "37 screens × 3 widths" — actual **41**.
- `:334-335` "**Fixed full-width solid-orange bottom nav bar** … owner iterated floating-glass → pill → fixed" — reversed by `d439928`.
- `:428` "AppProvider uses `_loadMockData()`" — `grep -rn _loadMockData lib/` → still nothing.

**`docs/TEST_MAP.md` got worse without being touched.** Two test files landed since round 2
(`git diff --name-status 820060b HEAD -- test/` → `A test/services/store_migrator_test.dart`,
plus modifications to `patient_scope_isolation_test.dart`, `main_shell_test.dart`,
`staff_role_sheet_test.dart`). Disk is now **101** `*_test.dart` files against the doc's
**99** (`:6`), and its "complete inventory" at `:156` still lists **86**. `grep -c
patient_scope_isolation docs/TEST_MAP.md` → **0**: the PHI regression guard and the new
`store_migrator_test.dart` are both invisible to the test map.

### V-6 · The five new artifacts — **ARCHITECTURE only; TEST_MAP and FEATURE_TRACKER untouched** ⚠️

The new section (`docs/ARCHITECTURE.md:373-394`) is **the best documentation added to this repo
in the audit's lifetime, and I could not find an inaccuracy in it.** Every claim checks out:

- "`session_scope.dart` … the single list of everything scoped to ONE patient" and the standing
  instruction "**When anything gains patient-scoped state … add it here in the same edit and
  assert it in `test/providers/patient_scope_isolation_test.dart`**" — this lifts round 2's
  highest-consequence gap (D-1) directly into the doc a new contributor reads for state flow.
  It even records that "the first version of this file was written from a symptom list and
  missed five stores", which is exactly the failure round 2 caught.
- "`demo_mode.dart` … A set of named sources, not a bool: a single global flag let one
  provider's recovery take the warning down while others still served samples" — matches
  `lib/data/demo_mode.dart`.
- "`store_migrator.dart` … Runs in `main()` **before** the providers are constructed, because
  they read storage in their constructors. Never throws" — matches `lib/main.dart:174`.
- "`storage.rules` … the client never reads a Firebase uid, so `request.auth.uid == patientId`
  is always false and would deny every upload" — matches the brief's own account.

**Coverage across the four docs D-1 named:**

| Artifact | SCREEN_MAP | ARCHITECTURE | TEST_MAP | FEATURE_TRACKER |
|---|---|---|---|---|
| `lib/utils/session_scope.dart` | n/a | ✅ `:379` | ❌ | ❌ |
| `lib/data/demo_mode.dart` | n/a | ✅ `:381` | ❌ | ❌ |
| `lib/widgets/demo_data_banner.dart` | n/a | ⚠️ `:382` — **now describes removed behaviour**, see V-7 | ❌ | ❌ |
| `lib/services/store_migrator.dart` | n/a | ✅ `:383` | ❌ (`store_migrator_test.dart` absent) | ❌ |
| `delete_account_screen.dart` / `/delete-account` | ✅ `:210` | ✅ `:385-390` | n/a | ❌ |
| `storage.rules` | n/a | ✅ `:392-394` | n/a | ❌ |

```
$ for t in "delete account" "account deletion" "session scope" "patient scop" "demo mode" \
           "sample data" "storage rules" "migrat" "store migrator"; do
    printf "%-20s %s\n" "$t" "$(grep -ci "$t" docs/FEATURE_TRACKER.md)"; done
delete account       0
account deletion     0
session scope        0
patient scop         0
demo mode            0
sample data          0
storage rules        0
migrat               0
store migrator       0
```

`FEATURE_TRACKER.md` was edited by `0f2729e` — **one row** — and is still blind to every
feature `820060b` shipped. Account deletion is the App Store 5.1.1(v) gate and a DPDP §12
obligation; the document a release manager opens before submission does not know it exists.

### V-7 · **NEW REGRESSION** — `ARCHITECTURE.md:382` documents behaviour that was deleted 43 minutes later ❌

`0f2729e` wrote, at `docs/ARCHITECTURE.md:382`:

> `lib/widgets/demo_data_banner.dart` | Renders that state on EVERY route | Installed from
> `MaterialApp.builder`, above the Navigator … **It owns the status-bar inset and removes it
> from the child.**

The code as of `9a80fe2` says the opposite, in its own class doc comment
(`lib/widgets/demo_data_banner.dart:10-27`):

> "TWO EARLIER SHAPES, BOTH WRONG — don't go back to either: … 2. **A full-width strip in a
> Column above the app: it consumed the status bar, pushed every glass app bar down** …
> So it is an **OVERLAY, not a layout participant**. It floats in a Stack over the app,
> **displaces nothing, and no screen needs any inset maths.**"

`docs/ARCHITECTURE.md:382` is a verbatim description of shape 2 — the shape `d439928` removed
*because it regressed*. This is the worst class of documentation error the checklist names: a
doc that describes a **reverted design as current**, in the same table that exists to stop the
reversion. Anyone acting on it re-introduces the inset maths the code comment forbids.

A weaker instance of the same drift sits in code at `lib/main.dart:432-433` ("It handles its own
top inset; see DemoDataBannerHost") — defensible, since the pill does read `padding.top`, but it
still echoes the removed contract.

**Only `CLAUDE.md:60-66` is correct**, and it is correct to the line — verified against
`lib/widgets/demo_data_banner.dart:38-53` (Stack, `Positioned(top: padding.top + kToolbarHeight + 4)`)
and `lib/main.dart:434` (`DemoDataBannerHost(child: child!)` inside `MaterialApp.builder`).

### V-8 · **NEW REGRESSION** — every doc but `CLAUDE.md` still describes a fixed orange nav bar ❌

`d439928` → `9a80fe2` reversed field round 5's fixed orange bar back to a floating liquid-glass
pill. Eight live doc statements are now wrong, three of which `0f2729e` edited *without*
correcting the description sitting in the same string:

| File:line | Text | Note |
|---|---|---|
| `README.md:44` | "— fixed solid-orange nav bar" | untouched |
| `README.md:334-335` | "**Fixed full-width solid-orange bottom nav bar** (`MainShell`), white icons/labels, SafeArea-padded — owner iterated floating-glass → pill → fixed" | untouched |
| `PROJECT.md:4` | "fixed solid-orange nav bar" | untouched |
| `docs/ARCHITECTURE.md:68` | "# **Fixed solid-orange bottom nav bar** (5 tabs: …)" | **`0f2729e` edited this exact line** — corrected `6 tabs`→`5 tabs`, left `Fixed solid-orange` |
| `docs/ARCHITECTURE.md:206-207` | "**FIXED full-width solid-orange bar**, white icons, SafeArea-padded (owner iterated floating-glass → pill → fixed)" | untouched; also still says "Six root tabs" |
| `docs/SCREEN_MAP.md:6` | "(MainShell -- 5 tabs, **FIXED full-width solid-orange bar**)" | **`0f2729e` edited this exact line** — same pattern |
| `docs/SCREEN_MAP.md:17` | "**Nav bar:** FIXED full-width solid-orange bar anchored to the bottom edge …" | untouched |
| `docs/FEATURE_TRACKER.md:252` | "20a\| **Fixed solid-orange bottom nav bar** \| Done (2026-06-11) \|" | a "Done" row for a design that has since been reversed; needs a superseded note, not deletion |

Ground truth (`lib/screens/main_shell.dart:94-140`): `GlassSurface(borderRadius: 32, sigma: 36,
opacity: 0.78)`, warm orange drop shadow `alpha: 0.18`, warm tint `orangeLight alpha 0.22`,
`backgroundColor: Colors.transparent`, `elevation: 0`, inside `Scaffold(extendBody: true)` at
`:54-57` with the pill in the `bottomNavigationBar` slot at `:77`.

`docs/CHANGELOG.md:56,59,82,88` are dated historical entries — **legitimate, leave them.**

### V-9 · `orangeStrong` and `onError` are documented **nowhere** except `CLAUDE.md` ❌

```
$ grep -rn "orangeStrong\|onError" --include="*.md" . | grep -v docs/audits/
CLAUDE.md:95:  glide underneath. Selected item uses `orangeStrong` (5.38:1), not `orangeText`
```

One hit for `orangeStrong`. **Zero for `onError`, anywhere in any `.md`.** Both are live
`HcPalette` fields (`lib/config/app_colors.dart:56` `onError`, `:64` `orangeStrong`) with
per-brightness values (`theme.dart:53,100` and `:55,103`).

The three places that carry the token contract all now under-describe the palette:

- `docs/ARCHITECTURE.md:182-197` (Theming & Dark Mode) — names `onOrange` only; no `orangeStrong`, no `onError`.
- `README.md:341` — names `onOrange` only.
- `docs/services-tab.md:300-307` — a token table listing `orange/orangeLight/orangeText`,
  frozen at 2026-03-21, missing both new tokens *and* `orangeDark`, `onOrange`, `sos`,
  `checkedIn`, `vitalNormal/Borderline/Alert`.

This is exactly the checklist §4 drift test — *"the in-repo tokens match the doc (no drift)"* —
and the answer is now no. It also has a testing consequence:
`grep -n "orangeStrong\|onError" test/widgets/dark_mode_test.dart` → **empty**, so the
dark-mode token guard does not cover either new token. A doc entry is the only thing that
would have caught that.

**Related, and the more serious half:** `lib/config/app_colors.dart:67-68` still carries this
doc comment on `onOrange`:

> `// Text/icons ON an orange fill. White on orange fails AA (~2.3:1), so both modes use the`
> `// same dark ink (6.3:1 on orange).`

`onOrange` is `Color(0xFFFFFFFF)` in **both** palettes (`theme.dart:32` light, `:78` dark).
The comment describes the *pre-owner-decision* dark-ink value and states the reverse of what
ships. This is the single most dangerous stale comment in the repo for this project, because it
reads as a standing engineering justification for reverting a decision the owner has made
durably (`CLAUDE.md:71`, `docs/FEATURE_TRACKER.md:254`). **Reported as a documentation defect —
the token value is correct and must not change; the comment is what is wrong.**

---

## Is the round-3 directory adequate? Is round 1 at `9c39dc1` acceptable?

The checklist's §5 bar is: *"point-in-time records — date them, don't rewrite."*

**Verified state of the record:**

```
$ git ls-tree -r --name-only 9c39dc1 -- docs/audits/    # → all 12 round-1 reports present
$ git show 9c39dc1:docs/audits/DOCUMENTATION_AUDIT.md | wc -l
425
$ git show 9c39dc1:docs/audits/DOCUMENTATION_AUDIT.md | head -1
# Documentation Checklist — Audit vs commit 803124d
$ head -1 docs/audits/DOCUMENTATION_AUDIT.md
# Documentation Checklist — Audit round 2 vs commit `820060b`
$ grep -ln "9c39dc1" docs/audits/*.md
docs/audits/AUDIT_SYNTHESIS.md
docs/audits/DOCUMENTATION_AUDIT.md
docs/audits/RELEASE_SUBMISSION_AUDIT.md
```

**Round 1 is fully intact and byte-recoverable.** Nothing was lost. All 12 files, complete.
`AUDIT_SYNTHESIS.md:3-13` now carries an honest banner that names the problem in the first
person — *"The individual reports in this directory have been rewritten in place for round 2 —
round 1's graded versions are recoverable at commit `9c39dc1`."* That is the correct disclosure
and it is more than most projects would write.

**Verdict on the directory: ⚠️ adequate going forward, not yet adequate as a record.**

Writing round 3 to `docs/audits/round3/` **does** satisfy "don't rewrite" prospectively — round
2's twelve reports will survive this round intact, which is the first time that will be true.
Three things stop it short of ✅:

1. **The layout is asymmetric and will mislead.** After this round the tree reads:
   `docs/audits/*.md` = round **2**; `docs/audits/round3/*.md` = round **3**; round 1 = not on
   disk at all. A reader who opens `docs/audits/DOCUMENTATION_AUDIT.md` gets the *older* of the
   two on-disk reports, in the *more prominent* location. The natural reading — top level is
   current, subdirectory is archive — is backwards. Round 4 writing to `round4/` makes it worse,
   not better.
2. **Round 1 exists only as a git object.** `git show 9c39dc1:docs/audits/…` recovers it, but it
   is absent from any checkout, invisible to file search, invisible to anyone browsing the repo
   on a phone or in a web UI without knowing the SHA. The checklist asks for point-in-time
   *records*; a record that requires knowing an eight-character SHA is a backup, not a record.
   Nine of the twelve round-2 files do not mention `9c39dc1` at all, so a reader of
   `SECURITY_PRIVACY_AUDIT.md` or `TESTING_AUDIT.md` has no in-file path to the graded round-1
   version of that same report.
3. **Ten of the twelve round-2 reports still carry no resolution status** (H-5, unchanged). Only
   `AUDIT_SYNTHESIS.md` gained a banner.

**Is `9c39dc1`-only acceptable?** For *this* project, at *this* moment — yes, narrowly: nothing
is lost, the loss was disclosed rather than hidden, and the branch is intact and unpushed. It
stops being acceptable the moment anyone rebases, squashes or force-pushes `fix/five-tab-nav`,
because the sole copy of round 1 is a dangling blob under a commit no branch points at except
through history. It is one `git rebase -i` away from the destruction the round-2 brief nearly
caused.

**Recommended (cheap, ~10 minutes, no rewriting):**
`git checkout 9c39dc1 -- docs/audits/ && mkdir docs/audits/round1 && mv …` to materialise
round 1 as files, then `round2/` likewise, leaving `docs/audits/` holding only
`AUDIT_SYNTHESIS.md` and an `INDEX.md` naming which round is current. Every round then has a
symmetric on-disk home and the current one is not the hardest to find.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Project meta | 2 | 4 | 0 | 0 |
| 2. Living technical docs | 0 | 4 | 0 | 0 |
| 3. Product / UX | 0 | 2 | 4 | 0 |
| 4. Brand / design | 0 | 2 | 1 | 0 |
| 5. Quality & audits | 1 | 3 | 1 | 0 |
| 6. Compliance & ship | 0 | 1 | 4 | 0 |
| 7. Per-feature docs | 0 | 3 | 0 | 0 |
| 8. Ops / infra | 0 | 2 | 1 | 0 |
| **TOTAL (35 items)** | **3** | **21** | **11** | **0** |

*(Round 1: 3 / 16 / 16. Round 2: 3 / 18 / 14. Round 3: 3 / 21 / 11.)*

Three items moved ❌→⚠️: **ARCHITECTURE.md** (the new artifacts section is real work),
**SCREEN_MAP.md** (route table clean-diff restored), and **§7 "Living docs updated when a
feature lands"** (`0f2729e` is the first commit in this repo's history to do it at all).
**Nothing reached ✅. The ✅ column has not moved in three rounds.**

---

## Findings

### Blockers

**B-1 · No `PRIVACY_POLICY.md`, no `DATA_HANDLING.md`.** `[R]` × 2, both hard store gates,
unchanged across three rounds. `/delete-account` now ships (`lib/main.dart:745-747`) and is a
DPDP §12 erasure path with no policy text behind it; `lib/data/demo_mode.dart` is a formal
admission that the app may render another patient's sample record, which a data-safety label
must answer for. The app links to `https://housepital.in/privacy`
(`lib/screens/settings/about_screen.dart:103-104`) — **BLOCKED-OWNER** on whether it resolves.

**B-2 · No `QA_CHECKLIST.md`.** `[R]`, unchanged. Since round 2 the untested-by-hand surface has
*grown*: `StoreMigrator` (runs on every cold start before any provider reads storage), the
`SessionScope` clear-on-switch path, `/delete-account`, the `_pendingVerification` payment
state, **and now a third nav shape and a second demo-notice shape in one week**. Not one
recorded manual on-device pass exists for any of them.

**B-3 · The dead "never show manpower prices" rule survives in 5 doc lines and 7 code/test
sites.** Full recount at V-2. The doc side moved 0→4 fixed; the code side moved 0→1 with a new
eighth site found in shipped `lib/` code (`assistant_executor.dart:377`). Three files
(`SCREENS_IMPLEMENTATION.md`, `docs/services-tab.md`, `docs/my-care-tab.md`) still state the
dead rule *and* re-import japa/nanny as Housepital offerings, contradicting `CLAUDE.md:38`.

### High

**H-1 · REGRESSION — `docs/ARCHITECTURE.md:382` documents the reverted demo-banner shape as
current.** V-7. Written 43 minutes before `d439928` deleted the behaviour it describes; the
code's own comment names that shape as one of "TWO EARLIER SHAPES, BOTH WRONG". **Fix:** replace
the last sentence with "It is a Stack overlay and displaces nothing; adding or removing it must
not change any screen's layout."

**H-2 · REGRESSION — eight live doc statements describe a fixed orange nav bar that no longer
exists.** V-8. Two of them are lines `0f2729e` edited without noticing the adjacent claim.
**Fix:** one search-replace across `README.md:44,334-335`, `PROJECT.md:4`,
`docs/ARCHITECTURE.md:68,206-207`, `docs/SCREEN_MAP.md:6,17`; add a superseded note to
`docs/FEATURE_TRACKER.md:252`.

**H-3 · `docs/SCREEN_MAP.md` now contradicts itself about the tab count.** V-3. `:6` says five
tabs; `:7-12` lists six; `:15`, `:73`, `:81` elaborate on the six-tab scheme. **Fix:** delete
rows `:10-12`'s Calendar entry and renumber, rewrite `:15`, delete the `### CALENDAR TAB
(Index 3)` section `:73-77`, retitle `:81` to Index 3.

**H-4 · `docs/TEST_MAP.md` untouched while its subject moved twice.** V-5. 99 vs **101** files;
`~1,771` vs the brief's **1,813**; inventory 86 of 101; `patient_scope_isolation_test.dart` and
`store_migrator_test.dart` — the regression guards for the PHI blocker and the storage-schema
blocker — both absent. `git log -1 --format=%cd -- docs/TEST_MAP.md` → **2026-06-15**.

**H-5 · `docs/FEATURE_TRACKER.md` remains blind to everything `820060b` shipped.** V-6. One row
edited; nine keyword greps return zero. Account deletion is an App Store gate and belongs in
the document a release manager reads.

**H-6 · `README.md` — the `[R]` front door — is stale on nine counts and untouched.** V-5. It
now misstates file count, LOC, test-file count, test count (twice, contradicting itself), route
count, tab count, tab *names*, sub-tab count, overflow-screen count, and the nav design.

**H-7 · `docs/ARCHITECTURE.md` still says ten providers where it matters.** `:17` was corrected
to 11 ✅, but `:348` still reads "**Ten** `ChangeNotifierProvider` instances initialized in
`main.dart`:" above a table (`:350-361`) that lists ten and omits `RemindersProvider`.
`grep -c ChangeNotifierProvider lib/main.dart` → **11**; `RemindersProvider` at `lib/main.dart:217`.
The number a reader trusts is the one over the list, and that one is still wrong.

**H-8 · `docs/DEPLOYMENT_GUIDE.md` still ships a release without storage rules.** V-4. The
storage deploy went into initial setup; the pre-launch hardening block (`:386-395`) and the
post-deploy checklist (`:441-450`) are unchanged, and the checklist's Firestore-rules tick
gives false assurance.

**H-9 · `orangeStrong` and `onError` appear in no document, and `onOrange`'s in-code comment
states the reverse of its value.** V-9. Checklist §4's no-drift test fails. The stale
`app_colors.dart:67-68` comment is the more urgent half — it reads as a rationale for undoing
a durable owner decision.

**H-10 · The known nav-pill occlusion is in no issues log.** The brief records it as "known and
unfixed": on screens whose content starts under the app bar (Settings), the demo pill occludes
content. `grep -rn -iE "occlud|occlus|covers content"` across all non-audit `.md` → **zero
hits**, and `docs/KNOWN_ISSUES.md` — the file that exists for exactly this — has no entry
(`:5` still self-dates "2026-05-28" while git says 2026-06-11). A known-and-accepted defect
that is written down nowhere becomes an unknown defect at the next handover.

### Medium / Low

- **M-1 · "37 screens × 3 widths" is now four short, stale in 8 places.** `overflow_smoke_test.dart`:
  21 `noArg(` + 15 `argScreen(` + 5 explicit `testWidgets` (7 total, 2 inside the helpers) =
  **41** screens × 3 widths = **123** tests. Stale at `CLAUDE.md:13`, `README.md:210,362,389,409`
  (`:409` also claims 111), `docs/TEST_MAP.md:4,119,208`, `docs/FEATURE_TRACKER.md:260`.
  (`docs/CHANGELOG.md:201` is historical — leave it.)
- **M-2 · `docs/CHANGELOG.md` newest entry is still `## [2026-06-13]`** (`:7`). Undocumented:
  the five-tab change, all ten blocker fixes, all of `5fa6d95`'s repairs, account deletion, and
  three nav iterations. For a `[+]` user-facing changelog on an app about to submit, account
  deletion alone is a required entry.
- **M-3 · `PROJECT.md` (the STATE.md substitute) is unchanged and now three commits further
  behind.** `:4` Calendar root tab + orange bar, `:86` vs `:92` self-contradiction, `:98` "In
  flight: PRs #10/#11/#12", `:101` Crashlytics as a TODO while `docs/FEATURE_TRACKER.md:239,241`
  marks it Done, `:105` coverage gate as TODO while `ci.yml:66` enforces it, `:31` broken
  `#-tech-stack` anchor, `:22,:68` unresolved TODOs.
- **M-4 · `CONTRIBUTING.md:31-33` still lists 3 CI steps.** `.github/workflows/ci.yml` has
  **8** named steps (`:25,33,40,54,66,84,101,105`), 5 gating; the doc omits *Design consistency*
  (`:40`) and the *Coverage gate* (`:66`), and its `flutter test` still lacks
  `--dart-define=RAZORPAY_KEY=rzp_test_ci_dummy_key`, so copy-pasting it silently skips the
  payment groups.
- **M-5 · `docs/ENVIRONMENT_SETUP.md` (2026-05-28) has no Firebase Storage step and no
  `dart-define`.** `grep -c dart-define docs/ENVIRONMENT_SETUP.md` → **0**. A fresh machine set
  up from it gets a configuration that does not match `firebase.json`.
- **M-6 · `docs/DATABASE_SCHEMA.md` documents the server schema well and the *client* schema not
  at all.** `StoreMigrator` versions 13 SharedPreferences namespaces (`lib/main.dart:174`); no
  data doc records the namespace list or the version contract, though `ARCHITECTURE.md:383` now
  at least says it exists.
- **M-7 · `SCREENS_IMPLEMENTATION.md`** — undated, 2026-03-21, `:5` "Total Screens: 33" against
  **91** Dart files under `lib/screens/`, carries the dead pricing rule (`:288`), and `:717`
  uses the pre-Calendar tab-index scheme.
- **M-8 · Three Flutter versions** — `README.md:26` 3.16+, `PROJECT.md:29` 3.41+, `ci.yml:22`
  pinned 3.41.2. Unchanged.
- **M-9 · `docs/KNOWN_ISSUES.md:5` misstates its own date** (2026-05-28 vs git 2026-06-11), and
  has no entry newer than that despite three rounds of shipped fixes.
- **L-1 · `README.md:425-434` "Remaining Steps for Production"** references `_loadMockData`
  (0 hits in `lib/`) and asks for tests that have existed for months.
- **L-2 · `docs/my-care-tab.md`, `docs/services-tab.md`, `SCREENS_IMPLEMENTATION.md` carry no
  date and no status banner** — the property that makes `docs/VISUAL_CONSISTENCY_AUDIT.md:3-15`
  trustworthy and these three not.
- **L-3 · Root `ARCHITECTURE.md` stub is correct** (`:1-8`) but `PROJECT.md:81,90` still flags
  the duplication as open.

### BLOCKED-OWNER

- **Whether `storage.rules` has been deployed.** Unchanged from round 2 and now more urgent,
  because `DEPLOYMENT_GUIDE`'s post-deploy checklist gives a green tick for rules being
  "deployed AND verified" while covering only Firestore. *Needed:* output of
  `firebase storage:rules get --project housepital-patient`, or console screenshot.
- **Liveness and content of `https://housepital.in/privacy` and `/terms`**
  (`about_screen.dart:97-98,103-104`). *Needed:* confirmation both resolve and whether either
  mentions account deletion / DPDP §12 erasure.
- **App Store Connect / Play Console privacy-label answers** — whether any are filled.
  Determines whether `DATA_HANDLING.md` is transcription or authoring.
- **Whether the brand guidelines PDF exists outside the repo** (`PROJECT.md:22` TODO).
- **CI green/red and current coverage %** — `ci.yml:66-79` enforces 50%; I was instructed not to
  run the suite and cannot read GitHub Actions.
- **Is the nav-pill occlusion on Settings owner-accepted or owner-unaware?** Determines whether
  H-10's fix is a `KNOWN_ISSUES.md` entry or a bug ticket.

---

## What is genuinely good (so it doesn't get lost)

- **`docs/ARCHITECTURE.md:373-394` is the best thing in this repo's documentation.** It does the
  thing every other doc fails to do: it records *why*, not just *what* — "The first version of
  this file was written from a symptom list and missed five stores"; "Free to fix before the
  first public release, effectively impossible after". I tried to break it and could not. It
  also propagates the `session_scope` standing instruction to the audience that needs it.
- **`CLAUDE.md` remains the only doc that tracks the code, now for the third round running, and
  the `d439928` edit is accurate to the line** — the pill geometry, `orangeStrong`'s 5.38:1 and
  *why* the white-on-orange rule does not govern glass, the `extendBody`/`bottomNavigationBar`-slot
  answer to round 5's objection, and the demo-notice overlay contract with both failed shapes
  named. Every clause verified against `main_shell.dart:54-140` and `demo_data_banner.dart:10-53`.
- **The `staff_role_sheet_test` rename is the model repair of this round.** It did not just
  change a string — it left nine lines explaining what the assertion actually proves, so the
  name cannot drift back. If the other seven dead-rule sites are fixed this way, B-3 closes for good.
- **The `DATABASE_SCHEMA` / `API_REFERENCE` pricing fixes are substantive, not cosmetic.** They
  replaced the dead rule with the live one *and* explained that `hide_price` is a dead column
  the client ignores — which prevents the next reader from resurrecting it from the schema.
- **`AUDIT_SYNTHESIS.md:3-13`'s superseded banner is honest about a process failure the author
  caused**, names the recovery commit, and tells the reader to treat the blocker table as
  history. That is a harder thing to write than a fix.
- **The code is still better documented than the project.** `demo_data_banner.dart:10-27`,
  `session_scope.dart`, `store_migrator.dart` and `main_shell.dart:60-100` all carry
  reasoned "don't go back to this" comments. Every doc-side fix in this report is available
  by copying from the code beside it.

---

## Executive summary

1. **Round-3 counts: 3 ✅ / 21 ⚠️ / 11 ❌ of 35** (r1 3/16/16 → r2 3/18/14 → r3 3/21/11). Three
   items moved ❌→⚠️; the ✅ column has not moved in three rounds.
2. **Genuinely fixed:** `SCREEN_MAP`'s route table — I re-derived both sets and the diff is
   **empty**, 53 vs 53, `/delete-account` present, `/services` no longer a placeholder. Round 1's
   best-verified property is restored.
3. **Genuinely fixed:** the four `API_REFERENCE`/`DATABASE_SCHEMA` pricing lines, the
   `staff_role_sheet_test` rename (with a comment that prevents recurrence), and
   `ARCHITECTURE`'s new five-artifact section, which is the strongest documentation in the repo.
4. **REGRESSED — `docs/ARCHITECTURE.md:382`** now describes the demo banner as owning and
   removing the status-bar inset. `d439928`, 43 minutes later, deleted exactly that shape; the
   code names it as one of "TWO EARLIER SHAPES, BOTH WRONG". A doc that describes a reverted
   design as current is worse than one that is silent.
5. **REGRESSED — eight doc statements still describe the fixed orange nav bar.** Two are lines
   `0f2729e` edited, correcting `6 tabs`→`5 tabs` inside a string whose other half
   ("FIXED full-width solid-orange bar") was left standing.
6. **Is any round-2 repair itself a surface?** Two are token-deep. `SCREEN_MAP:6` now says
   "5 tabs" above a list of six — the file is self-contradictory where it was merely wrong.
   `ARCHITECTURE:17` says 11 providers while `:348` still says "Ten" above a ten-row table
   missing `RemindersProvider`. **`DEPLOYMENT_GUIDE` is the one that matters operationally:**
   `--only storage` went into §1.2 initial setup, not into the pre-launch hardening block or the
   post-deploy checklist that R-2 named — so a release still ships without storage rules while
   the checklist ticks "rules deployed AND verified".
7. **Recount of the dead pricing rule:** doc side **4 of 9 fixed, 5 remain**
   (`SCREENS_IMPLEMENTATION.md:288`, `services-tab.md:74,154,386`, `my-care-tab.md:197`). Code
   side **1 of 7 fixed**, plus a previously-missed eighth site in shipped code
   (`assistant_executor.dart:377`). Six-tab lines: **3 of 17 rows fixed, 14 remain.**
8. **Only `ARCHITECTURE` learned about the five new artifacts.** `TEST_MAP` (untouched since
   2026-06-15, now 101 files vs its 99) and `FEATURE_TRACKER` (one row edited; nine keyword
   greps return zero) know nothing of session scoping, demo mode, the migrator, storage rules or
   account deletion. `orangeStrong` and `onError` appear in **no** document at all, and
   `app_colors.dart:67-68` still claims `onOrange` is dark ink when it is white in both palettes.
9. **The round-3 directory is adequate prospectively, not yet as a record.** Round 1 is fully
   intact at `9c39dc1` and the loss was disclosed rather than hidden — acceptable, narrowly, and
   only until someone rebases the branch. The layout is backwards: after this round the *older*
   report sits at the prominent path and the newer one in a subdirectory. Materialise `round1/`
   and `round2/` as directories with an `INDEX.md` and it becomes a real record for ~10 minutes' work.
10. **Verdict: FAIL** — three `[R]` items (PRIVACY_POLICY, DATA_HANDLING, QA_CHECKLIST) remain
    absent for the third round, and the pattern that commissioned this audit reproduced itself
    within 43 minutes of the commit meant to end it. **Top 5 remaining:** (1) PRIVACY_POLICY +
    DATA_HANDLING; (2) QA_CHECKLIST for the now-eleven untested-by-hand runtime paths;
    (3) `ARCHITECTURE:382` + the eight orange-nav lines, and `app_colors.dart:67-68`;
    (4) `DEPLOYMENT_GUIDE`'s pre-launch and post-deploy storage steps; (5) `README.md` and
    `TEST_MAP.md`, which are nine and four counts wrong respectively and both untouched.
