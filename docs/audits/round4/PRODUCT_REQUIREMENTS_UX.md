# Product Requirements & UX Validation — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** Product Requirements & UX Validation (PRD control family)
**Scope:** source review of `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app` at
`9127713` (branch `fix/five-tab-nav`); `docs/`, `README.md`, `PROJECT.md`, `CLAUDE.md`, and
`lib/`. See **Limitations**.

---

## Applicability

**MASTER-2.01 — always required.** This is the first always-required module in the suite and
the first time it has been run against this codebase. Nothing in it is optional or scaled
away: the app is a consumer health product whose users are patients under home care and
their remote family, and whose core promise is *visibility into a parent's care*.

**MASTER-1.02** requires that critical user journeys be listed and linked to requirements,
tests, monitoring and support paths. The master gate has already graded MASTER-1.02 **Fail**
(`docs/audits/round4/00_MASTER_APPLICABILITY_AND_GATE.md:38`) and delegated the production of
a candidate journey list to this module. §1 below discharges that.

---

## Prior-round status

**None.** No round-2 or round-3 report exists for this module —
`ls docs/audits/*.md docs/audits/round3/*.md` shows eleven modules, none of them Product
Requirements. This is a first look, so §2's journey traces are built from the code rather
than from prior findings. Where a prior round *did* record something in my scope
(`DOCUMENTATION_AUDIT.md:70` on the `BookingHistoryScreen` phantom) I state its current
status inline.

---

## 1. Critical user journeys — the list MASTER-1.02 asks for

### 1a. Does anything in this repo name them?

**No.** Verified by exhaustion:

| Candidate source | What it actually contains |
|---|---|
| `docs/FEATURE_TRACKER.md` | 275 lines of **features** in twelve tables (frontend widget → backend endpoint → status). No journey crosses two rows. |
| `docs/SCREEN_MAP.md` | 261 lines of **screens** (route → widget → data source → permissions). An inventory, not a path through it. |
| `docs/BUSINESS_RULES.md` | Pricing, GST, refunds, a permission matrix, and six **status state machines** (`:280-329`). These are the closest artefact — but they are object lifecycles (booking, invoice, deployment), not user journeys, and none is linked to a screen, a test, or a support path. |
| `docs/my-care-tab.md`, `docs/services-tab.md` | Developer documentation for two tabs. |
| `docs/superpowers/specs/*` | Four per-feature design specs. `2026-03-21-my-care-tab-design.md` is the only one with a `## Success Criteria` block (`:431-438`). |
| `README.md`, `PROJECT.md`, `CLAUDE.md` | Setup, stack, roadmap, design/storage contracts. |
| `docs/TEST_MAP.md` | 316 lines mapping **source file → test file**. `grep -niE "journey\|requirement\|business rule\|user story\|acceptance" docs/TEST_MAP.md` → **zero matches**. |

There is no `PERSONAS.md`, no `JOURNEYS.md`, no user-story file
(`find . -name "PERSONAS.md"` → empty; already recorded unchanged at
`docs/audits/DOCUMENTATION_AUDIT.md:203`).

**Outcome: confirms MASTER-1.02 Fail.**

### 1b. Candidate critical-journey list, derived from the code — **for owner ratification**

Derived from the five root tabs (`docs/SCREEN_MAP.md:5-12`), the 52 routes in
`lib/main.dart:440-764`, and the permission matrix at `docs/BUSINESS_RULES.md:104-126`.
"Completes today" is judged against *whether the user's intent reaches anyone at Housepital*,
not whether the screen renders.

| # | Journey | Entry point | Completes today? |
|---|---|---|---|
| **J1** | **First use** — install → sign in (phone OTP) → onboard → land on a patient | `splash_screen.dart` | **No.** Unreachable — see J1 trace in §2. |
| **J2** | **Daily reassurance** — open app → see whether staff arrived, vitals are safe, tasks were done | Home tab / My Care tab | **No.** Demo data with a latched banner — §3. |
| **J3** | **Log a medication dose** | Medications / Schedule / Calendar | **No.** RAM only — §2, Trace B. |
| **J4** | **Request or book a service** | Services tab → booking wizard / assessment | **No.** SharedPreferences only — §2, Trace A. |
| **J5** | **Pay an outstanding bill** | Billing tab → `/payment` | Simulated by default (`payment_service.dart:47-52`); by design, and honestly gated. |
| **J6** | **Rate the day / give feedback on care** | My Care rating card; daily-report dialog | **No.** §2, Trace C. |
| **J7** | **Escalate — raise a concern / request staff replacement** | `/raise-concern`, `/staff-replacement` | **Yes** — real API calls (`raise_concern_screen.dart:370`, `staff_replacement_screen.dart:187`). The only patient-initiated journey that leaves the phone. |
| **J8** | **Emergency (SOS)** | Home far-right / `/sos` | **Yes** — `tel:` dial, no gate. |
| **J9** | **Manage who can see the record** — add/remove a family member | Settings → Family Members | **No.** §2, Trace D. |
| **J10** | **Get help** — FAQ, call support, chat the coordinator | `/help-faq`, `/chat` | **Yes** (chat is real Firestore; support phone is real). |
| **J11** | **Leave** — logout / delete account / export data | Settings | **Partial.** Deletion is honest but local-only; there is no export; logout has nowhere to land. |
| **J12** | **Return after a gap** — reopen, see what changed | any tab | **Unverifiable** — no notification-driven state, no "last updated", no analytics. |

**Owner action:** ratify, amend or reject this list, then bind each journey to a requirement,
a test, a monitor and a support path. Until that exists MASTER-1.02 cannot pass.

---

## 2. End-to-end journey traces

### Trace A — J4 "Request a new service / book a service" · **does not complete**

**Catalog.** `service_catalog_screen.dart:12` imports `data/catalog_seeds.dart`; five
hardcoded `List<ServiceItem>` literals at `catalog_seeds.dart:14,152,207,271,361`.
`getServiceCatalog` / `getServiceDetail` have zero call sites in `lib/`.

**The one HTTP call in the flow** is `getAvailableSlots` (`service_booking_screen.dart:88`),
whose fallback at `:98-107` marks every slot available on any failure. The slot grid is
cosmetic.

**Where a completed booking goes.** All four completion paths terminate in `OrdersProvider`,
which imports no API service and writes only
`prefs.setString(_ordersKey, jsonEncode(_orders))` at `orders_provider.dart:205`:

