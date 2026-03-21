# My Care Tab Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Reports tab with a My Care tab that gives patients and remote family real-time visibility into active services, staff attendance, vitals, medications, and billing.

**Architecture:** New `MyCareProvider` fetches aggregated data from REST API endpoints. The main `MyCareScreen` is a scrollable page with five sections (Health Manager, Active Services, Staff Attendance, Billing, Quick Actions). Tapping a service card navigates to `ServiceDetailScreen` with conditional section visibility based on `serviceCategory`. A separate `MedicationProvider` handles CRUD for medications. All new models follow the existing `fromJson` pattern in `models.dart`.

**Tech Stack:** Flutter/Dart, Provider (ChangeNotifier), REST API via `ApiService` (http package), FCM push notifications, `fl_chart` for vitals sparklines, `shimmer` for loading states, `image_picker` for prescription photos.

**Spec:** `docs/superpowers/specs/2026-03-21-my-care-tab-design.md`

**Phase 2 scope (not in this plan):** Prescription photo upload UI, equipment deposit display in billing, offline caching with "last updated" banner, per-staff attendance detail on top-level My Care tab (currently shows summary only — full detail is in ServiceDetailScreen).

---

## File Structure

### New Files

| File | Responsibility |
|---|---|
| `lib/models/my_care_models.dart` | `ActiveService`, `HealthManager`, `ServiceDetail`, `StaffAttendanceSummary` models |
| `lib/models/medication_models.dart` | `MedicationFull`, `MedicationLog`, `MedicationScheduleSlot` models |
| `lib/providers/my_care_provider.dart` | State management for My Care tab data (active services, health manager, attendance, billing) |
| `lib/providers/medication_provider.dart` | State management for medication CRUD + schedule + logs |
| `lib/screens/my_care/my_care_screen.dart` | Top-level My Care tab — scrollable page with 5 sections |
| `lib/screens/my_care/widgets/health_manager_banner.dart` | Sticky Health Manager contact card widget |
| `lib/screens/my_care/widgets/active_service_card.dart` | Color-coded service card with summary stats |
| `lib/screens/my_care/widgets/staff_attendance_section.dart` | Today's staff attendance list |
| `lib/screens/my_care/widgets/billing_summary_section.dart` | Pre-paid billing consumption tracker |
| `lib/screens/my_care/widgets/quick_actions_row.dart` | Raise Concern / Daily Reports / Documents tiles |
| `lib/screens/my_care/service_detail_screen.dart` | Full detail view for one active service |
| `lib/screens/my_care/widgets/vitals_trend_grid.dart` | 2x2 vitals grid with sparklines (care packages only) |
| `lib/screens/my_care/widgets/care_report_section.dart` | Today's task timeline with completion ring |
| `lib/screens/my_care/widgets/equipment_deployed_section.dart` | Equipment list with rental info |
| `lib/screens/my_care/report_history_screen.dart` | List of past daily reports |
| `lib/screens/my_care/attendance_history_screen.dart` | 30-day attendance log |
| `lib/screens/my_care/medications_screen.dart` | Full medication list + management |
| `lib/screens/my_care/medication_schedule_screen.dart` | Today's time-slotted medication schedule |
| `lib/screens/my_care/add_edit_medication_screen.dart` | Add/edit medication form |

### Modified Files

| File | Change |
|---|---|
| `lib/models/models.dart` | Keep existing `Medication` class (for Patient.medications backward compat). Add re-export of new model files. |
| `lib/providers/app_provider.dart` | Add public `ApiService get apiService` getter (currently `_apiService` is private). |
| `lib/services/api_service.dart` | Add 10 new API endpoint methods for My Care + Medications |
| `lib/main.dart` | Register 7 new routes, add `MyCareProvider` + `MedicationProvider` to MultiProvider |
| `lib/screens/main_shell.dart` | Replace VitalsScreen (index 1) with MyCareScreen, update icon/label |
| `lib/screens/home/home_screen.dart` | Add "View My Care" banner chip |
| `assets/i18n/en.json` | Add ~40 new English translation keys |
| `assets/i18n/hi.json` | Add ~40 new Hindi translation keys |
| `lib/config/theme.dart` | Add service category color constants |

---

## Chunk 1: Data Models + API Endpoints

### Task 1: Create My Care models

**Files:**
- Create: `lib/models/my_care_models.dart`

- [ ] **Step 1: Create `ActiveService` model**

```dart
// lib/models/my_care_models.dart

class ActiveService {
  final String id;
  final String name;
  final String serviceCategory; // care_package, nursing, caretaker, japa, nanny, physiotherapy, equipment_rental, doctor_visit, iv_visit, dressing
  final String status; // active, paused, completed
  final DateTime startDate;
  final DateTime? endDate;
  final int totalDays;
  final int consumedDays;
  final bool isSessionBased;

  // Staff summary (null for equipment-only)
  final int? totalStaff;
  final int? checkedInStaff;

  // Vitals summary (only for care_package)
  final String? latestVitalLabel;
  final String? latestVitalStatus; // normal, warning, critical

  // Billing
  final int? dailyRate;
  final int? totalPaid;
  final int? totalConsumed;
  final int? remaining;
  final DateTime? renewalDate;

  // Deployments linked to this service
  final List<String> deploymentIds;

  ActiveService({
    required this.id,
    required this.name,
    required this.serviceCategory,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.totalDays,
    required this.consumedDays,
    this.isSessionBased = false,
    this.totalStaff,
    this.checkedInStaff,
    this.latestVitalLabel,
    this.latestVitalStatus,
    this.dailyRate,
    this.totalPaid,
    this.totalConsumed,
    this.remaining,
    this.renewalDate,
    this.deploymentIds = const [],
  });

  double get progressFraction =>
      totalDays > 0 ? (consumedDays / totalDays).clamp(0.0, 1.0) : 0.0;

  int get daysRemaining => totalDays - consumedDays;

  bool get hasStaff => totalStaff != null && totalStaff! > 0;

  bool get isCarePackage => serviceCategory == 'care_package';

  bool get showVitals => serviceCategory == 'care_package';

  bool get showStaff => !const ['equipment_rental'].contains(serviceCategory);

  bool get showAttendance =>
      const ['care_package', 'nursing', 'caretaker', 'japa', 'nanny']
          .contains(serviceCategory);

  bool get showDailyReport =>
      const ['care_package', 'nursing', 'caretaker', 'japa', 'nanny']
          .contains(serviceCategory);

  bool get showMedications => serviceCategory == 'care_package';

  bool get showEquipment =>
      const ['care_package', 'equipment_rental'].contains(serviceCategory);

  factory ActiveService.fromJson(Map<String, dynamic> json) => ActiveService(
        id: json['id'],
        name: json['name'],
        serviceCategory: json['service_category'],
        status: json['status'] ?? 'active',
        startDate: DateTime.parse(json['start_date']),
        endDate:
            json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
        totalDays: json['total_days'] ?? 0,
        consumedDays: json['consumed_days'] ?? 0,
        isSessionBased: json['is_session_based'] ?? false,
        totalStaff: json['total_staff'],
        checkedInStaff: json['checked_in_staff'],
        latestVitalLabel: json['latest_vital_label'],
        latestVitalStatus: json['latest_vital_status'],
        dailyRate: json['daily_rate'],
        totalPaid: json['total_paid'],
        totalConsumed: json['total_consumed'],
        remaining: json['remaining'],
        renewalDate: json['renewal_date'] != null
            ? DateTime.parse(json['renewal_date'])
            : null,
        deploymentIds: json['deployment_ids'] != null
            ? List<String>.from(json['deployment_ids'])
            : [],
      );
}
```

- [ ] **Step 2: Add `HealthManager` model to same file**

```dart
class HealthManager {
  final String id;
  final String staffId;
  final String name;
  final String phone;
  final String? photoUrl;
  final String availableFrom; // "08:00"
  final String availableTo; // "20:00"

  HealthManager({
    required this.id,
    required this.staffId,
    required this.name,
    required this.phone,
    this.photoUrl,
    this.availableFrom = '08:00',
    this.availableTo = '20:00',
  });

  bool get isAvailableNow {
    final now = TimeOfDay.now();
    final from = _parseTime(availableFrom);
    final to = _parseTime(availableTo);
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= (from.hour * 60 + from.minute) &&
        nowMinutes <= (to.hour * 60 + to.minute);
  }

  String get availabilityLabel => '$availableFrom – $availableTo';

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  factory HealthManager.fromJson(Map<String, dynamic> json) => HealthManager(
        id: json['id'],
        staffId: json['staff_id'],
        name: json['name'],
        phone: json['phone'],
        photoUrl: json['photo_url'],
        availableFrom: json['available_from'] ?? '08:00',
        availableTo: json['available_to'] ?? '20:00',
      );
}
```

- [ ] **Step 3: Add `ServiceDetail` model for the full detail view response**

