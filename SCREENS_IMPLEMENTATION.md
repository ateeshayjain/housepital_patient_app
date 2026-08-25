# Screens Implementation — Housepital Patient App

This document outlines the implementation of all screens in the Housepital Patient App Flutter project.

## Total Screens: 33 (across 8 modules + widgets)

---

## AUTH MODULE

### 1. LoginScreen
**File:** `lib/screens/auth/login_screen.dart`

Phone number entry with OTP flow initiation. Country code (+91) prefilled.

**Features:**
- Phone number input with validation (10 digits)
- Country code selector (India default)
- "Send OTP" button
- Housepital branding header
- Terms & conditions link

**Key Methods:**
- `_sendOtp()` — Validates phone, calls AuthProvider.sendOtp()
- `_validatePhone()` — 10-digit validation

**Props:** None

---

### 2. OtpScreen
**File:** `lib/screens/auth/otp_screen.dart`

6-digit OTP verification. Auto-focuses first field. Resend timer.

**Features:**
- 6-digit PIN code fields (auto-advance)
- Resend OTP button with 30-second cooldown timer
- Phone number display with edit option
- Auto-submit on 6th digit
- Loading state during verification

**Key Methods:**
- `_verifyOtp()` — Calls AuthProvider.verifyOtp(otp)
- `_resendOtp()` — Resend with cooldown reset

**Props:** None (phone from AuthProvider)

---

### 3. OnboardingScreen
**File:** `lib/screens/auth/onboarding_screen.dart`

Post-auth setup: name, relationship to patient, language preference.

**Features:**
- Name input field
- Relationship dropdown (Spouse, Son, Daughter, Son-in-law, Daughter-in-law, Sibling, Other)
- Language toggle (English/Hindi)
- Skip/Complete buttons
- Progress indicator

**Key Methods:**
- `_completeOnboarding()` — Saves profile via API

**Props:** None

---

## HOME MODULE

### 4. HomeScreen
**File:** `lib/screens/home/home_screen.dart`

Main dashboard showing today's snapshot: vitals, attendance, report progress, quick actions. (~1000 lines)

**Features:**
- Patient selector dropdown (multi-patient families)
- Notification bell + SOS button in app bar
- Vitals highlights: 6-card grid (BP systolic/diastolic, Pulse, SpO2, Temp, Sugar) with color-coded status (green/yellow/red via VitalHelper)
- On-duty staff banner with live duration counter (auto-updates via Timer every 60s)
- "View My Care" orange CTA banner (shown when active deployment exists)
- Today's attendance status with check-in timestamp
- Daily report progress: completion percentage bar, sections with task checklists
- Active care packages summary cards
- Quick actions: Call Staff, View Reports, Medication Schedule, Raise Concern
- Pull-to-refresh via RefreshIndicator

**Key Methods:**
- `_loadData()` — Calls AppProvider.loadPatients() then loadDashboard()
- `_buildVitalsGrid()` — 6 vital cards with color status
- `_buildOnDutyBanner()` — Staff name + role + duration
- `_buildAttendanceSection()` — Status badge + timestamp
- `_buildReportSection()` — Progress bar + task list
- `_navigateToMyCare()` — MainShell.shellKey.currentState.switchToTab(1)

**Props:** None

---

## MY CARE MODULE

### 5. MyCareScreen
**File:** `lib/screens/my_care/my_care_screen.dart`

Main care hub — the "control center" for families monitoring active services.

**Features:**
- WidgetsBindingObserver for foreground-staleness refresh (>60s)
- Pull-to-refresh
- Three UI states: loading (shimmer), error (retry button), empty (CTA to book service)
- Five sections stacked vertically:
  1. HealthManagerBanner — sticky contact card
  2. ActiveServiceCards — one per active service
  3. StaffAttendanceSection — aggregated staff on duty
  4. BillingSummarySection — pre-paid consumption tracker
  5. QuickActionsRow — raise concern, reports, documents

**Key Methods:**
- `_loadData()` — MyCareProvider.loadMyCareData(patientId)
- `_onRefresh()` — Pull-to-refresh handler
- `didChangeAppLifecycleState()` — Refresh if stale on foreground resume

**Props:** None (reads from MyCareProvider + AppProvider)

---

### 6. ServiceDetailScreen
**File:** `lib/screens/my_care/service_detail_screen.dart`

Full detail view for a single active service/deployment.

