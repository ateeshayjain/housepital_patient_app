# Test Map -- Housepital Patient App

**Last updated:** 2026-03-22
**Total test count:** 529 (133 new + 396 existing)
**Pass rate:** 526/529 (3 pre-existing widget test failures)

---

## Test Coverage by Module

### UTILS & HELPERS (target: 95%+)

| File | Test File | Tests | Status | Critical? |
|------|-----------|-------|--------|-----------|
| `lib/utils/pricing.dart` | `test/utils/pricing_test.dart` | 22 | PASS | YES |
| `lib/utils/vital_classifier.dart` | `test/utils/vital_classification_test.dart` | 26 | PASS | YES |
| `lib/utils/permissions.dart` | `test/utils/permission_test.dart` | 25 | PASS | YES |
| `lib/utils/booking_state_machine.dart` | `test/models/booking_state_machine_test.dart` | 24 | PASS | YES |
| `lib/utils/helpers.dart` | -- | 0 | MISSING | NO |
| `lib/utils/app_localizations.dart` | -- | 0 | MISSING | NO |

### MODELS (target: 80%+)

| File | Test File | Tests | Status | Critical? |
|------|-----------|-------|--------|-----------|
| `lib/models/models.dart` (ServiceItem) | `test/models/service_models_test.dart` | 12 | PASS | YES |
| `lib/models/my_care_models.dart` | `test/models/my_care_models_test.dart` | exists | PASS | YES |
| `lib/models/medication_models.dart` | `test/models/medication_models_test.dart` | exists | PASS | YES |
| `lib/models/models.dart` (Patient) | -- | 0 | MISSING | YES |
| `lib/models/models.dart` (CartItem) | covered by cart_provider_test | -- | PASS | YES |
| `lib/models/models.dart` (EquipmentItem) | covered by cart_provider_test | -- | PASS | YES |

### PROVIDERS (target: 80%+)

| Provider | Test File | Tests | Status | Critical? |
|----------|-----------|-------|--------|-----------|
| `lib/providers/cart_provider.dart` | `test/providers/cart_provider_test.dart` | 36 | PASS | YES |
| `lib/providers/my_care_provider.dart` | `test/providers/my_care_provider_test.dart` | 18 | PASS | YES |
| `lib/providers/medication_provider.dart` | `test/providers/medication_provider_test.dart` | exists | PASS | YES |
| `lib/providers/auth_provider.dart` | -- | 0 | MISSING | YES |
| `lib/providers/app_provider.dart` | -- | 0 | MISSING | NO |

### SCREENS / WIDGETS (target: 40%+)

| Screen | Test File | Tests | Status | Critical? |
|--------|-----------|-------|--------|-----------|
| My Care widgets | `test/screens/my_care/my_care_widgets_test.dart` | exists | 3 FAIL (pre-existing) | NO |
| Service Booking | `test/screens/services/service_booking_test.dart` | exists | PASS | YES |
| Equipment Detail | `test/screens/services/equipment_detail_test.dart` | exists | PASS | NO |
| Service Catalog | `test/screens/services/service_catalog_test.dart` | exists | PASS | NO |
| Cart Screen | -- | 0 | MISSING | YES |
| Home Screen | -- | 0 | MISSING | NO |
| Billing screens | -- | 0 | MISSING | YES |
| Settings screens | -- | 0 | MISSING | NO |

### SERVICES (target: 60%+)

| Service | Test File | Tests | Status | Critical? |
|---------|-----------|-------|--------|-----------|
| `lib/services/api_service.dart` | -- | 0 | MISSING | YES |
| `lib/services/firebase_service.dart` | -- | 0 | MISSING | YES |
| `lib/services/payment_service.dart` | -- | 0 | MISSING | YES |
| `lib/services/payment_reminder_service.dart` | -- | 0 | MISSING | NO |
| `lib/services/sync_service.dart` | -- | 0 | MISSING | YES |

---

## Existing Test Files (complete inventory)

| # | File Path | Status |
|---|-----------|--------|
| 1 | `test/widget_test.dart` | PASS |
| 2 | `test/models/service_models_test.dart` | PASS |
| 3 | `test/models/my_care_models_test.dart` | PASS |
| 4 | `test/models/medication_models_test.dart` | PASS |
| 5 | `test/models/booking_state_machine_test.dart` | PASS (NEW) |
| 6 | `test/providers/my_care_provider_test.dart` | PASS |
| 7 | `test/providers/medication_provider_test.dart` | PASS |
| 8 | `test/providers/cart_provider_test.dart` | PASS (NEW) |
| 9 | `test/providers/mock_api_service.dart` | helper (not a test) |
| 10 | `test/utils/pricing_test.dart` | PASS (NEW) |
| 11 | `test/utils/vital_classification_test.dart` | PASS (NEW) |
| 12 | `test/utils/permission_test.dart` | PASS (NEW) |
| 13 | `test/screens/my_care/my_care_widgets_test.dart` | 3 FAIL (pre-existing) |
| 14 | `test/screens/services/service_booking_test.dart` | PASS |
| 15 | `test/screens/services/equipment_detail_test.dart` | PASS |
| 16 | `test/screens/services/service_catalog_test.dart` | PASS |

---

## What's Missing (Priority Order)

### P0 -- Must have before release

| Gap | Recommended Test File | What to Test |
|-----|-----------------------|--------------|
| Auth provider | `test/providers/auth_provider_test.dart` | OTP login, session management, token refresh |
| Payment service | `test/services/payment_service_test.dart` | Razorpay integration, amount calculations |
| Patient model serialization | `test/models/patient_model_test.dart` | fromJson/toJson round-trip |
| API service | `test/services/api_service_test.dart` | Error handling, retry logic |

### P1 -- Should have post-MVP

| Gap | Recommended Test File | What to Test |
|-----|-----------------------|--------------|
| Firebase service | `test/services/firebase_service_test.dart` | Firestore CRUD, offline queue |
| Sync service | `test/services/sync_service_test.dart` | Offline queue, reconnect sync |
| Cart screen widget | `test/screens/cart/cart_screen_test.dart` | Render, quantity controls |
| Billing screens | `test/screens/billing/billing_test.dart` | Invoice display, payment methods |

### P2 -- Nice to have

| Gap | Recommended Test File | What to Test |
|-----|-----------------------|--------------|
| App localizations | `test/utils/app_localizations_test.dart` | Hindi string keys exist |
| Helpers (formatting) | `test/utils/helpers_test.dart` | Currency, date, time formatting |
| Settings screens | `test/screens/settings/settings_test.dart` | Profile edit, family management |

---

## Pre-existing Failures to Fix

The 3 failing tests in `test/screens/my_care/my_care_widgets_test.dart` are pre-existing widget test failures unrelated to the new test files. These should be triaged and fixed separately.

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
