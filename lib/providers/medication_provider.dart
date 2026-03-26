import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../models/medication_models.dart';
import '../services/api_service.dart';
import '../services/medication_reminder_service.dart';

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

    // Seed demo data immediately
    if (_medications.isEmpty) {
      _medications = DemoData.medications;
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
      debugPrint('Medications API unavailable, using demo data: $e');
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
}
