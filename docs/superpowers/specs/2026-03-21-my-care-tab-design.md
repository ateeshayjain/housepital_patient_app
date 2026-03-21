# My Care Tab — Active Service Monitoring

**Date:** 2026-03-21
**Status:** Design Approved
**Scope:** Patient app — new bottom tab for monitoring active services, staff attendance, vitals, billing, medications, and Health Manager communication.

---

## Problem

Patients and remote family members have no unified view of active services. The primary pain points are:

1. **Staff attendance anxiety** — "Did the nurse/caretaker show up on time?"
2. **Billing surprises** — "How much have I consumed? When is renewal?"
3. **Escalation difficulty** — "Who do I call when something goes wrong?"
4. **Care visibility** — "What tasks were completed today?"
5. **Health trajectory** — "Is the patient getting better or worse?"
6. **Medication tracking** — "Were the medicines given on time? Do we need refills?"

## Users

Both the **patient at home** and **remote family members** (in other cities) use this view equally. The design serves two modes:
- "I'm here, what's next" (patient)
- "I'm far away, is everything okay — show me proof" (family)

## Decision: Dedicated "My Care" Bottom Tab

**Chosen approach:** Replace the existing Reports tab with My Care — `Home | My Care | Services | Billing | More`

The current bottom tab bar is: `Home | Reports | Services | Billing | More` (5 tabs). My Care replaces Reports because:
- Reports (vitals, daily reports) are a subset of what My Care shows
- Reports content moves into My Care's service detail view
- No need for a 6th tab (bad mobile UX)
- Billing tab remains separate for invoice/payment management

**Why not other approaches:**
- Enhanced Home Screen — gets too long and dense, hard to find things
- Service-Specific Detail Screens — no unified view across services

**Empty state:** Patients with no active services see a CTA to book their first service, plus links to vitals history and past reports (preserving what Reports tab offered).

---

## Architecture

### Backend Integration

The patient app uses a REST API (`ApiService` → `https://api.housepital.com/v1`), NOT direct Supabase access. The staff app writes to Supabase directly. Data flows:

```
Staff App → Supabase → Backend API → Patient App
Patient App → Backend API → Supabase ← Staff App
```

**Real-time updates** via Firebase Cloud Messaging (FCM) push notifications — the backend sends a push when:
- Staff checks in/out → patient app refreshes attendance
- Vital recorded → patient app refreshes vitals
- Medication administered → patient app refreshes schedule
- Daily report submitted → patient app refreshes tasks

The patient app also polls on pull-to-refresh and on tab focus (existing pattern from home screen).

**New API endpoints needed:**

| Endpoint | Method | Description |
|---|---|---|
| `/v1/patients/{id}/active-services` | GET | Aggregated active services with summary stats |
| `/v1/patients/{id}/health-manager` | GET | Assigned Health Manager |
| `/v1/patients/{id}/medications` | GET | Medication list |
| `/v1/patients/{id}/medications` | POST | Add medication |
| `/v1/patients/{id}/medications/{id}` | PUT | Update medication |
| `/v1/patients/{id}/medications/{id}` | DELETE | Soft-delete medication |
| `/v1/patients/{id}/medication-logs` | GET | Administration logs (filterable by date) |
| `/v1/patients/{id}/medication-logs/{id}/stock` | PUT | Update stock count |
| `/v1/deployments/{id}/attendance` | GET | Attendance history (paginated) |
| `/v1/deployments/{id}/service-detail` | GET | Full service detail (staff + vitals + tasks + equipment) |

---

### My Care Tab — Top-Level Sections

The tab scrolls vertically with these sections:

#### 1. Health Manager Banner (sticky top)
- Assigned Health Manager name, photo, availability hours (e.g., "8 AM – 8 PM")
- One-tap Call and Message buttons
- Always visible — answers "who do I call?" immediately

#### 2. Active Services — Card Stack
Each active service rendered as a color-coded card:
- **ICU/Critical packages** — red header
- **Nursing deployments** (basic/advanced/critical) — orange header
- **Caretaker deployments** — teal header
- **Japa Maid / Nanny** — purple header
- **Physio/session services** — blue header
- **Equipment-only rentals** — green header

Color is determined by the `serviceCategory` field on the `ActiveService` model (see Data Model section).

Each card shows at-a-glance stats:
- Progress: "Day X of Y" or "Session X of Y"
- Staff status: "2/2 checked in ✓" (for deployment services)
- Key vital (for medical packages only): latest SpO2 or BP
- Renewal countdown: "18 days"
- Mini progress bar

