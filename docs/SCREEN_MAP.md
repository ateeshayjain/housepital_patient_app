# Screen Map -- Patient App

## Navigation Structure

```
Bottom Tab Bar (MainShell -- 5 tabs, FLOATING liquid-glass pill)
  |-- [0] Home        -> HomeScreen (Dashboard)
  |-- [1] My Care     -> MyCareScreen (Active services hub)
  |-- [2] Services    -> ServiceCatalogScreen (Marketplace)
  |-- [3] Billing     -> BillingScreen (Payments & invoices)
  |-- [4] More        -> SettingsScreen (Profile, settings, support)
```

Tab switching is managed via `IndexedStack` in `MainShell` for state preservation. A global key (`MainShell.shellKey`) allows programmatic tab switching from any screen via `MainShell.switchToTab(index)`.

**The care calendar is NOT a tab.** It was a root tab at index 3 during field rounds 4-5; the owner moved it to the My Care app bar (`'/care-calendar'`, custom action left of search) to get back to five icons. Indices **1, 2 and 3** are referenced externally by `switchToTab` calls and must not be reordered — in particular `home_screen`'s "Pay Now" button and upcoming-payment card call `switchToTab(3)` expecting **Billing**, which is what they silently stopped doing while Calendar occupied that index.

**Chrome:** the bar is a detached `GlassSurface` pill (16px side insets, radius 32, floating above the home indicator), not the fixed edge-to-edge orange bar of field round 5. It lives in the Scaffold's `bottomNavigationBar` slot so the body's bottom `MediaQuery` inset still covers its full footprint.

**Nav bar:** FIXED full-width solid-orange bar anchored to the bottom edge (owner iterated floating-glass → pill → fixed), white icons/labels, SafeArea-padded.

**GlassAppBar chrome contract:** every screen uses `GlassAppBar` (`lib/widgets/glass.dart`) — back on the left (or HOME leftmost on non-Home root tabs); trailing order `[custom…, home, search → /search, cart → /cart]` with the **CART always rightmost** and a live item-count badge. `showSearch`/`showCart`/`showHome` all default on; the purchase funnel (cart/checkout/payment) opts out of the cart icon; Billing shows no cart; the Home tab omits its own home button (SOS is the home-screen far-right emergency exception).

---

## Screen Inventory

### HOME TAB (Index 0)

| Screen        | Route   | Widget          | Data Source                           | Actions                         | Permissions |
|---------------|---------|-----------------|---------------------------------------|----------------------------------|-------------|
| Dashboard     | (tab)   | HomeScreen      | AppProvider (dashboard data)          | Navigate to vitals/reports/pay/SOS/search | All roles |

**Dashboard cards:** Attendance status, latest vitals (color-coded), daily report progress, billing due amount, active services count.

---

### MY CARE TAB (Index 1)

| Screen               | Route                  | Widget                     | Data Source                    | Actions                           | Permissions |
|----------------------|------------------------|----------------------------|--------------------------------|-----------------------------------|-------------|
| My Care Hub          | (tab)                  | MyCareScreen               | MyCareProvider.activeServices  | Tap service card, quick actions   | All roles   |
| Service Detail       | /service-detail        | ServiceDetailScreen        | API: deployments/:id/service-detail | View staff, vitals, report, equipment | All roles |
| Attendance History   | /attendance-history    | AttendanceHistoryScreen    | API: deployments/:id/attendance | View, paginate                   | All roles   |
| Report History       | /report-history        | ReportHistoryScreen        | API: patients/:id/reports      | View, tap to detail              | All roles   |
| Medications          | /medications           | MedicationsScreen          | MedicationProvider             | Add, edit, delete, stock update  | PRIMARY only (write) |
| Medication Schedule  | /medication-schedule   | MedicationScheduleScreen   | MedicationProvider.logs        | View today's schedule            | All roles   |
| Add/Edit Medication  | /add-medication        | AddEditMedicationScreen    | MedicationProvider             | Create/update medication         | PRIMARY only |
| Staff OTP Verify     | /staff-otp             | StaffOtpVerificationScreen | API                            | Verify staff identity via OTP    | All roles   |

