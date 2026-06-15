// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../models/models.dart';

/// Manpower service catalog (nurses, caretakers, physio).
///
/// Pricing rule (owner decision, Mar 2026 — re-confirmed 2026-06-11):
/// manpower prices ARE SHOWN, from the official Delhi NCR rate card
/// (per-day basePriceMin, excl. GST), and every item is directly bookable.
/// Housepital calls back after purchase to confirm requirements and assign
/// staff. The earlier "never show manpower prices" enforcement (audit M-1
/// and its extension) was based on a stale memory and is reversed here.
/// Quote-pending booking remains ONLY for items that genuinely lack a price.
final List<ServiceItem> manpowerServices = [
  // ── Nursing Staff ──
  ServiceItem(
    id: 'mp-nurse-basic-12', name: 'Nurse (Basic) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Basic nursing care — vitals monitoring, oral medication, feeding & personal hygiene assistance.',
    basePriceMin: 1600, durationMinutes: 720, iconName: 'medical_services',
    preparationNotes:
        'Monthly package: ₹40,500/mo (Nurse Basic, 12 hr).\n'
        'We call back right after booking to confirm requirements and assign staff.',
  ),
  ServiceItem(
    id: 'mp-nurse-basic-24', name: 'Nurse (Basic) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock basic nursing for patients needing continuous monitoring and care.',
    basePriceMin: 2200, durationMinutes: 1440, iconName: 'medical_services',
    preparationNotes:
        'Monthly package: ₹60,000/mo (Nurse Basic, 24 hr).\n'
        'We call back right after booking to confirm requirements and assign staff.',
  ),
  ServiceItem(
    id: 'mp-nurse-adv-12', name: 'Nurse (Advanced) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Advanced nursing — IV/IM medication, catheter care, RT feeding, sugar & BP monitoring.',
    basePriceMin: 1800, durationMinutes: 720, iconName: 'medical_services',
    preparationNotes:
        'Monthly package: ₹45,000/mo (Nurse Advanced, 12 hr).\n'
        'We call back right after booking to confirm requirements and assign staff.',
  ),
  ServiceItem(
    id: 'mp-nurse-adv-24', name: 'Nurse (Advanced) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock advanced nursing for patients needing clinical-grade care at home.',
    basePriceMin: 2500, durationMinutes: 1440, iconName: 'medical_services',
    preparationNotes:
        'Monthly package: ₹75,000/mo (Nurse Advanced, 24 hr).\n'
        'We call back right after booking to confirm requirements and assign staff.',
  ),
  // ── Critical Nurse — ICU-level care, directly bookable (owner 2026-06-11);
  // an assessment callback remains available as an optional secondary path.
  ServiceItem(
    id: 'mp-nurse-crit-12', name: 'Nurse (Critical) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Critical care nursing — tracheostomy care, ventilator management, suctioning, bed sore care.',
    // Rate card anomaly: the 12-hr critical-nurse MONTHLY rate is not on the
    // official card — only the per-day rate is published. Do not invent one.
    basePriceMin: 2000, durationMinutes: 720, iconName: 'medical_services',
    preparationNotes:
        'We call back right after booking to confirm the ICU-at-home setup, '
        'requirements and staff assignment.',
  ),
  ServiceItem(
    id: 'mp-nurse-crit-24', name: 'Nurse (Critical) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock critical care nursing for ICU-like home setups and ventilator patients.',
    basePriceMin: 3000, durationMinutes: 1440, iconName: 'medical_services',
    preparationNotes:
        'Monthly package: ₹90,000/mo (Nurse Critical, 24 hr).\n'
        'We call back right after booking to confirm the ICU-at-home setup, '
        'requirements and staff assignment.',
  ),
  // ── Care-takers ──
  ServiceItem(
    id: 'mp-caretaker-basic-12', name: 'Caretaker (Basic) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Basic caretaker — bathing, mobility assistance, feeding, companionship & medication reminders.',
    basePriceMin: 800, durationMinutes: 720, iconName: 'person',
    preparationNotes:
        'Monthly package: ₹18,000/mo (Caretaker Basic, 12 hr).\n'
        'We call back right after booking to confirm requirements and assign staff.',
  ),
  ServiceItem(
    id: 'mp-caretaker-basic-24', name: 'Caretaker (Basic) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock basic caretaker for daily living assistance and companionship.',
    basePriceMin: 1100, durationMinutes: 1440, iconName: 'person',
    preparationNotes:
        'Monthly package: ₹27,000/mo (Caretaker Basic, 24 hr).\n'
        'We call back right after booking to confirm requirements and assign staff.',
  ),
  ServiceItem(
    id: 'mp-caretaker-adv-12', name: 'Caretaker (Advanced) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Advanced caretaker with IM injection & BP monitoring skills for patients needing medical support.',
    basePriceMin: 1000, durationMinutes: 720, iconName: 'person',
    preparationNotes:
        'Monthly package: ₹21,000/mo (Caretaker Advanced, 12 hr).\n'
        'We call back right after booking to confirm requirements and assign staff.',
  ),
  ServiceItem(
    id: 'mp-caretaker-adv-24', name: 'Caretaker (Advanced) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock advanced caretaker with medical assistance capabilities.',
    basePriceMin: 1300, durationMinutes: 1440, iconName: 'person',
    preparationNotes:
        'Monthly package: ₹30,000/mo (Caretaker Advanced, 24 hr).\n'
        'We call back right after booking to confirm requirements and assign staff.',
  ),
  ServiceItem(
    id: 'mp-caretaker-crit-12', name: 'Caretaker (Critical / Semi-Nurse) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Semi-nurse level caretaker for complex care needs — RT feeding, suctioning assistance.',
    basePriceMin: 1200, durationMinutes: 720, iconName: 'person',
    preparationNotes:
        'Monthly package: ₹24,000/mo (Caretaker Critical, 12 hr).\n'
        'We call back right after booking to confirm requirements and assign staff.',
  ),
  ServiceItem(
    id: 'mp-caretaker-crit-24', name: 'Caretaker (Critical / Semi-Nurse) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock semi-nurse caretaker for patients needing intensive daily care.',
    basePriceMin: 1500, durationMinutes: 1440, iconName: 'person',
    preparationNotes:
        'Monthly package: ₹33,000/mo (Caretaker Critical, 24 hr).\n'
        'We call back right after booking to confirm requirements and assign staff.',
  ),
  // ── Physiotherapy ──
  ServiceItem(
    id: 'mp-physio-basic', name: 'Physiotherapy (Basic)',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Basic physiotherapy (30-40 min) for TKR, THR, frozen shoulder, lower back pain, posture correction, sciatica & sports injuries. Therapist: 1-2 years experience.',
    basePriceMin: 900, durationMinutes: 40, iconName: 'fitness_center',
  ),
  ServiceItem(
    id: 'mp-physio-advance', name: 'Physiotherapy (Advanced)',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Advanced physiotherapy (45-50 min) for neuro rehab, antenatal/postnatal, cardiac rehab, pulmo rehab (not on O2). Therapist: 2-4 years experience.',
    basePriceMin: 1200, durationMinutes: 50, iconName: 'fitness_center',
  ),
  ServiceItem(
    id: 'mp-physio-critical', name: 'Physiotherapy (Critical)',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Critical physiotherapy (50-60 min) for pulmo rehab on O2, neurosurgical cases, spinal cord injury & pediatric post-op. Therapist: 4+ years experience.',
    basePriceMin: 1500, durationMinutes: 60, iconName: 'fitness_center',
  ),
];

