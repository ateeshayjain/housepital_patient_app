# Software Testing & Code Quality Checklist (App-Agnostic) — Audit vs commit `803124d`

**Date:** 2026-08-03 · **Auditor:** Testing & Code Quality agent
**Checklist:** `Testing Checklist - App Agnostic.txt` (sections 1–9)
**Method:** static read of the full test tree + `grep`/`rg` + AST-ish brace-matching scripts over
`test/**/*_test.dart`. Per instruction I did **not** run `flutter test` (a central run was in
flight); `flutter analyze` was already reported CLEAN by the caller. Every verdict below cites a
file:line or a command output.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Code Quality & Architecture (test-tree scope) | 3 | 4 | 3 | 0 |
| 2. Input Validation & Sanitization | 2 | 2 | 3 | 2 |
| 3. Concurrency / Resource Cleanup (test scope) | 2 | 3 | 1 | 1 |
| 4. Security (auth, secrets, API, data, deps) | 3 | 3 | 5 | 2 |
| 5. Database & Data Integrity | 0 | 1 | 2 | 4 |
| 6. Error Handling | 4 | 2 | 1 | 0 |
| 7. Logging & Observability | 3 | 1 | 2 | 0 |
| **8. Testing (primary scope)** | **11** | **9** | **10** | **1** |
| 9. Release Readiness | 3 | 2 | 2 | 0 |
| **TOTAL** | **31** | **27** | **29** | **10** |

---

## Where the mass sits vs where the risk sits

Measured (`grep -rhE "^\s*(test|testWidgets)\(" test/<dir>`):

| Area | Test files | Test call sites | `expect(` calls | Test LOC | `lib/` LOC guarded |
|---|---:|---:|---:|---:|---:|
| `test/screens/` | 47 | 504 | 1,132 | 10,964 | 40,185 |
| `test/models/` | 13 | 276 | 793 | 3,832 | 2,754 |
| `test/providers/` | 13 | 236 | 533 | 3,640 | 2,073 |
| `test/utils/` | 8 | 177 | 300 | 1,398 | 821 |
| `test/services/` | 8 | 130 | 262 | 2,512 | 3,547 |
| `test/widgets/` | 6 | 34 | 71 | 618 | 1,905 |
| `test/integration/` | 4 | 15 | 101 | 566 | — |
| **Total** | **99** | **1,372** | **3,192** | **23,530** | **54,295** |

Plus 3 non-test helpers: `test/_mocks/fake_auth_api_service.dart`,
`test/_mocks/fake_firebase_service.dart`, `test/providers/mock_api_service.dart`.

1,372 static call sites expand to ~1,789 at runtime (parameterized guard loops, e.g.
`test/screens/overflow_smoke_test.dart` 37 screens × 3 widths). Ratio: **2.33 `expect(` per test**.

**The imbalance:** `test/models/` carries 276 tests for 2,754 LOC (1 test per 10 LOC) while
`test/services/` carries 130 tests for 3,547 LOC (1 per 27 LOC) — and services is where payments,
Firebase, sync and token refresh live. `test/screens/` looks well covered by file count (47 files)
but 120 of its tests never execute a single line of `lib/screens/` (see §8-B).

---

## Findings

### 8. Testing — Unit Tests

- ✅ **Test names describe behaviour, not implementation** — sampled across the suite, names read
  as sentences with expected outcomes, e.g. `test/services/payment_service_test.dart:419`
  `'when backend verification throws, onFailure (NOT onSuccess) is called with verification message'`
  and `test/providers/cart_provider_test.dart:135` `'setting quantity to 0 removes item'`.
  This is a genuine strength.

- ✅ **Dependencies mocked/stubbed (no real network/DB calls)** — `grep -rn "http.Client()\|HttpClient()"
  test --include="*_test.dart"` returns **zero** hits. `test/services/api_service_test.dart:36-58`
  injects `MockClient` from `package:http/testing.dart`; Razorpay is stubbed at the
  `MethodChannel` level (`test/services/payment_service_test.dart:107-133`). No test opens a socket.

- ✅ **Edge cases tested (empty inputs, nulls, boundaries)** — strongest in the pure-logic modules:
  `test/utils/pricing_test.dart:123` (`GST on ₹0`), `:127` (fractional `₹999 → ₹179.82`), `:131`
  (negative price throws), `:217` (over-consumed refund), `:226` (below minimum non-refundable);
  `test/providers/cart_provider_test.dart:135,141,147` (quantity 0 / negative / out-of-bounds);
  `test/utils/vital_ranges_test.dart:39-45` (ordering invariants per vital, table-driven).

- ✅ **All model encoding/decoding tested** — round-trips present across 13 model files, e.g.
  `test/models/cart_item_test.dart:335` `'toJson/fromJson round-trip'`,
  `test/screens/checkout/address_test.dart:26` `SavedAddress` round-trip,
  `test/models/service_models_test.dart:138` (`basePriceMin` null when absent).

- ⚠️ **All business logic tested** — the *pure* logic is covered well (`lib/utils/pricing.dart`
  34 tests, `lib/utils/permissions.dart` 49, `lib/utils/vital_classifier.dart` 23,
  `lib/utils/validators.dart` 17). But the business logic embedded in screens is not — see the
  `_priceMultiplier` finding below. `Validators.numberInRange` (`lib/utils/validators.dart:88`)
  has **no test group** despite being the validator used on the vitals-entry form
  (`lib/screens/reports/vitals_screen.dart:679`) — the one place a bad number is a clinical risk.

- ❌ **All business logic tested — `_priceMultiplier` has zero tests** — evidence:
  `grep -rn "ultiplier" test` returns exactly one unrelated hit
  (`test/screens/billing/billing_screen_test.dart:341` `'handles quantity multiplier'`, a cart-line
  test). `lib/screens/services/service_booking_screen.dart:151-156`:
  ```dart
  int get _priceMultiplier {
    if (_isIvVisit) return _ivSessions;
    if (_isOngoingManpower) return int.parse(_servicePeriod);
    if (_isPhysio) return int.parse(_physioPeriod);
    return 1;
  }
  ```
  It is applied at `:2126` and `:2477` (`final subtotal = price * _priceMultiplier`).
  **Impact:** this is the arithmetic that turns a ₹1,500/day caretaker rate into a ₹45,000
  30-day charge. An off-by-one, a wrong branch, or an `int.parse` on a non-numeric period would
  mis-bill every manpower and physio booking, and nothing in 1,789 tests would fail.
  **Fix:** extract the multiplier to `lib/utils/pricing.dart` as
  `int bookingMultiplier({required String serviceId, required int ivSessions, required String servicePeriod, required String physioPeriod})`
  and add a table-driven test per branch plus the `int.parse` failure case.

