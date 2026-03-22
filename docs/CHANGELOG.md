# Housepital Patient App -- Changelog

**Format:** `## [Date] -- [Summary]` with bullet points for each change.

---

## [2026-03-22] -- My Care Tab, Medications, Test Infrastructure, Documentation Framework

### Features Built
- **My Care Tab (full implementation):** Active services hub with 7 section widgets -- HealthManagerBanner, ActiveServiceCard, QuickActionsRow, VitalsTrendGrid, StaffAttendanceSection, CareReportSection, BillingSummarySection, EquipmentDeployedSection
- **Service Detail Screen:** Deep-dive into individual active services -- staff on duty, vitals summary, today's report, equipment deployed
- **Attendance History Screen:** Paginated attendance records per deployment
- **Report History Screen:** Paginated daily report list per deployment
- **Medications Module (full CRUD):**
  - MedicationsScreen -- list all active medications with stock indicators
  - MedicationScheduleScreen -- today's administration schedule with timeline
  - AddEditMedicationScreen -- create/update medication with form validation
  - MedicationProvider -- state management for medication CRUD + logs + stock
  - Backend endpoints: GET/POST/PUT/DELETE medications, GET logs, PUT stock
- **MyCareProvider:** State management for active services list and service detail
- **Backend medications routes:** Full REST API for medication management

### Test Infrastructure
- Added 133 new tests (total 529, pass rate 526/529)
- `test/utils/pricing_test.dart` -- 22 tests for pricing calculations
- `test/utils/vital_classification_test.dart` -- 26 tests for vitals GREEN/YELLOW/RED thresholds
- `test/utils/permission_test.dart` -- 25 tests for role-based permissions
- `test/models/booking_state_machine_test.dart` -- 24 tests for booking state transitions
- `test/providers/cart_provider_test.dart` -- 36 tests for cart operations
- `test/providers/my_care_provider_test.dart` -- 18 tests for active services provider
- Created TEST_MAP.md and TEST_STRATEGY.md

### Documentation
- Created Layer 1 docs: ARCHITECTURE.md, DATABASE_SCHEMA.md, API_REFERENCE.md, SCREEN_MAP.md, BUSINESS_RULES.md
- Created services-tab.md and my-care-tab.md feature documentation

### Files Changed
- `lib/screens/my_care/` -- 6 new screen files + widgets/ directory (8 widgets)
- `lib/models/my_care_models.dart` -- ActiveService, HealthManager, ServiceDetail models
- `lib/models/medication_models.dart` -- MedicationFull, MedicationLog models
- `lib/providers/my_care_provider.dart` -- NEW
- `lib/providers/medication_provider.dart` -- NEW
- `lib/services/api_service.dart` -- MODIFIED (added medications, active-services, service-detail, health-manager endpoints)
- `lib/main.dart` -- MODIFIED (added MyCareProvider, MedicationProvider, new routes)
- `lib/screens/main_shell.dart` -- MODIFIED (My Care tab added to bottom nav)
- Backend: `functions/src/routes/medications.ts` -- NEW
- Backend: `functions/src/routes/patients.ts` -- MODIFIED (active-services, health-manager endpoints)
- Backend: `functions/src/routes/deployments.ts` -- MODIFIED (service-detail endpoint)
- 7 new test files added under `test/`

### Database Changes
- No new migrations -- uses existing schema tables (deployments, staff, attendance, vitals, daily_reports, medications, medication_logs)

### Breaking Changes
- None

---

## [2026-03-21] -- Services Tab, Cart, Billing, Booking Wizard, Equipment Catalog

### Features Built
- **Service Catalog Screen:** 7 sub-tabs (Manpower, Equipment, Consultations, Visits, Diagnostics, Lab Tests, Packages) with TabController
- **Service Booking Screen (3-step wizard):** Slot selection, promo code application, order review with Razorpay checkout
- **Assessment Request Screen:** Dynamic questionnaire for caretaker/nursing/japa/nanny/ICU services
- **Equipment Detail Screen:** Product detail page with variant selection, rent/buy options, add-to-cart
- **Package Detail Screen:** Care package overview with included benefits
- **Cart System:** CartProvider with add/remove/quantity controls, saved-for-later, subtotal + GST calculation
- **Cart Screen:** Full cart UI with quantity controls, promo code input, checkout flow
- **Billing Module:**
  - BillingScreen -- billing summary dashboard with outstanding/paid/overdue amounts
  - InvoiceDetailScreen -- individual invoice with line items, PDF download stub
  - TransactionLogScreen -- payment transaction history with status badges
  - PaymentScreen -- Razorpay checkout wrapper with order creation and verification
  - PaymentMethodsScreen -- saved payment methods (static/placeholder)
- **Payment Service:** Full Razorpay integration with backend order creation and signature verification
- **Universal Search Screen:** Search across services, staff, and content
- **Coupon System:** Backend validation endpoint + frontend promo code input in booking wizard
- **Booking State Machine:** Valid state transitions for booking lifecycle
- **Pricing Utilities:** GST calculation, discount application, currency formatting (paise to rupees)
- **Vital Classifier:** GREEN/YELLOW/RED classification based on clinical thresholds
- **Permission Utilities:** Role-based action gating (PRIMARY_CONTACT, FAMILY_MEMBER, PATIENT_SELF)

