# Observability, Incident Response & Business Continuity — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** Observability / IR / BC (control family OIR) · **Scope:** source review of three repositories (see Limitations)

---

## Applicability

**APPLIES — ALWAYS-REQUIRED (MASTER-2.06).** The OIR family's own applicability rule is
"every live product; monitoring depth scales with architecture, user impact, data risk, and
support commitments." All four scaling factors are at their maximum here:

- **Architecture:** three deployables — the Flutter client, `housepital-backend`
  (Firebase Functions + Cloud SQL), `housepital-api` (Laravel + MySQL) — plus Firebase
  Auth/Firestore/Storage/FCM, Razorpay, Anthropic, and a WhatsApp provider.
- **User impact:** the product mediates *home healthcare delivery* — nurse and caretaker
  deployments, vitals, medication schedules, and an SOS path. An outage is not a lost
  session; care still has to be delivered.
- **Data risk:** patient identity, address, vitals, medication, and payment records.
- **Support commitments:** the app makes an explicit, customer-facing response-time promise
  in the concern form — Emergency 2h / High 12h / Medium 24h / Low 72h
  (`docs/SCREENS_IMPLEMENTATION.md:535`).

This module has **never been audited as its own control family**. The round-3
`POST_LAUNCH_OPS_AUDIT.md` is the nearest adjacent module and overlaps on roughly six of
these thirty-four controls; I have read it and reconciled every overlapping finding below
rather than re-deriving it. Where this report and that one differ, the difference is stated.

---

## Prior-round status

No round-3 report exists for OIR. The table below tracks the round-3 **POST_LAUNCH_OPS**
findings that fall inside this module's scope, per the brief's instruction to state for each
prior finding whether it is Pass / still open / regressed.

| Round-3 finding (POST_LAUNCH_OPS) | Status now | Evidence |
|---|---|---|
| **B6** · No iOS dSYM upload phase | **Still open — re-verified independently** | `ios/Runner.xcodeproj/project.pbxproj` contains 6 `PBXShellScriptBuildPhase` entries (lines 295, 311, 333, 350, 366, 387); all six are Flutter `xcode_backend.sh` or CocoaPods scripts. Zero reference to `upload-symbols` or Crashlytics. Extended this round: **Android has no symbol upload either** — `grep -rc -i crashlytics android/app/build.gradle.kts` → `0`, so the Crashlytics Gradle plugin is absent too. |
| **H10** · Non-fatals never reported (`logger.dart:63`) | **Still open, verbatim — and the count was understated** | `lib/utils/logger.dart:63-65` unchanged. Round 3 and `docs/KNOWN_ISSUES.md:32` both say "~45 warn/error sites"; the actual figure is **57** (§F-1). |
| **§D.2** · `StoreMigrator.run()` made throw-safe → a throw that used to reach Crashlytics now reaches nothing | **Still open** | `store_migrator.dart:114-119` guards the whole body and routes the failure to `Log.error`, which terminates at `debugPrint`. Before the guard, an escaping throw in `main()` reached `runZonedGuarded` (`main.dart:283-293`) → `FirebaseCrashlytics.recordError(..., fatal: true)`. The UX fix was correct; the observability cost it created has not been paid back. **Not a round-4 regression — a round-3 regression still unremedied.** |
| **§A** · `DemoMode` — one `markServingLiveData` call site for many sources | **Still open, quantified** | 12 declared sources; `markServingLiveData` is called for exactly **2** (`app_provider.dart:292` dashboard, `vitals_screen.dart:129` vitals). `sourceCareTeam`, `sourceCareCalendar`, `sourceProfile` have **0** call sites of any kind — declared and never wired (§F-7). |
| **§F.3** · Anthropic spend cap + budget alert | **Still open** | `functions/README.md:31` instructs the owner to "set a budget/spend limit"; nothing in any repo enforces or alerts on it. Console state unverifiable (BLOCKED-OWNER). |
| Crashlytics alerts + a named daily reader | **Still open** | `docs/DEPLOYMENT_GUIDE.md:427-439` specifies thresholds but is written as a pre-launch instruction ("Once builds are flowing crashes"), not a record of configuration. No named owner anywhere in the repo. |

**Nothing in this module regressed between round 3 and round 4.** Nothing in it advanced
either: commit `13e3656` touched storage keying, reminder cancellation, vitals sampling and
payment failure typing; commit `9127713` was documentation. Neither commit contains a single
line of observability, alerting, or continuity work. Against the brief's
surfaces → half-wires framing, this module is a third category: **not yet started.**

---

## Control results

### 1. Critical promises and service levels

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **OIR-1.01** — journeys have owners, SLIs, SLOs, measurement definitions, failure impact | **Fail** | No SLI/SLO/measurement definition exists in any of the three repos. `grep -rniE "\bSLO\b\|error budget"` across `*.md`/`*.dart`/`*.yml` (excluding `docs/audits/`) → 0 substantive hits. The single service-level promise in the product is the concern-form SLA at `docs/SCREENS_IMPLEMENTATION.md:535` (Emergency 2h / High 12h / Medium 24h / Low 72h) — and `docs/KNOWN_ISSUES.md:132` (TD-11) records that it "is not enforced or alerted on the backend". | A response-time commitment is shown to patients on the *emergency* concern path with no clock, no owner, and no measurement. Breach is undetectable and unprovable in either direction. **Owner: OWNER-TBD.** Mitigation: either instrument the SLA clock server-side or remove the hour figures from the UI before launch. |
| **OIR-1.02** — availability, latency, correctness, durability, freshness, crash/hang, delivery, business-integrity indicators | **Fail** | Only crash/hang is instrumented at all (`main.dart:113-135` Crashlytics + Performance). No availability indicator (nothing polls either health endpoint, §3.04). No correctness, durability, freshness or delivery indicator anywhere. **No product analytics SDK at all** — `pubspec.yaml:34-35` lists `firebase_crashlytics` and `firebase_performance` and no `firebase_analytics`. Business integrity: `payments.ts:211-217` writes `status:"failed"` to MySQL and logs nothing. | The two indicators that matter most for a care business — "is the backend reachable" and "are payments succeeding" — have no measurement. **Owner: OWNER-TBD.** |
| **OIR-1.03** — error budgets or explicit thresholds govern release pace | **Fail** | No error budget or reliability threshold exists. The only automated release gate is CI line coverage ≥ 50.0% (`.github/workflows/ci.yml`, `COVERAGE_THRESHOLD: "50.0"`), which is a code-quality gate, not a reliability signal. | Release pace is governed by nothing observable. **Owner: OWNER-TBD.** |
| **OIR-1.04** — dependencies, regions, clients, versions, tenants, background jobs separable in health analysis | **Fail** | Crashlytics separates by app version/OS/device automatically — a genuine partial. Everything else fails: correlation IDs are minted but never logged (§2.04); the two Laravel scheduled commands (`routes/console.php:12-13`) emit only `$this->info(...)` to stdout, which goes nowhere under cron; `DemoMode` tracks 12 per-source degradation flags (`lib/data/demo_mode.dart:24-35`) — the right data structure — but the set is on-device only and is transmitted nowhere. | Background jobs and backend dependencies cannot be separated because they are not observed at all. **Owner: OWNER-TBD.** |