**Features:**
- Gradient header with service name + color (HousepitalColors.serviceColor)
- Progress bar (consumed/total days or sessions)
- Staff on duty list with check-in times and duration
- 7-day attendance calendar with color-coded dots
- Vitals trend grid (fl_chart sparklines) — only for care_package
- Care report section with task timeline — only for care_package/nursing/caretaker/japa/nanny
- Medication links — only for care_package
- Equipment deployed list — only for care_package/equipment_rental
- Billing breakdown section

**Key Methods:**
- `_loadDetail()` — MyCareProvider.loadServiceDetail(deploymentId)
- Conditional section rendering based on `service.showVitals`, `service.showStaff`, etc.

**Props:**
- `service: ActiveService` — The service to show detail for

---

### 7. MedicationsScreen
**File:** `lib/screens/my_care/medications_screen.dart`

Full medication list with stock tracking and management.

**Features:**
- Medication cards showing name, dosage, frequency, prescribed by
- Stock count with low-stock warning (yellow border, warning badge)
- Refill estimate ("Refill in X days")
- FAB (FloatingActionButton) to add new medication
- Tap medication → AddEditMedicationScreen (edit mode)
- Pull-to-refresh

**Key Methods:**
- `_loadMedications()` — MedicationProvider.loadMedications(patientId)

**Props:** None

---

### 8. MedicationScheduleScreen
**File:** `lib/screens/my_care/medication_schedule_screen.dart`

Today's medication schedule grouped by time slot.

**Features:**
- Time slots: Morning (before 12), Afternoon (12-17), Night (17+)
- Each slot shows: icon + label + time + summary (e.g., "3/3 Given")
- Medication cards within each slot:
  - Green background = administered (shows time + staff name)
  - Grey background = scheduled/pending
  - Red alert = missed dose
- Missed dose alert banner at bottom

**Key Methods:**
- `_loadSchedule()` — MedicationProvider.loadTodaySchedule(patientId)

**Props:** None

---

### 9. AddEditMedicationScreen
**File:** `lib/screens/my_care/add_edit_medication_screen.dart`

Form for adding or editing a medication.

**Features:**
- Add mode (medication=null) vs Edit mode (medication provided)
- Fields: name, dosage, form (tablet/injection/syrup/inhaler/drops), frequency (dropdown), time slots (multi-select), instructions, stock count, stock unit, prescribed by, prescribed date
- Delete button in edit mode with confirmation dialog
- Form validation
- Returns true on success (for screen pop)

**Key Methods:**
- `_save()` — MedicationProvider.addMedication() or updateMedication()
- `_delete()` — MedicationProvider.deleteMedication() with confirmation

**Props:**
- `medication: MedicationFull?` — null for add mode, populated for edit mode

---

### 10. ReportHistoryScreen
**File:** `lib/screens/my_care/report_history_screen.dart`

Paginated list of past daily reports for a deployment.

**Features:**
- Report cards showing: date, completion percentage, staff name
- Tap report → /report-detail with reportId
- Pagination (load more on scroll)
- Empty state

**Key Methods:**
- `_loadReports()` — ApiService.getReportHistory(deploymentId, page)

**Props:**
- `deploymentId: String`

---

### 11. AttendanceHistoryScreen
**File:** `lib/screens/my_care/attendance_history_screen.dart`

Paginated 30-day attendance log.

**Features:**
- Attendance day cards with status icons (on_time, late, replacement, absent, leave)
- Color-coded: green = on_time, yellow = late/replacement, red = absent
- Staff name and replacement info
- Pagination

**Key Methods:**
- `_loadAttendance()` — ApiService.getAttendanceHistoryPaginated(deploymentId, page)

**Props:**
- `deploymentId: String`

---

### My Care Widgets
**Directory:** `lib/screens/my_care/widgets/`

**HealthManagerBanner** (`health_manager_banner.dart`) — Gradient card showing health manager name, availability hours, call button (url_launcher tel:), SMS button. Two-letter initials avatar or photo.

**ActiveServiceCard** (`active_service_card.dart`) — Color-coded card per service. Shows: service name, Day/Session counter, progress bar, staff count (if applicable), latest vital (if care_package), renewal date. Tappable → ServiceDetailScreen.

**StaffAttendanceSection** (`staff_attendance_section.dart`) — Aggregated view of today's staff across all services. Shows check-in status, on-duty duration, replacement flags.