1. Quote-first booking — `service_booking_screen.dart:2555` → `addOrder` `:2580`
2. Priced → cart → checkout — `cart_screen.dart:553` → `addOrder` `:581`
3. Equipment reserve — `equipment_item_card.dart:344`
4. Assistant — `assistant_local_actions.dart:130`

**Assessment requests** (`assessment_request_screen.dart:1391` `_submitRequest`) call
`OrdersProvider.addAssessment` at `:1415` and nothing else — the screen imports no service.

**`createBooking` exists and is dead.** Defined `api_service.dart:353` (POST `/bookings`),
declared `i_api_service.dart:83`. `grep -rn "createBooking" lib/ test/` returns the two
definitions plus `test/services/api_service_test.dart:394` — **no production call site.**
`createAssessmentRequest` (`api_service.dart:399`) has exactly one call site,
`assistant_executor.dart:390` — the *voice assistant*, not the questionnaire the user taps
through.

**31 of ~76 `ApiService` public methods have zero call sites in `lib/`,** including the
entire bookings and assessments surface: `createBooking`, `getBookings`, `cancelBooking`,
`submitRating`, `submitDailyRating`, `getAssessments`, `acceptAssessment`,
`declineAssessment`, `getServiceCatalog`, `getServiceDetail`, `getVitalsHistory`,
`getInvoices`, `getInvoiceDetail`, `getFamilyMembers`, `addFamilyMember`,
`removeFamilyMember`, `updateFamilyMember`, `inviteFamilyMember`, `getDashboard` and others.
`SyncService` is never instantiated at all (`grep -rn "SyncService" lib/` → its own file plus
one comment at `app_provider.dart:341`).

**What the user is told.** `booking_confirmation_screen.dart:219` "Order Confirmed!" over a
green check, then a next-steps block: *"A qualified professional will be assigned within 2
hours"* (`:335-338`), *"You will receive a confirmation call with staff details"* (`:341-343`),
*"Your equipment will be delivered within 24 hours"* (`:350-352`).
`assessment_request_screen.dart:1434-1435`: *"Our care coordinator will call you within 2
hours."* No one at Housepital can act on any of it. `my_orders_screen.dart:183,583` reads the
same local list back, so the user can "track" an order nobody received.

**Worst instance.** `cart_screen.dart:530` `_showRequestBookingModal` — wired to the *Request
Booking* CTA shown to non-payer roles at `:464` — displays *"Booking request sent to your
primary contact for approval. They'll receive a notification to confirm and pay."*
(`:542-544`). Its own docstring at `:527-529` reads **"Stub… No real persistence yet."**
Nothing is written, no provider is touched, no notification is sent.

### Trace B — J3 "Log a medication dose" · **does not complete; does not even persist**

`medication_provider.dart:43` — `final Set<String> _takenDoseKeys = {};`. A plain in-memory
set. `markDoseTakenToday` (`:51-54`) adds a key and notifies. `logDoseToday` (`:110-127`)
additionally appends a synthetic `MedicationLog` to the in-memory `_todayLogs` (`:116`) with
`status: 'administered'`.

`grep -rn "SharedPreferences" lib/` hits twelve files and **not one medication file.** Kill
the app and every dose logged today is gone. Adherence stats read the same volatile set
(`medications_screen.dart:147` → `dosesMarkedTakenToday`, `medication_provider.dart:57-61`).

**No caregiver, nurse or clinician can ever see it.** There is no client method (`IApiService`
has read-only `getMedicationLogs` at `:197`, no POST), no Firestore path (the only writes in
`lib/` are chat and `active_sessions`), no table (`database/schema.sql` has no
`medication_logs`; only a `medications JSON` column on `patients` at `:19`), and
`sync_service.dart` is pull-only and never instantiated. The code says so itself at
`medication_provider.dart:66-70`.

Two further defects:

- **A successful backend refresh erases the patient's own logs.**
  `medication_provider.dart:226` assigns `_todayLogs = results[1]` wholesale, discarding the
  synthetic log inserted at `:116`, then rebuilds `_schedule` at `:227`.
  `medication_schedule_screen.dart:267` gates the "Given" badge on `sm.log?.wasGiven`, so a
  pull-to-refresh (`:85`) un-marks the dose. Invisible today (the failure branch `:228-239`
  preserves the list) — it appears the moment a real backend connects. Meanwhile
  `medications_screen.dart:260` consults `_takenDoseKeys` and still shows it logged, so the
  two screens will disagree.
- **The notification "Taken" action does not log.**
  `medication_reminder_service.dart:277-279` fires the callback; the handler at
  `main.dart:341-352` navigates and shows *"Medication marked — confirm on the schedule"* but
  calls no provider method. The dose is not marked.

Unlike the demo-data fallbacks elsewhere, this carries **no `DemoMode` banner at all**.

### Trace C — J6 "Rate the day / give feedback" · **does not complete**

Two rating surfaces, neither of which reaches a server.

- **My Care card** — `my_care_screen.dart:577-750`, mounted `:326`. `_onRate` (`:613`) writes
  `prefs.setInt('daily_rating_YYYY-MM-DD', stars)` (`:614-615`). 4–5 stars → SnackBar
  *"Thanks for rating! We've shared your feedback with the team."* (`:620-625`). Nothing was
  shared. 1–3 stars → `_showLowRatingModal` (`:631`) collects free text and routes to
  `/raise-concern` with `arguments: {'rating':…, 'preFilledNote':…}` (`:670-678`) — but
  `main.dart:465-467` builds `const RaiseConcernScreen()` and ignores `settings.arguments`,
  and the screen never reads `ModalRoute…arguments`. **The star count and the "what went
  wrong" text the user just typed are silently discarded**; they land on a blank form.
- **Daily-report dialog** — `daily_report_screen.dart:684-737`. `int selectedRating = 0` at
  `:685` is a local closure variable. The submit handler (`:723-729`) is `Navigator.pop` plus
  `SnackBar('Rating submitted!')`. `commentController` (`:686`) is never read and never
  disposed.

`submitDailyRating` (`api_service.dart:506-518`, POST `/ratings`) and `submitRating`
(`:385-394`) both exist and have zero call sites. `FEATURE_TRACKER.md:193` records "Daily Care
Rating — **Not Started** — Backend ready, no UI" while two UIs ship.

### Trace D — J9 "Manage who can see the record" · **does not complete**

