# Known Issues

Running list of bugs, workarounds, technical debt, and things that work but are not right.

**Last updated:** 2026-08-03 (audit round 3)

## Open — from the eleven-checklist audits (rounds 1–3, `docs/audits/`)

Full evidence in `docs/audits/round3/`. Listed here so this file stops being the
one place that doesn't know.

**Blockers**
- `api.housepital.in` does not resolve. Every provider serves `DemoData`; the app
  ships a demo-data build.
- Demo clinical data seeds on every fresh install. Three rounds have improved the
  LABELLING; no round has gated the seed. There is no `DEMO_DATA` build flag.
- App icon is an upscale of a 143×182 raster (ink fills 50.2%×64.0%, no iOS 18
  dark/tinted variants). Needs the designer's vector before submission.
- `storage.rules` is written but **undeployed**; live posture unknown.
- No account-deletion request reaches any server — the record is written locally
  and read by nothing.
- Android release signs with the **debug** keystore; the auth gate at
  `main.dart` is commented out; no dSYM upload phase; no kill switch.

**High**
- ~~The demo-notice overlay pill absorbs touches~~ **FIXED 2026-08-20** — the
  overlay is now wrapped in `IgnorePointer`. It still occludes the first content
  row on several screens, and `maxLines: 1` still truncates the warning in Hindi
  and at the 1.4× text ceiling.
- `DemoMode` has **3** `markServingLiveData` call sites for **13** declared
  sources, so the notice largely does not clear;
  `sourceCareTeam`/`sourceCareCalendar`/`sourceProfile` are declared and never
  wired. (Counts corrected 2026-08-20 — this line said "one … for eleven".
  `sourceVitals` and `sourceStaffProfile` have since been added, both wired at
  both ends.)
- ~~`logger.dart:63` is an unwired TODO~~ **FIXED 2026-08-20** — `Log.sink` is
  now installed from `main.dart` and forwards warn/error to
  `FirebaseCrashlytics.recordError(fatal: false)` on mobile release builds.
  **64** warn/error sites (not the ~45 previously stated) now reach a remote
  sink, including every `StoreMigrator` failure path. Note the PII rule on
  `Log.sink`: messages must describe what failed, never who it happened to.
- ~~40.3 MiB of unreferenced product images ship~~ **FIXED 2026-08-20** — 235
  orphans deleted (40.2 MiB); `assets/images/products/` went 78 MiB → 38 MiB.
  Three orphans were first WIRED to catalog entries that had no photo rather
  than deleted. A test now asserts every catalog `image_url` resolves to a file
  that exists.
- Four `BackdropFilter` surfaces per frame (~22% of screen) since the pill nav.
- Dynamic Type clamped at 1.4×, untested; 17 of 54 icon buttons unlabelled;
  zero contrast assertions in `test/`.
- ~~the design gate still cites the old wrong figure~~ **FIXED 2026-08-20** —
  `scripts/check_design_consistency.sh` now states the measured 3.99:1 (AA-large
  only) and points at `orangeStrong` (5.38:1) for text under 18px. The chip
  theme moved from `orangeText` (3.63:1 on `orangeLight` — failing AA under a
  comment claiming it "keeps AA") to `orangeStrong` (4.90:1). The dark-mode
  comment citing "6.32:1 vs #1A1A1A" — a surface this file never defined — now
  carries the measured 8.99:1 (on `#000000`) and 7.29:1 (on `#1C1C1E`).
- Backend: the two databases define the same six nouns incompatibly;
  `family_members.user_id` is `UNIQUE`, so the server structurally cannot return
  two patients and the patient-switch feature would 403.
- ~~Backend: ~20 routes query columns and tables that do not exist~~
  **FIXED 2026-08-20** — `sql/005_schema_code_reconciliation.sql` adds the five
  genuinely-missing columns and four missing tables; the rest were renames in
  the CODE (`family_member_id` → `paid_by`/`raised_by`/`booked_by`/`rated_by`/
  `requested_by`, `schedule_times` → `time_slots`, `sort_order` →
  `display_order`, `base_amount` → `price_amount`), because the schema names
  are also what the Flutter client serialises.
  `functions/src/__tests__/schema-conformance.test.ts` now fails on any future
  drift, without needing a database. **The migration has not been run against
  any live database** — that is still outstanding.
- ~~Backend: `verifyPatientAccess` could be bypassed with an empty
  `patientId`~~ **FIXED 2026-08-20** — it denied only when BOTH ids were present
  and differed, and `verifyAuth` assigns `patientId = ""` to any
  Firebase-authenticated caller with no `family_members` row, so that blank
  claim satisfied the guard for every patient id. Now fails closed on all three
  conditions. **Not deployed.**

