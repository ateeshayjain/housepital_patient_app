# My Care Tab — Developer Documentation

## Overview

The **My Care** tab is the second tab in the Housepital patient app's bottom navigation. It replaces the former "Vitals" tab and gives patients/families a single dashboard to monitor all active home healthcare services — staff attendance, vitals, medications, billing, and daily care reports.

## Architecture

```
MyCareScreen (tab root)
├── HealthManagerBanner        — sticky contact card
├── ActiveServiceCard (×N)     — one per active service
├── StaffAttendanceSection     — aggregated staff on duty
├── BillingSummarySection      — pre-paid consumption tracker
└── QuickActionsRow            — raise concern, reports, documents

ServiceDetailScreen (push route)
├── Header with gradient + progress
├── StaffOnDuty list
├── 7-day attendance calendar
├── VitalsTrendGrid (fl_chart sparklines)
├── CareReportSection
├── Medications link
├── EquipmentDeployedSection
└── BillingSummarySection

MedicationsScreen → MedicationScheduleScreen → AddEditMedicationScreen
ReportHistoryScreen
AttendanceHistoryScreen
```

## State Management

Two providers manage all My Care state:

### MyCareProvider (`lib/providers/my_care_provider.dart`)

- **Data:** `activeServices`, `healthManager`, `selectedServiceDetail`
- **Loading:** Parallel fetch of services + health manager via `Future.wait`
- **Staleness:** 60-second cache; `isStale` getter triggers refresh on tab focus
- **Refresh:** Pull-to-refresh and `WidgetsBindingObserver` for foreground resume

### MedicationProvider (`lib/providers/medication_provider.dart`)

- **Data:** `medications`, `todayLogs`, `schedule` (time-slotted view)
- **CRUD:** `addMedication`, `updateMedication`, `deleteMedication`, `updateStock`
- **Schedule builder:** Groups active medications by time slot (Morning/Afternoon/Night), matches with today's administration logs
- **Computed:** `activeMedications`, `lowStockMedications`

## Data Models

### `lib/models/my_care_models.dart`

| Model | Purpose |
|---|---|
| `ActiveService` | Service card data with computed visibility flags (`showVitals`, `showStaff`, `showAttendance`, etc.) based on `serviceCategory` |
| `HealthManager` | Assigned coordinator with availability hours |
| `ServiceDetail` | Full detail view — nests `StaffOnDuty`, `AttendanceDay`, `VitalsSummary`, `CareReportSummary`, `EquipmentDeployed` |
| `StaffOnDuty` | Staff member with check-in time and `onDutyDuration` |
| `AttendanceDay` | Single day attendance record (on_time, late, replacement, absent) |
| `VitalsSummary` / `VitalCard` | BP, SpO2, pulse, temperature with sparkline data |
| `CareReportSummary` / `ReportTaskItem` | Daily care tasks with completion tracking |
| `EquipmentDeployed` | Equipment item with monthly rental rate |

### `lib/models/medication_models.dart`

| Model | Purpose |
|---|---|
| `MedicationFull` | Full medication record with `daysOfSupplyLeft`, `isLowStock`, `frequencyLabel`, and `toJson()` for writes |
| `MedicationLog` | Administration record with `wasGiven`, `wasSkipped`, `wasMissed` |
| `MedicationScheduleSlot` | Time slot grouping with `givenCount`, `allGiven`, `hasPending`, `summaryLabel` |
| `ScheduledMedication` | Pairs a medication with its log for a specific scheduled time |

## Service Categories & Visibility

Each `ActiveService` has a `serviceCategory` that controls which sections appear in `ServiceDetailScreen`:

| Category | Vitals | Staff | Attendance | Daily Report | Medications | Equipment |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| `care_package` | Yes | Yes | Yes | Yes | Yes | Yes |
| `nursing` | — | Yes | Yes | Yes | — | — |
| `caretaker` | — | Yes | Yes | Yes | — | — |
| `japa` | — | Yes | Yes | Yes | — | — |
| `nanny` | — | Yes | Yes | Yes | — | — |
| `physiotherapy` | — | Yes | — | — | — | — |
| `equipment_rental` | — | — | — | — | — | Yes |

## Color Coding

Service cards use color-coded headers defined in `HousepitalColors`:

| Category | Color | Constant |
|---|---|---|
| Care Package / ICU | Red | `serviceCarePackage` |
| Nursing | Orange | `serviceNursing` |
| Caretaker | Teal | `serviceCaretaker` |
| Japa / Nanny | Purple | `serviceJapaNanny` |
| Physiotherapy | Blue | `servicePhysio` |
| Equipment | Green | `serviceEquipment` |

