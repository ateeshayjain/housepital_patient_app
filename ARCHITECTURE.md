# Housepital Patient App — Architecture Guide

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER PATIENT APP                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ Screens  │→ │ Providers│→ │ Services │→ │  REST API    │   │
│  │ (UI)     │  │ (State)  │  │ (Logic)  │  │  (HTTP)      │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────┬───────┘   │
│       │                           │                 │           │
│       ↓                           ↓                 │           │
│  ┌──────────┐              ┌──────────────┐         │           │
│  │ Widgets  │              │  Firebase    │         │           │
│  │ (Reuse)  │              │  (Auth+FCM)  │         │           │
│  └──────────┘              └──────────────┘         │           │
│                                                     │           │
│  ┌──────────────────────────────────────────────┐   │           │
│  │ Utils: Helpers, Localizations, VitalClassifier│   │           │
│  └──────────────────────────────────────────────┘   │           │
└─────────────────────────────────────────────────────┼───────────┘
                                                      │
                                                      ↓
                                          ┌───────────────────┐
                                          │   BACKEND API     │
                                          │  (REST + Supabase) │
                                          │  ┌─────────────┐  │
                                          │  │  Supabase    │  │
                                          │  │  (Database)  │  │
                                          │  ├─────────────┤  │
                                          │  │  Storage     │  │
                                          │  │  (Files)     │  │
                                          │  └─────────────┘  │
                                          └───────────────────┘
```

## Layer Architecture

The app follows a strict 4-layer architecture. Each layer only talks to the one below it — screens never call the REST API directly.

### Layer 1: Screens (UI)

25+ screens across 12 feature folders. Each screen is a StatefulWidget that reads state from Providers and calls Services for actions.

```
screens/
├── auth/           → Login + OTP + Onboarding
├── home/           → Dashboard with vitals + attendance + reports
├── my_care/        → Service monitoring hub (7 screens + 8 widgets)
├── services/       → Catalog (5 tabs), booking, assessment, equipment
├── billing/        → Invoices, payments, transactions
├── settings/       → Profile, family members
├── support/        → Raise concern, staff profile
├── reports/        → Daily report detail, vitals history
├── sos/            → Emergency contacts
├── notifications/  → Push notification list
├── cart/           → Equipment cart + checkout
├── documents/      → Medical documents
├── search/         → Universal search
└── packages/       → Care package detail
```

### Layer 2: Providers (State Management)

5 ChangeNotifier providers manage app-wide state via the `provider` package:

**AuthProvider** — Handles authentication lifecycle: login state, session, current user (FamilyMember), phone number. Wraps FirebaseService calls and notifies listeners on state changes.

**AppProvider** — Handles core app state: current patient, all patients (multi-patient family support), active deployment, today's attendance, latest vitals, today's report, amount due, locale. Loads dashboard data. Exposes a public `apiService` getter for screens needing authenticated API access.

**MyCareProvider** — Handles My Care tab state: active services list, health manager, service detail. Enforces a 60-second staleness cache. Fetches data in parallel via `Future.wait`.

**MedicationProvider** — Handles medication state: medications list, today's logs, schedule slots. Supports full CRUD (add/update/delete). Schedule builder groups medications by time slot (Morning/Afternoon/Night).

**CartProvider** — Handles shopping cart state: equipment items (buy/rent), quantities, rental months. Computes subtotal, delivery charge (free over Rs.999), and total.

### Layer 3: Services (Business Logic)

5 service classes, each owning a single domain. All async, all wrapped in try-catch.

**ApiService** — REST client wrapping the `http` package. Base URL: `https://api.housepital.in/v1`. Auto-injects Bearer token on every request. Covers all endpoints: patients, dashboard, attendance, vitals, reports, active services, health manager, medications, services, invoices, family, concerns, notifications. Throws a custom `ApiException` for error handling.

**FirebaseService** — Firebase Auth (Phone OTP send/verify/logout) and FCM (token registration, permissions, topic subscription).

**PaymentService** — Razorpay integration wrapper. Initiates payment, handles success and failure callbacks.

**PaymentReminderService** — Schedules local notifications for due payments.

**SyncService** — Background sync for offline-first capability. Queue/process mechanism.

### Layer 4: Backend (REST API → Supabase)

The patient app does not talk to Supabase directly. All requests go through a REST API layer. The staff app writes directly to Supabase. Both share the same Supabase database.

**PostgreSQL** — All persistent data via Supabase. Shared tables: patients, deployments, attendance, vitals, daily_reports, medications, medication_logs, invoices, services, staff, family_members.

**Storage** — File storage via Supabase Storage. Medical documents, daily report photos, and other attachments.

## Data Flow Examples

### Loading My Care Dashboard

```
User opens My Care tab
    → my_care_screen.dart
    → MyCareProvider.loadMyCareData(patientId)
    → Future.wait([
        ApiService.getActiveServices(patientId),
        ApiService.getHealthManager(patientId),
      ])
    → REST API: GET /patients/{id}/active-services
    → REST API: GET /patients/{id}/health-manager
    → Provider sets _activeServices + _healthManager
    → notifyListeners() → UI rebuilds
    → 60-second staleness check on tab re-focus
```

### Adding a Medication

```
User taps "+ Add Medication"
    → add_edit_medication_screen.dart
    → User fills form (name, dosage, frequency, time slots, stock)
    → MedicationProvider.addMedication(patientId, body.toJson())
    → ApiService.addMedication(patientId, body)
    → REST API: POST /patients/{id}/medications
    → Provider adds new MedicationFull to _medications list
    → notifyListeners() → MedicationsScreen rebuilds with new med
```

### Service Booking (Instant)