**BillingSummarySection** (`billing_summary_section.dart`) — Pre-paid package consumption tracker. Shows: package paid amount, days consumed/total, progress bar, amount consumed vs remaining, next renewal date, equipment deposit.

**QuickActionsRow** (`quick_actions_row.dart`) — 3 action tiles: Raise Concern (red), Daily Reports (blue), Documents (green). Each tappable → navigates to respective screen.

**VitalsTrendGrid** (`vitals_trend_grid.dart`) — 2x2 grid of vital cards with fl_chart sparklines (last 7 readings). Shows: BP, SpO2, Pulse, Temperature with color-coded status.

**CareReportSection** (`care_report_section.dart`) — Today's report task timeline with completion stats. Shows: task name, status (completed/in_progress/upcoming), completion time, staff notes.

**EquipmentDeployedSection** (`equipment_deployed_section.dart`) — List of deployed equipment items with monthly rental rates and start dates.

---

## SERVICE CATALOG MODULE

### 12. ServiceCatalogScreen
**File:** `lib/screens/services/service_catalog_screen.dart`

Tabbed service browser with 5 sub-tabs. (~2000 lines)

**Features:**
- Tab 1 — Manpower: Nurses (basic/advanced/critical, 12/24hr), caretakers, nanny, japa, physiotherapy. Search filter. "Assessment First" badges on nursing. Tap → ServiceBookingScreen or AssessmentRequestScreen.
- Tab 2 — Equipment: Rental & purchase items (oxygen, wheelchair, hospital bed, etc.). Tap → EquipmentDetailScreen modal. Add to cart.
- Tab 3 — Consultations: Doctor visits, IV visits, dressing. Instant or assessment-based.
- Tab 4 — Diagnostics: Lab tests (ECG, blood work, etc.). Availability info.
- Tab 5 — Sleep Therapy: Sleep study services. Assessment-based.
- Global key `ServiceCatalogScreen.catalogKey` allows switching sub-tabs from HomeScreen.
- **Manpower prices ARE shown and directly bookable** (nursing, caretaker, physio) from the Delhi NCR rate card. The old "never show prices" rule was reversed by the owner on 2026-06-11 and must not be reintroduced. Japa/Nanny are Dai Maa, a separate business.

**Key Methods:**
- `_buildManpowerTab()` — Service cards with category grouping
- `_buildEquipmentTab()` — Grid of equipment items
- `_navigateToBooking(service)` — Routes to booking or assessment based on bookingType

**Props:** None

---

### 13. ServiceBookingScreen
**File:** `lib/screens/services/service_booking_screen.dart`

3-step booking wizard for instant-bookable services.

**Features:**
- Step 1 — Details: Service info, pricing, duration selector, auto-renew toggle (for manpower)
- Step 2 — Slot Selection: Date picker + time slot grid
- Step 3 — Review & Payment: Promo code input, order summary, total calculation, "Pay Now" button
- Razorpay integration on confirmation
- Stepper UI with back/next navigation

**Key Methods:**
- `_submitBooking()` — Creates booking + initiates Razorpay payment
- `_applyPromoCode()` — Validates and applies coupon

**Props:**
- `service: ServiceItem`

---

### 14. AssessmentRequestScreen
**File:** `lib/screens/services/assessment_request_screen.dart`

For assessment-based services (nursing, japa, nanny). Collects info for Housepital team review.

**Features:**
- Patient health info summary
- Doctor referral details
- Urgency selector (routine, urgent, emergency)
- Attachment upload (prescriptions, referral letters)
- Message text area
- Submit button

**Key Methods:**
- `_submitAssessment()` — ApiService.assessmentRequest(data)

**Props:**
- `service: ServiceItem`

---

### 15. EquipmentDetailScreen
**File:** `lib/screens/services/equipment_detail_screen.dart`

Modal popup for equipment items.

**Features:**
- Equipment images (carousel)
- Specs table
- Pricing: Buy price vs Monthly rent (with quarterly discounts)
- Buy button → adds to cart
- Rent button → ServiceBookingScreen with equipment context
- Stock availability indicator

**Key Methods:**
- `_addToCart()` — CartProvider.addItem()

**Props:**
- `service: ServiceItem`

---

## BILLING MODULE

### 16. BillingScreen
**File:** `lib/screens/billing/billing_screen.dart`

Billing dashboard with invoice management.