- ❌ **All business logic tested — the LIVE manpower pricing rule is untested; only the DEAD one is**
  — `test/screens/services/service_booking_test.dart:205-278` is the only widget test of the booking
  wizard. It constructs a manpower item with **no price**
  (`:216-221` `ServiceItem(id: 'mp-caretaker-basic-12', …, category: 'manpower', bookingType: 'scheduled')`
  — no `basePriceMin`) and then asserts `expect(find.textContaining('₹'), findsNothing)` (`:238`,
  `:246`, `:257`), `expect(order['totalAmount'], 0)` (`:275`) and `quoteStatus == 'pending'` (`:274`).
  That is correct for a price-less item — but the test is *named* `'manpower runs the FULL wizard …
  shows no ₹ anywhere'` and grouped under `'Manpower booking — quote-first wizard'` (`:182`), which
  encodes the rule the owner reversed on 2026-06-11. `grep -rn "basePriceMin" test` shows **no test
  anywhere constructs a priced manpower item and runs the wizard**.
  **Impact:** the current inviolable rule ("Manpower prices ARE shown and directly bookable",
  CLAUDE.md) has zero regression protection, while the suite reads as if the opposite rule is
  enforced. A future agent reading this file will re-hide prices and the suite will go greener, not
  redder. **Fix:** rename the group to `'price-less service → quote-pending'`, and add a sibling
  widget test with `basePriceMin: 1500`, `_servicePeriod = '30'`, asserting `₹45,000` on the review
  step and that the item lands in the cart (not `OrdersProvider`).

- ❌ **All service/repository methods tested** — four services have **zero** test files:
  `lib/services/firebase_service.dart` (396 LOC), `lib/services/sync_service.dart` (120 LOC),
  `lib/services/payment_reminder_service.dart` (167 LOC), `lib/services/voice_service.dart` (120 LOC).
  `lib/providers/billing_provider.dart` (64 LOC) likewise. Confirmed by `ls lib/services` vs
  `find test/services`. `docs/TEST_MAP.md:126,131,132` already admits firebase/sync/payment-reminder
  are MISSING and marks firebase + sync `Critical? YES` — so this is a known, unclosed P1.

- ⚠️ **Error paths tested (not just happy paths)** — good in `test/services/api_service_test.dart`
  (401/404/500 → `ApiException` at `:204-213`, `SocketException` and `TimeoutException` retried then
  rethrown) and in provider tests via `MockApiService.shouldThrowApiException`
  (`test/providers/mock_api_service.dart:24-27`). Weak everywhere in `test/screens/`: of 215
  `testWidgets`, none asserts a rendered error state produced by a thrown dependency.

### 8-A. Assertion quality (quantified)

Scripted analysis over all 1,372 test bodies (brace-matched, comments and string literals stripped):

| Category | Count | % of 1,372 |
|---|---:|---:|
| Tests with **no** `expect`/`verify` at all | **3** | 0.2% |
| Tests where **every** assertion is a `finds*` matcher (render-only) | **111** | 8.1% |
| …of those, where every finder is `find.text` (pure string presence) | **63** | 4.6% |
| `testWidgets` that are **inert** — no `tap`/`enterText`/`drag`/`longPress` **and** only `finds*` assertions | **97 of 215** | **45% of widget tests** |

- ❌ **Tests with no behavioural assertion** — 3 tests contain no assertion whatsoever:
  2 in `test/utils/notification_router_test.dart`, 1 in `test/services/payment_service_test.dart`
  (the `dispose()` loop at `:280-287`, which only checks "does not throw"). These pass
  unconditionally. **Fix:** add `expect(…)` or delete.

- ⚠️ **45% of widget tests are inert** — the largest single concentration is
  `test/screens/my_care/my_care_widgets_test.dart` (28 of its 34 tests). The pattern
  (`:94-98`):
  ```dart
  testWidgets('renders manager name', (tester) async {
    final manager = _makeHealthManager(name: 'Priya Sharma');
    await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));
    expect(find.text('Priya Sharma'), findsOneWidget);
  });
  ```
  This is not worthless — it *does* verify the constructor argument reaches the tree — but it is the
  weakest useful assertion available, and 28 near-identical variants of it inflate the count without
  adding risk coverage. `ActiveServiceCard` has computed state (days remaining, progress ratio,
  vital-status colour) and none of it is asserted numerically.
  Next largest: `care_team_screen_test.dart` 7/7, `quote_pending_surfaces_test.dart` 6/6,
  `staff_role_sheet_test.dart` 5/6, `home_layout_test.dart` 4/5, `booking_confirmation_test.dart` 4/8,
  `sos_screen_test.dart` 3/9.
  **Fix (cheap, high leverage):** for each inert test that renders a *computed* value, assert the
  computed number/colour rather than the input string; for screens with actions, add one
  `tester.tap` + state assertion per screen.

- ✅ **Not everything is inert — the guards are excellent.** `test/screens/overflow_smoke_test.dart`
  asserts `tester.takeException()` is null after pumping 37 screens at 320/375/414 with demo data
  populated (`:1-28` explains exactly why the older 1080×4000 tests could never catch the bug that
  shipped). `test/utils/i18n_sync_test.dart:27-59` asserts real key-set and placeholder-set equality
  against the actual JSON files with actionable `reason:` strings. These are the two highest-value
  test files in the repo.

### 8-B. Tests that assert a *copy* of production (tautologies)

**11 test files openly declare that they replicate production data or logic** rather than invoke it.
Found via `grep -rniE "re-?implement|replicate|mirror|canonical data|duplicated" test`:

| File | Tests | `testWidgets` | Imports the screen it mirrors? | Executes production code? |
|---|---:|---:|---|---|
| `test/screens/services/assessment_form_test.dart` | 26 | 0 | no | **no** |
| `test/screens/services/booking_history_test.dart` | 20 | 0 | no | **no** |
| `test/screens/settings/notification_prefs_test.dart` | 18 | 0 | no | **no** |
| `test/screens/cart/cart_coupon_test.dart` | 17 | 0 | no | **no** |
| `test/screens/services/equipment_detail_test.dart` | 17 | 0 | no | **no** |
| `test/screens/settings/help_faq_test.dart` | 12 | 0 | no | **no** |
| `test/screens/services/service_catalog_test.dart` | 10 | 0 | no | **no** |
| `test/screens/checkout/address_test.dart` | 19 | 0 | yes (model only) | partial |
| `test/screens/services/service_booking_test.dart` | 17 | 1 | yes | 1 of 17 |
| `test/screens/auth/login_screen_test.dart` | 19 | 8 | yes | 8 of 19 |
| `test/screens/dark_mode_sweep_test.dart` | 7 | 7 | yes | yes (fixtures duplicated only) |

- ❌ **120 tests execute zero production code** — the seven files in the top block have no
  `testWidgets` and never import the screen they claim to test. They import only
  `package:flutter_test/flutter_test.dart` and then declare their own copy. Example,
  `test/screens/cart/cart_coupon_test.dart:12-32`:
  ```dart
  // ── Coupon logic replicated from _CartScreenState._applyCoupon ──────────────
  int? applyWelcome10(String code, int subtotal) {
    if (code != 'WELCOME10') return null;
    int discount = (subtotal * 10 / 100).round();
    if (discount > 500) discount = 500;
    return discount;
  }
  ```
  All 17 tests exercise `applyWelcome10`. The real implementation at
  `lib/screens/cart/cart_screen.dart:49-60` is never called.
  **Impact:** if the ₹500 cap moves to ₹300 in production, all 17 tests still pass. Same structure
  for the FAQ list (18 entries duplicated), the notification-preference matrix (9 keys including the
  five `forced: true` safety alerts), the IV infusion price table, the equipment discount helpers and
  the NCR city list.
  *I checked for drift that has already happened and found none* — production and test copies still
  match for FAQ (18 vs 18 `question:` entries), notification keys (identical 9-key sets), the coupon
  formula, `_cities` (`lib/screens/checkout/address_selection_screen.dart:410`) and the IV table. The
  defect is structural, not yet live.
  **Fix:** make the data public and import it (`static const faqs`, `static const notifPrefs`,
  `static const ivInfusionTypes`), or move it to `lib/data/`. One-line change per file; the tests
  then become real.

