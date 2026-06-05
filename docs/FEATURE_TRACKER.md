# Feature Tracker -- Housepital Patient App

**Last updated:** 2026-06-05

Legend: Done = feature is shipped and working | In Progress = partially built | Not Started = not yet coded

---

## Authentication and Onboarding

| # | Feature                            | Frontend         | Backend          | Status         | Notes                                              |
|---|-------------------------------------|------------------|------------------|----------------|----------------------------------------------------|
| 1 | Phone OTP Login (Firebase Auth)     | LoginScreen      | /auth/verify-otp | Done           | Firebase Auth phone provider                       |
| 2 | OTP Verification Screen             | OtpScreen        | --               | Done           | pin_code_fields, 6-digit input                     |
| 3 | New User Onboarding                 | OnboardingScreen | /auth/onboarding | Done           | Creates patient + family_member + Firestore mapping|
| 4 | FCM Token Registration              | AuthProvider     | /auth/fcm-token  | Done           | Token stored, but notification routing not wired   |
| 5 | Session Persistence                 | AuthProvider     | --               | Done           | Firebase Auth session persists across app restarts  |
| 6 | Multi-patient Support               | --               | Schema supports  | Not Started    | DB supports multiple patients per user, UI does not|

---

## Dashboard (Home Tab)

| # | Feature                            | Frontend         | Backend                     | Status         | Notes                                    |
|---|-------------------------------------|------------------|---------------------------- |----------------|------------------------------------------|
| 1 | Dashboard Hub                       | HomeScreen       | /patients/:id/dashboard     | Done           | All cards rendering with live data       |
| 2 | Attendance Card                     | HomeScreen       | attendance_today endpoint   | Done           | Color-coded status badges                |
| 3 | Vitals Snapshot Card                | HomeScreen       | latest_vitals endpoint      | Done           | GREEN/YELLOW/RED classification           |
| 4 | Daily Report Progress Card          | HomeScreen       | report_summary in dashboard | Done           | Completion percentage bar                |
| 5 | Billing Due Card                    | HomeScreen       | billing_summary in dashboard| Done           | Pending amount with "Pay Now" CTA        |
| 6 | Active Services Count               | HomeScreen       | active_services_count       | Done           |                                          |
| 7 | Quick Actions (SOS, Search, etc.)   | HomeScreen       | --                          | Done           | Expanded Wrap grid; Care Guides tile added |
| 8 | Pull-to-Refresh                     | HomeScreen       | --                          | Done           | Triggers full dashboard reload             |
| 9 | Home Layout B (Team first)          | HomeScreen       | --                          | Done (2026-06) | Health Team first; hero demoted to bottom  |
| 10| AI Assistant FAB                    | AssistantFab     | /assistant (stub)           | Done (2026-06) | ✨ floating button → voice/text Hinglish bot |
| 11| Care Guides tile                    | HomeScreen       | /articles (stub)            | Done (2026-06) | Navigates to article list screen           |

---

## AI Assistant

| # | Feature                            | Frontend                     | Backend               | Status         | Notes                                             |
|---|-------------------------------------|------------------------------|-----------------------|----------------|---------------------------------------------------|
| 1 | Text chat                           | AssistantScreen              | /assistant (stub)     | Done (2026-06) | Message bubbles, Hinglish stub works              |
| 2 | Voice input (mic)                   | VoiceService (PluginVoice)   | --                    | Done (2026-06) | speech_to_text; no-op on web (kIsWeb guard)       |
| 3 | Voice output (TTS)                  | VoiceService                 | --                    | Done (2026-06) | flutter_tts; no-op on web                         |
| 4 | Billing query tool                  | AssistantExecutor            | getBillingSummary     | Done (2026-06) | "iss mahine ka bill kitna hai"                    |
| 5 | Duty-days query tool                | AssistantExecutor            | getAttendanceHistory  | Done (2026-06) | "staff kitne din aaya"; period filtered client-side|
| 6 | Place-call tool                     | AssistantExecutor            | url_launcher tel:     | Done (2026-06) | Confirm-before-act; name+number confirmation card |
| 7 | Navigate tool                       | AssistantExecutor            | Navigator.pushNamed   | Done (2026-06) | Light inline confirm; benign, reversible           |
| 8 | Permission gating                   | AssistantExecutor            | --                    | Done (2026-06) | Respects canUserPerform role matrix               |
| 9 | Backend /assistant endpoint         | AssistantService.useStub     | housepital-backend    | Not Started    | Stub mode active; LLM + tool-routing on backend   |