Use `HousepitalColors.serviceColor(category)` to get the appropriate color.

## API Endpoints

All endpoints go through `ApiService` (`lib/services/api_service.dart`) using REST with Bearer token auth.

### My Care

| Method | Endpoint | Returns |
|---|---|---|
| `getActiveServices(patientId)` | `GET /patients/{id}/active-services` | `List<ActiveService>` |
| `getHealthManager(patientId)` | `GET /patients/{id}/health-manager` | `HealthManager?` |
| `getDeploymentServiceDetail(deploymentId)` | `GET /deployments/{id}/detail` | `ServiceDetail` |
| `getAttendanceHistoryPaginated(deploymentId, page)` | `GET /deployments/{id}/attendance?page=N` | `List<AttendanceDay>` |

### Medications

| Method | Endpoint | Returns |
|---|---|---|
| `getMedications(patientId)` | `GET /patients/{id}/medications` | `List<MedicationFull>` |
| `addMedication(patientId, body)` | `POST /patients/{id}/medications` | `MedicationFull` |
| `updateMedication(patientId, medId, body)` | `PUT /patients/{id}/medications/{medId}` | `MedicationFull` |
| `deleteMedication(patientId, medId)` | `DELETE /patients/{id}/medications/{medId}` | `void` |
| `getMedicationLogs(patientId)` | `GET /patients/{id}/medication-logs?date=today` | `List<MedicationLog>` |
| `updateMedicationStock(patientId, medId, count)` | `PATCH /medications/{medId}/stock` | `void` |

## Routes

Registered in `main.dart` `onGenerateRoute`:

| Route | Arguments | Screen |
|---|---|---|
| `/service-detail` | `ActiveService` | `ServiceDetailScreen` |
| `/medications` | none | `MedicationsScreen` |
| `/medication-schedule` | none | `MedicationScheduleScreen` |
| `/add-medication` | `MedicationFull?` (null = add) | `AddEditMedicationScreen` |
| `/report-history` | `String` deploymentId | `ReportHistoryScreen` |
| `/attendance-history` | `String` deploymentId | `AttendanceHistoryScreen` |

## File Structure

```
lib/
├── models/
│   ├── my_care_models.dart          # ActiveService, HealthManager, ServiceDetail, etc.
│   └── medication_models.dart       # MedicationFull, MedicationLog, ScheduleSlot
├── providers/
│   ├── my_care_provider.dart        # Services + health manager state
│   └── medication_provider.dart     # Medications CRUD + schedule builder
├── screens/my_care/
│   ├── my_care_screen.dart          # Tab root
│   ├── service_detail_screen.dart   # Per-service detail
│   ├── medications_screen.dart      # Full medication list
│   ├── medication_schedule_screen.dart  # Daily time-slotted view
│   ├── add_edit_medication_screen.dart  # Add/edit form
│   ├── report_history_screen.dart   # Past daily reports
│   ├── attendance_history_screen.dart   # 30-day attendance
│   └── widgets/
│       ├── health_manager_banner.dart
│       ├── active_service_card.dart
│       ├── staff_attendance_section.dart
│       ├── billing_summary_section.dart
│       ├── quick_actions_row.dart
│       ├── vitals_trend_grid.dart
│       ├── care_report_section.dart
│       └── equipment_deployed_section.dart
└── config/theme.dart                # Service color constants

test/
├── models/
│   ├── my_care_models_test.dart     # 72 tests
│   └── medication_models_test.dart  # 57 tests
├── providers/
│   ├── mock_api_service.dart        # Manual mock
│   ├── my_care_provider_test.dart   # 22 tests
│   └── medication_provider_test.dart # 40 tests
└── screens/my_care/
    └── my_care_widgets_test.dart     # 29 tests
```

## Testing

Run all tests:
```bash
flutter test
```

Run My Care tests only:
```bash
flutter test test/models/ test/providers/ test/screens/my_care/
```

**220 tests** covering models, providers, and widgets.

## Business Rules

- **Never show prices for manpower services** (caretaker, nursing, japa, nanny) — users reject without talking to sales
- **Equipment pricing is monthly** (minimum 15 days = 1 month), never per-day
- **Staff app writes administration logs** — patient app is read-only for medication logs
- **Patient app writes medication CRUD** — add, edit, delete, stock updates
- **Health Manager** is the single point of contact — always visible at top of My Care tab

## Phase 2 (Not Yet Implemented)

- Prescription photo upload
- Equipment deposit display
- Offline caching with local DB
- Per-staff attendance breakdown on service detail
