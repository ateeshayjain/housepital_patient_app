# Test Map -- Housepital Patient App

**Last updated:** 2026-08-25
**Total test count:** **1,983 at runtime**, measured (1,469 `test()`/`testWidgets()` call sites; parameterized guard suites expand at runtime — the overflow smoke sweep alone is 39 screens × **4 passes**)
**Pass rate:** all 1,983 passing, 0 failures (payment groups require `--dart-define=RAZORPAY_KEY=...`; CI passes `rzp_test_ci_dummy_key`)
**Test file count:** 110 (`find test -name "*_test.dart" | wc -l`)

### The overflow sweep has four passes, not three

320×568, 375×667, 414×896 — and **375×667 at 200% text**. The fourth was added
when `main.dart`'s text clamp was raised from 1.4× to 2.0×: WCAG 1.4.4
requires 200%, and the old ceiling sat under a comment citing that very
criterion. All 156 rows pass, with the Ahem font's worst-case wide glyphs, so
the 1.4× ceiling had never been protecting anything.

**Do not delete that pass.** It is the only evidence behind the number in
`main.dart`; without it, 2.0× becomes a claim.

> **These numbers are from a local run on 2026-08-20 and have no independent
> attestation.** CI has never executed a step (47 runs, billing lock), so no
> figure in this file has ever been reproduced by anything but a developer
> machine. Treat it as a self-report until CI runs.

### Backend tests (separate repo)

`housepital-backend/functions` — `npx jest`. Two suites added in round 4 are
worth knowing about because they need no database and so run anywhere:

| Suite | What it pins |
|-------|--------------|
| `schema-conformance.test.ts` | Every `db("table")` chain in the routes against the SQL migrations. Caught ~20 columns and 4 tables that had never existed. |
| `vital-classifier.test.ts` | The TypeScript threshold table against the **Dart source**, parsed and diffed across the whole range, so the two languages cannot drift. |

### How to update this count

When you add or remove tests:

```bash
# Total passing tests (the "+N" lines in expanded reporter output):
flutter test --reporter=expanded 2>&1 | grep -cE " \+[0-9]+: "

# Total test files (excludes mocks/fakes/helpers):
find test -name "*_test.dart" | wc -l
```

Then update the three numbers in the header above and the corresponding line
in `README.md` ("Quick Stats" block) so the two docs don't drift.

History:
- 2026-03-25: 1090 tests / 47 files
- 2026-05-28 (batch 1): 1138 tests
- 2026-05-28 (batch 2): 1147 tests
- 2026-05-28 (batch 3): 1336 tests / 64 files (+199 from agents A+B+C)
- 2026-06-05 (batch 4+5 + features): 1383 tests (Blogs+Assistant+iOS firebase)
- 2026-06-05 (unit tests session): 1389 tests / 71 files (+6 home grid, FAB)
- 2026-06-08 (assistant actions + tri-audit): 1407 tests / 72 files (+18 actions, Care Guides restore, SOS-call)
- 2026-06-11 (glass/dark-mode/commerce/calendar/care-team/PDF waves): ~1,557 tests / 86 files (+overflow smoke 37×3, dark_mode, i18n_sync, calendar, care_team, articles, commerce/orders, invoice_pdf + handover services, payment/api/auth suites)
- 2026-06-15 (field rounds 3–6): ~1,771 tests at runtime / 99 files / 1,370 call sites (+fixed-nav shell contract, calendar root tab, manpower pricing/multiplier, product-image/ProductImage, typography histogram, chrome reorder, dose-log timestamps)

---

## Test Coverage by Module

### UTILS & HELPERS (target: 95%+)