---

## Care Guides (Education)

| # | Feature                            | Frontend                     | Backend               | Status         | Notes                                             |
|---|-------------------------------------|------------------------------|-----------------------|----------------|---------------------------------------------------|
| 1 | Article list screen                 | ArticleListScreen            | /articles (stub)      | Done (2026-06) | Category chip, read-time, shimmer loading         |
| 2 | Article detail screen               | ArticleDetailScreen          | /articles/:id (stub)  | Done (2026-06) | flutter_markdown body, share button               |
| 3 | Demo articles (28 offline)          | demo_articles.dart           | --                    | Done (2026-06) | 7 categories, JSON-backed const, kDemoArticlesJson|
| 4 | BlogProvider with fallback          | BlogProvider                 | /articles             | Done (2026-06) | Demo fallback when API unavailable                |
| 5 | Backend /articles endpoint          | --                           | housepital-backend    | Not Started    | App builds against demo data until live           |

---

## My Care Tab

| # | Feature                            | Frontend                 | Backend                          | Status         | Notes                                    |
|---|-------------------------------------|--------------------------|----------------------------------|----------------|------------------------------------------|
| 1 | Active Services Hub                 | MyCareScreen             | /patients/:id/active-services    | Done           | Lists all active deployments as cards    |
| 2 | Health Manager Banner               | HealthManagerBanner      | /patients/:id/health-manager     | Done           | Quick call/chat with coordinator         |
| 3 | Active Service Card                 | ActiveServiceCard        | --                               | Done           | Status, days consumed, vitals badge      |
| 4 | Quick Actions Row                   | QuickActionsRow          | --                               | Done           | SOS, Concern, Documents, Medications     |
| 5 | Vitals Trend Grid                   | VitalsTrendGrid          | service-detail vitals_summary    | Done           | 4-vital sparkline grid                   |
| 6 | Staff Attendance Section            | StaffAttendanceSection   | attendance in service-detail     | Done           | Today's check-in status                  |
| 7 | Care Report Section                 | CareReportSection        | today_report in service-detail   | Done           | Task completion with progress bar        |
| 8 | Billing Summary Section             | BillingSummarySection    | billing_summary                  | Done           | Outstanding amount for this service      |
| 9 | Equipment Deployed Section          | EquipmentDeployedSection | equipment in service-detail      | Done           | List of deployed equipment               |
| 10| Service Detail Screen               | ServiceDetailScreen      | /deployments/:id/service-detail  | Done           | Full drill-down for one active service   |
| 11| Attendance History                  | AttendanceHistoryScreen  | /deployments/:id/attendance      | Done           | Paginated attendance records             |
| 12| Report History                      | ReportHistoryScreen      | /patients/:id/reports            | Done           | Paginated daily reports                  |

---

## Medications

| # | Feature                            | Frontend                    | Backend                              | Status         | Notes                                |
|---|-------------------------------------|-----------------------------|--------------------------------------|----------------|--------------------------------------|
| 1 | Medication List                     | MedicationsScreen           | GET /patients/:id/medications        | Done           | Active meds with stock indicators    |
| 2 | Add Medication                      | AddEditMedicationScreen     | POST /patients/:id/medications       | Done           | Full form with schedule, stock       |
| 3 | Edit Medication                     | AddEditMedicationScreen     | PUT /patients/:id/medications/:id    | Done           |                                      |
| 4 | Delete Medication (soft)            | MedicationsScreen           | DELETE /patients/:id/medications/:id | Done           | Sets is_active = false               |
| 5 | Medication Schedule (today)         | MedicationScheduleScreen    | GET /patients/:id/medication-logs    | Done           | Timeline view of today's doses       |
| 6 | Stock Management                    | MedicationsScreen           | PUT /medications/:id/stock           | Done           | Update stock count                   |
| 7 | Low Stock Alert                     | --                          | --                                   | Not Started    | Push notification when stock < threshold |
| 8 | Prescription Photo Upload           | AddEditMedicationScreen     | --                                   | In Progress    | Field exists, upload not connected   |
| 9 | Medication Reminders (local push)   | medication_reminder_service | flutter_local_notifications          | Done           | Local push at 8AM/1PM/6PM/10PM schedule |

