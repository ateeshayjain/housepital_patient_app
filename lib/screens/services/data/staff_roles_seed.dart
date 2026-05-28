// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';

/// One level (Basic / Advanced / Critical / Standard) of a staff role's
/// scope of service — captures what IS and is NOT included.
class ServiceLevel {
  final String name;
  final List<String> included; // services included at this level
  final List<String> excluded; // services NOT included at this level

  const ServiceLevel({
    required this.name,
    required this.included,
    this.excluded = const [],
  });
}

/// A staff role surfaced in the Manpower tab (Caretaker, Nurse, Japa Maid,
/// Nanny, Physiotherapist).
class StaffRole {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<ServiceLevel> levels;
  final List<String> availableShifts;
  final double rating;
  final int reviewCount;

  const StaffRole({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.levels,
    required this.availableShifts,
    this.rating = 4.8,
    this.reviewCount = 120,
  });

  /// Flat list of all included responsibilities across all levels.
  List<String> get allResponsibilities {
    final set = <String>{};
    for (final level in levels) {
      set.addAll(level.included);
    }
    return set.toList();
  }
}

/// Canonical list of staff roles shown in the Manpower tab.
///
/// Sourced from HOUSEPITAL/DOC/01/00/01 (Nurse), HOUSEPITAL/DOC/02/00/01
/// (Caretaker) and the Scope of Services document for Japa & Nanny.
const staffRoles = <StaffRole>[
  // ── Caretaker (from HOUSEPITAL/DOC/02/00/01) ──────────────
  StaffRole(
    title: 'Caretaker',
    subtitle: 'Daily assistance & personal care',
    icon: Icons.person,
    availableShifts: ['12 Hours', '24 Hours'],
    rating: 4.8,
    reviewCount: 245,
    levels: [
      ServiceLevel(
        name: 'Basic',
        included: [
          'Oral care',
          'Toilet assistance',
          'Personal hygiene care (including sponging)',
          'Feeding',
          'Sanitary care',
          'Diaper changing & motion cleaning',
          'Muscle strengthening exercise',
          'Movement assistance',
          'Patient dressing & undressing',
          'Administration of oral medication',
          'Raw fruit & salad cutting for the patient',
        ],
        excluded: [
          'RT feeding',
          'Patient massage',
          'Sugar monitoring',
          'Insulin administration',
          'Blood pressure monitoring',
          'IV medication',
          'Tracheostomy care',
          'RT change',
          'Catheter care & change',
          'Suctioning',
          'Stitches care',
          'Bed sores care',
          'Ventilator care',
          'Household chores (brooming, mopping, cooking)',
        ],
      ),
      ServiceLevel(
        name: 'Advanced',
        included: [
          'All Basic services',
          'RT feeding',
          'Sugar monitoring',
          'Insulin administration',
          'Blood pressure monitoring',
        ],
        excluded: [
          'Patient massage',
          'IV medication',
          'Tracheostomy care',
          'RT change',
          'Catheter care & change',
          'Suctioning',
          'Stitches care',
          'Bed sores care',
          'Ventilator care',
          'Household chores (brooming, mopping, cooking)',
        ],
      ),
    ],
  ),
  // ── Nurse (from HOUSEPITAL/DOC/01/00/01) ───────────────────
  StaffRole(
    title: 'Nurse',
    subtitle: 'Medical care & clinical procedures',
    icon: Icons.medical_services,
    availableShifts: ['12 Hours', '24 Hours'],
    rating: 4.9,
    reviewCount: 189,
    levels: [
      ServiceLevel(
        name: 'Basic',
        included: [
          'Oral care',
          'Toilet assistance',
          'Personal hygiene care (including sponging)',
          'Feeding',
          'Muscle strengthening exercise',
          'Movement assistance',
          'Patient dressing & undressing',
          'Administration of oral medication',
          'Sugar monitoring',
          'Insulin administration',
          'Blood pressure monitoring',
          'Medication through IV & oral',
          'Catheter care & change',
        ],
        excluded: [
          'RT feeding',
          'Sanitary care',
          'Diaper changing & motion cleaning',
          'Patient massage',
          'Tracheostomy care',
          'RT change',
          'Suctioning',
          'Stitches care',
          'Bed sores care',
          'Ventilator care',
        ],
      ),
      ServiceLevel(
        name: 'Advanced',
        included: [
          'All Basic services',
          'RT feeding',
          'Sanitary care',
          'Tracheostomy care',
          'RT change',
          'Suctioning',
          'Stitches care',
          'Bed sores care',
        ],
        excluded: [
          'Diaper changing & motion cleaning',
          'Patient massage',
          'Ventilator care under FIO2 45%',
        ],
      ),
      ServiceLevel(
        name: 'Critical',
        included: [
          'All Advanced services',
          'Personal hygiene care',
          'Diaper changing & motion cleaning',
          'Ventilator care under FIO2 45%',
        ],
        excluded: [
          'Toilet assistance',
          'Patient massage',
          'Household chores',
        ],
      ),
    ],
  ),
  // ── Japa Maid (from HOUSEPITAL Scope of Services – Nanny & Japa, 0-7 months) ──
  StaffRole(
    title: 'Japa Maid',
    subtitle: 'Post-delivery mother & newborn care (0–7 months)',
    icon: Icons.child_friendly,
    availableShifts: ['12 Hours', '24 Hours'],
    rating: 4.7,
    reviewCount: 156,
    levels: [
      ServiceLevel(
        name: 'Standard',
        included: [
          // Feeding
          'Feeding baby at regular intervals (breastfeeding / formula)',
          'Helping mothers in lactation or breast feeding',
          'Feeding the baby (solid food)',
          'Prepare basic food for mother – daal, daliya, khichadi',
          // Grooming & hygiene
          'Taking care of umbilical cord',
          'Massaging and skin care of baby',
          'Massage for the mother',
          'Bathing, sponging and grooming – Baby',
          'Changing diapers – Baby',
          // Health safety
          'Administering medicine with parents\' consent – Baby',
          'Monitoring the baby\'s health',
          'Holding and soothing the baby',
          'Putting the child to sleep',
          // Household chores & sterilization
          'Cleaning and sterilization of baby items, toys',
          'Organising child\'s room, folding clothes, cleaning & cooking for the child',
          // Education & development
          'Engaging the child in playing activities',
          'Supervising & monitoring the safety of children',
        ],
        excluded: [
          'Toilet training – Baby',
          'Planning development activities (reading, arts & crafts)',
          'Educating the baby',
          'Dropping & picking children from/to school, parks, appointments',
        ],
      ),
    ],
  ),
  // ── Nanny (from HOUSEPITAL Scope of Services – Nanny & Japa, 7 months–5 years) ──
  StaffRole(
    title: 'Nanny',
    subtitle: 'Infant & toddler care (7 months – 5 years)',
    icon: Icons.child_care,
    availableShifts: ['12 Hours', '24 Hours'],
    rating: 4.8,
    reviewCount: 134,
    levels: [
      ServiceLevel(
        name: 'Standard',
        included: [
          // Feeding
          'Feeding the baby (solid food)',
          // Grooming & hygiene
          'Massaging and skin care of baby',
          'Bathing, sponging and grooming – Baby',
          'Changing diapers – Baby',
          'Toilet training – Baby',
          // Health safety
          'Administering medicine with parents\' consent – Baby',
          'Monitoring the baby\'s health',
          'Holding and soothing the baby',
          'Putting the child to sleep',
          // Household chores & sterilization
          'Cleaning and sterilization of baby items, toys',
          'Organising child\'s room, folding clothes, cleaning & cooking for the child',
          // Education & development
          'Planning development activities (reading, arts & crafts)',
          'Educating the baby',
          'Engaging the child in playing activities',
          'Supervising & monitoring the safety of children',
          'Dropping & picking children from/to school, parks, appointments',
        ],
        excluded: [
          'Feeding baby at regular intervals (breastfeeding / formula)',
          'Helping mothers in lactation or breast feeding',
          'Prepare basic food for mother – daal, daliya, khichadi',
          'Taking care of umbilical cord',
          'Massage for the mother',
        ],
      ),
    ],
  ),
  // ── Physiotherapist ────────────────────────────────────────
  StaffRole(
    title: 'Physiotherapist',
    subtitle: 'Rehab, mobility & pain management',
    icon: Icons.fitness_center,
    availableShifts: ['Per Visit (45 min)'],
    rating: 4.9,
    reviewCount: 98,
    levels: [
      ServiceLevel(
        name: 'Standard',
        included: [
          'Post-surgery rehabilitation exercises',
          'Joint mobility & strengthening',
          'Pain management techniques',
          'Balance & gait training',
          'Chest physiotherapy',
          'Personalised exercise plan',
        ],
      ),
    ],
  ),
];