### 2. Telemetry and privacy

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **OIR-2.01** — logs/metrics/traces/crash/audits/events/synthetics answer defined diagnostic questions | **Fail** | Client: 57 `Log.warn`/`Log.error` sites terminate at `debugPrint` (§F-1). Backend: `housepital-backend/functions/src/utils/logger.ts:5-20` defines info/warn/error but **only `logger.error` is ever called** — 0 `logger.info`, 0 `logger.warn` across 58 call sites in 19 files; no request, access, or success-path logging. `housepital-api` has **zero `Log::error` in the entire codebase**. No synthetic checks anywhere. | There is no diagnostic question the current telemetry can answer about a live incident. **Owner: OWNER-TBD.** |
| **OIR-2.02** — schemas, units, sampling, cardinality, retention, access, redaction, consent, residency, processor behaviour documented | **Fail** | No telemetry documentation exists in any repo. Retention is unconfigured in both backends: `housepital-backend` has no Cloud Logging sink or bucket config (`firebase.json` covers only functions/firestore/storage/auth); `housepital-api` resolves `LOG_STACK=single` (`.env:19`), so `config/logging.php:61-66` applies — **no `days` key, no rotation, unbounded file**. The `daily` channel's 14-day retention (`config/logging.php:72`) is dead config. | Unbounded log growth on a file that contains plaintext OTPs and patient phone numbers (see OIR-2.03). **Owner: OWNER-TBD.** |
| **OIR-2.03** — PII, secrets, tokens, content, sensitive identifiers excluded/transformed/access-restricted | **Fail** | **Confirmed on disk, not theoretical.** `housepital-api/app/Services/Notifications/LogNotificationService.php:16,21` interpolate the **OTP into the log message**; `:47-49` attach `patient_phone` as context on every notification; `app/Services/WhatsApp/LogWhatsAppClient.php:18` logs the full phone number and full message body. `storage/logs/laravel.log` currently contains verbatim lines of the form `[physio-notify] session #11: START OTP 8614 → patient {"patient_phone":"919822044317"}`, further OTPs, patient names, and a `local.ERROR` SQL exception carrying a phone number as a bound literal. `grep -rniE "redact\|sanitize\|mask\|scrub"` over `app/` and `config/` → 0 hits; `bootstrap/app.php:21-23` `withExceptions` is empty. Client-side, `firebase_service.dart:129` logs a local file path. | Authentication secrets and patient identifiers persisted in cleartext to a file with no rotation, no retention limit, and no documented access control. This is the most serious finding in the module and is a data-protection exposure independent of any outage. **Owner: OWNER-TBD. Fix before any production traffic.** |
| **OIR-2.04** — correlation identifiers support end-to-end diagnosis without becoming stable cross-context tracking IDs | **Fail** | The *design* is right and the *wiring* is absent — the module's signature pattern. `housepital-backend/functions/src/middleware/correlationId.ts:14-17` mints a per-request UUID and sets a response header; it is mounted at `index.ts:68`. **No call site anywhere reads `req.correlationId` into a log line.** The Flutter client neither sends nor stores one: `grep -rniE "requestId\|traceId\|correlation\|X-Request"` over `lib/` → 0 hits. `housepital-api` has none at all. `docs/KNOWN_ISSUES.md:134` (TD-13) marks "No structured logging on backend" as **RESOLVED: structured logging with correlation IDs** — that claim is materially overstated and should be corrected. | Two log lines from the same request cannot be tied together; a client report cannot be matched to a server trace. Non-tracking half of the control is satisfied (the ID is per-request, not stable) — but only vacuously. **Owner: OWNER-TBD.** |
| **OIR-2.05** — telemetry loss, delay, duplication, clock skew, sampling change, pipeline outage detectable | **Fail** | No mechanism exists to detect that telemetry stopped arriving. Crashlytics collection is enabled only when `!kIsWeb && !kDebugMode` (`main.dart:113-135`); nothing verifies uploads land. The dSYM gap (§3.01) means a class of reports arrives structurally unusable, which is itself an undetected telemetry-quality failure. | A silent Crashlytics outage is indistinguishable from a healthy app. **Owner: OWNER-TBD.** |