---

## Services Tab (Marketplace)

| # | Feature                            | Frontend                 | Backend              | Status         | Notes                                        |
|---|-------------------------------------|--------------------------|----------------------|----------------|----------------------------------------------|
| 1 | Service Catalog (7 sub-tabs)        | ServiceCatalogScreen     | GET /services        | Done           | Manpower, Equipment, Consults, Visits, Diag, Lab, Packages |
| 2 | Service Booking Wizard (3-step)     | ServiceBookingScreen     | POST /bookings       | Done           | Slot select, promo, review, pay              |
| 3 | Assessment Request Flow             | AssessmentRequestScreen  | POST /assessments    | Done           | Dynamic questionnaire per category           |
| 4 | Equipment Detail Page               | EquipmentDetailScreen    | GET /equipment       | Done           | Variant selection, rent/buy, add-to-cart     |
| 5 | Package Detail Page                 | PackageDetailScreen      | --                   | Done           | Static care package info                     |
| 6 | Promo Code Validation               | ServiceBookingScreen     | POST /coupons/validate | Done         | Coupon system fully wired in cart + booking  |
| 7 | Cart System                         | CartScreen               | --                   | Done -- rewritten | Flat CartItem model, List-based CartProvider with index-based ops, SharedPreferences persistence, coupon support (WELCOME10). Rewritten 2026-03-25 to fix grey screen / empty cart bugs. |
| 8 | Universal Search                    | UniversalSearchScreen    | --                   | Done           | Local search across services                 |
| 9 | Manpower Price Display              | ServiceCatalogScreen     | master Excel sync    | Done           | Prices now shown (synced from master Excel). MRP + strikethrough on equipment. |
| 10| Slot Availability Check             | ServiceBookingScreen     | GET /services/:id/slots | Done        | getAvailableSlots API checks real-time availability |
| 11| Booking Cancellation                | BookingHistoryScreen     | PUT /bookings/:id/cancel | Done       | Cancel from booking history with confirmation dialog |
| 12| Post-Service Rating                 | BookingHistoryScreen     | POST /ratings        | Done           | Rate completed bookings from booking history |
| 13| Booking Confirmation Screen         | BookingConfirmationScreen| --                   | Done           | Animated confirmation with booking ID, share, next steps |
| 14| Booking History                     | BookingHistoryScreen     | GET /patients/:id/bookings | Done     | Filter by status, cancel, rate, re-book      |
| 15| Address Selection (checkout)        | AddressSelectionScreen   | SharedPreferences    | Done           | Saved addresses, pincode validation, add/edit/delete |
| 16| My Orders                          | MyOrdersScreen           | OrdersProvider       | Done           | Done -- reads from OrdersProvider                    |

---

## Billing Tab

