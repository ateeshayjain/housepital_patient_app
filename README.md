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
| PDF | **pdf + printing** | On-device invoice PDFs (PRO FORMA for quotes) + Doctor Handover report |
| Fonts | **Bundled Archivo + NotoSansDevanagari TTFs** (`assets/fonts/`) | Consistent from first paint, works offline; google_fonts dependency removed — never re-add it |
| Colors | **#F39314** (Primary Orange) | Per Brand Guidelines |
| Localization | **English + Hindi** | Custom AppLocalizations with JSON assets |
| Loading | **Shimmer** | Skeleton loading animations |

## Quick Stats

- **149 Dart source files** | **~53,800 lines of code**
- **99 test files** | **~1,771 tests at runtime** (1,370 `test()`/`testWidgets()` call sites; parameterized guard suites expand at runtime) | **~23,800 test LOC**
- **6 bottom tabs** (Home, My Care, Services, Calendar, Billing, More) — fixed solid-orange nav bar
- **40+ screens** with full EN/HI localization and true-black tonal dark mode
- **52 named routes** in onGenerateRoute
- **351 equipment items** (all priced; 320 with bundled product photos, ~31 placeholder)

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

Firebase is initialized in `main.dart` (`Firebase.initializeApp`) — no code change
needed; Crashlytics + Performance init is guarded (mobile-only, release-only).

---

## Project Structure

