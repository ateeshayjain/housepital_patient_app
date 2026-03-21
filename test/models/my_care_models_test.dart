// test/models/my_care_models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/my_care_models.dart';

// ---------------------------------------------------------------------------
// Helpers — minimal valid JSON factories
// ---------------------------------------------------------------------------

Map<String, dynamic> _activeServiceJson({
  String id = 'svc-1',
  String name = 'Care Package',
  String serviceCategory = 'care_package',
  String status = 'active',
  String startDate = '2026-01-01',
  String? endDate,
  int totalDays = 30,
  int consumedDays = 12,
  bool isSessionBased = false,
  int? totalStaff,
  int? checkedInStaff,
  String? latestVitalLabel,
  String? latestVitalStatus,
  int? dailyRate,
  int? totalPaid,
  int? totalConsumed,
  int? remaining,
  String? renewalDate,
  List<String>? deploymentIds,
}) =>
    {
      'id': id,
      'name': name,
      'service_category': serviceCategory,
      'status': status,
      'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      'total_days': totalDays,
      'consumed_days': consumedDays,
      'is_session_based': isSessionBased,
      if (totalStaff != null) 'total_staff': totalStaff,
      if (checkedInStaff != null) 'checked_in_staff': checkedInStaff,
      if (latestVitalLabel != null) 'latest_vital_label': latestVitalLabel,
      if (latestVitalStatus != null) 'latest_vital_status': latestVitalStatus,
      if (dailyRate != null) 'daily_rate': dailyRate,
      if (totalPaid != null) 'total_paid': totalPaid,
      if (totalConsumed != null) 'total_consumed': totalConsumed,
      if (remaining != null) 'remaining': remaining,
      if (renewalDate != null) 'renewal_date': renewalDate,
      if (deploymentIds != null) 'deployment_ids': deploymentIds,
    };

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // ActiveService
  // =========================================================================
  group('ActiveService', () {
    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = _activeServiceJson(
          id: 'svc-42',
          name: 'Full Care',
          serviceCategory: 'care_package',
          status: 'active',
          startDate: '2026-01-01',
          endDate: '2026-01-31',
          totalDays: 30,
          consumedDays: 12,
          isSessionBased: false,
          totalStaff: 3,
          checkedInStaff: 2,
          latestVitalLabel: '120/80',
          latestVitalStatus: 'normal',
          dailyRate: 1500,
          totalPaid: 45000,
          totalConsumed: 18000,
          remaining: 27000,
          renewalDate: '2026-02-01',
          deploymentIds: ['dep-1', 'dep-2'],
        );

        final svc = ActiveService.fromJson(json);

        expect(svc.id, 'svc-42');
        expect(svc.name, 'Full Care');
        expect(svc.serviceCategory, 'care_package');
        expect(svc.status, 'active');
        expect(svc.startDate, DateTime(2026, 1, 1));
        expect(svc.endDate, DateTime(2026, 1, 31));
        expect(svc.totalDays, 30);
        expect(svc.consumedDays, 12);
        expect(svc.isSessionBased, false);
        expect(svc.totalStaff, 3);
        expect(svc.checkedInStaff, 2);
        expect(svc.latestVitalLabel, '120/80');
        expect(svc.latestVitalStatus, 'normal');
        expect(svc.dailyRate, 1500);
        expect(svc.totalPaid, 45000);
        expect(svc.totalConsumed, 18000);
        expect(svc.remaining, 27000);
        expect(svc.renewalDate, DateTime(2026, 2, 1));
        expect(svc.deploymentIds, ['dep-1', 'dep-2']);
      });

      test('applies defaults when nullable fields are absent', () {
        final json = {
          'id': 'svc-min',
          'name': 'Minimal',
          'service_category': 'nursing',
          'start_date': '2026-03-01',
          // No status, total_days, consumed_days, etc.
        };

        final svc = ActiveService.fromJson(json);

        expect(svc.status, 'active');
        expect(svc.totalDays, 0);
        expect(svc.consumedDays, 0);
        expect(svc.isSessionBased, false);
        expect(svc.totalStaff, isNull);
        expect(svc.checkedInStaff, isNull);
        expect(svc.endDate, isNull);
        expect(svc.renewalDate, isNull);
        expect(svc.deploymentIds, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // progressFraction
    // -----------------------------------------------------------------------
    group('progressFraction', () {
      test('returns 0.4 for 12 consumed out of 30 total', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(totalDays: 30, consumedDays: 12),
        );
        expect(svc.progressFraction, closeTo(0.4, 1e-9));
      });

      test('returns 0.0 when totalDays is 0', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(totalDays: 0, consumedDays: 0),
        );
        expect(svc.progressFraction, 0.0);
      });

      test('clamps to 1.0 when consumedDays exceeds totalDays', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(totalDays: 10, consumedDays: 15),
        );
        expect(svc.progressFraction, 1.0);
      });

      test('returns 1.0 exactly when fully consumed', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(totalDays: 30, consumedDays: 30),
        );
        expect(svc.progressFraction, 1.0);
      });
    });

    // -----------------------------------------------------------------------
    // daysRemaining
    // -----------------------------------------------------------------------
    group('daysRemaining', () {
      test('returns 18 for 30 total minus 12 consumed', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(totalDays: 30, consumedDays: 12),
        );
        expect(svc.daysRemaining, 18);
      });

      test('returns 0 when all days are consumed', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(totalDays: 20, consumedDays: 20),
        );
        expect(svc.daysRemaining, 0);
      });
    });

    // -----------------------------------------------------------------------
    // hasStaff
    // -----------------------------------------------------------------------
    group('hasStaff', () {
      test('returns true when totalStaff is greater than 0', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(totalStaff: 2),
        );
        expect(svc.hasStaff, isTrue);
      });

      test('returns false when totalStaff is 0', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(totalStaff: 0),
        );
        expect(svc.hasStaff, isFalse);
      });

      test('returns false when totalStaff is null', () {
        final svc = ActiveService.fromJson(_activeServiceJson());
        expect(svc.hasStaff, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // isCarePackage
    // -----------------------------------------------------------------------
    group('isCarePackage', () {
      test('returns true for care_package', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(serviceCategory: 'care_package'),
        );
        expect(svc.isCarePackage, isTrue);
      });

      test('returns false for nursing', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(serviceCategory: 'nursing'),
        );
        expect(svc.isCarePackage, isFalse);
      });

      test('returns false for equipment_rental', () {
        final svc = ActiveService.fromJson(
          _activeServiceJson(serviceCategory: 'equipment_rental'),
        );
        expect(svc.isCarePackage, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // showVitals
    // -----------------------------------------------------------------------
    group('showVitals', () {
      test('true only for care_package', () {
        expect(
          ActiveService.fromJson(_activeServiceJson(serviceCategory: 'care_package')).showVitals,
          isTrue,
        );
      });

      for (final cat in ['nursing', 'caretaker', 'japa', 'nanny', 'physiotherapy', 'equipment_rental']) {
        test('false for $cat', () {
          expect(
            ActiveService.fromJson(_activeServiceJson(serviceCategory: cat)).showVitals,
            isFalse,
          );
        });
      }
    });

    // -----------------------------------------------------------------------
    // showStaff
    // -----------------------------------------------------------------------
    group('showStaff', () {
      test('true for care_package', () {
        expect(
          ActiveService.fromJson(_activeServiceJson(serviceCategory: 'care_package')).showStaff,
          isTrue,
        );
      });

      for (final cat in ['nursing', 'caretaker', 'japa', 'nanny', 'physiotherapy']) {
        test('true for $cat', () {
          expect(
            ActiveService.fromJson(_activeServiceJson(serviceCategory: cat)).showStaff,
            isTrue,
          );
        });
      }

      test('false for equipment_rental', () {
        expect(
          ActiveService.fromJson(_activeServiceJson(serviceCategory: 'equipment_rental')).showStaff,
          isFalse,
        );
      });
    });

    // -----------------------------------------------------------------------
    // showAttendance
    // -----------------------------------------------------------------------
    group('showAttendance', () {
      for (final cat in ['care_package', 'nursing', 'caretaker', 'japa', 'nanny']) {
        test('true for $cat', () {
          expect(
            ActiveService.fromJson(_activeServiceJson(serviceCategory: cat)).showAttendance,
            isTrue,
          );
        });
      }

      for (final cat in ['physiotherapy', 'equipment_rental']) {
        test('false for $cat', () {
          expect(
            ActiveService.fromJson(_activeServiceJson(serviceCategory: cat)).showAttendance,
            isFalse,
          );
        });
      }
    });

    // -----------------------------------------------------------------------
    // showDailyReport
    // -----------------------------------------------------------------------
    group('showDailyReport', () {
      for (final cat in ['care_package', 'nursing', 'caretaker', 'japa', 'nanny']) {
        test('true for $cat', () {
          expect(
            ActiveService.fromJson(_activeServiceJson(serviceCategory: cat)).showDailyReport,
            isTrue,
          );
        });
      }

      for (final cat in ['physiotherapy', 'equipment_rental']) {
        test('false for $cat', () {
          expect(
            ActiveService.fromJson(_activeServiceJson(serviceCategory: cat)).showDailyReport,
            isFalse,
          );
        });
      }
    });

    // -----------------------------------------------------------------------
    // showMedications
    // -----------------------------------------------------------------------
    group('showMedications', () {
      test('true only for care_package', () {
        expect(
          ActiveService.fromJson(_activeServiceJson(serviceCategory: 'care_package')).showMedications,
          isTrue,
        );
      });

      for (final cat in ['nursing', 'caretaker', 'japa', 'nanny', 'physiotherapy', 'equipment_rental']) {
        test('false for $cat', () {
          expect(
            ActiveService.fromJson(_activeServiceJson(serviceCategory: cat)).showMedications,
            isFalse,
          );
        });
      }
    });

    // -----------------------------------------------------------------------
    // showEquipment
    // -----------------------------------------------------------------------
    group('showEquipment', () {
      for (final cat in ['care_package', 'equipment_rental']) {
        test('true for $cat', () {
          expect(
            ActiveService.fromJson(_activeServiceJson(serviceCategory: cat)).showEquipment,
            isTrue,
          );
        });
      }

      for (final cat in ['nursing', 'caretaker', 'japa', 'nanny', 'physiotherapy']) {
        test('false for $cat', () {
          expect(
            ActiveService.fromJson(_activeServiceJson(serviceCategory: cat)).showEquipment,
            isFalse,
          );
        });
      }
    });
  });

  // =========================================================================
  // HealthManager
  // =========================================================================
  group('HealthManager', () {
    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'hm-1',
          'staff_id': 'staff-99',
          'name': 'Priya Sharma',
          'phone': '+919876543210',
          'photo_url': 'https://cdn.example.com/priya.jpg',
          'available_from': '09:00',
          'available_to': '21:00',
        };

        final hm = HealthManager.fromJson(json);

        expect(hm.id, 'hm-1');
        expect(hm.staffId, 'staff-99');
        expect(hm.name, 'Priya Sharma');
        expect(hm.phone, '+919876543210');
        expect(hm.photoUrl, 'https://cdn.example.com/priya.jpg');
        expect(hm.availableFrom, '09:00');
        expect(hm.availableTo, '21:00');
      });

      test('applies default availability when fields are absent', () {
        final json = {
          'id': 'hm-2',
          'staff_id': 'staff-10',
          'name': 'Ravi Kumar',
          'phone': '+910000000000',
        };

        final hm = HealthManager.fromJson(json);

        expect(hm.availableFrom, '08:00');
        expect(hm.availableTo, '20:00');
        expect(hm.photoUrl, isNull);
      });
    });

    group('availabilityLabel', () {
      test('formats as "HH:MM – HH:MM" with en-dash', () {
        final hm = HealthManager.fromJson({
          'id': 'hm-3',
          'staff_id': 'staff-3',
          'name': 'Test Manager',
          'phone': '0000',
          'available_from': '08:00',
          'available_to': '20:00',
        });
        expect(hm.availabilityLabel, '08:00 – 20:00');
      });

      test('reflects custom availability times', () {
        final hm = HealthManager.fromJson({
          'id': 'hm-4',
          'staff_id': 'staff-4',
          'name': 'Night Manager',
          'phone': '0000',
          'available_from': '20:00',
          'available_to': '08:00',
        });
        expect(hm.availabilityLabel, '20:00 – 08:00');
      });
    });
  });

  // =========================================================================
  // ServiceDetail
  // =========================================================================
  group('ServiceDetail', () {
    test('fromJson constructs all nested objects', () {
      final json = {
        'service': _activeServiceJson(serviceCategory: 'care_package', totalDays: 30, consumedDays: 5),
        'staff_on_duty': [
          {
            'id': 'sod-1',
            'name': 'Nurse Joy',
            'role': 'nurse',
            'shift_type': '12hr',
            'check_in_time': '2026-03-21T08:00:00',
          },
        ],
        'attendance_days': [
          {
            'date': '2026-03-20',
            'status': 'on_time',
            'staff_name': 'Nurse Joy',
          },
        ],
        'vitals_summary': {
          'bp': {'label': '120/80', 'status': 'normal', 'sparkline': [120.0, 118.0]},
          'spo2': {'label': '97%', 'status': 'normal', 'sparkline': []},
          'pulse': {'label': '72 bpm', 'status': 'normal', 'sparkline': []},
          'temperature': {'label': '98.6°F', 'status': 'normal', 'sparkline': []},
        },
        'today_report': {
          'total_tasks': 8,
          'completed_tasks': 5,
          'tasks': [
            {'name': 'Morning vitals', 'status': 'completed', 'completed_at': '07:30'},
          ],
          'staff_notes': 'Patient resting well.',
        },
        'equipment': [
          {
            'name': 'Oxygen Concentrator',
            'monthly_rate': 4500,
            'start_date': '2026-03-01',
            'status': 'active',
          },
        ],
      };

      final detail = ServiceDetail.fromJson(json);

      expect(detail.service.id, 'svc-1');
      expect(detail.staffOnDuty.length, 1);
      expect(detail.staffOnDuty.first.name, 'Nurse Joy');
      expect(detail.attendanceDays.length, 1);
      expect(detail.attendanceDays.first.status, 'on_time');
      expect(detail.vitalsSummary, isNotNull);
      expect(detail.vitalsSummary!.bp.label, '120/80');
      expect(detail.todayReport, isNotNull);
      expect(detail.todayReport!.totalTasks, 8);
      expect(detail.equipment.length, 1);
      expect(detail.equipment.first.name, 'Oxygen Concentrator');
    });

    test('fromJson handles absent optional lists and nested nulls', () {
      final json = {
        'service': _activeServiceJson(),
      };

      final detail = ServiceDetail.fromJson(json);

      expect(detail.staffOnDuty, isEmpty);
      expect(detail.attendanceDays, isEmpty);
      expect(detail.equipment, isEmpty);
      expect(detail.vitalsSummary, isNull);
      expect(detail.todayReport, isNull);
    });
  });

  // =========================================================================
  // StaffOnDuty
  // =========================================================================
  group('StaffOnDuty', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'id': 'sod-99',
          'name': 'Meera Nair',
          'photo_url': 'https://cdn.example.com/meera.jpg',
          'role': 'caretaker',
          'shift_type': '24hr',
          'check_in_time': '2026-03-21T07:00:00',
          'rating': 4.5,
          'is_replacement': true,
          'replacing_name': 'Sunita Rao',
        };

        final staff = StaffOnDuty.fromJson(json);

        expect(staff.id, 'sod-99');
        expect(staff.name, 'Meera Nair');
        expect(staff.photoUrl, 'https://cdn.example.com/meera.jpg');
        expect(staff.role, 'caretaker');
        expect(staff.shiftType, '24hr');
        expect(staff.checkInTime, DateTime.parse('2026-03-21T07:00:00'));
        expect(staff.rating, 4.5);
        expect(staff.isReplacement, isTrue);
        expect(staff.replacingName, 'Sunita Rao');
      });

      test('defaults shift_type to 24hr when absent', () {
        final json = {
          'id': 's-1',
          'name': 'Default Staff',
          'role': 'nurse',
        };
        final staff = StaffOnDuty.fromJson(json);
        expect(staff.shiftType, '24hr');
        expect(staff.checkInTime, isNull);
        expect(staff.isReplacement, isFalse);
      });
    });

    group('onDutyDuration', () {
      test('returns a Duration when checkInTime is set', () {
        final checkIn = DateTime.now().subtract(const Duration(hours: 3));
        final staff = StaffOnDuty(
          id: 's-1',
          name: 'Test',
          role: 'nurse',
          shiftType: '12hr',
          checkInTime: checkIn,
        );
        expect(staff.onDutyDuration, isNotNull);
        expect(staff.onDutyDuration!.inHours, greaterThanOrEqualTo(2));
      });

      test('returns null when checkInTime is null', () {
        final staff = StaffOnDuty(
          id: 's-2',
          name: 'Test',
          role: 'nurse',
          shiftType: '12hr',
        );
        expect(staff.onDutyDuration, isNull);
      });
    });
  });

  // =========================================================================
  // AttendanceDay
  // =========================================================================
  group('AttendanceDay', () {
    test('fromJson parses all fields', () {
      final json = {
        'date': '2026-03-15',
        'status': 'late',
        'staff_name': 'Rekha Singh',
        'replacement_name': null,
      };

      final day = AttendanceDay.fromJson(json);

      expect(day.date, DateTime(2026, 3, 15));
      expect(day.status, 'late');
      expect(day.staffName, 'Rekha Singh');
      expect(day.replacementName, isNull);
    });

    test('fromJson handles replacement scenario', () {
      final json = {
        'date': '2026-03-16',
        'status': 'replacement',
        'staff_name': 'Original Staff',
        'replacement_name': 'Replacement Staff',
      };

      final day = AttendanceDay.fromJson(json);

      expect(day.status, 'replacement');
      expect(day.replacementName, 'Replacement Staff');
    });

    test('fromJson handles absent staff and replacement names', () {
      final json = {
        'date': '2026-03-17',
        'status': 'absent',
      };

      final day = AttendanceDay.fromJson(json);

      expect(day.staffName, isNull);
      expect(day.replacementName, isNull);
    });
  });

  // =========================================================================
  // VitalsSummary and VitalCard
  // =========================================================================
  group('VitalCard', () {
    test('fromJson parses label, status, and sparkline', () {
      final json = {
        'label': '128/82',
        'status': 'normal',
        'sparkline': [120.0, 122.0, 119.0, 125.0, 128.0],
      };

      final card = VitalCard.fromJson(json);

      expect(card.label, '128/82');
      expect(card.status, 'normal');
      expect(card.sparkline, [120.0, 122.0, 119.0, 125.0, 128.0]);
    });

    test('defaults status to normal when absent', () {
      final json = {'label': '97%'};
      final card = VitalCard.fromJson(json);
      expect(card.status, 'normal');
    });

    test('defaults sparkline to empty list when absent', () {
      final json = {'label': '78 bpm', 'status': 'normal'};
      final card = VitalCard.fromJson(json);
      expect(card.sparkline, isEmpty);
    });

    test('casts integer sparkline values to double', () {
      final json = {
        'label': '98.6°F',
        'status': 'normal',
        'sparkline': [98, 99, 97],
      };
      final card = VitalCard.fromJson(json);
      expect(card.sparkline, [98.0, 99.0, 97.0]);
      expect(card.sparkline.every((v) => v is double), isTrue);
    });
  });

  group('VitalsSummary', () {
    test('fromJson constructs all four VitalCard fields', () {
      final json = {
        'bp': {'label': '120/80', 'status': 'normal', 'sparkline': []},
        'spo2': {'label': '98%', 'status': 'normal', 'sparkline': [98.0, 97.0]},
        'pulse': {'label': '72 bpm', 'status': 'normal', 'sparkline': []},
        'temperature': {'label': '98.6°F', 'status': 'normal', 'sparkline': []},
      };

      final summary = VitalsSummary.fromJson(json);

      expect(summary.bp.label, '120/80');
      expect(summary.spo2.label, '98%');
      expect(summary.spo2.sparkline, [98.0, 97.0]);
      expect(summary.pulse.label, '72 bpm');
      expect(summary.temperature.label, '98.6°F');
    });
  });

  // =========================================================================
  // CareReportSummary
  // =========================================================================
  group('CareReportSummary', () {
    group('fromJson', () {
      test('parses all fields including nested tasks', () {
        final json = {
          'total_tasks': 8,
          'completed_tasks': 5,
          'tasks': [
            {'name': 'Morning vitals', 'status': 'completed', 'completed_at': '07:30'},
            {'name': 'Physiotherapy', 'status': 'in_progress'},
            {'name': 'Evening walk', 'status': 'upcoming'},
          ],
          'staff_notes': 'Patient stable and cooperative.',
        };

        final report = CareReportSummary.fromJson(json);

        expect(report.totalTasks, 8);
        expect(report.completedTasks, 5);
        expect(report.tasks.length, 3);
        expect(report.staffNotes, 'Patient stable and cooperative.');
      });

      test('handles missing tasks list and staffNotes', () {
        final json = {
          'total_tasks': 4,
          'completed_tasks': 2,
        };

        final report = CareReportSummary.fromJson(json);

        expect(report.tasks, isEmpty);
        expect(report.staffNotes, isNull);
      });

      test('defaults totalTasks and completedTasks to 0 when absent', () {
        final report = CareReportSummary.fromJson({});
        expect(report.totalTasks, 0);
        expect(report.completedTasks, 0);
      });
    });

    group('completionFraction', () {
      test('returns 5/8 = 0.625', () {
        final report = CareReportSummary.fromJson({
          'total_tasks': 8,
          'completed_tasks': 5,
        });
        expect(report.completionFraction, closeTo(0.625, 1e-9));
      });

      test('returns 0.0 when totalTasks is 0', () {
        final report = CareReportSummary.fromJson({
          'total_tasks': 0,
          'completed_tasks': 0,
        });
        expect(report.completionFraction, 0.0);
      });

      test('returns 1.0 when all tasks complete', () {
        final report = CareReportSummary.fromJson({
          'total_tasks': 6,
          'completed_tasks': 6,
        });
        expect(report.completionFraction, closeTo(1.0, 1e-9));
      });
    });
  });

  // =========================================================================
  // ReportTaskItem
  // =========================================================================
  group('ReportTaskItem', () {
    test('fromJson parses name, status, and completedAt', () {
      final json = {
        'name': 'Morning vitals',
        'status': 'completed',
        'completed_at': '07:30',
      };

      final item = ReportTaskItem.fromJson(json);

      expect(item.name, 'Morning vitals');
      expect(item.status, 'completed');
      expect(item.completedAt, '07:30');
    });

    test('fromJson handles absent completedAt', () {
      final json = {
        'name': 'Evening walk',
        'status': 'upcoming',
      };

      final item = ReportTaskItem.fromJson(json);

      expect(item.name, 'Evening walk');
      expect(item.status, 'upcoming');
      expect(item.completedAt, isNull);
    });

    test('fromJson parses in_progress status', () {
      final json = {
        'name': 'Physiotherapy session',
        'status': 'in_progress',
      };
      final item = ReportTaskItem.fromJson(json);
      expect(item.status, 'in_progress');
    });
  });

  // =========================================================================
  // EquipmentDeployed
  // =========================================================================
  group('EquipmentDeployed', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': 'Oxygen Concentrator',
        'monthly_rate': 4500,
        'start_date': '2026-03-01',
        'status': 'active',
      };

      final eq = EquipmentDeployed.fromJson(json);

      expect(eq.name, 'Oxygen Concentrator');
      expect(eq.monthlyRate, 4500);
      expect(eq.startDate, DateTime(2026, 3, 1));
      expect(eq.status, 'active');
    });

    test('defaults monthly_rate to 0 when absent', () {
      final json = {
        'name': 'Wheelchair',
        'start_date': '2026-02-15',
      };

      final eq = EquipmentDeployed.fromJson(json);

      expect(eq.monthlyRate, 0);
    });

    test('defaults status to active when absent', () {
      final json = {
        'name': 'Hospital Bed',
        'monthly_rate': 6000,
        'start_date': '2026-01-10',
      };

      final eq = EquipmentDeployed.fromJson(json);

      expect(eq.status, 'active');
    });

    test('parses returned status', () {
      final json = {
        'name': 'Nebuliser',
        'monthly_rate': 1500,
        'start_date': '2026-01-01',
        'status': 'returned',
      };

      final eq = EquipmentDeployed.fromJson(json);

      expect(eq.status, 'returned');
    });
  });
}
