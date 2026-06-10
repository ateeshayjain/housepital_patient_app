// lib/data/demo_data.dart
//
// Realistic seed data for demo / offline mode.
// Patient: Rajesh Kumar — ICU at Home + Caretaker + Physiotherapy

import 'dart:convert';

import '../config/constants.dart';
import '../models/care_event.dart';
import '../models/doctor_recommendation.dart';
import '../models/models.dart';
import '../models/my_care_models.dart';
import '../models/medication_models.dart';
import '../models/article.dart';
import 'demo_articles.dart';

class DemoData {
  DemoData._();

  // ── Dates relative to "now" ──────────────────────────────────────────
  static DateTime get _now => DateTime.now();
  static DateTime _daysAgo(int d) => _now.subtract(Duration(days: d));
  static DateTime _today(int hour, [int minute = 0]) =>
      DateTime(_now.year, _now.month, _now.day, hour, minute);

  // ── Patient ──────────────────────────────────────────────────────────
  static Patient get patient => Patient(
        id: 'pat_demo_rajesh',
        name: 'Rajesh Kumar',
        age: 72,
        gender: 'Male',
        conditions: ['Post-stroke', 'Hypertension', 'Type 2 Diabetes'],
        medications: [
          Medication(name: 'Amlodipine', dosage: '5 mg', schedule: 'Morning'),
          Medication(
              name: 'Metformin', dosage: '500 mg', schedule: 'Morning & Evening'),
          Medication(name: 'Aspirin', dosage: '75 mg', schedule: 'Afternoon'),
          Medication(
              name: 'Pantoprazole',
              dosage: '40 mg',
              schedule: 'Morning (empty stomach)'),
          Medication(
              name: 'Insulin Glargine',
              dosage: '10 units',
              schedule: 'Bedtime'),
        ],
        allergies: ['Sulfa drugs'],
        dietaryRestrictions: 'Low sodium, diabetic diet',
        mobilityStatus: 'Bed-ridden',
        doctorName: 'Dr. Ananya Sharma',
        doctorPhone: '9812345678',
        doctorHospital: 'Fortis Hospital',
        emergencyContacts: [
          EmergencyContact(
              name: 'Priya Kumar', phone: '9876543210', relation: 'Daughter'),
        ],
        address: 'B-42, Sector 15, Noida 201301',
        city: 'Noida',
        createdAt: _daysAgo(30),
        height: '170 cm',
        weight: '68 kg',
        diagnosis: 'Post-stroke rehabilitation, Hypertension, Type 2 Diabetes',
        feedingType: 'Oral (soft diet)',
        mentalCondition: 'Alert, oriented',
        motionStatus: 'Bed-ridden',
        bpSugarInsulin: 'BP managed, Sugar variable, On insulin',
      );

  // ── Deployments ──────────────────────────────────────────────────────
  static Deployment get icuDeployment => Deployment(
        id: 'dep_icu_001',
        patientId: 'pat_demo_rajesh',
        staffId: 'staff_sunita',
        staffName: 'Sunita Devi',
        staffRole: 'Critical Care Nurse',
        staffRating: 4.9,
        shiftType: '24hr',
        startDate: _daysAgo(15),
        totalDays: 30,
        status: 'active',
        autoRenew: true,
        billingCycle: 'monthly',
        nextBillingDate: _daysAgo(15).add(const Duration(days: 30)),
      );

  static Deployment get caretakerDeployment => Deployment(
        id: 'dep_ct_001',
        patientId: 'pat_demo_rajesh',
        staffId: 'staff_ram',
        staffName: 'Ram Singh',
        staffRole: 'Caretaker',
        staffRating: 4.6,
        shiftType: '12hr_day',
        startDate: _daysAgo(15),
        totalDays: 30,
        status: 'active',
        autoRenew: true,
        billingCycle: 'monthly',
        nextBillingDate: _daysAgo(15).add(const Duration(days: 30)),
      );