**Features:**
- Summary cards: Total Due, Overdue Count, Total Paid
- Filter tabs: All, Pending, Overdue, Paid
- Invoice list with status badges, dates, amounts
- Spend summary by category (Manpower, Equipment, Diagnostics, etc.) — pie chart breakdown
- Tap invoice → InvoiceDetailScreen

**Key Methods:**
- `_loadInvoices()` — Currently uses mock data (TODO: wire API)
- `_filterInvoices(status)` — Filters invoice list by tab

**Props:** None

---

### 17. InvoiceDetailScreen
**File:** `lib/screens/billing/invoice_detail_screen.dart`

Full invoice view with line items and payment option.

**Features:**
- Invoice number and period (billing start → end)
- Line items table: description, amount, GST, total
- Subtotal, Total GST, Grand Total
- Due date with overdue highlighting
- Pay button (for pending/overdue invoices) → PaymentScreen
- Download PDF and Share buttons

**Key Methods:**
- `_loadInvoice()` — ApiService.getInvoiceDetail(invoiceId)

**Props:**
- `invoiceId: String`

---

### 18. PaymentScreen
**File:** `lib/screens/billing/payment_screen.dart`

Razorpay payment integration.

**Features:**
- Amount display
- Description text
- Razorpay modal trigger
- Success/failure handling with UI feedback
- Invoice status update on success

**Key Methods:**
- `_initiatePayment()` — PaymentService.initializePayment(amount, description)
- `_onPaymentSuccess()` — Updates invoice, shows confirmation
- `_onPaymentError()` — Shows error message

**Props:**
- `amount: int`
- `description: String`
- `invoiceId: String?`

---

### 19. TransactionLogScreen
**File:** `lib/screens/billing/transaction_log_screen.dart`

Payment transaction history.

**Features:**
- List of past transactions: date, amount, status, reference ID
- Invoice link for each transaction
- Filter by date range

**Key Methods:**
- `_loadTransactions()`

**Props:** None

---

### 20. PaymentMethodsScreen
**File:** `lib/screens/billing/payment_methods_screen.dart`

Saved payment methods.

**Features:**
- Saved cards list
- UPI IDs
- Net banking options
- Add new payment method
- Set default payment method
- Remove payment method

**Props:** None

---

## SETTINGS MODULE

### 21. SettingsScreen
**File:** `lib/screens/settings/settings_screen.dart`

Main settings hub.

**Features:**
- User profile card (name, tap to edit)
- Menu items: Patient Profile, Family Members, Medical Documents, Notification Settings, Language Toggle (EN/HI), Help & FAQ, Logout
- Language switch updates AppProvider.setLocale() and rebuilds entire app

**Key Methods:**
- `_logout()` — AuthProvider.logout()
- `_switchLanguage(locale)` — AppProvider.setLocale(locale)

**Props:** None

---

### 22. PatientProfileScreen
**File:** `lib/screens/settings/patient_profile_screen.dart`

Edit patient medical details.

**Features:**
- Fields: Name, Age, Gender, Allergies, Medical Conditions, Dietary Restrictions, Mobility Status
- Doctor info: Name, Phone, Hospital
- Emergency contacts: Add/edit/remove (name, phone, relation)
- Save button → AppProvider.updatePatient()
- Form validation

**Key Methods:**
- `_saveProfile()` — API call to update patient
- `_addEmergencyContact()` — Adds contact to list
- `_removeEmergencyContact(index)` — Removes with confirmation

**Props:** None

---

### 23. FamilyMembersScreen
**File:** `lib/screens/settings/family_members_screen.dart`

Manage family members who can access the patient's data.

**Features:**
- Family member cards: name, phone, relationship, role badge (PRIMARY_CONTACT / FAMILY_MEMBER)
- Add new member form: name, phone, email, relationship dropdown
- Edit/remove existing members
- Notification preferences per member (toggle: attendance, vitals, reports, billing)
- Primary contact indicator

**Key Methods:**
- `_loadFamilyMembers()` — API call
- `_addMember()` — Form validation + API call
- `_removeMember(id)` — Confirmation dialog + API call
- `_updateNotificationPrefs(id, prefs)` — Toggle API call

**Props:** None

---

## SUPPORT MODULE

### 24. RaiseConcernScreen
**File:** `lib/screens/support/raise_concern_screen.dart`

Submit a support ticket.