- ❌ **A whole policy group tests logic that does not exist in production** —
  `test/screens/services/booking_history_test.dart:153-199`, group `'Booking history — Refund policy'`:
  ```dart
  test('>24 hours before service gives full (100%) refund', () {
    final scheduledDate = DateTime.now().add(const Duration(hours: 48));
    final now = DateTime.now();
    final hoursUntil = scheduledDate.difference(now).inHours;
    final refundPercent = hoursUntil > 24 ? 100 : 50;
    expect(refundPercent, 100);
  });
  ```
  The policy, the branch and the user-facing strings (`:182-198`) are all authored inside the test.
  `grep -rn "refundPercent\|hoursUntil" lib` returns **nothing** — there is no 24-hour refund policy
  in `lib/` at all. **Impact:** the suite reports a cancellation-refund policy as tested when the
  product does not implement one. **Fix:** delete the group, or implement
  `calculateCancellationRefund()` in `lib/utils/pricing.dart` and point the tests at it.
  Bonus bug: `:172-180` `'exactly 24 hours before service gives 50% refund'` passes for the wrong
  reason — the second `DateTime.now()` is microseconds later so `.inHours` truncates to **23**, not
  24; the comment "24 is not > 24" describes a branch the test never reaches.

### 8-C. Tests that guard code the app cannot reach

- ❌ **24 P0-labelled tests guard an orphan module.** `lib/utils/booking_state_machine.dart` exports
  `canTransition`, `transition`, `validNextStatuses` (`:40,50,62`). `grep -rn "BookingStateMachine\|
  canTransition\|booking_state_machine" lib` returns **zero hits outside the file itself** — the only
  references are the 24 assertions in `test/models/booking_state_machine_test.dart`.
  Meanwhile the actual status mutation, `lib/providers/orders_provider.dart:96-102`, applies
  **no validation at all**:
  ```dart
  void updateOrderStatus(String orderId, String newStatus) {
    final index = _orders.indexWhere((o) => o['id'] == orderId);
    if (index >= 0) {
      _orders[index] = {..._orders[index], 'status': newStatus};
  ```
  …and `grep -rn "updateOrderStatus" lib` shows it has **zero callers**.
  **Impact:** `docs/TEST_STRATEGY.md:157` lists *"Booking status transitions are strictly enforced —
  no skipping steps, no going backwards"* as a key business rule encoded in tests, and
  `docs/TEST_MAP.md:45` marks it `Critical? YES`. Both are false: nothing enforces it in the running
  app. **Fix:** call `canTransition()` inside `updateOrderStatus` and throw/no-op on an invalid
  transition, then add a provider-level test — that converts 24 dead tests into 24 live ones.

- ❌ **19 tests guard an unreachable screen.** `lib/screens/auth/login_screen.dart` is referenced
  nowhere: `grep -rn "LoginScreen\|'/login'" lib` matches only the file's own declaration
  (`:11,12,15,18`); it has no `onGenerateRoute` case in `lib/main.dart:425-500`.
  `test/screens/auth/login_screen_test.dart` has 19 tests including the "audit M-7" T&C-consent and
  Indian-mobile fixes.

- ⚠️ **The whole auth flow is behind a disabled gate.** `lib/main.dart:408-410`:
  ```dart
  // NOTE: Auth gate disabled for demo mode. Enable before production release.
  // home: Consumer<AuthProvider>(...),
  home: const SplashScreen(),
  ```
  and `lib/screens/splash_screen.dart:17` does `pushReplacementNamed('/home')`. So 45 auth tests
  (`auth_provider_test` 18 + `login_screen_test` 19 + `otp_screen_test` 8) currently guard a path no
  user traverses. This is expected for demo mode, but it means "authentication flows tested
  end-to-end" is untrue of the shipped build.

- ⚠️ **Other orphans** (never imported by any `lib` file): `lib/services/sync_service.dart` (also
  untested), `lib/screens/my_care/widgets/billing_summary_section.dart`,
  `lib/screens/my_care/widgets/quick_actions_row.dart`,
  `lib/screens/services/widgets/catalog_search_bar.dart`.

### 8-D. Coverage gaps ranked by risk (not by percentage)

| Risk area | Status | Evidence |
|---|---|---|
| Quote-vs-priced booking maths (`_priceMultiplier`) | ❌ none | `service_booking_screen.dart:151`; `grep "ultiplier" test` → 1 unrelated hit |
| Priced manpower booking end-to-end | ❌ none | no test builds a manpower `ServiceItem` with `basePriceMin` and pumps the wizard |
| Rate card values (`catalog_seeds.dart`) | ❌ none | only referenced by `overflow_smoke_test.dart`; no assertion on ₹800–1,500/day etc. |
| Token refresh — 401 → refresh → retry | ❌ none | `grep "onUnauthorized" test/services/api_service_test.dart` → none; `lib/services/api_service.dart:88-98` untested |
| Token refresh — `AuthProvider._refreshToken` / `handleUnauthorized` | ❌ none, and untestable as written | `lib/providers/auth_provider.dart:91-116` reaches `FirebaseAuth.instance.currentUser` directly (`:93`) instead of the injected `_firebaseService`, so `FakeFirebaseService` cannot drive it |
| 50-min periodic refresh timer | ❌ none | `lib/providers/auth_provider.dart:76-86` |
| Payment screen (`lib/screens/billing/payment_screen.dart`, 900 LOC) | ❌ none | `grep -rl "PaymentScreen" test` → no hits |
| Payment failure paths (service level) | ⚠️ good but **skipped by default** | 8 groups / 17 tests gated on `--dart-define`, see §8-F |
| Firestore security rules (156 LOC) | ❌ none | no rules-test harness anywhere in the repo |
| Cloud Function `functions/index.js` (197 LOC, Claude endpoint) | ❌ none | `functions/package.json` has no test script or dev-deps |
| Role/permission gating **at the 31 call sites** | ⚠️ matrix ✅, gates mostly ❌ | `canUserPerform` matrix has 49 tests; only 3 gates are exercised at widget level (`my_care_screen_test.dart:170` caretaker, `home_layout_test.dart:200` patient-self, `assistant_executor_test.dart:168,180,294`). Untested gates include `billing_screen.dart:135` (`canPay`), `cart_screen.dart:437,459` (pay vs request), `patient_profile_screen.dart:442`, `family_members_screen.dart:266`, `service_catalog_screen.dart:233`, `staff_role_card.dart:283`, `equipment_item_card.dart:246,300` |
| PDF generation | ✅ strongest service coverage | `invoice_pdf_service_test.dart` inspects uncompressed bytes for the PRO-FORMA / zero-amount policy (`:93`), amounts+GST on priced orders (`:114`), and determinism modulo `/ID` (`:142`) |
| Handover PDF | ⚠️ thin | 4 tests (`handover_report_service_test.dart`) for 308 LOC; determinism + filename only, no content-policy assertion, and no test that the `share_handover` role gate blocks a CARETAKER |
| SOS | ✅ good | `sos_screen_test.dart` covers 4 option tiles, clipboard copy, missing/empty address, and all three `tel:` launches (`:263,279,296`) plus the `/raise-concern` soft fallback |
| Offline/demo fallback | ⚠️ partial | `DemoData` referenced in 15 `lib` files and 19 test files, but no test asserts the *transition* (live fetch fails → demo data serves the UI); `sync_service.dart` untested and unused |
| Cart edge cases | ✅ strong | quantity 0 / negative / out-of-bounds (`cart_provider_test.dart:135,141,147`), rental subtotal (`:220`), delivery boundary at exactly ₹1,000 (`:248`), save-for-later merges |
| Cart rental-months clamp | ⚠️ | `lib/providers/cart_provider.dart:117` (`if (months < 1) months = 1`) has no test; only one happy-path call at `test/integration/cart_flow_test.dart:181` |