**Accepted risks (owner decisions, not defects)**
- White on Housepital orange = 2.33:1 — explicit owner decision, measured and accepted.
- Manpower prices shown and directly bookable.
- Floating liquid-glass pill nav (reverses field round 5).

---

## Build / CI

| ID     | Description                                                              | Found      | Status   |
|--------|--------------------------------------------------------------------------|------------|----------|
| CI-01  | `--tree-shake-icons` (default) can fail with a kernel-size assertion mid-batch when concurrent processes touch `lib/` during `flutter build web --release`. Workaround: rerun after `flutter clean`, or pass `--no-tree-shake-icons` (~150KB bundle bloat). Root cause is build-cache invalidation under concurrent edits, not an SDK bug. | 2026-05-28 | Open (workaround documented) |
| CI-02  | Pinned Flutter to 3.41.2 in `.github/workflows/ci.yml` to match local dev. Bump in lockstep across team — minor versions change `textScaler` semantics, `RadioGroup` deprecation, and `withOpacity` warnings. | 2026-05-28 | Resolved |
| CI-03  | CI now runs `flutter analyze --no-fatal-warnings --no-fatal-infos` before tests. Tightening to `--fatal-warnings` is blocked on the 284-issue pre-existing backlog (unused imports, deprecations). Tighten once backlog is cleared. | 2026-05-28 | Open (tracked) |

---

## Critical (Blocks Release)

| ID     | Description                                                              | Found      | Status   |
|--------|--------------------------------------------------------------------------|------------|----------|
| BUG-01 | ~~Razorpay key is hardcoded as test key~~ — `constants.dart:18` reads `RAZORPAY_KEY` from `String.fromEnvironment` with test fallback. **Production builds MUST pass `--dart-define=RAZORPAY_KEY=rzp_live_xxx`.** Add to release pipeline docs. | 2026-03-21 | Resolved 2026-05-28 (env wiring exists; ship-time config pending) |
| BUG-02 | Payment webhook has no idempotency check -- duplicate webhook events could cause double status updates. **Backend repo (separate from this Flutter app); add `INSERT IGNORE` or upsert keyed on Razorpay event ID + payment_id on the receiving Cloud Function / API server.** | 2026-03-21 | Open (backend repo, not this Flutter app) |
| BUG-33 | `firestore.rules` had an open allow-all rule that expired 2026-04-21 (~5 weeks before discovery on 2026-05-28). **Hardened in audit batch 4** with default-deny + per-collection auth-scoped rules (chat_messages, patients/{attendance,vitals}, users/notifications, active_sessions, fcm_tokens). File is in this repo at `firestore.rules` but **must be deployed via `firebase deploy --only firestore:rules`** from the backend repo. Verify live state at https://console.firebase.google.com/project/housepital-patient/firestore/rules. | 2026-05-28 | Resolved 2026-05-28 (file hardened — deployment to console pending) |
| BUG-34 | Firebase API keys hardcoded in `lib/config/firebase_options.dart` and `android/app/google-services.json` — safe by design ONLY IF Firebase Console restrictions are configured. Keys requiring restriction: `AIza…nTJg (web key — full value in lib/config/firebase_options.dart)` (one platform) and `AIza…3TLc (Android key — full value in android/app/google-services.json)` (other). Required restrictions: **HTTP referrer** (for web — limit to `*.housepital.in`), **package + SHA1** (for Android — `in.housepital.patient` + release signing SHA1), **bundle ID** (for iOS). See `docs/DEPLOYMENT_GUIDE.md` "Firebase Console hardening checklist" section. | 2026-05-28 | Open (console action required) |
| BUG-35 | Razorpay webhook idempotency missing in backend repo (`housepital-backend`). Duplicate `payment.captured` events could mark an invoice paid twice or send two confirmation messages. **Not actionable in this Flutter repo** — implementation belongs in `functions/src/routes/payments.ts` (insert with unique constraint on Razorpay event_id, or check-then-act with row lock). Cross-referenced from BUG-02. | 2026-05-28 | Open (backend repo) |

---

## High (Fix Before Launch)