| File | Test File | Tests | Status | Critical? |
|------|-----------|-------|--------|-----------|
| `lib/utils/pricing.dart` | `test/utils/pricing_test.dart` | 22 | PASS | YES |
| `lib/utils/vital_classifier.dart` | `test/utils/vital_classification_test.dart` | 26 | PASS | YES |
| `lib/utils/permissions.dart` | `test/utils/permission_test.dart` | 25 | PASS | YES |
| `lib/utils/booking_state_machine.dart` | `test/models/booking_state_machine_test.dart` | 24 | PASS | YES |
| `lib/utils/helpers.dart` | `test/utils/helpers_test.dart` | exists | PASS | NO |
| `lib/utils/notification_router.dart` | `test/utils/notification_router_test.dart` | exists | PASS | YES |
| `assets/i18n/*.json` (EN/HI key sync) | `test/utils/i18n_sync_test.dart` | exists | PASS (guard) | YES |
| `lib/utils/app_localizations.dart` | -- | 0 | MISSING | NO |

### MODELS (target: 80%+)

| File | Test File | Tests | Status | Critical? |
|------|-----------|-------|--------|-----------|
| `lib/models/models.dart` (ServiceItem) | `test/models/service_models_test.dart` | 12 | PASS | YES |
| `lib/models/my_care_models.dart` | `test/models/my_care_models_test.dart` | exists | PASS | YES |
| `lib/models/medication_models.dart` | `test/models/medication_models_test.dart` | exists | PASS | YES |
| `lib/models/models.dart` (Patient) | `test/models/patient_model_test.dart` | exists | PASS | YES |
| `lib/models/models.dart` (Payment) | `test/models/payment_models_test.dart` | exists | PASS | YES |
| `lib/models/models.dart` (EquipmentOrder) | `test/models/equipment_order_test.dart` | exists | PASS | YES |
| `lib/models/models.dart` (CartItem) | `test/models/cart_item_test.dart` | 24 | PASS | YES |
| `lib/models/models.dart` (EquipmentItem) | covered by cart_provider_test | -- | PASS | YES |
| `lib/models/care_event.dart` | `test/models/care_event_test.dart` | exists | PASS | YES |
| `lib/models/article.dart` | `test/models/article_test.dart` | exists | PASS | NO |
| `lib/models/assistant_models.dart` | `test/models/assistant_models_test.dart` | exists | PASS | YES |
| GST per-line rates | `test/models/gst_test.dart` | exists | PASS | YES |
| Lab test model | `test/models/lab_test_model_test.dart` | exists | PASS | NO |

### PROVIDERS (target: 80%+)

| Provider | Test File | Tests | Status | Critical? |
|----------|-----------|-------|--------|-----------|
| `lib/providers/cart_provider.dart` | `test/providers/cart_provider_test.dart` | 48 | PASS | YES |
| `lib/providers/my_care_provider.dart` | `test/providers/my_care_provider_test.dart` | 18 | PASS | YES |
| `lib/providers/medication_provider.dart` | `test/providers/medication_provider_test.dart` | exists | PASS | YES |
| `lib/providers/cart_provider.dart` (persistence) | `test/providers/cart_persistence_test.dart` | exists | PASS | YES |
| `lib/providers/orders_provider.dart` | `test/providers/orders_provider_test.dart` | 20 | PASS | YES |
| `lib/providers/orders_provider.dart` (persistence) | `test/providers/orders_persistence_test.dart` | 11 | PASS | YES |
| `lib/providers/orders_provider.dart` (refunds) | `test/providers/orders_provider_refund_test.dart` | exists | PASS | YES |
| `lib/providers/auth_provider.dart` | `test/providers/auth_provider_test.dart` | 18 | PASS | YES |
| `lib/providers/app_provider.dart` | `test/providers/app_provider_test.dart` | exists | PASS | NO |
| `lib/providers/theme_provider.dart` | `test/providers/theme_provider_test.dart` | 15 | PASS | YES |
| `lib/providers/blog_provider.dart` | `test/providers/blog_provider_test.dart` | exists | PASS | NO |
| `lib/providers/assistant_provider.dart` | `test/providers/assistant_provider_test.dart` | exists | PASS | YES |

### SCREENS / WIDGETS (target: 40%+)