### 8-E. Mock fidelity

Three fakes, all hand-written (no mockito/mocktail — a deliberate, documented choice):
`test/_mocks/fake_firebase_service.dart` (119 LOC), `test/_mocks/fake_auth_api_service.dart` (56),
`test/providers/mock_api_service.dart` (179).

- ✅ **Fakes fail loudly when under-configured** — `mock_api_service.dart:111,143,157` throw
  `StateError('… not configured in mock')` rather than returning null. Good practice.
- ✅ **`api_service_test` uses a genuinely high-fidelity harness** — `MockClient` from
  `package:http/testing.dart` means the real `ApiService` code path (headers, URI building, JSON
  decode, status mapping, `_withRetry`) executes. This is the best mock in the repo.
- ❌ **The fakes model exactly one failure shape.** `mock_api_service.dart:49-57`:
  ```dart
  void _maybeThrow() {
    if (shouldThrowApiException) throw ApiException(statusCode: …, message: …);
    if (shouldThrowGenericError) throw Exception('generic error');
  }
  ```
  There is **no** timeout, no `SocketException`, no latency/ordering control, no malformed-payload
  case, and no 401→refresh path — even though the real `ApiService` handles all of them
  (`lib/services/api_service.dart:71-82` retries `SocketException`/`TimeoutException`, `:95-97`
  refreshes on 401). Every fake method resolves synchronously, so no provider test can observe a
  loading state, a cancelled request, or two in-flight calls resolving out of order.
  **Impact:** provider error-handling is verified only against an immediate synchronous throw — the
  easiest possible failure. **Fix:** add `Duration? latency` and
  `Object? throwOnCall(int n)` to the fakes, plus a `TimeoutException` flag.
- ❌ **`FakeFirebaseService` cannot model token refresh.** It overrides `getIdToken()` (`:85`) but
  there is no `getIdToken(true)` force-refresh, matching the fact that production bypasses the
  service entirely (`auth_provider.dart:93`). The fake faithfully reproduces an untestable design.
- ⚠️ **`_FakeApiService` in `payment_service_test.dart:53` extends rather than implements
  `ApiService`** — deliberate and documented (`:48-52`), but it means any method PaymentService
  starts calling in future silently hits the *real* implementation against `https://fake.test`.

### 8-F. Skipped / gated tests — what does NOT run on a bare `flutter test`

`grep -rn "skip:" test` → 8 occurrences, all in `test/services/payment_service_test.dart`
(`:288, 360, 412, 468, 514, 643, 683, 818`), all gated on `_skipReason`
(`:185-191`), which is non-null unless `--dart-define=RAZORPAY_KEY=<non-placeholder>` is passed.

| Gated group | Line | Tests | What stops running without the define |
|---|---:|---:|---|
| `PaymentService construction` | 264 | 3 | ctor + dispose-leak safety |
| `createOrder` | 293 | 4 | order-id happy path, `referenceType` pass-through, backend-throw → null, missing-field → null |
| `openCheckout — verified success` | 365 | 1 | backend `verifyPayment` called with the right payment/order/signature |
| `openCheckout — verification failure (M-2 regression)` | 417 | 1 | **the regression guard that a failed verify must NOT confirm the booking** |
| `openCheckout — demo mode (skippedDemo)` | 473 | 1 | demo success without calling `verifyPayment` |
| `openCheckout — error handling` | 519 | 3 | cancel message pass-through, null-message fallback `'Payment failed'`, sync-throw contract |
| `openCheckout — external wallet` | 648 | 1 | wallet event fires neither callback and does not verify |
| `openCheckout — options payload` | 688 | 3 | amount / currency / `order_id` omission / brand theme `#E8820E` / prefill assembly |
| **Total silently skipped** | | **17** | |

Only the 2-test `'PaymentService — demo payments contract'` group (`:225`) runs in both configs —
and one of those two self-skips at runtime via `markTestSkipped` (`:240`) when a real-ish key *is*
configured, so no single invocation exercises both branches.

- ✅ **CI does pass the define** — `.github/workflows/ci.yml` runs
  `flutter test --coverage --reporter=expanded --dart-define=RAZORPAY_KEY=rzp_test_ci_dummy_key`,
  with an explicit comment (`ci.yml`, "Test" step) explaining that without it "they silently skip and
  CI looks green while never exercising payment payload/status logic". Correctly handled.
- ⚠️ **The default local command does not.** A developer running plain `flutter test` sees green
  while the entire payment-failure surface — including the M-2 regression — is skipped.
  CLAUDE.md documents the correct command, but nothing enforces it.
  **Fix:** add a `dart_test.yaml` default or a `tool/test.sh` wrapper that always injects the define.

### 8-G. Determinism

- ✅ **No real network, no real DB, no real filesystem writes** — verified above; the only real file
  reads are `assets/i18n/*.json` in `i18n_sync_test.dart:21-24` (intentional and correct).
- ⚠️ **60 `DateTime.now()` occurrences across 23 test files** (`grep -rc "DateTime.now()" test`).
  Highest: `billing_screen_test.dart` (10), `booking_history_test.dart` (6), `helpers_test.dart` (5),
  `cache_service_test.dart` (5), `orders_provider_refund_test.dart` (5). Most are benign relative
  offsets (`DateTime.now().subtract(Duration(days: 10))`), but `booking_history_test.dart:172-180`
  is a demonstrated wrong-reason pass (see §8-B) and `billing_screen_test.dart:233-270` builds
  30/15/10/8/7/3-day windows off the wall clock — a run straddling midnight or a month boundary can
  shift which bucket a fixture lands in.
- ⚠️ **Wall-clock sleeps used as synchronisation.** `grep -rhoE "Duration\((milliseconds|seconds): [0-9]+\)" test`
  → 36 × 100 ms, 10 × 1 s, 2 × 200 ms, 1 × 1200 ms, plus `runAsync` in 16 files.
  Worst offenders: `payment_service_test.dart:254` (`await Future.delayed(Duration(milliseconds: 1200))`
  to wait for a simulated checkout), `service_booking_test.dart:227` (200 ms for localisation to
  settle), `sos_screen_test.dart` (18 `runAsync` blocks). On a loaded CI runner these are the
  most likely flake sources in the suite. **Fix:** replace fixed delays with a completer/latch —
  `payment_service_test.dart:825-848` already contains a perfectly good `_CallbackLatch` that the
  1200 ms wait ignores.
