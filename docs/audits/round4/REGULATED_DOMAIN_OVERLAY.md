# Regulated Domain Overlay — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** Regulated Domain Overlay (control family REG) ·
**Scope:** source review of `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`
at HEAD `9127713`, branch `fix/five-tab-nav` (see Limitations)

---

## Applicability

**MASTER-3.11 is triggered on five independent grounds. This module applies in full; no
part of it is optional for this app.**

| Trigger | Evidence in this repo |
|---|---|
| **Health data** | BP, SpO2, pulse, temperature, blood sugar collected, stored, charted and interpreted — `lib/utils/vital_classifier.dart`, `lib/screens/reports/vitals_screen.dart`. Health data is **sensitive personal data** under India's DPDP Act 2023. |
| **Indian market** | Delhi NCR home healthcare; `AppConstants.emergencyNumber112 = '112'` (`lib/config/constants.dart:17`); EN/HI localisation; INR pricing. DPDP Act 2023 + DPDP Rules 2025 apply. |
| **Vulnerable population** | Elderly, post-stroke, bed-ridden, ventilator and tracheostomy patients are the explicit product audience — `lib/screens/services/data/catalog_seeds.dart:54-74`, `:115`, `:392-409`. |
| **Clinical decision surface** | The app renders a green/yellow/red verdict and the words "Normal" / "Needs attention" over patient vitals (`assets/i18n/en.json:320-322`), and asserts "Outside safe range on N occasions" (`lib/screens/reports/vitals_screen.dart:572`). |
| **Regulated goods & services sold** | ICU-at-home nursing, physiotherapy, injectables, tracheostomy change, 153 lab tests, X-ray, and BiPAP / CPAP / ventilator / oxygen-concentrator supply — `catalog_seeds.dart`, `assets/equipment_catalog.json` (351 items), `assets/lab_tests_catalog.json`. |

Additionally: an SOS/ambulance path (`lib/screens/sos/sos_screen.dart`), medication
scheduling with dose-state capture, and a PDF built for hand-off **to a treating
physician** (`lib/services/handover_report_service.dart`).

**This module has never been audited.** There is no round-2 or round-3
`REGULATED_DOMAIN_OVERLAY` report in `docs/audits/` or `docs/audits/round3/`, so there is
no prior-round status table below. This is a first look, conducted systematically rather
than assuming earlier rounds covered the ground. Where round 3's
`SECURITY_PRIVACY_AUDIT.md` reached an overlapping conclusion, I cite it rather than
re-deriving it, and I flag one place where a round-3 credit is **overstated in effect**
(§REG-4.01, the consent gate).

---

## The finding that governs every other one

Round 1→2 found the fixes were **surfaces**. Round 2→3 found they were **half-wires** —
correct data structures with the behaviour they enable left unwritten. Round 4's regulated
surfaces fit a third pattern, and it is worse than either:

> **Controls that are present, named, tested, and pointed the wrong way.**

Three examples, each verified independently below:

1. `EquipmentItem.needsAssessment` exists, is documented, is consumed by four call sites —
   and gates **11 BiPAP/CPAP masks while exempting all 20 BiPAP/CPAP/ventilator machines**
   (`lib/models/models.dart:1050`). Not a missing control. An inverted one.
2. `classifyVital` and `VitalHelper.getVitalStatus` are both well-tested clinical
   classifiers that **disagree**, and both run on the same screen
   (`lib/screens/reports/vitals_screen.dart:568` and `:716`).
3. `LoginScreen` contains a real, correctly-built DPDP consent gate — un-prechecked,
   CTA-disabled-until-agreed — and **nothing in the app ever instantiates it**
   (`lib/main.dart:418-419`).

A missing control is a gap. An inverted control is a **claim of safety that is false**,
and it is the harder failure to defend to a regulator, because the code demonstrates the
obligation was understood.

---

## Control results