```dart
class ServiceDetail {
  final ActiveService service;
  final List<StaffOnDuty> staffOnDuty;
  final List<AttendanceDay> attendanceDays; // last 7 days
  final VitalsSummary? vitalsSummary;
  final CareReportSummary? todayReport;
  final List<EquipmentDeployed> equipment;

  ServiceDetail({
    required this.service,
    this.staffOnDuty = const [],
    this.attendanceDays = const [],
    this.vitalsSummary,
    this.todayReport,
    this.equipment = const [],
  });

  factory ServiceDetail.fromJson(Map<String, dynamic> json) => ServiceDetail(
        service: ActiveService.fromJson(json['service']),
        staffOnDuty: (json['staff_on_duty'] as List? ?? [])
            .map((s) => StaffOnDuty.fromJson(s))
            .toList(),
        attendanceDays: (json['attendance_days'] as List? ?? [])
            .map((a) => AttendanceDay.fromJson(a))
            .toList(),
        vitalsSummary: json['vitals_summary'] != null
            ? VitalsSummary.fromJson(json['vitals_summary'])
            : null,
        todayReport: json['today_report'] != null
            ? CareReportSummary.fromJson(json['today_report'])
            : null,
        equipment: (json['equipment'] as List? ?? [])
            .map((e) => EquipmentDeployed.fromJson(e))
            .toList(),
      );
}

class StaffOnDuty {
  final String id;
  final String name;
  final String? photoUrl;
  final String role;
  final String shiftType; // 12hr, 24hr
  final DateTime? checkInTime;
  final double? rating;
  final bool isReplacement;
  final String? replacingName;

  StaffOnDuty({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.role,
    required this.shiftType,
    this.checkInTime,
    this.rating,
    this.isReplacement = false,
    this.replacingName,
  });

  Duration? get onDutyDuration =>
      checkInTime != null ? DateTime.now().difference(checkInTime!) : null;

  factory StaffOnDuty.fromJson(Map<String, dynamic> json) => StaffOnDuty(
        id: json['id'],
        name: json['name'],
        photoUrl: json['photo_url'],
        role: json['role'],
        shiftType: json['shift_type'] ?? '24hr',
        checkInTime: json['check_in_time'] != null
            ? DateTime.parse(json['check_in_time'])
            : null,
        rating: (json['rating'] as num?)?.toDouble(),
        isReplacement: json['is_replacement'] ?? false,
        replacingName: json['replacing_name'],
      );
}

class AttendanceDay {
  final DateTime date;
  final String status; // on_time, late, replacement, absent, leave
  final String? staffName;
  final String? replacementName;

  AttendanceDay({
    required this.date,
    required this.status,
    this.staffName,
    this.replacementName,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) => AttendanceDay(
        date: DateTime.parse(json['date']),
        status: json['status'],
        staffName: json['staff_name'],
        replacementName: json['replacement_name'],
      );
}

class VitalsSummary {
  final VitalCard bp;
  final VitalCard spo2;
  final VitalCard pulse;
  final VitalCard temperature;

  VitalsSummary({
    required this.bp,
    required this.spo2,
    required this.pulse,
    required this.temperature,
  });

  factory VitalsSummary.fromJson(Map<String, dynamic> json) => VitalsSummary(
        bp: VitalCard.fromJson(json['bp']),
        spo2: VitalCard.fromJson(json['spo2']),
        pulse: VitalCard.fromJson(json['pulse']),
        temperature: VitalCard.fromJson(json['temperature']),
      );
}

class VitalCard {
  final String label; // "128/82", "97%", "78 bpm", "98.6°F"
  final String status; // normal, warning, critical
  final List<double> sparkline; // last 7 readings

  VitalCard({
    required this.label,
    required this.status,
    this.sparkline = const [],
  });

  factory VitalCard.fromJson(Map<String, dynamic> json) => VitalCard(
        label: json['label'],
        status: json['status'] ?? 'normal',
        sparkline: (json['sparkline'] as List? ?? [])
            .map((v) => (v as num).toDouble())
            .toList(),
      );
}

class CareReportSummary {
  final int totalTasks;
  final int completedTasks;
  final List<ReportTaskItem> tasks;
  final String? staffNotes;

  CareReportSummary({
    required this.totalTasks,
    required this.completedTasks,
    this.tasks = const [],
    this.staffNotes,
  });

  double get completionFraction =>
      totalTasks > 0 ? completedTasks / totalTasks : 0.0;

  factory CareReportSummary.fromJson(Map<String, dynamic> json) =>
      CareReportSummary(
        totalTasks: json['total_tasks'] ?? 0,
        completedTasks: json['completed_tasks'] ?? 0,
        tasks: (json['tasks'] as List? ?? [])
            .map((t) => ReportTaskItem.fromJson(t))
            .toList(),
        staffNotes: json['staff_notes'],
      );
}

class ReportTaskItem {
  final String name;
  final String status; // completed, in_progress, upcoming
  final String? completedAt;

  ReportTaskItem({
    required this.name,
    required this.status,
    this.completedAt,
  });

  factory ReportTaskItem.fromJson(Map<String, dynamic> json) => ReportTaskItem(
        name: json['name'],
        status: json['status'],
        completedAt: json['completed_at'],
      );
}

class EquipmentDeployed {
  final String name;
  final int monthlyRate;
  final DateTime startDate;
  final String status; // active, returned

  EquipmentDeployed({
    required this.name,
    required this.monthlyRate,
    required this.startDate,
    this.status = 'active',
  });

  factory EquipmentDeployed.fromJson(Map<String, dynamic> json) =>
      EquipmentDeployed(
        name: json['name'],
        monthlyRate: json['monthly_rate'] ?? 0,
        startDate: DateTime.parse(json['start_date']),
        status: json['status'] ?? 'active',
      );
}
```

- [ ] **Step 4: Verify the file compiles**

Run: `cd /Users/ateeshayjain/housepital_patient_app && flutter analyze lib/models/my_care_models.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/models/my_care_models.dart
git commit -m "feat(my-care): add ActiveService, HealthManager, ServiceDetail models"
```

---

### Task 2: Create Medication models

**Files:**
- Create: `lib/models/medication_models.dart`

- [ ] **Step 1: Create `MedicationFull` model**

The existing `Medication` class in `models.dart:94-109` is a simple name/dosage/schedule model used by `Patient.medications`. The new model is much richer — name it `MedicationFull` to avoid collision during migration.

```dart
// lib/models/medication_models.dart

class MedicationFull {
  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String form; // tablet, injection, syrup, inhaler, drops
  final String frequency; // once_daily, twice_daily, thrice_daily, four_times_daily, as_needed
  final List<String> timeSlots; // ["08:00", "14:00", "21:00"]
  final String? instructions;
  final String? prescribedBy;
  final DateTime? prescribedDate;
  final DateTime? endDate;
  final int? stockCount;
  final String? stockUnit; // tablets, units, ml, puffs
  final String? prescriptionPhotoUrl;
  final bool isActive;

  MedicationFull({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    this.form = 'tablet',
    this.frequency = 'once_daily',
    this.timeSlots = const [],
    this.instructions,
    this.prescribedBy,
    this.prescribedDate,
    this.endDate,
    this.stockCount,
    this.stockUnit,
    this.prescriptionPhotoUrl,
    this.isActive = true,
  });

  /// Estimate days of supply remaining based on frequency.
  int? get daysOfSupplyLeft {
    if (stockCount == null || stockCount! <= 0) return null;
    final dosesPerDay = _dosesPerDay;
    if (dosesPerDay <= 0) return null;
    return (stockCount! / dosesPerDay).floor();
  }

  bool get isLowStock => (daysOfSupplyLeft ?? 999) < 5;

  int get _dosesPerDay {
    switch (frequency) {
      case 'once_daily':
        return 1;
      case 'twice_daily':
        return 2;
      case 'thrice_daily':
        return 3;
      case 'four_times_daily':
        return 4;
      default:
        return 1;
    }
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'once_daily':
        return 'Once daily';
      case 'twice_daily':
        return 'Twice daily';
      case 'thrice_daily':
        return 'Three times daily';
      case 'four_times_daily':
        return 'Four times daily';
      case 'as_needed':
        return 'As needed';
      default:
        return frequency;
    }
  }

  factory MedicationFull.fromJson(Map<String, dynamic> json) => MedicationFull(
        id: json['id'],
        patientId: json['patient_id'],
        name: json['name'],
        dosage: json['dosage'] ?? '',
        form: json['form'] ?? 'tablet',
        frequency: json['frequency'] ?? 'once_daily',
        timeSlots: json['time_slots'] != null
            ? List<String>.from(json['time_slots'])
            : [],
        instructions: json['instructions'],
        prescribedBy: json['prescribed_by'],
        prescribedDate: json['prescribed_date'] != null
            ? DateTime.parse(json['prescribed_date'])
            : null,
        endDate:
            json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
        stockCount: json['stock_count'],
        stockUnit: json['stock_unit'],
        prescriptionPhotoUrl: json['prescription_photo_url'],
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage': dosage,
        'form': form,
        'frequency': frequency,
        'time_slots': timeSlots,
        'instructions': instructions,
        'prescribed_by': prescribedBy,
        'prescribed_date': prescribedDate?.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'stock_count': stockCount,
        'stock_unit': stockUnit,
      };
}
```

- [ ] **Step 2: Add `MedicationLog` model**

```dart
class MedicationLog {
  final String id;
  final String medicationId;
  final String? staffId;
  final String? staffName;
  final DateTime scheduledTime;
  final DateTime? actualTime;
  final String status; // administered, skipped, missed
  final String? skipReason;
  final String? notes;

  MedicationLog({
    required this.id,
    required this.medicationId,
    this.staffId,
    this.staffName,
    required this.scheduledTime,
    this.actualTime,
    required this.status,
    this.skipReason,
    this.notes,
  });

  bool get wasGiven => status == 'administered';
  bool get wasSkipped => status == 'skipped';
  bool get wasMissed => status == 'missed';

  factory MedicationLog.fromJson(Map<String, dynamic> json) => MedicationLog(
        id: json['id'],
        medicationId: json['medication_id'],
        staffId: json['staff_id'],
        staffName: json['staff_name'],
        scheduledTime: DateTime.parse(json['scheduled_time']),
        actualTime: json['actual_time'] != null
            ? DateTime.parse(json['actual_time'])
            : null,
        status: json['status'],
        skipReason: json['skip_reason'],
        notes: json['notes'],
      );
}
```

- [ ] **Step 3: Add `MedicationScheduleSlot` — view model grouping meds by time of day**