- ⚠️ **`api_service_test.dart` sleeps ~18 s of real time.** Seven groups carry
  `timeout: const Timeout(Duration(seconds: 30))` (`:248, 266, 281, 328, 344, 361, 514`) because
  `_withRetry` uses real `Future.delayed(_retryDelay * attempt)` (`lib/services/api_service.dart:67,76,81`).
  **Fix:** make `_retryDelay` injectable and pass `Duration.zero` in tests.
- ⚠️ **Shared static `GlobalKey`.** `lib/screens/main_shell.dart:16-17` exposes
  `static final GlobalKey<MainShellState> shellKey`, reused by every test that pumps `MainShell`
  (`main_shell_test.dart`, `overflow_smoke_test.dart`, `dark_mode_sweep_test.dart`). Sequential
  pumps within a file are safe only because the previous tree is torn down first — it is a latent
  cross-test coupling, not a current failure.
- ✅ **Isolation hygiene is otherwise sound** — 36 `setUp(` vs only 2 `setUpAll(`;
  49 `addTearDown(` (correctly scoped, e.g. `service_booking_test.dart:211-212` resetting
  `tester.view`); `SharedPreferences.setMockInitialValues` called in 38 files. Only two file-scope
  mutable declarations exist (`address_test.dart:16`, `staff_role_sheet_test.dart:40`), both
  effectively const.

### 8-H. Integration Tests

- ❌ **`test/integration/` is not integration testing.** Four files, 15 tests total, and three of
  them contain exactly **one** test each (`assessment_to_orders_test.dart:17`,
  `billing_from_orders_test.dart:50`, `checkout_flow_test.dart:41`). All four drive providers
  directly in-process — `cart_flow_test.dart` is 12 `CartProvider` method-call tests. No widget
  tree, no navigation, no service boundary, no persistence round-trip across a restart.
- ❌ **Service-to-database flows tested** — no database in the test path at all; `firestore.rules`
  (156 LOC) and `database/schema.sql` have no harness.
- ✅ **API endpoint request/response tested** — genuinely covered by
  `test/services/api_service_test.dart` (50 tests, `MockClient`, per-method happy + error path).
- ❌ **Authentication flows tested end-to-end** — provider-level only, and the flow is disabled in
  the app (`lib/main.dart:408-410`).
- ⚠️ **Cross-module data flow tested (change in A reflects in B)** — partially:
  `billing_from_orders_test.dart:50` asserts billing totals derive from orders, and
  `orders_persistence_test.dart` asserts demo orders are never written to storage. Good, but only
  two such links for 11 providers.
- ✅ **External service integrations tested (with mocks)** — Razorpay via `MethodChannel` stub,
  HTTP via `MockClient`, Firebase via manual fake.

### 8-I. Security Tests

- ❌ **Authentication bypass attempts tested** — none.
- ❌ **Authorization escalation attempts tested** — the *matrix* is exhaustively tested
  (`permission_test.dart`, 49 tests, all 4 roles × all 9 actions plus unknown-role defaults at
  `:277`), but no test attempts to reach a gated action *through the UI* as a lower-privileged role.
  The 31 `canUserPerform` call sites in 14 screens are almost all unguarded by tests (§8-D).
- ❌ **SQL injection payloads tested** — none. `grep -rniE "injection|drop table|'; --" test` returns
  only unrelated hits (`'Injection (IV/IM)'`, `'IM Injection Visit'`).
- ❌ **XSS payloads tested** — none.
- ❌ **Rate limiting verified / CSRF protection verified** — none; no rate-limit or CSRF code exists
  client-side either. Server-side is BLOCKED-OWNER.
- ⚠️ **Invalid token handling tested** — partially: `api_service_test.dart:204` asserts a bare 401
  becomes `ApiException(401)`, and `:458` covers a 401 from `verifyOtp`. The *recovery* path
  (`onUnauthorized` → refresh → retry once, `lib/services/api_service.dart:88-98`) has **zero**
  tests. **Impact:** the single mechanism that keeps a 60-minute session alive is unverified.
  **Fix:** inject a `MockClient` that returns 401 then 200, set `onUnauthorized: () async => true`,
  and assert exactly two requests with the second carrying the new bearer token.

### 8-J. Regression Tests

- ✅ **Previously fixed bugs have regression tests** — 16 test files carry explicit provenance
  markers. `grep -rhoiE "BUG-[0-9]+|audit M-[0-9]+|audit R[0-9]+" test` →
  `BUG-08 BUG-09 BUG-10 audit M-1 M-4 M-5 M-6 M-7 M-12 M-14 R2`. Best example:
  `payment_service_test.dart:417` names the M-2 defect and asserts `onSuccess` must not fire.
  `overflow_smoke_test.dart:1-28` documents the exact shipped bug and why the old tests missed it.
  This is above-average discipline.
- ✅ **Critical paths have automated tests** — cart→checkout→order→billing chain is covered
  end-to-end at provider level.
- ⚠️ **Smoke tests cover auth, core CRUD, key features** — screens ✅ (37-screen overflow sweep,
  dark-mode sweep), auth ⚠️ (tested but the flow is disabled), payments ❌ by default (gated).

### 8-K. Test Infrastructure

- ✅ **Tests run in CI on every PR** — `.github/workflows/ci.yml`, `on: pull_request: branches: [main]`;
  Flutter pinned to `3.41.2` with a comment explaining why drift matters.
- ✅ **Code coverage tracked (minimum threshold enforced)** — `ci.yml` "Coverage gate" step parses
  `lcov.info` and fails below `COVERAGE_THRESHOLD: "50.0"`, uploads the artifact on every run with
  14-day retention. Genuinely enforced, not decorative.
- ⚠️ **Threshold is below the documented target** — `docs/TEST_STRATEGY.md:148` states 60% overall
  and 95%/80%/80% for utils/providers/models; CI enforces a flat 50% with a comment promising 70%
  "by next quarter". No per-module gate exists, so the 40%-target screens layer (40,185 LOC, the
  bulk of the codebase) can drag the global number while `lib/utils/` regressions hide inside it.
- ⚠️ **Tests are deterministic** — see §8-G; no known flakes, but ~20 s of wall-clock sleeping and
  60 `DateTime.now()` uses are unforced risk.
- ✅ **Test data is isolated** — per-test `setUp` + `SharedPreferences.setMockInitialValues`
  in 38 files; only 2 `setUpAll`.
