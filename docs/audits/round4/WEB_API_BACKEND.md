# Web, API & Backend — Audit round 4 · Suite v2.0 · commit 9127713
**Date:** 2026-08-03 · **Auditor:** Web/API/Backend · **Scope:** source review of three
deployment units (see Limitations)

Checklist: *Web, API & Backend Checklist (App-Agnostic)*, control family **API**, Suite v2.0,
verified 8 August 2026. 38 controls.

---

## Applicability

**MASTER-3.07 applies.** The estate under review contains three service-side deployment units,
all in scope and all read for this audit:

| Unit | Path | Stack | Role |
|---|---|---|---|
| Patient API | `/Users/ateeshayjain/WIPApps/Housepital/housepital-backend` | Firebase Functions (Node 20) + Express 4 + knex/mysql2 → MySQL `housepital` | 54 HTTP endpoints the Flutter patient app is coded against |
| Staff API | `/Users/ateeshayjain/WIPApps/Housepital/housepital-api` | Laravel 11 + Sanctum → MySQL `housepital_db` | 37 HTTP endpoints for the staff/physio apps |
| Assistant fn | `housepital_patient_app/functions/index.js` | Firebase Functions v2 (`onRequest`) + Anthropic SDK | 1 endpoint, the Sahayak brain |

The app is pointed at neither MySQL backend. `AppConstants.apiBaseUrl` is
`https://api.housepital.in/v1` (`lib/config/constants.dart:3`) and that host does not resolve:

```
$ nslookup api.housepital.in
** server can't find api.housepital.in: NXDOMAIN
```

That does **not** make the control family N/A. The code exists, is committed, defines the
contract the shipped binary calls, and is the artifact that will be deployed. It is audited as
source.

**No round-3 report exists for this module** (`docs/audits/round3/` contains eleven files, none
of them a backend report). This is the first look; the sweep below is therefore systematic
rather than differential.

---

## What the app actually receives today