**Tapping a card → Service Detail View** (see below)

#### 3. Today's Staff Attendance
For each deployed staff member:
- Name, role, shift type
- Check-in time and on-duty duration
- Status: On Duty (green), Replacement (yellow), Absent (red), Late (orange)
- Replacement staff clearly flagged with "Replacing [original name]"

#### 4. Billing Summary
Pre-paid package consumption tracker:
- Amount paid, days consumed / total, remaining balance
- Progress bar (consumed %)
- Daily rate × days = consumed calculation
- Next renewal date and amount
- Equipment deposit (refundable)
- Link to existing `/billing` tab for invoices and payment history

#### 5. Quick Actions Row
Three action tiles:
- **Raise Concern** — routes to existing `/raise-concern` screen
- **Daily Reports** — routes to new `/report-history` screen (list of past daily reports, each tappable to existing `/report-detail`)
- **Documents** — routes to existing `/documents` screen

---

### Service Detail View

Opens when tapping a service card. **One template, conditionally shows/hides sections** based on `serviceCategory`:

| Section | ICU / Care Package | Nursing / Caretaker / Japa / Nanny | Physio (per-session) | Equipment-only |
|---|---|---|---|---|
| Header + progress | ✓ Day X of Y | ✓ Day X of Y | ✓ Session X of Y | ✓ Month X |
| Staff on duty | ✓ Multiple staff | ✓ Single staff | ✗ (shown in header) | ✗ |
| 7-day attendance | ✓ | ✓ | ✗ (session log instead) | ✗ |
| Vitals trend | ✓ Full grid | ✗ | ✗ | ✗ |
| Daily care report | ✓ Full task list | ✓ Simpler checklist | ✗ (session notes) | ✗ |
| Medications | ✓ | ✗ | ✗ | ✗ |
| Equipment deployed | ✓ | ✗ | ✗ | ✓ (main content) |
| Billing summary | ✓ | ✓ | ✓ | ✓ |
| Staff notes | ✓ | ✓ | ✓ (session notes) | ✗ |

Section visibility is determined by checking `serviceCategory`:
- `care_package` → all sections
- `nursing`, `caretaker`, `japa`, `nanny` → staff + attendance + daily report + billing + notes
- `physiotherapy`, `doctor_visit`, `iv_visit`, `dressing` → header + billing + session notes
- `equipment_rental` → header + equipment list + billing

#### Service Detail Sections:

**Header:**
- Service name, start date, day/session progress with progress bar
- Quick stats: daily rate, consumed, remaining

**Staff on Duty:**
- Each staff member: name, role, shift type, check-in time, on-duty duration, rating, call button
- 7-day attendance calendar: green dots (on time), yellow (replacement with name), grey (today)

**Vitals Trend (care packages only):**
- 2×2 grid: BP, SpO2, Pulse, Temperature
- Each card: latest reading, status label (Normal/Elevated/Critical), 7-day sparkline
- Abnormal values highlighted with red border
- Tap any card → full vitals history screen (existing `/vitals` route)

**Today's Care Report:**
- Task timeline: completed (green ✓ + time), in-progress (orange ◷), upcoming (grey ○)
- Completion ring: "5/8 tasks, 62% complete"
- Nurse/staff notes in a highlighted box
- Link to past daily reports via `/report-history`

**Equipment Deployed (care packages and equipment-only):**
- List of equipment installed at home
- Monthly rental rate and start date for each
- "Active" status badge

---

### Medications Module

A full medication management system shared between patient and staff apps.

#### Daily Schedule View
- Medications grouped by time slot: Morning, Afternoon, Night
- Each medication shows:
  - Name, dosage, instructions (e.g., "1 tablet · After breakfast")
  - Status: Given (green, with timestamp + administered by), Pending, Upcoming
- Missed dose alerts in red banner with reason link
- Slot-level summary: "3/3 Given ✓" or "0/2 Pending"

#### Medication List / Management View
- All active medications with:
  - Name, dosage, frequency, instructions
  - Prescribing doctor, start date
  - **Stock tracking**: "28 tablets left", "Refill in 14 days"
  - Low-stock warning (yellow) when < 5 days supply
- Add Medication button (patient/family can add)
- Edit/delete existing medications
- Upload prescription photo capability

