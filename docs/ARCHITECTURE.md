# Housepital System Architecture

## Overview

- Two Flutter/Dart mobile apps sharing one Firebase backend
- **Patient App:** family monitoring dashboard + service marketplace + billing
- **Staff App:** field staff operations (attendance, reports, vitals, training)
- **Admin Dashboard:** ops team management (planned, not yet built)
- Single Express.js backend deployed as a Firebase Cloud Function (`api`)
- MySQL (Cloud SQL) for relational data + Firestore for real-time features

## Tech Stack

| Layer              | Technology                                        |
|--------------------|---------------------------------------------------|
| Frontend           | Flutter 3.x / Dart                                |
| State Management   | Provider (ChangeNotifier) -- 11 providers          |
| Backend Runtime    | Node.js + Express.js (TypeScript)                  |
| Hosting            | Firebase Cloud Functions (asia-south1)             |
| Relational DB      | Cloud SQL for MySQL (asia-south1)                  |
| Real-time DB       | Cloud Firestore (5 collections)                    |
| Authentication     | Firebase Auth (phone OTP)                          |
| Payments           | Razorpay (Standard Checkout, webhook)              |
| Push Notifications | Firebase Cloud Messaging (FCM)                     |
| Offline Storage    | SharedPreferences (language, cart, addresses, cache)|
| Local Notifications| flutter_local_notifications + timezone             |
| Typography         | Bundled Archivo + NotoSansDevanagari TTFs (`assets/fonts/`; google_fonts removed) |
| PDF Generation     | `pdf` + `printing` (on-device: invoices, doctor handover) |
| HTTP Client        | `http` package (Dart)                              |
| Testing            | flutter_test (unit)                                |
| i18n               | Custom AppLocalizations (EN + HI)                  |

## Project Structure

### Patient App (`/housepital_patient_app/`)