**My Care Hub widgets:** HealthManagerBanner, ActiveServiceCard (per service), QuickActionsRow, VitalsTrendGrid, StaffAttendanceSection, CareReportSection, BillingSummarySection, EquipmentDeployedSection.

---

### SERVICES TAB (Index 2)

| Screen              | Route               | Widget                   | Data Source                   | Actions                          | Permissions  |
|---------------------|----------------------|--------------------------|-------------------------------|----------------------------------|--------------|
| Service Catalog     | (tab)                | ServiceCatalogScreen     | API: /services                | Browse, search, filter           | All roles    |
| Service Booking     | /service-booking     | ServiceBookingScreen     | ServiceItem argument          | Select slot, apply promo, book   | PRIMARY only |
| Assessment Request  | /assessment-request  | AssessmentRequestScreen  | ServiceItem argument          | Fill questionnaire, submit       | PRIMARY only |
| Equipment Detail    | /equipment-detail    | EquipmentDetailScreen    | ServiceItem argument          | View details, rent               | PRIMARY only |
| Package Detail      | /package-detail      | PackageDetailScreen      | CarePackage argument          | View package benefits            | All roles    |
| Booking Confirmation| /booking-confirmation| BookingConfirmationScreen| Map args (serviceName, date, slot, amount) | View booking ID, share, next steps | All roles |
| Booking History     | /booking-history     | BookingHistoryScreen     | API: GET /patients/:id/bookings | Filter, cancel, rate, re-book  | All roles    |
| My Orders           | /my-orders           | MyOrdersScreen           | API: unified orders endpoint    | View all orders (bookings + equipment + rentals) | All roles |

**Manpower pricing rule:** manpower prices **ARE shown and directly bookable** (rate card: Caretaker ₹800–1,500/day, Nurse ₹1,600–3,000/day, monthly packages ₹18,000–₹90,000/mo). Booking runs the normal cart/payment path with a per-day × days (or × sessions) multiplier; Housepital calls back after purchase to assign staff. *(Reversed/re-confirmed 2026-06-11 — the old "never show" rule is dead.)* Quote-pending applies only to items that genuinely lack a price (`isQuote = price == null/0`, never `category == manpower`). Needs-based tier selection via the checklist on `staff_role_card.dart`. Equipment keeps MRP + strikethrough (Blinkit-style left category rail + dense 2-col grid); price-on-request items (none remain in the equipment catalog) use the Reserve flow. Consultations now include Psychiatrist + Diet & Nutrition (Nourish Programme).

**Lab Tests:** individual lab tests with full detail (name, price, preparation notes) plus package tiers (`assets/lab_tests_catalog.json`).

**Equipment catalog stats:** 351 items (`assets/equipment_catalog.json`; deduped 355 → 351, all priced); 320 carry a bundled product image (shared `ProductImage` widget renders in grid + detail sheet), ~31 generic items show the placeholder icon.

---

### CALENDAR TAB (Index 3)

| Screen        | Route           | Widget             | Data Source                    | Actions                                   | Permissions |
|---------------|-----------------|--------------------|--------------------------------|-------------------------------------------|-------------|
| Care Calendar | /care-calendar (My Care app bar) | CareCalendarScreen | CareEvent + MedicationProvider | Day/Week/Month views; single-tap mark-taken (timestamped log); staff attendance mark-present; future-day "N doses scheduled" cards | All roles |

---

### BILLING TAB (Index 4)