### Backend
- `functions/src/routes/bookings.ts` -- POST /bookings, GET /patients/:id/bookings
- `functions/src/routes/assessments.ts` -- POST /assessments, GET /patients/:id/assessments
- `functions/src/routes/billing.ts` -- billing summary, invoices, transactions
- `functions/src/routes/payments.ts` -- create-order, verify, webhook
- `functions/src/routes/equipment.ts` -- equipment catalog
- `functions/src/routes/coupons.ts` -- validate, list
- `functions/src/routes/services.ts` -- service catalog
- Seed data: 002_seed_services.sql, 003_seed_equipment.sql, 004_seed_coupons.sql

### Files Changed
- `lib/screens/services/` -- 4 new screens
- `lib/screens/billing/` -- 5 new screens
- `lib/screens/cart/cart_screen.dart` -- NEW
- `lib/screens/packages/package_detail_screen.dart` -- NEW
- `lib/screens/search/universal_search_screen.dart` -- NEW
- `lib/providers/cart_provider.dart` -- NEW
- `lib/services/payment_service.dart` -- NEW
- `lib/utils/booking_state_machine.dart` -- NEW
- `lib/utils/pricing.dart` -- NEW
- `lib/utils/vital_classifier.dart` -- NEW
- `lib/utils/permissions.dart` -- NEW
- `lib/data/care_packages.dart` -- NEW (static care package definitions)
- `lib/models/models.dart` -- MODIFIED (added ServiceItem, EquipmentItem, CartItem, Invoice, etc.)
- `lib/config/constants.dart` -- MODIFIED (added service categories, vital ranges, SLAs)
- `assets/equipment_catalog.json` -- NEW (equipment data)

### Database Changes
- Migration 001_initial_schema.sql -- 21 MySQL tables created
- Seed files: services, equipment, coupons

### Breaking Changes
- None (initial build)

---

## [2026-03-20] -- Core App Shell, Auth, Dashboard, Reports, Support, Settings

### Features Built
- **App Shell:** MainShell with 5-tab bottom navigation (Home, My Care, Services, Billing, More) using IndexedStack
- **Authentication:**
  - LoginScreen -- phone number input with country code
  - OtpScreen -- 6-digit OTP verification with pin_code_fields
  - OnboardingScreen -- new user registration (patient + family member details)
  - AuthProvider -- Firebase Auth phone OTP flow, session management, state machine
- **Dashboard (HomeScreen):** Attendance card, vitals snapshot (color-coded), daily report progress, billing due amount, active services count, quick actions
- **Reports:**
  - DailyReportScreen -- section-by-section report view with task completion, photos, medications
  - VitalsScreen -- vital sign charts with 7d/30d/90d period selector, color-coded readings
- **Support:**
  - RaiseConcernScreen -- concern form with category, urgency, evidence photo upload
  - StaffProfileScreen -- public staff profile with verification badges, reviews
- **SOS Screen:** Emergency call (ambulance + 112) with large call buttons
- **Notifications Screen:** Paginated notification list with read/unread status, mark-all-read
- **Settings:**
  - SettingsScreen -- settings hub with profile, family, documents, support links
  - PatientProfileScreen -- view/edit patient details (PRIMARY_CONTACT only for edit)
  - FamilyMembersScreen -- manage family members (add, edit, remove)
- **Document Repository:** Document listing (placeholder for future upload)
- **Localization:** Custom AppLocalizations with EN + HI support
- **Theme System:** HousepitalColors, HousepitalTheme (Material 3, Archivo font, WCAG AA compliant)
- **API Service:** Centralized HTTP client with auth token injection, error handling
- **Firebase Service:** Firestore listeners for real-time data
- **Sync Service:** Dashboard data synchronization
- **Payment Reminder Service:** Local notification reminders for payment dues

### Backend
- Express.js app with TypeScript deployed as Firebase Cloud Function
- Firebase Admin SDK init, Cloud SQL (Knex) connection pool, Razorpay SDK init
- Auth middleware: verifyAuth, verifyPatientAccess, requirePrimary
- Routes: auth, patients, deployments, staff, reports, family, concerns, ratings, notifications
- Firestore security rules for 5 collections
- Cloud SQL schema: 21 tables with indexes and foreign keys

### Files Changed
- Full initial codebase -- all files in lib/, functions/src/, sql/, assets/
- pubspec.yaml with 20+ dependencies
- firebase.json, .firebaserc, firestore.rules, firestore.indexes.json

### Database Changes
- Initial schema: 001_initial_schema.sql (21 tables)

### Breaking Changes
- N/A (initial release)

---

## Build History Notes

- Git history was unavailable at doc generation time. This changelog was reconstructed from file modification timestamps, existing documentation, and codebase analysis.
- Future entries should be updated from `git log --oneline` output at the start of each session.