```
lib/
 +-- main.dart                        # App entry, MultiProvider setup, route table
 +-- config/
 |   +-- constants.dart               # AppConstants (API URL, Razorpay key, vital ranges, SLAs)
 |   +-- theme.dart                   # HousepitalColors/-Dark, HousepitalTheme light + dark (Material 3)
 |   +-- app_colors.dart              # context.hc token resolver -- HcPalette light/dark
 |   +-- daimaa_theme.dart            # Dai Maa cross-promo banner colors
 |   +-- firebase_options.dart        # Firebase config (auto-generated)
 +-- models/
 |   +-- models.dart                  # Patient, Deployment, Attendance, VitalReading, etc.
 |   +-- my_care_models.dart          # ActiveService, HealthManager, ServiceDetail
 |   +-- medication_models.dart       # MedicationFull, MedicationLog
 |   +-- care_event.dart              # Care Calendar events
 |   +-- equipment_order.dart         # Orders + quote-pending bookings
 |   +-- medical_history.dart         # Read-only medical history
 |   +-- doctor_recommendation.dart   # Doctor recommendations -> cart
 |   +-- article.dart                 # Care Guides articles
 |   +-- assistant_models.dart        # Assistant actions + safe parsing
 +-- providers/
 |   +-- app_provider.dart            # AppProvider -- patient context, dashboard, language
 |   +-- auth_provider.dart           # AuthProvider -- login state, OTP flow
 |   +-- theme_provider.dart          # ThemeProvider -- ThemeMode persisted (system/light/dark)
 |   +-- billing_provider.dart        # BillingProvider -- billing summary, invoices, EMI
 |   +-- cart_provider.dart           # CartProvider -- cart + saved-for-later
 |   +-- my_care_provider.dart        # MyCareProvider -- active services, service detail
 |   +-- medication_provider.dart     # MedicationProvider -- medication CRUD + logs
 |   +-- orders_provider.dart         # OrdersProvider -- orders + quote-pending bookings + assessments
 |   +-- blog_provider.dart           # BlogProvider -- Care Guides articles (demo fallback)
 |   +-- assistant_provider.dart      # AssistantProvider -- service + executor + voice orchestration
 +-- screens/
 |   +-- main_shell.dart              # Fixed solid-orange bottom nav bar (5 tabs: Home/My Care/Services/Billing/More; calendar lives in the My Care app bar)
 |   +-- auth/
 |   |   +-- login_screen.dart
 |   |   +-- otp_screen.dart
 |   |   +-- onboarding_screen.dart
 |   +-- home/
 |   |   +-- home_screen.dart         # Dashboard tab
 |   +-- my_care/
 |   |   +-- my_care_screen.dart      # My Care tab (active services hub)
 |   |   +-- service_detail_screen.dart
 |   |   +-- medications_screen.dart
 |   |   +-- medication_schedule_screen.dart
 |   |   +-- add_edit_medication_screen.dart
 |   |   +-- report_history_screen.dart
 |   |   +-- attendance_history_screen.dart
 |   |   +-- staff_otp_verification_screen.dart  # OTP verification for staff check-in
 |   |   +-- widgets/                 # vitals_trend_grid, active_service_card, health_manager_banner, etc.
 |   +-- services/
 |   |   +-- service_catalog_screen.dart
 |   |   +-- service_booking_screen.dart
 |   |   +-- assessment_request_screen.dart
 |   |   +-- equipment_detail_screen.dart
 |   |   +-- booking_confirmation_screen.dart
 |   |   +-- my_orders_screen.dart      # Unified orders (bookings + equipment + rentals)
 |   +-- billing/
 |   |   +-- billing_screen.dart
 |   |   +-- invoice_detail_screen.dart
 |   |   +-- transaction_log_screen.dart
 |   |   +-- payment_screen.dart
 |   |   +-- payment_methods_screen.dart
 |   |   +-- emi_screen.dart            # EMI payment plans
 |   +-- cart/
 |   |   +-- cart_screen.dart
 |   +-- consultation/
 |   |   +-- video_consultation_screen.dart  # Video call with coordinator/doctor
 |   +-- chat/
 |   |   +-- chat_screen.dart           # In-app chat with coordinator
 |   +-- orders/
 |   |   +-- order_tracking_screen.dart  # Order status tracking
 |   +-- rental/
 |   |   +-- rental_agreement_screen.dart # Rental terms + digital signature
 |   |   +-- return_screen.dart          # Equipment return request
 |   +-- calendar/
 |   |   +-- care_calendar_screen.dart   # Day/Week/Month -- doses, attendance, mark taken/present
 |   +-- care_team/
 |   |   +-- care_team_screen.dart       # Group chat first, member call/chat, ambulance, past staff
 |   +-- articles/
 |   |   +-- article_list_screen.dart    # Care Guides -- featured hero + category accents
 |   |   +-- article_detail_screen.dart  # Markdown body
 |   |   +-- article_category_style.dart
 |   +-- assistant/
 |   |   +-- assistant_screen.dart       # Sahayak voice/text chat
 |   |   +-- assistant_executor.dart     # Confirm-first action execution
 |   +-- checkout/
 |   |   +-- address_selection_screen.dart
 |   +-- packages/
 |   |   +-- package_detail_screen.dart
 |   +-- reports/
 |   |   +-- daily_report_screen.dart
 |   |   +-- vitals_screen.dart
 |   +-- support/
 |   |   +-- raise_concern_screen.dart
 |   |   +-- staff_profile_screen.dart
 |   |   +-- staff_replacement_screen.dart # Request staff replacement
 |   +-- sos/
 |   |   +-- sos_screen.dart
 |   +-- notifications/
 |   |   +-- notifications_screen.dart
 |   +-- settings/
 |   |   +-- settings_screen.dart
 |   |   +-- patient_profile_screen.dart
 |   |   +-- family_members_screen.dart
 |   |   +-- notification_preferences_screen.dart
 |   |   +-- help_faq_screen.dart
 |   |   +-- about_screen.dart
 |   |   +-- referral_screen.dart       # Refer-a-friend program
 |   +-- documents/
 |   |   +-- document_repository_screen.dart
 |   +-- search/
 |       +-- universal_search_screen.dart
 +-- services/
 |   +-- api_service.dart             # All HTTP calls to backend
 |   +-- i_api_service.dart           # API service interface (for testing)
 |   +-- payment_service.dart         # Razorpay SDK wrapper
 |   +-- invoice_pdf_service.dart     # On-device invoice PDF (PRO FORMA for quote orders)
 |   +-- handover_report_service.dart # Doctor Handover PDF (role-gated export)
 |   +-- assistant_service.dart       # AI assistant backend client + Hinglish stub
 |   +-- voice_service.dart           # speech_to_text + flutter_tts wrapper
 |   +-- firebase_service.dart        # Firestore listeners
 |   +-- sync_service.dart            # Dashboard data sync
 |   +-- payment_reminder_service.dart
 |   +-- video_call_service.dart      # Video consultation (Agora/WebRTC)
 |   +-- cache_service.dart           # Offline caching with TTL
 |   +-- medication_reminder_service.dart  # Local push notifications for medication schedule
 +-- utils/
 |   +-- helpers.dart                 # Date formatting, currency helpers
 |   +-- app_localizations.dart       # i18n delegate
 |   +-- notification_router.dart     # Push notification tap -> screen routing
 |   +-- pricing.dart                 # GST, discount, commission calculations
 |   +-- vital_classifier.dart        # GREEN/YELLOW/RED vital classification
 |   +-- permissions.dart             # Role-based action gating
 |   +-- booking_state_machine.dart   # Booking status transitions
 +-- widgets/
 |   +-- glass.dart                   # Liquid Glass chrome: GlassAppBar, GlassSurface, HousepitalCard
 |   +-- document_attach_widgets.dart
 |   +-- common_widgets.dart
 |   +-- paginated_list.dart          # Reusable paginated list widget
 |   +-- assistant_fab.dart           # Assistant entry point on every tab
 +-- data/
     +-- care_packages.dart           # Static care package definitions
     +-- demo_data.dart               # Demo fallbacks when api.housepital.in unreachable
     +-- demo_articles.dart           # 28 offline Care Guides
```