### 3. Dashboards and alerts

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **OIR-3.01** — dashboards show health, trends, releases, objectives, dependencies, saturation, data integrity, user impact | **Fail** | No dashboard is defined, owned, or referenced as existing in any repo. `docs/DEPLOYMENT_GUIDE.md:427-439` describes the Crashlytics/Performance consoles in the future tense — "Once builds are flowing crashes" — and appears in the **pre-launch** checklist at `:457` as an unchecked box. **dSYM verified absent** (see Prior-round table, B6); `DEPLOYMENT_GUIDE.md:438-439` names this requirement itself and warns "Without dSYMs, all iOS crash reports are obfuscated and useless." | **Precision on the dSYM impact, to avoid overstating it:** no `--obfuscate` or `--split-debug-info` flag is used anywhere in the repo, so Dart-level errors routed through `recordFlutterFatalError` (`main.dart:117-118`) will carry **readable Dart stack traces**. What is lost is the **native** frames — iOS engine, plugin, and OS-level crashes — which arrive as unsymbolicated addresses. The guide's "all iOS crash reports" is broader than the truth; the gap is real but narrower. Live console state is unverifiable (BLOCKED-OWNER). **Owner: OWNER-TBD.** |
| **OIR-3.02** — alerts identify actionable condition, severity, owner, scope, evidence, runbook, escalation | **Fail** | **No alerting of any kind exists in any of the three repositories.** Searched all three for `sentry`, `bugsnag`, `rollbar`, `pagerduty`, `opsgenie`, `datadog`, `newrelic`, `honeybadger`, `alertPolicy`, `notificationChannel`, `uptime check`, `monitoring.googleapis`, Slack webhooks → the only hit is stock Laravel scaffolding at `housepital-api/config/logging.php:78` (`LOG_SLACK_WEBHOOK_URL`), which is **unset in both `.env` and `.env.example` and not in `LOG_STACK`** — dead config that can never fire. Partial credit where due: `DEPLOYMENT_GUIDE.md:434-436` specifies genuinely concrete thresholds (velocity > 0.1% of users in 1h; app start > 5s p95; HTTP > 3s p95). They are unconfigured, unowned, and carry no runbook or escalation path. | Nothing can page anyone. **Owner: OWNER-TBD.** |
| **OIR-3.03** — thresholds, windows, dedup, inhibition, maintenance handling, routing tested with synthetic signals | **Fail** | No alert exists to test; no synthetic or controlled-signal test has been run. Not tested is not N/A. | **Owner: OWNER-TBD.** |
| **OIR-3.04** — no critical promise depends on an unmonitored queue, cron, certificate, quota, vendor, backup, or manual process | **Fail** | Six unmonitored dependencies, each under a critical promise: (1) `housepital-api/routes/console.php:12-13` — two daily cron commands (`physio:send-reminders` 18:00, `physio:mark-no-shows` 23:30) with no `onFailure`, no `pingOnFailure`, no `withoutOverlapping`, and no try/catch in `SendPhysioReminders.php:30-39`, so one provider failure aborts the whole batch mid-loop silently; (2) Anthropic API quota — `functions/README.md:31` instructs a budget be set, nothing enforces it; (3) Razorpay webhook — no reconciliation job for orders stuck `pending` (`payments.ts:67`); (4) **no backup of any kind exists** (§7.02); (5) `storage.rules` written but undeployed (`docs/KNOWN_ISSUES.md:19`); (6) both health endpoints unpolled. | Patient-facing reminders can stop firing for days with no signal. **Owner: OWNER-TBD.** |
| **OIR-3.05** — store reviews, support contacts, refunds, abuse reports, privacy requests treated as operational signals | **Fail** | No process, triage route, or owner defined for any of these. Structurally worse for privacy requests: `docs/KNOWN_ISSUES.md:21-22` records that "No account-deletion request reaches any server — the record is written locally and read by nothing," so a DPDP erasure request is not merely untriaged, it is invisible by construction. | A regulated privacy request can be made by a user and observed by nobody. **Owner: OWNER-TBD.** |

### 4. On-call and incident command

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **OIR-4.01** — coverage, escalation, severity, response targets, handoff, authority, backup contacts documented and sustainable | **Fail** | `grep -rniE "on-call\|oncall\|escalation\|incident commander\|postmortem\|error budget\|runbook\|war room\|pagerduty\|rotation"` across all `*.md`/`*.dart`/`*.yml`/`*.sh` in the patient app (excluding `docs/audits/`) → **14 hits, every one a false positive** (`addMedicationCalls`, `AnimatedRotation`, "price-on-call", "Razorpay key rotation"). The two backend repos contain **zero** hits for the same terms. There is no severity model, no response target, and no named responder anywhere. | No one is designated to receive, own, or escalate a production incident. **Owner: OWNER-TBD.** |
| **OIR-4.02** — incident commander, technical lead, comms lead, scribe, legal/privacy/security contacts, decision authority assigned by severity | **Fail** | No role assignment of any kind exists. The only human contact recorded anywhere in infrastructure config is a support email in `firebase.json` (`googleSignIn.supportEmail`). | **Owner: OWNER-TBD.** |
| **OIR-4.03** — runbooks start from symptoms and include safe diagnostics, containment, rollback/disable, recovery, verification, escalation | **Fail** | `docs/TROUBLESHOOTING.md` is 557 lines and 13 sections. **Every section is developer-environment or build-time**, and I classified all 13: Flutter Build Failures (`:9`), Firebase Auth Issues (`:99` — emulator/SHA-1 setup), Cloud Functions Deployment Errors (`:129`), MySQL Connection Issues (`:180` — Cloud SQL proxy), Bottom Sheet Navigation (`:226` — a widget bug), Razorpay Issues (`:251`), Service Worker Caching (`:316`), Port Conflicts (`:384`), Cart Issues (`:420`), Test Failures (`:435`), Environment-Specific Issues (`:482` — emulator), Quick Diagnostic Commands (`:532`). **Zero production user-symptom playbooks.** The document never once starts from what a patient reports; it starts from what a developer's machine does. The closest approach is `:288` "Razorpay payment succeeds but backend verification fails" — framed as a local test-mode problem, with no containment, rollback, or escalation step. | The title promises a runbook; the content is an onboarding guide. An operator handed this during an outage gets nothing. **Owner: OWNER-TBD.** |
| **OIR-4.04** — incident access available through secure emergency procedures without shared permanent credentials | **BLOCKED-OWNER** | IAM roles, break-glass procedure, and console access are not knowable from source. One in-scope observation that bears on it: **`housepital-api` is not under version control** (`git -C housepital-api log` → `fatal: not a git repository`), so that service has no commit history, no blame, and **no rollback target** — an incident there cannot be remediated by reverting. | Needs Google Cloud / Firebase IAM review. The version-control gap is separately actionable and does not need console access. **Owner: OWNER-TBD.** |

