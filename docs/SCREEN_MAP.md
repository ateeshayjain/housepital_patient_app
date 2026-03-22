# Screen Map -- Patient App

## Navigation Structure

```
Bottom Tab Bar (MainShell -- 5 tabs)
  |-- [0] Home        -> HomeScreen (Dashboard)
  |-- [1] My Care     -> MyCareScreen (Active services hub)
  |-- [2] Services    -> ServiceCatalogScreen (Marketplace)
  |-- [3] Billing     -> BillingScreen (Payments & invoices)
  |-- [4] More        -> SettingsScreen (Profile, settings, support)
```

Tab switching is managed via `IndexedStack` in `MainShell` for state preservation. A global key (`MainShell.shellKey`) allows programmatic tab switching from any screen via `MainShell.switchToTab(index)`.

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

**Manpower price rule:** Services with `hide_price = true` (caretaker, nursing, japa, nanny) show no prices. Users must submit an assessment request to receive a personalized quote.

---

### BILLING TAB (Index 3)

| Screen             | Route             | Widget                | Data Source                        | Actions                    | Permissions  |
|--------------------|-------------------|-----------------------|------------------------------------|----------------------------|--------------|
| Billing Dashboard  | (tab)             | BillingScreen         | API: /patients/:id/billing/summary | View summary, invoices     | All roles    |
| Invoice Detail     | /invoice-detail   | InvoiceDetailScreen   | API: /invoices/:id                 | View, download, pay        | All roles    |
| Transaction Log    | /transactions     | TransactionLogScreen  | API: /patients/:id/transactions    | View payment history       | All roles    |
| Payment            | /payment          | PaymentScreen         | amount, description, invoice_id args | Razorpay checkout        | PRIMARY only |
| Payment Methods    | /payment-methods  | PaymentMethodsScreen  | (static/settings)                  | View saved methods         | All roles    |

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
| `/services`          | none                      | Scaffold (placeholder)     |
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