| Screen | Test File | Tests | Status | Critical? |
|--------|-----------|-------|--------|-----------|
| My Care widgets | `test/screens/my_care/my_care_widgets_test.dart` | exists | PASS | NO |
| Service Booking | `test/screens/services/service_booking_test.dart` | exists | PASS | YES |
| Equipment Detail | `test/screens/services/equipment_detail_test.dart` | exists | PASS | NO |
| Service Catalog | `test/screens/services/service_catalog_test.dart` | exists | PASS | NO |
| Assessment Form | `test/screens/services/assessment_form_test.dart` | exists | PASS | YES |
| Cart Screen (logic) | `test/screens/cart/cart_screen_test.dart` | 27 | PASS | YES |
| Cart Coupon | `test/screens/cart/cart_coupon_test.dart` | exists | PASS | YES |
| Address Selection | `test/screens/checkout/address_test.dart` | exists | PASS | NO |
| Booking Confirmation | `test/screens/services/booking_confirmation_test.dart` | exists | PASS | YES |
| Booking History | `test/screens/services/booking_history_test.dart` | exists | PASS | YES |
| Notification Preferences | `test/screens/settings/notification_prefs_test.dart` | exists | PASS | NO |
| Help / FAQ | `test/screens/settings/help_faq_test.dart` | exists | PASS | NO |
| Rental Agreement | `test/screens/rental/rental_agreement_test.dart` | exists | PASS | YES |
| Return | `test/screens/rental/return_test.dart` | exists | PASS | YES |
| EMI | `test/screens/billing/emi_test.dart` | exists | PASS | YES |
| Order Tracking | `test/screens/orders/order_tracking_test.dart` | exists | PASS | YES |
| Referral | `test/screens/settings/referral_test.dart` | exists | PASS | NO |
| Slot Availability | `test/screens/services/slot_availability_test.dart` | exists | PASS | YES |
| Home Screen (layout) | `test/screens/home/home_layout_test.dart` | exists | PASS | NO |
| Billing Screen (logic) | `test/screens/billing/billing_screen_test.dart` | 23 | PASS | YES |
| Care Calendar | `test/screens/calendar/care_calendar_screen_test.dart` | exists | PASS | YES |
| Care Team | `test/screens/care_team/care_team_screen_test.dart` | exists | PASS | YES |
| Article List / Detail | `test/screens/articles/article_list_test.dart`, `article_detail_test.dart` | exists | PASS | NO |
| Assistant (screen + executor) | `test/screens/assistant/assistant_screen_test.dart`, `assistant_executor_test.dart` | exists | PASS | YES |
| Login / OTP | `test/screens/auth/login_screen_test.dart`, `otp_screen_test.dart` | exists | PASS | YES |
| My Care (screen, widgets, meds, doctor advice) | `test/screens/my_care/*` (4 files) | exists | PASS | YES |
| Catalog navigation / equipment tab / sheets / staff role sheet | `test/screens/services/catalog_navigation_test.dart`, `equipment_tab_test.dart`, `equipment_bottom_sheet_test.dart`, `staff_role_sheet_test.dart` | exists | PASS | YES |
| SOS | `test/screens/sos/sos_screen_test.dart` | exists | PASS | YES |
| Settings (add patient, profile) | `test/screens/settings/add_patient_screen_test.dart`, `patient_profile_test.dart` | exists | PASS | NO |
| Overflow smoke (ALL screens) | `test/screens/overflow_smoke_test.dart` | 37 screens × 3 widths | PASS (guard) | YES |

### SERVICES (target: 60%+)

| Service | Test File | Tests | Status | Critical? |
|---------|-----------|-------|--------|-----------|
| `lib/services/api_service.dart` | `test/services/api_service_test.dart` | 50 | PASS | YES |
| `lib/services/firebase_service.dart` | -- | 0 | MISSING | YES |
| `lib/services/payment_service.dart` | `test/services/payment_service_test.dart` | 18 | PASS (8 groups gated on RAZORPAY_KEY dart-define; CI passes dummy key) | YES |
| `lib/services/invoice_pdf_service.dart` | `test/services/invoice_pdf_service_test.dart` | exists | PASS | YES |
| `lib/services/handover_report_service.dart` | `test/services/handover_report_service_test.dart` | exists | PASS | YES |
| `lib/services/assistant_service.dart` | `test/services/assistant_service_test.dart` | exists | PASS | YES |
| `lib/services/payment_reminder_service.dart` | -- | 0 | MISSING | NO |
| `lib/services/sync_service.dart` | -- | 0 | MISSING | YES |
| `lib/services/cache_service.dart` | `test/services/cache_service_test.dart` | exists | PASS | YES |
| `lib/services/video_call_service.dart` | `test/services/video_call_service_test.dart` | exists | PASS | YES |
| `lib/services/medication_reminder_service.dart` | `test/services/medication_reminder_test.dart` | exists | PASS | YES |