```
User taps service in catalog
    → service_booking_screen.dart (3-step wizard)
    → Step 1: Service details, duration, auto-renew toggle
    → Step 2: Date + time slot selection
    → Step 3: Review, promo code, total
    → User taps "Pay Now"
    → PaymentService.initializePayment(amount, description)
    → Razorpay modal opens
    → On success: ApiService.bookService(booking)
    → Show confirmation
```

### Vital Signs Display

```
HomeScreen loads
    → AppProvider.loadDashboard()
    → ApiService.getLatestVitals(patientId)
    → VitalHelper.getVitalColor(value, type) → Green/Yellow/Red
    → VitalHelper.getVitalStatus(value, type) → Normal/Borderline/Alert
    → UI shows 6-card grid with color-coded vitals
    → Tap vital card → /vitals route with chart history
```

## Navigation Architecture

### Bottom Tab Navigation (MainShell)

```
MainShell (Scaffold + BottomNavigationBar)
├── Tab 0: HomeScreen           (icon: home)
├── Tab 1: MyCareScreen         (icon: favorite)
├── Tab 2: ServiceCatalogScreen (icon: medical_services)
├── Tab 3: BillingScreen        (icon: receipt_long)
└── Tab 4: SettingsScreen       (icon: settings)
```

Uses `IndexedStack` to preserve tab state across switches. Global key `MainShell.shellKey` allows programmatic cross-tab navigation (e.g., Home → My Care).

### Named Routes (onGenerateRoute)

30+ routes defined in main.dart. Arguments passed via `settings.arguments` with type-safe casting. Routes cover auth flows, all detail screens, billing flows, and My Care drill-downs.

## Two-App Data Architecture

```
┌──────────────────┐         ┌──────────────────┐
│   STAFF APP      │         │   PATIENT APP    │
│  (Field Workers) │         │  (Families)      │
│                  │         │                  │
│  Writes directly │         │  Reads via       │
│  to Supabase:    │         │  REST API:       │
│  - Attendance    │         │  - View staff    │
│  - Vitals        │         │  - View vitals   │
│  - Daily reports │         │  - View reports  │
│  - Med logs      │         │  - Manage meds   │
│  - Photo logs    │         │  - Book services │
│                  │         │  - Pay invoices  │
└────────┬─────────┘         └────────┬─────────┘
         │                            │
         ↓                            ↓
┌──────────────────────────────────────────────┐
│              SUPABASE DATABASE               │
│  Shared tables: patients, deployments,       │
│  attendance, vitals, daily_reports,          │
│  medications, medication_logs, invoices,     │
│  services, staff, family_members             │
└──────────────────────────────────────────────┘
```

## Service Category System

6 color-coded categories control UI visibility across My Care screens:

| Category | Color | Hex | Vitals | Staff | Attendance | Reports | Medications | Equipment |
|----------|-------|-----|:------:|:-----:|:----------:|:-------:|:-----------:|:---------:|
| care_package | Red | #DC2626 | Yes | Yes | Yes | Yes | Yes | Yes |
| nursing | Orange | #F39314 | — | Yes | Yes | Yes | — | — |
| caretaker | Teal | #0D9488 | — | Yes | Yes | Yes | — | — |
| japa/nanny | Purple | #7C3AED | — | Yes | Yes | Yes | — | — |
| physiotherapy | Blue | #2563EB | — | Yes | — | — | — | — |
| equipment_rental | Green | #059669 | — | — | — | — | — | Yes |

`HousepitalColors.serviceColor(category)` returns the appropriate color. The `ActiveService` model exposes computed booleans (`showVitals`, `showStaff`, `showAttendance`, `showReports`, `showMedications`, `showEquipment`) that drive conditional rendering in `ServiceDetailScreen`.

## Brand System

All UI follows Housepital Brand & Identity Guidelines V1:

| Element | Value |
|---------|-------|
| Primary Color | #F39314 (Pantone 1375 C — Orange) |
| Orange Light | #FFF3E0 |
| Orange Dark | #CC6E00 |
| Grey Primary | #3D3D3D |
| Grey Secondary | #6B6B6B |
| Background | #F5F5F5 |
| Font | Archivo (Google Fonts, all weights) |
| Languages | English + Hindi (JSON-based i18n) |
| Material | Material 3 with WCAG AA contrast |

Status colors (Green/Yellow/Red) are functional — used for vital signs classification — not brand colors.

## Key Design Decisions

**Why REST API instead of direct Supabase?** Patient app is family-facing — it needs an authorization layer between family users and healthcare data. The REST API provides data aggregation (e.g., one call returns the full dashboard instead of 5 separate Supabase queries), rate limiting, and access control beyond what RLS alone can enforce.

**Why Firebase Auth instead of Supabase Auth?** Staff app uses Supabase Auth (all-in-one). Patient app uses Firebase because: (1) Firebase ecosystem for patient-facing features (FCM, Analytics, Crashlytics), (2) better OTP delivery rates in India, (3) separate auth domain from staff app avoids session conflicts.

**Why Provider over Riverpod/Bloc?** Matches the staff app pattern. 5 providers is sufficient for this scope. Lowest learning curve for the team. ChangeNotifier is well-understood and can be migrated to Riverpod later if complexity grows.

**Why separate My Care tab from Home?** Home shows today's snapshot for a single deployment. My Care shows all active services across multiple deployments — a family may have nursing, equipment rental, and physiotherapy running simultaneously, each needing its own detail view.

**Why medication CRUD in the patient app?** Patient/family manages the medication list (what medications, dosage, stock level). Staff app only marks medications as administered or skipped. This reflects the real-world workflow where families procure and track medications.