## Theming & Dark Mode

- `ThemeProvider` persists `ThemeMode` (system/light/dark) to SharedPreferences;
  `MaterialApp` reads `provider.mode` and supplies both `HousepitalTheme.lightTheme`
  and `darkTheme`.
- Every brightness-sensitive color resolves through `context.hc.*`
  (`lib/config/app_colors.dart` — `HcPalette` with light and dark token sets).
  Raw `Colors.*`, hex literals and `Colors.grey.shade*` are banned by
  `scripts/check_design_consistency.sh` (allowlist inside the script). The gate also
  prints an **informational fontSize histogram** (echo-only — never fails the build)
  to surface typography drift.
- **Dark mode is true-black tonal.** One-accent color budget (orange `#F39314`).
  **`onOrange` is WHITE app-wide** (`#FFFFFF` in both light and dark `theme.dart`,
  owner decision) — all text/icons on orange fills are white. Large iOS-style
  display titles.
- `test/widgets/dark_mode_test.dart` guards the token contract in CI.

## Liquid Glass Chrome Layer

- `lib/widgets/glass.dart` is the single source of app chrome: `GlassAppBar`
  (every screen), `GlassSurface`, and `HousepitalCard`
  (squircle `RoundedSuperellipseBorder(16)`, press-scale 0.97 @ 120ms).
- Glass screens pair with `extendBodyBehindAppBar` + top scroll padding
  `MediaQuery.padding.top + kToolbarHeight`.
- **Bottom nav** (`main_shell.dart`): FIXED full-width solid-orange bar, white
  icons, SafeArea-padded (owner iterated floating-glass → pill → fixed). Six root
  tabs (Calendar added at index 3 — indices 1/2 referenced externally).
- **Nav contract:** back on the left (or HOME leftmost on non-Home root tabs);
  trailing order `[custom…, home, search, cart]` with the **CART always rightmost**
  and a live item-count badge. `showSearch`/`showCart`/`showHome` default on; the
  purchase funnel (cart/checkout/payment) opts out of the cart icon; Billing shows
  no cart; SOS is the home-screen far-right exception.
- **`ProductImage`** (`lib/widgets/common_widgets.dart`) is the shared image
  renderer for equipment: asset path → `Image.asset`, URL → `CachedNetworkImage`,
  else fallback icon. Used by both the grid card and the detail sheet so bundled
  product photos in `assets/images/products/` render in both places (320/351 items
  have images; ~31 generic items show the icon).

## PDF Generation Layer

- All PDFs are generated **on-device** with the `pdf` + `printing` packages —
  no backend dependency:
  - `invoice_pdf_service.dart` — invoices; quote-pending orders (items that
    genuinely lack a price) render as PRO FORMA **without amounts**.
  - `handover_report_service.dart` — Doctor Handover report; role-gated
    (sensitive export).
- Both services accept an injected `DateTime` for deterministic tests.

## Payments & Assistant

- **Payments** (`payment_service.dart`): runs in **demo mode** when the Razorpay key
  is a placeholder (`rzp_test_XXXXXXXXXX` / `rzp_test_dummy`) — `openCheckout`
  simulates the checkout locally so the full purchase flow stays demoable. A real key
  via `--dart-define=RAZORPAY_KEY=…` enables real checkout. The CI key
  `rzp_test_ci_dummy_key` is deliberately NOT a placeholder (it un-skips the
  real-checkout test groups). Manpower books at rate-card prices via this same path.