  static Deployment get physioDeployment => Deployment(
        id: 'dep_physio_001',
        patientId: 'pat_demo_rajesh',
        staffId: 'staff_meera',
        staffName: 'Dr. Meera Patel',
        staffRole: 'Physiotherapist',
        staffRating: 4.8,
        shiftType: '12hr_day',
        startDate: _daysAgo(10),
        totalDays: 30,
        status: 'active',
        billingCycle: 'monthly',
      );

  // ── Today's Attendance ───────────────────────────────────────────────
  static Attendance get todayAttendance => Attendance(
        id: 'att_today_001',
        deploymentId: 'dep_icu_001',
        staffId: 'staff_sunita',
        date: _today(0),
        status: 'checked_in',
        checkInTime: _today(7, 0),
      );

  // ── Vitals History (7 days) ──────────────────────────────────────────
  static List<VitalReading> get vitalsHistory {
    // Realistic post-stroke ICU patient vitals
    final bpSys = [142.0, 138.0, 148.0, 135.0, 145.0, 140.0, 136.0];
    final bpDia = [88.0, 85.0, 92.0, 82.0, 90.0, 87.0, 84.0];
    final spo2 = [95.0, 94.0, 96.0, 95.0, 97.0, 96.0, 96.0];
    final pulse = [82.0, 78.0, 85.0, 76.0, 88.0, 80.0, 78.0];
    final temp = [98.4, 98.6, 99.0, 98.2, 98.8, 99.1, 98.6];
    final sugar = [180.0, 165.0, 210.0, 155.0, 195.0, 220.0, 170.0];

    return List.generate(7, (i) {
      final day = _daysAgo(6 - i);
      return VitalReading(
        id: 'vital_${6 - i}',
        patientId: 'pat_demo_rajesh',
        staffId: 'staff_sunita',
        staffName: 'Sunita Devi',
        recordedAt: DateTime(day.year, day.month, day.day, 8, 0),
        systolic: bpSys[i],
        diastolic: bpDia[i],
        pulse: pulse[i],
        spo2: spo2[i],
        temperature: temp[i],
        sugar: sugar[i],
        sugarType: 'fasting',
        notes: i == 6
            ? 'Slight increase in BP after breakfast — monitoring.'
            : null,
      );
    });
  }

  // ── Today's Report ───────────────────────────────────────────────────
  static DailyReport get todayReport => DailyReport(
        id: 'rpt_today_001',
        deploymentId: 'dep_icu_001',
        staffId: 'staff_sunita',
        staffName: 'Sunita Devi',
        date: _today(0),
        submittedAt: _today(10, 30),
        sections: [
          ReportSection(name: 'Morning Routine', status: 'done', tasks: [
            ReportTask(
                name: 'Morning Vitals',
                completed: true,
                completedAt: '07:15 AM'),
            ReportTask(
                name: 'Sponge Bath',
                completed: true,
                completedAt: '07:45 AM'),
            ReportTask(
                name: 'Medication (8 AM)',
                completed: true,
                completedAt: '08:05 AM'),
            ReportTask(
                name: 'Feeding (Breakfast)',
                completed: true,
                completedAt: '08:30 AM'),
            ReportTask(
                name: 'Suction', completed: true, completedAt: '09:00 AM'),
          ]),
          ReportSection(name: 'Midday', status: 'pending', tasks: [
            ReportTask(
                name: 'Physiotherapy (11 AM)', completed: false),
            ReportTask(name: 'Lunch Feeding', completed: false),
          ]),
          ReportSection(name: 'Evening', status: 'pending', tasks: [
            ReportTask(name: 'Evening Medication', completed: false),
          ]),
        ],
        staffNotes:
            'Patient comfortable. SpO2 maintained at 96% on 2L O2. Slight increase in BP after breakfast — monitoring.',
        completedTasks: 5,
        totalTasks: 8,
      );