```
housepital_patient_app/
├── pubspec.yaml                      # Dependencies (incl. pdf, printing; bundled fonts)
│
├── lib/
│   ├── main.dart                     # Entry point + Provider setup + 52 routes
│   │
│   ├── config/
│   │   ├── constants.dart            # API URLs, vital ranges, cities, relationships
│   │   ├── theme.dart                # Brand theme (#F39314, Archivo, light + dark)
│   │   ├── app_colors.dart           # context.hc token resolver (HcPalette light/dark)
│   │   ├── daimaa_theme.dart         # Dai Maa cross-promo banner colors
│   │   └── firebase_options.dart     # Firebase config
│   │
│   ├── models/                       # 9 model files
│   │   ├── models.dart               # Patient, Deployment, Attendance, Vitals, Invoice, ServiceItem, etc.
│   │   ├── my_care_models.dart       # ActiveService, HealthManager, ServiceDetail, StaffOnDuty, etc.
│   │   ├── medication_models.dart    # MedicationFull, MedicationLog, ScheduleSlot
│   │   ├── care_event.dart           # Care Calendar events (doses, attendance)
│   │   ├── equipment_order.dart      # Orders + quote-pending bookings
│   │   ├── medical_history.dart      # Read-only medical history (profile section)
│   │   ├── doctor_recommendation.dart# Doctor recommendations → cart
│   │   ├── article.dart              # Care Guides articles
│   │   └── assistant_models.dart     # Assistant actions + safe parsing
│   │
│   ├── services/                     # 13 service classes
│   │   ├── api_service.dart          # REST client with Bearer auth (+ i_api_service.dart interface)
│   │   ├── firebase_service.dart     # Phone OTP + FCM tokens + Storage uploads
│   │   ├── payment_service.dart      # Razorpay wrapper
│   │   ├── invoice_pdf_service.dart  # On-device invoice PDF (PRO FORMA for quotes)
│   │   ├── handover_report_service.dart # Doctor Handover PDF (role-gated)
│   │   ├── assistant_service.dart    # AI assistant backend client + Hinglish stub
│   │   ├── voice_service.dart        # speech_to_text + flutter_tts wrapper
│   │   ├── medication_reminder_service.dart # Local dose notifications
│   │   ├── payment_reminder_service.dart  # Due payment notifications
│   │   ├── cache_service.dart        # Offline caching with TTL
│   │   ├── video_call_service.dart   # Video consultation
│   │   └── sync_service.dart         # Background sync for offline
│   │
│   ├── providers/                    # 10 providers
│   │   ├── auth_provider.dart        # Auth state, session, user profile
│   │   ├── app_provider.dart         # Patient, deployment, vitals, dashboard, locale
│   │   ├── theme_provider.dart       # ThemeMode (system/light/dark), persisted
│   │   ├── my_care_provider.dart     # Active services, health manager, service detail
│   │   ├── medication_provider.dart  # Medications CRUD, schedule builder
│   │   ├── cart_provider.dart        # Equipment cart state
│   │   ├── orders_provider.dart      # Orders + quote-pending bookings + assessments
│   │   ├── billing_provider.dart     # Billing summary, EMI (quote orders excluded from sums)
│   │   ├── blog_provider.dart        # Care Guides articles
│   │   └── assistant_provider.dart   # Assistant orchestration (service+executor+voice)
│   │
│   ├── screens/                      # 40+ screens across 20+ folders
│   │   ├── auth/                     # login, otp, onboarding
│   │   ├── home/                     # dashboard with vitals + attendance + Dai Maa banner
│   │   ├── my_care/                  # service monitoring hub + medications
│   │   ├── calendar/                 # Care Calendar (Day/Week/Month, doses, attendance)
│   │   ├── care_team/                # Care Team hub (group chat, members, ambulance)
│   │   ├── services/                 # catalog (6 tabs), booking, equipment, my orders
│   │   ├── orders/                   # order tracking
│   │   ├── rental/                   # rental agreement, equipment return
│   │   ├── checkout/                 # address selection
│   │   ├── billing/                  # invoices, payments, transactions, EMI
│   │   ├── articles/                 # Care Guides list + markdown detail
│   │   ├── assistant/                # Sahayak voice/text chat + action executor
│   │   ├── consultation/             # video consultation
│   │   ├── chat/                     # coordinator chat
│   │   ├── settings/                 # profile (incl. medical history), family members
│   │   ├── support/                  # raise concern, staff profile, replacement
│   │   ├── reports/                  # daily report detail, vitals history
│   │   ├── sos/                      # emergency contacts
│   │   ├── notifications/            # push notification list
│   │   ├── cart/                     # equipment cart
│   │   ├── documents/                # prescription/report repository
│   │   ├── search/                   # universal search
│   │   └── packages/                 # care package detail
│   │
│   ├── widgets/                      # Reusable components
│   │   ├── glass.dart                # GlassAppBar, GlassSurface, HousepitalCard (Liquid Glass chrome)
│   │   ├── common_widgets.dart       # app_button, status_badge, loading_widget, etc.
│   │   ├── paginated_list.dart       # Reusable pagination
│   │   └── assistant_fab.dart        # ✨ assistant entry point
│   │
│   └── utils/                        # Business logic helpers
│       ├── app_localizations.dart    # Custom i18n with JSON (en/hi)
│       └── helpers.dart              # VitalHelper, DateHelper, AttendanceHelper
│
├── assets/
│   ├── fonts/                        # Bundled Archivo.ttf + NotoSansDevanagari.ttf
│   ├── i18n/en.json                  # English strings
│   ├── i18n/hi.json                  # Hindi strings
│   ├── equipment_catalog.json        # Equipment specs + pricing
│   └── images/                       # App images
│
├── scripts/
│   └── check_design_consistency.sh   # Static design gate (banned color/chrome patterns)
│
├── docs/
│   ├── my-care-tab.md                # My Care tab developer guide
│   └── superpowers/                  # Design specs + implementation plans
│
└── test/                             # 86 test files, 1,550+ tests
    ├── screens/overflow_smoke_test.dart  # 37 screens × 3 widths overflow guard
    ├── widgets/dark_mode_test.dart       # dark-mode token guard
    └── utils/i18n_sync_test.dart         # EN/HI key-sync guard
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
- 6 sub-tabs: Manpower, Equipment, Consultations, Diagnostics, Lab Tests, Packages
- Needs-based staff tier selection: checklist on `staff_role_card.dart` infers the
  right manpower tier from care needs
- **Manpower prices shown + directly bookable** — Delhi NCR rate card (Caretaker
  ₹800–1,500/day, Nurse ₹1,600–3,000/day, monthly packages ₹18,000–₹90,000/mo);
  booking runs the normal cart/payment path with a per-day × days (or × sessions)
  multiplier; Housepital calls back after purchase to assign staff. *(Reversed/
  re-confirmed 2026-06-11 — the old "never show" rule is dead.)* Quote-pending now
  applies only to items that genuinely lack a price (`isQuote = price == null/0`).
- Consultations include Psychiatrist + new Diet & Nutrition (Nourish Programme);
  no staff names in catalog copy
- Blinkit-style equipment browse: left category rail + dense 2-column grid,
  MRP strikethrough + discounted price; **all 351 items priced**, 320 with bundled
  product photos (`assets/images/products/`) via the shared `ProductImage` widget
  (renders in both grid card and detail sheet); ~31 generic items show placeholder
- Reserve flow for price-on-request equipment (no fabricated prices)
- Equipment detail sheet (buy vs. rent, specs, add to cart)
- Cart + Razorpay checkout (equipment); service booking wizard for bookable services

### Tab 5 — Billing
- Invoice dashboard (total due, overdue count, total paid)
- Invoice list with filter tabs (all, pending, overdue, paid)
- Invoice detail with line items + GST breakdown
- Razorpay payment integration
- Transaction history
- Payment methods management
- Spend summary by category

### Tab 4 — Calendar (root tab)
- Care Calendar is a root bottom-tab (index 3, between Services and Billing)
- Day / Week / Month views in one segmented control
- Dose groups with single-tap mark-taken (records a timestamped log)
- Staff attendance with mark-present confirmations
- Future-day "N doses scheduled" cards; hairline separators between dose rows

### Tab 6 — More (Settings)
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
- Powered by Claude via a Firebase Cloud Function (`functions/`); offline builds use
  a local Hinglish intent matcher/executor that really runs add-to-cart / booking
  offline (`assistant_service.dart` + `assistant_local_actions.dart`)

### Care Team Hub (`/care-team`)
- Group chat first — one tap reaches the whole team
- Per-member call/chat rows (health manager, on-duty staff, doctors)
- Ambulance card (call ambulance, 24x7 emergency)
- Past staff history (read-only)

### Commerce & Orders
- Full in-app commerce: cart → address → Razorpay checkout (equipment + manpower)
- Manpower booked at rate-card prices via the normal payment path (per-day × days /
  × sessions multiplier); Housepital calls back to assign staff
- **Demo-mode payments:** `payment_service.dart` simulates checkout when the Razorpay
  key is a placeholder; a real key via `--dart-define=RAZORPAY_KEY=…` enables real checkout
- Quote-pending only for items that genuinely lack a price (`quoteStatus: 'pending'`,
  PRO FORMA invoice without amounts)
- Reserve flow for price-on-request items
- My Orders + order tracking, rental agreement + return, EMI plans
- On-device PDF invoices via `invoice_pdf_service.dart` (PRO FORMA without
  amounts for quote orders) and Doctor Handover report via
  `handover_report_service.dart` (role-gated) — `pdf` + `printing` packages

### Medical History
- `MedicalHistory` model + read-only section in the patient profile

### Care Guides (Education)
- 28 articles across 7 categories (Pulmo, Neuro, Ortho, Elderly, Mother & Baby,
  Post-hospitalisation) — markdown bodies, read-time
- Redesigned list: featured hero card for the newest guide + per-category accent colors
- BlogProvider with offline demo fallback

### Design System — calm Apple direction
- **Fixed full-width solid-orange bottom nav bar** (`MainShell`), white icons/labels,
  SafeArea-padded — owner iterated floating-glass → pill → fixed
- `GlassAppBar` / `GlassSurface` chrome on every screen (`lib/widgets/glass.dart`).
  Nav contract: HOME leftmost, CART rightmost with a live badge, search in between;
  funnel screens (cart/checkout/payment) opt out of the cart icon, Billing shows no
  cart, SOS is the home-screen far-right exception
- `HousepitalCard` squircle cards (`RoundedSuperellipseBorder(16)`, press-scale)
- **`onOrange` is WHITE app-wide** (owner decision); one-accent color budget (orange
  `#F39314`); **true-black tonal dark mode**; large iOS-style display titles