`family_members_screen.dart:22-44` — `static final _mockMembers`, two hardcoded literals
("Suresh Kumar", "Meena Kumar"). `initState` copies from it at `:51`; no API load.
**Add** (`:224-243`) is `setState(() => _members.add(...))`; **remove** (`:64-66`) is
`setState(… removeWhere …)`. Both then show a success SnackBar (`:245-249`, `:68-70`). Because
`initState` re-copies from the static, **every change is reverted on screen pop.** Six family
CRUD methods exist in `api_service.dart:557-681` with no call sites.

`add_patient_screen.dart:106` → `AppProvider.addPatient` →
`app_provider.dart:245-249`, in-memory with `// TODO(persistence): persist to
SharedPreferences / backend.` at `:248`, while the screen says *"Patient added. You're now
their primary contact."* (`:114`).

**Prior-round findings restated in the brief are confirmed, and are worse than described:**
the service request does not merely "write to local storage" — the assessment path never
touches an API at all and the cart's Request-Booking modal writes *nothing*; the dose log does
not merely "never leave the phone" — it never leaves RAM.

---

## 3. Deliverability of the core promise

The promise, in the owner's own framing, is **visibility into a parent's care**. Measured
against the five things a remote family member opens the app to see:

| What the app shows | Where it comes from | Warned? |
|---|---|---|
| **Staff attendance** (My Care summary, service detail, calendar) | `DemoData` literals at `demo_data.dart:238-239,259-260,274-275`, seeded whenever the list is empty at `my_care_provider.dart:48-53`. Care Calendar reads `DemoData.icuServiceDetail.staffOnDuty` **unconditionally** at `care_calendar_screen.dart:1324`. | Partly. Calendar: **no**. |
| **Vitals** | `vitals_screen.dart` never calls `getVitalsHistory` (zero call sites). The chart is `Random(42)` at `:62-83`, or the user's own typed readings. | Yes (`sourceVitals`, the only source that also lowers, at `:129`). |
| **Daily reports** | `daily_report_screen.dart:32-33` calls the real API, then on **any** exception (`:38-89`) substitutes a ~50-line hardcoded report — nurse "Priya Mehra", "Metformin 500mg", "Amlodipine 5mg", and a staff-notes narrative. | **No flag raised at all.** |
| **Medication adherence** | Session RAM (Trace B). | **No.** |
| **Care rating / feedback loop** | Nowhere (Trace C). | **No.** |

**The demo notice is a one-way latch.** `markServingLiveData` is called in exactly **two**
places in all of `lib/` — `app_provider.dart:292` and `vitals_screen.dart:129`. Ten of twelve
`DemoMode` sources are raised and never lowered; three (`sourceCareTeam` `:31`,
`sourceCareCalendar` `:32`, `sourceProfile` `:33`) are **never raised at all**. Because
`my_care_provider.dart:48` seeds demo whenever `_activeServices.isEmpty` — always true on
first load — and never lowers the flag even after the API succeeds at `:65-69`, opening the My
Care tab **pins the notice on for the session against a perfectly healthy backend**, while the
three genuinely unlabelled surfaces (care team, calendar, daily-report detail) show fabricated
clinical data with no notice at all. The banner's own copy is excellent
(`en.json:323` / `hi.json:323`, "Showing sample data — … this is not your live record") and is
pointed at the wrong screens.

**Honest assessment.** Of the five load-bearing elements of the promise, **none is currently
deliverable.** Three are demo data, one is volatile RAM, one does not exist. The two journeys
that do complete — raise a concern (J7) and SOS (J8) — are the escalation paths, i.e. exactly
the things a family reaches for *when the visibility has already failed them*. The app today
is a high-fidelity demonstration of the promise, not an instance of it, and four screens tell
the user otherwise in the affirmative (`cart_screen.dart:543-544`,
`my_care_screen.dart:620-625`, `daily_report_screen.dart:726-728`,
`family_members_screen.dart:68-70`, plus `add_patient_screen.dart:112-117`).

**Against the round-2 → round-4 trajectory:** this module's evidence fits neither "surfaces"
nor "half-wires". These are **finished surfaces wired to a stub, with the confirmation copy
written as though the wire existed** — the API method is present, correct and never called.
Call it *dead-ended wiring*.

---

## 4. Control results