/// Diagnostics (at-home tests with equipment).
final List<ServiceItem> diagnosticServices = [
  ServiceItem(
    id: 'dx-ecg', name: 'ECG at Home',
    category: 'diagnostics', bookingType: 'instant',
    description: '12-lead ECG performed at home by a trained technician. Report within 2 hours.',
    basePriceMin: 500, durationMinutes: 30, leadTimeHours: 4, iconName: 'monitor_heart',
  ),
  ServiceItem(
    id: 'dx-xray', name: 'X-Ray at Home',
    category: 'diagnostics', bookingType: 'instant',
    description: 'Portable digital X-Ray at your doorstep. Report shared within 4 hours.',
    basePriceMin: 800, durationMinutes: 30, leadTimeHours: 6, iconName: 'radiology',
  ),
  ServiceItem(
    id: 'dx-holter', name: 'Holter Monitoring — 24 Hours',
    category: 'diagnostics', bookingType: 'instant',
    description: 'At-home 24-hour Holter monitor. Technician visits for setup & removal. Report in 24 hours.',
    basePriceMin: 2500, durationMinutes: 45, leadTimeHours: 12, iconName: 'monitor_heart',
  ),
  // ── Added at-home cardiac & sleep diagnostics (owner: "we provide all of
  //    these at home"). PRICES ARE ESTIMATES — vendor-rate column was blank;
  //    replace with confirmed vendor rates before launch.
  ServiceItem(
    id: 'dx-holter-48', name: 'Holter Monitoring — 48 Hours',
    category: 'diagnostics', bookingType: 'instant',
    description: 'At-home 48-hour Holter monitor for longer arrhythmia capture. Setup & removal at home. Report in 24 hours.',
    basePriceMin: 3500, durationMinutes: 45, leadTimeHours: 12, iconName: 'monitor_heart',
  ),
  ServiceItem(
    id: 'dx-holter-72', name: 'Holter Monitoring — 72 Hours',
    category: 'diagnostics', bookingType: 'instant',
    description: 'At-home 72-hour Holter monitor for extended cardiac rhythm tracking. Setup & removal at home. Report in 24 hours.',
    basePriceMin: 4500, durationMinutes: 45, leadTimeHours: 12, iconName: 'monitor_heart',
  ),
  ServiceItem(
    id: 'dx-abpm-24', name: 'ABPM (Ambulatory BP Monitoring) — 24 Hours',
    category: 'diagnostics', bookingType: 'instant',
    description: 'At-home 24-hour ambulatory blood-pressure monitoring. Technician fits & removes the cuff. Report in 24 hours.',
    basePriceMin: 2500, durationMinutes: 30, leadTimeHours: 12, iconName: 'monitor_heart',
  ),
  ServiceItem(
    id: 'dx-elr', name: 'Event Loop Recorder (ELR)',
    category: 'diagnostics', bookingType: 'instant',
    description: 'At-home event loop recorder for intermittent arrhythmias — worn as prescribed. Setup & removal at home. Report in 48 hours.',
    basePriceMin: 8000, durationMinutes: 45, leadTimeHours: 24, iconName: 'monitor_heart',
  ),
  ServiceItem(
    id: 'dx-sleep-study', name: 'Home Sleep Study (Level III)',
    category: 'diagnostics', bookingType: 'instant',
    description: 'At-home Level III sleep study for sleep apnoea — single overnight recording. Technician sets up at home. Report in 24 hours.',
    basePriceMin: 6000, durationMinutes: 45, leadTimeHours: 24, iconName: 'monitor_heart',
  ),
];