| Screen             | Route             | Widget                | Data Source                        | Actions                    | Permissions  |
|--------------------|-------------------|-----------------------|------------------------------------|----------------------------|--------------|
| Billing Dashboard  | (tab)             | BillingScreen         | API: /patients/:id/billing/summary | View summary, invoices     | All roles    |
| Invoice Detail     | /invoice-detail   | InvoiceDetailScreen   | API: /invoices/:id                 | View, download, pay        | All roles    |
| Transaction Log    | /transactions     | TransactionLogScreen  | API: /patients/:id/transactions    | View payment history       | All roles    |
| Payment            | /payment          | PaymentScreen         | amount, description, invoice_id args | Razorpay checkout        | PRIMARY only |
| Payment Methods    | /payment-methods  | PaymentMethodsScreen  | (static/settings)                  | View saved methods         | All roles    |
| EMI Plans          | /emi-options      | EmiScreen             | BillingProvider                    | View/manage EMI installments | PRIMARY only |

---

### CONSULTATION & CHAT

| Screen               | Route                | Widget                      | Data Source                    | Actions                          | Permissions  |
|----------------------|----------------------|-----------------------------|--------------------------------|----------------------------------|--------------|
| Video Consultation   | /video-consultation  | VideoConsultationScreen      | video_call_service             | Join/leave video call            | All roles    |
| In-app Chat          | /chat                | ChatScreen                  | Firestore chat_messages        | Send/receive messages            | All roles    |

---

### CARE CALENDAR & CARE TEAM

| Screen               | Route                | Widget                      | Data Source                    | Actions                          | Permissions  |
|----------------------|----------------------|-----------------------------|--------------------------------|----------------------------------|--------------|
| Care Calendar        | /care-calendar       | CareCalendarScreen          | CareEvent + MedicationProvider | Day/Week/Month views; dose groups mark-taken; staff attendance mark-present | All roles |
| Care Team Hub        | /care-team           | CareTeamScreen              | Demo/team data                 | Group chat (first), member call/chat, call ambulance, view past staff | All roles |

---

### ARTICLES & ASSISTANT

| Screen               | Route                | Widget                      | Data Source                    | Actions                          | Permissions  |
|----------------------|----------------------|-----------------------------|--------------------------------|----------------------------------|--------------|
| Care Guides List     | /articles            | ArticleListScreen           | BlogProvider (demo fallback)   | Browse; featured hero; category accent filters | All roles |
| Article Detail       | /article             | ArticleDetailScreen         | BlogProvider                   | Read markdown body, share        | All roles    |
| AI Assistant         | /assistant           | AssistantScreen             | AssistantProvider              | Voice/text Hinglish chat; confirm-first actions | All roles (role-gated actions) |

---

### ORDERS & RENTAL

| Screen               | Route                | Widget                      | Data Source                    | Actions                          | Permissions  |
|----------------------|----------------------|-----------------------------|--------------------------------|----------------------------------|--------------|
| My Orders            | /my-orders           | MyOrdersScreen              | OrdersProvider                 | View bookings (incl. quote-pending) + equipment + rentals | All roles |
| Order Tracking       | /order-tracking      | OrderTrackingScreen          | API: order status              | Track delivery/assignment status | All roles    |
| Rental Agreement     | /rental-agreement    | RentalAgreementScreen        | API: rental terms              | Review terms, digital sign       | PRIMARY only |
| Equipment Return     | /return-equipment    | ReturnScreen                 | API: return request            | Schedule return, reason          | PRIMARY only |

---

### MORE TAB (Index 4)

| Screen             | Route              | Widget                   | Data Source                     | Actions                    | Permissions  |
|--------------------|--------------------|--------------------------|---------------------------------|----------------------------|--------------|
| Settings           | (tab)              | SettingsScreen           | AppProvider, AuthProvider       | Navigate to sub-screens    | All roles    |
| Patient Profile    | /patient-profile   | PatientProfileScreen     | API: /patients/:id              | View/edit patient info     | PRIMARY only (edit) |
| Family Members     | /family-members    | FamilyMembersScreen      | API: /patients/:id/family       | Add, remove, edit members  | PRIMARY only (write) |
| Documents          | /documents         | DocumentRepositoryScreen | (TBD)                           | Search, share, open docs   | PRIMARY only (upload) |
| Notification Prefs | /notification-preferences | NotificationPreferencesScreen | SharedPreferences       | Toggle notification types  | All roles (own prefs) |
| Help / FAQ         | /help-faq          | HelpFaqScreen            | Static (20 FAQs)                | Search, filter by category, contact support | All roles |
| About              | /about             | AboutScreen              | Static                          | View version, company info, links | All roles |
| Referral           | /referrals         | ReferralScreen           | API: referral code + stats      | Share referral code, view rewards | All roles |