| Control | Outcome | Evidence | Impact / mitigation (Warnings and Fails) |
|---|---|---|---|
| **PRD-1.01** Target users, contexts, abilities, constraints, motivations, excluded users | **Warning** | `docs/superpowers/specs/2026-03-21-my-care-tab-design.md:22-26` defines two user modes ("I'm here, what's next" / "I'm far away, show me proof"); `docs/BUSINESS_RULES.md:104-126` defines four roles. No `PERSONAS.md` (`find . -name PERSONAS.md` → empty). No abilities, constraints, device/connectivity assumptions, or non-target users anywhere. | The primary cohort — elderly, oncology/geriatric, often Hindi-preferring, low digital literacy — is nowhere written down, so design decisions (1.4× Dynamic Type clamp, colour-coded vitals) cannot be checked against it. **Fix:** `docs/PERSONAS.md` covering patient-self, primary contact, remote family, caretaker; state excluded users. **Owner:** OWNER-TBD · **Due:** before first external build. |
| **PRD-1.02** Problem statements in user language and evidence | **Warning** | `2026-03-21-my-care-tab-design.md:11-20` states six problems verbatim in user voice ("Did the nurse/caretaker show up on time?", "How much have I consumed?"). Genuinely good, and not features in disguise. `2026-03-23-unified-my-orders-design.md:7`, `2026-06-02-home-assistant-blogs-design.md:24` similar. | **No evidence is cited for any statement** — no interview, ticket, or support-log reference. Covers ~3 features of ~25. **Fix:** attach a source to each problem statement. **Owner:** OWNER-TBD. |
| **PRD-1.03** Desired outcomes, guardrails, measures of success before solution commitment | **Fail** | Repo-wide `grep -rniE "success metric\|success criteri\|KPI\|north star\|guardrail\|OKR\|retention rate\|DAU"` over all `*.md` (excluding audits) returns **one** hit: `2026-03-21-my-care-tab-design.md:431`. Its seven criteria are qualitative; criterion 1 ("within 3 seconds") was never measured; criterion 6 ("Everything the staff app writes is visible in the patient app via API") is not met. No guardrail outcome anywhere. | Nothing is measurable and nothing is measured. Ties directly to the zero-analytics finding below: with no event tracking there is no instrument that *could* evaluate a success criterion even if one were written. Success is currently adjudicated by one stakeholder's opinion (§7). |
| **PRD-1.04** Assumptions, unknowns, dependencies, risks, highest-cost failure modes with validation plans | **Warning** | `docs/KNOWN_ISSUES.md` is a substantial register (blockers / critical / high / medium / low / tech debt / workarounds) and `:14-16` records the demo-data blocker honestly. Specs carry "Open items / dependencies". | **No owner, no due date, no validation plan on a single row.** The register is also internally stale: BUG-14 "Invoice PDF download is a stub" (`:95`) is Open while `FEATURE_TRACKER.md:162` says Done; BUG-16 "`/services` maps to empty `Scaffold()`" (`:97`) is fixed (`main.dart:573-575`); TD-01 (`:122`) contradicts BUG-01 Resolved (`:65`). **Fix:** add owner/due/mitigation columns; reconcile against FEATURE_TRACKER. |
| **PRD-1.05** No data, accounts, permissions, or behaviour unrelated to core value | **Pass** | Four iOS purpose strings, all specific and justified (`ios/Runner/Info.plist:69-76`: microphone/speech for the assistant, camera/photos for prescriptions). Four Android permissions (`AndroidManifest.xml:2-5`: boot, exact alarm, notifications, audio) — all serve medication reminders or voice. No location, contacts, IDFA, ad SDK or analytics SDK. No account is required to use the app. | — |
| **PRD-2.01** In-scope, out-of-scope, deferred, prohibited behaviour recorded | **Pass** | `CLAUDE.md:21-56` "Inviolable business rules" records **prohibited** behaviour explicitly (never render ₹0; never branch control flow on a user-facing string; Japa/Nanny not sold here; SOS never gated). Specs carry `### Out of scope` and `### v1 scope boundaries (explicitly later)` (`2026-06-02-home-assistant-blogs-design.md:43,118,181`). `FEATURE_TRACKER.md:264-271` records Blocked Items with a blocker and an owner. | — (accuracy of the *status* column is graded at PRD-8.02.) |
| **PRD-2.02** Functional requirements have observable acceptance criteria covering normal, boundary, negative, interruption, recovery | **Fail** | Four features have "Done criteria" (`2026-06-02-ai-assistant.md:219-223`, `2026-06-02-home-layout-b.md:252-256`) or named test cases (`2026-03-23-unified-my-orders-design.md:278-292`). Everything else — booking, payment, assessment, medications, deletion, family — has none. Interruption and recovery are covered nowhere. | **The decisive consequence:** no acceptance criterion anywhere in the repo says *"the booking reaches Housepital"* or *"the dose log is retrievable by the care team"*. That is precisely why four journeys can ship with success dialogs over dead ends and a green test suite. This is the single highest-leverage fix in this report. |
| **PRD-2.03** Nonfunctional requirements cover accessibility, privacy, security, performance, reliability, localization, support, compatibility | **Fail** | Covered: accessibility partially (`CLAUDE.md:107-113` — ≥44pt, 11px min, motion gating) and localization (`CLAUDE.md:115-118` + `test/utils/i18n_sync_test.dart` guard). Absent: **privacy** (no `PRIVACY_POLICY.md`, no `DATA_INVENTORY.md` — see `docs/audits/round3/SECURITY_PRIVACY_AUDIT.md:415`), **performance** (no frame/startup budget), **reliability** (no availability or data-durability target), **support** (no in-app support SLA), **compatibility** (no minimum OS matrix stated as a requirement). | Five of eight categories unwritten. For a health app under DPDP the operative blocker is the missing privacy NFR; that remediation is shared with the Security & Privacy module and should be tracked once, not twice. |
| **PRD-2.04** Requirements identify source, rationale, owner, priority, dependencies, applicable release | **Warning** | **Source and rationale are unusually strong** — `BUSINESS_RULES.md:9` records the manpower-price reversal with date, commit `e41224c`, and *why the previous rule was wrong* ("based on a stale memory"). `CLAUDE.md:93-101` does the same for the nav pill. | No owner, no priority, and no release/condition binding on any requirement — nothing distinguishes "required for v1" from "someday". The only Owner column in the repo is `FEATURE_TRACKER.md:266-271` (4 rows, "Founder"/"Ops"). |
| **PRD-2.05** Conflicting requirements and tradeoffs have an approved decision record | **Warning** | Real decision records exist with a named approving authority (the owner) and dated lineage: manpower pricing (`BUSINESS_RULES.md:9`), `onOrange` = white at a measured 2.33:1 (`CLAUDE.md:102`), nav-bar shape (`CLAUDE.md:93-96`). | **The record is not propagated.** `docs/TEST_STRATEGY.md:154` — under the heading *"Key Business Rules Encoded in Tests"* — still states the **reversed** rule: *"Manpower services … have NO commission — users reject if they see prices upfront."* That directly contradicts `BUSINESS_RULES.md:7` and `CLAUDE.md:23`. `SCREEN_MAP.md:18` ("detached `GlassSurface` pill") and `SCREEN_MAP.md:20` ("FIXED full-width solid-orange bar") contradict each other in **adjacent paragraphs of the same file**. **Fix:** a decision-propagation checklist. **Owner:** OWNER-TBD. |
| **PRD-3.01** Journeys cover first use, primary goals, return use, settings, help, error recovery, export/deletion, offboarding | **Fail** | **First use is unreachable.** `grep -rn "LoginScreen" lib/` returns only `login_screen.dart:11,12,15,18` — its own declaration. There is no `/login` case in `main.dart`. `'/otp'` and `'/onboarding'` each appear exactly once in all of `lib/` — as their own case labels at `main.dart:446,448`. `splash_screen.dart:17` unconditionally `pushReplacementNamed('/home')`. The auth gate is commented out at `main.dart:417-419`. **Export:** none (`grep -rn "export" lib/screens/settings/` → nothing); the role-gated handover PDF is the nearest thing. **Offboarding:** `settings_screen.dart:441-471` wipes and signs out, then `nav.pop()` — the user remains inside the app, because there is no sign-in surface to return to. | Anyone who picks up the phone opens straight into a patient's clinical record, no credential. Sign-up, OTP and onboarding are dead code that three prior rounds' test suites still cover. **This is a release blocker independent of the demo-data blocker.** |
| **PRD-3.02** Navigation and IA use user mental models and consistent terminology | **Warning** | In-app IA is sound: five consumer-legible tabs (`SCREEN_MAP.md:5-12`), `IndexedStack` state preservation, a consistent `GlassAppBar` chrome contract. | The **documented** IA is not. `SCREEN_MAP.md:76` heads "CALENDAR TAB (Index 3)" and `:84` "BILLING TAB (Index 4)" while `:136` heads "MORE TAB (Index 4)" — index 4 assigned twice, contradicting `:5-12` and `:14-16`, which say the calendar is not a tab. `README.md:278` still reads "Tab 4 — Calendar (root tab)". `SCREEN_MAP.md:65,221` document `BookingHistoryScreen`; `grep -rn "class BookingHistoryScreen" lib/` → nothing, and `main.dart:620-621` routes `/booking-history` to `MyOrdersScreen` — the phantom recorded at `docs/audits/DOCUMENTATION_AUDIT.md:70` and `round3/DOCUMENTATION_AUDIT.md:75` is **still unchanged in round 4**, and `FEATURE_TRACKER.md:123,124,126` marks three features "Done" against it. One screen carries three names. |
| **PRD-3.03** Deep links, notifications, shared links, search, widgets, external entry points land in safe states | **Warning** | Notification routing exists and is tested (`notification_router.dart`, `TEST_MAP.md`); universal search exists. | **No deep-link support of any kind:** no `uni_links`/`app_links` in `pubspec.yaml`; `grep "CFBundleURLSchemes" ios/Runner/Info.plist` and `grep "android:host" android/app/src/main/AndroidManifest.xml` → zero. Recorded as BUG-23 (`KNOWN_ISSUES.md:113`). The booking-confirmation share button shares an ID that exists only on that handset (Trace A). **Fix:** state deep links as out of scope for v1, or configure them. |
| **PRD-3.04** Leave, cancel, go back, resume, recover without losing work or entering a trap | **Warning** | `PopScope` appears exactly once in `lib/` — `booking_confirmation_screen.dart:187-188`, correctly blocking back-navigation into a completed payment. Cart resume works (`CartProvider` + SharedPreferences). `payment_screen.dart:614` deliberately withholds retry on the unverified branch to prevent a double debit. | No draft persistence anywhere (`grep -rn "draft" lib/screens/` → nothing). `assessment_request_screen.dart` is a 1,453-line questionnaire with no unsaved-work guard: backing out loses every answer silently. The low-rating modal discards the user's typed explanation (Trace C). |
| **PRD-3.05** Multi-user, role, household, cross-device journeys identify who can see, change, share, revoke, delete each object | **Fail** | `BUSINESS_RULES.md:104-132` is a thorough 22-action × 3-role matrix, enforced by `permissions.dart` and covered by 25 tests (`TEST_MAP.md`). | **No role is ever established at runtime** — the auth gate is commented out (`main.dart:417-419`), so the matrix is evaluated against an unauthenticated default. And the mechanism by which access is granted or revoked is a mock: `family_members_screen.dart:22-44,51,64-66,224-243` — **there is no revoke that revokes anything** (Trace D). A patient cannot see who has access to their record, and `BUSINESS_RULES.md:111,123` denies `PATIENT_SELF` the ability to add or remove members at all. |
| **PRD-4.01** Every surface defines loading, empty, error, offline, stale, partial, denied, unavailable, success | **Fail** | Present: `ErrorRetryWidget` on 5 screens (`my_care_screen.dart:339`, `service_detail_screen.dart:55`, `medications_screen.dart:92`, `medication_schedule_screen.dart:68`, `staff_profile_screen.dart:171`); `paginated_list.dart:180,220` loading/empty/error/retry; `EmptyState` in 12 screen files. | **The dominant pattern is demo fallback *instead of* an error state.** `my_care_provider.dart:48-53` seeds `DemoData` whenever the list is empty, making the error state unreachable on the app's primary monitoring tab. `daily_report_screen.dart:38-89` substitutes a hardcoded report with a named nurse and named drugs on any exception, raising no flag. **Offline and stale states are defined nowhere** — no connectivity check exists in `lib/`; the approved spec asked for a "Last updated X minutes ago" banner (`2026-03-21-my-care-tab-design.md:426`) and it was not built. |
| **PRD-4.02** Errors explain impact, preserve work, give an actionable next step, distinguish retryable from permanent | **Warning** | `payment_screen.dart` is exemplary: typed `PaymentFailure {notStarted, declined, unverified}` replacing a string match (`:283`), a deliberate no-retry branch with the reason written down (`:614`), and `AppConstants.supportPhone` as the escape hatch. `delete_account_screen.dart:32-39` separates what is DONE from what is REQUESTED. | Outside payments the pattern does not hold: `assessment_request_screen.dart:1396-1411` uses bare hardcoded-English SnackBars; and three surfaces report *success* for a failure (Traces A, C, D), which is the inverse of this control. |
| **PRD-4.03** Destructive and consequential actions communicate scope, reversibility, dependencies, effect on others | **Warning** | `delete_account_screen.dart:17-43` is a model of this control — cites App Review 5.1.1(v) and DPDP §12, requires typing a **localized** confirm word (`:70-76`), records the request durably *before* wiping (`:101-104`), and states done-vs-requested separately. `settings_screen.dart:454-461` wipes session data before sign-out for the shared-phone case. | The logout dialog is **hardcoded English** — `const Text('Logout')`, `const Text('Are you sure you want to logout?')` (`settings_screen.dart:445-446`) — so a Hindi-preferring user gets English at the exact moment their local clinical data is erased, and the dialog never says the data will be erased. `family_members_screen.dart:59-61` asks "Are you sure you want to remove X?" without saying what X loses access to. |
| **PRD-4.04** Duplicate action, rapid repetition, interruption, timeout, stale state, concurrency, partial completion have defined behaviour | **Fail** | Submit guards (`_isSubmitting`/`_isProcessing`) exist in **5 of 91** screen files: `delete_account_screen`, `return_screen`, `staff_replacement_screen`, `raise_concern_screen`, `payment_screen`. | The two highest-consequence non-payment writes have none: `assessment_request_screen.dart:1391` `_submitRequest` (no guard, no `bool` flag in the class) and `cart_screen.dart:553` `_checkout`. **Stale state is actively mishandled** — `medication_provider.dart:226` discards the patient's own dose log on a successful refresh, un-marking a dose in one screen while another keeps showing it marked (Trace B). This defect is dormant today and fires the day a backend connects. |
| **PRD-4.05** Support and diagnostics reachable when automated recovery is insufficient | **Warning** | Support is genuinely reachable: `AppConstants.supportPhone` (`constants.dart:19`) referenced from 12 sites across 8 files (`main.dart`, `help_faq_screen`, `home_screen`, `sos_screen`, `care_team_screen`, `staff_otp_verification_screen`, `article_detail_screen`, `demo_data`); 20-FAQ help screen; `/chat` is real Firestore; `raise_concern_screen.dart:370` posts to a real endpoint. | **Diagnostics are absent.** `logger.dart:63` is an unwired `TODO(observability)`, so ~45 warn/error sites — including every demo-data fallback and every `StoreMigrator` failure — reach no remote sink. There is no send-logs/attach-diagnostics path and no analytics. A user can reach support; support has no data about what the user saw. |
| **PRD-5.01** Privacy, permission, purchase, subscription, sharing and **AI** disclosures appear before commitment in plain language | **Warning** | iOS purpose strings are specific and plain (`Info.plist:69-76`). The demo banner is exemplary and localized (`en.json:323`, `hi.json:323`). Terms and Privacy links exist (`about_screen.dart:97-104` → `housepital.in/terms`, `/privacy`). | **No AI disclosure.** The assistant is titled only "Sahayak" (`assistant_screen.dart:81`); there is no statement that it is automated, no medical-advice disclaimer, and no notice that with `ASSISTANT_API_URL` set the user's message is sent to a Cloud Function and on to a third-party model. Its chrome is hardcoded Hinglish outside i18n (`grep -n "assistant" assets/i18n/en.json` → zero keys). No pre-purchase notice that checkout is simulated on a placeholder-key build. Policy-text accuracy is not verifiable from source (external URLs) — see BLOCKED-OWNER. |
| **PRD-5.02** Defaults favour safety and privacy; no exploitation of inertia | **Pass** | Safety notifications are non-disableable and promotional is off by default (`BUSINESS_RULES.md:138-148`). Crashlytics/Performance collection is disabled in debug (`main.dart:130-133`). No pre-ticked consent, no account requirement, no tracking SDK. | — |
| **PRD-5.03** No false urgency, scarcity, obstruction, hidden costs, confirm-shaming, forced continuity, trick wording, disguised ads, difficult cancellation | **Warning** | Clean on every commercial dark pattern. Repo-wide grep for urgency/scarcity copy returns only `otp_screen.dart:172` ("OTP expires in …", a real expiry) and article prose. No subscriptions or trials (`autoRenew` is a model field only, `models.dart:236`). Cancellation is in-app; account deletion is a first-class screen; GST and totals are itemized. | **Trick wording is present, in its most consequential form:** five confirmations assert work that did not occur — `cart_screen.dart:543-544`, `my_care_screen.dart:620-625`, `daily_report_screen.dart:726-728`, `family_members_screen.dart:68-70`, `add_patient_screen.dart:112-117`. Not commercially motivated, which is why this is a Warning rather than a Fail here; graded Fail at PRD-6.04 and PRD-8.02 where it belongs. |
| **PRD-5.04** Consequential recommendations or automation communicate limitations, uncertainty, alternatives, human review routes | **Fail** | Credit where due: article bodies carry a plain-language disclaimer (`demo_articles.dart:208`: "This is general guidance. For your specific situation, talk to your doctor or your Housepital Health Manager"); the assistant confirms before acting and never charges. | **Vitals classification is an unqualified automated clinical judgement.** GREEN/YELLOW/RED thresholds are hardcoded in `constants.dart` (`BUSINESS_RULES.md:162-188`), diverge from the backend's own thresholds (`:182-188`), carry **no clinician sign-off** (master gate MASTER-3.11 confirms none has occurred), state no uncertainty, offer no alternative, and name no human review route on the vitals surface — while the underlying series is `Random(42)` (`vitals_screen.dart:62-83`). A family member can read "RED" or "GREEN" about a parent's oxygen saturation from fabricated data with no caveat attached. |
| **PRD-5.05** Children, vulnerable users, caregivers, shared devices, coercive contexts considered | **Warning** | Shared devices **are** considered — `settings_screen.dart:454-457` and the `SessionScope` wipe-before-sign-out, plus per-patient storage keys (`CLAUDE.md:120-133`). Caregivers are a first-class role in the matrix. Children: N/A to this product. | Vulnerable users are not documented as a design constraint (see PRD-1.01), and Dynamic Type is clamped at 1.4× (`main.dart:426-427`) — capping the accommodation the elderly cohort most needs. Coercive contexts are unconsidered: a `PRIMARY_CONTACT` holds full read and write over a competent adult's health record; the patient cannot see who has access and cannot revoke it (`BUSINESS_RULES.md:111,123` + Trace D). |
| **PRD-6.01** Labels, actions, instructions, warnings, units, terminology consistent and understandable | **Warning** | EN/HI parity is guarded by a test (`test/utils/i18n_sync_test.dart`); vitals units are explicit (`BUSINESS_RULES.md:166-180`). | Hardcoded English at consequential moments: `settings_screen.dart:445-446` (logout), `assessment_request_screen.dart:1398,1407,1435,1447`, `cart_screen.dart:543-544`, `family_members_screen.dart:69`, `daily_report_screen.dart:727`. One screen carries three names ("My Orders" / "Booking History" / `/booking-history`). Depth of this control belongs to the Content & Localization module; recorded here for journey impact. |
| **PRD-6.02** Critical content not dependent on jargon, colour, sound, motion, memory, position, or specialist knowledge without support | **Warning** | Vitals status is conveyed as GREEN/YELLOW/RED and attendance as "color-coded status badges" (`FEATURE_TRACKER.md:28,27`); round 3 records **zero contrast assertions in `test/`** and 17 of 54 icon buttons unlabelled. Clinical terms (SpO₂, systolic/diastolic, mmHg) appear with no glossary for a low-literacy cohort. | Measurement is owned by the Accessibility module; the product consequence recorded here is that the app's single most safety-relevant signal is primarily a colour. **Fix:** pair every vitals/attendance colour with a text or icon token. |
| **PRD-6.03** Legal and safety content accurate without displacing the plain-language explanation | **Warning** | `delete_account_screen.dart:17-43` does exactly this — legal basis cited, then plain language on what is done vs requested. The demo banner is accurate and plain. | The terms and privacy texts are external URLs (`about_screen.dart:98,104`) and cannot be assessed from source — unverified, not N/A. |
| **PRD-6.04** Content hierarchy answers what this is, why it matters, what happens next, how to recover | **Fail** | The *shape* is right — `booking_confirmation_screen.dart:335-352` is an explicit next-steps block. | The content is false. "A qualified professional will be assigned within 2 hours" (`:335-338`), "You will receive a confirmation call" (`:341-343`), "delivered within 24 hours" (`:350-352`), "Our care coordinator will call you within 2 hours" (`assessment_request_screen.dart:1434-1435`) — for records that exist only in `prefs` (`orders_provider.dart:205`). "What happens next" is answered confidently and wrongly, and "how to recover" is unanswerable because the user has no way to learn the request was never received. |
| **PRD-7.01** Research participants represent important contexts, abilities, devices, languages, experience levels, risk groups | **Fail** | Repo-wide `grep -rniE "usability test\|user research\|user interview\|participant\|focus group\|beta test\|pilot\|A/B test\|user validation\|persona"` across all `*.md` returns **zero product-research hits** — the only matches are the word "participant" describing a layout widget and "persona" describing a permission role. The only validation artefact is six "Field Round" changelog entries (`CHANGELOG.md:31,48,80,106`) recording **one** stakeholder's — the owner's — preferences. | **Absence is the finding.** No patient, no remote family member, no caretaker, and no Hindi-first or screen-reader user has been observed using this app, on any device, at any point. For a product whose core promise is clinical reassurance to anxious families, this is the deepest gap in the report. **Fix:** 5–8 moderated sessions covering J2, J3, J4, J6 with real families in Delhi NCR before any external build. **Owner:** OWNER-TBD. |
| **PRD-7.02** Study tasks reflect real goals and include mistakes, recovery, permission denial, interruption, consequential decisions | **Fail** | No study of any kind exists to assess. | Consequence of 7.01. Not tested is not N/A. |
| **PRD-7.03** Findings distinguish observation from interpretation; record severity, evidence, frequency, affected users, design response | **Fail** | The field-round entries record the design **response** only — never an observation, severity, frequency, or affected user. | The clearest symptom: the bottom nav went **floating-glass → orange pill → fixed full-width orange bar → back to the floating pill** across field rounds 3, 4-5 and 8 (`CLAUDE.md:93-96`, `CHANGELOG.md:8,80,106`). Four reversals of one decision with no recorded observation capable of adjudicating between them, each consuming a build cycle. Round 5's stated objection ("the pill covered content") was answered structurally in round 8 rather than by measurement. |
| **PRD-7.04** Accessibility evaluation includes people with relevant disabilities or qualified specialists at a cadence appropriate to risk | **Fail** | Automated guards exist and are real (`scripts/check_design_consistency.sh`, `dark_mode_test.dart`, 37-screen × 3-width overflow smoke). No specialist review and no participant with a disability. Round 3 records Dynamic Type clamped at 1.4× and untested, 17 of 54 icon buttons unlabelled, zero contrast assertions in `test/`. | For a primary cohort of elderly patients, automated token checks are not an accessibility evaluation. |
| **PRD-7.05** Material unresolved usability risks have explicit owner, due date, mitigation, approval | **Fail** | `KNOWN_ISSUES.md` carries usability risks (BUG-21 `:109`, BUG-22 `:110`, the demo pill absorbing touches `:26-28`) with **no owner, no due date and no approver on any row**. `grep -rniE "sign-?off\|approved by\|approver\|decision owner"` across non-audit `*.md` → zero. | Structural: the suite's Warning mechanics require an approver, and none exists anywhere in the repo. Blocks MASTER-4.02 for the same reason MASTER-1.05 fails. |
| **PRD-8.01** Critical requirements trace to design, implementation, test cases, analytics/monitoring, support content, release evidence | **Fail** | Partial traces exist and are useful: `SCREEN_MAP.md` maps screen → route → widget → data source; `docs/TEST_MAP.md` maps **source file → test file**; `2026-03-23-unified-my-orders-design.md:278-292` names specific test cases. | **No document maps a requirement to the test that proves it.** The only requirement→test artefact in the repo is `TEST_STRATEGY.md:152-161` ("Key Business Rules Encoded in Tests"), and its **first entry (`:154`) states the reversed manpower rule** — contradicting `BUSINESS_RULES.md:7` and `CLAUDE.md:23`. The monitoring leg has nothing to trace to: **no analytics SDK exists anywhere** (verified across `pubspec.yaml`, `pubspec.lock`, `lib/`, `test/`, `ios/Runner`, `android/app/src` for `firebase_analytics`/`logEvent`/`setUserId`/Sentry/Mixpanel/Amplitude/PostHog/Segment → zero hits; `FEATURE_TRACKER.md:238` agrees, "Analytics / Event Tracking — Not Started"), and `logger.dart:63` is unwired, so even crash-adjacent warnings reach no sink. The release-evidence leg has nothing to trace to either. **This is the direct answer to the audit question: requirements-to-test traceability does not exist, and the one document that attempts it is wrong.** |
| **PRD-8.02** Release artifact matches approved journeys, copy, states, platform behaviour, privacy model, commercial terms | **Fail** | Four traced journeys (§2) show the artifact does not match its own approved journeys. Status reporting compounds it: `FEATURE_TRACKER.md:162` "Invoice PDF Download — Done" vs `KNOWN_ISSUES.md:95` BUG-14 Open; `:123,124,126` three features "Done" against a class that does not exist; `:193` "Daily Care Rating — Not Started, no UI" while two rating UIs ship; `:26` "Dashboard Hub — All cards rendering with live data" while `README.md:428` says "AppProvider uses `_loadMockData()`"; `:252` records the fixed orange nav bar that `CLAUDE.md:88-101` reversed. | I am also auditing **source, not a release artifact** (MASTER-4.04), so even a match could not be certified here. **Both facts must be stated to the external reviewer.** |
| **PRD-8.03** Known limitations reflected in marketing, onboarding, help, accessibility information, reviewer notes, support playbooks | **Fail** | The demo-data banner is a genuine, well-written, localized in-product limitation disclosure (`en.json:323`, `hi.json:323`) — and it is the best artefact in this control. | It is the only one. Onboarding cannot disclose anything (unreachable, PRD-3.01). `grep -i "demo\|sample" lib/screens/settings/help_faq_screen.dart` → **zero** across 20 FAQs. No reviewer notes, no support playbook, no accessibility statement. `README.md` and `FEATURE_TRACKER.md` overstate readiness in the ways listed above. Nothing tells a support agent that a "confirmed order" may never have been received. |
| **PRD-8.04** Product owner, design owner, engineering owner, quality owner approve readiness or record accepted conditions | **Fail** | `grep -rniE "sign-?off\|approved by\|approver\|decision owner\|reviewed by"` across non-audit `*.md` → zero. No `CODEOWNERS` (`.github/` contains only `workflows/`). `PROJECT.md:5` names one project owner, not four readiness owners. | Mirrors MASTER-1.05 Fail. Without a named quality owner and risk-acceptance authority, none of the 16 Warnings in this report can be formally accepted, and the release decision has no signatory. |

