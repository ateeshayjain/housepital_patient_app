# App Quality Audit System — Master Applicability & Release Gate

**Control family MASTER · Suite v2.0 · Audit round 4**

> **Status: IN PROGRESS.** Module reports are being produced in this directory. Sections 4
> and 5 cannot be completed until every module has reported, and several controls are
> explicitly the owner's to sign rather than the auditor's to assert. Those are marked
> **OWNER**, not guessed.

## Audit record (MASTER-1.01)

| Field | Value |
|---|---|
| App / project | Housepital Patient App (Flutter/Dart) |
| Release / build / artifact | No release. Unsigned-for-distribution Release build side-loaded to one device for field review. Never submitted to App Store Connect. |
| Commit | `9127713`, branch `fix/five-tab-nav` (ahead of `main`, no PR) |
| Platforms / environments | iOS (primary, iPhone 15/iOS 27 test device); Android declared but unreleased and debug-signed; web builds but is not a target |
| Territories | India — Delhi NCR |
| Owner | **OWNER — to name** |
| Auditor | Claude (automated source review, 25 modules) |
| Independent reviewer | **OWNER — external review pending; this record is the input to it** |
| Audit date | 2026-08-03 |
| Decision date | **OWNER** |

## Outcome vocabulary in use

Pass · Warning · Fail · N/A, per the master document. **"Not tested is not N/A."** Where a
control could not be verified from source, it is graded Warning or Fail with the limitation
stated, or **BLOCKED-OWNER** where it needs access this audit does not have (App Store
Connect, Firebase console, production traffic, a physical Android device, legal or clinical
opinion).

## 1. Audit administration

| Control | Outcome | Evidence / rationale |
|---|---|---|
| MASTER-1.01 Identification | **Warning** | Everything above is recorded except owner, auditor-of-record and reviewer, which are the owner's to name. There is also no release artifact to identify — evidence is source, not a built release (see MASTER-4.04). |
| MASTER-1.02 Critical journeys listed and linked to requirements, tests, monitoring, support | **Fail** | No document in the repo names the critical user journeys. `docs/FEATURE_TRACKER.md` lists features, not journeys, and nothing links a journey to a test, a monitor, or a support path. There is no monitoring to link to (`logger.dart:63` is an unwired TODO; no analytics exist). The Product Requirements module is producing a candidate journey list for the owner to ratify. |
| MASTER-1.03 Applicable laws, store policies, contracts, sector rules, accessibility targets, risk tolerances identified with owners | **Fail** | Partially identified across audit reports (Apple Review Guidelines, WCAG 2.2 AA, DPDP Act 2023) but never assembled into a register, and no owner is named against any of them. No `PRIVACY_POLICY.md`, no `DATA_HANDLING.md`. The regulated-domain overlay (MASTER-3.11) had never been run before this round. |
| MASTER-1.04 Suite v2.0; template changes do not rewrite prior audit records | **Warning** | This round is v2.0. Round 4 writes to `docs/audits/round4/`; round 3 is at `docs/audits/round3/`; round 2 at `docs/audits/`; round 1 recoverable at commit `9c39dc1`. **Graded Warning, not Pass — corrected 2026-08-20.** Round 2 rewrote round 1's files in place. The control this item tests is *"prior audit records are not rewritten"*, and that control was broken once in this project's history. It has been fixed from round 3 onward and the original records are recoverable from git, which is why this is a Warning rather than a Fail — but a control with a known past breach is not a Pass, and grading it Pass because the breach was already disclosed in the same cell confuses *disclosed* with *clean*. An external auditor reading only the verdict column would have been misled. Requires a risk owner under MASTER-4.02, which MASTER-1.05 records as unavailable. |
| MASTER-1.05 Evidence storage, issue tracker, risk-acceptance authority, release decision authority named | **Fail** | None are named anywhere in the repo. There is no issue tracker referenced, no risk-acceptance authority, and no named release approver. This blocks MASTER-4.02 (every Warning needs an approving risk owner) as a matter of structure, not diligence. |

## 2. Always-required modules

All are activated and running in this round.

| Control | Module | Status |
|---|---|---|
| MASTER-2.01 | Product Requirements & UX Validation | Running (first audit) |
| MASTER-2.02 | Apple Design Framework | Running (4th) |
| MASTER-2.03 | Accessibility · Content & Localization | Running (4th) |
| MASTER-2.04 | Software Testing & Quality Verification | Running (4th) |
| MASTER-2.05 | Performance & Reliability · Security & Privacy · Documentation · CI/CD & Supply Chain | Running (CI/CD is a first audit) |
| MASTER-2.06 | Release & Store Submission · Platform & Device Lifecycle · Post-Launch Ops · Observability/Incident/Continuity | Running (Platform and Observability are first audits) |
| MASTER-2.07 | Upgrade Path — required for every release after first production distribution | Running. **Note:** there has been no production distribution, so this module is technically pre-triggered; it is run anyway because the local storage schema is being set NOW and is free to fix only until the first public build. |

## 3. Feature and risk triggers