### 5. Security, privacy, and integrity incidents

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **OIR-5.01** — playbooks for credential compromise, unauthorized access, malware/supply-chain, data leak, corruption, deletion, fraud, abuse, processor breach | **Fail** | Exactly **one** of the nine named scenarios has a playbook: Razorpay key rotation, `docs/DEPLOYMENT_GUIDE.md:441-445`. The other eight have nothing. | **Owner: OWNER-TBD.** |
| **OIR-5.02** — evidence preservation, chain of custody, log retention, affected-data determination, containment, key/token rotation, forensics planned | **Fail** | No forensics or evidence-preservation plan. Log retention unconfigured in both backends (§2.02). Affected-data determination is structurally impossible: **security-relevant rejections are unlogged** — `housepital-backend/functions/src/middleware/auth.ts:84-89` and `:105-108` return **403 cross-patient-access denials with no log line**, so an attempt to read another patient's record leaves zero trace; `auth.ts:25-28` and `:65-67` likewise for 401s. | After a suspected breach the team could not determine who accessed what. **Owner: OWNER-TBD.** |
| **OIR-5.03** — contractual and regulatory notification criteria, clocks, jurisdictions, contacts, approval routes maintained and tested | **Fail** | Nothing in any repo addresses breach notification. The checklist's own source baseline names **CERT-In Cyber Security Directions**, which impose a 6-hour incident-reporting obligation on Indian entities; India's DPDP Act adds data-breach notification duties. Neither is referenced, and no clock, contact, or approval route exists. | A statutory reporting clock the organisation is subject to, with no mechanism to start it. **Owner: OWNER-TBD.** |
| **OIR-5.04** — user protection can proceed quickly via revocation, forced logout, feature disable, warning, correction, or export | **Fail** | **No kill switch, no remote config, no feature flag** — confirmed by `docs/KNOWN_ISSUES.md:23` ("no kill switch") and by the absence of `firebase_remote_config` from `pubspec.yaml`. One real mechanism exists: forced logout on 401 via `apiService.onUnauthorized = authProvider.handleUnauthorized` (`main.dart:190`) — but it can only fire in response to a server the app does not currently reach, and the auth gate itself is commented out (`main.dart:417-418`). Disabling a misbehaving feature requires an App Store release. | On iOS, the minimum time to contain a client-side defect is a full review cycle. **Owner: OWNER-TBD.** |

### 6. Communication and support

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **OIR-6.01** — internal, customer, store/reviewer, partner, regulator, public channels predefined by severity and audience | **Fail** | No communication plan, status page, or audience matrix exists in any repo. | **Owner: OWNER-TBD.** |
| **OIR-6.02** — status updates state known impact, affected scope, workaround, next update time, corrections | **Fail** | No status channel exists. The app's only degraded-state communication is the demo pill, which states impact ("not your live record") but **no scope, no workaround, and no next update** — and offers no action (§F-6). | Patients learn their data is wrong and are told nothing about what to do. **Owner: OWNER-TBD.** |
| **OIR-6.03** — support receives verified guidance, diagnostic questions, data-safety warnings, escalation criteria, resolution updates | **Fail** | No support-facing material exists; `TROUBLESHOOTING.md` is developer-facing (§4.03). The sharpest instance: `lib/services/store_migrator.dart:20-22` and `:199-203` make an explicit written promise that **"support can retrieve a patient's order history from `__quarantine_v1_*`"** — but (a) no runbook tells support how, (b) the quarantine event is announced only through `Log.warn` at `:220`, which terminates at `debugPrint`, so support is never told a quarantine happened, and (c) `grep -rn "quarantine" lib/` finds **no reader of those keys anywhere in the app**. The recovery path exists in storage and in no procedure. | A data-recovery guarantee that cannot be invoked because no one is informed it is needed. **Owner: OWNER-TBD.** |
| **OIR-6.04** — accessibility and localization considered in urgent communications and workarounds | **Warning** | The one urgent message that exists was built with genuine care: `lib/widgets/demo_data_banner.dart:74-84` fires an **assertive** `SemanticsService.sendAnnouncement` on appearance and `:90-94` marks the pill a `liveRegion` carrying the **full** sentence, with a code comment explaining that a VoiceOver user would otherwise "have already heard the fake vitals read out". Both `demo_banner_message` and `demo_banner_short` exist in `en.json` and `hi.json` (`:323`, `:354`), enforced by the i18n sync guard. | Risk remains: the **visible** pill shows only the short string with `maxLines: 1` (`demo_data_banner.dart:118`), which `docs/KNOWN_ISSUES.md:29-30` records as truncating in Hindi and at the 1.4× text ceiling — so the sighted Hindi reader gets the least information. And this is the *only* urgent communication surface, so the control is satisfied over a sample of one. **Owner: OWNER-TBD.** Mitigation: allow the pill to wrap to two lines, and re-test at `hi` × 1.4×. |

### 7. Continuity and recovery

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **OIR-7.01** — business impact analysis: essential functions, dependencies, people, facilities/accounts, data, vendors, maximum tolerable outage | **Fail** | No BIA exists. No document in any of the three repos identifies which functions are essential, which vendors are single points of failure, or what outage duration is tolerable. For a service that dispatches nurses and caretakers to homes, the essential function is **care delivery**, and no artifact anywhere states how it continues when the software does not. | The organisation has not written down what it must keep doing when the app stops. **Owner: OWNER-TBD.** |
| **OIR-7.02** — RPO/RTO, backup, failover, alternate provider/manual procedure, return-to-normal for critical tiers | **Fail** | No RPO or RTO figure exists anywhere. **No backup exists in any repo** — no `mysqldump` cron, no scheduled Firestore export, no `spatie/laravel-backup`, no backup command. The only backup reference is an *instruction to a human* before a manual migration: `docs/DEPLOYMENT_GUIDE.md:484`. Partial credit: `DEPLOYMENT_GUIDE.md §9 (:467-492)` is a real, usable **rollback** procedure covering Cloud Functions, database, and all three app platforms, and correctly notes that App Store Connect cannot roll back. But rollback is not continuity, and it does not apply to `housepital-api`, which has no git history to roll back to (§4.04). | A database loss is unrecoverable. **Owner: OWNER-TBD. Fix before any production traffic.** |
| **OIR-7.03** — regional outage, vendor loss, account lockout, key loss, staff unavailability, network isolation, data corruption, prolonged store delay exercised | **Fail** | No exercise of any kind has been run or recorded. Not tested is not N/A. | **Owner: OWNER-TBD.** |
| **OIR-7.04** — continuity procedures preserve authorization, privacy, integrity, auditability, and user communication under degraded operation | **Fail** | Degraded operation is the app's *default* state today, and it preserves none of the five. **Authorization:** the auth gate is commented out (`main.dart:417-418`). **Integrity:** the app presents fabricated clinical data as the record (§F-6). **Auditability:** no event is recorded anywhere. **User communication:** the pill offers no workaround (§6.02). The SOS-specific case is the most serious (§F-5). | See §F-5 and §F-6. **Owner: OWNER-TBD.** |