---

## Scorecard

**Pass 3 · Warning 16 · Fail 19 · N/A 0** (BLOCKED-OWNER 1, recorded separately below and not
counted as a control outcome)

Total controls assessed: 38 of 38. No control was graded N/A; nothing was skipped.

---

## Release blockers (every Fail)

1. **PRD-3.01 — first use does not exist.** `LoginScreen` is unreachable dead code; no
   `/login` route; `splash_screen.dart:17` opens a patient's clinical record with no
   credential; auth gate commented out at `main.dart:417-419`.
2. **PRD-3.05 — no role is established and no access can be revoked.** Permission matrix
   evaluated against an unauthenticated default; family membership is a static mock whose
   changes revert on screen pop (`family_members_screen.dart:51`).
3. **PRD-6.04 / PRD-8.02 — the app tells users that work succeeded when nothing was
   recorded.** Five confirmations: `cart_screen.dart:543-544` (self-declared stub at `:527`),
   `booking_confirmation_screen.dart:335-352`, `assessment_request_screen.dart:1434-1435`,
   `my_care_screen.dart:620-625`, `family_members_screen.dart:68-70`.
4. **PRD-4.01 — fabricated clinical data is served with no warning.**
   `daily_report_screen.dart:38-89` (named nurse, named drugs, on any exception, no
   `DemoMode` flag); `care_calendar_screen.dart:1324` (unconditional); care team. Meanwhile
   the banner latches ON for healthy backends (`my_care_provider.dart:48-53`, ten of twelve
   sources never lowered).