- Typography scale converging on a canon; the design gate prints an informational
  fontSize histogram (echo-only) so drift shows in CI
- Every brightness-sensitive color resolves through `context.hc` tokens
  (`HcPalette` light/dark in `lib/config/app_colors.dart`)
- Bundled Archivo + NotoSansDevanagari fonts (no runtime font fetch)
- Dai Maa is a separate business — a single cross-promo banner on Home, nothing else

### Cross-Cutting Features
- SOS emergency screen (Housepital, Police, Medical emergency) — never blocked
- Push notifications (FCM)
- Universal search
- Pull-to-refresh on all data screens
- Shimmer loading skeletons
- Custom error states with retry

### Guards & CI
- CI: `flutter analyze` → design gate (`scripts/check_design_consistency.sh`) →
  full test run with `--dart-define=RAZORPAY_KEY=rzp_test_ci_dummy_key` →
  coverage gate (lcov threshold)
- Overflow smoke test: 37 screens × 3 widths (320/375/414)
- Dark-mode token guard (`test/widgets/dark_mode_test.dart`)
- EN/HI i18n key-sync guard (`test/utils/i18n_sync_test.dart`)

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
# Full suite (the dart-define un-skips 8 payment groups):
flutter test --dart-define=RAZORPAY_KEY=rzp_test_ci_dummy_key

