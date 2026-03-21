import '../models/models.dart';

/// Official HPL Care Packages and condition-based bundles.
/// Per-day packages from HPL Tariff Annexure + condition-based kits.
const List<CarePackage> carePackages = [
  // ═════════════════════════════════════════════
  // OFFICIAL HPL DAILY CARE PACKAGES
  // ═════════════════════════════════════════════

  // ─────────────────────────────────────────────
  // 1. Critical Care Package — ₹15,000/day (all-inclusive)
  // ─────────────────────────────────────────────
  CarePackage(
    id: 'pkg_critical',
    name: 'Critical Care Package',
    condition: 'ICU-at-Home',
    icon: 'local_hospital',
    description:
        'Hospital-grade critical care at home. Includes 24-hour nursing, 24-hour caretaker, ventilator/BiPAP, centralised vital monitoring, doctor visits, physiotherapy, and ACLS ambulance on call.',
    discountPercent: 15,
    pricePerDay: 15000,
    minDays: 5,
    highlights: [
      '24-hour Nursing + 24-hour Caretaker',
      'Oxygen concentrators (up to 2) + ventilator/BiPAP',
      'Centralised vital monitoring',
      'Weekly doctor visits + 10 tele-consults (first 2 weeks)',
      'ACLS ambulance on call (20 km)',
      'Physiotherapy every 5 days',
      'Diet plan and consultation included',
    ],
    items: [
      // Equipment Support
      PackageItem(equipmentId: 161, name: 'Oxygen Concentrator 10L', isRental: true, rentalMonths: 1, quantity: 2),
      PackageItem(equipmentId: 239, name: 'Ventilator / BiPAP', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 109, name: 'Hospital Bed Electric', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 7, name: 'Air Mattress', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 210, name: 'Suction Machine', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 74, name: 'DVT Pump', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 110, name: '5 Para Monitor', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 30, name: 'BiPAP Connector', isRental: true, rentalMonths: 1),
      // Complimentary items
      PackageItem(equipmentId: 247, name: 'Wheelchair', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 47, name: 'BP Machine'),
      PackageItem(equipmentId: 200, name: 'Stethoscope'),
      PackageItem(equipmentId: 177, name: 'Pulse Oximeter'),
      PackageItem(equipmentId: 127, name: 'IV Stand', isRental: true, rentalMonths: 1),
    ],
    services: [
      PackageService(name: '24-Hour Nursing', type: 'nurse', shift: '24hr', durationDays: 30, pricePerDay: 3000),
      PackageService(name: '24-Hour Caretaker', type: 'caretaker', shift: '24hr', durationDays: 30, pricePerDay: 1500),
      PackageService(name: 'Doctor Visit (weekly)', type: 'doctor', shift: '12hr_day', durationDays: 4, pricePerDay: 3500),
      PackageService(name: 'Physiotherapy (every 5 days)', type: 'physiotherapist', shift: '12hr_day', durationDays: 6, pricePerDay: 1200),
    ],
  ),

  // ─────────────────────────────────────────────
  // 2. Advance Care Package — ₹11,000/day
  // ─────────────────────────────────────────────
  CarePackage(
    id: 'pkg_advance',
    name: 'Advance Care Package',
    condition: 'Advanced Home Care',
    icon: 'medical_services',
    description:
        'Advanced home care with 24-hour nursing, 24-hour caretaker, oxygen concentrator, non-centralised vital monitoring, doctor visits, physiotherapy, and ACLS ambulance on call.',
    discountPercent: 12,
    pricePerDay: 11000,
    minDays: 5,
    highlights: [
      '24-hour Nursing + 24-hour Caretaker',
      'Oxygen concentrator (up to 1) with transformer',
      'Non-centralised vital monitoring',
      '5 tele-consults + 2 doctor visits (first 2 weeks)',
      'ACLS ambulance on call (15 km)',
      'Physiotherapy every 5 days',
    ],
    items: [
      PackageItem(equipmentId: 161, name: 'Oxygen Concentrator 10L', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 109, name: 'Hospital Bed Electric', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 7, name: 'Air Mattress', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 210, name: 'Suction Machine', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 74, name: 'DVT Pump', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 110, name: '5 Para Monitor', isRental: true, rentalMonths: 1),
      // Complimentary items
      PackageItem(equipmentId: 247, name: 'Wheelchair', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 47, name: 'BP Machine'),
      PackageItem(equipmentId: 200, name: 'Stethoscope'),
      PackageItem(equipmentId: 177, name: 'Pulse Oximeter'),
      PackageItem(equipmentId: 127, name: 'IV Stand', isRental: true, rentalMonths: 1),
    ],
    services: [
      PackageService(name: '24-Hour Nursing', type: 'nurse', shift: '24hr', durationDays: 30, pricePerDay: 2500),
      PackageService(name: '24-Hour Caretaker', type: 'caretaker', shift: '24hr', durationDays: 30, pricePerDay: 1300),
      PackageService(name: 'Doctor Visit (first 2 weeks)', type: 'doctor', shift: '12hr_day', durationDays: 2, pricePerDay: 3500),
      PackageService(name: 'Physiotherapy (every 5 days)', type: 'physiotherapist', shift: '12hr_day', durationDays: 6, pricePerDay: 1200),
    ],
  ),

  // ─────────────────────────────────────────────
  // 3. Basic Care Package — ₹4,000/day
  // ─────────────────────────────────────────────
  CarePackage(
    id: 'pkg_basic',
    name: 'Basic Care Package',
    condition: 'Home Recovery',
    icon: 'home',
    description:
        'Essential home care with 24-hour nursing, 24-hour caretaker, oxygen support, hospital bed, doctor visits, and physiotherapy. Ideal for stable patients recovering at home.',
    discountPercent: 10,
    pricePerDay: 4000,
    minDays: 7,
    highlights: [
      '24-hour Nursing + 24-hour Caretaker',
      'Oxygen concentrator or cylinder (up to 1)',
      'Non-centralised vital monitoring',
      '2 tele-consults + 1 doctor visit (first 2 weeks)',
      'Hospital bed with compressible mattress',
      'Physiotherapy every 5 days',
    ],
    items: [
      PackageItem(equipmentId: 166, name: 'Oxygen Concentrator 5L', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 109, name: 'Hospital Bed Electric', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 7, name: 'Air Mattress', isRental: true, rentalMonths: 1),
      // Complimentary items
      PackageItem(equipmentId: 200, name: 'Stethoscope'),
      PackageItem(equipmentId: 247, name: 'Wheelchair', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 177, name: 'Pulse Oximeter'),
      PackageItem(equipmentId: 127, name: 'IV Stand', isRental: true, rentalMonths: 1),
    ],
    services: [
      PackageService(name: '24-Hour Nursing', type: 'nurse', shift: '24hr', durationDays: 30, pricePerDay: 2200),
      PackageService(name: '24-Hour Caretaker', type: 'caretaker', shift: '24hr', durationDays: 30, pricePerDay: 1100),
      PackageService(name: 'Doctor Visit (first 2 weeks)', type: 'doctor', shift: '12hr_day', durationDays: 1, pricePerDay: 3500),
      PackageService(name: 'Physiotherapy (every 5 days)', type: 'physiotherapist', shift: '12hr_day', durationDays: 6, pricePerDay: 900),
    ],
  ),

  // ═════════════════════════════════════════════
  // CONDITION-BASED PACKAGES
  // ═════════════════════════════════════════════

  // ─────────────────────────────────────────────
  // 4. Post TKR / THR (Total Knee/Hip Replacement)
  // ─────────────────────────────────────────────
  CarePackage(
    id: 'pkg_tkr_thr',
    name: 'Post Joint Replacement Kit',
    condition: 'Post TKR / THR',
    icon: 'healing',
    description:
        'Complete recovery kit for patients after total knee or hip replacement surgery. Includes mobility aids, DVT prevention, and physiotherapy support.',
    discountPercent: 12,
    highlights: [
      'Everything needed for 30-day recovery',
      'Physiotherapy included (Basic tier)',
      'DVT prevention equipment',
      'Saves vs buying separately',
    ],
    items: [
      PackageItem(equipmentId: 131, name: 'Knee Immobilizer', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 74, name: 'DVT Pump', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 241, name: 'Walker', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 62, name: 'Commode Chair', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 68, name: 'Crepe Bandage', quantity: 4),
      PackageItem(equipmentId: 3, name: 'Abduction Pillow', isRental: true, rentalMonths: 1),
    ],
    services: [
      PackageService(name: 'Physiotherapy (Basic)', type: 'physiotherapist', shift: '12hr_day', durationDays: 30, pricePerDay: 900),
      PackageService(name: 'Nurse (Basic, 12-hr)', type: 'nurse', shift: '12hr_day', durationDays: 14, pricePerDay: 1600),
    ],
  ),

  // ─────────────────────────────────────────────
  // 5. Sleep Apnea Care
  // ─────────────────────────────────────────────
  CarePackage(
    id: 'pkg_sleep_apnea',
    name: 'Sleep Apnea Care Kit',
    condition: 'Sleep Apnea',
    icon: 'bedtime',
    description:
        'Comprehensive sleep therapy package with CPAP/BiPAP machines, masks, and monitoring. Includes setup assistance and doctor consultation.',
    discountPercent: 10,
    highlights: [
      'CPAP machine with mask fitting',
      'Pulse oximeter for overnight monitoring',
      'Replacement tubing and filters included',
      'Doctor consultation for titration',
    ],
    items: [
      PackageItem(equipmentId: 21, name: 'CPAP Machine', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 177, name: 'Pulse Oximeter'),
      PackageItem(equipmentId: 124, name: 'Humidifier', isRental: true, rentalMonths: 1),
    ],
    services: [
      PackageService(name: 'Doctor Consultation (Sleep Study)', type: 'doctor', shift: '12hr_day', durationDays: 1, pricePerDay: 3500),
    ],
  ),

  // ─────────────────────────────────────────────
  // 6. Baby & Mother Care
  // ─────────────────────────────────────────────
  CarePackage(
    id: 'pkg_baby_care',
    name: 'New Baby & Mother Care Kit',
    condition: 'Baby Care',
    icon: 'child_care',
    description:
        'Essential care package for newborns and new mothers. Includes health monitoring equipment and a trained Japa Maid for post-delivery care.',
    discountPercent: 10,
    highlights: [
      'Trained Japa Maid (24-hr, 30 days)',
      'Baby health monitoring essentials',
      'Nebulizer for infant respiratory care',
      'Breastfeeding support & mother care',
    ],
    items: [
      PackageItem(equipmentId: 153, name: 'Nebulizer'),
      PackageItem(equipmentId: 124, name: 'Humidifier', isRental: true, rentalMonths: 1),
    ],
    services: [
      PackageService(name: 'Japa Maid (24-hr)', type: 'japa_maid', shift: '24hr', durationDays: 30, pricePerDay: 1500),
    ],
  ),

  // ─────────────────────────────────────────────
  // 7. Neuro Patient Care
  // ─────────────────────────────────────────────
  CarePackage(
    id: 'pkg_neuro',
    name: 'Neuro Patient Care Kit',
    condition: 'Neuro Patients',
    icon: 'psychology',
    description:
        'Specialized care for stroke, paralysis, and neurological conditions. Hospital bed, mobility aids, suction machine, and full-time caretaker.',
    discountPercent: 15,
    highlights: [
      'Electric hospital bed with air mattress',
      'Full-time trained caretaker (24-hr)',
      'Wheelchair and mobility support',
      'Suction machine for airway management',
      'Biggest savings — 15% off',
    ],
    items: [
      PackageItem(equipmentId: 109, name: 'Electric Hospital Bed', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 7, name: 'Air Mattress', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 4, name: 'Bed Railing', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 247, name: 'Wheelchair', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 210, name: 'Suction Machine', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 177, name: 'Pulse Oximeter'),
      PackageItem(equipmentId: 47, name: 'BP Monitor'),
    ],
    services: [
      PackageService(name: 'Caretaker (Advanced, 24-hr)', type: 'caretaker', shift: '24hr', durationDays: 30, pricePerDay: 1300),
      PackageService(name: 'Physiotherapy (Advanced)', type: 'physiotherapist', shift: '12hr_day', durationDays: 30, pricePerDay: 1200),
    ],
  ),

  // ─────────────────────────────────────────────
  // 8. Geriatric / Elder Care
  // ─────────────────────────────────────────────
  CarePackage(
    id: 'pkg_geriatric',
    name: 'Elder Care Essentials Kit',
    condition: 'Geriatric Patients',
    icon: 'elderly',
    description:
        'Comprehensive home care for elderly patients. Hospital bed, mobility aids, daily monitoring, and full-time caretaker for daily activities.',
    discountPercent: 12,
    highlights: [
      'Hospital bed with air mattress',
      'Full-time caretaker (24-hr)',
      'Daily vitals monitoring (BP, Sugar, SpO2)',
      'Mobility aids — walker and wheelchair',
    ],
    items: [
      PackageItem(equipmentId: 49, name: 'Hospital Bed (Manual)', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 8, name: 'Air Mattress', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 241, name: 'Walker', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 247, name: 'Wheelchair', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 62, name: 'Commode Chair', isRental: true, rentalMonths: 1),
      PackageItem(equipmentId: 47, name: 'BP Monitor'),
      PackageItem(equipmentId: 120, name: 'Glucometer'),
      PackageItem(equipmentId: 177, name: 'Pulse Oximeter'),
      PackageItem(equipmentId: 235, name: 'Bed Pan'),
    ],
    services: [
      PackageService(name: 'Caretaker (Basic, 24-hr)', type: 'caretaker', shift: '24hr', durationDays: 30, pricePerDay: 1100),
    ],
  ),
];
