# UGC, Sharing & Trust Safety — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** UGC / Sharing / Trust & Safety (control family TRUST) ·
**Scope:** source review of `housepital_patient_app` @ `9127713` (branch `fix/five-tab-nav`),
plus `../housepital-backend` (Firebase Functions + MySQL) where the client's UGC endpoints
are supposed to land. See Limitations.

---

## Applicability

**MASTER-3.03 activates this checklist.** The checklist's own applicability clause is "any
app with UGC, profiles, chat, reviews, comments, public/shared media, creator content,
communities, or user-to-user interaction." This app has five of those:

| Surface | Where | Content type |
|---|---|---|
| Patient ↔ coordinator chat with photo attachments | `lib/screens/chat/chat_screen.dart` (Firestore `chat_messages/{patientId}/messages`, photos → Storage `chat/{patientId}/…`) | free text + user photographs |
| Concern / complaint with evidence photos | `lib/screens/support/raise_concern_screen.dart` → `POST /concerns` | 1,000-char free text + up to 3 photographs |
| Equipment reviews | `lib/screens/services/equipment_detail_screen.dart:1302-1381` → `GET/POST /equipment/:id/reviews` | star rating + uncapped free text, displayed to other users |
| Daily care rating of the staff on duty | `lib/screens/my_care/my_care_screen.dart:613`, `lib/screens/reports/daily_report_screen.dart:684` | 1–5 score + free-text comment |
| Staff replacement request | `lib/screens/support/staff_replacement_screen.dart` (reason list includes **"Behaviour"**) | categorical allegation + free text |
| Family-member addition | `lib/screens/settings/family_members_screen.dart` | third-party name/phone/email, and a grant of access to another person's health data |
| Doctor-handover PDF export | `lib/services/handover_report_service.dart:326` `Printing.sharePdf` | a clinical document leaving the app's trust boundary |

Not applicable: no public feed, no follower graph, no discovery/search of other users, no
creator monetisation, no ephemeral media, no live streaming. Controls that depend on those
are graded N/A **with** a rationale below; nothing is graded N/A merely because I did not
reach it.

### The finding that frames the whole report

**Most of this app's UGC is *about identifiable third parties* — the nurses and caretakers
working inside someone's home — and not one of those third parties has any voice in the
system.** A "Behaviour" complaint, a 1-star day, a photograph taken inside the home that
incidentally contains the worker's face: every one of these is recorded, and none of them
has a review step, a notice to the person described, a right of reply, an appeal, a
correction path, or a retention limit. Symmetrically, the *patient* has no way to report or
block a worker's conduct in-channel either — the chat is one-way-trusted by construction.

There is no moderation of any kind anywhere in this codebase. `grep -rin
"moderat\|abuse\|profanity\|report content\|block user"` across `lib/`, `assets/i18n/`,
`docs/` and the backend returns **zero** product hits. That absence is the report's central
Fail, and it is an absence by omission rather than by decision — I found no document,
comment, or ticket anywhere acknowledging it as a considered choice.

---

## Prior-round status

**No round-3 or round-2 report exists for this module.** `ls docs/audits/round3/` and
`ls docs/audits/*.md` list eleven modules; UGC / Trust & Safety is not among them. This is
the first look. I have therefore worked from the checklist rather than from prior findings,
and have deliberately re-derived facts (endpoint existence, rule deployment, call sites)
rather than importing them from adjacent reports.

Two carried items from the round-3 **known-open** list are load-bearing here and I verified
both rather than assuming: `storage.rules` undeployed (still true per its own header and
`docs/KNOWN_ISSUES.md`; live state is BLOCKED-OWNER) and the auth gate commented out
(confirmed — `lib/screens/splash_screen.dart:17` jumps straight to `/home`).

### Which round-3 pattern does this work fit?

Round 2 → 3 concluded the fixes were "half-wires — correct data structures with the
behaviour they enable left unwritten." **The UGC surface is the purest example of that
pattern in the repo, and it was never touched by rounds 1–3.** The `family_concerns` and
`daily_ratings` tables are fully modelled, with `deployment_id`, `status`, `assigned_to`,
`resolution_notes` and `resolution_satisfaction` columns
(`housepital-backend/sql/001_initial_schema.sql:359-399`) — a complete complaint-lifecycle
schema. The client sends no `deployment_id`, never reads a concern back, and two of the
three rating entry points post nothing at all. The structure for a fair process exists in
SQL; the process does not exist in software.

---

## Control results

