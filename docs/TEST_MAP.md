# Test Map -- Housepital Patient App

**Last updated:** 2026-03-24
**Total test count:** 973
**Pass rate:** 973/973 (all passing)

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
| `lib/models/models.dart` (CartItem) | covered by cart_provider_test | -- | PASS | YES |
| `lib/models/models.dart` (EquipmentItem) | covered by cart_provider_test | -- | PASS | YES |

### PROVIDERS (target: 80%+)

| Provider | Test File | Tests | Status | Critical? |
|----------|-----------|-------|--------|-----------|
| `lib/providers/cart_provider.dart` | `test/providers/cart_provider_test.dart` | 36 | PASS | YES |
| `lib/providers/my_care_provider.dart` | `test/providers/my_care_provider_test.dart` | 18 | PASS | YES |
| `lib/providers/medication_provider.dart` | `test/providers/medication_provider_test.dart` | exists | PASS | YES |
| `lib/providers/cart_provider.dart` (persistence) | `test/providers/cart_persistence_test.dart` | exists | PASS | YES |
| `lib/providers/auth_provider.dart` | -- | 0 | MISSING | YES |
| `lib/providers/app_provider.dart` | `test/providers/app_provider_test.dart` | exists | PASS | NO |

### SCREENS / WIDGETS (target: 40%+)

| Screen | Test File | Tests | Status | Critical? |
|--------|-----------|-------|--------|-----------|
| My Care widgets | `test/screens/my_care/my_care_widgets_test.dart` | exists | PASS | NO |
| Service Booking | `test/screens/services/service_booking_test.dart` | exists | PASS | YES |
| Equipment Detail | `test/screens/services/equipment_detail_test.dart` | exists | PASS | NO |
| Service Catalog | `test/screens/services/service_catalog_test.dart` | exists | PASS | NO |
| Assessment Form | `test/screens/services/assessment_form_test.dart` | exists | PASS | YES |
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
| Home Screen | -- | 0 | MISSING | NO |
| Billing screens | -- | 0 | MISSING | YES |
| Settings screens | -- | 0 | MISSING | NO |
| About | -- | 0 | MISSING | NO |

### SERVICES (target: 60%+)

| Service | Test File | Tests | Status | Critical? |
|---------|-----------|-------|--------|-----------|
| `lib/services/api_service.dart` | -- | 0 | MISSING | YES |
| `lib/services/firebase_service.dart` | -- | 0 | MISSING | YES |
| `lib/services/payment_service.dart` | -- | 0 | MISSING | YES |
| `lib/services/payment_reminder_service.dart` | -- | 0 | MISSING | NO |
| `lib/services/sync_service.dart` | -- | 0 | MISSING | YES |
| `lib/services/cache_service.dart` | `test/services/cache_service_test.dart` | exists | PASS | YES |
| `lib/services/video_call_service.dart` | `test/services/video_call_service_test.dart` | exists | PASS | YES |
| `lib/services/medication_reminder_service.dart` | `test/services/medication_reminder_test.dart` | exists | PASS | YES |

### WIDGETS (target: 40%+)

| Widget | Test File | Tests | Status | Critical? |
|--------|-----------|-------|--------|-----------|
| `lib/widgets/paginated_list.dart` | `test/widgets/paginated_list_test.dart` | exists | PASS | YES |

---

## Existing Test Files (complete inventory)

| # | File Path | Status |
|---|-----------|--------|
| 1 | `test/widget_test.dart` | PASS |
| 2 | `test/models/service_models_test.dart` | PASS |
| 3 | `test/models/my_care_models_test.dart` | PASS |
| 4 | `test/models/medication_models_test.dart` | PASS |
| 5 | `test/models/booking_state_machine_test.dart` | PASS |
| 6 | `test/models/patient_model_test.dart` | PASS |
| 7 | `test/models/payment_models_test.dart` | PASS |
| 8 | `test/models/equipment_order_test.dart` | PASS |
| 9 | `test/providers/my_care_provider_test.dart` | PASS |
| 10 | `test/providers/medication_provider_test.dart` | PASS |
| 11 | `test/providers/cart_provider_test.dart` | PASS |
| 12 | `test/providers/cart_persistence_test.dart` | PASS |
| 13 | `test/providers/app_provider_test.dart` | PASS |
| 14 | `test/providers/mock_api_service.dart` | helper (not a test) |
| 15 | `test/utils/pricing_test.dart` | PASS |
| 16 | `test/utils/vital_classification_test.dart` | PASS |
| 17 | `test/utils/vital_ranges_test.dart` | PASS |
| 18 | `test/utils/permission_test.dart` | PASS |
| 19 | `test/utils/helpers_test.dart` | PASS |
| 20 | `test/utils/notification_router_test.dart` | PASS |
| 21 | `test/screens/my_care/my_care_widgets_test.dart` | PASS |
| 22 | `test/screens/services/service_booking_test.dart` | PASS |
| 23 | `test/screens/services/equipment_detail_test.dart` | PASS |
| 24 | `test/screens/services/service_catalog_test.dart` | PASS |
| 25 | `test/screens/services/assessment_form_test.dart` | PASS |
| 26 | `test/screens/services/booking_confirmation_test.dart` | PASS |
| 27 | `test/screens/services/booking_history_test.dart` | PASS |
| 28 | `test/screens/services/slot_availability_test.dart` | PASS |
| 29 | `test/screens/cart/cart_coupon_test.dart` | PASS |
| 30 | `test/screens/checkout/address_test.dart` | PASS |
| 31 | `test/screens/settings/help_faq_test.dart` | PASS |
| 32 | `test/screens/settings/notification_prefs_test.dart` | PASS |
| 33 | `test/screens/settings/referral_test.dart` | PASS |
| 34 | `test/screens/rental/rental_agreement_test.dart` | PASS |
| 35 | `test/screens/rental/return_test.dart` | PASS |
| 36 | `test/screens/billing/emi_test.dart` | PASS |
| 37 | `test/screens/orders/order_tracking_test.dart` | PASS |
| 38 | `test/services/cache_service_test.dart` | PASS |
| 39 | `test/services/video_call_service_test.dart` | PASS |
| 40 | `test/services/medication_reminder_test.dart` | PASS |
| 41 | `test/widgets/paginated_list_test.dart` | PASS |

---

## What's Missing (Priority Order)

### P0 -- Must have before release

| Gap | Recommended Test File | What to Test |
|-----|-----------------------|--------------|
| Auth provider | `test/providers/auth_provider_test.dart` | OTP login, session management, token refresh |
| Payment service | `test/services/payment_service_test.dart` | Razorpay integration, amount calculations |
| API service | `test/services/api_service_test.dart` | Error handling, retry logic |

### P1 -- Should have post-MVP

| Gap | Recommended Test File | What to Test |
|-----|-----------------------|--------------|
| Firebase service | `test/services/firebase_service_test.dart` | Firestore CRUD, offline queue |
| Sync service | `test/services/sync_service_test.dart` | Offline queue, reconnect sync |
| Billing screens | `test/screens/billing/billing_test.dart` | Invoice display, payment methods |
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

All previously failing tests (3 in `my_care_widgets_test.dart`) have been fixed. All 973 tests now pass.

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
