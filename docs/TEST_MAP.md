# Test Map -- Housepital Patient App

**Last updated:** 2026-06-11
**Total test count:** ~1,557 at runtime (1,226 `test()`/`testWidgets()` call sites; parameterized guard suites — e.g. overflow smoke 37 screens × 3 widths — expand at runtime)
**Pass rate:** all passing (payment groups require `--dart-define=RAZORPAY_KEY=...`; CI passes `rzp_test_ci_dummy_key`)
**Test file count:** 86 (`find test -name "*_test.dart" | wc -l`)

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