  // ── Active Services (My Care screen) ─────────────────────────────────
  static List<ActiveService> get activeServices => [
        // 1. ICU Setup at Home
        ActiveService(
          id: 'svc_icu_001',
          name: 'ICU Setup at Home',
          serviceCategory: 'care_package',
          status: 'active',
          startDate: _daysAgo(15),
          endDate: _daysAgo(15).add(const Duration(days: 30)),
          totalDays: 30,
          consumedDays: 15,
          totalStaff: 2,
          checkedInStaff: 2,
          latestVitalLabel: '136/84 mmHg',
          latestVitalStatus: 'warning',
          dailyRate: 4500,
          totalPaid: 115500,
          totalConsumed: 67500,
          remaining: 67500,
          renewalDate: _daysAgo(15).add(const Duration(days: 30)),
          deploymentIds: ['dep_icu_001', 'dep_ct_001'],
        ),
        // 2. Caretaker (Basic) 12 Hours
        ActiveService(
          id: 'svc_ct_001',
          name: 'Caretaker (Basic) 12 Hours',
          serviceCategory: 'caretaker',
          status: 'active',
          startDate: _daysAgo(15),
          endDate: _daysAgo(15).add(const Duration(days: 30)),
          totalDays: 30,
          consumedDays: 15,
          totalStaff: 1,
          checkedInStaff: 1,
          deploymentIds: ['dep_ct_001'],
        ),
        // 3. Physiotherapy (Advanced) — session-based
        ActiveService(
          id: 'svc_physio_001',
          name: 'Physiotherapy (Advanced)',
          serviceCategory: 'physiotherapy',
          status: 'active',
          startDate: _daysAgo(10),
          endDate: _daysAgo(10).add(const Duration(days: 30)),
          totalDays: 30,
          consumedDays: 10,
          isSessionBased: true,
          totalStaff: 1,
          checkedInStaff: 0,
          deploymentIds: ['dep_physio_001'],
        ),
      ];

  // ── Service Detail (ICU) ─────────────────────────────────────────────
  static ServiceDetail get icuServiceDetail => ServiceDetail(
        service: activeServices[0],
        staffOnDuty: [
          StaffOnDuty(
            id: 'staff_sunita',
            name: 'Sunita Devi',
            role: 'Critical Care Nurse',
            shiftType: '24hr',
            checkInTime: _today(7, 0),
            rating: 4.9,
          ),
          StaffOnDuty(
            id: 'staff_ram',
            name: 'Ram Singh',
            role: 'Caretaker',
            shiftType: '12hr',
            checkInTime: _today(8, 0),
            rating: 4.6,
          ),
        ],
        attendanceDays: List.generate(7, (i) {
          return AttendanceDay(
            date: _daysAgo(6 - i),
            status: i == 3 ? 'late' : 'on_time',
            staffName: 'Sunita Devi',
          );
        }),
        vitalsSummary: VitalsSummary(
          bp: VitalCard(
            label: '136/84 mmHg',
            status: 'warning',
            sparkline: [142, 138, 148, 135, 145, 140, 136],
          ),
          spo2: VitalCard(
            label: '96%',
            status: 'normal',
            sparkline: [95, 94, 96, 95, 97, 96, 96],
          ),
          pulse: VitalCard(
            label: '78 bpm',
            status: 'normal',
            sparkline: [82, 78, 85, 76, 88, 80, 78],
          ),
          temperature: VitalCard(
            label: '98.6\u00B0F',
            status: 'normal',
            sparkline: [98.4, 98.6, 99.0, 98.2, 98.8, 99.1, 98.6],
          ),
        ),
        todayReport: CareReportSummary(
          totalTasks: 8,
          completedTasks: 5,
          tasks: [
            ReportTaskItem(
                name: 'Morning Vitals',
                status: 'completed',
                completedAt: '07:15 AM'),
            ReportTaskItem(
                name: 'Sponge Bath',
                status: 'completed',
                completedAt: '07:45 AM'),
            ReportTaskItem(
                name: 'Medication (8 AM)',
                status: 'completed',
                completedAt: '08:05 AM'),
            ReportTaskItem(
                name: 'Feeding (Breakfast)',
                status: 'completed',
                completedAt: '08:30 AM'),
            ReportTaskItem(
                name: 'Suction',
                status: 'completed',
                completedAt: '09:00 AM'),
            ReportTaskItem(
                name: 'Physiotherapy (11 AM)', status: 'upcoming'),
            ReportTaskItem(name: 'Lunch Feeding', status: 'upcoming'),
            ReportTaskItem(name: 'Evening Medication', status: 'upcoming'),
          ],
          staffNotes:
              'Patient comfortable. SpO2 maintained at 96% on 2L O2. Slight increase in BP after breakfast — monitoring.',
        ),
        equipment: [
          EquipmentDeployed(
            name: 'Ventilator (ResMed)',
            monthlyRate: 29999,
            startDate: _daysAgo(15),
            status: 'active',
          ),
          EquipmentDeployed(
            name: '5 Para Monitor (BPL)',
            monthlyRate: 8099,
            startDate: _daysAgo(15),
            status: 'active',
          ),
          EquipmentDeployed(
            name: 'Hospital Bed (5 Function Electric)',
            monthlyRate: 13499,
            startDate: _daysAgo(15),
            status: 'active',
          ),
          EquipmentDeployed(
            name: 'Suction Machine',
            monthlyRate: 2999,
            startDate: _daysAgo(15),
            status: 'active',
          ),
        ],
      );

