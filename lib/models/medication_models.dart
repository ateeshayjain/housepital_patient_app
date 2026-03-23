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
  final bool remindersEnabled;

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
    this.remindersEnabled = true,
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
        remindersEnabled: json['reminders_enabled'] ?? true,
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
        'reminders_enabled': remindersEnabled,
      };
}

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