| Control | Trigger | Applies | Rationale |
|---|---|---|---|
| MASTER-3.01 | Accounts, sign-in, sessions, roles, invitations, identity | **Yes** | Phone/OTP auth via Firebase; four roles in `permissions.dart`; family-member invitations; multiple patients per account. Note the auth gate is currently commented out at `main.dart`. |
| MASTER-3.02 | Payments, marketplace, external checkout | **Yes** | Razorpay checkout, cart, coupons, GST, EMI screen, invoices. Real-world services, so outside IAP. |
| MASTER-3.03 | UGC, chat, reviews, sharing | **Yes** | Patient↔care-team chat with photo attachments, equipment reviews, concern reports with evidence photos about **named staff**, staff ratings, PDF sharing. |
| MASTER-3.04 | Notifications, deep links, background work | **Yes** | FCM push, local medication reminders with snooze, notification routing. |
| MASTER-3.05 | AI/ML, agents, consequential automation | **Yes** | Sahayak assistant executes 11 actions including bookings and staff replacement; Claude Cloud Function; owner intends it to become the primary voice interface. |
| MASTER-3.06 | Analytics, telemetry beyond operations | **Yes** | No product analytics, but Firebase Performance + Crashlytics transmit off-device. Activated so the absence and the telemetry are both assessed — absence is not N/A. |
| MASTER-3.07 | Web, API, backend, worker, database, admin | **Yes** | Two backends (Firebase Functions + MySQL; Laravel + MySQL) plus an assistant Cloud Function. |
| MASTER-3.08 | Multiple devices or users share persisted state | **Yes** | One patient is shared by patient, primary contact, family members, and a separate staff app. |
| MASTER-3.09 | Files, media, imports, exports, attachments | **Yes** | Photo capture and upload from six screens, document repository, invoice and doctor-handover PDF export and sharing. |
| MASTER-3.10 | Personal data, backups, retention, portability | **Yes** | Health data throughout; DPDP Act 2023 applies. |
| MASTER-3.11 | **Regulated / high-impact use** | **Yes** | Health data; elderly and post-stroke patients; vitals colour-coded as normal/borderline/alert; a clinical handover document; medication scheduling; ambulance dispatch. **Specialist review required — this audit cannot substitute for clinical and legal opinion.** |
| MASTER-3.12 | Multiple locales, non-Latin input, international distribution | **Yes** | English + Hindi (Devanagari), bundled `NotoSansDevanagari`, 353 key pairs. |

**No trigger is N/A.** Every module in the suite applies to this app.

## 4. Gate evidence and findings

To be completed when all modules report. Preliminary positions:

| Control | Outcome | Evidence / rationale |
|---|---|---|
| MASTER-4.01 Each control has an outcome plus evidence; every N/A explains itself | Pending | Enforced by the round-4 brief. |
| MASTER-4.02 Every Warning has impact, ticket, owner, due date, compensating control, approving risk owner | **Fail (structural)** | No issue tracker, no named risk owner, no due-date process exists. Module reports supply impact and mitigation and mark `OWNER-TBD`; the remaining fields cannot be satisfied until MASTER-1.05 is. |
| MASTER-4.03 Every Fail is resolved and re-verified or formally blocks release; severity is not silently downgraded | Pending | Rounds 1→3 demonstrate the re-verification discipline: each round audited the previous round's fixes and found them insufficient (surfaces, then half-wires). No finding has been downgraded without evidence. |
| MASTER-4.04 Evidence from the release artifact and a production-like environment | **Fail** | **Material limitation, stated plainly.** All evidence is static source review. There is no production environment — `api.housepital.in` does not resolve. There is no release artifact — the app has never been built for distribution. Device evidence is limited to one side-loaded iPhone. No Android device was tested. |
| MASTER-4.05 Cross-checks reconcile data inventory, privacy policy, store labels, privacy manifest, permissions, analytics, SDK behaviour, actual network traffic | **Fail** | There is no privacy policy in the repo, no `PrivacyInfo.xcprivacy`, no store labels, and no network-traffic capture. A data inventory is being produced by the Data Lifecycle module — it did not previously exist. |
| MASTER-4.06 Open findings deduplicated and traceable across checklists | **Warning** | Findings are traceable per round and cross-referenced in each round's synthesis, and `docs/KNOWN_ISSUES.md` now carries the open set. They are not deduplicated into a single register with IDs. |

## 5. Final release decision

**Auditor recommendation: REJECT for public release. HOLD for continued internal field use.**

Justification, stated for an external reviewer:

1. **The app ships fabricated clinical data.** Every provider falls back to `DemoData`
   because no backend is reachable. Three rounds have improved how that is *labelled*; no
   round has *gated* it. There is no `DEMO_DATA` build flag.
2. **Several always-required modules have material Fails**, including MASTER-1.02
   (critical journeys), MASTER-1.05 (decision authority), MASTER-4.04 (evidence source)
   and MASTER-4.05 (privacy reconciliation).
3. **MASTER-3.11 requires specialist review that has not occurred.** No clinician or
   Indian healthcare lawyer has reviewed vitals classification, the handover document, or
   DPDP compliance.
4. Known release blockers carried into this round: undeployed Storage rules, Android debug
   keystore, disabled auth gate, no dSYM upload, no kill switch, a raster app icon, and a
   deletion request that reaches no server.

Continued **internal** field use is reasonable and is what the app is currently doing —
one device, the owner's own, with the sample-data notice visible.

| Field | Value |
|---|---|
| Overall result | **Reject** (public release) / **Hold** (internal use) — auditor recommendation |
| Release blockers | See each module's "Release blockers" section |
| Accepted risks and approver | White-on-orange 2.33:1; manpower pricing shown; floating pill nav. **Approver: OWNER — to sign** |
| Decision owner / signature / date | **OWNER** |
| Archived audit and evidence location | `docs/audits/` (round 2), `docs/audits/round3/`, `docs/audits/round4/`; round 1 at commit `9c39dc1`. Git history is the immutable archive. |

## Source baselines

Per the master document, reviewed 8 August 2026: Apple App Review Guidelines, Apple Human
Interface Guidelines, W3C WCAG 2.2, OWASP MASVS, NIST SSDF. This audit additionally applies
India's DPDP Act 2023 given MASTER-3.11.