`api.housepital.in` → NXDOMAIN → `dart:io` `SocketException` → `ApiService._withRetry`
(`lib/services/api_service.dart:55–85`) retries twice with 1 s / 2 s backoff → rethrows →
providers catch and seed demo data (`lib/providers/app_provider.dart:151–152, 302–309`,
`lib/providers/billing_provider.dart:42`), raising a `DemoMode` source. Net effect: **every
network-backed screen shows `DemoData` after roughly three seconds of failed retries.** No
patient data has ever traversed either API. This is consistent with `CLAUDE.md` ("Runs in demo
mode when `api.housepital.in` is unreachable") and is the single mitigating fact behind every
finding below — the defects are latent, not live.

---

## The central finding: the Patient API has never been executed against its own schema

`housepital-backend/sql/001_initial_schema.sql` defines 21 tables. The route handlers query
**four tables that the schema does not define** and reference **column names the schema does not
have** in twenty distinct places. Every one is a hard MySQL error (`ER_BAD_FIELD_ERROR`,
`ER_NO_DEFAULT_FOR_FIELD`, `ER_NO_SUCH_TABLE`) or an invalid-enum comparison, not a subtle bug.

Corroborating evidence that it was never run: `functions/lib` (the TypeScript build output and
the Firebase deploy artifact) does not exist; the last backend commit is `7417387`, files dated
22–23 March 2026; and the test suite is 26 cases across two files
(`__tests__/auth.test.ts` 5, `__tests__/validators.test.ts` 21) covering the auth middleware and
Zod schemas only — **zero route tests, zero database tests**, which is precisely why none of
this was caught.

### Code-vs-schema drift sweep (complete)

Schema line numbers are `housepital-backend/sql/001_initial_schema.sql`.

| # | Code site | What the code does | What the schema says | Effect |
|---|---|---|---|---|
| 1 | `routes/bookings.ts:97–114` | `INSERT bookings {family_member_id, base_amount}` | :237 `booked_by` NOT NULL, :248 `price_amount` NOT NULL, :240 `booking_type` NOT NULL; no `family_member_id`, no `base_amount` | 500 on every booking |
| 2 | `routes/bookings.ts:111` | `payment_status: "unpaid"` | :253 `ENUM('pending','paid','refunded','partial_refund')` | invalid enum |
| 3 | `routes/payments.ts:57–70` | `INSERT payments {family_member_id, updated_at, status:'pending'}` | :307 `paid_by`; :305 `payment_number` UNIQUE NOT NULL; :313 `total_amount` NOT NULL; :318 enum has no `pending`; table has no `updated_at` | 500 on every order creation |
| 4 | `routes/payments.ts:121–128, 190–196, 212–217, 221–227` | `UPDATE payments SET updated_at…, status='captured'/'failed'/'refunded'` | no `updated_at`; :318 enum has no `captured` | 500 on verify + all three webhook branches |
| 5 | `routes/billing.ts:67` | `WHERE payments.status = 'captured'` | :318 the completed value is `completed` | matches nothing → `total_paid` silently always 0 |
| 6 | `routes/assessments.ts:44–56` | `INSERT assessment_requests {family_member_id}` | :277 `requested_by` NOT NULL | 500 |
| 7 | `routes/concerns.ts:38–50` | `INSERT family_concerns {family_member_id, updated_at, status:'open'}` | :362 `raised_by` NOT NULL; no `updated_at`; :369 enum starts at `received` | 500 |
| 8 | `routes/ratings.ts:37, 54` | `daily_ratings` filtered/inserted on `family_member_id`; no `date` supplied | :388 `rated_by` NOT NULL, :389 `date` DATE NOT NULL, :393 `UNIQUE(deployment_id, rated_by, date)` | 500; the daily-uniqueness invariant is unreachable |
| 9 | `routes/medications.ts:76–91` | `INSERT medications {schedule_times, start_date, low_stock_threshold, updated_at}` | :427 `time_slots`; :430 `prescribed_date`; no `low_stock_threshold`; no `updated_at` | 500 |
| 10 | `routes/medications.ts:129–153, 268–270` | `UPDATE medications` with the same four names | idem | 500 |
| 11 | `routes/medications.ts:218` | `SELECT medication_logs WHERE patient_id` | :444–458 `medication_logs` has no `patient_id` (it links via `medication_id`) | 500 |
| 12 | `routes/services.ts:16` | `ORDER BY service_catalog.sort_order` | :111 `display_order` | 500 — the whole service catalog |
| 13 | `routes/equipment.ts:20, 24, 39` | `WHERE is_active` / `WHERE type` / `ORDER BY sort_order` | :120–143 `status ENUM('Active','Inactive')`; no `type`; no `sort_order` | 500 — the whole equipment catalog |
| 14 | `routes/notifications.ts:52, 75, 76` | `is_read`, `read_at` | :403–416 `status ENUM('sent','delivered','read','failed')`; neither column exists | 500 on mark-read and mark-all-read |
| 15 | `routes/staff.ts:27, 41` | `SELECT staff_reviews`, `SELECT staff_documents` | tables not defined | 500 |
| 16 | `routes/patients.ts:599` | `SELECT health_manager_assignments` | table not defined | 500 |
| 17 | `routes/deployments.ts:217` | `SELECT equipment_deployments` | table not defined | 500 |
| 18 | `routes/coupons.ts:66, 71` | reads `coupon.max_uses`; counts prior use over `bookings.promo_code` | :473 `usage_limit`; :483 `coupon_usage` (with `UNIQUE(coupon_id, patient_id)`) exists and is **never written by any route** | usage limit silently unenforced; per-patient reuse guard is dead |
| 19 | `routes/patients.ts:559–575`, `routes/deployments.ts:40–55` | reads `dep.service_name`, `.staff_role`, `.service_category`, `.is_session_based`, `.daily_rate`, `.total_paid`, `.total_consumed`, `.remaining` | `deployments` (:147–165) has none of these | `undefined` → every active service renders as "Care Service" / "care_package" / 30 days / null price |
| 20 | `routes/family.ts:63` | `INSERT family_members {user_id: ""}` | :45 `user_id VARCHAR(128) NOT NULL UNIQUE` | the first family invite in the whole database succeeds; every subsequent one, for any patient, fails `ER_DUP_ENTRY` |

Net: of the Patient API's 54 endpoints, **20 cannot complete a successful response** against the
schema in the same repository — `POST /bookings`; `POST /payments/create-order`, `/verify`,
`/webhook`; `POST /assessments`; `POST /concerns`; `POST /ratings`; all five medication write and
log routes; `GET /services`; `GET /equipment`; both `/notifications` mark-read routes;
`GET /staff/:id/profile`; `GET /patients/:id/health-manager`;
`GET /deployments/:id/service-detail`; and every `POST /patients/:id/family` after the first in
the database. That is every write path in bookings, payments, ratings, concerns, assessments and
medications, plus both product catalogues. A further two (`/billing/summary`, the active-services
list) return silently wrong data rather than erroring.

---

## The second structural finding: `validateBody` throws into an Express 4 async handler

`utils/validators.ts:97–106` throws `AppError` on a schema miss. Ten POST handlers call it
**outside** their `try` block:

`auth.ts:67`, `auth.ts:164`, `bookings.ts:34`, `payments.ts:30`, `ratings.ts:24`,
`concerns.ts:26`, `assessments.ts:30`, `medications.ts:60`, `coupons.ts:14`, `family.ts:56`.

The dependency is `express: ^4.18.2` (`functions/package.json`). Express 4 does not catch
rejections from `async` handlers, so the throw never reaches `errorHandler` (registered at
`index.ts:113`). The request receives no response and hangs to the 60 s function timeout
(`index.ts:122`), and Node 20's default `--unhandled-rejections=throw` terminates the worker.

**Consequence:** any authenticated caller can kill a Cloud Function instance and stall a request
slot with a single malformed JSON body — e.g. `POST /ratings {"rating": 9}`. That is a
one-request availability primitive, and it is on the same code path (`validateBody`) that
`7417387` added as a security improvement.

---

## Authorization findings (Patient API)

### A. `verifyPatientAccess` fails open for any user without a `family_members` row

```ts
// middleware/auth.ts:97–110
const patientId = req.params.patientId || req.params.id;
if (patientId && authReq.patientId && patientId !== authReq.patientId) { …403… }
next();
```

`verifyAuth` sets `authReq.patientId = ""` for any valid Firebase identity with no
`family_members` row (`auth.ts:44–53`). `"" && …` short-circuits, so the guard calls `next()`
unconditionally. Every route protected only by this middleware becomes unscoped for that user:
dashboard, deployment, attendance (today + history), vitals (latest + history), daily reports
(today + history), active services, health manager, medications, medication logs, family roster,
concerns, assessments, bookings, invoices, transactions, billing summary.

Two reachable paths into that state:

1. **A newly registered account.** The app uses Firebase phone auth; anyone can obtain a valid
   ID token, then simply not call `/auth/onboarding`.
2. **A removed family member.** `family.ts:219` and `family.ts:268` hard-`DELETE` the
   `family_members` row. On the removed user's next request `verifyAuth` finds no row, sets
   `patientId = ""`, and the guard stops applying. **Removal does not revoke access — it
   converts scoped access into unscoped access**, including to the patient they were just
   removed from.

Reads require knowing a UUID, which is a real friction, but deployment / report / invoice /
transaction IDs are exactly the identifiers that travel in FCM payloads, generated PDFs and
support threads.

### B. Endpoints with no ownership check at all

| Endpoint | Site | Returns |
|---|---|---|
| `GET /deployments/:id/service-detail` | `deployments.ts:11–14` | staff on duty, 7-day attendance, 7-reading vitals series with clinical status, today's task list and staff notes, equipment — for **any** deployment id |
| `GET /deployments/:id/attendance` | `deployments.ts:245–248` | full paginated attendance for any deployment |
| `GET /reports/:id` | `reports.ts:11–14` | any patient's full daily clinical report |
| `GET /invoices/:id` | `billing.ts:150–153` | any patient's invoice with line items |
| `GET /transactions/:id` | `billing.ts:214–217` | any payment row, including `razorpay_*` identifiers |

All five carry `verifyAuth` and nothing else. Any authenticated user with an id reads another
patient's clinical and financial record.

### C. IDOR + missing function-level check on family-member mutation

`family.ts:129–189` (`PUT /patients/:patientId/family/:memberId`) looks the member up as
`db("family_members").where("id", memberId)` with **no patient scope** and **no `requirePrimary`**.
A caller supplies their own `patientId` (so `verifyPatientAccess` passes) and any `memberId`, and
rewrites that person's `name`, `phone`, `email`, `relationship` and notification preferences —
anywhere in the database. `family.ts:193–226` (remove) has `requirePrimary` but the same unscoped
lookup, so any primary contact can delete any non-primary family member of any patient.

`family.ts:230–275` (the legacy `PUT /family/:memberId/remove`) is the only handler in the file
that gets this right — it checks `member.patient_id !== authReq.patientId` **and** the role
explicitly. The correct pattern exists in the repo and was not applied to the newer routes.

---

## Authorization findings (Staff API)

`routes/api.php:38` wraps everything in `auth:sanctum` and that is the **entire** authorization
model. A repository-wide search finds no role gate:

```
$ grep -rn "role_code|authorize\(|Gate::|->can\(|abort\(403" app/Http app/Services routes/
app/Http/Controllers/Api/PhysioSupervisorController.php:56:  'role_code' => $c['physio']->role_code,   # display only
app/Http/Controllers/Api/PhysioPackageController.php:58:   ->with('physio:id,full_name,role_code')  # eager-load only
app/Http/Controllers/Api/AuthController.php:91:            'role_code' => 'CT_BASIC',               # default on create
```

`AuthController::verifyOtp` (`AuthController.php:87–94`) creates any unknown phone as a staff
member with `role_code = CT_BASIC` and issues a token. That token then reaches, with no further
check:

- `GET /physio/supervisor/queue`, `/active` — the full pending and active patient book (names,
  addresses, tiers, no-show flags)
- `GET /physio/supervisor/packages/{id}/pool` and `POST …/assign` — assign any physio to any
  patient (`PhysioSupervisorController.php:50, 86`)
- `POST /physio/packages` — create packages (`PhysioPackageController.php:22`)

This is OWASP API5 (Broken Function Level Authorization) with a self-service enrolment path in
front of it. `staff.onboarding_status` has a `blacklisted` value
(`2026_02_25_100000_create_housepital_tables.php:34–37`) and **no code reads it** — a blacklisted
staff member's token continues to work. `config/sanctum.php:50` sets `'expiration' => null`, so
tokens never expire.

The physio visit lifecycle is the counter-example and is done correctly:
`PhysioVisitController::session()` (`PhysioVisitController.php:147–150`) does not scope by owner,
but `VisitService` re-runs `gateIdentity()` on **every** consequential call
(`VisitService.php:45, 91, 124, 158, 184, 209`) and compares with `hash_equals`. That is the
right shape; it is simply not applied anywhere else in the codebase.

---

## Webhook findings

**Razorpay** (`payments.ts:155–236`) — two independent defects that each defeat verification:

1. `index.ts:81` installs `express.json()` globally, so by the time the handler runs the raw body
   is gone. `payments.ts:166–167` reconstructs it with `JSON.stringify(req.body)`, which does not
   reproduce the bytes Razorpay signed (whitespace and unicode escaping differ). The HMAC will
   not match a genuine webhook.
2. The secret used is `getRazorpayKeySecret()` (`config/razorpay.ts:30`), i.e. the API key
   secret. Razorpay signs webhooks with a **separate webhook secret**.

There is also no timestamp check, no replay window, and no dedupe on the event/payment id, so a
replayed `payment.captured` re-applies. Once the signature is fixed, replay is unguarded.

**WhatsApp** (`routes/api.php:30` → `WhatsAppWebhookController.php:20–39`) — public, and the
route comment ("secure via signature in the adapter") describes a control that does not exist;
`grep -rni "signature|hmac"` over `app/`, `routes/`, `config/` returns only Artisan command
signatures. The handler passes the attacker-supplied `from` field straight into
`RescheduleService::handleInbound()`, which resolves it to a patient by phone
(`RescheduleService.php:191–199`). Two consequences:

- `POST /api/webhooks/whatsapp {"from":"<victim>","text":"cancel"}` marks that patient's next
  physio visit `missed` (`RescheduleService.php:149`) — no auth, no rate limit.
- Every branch of `handleInbound` ends in `reply()` → `whatsapp->sendText($phone, …)`
  (`RescheduleService.php:260–265`), so the endpoint is an **unauthenticated outbound-message
  amplifier on the company's WhatsApp account**, for any phone number, at any rate.
- `message_id` is recorded on the reschedule log but never checked for prior use → replay.

---

## Secrets, environments, deployment

- **`housepital-api` is not a git repository.** `git log` in that directory returns
  `fatal: not a git repository (or any of the parent directories): .git`. Nothing in the staff
  API is version-controlled, reviewed, or recoverable. `.gitignore` lists `.env`, but with no
  repository the entry is inert.
- **One environment.** `housepital-api/.env` is the only config and reads `APP_ENV=local`,
  `APP_DEBUG=true`, `DB_USERNAME=root`, `DB_PASSWORD=` (empty), `LOG_LEVEL=debug`. `.env.example`
  carries the same `APP_DEBUG=true`. `config/app.php:68` hardcodes `'timezone' => 'UTC'` — not
  even env-driven — in a Delhi-NCR product.
- **`housepital-backend` is a git repo** (`origin https://github.com/ateeshayjain/housepital-backend.git`,
  7 commits, `main` + one merged feature branch), but has no CI, no `.github/`, no IaC, and no
  build artifact (`functions/lib` absent). `firebase.json` registers only `functions` and
  `firestore` — no `hosting` rewrite, so a deployed function is served at
  `…/api/<path>`, not at the `/v1` prefix the app is built against
  (`lib/config/constants.dart:3`).
- **No migration tooling on the Patient API.** `config/cloudSql.ts:33–35` sets
  `migrations.directory = "../../sql"`, but `sql/` holds four hand-run scripts using
  `CREATE TABLE IF NOT EXISTS` with no `down`, no ledger table, and no `migrate` script in
  `package.json`. The Staff API by contrast has real reversible migrations with a framework-managed
  ledger — including a data backfill (`2026_07_16_100000_create_patient_tables.php:62–86`), though
  that backfill loads every `visit_packages` row into memory and runs unbatched inside `up()`.
- **`ANTHROPIC_API_KEY` is handled correctly.** `functions/index.js:21` uses
  `defineSecret("ANTHROPIC_API_KEY")` and the key is injected at runtime. A scan across all refs
  in the patient-app repository for `sk-ant-` returns nothing. This holds; re-verified.
- Razorpay key/secret and the Cloud SQL password come from plain env vars
  (`config/razorpay.ts:9–10`, `config/cloudSql.ts:15–19`) with a default empty DB password. No
  documented store, rotation, owner, or expiry alert for any credential, domain, or certificate.

---

## Assistant Cloud Function (`housepital_patient_app/functions/index.js`)

`exports.assistant = onRequest({ secrets: […], region: "asia-south1", cors: true, … })`
(lines 133–141). `cors: true` reflects any origin, and there is **no token verification** —
no `verifyIdToken`, no shared secret, no App Check. Anyone with the URL can invoke it.

Mitigations that genuinely exist and should be credited: input is capped at 1,000 characters
(line 147), `role` is validated against a four-value allowlist rather than interpolated
(lines 159–167), `max_tokens` is 512, `thinking` is disabled, the output is constrained by a JSON
schema, the function never returns an error to the caller, and the app-side executor re-checks
permissions. The prompt is also static, which limits injection value.

The residual risk is **cost**, not data: an unauthenticated caller can drive unbounded
Anthropic Opus spend against the project's key. There is no rate limit, no quota, no App Check,
and (per the README) no budget cap is enforced in code. This should be gated with Firebase App
Check or an ID-token check before the URL is distributed in a build.

---

## App ↔ Patient-API contract breaks

Independent of the schema drift, the two sides disagree about the wire format.

| App call | Backend |
|---|---|
| `completeOnboarding` posts `{name, relationship, preferred_language}` (`api_service.dart:166–176`) | `onboardingSchema` **requires** `patient_name` and `patient_city` (`validators.ts:45–55`) → 400 (in practice, the hang described above) on every onboarding attempt |
| `verifyOtp` posts `{phone, otp}` (`api_service.dart:161`) | `POST /auth/verify-otp` requires a Firebase ID token header and ignores the body entirely (`auth.ts:17`) — two different auth models |
| `getAvailableCoupons`, `getTransactions` cast the response to `Map<String,dynamic>` (`api_service.dart:594–612`, via `_handleResponse` at :138–150) | `coupons.ts:125` and `billing.ts:202` return **bare JSON arrays** → client-side type error |

Fourteen endpoints the app calls have no route at all: `POST /patients/:id/vitals`,
`GET /services/:id/slots`, `POST /bookings/:id/cancel`, `POST /bookings/:id/rate`,
`PUT /assessments/:id/accept`, `PUT /assessments/:id/decline`,
`GET /patients/:id/equipment-orders`, `GET /equipment/:id/reviews`,
`POST /equipment/:id/reviews`, `POST /deployments/:id/replacement`,
`POST /equipment-orders/:id/return`, `GET /articles`, `GET /articles/:id`,
`GET /patients/:id/sync`.

---

## Control results

`housepital-backend` = Patient API · `housepital-api` = Staff API.

| Control | Outcome | Evidence | Impact / mitigation (Warnings and Fails) |
|---|---|---|---|
| **API-1.01** Inventory of APIs, hosts, functions, queues, DBs, webhooks, vendors with owners | **Fail** | No inventory document in either repo. Estate is 3 deployment units, 2 MySQL databases, 1 Firestore, 1 database queue, 2 webhooks, 5 vendors (Firebase, Cloud SQL, Razorpay, Anthropic, an unselected WhatsApp BSP). `housepital-api` has `docs/specs/` × 2 design docs — feature specs, not an inventory. | Two webhooks and a public LLM endpoint exist that nobody has enumerated; the Razorpay and WhatsApp webhook defects below are a direct consequence. Owner: **OWNER-TBD**. Due before any deploy. Mitigation: nothing deployed. |
| **API-1.02** Trust boundaries, data flows, environments, tenancy, secrets, deployment units diagrammed | **Fail** | No diagram or data-flow doc in either backend repo. `housepital_patient_app/docs/ARCHITECTURE.md` documents the Flutter app's 11 providers and storage/payment contracts only. | The patient/staff trust boundary is undefined, which is why `family_members` is used as both an identity table and an invite table (finding #20) and why the two `patients` tables were built independently. **OWNER-TBD**. |
| **API-1.03** Debug/legacy/undocumented/admin endpoints removed or protected **and monitored** | **Warning** | `POST /auth/dev-login` is env-guarded (`AuthController.php:120–122`) ✓; `otp_debug` is env-guarded (`AuthController.php:49`) ✓. But `PUT /family/:memberId/remove` is live and labelled "(legacy)" with no sunset (`family.ts:228–230`); all 92 endpoints across the estate are undocumented; **nothing is monitored**. | The env guards are correct *code*, but `APP_ENV=local` is the only environment that has ever existed, so the guard has never been exercised in its protective configuration. Impact: a mis-set `APP_ENV` turns `dev-login` into a phone-only token mint. Mitigation: set `APP_ENV=production` in a real deployment config before first deploy. **OWNER-TBD**. |
| **API-1.04** Ownership, on-call, SLOs, scaling limits, recovery tier, deprecation policy defined | **Fail** | None of the six defined anywhere in either repo. `minInstances: 0` (`index.ts:124`) is the only scaling statement. | No one is accountable for a live incident; unverified. **OWNER-TBD**. |
| **API-2.01** Schemas define types, limits, enums, errors, pagination, idempotency, versioning, compatibility | **Fail** | Zod covers 11 request bodies (`validators.ts`); no response schemas, no OpenAPI, nothing for the Staff API beyond inline `$request->validate`. Pagination is inconsistent — `/patients/:id/bookings` returns `total/page/page_size`, `/patients/:id/reports` accepts `page` and returns neither, `/coupons` and `/patients/:id/transactions` return bare arrays. **Zero** idempotency keys in 92 endpoints. `/v1` in `constants.dart:3` is served by no router. | Client and server disagree on the wire format in three provable places (see contract-break table). Fix with an OpenAPI document generated from the Zod schemas. **OWNER-TBD**. |
| **API-2.02** Method, content type, encoding, size, nesting, file, timeout, rate validated before expensive processing | **Warning** | Patient API: `express.json({limit:"1mb"})` ✓ (`index.ts:81`), three rate limiters ✓ (`index.ts:32–52`), `acquireConnectionTimeout: 10000` ✓ (`config/cloudSql.ts:31`), method check on the assistant fn ✓ (`functions/index.js:143`). Missing: content-type enforcement, nesting depth, outbound timeouts on the Razorpay and Anthropic SDK calls. Staff API: no size limit and no rate limit of any kind (see API-4.05). | A slow Razorpay response consumes the full 60 s function budget. Add explicit SDK timeouts. **OWNER-TBD**. |
| **API-2.03** All external input treated as untrusted | **Fail** | Razorpay webhook signature is computed over `JSON.stringify(req.body)` with the API secret (`payments.ts:166–171`) — cannot match a genuine webhook, and if "fixed" by disabling the check it accepts anything. WhatsApp webhook has no signature at all and **trusts the `from` field to identify a patient** (`WhatsAppWebhookController.php:22–32` → `RescheduleService.php:191–199`). | Release-blocking. An unauthenticated POST cancels a real patient's physio visit and sends WhatsApp messages from the company account to arbitrary numbers. Fix: raw-body HMAC with the correct Razorpay webhook secret + replay window; BSP signature verification on the WhatsApp route. |
| **API-2.04** Unknown fields/enums degrade safely; breaking changes versioned with migration/deprecation | **Fail** | Field allowlists in `patients.ts:95–133` and `medications.ts:130–151` do drop unknown fields safely ✓. But there is no API version in any route (the app's `/v1` is unserved), no deprecation policy, and the "(legacy)" family route has no sunset date. Enum drift is *not* safe: `payment_status:'unpaid'`, `status:'open'`, `status:'pending'`/`'captured'` are all written as values the enum does not accept. | Any schema change is a silent break for shipped binaries. **OWNER-TBD**. |
| **API-2.05** Errors consistent, actionable, correlation-friendly, no internal leakage | **Fail** | Two incompatible envelopes: `{error: string}` (Patient API) vs `{success, data, message}` (Staff API). `correlationId` is generated and returned as a header (`correlationId.ts:14–18`) but **`grep -rn "correlationId"` finds only the middleware and its import** — no log line and no error body carries it, so it correlates nothing. `errorHandler.ts:19–22` returns `err.message` verbatim. `APP_DEBUG=true` returns full Laravel stack traces with absolute filesystem paths (visible today in `storage/logs/laravel.log`). | A production incident cannot be traced across the app→function→DB path. Wire `correlationId` into `logger` and into the error body; set `APP_DEBUG=false`. |
| **API-3.01** Authn validates signature, issuer, audience, scope, expiry, revocation, current account state | **Fail** | `auth.verifyIdToken(idToken)` (`middleware/auth.ts:34`) validates signature/issuer/audience/expiry ✓ but omits `checkRevoked` — a revoked session survives until token expiry. Staff API: `config/sanctum.php:50` `'expiration' => null` — tokens never expire; `staff.onboarding_status` includes `blacklisted` and **no code reads it**, so a blacklisted staff member keeps full API access indefinitely. | Release-blocking for a healthcare staff API: there is no way to revoke a compromised or terminated staff member's access. Fix: `verifyIdToken(token, true)`; Sanctum expiration; an `onboarding_status` check in an auth middleware. |
| **API-3.02** Object-, property- and function-level authorization on every request and background job | **Fail** | `verifyPatientAccess` fails open on `patientId === ""` (`middleware/auth.ts:105`); five endpoints have no ownership check at all (`deployments.ts:11, 245`, `reports.ts:11`, `billing.ts:150, 214`); family-member mutation is unscoped and un-role-gated (`family.ts:129–189`); the entire Staff API has zero role checks (grep output above). | Release-blocking. Cross-patient PHI and financial-record reads; supervisor functions callable by any self-registered staff account. |
| **API-3.03** Server-side filters prevent client-controlled scope, mass assignment, overbroad fields, IDOR | **Fail** | Good: body `patient_id` is compared against `authReq.patientId` in `bookings.ts:38`, `payments.ts:32`, `ratings.ts:26`, `concerns.ts:28`, `assessments.ts:34`; `VitalController.php:62` uses `$request->only()`; `staff.ts:56–72` deliberately withholds salary/Aadhaar/PAN and nulls document URLs. Bad: `family.ts:138–140` and `family.ts:203–205` look up `memberId` with no tenant scope — a textbook IDOR. | Release-blocking; same fix set as API-3.02. |
| **API-3.04** Admin/support/service accounts: stronger authn, least privilege, JIT, complete audit logs | **Fail** | No admin tier exists in either backend. The Staff API's supervisor and health-manager surfaces are ordinary `CT_BASIC` tokens. `audit_logs` is created by `2026_02_25_100000_create_housepital_tables.php:311–325` and the `AuditLog` model exists — `grep` finds **no write to it anywhere**. `getDb()` connects as a single DB user (`config/cloudSql.ts:17`) with no privilege separation. | Release-blocking for a healthcare record system: privileged actions (assign physio, pause package, delete family member) are unattributable. |
| **API-3.05** CORS, CSRF, cookies, session, WebSocket, GraphQL, file, browser controls match the real client architecture | **Fail** | `Cors.php:28` sets `Access-Control-Allow-Origin: *` on **every** response, and `bootstrap/app.php:16` `prepend`s it so it runs before authentication — while `bootstrap/app.php:19` enables `statefulApi()` (cookie-based Sanctum). Patient API allowlist (`index.ts:56–61`) hardcodes `http://localhost:8080` and `:8082` in production code and lists two Firebase Hosting origins that are not the real client (a native Flutter app, which sends no `Origin` and is admitted by the `!origin` branch at `index.ts:73`). `helmet({contentSecurityPolicy: false})` (`index.ts:69`). | Wildcard CORS on an authenticated API with the stateful cookie path enabled is the classic misconfiguration. No credentialed browser client exists today, which is the mitigation. Remove `statefulApi()` or scope the origin allowlist; drop the localhost entries. |
| **API-4.01** Injection, XSS, SSRF, traversal, deserialization, smuggling, cache poisoning, unsafe redirects prevented **and tested** | **Warning** | Parameterisation verified good throughout: knex builders everywhere; all three `whereRaw` calls use bindings (`patients.ts:381`, `medications.ts:222`, `RescheduleService.php:196`); the `LIKE` search binds its parameter (`equipment.ts:29–35`); Eloquent throughout the Staff API. No SSRF surface beyond two fixed-host SDKs. **But**: log injection is present — `LogWhatsAppClient.php:18` interpolates unsanitised inbound patient text into a log line; and there are **zero** injection tests in either repo. | "Prevented" holds on inspection; "tested" does not. Sanitise the logged message; add negative tests when route tests are written. **OWNER-TBD**. |
| **API-4.02** Sensitive flows have bot, fraud, enumeration, credential-stuffing, resource-consumption controls | **Fail** | `POST /auth/send-otp` has no rate limit and deletes prior OTPs (`AuthController.php:19–52`) → free SMS flood at the company's cost. `POST /auth/verify-otp` has **no attempt counter** on a 6-digit OTP (`AuthController.php:58–113`). `verifyEndOtp` has **no attempt counter** on a 4-digit OTP (`VisitService.php:207–217`) — 10,000 tries marks a visit complete without the patient. The public WhatsApp webhook is an unmetered outbound-message amplifier. The assistant function is an unauthenticated LLM spend primitive. | Release-blocking. `verifyStartOtp` *does* cap at 3 attempts (`VisitService.php:132`, `MAX_OTP_ATTEMPTS`) — the correct pattern exists and was not applied to the completion OTP or to login. |
| **API-4.03** Webhooks verify signature, timestamp, replay, source, event identity, environment, authorization before side effects | **Fail** | Razorpay: wrong body (re-serialized, `payments.ts:166–167`), wrong secret (`config/razorpay.ts:30`), no timestamp, no replay window, no event-id dedupe — and the side effects (`payments` + `bookings` updates) run before any of that could be added. WhatsApp: nothing whatsoever; `message_id` is stored (`RescheduleService.php:176`) but never checked. | Release-blocking; see API-2.03. |
| **API-4.04** Outbound requests restrict schemes, destinations, redirects, DNS/IP ranges, credentials, response size, timeouts, parsed content | **Warning** | Two outbound integrations, both via vendor SDKs to fixed hosts (Razorpay, Anthropic) — no user-controlled destination, so no SSRF. Anthropic call bounds input (1,000 chars, `functions/index.js:147`) and output (`max_tokens: 512`) ✓ and parses only a schema-constrained JSON block ✓. Missing: explicit timeouts and response-size caps on both. | Bounded blast radius; a hung vendor call consumes the function's 60 s / 30 s budget. Add SDK timeouts. **OWNER-TBD**. |
| **API-4.05** Rate limits combine identity, tenant, endpoint, cost and global protection without enabling DoS against victims | **Fail** | Staff API: **none**. Laravel 11 applies `throttle:` only when `throttleApi()` is called (`vendor/…/Configuration/Middleware.php:495–499`: `$this->apiLimiter ? 'throttle:'.$this->apiLimiter : null`); `bootstrap/app.php:14–20` never calls it. Patient API: three `express-rate-limit` limiters, but (a) the default store is **in-memory per function instance**, so with `minInstances: 0` and autoscaling the "5 auth attempts / 15 min" cap is 5 × N containers, and (b) `app.set('trust proxy', …)` is never called (`grep` returns nothing), so `req.ip` behind the Google front end can collapse across callers — one abuser exhausting the shared bucket is exactly the "denial of service against victims" this control names. All limits are per-IP only: no identity, tenant, or cost dimension. | Release-blocking. Fix: `throttleApi()` on the Laravel side; a shared store (Firestore/Redis) plus `trust proxy` and a uid-keyed limiter on the Firebase side. |
| **API-5.01** Constraints, transactions, isolation, locks, optimistic concurrency, uniqueness, FKs, idempotency enforce invariants | **Fail** | **One** transaction in 92 endpoints (`auth.ts:95`, onboarding). `/payments/verify` performs two independent updates (`payments.ts:121, 132`) with no transaction and no idempotency key — a retried verify re-applies. `booking_number` is drawn from 9,000 values against a `UNIQUE` column (`bookings.ts:17–20` vs schema :235) — a 50 % collision chance by ~112 bookings; `request_number` from 900,000 (`assessments.ts:15–18`). `family_members.user_id` is `UNIQUE` yet written as `''` for every invite (`family.ts:63`), so the second invite in the database always fails. `coupon_usage` (schema :483, with the reuse-prevention unique key) is never written. | Release-blocking: money can be double-applied and bookings will collide in the first weeks of live traffic. |
| **API-5.02** Read-modify-write, counters, balances, permissions, membership, state machines safe under concurrency and retries | **Fail** | `coupons.used_count` (schema :474) is never incremented; the substitute check counts `bookings.promo_code` rows (`coupons.ts:67–70`) — check-then-act, racy, and gated on a non-existent `max_uses` column so it never runs. OTP attempt counting is a non-atomic cache read-then-write (`VisitService.php:340–346`). `$package->increment('completed_sessions')` is atomic ✓ but the "is this the last session" decision is a separate read (`VisitService.php:226–230`). No optimistic-concurrency column anywhere. | Coupons can be over-redeemed and packages can complete twice under concurrent requests. **OWNER-TBD**. |
| **API-5.03** Migrations, backfills, dual reads/writes, indexes, query plans, pools, timeouts, pagination, large accounts tested | **Fail** | Patient API has **no migration tooling**: `config/cloudSql.ts:33–35` points knex at `../../sql`, which holds four hand-run scripts with `CREATE TABLE IF NOT EXISTS`, no `down`, no ledger, and no `migrate` npm script. Staff API has real reversible migrations ✓, but `backfillPatients()` (`2026_07_16…:62–86`) loads the whole `visit_packages` table into memory and writes row-by-row inside `up()` with no batching or transaction. No `page_size` upper bound on any paginated endpoint (`bookings.ts:134`, `patients.ts:299, 448`, `deployments.ts:252`, `notifications.ts:14`) — `page_size=1000000` is accepted. No query-plan or large-account testing anywhere. | Release-blocking on the schema side: with no migration ledger there is no defined way to evolve `housepital` after first deploy. |
| **API-5.04** Caches define ownership, key scope, privacy, TTL, invalidation, stale behavior, stampede protection, authorization-safe variation | **Warning** | Only application caches exist (`CACHE_STORE=database`): OTP attempts keyed by session id with a 15-min TTL (`VisitService.php:330–350`) ✓, and pending reschedule offers keyed by phone-last-10 with a 30-min TTL (`RescheduleService.php:92–96, 255–258`) ✓. No HTTP cache, no CDN. Ownership and privacy are undocumented; the phone-keyed offer is shared across a patient's multiple packages and `activePackageFor` resolves ambiguity with `latest()` (`RescheduleService.php:197`). | Low impact — a patient with two active packages could apply a slot offer to the wrong one. Document ownership; key the pending offer by package id. **OWNER-TBD**. |
| **API-5.05** Deletion, retention, repair, reconciliation, archival, backup, restore preserve tenant isolation and referential integrity | **Fail** | Hard `DELETE` on `family_members` with no soft-delete or audit (`family.ts:219, 268`). The Patient schema cascades from `patients` ✓ but leaves `deployments.booking_id`, `bookings.assigned_staff_id`, `payments.reference_id`, `assessment_requests.deployment_id` unconstrained. The Staff schema references `supervisor_id`, `approved_by`, `reviewed_by`, `assigned_to` with **no** foreign keys. No retention policy, no backup or restore procedure in either repo. The shipped app promises users "Account deletion is processed within 7 working days as per our data retention policy" (`lib/screens/settings/help_faq_screen.dart:157`) and **no server-side deletion endpoint exists to honour it**. | Release-blocking: a published data-deletion commitment with no implementation is a DPDP Act exposure independent of the technical defects. |
| **API-6.01** Messages and jobs have schema, identity, idempotency, retry, timeout, ordering, dedupe, visibility, poison handling, DLQ | **Warning** | `QUEUE_CONNECTION=database` with `jobs`/`failed_jobs` tables (`0001_01_01_000002_create_jobs_table.php`), and `grep -rn "ShouldQueue\|dispatch("` over `app/` returns **nothing** — the queue has zero producers. The only asynchronous work is two Artisan commands, neither of which has a job identity, idempotency marker, retry policy, or DLQ path. | Narrow subject, so not a Fail; but a manual re-run of `physio:send-reminders` re-messages every patient (see API-6.04). **OWNER-TBD**. |
| **API-6.02** Backpressure, bounded concurrency, rate limits, quota, batch size, checkpointing, cancellation, shutdown, partial completion | **Warning** | `SendPhysioReminders::handle()` `->get()`s all of tomorrow's sessions and sends synchronously in a loop with no batching, no per-send error isolation and no checkpoint (`SendPhysioReminders.php:24–39`) — one BSP failure aborts the run mid-way with no record of who was already messaged. `MarkPhysioNoShows` is unbounded but at least re-checks state per row (`MarkPhysioNoShows.php:24–45`). No BSP rate-limit awareness. | At present volumes this is survivable; it will not survive a few hundred daily sessions. Batch with `chunkById` and record a per-session `reminder_sent_at`. **OWNER-TBD**. |
| **API-6.03** Schedules define time zone, overlap, missed run, duplicate run, clock drift, leader election, manual replay | **Fail** | `bootstrap/app.php` → `routes/console.php:12–13`: `Schedule::command('physio:send-reminders')->dailyAt('18:00')` and `->dailyAt('23:30')`, with **no** `->timezone()`, `->withoutOverlapping()`, or `->onOneServer()`. `config/app.php:68` hardcodes `'timezone' => 'UTC'` and `.env` sets no `APP_TIMEZONE`, so the D-1 reminder fires at **23:30 IST** and the no-show sweep at **05:00 IST**. Worse, `MarkPhysioNoShows.php:29–30` compares the stored local wall-clock `scheduled_time` against `Carbon::now()->format('H:i:s')` in UTC — a 5 h 30 m offset — so the "time has fully passed" guard evaluates 5.5 hours ahead of local time. | Release-blocking for the physio module: patients get "your visit is tomorrow" texts at 11:30 pm, and sessions that have not yet occurred can be marked `physio_no_show` — which pays out a make-up session and raises a red flag against the physio. Fix: `->timezone('Asia/Kolkata')` + `APP_TIMEZONE`, plus `withoutOverlapping()` and `onOneServer()`. |
| **API-6.04** Workers re-check authorization and current state rather than trusting stale enqueue-time assumptions | **Warning** | `MarkPhysioNoShows.php:38–40` re-checks `package->status !== 'active'` before acting ✓ and re-reads `status`/`actual_start` in the query ✓. `SendPhysioReminders.php:26–29` re-checks session and package status ✓. Neither is idempotent: a second run on the same day re-sends every reminder, because nothing records that a reminder was sent. | Duplicate patient messaging on any manual replay or scheduler retry. Add a `reminder_sent_at` guard. **OWNER-TBD**. |
| **API-7.01** Latency, availability, error, freshness, throughput, saturation, correctness objectives with dashboards and alerts | **Fail** | No SLO, dashboard, alert or metric definition in either repo. `grep` finds no metrics client, no OpenTelemetry, no Sentry/Crashlytics wiring on either backend. | Unverified and unverifiable; an outage would be discovered by users. **OWNER-TBD**. |
| **API-7.02** Timeouts, retries, circuit breakers, bulkheads, load shedding, fallbacks, feature flags, dependency isolation tested together | **Fail** | Present: knex pool `min:0 max:10`, `acquireTimeoutMillis: 10000` (`config/cloudSql.ts:23–31`), function `timeoutSeconds: 60` (`index.ts:122`), and the assistant function's graceful `DEGRADED` fallback (`functions/index.js:194–197`) ✓. Absent: circuit breakers, bulkheads, load shedding, feature flags, dependency isolation — and **none of it is tested**, because there are no integration tests on either backend. The client-side retry (`api_service.dart:55–85`) retries 5xx with no jitter, which amplifies a struggling backend. | Release-blocking as "tested": a dependency failure has never been exercised. Note the pool ceiling of 10 per instance × unbounded instances will exhaust Cloud SQL connections under load. |
| **API-7.03** Load, spike, soak, failure injection, region/vendor outage, queue backlog, cache loss, DB failover, restore tests match capacity assumptions | **Fail** | No load or chaos testing of any kind; no capacity assumptions recorded. **Unverified — stated plainly.** | **OWNER-TBD**. |
| **API-7.04** Structured logs, metrics, traces, audit events, correlation identifiers diagnose failures without exposing sensitive data | **Fail** | Structured JSON logger exists ✓ (`utils/logger.ts`), but no log line carries the correlation id (verified by grep). No metrics, no traces. `audit_logs` is never written. **Sensitive data is exposed**: `LogWhatsAppClient.php:18` writes the outbound message — which for `sendStartOtp`/`sendEndOtp` (`WhatsAppNotificationService.php:18–29`) contains the live OTP — to `storage/logs/laravel.log` together with the patient's phone number, at `LOG_LEVEL=debug`. Laravel stack traces on disk carry absolute filesystem paths. | Release-blocking. Because `WhatsAppClient` is bound to `LogWhatsAppClient` (`AppServiceProvider.php:22`), the physio dual-OTP gate currently **delivers nothing to the patient and writes the OTP to a log file** — the gate is decorative as bound. |
| **API-7.05** Health/readiness checks reflect the ability to serve correctly, not merely that a process is running | **Fail** | `index.ts:84–90` returns a hardcoded `{status:"ok", version:"1.0.0"}` with no database, secret or dependency probe — it would return `ok` against every one of the 20 schema drifts above. Laravel's `health: '/up'` (`bootstrap/app.php:12`) is the framework default: it boots the app and returns 200, checking no dependency. | A load balancer or uptime monitor would report both services healthy while every request 500s. Add a DB round-trip and a schema-version assertion. |
| **API-8.01** Infrastructure/configuration versioned, reviewed, scanned, environment-separated, least privilege, reproducibly deployed | **Fail** | `housepital-api` **is not a git repository** (`git log` → `fatal: not a git repository`). `housepital-backend` is (7 commits, `origin` on GitHub) but has no CI, no `.github/`, no IaC, no dependency scanning, and no build artifact (`functions/lib` absent). One environment: `APP_ENV=local`, `APP_DEBUG=true`, `DB_USERNAME=root`, empty `DB_PASSWORD`. `getDb()` uses one DB user for all operations. | Release-blocking. The staff API — which holds Aadhaar, PAN and bank-account columns — has no version history, no review trail, and no recoverable state. Put it under version control before anything else. |
| **API-8.02** Secrets, certificates, domains, DNS, queues, quotas, backups, vendors, scheduled jobs, data stores have owners and expiry/failure alerts | **Fail** | `api.housepital.in` → NXDOMAIN (command output above), i.e. the domain the shipped binary targets is not registered or not delegated. Razorpay key/secret and the Cloud SQL password are plain env vars with an empty default password (`config/cloudSql.ts:18`); no store, rotation, owner or expiry alert for any credential. No backups configured. `ANTHROPIC_API_KEY` is the one correctly-managed secret (Firebase `defineSecret`, `functions/index.js:21`; absent from all refs — re-verified) ✓. | Release-blocking: there is no owner for the domain the app calls. |
| **API-8.03** Canary/phased deploy, schema order, compatibility, halt criteria, rollback/forward-fix, smoke verification, post-deploy monitoring recorded | **Fail** | The entire deployment procedure is `firebase deploy --only functions` in `functions/README.md` and a `predeploy` npm build hook in `firebase.json`. No canary, no ordering rule between the four `sql/` scripts and the code that depends on them, no halt criteria, no rollback, no smoke test, no post-deploy monitoring. | Release-blocking. Given the 20 schema drifts, an unordered first deploy would take the API straight to a fully-500ing state with no rollback path. |
| **API-8.04** RPO/RTO, backup restore, failover, corruption recovery, account compromise, region loss, trusted rebuild exercised | **Fail** | Nothing defined or exercised for either database. Both services are single-region `asia-south1` with no failover. **Unverified — stated plainly.** | Release-blocking for a system holding clinical records. **OWNER-TBD**. |
| **API-8.05** Admin operations, data repairs, support actions, emergency access, manual jobs authorized, attributable, idempotent, reviewed | **Fail** | No admin surface exists. The `audit_logs` table is never written. The only privileged path, `POST /auth/dev-login`, mints a full staff token from a phone number alone (env-guarded). The two manual Artisan jobs are neither attributable nor idempotent (API-6.04). | Release-blocking: any data repair would be performed directly against MySQL with no attribution. |

---

## Scorecard

**Pass 0 · Warning 8 · Fail 30 · N/A 0** (+ BLOCKED-OWNER 0 as a distinct outcome; see the
BLOCKED-OWNER section for evidence that could not be obtained and is folded into the Fails above
as "unverified")

Zero Passes is an unusual result and I want to be explicit that it is not indiscriminate. This
control family assumes a service that has been deployed, operated and observed. Neither MySQL
backend has ever been built, deployed, or executed against its own schema, so the operational
half of the checklist (families 7 and 8, 10 controls) has no evidence to grade against, and the
correctness half fails on hard, individually-cited defects rather than on judgement calls.

**Work that is genuinely correct and should not be lost in a rewrite:**

- Firestore rules are default-deny with real ownership predicates and `allow write: if false`
  on every collection Cloud Functions own (`firestore.rules`) — the best-designed security
  artifact in the estate.
- `staff.ts:40–72` deliberately withholds salary, address, Aadhaar and PAN and nulls document
  URLs — correct property-level authorization thinking.
- `VisitService` re-runs `gateIdentity()` on every consequential call and compares OTPs with
  `hash_equals` (`VisitService.php:131, 166, 215`) — timing-safe and correctly placed.
- The Razorpay signature construction on `/payments/verify` (`payments.ts:100–104`) is correct
  (`order_id|payment_id`, HMAC-SHA256, key secret) — only the *webhook* variant is wrong.
- `ANTHROPIC_API_KEY` handling via `defineSecret`, plus role allowlisting and input capping in
  the assistant function.
- The Staff API's migrations are real, reversible, and framework-ledgered.
- `helmet`, the 1 MB body cap, the three-tier limiters, the structured logger and the N+1
  removals in `patients.ts:486` / `deployments.ts:58` are all genuine improvements from
  `fa58d93`–`7417387`.

---

## Release blockers (every Fail)

Grouped so they can be ticketed. All are **OWNER-TBD** — no owner is derivable from either repo.

**B1 — Cross-patient PHI and financial exposure.** `middleware/auth.ts:105` fails open when
`patientId` is `""`; `deployments.ts:11, 245`, `reports.ts:11`, `billing.ts:150, 214` have no
ownership check; `family.ts:129–189, 193–226` are unscoped IDORs, the first also missing
`requirePrimary`. Removing a family member *grants* unscoped access. *(API-3.02, 3.03)*

**B2 — Staff API has no authorization model.** One `auth:sanctum` gate, zero role checks;
self-registration mints `CT_BASIC`; supervisor and health-manager endpoints are open to any
staff token; `onboarding_status='blacklisted'` is never read; Sanctum tokens never expire.
*(API-3.01, 3.02, 3.04)*

**B3 — Both webhooks are unauthenticated in effect.** Razorpay HMAC uses a re-serialized body
and the wrong secret, with no replay guard; the WhatsApp webhook has no signature and trusts
`from` to identify a patient, allowing visit cancellation and unmetered outbound messaging from
the company account. *(API-2.03, 4.03)*

**B4 — The Patient API cannot execute against its own schema.** Twenty cited drifts across 24+
endpoints, four undefined tables. *(API-2.01, 2.04, 5.01, 5.03)*

**B5 — Malformed request bodies hang and crash the function.** `validateBody` throws outside the
`try` in ten POST handlers on Express 4. *(API-2.02, 2.05, 7.02)*

**B6 — No rate limiting on the Staff API; ineffective limiting on the Patient API.**
`throttleApi()` never called; `express-rate-limit` uses per-instance memory with `trust proxy`
unset. Unlimited OTP attempts on both the 6-digit login OTP and the 4-digit visit-completion OTP.
*(API-4.02, 4.05)*

**B7 — Money invariants are unenforced.** No transaction or idempotency on payment verification;
`booking_number` from a 9,000-value space against a UNIQUE column; coupon usage limits and the
`coupon_usage` reuse guard are dead code. *(API-5.01, 5.02)*

**B8 — OTPs are written to a log file and never delivered.** `WhatsAppClient` is bound to
`LogWhatsAppClient`, so the physio dual-OTP verification gate is decorative and the OTP plus
patient phone land in `storage/logs/laravel.log` at `LOG_LEVEL=debug`. *(API-7.04)*

**B9 — Scheduled jobs run in UTC in a Delhi-NCR product.** Reminders at 23:30 IST; the no-show
sweep compares a local wall-clock column against a UTC clock and can mark future sessions as
no-shows. No overlap or single-server guard. *(API-6.03)*

**B10 — No versioning, environment separation, deploy pipeline, rollback, backup, or DR.**
`housepital-api` is not under version control at all; one `.env` with `APP_DEBUG=true` and
`DB_USERNAME=root`; `api.housepital.in` does not resolve; no migration tooling on the Patient
API; no health check that checks anything. *(API-1.01, 1.02, 1.04, 5.03, 5.05, 7.01, 7.03, 7.05,
8.01–8.05)*

**B11 — A published data-deletion promise with no implementation.**
`help_faq_screen.dart:157` commits to 7-working-day account deletion; no deletion endpoint
exists on either backend. *(API-5.05)*

**B12 — The assistant Cloud Function is publicly invokable.** `cors: true` with no token check;
unbounded LLM spend against the project's Anthropic key. *(API-4.02, 3.01)*

---

## Warnings requiring risk acceptance

| # | Control | Risk | Mitigation | Owner / due |
|---|---|---|---|---|
| W1 | API-1.03 | Env-guarded debug endpoints (`dev-login`, `otp_debug`) have never run in their protective configuration because only `APP_ENV=local` exists | Set `APP_ENV=production` in a real deploy config and verify both return 404/null | OWNER-TBD, before first deploy |
| W2 | API-2.02 | No outbound timeouts on the Razorpay/Anthropic SDK calls; no content-type enforcement | Set explicit SDK timeouts below the function budget | OWNER-TBD |
| W3 | API-4.01 | Injection prevention verified by inspection only — zero tests; unsanitised patient text interpolated into a log line | Sanitise `LogWhatsAppClient`; add negative tests with the route test suite | OWNER-TBD |
| W4 | API-4.04 | Outbound calls lack response-size caps and timeouts | As W2 | OWNER-TBD |
| W5 | API-5.04 | Pending reschedule offer is keyed by phone, ambiguous across a patient's multiple packages | Key by package id | OWNER-TBD |
| W6 | API-6.01 | Configured database queue has zero producers; the two Artisan jobs have no identity/idempotency/DLQ | Move messaging onto the queue with a job identity | OWNER-TBD |
| W7 | API-6.02 | Reminder job sends synchronously, unbatched, with no checkpoint or per-send isolation | `chunkById` + per-send try/catch + `reminder_sent_at` | OWNER-TBD |
| W8 | API-6.04 | Reminders are not deduped; a replay double-messages every patient | Same `reminder_sent_at` guard | OWNER-TBD |

---

## Integration verdict: **merge, do not sync**

The brief asked for a concrete recommendation with checkable reasoning. Mine is: **collapse the
two databases into one, with the Laravel schema as the base, and rewrite the patient API's
queries against it.** Do not attempt a sync.

### The six shared nouns are not two views of one model

| Noun | `housepital` (Patient) | `housepital_db` (Staff) |
|---|---|---|
| `patients` | `VARCHAR(36)` UUID PK, `name`, no phone, `city` ENUM of 5 NCR cities, clinical JSON columns; **every** clinical table FKs to it (schema :9–39) | `BIGINT` auto PK, `full_name`, `phone` (indexed, not unique), `patient_ref`, lat/lng, `clinical_history` TEXT. Created 2026-07-16 **for the physio module only** and linked to `visit_packages` — **`deployments` does not reference it** and still carries `patient_name` as a denormalised string (`2026_07_16_100000…:20–53`) |
| `staff` | UUID PK, `name`, `role VARCHAR(50)`, rating/verification booleans (:75–90) | `BIGINT` PK, `full_name`, `role_code` ENUM of 12, encrypted Aadhaar/PAN/bank columns, `onboarding_status` ENUM of 7 |
| `deployments` | UUID PK, **FK `patient_id`**, `shift_type ENUM('12hr_day','12hr_night','24hr')`, `status ENUM(active,paused,completed,cancelled)`, `billing_cycle` (:147–165) | `BIGINT` PK, **FK `staff_id` only**, patient fully denormalised, `shift_type ENUM('HD_DAY','HD_NIGHT','FD')`, `status ENUM(active,completed,terminated,replaced)`, `service_model`, lat/lng |
| `attendance` | **`UNIQUE(deployment_id, date)`**, `status ENUM(checked_in,waiting,late,absent,on_leave,checked_out)`, `check_in_selfie` (:169–183) | **`UNIQUE(staff_id, date)`**, `status ENUM(pending,checked_in,checked_out,absent,leave,late)`, `check_in_selfie_url`, geofence lat/lng + `check_in_within_geofence` |
| `vitals` | **FK `patient_id`**, `systolic`/`diastolic`/`sugar`/`sugar_type`, `DECIMAL(5,1)` (:187–205) | **FK `staff_id`**, nullable `deployment_id`, **no patient reference at all**, `bp_systolic`/`bp_diastolic`/`blood_sugar`/`blood_sugar_type`, `INT`, plus six colour-status enums the patient schema has no column for |
| `daily_reports` | `UNIQUE(deployment_id, date)`, `patient_id` NOT NULL, `sections` JSON, `completed_tasks`/`total_tasks` (:209–229) | `UNIQUE(staff_id, date)`, no patient reference, `checklist_items` JSON, `checklist_completion_pct`, `sbar_handover` JSON |

*(Correction to the round-3 lead: the staff DB **does** now have a `patients` table — added by
`2026_07_16_100000_create_patient_tables.php`. It is physio-only and is not reachable from
`deployments`, so the substance of the observation stands, but "no `patients` table at all" is no
longer accurate and should not be repeated.)*

### Why a sync is not implementable

1. **There is no correlation key.** Patient identity is a UUID on one side and a BIGINT on the
   other, and on the staff side the three clinical tables (`vitals`, `daily_reports`,
   `attendance`) carry **no patient reference whatsoever** — a vitals reading is
   `(staff_id, deployment_id)` and `deployments` holds only `patient_name`. To produce the
   patient app's `vitals.patient_id` you must resolve a free-text name. A sync needs a stable
   key; there is not one to build on.
2. **The unique keys make the mapping lossy in one direction and ambiguous in the other.**
   Patient-side `attendance` is unique per `(deployment, date)`; staff-side per `(staff, date)`.
   One caretaker covering two patients in a day produces two rows in one model and one row in the
   other; that is not a transform, it is information loss.
3. **The enums do not overlap.** `shift_type` shares zero values (`12hr_day`/`12hr_night`/`24hr`
   vs `HD_DAY`/`HD_NIGHT`/`FD`); `attendance.status` and `deployments.status` each differ by two
   values. Every enum needs a hand-written, hand-maintained bidirectional map.
4. **You would be syncing against an unversioned schema.** The staff side has migrations with a
   ledger; the patient side has four idempotent `.sql` scripts with no `down` and no ledger. A
   sync process must be maintained against both; one of them cannot express change.
5. **There is nothing on the patient side to preserve.** Twenty proven code-vs-schema breaks,
   no build artifact, and no deployment mean `housepital` has never held a row of real data.
   The usual argument for sync-over-merge — "we cannot migrate live data" — does not apply.

### The merge, concretely

1. **Base = the Laravel schema**, because it is the only one in the estate with reversible,
   ledgered migrations, and because the staff app is the only writer whose writes actually occur
   in the field.
2. **Promote `patients` to first class.** Add `patient_id` FKs to `deployments`, `vitals`,
   `daily_reports`, `attendance`; backfill from `deployments.patient_name` +
   `family_contact_phone` and from `visit_packages.patient_phone`; then drop the denormalised
   `patient_*` columns from `deployments` and `visit_packages`.
3. **Reconcile `attendance` uniqueness to `(staff_id, deployment_id, date)`** — the superset that
   both models can express — and take the union of the two status enums.
4. **Bring the patient-only tables across unchanged**: `family_members`, `bookings`,
   `assessment_requests`, `payments`, `invoices`, `family_concerns`, `daily_ratings`,
   `notification_log`, `medications`, `medication_logs`, `coupons`, `coupon_usage`,
   `service_catalog`, `equipment_catalog`, `fcm_tokens`. They have no staff-side counterpart,
   so they merge without conflict. Choose `BIGINT` or `UUID` **once**, estate-wide.
5. **Delete `housepital-backend/sql/*.sql` as an independent schema** and regenerate every knex
   query against the merged migrations. Because all twenty drifts must be rewritten anyway, this
   costs nothing over fixing them in place — and fixing them in place would leave two schemas to
   keep in step forever.
6. **Keep the two APIs** as separate deployment units against the one database. That is the
   correct boundary: different clients, different authentication (Firebase ID tokens vs Sanctum),
   different rate profiles. What must be shared is the *store*, not the service.

**Falsifiable claim for the reviewer:** if any of (a) a stable patient key across both databases,
(b) a lossless `attendance` mapping, or (c) a single row of production data in `housepital` can
be produced, the sync option becomes arguable. None of the three exists in the source as read on
2026-08-03.

---

## BLOCKED-OWNER — needs access I do not have

| Item | Why it matters | Access required |
|---|---|---|
| Whether `api` (Firebase Functions) or `assistant` is deployed at all | Determines whether any finding is live rather than latent | Firebase console / `firebase functions:list` for project `housepital-patient` |
| Whether Cloud SQL instances for `housepital` and `housepital_db` exist, and whether either holds data | Decides merge sequencing and whether B4 is theoretical | GCP console / Cloud SQL |
| Firebase API-key restrictions and App Check status | The only real control on the public assistant function | Firebase console |
| Whether the Razorpay webhook is registered, and with which secret | Confirms B3's exploitability | Razorpay dashboard |
| DNS ownership of `housepital.in` and whether `api.` was ever delegated | B10 | Registrar |
| Anthropic spend limit on the project key | Bounds B12 | console.anthropic.com |
| Whether the staff API is running anywhere (its `.env` says `localhost:8000`) | Decides whether B2/B3/B6 are live | Hosting provider |

---

## Limitations of this audit

- **Source review only (MASTER-4.04).** No release artifact and no production-like environment
  was available for either backend. `functions/lib` has never been built and neither MySQL
  database is reachable from this machine. Every runtime claim is derived from reading code
  against DDL, not from executing it.
- **The MySQL error classifications in the drift table are inferred from the DDL**, not observed.
  Whether a given drift produces `ER_BAD_FIELD_ERROR` at parse time or
  `ER_NO_DEFAULT_FOR_FIELD` at insert time depends on `sql_mode`, which is unset in
  `config/cloudSql.ts`. The *presence* of the drift is directly verifiable from the two files
  cited in each row; only the precise error code is inferred.
- **Per the audit brief I did not run `flutter test`, `flutter build`, `npm test`, or
  `php artisan test`.** Test *counts* were obtained by reading and grepping the test sources.
- **`housepital-api` is not a git repository**, so no history-based analysis (blame, secret
  scanning across refs, review trail) was possible for the staff API. The secret scan I did run
  covered the patient-app repository only.
- **Dependency vulnerability scanning was not performed** on either backend's lockfile.
- Endpoint counts are from static route enumeration (`grep 'router\.(get|post|put|delete)('`
  and `routes/api.php`), not from a running router dump. `housepital-backend` commit `3f4250d`
  claims "all 67 endpoints"; I count 54 registered handlers.
- The Firestore rules were read but not tested against the emulator's rules test suite.
