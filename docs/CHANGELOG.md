# Housepital Patient App -- Changelog

**Format:** `## [Date] -- [Summary]` with bullet points for each change.

---

## [2026-05-28 (Audit Batch 3)] -- 4bcaadb -- +199 Tests, Dead Code Sweep, 3 Audits, Prod Fixes

Builds on batches 1 and 2. 1336 passing tests, 17 skipped, 0 failing
(+199 over batch 2). Analyzer 0 errors, 198 issues (-86 from dead code sweep).
Clean web release build with tree-shake-icons.

### Test coverage (+199 tests)
- `payment_service_test.dart` (18) — init, openCheckout, verification outcomes, demo mode
- `api_service_test.dart` (50) — Bearer token, status codes, all 13 endpoint groups
- `auth_provider_test.dart` (18) — cold-start restore, OTP send/verify, logout
- `theme_provider_test.dart` (15) — empty prefs, garbage values, last-write-wins
- `otp_screen_test.dart` (8) — countdown, 5-min expiry lock, resend cooldown
- `login_screen_test.dart` (19) — 11-case Indian-mobile validator, T&C consent
- `gst_test.dart` — per-line GST 0%/5%/18%
- `orders_provider_refund_test.dart` — cancelOrder refund computation
- `daimaa_landing_screen_test.dart` — cards + Dai Maa colors
- `assessment_request_daimaa_test.dart` — Japa/Nanny branded form
- `add_patient_screen_test.dart` — form validation + chip multi-select
- `sos_screen_test.dart` — address card, copy clipboard, tel: launches
- Extended `permission_test.dart` with CARETAKER role + unknown-role default

### Minimal lib changes for testability
- `ApiService` constructor now accepts optional `http.Client` (DI)
- `FirebaseService.verifyOtp` return type Future<UserCredential> → Future<void>
  (caller discarded credential — enables faking)

### Dead code sweep (~1,199 lines removed)
- Methods/getters: `_buildVitalsHighlights`, `_buildDailyReportSection`,
  `_buildPaymentBanner`, `_showAllReminders`, `_loadPaymentReminders`,
  `_isManpower`, `_navigateToEquipmentDetail`, `_sectionTaskCount`, `_detailRow`
- Fields: `_autoPayEnabled`, `_onDutySince`, `_paymentReminders`, `_loaded`,
  `_addressesLoaded`, `_preferredStaffId`, `_initialized`
- Classes: `_ActiveServiceCard`, `_VitalPill`, `_ProgressRingPainter`,
  `_TherapyTab`, `_TherapyCard`
- Static lists: `_equipmentServices` (~280 lines)
- 11 unused imports across 6 files
- 12 `activeColor` → `activeThumbColor` (Material API churn)
- 39 `DropdownButtonFormField value:` → `initialValue:` (Material API churn)

### Audits (read-only)
- **Apple Design Framework**: 12 pass / 9 partial / 0 fail
- **Testing & Code Quality**: 3 CRITICAL findings (firestore.rules expired,
  raw exceptions leaked, Firebase keys unrestricted)
- **Documentation**: 3 missing meta files

### Critical audit fixes in batch
- `otp_screen.dart` — timer leak: dispose() called controller dispose first,
  which threw on pin_code_fields v8 autoDispose, preventing timer.cancel().
  Result: 2 periodic timers leaked on every back-nav. Fixed by cancelling
  timers before controller dispose, wrapped in try/catch.
- `return_screen.dart:357` — replaced raw exception text leak with friendly
  message; raw error via debugPrint internally.
- `staff_replacement_screen.dart:222` — same fix + coordinator phone fallback.

### New meta documentation
- NEW `PROJECT.md` (root) — project meta, secrets map, doc map, roadmap
- NEW `CONTRIBUTING.md` — branching, commit style, PR requirements, agent file-ownership
- NEW `LICENSE` — proprietary with full Housepital Pvt Ltd legal name + CIN
- `README.md` — Quick Links block, CI badge, full `--dart-define=RAZORPAY_KEY=` setup
- `.gitignore` — added `.env*`, `google-services.json`, `GoogleService-Info.plist`
- `docs/KNOWN_ISSUES.md` — updated BUG-01 status, added CI-01/02/03