5. **PRD-5.04 — vitals RED/YELLOW/GREEN is an unqualified automated clinical judgement**
   over `Random(42)` data (`vitals_screen.dart:62-83`), with no clinician sign-off, no
   uncertainty statement and no human-review route.
6. **PRD-4.04 — dose logging is unsafe by design and gets worse when the backend lands.**
   In-RAM only (`medication_provider.dart:43`); `:226` discards it on a successful refresh;
   two screens will then disagree; the notification "Taken" action does not log
   (`main.dart:341-352`).
7. **PRD-2.02 / PRD-8.01 — no acceptance criteria and no requirement→test traceability.**
   The one artefact that attempts it (`TEST_STRATEGY.md:154`) encodes a rule the owner
   reversed on 2026-06-11. 1,819 passing tests prove no journey completes.
8. **PRD-7.01–7.05 — zero user or accessibility validation** of any kind, with no owner,
   due date or approver on any usability risk.
9. **PRD-1.03 / PRD-8.03 — no success measures and no instrument to measure them.** Zero
   analytics SDK; `logger.dart:63` unwired.
10. **PRD-2.03 / PRD-8.04 — no written privacy NFR and no named readiness approvers.**
    (Privacy remediation is shared with the Security & Privacy module; track once.)

---

## Warnings requiring risk acceptance