| # | Feature                            | Frontend               | Backend                          | Status         | Notes                                    |
|---|-------------------------------------|------------------------|----------------------------------|----------------|------------------------------------------|
| 1 | Billing Dashboard                   | BillingScreen          | /patients/:id/billing/summary    | Done           | Done -- reads from OrdersProvider        |
| 2 | Invoice List                        | BillingScreen          | /patients/:id/invoices           | Done           | Paginated invoices                       |
| 3 | Invoice Detail                      | InvoiceDetailScreen    | /invoices/:id                    | Done           | Line items, amounts, status              |
| 4 | Transaction Log                     | TransactionLogScreen   | /patients/:id/transactions       | Done           | Payment history with status badges       |
| 5 | Razorpay Payment                    | PaymentScreen          | /payments/create-order + verify  | Done           | Done -- web simulation mode              |
| 6 | Payment Webhook Handler             | --                     | /payments/webhook                | Done           | payment.captured, payment.failed, refund |
| 7 | Invoice PDF Download                | InvoiceDetailScreen    | --                               | Not Started    | Button exists, shows "Coming soon"       |
| 8 | Payment Methods Management          | PaymentMethodsScreen   | --                               | Not Started    | Placeholder screen                       |
| 9 | EMI Payment Support                 | EmiScreen              | BillingProvider                  | Done           | EMI plan display, installment tracking   |
| 10| Payment Reminders (push)            | --                     | --                               | Not Started    | PaymentReminderService exists but not connected to FCM |
| 11| Overdue Payment Blocking            | --                     | --                               | Not Started    | Business rule: block new bookings if overdue |

---

## Reports

| # | Feature                            | Frontend             | Backend                    | Status         | Notes                                    |
|---|-------------------------------------|----------------------|----------------------------|----------------|------------------------------------------|
| 1 | Daily Report View                   | DailyReportScreen    | /reports/:id               | Done           | Sections, tasks, photos, medications     |
| 2 | Report History (paginated)          | ReportHistoryScreen  | /patients/:id/reports      | Done           |                                          |
| 3 | Vitals Charts (7d/30d/90d)          | VitalsScreen         | /patients/:id/vitals       | Done           | fl_chart with period selector            |
| 4 | Vitals Trend Sparklines             | VitalsTrendGrid      | vitals_summary in API      | Done           | 4-vital mini charts                      |
| 5 | Vitals Alert Notifications          | --                   | --                         | Not Started    | RED vital should trigger push/SMS/WA     |
| 6 | Weekly Summary Report               | --                   | --                         | Not Started    | Aggregated weekly summary for family     |

---

## Support

| # | Feature                            | Frontend               | Backend                  | Status         | Notes                                    |
|---|-------------------------------------|------------------------|--------------------------|----------------|------------------------------------------|
| 1 | Raise a Concern                     | RaiseConcernScreen     | POST /concerns           | Done           | Evidence upload fixed, real API submission |
| 2 | Concern History                     | --                     | GET /patients/:id/concerns | Done (API)   | API exists, no dedicated history screen  |
| 3 | Staff Profile                       | StaffProfileScreen     | /staff/:id/profile       | Done           | Verification badges, reviews             |
| 4 | SOS Emergency                       | SOSScreen              | --                       | Done           | Call ambulance + 112                     |
| 5 | Coordinator Chat                    | ChatScreen             | Firestore chat_messages  | Done           | Real-time in-app chat with coordinator   |
| 6 | Staff Replacement Request           | StaffReplacementScreen | POST /replacements       | Done           | Request replacement with reason          |
| 7 | Daily Care Rating                   | --                     | POST /ratings            | Not Started    | Backend ready, no UI                     |

---

## Settings and Profile

| # | Feature                            | Frontend                  | Backend                        | Status         | Notes                                 |
|---|-------------------------------------|---------------------------|--------------------------------|----------------|---------------------------------------|
| 1 | Settings Hub                        | SettingsScreen            | --                             | Done           | All dead ends wired to real screens   |
| 2 | Patient Profile (view/edit)         | PatientProfileScreen      | GET/PUT /patients/:id          | Done           | Real API save, city dropdown list     |
| 3 | Family Members Management           | FamilyMembersScreen       | /patients/:id/family           | Done           | Add, edit, remove (not PRIMARY)       |
| 4 | Document Repository                 | DocumentRepositoryScreen  | --                             | Done           | Search, share, open documents         |
| 5 | Notification Preferences            | NotificationPreferencesScreen | SharedPreferences          | Done           | Toggleable + forced-ON notification types |
| 6 | Language Toggle (EN/HI)             | SettingsScreen            | preferred_language in DB       | Done           | AppProvider.locale + AppLocalizations |
| 7 | Help / FAQ                          | HelpFaqScreen             | --                             | Done           | 20 FAQs, search, categories, contact support |
| 8 | Terms & Privacy Policy              | AboutScreen               | --                             | Done           | Links to terms/privacy in About screen |
| 9 | App Version Info                    | AboutScreen               | --                             | Done           | Company info, version, social links   |
| 10| Logout                             | SettingsScreen            | --                             | Done           | Firebase Auth sign out                |