| ID     | Description                                                              | Found      | Status   |
|--------|--------------------------------------------------------------------------|------------|----------|
| BUG-03 | ~~Share button on booking confirmation is a no-op~~ | 2026-03-21 | Resolved 2026-03-22 |
| BUG-04 | ~~Promo code field in booking wizard is a stub~~ | 2026-03-21 | Resolved 2026-03-22 |
| BUG-05 | ~~Payment stub in booking wizard~~ | 2026-03-21 | Resolved 2026-03-22 |
| BUG-06 | ~~Form validation gaps in assessment request~~ | 2026-03-21 | Resolved 2026-03-22 |
| BUG-07 | 3 pre-existing widget test failures in `test/screens/my_care/my_care_widgets_test.dart` -- cause unknown, needs triage | 2026-03-22 | Open |
| BUG-08 | AuthProvider has no test coverage -- login flow, session management, token refresh are untested | 2026-03-22 | Open |
| BUG-09 | PaymentService has no test coverage -- Razorpay integration, amount calculations untested | 2026-03-22 | Open |
| BUG-10 | ApiService has no test coverage -- error handling, retry logic, all HTTP calls untested | 2026-03-22 | Open |
| BUG-11 | ~~No offline handling -- app crashes or shows blank when there is no network connectivity~~ | 2026-03-20 | Resolved 2026-03-24 |

---

## Medium (Fix After Launch)

| ID     | Description                                                              | Found      | Status   |
|--------|--------------------------------------------------------------------------|------------|----------|
| BUG-12 | Hard-coded colors in some screens instead of using `HousepitalColors` constants -- inconsistent theming | 2026-03-21 | Open |
| BUG-13 | ~~Hindi translations incomplete -- some screens still show English text when Hindi locale is selected~~ | 2026-03-20 | Resolved 2026-03-24 |
| BUG-14 | Invoice PDF download is a stub -- button exists but PDF generation/download not implemented | 2026-03-21 | Open |
| BUG-15 | ~~Document repository screen is a placeholder~~ -- search, share, open implemented | 2026-03-20 | Resolved 2026-03-22 |
| BUG-16 | `/services` route maps to an empty `Scaffold()` -- no fallback content | 2026-03-21 | Open |
| BUG-17 | Family member invite sends no actual SMS/WhatsApp -- backend records the intention but MSG91 integration is not connected | 2026-03-20 | Open |
| BUG-18 | ~~Notification routing not implemented -- tapping a push notification does not navigate to the relevant screen~~ | 2026-03-20 | Resolved 2026-03-24 |
| BUG-19 | Vitals chart Y-axis may not auto-scale for extreme edge cases (e.g., BP 220 could render off-screen) | 2026-03-22 | Open |
| BUG-20 | Payment Methods screen is static/placeholder -- no actual saved payment method management | 2026-03-21 | Open |

---

## Low (Nice to Have)

| ID     | Description                                                              | Found      | Status   |
|--------|--------------------------------------------------------------------------|------------|----------|
| BUG-21 | No loading skeleton/shimmer on all screens -- some screens use CircularProgressIndicator instead of shimmer placeholders | 2026-03-20 | Open |
| BUG-22 | Cart badge count not shown on bottom nav bar                             | 2026-03-21 | Open |
| BUG-27 | ~~Cart shows empty after adding items (grey screen / deserialization failure)~~ | 2026-03-22 | Resolved 2026-03-25 |
| BUG-28 | ~~Cart grey screen on reopen after app restart~~ | 2026-03-23 | Resolved 2026-03-25 |
| BUG-23 | No deep linking support -- app cannot be opened from a URL               | 2026-03-20 | Open |
| BUG-24 | ~~Coordinator chat (Firestore chat_messages) has no UI screen yet~~ | 2026-03-20 | Resolved 2026-03-24 |

---

## Technical Debt

| ID    | Description                                                                   | Impact          |
|-------|-------------------------------------------------------------------------------|-----------------|
| TD-01 | Razorpay key should be loaded from `--dart-define` or `.env` file, not hardcoded in `constants.dart` | Security risk |
| TD-02 | GST rate (18%) is hardcoded in `bookings.ts` -- should be in a config table for future multi-rate support | Config rigidity |
| TD-03 | Vitals alert thresholds are hardcoded in `constants.dart` -- should be server-driven for admin configurability | Config rigidity |
| TD-04 | ~~No retry logic on failed HTTP requests in `ApiService`~~ -- RESOLVED: retry with exponential backoff added | ~~Reliability~~ |
| TD-05 | No retry logic on Firestore listener subscription failures -- page refresh needed to reconnect | Stale data |
| TD-06 | Equipment catalog loaded from local JSON asset (`assets/equipment_catalog.json`) -- should be server-driven for real-time catalog updates | Data freshness |
| TD-07 | `AppProvider` is a god object holding patient context, dashboard data, locale, and billing summary -- should be split | Maintainability |
| TD-08 | ~~No pagination on several list endpoints~~ -- RESOLVED: PaginatedList widget + pagination on all endpoints | ~~Performance~~ |
| TD-09 | All backend routes in separate files but no route-level error handling -- relies on global error handler only | Debuggability |
| TD-10 | No database connection health check or reconnection logic in `cloudSql.ts` -- cold starts may fail silently | Reliability |
| TD-11 | Concern SLA tracking exists in constants but is not enforced or alerted on the backend | Business logic gap |
| TD-12 | `onGenerateRoute` in `main.dart` is a large switch statement (30+ cases) -- should migrate to `go_router` declarative routing | Maintainability |
| TD-13 | ~~No structured logging on backend~~ -- RESOLVED: structured logging with correlation IDs | ~~Observability~~ |
| TD-14 | ~~No rate limiting on API endpoints~~ -- RESOLVED: express-rate-limit applied to all endpoints | ~~Security~~ |
| TD-15 | WhatsApp notification integration (MSG91) is not connected -- templates not submitted for approval | Feature gap |