```dart
/// Groups medications + their logs for a specific time slot (e.g., "Morning — 8:00 AM").
class MedicationScheduleSlot {
  final String label; // "Morning", "Afternoon", "Night"
  final String time; // "08:00"
  final String icon; // emoji
  final List<ScheduledMedication> medications;

  MedicationScheduleSlot({
    required this.label,
    required this.time,
    required this.icon,
    this.medications = const [],
  });

  int get givenCount => medications.where((m) => m.log?.wasGiven ?? false).length;
  int get totalCount => medications.length;
  bool get allGiven => givenCount == totalCount && totalCount > 0;
  bool get hasPending => medications.any((m) => m.log == null && !m.isPast);
  String get summaryLabel {
    if (allGiven) return '$givenCount/$totalCount Given';
    if (givenCount > 0) return '$givenCount/$totalCount Given';
    final now = DateTime.now();
    final slotHour = int.tryParse(time.split(':').first) ?? 0;
    if (now.hour < slotHour) return '0/$totalCount Upcoming';
    return '0/$totalCount Pending';
  }
}

class ScheduledMedication {
  final MedicationFull medication;
  final MedicationLog? log; // null if not yet administered/skipped/missed
  final DateTime scheduledTime;

  ScheduledMedication({
    required this.medication,
    this.log,
    required this.scheduledTime,
  });

  bool get isPast => DateTime.now().isAfter(scheduledTime);
}
```

- [ ] **Step 4: Verify the file compiles**

Run: `cd /Users/ateeshayjain/housepital_patient_app && flutter analyze lib/models/medication_models.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/models/medication_models.dart
git commit -m "feat(my-care): add MedicationFull, MedicationLog, MedicationScheduleSlot models"
```

---

### Task 3: Add API endpoints to ApiService

**Files:**
- Modify: `lib/services/api_service.dart:441-456` (add before closing brace of class, after `getEquipmentCatalog`)

- [ ] **Step 1: Add `_delete` helper method**

Add after the `_put` method (line 46 in `api_service.dart`):

```dart
  Future<Map<String, dynamic>> _delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    return _handleResponse(response);
  }
```

- [ ] **Step 2: Add My Care API methods**

Add at the end of the class, before the closing `}`:

```dart
  // ==================== MY CARE ====================

  Future<List<ActiveService>> getActiveServices(String patientId) async {
    final data = await _get('/patients/$patientId/active-services');
    return (data['services'] as List)
        .map((s) => ActiveService.fromJson(s))
        .toList();
  }

  Future<HealthManager?> getHealthManager(String patientId) async {
    try {
      final data = await _get('/patients/$patientId/health-manager');
      return HealthManager.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ServiceDetail> getServiceDetail(String deploymentId) async {
    final data = await _get('/deployments/$deploymentId/service-detail');
    return ServiceDetail.fromJson(data);
  }

  Future<List<Attendance>> getAttendanceHistoryPaginated(
    String deploymentId, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final data = await _get(
      '/deployments/$deploymentId/attendance',
      queryParams: {'page': '$page', 'page_size': '$pageSize'},
    );
    return (data['records'] as List)
        .map((a) => Attendance.fromJson(a))
        .toList();
  }
```

- [ ] **Step 3: Add Medication API methods**

```dart
  // ==================== MEDICATIONS ====================

  Future<List<MedicationFull>> getMedications(String patientId) async {
    final data = await _get('/patients/$patientId/medications');
    return (data['medications'] as List)
        .map((m) => MedicationFull.fromJson(m))
        .toList();
  }

  Future<MedicationFull> addMedication(
      String patientId, Map<String, dynamic> body) async {
    final data =
        await _post('/patients/$patientId/medications', body: body);
    return MedicationFull.fromJson(data);
  }

  Future<MedicationFull> updateMedication(
      String patientId, String medicationId, Map<String, dynamic> body) async {
    final data = await _put(
        '/patients/$patientId/medications/$medicationId',
        body: body);
    return MedicationFull.fromJson(data);
  }

  Future<void> deleteMedication(
      String patientId, String medicationId) async {
    await _delete('/patients/$patientId/medications/$medicationId');
  }

  Future<List<MedicationLog>> getMedicationLogs(
    String patientId, {
    String? date, // YYYY-MM-DD, defaults to today on backend
  }) async {
    final params = <String, String>{};
    if (date != null) params['date'] = date;
    final data = await _get('/patients/$patientId/medication-logs',
        queryParams: params.isNotEmpty ? params : null);
    return (data['logs'] as List)
        .map((l) => MedicationLog.fromJson(l))
        .toList();
  }

  /// Note: Spec says /medication-logs/{id}/stock but stock belongs on the medication
  /// entity, not on a log entry. Using /medications/{id}/stock instead.
  Future<void> updateMedicationStock(
      String patientId, String medicationId, int stockCount) async {
    await _put('/patients/$patientId/medications/$medicationId/stock',
        body: {'stock_count': stockCount});
  }
```

- [ ] **Step 4: Add required imports at top of api_service.dart**

```dart
import '../models/my_care_models.dart';
import '../models/medication_models.dart';
```

- [ ] **Step 5: Verify compiles**

Run: `cd /Users/ateeshayjain/housepital_patient_app && flutter analyze lib/services/api_service.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/services/api_service.dart
git commit -m "feat(my-care): add My Care + Medication API endpoints to ApiService"
```

---

### Task 4: Add service category colors to theme

**Files:**
- Modify: `lib/config/theme.dart` (add to `HousepitalColors` class)

- [ ] **Step 1: Add color constants**

Add to the `HousepitalColors` class:

```dart
  // Service category colors (card headers)
  static const Color serviceCarePackage = Color(0xFFDC2626); // red
  static const Color serviceNursing = Color(0xFFEA580C); // orange
  static const Color serviceCaretaker = Color(0xFF0D9488); // teal
  static const Color serviceJapaNanny = Color(0xFF7C3AED); // purple
  static const Color servicePhysio = Color(0xFF2563EB); // blue
  static const Color serviceEquipment = Color(0xFF059669); // green

  static Color serviceColor(String category) {
    switch (category) {
      case 'care_package':
        return serviceCarePackage;
      case 'nursing':
        return serviceNursing;
      case 'caretaker':
        return serviceCaretaker;
      case 'japa':
      case 'nanny':
        return serviceJapaNanny;
      case 'physiotherapy':
      case 'doctor_visit':
      case 'iv_visit':
      case 'dressing':
        return servicePhysio;
      case 'equipment_rental':
        return serviceEquipment;
      default:
        return serviceNursing;
    }
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/config/theme.dart
git commit -m "feat(my-care): add service category color palette to theme"
```

---

## Chunk 2: Providers (State Management)

### Task 5: Create MyCareProvider

**Files:**
- Create: `lib/providers/my_care_provider.dart`

- [ ] **Step 1: Create provider with data loading**

```dart
import 'package:flutter/material.dart';
import '../models/my_care_models.dart';
import '../services/api_service.dart';

class MyCareProvider extends ChangeNotifier {
  final ApiService _apiService;

  // State
  List<ActiveService> _activeServices = [];
  HealthManager? _healthManager;
  ServiceDetail? _selectedServiceDetail;
  bool _isLoading = false;
  bool _isDetailLoading = false;
  String? _error;
  String? _detailError;
  DateTime? _lastFetchedAt;

  MyCareProvider(this._apiService);

  // Getters
  List<ActiveService> get activeServices => _activeServices;
  HealthManager? get healthManager => _healthManager;
  ServiceDetail? get selectedServiceDetail => _selectedServiceDetail;
  bool get isLoading => _isLoading;
  bool get isDetailLoading => _isDetailLoading;
  String? get error => _error;
  String? get detailError => _detailError;
  bool get hasActiveServices => _activeServices.isNotEmpty;
  bool get isStale =>
      _lastFetchedAt == null ||
      DateTime.now().difference(_lastFetchedAt!) > const Duration(seconds: 60);

  /// Load top-level My Care data: active services + health manager.
  Future<void> loadMyCareData(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getActiveServices(patientId),
        _apiService.getHealthManager(patientId),
      ]);

      _activeServices = results[0] as List<ActiveService>;
      _healthManager = results[1] as HealthManager?;
      _lastFetchedAt = DateTime.now();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load care data';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load full detail for a single service/deployment.
  Future<void> loadServiceDetail(String deploymentId) async {
    _isDetailLoading = true;
    _detailError = null;
    _selectedServiceDetail = null;
    notifyListeners();

    try {
      _selectedServiceDetail =
          await _apiService.getServiceDetail(deploymentId);
    } on ApiException catch (e) {
      _detailError = e.message;
    } catch (e) {
      _detailError = 'Failed to load service detail';
    }

    _isDetailLoading = false;
    notifyListeners();
  }

  /// Called by FCM handler or pull-to-refresh.
  Future<void> refresh(String patientId) => loadMyCareData(patientId);
}
```

- [ ] **Step 2: Verify compiles**

Run: `cd /Users/ateeshayjain/housepital_patient_app && flutter analyze lib/providers/my_care_provider.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/providers/my_care_provider.dart
git commit -m "feat(my-care): add MyCareProvider for active services + health manager state"
```

---

### Task 6: Create MedicationProvider

**Files:**
- Create: `lib/providers/medication_provider.dart`

- [ ] **Step 1: Create provider**

