# Test Strategy -- Housepital Patient App

## Testing Stack

```
Flutter/Dart app
├── Unit Tests:         flutter_test (built into Flutter SDK)
├── Widget Tests:       flutter_test (widget testing with WidgetTester)
├── Provider Tests:     flutter_test (Provider/ChangeNotifier testing)
├── Integration Tests:  integration_test package (runs on real devices/emulators)
├── E2E Tests:          Patrol (native-aware end-to-end testing)
├── Security Tests:     Firestore Security Rules unit tests (Firebase Emulator Suite)
├── Payment Tests:      Razorpay test mode + webhook simulation
└── Coverage:           flutter test --coverage (target: 80%+ business logic, 60%+ overall)
```

---

## What to Test vs What to Skip

### MUST TEST (business logic, data integrity, security)

| Category | Examples | Priority |
|----------|----------|----------|
| Business rules | Pricing calculations, refund logic, commission splits | P0 |
| Permission checks | PRIMARY_CONTACT vs FAMILY_MEMBER vs PATIENT_SELF | P0 |
| State machines | Booking status transitions, concern status transitions | P0 |
| Vitals classification | GREEN/YELLOW/RED alert thresholds | P0 |
| Payment flows | Amount calculations, webhook handling, refund processing | P0 |
| Data validation | Phone numbers, vital sign ranges, date boundaries | P0 |
| Cart operations | Add/remove/quantity, subtotal, delivery charge logic | P1 |

### SHOULD TEST (important but lower risk)

| Category | Examples | Priority |
|----------|----------|----------|
| Screen rendering | Components render without crashing | P2 |
| Navigation | Correct screen loads for each route | P2 |
| i18n | Hindi strings render correctly (no missing keys) | P2 |
| Form validation | Required fields, input formats | P2 |
| API response handling | Loading, success, error, empty states | P2 |
| Date/time formatting | DD/MM/YYYY, 12hr with AM/PM, IST timezone | P2 |

### SKIP / TEST MANUALLY

- Visual pixel-perfect layout (use Widgetbook or manual review)
- Third-party SDK internals (Razorpay SDK, Firebase client, platform plugins)
- Deep native behavior (camera, GPS, biometrics -- test on real devices)
- Performance benchmarks (profile manually on budget Android device)

---

## Test File Naming Convention

All test files use Flutter standard: `*_test.dart`

```
test/
├── utils/
│   ├── pricing_test.dart
│   ├── vital_classification_test.dart
│   └── permission_test.dart
├── models/
│   ├── service_models_test.dart
│   ├── my_care_models_test.dart
│   ├── medication_models_test.dart
│   └── booking_state_machine_test.dart
├── providers/
│   ├── my_care_provider_test.dart
│   ├── medication_provider_test.dart
│   ├── cart_provider_test.dart
│   └── mock_api_service.dart
├── screens/
│   ├── my_care/
│   │   └── my_care_widgets_test.dart
│   └── services/
│       ├── service_booking_test.dart
│       ├── equipment_detail_test.dart
│       └── service_catalog_test.dart
└── widget_test.dart
```

**Pattern:** `[what_is_being_tested]_test.dart`

Examples:
- `pricing_test.dart` -- tests for commission, GST, refund calculations
- `vital_classification_test.dart` -- tests for vital sign alert classification
- `booking_state_machine_test.dart` -- tests for booking status transitions

---

## When to Write Tests

### Agent MUST write tests for:

- Any new utility function (pure logic) --> unit test
- Any new Provider/ChangeNotifier --> provider test
- Any business rule implementation --> unit test with edge cases and boundaries
- Any state machine (status transitions) --> unit test for every valid + invalid transition
- Any payment-related code --> unit + integration test
- Any permission/role check --> unit test for all roles x all actions

### Tests optional for:

- New UI screen --> widget test (optional for MVP, required post-MVP)
- Style/layout changes --> skip automated tests

### Test structure per test file:

1. **Fixture helpers** at the top (factory functions for test data)
2. **`setUp()`** to initialize fresh instances before each test
3. **`group()`** blocks to organize tests by feature/scenario
4. **Descriptive test names** that read as sentences
5. **Edge cases**: boundary values, null inputs, empty states, error conditions

---

## Running Tests

```bash
# Run all tests
flutter test

# Run only business logic tests (fastest feedback)
flutter test test/utils/

# Run specific test file
flutter test test/utils/pricing_test.dart

# Run with coverage report
flutter test --coverage

# Run E2E (requires emulator/device)
flutter test integration_test/
```

---

## Coverage Targets

| Module | Target | Rationale |
|--------|--------|-----------|
| `lib/utils/` | 95%+ | Pure business logic, no excuses |
| `lib/providers/` | 80%+ | State management, critical paths |
| `lib/models/` | 80%+ | Data integrity, serialization |
| `lib/screens/` | 40%+ | Widget tests are slower to write and maintain |
| `lib/services/` | 60%+ | API/Firebase calls, mock-heavy |
| **Overall** | **60%+** | MVP baseline |

---

## Key Business Rules Encoded in Tests

1. **Manpower prices ARE shown and directly bookable** -- caretaker, nurse, physio, from the official Delhi NCR rate card. Prices were hidden Mar-Jun 2026 on a stale premise; the owner reversed that on 2026-06-11. This line said the opposite until 2026-08-20, under a heading claiming to describe what the tests encode -- it did not, and a reader trusting it would have "fixed" the code back to the retired rule.
2. **Vital sign boundaries go to the MORE SEVERE category** (e.g., BP 140 is RED, not yellow). There is exactly ONE classifier, `lib/utils/vital_classifier.dart`; the second threshold table in `AppConstants.vitalRanges` disagreed with it and has been removed.
3. **FAMILY_MEMBER can book but cannot pay** -- PRIMARY_CONTACT can do both.
4. **Booking status transitions are strictly enforced** -- no skipping steps, no going backwards.
5. **Equipment gets 30% discount for 3-month plan customers.**
6. **GST is 18% on service price.**
7. **Delivery is free above ₹999.**
8. **Minimum non-refundable amount is ₹500.**