# Targeted guards:
flutter test test/screens/overflow_smoke_test.dart   # 37 screens × 3 widths
flutter test test/widgets/dark_mode_test.dart        # dark-mode tokens
flutter test test/utils/i18n_sync_test.dart          # EN/HI key sync
```

### Test Coverage

Authoritative, always-current counts live in [docs/TEST_MAP.md](./docs/TEST_MAP.md).
As of 2026-06-15: **~1,771 tests at runtime across 99 files** (1,370 `test()`/
`testWidgets()` call sites; parameterized guard suites expand at runtime; analyzer
clean). The table below is an illustrative sample; field rounds 3–6 added fixed-nav
shell, calendar-tab, manpower-pricing, product-image, and typography guards.

| Module (sample) | Tests | What's Covered |
|--------|-------|----------------|
| my_care_models | 72 | fromJson, computed properties, visibility flags, edge cases |
| medication_models | 57 | fromJson, toJson, daysOfSupplyLeft, isLowStock, frequency labels |
| my_care_provider | 22 | loadMyCareData, loadServiceDetail, staleness, error handling |
| medication_provider | 40 | CRUD operations, schedule builder, computed getters, error handling |
| assistant (executor/service/provider/screen) | 52 | actions, confirm-first, permission gating, stub patterns |
| overflow smoke | 111 | 37 screens × 320/375/414 widths, Ahem worst-case font |
| **Total** | **~1,771** | see TEST_MAP.md for the full per-file breakdown |

---

## Business Rules

- **Manpower prices ARE shown and directly bookable** (caretaker, nurse, physio) — Delhi NCR rate card, per-day × days (or × sessions) on the normal cart/payment path; Housepital calls back after purchase to assign staff. *(Reversed/re-confirmed 2026-06-11; the old "never show" rule is dead. Japa/Nanny are Dai Maa, a separate business.)* Quote-pending applies only to items that genuinely lack a price (`isQuote = price == null/0`) — those export PRO FORMA invoices and are excluded from billing sums
- **Equipment rental minimum** is 1 month (security deposit = 1 month rental)
- **Staff app writes administration logs** — patient app is read-only for medication logs
- **Patient app writes medication CRUD** — add, edit, delete, stock updates
- **Health Manager** is the single point of contact — always visible at top of My Care tab
- **Service categories** control which sections appear in service detail views

---

## Remaining Steps for Production

1. **Firebase Setup** — Add google-services.json / GoogleService-Info.plist (Firebase.initializeApp() is already wired in main.dart)
2. **Wire Mock Data** — AppProvider uses _loadMockData(); connect to real REST API
3. **Backend API** — Build REST endpoints matching ApiService methods
4. **Push Notifications** — Wire FCM token registration and notification handlers
5. **Payment Integration** — Add Razorpay API keys and webhook handlers
6. **Offline Support** — Implement SyncService with local DB caching
7. **App Store Builds** — flutter build apk (Android), flutter build ios (iOS)
8. **Widget Tests** — Add screen-level tests for critical flows (booking, payment)