### REG-1 — Scope and qualified ownership

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **REG-1.01** Jurisdictions, territories, processing locations, cross-border flows identified | **Fail** | No such artefact exists. `ls docs/` returns 18 files; none is a jurisdiction or data-flow register. `lib/config/firebase_options.dart:26,35,47` declares `projectId: 'housepital-patient'` with **no `locationId`** — the Firebase region, and therefore data residency, is not determinable from source. `lib/config/constants.dart:3` points at `https://api.housepital.in/v1`, which does not resolve. Cross-border processing is nevertheless live: Crashlytics + Performance are enabled in every release build (`lib/main.dart:123-126`). | **Impact:** DPDP §16 restricts transfer to notified territories; the company cannot state where sensitive health data rests. **Mitigation:** record the Firebase region and every processor before any real-patient traffic. **Owner:** OWNER-TBD (needs Firebase console). |
| **REG-1.02** Sector, professional, privacy, cybersecurity, payments, records and AI regimes screened | **Fail** | The only regulatory reference anywhere in the repo is an incidental one: `docs/ARCHITECTURE.md:387` and `lib/screens/settings/delete_account_screen.dart:21` cite "App Store 5.1.1(v) / DPDP §12" for the deletion path. `grep -liE "telemedicine\|medical device\|clinical establishment\|CDSCO\|NABH"` across `docs/*.md` returns **zero**. No screening exists for the three regimes that most obviously bite: telemedicine, medical devices, and clinical-establishment licensing. | **Impact:** the regimes governing the app's three riskiest features have never been looked at. **Owner:** OWNER-TBD (healthcare regulatory counsel). |
| **REG-1.03** Qualified legal / compliance / clinical owners assigned | **Fail** | No named clinical or legal owner appears in `CLAUDE.md`, `docs/`, or any source comment. The vital thresholds in `lib/utils/vital_classifier.dart:5-11` are presented as a table with **no citation, no author, and no clinician attribution**. | **Impact:** clinical content is unowned; no one is accountable for the thresholds. See BLOCKED-OWNER #1. |
| **REG-1.04** Licences, registrations, responsible officers, insurance, regulator contacts recorded | **Fail** | Nothing recorded. Not screened: Clinical Establishments Act registration for ICU-at-home/nursing; CDSCO dealer licence for sale/rental of BiPAP, CPAP, ventilators and oxygen concentrators (notified devices); ambulance operating authority; professional indemnity cover. | **Impact:** the app sells regulated services and devices with no evidence of authority to do so. See BLOCKED-OWNER #3, #4, #9, #10. |