### 8. Exercises and learning

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **OIR-8.01** — alert drills, game days, restore tests, tabletops, security exercises, comms rehearsals at a risk-based cadence | **Fail** | No exercise has been run, scheduled, or documented. No restore test is possible — there is no backup to restore (§7.02). | **Owner: OWNER-TBD.** |
| **OIR-8.02** — exercises record detection, acknowledgement, decision, containment, recovery, communication, and actual RPO/RTO | **Fail** | No exercises, therefore no records. Not tested is not N/A. | **Owner: OWNER-TBD.** |
| **OIR-8.03** — post-incident reviews identify contributing system conditions and track durable corrective actions with owners and verification | **Warning** | No incident-review process exists, and there has been no production incident to review. But the control's *mechanism* demonstrably exists in a defect context and works: the four-round audit programme (`docs/audits/`, `round3/`, `round4/`), `KNOWN_ISSUES.md` and `CHANGELOG.md` track findings → corrective action → **re-verification in a later round**, and the round-3 report explicitly re-tests every round-2 item. That is a functioning corrective-action loop with verification — the strongest genuine asset in this module. | Risk remains: the loop has never been exercised against a live incident, and it has no severity model, no clock, and no named owner — all three of which a post-incident process needs and a defect-review process does not. **Owner: OWNER-TBD.** Mitigation: reuse the existing round/verification machinery as the PIR format rather than inventing one. |
| **OIR-8.04** — recurring findings update tests, monitoring, runbooks, architecture, support material, training, and this checklist | **Warning** | Partially true, and the pattern of *which* limbs move is itself the evidence. Findings **do** propagate to tests (`docs/TEST_MAP.md`, `test/providers/patient_scope_isolation_test.dart`), architecture (`docs/ARCHITECTURE.md`), and contracts (`CLAUDE.md`). They **do not** propagate to monitoring or runbooks: round 3 ranked `logger.dart:63` "the single highest-value line in the audit" and it is unchanged in round 4; `TROUBLESHOOTING.md` has gained no production playbook across four rounds. | The improvement loop is real but structurally biased toward code and away from operations, which is why this module scored as it did. **Owner: OWNER-TBD.** Mitigation: treat monitoring/runbook items as release-gating rather than backlog. |

---

## Scorecard

**Pass 0 · Warning 3 · Fail 30 · N/A 0 · BLOCKED-OWNER 1**  (34 controls)

Zero Pass warrants a word, because a scorecard that extreme invites the suspicion that the
auditor graded harshly. It is not a grading artifact. Observability, incident response and
business continuity are the one control family on which **no implementation work has ever
been done** in this project — not attempted-and-flawed, but absent. The three non-Fails are
each a real, identifiable asset (the accessible degraded-state announcement; the
audit-and-verification loop; its partial propagation), and I have credited concrete partials
inside the Fails wherever they exist — the specified alert thresholds, the rollback
procedure, the correlation-ID middleware, the per-source `DemoMode` set, the forced-logout
hook. Every one of them is a correct component with nothing connected to it.

---

## Release blockers (every Fail)

All 30 Fails block release under the Suite v2.0 rule unless formally accepted by a named
authority. Ranked by consequence, the ones that should not be accepted:

1. **OIR-2.03 — plaintext OTPs and patient phone numbers in an unrotated log.**
   `LogNotificationService.php:16,21,47-49`, `LogWhatsAppClient.php:18`, persisted now in
   `housepital-api/storage/logs/laravel.log`. Authentication secrets and patient identifiers
   in cleartext, with no rotation, no retention bound, and no documented access control.
   This is a live data-protection exposure that does not require an outage to cause harm.
2. **OIR-7.02 — no backup of any kind, and no RPO/RTO.** A database loss is unrecoverable.
   For patient records this is the highest-severity continuity gap.
3. **OIR-7.04 / §F-5 — the SOS path under degraded operation** (detailed below).
4. **OIR-3.02 / OIR-3.04 — zero alerting, six unmonitored critical dependencies.** Nothing
   can page anyone; patient reminder crons can fail silently for days.
5. **OIR-2.01 / OIR-2.04 — `logger.dart:63`.** One line, 57 call sites, including every
   `StoreMigrator` data-integrity path. Round 3 called it the highest-value line in the
   audit; it is unchanged.
6. **OIR-4.01 / OIR-4.03 — no on-call, no severity model, no production runbook.**
7. **OIR-5.03 — no breach-notification mechanism** against a CERT-In 6-hour clock.

---

## Warnings requiring risk acceptance

| Warning | Impact | Mitigation | Owner / due |
|---|---|---|---|
| **OIR-6.04** — urgent-comms a11y/l10n satisfied over a sample of one; visible pill truncates in Hindi and at 1.4× | Sighted Hindi readers get the least information from the only outage message | Let the pill wrap to two lines; re-test `hi` × 1.4× | OWNER-TBD / before launch |
| **OIR-8.03** — corrective-action loop exists for defects, never exercised on an incident; no severity model or clock | A first real incident would be handled ad hoc | Adopt the existing round/verification format as the PIR template; add severity + clock | OWNER-TBD / before launch |
| **OIR-8.04** — loop propagates to tests/architecture but never to monitoring/runbooks | The same operational findings recur across rounds unremedied | Make monitoring/runbook findings release-gating | OWNER-TBD / next round |

---

## BLOCKED-OWNER — needs access I do not have

| Item | What is needed |
|---|---|
| **OIR-4.04** — emergency access procedures, break-glass, absence of shared permanent credentials | Google Cloud / Firebase IAM review |
| Whether Crashlytics/Performance alerts per `DEPLOYMENT_GUIDE.md §7a.5` are in fact configured | Firebase console (`housepital-patient`) |
| Whether Cloud SQL automated backups are enabled at the project level | GCP console — nothing in any repo asserts or configures them |
| Whether an Anthropic spend cap exists | Anthropic + GCP billing console |
| Effective Cloud Logging retention on `_Default` | GCP Logging console |

---

## Findings in detail

### F-1 · `logger.dart:63` — exactly what is invisible

`lib/utils/logger.dart:52-66` is the single chokepoint. Lines 58-62 emit to `debugPrint`;
line 63 is the unwired TODO. Nothing else in the method has a remote effect.

**Count — the brief's figure and `KNOWN_ISSUES.md:32` both say "~45"; the correct figure is 57.**

```
$ grep -rn --include="*.dart" -E "Log\.(warn|error)\(" lib/ | grep -v lib/utils/logger.dart | wc -l
57
```
(53 `warn` + 5 `error` = 58 raw, less one occurrence inside the doc-comment usage example at
`logger.dart:23`.) Distribution:

| File | warn+error |
|---|---|
| `services/firebase_service.dart` | 20 |
| `services/store_migrator.dart` | 6 |
| `services/payment_service.dart` | 6 |
| `services/sync_service.dart` | 3 |
| `providers/medication_provider.dart` | 3 |
| `providers/app_provider.dart` | 3 |
| `utils/session_scope.dart` | 2 |
| `services/payment_reminder_service.dart` | 2 |
| `services/cache_service.dart` | 2 |
| `screens/settings/delete_account_screen.dart` | 2 |
| `providers/orders_provider.dart` | 2 |
| `providers/cart_provider.dart` | 2 |
| `providers/{reminders,my_care,billing,auth}_provider.dart` | 1 each |

**Precisely what "invisible" means.** `debugPrint` is *not* compiled out of Flutter release
builds — it forwards to `print`, which reaches the platform log (`os_log` on iOS, `logcat`
on Android). So the data exists on the handset. It is invisible in the sense that matters:
**there is no remote sink, so retrieving it requires physical possession of the device and a
cable.** For a Delhi NCR patient population this is equivalent to not having it.

Note also that `ApiService`'s retry and timeout diagnostics are at `Log.debug`
(`api_service.dart:64,74,80`), which `logger.dart:55-57` **drops entirely in release** — so
network degradation is invisible even on the device. And no log is emitted when retries are
finally exhausted.

**The `StoreMigrator` subset is the part that matters.** All six of its sites are data-integrity
events, and every one is silent off-device:

| Line | Event |
|---|---|
| `:117` | `Log.error` — migration aborted entirely; app continues on un-migrated data |
| `:133` | `Log.warn` — data present with no version stamp; treated as v1 |
| `:146` | `Log.warn` — **downgrade detected**; store left untouched |
| `:161` | `Log.warn` — **gap in the migration table**; a version silently skipped |
| `:167` | `Log.error` — **a migration step FAILED** — the exact silent-data-loss path the file exists to prevent |
| `:220` | `Log.warn` — **patient data quarantined** |

The file's own header (`:8-14`) states it exists because the old code "respond[ed] to a parse
failure by silently overwriting the user's orders." Round 4 has fixed the *behaviour* — it
quarantines instead of overwriting — while leaving the *detection* at zero. The failure mode
has changed from "data destroyed silently" to "data preserved silently," which is a real
improvement and still leaves nobody able to tell it happened. Compounding this, per the
prior-round table: making `run()` throw-safe (`:114-119`) removed the one path by which such
a failure previously reached Crashlytics via `runZonedGuarded`.

### F-2 · Crashlytics wiring — correct, with two holes

`main.dart:101` wraps the entire app in `runZonedGuarded`; `:117-118` routes `FlutterError.onError`
to `recordFlutterFatalError`; `:119-122` routes `PlatformDispatcher.instance.onError`; `:283-293`
catches uncaught async/zone errors. The `kIsWeb` guard (`:113`) and the `kDebugMode` split
(`:116`, `:127`) are both correct and well-reasoned in comments. This is the best-executed
observability code in the repo.

Two holes:
1. **No symbol upload on either platform.** iOS: zero `upload-symbols`/Crashlytics references
   across six shell-script phases. Android: no Crashlytics Gradle plugin. Release configs *do*
   produce dSYMs (`project.pbxproj:472,653` → `dwarf-with-dsym`); they are simply never sent.
   Scoped impact as stated in OIR-3.01 — Dart traces stay readable, native frames do not.
2. **`ErrorWidget.builder` (`main.dart:140-169`) reports nothing.** It shows the user "We've
   logged the issue" — but in a non-debug build it calls no recorder at all; `FlutterError.presentError`
   is invoked only when `kDebugMode` (`:142-144`). The reassurance shown to the user is false.
   This is a one-line fix at the same site and is not currently recorded in `KNOWN_ISSUES.md`.

No test anywhere references Crashlytics (`grep -rln "Crashlytics" test/` → no matches), and
there is no test for `logger.dart`.

### F-3 · Is there ANY alerting? Any dashboard? — No, to both

Searched all three repositories for every common alerting and APM vendor plus GCP-native
alert primitives. **The only hit in any repo is dead stock config** (`housepital-api/config/logging.php:78`,
an unset `LOG_SLACK_WEBHOOK_URL` on a channel that is not in the active stack).

Neither backend has CI: `housepital-backend/.github` and `housepital-api/.github` do not exist,
and neither repo contains any `.yml`, `.tf`, `Dockerfile`, or `Makefile`. Deployment is a manual
`firebase deploy`. The patient app's `.github/workflows/ci.yml` runs on push/PR to `main` only —
**no `schedule:` trigger, no notification step**. It is a build signal; it says nothing about production.

**Could the team detect the backend was down?** No.
- `housepital-backend/functions/src/index.ts:83-90` exposes `/health`, but it is a **static
  liveness stub** — it returns `{"status":"ok"}` without touching Cloud SQL, Firestore, or
  Razorpay, so it reports healthy with the database down. `housepital-api` exposes Laravel's
  default `/up` (`bootstrap/app.php:12`) with no DB check registered.
- **Nothing polls either endpoint.** No uptime check, no synthetic monitor, no scheduled function
  (`grep -rniE "pubsub|onSchedule|cron"` in `housepital-backend/functions/src` → 0 hits).
- The client's response to a dead backend is to display demo data and emit `Log.warn` to a dead
  sink (`app_provider.dart:296-298`).

**Could the team detect payments were failing?** No — at three independent layers:
- `housepital-backend/functions/src/routes/payments.ts:211-217` — the `payment.failed` webhook
  branch writes `status:"failed"` to MySQL and **logs nothing and alerts nobody**.
- `:106-109` and `:173-176` — Razorpay **signature verification failures are entirely unlogged**
  (bare `res.status(400)`). A forged webhook or a rotated-secret outage produces no signal at all.
- Client-side, `payment_service.dart:222` reports failures via `Log.warn` → dead sink.
- There is **no reconciliation job** for orders left `pending` at `payments.ts:67` when a webhook
  never arrives.

### F-4 · Incident response — who, what severity, which runbook

**Who is on call:** nobody. No rotation, escalation path, or named responder exists in any repo.

**Severity model:** none for engineering. The only severity taxonomy in the product is
customer-facing — the concern form's Emergency/High/Medium/Low with 2h/12h/24h/72h targets
(`docs/SCREENS_IMPLEMENTATION.md:535`) — and `KNOWN_ISSUES.md:132` records it is not enforced
or alerted on. The app makes a 2-hour emergency promise it cannot measure.