#### Data Flow
- **Patient app writes** (via REST API): add/edit/delete medications, update stock counts, upload prescriptions
- **Staff app writes** (via Supabase): mark administered (timestamp + who), record skipped dose + reason, flag adverse reactions, add PRN (as-needed) doses
- **Backend** pushes FCM notification to patient app when staff writes a medication log
- **Timezone handling**: All `time_slots` stored in IST (Asia/Kolkata). Display in local time. Remote family members see IST times with a timezone indicator if their device is in a different zone.

---

## Data Model Changes

### New Backend Tables

These tables live in the Supabase/MySQL backend. The patient app accesses them through the REST API.

#### `medications`
Replaces the JSONB `medications` field on `deployments` table and the `Patient.medications` list.

| Column | Type | Description |
|---|---|---|
| id | uuid | Primary key |
| patient_id | uuid | FK to patients |
| name | text | Medication name |
| dosage | text | e.g., "500mg", "10U" |
| form | text | tablet, injection, syrup, inhaler, drops |
| frequency | text | once_daily, twice_daily, thrice_daily, four_times_daily, as_needed |
| time_slots | jsonb | Array of times in IST: ["08:00", "14:00", "21:00"] |
| instructions | text | "After meals", "Before bed" |
| prescribed_by | text | Doctor name |
| prescribed_date | date | When prescribed |
| end_date | date | Nullable — ongoing if null |
| stock_count | int | Current stock (nullable for non-countable like injections from vial) |
| stock_unit | text | tablets, units, ml, puffs |
| prescription_photo_url | text | Uploaded prescription image |
| is_active | boolean | Soft delete |
| created_at | timestamptz | |
| updated_at | timestamptz | |

#### `medication_logs`
Records each administration or skip event.

| Column | Type | Description |
|---|---|---|
| id | uuid | Primary key |
| medication_id | uuid | FK to medications |
| patient_id | uuid | FK to patients (denormalized for query performance) |
| staff_id | uuid | FK to staff (who administered) — nullable for self-administered |
| scheduled_time | timestamptz | When it was due |
| actual_time | timestamptz | When it was actually given (null if skipped/missed) |
| status | text | administered, skipped, missed |
| skip_reason | text | Nullable — reason for skipping |
| notes | text | Any notes (e.g., adverse reaction) |
| created_at | timestamptz | |

Note: `deployment_id` removed — logs link to `medication_id` which links to `patient_id`. Medications outlive deployments; the log doesn't need a deployment reference.

#### `health_managers`
Links patients to their assigned Health Manager.

| Column | Type | Description |
|---|---|---|
| id | uuid | Primary key |
| patient_id | uuid | FK to patients |
| staff_id | uuid | FK to staff table (proper identity link) |
| manager_name | text | Denormalized for display |
| manager_phone | text | Denormalized for quick access |
| manager_photo_url | text | Denormalized |
| available_from | time | e.g., "08:00" |
| available_to | time | e.g., "20:00" |
| is_active | boolean | |

`staff_id` FK ensures managers are real staff members, can be reassigned, and can be linked across patients.

### New Patient App Models (Dart)

#### `ActiveService`
Aggregated view model returned by `/v1/patients/{id}/active-services`.

```dart
class ActiveService {
  final String id;
  final String name;                    // "Critical Care Package", "Nursing (Advanced, 24hr)"
  final String serviceCategory;         // care_package, nursing, caretaker, japa, nanny, physiotherapy, equipment_rental
  final String status;                  // active, paused, completed
  final DateTime startDate;
  final DateTime? endDate;
  final int totalDays;                  // or totalSessions for session-based
  final int consumedDays;               // or completedSessions
  final bool isSessionBased;            // true for physio, doctor visits

  // Staff summary (null for equipment-only)
  final int? totalStaff;
  final int? checkedInStaff;

  // Vitals summary (only for care_package)
  final String? latestVitalLabel;       // "SpO2 97%" or "BP 128/82"
  final String? latestVitalStatus;      // normal, warning, critical

  // Billing
  final int? dailyRate;                 // null for session-based
  final int? totalPaid;
  final int? totalConsumed;
  final int? remaining;
  final DateTime? renewalDate;

  // Deployments linked to this service
  final List<String> deploymentIds;
}
```

#### `HealthManager`
```dart
class HealthManager {
  final String id;
  final String staffId;
  final String name;
  final String phone;
  final String? photoUrl;
  final String availableFrom;           // "08:00"
  final String availableTo;             // "20:00"
}
```