**Features:**
- Category dropdown: General, Billing, Medical, Technical
- Severity selector: Low, Medium, High, Emergency (with SLA display: Emergency 2h, High 12h, Medium 24h, Low 72h)
- Message text area
- Attachment upload (photo)
- Submit button

**Key Methods:**
- `_submitConcern()` — Creates FamilyConcern record via API

**Props:** None

---

### 25. StaffProfileScreen
**File:** `lib/screens/support/staff_profile_screen.dart`

View individual staff member profile.

**Features:**
- Photo, name, role, rating (stars)
- Reviews list with comments
- Qualifications and certifications
- Availability information
- Current deployments
- Contact button (call)
- Report concern button

**Key Methods:**
- `_loadStaffProfile()` — ApiService.getStaffProfile(staffId)

**Props:**
- `staffId: String`

---

## OTHER SCREENS

### 26. SOSScreen
**File:** `lib/screens/sos/sos_screen.dart`

Emergency contact screen with red background.

**Features:**
- Housepital Emergency: 9990911911
- Police: 112
- Medical Emergency button
- url_launcher for direct phone calls

**Props:** None

---

### 27. NotificationsScreen
**File:** `lib/screens/notifications/notifications_screen.dart`

Push notification list.

**Features:**
- Notification cards: title, message, timestamp
- Type icons (report, payment, staff, vitals)
- Dismiss/archive
- Tap → navigate to relevant screen

**Props:** None

---

### 28. CartScreen
**File:** `lib/screens/cart/cart_screen.dart`

Shopping cart for equipment purchases/rentals.

**Features:**
- Cart items: name, buy/rent label, quantity, price
- Quantity +/- buttons
- Remove item button
- Rental months selector (for rental items)
- Subtotal, Delivery charge (free over Rs.999), Total
- Checkout button → PaymentScreen

**Key Methods:**
- `_checkout()` — Navigates to PaymentScreen with total

**Props:** None

---

### 29. DocumentRepositoryScreen
**File:** `lib/screens/documents/document_repository_screen.dart`

Medical documents vault.

**Features:**
- Document cards: name, type badge (prescription/report/test/other), upload date
- Upload new document button
- Download and share options per document
- Filter by type
- Empty state

**Props:** None

---

### 30. UniversalSearchScreen
**File:** `lib/screens/search/universal_search_screen.dart`

Global search across the app.

**Features:**
- Search text field with debounce
- Result categories: medications, services, staff, reports
- Tap result → navigate to detail screen
- Recent searches

**Props:** None

---

### 31. PackageDetailScreen
**File:** `lib/screens/packages/package_detail_screen.dart`

Care package overview.

**Features:**
- Package name and description
- Services included list
- Duration and pricing
- Inclusions checklist
- "Book Now" button → ServiceBookingScreen

**Props:**
- `package: CarePackage`

---

### 32. DailyReportScreen
**File:** `lib/screens/reports/daily_report_screen.dart`

Full daily report view.

**Features:**
- Report date and staff name
- Sections: Morning Routine, Afternoon Care, Evening Care, etc.
- Task checklist with completion status per section
- Medication log for that day
- Staff notes and photos
- Vital readings logged during shift

**Key Methods:**
- `_loadReport()` — ApiService.getDailyReport(reportId)

**Props:**
- `reportId: String`

---

### 33. VitalsScreen
**File:** `lib/screens/reports/vitals_screen.dart`

Vitals chart and history.

**Features:**
- Chart (fl_chart) showing vital trends over 7d/30d/3m
- Period selector tabs
- Latest reading values with color status
- Normal ranges highlighted on chart
- Vital type selector (BP, Pulse, SpO2, Temp, Sugar)

**Key Methods:**
- `_loadVitals()` — ApiService.getVitalsHistory(patientId, period)
- `_buildChart()` — fl_chart line chart with gradient

**Props:**
- `initialVital: String?` — Optional vital type to start with

---

## User Flow Summary