**Runbook:** `TROUBLESHOOTING.md` is not one. All 13 sections are developer-environment or
build-time (full classification in OIR-4.03). It contains no entry that begins with a patient
symptom, and no containment, rollback, or escalation step. `DEPLOYMENT_GUIDE.md §9` is the only
genuine operational procedure in the repo and it covers rollback only.

### F-5 · The SOS path, traced end to end

This is the one flow where an outage is a safety issue. Tracing it also produced the module's
clearest single defect.

**Entry.** Route `/sos` (`main.dart:451-452`), reachable from the Home app bar. No permission
gate and no confirmation dialog, correctly honouring the `CLAUDE.md` contract "SOS is never
blocked." **Pass on availability of the entry point.**

**Structure.** `lib/screens/sos/sos_screen.dart` renders a dispatch-address card plus four
options. Three are direct `tel:` dials through `url_launcher`; one is not.

**Failure point 1 — the dispatch address is fabricated under outage.** `sos_screen.dart:18-19`
reads `context.watch<AppProvider>().currentPatient?.address` and `:47` renders it under the label
**"Dispatch address"**. When the API is unreachable, `app_provider.dart:150-152` assigns
`_currentPatient = DemoData.patient`, whose address is `'B-42, Sector 15, Noida 201301'`
(`demo_data.dart:58`). The provider's own comment at `:153-155` names the problem exactly: *"The
patient's own IDENTITY is sample data here — the most misleading fallback in the app."* On the
emergency screen the consequence is concrete: a patient in distress is shown a confident,
plausible, **wrong** address labelled as where help will be sent, with a Copy button to hand it
to a dispatcher. The demo pill above it says "Sample data — not your live record"; it does not
say "this address is not yours."

**Failure point 2 — dialer failure is handled for the user and invisible to the team.**
`_makeCall` (`:247-289`) is well built: if `canLaunchUrl`/`launchUrl` fails it shows a blocking
dialog with the number and a Copy Number action (`:262-288`) rather than failing silently. Good
UX. But the catch at `:254-256` is `catch (_) { dialerOpened = false; }` — **the exception is
discarded entirely.** There is no `Log` call anywhere in `lib/screens/sos/`. A systemic dialer
failure across a device population would be undetectable.

**Failure point 3 — "Book Housepital Ambulance" is not a dispatch.** `:86-92` presents an option
titled *Book Housepital Ambulance*, subtitle *Request ACLS ambulance dispatch*. `_bookAmbulance`
(`:192-194`) navigates to `/raise-concern` — a support ticket form. To its credit the form does
**not** fabricate success: `raise_concern_screen.dart:406-421` catches `ApiException` and generic
errors and surfaces a red snackbar. But with the backend unreachable, the terminal state of an
ambulance request is a **transient snackbar reading "Something went wrong. Please try again."**
with no phone-call affordance, no retry queue, and — because the screen contains no `Log` call —
no record anywhere that an emergency request was attempted and lost.

**Failure point 4 — one phone number backs two of the three dial options.**
`AppConstants.emergencyPhone` and `AppConstants.supportPhone` are both `'9990911911'`
(`lib/config/constants.dart:17,19`). "Medical Emergency" and "Staff Emergency" therefore dial the
same line. If that line is down or saturated, two of the four SOS options fail together; only
`112` (`:18`) is independent.

**Failure point 5 — zero telemetry on the entire path.** No SOS press is counted anywhere. The
team cannot detect an SOS spike — which for a home-care business is a genuine incident signal —
and cannot establish after the fact whether an SOS was raised.

**Net assessment.** The *primary* SOS action is architecturally sound for continuity: a `tel:`
dial needs no backend, no auth, and no network, and it degrades to a copyable number. That is the
right design and it should be preserved. Everything wrapped around it — the address, the
ambulance option, and the complete absence of recording — fails under exactly the conditions the
screen exists for.

### F-6 · The demo-data fallback as an observability defect

The fallback makes an outage invisible to the user and to the team **simultaneously**, which is
the property that makes it an observability finding and not merely a UX one.

**To the team:** `app_provider.dart:294-299` — total backend failure produces
`Log.warn('Dashboard API unavailable, using demo/cache data')` and the comment *"Demo data already
loaded — no action needed."* That `Log.warn` terminates at `debugPrint`. A complete production
outage generates **zero remote signal**.

**To the user:** by the time the catch runs, `_seedDemoDataIfEmpty` (`:302-316`) has already
populated an ICU deployment, today's attendance, the latest vitals, today's report, and an amount
due — all from `DemoData`. The patient sees a complete, internally consistent, entirely fictional
clinical dashboard. The sole visual signal is a 12px glass pill reading **"Sample data — not your
live record"** (`demo_data_banner.dart:116-117`), `maxLines: 1`. The fuller sentence — *"we can't
reach Housepital right now"* (`en.json:323`) — reaches screen-reader users only (`:80`, `:94`); it
is never shown visually. Neither string tells the patient what to do, and the pill has **no tap
action and no phone affordance**.