/// Lab Tests (panels + sample collection).
final List<ServiceItem> labServices = [
  ServiceItem(
    id: 'lab-fever', name: 'Fever Panel',
    category: 'lab', bookingType: 'instant',
    description: 'CBC, CRP, Procalcitonin, Peripheral Smear, Typhidot, Dengue NS1, COVID test, Urine Routine — comprehensive fever workup.',
    basePriceMin: 4999, basePriceMax: 4999, iconName: 'science',
  ),
  ServiceItem(
    id: 'lab-wellness', name: 'Wellness Package',
    category: 'lab', bookingType: 'instant',
    description: 'CBC, LFT, KFT, Uric Acid, Thyroid, Lipid Profile, Vitamin B12 & D, Iron, ESR, HbA1C, Folate — 14 tests for complete health check.',
    basePriceMin: 7599, basePriceMax: 7599, iconName: 'science',
  ),
  ServiceItem(
    id: 'lab-immunity', name: 'Immunity Package',
    category: 'lab', bookingType: 'instant',
    description: 'CRP, ESR, Vitamin D & B12, Iron Profile, Folate, Phosphorus, Calcium, Total Proteins — immune health assessment.',
    basePriceMin: 4599, basePriceMax: 4599, iconName: 'science',
  ),
  ServiceItem(
    id: 'lab-bone', name: 'Bone Package',
    category: 'lab', bookingType: 'instant',
    description: 'Alkaline Phosphatase, LDH, PTH, Calcium, Vitamin D — bone health and osteoporosis screening.',
    basePriceMin: 2999, basePriceMax: 2999, iconName: 'science',
  ),
  ServiceItem(
    id: 'lab-metabolic', name: 'Metabolic Package',
    category: 'lab', bookingType: 'instant',
    description: 'Random Sugar, HbA1C, GGT, Lipid Profile, CRP, Liver Profile — metabolic syndrome screening.',
    basePriceMin: 1799, basePriceMax: 1799, iconName: 'science',
  ),
  ServiceItem(
    id: 'lab-adolescent', name: 'Adolescent Package',
    category: 'lab', bookingType: 'instant',
    description: 'HbA1C, CBC, Vitamin D, TSH, Iron Profile — health check for young adults.',
    basePriceMin: 2499, basePriceMax: 2499, iconName: 'science',
  ),
  ServiceItem(
    id: 'lab-anemia', name: 'Anemia Package',
    category: 'lab', bookingType: 'instant',
    description: 'CBC, Peripheral Smear, ESR, HPLC, Ferritin, Iron Profile, Reticulocyte Count, B12, Folate — complete anemia workup.',
    basePriceMin: 4599, basePriceMax: 4599, iconName: 'science',
  ),
  ServiceItem(
    id: 'dx-sample-5km', name: 'Blood Sample Collection (0-5 km)',
    category: 'lab', bookingType: 'instant',
    description: 'Phlebotomist visits your home to collect blood samples. Reports shared digitally.',
    basePriceMin: 150, basePriceMax: 150, iconName: 'science',
  ),
  ServiceItem(
    id: 'dx-sample-10km', name: 'Blood Sample Collection (5-10 km)',
    category: 'lab', bookingType: 'instant',
    description: 'Phlebotomist visits your home to collect blood samples. Reports shared digitally.',
    basePriceMin: 200, basePriceMax: 200, iconName: 'science',
  ),
  ServiceItem(
    id: 'dx-sample-15km', name: 'Blood Sample Collection (10-15 km)',
    category: 'lab', bookingType: 'instant',
    description: 'Phlebotomist visits your home to collect blood samples. Reports shared digitally.',
    basePriceMin: 250, basePriceMax: 250, iconName: 'science',
  ),
];

