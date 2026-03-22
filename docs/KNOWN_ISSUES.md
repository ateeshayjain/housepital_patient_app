# Known Issues

Running list of bugs, workarounds, technical debt, and things that work but are not right.

**Last updated:** 2026-03-22

---

## Critical (Blocks Release)

| ID     | Description                                                              | Found      | Status   |
|--------|--------------------------------------------------------------------------|------------|----------|
| BUG-01 | Razorpay key is hardcoded as test key in `constants.dart` -- must switch to production key loaded from environment before release | 2026-03-21 | Open |
| BUG-02 | Payment webhook has no idempotency check -- duplicate webhook events could cause double status updates | 2026-03-21 | Open |

---

## High (Fix Before Launch)

| ID     | Description                                                              | Found      | Status   |
|--------|--------------------------------------------------------------------------|------------|----------|
| BUG-03 | Share button on booking confirmation is a no-op -- `share_plus` is imported but the share action is not wired to actual share intent | 2026-03-21 | Open |
| BUG-04 | Promo code field in booking wizard is a stub -- API validates the code but discount is not visually reflected in the order summary before payment | 2026-03-21 | Open |
| BUG-05 | Payment stub in booking wizard -- booking wizard creates the booking but payment flow is not fully integrated into the booking confirmation lifecycle | 2026-03-21 | Open |
| BUG-06 | Form validation gaps -- assessment request questionnaire allows empty submissions in some categories | 2026-03-21 | Open |
| BUG-07 | 3 pre-existing widget test failures in `test/screens/my_care/my_care_widgets_test.dart` -- cause unknown, needs triage | 2026-03-22 | Open |
| BUG-08 | AuthProvider has no test coverage -- login flow, session management, token refresh are untested | 2026-03-22 | Open |
| BUG-09 | PaymentService has no test coverage -- Razorpay integration, amount calculations untested | 2026-03-22 | Open |
| BUG-10 | ApiService has no test coverage -- error handling, retry logic, all HTTP calls untested | 2026-03-22 | Open |
| BUG-11 | No offline handling -- app crashes or shows blank when there is no network connectivity | 2026-03-20 | Open |

---

## Medium (Fix After Launch)

| ID     | Description                                                              | Found      | Status   |
|--------|--------------------------------------------------------------------------|------------|----------|
| BUG-12 | Hard-coded colors in some screens instead of using `HousepitalColors` constants -- inconsistent theming | 2026-03-21 | Open |
| BUG-13 | Hindi translations incomplete -- some screens still show English text when Hindi locale is selected | 2026-03-20 | Open |
| BUG-14 | Invoice PDF download is a stub -- button exists but PDF generation/download not implemented | 2026-03-21 | Open |
| BUG-15 | Document repository screen is a placeholder -- upload and document management not implemented | 2026-03-20 | Open |
| BUG-16 | `/services` route maps to an empty `Scaffold()` -- no fallback content | 2026-03-21 | Open |
| BUG-17 | Family member invite sends no actual SMS/WhatsApp -- backend records the intention but MSG91 integration is not connected | 2026-03-20 | Open |
| BUG-18 | Notification routing not implemented -- tapping a push notification does not navigate to the relevant screen | 2026-03-20 | Open |
| BUG-19 | Vitals chart Y-axis may not auto-scale for extreme edge cases (e.g., BP 220 could render off-screen) | 2026-03-22 | Open |
| BUG-20 | Payment Methods screen is static/placeholder -- no actual saved payment method management | 2026-03-21 | Open |

---

## Low (Nice to Have)

| ID     | Description                                                              | Found      | Status   |
|--------|--------------------------------------------------------------------------|------------|----------|
| BUG-21 | No loading skeleton/shimmer on all screens -- some screens use CircularProgressIndicator instead of shimmer placeholders | 2026-03-20 | Open |
| BUG-22 | Cart badge count not shown on bottom nav bar                             | 2026-03-21 | Open |
| BUG-23 | No deep linking support -- app cannot be opened from a URL               | 2026-03-20 | Open |
| BUG-24 | Coordinator chat (Firestore chat_messages) has no UI screen yet          | 2026-03-20 | Open |

---

## Technical Debt

| ID    | Description                                                                   | Impact          |
|-------|-------------------------------------------------------------------------------|-----------------|
| TD-01 | Razorpay key should be loaded from `--dart-define` or `.env` file, not hardcoded in `constants.dart` | Security risk |
| TD-02 | GST rate (18%) is hardcoded in `bookings.ts` -- should be in a config table for future multi-rate support | Config rigidity |
| TD-03 | Vitals alert thresholds are hardcoded in `constants.dart` -- should be server-driven for admin configurability | Config rigidity |
| TD-04 | No retry logic on failed HTTP requests in `ApiService` -- network errors result in immediate failure | Reliability |
| TD-05 | No retry logic on Firestore listener subscription failures -- page refresh needed to reconnect | Stale data |
| TD-06 | Equipment catalog loaded from local JSON asset (`assets/equipment_catalog.json`) -- should be server-driven for real-time catalog updates | Data freshness |
| TD-07 | `AppProvider` is a god object holding patient context, dashboard data, locale, and billing summary -- should be split | Maintainability |
| TD-08 | No pagination on several list endpoints (concerns, assessments, active-services) -- will become slow with scale | Performance |
| TD-09 | All backend routes in separate files but no route-level error handling -- relies on global error handler only | Debuggability |
| TD-10 | No database connection health check or reconnection logic in `cloudSql.ts` -- cold starts may fail silently | Reliability |
| TD-11 | Concern SLA tracking exists in constants but is not enforced or alerted on the backend | Business logic gap |
| TD-12 | `onGenerateRoute` in `main.dart` is a large switch statement (30+ cases) -- should migrate to `go_router` declarative routing | Maintainability |
| TD-13 | No structured logging on backend -- uses `console.log` instead of a logging library | Observability |
| TD-14 | No rate limiting on API endpoints (express-rate-limit is a dependency but not applied) | Security |
| TD-15 | WhatsApp notification integration (MSG91) is not connected -- templates not submitted for approval | Feature gap |

---

## Workarounds in Place

| Issue | Workaround | Permanent Fix Needed |
|-------|-----------|---------------------|
| Razorpay test mode | Test key hardcoded -- payments succeed in test mode but no real money moves | Switch to env-loaded production key |
| No offline mode | Users must have internet for all operations | Implement Hive/SharedPreferences caching with TTL |
| Hindi incomplete | Fallback to English for missing keys via `AppLocalizations` | Complete all Hindi string translations |
| Invoice PDF | "Download" button shows a snackbar saying "Coming soon" | Integrate pdfkit on backend or Razorpay Invoice API |
| Family invite | Invite is recorded in DB but no actual message sent | Connect MSG91 SMS/WhatsApp API |

---

**Update rule:** Add new issues as they are found. Remove issues when they are fixed (move to a "Resolved" section at the bottom with the fix date).