### 1. Product boundaries and community rules

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **TRUST-1.01** Allowed / restricted / age-gated / prohibited content defined in plain language with examples and consistent enforcement scope | **Fail** | No community guidelines, content policy, or acceptable-use text exists in the repo. `grep -rn "report\|abuse\|block" assets/i18n/en.json` returns only "Daily **Report**s"-type matches — no trust-and-safety vocabulary in either locale. The only policy pointers are two external links, `lib/screens/settings/about_screen.dart:97-104` → `https://housepital.in/terms` and `https://housepital.in/privacy`, **and both fail TLS**: the apex certificate covers only `www.housepital.in` (`openssl s_client -connect housepital.in:443` → `subject=CN=www.housepital.in`, `SAN: DNS:www.housepital.in`; `curl https://housepital.in/privacy` → exit 60). Adding `www.` returns 200. `_launchUrl` (`about_screen.dart:166-177`) gates on `canLaunchUrl`, which succeeds for any `https:` URI, so the user is handed to Safari and shown a certificate interstitial, not a policy. | Users cannot read the terms they are held to; a reviewer checking Apple 1.2 / 5.1.1 hits a security warning. One-character fix (`www.`) but it must ship. Owner: OWNER-TBD. Due: before submission. |
| **TRUST-1.02** Product identifies public / private / group / direct / ephemeral / anonymous / searchable / exportable / externally shareable contexts | **Fail** | No surface tells the user its audience. Equipment reviews are published to every other user of that catalogue item and the compose sheet says only "Share your experience…" (`equipment_detail_screen.dart:1338`). The low-rating sheet claims text is "visible to your coordinator" (`my_care_screen.dart:659`) — that text is in fact **discarded** (see TRUST-3.05). Chat photos become Firebase `getDownloadURL()` tokens (`lib/services/firebase_service.dart:138`), i.e. bearer-capability URLs readable by anyone holding the link regardless of Storage rules, with no expiry and no revocation — the most externally-shareable context in the product, and it is nowhere disclosed. | The user cannot form a correct expectation about any post. Escalates every downstream control. |
| **TRUST-1.03** Risk assessment covers harassment, grooming, stalking, doxxing, hate, threats, sexual content, self-harm, fraud, spam, impersonation, IP abuse, coordinated manipulation | **Fail** | No such document exists. `docs/` contains 15 markdown files (`API_REFERENCE`, `BUSINESS_RULES`, `KNOWN_ISSUES`, …) and none names any of these risks. `docs/KNOWN_ISSUES.md` does not list a single trust-and-safety item. The one risk the product's own shape screams — a false or malicious allegation against a named home-care worker who is alone in a stranger's house — is unassessed. | The most likely serious harm in this product (a worker's livelihood ended by an unreviewed, unanswerable complaint; or a worker's misconduct with no in-app reporting channel for the family) has had no analysis. |
| **TRUST-1.04** Policies, terms, age rating, marketing, moderation capability, and actual product defaults agree | **Fail** | They actively disagree. (a) The client's permission matrix grants `raise_concern` to `FAMILY_MEMBER` and `CARETAKER` (`lib/utils/permissions.dart:57-70`); the backend rejects both — `POST /concerns` is wrapped in `requirePrimary` (`housepital-backend/functions/src/routes/concerns.ts:21`), as is `POST /ratings` (`ratings.ts:19`). A caretaker who is told in-app they may raise a concern receives a 403. (b) `lib/screens/reports/daily_report_screen.dart:727` tells the user "Rating submitted!" while submitting nothing. (c) `my_care_screen.dart:623` tells the user "We've shared your feedback with the team" after a `SharedPreferences.setInt` and no network call (`:613-617`). (d) `equipment_detail_screen.dart:1371` says "Thank you for your review!" after a swallowed failure against an endpoint that does not exist. Moderation capability claimed: none. Moderation capability present: none — the only agreement in the set. | Four user-facing claims are false as shipped. Two are about whether a complaint against a named worker was recorded. |

