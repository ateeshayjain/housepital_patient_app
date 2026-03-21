// lib/models/my_care_models.dart

import 'package:flutter/material.dart';

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