### WIDGETS (target: 40%+)

| Widget | Test File | Tests | Status | Critical? |
|--------|-----------|-------|--------|-----------|
| `lib/widgets/paginated_list.dart` | `test/widgets/paginated_list_test.dart` | exists | PASS | YES |
| `lib/widgets/assistant_fab.dart` | `test/widgets/assistant_fab_test.dart` | 4 | PASS | NO |
| Dark-mode token guard (app-wide) | `test/widgets/dark_mode_test.dart` | exists | PASS (guard) | YES |

### INTEGRATION

| Flow | Test File | Status |
|------|-----------|--------|
| Cart end-to-end | `test/integration/cart_flow_test.dart` | PASS |
| Checkout flow | `test/integration/checkout_flow_test.dart` | PASS |
| Assessment → Orders | `test/integration/assessment_to_orders_test.dart` | PASS |
| Billing from Orders | `test/integration/billing_from_orders_test.dart` | PASS |

---

## Existing Test Files (complete inventory — 86 files, 2026-06-11)

| # | File Path | Status |
|---|-----------|--------|
| 1 | `test/integration/assessment_to_orders_test.dart` | PASS |
| 2 | `test/integration/billing_from_orders_test.dart` | PASS |
| 3 | `test/integration/cart_flow_test.dart` | PASS |
| 4 | `test/integration/checkout_flow_test.dart` | PASS |
| 5 | `test/models/article_test.dart` | PASS |
| 6 | `test/models/assistant_models_test.dart` | PASS |
| 7 | `test/models/booking_state_machine_test.dart` | PASS |
| 8 | `test/models/care_event_test.dart` | PASS |
| 9 | `test/models/cart_item_test.dart` | PASS |
| 10 | `test/models/equipment_order_test.dart` | PASS |
| 11 | `test/models/gst_test.dart` | PASS |
| 12 | `test/models/lab_test_model_test.dart` | PASS |
| 13 | `test/models/medication_models_test.dart` | PASS |
| 14 | `test/models/my_care_models_test.dart` | PASS |
| 15 | `test/models/patient_model_test.dart` | PASS |
| 16 | `test/models/payment_models_test.dart` | PASS |
| 17 | `test/models/service_models_test.dart` | PASS |
| 18 | `test/providers/app_provider_test.dart` | PASS |
| 19 | `test/providers/assistant_provider_test.dart` | PASS |
| 20 | `test/providers/auth_provider_test.dart` | PASS |
| 21 | `test/providers/blog_provider_test.dart` | PASS |
| 22 | `test/providers/cart_persistence_test.dart` | PASS |
| 23 | `test/providers/cart_provider_test.dart` | PASS |
| 24 | `test/providers/medication_provider_test.dart` | PASS |
| 25 | `test/providers/my_care_provider_test.dart` | PASS |
| 26 | `test/providers/orders_persistence_test.dart` | PASS |
| 27 | `test/providers/orders_provider_refund_test.dart` | PASS |
| 28 | `test/providers/orders_provider_test.dart` | PASS |
| 29 | `test/providers/theme_provider_test.dart` | PASS |
| 30 | `test/screens/articles/article_detail_test.dart` | PASS |
| 31 | `test/screens/articles/article_list_test.dart` | PASS |
| 32 | `test/screens/assistant/assistant_executor_test.dart` | PASS |
| 33 | `test/screens/assistant/assistant_screen_test.dart` | PASS |
| 34 | `test/screens/auth/login_screen_test.dart` | PASS |
| 35 | `test/screens/auth/otp_screen_test.dart` | PASS |
| 36 | `test/screens/billing/billing_screen_test.dart` | PASS |
| 37 | `test/screens/billing/emi_test.dart` | PASS |
| 38 | `test/screens/calendar/care_calendar_screen_test.dart` | PASS |
| 39 | `test/screens/care_team/care_team_screen_test.dart` | PASS |
| 40 | `test/screens/cart/cart_coupon_test.dart` | PASS |
| 41 | `test/screens/cart/cart_screen_test.dart` | PASS |
| 42 | `test/screens/checkout/address_test.dart` | PASS |
| 43 | `test/screens/home/home_layout_test.dart` | PASS |
| 44 | `test/screens/my_care/doctor_advice_card_test.dart` | PASS |
| 45 | `test/screens/my_care/medications_screen_test.dart` | PASS |
| 46 | `test/screens/my_care/my_care_screen_test.dart` | PASS |
| 47 | `test/screens/my_care/my_care_widgets_test.dart` | PASS |
| 48 | `test/screens/orders/order_tracking_test.dart` | PASS |
| 49 | `test/screens/overflow_smoke_test.dart` | PASS (guard: 37 screens × 3 widths) |
| 50 | `test/screens/rental/rental_agreement_test.dart` | PASS |
| 51 | `test/screens/rental/return_test.dart` | PASS |
| 52 | `test/screens/services/assessment_form_test.dart` | PASS |
| 53 | `test/screens/services/booking_confirmation_test.dart` | PASS |
| 54 | `test/screens/services/booking_history_test.dart` | PASS |
| 55 | `test/screens/services/catalog_navigation_test.dart` | PASS |
| 56 | `test/screens/services/equipment_bottom_sheet_test.dart` | PASS |
| 57 | `test/screens/services/equipment_detail_test.dart` | PASS |
| 58 | `test/screens/services/equipment_tab_test.dart` | PASS |
| 59 | `test/screens/services/service_booking_test.dart` | PASS |
| 60 | `test/screens/services/service_catalog_test.dart` | PASS |
| 61 | `test/screens/services/slot_availability_test.dart` | PASS |
| 62 | `test/screens/services/staff_role_sheet_test.dart` | PASS |
| 63 | `test/screens/settings/add_patient_screen_test.dart` | PASS |
| 64 | `test/screens/settings/help_faq_test.dart` | PASS |
| 65 | `test/screens/settings/notification_prefs_test.dart` | PASS |
| 66 | `test/screens/settings/patient_profile_test.dart` | PASS |
| 67 | `test/screens/settings/referral_test.dart` | PASS |
| 68 | `test/screens/sos/sos_screen_test.dart` | PASS |
| 69 | `test/services/api_service_test.dart` | PASS |
| 70 | `test/services/assistant_service_test.dart` | PASS |
| 71 | `test/services/cache_service_test.dart` | PASS |
| 72 | `test/services/handover_report_service_test.dart` | PASS |
| 73 | `test/services/invoice_pdf_service_test.dart` | PASS |
| 74 | `test/services/medication_reminder_test.dart` | PASS |
| 75 | `test/services/payment_service_test.dart` | PASS (8 groups gated on RAZORPAY_KEY) |
| 76 | `test/services/video_call_service_test.dart` | PASS |
| 77 | `test/utils/helpers_test.dart` | PASS |
| 78 | `test/utils/i18n_sync_test.dart` | PASS (guard: EN/HI key sync) |
| 79 | `test/utils/notification_router_test.dart` | PASS |
| 80 | `test/utils/permission_test.dart` | PASS |
| 81 | `test/utils/pricing_test.dart` | PASS |
| 82 | `test/utils/vital_classification_test.dart` | PASS |
| 83 | `test/utils/vital_ranges_test.dart` | PASS |
| 84 | `test/widgets/assistant_fab_test.dart` | PASS |
| 85 | `test/widgets/dark_mode_test.dart` | PASS (guard: dark-mode tokens) |
| 86 | `test/widgets/paginated_list_test.dart` | PASS |