### 2. Safety by design

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **TRUST-2.01** Privacy/audience defaults minimise unintended exposure — especially minors, precise location, contacts, health, household information | **Fail** | The default and only behaviour for a concern photo is: upload to `concerns/{patientId}_{batchTs}/{i}_{filename}` (`raise_concern_screen.dart:330`) and mint a permanent public download URL. `storage.rules` states its own limitation in the file: *"It does NOT stop one authenticated user from reading another patient's photo if they can guess the path"* (`storage.rules:31-33`), and the concerns path packs two ids into one segment so no rule can scope it (`storage.rules:49-57`). These photos are, by the form's own framing, taken inside a home, of a patient and/or a worker. `chat/{patientId}/…` has the same read rule (`allow read: if isSignedIn()`, `storage.rules:75`). There is no consent step, no EXIF/location stripping (`ImagePicker` `maxWidth`/`imageQuality` re-encode but the plugin does not guarantee metadata removal, and nothing in `lib/` strips it), and no audience choice. | Household-interior imagery and worker likenesses are stored under guessable paths behind rules the repo itself documents as insufficient. Mitigation available today: none in-app. Owner: OWNER-TBD. |
| **TRUST-2.02** Users understand audience, persistence, forwarding/download/screenshot risk, location metadata, identity before posting/sharing | **Fail** | Nothing in the concern flow, the chat flow, or the review flow states who will see the content, for how long, or that it cannot be withdrawn. The one place the app does this well is the handover PDF, which stamps its own face: `handover_report_service.dart:103-105` and the red header band at `:333-345` ("SAMPLE DATA - NOT A CLINICAL RECORD…"), with an explicit code comment that "an in-app banner cannot travel with a PDF". That reasoning is correct and is applied to exactly one artifact. **The same argument applies verbatim to a photograph of a care worker leaving the device, and is applied nowhere.** | Users share evidence photographs of an identifiable person without being told the sharing is permanent and irrevocable. |
| **TRUST-2.03** Invitation, discovery, recommendation, contact sync, nearby, search resist unwanted contact and enumeration | **Warning** | The only invitation surface is `family_members_screen.dart`. It is **entirely local mock state**: `_mockMembers` (`:22-42`), `setState(() => _members.add(newMember))` (`:245`), and no API call — the backend's `POST /patients/:id/family/invite` (`housepital-backend/functions/src/routes/family.ts:103`) is never called from `lib/` (`grep -rn "family/invite" lib/` → no hits), and the backend handler itself is a stub that sends nothing (`family.ts:117-118`: *"In production, send an SMS/WhatsApp invite… For now, just record the invitation"*). No enumeration or unwanted-contact vector exists **today because the feature does not function**. But the design as written adds a third party by phone number, with no verification and no consent from that person, and switches on notifications about someone else's vitals by default (`notifyVitals = true`, `:77`). There is no user discovery or search anywhere in the app (verified: no user-search endpoint, no contact-sync permission in `ios/Runner/Info.plist`). | Impact: low today (non-functional), high on wiring. Mitigation: require the invitee to confirm before any health notification flows. Owner: OWNER-TBD. Ticket: TBD. |
| **TRUST-2.04** Rate, trust, friction, reputation controls limit spam, mass messaging, scraping, account farming, repeated abuse | **Fail** | No rate limiting exists on any UGC path in the client. Chat: `_sendMessage` (`chat_screen.dart:78-91`) is an unguarded `_messagesRef.add` on every tap — no debounce, no cooldown, no client cap, and no `try`/`catch`, so a Firestore rejection (e.g. the rules' `text.size() < 5000` cap, `firestore.rules:75`, which the client never enforces — the `TextField` at `:312-329` has no `maxLength`) surfaces as an uncaught async exception with the input box left uncleared. Equipment reviews: unlimited submissions per item per user, no purchase check, no length cap (`equipment_detail_screen.dart:1330-1334`, `maxLines: 4` is visual only). The **only** rate control in the entire UGC surface lives in the backend and is unreachable: `daily_ratings` has `UNIQUE KEY uk_deployment_rater_date` and `ratings.ts:35-45` returns 409 on a second rating the same day. | An unbounded write path into Firestore and Storage, authenticated-only, with the app's auth gate disabled. Cost and abuse exposure both uncapped. |
| **TRUST-2.05** High-risk features have staged rollout, age/identity controls, safety metrics, rapid disable, trained response ownership | **Fail** | No feature flags for any UGC surface (`grep -rn "featureFlag\|remoteConfig\|kill.?switch" lib/` → no hits; the app has no Remote Config dependency in `pubspec.yaml`). Complaints against named workers, photo upload, and published reviews all ship on, for everyone, with no way to disable any of them without a store release. No safety metric is emitted anywhere. `DemoMode` — the app's one runtime-honesty mechanism — has **no source constant for any UGC surface**: `lib/data/demo_mode.dart:23-34` lists twelve sources and none covers staff profiles, equipment reviews, or concerns, so the demo-notice pill stays *down* while the app shows fabricated content (see TRUST-3.01). | No containment. If a review surface is abused post-launch the only remedy is an App Store submission. |

### 3. Content controls and moderation

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **TRUST-3.01** Proactive filters/classifiers with documented scope, thresholds, languages, FP/FN risk, human review, appeal behaviour | **Fail** | **There is no filter, classifier, wordlist, or human review step anywhere.** `lib/utils/validators.dart:113-125` is the entire content-inspection layer: presence and a 1,000-character cap. Nothing inspects what a concern says, and nothing inspects it before it is recorded against a care assignment. Worse, the surfaces that *display* content about named workers are populated with fabricated content that the app presents as genuine: `lib/screens/support/staff_profile_screen.dart:42-129` catches any profile-fetch failure and substitutes a hardcoded profile carrying `'rating': 4.8`, `'total_reviews': 142`, `'police_verified': true`, `'id_verified': true`, four "verified" Aadhaar/police/training/medical documents, and four named reviews ("Ramesh K.", "Suresh G.", "Anita S.", "Vikram P."). `equipment_detail_screen.dart:177-200` does the same with three invented reviews ("Rajesh K.", "Priya M.", "Suresh P."). Neither path calls `DemoMode.markServingDemoData`, so no notice appears. Since `api.housepital.in` does not resolve (`host api.housepital.in` → NXDOMAIN), **this fallback is the shipping behaviour, not an edge case.** | A family decides whether to admit a stranger into their home partly on "Police Verification — verified" and a 4.8/142-review score that the app invented locally. This is the single most consequential trust defect I found. Fabricated user reviews also breach App Review Guideline 1.2 / 3.2.2(vi). |
| **TRUST-3.02** Moderation tools expose sufficient context and history without granting unnecessary access to private/sensitive data | **Fail** | No moderation tool exists in scope. The nearest analogue — the coordinator's view of a concern — is not built here, but the data model hands it more than it needs and less than it can act on: `family_concerns` stores the raw description and `evidence_urls` as permanent public URLs (`sql/001_initial_schema.sql:359-380`) with no field-level access control, while `deployment_id` (the only link to *which worker the complaint is about*) is nullable and **never populated by the client** (`api_service.dart:476-495` sends `patient_id`, `category`, `description`, `urgency`, `preferred_resolution`, `evidence_urls` — no deployment, no staff id). | Any reviewer gets the photographs and the narrative; nobody gets a reliable, structured link to the person accused, so the accusation is resolved by human inference over free text. Both halves of the control fail in opposite directions. |
| **TRUST-3.03** Priority queues and escalation for imminent harm, child safety, credible threats, NCII, legal requests | **Fail** | The app collects an urgency signal and promises against it: `raise_concern_screen.dart:381-385` promises a 2-hour response for `emergency`, 12 hours for `high`, 24–72 hours otherwise. Nothing routes on it. The value is a plain column (`family_concerns.urgency`, `sql/001_initial_schema.sql:367`); `concerns.ts:38-51` inserts it and returns 201; there is no notification, no paging, no queue, no on-call. `medical_concern` — "मरीज़ की तबियत", i.e. *the patient's condition* (`raise_concern_screen.dart:41`) — is an ordinary dropdown row with no clinical escalation, and the same screen is the fallback destination for a failed SOS path (`lib/screens/sos/sos_screen.dart:84,193`). The one honest thing here: the SLA text is generated client-side and shown after a 201, so it does not depend on a queue that does not exist — it simply is not true. | A family reporting "Emergency — patient's condition" is told help comes in 2 hours by a system with no mechanism to deliver it. Release-blocking on its own. |
| **TRUST-3.04** Moderator actions authorised, attributable, reason-coded, auditable, quality-reviewed, protected from insider abuse | **Fail** | No moderator role, no action log, no audit trail. `firestore.rules:148-153` explicitly notes `audit_logs/{logId}` as a TODO that is "still to model". `family_concerns` has `assigned_to VARCHAR(255)` and `resolution_notes` (`sql:371-372`) — free-text, unattributed, unversioned, with no record of who changed a status or why. Chat is unauditable in the other direction too: `firestore.rules:76-77` sets `allow update, delete: if false` for messages, which is a good append-only property, but the backend service account bypasses rules entirely (`firestore.rules:58-59`), so the operator side has silent, unlogged write access to the record. | Insider modification of a complaint record — or of a worker's rating — is undetectable. |
| **TRUST-3.05** Removed/restricted content cannot trivially reappear via alternate format, account, share link, cache, recommendation, or sync resurrection | **Fail** | Nothing can be removed, so nothing can be *kept* removed. Concrete resurrection vectors: (a) Firebase `getDownloadURL()` tokens (`firebase_service.dart:138`) are unauthenticated bearer URLs — deleting the Firestore message or the MySQL row leaves the photo reachable forever by anyone who saw the link. (b) `equipment_detail_screen.dart:1356-1369`: the POST failure is swallowed by `catch (_) { /* Silently handle — review will appear on next load */ }` and the review is inserted into local state anyway, so a review that was *never accepted by any server* is displayed to the author as published. (c) The reverse of resurrection, equally bad: `my_care_screen.dart:668-676` pushes `/raise-concern` with `{'rating', 'preFilledNote', 'source'}`, and `lib/main.dart:465-467` constructs `const RaiseConcernScreen()` — the route takes no arguments and `RaiseConcernScreen` never reads `ModalRoute.of(context)!.settings.arguments` (verified: zero `ModalRoute` references in the file). `sos_screen.dart:189` even documents this: *"/raise-concern accepts no args today"*. **A user who types what went wrong into "What went wrong?" and taps "Send to coordinator" has that text silently deleted and lands on an empty form.** | Content the user believes is published is not; content the user believes was sent was destroyed; content that exists cannot be deleted. All three failure modes at once. |

### 4. Reporting, blocking, and user controls

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **TRUST-4.01** Users can report content, accounts, messages, transactions, safety incidents from relevant context, with category and evidence | **Fail** | **There is no report control anywhere in the app.** No "Report" affordance on a chat message, on an equipment review, on a staff profile, or on any other surface (`grep -rn "report" assets/i18n/en.json` yields only care-report strings; no `Icons.flag`, no `Icons.report` in any UGC screen). The concern form is the closest thing and it is a *service complaint funnel*, not a safety report: its eight categories (`raise_concern_screen.dart:36-45`) are behaviour / not-following-routine / absent / replacement / medical / payment / quality / other. There is no category for harassment, theft, assault, or abuse of the patient — the incidents a home-care app most needs a channel for. The absence is the finding, exactly as the brief anticipated. | A family whose elderly relative is being mistreated by a worker in their home has no in-app path that names the harm. They can file "Staff behaviour", which is routed identically to a billing query. Release-blocking. |
| **TRUST-4.02** Reports get acknowledgement, severity-appropriate response, status/closure communication, urgent safety guidance | **Fail** | Acknowledgement exists and is the only part that does: an `AlertDialog` with the SLA text (`raise_concern_screen.dart:387-405`). After that the concern is invisible. `getConcerns` is defined in `i_api_service.dart:151` and implemented at `api_service.dart:496-502` and is called from **nowhere** — `grep -rn "getConcerns" lib/` returns only the interface and the implementation. There is no "My concerns" screen, no ticket id shown to the user (the returned `FamilyConcern.id` is discarded), and no status surface, despite the schema modelling a full seven-state lifecycle (`received → acknowledged → investigating → in_progress → resolved → escalated → closed`, `sql:369`). No urgent safety guidance is shown for any urgency level — an `emergency` submission gets the same dialog with different text. | The user cannot tell whether anything happened. There is no evidence trail they can cite. |
| **TRUST-4.03** Blocking prevents expected contact, visibility, recommendation, invitation, and notification paths without unnecessarily revealing the block | **Fail** | No block exists in any direction. A patient cannot block a worker; a worker has no account here at all. The nearest lever is `staff_replacement_screen.dart` — which posts to `POST /deployments/:id/replacement` (`api_service.dart:846`), an endpoint that **does not exist**: `deployments.ts` defines exactly two routes, both `GET` (`router.get` at `:11` and `:245`). So the one control a family has to end contact with a specific worker is wired to a 404, and `_submitRequest` (`staff_replacement_screen.dart:184-215`) shows "Request Submitted — We'll assign a new professional within 24 hours" on the success path only; the `catch` is a snackbar, so in demo mode the user sees an error they cannot distinguish from a network blip. Note the reason list includes "Behaviour" (`:33-39`) — an allegation with employment consequences, submitted to a non-existent endpoint. | The family's only removal mechanism is non-functional. In a product where the "content" is a person in your house, blocking is not a social nicety — it is the safety control. |
| **TRUST-4.04** Mute, restrict, leave, revoke, remove-follower/member, privacy, download, comment, message controls work across devices and surfaces | **Fail** | Users cannot delete their own chat messages (`firestore.rules:76-77`, `allow update, delete: if false`) or their own photos (`storage.rules:78,84`, `allow update, delete: if false`). They cannot edit or withdraw a concern (no endpoint), or delete an equipment review (no endpoint). Removing a family member mutates local state only (`family_members_screen.dart:63-69`) and never calls the backend's `POST /patients/:id/family/:memberId/remove` (`family.ts:193`) — so on a second device, or after reinstall, the removed member is back. Notification preferences captured in the add sheet (`:186-215`) are written into a local object and dropped. The append-only chat design is defensible as a clinical record; shipping it with **no** user-facing deletion path and no stated retention period is not. | Nothing a user does to withdraw their own content works, and one thing (family removal) appears to work and does not — the worst variant. |
| **TRUST-4.05** Published contact information and an accessible support route exist for safety concerns | **Warning** | A real route exists: `AppConstants.supportPhone = '9990911911'` (`lib/config/constants.dart:19`), used on the payment-failure and SOS paths, and `wecare@housepital.in` in `help_faq_screen.dart:157`. That is more than most of this checklist found. But it is a general support line, not a published safety-report contact; it is not surfaced from any UGC screen; and the two links that would carry the legal contact and grievance-officer details required by the DPDP Rules 2025 are the broken apex-domain URLs from TRUST-1.01. | Impact: a user with a safety emergency can reach a human by phone, which materially limits the harm from TRUST-4.01/4.02. Mitigation: fix the `www.` URLs and add the safety/grievance contact to the concern screen. Owner: OWNER-TBD. Due: before submission. Approver: OWNER-TBD. |

### 5. Age assurance and child safety

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **TRUST-5.01** Age rating, minimum age, parental controls, age declaration/assurance, child-data handling, content access align by territory and platform | **BLOCKED-OWNER** | I can establish the client side: there is no age gate, no date-of-birth capture at signup, and no minimum-age declaration anywhere (`lib/screens/auth/` contains `otp_screen.dart` and `onboarding_screen.dart`; neither collects age — and the auth flow is bypassed entirely, `splash_screen.dart:17`). The patient's age *is* collected as clinical data, but the *account holder's* age is not. The App Store age rating and the declared "Made for Kids" status live in App Store Connect, which I cannot read. Under the India DPDP Rules 2025, verifiable parental consent for a data principal under 18 is a live obligation and nothing in the repo addresses it. | Needs: App Store Connect age-rating questionnaire; a documented decision on DPDP §9 (children's data) for the account holder. Not gradeable from source. |
| **TRUST-5.02** Minor accounts use protective defaults for discovery, messaging, location, personalisation, purchase, public sharing | **Fail** | There is no concept of a minor account, so no protective default can apply — and this is *not* N/A, because the product genuinely admits minors: the family-member sheet offers "Son", "Daughter", "Sibling" with no age field (`family_members_screen.dart:163-171`), and any such member, at any age, would receive vitals and daily-report notifications about a relative's health and can open the chat and the concern form. Purchases are role-gated (`permissions.dart:57-63`, `FAMILY_MEMBER` lacks `pay`) — the one protective default present, and it is a role default, not an age one. | A 14-year-old added as "Son" gets the same messaging, photo-upload, and health-data access as an adult. |
| **TRUST-5.03** Adults cannot exploit age, role, family, school, or creator mechanisms to gain inappropriate access to minors | **Warning** | No user-to-user contact graph exists: chat is a single fixed thread to a Housepital coordinator (`main.dart:638-651`, `patientId` + `coordinatorName` only), there is no DM between users, no discovery, no profile browsing. The exploitation surface is therefore small. What remains: the primary contact can unilaterally add any phone number as a "family member" with health-data notifications and no consent from that person (TRUST-2.03), and the app has no age signal to protect anyone with. The patient may themselves be a minor (paediatric home care is not excluded by anything in `catalog_seeds.dart`), and `PATIENT_SELF` can export the full handover PDF (`permissions.dart:64-67`). | Impact: contained by architecture, not by design intent. Mitigation: consent-on-invite plus an age field before the family feature is wired. Owner: OWNER-TBD. |
| **TRUST-5.04** Parental consent/control does not expose a child to coercion, surveillance, or unsafe account recovery | **Warning** | The app has no parental-control feature, so the classic vector is absent — but the product *is* a household surveillance surface (vitals, attendance, daily reports, staff check-in photos) whose access is granted by one person to others with no notice to the subject. The patient — the person under observation — has `PATIENT_SELF: {view, share_handover}` (`permissions.dart:64-67`) and therefore **cannot see or change who is watching them**: `manage_family` is primary-contact only, and the family list screen hides only the FAB (`family_members_screen.dart:270-279`) while still rendering the roster. Account recovery is OTP-to-phone with a 30-second client cooldown; if the phone is controlled by a family member, so is the account. | Impact: a dependent adult or minor patient cannot audit or revoke observation of themselves. Mitigation: expose the watcher list to `PATIENT_SELF` with a revoke path. Owner: OWNER-TBD. |
| **TRUST-5.05** Child-safety escalation, preservation, reporting, specialist contacts established before launch where applicable | **Fail** | Nothing exists. No escalation path, no preservation policy, no specialist contact, and — per TRUST-3.03 — no escalation mechanism of any kind to hang one on. "Where applicable" applies: paediatric patients and minor family members are both reachable states of this product, and Indian POCSO/child-welfare reporting duties would attach to a credible in-home abuse report. Not N/A: unaddressed is not inapplicable. | If a family reports child abuse by a worker through the only channel available ("Staff behaviour", free text), it lands in an unmonitored MySQL table with a 24–72 hour promise. |

### 6. Enforcement, appeals, and transparency

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **TRUST-6.01** Warnings, content limits, feature restrictions, suspension, termination have proportional criteria and consistent consequences | **Fail** | No enforcement ladder exists against users. Against *workers* — the people this app's UGC is about — the schema implies one and the criteria are unwritten: `family_concerns.preferred_resolution` lets the complainant select **"Counseling of staff"** or **"Replacement"** (`raise_concern_screen.dart:186-188`), i.e. the reporting party proposes the sanction, and `daily_ratings` accumulates scores against a `deployment_id` with no floor, no context, and no threshold policy. `staff.total_reviews` / `staff.rating` are surfaced to prospective families (`housepital-backend/functions/src/routes/staff.ts:63`). Nothing in the repo defines what a rating or a complaint *does* to a worker. | Sanction-by-customer-request with no stated criteria is the definition of disproportionate. |
| **TRUST-6.02** Users receive understandable reason, affected scope, duration, relevant policy, appeal route, and data/export access where safe and permitted | **Fail** | Read in the direction that matters here — the *subject* of the content — this is absolute: a worker is never told a complaint was filed, never sees its text or its photographs, is never given a policy, a scope, a duration, or an appeal route. Read in the ordinary direction it also fails: no user is told the outcome of anything they filed (TRUST-4.02), and no export of one's own UGC exists (`grep -rn "export.*data\|data portability" lib/` → no hits; the handover PDF is clinical data, not UGC). The deletion flow is the one honest artifact in this area — `delete_account_screen.dart:146-166` deliberately separates what is *done* from what is *requested* and issues a reference id — and it still does not delete a single chat message, storage photo, or concern row. | No natural-justice process for the person whose livelihood the content affects. |
| **TRUST-6.03** Appeals are independent enough to correct mistakes, time-bound, accessible, localised, protected from retaliation | **Fail** | There is no appeal mechanism for anyone. `resolution_satisfaction` (`sql:373`) lets the *complainant* grade the resolution; the accused has no field, no endpoint, and no client. Independence is structurally impossible: the entity that receives the complaint, employs the worker, and decides the outcome is the same entity, with no separation modelled anywhere. Retaliation protection is not addressed — a worker who learns a family complained has no protected channel, and the family who complained is not protected either, since the same worker may return the next day (replacement is a 404, TRUST-4.03). | Both parties are unprotected. This is the control the brief's framing points at most directly, and it is empty. |
| **TRUST-6.04** Transparency reporting and regulator/store responses producible from reliable, privacy-safe records | **Fail** | Not producible. There is no report volume to count (no reporting feature), no enforcement actions logged (TRUST-3.04), no `audit_logs` table (`firestore.rules:148-153` marks it TODO), and the two data stores that do hold UGC disagree with each other and with the client. Concretely, **the writes as coded would fail**: `concerns.ts:38-51` inserts a `family_member_id` column into `family_concerns`, whose schema names that column `raised_by` (`sql:362`); `ratings.ts:50-58` inserts `family_member_id` into `daily_ratings`, whose column is `rated_by` (`sql:388`), and omits `date DATE NOT NULL` (`sql:389`) which has no default. Both inserts would throw on a real MySQL instance. | Even the underlying record layer is not reliable, so no honest transparency figure could be produced. Also blocks any DPDP grievance-response obligation. |

### 7. Operations and responder safety

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **TRUST-7.01** Moderation coverage, response targets, languages, surge plans, vendor oversight, quality metrics, after-hours escalation match product risk | **Fail** | Response targets are *published to users* (2h / 12h / 24–72h, `raise_concern_screen.dart:381-385`) with no coverage behind them: no queue, no rota, no notification to any operator, no after-hours path (TRUST-3.03). Languages: the concern categories are bilingual EN/HI (`:37-44`) and the assistant is Hinglish — good — but there is no evidence of Hindi-capable review, because there is no review. `docs/` contains no operations runbook for concerns; `docs/POST_LAUNCH_OPS_AUDIT.md` (round 2) does not mention them. | A published SLA with no operational backing is a commitment the business will breach on day one, in writing, in the app. |
| **TRUST-7.02** Responder access, training, psychological safety, rotation, exposure minimisation, support addressed for disturbing content | **Fail** | Unaddressed. Coordinators will receive photographs taken inside homes of unwell and elderly people, uploaded under a "medical concern" or "staff behaviour" category — foreseeably distressing material. There is no exposure-minimisation mechanism (no blur-by-default, no content warning on the photo, no thumbnail-first pattern), no rotation policy, and no support documented. Exposure is instead *maximised* by the permanent public download URLs. Not N/A: the operator-facing app is a separate repo, but the exposure is created by this client's design and by these Storage rules. | An identified operational-safety gap with no owner. |
| **TRUST-7.03** Safety incidents have evidence preservation, law-enforcement/legal review, user communication, post-incident improvement paths | **Warning** | Preservation is accidental but real and is the strongest thing in this section: chat is append-only by rule (`firestore.rules:76-77`), storage objects are immutable (`storage.rules:78,84`), and `family_concerns` rows are never deleted by any code path. So evidence would survive. Everything built on top is missing: no legal-hold concept, no law-enforcement request process, no user communication path (TRUST-4.02), and no post-incident review. And preservation-by-accident has a cost — it is indistinguishable from indefinite retention with no policy (see below). | Impact: evidence exists but nobody is designated to act on it. Mitigation: name an incident owner and write the LE-request process before launch. Owner: OWNER-TBD. |
| **TRUST-7.04** Metrics detect prevalence, reporting, response, recurrence, evasion, false enforcement, appeals, disproportionate impact — without incentivising superficial closure | **Fail** | No analytics or safety telemetry of any kind is wired for UGC. `lib/utils/logger.dart` is local logging (and carries the round-3 unwired TODO at `:63`); there is no analytics SDK in `pubspec.yaml` for these events. Nothing counts concerns, ratings, response times, or repeat complaints against the same deployment — even though `daily_ratings.deployment_id` and `family_concerns.deployment_id` are exactly the keys that would reveal both a genuinely unsafe worker and a family filing disproportionate complaints. The one metric that *is* surfaced is the one most vulnerable to superficial closure: `resolution_satisfaction`, graded by the complainant. | Neither a pattern of harm nor a pattern of false accusation is detectable. |

### Cross-cutting: retention of user content

Assessed under TRUST-2.01 / 4.04 / 7.03; recorded here because the brief asks directly and
because no single control owns it.

**There is no retention policy for any user-generated content in this product.** Not a
short one, not a long one — none, in code, in schema, or in documentation.

- **Chat messages**: `chat_messages/{patientId}/messages`, no TTL, no Firestore TTL policy
  in `firestore.indexes.json`, `allow update, delete: if false` (`firestore.rules:76-77`).
  Retained indefinitely.
- **Chat and concern photographs**: Firebase Storage, immutable, plus permanent
  unauthenticated download URLs (`firebase_service.dart:138`). Retained indefinitely and
  reachable by link even if the referencing row is deleted.
- **Concerns**: `family_concerns` has `created_at` and `resolved_at` and no expiry;
  `ON DELETE CASCADE` from `patients` is the only removal path, and nothing in the app
  deletes a patient.
- **Ratings**: `daily_ratings`, same.
- **Account deletion** does not touch any of the above: `delete_account_screen.dart:100-166`
  records a request locally, attempts `FirebaseAuth.currentUser.delete()`, wipes device
  state via `SessionScope.clearSession`, and shows a reference number. There is no
  server-side erasure endpoint (`grep -n "_delete" lib/services/api_service.dart` → the only
  DELETE call in the whole client is `deleteMedication`, `:770-773`).

`help_faq_screen.dart:157` tells users "Account deletion is processed within 7 working days
as per our data retention policy." **No such policy exists in this repository**, and the
link where a user would read it is the broken apex URL from TRUST-1.01. Under the India
DPDP Rules 2025 — a named source baseline of this checklist — erasure on withdrawal of
consent and defined retention periods are obligations, not aspirations.

### Cross-cutting: `Printing.sharePdf` and the handover document

The brief asks specifically about this. It is, unusually, the surface I would defend.

`handover_report_service.dart:326` hands a generated PDF to the OS share sheet, from which
it can go to WhatsApp, mail, a printer, or any installed app — an unbounded exfiltration of
a clinical summary, and the app cannot govern what happens next. Three mitigations are
genuinely in place:

1. **Role gating is real and correctly reasoned.** `shareHandover` is denied to
   `CARETAKER` (`permissions.dart:65-68`) — hired staff cannot export the patient's medical
   history — and every call site checks it (`my_care_screen.dart:168`,
   `medications_screen.dart:60`, `medication_schedule_screen.dart:50-52`). Three call sites,
   three gates, no bypass.
2. **The document self-declares.** `handover_report_service.dart:333-345` prints a red
   header band on every page: "SAMPLE DATA - NOT A CLINICAL RECORD… Do not use it for
   clinical decisions," with the code comment (`:103-105`) explaining that an in-app banner
   cannot travel with a PDF. It also raises `DemoMode.sourceHandover`. This is the correct
   instinct, correctly executed.
3. **Determinism.** Filename and content share one injected `DateTime` (`:314-320`), so a
   share at 23:59 cannot mislabel its own contents.

What is missing: **no consent or awareness step before the share sheet opens** — `_share()`
(`my_care_screen.dart:466-479`) goes straight to the OS sheet with no "this leaves the app
and cannot be recalled" confirmation, which is exactly the disclosure TRUST-2.02 requires
and which the PDF's own header proves the team knows how to write. And the document names
the staff on duty (`:115`, `DemoData.icuServiceDetail.staffOnDuty`), so a third party's
name and role travel in it with no notice to them. **Warning**, not Fail: the two highest
risks (staff self-export, silent fabrication) are both closed.

---

## Scorecard

| Outcome | Count |
|---|---|
| **Pass** | **0** |
| **Warning** | **5** (TRUST-2.03, 4.05, 5.03, 5.04, 7.03) |
| **Fail** | **26** |
| **N/A** | **0** |
| **BLOCKED-OWNER** | **1** (TRUST-5.01) |
| **Total controls** | **32** |

Plus one cross-cutting **Warning** on `Printing.sharePdf` (not a numbered control;
assessed under TRUST-2.02, which fails on other grounds).

No control passed. I looked hard for one and the closest candidates —
append-only chat, the role gate on handover export, the honest deletion dialog — are each
one component of a control whose other components are absent.

---

## Release blockers (every Fail)

All 26 Fails block release under the checklist's release rule. Ranked by the harm they
enable, the ones that should be fixed or formally accepted first:

1. **TRUST-3.01 — fabricated verification and reviews about named workers.**
   `staff_profile_screen.dart:42-129` invents `police_verified: true`, `id_verified: true`,
   four "verified" identity documents, a 4.8 rating over 142 reviews, and four named
   testimonials whenever the profile fetch fails — which, with `api.housepital.in`
   NXDOMAIN, is always. Families use this to decide whether to let a stranger into the
   house. `equipment_detail_screen.dart:177-200` does the same for product reviews.
   Neither raises `DemoMode`, so no notice shows.
2. **TRUST-4.01 — no report path for abuse, in either direction.** No report control on any
   surface; the concern form has no harassment/theft/assault/abuse category.
3. **TRUST-3.03 — published SLA with no escalation behind it.** 2 hours promised for
   "Emergency", including "medical concern — मरीज़ की तबियत", routed nowhere.
4. **TRUST-6.03 / 6.02 — no right of reply or appeal for the person the content is about.**
   A worker is never notified, never shown the allegation or its photographs, and has no
   route to contest it. `resolution_satisfaction` is graded by the complainant.
5. **TRUST-3.05 — the low-rating free text is silently destroyed.**
   `my_care_screen.dart:668-676` passes `preFilledNote`; `main.dart:465-467` builds
   `const RaiseConcernScreen()` and the screen never reads route arguments. The user is told
   the text is "visible to your coordinator" (`:659`) and taps "Send to coordinator".
6. **TRUST-4.03 — the only removal control is wired to a 404.**
   `POST /deployments/:id/replacement` does not exist; `deployments.ts` has two GET routes.
7. **TRUST-1.04 — three false success messages.** "Rating submitted!"
   (`daily_report_screen.dart:727`, submits nothing), "We've shared your feedback with the
   team" (`my_care_screen.dart:623`, `SharedPreferences` only), "Thank you for your review!"
   (`equipment_detail_screen.dart:1371`, after `catch (_)` on a non-existent endpoint).
8. **TRUST-1.01 — Terms and Privacy links fail TLS.** `https://housepital.in/{terms,privacy}`
   → cert covers `www.` only; `https://www.housepital.in/privacy` → 200. One-word fix.
9. **TRUST-6.04 — backend UGC writes would throw.** `family_member_id` vs `raised_by`
   (`concerns.ts:41` / `sql:362`); `family_member_id` vs `rated_by` and a missing
   `date NOT NULL` (`ratings.ts:53` / `sql:388-389`).
10. **TRUST-2.01 / 4.04 — indefinite retention with no erasure path**, over permanent
    unauthenticated photo URLs, while `help_faq_screen.dart:157` cites a retention policy
    that does not exist.

## Warnings requiring risk acceptance

| # | Control | Impact | Mitigation | Owner | Due | Approver |
|---|---|---|---|---|---|---|
| W-1 | TRUST-2.03 | Family invitation adds a third party by phone with no consent and health notifications on by default | Non-functional today (local mock, `family_members_screen.dart:245`); require invitee confirmation before wiring | OWNER-TBD | before the family feature is wired to the backend | OWNER-TBD |
| W-2 | TRUST-4.05 | Support phone/email exist but no published *safety* contact, and the policy links are broken | Fix `www.` URLs; surface the grievance contact on the concern screen | OWNER-TBD | before submission | OWNER-TBD |
| W-3 | TRUST-5.03 | No age signal anywhere; primary contact grants minors adult-level access | Add an age field to the family sheet; keep purchase gating | OWNER-TBD | before the family feature is wired | OWNER-TBD |
| W-4 | TRUST-5.04 | `PATIENT_SELF` cannot see or revoke who is observing them | Expose the watcher roster with a revoke path to `PATIENT_SELF` | OWNER-TBD | v1.1 | OWNER-TBD |
| W-5 | TRUST-7.03 | Evidence is preserved by accident; no incident owner, no LE-request process | Name an incident owner; write the preservation/LE runbook | OWNER-TBD | before launch | OWNER-TBD |
| W-6 | `Printing.sharePdf` | Clinical PDF naming staff leaves the trust boundary with no pre-share consent step | Add a one-tap "this leaves the app and cannot be recalled" confirmation | OWNER-TBD | v1.1 | OWNER-TBD |

## BLOCKED-OWNER — needs access I do not have

| # | Item | Where it lives | Why it blocks |
|---|---|---|---|
| B-1 | **TRUST-5.01** — App Store age rating, minimum-age declaration, Kids Category status | App Store Connect | Cannot be read from source; determines whether TRUST-5.02/5.03 obligations bind harder |
| B-2 | Live Firebase **Storage** rules | Firebase Console → Storage → Rules | `storage.rules` is undeployed per its own header (`:8`) and `docs/KNOWN_ISSUES.md`; the live rule governing every concern-evidence and chat photo is unknown. If the bucket still carries a permissive default, every photograph of a patient's home and a worker's face is broadly readable. **Verify before launch.** |
| B-3 | Live Firebase **Firestore** rules | Firebase Console → Firestore → Rules | `firestore.rules` claims deployment on 2026-05-28 (`:20-24`) but the repo cannot prove the live state; the chat append-only and per-patient scoping claims in this report rest on it |
| B-4 | Whether any human process reviews concerns, and its SLA | Housepital operations | The 2h/12h/24–72h promise at `raise_concern_screen.dart:381-385` may be met by an out-of-band process I cannot see. Nothing in either repo routes to one. |
| B-5 | Existence of a written retention/erasure policy and a DPDP grievance officer | housepital.in / company records | `help_faq_screen.dart:157` asserts a policy; no copy exists in the repo |

## Limitations of this audit

- **This is a source review.** Per MASTER-4.04, evidence should come from the release
  artifact in a production-like environment. I audited `9127713` on disk plus
  `../housepital-backend`. I did not build, install, or run the app, and per the brief did
  not run `flutter test` / `flutter build`. Runtime behaviour — what a real Firestore
  rejection looks like to a user, whether a Storage upload actually succeeds against the
  live bucket — is inferred from code, and is labelled as such throughout.
- **Live cloud configuration is out of reach** (B-2, B-3). Several verdicts state what the
  repo's rules *would* enforce if deployed; where the live state changes the verdict I have
  said so rather than assuming the repo is authoritative.
- **The staff-side app (`../housepital_staff_app`) and the Laravel API
  (`../housepital-api`) were not audited.** A worker-facing notification or reply channel
  could exist there. I checked that the patient app and `housepital-backend` contain no such
  path; I did not exhaustively read the staff repo, so "the worker is never notified" is
  established for these two codebases and is unverified for the third. This is the single
  most consequential limitation in the report and I flag it rather than soften the finding.
- **Network checks were run on 2026-08-03** from this machine: `host api.housepital.in` →
  NXDOMAIN; `curl https://housepital.in/privacy` → curl 60 (cert mismatch);
  `curl https://www.housepital.in/privacy` → 200;
  `openssl s_client -connect housepital.in:443` → `CN=www.housepital.in`, SAN
  `DNS:www.housepital.in` only. DNS and certificates change; re-verify at submission.
- **Test evidence is source-read only.** I confirmed by grep that zero tests reference
  `ChatScreen`, and that `RaiseConcernScreen`, `EquipmentDetailScreen` and
  `StaffProfileScreen` appear only in `test/screens/overflow_smoke_test.dart` and
  `test/screens/dark_mode_sweep_test.dart` — layout guards, not behaviour. No test asserts
  that a concern is submitted, that a rating reaches a server, or that a review is
  moderated. The suite's 1,819 passing tests do not cover this module's behaviour at all.
- **I did not attempt any adversarial testing** — no attempt to guess Storage paths, post an
  oversized message, or submit abusive content. All abuse findings are structural (absent
  controls), not demonstrated exploits.