**It also decays.** Of 12 declared sources (`demo_mode.dart:24-35`), only 2 ever call
`markServingLiveData`. The other 10 are **sticky**: once flipped to demo they never clear for the
session even after the backend recovers. Three — `sourceCareTeam`, `sourceCareCalendar`,
`sourceProfile` — have **zero call sites of any kind**, exactly the anti-pattern `CLAUDE.md`
warns about ("an unused constant is invisible to the analyzer and makes the list read complete
when it isn't"). The practical effect is alarm fatigue on the only degraded-state indicator the
product has: a pill that stays on after recovery trains users to ignore it.

**Why this is the module's central finding.** Every other gap here is an absence. This one is an
active mechanism that *consumes* the outage signal at both ends — it suppresses the user's reason
to report and the team's ability to detect, and it does so for a clinical dashboard. `KNOWN_ISSUES.md:15-16`
already records that "Demo clinical data seeds on every fresh install. Three rounds have improved
the LABELLING; no round has gated the seed. There is no `DEMO_DATA` build flag." That remains the
correct characterisation, and gating the seed behind a build flag would resolve a large share of
this module's user-facing risk in a single change.

### F-7 · Backend observability (both services)

| Dimension | `housepital-backend` | `housepital-api` |
|---|---|---|
| Logger | Custom JSON wrapper, `functions/src/utils/logger.ts:5-20` | Stock Laravel, `config/logging.php` unmodified |
| Levels actually used | **`error` only** — 0 `logger.info`, 0 `logger.warn` across 58 sites | 2 `Log::info` dev stubs; **0 `Log::error` in the codebase** |
| Uses `functions.logger` | No — raw `console.*`, so Cloud Logging severity is not natively mapped | n/a |
| Redaction | **None** | **None — OTPs and phone numbers in cleartext on disk** |
| Correlation ID | Minted (`middleware/correlationId.ts:14-17`), **never logged** | None |
| Error reporting SDK | **None** | **None** |
| Alerting | **None** | **None** (dead Slack stub) |
| Retention | Unconfigured (GCP `_Default`) | **Unconfigured — `single` channel, no rotation, unbounded** |
| Health endpoint | `/health` (`index.ts:84`) — static stub, unpolled | `/up` — framework default, unpolled |
| Runbooks / ops docs | **Zero `.md` files in the entire repo** | Stock Laravel README + 2 feature specs |
| Backup / RPO / RTO | **None** | **None** |
| CI / IaC | **None** | **None** |
| Version control | git, 7 commits | **Not a git repository** |

Two further silent-failure classes worth recording:
- `housepital-api/app/Http/Controllers/Api/PhysioSupervisorController.php:96-101` is the **only**
  `try`/`catch` in the entire Laravel application. It swallows the exception, never logs it, and
  returns the raw internal exception message to the client.
- `housepital-api/routes/api.php:30` → `WhatsAppWebhookController::handle` — the route comment
  claims it is secured "via signature in the adapter", but `:20-39` performs only `$request->validate()`.
  There is no signature verification and no logging of the inbound call. Flagged here because it is
  an unauthenticated, unlogged entry point; the security assessment belongs to the security module.

The patient app's own Cloud Function is comparable: `functions/index.js:191-192` has a single
`console.error("assistant error:", err)` with no structured context and no correlation ID, and
`functions/README.md:31` asks the owner to set an Anthropic spend limit that nothing enforces.

**Correction to `KNOWN_ISSUES.md:134`.** TD-13 is struck through as *"RESOLVED: structured logging
with correlation IDs."* The structured-logging half is defensible; the correlation-ID half is not —
IDs are generated and never written to a log line. TD-13 should be reopened as partial.

### F-8 · Business continuity for a home healthcare service

The essential function is **care delivery**, not app availability. A nurse still has to arrive; a
medication still has to be taken. The audit question is whether that continues when the software
does not.

**Is there a documented fallback?** No. `grep -rniE "continuity|disaster|failover|RPO|RTO"` across
all three repos returns nothing operational. No document states what happens to scheduled
deployments, attendance capture, or the concern SLA during an outage.

**Do the pieces exist?** Largely, yes — which is what makes the absence of a *procedure* the
finding rather than the absence of *capability*. A single support number, `9990911911`
(`constants.dart:17,19`), is surfaced across the app: `help_faq_screen.dart:357` (dial) and `:370`
(**WhatsApp** via `wa.me`), `home_screen.dart:821,874`, `care_team_screen.dart:41,54,70,363,381`,
`staff_otp_verification_screen.dart:354`, `article_detail_screen.dart:305`, and the SOS screen. A
patient who thinks to look can reach a human by phone or WhatsApp from several screens.

**Does the app tell the patient what to do when it is down?** No — and this is the gap. The demo
pill announces that the data is wrong and stops there: no phone number, no tap action, no
instruction. The one screen that does it correctly is account deletion, whose failure copy reads
*"Nothing has been deleted. Please try again, or call us on 9990-911-911"* (`en.json:347`) and
*"Pending: we could not remove your login automatically. Call us and we will do it"* (`:351`).
That is exactly the right pattern — state the failure, name the fallback, give the number — and
it exists on a settings screen while being absent from the clinical dashboard, the concern form,
and the SOS ambulance path.

**Cheapest high-value remedy identified by this audit:** make the demo pill tappable, opening a
sheet that says what is unavailable and offers Call and WhatsApp actions on
`AppConstants.supportPhone`. It reuses copy patterns and constants already in the repo and
converts the single largest user-facing continuity gap into a working manual procedure.

**Single point of failure worth recording:** support and emergency resolve to the same number, and
the WhatsApp fallback resolves to that number too. Every non-112 fallback path in the product
terminates at one phone line, with no documented alternate.

---

## Limitations of this audit

1. **Source review only (MASTER-4.04).** Evidence should come from the release artifact and a
   production-like environment. I audited three source trees at `9127713`. No build, no device, no
   production traffic, and — per the brief's concurrency rule — no `flutter test`, `flutter build`,
   or `pod install` was run. Central results cited without re-running: `flutter analyze` clean,
   design gate passes, 1,819 tests pass across 101 files.
2. **Console-side configuration is unverifiable.** Whether Crashlytics/Performance alerts, Cloud SQL
   automated backups, GCP log retention, an Anthropic spend cap, or break-glass IAM exist is not
   knowable from source. All are listed under BLOCKED-OWNER. Where the repo documents an intent to
   configure something (`DEPLOYMENT_GUIDE.md §7a.5`), I graded the **repo evidence**, not an assumed
   console state — a documented instruction is not a record of configuration.
3. **No production incident has occurred**, so controls concerning incident *handling* (OIR-8.02,
   8.03) are assessed on documented process and mechanism rather than observed performance. I have
   graded absence of process as Fail/Warning, not N/A, per the "not tested is not N/A" rule.
4. **`housepital-api` is not under version control**, so I cannot establish when its logging
   behaviour was introduced, whether the `.env` on disk matches any deployed environment, or whether
   `storage/logs/laravel.log` reflects development or production traffic. The OTP and phone-number
   values I cite are present in that file; I have deliberately **not** reproduced full values here
   beyond what is needed to make the finding verifiable, and I did not modify the file.
5. **Backend evidence for §F-7 was gathered by a delegated read-only search** across both backend
   repos. I have reproduced its file:line citations as given; I spot-verified the patient-app-side
   claims and the cross-cutting summary directly, but did not independently re-open every backend
   file cited.
6. **Scope boundary.** The WhatsApp webhook signature gap (`routes/api.php:30`) and the disabled
   auth gate (`main.dart:417-418`) are recorded here only for their observability and continuity
   consequences. Their security assessment belongs to the security/privacy module.