---

### SUPPORT (Additional)

| Screen                | Route                   | Widget                       | Data Source                    | Actions                    | Permissions  |
|-----------------------|-------------------------|------------------------------|--------------------------------|----------------------------|--------------|
| Staff Replacement     | /staff-replacement      | StaffReplacementScreen       | API: replacement request       | Request new staff, reason  | PRIMARY only |

---

### CHECKOUT SCREENS (Accessible from booking flow)

| Screen             | Route              | Widget                   | Data Source                     | Actions                    | Permissions  |
|--------------------|--------------------|--------------------------|---------------------------------|----------------------------|--------------|
| Address Selection  | (pushed directly)  | AddressSelectionScreen   | SharedPreferences (saved addresses) | Select, add, edit, delete addresses; pincode validation | All roles |

---

### STANDALONE SCREENS (Accessible from multiple tabs)

| Screen             | Route              | Widget                   | Data Source                     | Actions                        | Permissions  |
|--------------------|--------------------|--------------------------|---------------------------------|--------------------------------|--------------|
| Login              | (initial)          | LoginScreen              | AuthProvider                    | Enter phone, request OTP       | Unauthenticated |
| OTP Verification   | /otp               | OtpScreen                | AuthProvider                    | Enter OTP, verify              | Unauthenticated |
| Onboarding         | /onboarding        | OnboardingScreen         | AuthProvider                    | Enter patient/family details   | New users    |
| SOS                | /sos               | SOSScreen                | AppConstants (emergency numbers)| Call ambulance, call 112       | All roles    |
| Notifications      | /notifications     | NotificationsScreen      | API: /notifications             | View, mark read, mark all read | All roles    |
| Raise Concern      | /raise-concern     | RaiseConcernScreen       | API: POST /concerns             | Fill form, attach evidence     | All roles    |
| Staff Profile      | /staff-profile     | StaffProfileScreen       | API: /staff/:id/profile         | View only                      | All roles    |
| Daily Report       | /report-detail     | DailyReportScreen        | API: /reports/:id               | View sections, photos          | All roles    |
| Vitals             | /vitals            | VitalsScreen             | API: /patients/:id/vitals       | View charts (7d/30d/90d)       | All roles    |
| Cart               | /cart              | CartScreen               | CartProvider                    | View, remove, checkout         | PRIMARY only |
| Search             | /search            | UniversalSearchScreen    | (local + API)                   | Search services, staff, etc.   | All roles    |

---

## Route Table (`onGenerateRoute` in main.dart)