/// Consultations (doctor visits, mental health, therapy).
final List<ServiceItem> consultationServices = [
  ServiceItem(
    id: 'con-doctor', name: 'Doctor Visit',
    category: 'consultation', bookingType: 'scheduled',
    description: 'Tell us your concern — we\'ll recommend the right doctor (General Physician or ICU Specialist) for your home visit.',
    basePriceMin: 3500, basePriceMax: 5000, durationMinutes: 30, leadTimeHours: 4,
    iconName: 'stethoscope',
  ),
  // Content from the Mental Health SM creative (2026-06): "Because talking
  // is important." Fees per creative: initial ₹1,000 (15 min) / therapy
  // ₹1,500 (40 min) / monthly pack ₹9,500 (8 sessions). 100% online,
  // Mon–Fri 6–8 PM. No staff names in catalog copy (owner rule) — the
  // assigned professional is introduced at confirmation.
  ServiceItem(
    id: 'con-psychiatrist', name: 'Psychiatrist Consultation',
    category: 'consultation', bookingType: 'scheduled',
    description:
        'Because talking is important. Consultant psychiatrist & '
        'psychotherapist (MBBS, MD Psychiatry) — 100% online, private '
        'and judgment-free.',
    basePriceMin: 1000, basePriceMax: 1500,
    durationMinutes: 40, leadTimeHours: 24, iconName: 'psychology',
    // preparationNotes shape (parsed generically by the booking screen):
    //   'Label: a, b, c'      → sub-label + soft chips (comma list)
    //   'Plans: x ₹.. · y ₹..' → plan rows (· -separated, each has ₹)
    //   'About: …'             → routed to the 'About your specialist' section
    // Keep the same facts; only the delimiters drive rendering.
    preparationNotes:
        'Helps with: depression & bipolar, anxiety & OCD, schizophrenia & '
        'psychosis, de-addiction (incl. gaming), child psychiatry & IQ, '
        'dementia & elderly care, eating disorders, ADHD, grief, sleep '
        'issues, migraine.\n'
        'Therapy & assessment: CBT, DBT, grief, marital, family, '
        'occupational, IQ assessment.\n'
        'Also trained in rTMS & ECT — advanced, specialist-supervised care.\n'
        'Plans: initial consult ₹1,000 (15-min assessment) · therapy session '
        '₹1,500 (40 min) · monthly pack ₹9,500 (8 sessions).\n'
        'On call: 100% online · Mon–Fri · 6:00–8:00 PM.',
  ),
  // Content from the Clinical Dietetics SM creatives (2026-06): The Nourish
  // Programme (30/60/90-day) + the senior clinical dietitian on
  // call (complimentary with every Housepital package).
  ServiceItem(
    id: 'con-diet', name: 'Diet & Nutrition — The Nourish Programme',
    category: 'consultation', bookingType: 'scheduled',
    description:
        'Weight loss, diabetes & lifestyle care — one clinical nutrition '
        'plan, built bedside, reviewed every week.',
    basePriceMin: 3000, basePriceMax: 6000,
    durationMinutes: 45, leadTimeHours: 24, iconName: 'restaurant',
    // preparationNotes shape (parsed generically by the booking screen):
    //   'Plans: x ₹.. · y ₹..' → distinct plan rows (· -separated, each ₹)
    //   'Label: a, b, c'        → sub-label + soft chips (comma list)
    //   'About: …'              → 'About your specialist' section; a
    //                             'Trained at:' label there renders as
    //                             institution chips.
    preparationNotes:
        'Plans: 30-day quick reset ₹3,000 · 60-day (most popular) ₹4,500 · '
        '90-day best results ₹6,000.\n'
        'Every plan includes: daily WhatsApp support, a weekly plan, '
        'recipes.\n'
        'Specialities: oncology nutrition, diabetes & cardiac, '
        'post-surgical, renal & liver, gut healing, geriatric care.\n'
        'On call: a senior clinical dietitian is complimentary with every '
        'Housepital package.\n'
        // 'About:' lines render under a separate 'About your specialist'
        // section on the booking screen — never inside the notes blob.
        'About: Senior clinical dietitian, 12+ years in oncology, '
        'transplant & critical care.\n'
        'About: Credentials: M.Sc. Nutrition & Dietetics · double-certified '
        'cancer nutritionist · liver-transplant nutrition certified · IAPEN '
        'India Oncology Core Committee · published author.\n'
        'About: Trained at: Medanta, Sir HN Reliance, AIMS, Stanford, Duke, '
        'Univ. of Colorado.',
  ),
  ServiceItem(
    id: 'con-grief', name: 'Grief Counselling',
    category: 'consultation', bookingType: 'scheduled',
    description: 'Compassionate support for loss, bereavement & emotional recovery. In-person or video.',
    basePriceMin: 1200, durationMinutes: 60, leadTimeHours: 24, iconName: 'favorite',
  ),
  ServiceItem(
    id: 'th-sleep', name: 'Sleep Therapy',
    category: 'consultation', bookingType: 'instant',
    description: 'Certified sleep therapist visit — assessment, sleep hygiene counselling & personalised routine.',
    basePriceMin: 1500, durationMinutes: 60, leadTimeHours: 24, iconName: 'bedtime',
  ),
];

