// lib/data/demo_data.dart
//
// Realistic seed data for demo / offline mode.
// Patient: Rajesh Kumar — ICU at Home + Caretaker + Physiotherapy

import '../models/models.dart';
import '../models/my_care_models.dart';
import '../models/medication_models.dart';
import '../models/article.dart';

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
  static List<Article> get articles => [
        Article(
          id: 'art_bedridden_care',
          title: 'Caring for a Bedridden Patient at Home',
          summary:
              'Simple daily routines that keep a bedridden loved one safe, '
              'clean and comfortable.',
          body: '''
# Caring for a Bedridden Patient at Home

Caring for someone confined to bed can feel overwhelming. A steady daily routine makes it manageable.

## Daily essentials
- **Reposition every 2 hours** to prevent pressure sores.
- **Keep skin clean and dry** — change soiled linen promptly.
- **Offer fluids regularly**, even small sips, to avoid dehydration.

## Watch for warning signs
- Redness over the hips, heels or lower back.
- Reduced appetite or confusion.
- Fever or breathing changes.

If anything seems off, call your Health Manager — early action prevents complications.
''',
          coverImageUrl: null,
          category: 'Home Care',
          readMinutes: 4,
          publishedAt: _daysAgo(12),
        ),
        Article(
          id: 'art_post_icu',
          title: 'Post-ICU Recovery: The First 30 Days',
          summary:
              'What to expect after discharge from intensive care and how to '
              'support a smooth recovery at home.',
          body: '''
# Post-ICU Recovery: The First 30 Days

Recovery after an ICU stay is gradual. Patience and consistency matter most.

## Setting up at home
- Create a calm, well-lit space close to a bathroom.
- Keep medicines, water and a call bell within reach.
- Maintain a regular sleep schedule to rebuild strength.

## Rebuilding strength
- Start with short, gentle walks as advised by the physiotherapist.
- Follow the prescribed breathing exercises daily.
- Eat small, protein-rich meals through the day.

Track progress weekly and share concerns with your care team.
''',
          coverImageUrl: null,
          category: 'Recovery',
          readMinutes: 5,
          publishedAt: _daysAgo(20),
        ),
        Article(
          id: 'art_diabetes_diet',
          title: 'Managing the Diabetes Diet for Elders',
          summary:
              'Practical, India-friendly meal tips to keep blood sugar steady '
              'for older adults.',
          body: '''
# Managing the Diabetes Diet for Elders

Good food choices help keep blood sugar in a safe range without feeling deprived.

## Build a balanced plate
- Fill half the plate with **vegetables and dal**.
- Choose **whole grains** — millets, brown rice or whole-wheat roti.
- Add a small portion of **protein** with every meal.

## Smart habits
- Eat at regular times each day.
- Limit sweets, fried snacks and sugary drinks.
- Keep a simple log of fasting readings.

Always tailor portions to your doctor's advice.
''',
          coverImageUrl: null,
          category: 'Nutrition',
          readMinutes: 4,
          publishedAt: _daysAgo(28),
        ),
        Article(
          id: 'art_bed_sores',
          title: 'Preventing Bed Sores',
          summary:
              'Bed sores are painful but largely preventable. Here is how to '
              'protect the skin.',
          body: '''
# Preventing Bed Sores

Bed sores (pressure injuries) form where skin presses against a surface for too long.

## Prevention basics
- **Change position every 2 hours**, day and night.
- Use soft pillows or a pressure-relief mattress.
- Keep skin clean, dry and moisturised.

## Inspect daily
- Check bony areas: heels, hips, tailbone, elbows.
- Look for redness that does not fade within minutes.

Report any open or darkened skin to your nurse immediately.
''',
          coverImageUrl: null,
          category: 'Home Care',
          readMinutes: 3,
          publishedAt: _daysAgo(35),
        ),
        Article(
          id: 'art_when_to_call',
          title: 'When to Call Your Health Manager',
          summary:
              'A quick guide to the signs that mean you should reach out for '
              'help right away.',
          body: '''
# When to Call Your Health Manager

Your Health Manager is here to help. Knowing when to call saves precious time.

## Call right away if you notice
- **Sudden breathlessness** or chest pain.
- High fever that does not come down.
- New confusion, fainting or a fall.
- A wound that is bleeding or looks infected.

## Call the same day for
- Missed or doubled medicine doses.
- Poor appetite or low fluid intake for over a day.
- Questions about the care plan.

When in doubt, it is always okay to call.
''',
          coverImageUrl: null,
          category: 'Guidance',
          readMinutes: 3,
          publishedAt: _daysAgo(5),
        ),
      ];
}