(Plus helpers that are not test files, e.g. `test/providers/mock_api_service.dart`.)

---

## What's Missing (Priority Order)

### P0 -- Must have before release

All previous P0 gaps are RESOLVED:

| Gap | Test File | Status |
|-----|-----------|--------|
| ~~Auth provider~~ | `test/providers/auth_provider_test.dart` | RESOLVED (18 tests) |
| ~~Payment service~~ | `test/services/payment_service_test.dart` | RESOLVED — exists; 8 groups gated behind RAZORPAY_KEY dart-define, CI passes `rzp_test_ci_dummy_key` |
| ~~API service~~ | `test/services/api_service_test.dart` | RESOLVED (50 tests) |

### P1 -- Should have post-MVP

| Gap | Recommended Test File | What to Test |
|-----|-----------------------|--------------|
| Firebase service | `test/services/firebase_service_test.dart` | Firestore CRUD, offline queue |
| Sync service | `test/services/sync_service_test.dart` | Offline queue, reconnect sync |
| ~~Billing screens~~ | ~~`test/screens/billing/billing_test.dart`~~ | ~~Invoice display, payment methods~~ RESOLVED: billing_screen_test.dart added |
| Video consultation | `test/screens/consultation/video_consultation_test.dart` | Join/leave flow |
| Chat screen | `test/screens/chat/chat_screen_test.dart` | Send/receive messages |