---

## Notifications

| # | Feature                            | Frontend                | Backend                    | Status         | Notes                                    |
|---|-------------------------------------|-------------------------|----------------------------|----------------|------------------------------------------|
| 1 | Notification List                   | NotificationsScreen     | GET /notifications         | Done           | Paginated with read/unread status        |
| 2 | Mark as Read                        | NotificationsScreen     | PUT /notifications/:id/read| Done           |                                          |
| 3 | Mark All as Read                    | NotificationsScreen     | PUT /notifications/read-all| Done           |                                          |
| 4 | FCM Token Registration              | AuthProvider            | POST /auth/fcm-token       | Done           |                                          |
| 5 | Push Notification Display            | --                     | --                         | Done           | FCM shows system notification            |
| 6 | Notification Tap Routing            | notification_router.dart | --                        | Done           | Push notification taps route to correct screen |
| 7 | SMS/WhatsApp Notifications          | --                      | --                         | Not Started    | MSG91 integration not connected          |

---

## Cross-Cutting Concerns

| # | Feature                            | Status         | Notes                                                |
|---|-------------------------------------|----------------|------------------------------------------------------|
| 1 | Localization (EN + HI)              | Done           | 90+ Hindi translation keys added, near-complete      |
| 2 | Offline Support                     | Done           | cache_service with TTL, SharedPreferences persistence |
| 3 | Error Handling (global)             | Done           | Backend global error handler + Flutter error UI      |
| 4 | Loading States                      | Done           | Most screens have loading indicators                 |
| 5 | Empty States                        | In Progress    | Some screens have empty states, some do not          |
| 6 | WCAG Accessibility                  | In Progress    | Colors are AA compliant, semantic labels partial     |
| 7 | Analytics / Event Tracking          | Not Started    |                                                      |
| 8 | Crash Reporting (Crashlytics)       | Not Started    |                                                      |
| 9 | Deep Linking                        | Not Started    |                                                      |
| 10| App Performance Monitoring          | Not Started    |                                                      |
| 11| Rate Limiting (backend)             | Done           | express-rate-limit applied to all endpoints          |
| 12| Structured Logging (backend)        | Done           | Structured logging with correlation IDs              |
| 13| Zod Validation (backend)            | Done           | Request payload validation with Zod schemas          |
| 14| CORS Restriction (backend)          | Done           | CORS restricted to allowed origins                   |
| 15| Retry with Backoff (frontend)       | Done           | API calls retry with exponential backoff             |
| 16| Pagination Widget                   | Done           | Reusable PaginatedList widget in lib/widgets/        |
| 17| Video Consultation                  | Done           | VideoConsultationScreen + video_call_service          |
| 18| Referral Program                    | Done           | ReferralScreen with share code + reward tracking     |

---

## Blocked Items

| Feature                    | Blocked By                                            | Owner   |
|----------------------------|-------------------------------------------------------|---------|
| Invoice PDF generation     | Razorpay live mode approval pending + pdfkit backend  | Founder |
| WhatsApp notifications     | MSG91 template approval from WhatsApp                 | Founder |
| ~~Lab test catalog (detailed)~~| ~~Lab partner pricing not finalized~~ (RESOLVED -- 153 individual tests added) | Ops |
| Razorpay production mode   | Business verification with Razorpay                   | Founder |
| Multi-patient support UI   | Product decision on UX flow                           | Founder |

---

**Update rule:** Update after every feature ships or every session, whichever is more frequent.