- ⚠️ **Tests run fast (< 5 min for unit suite)** — cannot time it (instructed not to run the suite,
  and the central run's wall time was not provided to me). Static evidence: ≥18 s of deliberate
  sleeping in `api_service_test.dart` alone plus ~7 s across 100 ms/1 s delays elsewhere; 215 widget
  tests including a 111-permutation overflow sweep. Plausibly 2–4 min. **BLOCKED-OWNER** for the
  exact figure — I need the central run's reported duration.

### 8-L. Docs vs the actual test tree

`docs/TEST_MAP.md` and `docs/TEST_STRATEGY.md` are both stale and, in three places, actively wrong.

- ✅ File count correct — `TEST_MAP.md:6` claims 99, `find test -name "*_test.dart" | wc -l` → **99**.
- ⚠️ Call-site count off by 2 — `:4` claims 1,370, actual **1,372**. Runtime claim ~1,771 vs the
  central run's ~1,789.
- ❌ **`TEST_MAP.md:156` self-contradicts** — the section is titled *"Existing Test Files (complete
  inventory — 86 files, 2026-06-11)"* inside a document whose header says 99. **13 files are absent
  from the inventory:** `reminders_provider_test`, `dark_mode_sweep_test`, `main_shell_test`,
  `medication_schedule_screen_test`, `service_detail_screen_test`, `quote_pending_surfaces_test`,
  `vitals_screen_test`, `equipment_rail_classification_test`, `reserve_flow_negative_test`,
  `validators_test`, `care_pulse_ring_test`, `day_part_header_test`, `glass_app_bar_test`.
- ❌ **Per-file counts are wrong in both directions** — `cart_provider_test` listed 48, actual 36;
  `permission_test` listed 25, actual 49; `pricing_test` 22 → 26; `vital_classification` 26 → 23;
  `cart_item_test` 24 → 19; `cart_screen_test` 27 → 31; `billing_screen_test` 23 → 26;
  `my_care_provider_test` 18 → 21; `orders_persistence_test` 11 → 10.
- ❌ **`TEST_MAP.md:286` misattributes the skips** — *"17 are skipped (Firebase-init-dependent
  scenarios that need an emulator harness)"*. They are not Firebase-related: all 17 are the Razorpay
  `--dart-define` gate in `payment_service_test.dart` (§8-F). A reader would go looking for an
  emulator harness that has nothing to do with it.
- ❌ **`TEST_STRATEGY.md:154` states the DEAD business rule as fact** — *"Manpower services
  (caretaker, nursing_deployment, japa, nanny) have NO commission — users reject if they see prices
  upfront."* The second clause was reversed by the owner on 2026-06-11 and CLAUDE.md now lists the
  opposite as inviolable. (The *commission* half may still be correct — `pricing_test.dart:60-96`
  tests zero commission for manpower — but the justification clause must go, and Japa/Nanny are no
  longer Housepital offerings per CLAUDE.md.)
- ❌ **`TEST_STRATEGY.md:5-15` describes a testing stack that does not exist.** Claimed:
  `integration_test` package (no `integration_test/` directory; not in `pubspec.yaml`),
  Patrol E2E (`grep patrol pubspec.yaml` → 0), Firestore Security Rules unit tests via the Emulator
  Suite (no such harness anywhere), Razorpay webhook simulation (no webhook test).
  `dev_dependencies` is exactly `flutter_test`, `flutter_lints`, `plugin_platform_interface`,
  `url_launcher_platform_interface`.
- ⚠️ `TEST_STRATEGY.md:26` lists only three roles for permission tests; `CARETAKER` was added later
  (`lib/utils/permissions.dart:23`) and is tested (`permission_test.dart:133`).

---

## Sections 1–7 and 9 (secondary scope — sibling audits cover these in depth)

### 1. Code Quality & Architecture
- ✅ **Dependency Inversion in the data layer** — `lib/services/i_api_service.dart` exists and
  `AuthProvider` depends on `IApiService` (`lib/providers/auth_provider.dart:44`), which is what
  makes the fakes possible without a mocking framework.
- ✅ **Dead code — no commented-out blocks** — `grep -rnE "^\s*// *(final|const|return|if \(|await|setState|Widget )" lib`
  → **2** hits. Very clean.
- ✅ **No `print()` in production** — `grep -rn "^\s*print(" lib` → **0**; a `Log` wrapper is used
  (`lib/utils/logger.dart`).
- ❌ **"Ensure that files are never [un]referenced"** — 6 orphan files (§8-C), one of which
  (`booking_state_machine.dart`) carries 24 tests and a `Critical? YES` label.
- ❌ **Views should never directly call the data layer** — the booking wizard holds pricing
  arithmetic (`_priceMultiplier`), the catalog data (`_ivInfusionTypes`, `_concernCategories`) and
  the coupon rule (`cart_screen.dart:49-60`) inside `State` classes. This is *the direct cause* of
  the 120 mirror-tests: the tests physically cannot reach the logic. Fixing the layering fixes the
  test problem.
- ⚠️ **Single Responsibility** — `service_booking_screen.dart` is 3,032 LOC,
  `equipment_detail_screen.dart` 1,923, `home_screen.dart` 1,904, `care_calendar_screen.dart` 1,811.
- ⚠️ **DRY / single source of truth for constants** — violated by construction in 11 test files
  (§8-B), plus `_cities` duplicated between `address_selection_screen.dart:410` and
  `address_test.dart:13`.
- ⚠️ **Centralize validation logic** — `lib/utils/validators.dart` exists and is good, but
  `login_screen.dart` re-implements Indian-mobile validation inline (per
  `login_screen_test.dart:23-28`) instead of calling `Validators.indianMobile`.

### 2. Input Validation & Sanitization
- ✅ **Client-side text/email/pincode/name/age validation** — `lib/utils/validators.dart:26-113`,
  17 tests in `test/utils/validators_test.dart` covering accept/reject/required-vs-optional per rule.
- ✅ **Description length cap tested** — `validators_test.dart:137` `'enforces the raise-concern DoS
  cap (default 1000)'`.
- ⚠️ **Bounds numeric inputs** — `Validators.numberInRange` exists (`:88`) and is used on the vitals
  form (`vitals_screen.dart:679`) but has **no test group**.
- ⚠️ **Limit the size of array/collection inputs** — cart has no maximum item count or maximum
  quantity; `updateQuantity` only clamps the lower bound (`cart_provider.dart:104-112`).
- ❌ **File uploads validated for type/size/content** — no upload validation tests found.
- ❌ **AI/LLM: user content sanitized before prompts; prompt-injection patterns filtered; AI output
  sanitized; token/cost limits per user** — `functions/index.js` (197 LOC, `@anthropic-ai/sdk`) has
  no tests of any kind and no test harness configured in `functions/package.json`. The local
  Hinglish intent matcher (`assistant_service.dart`, 14 tests; `assistant_executor.dart`, 28 tests)
  is well covered, but none of those tests feed adversarial input.
- ❌ **Server-side re-validation / SQLi / XSS / CSRF / path traversal / body-size limits** — no tests.
- N/A **Command injection** — no shell execution in a Flutter client.
- N/A **Content-Type validation on uploads** — no upload endpoint in the client.

### 3. Concurrency & Resource Cleanup
- ✅ **Async operations awaited** — `flutter analyze` clean with `unawaited_futures`-class lints
  from `flutter_lints ^6.0.0`.
- ✅ **Timers invalidated** — `auth_provider.dart:83-86` `_stopTokenRefreshTimer`;
  `payment_service_test.dart` disposes the service in every test.
- ⚠️ **Subscriptions/observers removed during cleanup** — only 2 `tearDown(` in the whole suite
  (49 `addTearDown` compensate), so listener-leak regressions are largely unguarded;
  `cart_provider_test.dart:97` and `auth_provider_test.dart:308` are the only listener-contract tests.