| Route                | Arguments Type            | Target Screen              |
|----------------------|---------------------------|----------------------------|
| `/otp`               | none                      | OtpScreen                  |
| `/onboarding`        | none                      | OnboardingScreen           |
| `/sos`               | none                      | SOSScreen                  |
| `/notifications`     | none                      | NotificationsScreen        |
| `/settings`          | none                      | SettingsScreen             |
| `/patient-profile`   | none                      | PatientProfileScreen       |
| `/billing`           | none                      | BillingScreen              |
| `/raise-concern`     | none                      | RaiseConcernScreen         |
| `/vitals`            | `String?` (vital type)    | VitalsScreen               |
| `/report-detail`     | `String` (reportId)       | DailyReportScreen          |
| `/staff-profile`     | `String` (staffId)        | StaffProfileScreen         |
| `/service-booking`   | `ServiceItem`             | ServiceBookingScreen       |
| `/equipment-detail`  | `ServiceItem`             | EquipmentDetailScreen      |
| `/assessment-request`| `ServiceItem`             | AssessmentRequestScreen    |
| `/invoice-detail`    | `Invoice` or `String`     | InvoiceDetailScreen        |
| `/transactions`      | none                      | TransactionLogScreen       |
| `/payment`           | `Map<String, dynamic>`    | PaymentScreen              |
| `/family-members`    | none                      | FamilyMembersScreen        |
| `/cart`              | none                      | CartScreen                 |
| `/payment-methods`   | none                      | PaymentMethodsScreen       |
| `/package-detail`    | `CarePackage`             | PackageDetailScreen        |
| `/search`            | none                      | UniversalSearchScreen      |
| `/documents`         | none                      | DocumentRepositoryScreen   |
| `/services`          | none                      | -> root tab 2 (redirect)   |
| `/delete-account`    | none                      | DeleteAccountScreen        |
| `/service-detail`    | `ActiveService`           | ServiceDetailScreen        |
| `/medications`       | none                      | MedicationsScreen          |
| `/medication-schedule`| none                     | MedicationScheduleScreen   |
| `/add-medication`    | `MedicationFull?`         | AddEditMedicationScreen    |
| `/report-history`    | `String` (deploymentId)   | ReportHistoryScreen        |
| `/attendance-history`| `String` (deploymentId)   | AttendanceHistoryScreen    |
| `/booking-confirmation` | `Map<String, dynamic>` (serviceName, scheduledDate, scheduledSlot, totalAmount) | BookingConfirmationScreen |
| `/booking-history`   | none                      | BookingHistoryScreen       |
| `/notification-preferences` | none               | NotificationPreferencesScreen |
| `/help-faq`          | none                      | HelpFaqScreen              |
| `/about`             | none                      | AboutScreen                |
| `/video-consultation`| `Map<String, dynamic>`    | VideoConsultationScreen     |
| `/chat`              | `String` (patientId)      | ChatScreen                 |
| `/staff-otp`         | `Map<String, dynamic>`    | StaffOtpVerificationScreen |
| `/order-tracking`    | `String` (orderId)        | OrderTrackingScreen        |
| `/rental-agreement`  | `Map<String, dynamic>`    | RentalAgreementScreen      |
| `/return-equipment`  | `Map<String, dynamic>`    | ReturnScreen               |
| `/emi-options`       | `Map<String, dynamic>`    | EmiScreen                  |
| `/staff-replacement` | `String` (deploymentId)   | StaffReplacementScreen     |
| `/referrals`         | none                      | ReferralScreen             |
| `/my-orders`         | none                      | MyOrdersScreen             |
| `/home`              | none                      | MainShell (shellKey)       |
| `/assistant`         | none                      | AssistantScreen            |
| `/care-calendar`     | none                      | CareCalendarScreen         |
| `/care-team`         | none                      | CareTeamScreen             |
| `/articles`          | none                      | ArticleListScreen          |
| `/article`           | `String` (articleId)      | ArticleDetailScreen        |
| `/add-patient`       | none                      | AddPatientScreen           |
| (default)            | none                      | MainShell                  |

---

## Screen States

Every screen MUST handle these states:

| State              | Description                                | UI Pattern                        |
|--------------------|--------------------------------------------|-----------------------------------|
| Data loaded        | Happy path -- data displayed               | Normal content                    |
| Loading            | API call in progress                       | Skeleton/shimmer or CircularProgressIndicator |
| Empty              | No data exists yet                         | Empty state illustration + message|
| Error              | API call failed                            | Error message + retry button      |
| Permission denied  | FAMILY_MEMBER trying PRIMARY-only action   | Disabled button or info message   |
| Offline            | No internet (future)                       | Cached data with "last updated" badge |

---

**Update rule:** Every new screen = update this map. Every route change = update this map.