All sixteen require an impact, mitigation, owner, due date and approver. **No approver exists
anywhere in the repo (PRD-7.05, PRD-8.04), so every one of them is currently unacceptable in
the formal sense** — this is a structural gap, not a diligence gap. Owner is recorded as
`OWNER-TBD` throughout, which is honest rather than evasive: nothing in the repository
identifies a risk-acceptance authority.

Highest-consequence Warnings, in order: **PRD-2.05** (a reversed business rule still live in
`TEST_STRATEGY.md:154`, and `SCREEN_MAP.md:18` contradicting `:20`), **PRD-5.01** (no AI
disclosure on Sahayak), **PRD-5.05** (no patient-side visibility or revocation of family
access), **PRD-6.02** (safety signal carried by colour alone), **PRD-3.02** (the
`BookingHistoryScreen` phantom, **unchanged since round 2** and now propagated into three
"Done" rows of `FEATURE_TRACKER.md`).

**Accepted risks, correctly excluded from grading** per the brief: white on Housepital orange
(2.33:1), manpower prices shown and directly bookable, the floating glass pill nav. Each is a
measured owner decision with a dated lineage; none is graded a Fail here.

---

## BLOCKED-OWNER — needs access I do not have

1. **Terms of Service and Privacy Policy content** (`about_screen.dart:98,104` →
   `housepital.in/terms`, `/privacy`). PRD-6.03 and PRD-5.01 require the plain-language and
   accuracy of these texts to be assessed; they are external web pages, not repository
   artefacts, and I audited source with no network fetch. **Not N/A — unverified.**