#### `Medication` (replaces existing)
```dart
class Medication {
  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String form;                    // tablet, injection, syrup, etc.
  final String frequency;               // once_daily, twice_daily, etc.
  final List<String> timeSlots;         // ["08:00", "14:00", "21:00"]
  final String? instructions;
  final String? prescribedBy;
  final DateTime? prescribedDate;
  final DateTime? endDate;
  final int? stockCount;
  final String? stockUnit;
  final String? prescriptionPhotoUrl;
  final bool isActive;
}
```

#### `MedicationLog`
```dart
class MedicationLog {
  final String id;
  final String medicationId;
  final String? staffId;
  final String? staffName;              // denormalized
  final DateTime scheduledTime;
  final DateTime? actualTime;
  final String status;                  // administered, skipped, missed
  final String? skipReason;
  final String? notes;
}
```

### Migration Notes

- `Patient.medications` (existing `List<Medication>`) will be deprecated once the new `medications` table is populated. During migration, the patient app reads from the new API endpoint; the old field is ignored.
- `DailyReport.medications` (`List<MedicationEntry>`) continues to work as-is — it records what medications were noted in the daily report. The new `medication_logs` table is the authoritative administration record; `DailyReport.medications` is supplementary context.
- Staff app: `Deployment.medications` JSONB continues to be readable during migration. New medication writes go to the `medications` table. Staff app reads from both during transition, then drops JSONB reads.

### Staff App Changes

- Add `MedicationService` — read from `medications` table, write to `medication_logs`
- Existing vitals, attendance, daily report services unchanged
- Patient app reads their output through the REST API

---

## New Screens (Patient App)

| Screen | Route | Description |
|---|---|---|
| MyCareScreen | (bottom tab, index 1) | Top-level My Care tab with all sections |
| ServiceDetailScreen | `/service-detail` | Detail view for tapped service card (takes `ActiveService`) |
| ReportHistoryScreen | `/report-history` | List of past daily reports (takes `deploymentId`) |
| MedicationsScreen | `/medications` | Full medication list + management |
| MedicationScheduleScreen | `/medication-schedule` | Today's time-slotted schedule |
| AddEditMedicationScreen | `/medication-add` | Add or edit a medication (takes optional `Medication`) |
| AttendanceHistoryScreen | `/attendance-history` | 30-day staff attendance log (takes `deploymentId`) |

All new routes must be registered in `main.dart` `onGenerateRoute()`.

---

## Integration with Existing App

### Bottom Tab Bar Change
Current: `Home | Reports | Services | Billing | More`
New: `Home | My Care | Services | Billing | More`

In `main_shell.dart`:
- Replace Reports tab (index 1) with MyCareScreen
- Update icon: `Icons.bar_chart_outlined` → `Icons.favorite_outline` / `Icons.favorite`
- Update label: `tab_reports` → `tab_my_care`

### Home Screen Changes
- Existing "Your Staff" and "Today's Vitals" sections remain (quick glance)
- Add a banner/chip: "View My Care →" that switches to tab index 1
- No duplication of detailed data — home shows summary, My Care goes deep

### Real-time Updates
- FCM push notifications trigger data refresh (existing pattern in the app)
- Pull-to-refresh on My Care tab calls `/v1/patients/{id}/active-services`
- Tab focus triggers refresh if data is stale (> 60 seconds)

### Existing Routes Reused
- `/vitals` — vitals history (tap from vitals grid)
- `/report-detail` — daily report detail (tap from care report)
- `/raise-concern` — raise concern (tap from quick actions)
- `/documents` — document repository (tap from quick actions)
- `/billing` — billing tab (tap from billing summary)
- `/staff-profile` — staff profile (tap staff name)

### Loading / Error / Empty States
- **Loading**: Skeleton shimmer cards matching the section layout (existing pattern from home screen)
- **Error**: Retry banner with "Couldn't load data. Tap to retry." (existing error pattern)
- **Empty state (no active services)**: Illustration + "No active services" + "Book a Service" CTA button → Services tab
- **Offline**: Show last cached data with "Last updated X minutes ago" banner. Medication management (add/edit) disabled offline with explanation.

---

## Success Criteria

1. Remote family member opens My Care tab and within 3 seconds knows: staff is here, vitals are stable, meds were given
2. Patient can see all medications with stock levels and refill reminders
3. Billing shows exact consumption with no surprises
4. Health Manager is one tap away
5. Staff attendance with replacement visibility is clear
6. Everything the staff app writes is visible in the patient app via API with FCM-triggered refresh
7. Simpler services (Japa, Caretaker) show a clean subset — no empty sections visible