| Flow | Screens Involved | Entry Point |
|------|-----------------|-------------|
| Login | Login → OTP → Onboarding → Home | App launch |
| View Dashboard | Home | Tab 0 |
| Monitor Services | Home → My Care → Service Detail | Tab 1 or Home banner |
| Check Vitals | Home (grid) → Vitals (chart) | Tap vital card |
| View Staff | Home → Staff Profile | Tap staff name |
| Manage Medications | My Care → Medications → Add/Edit | My Care tab |
| View Med Schedule | My Care → Medication Schedule | My Care tab |
| Book Service | Services → Service Booking → Payment | Tab 2 |
| Request Assessment | Services → Assessment Request | Tab 2 |
| Rent/Buy Equipment | Services → Equipment Detail → Cart → Payment | Tab 2 |
| Pay Invoice | Billing → Invoice Detail → Payment | Tab 3 |
| View Transactions | Billing → Transaction Log | Tab 3 |
| Edit Profile | Settings → Patient Profile | Tab 4 |
| Manage Family | Settings → Family Members | Tab 4 |
| Raise Concern | My Care (quick action) → Raise Concern | My Care or Home |
| Emergency | SOS button → SOS Screen | App bar |
| Search | Search icon → Universal Search | App bar |
| View Reports | My Care → Report History → Report Detail | My Care tab |
| View Attendance | My Care → Attendance History | My Care tab |

---

## Design Specifications

### Colors (from HousepitalTheme)
- **Primary:** Orange #F39314, Light #FFF3E0, Dark #CC6E00
- **Status:** Success #2E7D32, Warning #E65100, Error #D32F2F, Info #1565C0
- **Vitals:** Normal (green), Borderline (yellow), Alert (red)
- **Services:** Red (ICU), Orange (Nursing), Teal (Caretaker), Purple (Japa/Nanny), Blue (Physio), Green (Equipment)

### Typography
- **Font Family:** Archivo (Google Fonts, all weights)
- **Headlines:** 24-28px, w600-w700
- **Titles:** 18px, w600
- **Body:** 16px, w400
- **Captions:** 12px, w400

### Layout Standards
- **Padding:** 16px global, 12px internal
- **Corner Radius:** 12px cards, 8px inputs, 10px action tiles
- **SafeArea:** Applied to all screens
- **Material 3:** Enabled

### Navigation Patterns
- Bottom tabs with IndexedStack
- Named routes via onGenerateRoute
- Type-safe arguments via settings.arguments
- Global keys for cross-tab navigation

---

## File Structure

```
lib/
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── otp_screen.dart
│   │   └── onboarding_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── my_care/
│   │   ├── my_care_screen.dart
│   │   ├── service_detail_screen.dart
│   │   ├── medications_screen.dart
│   │   ├── medication_schedule_screen.dart
│   │   ├── add_edit_medication_screen.dart
│   │   ├── report_history_screen.dart
│   │   ├── attendance_history_screen.dart
│   │   └── widgets/
│   │       ├── health_manager_banner.dart
│   │       ├── active_service_card.dart
│   │       ├── staff_attendance_section.dart
│   │       ├── billing_summary_section.dart
│   │       ├── quick_actions_row.dart
│   │       ├── vitals_trend_grid.dart
│   │       ├── care_report_section.dart
│   │       └── equipment_deployed_section.dart
│   ├── services/
│   │   ├── service_catalog_screen.dart
│   │   ├── service_booking_screen.dart
│   │   ├── assessment_request_screen.dart
│   │   └── equipment_detail_screen.dart
│   ├── billing/
│   │   ├── billing_screen.dart
│   │   ├── invoice_detail_screen.dart
│   │   ├── payment_screen.dart
│   │   ├── transaction_log_screen.dart
│   │   └── payment_methods_screen.dart
│   ├── settings/
│   │   ├── settings_screen.dart
│   │   ├── patient_profile_screen.dart
│   │   └── family_members_screen.dart
│   ├── support/
│   │   ├── raise_concern_screen.dart
│   │   └── staff_profile_screen.dart
│   ├── sos/
│   │   └── sos_screen.dart
│   ├── notifications/
│   │   └── notifications_screen.dart
│   ├── cart/
│   │   └── cart_screen.dart
│   ├── documents/
│   │   └── document_repository_screen.dart
│   ├── search/
│   │   └── universal_search_screen.dart
│   ├── packages/
│   │   └── package_detail_screen.dart
│   └── reports/
│       ├── daily_report_screen.dart
│       └── vitals_screen.dart
```

---

## Summary

This document covers the complete screen implementation for the Housepital Patient App. All screens follow Material Design 3 principles and Housepital's orange-primary branding. The app is built for families monitoring home healthcare services, with emphasis on real-time visibility into staff attendance, vitals, medications, and care reports.

Total Screens: 33
Modules: 8 (Auth, Home, My Care, Services, Billing, Settings, Support, Other)
My Care Widgets: 8