---

## Limitations of this audit

- **Source review only, per MASTER-4.04.** No release artifact exists to audit and no
  production-like environment was available. Every verdict describes `9127713` as written,
  not as built or as experienced on a device. PRD-8.02 in particular cannot be discharged
  from source alone even in principle.
- **No app was run.** Per the round-4 rules I did not execute `flutter test`, `flutter build`
  or any device/simulator session. Journey completion is judged by reading control flow to
  its terminus (provider → persistence → network), not by observing it. Where I assert
  "no call site" I have run the grep and state it.
- **Central results cited, not reproduced:** `flutter analyze` clean, design gate passes,
  1,819 tests across 101 files pass. I read test *sources* where test quality bore on
  traceability (PRD-8.01).
- **No prior report for this module**, so nothing was inherited or cross-checked against an
  earlier baseline of the same controls; where a prior round covered overlapping ground
  (`DOCUMENTATION_AUDIT.md:70`, `round3/SECURITY_PRIVACY_AUDIT.md:415`) I cite it and state
  its current status.
- **Backend repositories were not opened.** `../housepital-backend` and `../housepital-api`
  are in scope for this suite but bear on this module only through the app's client
  contract, which I traced from `i_api_service.dart` / `api_service.dart` inside this repo.
  Whether the backend could accept a booking is immaterial to the finding that the app
  never sends one.
- **The candidate journey list in §1b is derived, not authoritative.** It is offered for
  owner ratification. If the owner's real journey set differs, the traces in §2 remain valid
  but the coverage claim does not.