- ⚠️ **Debounced operations capture state at invocation time** — no debounce tests found.
- ⚠️ **Race conditions in read-modify-write** — no concurrency test exists; every fake resolves
  synchronously, so interleaving is unreachable (§8-E).
- ❌ **Task cancellation checked in long operations** — no test cancels an in-flight request;
  `ApiService` exposes no cancellation token.
- N/A **UI updates dispatched to main thread / lock ordering** — Dart is single-isolate here.

### 4. Security
- ✅ **No credentials in source** — `AppConstants.razorpayKey` defaults to the placeholder
  `rzp_test_XXXXXXXXXX` and is injected via `--dart-define`; CI passes a static dummy
  (`ci.yml`, "Test" step, explicitly annotated "Static dummy, never a real credential").
- ✅ **Secrets loaded from environment / secret manager** — `ANTHROPIC_API_KEY` is server-side only
  (`functions/index.js`); Firebase plists gitignored per CLAUDE.md.
- ✅ **Lockfile committed** — `pubspec.lock` present.
- ⚠️ **Token expiration enforced / refresh rotation implemented** — implemented
  (`auth_provider.dart:76-116`) but **untested and untestable** (§8-D).
- ⚠️ **Authorization checked on every request (not just UI hiding)** — client-side gating is
  UI-hiding by construction (`canUserPerform` guards `if` blocks in widget trees);
  server-side enforcement lives in `firestore.rules` (156 LOC) with no tests.
- ⚠️ **Dependencies pinned** — `pubspec.yaml` uses caret ranges (`^6.0.0` etc.), resolved by
  `pubspec.lock`. Acceptable, not strict pinning.
- ❌ **Failed login attempts rate-limited** — no client-side attempt counter, no test.
- ❌ **Dependencies scanned for known vulnerabilities** — no `dart pub outdated --mode=security`,
  Dependabot config, or audit step in `ci.yml`.
- ❌ **Rate limiting on expensive operations (AI calls)** — no test; `functions/index.js` untested.
- ❌ **Audit logging for security-relevant actions** — no logging test; `logger.dart:63` carries a
  `TODO(observability)` for Crashlytics forwarding.
- ❌ **Sensitive data encrypted at rest** — no test asserts that tokens are not written to
  `SharedPreferences` in plaintext.
- N/A **Passwords hashed / password strength** — phone+OTP auth, no passwords in the app.
- N/A **CORS** — no browser-origin API surface under test.

### 5. Database & Data Integrity
- ⚠️ **Large result sets paginated** — `lib/widgets/paginated_list.dart` exists with 6 tests
  (`test/widgets/paginated_list_test.dart`), but no test drives a large backend page set.
- ❌ **Foreign keys / unique / NOT NULL / check constraints / cascading deletes / no orphaned
  records** — `database/schema.sql` exists but has **no test harness**; `firestore.rules` likewise.
- ❌ **Migrations are reversible** — no migration tooling or test in the repo.
- N/A **Parameterized statements / indexes / N+1 / connection pooling / query timeouts** — the
  Flutter client issues HTTP calls, not SQL; these belong to the backend audit. **BLOCKED-OWNER.**

### 6. Error Handling
- ✅ **Global error boundary exists** — `lib/main.dart:98` `runZonedGuarded`, `:114`
  `FlutterError.onError`, `:116` `PlatformDispatcher.instance.onError`.
- ✅ **Retry logic with backoff for transient failures** — `lib/services/api_service.dart:19-82`
  (`_maxRetries = 2`, `_retryDelay * attempt`), covering `SocketException`, `TimeoutException` and
  5xx; tested in `api_service_test.dart`.
- ✅ **Error types/enums used (not string-based)** — `ApiException(statusCode:, message:)` used
  consistently; `AuthState` enum for auth.
- ✅ **Graceful degradation when dependencies unavailable** — the `DemoData` fallback across 15
  `lib` files is the whole demo-mode design.
- ⚠️ **User-facing error messages helpful and non-technical** — spot-checked as good
  (`'Payment failed'`, `'Invalid or expired coupon code'`, `'Please enter a coupon code'`), but the
  coupon strings are only asserted against the test's own copy (§8-B).
- ⚠️ **All errors caught and handled** — `payment_service_test.dart:601-608` documents a
  **known unfixed limitation**: `openCheckout` wraps `_razorpay.open()` in try/catch, but the call is
  internally async, so a platform-channel throw becomes an unhandled future error and **no callback
  fires** — the user sees a checkout that silently does nothing. The test only asserts the
  synchronous contract. This is a real, self-documented payment-path defect.
- ❌ **Circuit breakers for external service calls** — none; `_withRetry` retries and gives up but
  never opens a circuit.

### 7. Logging & Observability
- ✅ **Structured logging, not `print`** — `lib/utils/logger.dart` with `Log.debug/warn/error` and a
  `tag:` parameter; zero `print(` in `lib`.
- ✅ **Log levels used appropriately** — `Log.debug` for retries (`api_service.dart:65,74,80`),
  `Log.warn` for refresh failure (`auth_provider.dart:100`).
- ✅ **No sensitive data in logs** — spot-checked: tokens are never interpolated into log strings.
- ⚠️ **18 files still use `debugPrint`** alongside the `Log` wrapper — two logging paths.
- ❌ **Request tracing / correlation IDs** — none.
- ❌ **Performance metrics tracked / alerts for error spikes** — none in-app;
  `logger.dart:63` `// TODO(observability): forward warn/error to FirebaseCrashlytics.recordError`.
  **BLOCKED-OWNER** for whether alerting exists outside the repo.

### 9. Release Readiness
- ✅ **No TODO/FIXME/HACK blocking release** — exactly **3** in 54,295 LOC
  (`app_provider.dart:171` persistence, `logger.dart:63` observability,
  `staff_role_card.dart:300` backend wiring). All scoped and non-blocking.
- ✅ **Environment variables documented** — `docs/ENVIRONMENT_SETUP.md` present; CLAUDE.md documents
  the `RAZORPAY_KEY` define and the `ANTHROPIC_API_KEY` server-side rule.
- ✅ **Known issues documented and accepted** — `docs/KNOWN_ISSUES.md` present and referenced from
  `ci.yml` (tree-shake-icons workaround).
- ⚠️ **Rollback plan exists** — `docs/DEPLOYMENT_GUIDE.md` present; contents not verified against a
  real rollback drill. **BLOCKED-OWNER.**
- ⚠️ **Monitoring/alerting configured** — see §7. **BLOCKED-OWNER.**
- ❌ **No debug/demo mode enabled by default** — the app ships with the auth gate commented out
  (`lib/main.dart:408-410`, *"Auth gate disabled for demo mode. Enable before production release."*)
  and payments in simulated mode with the placeholder key. Both are intentional for demo, both are
  release blockers, and **no test asserts they are off** — a `flutter test` after re-enabling the gate
  would not tell you whether it stayed enabled.
- ❌ **Runbook exists for common failure modes** — `docs/TROUBLESHOOTING.md` exists but no runbook
  keyed to the failure modes this audit surfaces (payment verify failure, token refresh failure,
  demo-fallback activation).

---

## Blockers (must fix before release)