  // ── Health Manager ───────────────────────────────────────────────────
  static HealthManager get healthManager => HealthManager(
        id: 'hm_001',
        staffId: 'staff_hm_001',
        name: 'Vikram Mehta',
        phone: '9988776655',
        availableFrom: '08:00',
        availableTo: '20:00',
      );

  // ── Operations Supervisor (Care Team screen) ─────────────────────────
  /// Escalation contact above the Health Manager. Demo-only record — the
  /// backend has no supervisor endpoint yet, so this is a plain Dart record.
  static ({String name, String role, String phone}) get supervisor => (
        name: 'Rohit Verma',
        role: 'Operations Supervisor',
        phone: AppConstants.supportPhone,
      );

  // ── Doctor Recommendations (My Care → Doctor's Advice card) ──────────
  /// What Dr. Ananya Sharma recommended at her visit 2 days ago.
  static List<DoctorRecommendation> get doctorRecommendations => const [
        DoctorRecommendation(
          id: 'rec_nebulizer',
          title: 'Nebulizer (Rental)',
          note: 'Twice daily for chest congestion',
          type: 'equipment',
          catalogId: 'NDK-NEBULI',
          isRental: true,
        ),
        DoctorRecommendation(
          id: 'rec_cbc',
          title: 'CBC Blood Test',
          note: 'Repeat after 1 week of antibiotics',
          type: 'lab',
          catalogId: 'lab-cbc',
        ),
        DoctorRecommendation(
          id: 'rec_physio',
          title: 'Physiotherapy (Basic)',
          note: '2 weeks, post-bedrest mobility',
          type: 'service',
          catalogId: 'mp-physio-basic',
        ),
      ];