/// Visits (nursing procedures at home).
final List<ServiceItem> visitServices = [
  ServiceItem(
    id: 'visit-iv', name: 'IV Visit',
    category: 'visit', bookingType: 'scheduled',
    description: 'Tell us the type of IV procedure — we\'ll assign the right nurse level and bill accordingly.',
    basePriceMin: 900, basePriceMax: 1500, iconName: 'vaccines',
  ),
  ServiceItem(
    id: 'visit-im', name: 'IM Injection Visit',
    category: 'visit', bookingType: 'scheduled',
    description: 'Intramuscular injection visit — nurse administers prescribed IM medication at home.',
    basePriceMin: 500, basePriceMax: 500, durationMinutes: 30, iconName: 'medical_services',
  ),
  ServiceItem(
    id: 'visit-dressing-basic', name: 'Dressing Visit (Basic)',
    category: 'visit', bookingType: 'scheduled',
    description: 'Basic wound dressing — simple wounds, surgical site care, suture line dressing.',
    basePriceMin: 1200, basePriceMax: 1200, durationMinutes: 45, iconName: 'medical_services',
  ),
  ServiceItem(
    id: 'visit-dressing-adv', name: 'Dressing Visit (Advanced)',
    category: 'visit', bookingType: 'scheduled',
    description: 'Advanced dressing — complex wounds, drain site care, negative pressure wound care.',
    basePriceMin: 1500, basePriceMax: 1500, durationMinutes: 60, iconName: 'medical_services',
  ),
  ServiceItem(
    id: 'visit-dressing-crit', name: 'Dressing Visit (Critical)',
    category: 'visit', bookingType: 'scheduled',
    description: 'Critical dressing — deep wound debridement, extensive burn care, multi-site dressing.',
    basePriceMin: 2000, basePriceMax: 2000, durationMinutes: 90, iconName: 'medical_services',
  ),
  ServiceItem(
    id: 'visit-catheter', name: 'Catheter Change',
    category: 'visit', bookingType: 'scheduled',
    description: 'Urinary catheter insertion or change by trained nurse at home.',
    basePriceMin: 1200, basePriceMax: 1200, durationMinutes: 30, iconName: 'medical_services',
  ),
  ServiceItem(
    id: 'visit-rt-change', name: 'RT (Ryles Tube) Change',
    category: 'visit', bookingType: 'scheduled',
    description: 'Nasogastric / Ryles tube insertion or change by trained nurse.',
    basePriceMin: 1200, basePriceMax: 1200, durationMinutes: 30, iconName: 'medical_services',
  ),
  ServiceItem(
    id: 'visit-tracheostomy', name: 'Tracheostomy Change',
    category: 'visit', bookingType: 'scheduled',
    description: 'Tracheostomy tube change by experienced critical care nurse.',
    basePriceMin: 5000, basePriceMax: 5000, durationMinutes: 60, iconName: 'medical_services',
  ),
];

/// Icon mapping used by card widgets to resolve `ServiceItem.iconName`.
const catalogIconMap = <String, IconData>{
  'medical_services': Icons.medical_services,
  'restaurant': Icons.restaurant,
  'fitness_center': Icons.fitness_center,
  'bedtime': Icons.bedtime,
  'science': Icons.science,
  'person': Icons.person,
  'local_hospital': Icons.local_hospital,
  'monitor_heart': Icons.monitor_heart,
  'child_friendly': Icons.child_friendly,
  'child_care': Icons.child_care,
  'bed': Icons.bed,
  'air': Icons.air,
  'accessible': Icons.accessible,
  'inventory_2': Icons.inventory_2,
  'radiology': Icons.monitor_heart,
  'stethoscope': Icons.medical_information,
  'psychology': Icons.psychology,
  'favorite': Icons.favorite,
  'vaccines': Icons.vaccines,
  'healing': Icons.healing,
};
