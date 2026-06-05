# Known Issues

Running list of bugs, workarounds, technical debt, and things that work but are not right.

**Last updated:** 2026-05-28

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