1. **`_priceMultiplier` has no test** (`lib/screens/services/service_booking_screen.dart:151-156`,
   applied at `:2126`, `:2477`). The multiplication that converts a per-day rate into a booking
   total is unverified. Extract to `lib/utils/pricing.dart` and table-drive every branch.
2. **The live manpower pricing rule has no test; only the reversed rule is encoded**
   (`test/screens/services/service_booking_test.dart:182-278`). Add a priced-manpower wizard test
   asserting ₹ appears, the multiplier applies, and the item goes to the cart.
3. **Token-refresh recovery is untested and untestable.** `lib/providers/auth_provider.dart:93`
   uses `FirebaseAuth.instance.currentUser` instead of the injected `_firebaseService`; the
   `onUnauthorized` 401→refresh→retry path (`lib/services/api_service.dart:88-98`) has zero tests.
   Route the refresh through `FirebaseService.getIdToken(forceRefresh: true)`, then add the
   401-then-200 `MockClient` test.
4. **17 payment tests — including the M-2 "failed verification must not confirm the booking"
   regression — are silently skipped on a bare `flutter test`** (§8-F). CI is correct; make the
   local default match via `dart_test.yaml` or a `tool/test.sh` wrapper.
5. **Auth gate and demo payments are on by default with no test asserting they are off**
   (`lib/main.dart:408-410`). Add a release-guard test that fails when `home:` is `SplashScreen`
   under a `--dart-define=RELEASE=true`, and one asserting
   `PaymentService.isDemoPayments == false` for a production key.

## High

6. **120 tests execute zero production code** (§8-B). Seven files test a hand-copied duplicate of
   FAQ data, notification preferences, coupon maths, IV price tables, equipment discounts, catalog
   invariants and address cities. No drift has occurred *yet* — I diffed all of them — but nothing
   would detect it. Make the constants public and import them.
7. **The booking state machine is enforced only in tests.**
   `lib/utils/booking_state_machine.dart` has zero production callers;
   `lib/providers/orders_provider.dart:96-102` mutates status with no validation and has zero
   callers itself. Wire `canTransition` into `updateOrderStatus`.
8. **A refund policy is "tested" that does not exist in production**
   (`test/screens/services/booking_history_test.dart:153-199`). Delete or implement.
9. **`openCheckout` swallows async platform-channel failures** — self-documented at
   `test/services/payment_service_test.dart:601-608`: the user gets no callback at all. Await the
   future or attach a `.catchError` that routes to `onFailure`.
10. **Role gates are untested at 28 of 31 call sites** — notably `billing_screen.dart:135` (`canPay`),
    `cart_screen.dart:437,459` and the handover-export gate. Add one widget test per gate with a
    CARETAKER/FAMILY_MEMBER role.
11. **Four services and one provider have no tests at all** — `firebase_service.dart` (396 LOC),
    `sync_service.dart`, `payment_reminder_service.dart`, `voice_service.dart`,
    `billing_provider.dart`. `firestore.rules` (156 LOC) and `functions/index.js` (197 LOC, the
    Claude endpoint) likewise — the latter is the app's prompt-injection surface.
12. **No security tests of any kind** — no auth-bypass, authz-escalation, injection, XSS, CSRF or
    rate-limit test exists (§8-I).

## Medium / Low

13. **45% of widget tests are inert** (97 of 215) — pump-and-assert-a-string with no interaction.
    Highest concentration `my_care_widgets_test.dart` (28/34). Assert computed values, not inputs.
14. **3 tests contain no assertion at all** — `notification_router_test.dart` ×2,
    `payment_service_test.dart:280-287`.
15. **~20 s of wall-clock sleeping used as synchronisation** — `api_service_test.dart` 7×30 s
    timeouts around real retry delays; `payment_service_test.dart:254` 1200 ms; 36×100 ms elsewhere.
    Make `_retryDelay` injectable; use the existing `_CallbackLatch`.
16. **`booking_history_test.dart:172-180` passes for the wrong reason** — `.inHours` truncates to 23,
    so the "exactly 24 hours" boundary is never actually exercised.
17. **60 `DateTime.now()` uses across 23 test files**; `billing_screen_test.dart:233-270` builds
    day-window fixtures off the wall clock. Inject a fixed clock (the PDF services already do —
    `handover_report_service_test.dart:19` `'is deterministic for a fixed "now"'`).
18. **`test/integration/` is misnamed** — 4 files, 15 tests, three with a single test each, all
    provider-level. Either rename to `test/flows/` or add real widget-navigation integration tests.
19. **`i18n_sync_test.dart` cannot catch the bug it was written for.** Its header (`:5-6`) cites
    `"today_report"` shipping as raw text because "the key existed in code but not in en.json", but
    the test only compares `en.json` ↔ `hi.json` key sets — a key missing from *both* passes. I ran
    the missing check manually: 161 keys referenced in `lib`, **0 missing** from `en.json` (no live
    bug), but **160 of 321 keys (50%) are unused**. Add a third assertion that every `t('…')` literal
    in `lib` resolves, and flag orphan keys.
20. **`Validators.numberInRange` untested** despite guarding vitals entry
    (`lib/screens/reports/vitals_screen.dart:679`).
21. **`cart_provider.dart:117` rental-months clamp (`months < 1`) untested.**
22. **Coverage gate (50%) is below the documented target (60%)** and is global-only — the 40,185-LOC
    screens layer can mask regressions in `lib/utils/`. Add per-module gates.
23. **6 orphan files in `lib`** — `booking_state_machine.dart`, `sync_service.dart`,
    `login_screen.dart`, `billing_summary_section.dart`, `quick_actions_row.dart`,
    `catalog_search_bar.dart`.
24. **`docs/TEST_MAP.md` and `docs/TEST_STRATEGY.md` are stale and in three places wrong** (§8-L):
    the "complete inventory" lists 86 files in a 99-file document; 9 per-file counts are wrong; the
    17 skips are misattributed to Firebase; `TEST_STRATEGY.md:154` states the reversed manpower rule
    as fact; `TEST_STRATEGY.md:5-15` claims four testing tiers (integration_test, Patrol, Firestore
    rules emulator, webhook simulation) that do not exist in `pubspec.yaml` or the repo.

## BLOCKED-OWNER

- **Suite wall-clock time (<5 min target)** — I was instructed not to run `flutter test`.
  Need: the central run's reported duration.
- **Coverage percentage per module** — needs `coverage/lcov.info` from the central run; I could not
  generate it without running the suite.
- **Backend/database items (§5)** — foreign keys, indexes, migrations, connection pooling, query
  timeouts, server-side re-validation, CORS, HTTPS enforcement, rate limiting. `database/schema.sql`
  and `firestore.rules` are in-repo but the live backend is unreachable in demo mode. Need: backend
  repo access or a Firebase emulator run.
- **Monitoring/alerting and error-spike alerts (§7, §9)** — need Firebase Crashlytics / console
  access to confirm what is configured outside the repo.
- **Dependency vulnerability status (§4)** — need a `dart pub outdated --mode=security` run against
  the live pub.dev advisory database (network-dependent).
- **Rollback plan validity (§9)** — `docs/DEPLOYMENT_GUIDE.md` exists; confirming it works needs a
  drill against App Store Connect / Play Console.

---

*Read-only audit. No files under `lib/` or `test/` were modified.*
