// Medical History Model
//
// Read-only snapshot of the medical history the supervisor captures in the
// staff-app deployment wizard (Conditions, Diagnosis, Lines, feeding/motion
// status, dietary restrictions, restrictions, special instructions, …).
// The patient app only DISPLAYS this — it is recorded and edited supervisor-
// side, then synced down, so there is no edit flow and no toJson here.
class MedicalHistory {
  /// Condition chips, e.g. Diabetes / Hypertension / Stroke.
  final List<String> conditions;
  final String diagnosis;
  final String? heightCm;
  final String? weightKg;

  /// Lines in place, e.g. 'IV Line', 'Central Line', 'Tracheostomy'.
  final List<String> lines;
  final bool dischargeSummaryAvailable;
  final bool rtPegFeeding;
  final bool mentalCondition;

  /// 'Urine bag' / 'Diaper' / 'Normal'.
  final String motionStatus;
  final bool bpSugarInsulin;
  final String? allergies;
  final String mobilityStatus;

  /// e.g. 'Low Salt', 'Diabetic Diet', 'Soft Food'.
  final List<String> dietaryRestrictions;
  final String? restrictions;
  final String? specialInstructions;
  final String? preferredHospital;

  const MedicalHistory({
    required this.conditions,
    required this.diagnosis,
    this.heightCm,
    this.weightKg,
    required this.lines,
    required this.dischargeSummaryAvailable,
    required this.rtPegFeeding,
    required this.mentalCondition,
    required this.motionStatus,
    required this.bpSugarInsulin,
    this.allergies,
    required this.mobilityStatus,
    required this.dietaryRestrictions,
    this.restrictions,
    this.specialInstructions,
    this.preferredHospital,
  });

  factory MedicalHistory.fromJson(Map<String, dynamic> json) =>
      MedicalHistory(
        conditions: (json['conditions'] as List?)?.cast<String>() ?? const [],
        diagnosis: json['diagnosis'] as String? ?? '',
        heightCm: json['height_cm'] as String?,
        weightKg: json['weight_kg'] as String?,
        lines: (json['lines'] as List?)?.cast<String>() ?? const [],
        dischargeSummaryAvailable:
            json['discharge_summary_available'] as bool? ?? false,
        rtPegFeeding: json['rt_peg_feeding'] as bool? ?? false,
        mentalCondition: json['mental_condition'] as bool? ?? false,
        motionStatus: json['motion_status'] as String? ?? '',
        bpSugarInsulin: json['bp_sugar_insulin'] as bool? ?? false,
        allergies: json['allergies'] as String?,
        mobilityStatus: json['mobility_status'] as String? ?? '',
        dietaryRestrictions:
            (json['dietary_restrictions'] as List?)?.cast<String>() ??
                const [],
        restrictions: json['restrictions'] as String?,
        specialInstructions: json['special_instructions'] as String?,
        preferredHospital: json['preferred_hospital'] as String?,
      );
}
