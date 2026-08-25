import 'package:flutter/foundation.dart';
import '../data/demo_data.dart';
import '../data/demo_mode.dart';
import '../models/medication_models.dart';
// audit batch 4 (Agent J): still need api_service for the ApiException type.
import '../services/api_service.dart';
import '../services/i_api_service.dart';
import '../services/medication_reminder_service.dart';
import '../utils/logger.dart';

class MedicationProvider extends ChangeNotifier {
  // audit batch 4 (Agent J): depend on IApiService (DIP).
  final IApiService _apiService;

  List<MedicationFull> _medications = [];
  List<MedicationLog> _todayLogs = [];
  List<MedicationScheduleSlot> _schedule = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  MedicationProvider(IApiService api) : _apiService = api;

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

  // ── Mark-taken state (Care Calendar quick actions) ─────────────────────
  // The schedule screen renders staff-administered MedicationLogs from the
  // backend; the patient-side "Mark taken" quick action on the Care Calendar
  // needs its own session-local record. Lifted here (not screen-local) so the
  // calendar and any future surface share one source of truth.
  final Set<String> _takenDoseKeys = {};

  String _doseKey(String medicationId, String timeSlot, DateTime day) =>
      '$medicationId|$timeSlot|${day.year}-${day.month}-${day.day}';

  bool isDoseTakenToday(String medicationId, String timeSlot) =>
      _takenDoseKeys.contains(_doseKey(medicationId, timeSlot, DateTime.now()));

  void markDoseTakenToday(String medicationId, String timeSlot) {
    _takenDoseKeys.add(_doseKey(medicationId, timeSlot, DateTime.now()));
    notifyListeners();
  }

  /// Doses marked taken today via the quick action (any med/slot).
  int get dosesMarkedTakenToday {
    final now = DateTime.now();
    final suffix = '|${now.year}-${now.month}-${now.day}';
    return _takenDoseKeys.where((k) => k.endsWith(suffix)).length;
  }

  // ── Single-tap dose logging (Medications list / Today's Schedule) ──────
  // Owner request: one tap on a med card logs today's next pending dose —
  // no navigation, no dialog. Reuses the Care Calendar's mark-taken pathway
  // (_takenDoseKeys) and ALSO records a session-local MedicationLog so the
  // Today's Schedule rows flip to "Given". Same offline demo-mode behaviour
  // as markDoseTakenToday: IApiService has no patient-side dose-log endpoint
  // (MedicationLogs are staff-administered, read-only from this app), so the
  // record is kept session-local — there is no API call to attempt or fail.

  /// True when [timeSlot] of [medicationId] is already resolved today —
  /// either via a quick action this session, or by an existing backend log
  /// for that slot (any status: a staff-administered/skipped/missed entry
  /// means the slot is no longer "pending").
  bool isSlotLoggedToday(String medicationId, String timeSlot) {
    if (isDoseTakenToday(medicationId, timeSlot)) return true;
    final parts = timeSlot.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    // _todayLogs holds today's logs by contract; match slot like
    // _buildSchedule does (hour + minute).
    return _todayLogs.any((l) =>
        l.medicationId == medicationId &&
        l.scheduledTime.hour == hour &&
        l.scheduledTime.minute == minute);
  }

  /// Earliest time slot of [medicationId] not yet logged today, or null when
  /// every slot is logged (or the med is unknown / has no slots).
  String? nextPendingSlotToday(String medicationId) {
    // Public getter (not the private field) so test doubles that override
    // `medications` keep working.
    final med = medications.cast<MedicationFull?>().firstWhere(
          (m) => m!.id == medicationId,
          orElse: () => null,
        );
    if (med == null) return null;
    final slots = [...med.timeSlots]..sort();
    for (final slot in slots) {
      if (!isSlotLoggedToday(medicationId, slot)) return slot;
    }
    return null;
  }

  /// Marks [timeSlot] of [medicationId] as taken today (patient quick
  /// action). Updates _todayLogs + _schedule and notifies via
  /// [markDoseTakenToday]. Returns false (no-op) when the slot is already
  /// logged today.
  bool logDoseToday(String medicationId, String timeSlot) {
    if (isSlotLoggedToday(medicationId, timeSlot)) return false;
    final now = DateTime.now();
    final parts = timeSlot.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    _todayLogs.add(MedicationLog(
      id: 'patient_log_${medicationId}_$timeSlot',
      medicationId: medicationId,
      scheduledTime: DateTime(now.year, now.month, now.day, hour, minute),
      actualTime: now,
      status: 'administered',
      notes: 'Logged by patient (quick action)',
    ));
    _schedule = _buildSchedule();
    markDoseTakenToday(medicationId, timeSlot); // notifies listeners
    return true;
  }