- **Sahayak assistant**: demo builds use a local Hinglish intent matcher/executor
  (`assistant_service.dart` + `assistant_local_actions.dart`) that really executes
  add-to-cart / booking offline; the Cloud Function (Claude) is used when
  `ASSISTANT_API_URL` is set.

### Backend (`/housepital-backend/`)

```
functions/src/
 +-- index.ts                 # Express app, route mounting, Cloud Function export
 +-- config/
 |   +-- firebase.ts          # Firebase Admin SDK init
 |   +-- cloudSql.ts          # Knex MySQL connection pool
 |   +-- razorpay.ts          # Razorpay SDK instance
 +-- middleware/
 |   +-- auth.ts              # verifyAuth, requirePrimary, verifyPatientAccess
 |   +-- errorHandler.ts      # Global error handler
 +-- routes/
     +-- auth.ts              # /auth/*          (verify-otp, onboarding, fcm-token)
     +-- patients.ts          # /patients/*       (CRUD, dashboard, vitals, reports, etc.)
     +-- deployments.ts       # /deployments/*    (service-detail, attendance)
     +-- staff.ts             # /staff/*          (profile)
     +-- reports.ts           # /reports/*        (report detail)
     +-- family.ts            # /patients/:id/family/*  + /family/:id/remove (legacy)
     +-- services.ts          # /services/*       (catalog)
     +-- bookings.ts          # /bookings (POST)  + /patients/:id/bookings (GET)
     +-- assessments.ts       # /assessments (POST) + /patients/:id/assessments (GET)
     +-- billing.ts           # /patients/:id/billing, /invoices/:id, /transactions/:id
     +-- payments.ts          # /payments/*       (create-order, verify, webhook)
     +-- concerns.ts          # /concerns (POST)  + /patients/:id/concerns (GET)
     +-- ratings.ts           # /ratings (POST)
     +-- notifications.ts     # /notifications/*  (list, read, read-all)
     +-- equipment.ts         # /equipment/*      (catalog)
     +-- medications.ts       # /patients/:id/medications, /medication-logs, stock
     +-- coupons.ts           # /coupons/*        (validate, list)

sql/
 +-- 001_initial_schema.sql   # 20 MySQL tables

firestore.rules                # 5 Firestore collection security rules
```

## Environment Config

| Variable                | Description                               | Location             |
|-------------------------|-------------------------------------------|----------------------|
| Firebase Project ID     | Cloud project identifier                  | firebase.json        |
| API Base URL            | Cloud Function endpoint                   | constants.dart       |
| Razorpay Key ID         | Payment gateway (test/live)               | constants.dart / env |
| Razorpay Key Secret     | Server-side payment verification          | Cloud Function env   |
| Cloud SQL connection    | MySQL host/user/pass/db                   | cloudSql.ts / env    |

- API URL format: `https://asia-south1-<project-id>.cloudfunctions.net/api/<route>`
- Current API base in constants.dart: `https://api.housepital.in/v1`
- Cloud Function region: `asia-south1`
- Cloud Function memory: `256MB`, timeout: `60s`

## Data Flow Diagram

```
Flutter Patient App
       |
       | HTTPS (Bearer token)
       v
Firebase Cloud Functions (Express.js)
       |
       +-------> Cloud SQL MySQL (relational data)
       |           - patients, family_members, staff
       |           - bookings, payments, invoices
       |           - vitals, daily_reports, attendance
       |           - medications, concerns, ratings
       |           - service_catalog, equipment_catalog
       |           - coupons, coupon_usage
       |           - notification_log, fcm_tokens
       |
       +-------> Cloud Firestore (real-time data)
       |           - user_patients (auth mapping)
       |           - active_sessions (live attendance)
       |           - vitals_live (real-time vitals)
       |           - chat_messages (coordinator chat)
       |           - notifications (in-app)
       |
       +-------> Razorpay API
       |           - Create orders
       |           - Verify payments
       |           - Receive webhooks
       |
       +-------> Firebase Auth
                   - Phone OTP verification
                   - ID token generation/validation

Razorpay ----webhook----> /payments/webhook (signature verified)
```

## External Service Dependencies