### P2 -- Nice to have

| Gap | Recommended Test File | What to Test |
|-----|-----------------------|--------------|
| App localizations | `test/utils/app_localizations_test.dart` | Hindi string keys exist |
| Settings screens | `test/screens/settings/settings_test.dart` | Profile edit, family management |
| About screen | `test/screens/settings/about_test.dart` | Render, link taps |
| Staff replacement | `test/screens/support/staff_replacement_test.dart` | Reason selection, request flow |

---

## Pre-existing Failures

All previously failing tests (3 in `my_care_widgets_test.dart`) have been fixed. All 1336 tests now pass; 17 are skipped (Firebase-init-dependent scenarios that need an emulator harness — tracked but not blocking).

---

## Coverage Commands

```bash
# Run all tests
flutter test

# Run only new business logic tests
flutter test test/utils/ test/models/booking_state_machine_test.dart test/providers/cart_provider_test.dart

# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 2026-08-03 (audit rounds 1–3)

| File | Guards |
|---|---|
| `test/providers/patient_scope_isolation_test.dart` | The PHI wipe. Every store `SessionScope` clears, plus the `loadPatients` switch path. **Add an assertion here whenever `SessionScope` gains a store.** |
| `test/services/store_migrator_test.dart` | Storage versioning. Includes the migration LOOP itself via `debugSetMigrations` — the failed-step guard, early return and version increment were previously executed by no test and could each be deleted with the suite green. |

**Known test-quality gaps carried from round 3** (not yet closed): `SessionScope`
itself is imported by zero tests despite three call sites; `session_scope.dart`,
`demo_mode.dart`, `demo_data_banner.dart` and `delete_account_screen.dart` have no
tests; ~120 tests assert copies of production data rather than production; 17 payment
tests skip without `--dart-define=RAZORPAY_KEY`.

---

## Round 4 additions (2026-08-20)

Eight files, all written against a specific defect that shipped. Each header
comment names the defect rather than the function, because in every case the
code read correctly and the *behaviour* was wrong.

| File | The defect it exists for |
|------|--------------------------|
| `test/services/money_units_test.dart` | `PaymentScreen.amount` was read as rupees by everything that displayed it and as paise by everything that charged it. Cart showed ₹5,000 and billed ₹50; Billing showed ₹5,00,000 and billed correctly. Pins that exactly one conversion exists, at the gateway boundary. |
| `test/models/equipment_assessment_gate_test.dart` | `needsAssessment` exempted every rentable item, and every ventilator/BiPAP/CPAP/concentrator/suction machine in the catalog is rentable. It gated BiPAP *masks* instead. |
| `test/models/equipment_catalog_gate_test.dart` | The same rule against the **shipped catalog**, not a fixture — the failure was invisible in the abstract and obvious against the data. Also checks every referenced product image still exists after the 235-file delete. |
| `test/services/assistant_clinical_guard_test.dart` | "bleeding ho raha hai" routed to `get_duty_days`, because the unanchored pattern `din` matches "blee-**din**-g". Pins the word boundaries AND the guard that pre-empts routing entirely. |
| `test/screens/staff_profile_no_fabrication_test.dart` | The staff-profile fallback fabricated `police_verified: true`, a rating and four named reviews — on the only code path that runs in a shipped build. |
| `test/services/notification_id_test.dart` | Notification IDs overflowed 32 bits, so two medications could collapse onto one ID and scheduling the second silently replaced the first. |
| `test/utils/vital_classifier_test.dart` | Replaces `vital_ranges_test.dart`, which validated that a threshold map was *self*-consistent while it disagreed with the other classifier. Pins **agreement** between both entry points. |
| `test/widgets/medical_disclaimer_test.dart` | The app carried no medical disclaimer anywhere. Pins placement, both languages, and that it never blocks or touches the SOS path. |

### One thing these tests taught about tests

Three of the eight found bugs in *themselves* before they found anything else:
the payment fake returned `{'order_id': ...}` — mirroring the client's wrong
assumption instead of the backend's actual response, which is precisely why
that bug survived four audit rounds; the schema parser was truncated by a
semicolon inside a SQL comment; and the Dart/TypeScript differ ran past the
end of one function into the next and reported four phantom mismatches.

A fake built from the code under test can only ever confirm that code. Build
it from the contract.

Also worth recording, because it silently weakens widget tests:
`AppLocalizations.delegate.load()` awaits `rootBundle.loadString`, and
`Localizations` renders an **empty widget** until that resolves.
`pumpAndSettle` settles frames and animations, not arbitrary futures — so the
second and later `pumpWidget` calls in a file find an empty tree, and a
`findsNothing` assertion passes for entirely the wrong reason. Use the
`runAsync` + delay pattern from `test/screens/home/home_layout_test.dart`.

---

## Round 5 additions (2026-08-25)

| File | The defect it exists for |
|------|--------------------------|
| `test/screens/bucket_b_regressions_test.dart` | Startup latency, build environments, glass contrast, the vitals per-chart rule, and four surfaces that reported success for actions that never happened. |
| `test/utils/data_lifecycle_test.dart` | `ImagePrivacy` re-encoded every picked photo to a temp file and **never deleted it** — the fix that stripped GPS from a wound photo left a full-resolution copy in the OS temp area indefinitely. Also pins that the deletion notice no longer promises to delete documents the app has never stored. |
| `test/screens/text_scale_and_contrast_test.dart` | The 1.4× text clamp, and `Colors.white70` over the orange gradient at 1.82:1 — the worst text contrast in the app, on the amount someone is about to be charged. Computes the contrast ratios rather than asserting them. |

### Backend (separate repo)

| Suite | What it pins |
|-------|--------------|
| `schema-conformance.test.ts` | Every `db("table")` chain against the migrations. |
| `vital-classifier.test.ts` | The TypeScript thresholds against the **Dart source**, diffed across the range. |
| `route-conformance.test.ts` | Every client API call against every backend route. Found **13 calls with no route**, including the only caregiver-removal control in the app. Its `ACCEPTED_MISSING` set has two guards: the list cannot silently grow, and an entry must be removed once its route exists. |

85 backend tests pass.

### A pattern worth naming

Five of the checks written across rounds 4 and 5 found bugs **in themselves**
before they found anything in the product: a payment fake built from the
caller's imagined field name, a SQL parser truncated by a semicolon inside a
comment, a Dart/TypeScript differ that ran past the end of one function into
the next, a keyword blacklist that deleted two real columns, and a
source-text assertion that failed on the *documentation of the fix it was
testing*.

The common thread: each was built from what the author expected rather than
from the artefact. A fake built from the code under test can only confirm that
code.