  /// Single-tap logging for the Medications list: records the NEXT pending
  /// dose slot today for [medicationId]. Returns false when all of today's
  /// doses are already logged (no-op).
  bool logNextDoseToday(String medicationId) {
    final slot = nextPendingSlotToday(medicationId);
    if (slot == null) return false;
    return logDoseToday(medicationId, slot);
  }

  /// When [timeSlot] of [medicationId] was actually logged today (patient
  /// quick action or staff administration), or null if not logged / no
  /// timestamped record exists. Surfaces the time on Taken badges.
  DateTime? doseLoggedTimeToday(String medicationId, String timeSlot) {
    final parts = timeSlot.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    for (final l in _todayLogs) {
      if (l.medicationId == medicationId &&
          l.scheduledTime.hour == hour &&
          l.scheduledTime.minute == minute) {
        return l.actualTime;
      }
    }
    return null;
  }

  // ── Refill requests (session state) ────────────────────────────────────
  final Set<String> _refillRequestedIds = {};

  bool isRefillRequested(String medicationId) =>
      _refillRequestedIds.contains(medicationId);

  /// Sends a refill request to the Health Manager via the same concerns
  /// endpoint the Raise-Concern screen uses. Demo mode has no backend — the
  /// request is treated as queued (success) so the flow stays demo-complete.
  Future<bool> requestRefill(String patientId, MedicationFull med) async {
    try {
      await _apiService.raiseConcern(
        patientId: patientId,
        category: 'other',
        description: 'Medication refill request: ${med.name} ${med.dosage} — '
            'stock low (${med.stockCount ?? 0} ${med.stockUnit ?? 'units'} left).',
        urgency: 'medium',
      );
    } catch (e) {
      Log.warn('Refill concern API unavailable, queued locally (demo)',
          error: e, tag: 'MedicationProvider');
    }
    _refillRequestedIds.add(med.id);
    notifyListeners();
    return true;
  }

  /// Load medications list.
  Future<void> loadMedications(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Seed demo data immediately
    if (_medications.isEmpty) {
      _medications = DemoData.medications;
      DemoMode.markServingDemoData(DemoMode.sourceMedications);
    }

    _isLoading = false;
    notifyListeners();

    // Then try API in background
    try {
      final apiMeds = await _apiService.getMedications(patientId)
          .timeout(const Duration(seconds: 5));
      _medications = apiMeds;
      if (!kIsWeb) {
        MedicationReminderService().rescheduleAll(activeMedications);
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      Log.warn('Medications API unavailable, using demo data',
          error: e, tag: 'MedicationProvider');
    }
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
    } catch (e) {
      // Demo-mode fallback — every other loader in this provider falls back
      // to DemoData when the API is unreachable; the schedule must too
      // (field bug: Today's Schedule showed "Couldn't load data" on device).
      Log.warn('Schedule API unavailable, using demo data',
          error: e, tag: 'MedicationProvider');
      if (_medications.isEmpty) {
        _medications = DemoData.medications;
        DemoMode.markServingDemoData(DemoMode.sourceMedications);
      }
      _schedule = _buildSchedule();
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
      // Schedule reminders for the new medication
      if (!kIsWeb) {
        MedicationReminderService().scheduleMedicationReminders(med);
      }
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
      // Reschedule reminders for the updated medication
      if (!kIsWeb) {
        final svc = MedicationReminderService();
        await svc.cancelReminders(medicationId);
        await svc.scheduleMedicationReminders(updated);
      }
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
      // Cancel reminders for the deleted medication
      if (!kIsWeb) {
        MedicationReminderService().cancelReminders(medicationId);
      }
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
  /// Clears every field that belongs to ONE patient (see
  /// MyCareProvider.clearPatientScopedData). Dose-taken and refill markers go
  /// too: they are keyed per medication, and medications are per patient.
  void clearPatientScopedData() {
    _medications = [];
    _todayLogs = [];
    _schedule = [];
    _isLoading = false;
    _isSaving = false;
    _error = null;
    _takenDoseKeys.clear();
    _refillRequestedIds.clear();
    notifyListeners();
  }

}