---

## Workarounds in Place

| Issue | Workaround | Permanent Fix Needed |
|-------|-----------|---------------------|
| Razorpay test mode | Test key hardcoded -- payments succeed in test mode but no real money moves | Switch to env-loaded production key |
| ~~No offline mode~~ | ~~Users must have internet for all operations~~ | RESOLVED: cache_service with TTL + SharedPreferences |
| ~~Hindi incomplete~~ | ~~Fallback to English for missing keys~~ | RESOLVED: 90+ Hindi keys added |
| Invoice PDF | "Download" button shows a snackbar saying "Coming soon" | Integrate pdfkit on backend or Razorpay Invoice API |
| Family invite | Invite is recorded in DB but no actual message sent | Connect MSG91 SMS/WhatsApp API |

---

---

## Resolved

| ID     | Description                                                              | Found      | Resolved   | Fix                                           |
|--------|--------------------------------------------------------------------------|------------|------------|-----------------------------------------------|
| BUG-03 | Share button on booking confirmation was a no-op                         | 2026-03-21 | 2026-03-22 | BookingConfirmationScreen now uses share_plus correctly |
| BUG-04 | Promo code field was a stub -- discount not reflected in UI              | 2026-03-21 | 2026-03-22 | Coupon system added to CartScreen + booking flow |
| BUG-05 | Payment stub in booking wizard                                          | 2026-03-21 | 2026-03-22 | Booking now flows to real Razorpay + confirmation screen |
| BUG-06 | Form validation gaps in assessment request questionnaire                 | 2026-03-21 | 2026-03-22 | Form validators added to AssessmentRequestScreen |
| BUG-15 | Document repository screen was a placeholder                            | 2026-03-20 | 2026-03-22 | Search, share, open functionality implemented  |
| BUG-11 | No offline handling -- app crashes or shows blank with no network       | 2026-03-20 | 2026-03-24 | cache_service with TTL + offline caching        |
| BUG-13 | Hindi translations incomplete                                          | 2026-03-20 | 2026-03-24 | 90+ Hindi translation keys added               |
| BUG-18 | Notification routing not implemented                                   | 2026-03-20 | 2026-03-24 | notification_router.dart routes push taps to correct screen |
| BUG-24 | Coordinator chat had no UI screen                                      | 2026-03-20 | 2026-03-24 | ChatScreen using Firestore chat_messages        |
| BUG-25 | Bottom sheet navigation shows grey screen (pop-then-push pattern)      | 2026-03-23 | 2026-03-24 | Replaced with return-result-to-parent pattern   |
| BUG-26 | Razorpay crashes on web platform                                       | 2026-03-23 | 2026-03-24 | Guarded with kIsWeb check                       |
| BUG-27 | Cart shows empty after adding items (grey screen / deserialization)    | 2026-03-22 | 2026-03-25 | Cart rewrite: flat CartItem model replaces nested EquipmentItem serialization |
| BUG-28 | Cart grey screen on reopen after app restart                           | 2026-03-23 | 2026-03-25 | Cart rewrite: List<CartItem> with SharedPreferences persistence via flat JSON |
| BUG-29 | Orders not persisting across app restarts                              | 2026-03-24 | 2026-03-25 | OrdersProvider with SharedPreferences persistence for orders and assessments |
| BUG-30 | Billing screen used mock/hardcoded data                                | 2026-03-24 | 2026-03-25 | BillingScreen rewritten to read from OrdersProvider with real order data |
| BUG-31 | Payment crashes on web platform (Razorpay SDK unavailable)             | 2026-03-24 | 2026-03-25 | Web simulation mode added to PaymentService with kIsWeb guard |
| BUG-32 | Missing i18n keys causing fallback to raw key strings                  | 2026-03-24 | 2026-03-25 | Added missing translation keys for billing, orders, and payment screens |

---

**Update rule:** Add new issues as they are found. Remove issues when they are fixed (move to a "Resolved" section at the bottom with the fix date).
