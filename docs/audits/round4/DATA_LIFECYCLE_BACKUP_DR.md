# Data Lifecycle, Backup & Disaster Recovery — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** Data Lifecycle / Backup / DR module · **Scope:** source review of
`housepital_patient_app` @ `9127713`, `../housepital-backend` @ `7417387`, and `../housepital-api`
(untracked working tree — see DATA-1.04). See Limitations.

---

## Applicability

**MASTER-3.10 applies — "Yes: Health data throughout; DPDP Act 2023 applies"**
(`docs/audits/round4/00_MASTER_APPLICABILITY_AND_GATE.md:70`).

Everything the checklist governs is present in this product:

- **Personal health data.** `patients` carries `conditions`, `medications`, `allergies`,
  `diagnosis`, `iv_central_line`, `feeding_type`, `mental_condition`, `bp_sugar_insulin`
  (`../housepital-backend/sql/001_initial_schema.sql:9-39`). On device, `RemindersProvider`
  stores free-text clinical reminders and says so
  (`lib/providers/reminders_provider.dart:191-193`: *"Reminder titles are free text a family
  types about one patient ('insulin before dinner'), so they are clinical content"*).
- **Cloud storage.** Firebase Storage holds chat photos and concern-evidence photos
  (`storage.rules:75-93`); Firestore holds chat messages, vitals, attendance, notifications
  (`firestore.rules:66-146`); Cloud SQL MySQL `housepital` is the relational store
  (`../housepital-backend/sql/001_initial_schema.sql:3`).
- **Legal retention.** The app tells the user, in production copy, that it retains invoices
  because *"Indian tax law requires us to retain"* them
  (`assets/i18n/en.json` → `delete_account_kept_1`).
- **Portability.** DPDP Act 2023 §11 (right to access) and §12 (right to erasure) are both
  cited in the codebase (`lib/screens/settings/delete_account_screen.dart:19-21`).

This module has **never been audited**. There is no round-3 report for it, so there is no
prior-round status table; this is a first look and is written systematically rather than as a
delta.

---

## Data inventory

This inventory did not previously exist in any form
(`00_MASTER_APPLICABILITY_AND_GATE.md:86` records its absence). It is produced here because
DATA-1.01 cannot be graded without it. **Producing it is not the same as the product having
one** — see DATA-1.01/1.02.

### A. On-device: SharedPreferences (iOS `NSUserDefaults` plist, Android XML — unencrypted)

| Key | Written at | Contents | Class | Cleared on patient switch | Cleared on logout |
|---|---|---|---|---|---|
| `has_onboarded` | `auth_provider.dart:196` | bool | Device | No | Yes |
| `preferred_language` | `auth_provider.dart:197`, `app_provider.dart:107` | `en`/`hi` | Account | No | Yes |
| `theme_mode` | `theme_provider.dart:55` | enum | Device | No | Yes |
| `profile_photo_path` | `app_provider.dart:121` | **filesystem path to a face photo** | **Personal** | No (memory only, `app_provider.dart:234`) | Yes (key only — see below) |
| `notif_staff_checkin`, `notif_daily_report`, `notif_weekly_summary`, `notif_promotional`, `notif_late_checkin`, `notif_noshow`, `notif_vitals_red`, `notif_payment_reminder`, `notif_booking_confirmation` (9 keys) | `app_provider.dart:143` | bool ×9 | Account | No | Yes |
| `housepital_cart_items` | `cart_provider.dart:222` | services/equipment in cart | **Health-adjacent** (reveals condition) | Yes (`session_scope.dart:89`) | Yes |
| `housepital_saved_items` | `cart_provider.dart:226` | saved-for-later items | **Health-adjacent** | Yes | Yes |
| `housepital_orders_<patientId>` | `orders_provider.dart:205` | **full purchase + care history** | **Health + financial** | No — read of a different key by design (`orders_provider.dart:47-52`) | Yes |
| `housepital_assessments_<patientId>` | `orders_provider.dart:206` | nursing assessment requests | **Health** | No — as above | Yes |
| `housepital_reminders` | `reminders_provider.dart:181` | **free-text clinical reminders** | **Health** | Yes (`reminders_provider.dart:194-204`) | Yes |
| `housepital_saved_addresses` | `address_selection_screen.dart:126` | **home addresses where a nurse is dispatched** | **Personal (location)** | Yes (`session_scope.dart:50`) | Yes |
| `daily_rating_YYYY-MM-DD` (unbounded, one per day) | `my_care_screen.dart:615` | 1–5 satisfaction | Personal | Yes (prefix sweep, `session_scope.dart:129-133`) | Yes |
| `housepital_cache_dashboard_<patientId>` | `cache_service.dart:19` via `app_provider.dart:266` | **deployment, attendance, latest vitals, today's report, amount due** | **Health + financial** | Yes (`CacheService.clear()`) | Yes |
| `housepital_schema_version` | `store_migrator.dart:36` | int | Device | No | **Preserved by design** (`auth_provider.dart:232`) |
| `housepital_pending_deletion` | `delete_account_screen.dart:84` | reference, timestamp, `patientId`, `deliveredToServer:false` | **Personal (identifier)** | No | **Preserved by design** (`auth_provider.dart:233`) |
| `__quarantine_v1_housepital_orders`, `__quarantine_v1_housepital_assessments` | `store_migrator.dart:208` | **verbatim copy of pre-v2 order and assessment history** | **Health + financial** | **No** | Yes (swept by the `getKeys()` loop, `auth_provider.dart:235-238`) |
| `housepital_orders`, `housepital_assessments` (legacy v1) | pre-2026-08-03 builds | as above | **Health + financial** | n/a — removed by migration | n/a |

Legacy key count: 18 distinct key *shapes*, three of which (`housepital_orders_*`,
`daily_rating_*`, `__quarantine_v*_*`) are unbounded families.

### B. On-device: memory only — lost on app termination, not merely device loss

| Data | Site | Persisted? |
|---|---|---|
| **Manually entered vitals** (BP, pulse, SpO₂, temperature, blood sugar) | `app_provider.dart:324-339` | **No.** `addVitalReading` appends to `List<VitalReading> _vitalsHistory` (`app_provider.dart:41`) and attempts one best-effort API POST whose failure is logged and swallowed (`app_provider.dart:334-338`). No SharedPreferences write exists. |
| **Medication dose logs** (patient tapping "taken") | `medication_provider.dart:110-126` | **No.** `logDoseToday` appends to `_todayLogs` (`medication_provider.dart:16`), which is wholesale *overwritten* by the next `loadMedications` (`medication_provider.dart:226`). |
| **Uploaded medical documents** | `document_repository_screen.dart:629-700` | **No.** `_uploadFromGallery` picks an image and passes **only `image.name`** to `_showCategorizeDialog` (line 636); the confirm handler inserts a metadata row into a `State` field `_documents` with a **hard-coded `fileSizeBytes: 350000`** (line 691). The image bytes are never read, never uploaded, never written to disk. |
| **Added patients** | `app_provider.dart:245-249` | **No** — `// TODO(persistence): persist to SharedPreferences / backend.` |

### C. Device filesystem (outside SharedPreferences)

| Artifact | Site | Lifecycle |
|---|---|---|
| Profile photo JPEG | `settings_screen.dart:70-74`, `patient_profile_screen.dart:205-209` | `ImagePicker` writes to the app's **tmp/cache** directory; only the *path* is stored. The file is never copied into app storage and **never deleted** by logout, patient switch, or account deletion. `grep -rn "getApplicationDocumentsDirectory\|copy(" lib/` → 0 hits. |
| Invoice PDF | `invoice_pdf_service.dart:261-264` | `Printing.sharePdf` writes a temp file. No cleanup call anywhere. |
| Doctor-handover PDF | `handover_report_service.dart:323` | Same. |

### D. Firestore (project `housepital-patient`, `asia-south1` per `firebase.json:12`)

| Path | App access | Class |
|---|---|---|
| `chat_messages/{patientId}/messages/{messageId}` | read + **create** (`chat_screen.dart:45-48, 82`) | **Health** (free text to a coordinator) + photo URLs |
| `active_sessions/{deploymentId}` | **write** (OTP, `staff_otp_verification_screen.dart:83-89`) + read (`order_tracking_screen.dart:150`) | **Authentication secret** (4-digit OTP in plaintext) |
| `patients/{patientId}/attendance/{date}` | read (`firebase_service.dart:239-245`) | Health-adjacent |
| `patients/{patientId}/vitals` | read (`firebase_service.dart:257-267`) | **Health** |
| `users/{userId}/notifications` | read (`firebase_service.dart:279-287`) | Personal |
| `user_patients/{userId}/patients/{patientId}` | backend only (`../housepital-backend/functions/src/routes/auth.ts:132-133`) | Personal (relationship graph) |
| `fcm_tokens/{userId}` | declared in rules (`firestore.rules:142`); **no client code path** | Device identifier |
| `vitals_live/{patientId}` | declared in `../housepital-backend/firestore.rules:22`; **no client code path** | **Health** |

### E. Firebase Storage

| Path | Written at | Class | Deletable? |
|---|---|---|---|
| `chat/{patientId}/{ts}_{filename}` | `chat_screen.dart:133` via `firebase_service.dart:116-143` | **Health** (photos of a patient/wound/prescription) | **No** — `allow update, delete: if false` (`storage.rules:83`) |
| `concerns/{patientId}_{batchTs}/{i}_{name}` | `raise_concern_screen.dart:328` | **Health** | **No** — `storage.rules:90` |

### F. MySQL — three divergent definitions of the same domain

| Definition | DB | Tables | Holding health data |
|---|---|---|---|
| `../housepital-backend/sql/001_initial_schema.sql` | `housepital` | 21: `patients`, `family_members`, `fcm_tokens`, `staff`, `service_catalog`, `equipment_catalog`, `deployments`, `attendance`, `vitals`, `daily_reports`, `bookings`, `assessment_requests`, `payments`, `invoices`, `family_concerns`, `daily_ratings`, `notification_log`, `medications`, `medication_logs`, `coupons`, `coupon_usage` | `patients`, `vitals`, `daily_reports`, `medications`, `medication_logs`, `assessment_requests`, `family_concerns`, `attendance` |
| `database/schema.sql` (this repo) | `housepital` — **same name, 16 tables, no `medications`/`medication_logs`/`equipment_catalog`/`coupons`** | 16 | same subset |
| `../housepital-api/database/migrations/` (Laravel) | separate | ~25 incl. `patients`, `patient_documents`, `vitals`, `daily_reports`, `photo_logs`, `grievances`, `audit_logs`, `otp_verifications` | `patients`, `patient_documents`, `vitals`, `daily_reports`, `photo_logs`, `grievances` |

`../housepital-api/database/migrations/2026_02_25_100000_create_housepital_tables.php:328-337`
stores the **OTP in plaintext** with an `expires_at` column and no reaper.

---

## Control results

| Control | Outcome | Evidence | Impact / mitigation (Warnings and Fails) |
|---|---|---|---|
| **DATA-1.01** Every data category mapped collection→deletion | **Fail** | No such map exists in either repo. `docs/DATABASE_SCHEMA.md` documents MySQL columns and Firestore paths only — it contains no local-store section, no lifecycle column, no deletion column (`grep -niE "retention\|delete\|backup" docs/DATABASE_SCHEMA.md` → 0 hits outside `ON DELETE CASCADE` DDL). The inventory above had to be reconstructed from source for this audit. | 18 SharedPreferences key shapes, 8 Firestore paths, 2 Storage paths and 3 MySQL schemas exist with no map. Nobody can answer "where does a patient's blood-sugar reading live" without re-doing this work. **Owner: OWNER-TBD. Due: before first external data-subject request.** Mitigation: adopt §"Data inventory" above as `docs/DATA_INVENTORY.md` and add a CLAUDE.md contract clause requiring it to be edited in the same commit as any new store. |
| **DATA-1.02** Each item records sensitivity, owner, source, purpose, scope, authoritative store, recipients, processors, residency, retention, backup behavior | **Fail** | None of the eleven attributes is recorded for any item anywhere. The only residency fact in either repo is `firebase.json:12` `"location": "asia-south1"` and the comment `-- Cloud SQL instance: asia-south1` (`../housepital-backend/sql/001_initial_schema.sql:3`). No processor list, no retention value, no backup attribute. | Residency is the one attribute that is (incidentally) correct for DPDP purposes. Everything else is unrecorded. **OWNER-TBD**, same ticket as 1.01. |
| **DATA-1.03** Personal/health/auth/financial/location/confidential classified consistently | **Fail** | Classification exists in three code comments and nowhere else: `app_provider.dart:219` (`_vitalsHistory.clear(); // manually entered readings — PHI`), `reminders_provider.dart:191-193`, `session_scope.dart:96-98`. There is no scheme, and identically sensitive items are handled inconsistently — `housepital_reminders` is wiped on patient switch (`reminders_provider.dart:199`) while `__quarantine_v1_housepital_orders`, which holds the same patient's order history, is not (`session_scope.dart:49-51` lists one key). The plaintext OTP in `active_sessions` (`staff_otp_verification_screen.dart:85`) and in `otp_verifications.otp` is nowhere classified as an authentication secret. | Inconsistent classification is why the quarantine gap and the profile-photo file gap both exist: no one asked "what class is this" before deciding whether to wipe it. **OWNER-TBD.** |
| **DATA-1.04** Unknown/unused/duplicated/shadow/legacy stores identified and removed or governed | **Fail** | **(a)** Three divergent MySQL schemas define the same entities, two of them claiming database name `housepital` (`database/schema.sql:6` vs `../housepital-backend/sql/001_initial_schema.sql:3`); `database/schema.sql` omits `medications`, `medication_logs`, `equipment_catalog`, `coupons`, `coupon_usage`. **(b)** Two divergent `firestore.rules` files — `md5 firestore.rules ../housepital-backend/firestore.rules` → `dd02afa1…` vs `3154fe51…`; they use **incompatible authorization models** (this repo: `request.auth.uid == patientId`, `firestore.rules:67`; backend: `exists(/…/user_patients/$(request.auth.uid)/patients/$(patientId))`, `../housepital-backend/firestore.rules:16`). Both repos' `firebase.json` point at their own copy. **(c)** `vitals_live/{patientId}` and `fcm_tokens/{userId}` are declared in rules with **zero** client or server code paths — shadow collections. **(d)** `../housepital-api` **is not a git repository** (`git log` → `fatal: not a git repository`): a MySQL schema holding `patient_documents` and `vitals` has no version history and no remote. | (d) is the most serious: the staff API's schema and code exist only on one laptop. A disk failure loses it outright, and there is no backup (DATA-6). **OWNER-TBD. Due: immediately — `git init` + remote is a ten-minute fix.** For (a)/(b), one file must be designated authoritative and the other deleted. |
| **DATA-2.01** Collection limited to necessary data | **Warning** | Client-side collection is genuinely modest — the app asks for name, phone, address, language and clinical fields the service needs. But `patients` declares 12 free-text clinical columns (`diagnosis`, `iv_central_line`, `feeding_type`, `mental_condition`, `motion_status`, `bp_sugar_insulin`, `discharge_summary_available`, `requirement`, `height`, `weight`, `dietary_restrictions`, `mobility_status` — `sql/001_initial_schema.sql:13-33`) that **no patient-app route reads or writes**; and `otp_verifications` retains a plaintext OTP indefinitely. | Impact: schema-level over-collection, not yet realised (no production writes confirmed). Mitigation: drop or defer the unused clinical columns before the backend is pointed at, and hash or reap OTPs. **OWNER-TBD. Due: before backend go-live.** |
| **DATA-2.02** Purpose changes / new recipients / new retention require review before processing expands | **Fail** | No review gate exists. `CLAUDE.md` has an explicit "Storage & session contracts" section that requires a `SessionScope` entry and a test for new patient-scoped state — it has **no clause** requiring review when *collection* or *purpose* expands, and no privacy owner is named. There is no `PRIVACY_POLICY.md`, no DPIA, no processor register (`00_MASTER_APPLICABILITY_AND_GATE.md:39`). | The existing `SessionScope` contract proves the team can enforce a data rule via CLAUDE.md; the gap is that no rule covers *new* collection. Cheap fix. **OWNER-TBD.** |
| **DATA-2.03** Defaults, permissions, consent, notices and store declarations reflect actual collection | **Fail** | **(a)** `delete_account_removed_3` promises deletion of *"Medicines, reminders and documents"* — no document is ever stored (§B), so the notice describes a store that does not exist. **(b)** `delete_account_removed_4` and `delete_account_done_device` state *"everything stored on this phone has been erased"*; the profile photo JPEG in the picker cache is not erased (§C) and `housepital_schema_version` / `housepital_pending_deletion` survive (`auth_provider.dart:231-234` — documented and non-PHI, but the copy is absolute). **(c)** `delete_account_kept_1` asserts an active tax-law retention of invoices; no invoice is retained anywhere on deletion, because no invoice exists server-side. **(d)** No app-level `ios/Runner/PrivacyInfo.xcprivacy` — only vendored Pod manifests (`find ios -name PrivacyInfo.xcprivacy` → 24 hits, all under `ios/Pods/`), while the app uses `NSUserDefaults`, a required-reason API. | (a)–(c) are inaccurate statements to a patient about their medical records — the exact failure class `delete_account_screen.dart:24-30` was written to prevent, reappearing one layer up in the copy. (d) is an App Review rejection risk. **OWNER-TBD. Due: before submission.** |
| **DATA-2.04** Synthetic / on-device / ephemeral / less-precise data used where it meets the need | **Pass** | Deliberate and repeated: PDFs are generated on-device rather than server-side (`invoice_pdf_service.dart`, `handover_report_service.dart`); the Sahayak assistant uses a **local** intent matcher in demo builds instead of sending transcripts to a model (`assistant_local_actions.dart:13`, `CLAUDE.md` Architecture notes); the dashboard cache carries a 30-minute TTL (`cache_service.dart:7`); `DemoData` supplies synthetic records for 12 declared sources (`lib/data/demo_mode.dart:24-35`) rather than seeding real ones. | — |
| **DATA-3.01** Authoritative and derived stores, caches, replicas, indexes, logs, exports, local files and backups have documented consistency rules | **Fail** | No consistency rules are documented, and two are demonstrably broken. **(a)** The app **writes** `active_sessions/{deploymentId}` (`staff_otp_verification_screen.dart:83-89`) while *both* rules files deny client writes there (`firestore.rules:134`, `../housepital-backend/firestore.rules:17`). **(b)** This repo's rules gate every collection on `request.auth.uid == patientId`, but `grep -rn "\.uid" lib/` returns **0 hits** — the client never reads a uid, and every id it sends is a backend id (`pat_demo_rajesh`). `storage.rules:20-33` states this explicitly and refuses to make the same mistake. Deploying `firestore.rules` as written therefore denies 100% of chat sends, OTP writes, vitals reads and notification reads. | The local store is currently the only store the app can actually read or write. If the rules are deployed as written the app's Firestore paths silently fail; if they are not deployed, the live rules are unknown. Either way there is no documented reconciliation between SharedPreferences, `CacheService`, Firestore and MySQL. **OWNER-TBD. Due: before backend go-live.** |
| **DATA-3.02** Encryption, key management, access control, tenant isolation, integrity constraints, transactions, audit logging match classification | **Fail** | **Encryption:** `grep -n "secure_storage" pubspec.yaml` → 0 hits; `grep -rn "FlutterSecureStorage" lib/` → 0 hits. Every item in §A — order history, clinical reminders, cached vitals, dispatch addresses — sits in plain `NSUserDefaults` / Android XML, protected only by platform file protection. **Isolation:** `storage.rules:33-36` states in the file itself that it *"does NOT stop one authenticated user from reading another patient's photo if they can guess the path."* **Integrity:** MySQL is strong here — FKs with `ON DELETE CASCADE` throughout and `UNIQUE KEY uk_deployment_date` (`sql/001_initial_schema.sql:250`). **Audit logging:** `audit_logs` exists in Laravel (`…create_housepital_tables.php:311`) with an Eloquent model but **no writer** — `grep -rn "AuditLog" app/ routes/` returns only the model and one `hasMany`. | Local PHI at rest is unencrypted; cross-patient reads in Storage are possible for any authenticated user; no access to health data is attributable. **OWNER-TBD. Due: before first real patient.** Mitigation: `flutter_secure_storage` for the health-class keys, custom claims per `storage.rules:41-49`. |
| **DATA-3.03** Validation covers source authenticity, schema, ranges, referential integrity, uniqueness, encoding, file safety, corruption detection | **Warning** | Real coverage exists: Zod on all backend POST routes (`../housepital-backend` commit `7417387`), 1 MB body limit and 10 s query timeout (`d2232d9`, `functions/src/index.ts:81`), FK/unique constraints in MySQL, image-only + <10 MB file safety in `storage.rules:70-73`, `text.size() < 5000` on chat (`firestore.rules:75`), and tolerant JSON readers on the client that quarantine rather than overwrite (`store_migrator.dart:204-222`). Missing: no range validation on vitals before local display (`constants.dart:32 vitalRanges` is presentational), no encoding checks, and **no corruption detection on the local store** — a truncated `housepital_orders_<id>` blob is indistinguishable from an empty one. | Impact: a corrupt local blob degrades to "no orders" silently. Mitigation: a length/checksum field in the persisted wrapper. **OWNER-TBD.** |
| **DATA-3.04** Administrative/support access least-privilege, time-bound, purpose-limited, reviewed, attributable | **Fail** | The only administrative access path defined anywhere is `StoreMigrator`'s promise that *"support can retrieve a patient's order history"* from `__quarantine_v1_*` (`store_migrator.dart:22, 62-64`). There is no mechanism by which support can reach a key on a patient's phone, no procedure, no authorisation step, and no record of access. Server-side, `audit_logs` is unwritten (see 3.02). | A documented support capability that does not exist is worse than none: it will be cited in a support conversation and cannot be honoured. **OWNER-TBD.** |
| **DATA-3.05** Temporary files, caches, downloads, previews, logs and failed partial operations have quotas and cleanup deadlines | **Fail** | **(a)** `CacheService` has a 30-minute TTL but **never deletes** expired entries — `get()` returns `null` on expiry (`cache_service.dart:31`) and leaves the blob, containing vitals and amount-due, on disk forever; the only remover is `clear()` (line 38), called on patient switch/logout. **(b)** `__quarantine_v*_*` has **no TTL, no reaper and no cap** — see the dedicated assessment below. **(c)** `daily_rating_YYYY-MM-DD` grows one key per day forever with no cap; only a patient switch or logout sweeps it (`session_scope.dart:129-133`). **(d)** Shared PDFs and the profile-photo JPEG are left in temp directories with no cleanup (§C). | Unbounded, undeleted local PHI on a device that may never log out. **OWNER-TBD. Due: before first release.** Mitigation: delete on expiry in `CacheService.get`; a bounded quarantine reaper; cap `daily_rating_*` to N days. |
| **DATA-4.01** Retention periods defined per category and purpose (active use, inactivity, closure, hold, backups, logs) | **Fail** | `grep -rniE "retention" docs/*.md README.md ARCHITECTURE.md PROJECT.md CLAUDE.md` returns exactly two hits, neither about data: a **payment** minimum (`docs/BUSINESS_RULES.md:76` "Minimum retention: Rs 2,000") and CI **artifact** retention (`docs/CHANGELOG.md:515` "7d retention"). No data-retention period is defined for any category, in any repo, for active use, inactivity, closure, hold, backups or logs. | Nothing is ever scheduled for deletion because nothing has a deadline. **OWNER-TBD.** |
| **DATA-4.02** Automated retention jobs monitored, idempotent, safe against over-deletion, verified against authoritative counts | **Fail** | There are no retention jobs. The only scheduler in either backend is `../housepital-api/routes/console.php:12-13` — `physio:send-reminders` and `physio:mark-no-shows`; neither deletes anything. `otp_verifications` carries `expires_at` (`…create_housepital_tables.php:332`) with no job that acts on it. `notification_log`, `audit_logs`, `attendance`, `vitals` grow without bound. | **OWNER-TBD.** |
| **DATA-4.03** Deletion propagates to primary stores, replicas, indexes, files, analytics, processors, devices and backup expiry | **Fail** | Deletion propagates to **nothing** outside the device. `grep -rn "router.delete\|\.delete(" ../housepital-backend/functions/src/routes/` returns three hits: two `family_members` row deletes and one medication route — **no patient, vitals, reports, bookings, invoices or concerns delete endpoint exists**. `grep -rn "DELETE FROM" functions/src/` → 0. Firebase Storage objects are **immutable by rule**: `allow update, delete: if false` on both `chat/` (`storage.rules:83`) and `concerns/` (`storage.rules:90`). Chat messages are likewise `allow update, delete: if false` (`firestore.rules:78`). On device, the profile-photo JPEG survives the wipe (§C). | A patient who exercises DPDP §12 today gets: local prefs erased, one Firebase credential deleted, and **every photo they ever sent, every chat message, and their face photo left in place**, with no endpoint capable of removing them. **Release-blocking.** **OWNER-TBD. Due: before first real patient.** |
| **DATA-4.04** Legal/fraud retention exceptions narrowly scoped, access-restricted, disclosed, deleted when the obligation ends | **Fail** | The app **discloses** two exceptions (`delete_account_kept_1`: invoices per Indian tax law; `delete_account_kept_2`: "anything an ongoing medical or legal matter requires"). Neither is scoped (no period named), neither is access-restricted (no separate store, no restricted role), neither has an end-of-obligation deletion, and — because nothing is retained server-side at all — neither is implemented. `delete_account_kept_2` is open-ended by construction. | A disclosed but unimplemented and unbounded retention exception is a DPDP §8(7) exposure and misleads the user about what is being kept. **OWNER-TBD. Due: before submission** (copy change is cheap; the control is not). |
| **DATA-4.05** Soft deletion not treated as completed deletion unless followed by an enforced hard-delete or de-identification schedule | **Fail** | `/delete-account` writes `housepital_pending_deletion` (`delete_account_screen.dart:83-91`). `grep -rn "pendingDeletionKey\|housepital_pending_deletion" lib/ test/` returns **three hits: the constant, the single writer, and the preserve-list entry in `auth_provider.dart:233`. There is no reader, in the app or in either backend.** There is no replay mechanism, no queue, no schedule, and no hard-delete. The record's own field is `'deliveredToServer': false` and nothing ever sets it true. Zero tests reference it. | The screen's own doc comment is honest about this (`delete_account_screen.dart:41-43`), and the user-facing copy correctly separates "Done" from "Requested — not yet done" (`delete_account_done_server`). That honesty is why this is a Fail on the *control* rather than a misrepresentation finding. But the record is inert: on the user's next reinstall it is gone, and the reference number they were told to quote resolves to nothing. **Release-blocking under DPDP §12.** **OWNER-TBD.** |
| **DATA-5.01** Access, correction, export, objection, consent withdrawal and deletion requests have authenticated, accessible, time-bound workflows | **Fail** | Only deletion has a UI, and it is not authenticated server-side, not time-bound (no SLA stated — `delete_account_done_server` says only "call us"), and terminates in an unread local key (4.05). There is **no** access request, no correction request, no objection, and no consent-withdrawal path (notification toggles are preferences, not consent records). No endpoint in either backend implements any of them (`grep -rniE "gdpr\|dpdp\|erasure\|data export" ../housepital-backend/functions/src/` → 0 hits). | DPDP 2023 §11/§12/§13 unmet. **Release-blocking.** **OWNER-TBD.** |
| **DATA-5.02** Exports complete, understandable, portable, safely delivered, no cross-user disclosure | **Fail** | Two export paths exist. **(a) Invoice PDF** (`invoice_pdf_service.dart:96, 261-264`) — real order data, single order, not a portability export. **(b) Doctor-handover PDF** (`handover_report_service.dart:98-114`) — **built entirely from `DemoData`**: `DemoData.patient`, `DemoData.medicalHistory`, `DemoData.medications`, `DemoData.vitalsHistory`, `DemoData.todayReport`, `DemoData.activeServices`, `DemoData.icuServiceDetail.staffOnDuty`, `DemoData.upcomingAppointments` (lines 107-114), and it raises `DemoMode.markServingDemoData(DemoMode.sourceHandover)` (line 105) to say so. The filename is derived from `DemoData.patient.name` (line 308). Neither path exports the user's manually entered vitals, dose logs, reminders or addresses. Format is PDF — human-readable but not machine-portable. | The one export the product describes as "the patient's medical record" hands a **fabricated patient's** history to a doctor. The `DemoMode` pill is the only signal, and it is an overlay a user can miss. No DPDP-compliant access/portability export exists at all. **Release-blocking.** **OWNER-TBD.** |
| **DATA-5.03** Shared/jointly owned/public/purchased/legally retained/user-generated content has explicit rights behavior on deletion | **Fail** | The product is explicitly multi-party — one patient watched by the patient, a primary contact and family members (`session_scope.dart:22-25`), with a role model (`permissions.dart:8-14`). Nothing defines whose data a chat message, a concern photo, a daily rating or an order is when one of those parties deletes their account. Chat and concern photos are append-only by rule and unreachable by any delete path (4.03). `family_members` has `ON DELETE CASCADE` from `patients` (`sql/001_initial_schema.sql:57`) — i.e. deleting a patient silently deletes every family member's record, which is the opposite of an explicit rights decision. | A family member deleting their account has no defined effect on the patient's record, and vice versa. **OWNER-TBD.** |
| **DATA-5.04** Request execution verified at authoritative stores and processors, not inferred from a UI confirmation | **Fail** | The deletion flow's only verification is a dialog (`delete_account_screen.dart:149-168`). `credentialDeleted` is the one genuinely verified fact and it is reported honestly. Everything else — "everything stored on this phone has been erased" — is asserted, not read back; no post-wipe `prefs.getKeys()` assertion exists, and the profile-photo file that survives disproves the assertion (§C). Nothing is verified at Firestore, Storage or MySQL because no deletion reaches them. | **OWNER-TBD.** |
| **DATA-6.01** Backup scope, frequency, retention, encryption, key separation, immutability, geography, ownership, monitoring match recovery objectives | **Fail** | **No backup exists in source, for any store.** Exhaustive search across both backends (`grep -rniE "backup\|mysqldump\|restore\|point-in-time\|pitr\|snapshot\|retention\|disaster\|rpo\|rto"` over `*.ts *.js *.json *.md *.sql *.yaml *.yml *.php`, excluding `node_modules`/`vendor`) returns **zero true positives** — every hit is the substring "restore"/"backup" inside unrelated prose (e.g. `sql/003_seed_equipment.sql:14` "home ventilation backup kits") or a Firestore import line. There is no `.github/workflows` in either backend, no Terraform, no `cloudbuild.yaml`, no Dockerfile (`find . -name "*.tf" -o -name "cloudbuild*" -o -name "Dockerfile"` → 0). The single backup artefact in the entire project is a **documentation example line**: `mysqldump -h HOST -u USER -p DB > backup.sql  # Backup` (`docs/ENVIRONMENT_SETUP.md:392`) — no schedule, no encryption, no destination, no retention, no owner, no monitoring. Firestore has no export schedule declared in either `firebase.json`. | If a production Cloud SQL instance exists, its recoverability rests entirely on whatever the GCP console defaults to, which this audit cannot see (BLOCKED-OWNER below). **Release-blocking for backend go-live.** **OWNER-TBD.** |
| **DATA-6.02** Backups include databases, files, configuration, schemas, encryption metadata, dependency versions needed to restore safely | **Fail** | Vacuously unmet — no backup exists. Compounding it: the **schema itself is not safely recoverable**. `../housepital-api` is not under version control (DATA-1.04d), and the two MySQL schema files that are tracked disagree. Firebase Storage objects have no backup and no lifecycle rule. Firestore has no export configured. | Restoring MySQL from a hypothetical dump would still require a schema no one can identify as authoritative. **OWNER-TBD.** |
| **DATA-6.03** Backup jobs detect missing sources, partial success, corruption, quota exhaustion, freshness drift | **Fail** | No jobs, therefore no monitoring. There is no alerting of any kind in either backend (`functions/src/utils/logger.ts` logs to Cloud Logging; nothing thresholds it). | **OWNER-TBD.** |
| **DATA-6.04** Sensitive data excluded from ordinary backup documented with alternate recovery or accepted-loss decision | **Fail** | The largest excluded category is **all of §A and §B** — the entire on-device store, which is currently the app's only working store. No accepted-loss decision is recorded anywhere. See the demo-mode quantification below. | This is the single most consequential finding in the module and it has never been written down. **Release-blocking.** **OWNER-TBD.** |
| **DATA-7.01** RPO and RTO defined by tier with approved business and user impact | **Fail** | `grep -rniE "rpo\|rto\|recovery objective"` across both backends and all `docs/*.md` → 0 hits. No tiering, no objectives, no approval. | **OWNER-TBD.** |
| **DATA-7.02** Restore drills use representative encrypted backups and verify counts, relationships, files, permissions, keys, app compatibility, critical journeys | **Fail** | **No restore has ever been performed or documented.** No drill record, no runbook, no restore script. `docs/DEPLOYMENT_GUIDE.md` contains no restore section. | An untested restore is not a restore. **OWNER-TBD.** |
| **DATA-7.03** Regional, account, provider, accidental-deletion, ransomware, corruption, operator-error and credential-loss scenarios have playbooks | **Fail** | No playbook exists for any scenario. `docs/TROUBLESHOOTING.md` covers build and simulator problems only. Credential loss is acute here: `../housepital-api` exists on one machine with no remote (DATA-1.04d), and the Cloud SQL connection name is a commented-out line in `.env.example` (`../housepital-backend/.env.example:7`). | **OWNER-TBD.** |
| **DATA-7.04** Failover and restore prevent split brain, stale overwrite, duplicate processing, cross-tenant leak, unsafe return to service | **Warning** | Genuine, tested controls exist **at the device level**, and they are the strongest data work in the codebase: `StoreMigrator` refuses to migrate backwards when a newer store is found (`store_migrator.dart:141-151`), stamps the last *good* version on a failed step so it is retried rather than falsely marked done (`store_migrator.dart:166-177`), quarantines rather than overwrites (`store_migrator.dart:65-73`), and `OrdersProvider.clearPatientScopedData()` is memory-only precisely so a patient switch cannot write `[]` over the outgoing patient's history (`CLAUDE.md` Storage contracts; asserted in `test/providers/patient_scope_isolation_test.dart:300`). Cross-tenant leak is covered by `SessionScope` and its isolation test. What is missing is any **server-side** failover design, and the Storage cross-patient read gap that `storage.rules:33-36` documents. | Impact limited to the server tier, which is not live. Mitigation: carry the device-level discipline into the backend design. **OWNER-TBD. Due: before backend go-live.** |
| **DATA-7.05** Recovery evidence records actual time, data loss, defects, decisions, corrective actions against objectives | **Fail** | No recovery has occurred, no objectives exist, no evidence format is defined. | **OWNER-TBD.** |
| **DATA-8.01** Schema migration, backfill, re-encryption, provider/region move, format change preserve integrity, rights, retention, auditability | **Warning** | **Local store: strong.** `StoreMigrator` is versioned (`currentVersion = 2`), has a frozen-literal contract, a fresh-install vs pre-versioning discriminator that avoids the stale-key-list failure mode it documents (`store_migrator.dart:38-44`), a never-throws guard around `main()` (`store_migrator.dart:109-120`), and is exercised by `test/services/store_migrator_test.dart` including the loop body via `debugSetMigrations`. **MySQL: weak.** One raw `.sql` file applied by hand, no migration runner, three divergent definitions (DATA-1.04a). `../housepital-api` has Laravel migrations including a data backfill (`…create_patient_tables.php:60-90`) but no version control. **Neither preserves rights or retention**, because neither exists (DATA-4/5), and neither is auditable (`audit_logs` unwritten). | Impact: the local migration path is safe; the server path is not, and no migration preserves a right or a retention deadline because none is defined. **OWNER-TBD.** |
| **DATA-8.02** Archived data remains readable, secure, discoverable for authorized purpose, and deletable on schedule | **Fail** | The only archive in the product is `__quarantine_v*_*`. Readable: yes (JSON string). Secure: no more than the rest — plain `NSUserDefaults`, unencrypted (3.02). **Discoverable: no** — the promise that *"support can recover a patient's order history from `__quarantine_v1_*`"* (`store_migrator.dart:62-64`) has no supporting mechanism (3.04). **Deletable on schedule: no** — no TTL, no reaper, no cap. | **OWNER-TBD.** See the dedicated assessment below. |
| **DATA-8.03** Shutdown includes user notice, export, processor return/deletion, key destruction, backup expiry, legal retention, proof of completion | **Fail** | No shutdown or wind-down plan exists in either repo. Given DATA-5.02, there is also no export path with which to honour one. Concretely relevant: the app already links out to a **separate business** (Dai Maa, `daimaa_theme.dart:30`) and depends on three third-party processors (Google/Firebase, Razorpay, Anthropic for the assistant Cloud Function) with no return-or-delete terms recorded. | **OWNER-TBD.** |
| **DATA-8.04** Stewardship findings have owner, due date, evidence, approval; material integrity or unrecoverable-backup failures block release | **Fail** | No stewardship register exists (`docs/KNOWN_ISSUES.md` tracks defects, not data findings — `grep -cniE "backup\|retention\|quarantine\|data loss" docs/KNOWN_ISSUES.md` → **0**). This audit itself surfaces material unrecoverable-backup failures (DATA-6.01/6.04), which under this control **block release**. | **OWNER-TBD.** |

---

## Requested deep-dives

### 1. `StoreMigrator.quarantine()` — no TTL, no reaper, no cap

**What is actually true today.** The single shipped step (`store_migrator.dart:65-73`) quarantines
exactly two keys, `housepital_orders` and `housepital_assessments`, once, on a v1 device. So the
present-day footprint is **bounded at two entries** and the "unbounded" concern is a property of
the contract, not of the current code. That distinction matters and I state it before the criticism.

**What is nonetheless wrong.**

1. **The step quarantines unconditionally, not on parse failure.** The contract says a migration
   quarantines data *"it cannot parse"* (`store_migrator.dart:21`), and `quarantine()`'s own
   docstring says *"before overwriting anything it could not parse"* (line 201). The v1→v2 step
   attempts no parse — it copies and removes for every v1 device (lines 68-72). The commentary at
   lines 58-64 justifies this on attribution grounds, which is sound; the docstrings do not match
   the behaviour. Result: **every** upgrading device permanently retains a verbatim second copy of
   its full order and assessment history, whether or not anything was wrong with it.
2. **The copy is never read.** `grep -rn "__quarantine" lib/` returns hits only inside
   `store_migrator.dart` itself. The comment says support can retrieve it; nothing lets them.
3. **No expiry, no cap, no reaper.** Confirmed: `quarantine` (lines 204-222) only writes; there is
   no counterpart. `SessionScope._patientScopedPrefsKeys` lists one key and does not include the
   quarantine prefix (`session_scope.dart:49-51`); the prefix sweep in that file matches only
   `daily_rating_` (line 130). So a quarantined blob **survives a patient switch** — patient A's
   order history remains on a device now showing patient B, on a phone the file's sibling
   `session_scope.dart:22-28` describes as routinely shared between family members.
4. **It is removed by logout and by account deletion**, via the untargeted `getKeys()` sweep in
   `auth_provider.dart:235-238`. That is correct — and accidental. Nothing names the quarantine
   prefix as intentionally session-scoped, and `test/services/store_migrator_test.dart:270` asserts
   only that a *fresh install* has no quarantine keys. If the preserve-set in `auth_provider.dart`
   ever grows a prefix rule, this protection disappears silently.

**Grade contribution:** DATA-3.05 Fail, DATA-4.01 Fail, DATA-8.02 Fail, DATA-1.03 Fail.
**Cheapest fix:** add `'__quarantine_'` to a prefix sweep in `SessionScope._clearPatientScopedStorage`
(one line, next to the existing `_dailyRatingPrefix` loop), and either implement the support
retrieval path or delete the sentence that promises it.

### 2. Does any backup exist for MySQL or Firestore?

**No.** Stated as a negative with the search that establishes it:

```
grep -rniE "backup|mysqldump|restore|point-in-time|pitr|snapshot|retention|disaster|rpo|rto" \
  ../housepital-backend ../housepital-api housepital_patient_app \
  --include="*.ts" --include="*.js" --include="*.json" --include="*.md" --include="*.sql" \
  --include="*.yaml" --include="*.yml" --include="*.php" \
  (node_modules and vendor excluded)
```

Every hit is a false positive except `docs/ENVIRONMENT_SETUP.md:392`
(`mysqldump … > backup.sql  # Backup`), which is an example command in a setup guide.
Neither `firebase.json` declares a Firestore export schedule. There is no CI/CD in either backend
(`ls ../housepital-backend/.github` → does not exist), no IaC of any kind. **No restore procedure
is documented, and no restore has ever been tested** — there is nothing in either repo that could
be a drill record.

### 3. Portability — is there any export path at all?

Two, and neither is a portability export.

| Path | Source of data | Assessment |
|---|---|---|
| Invoice PDF (`invoice_pdf_service.dart:96`) | The real order map | Real, but single-order and financial only |
| Doctor-handover PDF (`handover_report_service.dart:98`) | **`DemoData` exclusively** — lines 107-114 | Exports a fabricated patient's history, flagged only by the `DemoMode` overlay pill (line 105) |

Neither exports the data the user actually created — manually entered vitals, dose logs,
reminders, saved addresses, ratings. There is **no** "download my data" affordance, no JSON/CSV
export, and no server endpoint. DPDP §11 is unmet (DATA-5.01, DATA-5.02 — both Fail).

### 4. RPO/RTO — what is lost if the MySQL instance dies right now?

**Nothing that the app would notice, and that is the finding.**

- The app is pointed at `https://api.housepital.in/v1` (`lib/config/constants.dart:3`), which per
  the project baseline does not resolve. Every provider falls through to `DemoData`.
- Therefore no patient-app write has ever reached MySQL. `RPO = 0` today **only because the
  database is empty of app-originated data**.
- The moment the backend is reachable, RPO becomes **unbounded** — with no backup (DATA-6.01), the
  loss window on instance failure is *all data since instance creation*, and RTO is *the time to
  re-derive a schema from three disagreeing files* (DATA-1.04a) plus re-entry of everything.
- The `../housepital-api` MySQL database is worse: its schema exists only in an **untracked**
  working directory (DATA-1.04d). Losing that laptop loses the schema, not just the rows.

### 5. Demo-mode quantification — what a device loss actually costs

This module is the one placed to answer it, so it is quantified rather than characterised.

**Lost on device loss / uninstall / OS restore-to-new-device (SharedPreferences is included in
iCloud/Android backup only if the app permits it; no `BackupAgent` or `allowBackup` policy is
declared in `android/app/src/main/AndroidManifest.xml`, and no iOS backup exclusion is set):**

| Data | Store | Recoverable from anywhere? |
|---|---|---|
| Complete order and care-booking history | `housepital_orders_<patientId>` | **No** — no server copy |
| Nursing assessment requests | `housepital_assessments_<patientId>` | **No** |
| Free-text clinical reminders ("insulin before dinner") | `housepital_reminders` | **No** |
| Home dispatch addresses | `housepital_saved_addresses` | **No** |
| Daily satisfaction ratings (one per day, all history) | `daily_rating_*` | **No** |
| Cart and saved-for-later | `housepital_cart_items`, `housepital_saved_items` | **No** |
| Cached deployment / attendance / vitals / amount due | `housepital_cache_dashboard_*` | **No** |
| Notification preferences (9) | `notif_*` | **No** |
| Pending account-deletion request + its reference number | `housepital_pending_deletion` | **No** — and the user was told to quote that reference |

**Lost on app termination — not even device loss required:**

| Data | Site |
|---|---|
| **Every manually entered vital sign** — BP, pulse, SpO₂, temperature, blood sugar | `app_provider.dart:41, 324-339` — in-memory `List`, no persistence |
| **Every dose the patient logged as taken** | `medication_provider.dart:16, 110-126` — in-memory, and overwritten by the next `loadMedications` (line 226) |
| **Every document the patient "uploaded"** | `document_repository_screen.dart:686-697` — a metadata row in a `State` field; the image bytes are discarded at line 636 |
| Any patient added via "add patient" | `app_provider.dart:245-249` — `TODO(persistence)` |

**Net:** of the four data types a home-care patient app exists to capture between visits — vitals,
dose adherence, documents, and care history — **three do not survive closing the app**, and the
fourth does not survive losing the phone. The app presents all four as recorded. There is no
warning, no export, no sync, and no accepted-loss decision on file (DATA-6.04).

---

## Scorecard

**Pass 1 · Warning 5 · Fail 29 · N/A 0** (+ **BLOCKED-OWNER 5**) — 35 controls.

A 29-Fail result is not 29 independent defects. It is the signature of an **absent data-lifecycle
programme**: families 4 (retention/deletion), 5 (rights/portability), 6 (backup) and 7 (restore/DR)
are 18 of those 29, and each family fails for one root cause — no retention definitions, no rights
workflows, no backup, no DR plan. Fixing four root causes clears eighteen controls.

Against the round-1→2→3 trajectory in the brief: this module fits neither "surfaces" nor
"half-wires". The pattern here is **third**, and worse — *a correct and well-tested mechanism built
for a store that holds nothing durable, in front of a lifecycle that was never designed.*
`StoreMigrator` and `SessionScope` are the best-engineered data code in the repository (versioned,
contracted, quarantine-safe, tested through their loop bodies), and they govern a store from which
the product's four primary data types are absent because three of them were never persisted at all.

---

## Release blockers (every Fail)

Ordered by consequence, not by control number.

1. **DATA-6.04 / the demo-mode data loss.** Manually entered vitals, dose logs and uploaded
   documents do not survive app termination (`app_provider.dart:324`, `medication_provider.dart:110`,
   `document_repository_screen.dart:686`). The UI presents all three as recorded. Either persist
   them or tell the user they are not saved.
2. **DATA-4.03 — deletion propagates nowhere.** No delete endpoint for patient data exists; chat
   messages and all uploaded photos are immutable by rule (`storage.rules:83, 90`;
   `firestore.rules:78`); the profile-photo JPEG survives the wipe.
3. **DATA-4.05 — the deletion record has no reader.** `housepital_pending_deletion` is written by
   one site and read by none, in any repo.
4. **DATA-5.01 / 5.02 — no access or portability path.** DPDP §11 unmet; the only "medical record"
   export is built from `DemoData` (`handover_report_service.dart:107-114`).
5. **DATA-6.01 / 6.02 / 6.03 — no backup of any store**, and `../housepital-api` is not under
   version control at all.
6. **DATA-7.01 / 7.02 / 7.03 / 7.05 — no RPO/RTO, no drill, no playbook, no evidence format.**
7. **DATA-1.01 / 1.02 / 1.03 / 1.04 — no inventory, no classification, four categories of
   duplicated/shadow/untracked store.**
8. **DATA-3.01 / 3.02 — Firestore rules encode an authorization model the client cannot satisfy**
   (`grep -rn "\.uid" lib/` → 0), the app writes to a path both rule files deny, and local PHI is
   unencrypted.
9. **DATA-3.04 / 3.05 — no attributable admin access; caches, quarantine and daily-rating keys have
   no cleanup deadline or cap.**
10. **DATA-2.02 / 2.03 — no review gate on new collection; deletion copy describes stores and
    retention exceptions that do not exist; no app-level `PrivacyInfo.xcprivacy`.**
11. **DATA-4.01 / 4.02 / 4.04 — no retention period for any category, no retention job, an
    open-ended undisclosed-scope legal-hold claim in shipped copy.**
12. **DATA-5.03 / 5.04 — no multi-party rights model; deletion verified only by a dialog.**
13. **DATA-8.02 / 8.03 / 8.04 — quarantine archive undiscoverable and undeletable; no wind-down
    plan; no stewardship register.**

Under the checklist's release rule, all of the above block release unless formally accepted by a
named authority. **No named authority appears anywhere in the repository** — hence `OWNER-TBD`
throughout.

---

## Warnings requiring risk acceptance

| # | Control | Impact | Mitigation | Owner / due |
|---|---|---|---|---|
| W1 | DATA-2.01 | 12 unused free-text clinical columns on `patients`; plaintext OTP retained | Drop/defer the columns; hash or reap `otp_verifications` | OWNER-TBD / before backend go-live |
| W2 | DATA-3.03 | No corruption detection on the local store — a truncated blob reads as "empty" | Add a length or checksum field to the persisted wrapper in `OrdersProvider._persist` | OWNER-TBD / before first release |
| W3 | DATA-7.04 | Device-level stale-overwrite and cross-tenant controls are strong and tested; no server-side equivalent, and Storage paths are cross-patient readable by any signed-in user (`storage.rules:33-36`) | Custom claims per `storage.rules:41-49`, or backend-issued upload URLs | OWNER-TBD / before backend go-live |
| W4 | DATA-8.01 | Local migration is safe; MySQL has three divergent schemas and no runner; the Laravel schema is untracked | Designate one authoritative schema, delete the others, adopt a migration runner, `git init` the API repo | OWNER-TBD / immediately |
| W5 | DATA-1.04(b) partial | Two divergent `firestore.rules` with incompatible auth models; unclear which is deployed | Designate one, delete the other, record the deploy in `DEPLOYMENT_GUIDE.md` | OWNER-TBD / before submission |

---

## BLOCKED-OWNER — needs access I do not have

| # | Question | Access required |
|---|---|---|
| B1 | Does a production Cloud SQL instance exist, and are automated backups / point-in-time recovery enabled on it? The connection name is a commented-out line (`../housepital-backend/.env.example:7`); nothing in source configures backups either way. | GCP console for project `housepital-patient` |
| B2 | Which `firestore.rules` and which `storage.rules` are **live**? Both files carry deploy warnings (`firestore.rules:7-13`, `storage.rules:5-11`) and `docs/KNOWN_ISSUES.md:67` records the Firestore deployment as still pending. | Firebase console → Firestore/Storage rules |
| B3 | Is a Firestore scheduled export configured outside `firebase.json`? | Firebase / GCP console |
| B4 | Do the App Store privacy nutrition labels declare health data, and do they match §A–§F above? | App Store Connect |
| B5 | Do any real patient rows exist in `housepital` or the Laravel database today? This determines whether DATA-6/7 are prospective or already-realised losses. | Database access |

None of these is graded N/A. Each is a control whose *live* state I could not verify; the *source*
state is graded Fail above on the evidence that source contains no configuration for it.

---

## Limitations of this audit

- **MASTER-4.04: this is a SOURCE review, not a release-artifact or production review.** I did not
  build, run, or install the app; I did not inspect a device's `NSUserDefaults` plist; I did not
  observe network traffic; I did not open the Firebase, GCP or App Store Connect consoles. Every
  claim about what is *stored* is derived from the code that writes it.
- Per the brief I did **not** run `flutter test`, `flutter build` or `flutter clean`. Test-quality
  claims are from reading test sources (`test/services/store_migrator_test.dart`,
  `test/providers/patient_scope_isolation_test.dart`). Central results cited: `flutter analyze`
  clean, design gate passes, 1,819 tests across 101 files.
- I did not resolve `api.housepital.in`; I take the project baseline's statement that it does not
  resolve, and note that `lib/config/constants.dart:3` points there.
- `../housepital-api` was read at its working-tree state. Because it is not a git repository, I
  cannot cite a commit for it, and I cannot tell whether what I read matches anything deployed.
- Backup, restore and DR findings are **negative findings** — assertions that something is absent.
  They rest on the exhaustive greps quoted verbatim in DATA-6.01 and deep-dive §2, which a reviewer
  can re-run. If backup configuration exists outside these three repositories (a console setting, a
  cron on a server, a managed-provider default), this audit cannot see it — that is B1/B3.
- No round-3 report exists for this module, so there is no prior-finding regression table. Where a
  round-3 carried-open item touches data lifecycle (`storage.rules` undeployed, `DemoMode` having
  one `markServingLiveData` call site for eleven sources — verified: `grep -rn
  "markServingLiveData" lib/` returns 2 call sites for 12 declared sources,
  `lib/data/demo_mode.dart:24-35`), it is cited inline rather than in a status table.