```dart
import 'package:flutter/material.dart';
import '../models/medication_models.dart';
import '../services/api_service.dart';

class MedicationProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<MedicationFull> _medications = [];
  List<MedicationLog> _todayLogs = [];
  List<MedicationScheduleSlot> _schedule = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  MedicationProvider(this._apiService);

  // Getters
  List<MedicationFull> get medications => _medications;
  List<MedicationLog> get todayLogs => _todayLogs;
  List<MedicationScheduleSlot> get schedule => _schedule;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  List<MedicationFull> get activeMedications =>
      _medications.where((m) => m.isActive).toList();

  List<MedicationFull> get lowStockMedications =>
      activeMedications.where((m) => m.isLowStock).toList();

  /// Load medications list.
  Future<void> loadMedications(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _medications = await _apiService.getMedications(patientId);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load medications';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load today's medication schedule (meds + logs, grouped by time slot).
  Future<void> loadTodaySchedule(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getMedications(patientId),
        _apiService.getMedicationLogs(patientId),
      ]);

      _medications = results[0] as List<MedicationFull>;
      _todayLogs = results[1] as List<MedicationLog>;
      _schedule = _buildSchedule();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load schedule';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new medication.
  Future<bool> addMedication(String patientId, Map<String, dynamic> body) async {
    _isSaving = true;
    notifyListeners();

    try {
      final med = await _apiService.addMedication(patientId, body);
      _medications.add(med);
      _isSaving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Update an existing medication.
  Future<bool> updateMedication(
      String patientId, String medicationId, Map<String, dynamic> body) async {
    _isSaving = true;
    notifyListeners();

    try {
      final updated =
          await _apiService.updateMedication(patientId, medicationId, body);
      final index = _medications.indexWhere((m) => m.id == medicationId);
      if (index != -1) _medications[index] = updated;
      _isSaving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Soft-delete a medication.
  Future<bool> deleteMedication(String patientId, String medicationId) async {
    try {
      await _apiService.deleteMedication(patientId, medicationId);
      _medications.removeWhere((m) => m.id == medicationId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Update stock count for a medication.
  Future<void> updateStock(
      String patientId, String medicationId, int newCount) async {
    try {
      await _apiService.updateMedicationStock(patientId, medicationId, newCount);
      final index = _medications.indexWhere((m) => m.id == medicationId);
      if (index != -1) {
        // Reload single medication to get updated data
        await loadMedications(patientId);
      }
    } catch (_) {
      // Silently fail — stock update is non-critical
    }
  }

  /// Build schedule slots from medications + today's logs.
  List<MedicationScheduleSlot> _buildSchedule() {
    final slotMap = <String, List<ScheduledMedication>>{};
    final today = DateTime.now();

    for (final med in activeMedications) {
      if (med.frequency == 'as_needed') continue;

      for (final timeStr in med.timeSlots) {
        final parts = timeStr.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        final scheduledTime =
            DateTime(today.year, today.month, today.day, hour, minute);

        // Find matching log
        final log = _todayLogs.cast<MedicationLog?>().firstWhere(
              (l) =>
                  l!.medicationId == med.id &&
                  l.scheduledTime.hour == hour &&
                  l.scheduledTime.minute == minute,
              orElse: () => null,
            );

        final key = timeStr;
        slotMap.putIfAbsent(key, () => []);
        slotMap[key]!.add(ScheduledMedication(
          medication: med,
          log: log,
          scheduledTime: scheduledTime,
        ));
      }
    }

    // Sort slots by time and assign labels
    final sortedKeys = slotMap.keys.toList()..sort();
    return sortedKeys.map((time) {
      final hour = int.tryParse(time.split(':').first) ?? 0;
      String label;
      String icon;
      if (hour < 12) {
        label = 'Morning';
        icon = '\u{1F305}'; // sunrise emoji
      } else if (hour < 17) {
        label = 'Afternoon';
        icon = '\u{2600}\u{FE0F}'; // sun emoji
      } else {
        label = 'Night';
        icon = '\u{1F319}'; // crescent moon emoji
      }

      return MedicationScheduleSlot(
        label: label,
        time: time,
        icon: icon,
        medications: slotMap[time]!,
      );
    }).toList();
  }
}
```

- [ ] **Step 2: Verify compiles**

Run: `cd /Users/ateeshayjain/housepital_patient_app && flutter analyze lib/providers/medication_provider.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/providers/medication_provider.dart
git commit -m "feat(my-care): add MedicationProvider for medication CRUD + schedule"
```

---

### Task 7: Register providers + routes in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add imports at top of `main.dart`**

Add after line 12 (`import 'utils/app_localizations.dart';`):

```dart
import 'providers/my_care_provider.dart';
import 'providers/medication_provider.dart';
import 'screens/my_care/my_care_screen.dart';
import 'screens/my_care/service_detail_screen.dart';
import 'screens/my_care/report_history_screen.dart';
import 'screens/my_care/medications_screen.dart';
import 'screens/my_care/medication_schedule_screen.dart';
import 'screens/my_care/add_edit_medication_screen.dart';
import 'screens/my_care/attendance_history_screen.dart';
import 'models/my_care_models.dart';
import 'models/medication_models.dart';
```

- [ ] **Step 1b: Add public `apiService` getter to AppProvider**

In `lib/providers/app_provider.dart`, add after line 7 (`final ApiService _apiService;`):

```dart
  ApiService get apiService => _apiService;
```

This allows screens like `ReportHistoryScreen` and `AttendanceHistoryScreen` to access the authenticated `ApiService` instance.

- [ ] **Step 2: Add providers to MultiProvider**

Add after the `CartProvider` (line 58-60), before the closing `]`:

```dart
        ChangeNotifierProvider(
          create: (ctx) => MyCareProvider(ctx.read<AuthProvider>().apiService ?? ApiService()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MedicationProvider(ctx.read<AuthProvider>().apiService ?? ApiService()),
        ),
```

**Note:** Since providers need `ApiService`, and `ApiService` is created at the top of `main()` as a local variable, the cleanest approach is to pass `apiService` directly:

```dart
        ChangeNotifierProvider(
          create: (_) => MyCareProvider(apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => MedicationProvider(apiService),
        ),
```

- [ ] **Step 3: Add new routes to `onGenerateRoute`**

Add these cases before the `default:` case (line 198):

```dart
          case '/service-detail':
            final service = settings.arguments as ActiveService;
            return MaterialPageRoute(
                builder: (_) => ServiceDetailScreen(service: service));
          case '/report-history':
            final deploymentId = settings.arguments as String;
            return MaterialPageRoute(
                builder: (_) =>
                    ReportHistoryScreen(deploymentId: deploymentId));
          case '/medications':
            return MaterialPageRoute(
                builder: (_) => const MedicationsScreen());
          case '/medication-schedule':
            return MaterialPageRoute(
                builder: (_) => const MedicationScheduleScreen());
          case '/medication-add':
            final medication = settings.arguments as MedicationFull?;
            return MaterialPageRoute(
                builder: (_) =>
                    AddEditMedicationScreen(medication: medication));
          case '/attendance-history':
            final deploymentId = settings.arguments as String;
            return MaterialPageRoute(
                builder: (_) =>
                    AttendanceHistoryScreen(deploymentId: deploymentId));
```

- [ ] **Step 4: Verify compiles** (will have import errors until screens are created — that's expected, skip if screens don't exist yet)

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat(my-care): register MyCareProvider, MedicationProvider, and 7 new routes"
```

---

## Chunk 3: My Care Tab Screen + Widgets

### Task 8: Create My Care tab screen

**Files:**
- Create: `lib/screens/my_care/my_care_screen.dart`

- [ ] **Step 1: Create the main screen**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/my_care_provider.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/common_widgets.dart';
import '../../screens/main_shell.dart';
import 'widgets/health_manager_banner.dart';
import 'widgets/active_service_card.dart';
import 'widgets/staff_attendance_section.dart';
import 'widgets/billing_summary_section.dart';
import 'widgets/quick_actions_row.dart';

class MyCareScreen extends StatefulWidget {
  const MyCareScreen({super.key});

  @override
  State<MyCareScreen> createState() => _MyCareScreenState();
}

class _MyCareScreenState extends State<MyCareScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => _loadData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes to foreground and data is stale
    if (state == AppLifecycleState.resumed) {
      final myCare = context.read<MyCareProvider>();
      if (myCare.isStale) _loadData();
    }
  }

  void _loadData() {
    final patientId = context.read<AppProvider>().currentPatient?.id;
    if (patientId != null) {
      context.read<MyCareProvider>().loadMyCareData(patientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final myCare = context.watch<MyCareProvider>();
    final app = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('tab_my_care')),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final patientId = app.currentPatient?.id;
          if (patientId != null) {
            await myCare.refresh(patientId);
          }
        },
        child: _buildBody(myCare, app, l),
      ),
    );
  }

  Widget _buildBody(MyCareProvider myCare, AppProvider app, AppLocalizations l) {
    if (myCare.isLoading && myCare.activeServices.isEmpty) {
      return const Center(child: LoadingWidget());
    }

    if (myCare.error != null && myCare.activeServices.isEmpty) {
      return _buildError(myCare, app, l);
    }

    if (!myCare.hasActiveServices) {
      return _buildEmpty(l);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Health Manager Banner
          if (myCare.healthManager != null)
            HealthManagerBanner(manager: myCare.healthManager!),

          // 2. Active Services
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l.t('active_services'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          ...myCare.activeServices.map((service) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ActiveServiceCard(
                  service: service,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/service-detail',
                    arguments: service,
                  ),
                ),
              )),

          // 3. Today's Staff Attendance
          if (myCare.activeServices.any((s) => s.hasStaff))
            StaffAttendanceSection(services: myCare.activeServices),

          // 4. Billing Summary
          if (myCare.activeServices.any((s) => s.totalPaid != null))
            BillingSummarySection(services: myCare.activeServices),

          // 5. Quick Actions
          const QuickActionsRow(),
        ],
      ),
    );
  }

  Widget _buildError(
      MyCareProvider myCare, AppProvider app, AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l.t('error_load_data'),
              style: const TextStyle(color: HousepitalColors.greyLight)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loadData,
            child: Text(l.t('tap_to_retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border,
                size: 64, color: HousepitalColors.greyLight),
            const SizedBox(height: 16),
            Text(l.t('no_active_services'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(l.t('no_active_services_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: HousepitalColors.greyLight)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => MainShell.switchToTab(2), // Services tab
              child: Text(l.t('book_a_service')),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/vitals'),
              child: Text(l.t('view_vitals_history')),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/my_care/my_care_screen.dart
git commit -m "feat(my-care): add MyCareScreen — main tab with sections"
```