  // ── Medications (MedicationFull) ─────────────────────────────────────
  static List<MedicationFull> get medications => [
        MedicationFull(
          id: 'med_amlodipine',
          patientId: 'pat_demo_rajesh',
          name: 'Amlodipine',
          dosage: '5 mg',
          form: 'tablet',
          frequency: 'once_daily',
          timeSlots: ['08:00'],
          instructions: 'Take with water after food',
          prescribedBy: 'Dr. Ananya Sharma',
          prescribedDate: _daysAgo(30),
          stockCount: 22,
          stockUnit: 'tablets',
          isActive: true,
        ),
        MedicationFull(
          id: 'med_metformin',
          patientId: 'pat_demo_rajesh',
          name: 'Metformin',
          dosage: '500 mg',
          form: 'tablet',
          frequency: 'twice_daily',
          timeSlots: ['08:00', '21:00'],
          instructions: 'Take after meals',
          prescribedBy: 'Dr. Ananya Sharma',
          prescribedDate: _daysAgo(30),
          stockCount: 40,
          stockUnit: 'tablets',
          isActive: true,
        ),
        MedicationFull(
          id: 'med_aspirin',
          patientId: 'pat_demo_rajesh',
          name: 'Aspirin',
          dosage: '75 mg',
          form: 'tablet',
          frequency: 'once_daily',
          timeSlots: ['14:00'],
          instructions: 'Blood thinner — take after lunch',
          prescribedBy: 'Dr. Ananya Sharma',
          prescribedDate: _daysAgo(30),
          stockCount: 18,
          stockUnit: 'tablets',
          isActive: true,
        ),
        MedicationFull(
          id: 'med_pantoprazole',
          patientId: 'pat_demo_rajesh',
          name: 'Pantoprazole',
          dosage: '40 mg',
          form: 'tablet',
          frequency: 'once_daily',
          timeSlots: ['07:00'],
          instructions: 'Take on empty stomach, 30 min before breakfast',
          prescribedBy: 'Dr. Ananya Sharma',
          prescribedDate: _daysAgo(30),
          stockCount: 25,
          stockUnit: 'tablets',
          isActive: true,
        ),
        MedicationFull(
          id: 'med_insulin',
          patientId: 'pat_demo_rajesh',
          name: 'Insulin Glargine',
          dosage: '10 units',
          form: 'injection',
          frequency: 'once_daily',
          timeSlots: ['22:00'],
          instructions: 'Subcutaneous injection at bedtime',
          prescribedBy: 'Dr. Ananya Sharma',
          prescribedDate: _daysAgo(30),
          stockCount: 3,
          stockUnit: 'units',
          isActive: true,
        ),
      ];

  // ── Upcoming appointments (Care Calendar) ────────────────────────────
  /// Future visits/tests/renewals shown on the Care Calendar. Dates are
  /// relative to "now" like the rest of the demo data:
  ///  • Physiotherapy session tomorrow (active physio service).
  ///  • CBC sample pickup +2 days (ties to Dr. Sharma's CBC recommendation).
  ///  • Dr. Ananya Sharma follow-up visit +3 days.
  ///  • ICU service renewal on ActiveService.renewalDate (~+15 days).
  static List<CareEvent> get upcomingAppointments {
    DateTime onDay(int daysFromNow, int hour) {
      final d = _now.add(Duration(days: daysFromNow));
      return DateTime(d.year, d.month, d.day, hour);
    }

    final renewal = activeServices.first.renewalDate!;
    return [
      CareEvent(
        date: onDay(1, 11),
        type: CareEventType.visit,
        title: 'Physiotherapy session',
        subtitle: '${physioDeployment.staffName} · 11:00 AM',
      ),
      CareEvent(
        date: onDay(2, 9),
        type: CareEventType.test,
        title: 'CBC sample pickup',
        subtitle: 'Home sample collection · 9:00 AM',
      ),
      CareEvent(
        date: onDay(3, 17),
        type: CareEventType.visit,
        title: 'Follow-up visit — Dr. Ananya Sharma',
        subtitle: 'Fortis Hospital · 5:00 PM',
      ),
      CareEvent(
        date: DateTime(renewal.year, renewal.month, renewal.day, 10),
        type: CareEventType.renewal,
        title: 'ICU service renewal',
        subtitle: 'ICU Setup at Home · 30-day cycle',
      ),
    ];
  }