### GitHub repo state
- Added topics: flutter, healthcare, india, home-healthcare, firebase, dart, provider

---

## [2026-05-28 (Audit Batch 2)] -- 946df8d -- Dark Theme, 20 Medium Fixes, CI Hardening

Builds on batch 1. Adds full dark theme, fixes 20 medium-priority issues from
the post-batch-1 re-audit, plus CI hardening and tree-shake-icons re-enabled
(1.6MB bundle reduction). 1147/1147 tests pass; release web build clean.

### Dark theme
- NEW `lib/providers/theme_provider.dart` — ChangeNotifier persisting ThemeMode
  to SharedPreferences (system/light/dark)
- `lib/config/theme.dart` — NEW `HousepitalColorsDark` with WCAG-AA tokens
  (surface #1A1A1A textPrimary #F2F2F2 → 14.9:1 AAA; onOrange → 6.32:1) +
  new `HousepitalTheme.darkTheme` factory mirroring lightTheme
- `lib/config/daimaa_theme.dart` — NEW `DaiMaaColorsDark` + 4 theme-aware
  helpers; cream backgrounds adapt to dark plum-tinted surface #2A1F2A
- `main.dart` — ThemeProvider registered; MaterialApp reads provider.mode
- `settings_screen.dart` — Appearance tile opens 3-option RadioListTile sheet

### Critical regressions batch 1 missed
- M-1 manpower prices: catalog (3 card types) + booking screen hide price for
  category == 'manpower'; `basePriceMin` REMOVED from all 14 manpower seeds
  (nurse, caretaker, japa, nanny — per persistent memory rule, never show
  manpower prices)
- M-2 booking number regen: `BookingConfirmationScreen` accepts bookingNumber
  param; main.dart was silently dropping it before
- M-3 cart static call: replaced with `context.read<OrdersProvider>()`
  `.generateUniqueBookingNumber()`
- M-8 `OrderTrackingScreen`: `substring(0,8)` guarded for IDs <8 chars
- M-20 chat initials: split now filters empty tokens, returns 'HP' fallback

### Scenario + journey fixes
- M-4 SOS: 4th tile "Book Housepital Ambulance" + visible patient address card
  with Copy button
- M-5 CARETAKER persona: new permissions matrix `{view, raise_concern}` + 9
  new permission tests
- M-6 OTP expiry: parallel 5-min countdown, disables PIN field on expiry
- M-7 login: Indian mobile regex `^[6-9]\d{9}$` + required T&C consent checkbox
- M-10 rental return: refund estimate card with pro-rata + security deposit −
  damage fee
- M-11 assessment cancel/edit: new TextButtons on submitted/in_review cards
- M-12 refund tracking: `cancelOrder` records refundAmount + refundStatus +
  refundEta (₹100 fee within 24h, 50% after)

### Billing + UX consistency
- M-13 destructive consistency: 4 hand-rolled AlertDialogs → `confirmDestructiveAction`
- M-14 per-item GST: replaced hardcoded 18% with computed `CartItem.gstRate`
  getter (0% service/manpower, 5% lab, 18% equipment)
- M-15 stop faking cards: 'Add Card' dialog → 'Set up auto-pay' bottom sheet
  pointing to coordinator (tel:9050200183); no fake HDFC •••• 4521
- M-16 documents: 'Open' launches via url_launcher externalApplication; 'Upload
  PDF' hidden on web, mobile points users to wecare@ email
- M-17 cart debug noise removed

### File handling
- M-9 Firebase Storage uploads: new `firebase_service.uploadFile()`; chat +
  raise_concern now upload to FBS and write download URLs (not local
  /storage/emulated paths). Concurrency cap 3. Web guard via kIsWeb.
- M-18 banner slides.length: replaced hardcoded `% 3` with stored `_slideCount`
- M-19 `withOpacity` → `withValues`: 5 holdouts migrated

### Build tooling + CI hardening
- `.github/workflows/ci.yml` — Flutter pinned to 3.41.2 (was 3.24.0); added
  Analyze step (`--no-fatal-warnings --no-fatal-infos`); Test step uses
  `--reporter=expanded`; on failure uploads build/web + coverage (7d retention)
- Tree-shake-icons re-enabled — earlier failure was transient build cache from
  concurrent agent writes, not an SDK bug (documented as CI-01)

### Dependencies added
- `firebase_storage: ^12.4.0`
- `path: ^1.9.0` (explicit declaration)

---

## [2026-05-28 (Audit Batch 1)] -- b7129af -- Blockers, Brand, Permissions, Dai Maa, A11y

Resolves 14 of 31 issues from the multi-dimensional audit (functionality, HIG,
accessibility, usability, use cases, scenarios, journeys, brand). 1138/1138
tests pass; web release build clean.

### Critical functionality
- `payment_service`: `_handleSuccess` now awaits verification and branches via
  `_VerificationOutcome` enum; failed verification calls `onFailure` (was
  silently calling `onSuccess`); demo mode keeps its own explicit branch
- `app_provider`: `results[4]` cast nullable with safe fallback; defensive
  num/DateTime parsing in `_seedDemoDataIfEmpty` and `updateFromSync`
- `main.dart`: 15 unsafe `as` casts on `settings.arguments` → `is!` guards that
  route to friendly error screen (was crashing My Care / Home tabs)
- `billing → order-tracking` nav: pass `{bookingId, orderType}` not raw map
- `service_booking`: promo Apply button wired to `_applyPromo` (WELCOME10);
  Remove button + disabled state after apply
- `sos_screen`: `_makeCall` wraps launch in try/catch; on failure shows dialog
  with Copy Number + Close
- `orders_provider`: booking number uses last 7 digits of epoch ms +
  `generateUniqueBookingNumber()` collision check
- `sync_service`: bool guard → `Completer<void>?` — concurrent callers share
  the in-flight future

### Brand compliance
- `constants`: API domain housepital.com → housepital.in (BLOCKER)
- `about_screen`: legal name → "Housepital Pvt Ltd"; full Mohan Cooperative
  address; CIN U85100DL2019PTC357830; tagline to period-separated form
- `help_faq`: both support@housepital.in → wecare@housepital.in
- `splash_screen`: hardcoded 0xFFF39314 → `HousepitalColors.orange` token
- `theme`: `GoogleFonts.notoSansDevanagari` added as fontFamilyFallback for
  Hindi glyphs when Archivo lacks coverage
- `home_screen`: banner title to sentence case with periods
- 4 docs + ARCHITECTURE.md: housepital.com → housepital.in
- `payment_service`: debug assert catches placeholder Razorpay key

### Permissions + Add Patient
- `permissions`: added `request_booking` action; FAMILY_MEMBER can view,
  request_booking, rate, raise_concern (NOT book); PRIMARY_CONTACT has all 8
- `app_provider`: `currentUserRole`, `setUserRole()`, `addPatient()`
- 17 `canUserPerform()` call sites across 9 screens
- NEW `add_patient_screen` — full form with addPatient() integration
- `main.dart`: registered `/add-patient`; `/booking-history` alias → `/my-orders`
- `home_screen`: role badge below greeting; "Call my family caregiver" card
  for PATIENT_SELF; hides Book Services / Dai Maa for view-only roles
- `settings`: Add Patient tile + Family Members tile, both gated
- `patient_profile`: AbsorbPointer wraps form for non-editors; read-only banner

### Dai Maa sub-brand
- NEW `config/daimaa_theme.dart` — DaiMaaColors (plum #5C3C5C, lavender
  #B48EAD, pink #E3AFBE, cream #F5F0EB), DaiMaaBrandHeader, DaiMaaBadge widgets
- NEW `screens/daimaa/daimaa_landing_screen.dart` — cream bg, plum AppBar,
  Japa Maid (0-7m) + Nanny (7m-5y), Call Coordinator CTA
- `home_screen`: plum Dai Maa entry tile after Quick Actions
- `service_catalog`: Japa/Nanny role cards get plum border + lavender icon
  tint + DAI MAA badge
- `assessment_request`: japa/nanny → cream bg, plum AppBar, DaiMaaBrandHeader

### Accessibility
- 44pt+ touch targets: Quick Actions grid, miniVitalChip, cart close/delete
- `main.dart`: `MaterialApp` builder clamps `textScaler` 0.85–1.4
- `miniVitalChip`: zone icon + color (WCAG 1.4.1); semantic label
- NEW `confirmDestructiveAction()` helper, wired to cart remove, address delete,
  medication remove
- 5 Image widgets get `semanticLabel`
- Hero banner: Semantics(container, image, label)
- Form field labelText added on promo + coupon inputs

### Cleanup
- `home_screen`: live `_buildMedicationsSnippet` using `MedicationProvider`
- NEW `_DailyCareRatingCard` in my_care_screen — 5-star rating persisted to
  SharedPreferences; ratings 1-3 open feedback modal → /raise-concern
- `service_booking._buildReviewStep`: price null/0 → disabled Add-to-Cart +
  Request Assessment button

---

## [2026-03-25 (Session 6)] -- OrdersProvider, Billing Rewrite, i18n Fixes, Payment Web Sim

### OrdersProvider
- **New provider:** `OrdersProvider` manages orders and assessments with SharedPreferences persistence
- **addOrder:** Creates orders with booking number, items, total, status 'confirmed', newest-first ordering
- **addAssessment:** Creates assessment requests with serviceId, serviceName, status 'submitted'
- **cancelOrder / updateOrderStatus:** Status management with cancellation reason tracking
- **generateBookingNumber:** Produces HPL-BOOK-XXXXX format (5-digit random suffix)

### Billing Rewrite
- **BillingScreen rewritten:** Now reads from OrdersProvider instead of mock/hardcoded data
- **Billing calculations:** totalOutstanding (confirmed + in_progress), totalPaid (completed), overdueCount (confirmed > 7 days)
- **Spend summary:** Groups spend by service vs equipment category with percentage breakdown

### i18n Fixes
- Added missing translation keys for billing, orders, and payment screens

### Payment Web Simulation
- **PaymentService:** Web simulation mode with kIsWeb guard prevents Razorpay SDK crash on web

### New Test Files (3)
- `test/providers/orders_provider_test.dart` -- 20 tests for OrdersProvider (addOrder, addAssessment, cancelOrder, updateOrderStatus, generateBookingNumber, empty state)
- `test/screens/billing/billing_screen_test.dart` -- 23 tests for billing calculation logic (totalOutstanding, totalPaid, overdueCount, spendSummary, zero state)
- `test/providers/orders_persistence_test.dart` -- 11 tests for SharedPreferences persistence (persist, load, corrupt JSON, round-trip)

### Code Quality Fixes
- Removed 6 unused imports across lib/ (main.dart, app_provider.dart, billing_provider.dart, main_shell.dart, service_detail_screen.dart, cart_screen.dart)
- Fixed empty catch block in universal_search_screen.dart (now logs error with debugPrint)
- No print() statements found in production code (all use debugPrint)
- All form fields have validators

### Known Issues Resolved
- BUG-29: Orders not persisting (OrdersProvider with SharedPreferences)
- BUG-30: Billing mock data (reads from OrdersProvider)
- BUG-31: Payment web crash (web simulation mode)
- BUG-32: Missing i18n keys (translation keys added)

### Documentation Updated
- ARCHITECTURE.md: Added OrdersProvider (6 -> 7 providers)
- FEATURE_TRACKER.md: Updated billing, My Orders, payment statuses
- KNOWN_ISSUES.md: Marked 4 issues resolved
- CHANGELOG.md: Added Session 6 entry
- TEST_MAP.md: Added 3 new test files

---

## [2026-03-25 (Session 5)] -- Cart Rewrite, Comprehensive Cart Tests

### Cart Rewrite
- **CartProvider rewritten:** Replaced nested EquipmentItem-based cart with flat `CartItem` model and `List<CartItem>` with index-based operations
- **CartItem model:** Flat data class with `equipmentId`, `name`, `brand`, `imageUrl`, `unitPrice`, `mrp`, `isRental`, `rentalMonths`, `quantity`, `lineTotal`, `copyWith`, `toJson`/`fromJson`
- **CartScreen rewritten:** Uses index-based operations, coupon section with WELCOME10 (10% off, max Rs.500), delivery charge logic (free above Rs.999, Rs.49 below)
- **Persistence:** SharedPreferences with flat JSON serialization (no nested EquipmentItem deserialization failure)

### New Test Files (3)
- `test/models/cart_item_test.dart` -- 24 tests for flat CartItem model (constructor, defaults, lineTotal, copyWith, toJson, fromJson, round-trip)
- `test/screens/cart/cart_screen_test.dart` -- 27 tests for cart screen data/logic (empty state, addItem, subtotal, delivery charge, total, coupon WELCOME10, remove, clear)
- `test/integration/cart_flow_test.dart` -- 12 tests for end-to-end cart flow (add->update->remove, rental save/restore, clear all, duplicates, merge, notifications)

### Existing Test Updates
- `test/screens/cart/cart_coupon_test.dart` -- verified compatible with new CartProvider API (no changes needed)

### Known Issues Resolved
- BUG-27: Cart shows empty after adding items (flat CartItem model fixes deserialization)
- BUG-28: Cart grey screen on reopen (flat JSON persistence)

### Breaking Changes
- CartProvider API is now index-based (not key-based)
- CartItem is a flat model (no nested EquipmentItem)

---

## [2026-03-24 (Session 4)] -- P0/P1 Features, Pricing Sync, 16 New Features, 973 Tests

### New Screens (10)
- **VideoConsultationScreen:** Video call with coordinator/doctor via video_call_service
- **ChatScreen:** Real-time in-app chat with coordinator using Firestore chat_messages
- **StaffOtpVerificationScreen:** OTP-based staff identity verification at check-in
- **OrderTrackingScreen:** Track order delivery/assignment status with timeline
- **RentalAgreementScreen:** Rental terms display with digital signature (deposit = 1 month, 3-day return notice)
- **ReturnScreen:** Equipment return request with reason and scheduling
- **EmiScreen:** EMI payment plans display and installment tracking
- **StaffReplacementScreen:** Request staff replacement with reason selection
- **ReferralScreen:** Refer-a-friend program with shareable code and reward tracking
- **MyOrdersScreen:** Unified view of all orders (bookings + equipment + rentals)

### Major Features
- **Pricing overhaul:** Manpower services now show prices (was hidden). MRP + strikethrough pricing on equipment. All 364 items synced from master Excel (single source of truth).
- **Equipment tab reorganization:** Sale and Rental categories replace Equipment/Consumable tabs
- **Lab tests expansion:** 153 individual lab tests added with full detail (was 7 packages only)
- **Medication reminders:** Local push notifications via flutter_local_notifications at 8AM/1PM/6PM/10PM
- **Pagination widget:** Reusable PaginatedList widget for all list screens
- **Offline caching:** cache_service with TTL for dashboard and catalog data
- **Push notification routing:** notification_router.dart handles tap -> screen navigation
- **Hindi translations:** 90+ new keys added (near-complete coverage)
- **Cart persistence:** SharedPreferences-backed cart survives app restart

### Code Quality Improvements
- **Rate limiting:** express-rate-limit applied to all backend endpoints
- **Zod validation:** Request payload validation with Zod schemas on backend
- **CORS restriction:** Backend CORS restricted to allowed origins only
- **Structured logging:** Correlation IDs for request tracing on backend
- **Retry with backoff:** API calls retry with exponential backoff on failure

### Bug Fixes
- **Bottom sheet grey screen:** Replaced pop-then-push pattern with return-result-to-parent pattern
- **Razorpay web crash:** Guarded with kIsWeb check to prevent crash on web platform
- **Offline handling:** cache_service prevents blank screen when offline

### New Service Files
- `lib/services/video_call_service.dart` (NEW)
- `lib/services/cache_service.dart` (NEW)
- `lib/services/medication_reminder_service.dart` (NEW)
- `lib/services/i_api_service.dart` (NEW -- API service interface)

### New Utility Files
- `lib/utils/notification_router.dart` (NEW)
- `lib/widgets/paginated_list.dart` (NEW)

### New Provider
- `lib/providers/billing_provider.dart` (NEW -- BillingProvider)

### Test Results
- **973 tests passing** (was 529 previously)
- 24 new test files added covering new screens, services, and utilities

### Known Issues Resolved
- BUG-11: Offline handling (cache_service added)
- BUG-13: Hindi translations (90+ keys added)
- BUG-18: Notification routing (notification_router.dart)
- BUG-24: Coordinator chat (ChatScreen)
- BUG-25: Bottom sheet grey screen (return-result-to-parent pattern)
- BUG-26: Razorpay web crash (kIsWeb guard)

### Breaking Changes
- Equipment tab categories changed from Equipment/Consumable to Sale/Rental
- Manpower services now show prices (previously hidden with hide_price flag)

---

## [2026-03-22 (Session 2)] -- 24 Issues Fixed: New Screens, Bug Fixes, Permissions Update

### New Screens (6)
- **BookingConfirmationScreen:** Animated confirmation with booking ID, next steps, share via share_plus
- **BookingHistoryScreen:** Filter by status, cancel bookings, rate completed services, re-book
- **AddressSelectionScreen:** Saved addresses with SharedPreferences persistence, pincode validation, add/edit/delete
- **NotificationPreferencesScreen:** Toggleable notification types + forced-ON for critical alerts (late check-in, vitals RED, payment)
- **HelpFaqScreen:** 20 FAQs across 5 categories (Booking, Payments, Staff, Equipment, Account), search, contact support
- **AboutScreen:** Company info, app version, social links, terms/privacy policy links

### Bug Fixes (18)
- **PaymentScreen:** Replaced `Random()` stub with real Razorpay integration
- **CartProvider:** Added SharedPreferences persistence so cart survives app restart
- **CartScreen:** Added coupon/promo code system with discount display
- **EquipmentDetailScreen:** Added rental duration selector, share button, sorting options
- **PatientProfileScreen:** Wired real API save (PUT /patients/:id), added city dropdown list
- **RaiseConcernScreen:** Fixed evidence upload, wired real API submission (POST /concerns)
- **DocumentRepositoryScreen:** Implemented search, share, open document functionality
- **SettingsScreen:** All dead-end navigation items now wired to real screens
- **permissions.dart:** FAMILY_MEMBER role can now book services (added 'book' to permission set)
- **AssessmentRequestScreen:** Added form field validators to prevent empty submissions
- **ServiceBookingScreen:** Booking now navigates to BookingConfirmationScreen, address loading from saved addresses, IV line validator added

### Permission Changes
- FAMILY_MEMBER can now perform 'book' action (was previously PRIMARY_CONTACT only)

### Files Created
- `lib/screens/services/booking_confirmation_screen.dart` (NEW)
- `lib/screens/services/booking_history_screen.dart` (NEW)
- `lib/screens/checkout/address_selection_screen.dart` (NEW)
- `lib/screens/settings/notification_preferences_screen.dart` (NEW)
- `lib/screens/settings/help_faq_screen.dart` (NEW)
- `lib/screens/settings/about_screen.dart` (NEW)

### Files Modified
- `lib/screens/billing/payment_screen.dart` (MODIFIED -- real Razorpay)
- `lib/providers/cart_provider.dart` (MODIFIED -- SharedPreferences persistence)
- `lib/screens/cart/cart_screen.dart` (MODIFIED -- coupon system)
- `lib/screens/services/equipment_detail_screen.dart` (MODIFIED -- rental selector, share, sorting)
- `lib/screens/settings/patient_profile_screen.dart` (MODIFIED -- real API, city list)
- `lib/screens/support/raise_concern_screen.dart` (MODIFIED -- evidence upload, real API)
- `lib/screens/documents/document_repository_screen.dart` (MODIFIED -- search, share, open)
- `lib/screens/settings/settings_screen.dart` (MODIFIED -- dead ends wired)
- `lib/utils/permissions.dart` (MODIFIED -- FAMILY_MEMBER can book)
- `lib/screens/services/assessment_request_screen.dart` (MODIFIED -- form validators)
- `lib/screens/services/service_booking_screen.dart` (MODIFIED -- confirmation flow, address, IV validator)
- `lib/main.dart` (MODIFIED -- new routes added)

### Known Issues Resolved
- BUG-03: Share button on booking confirmation (now wired)
- BUG-04: Promo code stub (coupon system added)
- BUG-05: Payment stub in booking wizard (real Razorpay flow)
- BUG-06: Form validation gaps in assessment request (validators added)
- BUG-15: Document repository placeholder (search/share/open implemented)

### Breaking Changes
- None

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