---

### Task 9: Create My Care widgets

**Files:**
- Create: `lib/screens/my_care/widgets/health_manager_banner.dart`
- Create: `lib/screens/my_care/widgets/active_service_card.dart`
- Create: `lib/screens/my_care/widgets/staff_attendance_section.dart`
- Create: `lib/screens/my_care/widgets/billing_summary_section.dart`
- Create: `lib/screens/my_care/widgets/quick_actions_row.dart`

- [ ] **Step 1: Create `HealthManagerBanner`**

```dart
// lib/screens/my_care/widgets/health_manager_banner.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';

class HealthManagerBanner extends StatelessWidget {
  final HealthManager manager;

  const HealthManagerBanner({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF5EB), Color(0xFFFFF0E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE0C0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: HousepitalColors.orange,
            backgroundImage: manager.photoUrl != null
                ? NetworkImage(manager.photoUrl!)
                : null,
            child: manager.photoUrl == null
                ? Text(
                    manager.name.split(' ').map((n) => n[0]).take(2).join(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Health Manager',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        letterSpacing: 0.5)),
                Text(manager.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                    'Available ${manager.availableFrom} – ${manager.availableTo}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                launchUrl(Uri.parse('tel:${manager.phone}')),
            style: IconButton.styleFrom(
              backgroundColor: HousepitalColors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.phone, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () =>
                launchUrl(Uri.parse('sms:${manager.phone}')),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create `ActiveServiceCard`**

```dart
// lib/screens/my_care/widgets/active_service_card.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/helpers.dart';

class ActiveServiceCard extends StatelessWidget {
  final ActiveService service;
  final VoidCallback onTap;

  const ActiveServiceCard({
    super.key,
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = HousepitalColors.serviceColor(service.serviceCategory);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // Color-coded header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      service.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      service.isSessionBased
                          ? 'Session ${service.consumedDays} of ${service.totalDays}'
                          : 'Day ${service.consumedDays} of ${service.totalDays}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (service.hasStaff)
                        _stat('Staff Today',
                            '${service.checkedInStaff}/${service.totalStaff} ${service.checkedInStaff == service.totalStaff ? "\u2713" : ""}',
                            service.checkedInStaff == service.totalStaff
                                ? HousepitalColors.success
                                : HousepitalColors.warning),
                      if (service.showVitals && service.latestVitalLabel != null)
                        _stat('Latest', service.latestVitalLabel!,
                            _vitalColor(service.latestVitalStatus)),
                      if (service.renewalDate != null)
                        _stat('Renewal', '${service.daysRemaining} days',
                            HousepitalColors.grey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: service.progressFraction,
                      minHeight: 4,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor)),
      ],
    );
  }

  Color _vitalColor(String? status) {
    switch (status) {
      case 'critical':
        return HousepitalColors.error;
      case 'warning':
        return HousepitalColors.warning;
      default:
        return HousepitalColors.success;
    }
  }
}
```

- [ ] **Step 3: Create `StaffAttendanceSection`**

```dart
// lib/screens/my_care/widgets/staff_attendance_section.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/app_localizations.dart';

class StaffAttendanceSection extends StatelessWidget {
  final List<ActiveService> services;