  // ── Orders (pre-seeded for billing visibility) ───────────────────────
  static List<Map<String, dynamic>> get orders => [
        // Active ongoing equipment rental order
        {
          'id': 'HPL-BOOK-10001',
          'items': [
            {
              'equipmentId': 'eq_ventilator',
              'name': 'Ventilator (ResMed)',
              'brand': 'ResMed',
              'unitPrice': 29999,
              'isRental': true,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': false,
            },
            {
              'equipmentId': 'eq_monitor',
              'name': '5 Para Monitor (BPL)',
              'brand': 'BPL',
              'unitPrice': 8099,
              'isRental': true,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': false,
            },
            {
              'equipmentId': 'eq_bed',
              'name': 'Hospital Bed (5 Function Electric)',
              'brand': 'Housepital',
              'unitPrice': 13499,
              'isRental': true,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': false,
            },
            {
              'equipmentId': 'eq_suction',
              'name': 'Suction Machine',
              'brand': 'Housepital',
              'unitPrice': 2999,
              'isRental': true,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': false,
            },
          ],
          'totalAmount': 54596,
          'status': 'delivered',
          'createdAt': _daysAgo(15).toIso8601String(),
          'type': 'equipment',
        },
        // Completed first payment
        {
          'id': 'HPL-BOOK-10002',
          'items': [
            {
              'equipmentId': 'svc_nursing',
              'name': 'Critical Nursing 24hr (15 days)',
              'brand': 'Housepital',
              'unitPrice': 67500,
              'isRental': false,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': true,
            },
            {
              'equipmentId': 'svc_caretaker',
              'name': 'Caretaker 12hr (15 days)',
              'brand': 'Housepital',
              'unitPrice': 13500,
              'isRental': false,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': true,
            },
            {
              'equipmentId': 'svc_physio',
              'name': 'Physiotherapy — 6 visits',
              'brand': 'Housepital',
              'unitPrice': 7200,
              'isRental': false,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': true,
            },
            {
              'equipmentId': 'svc_equip',
              'name': 'Equipment Rental (15 days)',
              'brand': 'Housepital',
              'unitPrice': 27298,
              'isRental': false,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': true,
            },
          ],
          'totalAmount': 115498,
          'status': 'confirmed',
          'createdAt': _daysAgo(15).toIso8601String(),
          'type': 'mixed',
        },
        // Upcoming second-half billing
        {
          'id': 'HPL-BOOK-10003',
          'items': [
            {
              'equipmentId': 'svc_nursing_2',
              'name': 'Critical Nursing 24hr (days 16-30)',
              'brand': 'Housepital',
              'unitPrice': 67500,
              'isRental': false,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': true,
            },
            {
              'equipmentId': 'svc_ct_2',
              'name': 'Caretaker 12hr (days 16-30)',
              'brand': 'Housepital',
              'unitPrice': 13500,
              'isRental': false,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': true,
            },
            {
              'equipmentId': 'svc_physio_2',
              'name': 'Physiotherapy — 6 visits',
              'brand': 'Housepital',
              'unitPrice': 7200,
              'isRental': false,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': true,
            },
            {
              'equipmentId': 'svc_equip_2',
              'name': 'Equipment Rental (days 16-30)',
              'brand': 'Housepital',
              'unitPrice': 27298,
              'isRental': false,
              'rentalMonths': 1,
              'quantity': 1,
              'isService': true,
            },
          ],
          'totalAmount': 115498,
          'status': 'confirmed',
          'createdAt': _now.toIso8601String(),
          'type': 'mixed',
        },
      ];

  // ── Billing summary ──────────────────────────────────────────────────
  static Map<String, dynamic> get billingSummary => {
        'amount_due': 115500,
        'due_date':
            _daysAgo(15).add(const Duration(days: 30)).toIso8601String(),
      };

  // ── Care Guides / Articles ───────────────────────────────────────────
  // Parsed from the embedded JSON in demo_articles.dart so generated content
  // drops in verbatim. Synchronous (jsonDecode) to match BlogProvider's
  // offline-fallback usage.
  static List<Article> get articles => (jsonDecode(kDemoArticlesJson) as List)
      .map((e) => Article.fromJson(e as Map<String, dynamic>))
      .toList();
}
