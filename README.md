# Housepital Patient App — Flutter + Firebase

[![CI](https://github.com/ateeshayjain/housepital_patient_app/actions/workflows/ci.yml/badge.svg)](https://github.com/ateeshayjain/housepital_patient_app/actions/workflows/ci.yml)

A mobile app for Housepital's patients and their families across Delhi NCR.
Replaces phone-call-based monitoring with structured, transparent visibility into all active home healthcare services.

## Quick Links

| Resource | Link |
|---|---|
| Project meta / onboarding | [PROJECT.md](./PROJECT.md) |
| Contributing | [CONTRIBUTING.md](./CONTRIBUTING.md) |
| Open PRs | <https://github.com/ateeshayjain/housepital_patient_app/pulls> |
| Architecture | [ARCHITECTURE.md](./ARCHITECTURE.md) |
| API reference | [docs/API_REFERENCE.md](./docs/API_REFERENCE.md) |
| AI Assistant backend | [functions/README.md](./functions/README.md) |
| Known issues | [docs/KNOWN_ISSUES.md](./docs/KNOWN_ISSUES.md) |
| Troubleshooting | [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) |
| Deployment | [docs/DEPLOYMENT_GUIDE.md](./docs/DEPLOYMENT_GUIDE.md) |

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Framework | **Flutter 3.16+** (Dart) | Cross-platform, shared codebase with staff app |
| Backend | **Firebase** (Cloud Functions + Cloud SQL MySQL + Firestore) | Functions serve the API; MySQL is the system of record; Firestore for realtime/auth mapping |
| State | **Provider** (ChangeNotifier) | Simple, sufficient, matches staff app patterns |
| Auth | **Firebase Auth** (Phone OTP) | Firebase ecosystem for patient-facing app |
| Push | **Firebase Cloud Messaging** | Real-time alerts for attendance, vitals, reports |
| AI Assistant | **Claude** via Firebase Cloud Function (`functions/`) | Sahayak — Hinglish voice/text bot; key held as a Firebase secret |
| Charts | **fl_chart** | Vitals sparklines in My Care tab |
| Payments | **Razorpay** | Indian payment gateway (cards, UPI, netbanking) |
| Fonts | **Archivo** (Google Fonts) | Per Housepital Brand Guidelines V1 |
| Colors | **#F39314** (Primary Orange) | Per Brand Guidelines |
| Localization | **English + Hindi** | Custom AppLocalizations with JSON assets |
| Loading | **Shimmer** | Skeleton loading animations |

## Quick Stats

- **45+ Dart source files** | **15,000+ lines of code**
- **72 test files** | **1407 unit tests** | **2,900+ test LOC**
- **5 bottom tabs** (Home, My Care, Services, Billing, Settings)
- **25+ screens** with full EN/HI localization
- **30+ named routes** in onGenerateRoute

---

## How to Run

### Prerequisites

1. Flutter SDK 3.16+
2. Firebase project (for Auth + FCM)
3. Android Studio or VS Code with Flutter extension

### Steps

```bash
git clone git@github.com:ateeshayjain/housepital_patient_app.git
cd housepital_patient_app
flutter pub get

# Drop Firebase config files in place (distributed via secure channel —
# these are gitignored as of 2026-05-28):
#   android/app/google-services.json
#   ios/Runner/GoogleService-Info.plist

# Run with the Razorpay test key passed via --dart-define:
flutter run --dart-define=RAZORPAY_KEY=rzp_test_XXXXXXXXXX

# AI-powered assistant (optional): also pass the deployed Cloud Function URL.
# Without this flag the assistant uses the offline Hinglish stub.
# See functions/README.md to deploy the function + set ANTHROPIC_API_KEY.
flutter run \
  --dart-define=RAZORPAY_KEY=rzp_test_XXXXXXXXXX \
  --dart-define=ASSISTANT_API_URL=https://asia-south1-housepital-patient.cloudfunctions.net/assistant

# Or run tests:
flutter test

# For a production build, pass the live Razorpay key
# (see docs/KNOWN_ISSUES.md BUG-01):
flutter build apk --release \
  --dart-define=RAZORPAY_KEY=rzp_live_XXXXXXXXXX
flutter build web --release \
  --dart-define=RAZORPAY_KEY=rzp_live_XXXXXXXXXX
```

If `flutter build web --release` ever errors with a kernel-size assertion
during the tree-shake-icons step, retry with `flutter clean && flutter pub
get` first; the workaround is `--no-tree-shake-icons` (see
[docs/KNOWN_ISSUES.md § CI-01](./docs/KNOWN_ISSUES.md)).

### Firebase Setup

1. Add google-services.json (Android) and GoogleService-Info.plist (iOS)
2. Enable Phone Auth in Firebase Console
3. Uncomment Firebase initialization in main.dart

---

## Project Structure

```
housepital_patient_app/
├── pubspec.yaml                      # Dependencies (20+ packages)
│
├── lib/
│   ├── main.dart                     # Entry point + Provider setup + routes
│   │
│   ├── config/
│   │   ├── constants.dart            # API URLs, vital ranges, cities, relationships
│   │   └── theme.dart                # Brand theme (#F39314, Archivo, service colors)
│   │
│   ├── models/                       # 3 model files
│   │   ├── models.dart               # Patient, Deployment, Attendance, Vitals, Invoice, ServiceItem, etc. (25+ classes)
│   │   ├── my_care_models.dart       # ActiveService, HealthManager, ServiceDetail, StaffOnDuty, etc. (10 classes)
│   │   └── medication_models.dart    # MedicationFull, MedicationLog, ScheduleSlot (4 classes)
│   │
│   ├── services/                     # 5 service classes
│   │   ├── api_service.dart          # REST client with Bearer auth, all API endpoints
│   │   ├── firebase_service.dart     # Phone OTP + FCM tokens
│   │   ├── payment_service.dart      # Razorpay wrapper
│   │   ├── payment_reminder_service.dart  # Due payment notifications
│   │   └── sync_service.dart         # Background sync for offline
│   │
│   ├── providers/                    # 4 providers
│   │   ├── auth_provider.dart        # Auth state, session, user profile
│   │   ├── app_provider.dart         # Patient, deployment, vitals, dashboard, locale
│   │   ├── my_care_provider.dart     # Active services, health manager, service detail
│   │   ├── medication_provider.dart  # Medications CRUD, schedule builder
│   │   └── cart_provider.dart        # Equipment cart state
│   │
│   ├── screens/                      # 25+ screens across 12 folders
│   │   ├── auth/                     # login, otp, onboarding
│   │   ├── home/                     # dashboard with vitals + attendance + report
│   │   ├── my_care/                  # service monitoring hub (7 screens + 8 widgets)
│   │   ├── services/                 # catalog (5 tabs), booking, assessment, equipment
│   │   ├── billing/                  # invoices, payments, transactions
│   │   ├── settings/                 # profile, family members
│   │   ├── support/                  # raise concern, staff profile
│   │   ├── reports/                  # daily report detail, vitals history
│   │   ├── sos/                      # emergency contacts
│   │   ├── notifications/            # push notification list
│   │   ├── cart/                     # equipment cart + checkout
│   │   ├── documents/                # prescription/report repository
│   │   ├── search/                   # universal search
│   │   └── packages/                 # care package detail
│   │
│   ├── widgets/                      # Reusable components
│   │   └── common/                   # app_button, status_badge, loading_widget, etc.
│   │
│   └── utils/                        # Business logic helpers
│       ├── app_localizations.dart    # Custom i18n with JSON (en/hi)
│       └── helpers.dart              # VitalHelper, DateHelper, AttendanceHelper
│
├── assets/
│   ├── i18n/en.json                  # English strings
│   ├── i18n/hi.json                  # Hindi strings
│   ├── equipment_catalog.json        # Equipment specs + pricing
│   └── images/                       # App images
│
├── docs/
│   ├── my-care-tab.md                # My Care tab developer guide
│   └── superpowers/                  # Design specs + implementation plans
│
└── test/                             # 1407 unit tests
    ├── models/                       # 129 model tests
    ├── providers/                    # 62 provider tests
    └── screens/my_care/              # 29 widget tests
```

---

## What's Built

### Tab 1 — Home Dashboard
- Patient selector (multi-patient families)
- Vitals highlights (BP, Pulse, SpO2, Temp, Sugar) with color-coded status
- On-duty staff banner with live duration counter
- Today's attendance status with timestamps
- Daily report progress (completion percentage, task checklist)
- Quick actions (call staff, view reports, medications, raise concern)
- Active care packages summary
- My Care tab link banner

### Tab 2 — My Care (Service Monitoring Hub)
- Health Manager banner (single point of contact, call/SMS)
- Active service cards (color-coded by category)
- Staff attendance overview
- Billing summary (pre-paid consumption tracker)
- Quick actions (raise concern, daily reports, documents)
- Service detail drill-down:
  - Staff on duty with check-in times
  - 7-day attendance calendar
  - Vitals trend grid (fl_chart sparklines)
  - Care report with task timeline
  - Equipment deployed list
  - Billing breakdown
- Medication management:
  - Full medication list with stock tracking
  - Daily schedule view (Morning/Afternoon/Night time slots)
  - Add/edit medication form
  - Low stock alerts
- Report history and attendance history

### Tab 3 — Service Catalog
- 5 sub-tabs: Manpower, Equipment, Consultations, Diagnostics, Sleep Therapy
- Service booking wizard (3-step: details → slot → payment)
- Assessment request flow (for nursing, japa, nanny)
- Equipment detail modal (buy vs. rent, specs, add to cart)
- Cart + Razorpay checkout

### Tab 4 — Billing
- Invoice dashboard (total due, overdue count, total paid)
- Invoice list with filter tabs (all, pending, overdue, paid)
- Invoice detail with line items + GST breakdown
- Razorpay payment integration
- Transaction history
- Payment methods management
- Spend summary by category

### Tab 5 — Settings
- Patient profile editor (medical details, dietary restrictions, emergency contacts)
- Family members management (add/remove, notification preferences)
- Medical document repository
- Language toggle (EN/HI)
- Notification settings
- Help & FAQ
- Logout

### AI Assistant — "Sahayak" (✨ FAB on every tab)
- Voice + text, Hinglish — speak or type ("mere iss mahine ka bill kitna hai")
- Answers: billing, staff duty-days, staff/health-manager info
- Takes actions (all confirm-before-act): raise a concern, book/renew a service,
  request a staff replacement, place a call (SOS never blocked)
- Pay a bill → routes to the payment screen (never charges money itself)
- Powered by Claude via a Firebase Cloud Function (`functions/`); offline
  Hinglish keyword stub when `ASSISTANT_API_URL` is not set

### Care Guides (Education)
- 28 articles across 7 categories (Pulmo, Neuro, Ortho, Elderly, Mother & Baby,
  Post-hospitalisation) — markdown bodies, category chips, read-time
- BlogProvider with offline demo fallback

### Cross-Cutting Features
- SOS emergency screen (Housepital, Police, Medical emergency)
- Push notifications (FCM)
- Universal search
- Pull-to-refresh on all data screens
- Shimmer loading skeletons
- Custom error states with retry

---

## Security & Compliance

| Concern | Implementation |
|---------|---------------|
| Auth | Firebase Phone OTP (SMS-based). No passwords. |
| API Auth | Bearer token from Firebase ID token |
| Data Access | Patient app calls Firebase Cloud Functions (backed by Cloud SQL MySQL + Firestore) |
| AI key | ANTHROPIC_API_KEY is a server-side Firebase secret on the assistant function — never in the app binary |
| Payments | Razorpay handles card/UPI/netbanking — no PCI scope in app |
| Localization | EN/HI with JSON asset files |
| Error UX | Custom error screens, never raw exceptions |

---

## Testing

```bash
flutter test                    # All 1407 tests
flutter test test/models/       # 129 model tests
flutter test test/providers/    # 62 provider tests
flutter test test/screens/      # 29 widget tests
```

### Test Coverage

Authoritative, always-current counts live in [docs/TEST_MAP.md](./docs/TEST_MAP.md).
As of 2026-06-08: **1407 tests across 72 files** (analyzer clean). The table
below is an illustrative sample of the earliest coverage; later batches added
auth, payments, API, assistant, blogs, and home-layout suites.

| Module (sample) | Tests | What's Covered |
|--------|-------|----------------|
| my_care_models | 72 | fromJson, computed properties, visibility flags, edge cases |
| medication_models | 57 | fromJson, toJson, daysOfSupplyLeft, isLowStock, frequency labels |
| my_care_provider | 22 | loadMyCareData, loadServiceDetail, staleness, error handling |
| medication_provider | 40 | CRUD operations, schedule builder, computed getters, error handling |
| assistant (executor/service/provider/screen) | 52 | actions, confirm-first, permission gating, stub patterns |
| blogs/articles | 10 | Article model, BlogProvider fallback, list screen |
| **Total** | **1407** | see TEST_MAP.md for the full per-file breakdown |

---

## Business Rules

- **Never show prices for manpower services** (caretaker, nursing, japa, nanny) — users reject without talking to sales
- **Equipment pricing is monthly** (minimum 15 days = 1 month), never per-day
- **Staff app writes administration logs** — patient app is read-only for medication logs
- **Patient app writes medication CRUD** — add, edit, delete, stock updates
- **Health Manager** is the single point of contact — always visible at top of My Care tab
- **Service categories** control which sections appear in service detail views

---

## Remaining Steps for Production

1. **Firebase Setup** — Add google-services.json / GoogleService-Info.plist, uncomment Firebase.initializeApp() in main.dart
2. **Wire Mock Data** — AppProvider uses _loadMockData(); connect to real REST API
3. **Backend API** — Build REST endpoints matching ApiService methods
4. **Push Notifications** — Wire FCM token registration and notification handlers
5. **Payment Integration** — Add Razorpay API keys and webhook handlers
6. **Offline Support** — Implement SyncService with local DB caching
7. **App Store Builds** — flutter build apk (Android), flutter build ios (iOS)
8. **Widget Tests** — Add screen-level tests for critical flows (booking, payment)
