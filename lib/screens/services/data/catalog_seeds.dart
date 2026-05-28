// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../models/models.dart';

/// Manpower service catalog (nurses, caretakers, japa, nanny, physio).
///
/// audit M-1 (extension): basePriceMin REMOVED from ALL manpower seeds
/// including nurses. User memory rule covers "caretaker, nursing, japa,
/// nanny" — original M-1 fix only stripped caretaker/japa/nanny; nurse
/// seeds had basePriceMin retained but the category guard was hiding it
/// in UI. Now the data layer matches the UI rule.
final List<ServiceItem> manpowerServices = [
  // ── Nursing Staff ──
  ServiceItem(
    id: 'mp-nurse-basic-12', name: 'Nurse (Basic) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Basic nursing care — vitals monitoring, oral medication, feeding & personal hygiene assistance.',
    durationMinutes: 720, iconName: 'medical_services',
  ),
  ServiceItem(
    id: 'mp-nurse-basic-24', name: 'Nurse (Basic) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock basic nursing for patients needing continuous monitoring and care.',
    durationMinutes: 1440, iconName: 'medical_services',
  ),
  ServiceItem(
    id: 'mp-nurse-adv-12', name: 'Nurse (Advanced) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Advanced nursing — IV/IM medication, catheter care, RT feeding, sugar & BP monitoring.',
    durationMinutes: 720, iconName: 'medical_services',
  ),
  ServiceItem(
    id: 'mp-nurse-adv-24', name: 'Nurse (Advanced) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock advanced nursing for patients needing clinical-grade care at home.',
    durationMinutes: 1440, iconName: 'medical_services',
  ),
  // ── Critical Nurse — ICU setup, assessment required ──
  ServiceItem(
    id: 'mp-nurse-crit-12', name: 'Nurse (Critical) – 12 Hours',
    category: 'manpower', bookingType: 'assessment',
    description: 'Critical care nursing — tracheostomy care, ventilator management, suctioning, bed sore care.',
    iconName: 'medical_services',
  ),
  ServiceItem(
    id: 'mp-nurse-crit-24', name: 'Nurse (Critical) – 24 Hours',
    category: 'manpower', bookingType: 'assessment',
    description: 'Round-the-clock critical care nursing for ICU-like home setups and ventilator patients.',
    iconName: 'medical_services',
  ),
  // ── Care-takers ──
  // audit M-1: basePriceMin REMOVED for caretaker/japa/nanny — manpower
  // pricing is "Price on assessment" only (user persistent memory rule:
  // never show prices for caretaker, nursing, japa, nanny services).
  ServiceItem(
    id: 'mp-caretaker-basic-12', name: 'Caretaker (Basic) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Basic caretaker — bathing, mobility assistance, feeding, companionship & medication reminders.',
    durationMinutes: 720, iconName: 'person',
  ),
  ServiceItem(
    id: 'mp-caretaker-basic-24', name: 'Caretaker (Basic) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock basic caretaker for daily living assistance and companionship.',
    durationMinutes: 1440, iconName: 'person',
  ),
  ServiceItem(
    id: 'mp-caretaker-adv-12', name: 'Caretaker (Advanced) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Advanced caretaker with IM injection & BP monitoring skills for patients needing medical support.',
    durationMinutes: 720, iconName: 'person',
  ),
  ServiceItem(
    id: 'mp-caretaker-adv-24', name: 'Caretaker (Advanced) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock advanced caretaker with medical assistance capabilities.',
    durationMinutes: 1440, iconName: 'person',
  ),
  ServiceItem(
    id: 'mp-caretaker-crit-12', name: 'Caretaker (Critical / Semi-Nurse) – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Semi-nurse level caretaker for complex care needs — RT feeding, suctioning assistance.',
    durationMinutes: 720, iconName: 'person',
  ),
  ServiceItem(
    id: 'mp-caretaker-crit-24', name: 'Caretaker (Critical / Semi-Nurse) – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Round-the-clock semi-nurse caretaker for patients needing intensive daily care.',
    durationMinutes: 1440, iconName: 'person',
  ),
  // ── Japa Maid ──
  // audit M-1: basePriceMin REMOVED — assessment-only pricing.
  ServiceItem(
    id: 'mp-japa-24', name: 'Japa Maid – 24 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Post-delivery care for mother & newborn (0-7 months) — breastfeeding support, baby massage, bathing, umbilical cord care & mother\'s diet preparation.',
    durationMinutes: 1440, iconName: 'child_friendly',
  ),
  // ── Nanny ──
  // audit M-1: basePriceMin REMOVED — assessment-only pricing.
  ServiceItem(
    id: 'mp-nanny-12', name: 'Nanny – 12 Hours',
    category: 'manpower', bookingType: 'scheduled',
    description: 'Professional nanny for infants & toddlers (7 months–5 years) — feeding, sleep routine, developmental activities, hygiene & safety supervision.',
    durationMinutes: 720, iconName: 'child_care',
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
    id: 'dx-holter', name: 'Holter Monitoring',
    category: 'diagnostics', bookingType: 'instant',
    description: '24-hour Holter monitor fitted at home. Technician visits for setup & removal. Report in 48 hours.',
    basePriceMin: 2500, durationMinutes: 45, leadTimeHours: 12, iconName: 'monitor_heart',
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
  ServiceItem(
    id: 'con-psychiatrist', name: 'Psychiatrist Consultation',
    category: 'consultation', bookingType: 'scheduled',
    description: 'Licensed psychiatrist for mental health assessment, medication management & therapy referrals.',
    basePriceMin: 1500, durationMinutes: 45, leadTimeHours: 24, iconName: 'psychology',
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