### REG-2 — Obligation register

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **REG-2.01** Each obligation records citation, applicability, owner, control, evidence, retention, review cadence | **Fail** | No obligation register exists in any form. | **Impact:** no traceability from any law to any control. **Owner:** OWNER-TBD. |
| **REG-2.02** Conflicting territorial/sector obligations have an approved distribution decision | **Warning** | Single intended territory (Delhi NCR / India) is implicit throughout, so material conflict is unlikely today. But no approved distribution decision is recorded, and App Store territory restriction is not verifiable from source. | **Impact:** low today; rises the moment the app is listed without territory limits. **Mitigation:** record an explicit India-only distribution decision. **Owner:** OWNER-TBD (needs App Store Connect — BLOCKED-OWNER #7). |
| **REG-2.03** Upcoming obligations and phased commencement tracked | **Fail** | The DPDP Rules 2025 carry phased commencement — a fact this checklist's own source baseline names. Nothing in the repo tracks it. `docs/KNOWN_ISSUES.md` tracks engineering debt only; `grep -niE "dpdp\|regulat"` returns one line about demo seeds. | **Impact:** obligations will commence unnoticed. **Owner:** OWNER-TBD. |
| **REG-2.04** Regulator, store, professional-body, processor and customer-contract requirements distinguished | **Fail** | Not distinguished anywhere. The single deletion-path comment conflates an Apple store rule with a statutory right (`delete_account_screen.dart:21`) — which is convenient shorthand, but it is the only place the two regimes are mentioned and they are not separated. | **Impact:** store compliance will be mistaken for legal compliance. |

### REG-3 — Users, eligibility, and professional boundaries

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **REG-3.01** Eligibility verified only to the degree necessary | **Fail** | **There is no authentication at all.** `lib/main.dart:417-419`: `// NOTE: Auth gate disabled for demo mode. Enable before production release.` / `home: const SplashScreen()`. `lib/screens/splash_screen.dart:14-17` waits 2 s then `pushReplacementNamed('/home')` unconditionally. `grep -rn "'/login'" lib/` returns **zero** — the route is not even registered. `AppProvider._currentUserRole` defaults to `'PRIMARY_CONTACT'` (`lib/providers/app_provider.dart:20`), the **most privileged** role. No age gate exists (`Validators.age` accepts 0–150, `lib/utils/validators.dart:74-81`), while `assessment_request_screen.dart:858,967` collects "Baby's Age (in months)" and "Child's Age" as required fields. | **Impact:** anyone holding the unlocked handset reaches a named patient's full medical history, medication list and vitals in 2 seconds, and can export the handover PDF. DPDP §9 verifiable-parental-consent duties are unaddressed while the app actively collects minors' data. **Mitigation:** re-enable the auth gate. **Owner:** OWNER-TBD. **Release blocker.** |
| **REG-3.02** Product clearly distinguishes information, administrative support, recommendation, diagnosis, advice, transaction, professional service | **Fail** | The app renders clinical verdicts with **no disclaimer anywhere on any clinical surface**. `assets/i18n/en.json:320-322` — `"vital_status_normal": "Normal"`, `"vital_status_alert": "Needs attention"`. `vitals_screen.dart:572` — `'Outside safe range on $alertCount occasion…'`. A repo-wide search for `disclaimer`, `not medical advice`, `not a substitute`, `consult your doctor`, `for information only`, `seek medical`, `treatment advice` returns **zero hits in `lib/` and zero in both i18n files**. The sole disclaimer in the product is a markdown sentence at the bottom of all 28 article bodies (`lib/data/demo_articles.dart:17,25,33,…`), English-only, visible only if the reader scrolls to the end. It does not appear on vitals, medications, the handover PDF, or the assistant. Meanwhile `document_repository_screen.dart:92-108` shows **every user** a mock "CBC & Thyroid Panel — Routine blood work — all normal" and "Chest X-Ray — Annual checkup — no abnormalities". | **Impact:** an elderly or post-stroke patient is told, without qualification, that fabricated readings are "Normal" and that fabricated imaging shows "no abnormalities". This is the single highest-harm defect in the app. **Release blocker.** |
| **REG-3.03** Required professional review, consent, supervision, escalation, second opinion, suitability controls defined | **Fail** | **A red vital does nothing.** `vitals_screen.dart:866-889` maps `'red'` to a colour and the label "Needs attention"; `grep -rn "escalat\|notifyDoctor\|criticalAlert\|emergencyAlert" lib/` returns **zero**. No clinician is notified, no advice is given, no emergency instruction is shown. `test/utils/vital_classification_test.dart:59` is named `'RED: <92% — triggers mandatory notification'` — **the notification it names does not exist**; the test body asserts only the returned string. Clinical gating on services is absent across the catalogue: Critical Nurse for ventilator/tracheostomy patients (`catalog_seeds.dart:54-74`), IM injections (`:368-373`), catheter / Ryles-tube / **tracheostomy change** (`:392-409`), all 153 lab tests and X-ray are `bookingType: 'instant'` and route straight to cart. `grep -i contraindicat lib/` returns **zero**. | **Impact:** the app's own triage output is a dead end, and its most invasive services have no clinical gate. **Release blocker.** |
| **REG-3.04** Vulnerable users, guardians, caregivers, representatives, shared-device scenarios have safe authority and privacy rules | **Fail** | Genuine work exists and deserves credit: a four-role matrix that correctly bars hired caretakers from exporting medical history (`lib/utils/permissions.dart:65-70`), per-patient storage keys, and `SessionScope` fan-out including `cancelAllReminders` (round-4 commit `13e3656`). **All of it is unenforced**, because REG-3.01 grants every device holder `PRIMARY_CONTACT`. `canUserPerform(role, UserAction.shareHandover)` at `medications_screen.dart:60` is therefore always true. No guardian or power-of-attorney concept exists (`grep guardian lib/` → zero). | **Impact:** a considered authority model provides zero protection in the shipped build. **Mitigation:** the model is sound; it needs the auth gate of REG-3.01 to mean anything. |

### REG-4 — Data and records duties

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **REG-4.01** Sensitive categories, consent/authorization, purpose, accuracy, retention, residency, transfer defined | **Fail** | A correct DPDP consent gate **exists and is unreachable**. `lib/screens/auth/login_screen.dart:25` (`_agreedToTerms = false`, un-prechecked), `:48-60` (bounce), `:272-278` (CTA disabled until agreed) — and `grep -rn "LoginScreen" lib/` returns **only its own declaration**. It is imported by nothing. Round 3's `SECURITY_PRIVACY_AUDIT.md:646` credited this gate as real; **it is real code and zero users see it**, because of `main.dart:418-419`. `/onboarding` is registered (`main.dart:448-450`) but nothing navigates to it, and it contains no consent anyway. Net: **the user reaches full health data having accepted nothing and been told nothing.** No retention policy exists (`help_faq_screen.dart:157` cites a "data retention policy" that is absent from the repo); no residency is determinable. | **Impact:** processing sensitive personal data with no notice and no consent — DPDP §5–§6. **Release blocker.** |
| **REG-4.02** Record integrity, attribution, timestamps, audit trail, export format, evidentiary requirements | **Fail** | **The clinician-facing adherence figure is a formula on the calendar date.** `lib/models/care_event.dart:42-43`: `int adherencePercentFor(DateTime day) => 80 + ((day.day * 7 + day.weekday * 3) % 21);` — range **80–100%, never lower**. `weeklyAdherencePercent()` averages seven of these (`:47-54`), and `handover_report_service.dart:118,205` prints the result on the Doctor Handover Report as `'This week adherence: $pct% ($weekTaken/$weekTotal doses)'`. The patient's real dose log is never consulted; `MedicationProvider._takenDoseKeys` is an in-memory `Set` (`medication_provider.dart:43`) that does not survive a cold start. A patient who took **no** doses is reported to their physician at ~90% adherence, and the number can never indicate poor adherence. The same PDF's footer asserts a provenance that is false: `handover_report_service.dart:296-297` — `'Compiled by the Housepital patient app from supervisor-synced records.'` — directly contradicting its own header band at `:133-135`. No audit trail exists (round 3, `SECURITY_PRIVACY_AUDIT.md:715`). | **Impact:** a document designed to be handed to a treating doctor carries a fabricated, systematically flattering clinical metric and a false provenance statement. **Release blocker.** |
| **REG-4.03** Processor/subprocessor contracts, breach notice, deletion, audit, localisation duties verified | **Fail** | Firebase (Google) processes crash, performance and uploaded medical-document data. No DPA, subprocessor list, or localisation commitment is recorded anywhere in the repo. `storage.rules` remains **undeployed** (`CLAUDE.md`, carried open from round 3) — the file exists, the live bucket is not governed by it. | **Impact:** unverified processor chain for sensitive health data. See BLOCKED-OWNER #6. |
| **REG-4.04** Test, analytics, support and model use of regulated data reviewed as rigorously as production | **Fail** | `main.dart:113-126` enables Crashlytics **and** Performance collection in every non-debug build with no consent and no opt-out; `settings_screen.dart` has no telemetry toggle (round 3, `SECURITY_PRIVACY_AUDIT.md:556-557` — **still open, unchanged at round 4**). Separately, demo clinical data seeds on every fresh install (`docs/KNOWN_ISSUES.md:15`), so fabricated patient records are the default content of a production binary. | **Impact:** processing without notice under DPDP; fabricated clinical data ships as production content. |

### REG-5 — Safety, claims, and user protection

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **REG-5.01** Marketing, labels, efficacy claims, risk disclosures, pricing and limitations substantiated and approved | **Fail** | `sos_screen.dart:89-90` labels a button **`'Book Housepital Ambulance'` / `'Request ACLS ambulance dispatch'`**. `_bookAmbulance` at `:192-194` is `Navigator.pushNamed(context, '/raise-concern')` — a support ticket whose `'emergency'` SLA is **2 hours** (`constants.dart:47`). The code comment at `:81-85` admits no bookable ambulance exists. `sos_screen.dart:65` labels a button `'Alert Housepital Ops'`; it only opens the dialer, and dials `supportPhone`, which is **byte-identical to `emergencyPhone`** (`constants.dart:16,18` — both `'9990911911'`), so two differently-labelled escalation paths have one destination. Care packages advertise "10 tele-consults" (`care_packages.dart:27`) with no delivery mechanism: `video_call_service.dart` is a stub whose `joinRoom` sets a boolean, and `video_consultation_screen.dart:182-199` renders an `Icon(Icons.person)` labelled `'Remote Video'` beside a live incrementing call timer. Pricing is not substantiated either — 39 of 351 equipment items share the placeholder price `15000.0`, spanning devices from a ₹2,500 "BiPAP Machine" to a ₹135,000 DreamStation. | **Impact:** an emergency claim that does not perform, and a paid-for service that is simulated. **Release blocker.** |
| **REG-5.02** Hazard analysis covers misuse, delayed action, false positive/negative, automation bias, unavailable service, incorrect data, vulnerable-user harm | **Fail** | No hazard analysis artefact exists. A live false-negative source is demonstrable: **two classifiers with different thresholds run on the same screen.** `vitals_screen.dart:568` calls `VitalHelper.getVitalStatus` (thresholds: `constants.dart:32-39`); `vitals_screen.dart:716` calls `classifyVital` (thresholds: `vital_classifier.dart:41-76`). They diverge on clinically decisive values — worked examples in the table below. Both threshold sets are locked in by **passing** tests (`test/utils/vital_classification_test.dart`, `test/utils/vital_ranges_test.dart`); no test compares them, so the 1,819-test suite certifies two mutually incompatible clinical rules. | **Impact:** SpO2 91% — the number that matters most for this patient population — is shown RED on My Care yet **excluded** from the Vitals screen's "Outside safe range" count. **Release blocker.** |
| **REG-5.03** Safety limits, contraindications, alerts, escalation, emergency instructions, human override tested with domain experts | **Fail** | No evidence of any clinician review. The `needsAssessment` inversion is the clearest instance: `lib/models/models.dart:1050` — `if (availableForRent == true) return false;` — evaluated against `assets/equipment_catalog.json` gates **11 items, every one a mask** (BiPAP Mask S/M/L, CPAP Nose Mask) and exempts **20 items, every one a machine** (Auto BIPAP, BiPAP A40, DreamStation BiPAP AVAPS 30, AirSense 10 CPAP, Stellar/Floton ventilators). All 17 oxygen concentrators are exempt on a second count: `'oxygen'` is absent from the name list at `models.dart:1052-1056`. The app's own article content knows the risk — `demo_articles.dart:25`: "Set the flow exactly as the doctor advised - never increase it yourself" — and no such warning appears in the purchase flow. The one mandatory prescription gate (IV visits, `service_booking_screen.dart:1466`) tests `_attachedFiles.isEmpty` against a list of **filenames**, and `document_attach_widgets.dart:170-174` synthesises `'Prescription_<timestamp>.jpg'` on tap **without opening a camera** — two taps defeat it. No max-dose, drug-interaction or duplicate check exists on medication entry (`add_edit_medication_screen.dart:103-116` validates emptiness only); no self-harm screening on the psychiatry booking path (`catalog_seeds.dart:284-309`). | **Impact:** prescription-only respiratory devices with prescriber-set pressures and flow rates are one-tap cart additions for the exact population least able to detect the error. **Release blocker.** |
| **REG-5.04** Dark patterns, unsuitable targeting, discriminatory outcomes, unfair terms, hidden fees, exploitative personalisation prohibited | **Warning** | I found no dark patterns, and two flows are notably honest: the deletion screen requires typing `DELETE`, states plainly "Requested — not yet done" (`en.json:352`), and is fully localised EN/HI (`en.json:327-353`, `hi.json:327-353`); the rental consent checkbox is un-prechecked (`rental_agreement_screen.dart:91-111`). No personalisation or targeting engine exists, so exploitative personalisation is structurally impossible today. The residual risk is pricing integrity (39 placeholder prices, above) and the fact that no terms are accepted at all before purchase. | **Impact:** low and non-systemic. **Mitigation:** correct the placeholder prices before any real transaction. **Owner:** OWNER-TBD. |

**Worked divergence — two classifiers, one screen** (thresholds from `constants.dart:32-39` vs `vital_classifier.dart:41-76`):

| Reading | `classifyVital` (My Care pill; entry sheet) | `VitalHelper.getVitalStatus` (Vitals "Insights") | Clinical consequence |
|---|---|---|---|
| **SpO2 91%** | `red` | `borderline` — **not** counted as an alert | Shown as an emergency on one screen; **omitted** from the "Outside safe range on N occasions" summary on another |
| **Blood sugar 190 mg/dL** | `yellow` | `alert` | Divergence runs the **opposite** way — under-alarms on the pill, over-alarms in the summary |
| **Systolic 140 mmHg** | `red` | `borderline` | Stage-2 hypertension threshold reported as merely borderline in the summary |
| **Systolic 95 mmHg** | `green` | `borderline` | Contradictory reassurance |

Latent, not yet reachable, but worth fixing in the same edit: `classifyVital` has **no
`diastolic` case** and its `default` returns `'green'` (`vital_classifier.dart:36-38`), so
any future caller passing an unrecognised vital type receives a silent "safe" verdict.

### REG-6 — Security, resilience, and incident duties

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **REG-6.01** Security standards, assurance levels, audits, pen tests, logging, monitoring, recovery objectives mapped | **Fail** | No standard is mapped. CERT-In Cyber Security Directions — a named source baseline of this framework — are unaddressed anywhere in the repo. No audit log exists (round 3, `SECURITY_PRIVACY_AUDIT.md:715`); `storage.rules` is undeployed. | **Impact:** no assurance basis for a sensitive-health-data system. |
| **REG-6.02** Incident classification, regulator/individual notification, evidence, reporting format, legal timelines documented | **Fail** | No breach runbook exists (round 3, `SECURITY_PRIVACY_AUDIT.md:665` — **still open**). CERT-In's 6-hour reporting obligation and DPDP §8(6) breach-notification duty are unmapped, with no responsible authority named. | **Impact:** a breach would be discovered and handled ad hoc, past statutory deadlines. **Release blocker.** |
| **REG-6.03** Continuity covers prolonged outage, data unavailability, professional handoff, alternative access, manual operation, safe shutdown | **Fail** | **The app's designed response to backend unavailability is to substitute fabricated clinical data.** `CLAUDE.md` states this is intended; `DemoData` fallbacks serve every provider, and `api.housepital.in` does not resolve today, so this is the **only** state the app has ever run in. There is no safe-shutdown or degraded mode for clinical surfaces: vitals still classify, the handover PDF still generates. Real mitigation exists and deserves credit — the `DemoDataBannerHost` pill overlay (`main.dart:434`) and the PDF's red header band (`handover_report_service.dart:131-140`), which correctly travels with a document an in-app banner cannot follow. But the band's text ("generated while the Housepital service was unreachable") describes a **conditional** that the code does not implement: `buildHandoverPdf` reads `DemoData` unconditionally (`:107-114`), so the band is always shown and the footer at `:296-297` contradicts it in the same document. | **Impact:** for a clinical app, silent substitution of plausible fabricated data is a more dangerous failure mode than an error screen. **Release blocker.** |
| **REG-6.04** Vendors and critical dependencies meet equivalent regulatory, audit, resilience, breach and exit obligations | **Fail** | No vendor register. Firebase/Google (analytics, crash, storage, auth) and Razorpay (payments) carry no recorded regulatory, breach or exit obligations. | **Impact:** unmanaged dependency risk. See BLOCKED-OWNER #6. |

### REG-7 — AI and automated-decision overlay

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **REG-7.01** System classified under applicable AI/automated-decision regimes by use, impact, user, territory, deployment role | **Fail** | No classification exists. Two automated-decision surfaces are unclassified: (a) `classifyVital` — a deterministic rule-based classifier producing a **clinical triage output** on five vitals for elderly and post-stroke patients; (b) the Sahayak assistant, which **really executes** add-to-cart and booking actions offline (`assistant_local_actions.dart`) and switches to a Cloud LLM whenever `ASSISTANT_API_URL` is set. Whether (a) constitutes Software as a Medical Device under India's Medical Devices Rules 2017 is the pivotal open question — see BLOCKED-OWNER #2. Rule-based does not exempt it: NIST AI RMF and SaMD frameworks both scope by **function and risk**, not by implementation technique. | **Impact:** the app may be an unregistered SaMD. **Release blocker pending BLOCKED-OWNER #2.** |
| **REG-7.02** Training/data rights, transparency, explainability, human review, contestability, bias, accuracy, robustness, monitoring, record duties mapped | **Fail** | The thresholds are stated as a bare table with no source, no version and no author (`vital_classifier.dart:5-11`). A patient cannot see why a reading was called "Needs attention", cannot contest it, and no human reviews it. No accuracy monitoring exists. The assistant has no disclaimer and no "I am not a doctor" framing (`assistant_screen.dart`, `assistant_service.dart` — zero hits for `disclaim`, `not a doctor`, `cannot diagnose`). | **Impact:** automation bias in a population that is highly likely to defer to an on-screen verdict. |
| **REG-7.03** Professional or regulated decisions not delegated beyond what law, licence, evidence and human accountability permit | **Fail** | The app issues an unqualified clinical verdict ("Normal") on five vitals, with no clinician in the loop, no disclaimer, no escalation, and — per REG-1.03 — no clinician having ever signed the thresholds. | **Impact:** clinical interpretation delegated wholly to unvalidated software. **Release blocker.** |
| **REG-7.04** Material model/provider changes trigger renewed domain validation and regulatory assessment | **Fail** | No such process. The assistant silently switches from a local intent matcher to a cloud LLM on an environment variable with no gate, no revalidation and no record. | **Impact:** the system's risk profile can change at deploy time with no assessment. |

### REG-8 — Evidence, approval, and ongoing surveillance

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **REG-8.01** Compliance evidence pack links obligations to policies, designs, code, tests, records, training, contracts, audits, approvals | **Fail** | No evidence pack. `docs/` holds engineering documentation only. | **Impact:** nothing to produce to a regulator, an insurer, or a hospital partner. |
| **REG-8.02** Release and territory gates prevent distribution when a required licence, filing, disclosure, assessment, responsible person or control is incomplete | **Fail** | The release gates that exist are engineering gates: `flutter analyze`, the design-consistency script, and the test suite (`CLAUDE.md`). **None checks for a disclaimer, a consent gate, an enabled auth gate, or a clinical sign-off.** The proof is this audit: every blocker below passes CI today. | **Impact:** the pipeline cannot stop a non-compliant release; it has already let one through. **Release blocker.** |
| **REG-8.03** Complaints, adverse events, safety reports, regulator notices, audits, legal changes, real-world outcomes feed periodic review | **Fail** | A concern/SLA structure exists (`constants.dart:46-51`) and is the nearest thing to a complaints channel, but there is **no adverse-event pathway** — no way to record that a patient came to harm, no clinical safety officer, no review cadence. | **Impact:** harm would not be systematically captured or reviewed. |
| **REG-8.04** Noncompliance has containment, user protection, correction, notification, withdrawal/recall and proof-of-closure procedures | **Fail** | No kill switch, no forced-update mechanism, no remote feature disablement, no recall procedure. Once a build with the REG-3.02 defects is on a patient's phone, there is no mechanism to withdraw it. | **Impact:** no ability to contain a clinical-safety defect post-release. **Release blocker.** |

---

## Scorecard

**Pass 0 · Warning 2 · Fail 30 · N/A 0**  (+ **BLOCKED-OWNER 10**, recorded separately —
these do not substitute for the grades above; each blocked item sits inside a control
already graded on the evidence available in source.)

No control passes. I have checked this result for inflation and it holds: the module
requires a jurisdiction register, an obligation register, assigned clinical and legal
ownership, a hazard analysis, a consent and notice mechanism, and a compliance evidence
pack. **None of these six artefacts exists in any form**, and the controls that depend on
them cannot pass on partial code-level evidence. Where partial work genuinely exists —
the role matrix (REG-3.04), the deletion flow and rental consent (REG-5.04), the demo
banner and PDF band (REG-6.03) — I have said so explicitly and, in REG-5.04, graded
Warning rather than Fail on that basis.

---

## Release blockers (every Fail marked as such)

1. **REG-3.02 — No medical disclaimer on any clinical surface**, while the app renders
   "Normal" over vitals and shows every user mock reports reading "all normal" and "no
   abnormalities" (`en.json:320-322`; `document_repository_screen.dart:92-108`).
2. **REG-5.03 — `needsAssessment` is inverted**: gates 11 masks, exempts 20 BiPAP/CPAP/
   ventilator machines and all 17 oxygen concentrators (`models.dart:1050-1056`).
3. **REG-4.02 — Fabricated adherence on a physician-facing document**:
   `adherencePercentFor` is arithmetic on the date, floor 80%, printed as clinical fact
   (`care_event.dart:42-43` → `handover_report_service.dart:118,205`), with a false
   provenance footer at `:296-297`.
4. **REG-5.02 — Two disagreeing classifiers on one screen**; SpO2 91% is red on one
   surface and excluded from the alert count on another (`vitals_screen.dart:568,716`).
5. **REG-3.01 / REG-4.01 — No authentication and no consent**: `main.dart:417-419`;
   `LoginScreen` orphaned; default role `PRIMARY_CONTACT`.
6. **REG-5.01 — "Request ACLS ambulance dispatch" opens a support ticket**
   (`sos_screen.dart:89-90,192-194`); paid tele-consults are a UI stub.
7. **REG-3.03 — Red vitals escalate to nobody**; a test claims a notification that does
   not exist (`test/utils/vital_classification_test.dart:59`).
8. **REG-6.03 — Silent substitution of fabricated clinical data** as the designed
   response to backend unavailability.
9. **REG-6.02 — No breach/incident runbook** against CERT-In and DPDP timelines.
10. **REG-7.01 / REG-7.03 — Possible unregistered SaMD**; clinical interpretation
    delegated to unvalidated, unsigned thresholds.
11. **REG-8.02 / REG-8.04 — No compliance release gate and no recall path.**

Per the Suite v2.0 release rule, each Fail blocks release unless formally accepted by a
named authority. **For blockers 1–4 and 6, formal acceptance is not an appropriate
instrument**: they are patient-safety defects and misstatements of fact, not risk
trade-offs, and accepting them would place the accepting individual personally behind a
false clinical claim.

---

## Warnings requiring risk acceptance

| # | Control | Impact | Mitigation | Owner / due |
|---|---|---|---|---|
| W-1 | REG-2.02 | No approved distribution decision; App Store territories unverified from source. Low today (single intended territory), rises on listing. | Record an explicit India-only distribution decision; confirm territory settings. | OWNER-TBD / before submission |
| W-2 | REG-5.04 | 39 of 351 equipment items carry the placeholder price `15000.0` across devices priced ₹2,500–₹135,000; no terms are accepted before purchase. | Correct catalogue prices; land the consent gate from REG-4.01. | OWNER-TBD / before first real transaction |

---

## BLOCKED-OWNER — needs access or expertise I do not have

| # | Question | Exactly who is needed |
|---|---|---|
| 1 | Are the vital thresholds in `vital_classifier.dart:5-11` clinically correct for elderly and post-stroke home-care patients, and which set supersedes `constants.dart:32-39`? | **A registered medical practitioner (MD Internal Medicine / General Medicine)**, ideally with geriatric or stroke-rehabilitation experience, to sign the thresholds in writing. |
| 2 | Does colour-coded classification of vitals with a "Normal" / "Needs attention" verdict constitute Software as a Medical Device under India's Medical Devices Rules 2017? | **Indian medical-device regulatory counsel or a CDSCO consultant.** This determines whether blockers 1, 4 and 7 are product defects or unlicensed-device offences. |
| 3 | Is the entity registered under the Clinical Establishments Act 2010 (and Delhi/NCR state rules) for ICU-at-home and nursing services? | **Healthcare regulatory counsel + the entity's compliance officer.** |
| 4 | Does the entity hold a CDSCO licence to sell and rent BiPAP, CPAP, ventilators and oxygen concentrators, and is a prescription legally required to dispense them? | **Medical-device regulatory counsel.** Directly governs REG-5.03. |
| 5 | Do the Telemedicine Practice Guidelines 2020 apply to the doctor and psychiatrist consultations sold in-app, and what RMP identification/record duties attach? | **Healthcare counsel + a registered medical practitioner.** |
| 6 | Firebase project region (data residency) and the executed Google Cloud DPA / subprocessor list. | **Firebase console access** (I audited source only). |
| 7 | App Store Connect territory settings and the App Privacy nutrition label vs actual health-data collection. | **App Store Connect access.** |
| 8 | Do `https://housepital.in/privacy` and `/terms` exist, cover sensitive health data, and name a DPDP §13 grievance officer? | **Live web access / the owner.** Source shows only the two URLs at `about_screen.dart:98,104`. |
| 9 | Ambulance operating authority, and substantiation for the "ACLS" capability claim. | **The operations owner.** |
| 10 | Professional indemnity and cyber insurance covering app-mediated clinical harm. | **The owner / insurance broker.** |

---

## Limitations of this audit

- **MASTER-4.04: this is a source review, not a release-artefact review.** I audited the
  working tree at commit `9127713`. I did not inspect a signed build, a production-like
  environment, or production traffic. That is an honest constraint of this engagement, not
  a finding.
- **Per the audit brief I did not run `flutter test`, `flutter build`, `flutter clean` or
  `pod install`** (concurrent agents). I cite the central results — `flutter analyze`
  clean, design gate passing, 1,819 tests passing across 101 files — and I read test
  **sources** for the test-quality findings at REG-3.03 and REG-5.02.
- **No console or store access:** Firebase, App Store Connect, the live website, and any
  physical device were out of reach. Everything depending on them is recorded under
  BLOCKED-OWNER rather than graded from assumption.
- **I am neither a lawyer nor a clinician.** This report identifies where obligations
  plausibly attach and where the code contradicts a safety claim; it is **not legal advice
  and not clinical validation**, and REG-1.03 exists precisely because this framework must
  not be used as a substitute for either.
- Verification of the equipment findings was performed by parsing
  `assets/equipment_catalog.json` (351 items) directly against the `needsAssessment`
  predicate at `models.dart:1048-1057`. The mask/machine split (11 gated, 20 exempt) and
  the 17 ungated oxygen concentrators are reproducible from the checked-in catalogue.
- Backend repositories `../housepital-backend` and `../housepital-api` were in scope but
  are not load-bearing for this module's conclusions: the app is pointed at neither, so no
  clinical data leaves the device via that path today. The residency and processor
  questions at REG-1.01 and REG-4.03 concern **Firebase**, which is live.

---

## The question the brief asks directly

> **Is this app, as it stands, safe to put in front of a real patient?**

**No. It should not be placed in front of a real patient in its current state, and the
gap is not a matter of polish.**

The reason is narrow and specific, and it is not "the app is unfinished". It is that the
app makes **affirmative clinical statements that are false**, to a population selected for
its inability to detect the error:

- It tells a patient their vitals are "Normal" — with no disclaimer anywhere — using
  numbers that are fabricated and thresholds no clinician has signed.
- It shows every user a chest X-ray reading "no abnormalities" and blood work reading
  "all normal" that belong to nobody.
- It hands a treating physician a PDF asserting ~90% medication adherence computed from
  the calendar date, under a footer claiming the record came from supervisor sync.
- It offers a one-tap purchase of prescription-only respiratory devices to ventilator and
  post-stroke patients, behind a gate that protects the masks and passes the machines.
- It offers an "ACLS ambulance dispatch" button that files a support ticket.

Each of these is worse than an absent feature, because each **is trusted**. The demo-data
banner and the PDF's red band are genuine, well-judged mitigations, and they are the
reason my recommendation is Hold rather than Reject — the authors clearly understood the
duty. But a banner cannot repair a document whose own footer contradicts it, and it does
not reach the word "Normal" printed beside a patient's blood pressure.

### The minimum that changes the answer

This is the smallest set that makes real-patient exposure defensible. It is deliberately
short, and it is ordered.

1. **Delete the fabricated adherence figure.** Remove `adherencePercentFor`
   (`care_event.dart:42-43`) from the handover path, or print nothing where the real dose
   log is unavailable. Delete the "supervisor-synced records" footer
   (`handover_report_service.dart:296-297`). *(Hours.)*
2. **Remove the mock clinical assertions.** The "all normal" / "no abnormalities" strings
   in `document_repository_screen.dart:92-108` must not ship in a binary a patient can open.
3. **One classifier, clinician-signed.** Delete either `VitalHelper.getVitalColor` or
   `classifyVital`; keep one; have the RMP of BLOCKED-OWNER #1 sign the thresholds in
   writing and cite that signature in the source. Add a test that fails if a second
   threshold table reappears.
4. **A persistent, non-dismissible medical disclaimer** on vitals, medications, the
   handover PDF and the assistant, in **both** EN and HI — the article-body sentence is
   the right words in the wrong place and the wrong language coverage.
5. **Un-invert `needsAssessment`.** Remove the `availableForRent` early return
   (`models.dart:1050`) and add oxygen concentrators to the name list. Make the IV
   prescription check test an actual uploaded artefact, not a synthesised filename
   (`document_attach_widgets.dart:170-174`).
6. **Tell the truth on the SOS screen.** Either dispatch an ambulance or relabel the
   button; give `emergencyPhone` and `supportPhone` distinct destinations or merge the two
   options into one.
7. **Give a red vital somewhere to go** — at minimum inline text directing the user to
   their doctor or 112. A triage output that terminates in a colour is automation bias
   with no counterweight.
8. **Re-enable the auth gate** (`main.dart:417-419`) so the consent screen that already
   exists is reachable, and so the role matrix that already exists has meaning.
9. **Name a clinical owner and obtain the BLOCKED-OWNER #2 determination** on SaMD status
   *before* real-patient exposure, not after. If the answer is that this is a medical
   device, items 1–8 are necessary but not sufficient.

Items 1, 2, 5 and 6 are small, surgical source changes — the harm they remove is out of
all proportion to their size. Items 3, 4 and 8 are a few days. Item 9 is the only one that
cannot be compressed by engineering effort, and it is the one that should start first.

---

**Overall result:** ☐ Pass ☐ Pass with accepted warnings ☑ **Hold** ☐ Reject

**Decision owner / signature / date:** OWNER-TBD — no named authority exists in the repo
to accept these risks (REG-1.03).
