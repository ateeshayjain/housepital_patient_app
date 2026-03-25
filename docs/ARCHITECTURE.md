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
| State Management   | Provider (ChangeNotifier) -- 6 providers           |
| Backend Runtime    | Node.js + Express.js (TypeScript)                  |
| Hosting            | Firebase Cloud Functions (asia-south1)             |
| Relational DB      | Cloud SQL for MySQL (asia-south1)                  |
| Real-time DB       | Cloud Firestore (5 collections)                    |
| Authentication     | Firebase Auth (phone OTP)                          |
| Payments           | Razorpay (Standard Checkout, webhook)              |
| Push Notifications | Firebase Cloud Messaging (FCM)                     |
| Offline Storage    | SharedPreferences (language, cart, addresses, cache)|
| Local Notifications| flutter_local_notifications + timezone             |
| Typography         | Google Fonts (Archivo)                             |
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
 |   +-- theme.dart                   # HousepitalColors, HousepitalTheme (Material 3)
 |   +-- firebase_options.dart        # Firebase config (auto-generated)
 +-- models/
 |   +-- models.dart                  # Patient, Deployment, Attendance, VitalReading, etc.
 |   +-- my_care_models.dart          # ActiveService, HealthManager, ServiceDetail
 |   +-- medication_models.dart       # MedicationFull, MedicationLog
 +-- providers/
 |   +-- app_provider.dart            # AppProvider -- patient context, dashboard, language
 |   +-- auth_provider.dart           # AuthProvider -- login state, OTP flow
 |   +-- billing_provider.dart        # BillingProvider -- billing summary, invoices, EMI
 |   +-- cart_provider.dart           # CartProvider -- cart + saved-for-later
 |   +-- my_care_provider.dart        # MyCareProvider -- active services, service detail
 |   +-- medication_provider.dart     # MedicationProvider -- medication CRUD + logs
 +-- screens/
 |   +-- main_shell.dart              # Bottom nav bar (5 tabs)
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
 |   +-- document_attach_widgets.dart
 |   +-- common_widgets.dart
 |   +-- paginated_list.dart          # Reusable paginated list widget
 +-- data/
     +-- care_packages.dart           # Static care package definitions
```

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
- Current API base in constants.dart: `https://api.housepital.com/v1`
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
| Google Fonts     | Archivo typeface               | Active    | pubspec.yaml                 |

## State Management

Six `ChangeNotifierProvider` instances initialized in `main.dart`:

| Provider              | Scope                          | Key State                                      |
|-----------------------|--------------------------------|------------------------------------------------|
| `AuthProvider`        | Login, OTP, session            | AuthState, user profile, Firebase token         |
| `AppProvider`         | Global app state               | Current patient, dashboard data, locale          |
| `BillingProvider`     | Billing + payments             | Billing summary, invoices, EMI plans, transactions |
| `CartProvider`        | Shopping cart                  | List<CartItem> with index-based ops, SharedPreferences persistence. Flat CartItem model (no nested EquipmentItem). |
| `MyCareProvider`      | Active services hub            | Active services list, service detail, staff      |
| `MedicationProvider`  | Medication management          | Medication list, logs, stock, reminders          |

### Auth Middleware Stack (Backend)

| Middleware             | Purpose                                                |
|------------------------|--------------------------------------------------------|
| `verifyAuth`           | Validates Firebase ID token, attaches uid/role/patientId|
| `verifyPatientAccess`  | Ensures URL patientId matches authenticated user's patient|
| `requirePrimary`       | Blocks non-PRIMARY_CONTACT users from write operations |

**Update rule:** Every time a new service, library, or structural change is made, this file MUST be updated in the same session.