| Service          | Purpose                        | Status    | Config Location              |
|------------------|--------------------------------|-----------|------------------------------|
| Firebase Auth    | Phone OTP authentication       | Active    | firebase.json + config/      |
| Cloud SQL MySQL  | Relational data storage        | Active    | cloudSql.ts + env vars       |
| Cloud Firestore  | Real-time data (5 collections) | Active    | firestore.rules              |
| Razorpay         | Payment gateway                | Test mode | constants.dart + razorpay.ts |
| FCM              | Push notifications             | Active    | firebase.json                |
| Crashlytics/Perf | Crash + performance monitoring | Active (guarded: mobile-only, release-only) | main.dart |

(Fonts are no longer an external dependency — Archivo + NotoSansDevanagari are
bundled TTFs in `assets/fonts/`; google_fonts was removed.)

## State Management

Ten `ChangeNotifierProvider` instances initialized in `main.dart`:

| Provider              | Scope                          | Key State                                      |
|-----------------------|--------------------------------|------------------------------------------------|
| `AuthProvider`        | Login, OTP, session            | AuthState, user profile, Firebase token         |
| `AppProvider`         | Global app state               | Current patient, dashboard data, locale          |
| `BillingProvider`     | Billing + payments             | Billing summary, invoices, EMI plans, transactions |
| `CartProvider`        | Shopping cart                  | List<CartItem> with index-based ops, SharedPreferences persistence. Flat CartItem model (no nested EquipmentItem). |
| `MyCareProvider`      | Active services hub            | Active services list, service detail, staff      |
| `MedicationProvider`  | Medication management          | Medication list, logs, stock, reminders          |
| `OrdersProvider`      | Orders + assessments           | Order list (incl. quote-pending manpower bookings), assessment list, SharedPreferences persistence; demo orders seeded in-memory only |
| `ThemeProvider`       | Appearance                     | ThemeMode (system/light/dark), persisted to SharedPreferences |
| `BlogProvider`        | Care Guides                    | Article list/detail with offline demo fallback   |
| `AssistantProvider`   | AI assistant                   | Conversation state, action execution (confirm-first), voice |

### Auth Middleware Stack (Backend)

| Middleware             | Purpose                                                |
|------------------------|--------------------------------------------------------|
| `verifyAuth`           | Validates Firebase ID token, attaches uid/role/patientId|
| `verifyPatientAccess`  | Ensures URL patientId matches authenticated user's patient|
| `requirePrimary`       | Blocks non-PRIMARY_CONTACT users from write operations |

**Update rule:** Every time a new service, library, or structural change is made, this file MUST be updated in the same session.

## Patient scoping, demo honesty and storage versioning (2026-08-03)

Four small pieces added after the eleven-checklist audit. Each exists because
the audit found a specific failure; keep the reason attached to the code.

| File | Responsibility | Why it exists |
|---|---|---|
| `lib/utils/session_scope.dart` | The single list of everything scoped to ONE patient, cleared together | `switchPatient` and `logout` reset nothing, so patient A's deployment, vitals, medications, orders and amount due rendered under patient B's name. The app is shared between a patient, a primary contact and family members, so this is a PHI leak, not a caching detail. **When anything gains patient-scoped state — a provider field, a prefs key, a cache entry — add it here in the same edit and assert it in `test/providers/patient_scope_isolation_test.dart`.** The first version of this file was written from a symptom list and missed five stores. |
| `lib/data/demo_mode.dart` | Tracks WHICH sources are serving bundled sample data | The app falls back to `DemoData` when `api.housepital.in` is unreachable, which is a good demo property and a dangerous clinical one. A set of named sources, not a bool: a single global flag let one provider's recovery take the warning down while others still served samples. |
| `lib/widgets/demo_data_banner.dart` | Renders that state on EVERY route | Installed from `MaterialApp.builder`, above the Navigator — in `MainShell` it missed every pushed clinical screen and double-counted the top safe-area inset. It owns the status-bar inset and removes it from the child. |
| `lib/services/store_migrator.dart` | Stamps and migrates local storage | 13 SharedPreferences namespaces were bare JSON with no version. Free to fix before the first public release, effectively impossible after. Runs in `main()` **before** the providers are constructed, because they read storage in their constructors. Never throws — it sits before `runApp`, where an exception is a black screen rather than a crash report. |

`lib/screens/settings/delete_account_screen.dart` (route `/delete-account`) is
the App Store 5.1.1(v) / DPDP §12 deletion path. It records a durable local
request, deletes the Firebase credential, wipes local data, and then states
separately what is **done** and what is **requested** — it must never claim a
server-side erasure the app cannot perform.

`storage.rules` covers chat and concern-evidence photo uploads. Read the
header before changing the ownership model: the client never reads a Firebase
uid, so `request.auth.uid == patientId` is always false and would deny every
upload.