  const StaffAttendanceSection({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Aggregate staff status from all services that have staff
    final staffServices = services.where((s) => s.hasStaff).toList();
    if (staffServices.isEmpty) return const SizedBox.shrink();

    final totalStaff =
        staffServices.fold<int>(0, (sum, s) => sum + (s.totalStaff ?? 0));
    final checkedIn =
        staffServices.fold<int>(0, (sum, s) => sum + (s.checkedInStaff ?? 0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.t('todays_staff'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '$checkedIn/$totalStaff checked in',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: checkedIn == totalStaff
                      ? HousepitalColors.success
                      : HousepitalColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Summary card — detailed attendance is in ServiceDetailScreen
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    checkedIn == totalStaff
                        ? Icons.check_circle
                        : Icons.access_time,
                    color: checkedIn == totalStaff
                        ? HousepitalColors.success
                        : HousepitalColors.warning,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      checkedIn == totalStaff
                          ? l.t('all_staff_checked_in')
                          : l.t('staff_pending_checkin'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Create `BillingSummarySection`**

```dart
// lib/screens/my_care/widgets/billing_summary_section.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/helpers.dart';
import '../../../utils/app_localizations.dart';

class BillingSummarySection extends StatelessWidget {
  final List<ActiveService> services;

  const BillingSummarySection({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Aggregate billing from all services
    final totalPaid =
        services.fold<int>(0, (sum, s) => sum + (s.totalPaid ?? 0));
    final totalConsumed =
        services.fold<int>(0, (sum, s) => sum + (s.totalConsumed ?? 0));
    final remaining =
        services.fold<int>(0, (sum, s) => sum + (s.remaining ?? 0));
    final progress =
        totalPaid > 0 ? (totalConsumed / totalPaid).clamp(0.0, 1.0) : 0.0;

    // Earliest renewal date
    final renewalDates = services
        .where((s) => s.renewalDate != null)
        .map((s) => s.renewalDate!)
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('billing_summary'),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Package Paid',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400])),
                          Text(DateHelper.formatCurrency(totalPaid),
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Consumed',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400])),
                          Text(DateHelper.formatCurrency(totalConsumed),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: HousepitalColors.orange)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation(
                          HousepitalColors.orange),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          '${DateHelper.formatCurrency(totalConsumed)} consumed',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      Text(
                          '${DateHelper.formatCurrency(remaining)} remaining',
                          style: const TextStyle(
                              fontSize: 12,
                              color: HousepitalColors.success,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (renewalDates.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Next renewal',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        Text(DateHelper.formatDate(renewalDates.first),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/billing'),
                      child: Text(l.t('view_invoices')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Create `QuickActionsRow`**

```dart
// lib/screens/my_care/widgets/quick_actions_row.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../utils/app_localizations.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _tile(
            context,
            icon: Icons.warning_amber_rounded,
            label: l.t('raise_concern'),
            subtitle: l.t('staff_service_billing'),
            color: HousepitalColors.error,
            bgColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
            onTap: () => Navigator.pushNamed(context, '/raise-concern'),
          ),
          const SizedBox(width: 10),
          _tile(
            context,
            icon: Icons.assignment_outlined,
            label: l.t('daily_reports'),
            subtitle: l.t('view_all_reports'),
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
            onTap: () => Navigator.pushNamed(context, '/report-history',
                arguments: ''), // TODO: pass primary deploymentId
          ),
          const SizedBox(width: 10),
          _tile(
            context,
            icon: Icons.description_outlined,
            label: l.t('documents'),
            subtitle: l.t('prescriptions_reports'),
            color: HousepitalColors.success,
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
            onTap: () => Navigator.pushNamed(context, '/documents'),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Verify all widget files compile**

Run: `cd /Users/ateeshayjain/housepital_patient_app && flutter analyze lib/screens/my_care/widgets/`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/screens/my_care/widgets/
git commit -m "feat(my-care): add My Care widgets — health manager, service card, attendance, billing, quick actions"
```

---

### Task 10: Wire up MainShell tab replacement

**Files:**
- Modify: `lib/screens/main_shell.dart`

- [ ] **Step 1: Replace VitalsScreen import with MyCareScreen**

Replace line 5 (`import 'reports/vitals_screen.dart';`) with:
```dart
import 'my_care/my_care_screen.dart';
```

- [ ] **Step 2: Replace VitalsScreen in `_screens` list**

Replace line 30 (`const VitalsScreen(),`) with:
```dart
    const MyCareScreen(),
```

- [ ] **Step 3: Update tab icon and label**

Replace lines 60-64:
```dart
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart_outlined),
            activeIcon: const Icon(Icons.bar_chart),
            label: l.t('tab_reports'),
          ),
```
With:
```dart
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_outline),
            activeIcon: const Icon(Icons.favorite),
            label: l.t('tab_my_care'),
          ),
```

- [ ] **Step 4: Verify compiles**

Run: `cd /Users/ateeshayjain/housepital_patient_app && flutter analyze lib/screens/main_shell.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/screens/main_shell.dart
git commit -m "feat(my-care): replace Reports tab with My Care in bottom navigation"
```

---

### Task 11: Add localization keys

**Files:**
- Modify: `assets/i18n/en.json`
- Modify: `assets/i18n/hi.json`

- [ ] **Step 1: Add English keys**

Add these keys to `en.json`:

```json
  "tab_my_care": "My Care",
  "active_services": "Active Services",
  "todays_staff": "Today's Staff",
  "all_staff_checked_in": "All staff checked in and on duty",
  "staff_pending_checkin": "Some staff haven't checked in yet",
  "billing_summary": "Billing Summary",
  "view_invoices": "View Invoices & Payment History",
  "raise_concern": "Raise Concern",
  "staff_service_billing": "Staff, service, billing",
  "daily_reports": "Daily Reports",
  "view_all_reports": "View all reports",
  "documents": "Documents",
  "prescriptions_reports": "Prescriptions, reports",
  "no_active_services": "No Active Services",
  "no_active_services_desc": "You don't have any active services right now. Book a service to get started.",
  "book_a_service": "Book a Service",
  "view_vitals_history": "View Vitals History",
  "error_load_data": "Couldn't load data",
  "tap_to_retry": "Tap to retry",
  "medications": "Medications",
  "medication_schedule": "Today's Schedule",
  "add_medication": "Add Medication",
  "edit_medication": "Edit Medication",
  "stock_left": "{count} {unit} left",
  "refill_in_days": "Refill in {days} days",
  "low_stock_warning": "Low stock — refill soon",
  "given_at": "Given {time}",
  "by_staff": "by {name}",
  "scheduled": "Scheduled",
  "missed_yesterday": "Missed Yesterday",
  "view_reason": "View reason",
  "save": "Save",
  "delete": "Delete",
  "cancel": "Cancel",
  "confirm_delete_medication": "Are you sure you want to remove this medication?",
  "attendance_history": "Attendance History",
  "report_history": "Report History",
  "service_detail": "Service Detail",
  "staff_on_duty": "Staff on Duty",
  "vitals_trend": "Vitals Trend",
  "todays_care_report": "Today's Care Report",
  "equipment_deployed": "Equipment Deployed",
  "tasks_completed": "{done}/{total} tasks, {percent}% complete",
  "view_my_care": "View My Care"
```

- [ ] **Step 2: Add Hindi keys**

Add corresponding Hindi translations to `hi.json`:

```json
  "tab_my_care": "मेरी देखभाल",
  "active_services": "सक्रिय सेवाएं",
  "todays_staff": "आज का स्टाफ",
  "all_staff_checked_in": "सभी स्टाफ चेक इन हो गए",
  "staff_pending_checkin": "कुछ स्टाफ अभी चेक इन नहीं हुए",
  "billing_summary": "बिलिंग सारांश",
  "view_invoices": "इनवॉइस और भुगतान इतिहास देखें",
  "raise_concern": "शिकायत दर्ज करें",
  "staff_service_billing": "स्टाफ, सेवा, बिलिंग",
  "daily_reports": "दैनिक रिपोर्ट",
  "view_all_reports": "सभी रिपोर्ट देखें",
  "documents": "दस्तावेज़",
  "prescriptions_reports": "प्रिस्क्रिप्शन, रिपोर्ट",
  "no_active_services": "कोई सक्रिय सेवा नहीं",
  "no_active_services_desc": "अभी कोई सक्रिय सेवा नहीं है। सेवा बुक करें।",
  "book_a_service": "सेवा बुक करें",
  "view_vitals_history": "वाइटल्स इतिहास देखें",
  "error_load_data": "डेटा लोड नहीं हो सका",
  "tap_to_retry": "पुनः प्रयास करें",
  "medications": "दवाइयां",
  "medication_schedule": "आज का शेड्यूल",
  "add_medication": "दवाई जोड़ें",
  "edit_medication": "दवाई संपादित करें",
  "stock_left": "{count} {unit} बाकी",
  "refill_in_days": "{days} दिन में रिफिल",
  "low_stock_warning": "कम स्टॉक — जल्दी रिफिल करें",
  "given_at": "{time} पर दी गई",
  "by_staff": "{name} द्वारा",
  "scheduled": "निर्धारित",
  "missed_yesterday": "कल छूट गई",
  "view_reason": "कारण देखें",
  "save": "सेव करें",
  "delete": "हटाएं",
  "cancel": "रद्द करें",
  "confirm_delete_medication": "क्या आप इस दवाई को हटाना चाहते हैं?",
  "attendance_history": "उपस्थिति इतिहास",
  "report_history": "रिपोर्ट इतिहास",
  "service_detail": "सेवा विवरण",
  "staff_on_duty": "ड्यूटी पर स्टाफ",
  "vitals_trend": "वाइटल्स ट्रेंड",
  "todays_care_report": "आज की केयर रिपोर्ट",
  "equipment_deployed": "तैनात उपकरण",
  "tasks_completed": "{done}/{total} कार्य, {percent}% पूर्ण",
  "view_my_care": "मेरी देखभाल देखें"
```

- [ ] **Step 3: Commit**

```bash
git add assets/i18n/
git commit -m "feat(my-care): add English and Hindi localization keys for My Care tab"
```

---

## Chunk 4: Service Detail Screen

### Task 12: Create ServiceDetailScreen

**Files:**
- Create: `lib/screens/my_care/service_detail_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/my_care_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/my_care_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import 'widgets/vitals_trend_grid.dart';
import 'widgets/care_report_section.dart';
import 'widgets/equipment_deployed_section.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ActiveService service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (widget.service.deploymentIds.isNotEmpty) {
        context
            .read<MyCareProvider>()
            .loadServiceDetail(widget.service.deploymentIds.first);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final myCare = context.watch<MyCareProvider>();
    final color = HousepitalColors.serviceColor(widget.service.serviceCategory);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.service.name),
      ),
      body: myCare.isDetailLoading
          ? const Center(child: LoadingWidget())
          : myCare.detailError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l.t('error_load_data')),
                      TextButton(
                        onPressed: () {
                          if (widget.service.deploymentIds.isNotEmpty) {
                            myCare.loadServiceDetail(
                                widget.service.deploymentIds.first);
                          }
                        },
                        child: Text(l.t('tap_to_retry')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    if (widget.service.deploymentIds.isNotEmpty) {
                      await myCare.loadServiceDetail(
                          widget.service.deploymentIds.first);
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with progress
                        _buildHeader(color),

                        // Staff on duty
                        if (widget.service.showStaff &&
                            myCare.selectedServiceDetail != null)
                          _buildStaffSection(myCare.selectedServiceDetail!, l),

                        // 7-day attendance
                        if (widget.service.showAttendance &&
                            myCare.selectedServiceDetail != null)
                          _buildAttendanceCalendar(
                              myCare.selectedServiceDetail!, l),

                        // Vitals trend
                        if (widget.service.showVitals &&
                            myCare.selectedServiceDetail?.vitalsSummary != null)
                          VitalsTrendGrid(
                              vitals:
                                  myCare.selectedServiceDetail!.vitalsSummary!),

                        // Today's care report
                        if (widget.service.showDailyReport &&
                            myCare.selectedServiceDetail?.todayReport != null)
                          CareReportSection(
                            report: myCare.selectedServiceDetail!.todayReport!,
                            deploymentId: widget.service.deploymentIds.isNotEmpty
                                ? widget.service.deploymentIds.first
                                : '',
                          ),

                        // Medications
                        if (widget.service.showMedications)
                          _buildMedicationsLink(l),

                        // Equipment deployed
                        if (widget.service.showEquipment &&
                            myCare.selectedServiceDetail != null)
                          EquipmentDeployedSection(
                              equipment:
                                  myCare.selectedServiceDetail!.equipment),

                        // Billing summary for this service
                        _buildServiceBilling(l),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.service.name,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Started ${DateHelper.formatDate(widget.service.startDate)}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                widget.service.isSessionBased
                    ? 'Session ${widget.service.consumedDays} of ${widget.service.totalDays}'
                    : 'Day ${widget.service.consumedDays} of ${widget.service.totalDays}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (widget.service.dailyRate != null)
                Text(
                  '${DateHelper.formatCurrency(widget.service.dailyRate!)}/day',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.service.progressFraction,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffSection(ServiceDetail detail, AppLocalizations l) {
    if (detail.staffOnDuty.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('staff_on_duty'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...detail.staffOnDuty.map((staff) => Card(
                color: staff.isReplacement
                    ? const Color(0xFFFEFCE8)
                    : const Color(0xFFF0FDF4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: staff.isReplacement
                        ? HousepitalColors.warning
                        : HousepitalColors.success,
                    child: Text(
                      staff.name.split(' ').map((n) => n[0]).take(2).join(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(staff.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (staff.isReplacement)
                        Text(' (Replacement)',
                            style: TextStyle(
                                fontSize: 11,
                                color: HousepitalColors.warning)),
                    ],
                  ),
                  subtitle: Text(
                    '${staff.role} (${staff.shiftType})${staff.checkInTime != null ? ' · Checked in ${DateHelper.formatTime(staff.checkInTime!)}' : ''}',
                  ),
                  trailing: staff.checkInTime != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatDuration(staff.onDutyDuration),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: staff.isReplacement
                                      ? HousepitalColors.warning
                                      : HousepitalColors.success),
                            ),
                            Text('on shift',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[400])),
                          ],
                        )
                      : null,
                  onTap: () => Navigator.pushNamed(context, '/staff-profile',
                      arguments: staff.id),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAttendanceCalendar(ServiceDetail detail, AppLocalizations l) {
    if (detail.attendanceDays.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('7-Day Attendance',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (widget.service.deploymentIds.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                      context, '/attendance-history',
                      arguments: widget.service.deploymentIds.first),
                  child: const Text('View All'),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: detail.attendanceDays.map((day) {
              Color dotColor;
              switch (day.status) {
                case 'on_time':
                  dotColor = HousepitalColors.success;
                  break;
                case 'replacement':
                  dotColor = HousepitalColors.warning;
                  break;
                case 'absent':
                case 'late':
                  dotColor = HousepitalColors.error;
                  break;
                default:
                  dotColor = Colors.grey[300]!;
              }
              final isToday = _isToday(day.date);
              return Column(
                children: [
                  Text(DateHelper.formatDateShort(day.date),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? Colors.grey[400] : dotColor,
                      border: isToday
                          ? Border.all(color: HousepitalColors.orange, width: 2)
                          : null,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsLink(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('medications'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/medication-schedule'),
                  icon: const Icon(Icons.schedule),
                  label: Text(l.t('medication_schedule')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/medications'),
                  icon: const Icon(Icons.medication),
                  label: Text(l.t('medications')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceBilling(AppLocalizations l) {
    final s = widget.service;
    if (s.totalPaid == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('billing_summary'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _billingRow('Package Paid',
                      DateHelper.formatCurrency(s.totalPaid!)),
                  _billingRow('Consumed',
                      DateHelper.formatCurrency(s.totalConsumed ?? 0)),
                  _billingRow('Remaining',
                      DateHelper.formatCurrency(s.remaining ?? 0)),
                  if (s.renewalDate != null)
                    _billingRow(
                        'Renewal', DateHelper.formatDate(s.renewalDate!)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/my_care/service_detail_screen.dart
git commit -m "feat(my-care): add ServiceDetailScreen with conditional sections"
```

---

### Task 13: Create detail sub-widgets

**Files:**
- Create: `lib/screens/my_care/widgets/vitals_trend_grid.dart`
- Create: `lib/screens/my_care/widgets/care_report_section.dart`
- Create: `lib/screens/my_care/widgets/equipment_deployed_section.dart`

- [ ] **Step 1: Create `VitalsTrendGrid`**

```dart
// lib/screens/my_care/widgets/vitals_trend_grid.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/app_localizations.dart';

class VitalsTrendGrid extends StatelessWidget {
  final VitalsSummary vitals;

  const VitalsTrendGrid({super.key, required this.vitals});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('vitals_trend'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              _vitalCard(context, 'BP', vitals.bp),
              _vitalCard(context, 'SpO2', vitals.spo2),
              _vitalCard(context, 'Pulse', vitals.pulse),
              _vitalCard(context, 'Temp', vitals.temperature),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalCard(BuildContext context, String title, VitalCard card) {
    final statusColor = _statusColor(card.status);

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/vitals', arguments: title.toLowerCase()),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: card.status == 'critical'
                ? HousepitalColors.error
                : const Color(0xFFE5E7EB),
          ),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    card.status[0].toUpperCase() + card.status.substring(1),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(card.label,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (card.sparkline.length > 1) ...[
              const Spacer(),
              SizedBox(
                height: 24,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: card.sparkline
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        isCurved: true,
                        color: statusColor,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: statusColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'critical':
        return HousepitalColors.error;
      case 'warning':
        return HousepitalColors.warning;
      default:
        return HousepitalColors.success;
    }
  }
}
```

- [ ] **Step 2: Create `CareReportSection`**

```dart
// lib/screens/my_care/widgets/care_report_section.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/app_localizations.dart';
import '../../../utils/helpers.dart';

class CareReportSection extends StatelessWidget {
  final CareReportSummary report;
  final String deploymentId;

  const CareReportSection({
    super.key,
    required this.report,
    required this.deploymentId,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final percent = (report.completionFraction * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.t('todays_care_report'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${report.completedTasks}/${report.totalTasks} tasks, $percent%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ...report.tasks.map((task) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              task.status == 'completed'
                                  ? Icons.check_circle
                                  : task.status == 'in_progress'
                                      ? Icons.access_time
                                      : Icons.radio_button_unchecked,
                              size: 18,
                              color: task.status == 'completed'
                                  ? HousepitalColors.success
                                  : task.status == 'in_progress'
                                      ? HousepitalColors.orange
                                      : Colors.grey[400],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(task.name,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                            if (task.completedAt != null)
                              Text(task.completedAt!,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      )),
                  if (report.staffNotes != null) ...[
                    const Divider(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.note, size: 16, color: HousepitalColors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(report.staffNotes!,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(
                          context, '/report-history',
                          arguments: deploymentId),
                      child: Text(l.t('view_all_reports')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create `EquipmentDeployedSection`**

```dart
// lib/screens/my_care/widgets/equipment_deployed_section.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/app_localizations.dart';
import '../../../utils/helpers.dart';

class EquipmentDeployedSection extends StatelessWidget {
  final List<EquipmentDeployed> equipment;

  const EquipmentDeployedSection({super.key, required this.equipment});

  @override
  Widget build(BuildContext context) {
    if (equipment.isEmpty) return const SizedBox.shrink();

    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('equipment_deployed'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...equipment.map((eq) => Card(
                child: ListTile(
                  leading: const Icon(Icons.medical_services_outlined,
                      color: HousepitalColors.serviceEquipment),
                  title: Text(eq.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${DateHelper.formatCurrency(eq.monthlyRate)}/month · Since ${DateHelper.formatDateShort(eq.startDate)}'),
                  trailing: StatusBadge(
                    text: eq.status == 'active' ? 'Active' : 'Returned',
                    color: eq.status == 'active'
                        ? HousepitalColors.success
                        : Colors.grey,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Verify compiles**

Run: `cd /Users/ateeshayjain/housepital_patient_app && flutter analyze lib/screens/my_care/widgets/`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/screens/my_care/widgets/vitals_trend_grid.dart lib/screens/my_care/widgets/care_report_section.dart lib/screens/my_care/widgets/equipment_deployed_section.dart
git commit -m "feat(my-care): add vitals trend, care report, and equipment detail widgets"
```

---

## Chunk 5: Medication Screens

### Task 14: Create MedicationsScreen (list + management)

**Files:**
- Create: `lib/screens/my_care/medications_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/medication_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final patientId = context.read<AppProvider>().currentPatient?.id;
      if (patientId != null) {
        context.read<MedicationProvider>().loadMedications(patientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final medProv = context.watch<MedicationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('medications')),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/medication-schedule'),
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(l.t('medication_schedule')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/medication-add');
          if (result == true) {
            final patientId = context.read<AppProvider>().currentPatient?.id;
            if (patientId != null) {
              medProv.loadMedications(patientId);
            }
          }
        },
        child: const Icon(Icons.add),
      ),
      body: medProv.isLoading
          ? const Center(child: LoadingWidget())
          : medProv.error != null
              ? Center(child: Text(l.t('error_load_data')))
              : medProv.activeMedications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.medication_outlined,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('No medications added yet',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        final patientId =
                            context.read<AppProvider>().currentPatient?.id;
                        if (patientId != null) {
                          await medProv.loadMedications(patientId);
                        }
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: medProv.activeMedications.length,
                        itemBuilder: (context, index) {
                          final med = medProv.activeMedications[index];
                          return _medicationCard(context, med, l, medProv);
                        },
                      ),
                    ),
    );
  }

  Widget _medicationCard(BuildContext context, MedicationFull med,
      AppLocalizations l, MedicationProvider medProv) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: med.isLowStock
              ? const Color(0xFFFDE68A)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(context, '/medication-add',
              arguments: med);
          if (result == true) {
            final patientId = context.read<AppProvider>().currentPatient?.id;
            if (patientId != null) medProv.loadMedications(patientId);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${med.name} ${med.dosage}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                            '${med.form} · ${med.frequencyLabel} · ${med.instructions ?? ""}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        if (med.prescribedBy != null)
                          Text('Prescribed by ${med.prescribedBy}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, size: 16, color: Colors.grey),
                ],
              ),
              if (med.stockCount != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    if (med.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEFCE8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${med.stockCount} ${med.stockUnit ?? "units"} left — refill soon',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFCA8A04),
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${med.stockCount} ${med.stockUnit ?? "units"} left',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (med.daysOfSupplyLeft != null && !med.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Refill in ${med.daysOfSupplyLeft} days',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/my_care/medications_screen.dart
git commit -m "feat(my-care): add MedicationsScreen — medication list with stock tracking"
```

---

### Task 15: Create MedicationScheduleScreen

**Files:**
- Create: `lib/screens/my_care/medication_schedule_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/medication_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class MedicationScheduleScreen extends StatefulWidget {
  const MedicationScheduleScreen({super.key});

  @override
  State<MedicationScheduleScreen> createState() =>
      _MedicationScheduleScreenState();
}

class _MedicationScheduleScreenState extends State<MedicationScheduleScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final patientId = context.read<AppProvider>().currentPatient?.id;
      if (patientId != null) {
        context.read<MedicationProvider>().loadTodaySchedule(patientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final medProv = context.watch<MedicationProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l.t('medication_schedule'))),
      body: medProv.isLoading
          ? const Center(child: LoadingWidget())
          : medProv.error != null
              ? Center(child: Text(l.t('error_load_data')))
              : medProv.schedule.isEmpty
                  ? const Center(child: Text('No medications scheduled today'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        final patientId =
                            context.read<AppProvider>().currentPatient?.id;
                        if (patientId != null) {
                          await medProv.loadTodaySchedule(patientId);
                        }
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: medProv.schedule.length,
                        itemBuilder: (context, index) =>
                            _slotSection(medProv.schedule[index], l),
                      ),
                    ),
    );
  }

  Widget _slotSection(MedicationScheduleSlot slot, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(slot.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('${slot.label} — ${_formatSlotTime(slot.time)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                slot.summaryLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: slot.allGiven
                      ? HousepitalColors.success
                      : HousepitalColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...slot.medications.map((sm) => _medItem(sm)),
        ],
      ),
    );
  }

  Widget _medItem(ScheduledMedication sm) {
    final isGiven = sm.log?.wasGiven ?? false;
    final isMissed = sm.log?.wasMissed ?? false;

    Color bgColor;
    Color borderColor;
    if (isGiven) {
      bgColor = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFFBBF7D0);
    } else if (isMissed) {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
    } else {
      bgColor = const Color(0xFFF9FAFB);
      borderColor = const Color(0xFFE5E7EB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 28),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isGiven
                ? Icons.check
                : isMissed
                    ? Icons.warning_amber
                    : Icons.radio_button_unchecked,
            size: 16,
            color: isGiven
                ? HousepitalColors.success
                : isMissed
                    ? HousepitalColors.error
                    : Colors.grey[400],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${sm.medication.name} ${sm.medication.dosage}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sm.isPast && !isGiven
                          ? Colors.grey[400]
                          : Colors.grey[900],
                    )),
                Text('${sm.medication.form} · ${sm.medication.instructions ?? ""}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          if (isGiven && sm.log != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    'Given ${DateHelper.formatTime(sm.log!.actualTime ?? sm.log!.scheduledTime)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF16A34A))),
                if (sm.log!.staffName != null)
                  Text('by ${sm.log!.staffName}',
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            )
          else if (!isGiven && !isMissed)
            Text(l.t('scheduled'),
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ],
      ),
    );
  }

  AppLocalizations get l => AppLocalizations.of(context)!;

  String _formatSlotTime(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:$minute $period';
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/my_care/medication_schedule_screen.dart
git commit -m "feat(my-care): add MedicationScheduleScreen — daily time-slotted view"
```

---

### Task 16: Create AddEditMedicationScreen

**Files:**
- Create: `lib/screens/my_care/add_edit_medication_screen.dart`

- [ ] **Step 1: Create the form screen**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/medication_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
import '../../utils/app_localizations.dart';

class AddEditMedicationScreen extends StatefulWidget {
  final MedicationFull? medication; // null = add mode

  const AddEditMedicationScreen({super.key, this.medication});

  @override
  State<AddEditMedicationScreen> createState() =>
      _AddEditMedicationScreenState();
}

class _AddEditMedicationScreenState extends State<AddEditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _instructionsCtrl;
  late final TextEditingController _prescribedByCtrl;
  late final TextEditingController _stockCtrl;

  late String _form;
  late String _frequency;
  late String _stockUnit;
  late List<String> _timeSlots;

  bool get isEditing => widget.medication != null;

  static const _forms = ['tablet', 'injection', 'syrup', 'inhaler', 'drops'];
  static const _frequencies = [
    'once_daily',
    'twice_daily',
    'thrice_daily',
    'four_times_daily',
    'as_needed',
  ];
  static const _stockUnits = ['tablets', 'units', 'ml', 'puffs'];
  static const _defaultSlots = {
    'once_daily': ['08:00'],
    'twice_daily': ['08:00', '20:00'],
    'thrice_daily': ['08:00', '14:00', '21:00'],
    'four_times_daily': ['06:00', '12:00', '18:00', '22:00'],
    'as_needed': <String>[],
  };

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    _nameCtrl = TextEditingController(text: med?.name ?? '');
    _dosageCtrl = TextEditingController(text: med?.dosage ?? '');
    _instructionsCtrl = TextEditingController(text: med?.instructions ?? '');
    _prescribedByCtrl = TextEditingController(text: med?.prescribedBy ?? '');
    _stockCtrl = TextEditingController(
        text: med?.stockCount != null ? '${med!.stockCount}' : '');
    _form = med?.form ?? 'tablet';
    _frequency = med?.frequency ?? 'once_daily';
    _stockUnit = med?.stockUnit ?? 'tablets';
    _timeSlots =
        med?.timeSlots ?? List.from(_defaultSlots[_frequency] ?? ['08:00']);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _instructionsCtrl.dispose();
    _prescribedByCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final medProv = context.watch<MedicationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l.t('edit_medication') : l.t('add_medication')),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, medProv, l),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Medication Name'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dosageCtrl,
              decoration:
                  const InputDecoration(labelText: 'Dosage (e.g., 500mg)'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Dosage is required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _form,
              decoration: const InputDecoration(labelText: 'Form'),
              items: _forms
                  .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f[0].toUpperCase() + f.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _form = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: _frequencies
                  .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(MedicationFull(
                              id: '',
                              patientId: '',
                              name: '',
                              dosage: '',
                              frequency: f)
                          .frequencyLabel)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _frequency = v!;
                  _timeSlots = List.from(_defaultSlots[v] ?? ['08:00']);
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(
                  labelText: 'Instructions (e.g., After meals)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prescribedByCtrl,
              decoration: const InputDecoration(labelText: 'Prescribed by'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _stockCtrl,
                    decoration: const InputDecoration(labelText: 'Stock count'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _stockUnit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: _stockUnits
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _stockUnit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: medProv.isSaving ? null : () => _save(medProv),
              child: medProv.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(l.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(MedicationProvider medProv) async {
    if (!_formKey.currentState!.validate()) return;

    final patientId = context.read<AppProvider>().currentPatient?.id;
    if (patientId == null) return;

    final body = {
      'name': _nameCtrl.text.trim(),
      'dosage': _dosageCtrl.text.trim(),
      'form': _form,
      'frequency': _frequency,
      'time_slots': _timeSlots,
      'instructions': _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      'prescribed_by': _prescribedByCtrl.text.trim().isEmpty
          ? null
          : _prescribedByCtrl.text.trim(),
      'stock_count': _stockCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_stockCtrl.text.trim()),
      'stock_unit': _stockUnit,
    };

    bool success;
    if (isEditing) {
      success =
          await medProv.updateMedication(patientId, widget.medication!.id, body);
    } else {
      success = await medProv.addMedication(patientId, body);
    }

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _confirmDelete(
      BuildContext context, MedicationProvider medProv, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('delete')),
        content: Text(l.t('confirm_delete_medication')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.t('cancel'))),
          TextButton(
            onPressed: () async {
              final patientId =
                  context.read<AppProvider>().currentPatient?.id;
              if (patientId != null) {
                await medProv.deleteMedication(
                    patientId, widget.medication!.id);
              }
              if (mounted) {
                Navigator.pop(ctx); // close dialog
                Navigator.pop(context, true); // pop screen
              }
            },
            child: Text(l.t('delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/my_care/add_edit_medication_screen.dart
git commit -m "feat(my-care): add AddEditMedicationScreen — medication CRUD form"
```

---

## Chunk 6: Supporting Screens + Home Screen Integration

### Task 17: Create ReportHistoryScreen

**Files:**
- Create: `lib/screens/my_care/report_history_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class ReportHistoryScreen extends StatefulWidget {
  final String deploymentId;

  const ReportHistoryScreen({super.key, required this.deploymentId});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<DailyReport> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final app = context.read<AppProvider>();
      final patientId = app.currentPatient?.id;
      if (patientId != null) {
        _reports = await app.apiService.getReportHistory(patientId);
      }
    } catch (e) {
      _error = 'Failed to load reports';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('report_history'))),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l.t('error_load_data')),
                      TextButton(
                          onPressed: _loadReports,
                          child: Text(l.t('tap_to_retry'))),
                    ],
                  ),
                )
              : _reports.isEmpty
                  ? Center(child: Text(l.t('no_data')))
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                  DateHelper.formatDate(report.date)),
                              subtitle: Text(
                                  '${report.completedTasks} tasks completed'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pushNamed(
                                  context, '/report-detail',
                                  arguments: report.id),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
```

**Note:** This screen uses the existing `getReportHistory` method via `AppProvider.apiService` (public getter added in Task 7). The existing `DailyReport` model is reused.

- [ ] **Step 2: Commit**

```bash
git add lib/screens/my_care/report_history_screen.dart
git commit -m "feat(my-care): add ReportHistoryScreen — past daily reports list"
```

---

### Task 18: Create AttendanceHistoryScreen

**Files:**
- Create: `lib/screens/my_care/attendance_history_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String deploymentId;

  const AttendanceHistoryScreen({super.key, required this.deploymentId});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<Attendance> _records = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _records = await context.read<AppProvider>().apiService
          .getAttendanceHistoryPaginated(widget.deploymentId);
    } catch (e) {
      _error = 'Failed to load attendance';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('attendance_history'))),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l.t('error_load_data')),
                      TextButton(
                          onPressed: _loadData,
                          child: Text(l.t('tap_to_retry'))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final a = _records[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            AttendanceHelper.getStatusIcon(a.status),
                            color:
                                AttendanceHelper.getStatusColor(a.status),
                          ),
                          title: Text(a.checkInTime != null
                              ? DateHelper.formatDate(a.checkInTime!)
                              : 'No check-in'),
                          subtitle: Text(
                              '${a.status} · ${a.checkInTime != null ? "In: ${DateHelper.formatTime(a.checkInTime!)}" : ""} ${a.checkOutTime != null ? "· Out: ${DateHelper.formatTime(a.checkOutTime!)}" : ""}'),
                          trailing: StatusBadge(
                            text: a.status,
                            color:
                                AttendanceHelper.getStatusColor(a.status),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/my_care/attendance_history_screen.dart
git commit -m "feat(my-care): add AttendanceHistoryScreen — 30-day attendance log"
```

---

### Task 19: Add "View My Care" banner to Home Screen

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Add banner widget after the vitals section**

Find the services section in the home screen build method and add before it:

```dart
// "View My Care" banner
if (app.activeDeployment != null)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: InkWell(
      onTap: () => MainShell.switchToTab(1),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDE0C0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite, color: HousepitalColors.orange, size: 20),
            const SizedBox(width: 8),
            Text(l.t('view_my_care'),
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.orange)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: HousepitalColors.orange),
          ],
        ),
      ),
    ),
  ),
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat(my-care): add 'View My Care' banner to home screen"
```

---

### Task 20: Full compile check + run

- [ ] **Step 1: Run full analysis**

Run: `cd /Users/ateeshayjain/housepital_patient_app && flutter analyze`
Expected: No errors (warnings acceptable)

- [ ] **Step 2: Fix any analysis errors**

Address any import issues, type mismatches, or missing references identified by the analyzer.

- [ ] **Step 3: Run the app in debug mode**

Run: `cd /Users/ateeshayjain/housepital_patient_app && flutter run -d chrome --web-port=8080`

Verify:
- App launches without crash
- Bottom tab bar shows "My Care" with heart icon at index 1
- Tapping My Care tab shows loading then empty state (no backend yet)
- Home screen shows "View My Care" banner

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat(my-care): complete My Care tab implementation — all screens, models, providers, and integration"
```

---

## Summary

| Chunk | Tasks | What it delivers |
|---|---|---|
| 1: Data Models + API | Tasks 1–4 | All Dart models + API endpoints + theme colors |
| 2: Providers | Tasks 5–7 | MyCareProvider + MedicationProvider + route registration |
| 3: My Care Tab + Widgets | Tasks 8–11 | Main screen, 5 section widgets, tab replacement, i18n |
| 4: Service Detail | Tasks 12–13 | ServiceDetailScreen + vitals/report/equipment widgets |
| 5: Medications | Tasks 14–16 | Medications list, schedule view, add/edit form |
| 6: Supporting + Integration | Tasks 17–20 | Report history, attendance history, home banner, full compile |

**Total:** 20 tasks, ~20 files created, ~5 files modified.
