// test/screens/services/service_catalog_test.dart
//
// Tests data integrity of the Housepital service catalog.
// Since the catalog is defined as static fields inside a private State class,
// we replicate the canonical data here and verify invariants.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

// ---------------------------------------------------------------------------
// Canonical catalog data — must mirror service_catalog_screen.dart exactly.
// If the source changes, update this list and re-run tests.
// ---------------------------------------------------------------------------

final List<ServiceItem> _physioServices = [
  ServiceItem(
    id: 'mp-physio',
    name: 'Physiotherapy',
    category: 'manpower',
    bookingType: 'instant',
    basePriceMin: 800,
    durationMinutes: 45,
    iconName: 'fitness_center',
  ),
];

final List<ServiceItem> _manpowerServices = [
  ServiceItem(id: 'mp-nurse-basic-12', name: 'Nurse (Basic) – 12 Hours', category: 'manpower', bookingType: 'scheduled', basePriceMin: 900),
  ServiceItem(id: 'mp-nurse-basic-24', name: 'Nurse (Basic) – 24 Hours', category: 'manpower', bookingType: 'scheduled', basePriceMin: 1200),
  ServiceItem(id: 'mp-nurse-adv-12', name: 'Nurse (Advanced) – 12 Hours', category: 'manpower', bookingType: 'scheduled', basePriceMin: 1200),
  ServiceItem(id: 'mp-nurse-adv-24', name: 'Nurse (Advanced) – 24 Hours', category: 'manpower', bookingType: 'scheduled', basePriceMin: 1500),
  ServiceItem(id: 'mp-nurse-crit-12', name: 'Nurse (Critical) – 12 Hours', category: 'manpower', bookingType: 'assessment'),
  ServiceItem(id: 'mp-nurse-crit-24', name: 'Nurse (Critical) – 24 Hours', category: 'manpower', bookingType: 'assessment'),
  ServiceItem(id: 'mp-caretaker-basic-12', name: 'Caretaker (Basic) – 12 Hours', category: 'manpower', bookingType: 'scheduled', basePriceMin: 600),
  ServiceItem(id: 'mp-caretaker-basic-24', name: 'Caretaker (Basic) – 24 Hours', category: 'manpower', bookingType: 'scheduled', basePriceMin: 800),
  ServiceItem(id: 'mp-caretaker-adv-12', name: 'Caretaker (Advanced) – 12 Hours', category: 'manpower', bookingType: 'scheduled', basePriceMin: 800),
  ServiceItem(id: 'mp-caretaker-adv-24', name: 'Caretaker (Advanced) – 24 Hours', category: 'manpower', bookingType: 'scheduled', basePriceMin: 1000),
  ServiceItem(id: 'mp-caretaker-crit-12', name: 'Caretaker (Critical / Semi-Nurse) – 12 Hours', category: 'manpower', bookingType: 'scheduled', basePriceMin: 1000),
  ServiceItem(id: 'mp-caretaker-crit-24', name: 'Caretaker (Critical / Semi-Nurse) – 24 Hours', category: 'manpower', bookingType: 'scheduled', basePriceMin: 1200),
  ServiceItem(id: 'mp-physio-basic', name: 'Physiotherapy (Basic)', category: 'manpower', bookingType: 'scheduled', basePriceMin: 900),
  ServiceItem(id: 'mp-physio-advance', name: 'Physiotherapy (Advanced)', category: 'manpower', bookingType: 'scheduled', basePriceMin: 1200),
  ServiceItem(id: 'mp-physio-critical', name: 'Physiotherapy (Critical)', category: 'manpower', bookingType: 'scheduled', basePriceMin: 1500),
];

final List<ServiceItem> _equipmentServices = [
  ServiceItem(id: 'eq-hospital-bed', name: 'Hospital Bed', category: 'equipment', bookingType: 'instant', basePriceMin: 2500),
  ServiceItem(id: 'eq-oxygen-concentrator', name: 'Oxygen Concentrator', category: 'equipment', bookingType: 'instant', basePriceMin: 3000),
  ServiceItem(id: 'eq-wheelchair', name: 'Wheelchair', category: 'equipment', bookingType: 'instant', basePriceMin: 4500),
  ServiceItem(id: 'eq-bp-monitor', name: 'BP Monitor', category: 'equipment', bookingType: 'instant', basePriceMin: 1200),
  ServiceItem(id: 'eq-consumables', name: 'Medical Consumables', category: 'equipment', bookingType: 'instant', basePriceMin: 500),
];

final List<ServiceItem> _diagnosticServices = [
  ServiceItem(id: 'dx-ecg', name: 'ECG at Home', category: 'diagnostics', bookingType: 'instant', basePriceMin: 500),
  ServiceItem(id: 'dx-xray', name: 'X-Ray at Home', category: 'diagnostics', bookingType: 'instant', basePriceMin: 800),
  ServiceItem(id: 'dx-holter', name: 'Holter Monitoring — 24 Hours', category: 'diagnostics', bookingType: 'instant', basePriceMin: 2500),
  // At-home cardiac & sleep diagnostics (prices are ESTIMATES — replace with
  // confirmed vendor rates).
  ServiceItem(id: 'dx-holter-48', name: 'Holter Monitoring — 48 Hours', category: 'diagnostics', bookingType: 'instant', basePriceMin: 3500),
  ServiceItem(id: 'dx-holter-72', name: 'Holter Monitoring — 72 Hours', category: 'diagnostics', bookingType: 'instant', basePriceMin: 4500),
  ServiceItem(id: 'dx-abpm-24', name: 'ABPM (Ambulatory BP Monitoring) — 24 Hours', category: 'diagnostics', bookingType: 'instant', basePriceMin: 2500),
  ServiceItem(id: 'dx-elr', name: 'Event Loop Recorder (ELR)', category: 'diagnostics', bookingType: 'instant', basePriceMin: 8000),
  ServiceItem(id: 'dx-sleep-study', name: 'Home Sleep Study (Level III)', category: 'diagnostics', bookingType: 'instant', basePriceMin: 6000),
];

final List<ServiceItem> _labServices = [
  ServiceItem(id: 'lab-fever', name: 'Fever Panel', category: 'lab', bookingType: 'instant', basePriceMin: 4999, basePriceMax: 4999),
  ServiceItem(id: 'lab-wellness', name: 'Wellness Package', category: 'lab', bookingType: 'instant', basePriceMin: 7599, basePriceMax: 7599),
  ServiceItem(id: 'lab-immunity', name: 'Immunity Package', category: 'lab', bookingType: 'instant', basePriceMin: 4599, basePriceMax: 4599),
  ServiceItem(id: 'lab-bone', name: 'Bone Package', category: 'lab', bookingType: 'instant', basePriceMin: 2999, basePriceMax: 2999),
  ServiceItem(id: 'lab-metabolic', name: 'Metabolic Package', category: 'lab', bookingType: 'instant', basePriceMin: 1799, basePriceMax: 1799),
  ServiceItem(id: 'lab-adolescent', name: 'Adolescent Package', category: 'lab', bookingType: 'instant', basePriceMin: 2499, basePriceMax: 2499),
  ServiceItem(id: 'lab-anemia', name: 'Anemia Package', category: 'lab', bookingType: 'instant', basePriceMin: 4599, basePriceMax: 4599),
  ServiceItem(id: 'dx-sample-5km', name: 'Blood Sample Collection (0-5 km)', category: 'lab', bookingType: 'instant', basePriceMin: 150, basePriceMax: 150),
  ServiceItem(id: 'dx-sample-10km', name: 'Blood Sample Collection (5-10 km)', category: 'lab', bookingType: 'instant', basePriceMin: 200, basePriceMax: 200),
  ServiceItem(id: 'dx-sample-15km', name: 'Blood Sample Collection (10-15 km)', category: 'lab', bookingType: 'instant', basePriceMin: 250, basePriceMax: 250),
];

final List<ServiceItem> _therapyServices = [
  ServiceItem(id: 'th-sleep-legacy', name: 'Sleep Therapy', category: 'therapy', bookingType: 'instant', basePriceMin: 1500),
];

final List<ServiceItem> _consultationServices = [
  ServiceItem(id: 'con-doctor', name: 'Doctor Visit', category: 'consultation', bookingType: 'scheduled', basePriceMin: 3500, basePriceMax: 5000),
  ServiceItem(id: 'con-psychiatrist', name: 'Psychiatrist Consultation', category: 'consultation', bookingType: 'scheduled', basePriceMin: 1500),
  ServiceItem(id: 'con-grief', name: 'Grief Counselling', category: 'consultation', bookingType: 'scheduled', basePriceMin: 1200),
  ServiceItem(id: 'th-sleep', name: 'Sleep Therapy', category: 'consultation', bookingType: 'instant', basePriceMin: 1500),
];

final List<ServiceItem> _visitServices = [
  ServiceItem(id: 'visit-iv', name: 'IV Visit', category: 'visit', bookingType: 'scheduled', basePriceMin: 900, basePriceMax: 1500),
  ServiceItem(id: 'visit-im', name: 'IM Injection Visit', category: 'visit', bookingType: 'scheduled', basePriceMin: 500, basePriceMax: 500),
  ServiceItem(id: 'visit-dressing-basic', name: 'Dressing Visit (Basic)', category: 'visit', bookingType: 'scheduled', basePriceMin: 1200, basePriceMax: 1200),
  ServiceItem(id: 'visit-dressing-adv', name: 'Dressing Visit (Advanced)', category: 'visit', bookingType: 'scheduled', basePriceMin: 1500, basePriceMax: 1500),
  ServiceItem(id: 'visit-dressing-crit', name: 'Dressing Visit (Critical)', category: 'visit', bookingType: 'scheduled', basePriceMin: 2000, basePriceMax: 2000),
  ServiceItem(id: 'visit-catheter', name: 'Catheter Change', category: 'visit', bookingType: 'scheduled', basePriceMin: 1200, basePriceMax: 1200),
  ServiceItem(id: 'visit-rt-change', name: 'RT (Ryles Tube) Change', category: 'visit', bookingType: 'scheduled', basePriceMin: 1200, basePriceMax: 1200),
  ServiceItem(id: 'visit-tracheostomy', name: 'Tracheostomy Change', category: 'visit', bookingType: 'scheduled', basePriceMin: 5000, basePriceMax: 5000),
];

/// All services combined — the full catalog.
final List<ServiceItem> _allServices = [
  ..._physioServices,
  ..._manpowerServices,
  ..._equipmentServices,
  ..._diagnosticServices,
  ..._labServices,
  ..._therapyServices,
  ..._consultationServices,
  ..._visitServices,
];

const _validBookingTypes = {'instant', 'scheduled', 'assessment'};
const _validCategories = {
  'manpower',
  'equipment',
  'diagnostics',
  'lab',
  'therapy',
  'consultation',
  'visit',
};

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Unique IDs
  // =========================================================================
  group('Service catalog — unique IDs', () {
    test('all ServiceItem entries have unique IDs', () {
      final ids = _allServices.map((s) => s.id).toList();
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, ids.length,
          reason: 'Duplicate IDs found: ${ids.where((id) => ids.indexOf(id) != ids.lastIndexOf(id)).toSet()}');
    });
  });

  // =========================================================================
  // Valid bookingType
  // =========================================================================
  group('Service catalog — valid bookingType', () {
    for (final svc in _allServices) {
      test('${svc.id} has valid bookingType "${svc.bookingType}"', () {
        expect(_validBookingTypes, contains(svc.bookingType));
      });
    }
  });

  // =========================================================================
  // Valid category
  // =========================================================================
  group('Service catalog — valid category', () {
    for (final svc in _allServices) {
      test('${svc.id} has valid category "${svc.category}"', () {
        expect(_validCategories, contains(svc.category));
      });
    }
  });

  // =========================================================================
  // Manpower pricing: all show prices except ICU/critical nurse (assessment)
  // =========================================================================
  group('Service catalog — manpower pricing', () {
    // Non-ICU manpower services should have prices (direct purchase)
    final pricedManpowerIds = {
      'mp-nurse-basic-12', 'mp-nurse-basic-24',
      'mp-nurse-adv-12', 'mp-nurse-adv-24',
      'mp-caretaker-basic-12', 'mp-caretaker-basic-24',
      'mp-caretaker-adv-12', 'mp-caretaker-adv-24',
      'mp-caretaker-crit-12', 'mp-caretaker-crit-24',
      'mp-physio-basic', 'mp-physio-advance', 'mp-physio-critical',
    };

    for (final svc in _allServices.where((s) => pricedManpowerIds.contains(s.id))) {
      test('${svc.id} (${svc.name}) has a price', () {
        expect(svc.basePriceMin, isNotNull,
            reason: 'Non-ICU manpower services should show prices');
        expect(svc.bookingType, 'scheduled',
            reason: 'Non-ICU manpower services should be directly bookable');
      });
    }

    // ICU/critical nurse stays assessment-only (no price, needs assessment)
    final icuAssessmentIds = {'mp-nurse-crit-12', 'mp-nurse-crit-24'};
    for (final svc in _allServices.where((s) => icuAssessmentIds.contains(s.id))) {
      test('${svc.id} (${svc.name}) is assessment-only (ICU setup)', () {
        expect(svc.basePriceMin, isNull,
            reason: 'ICU nurse services require assessment');
        expect(svc.bookingType, 'assessment');
      });
    }
  });

  // =========================================================================
  // Doctor Visit consolidation
  // =========================================================================
  group('Service catalog — Doctor Visit', () {
    test('Doctor Visit is consolidated as "con-doctor"', () {
      final doctorServices = _allServices.where((s) => s.id == 'con-doctor').toList();
      expect(doctorServices.length, 1);
      expect(doctorServices.first.name, 'Doctor Visit');
    });

    test('con-doctor has bookingType "scheduled"', () {
      final doctor = _allServices.firstWhere((s) => s.id == 'con-doctor');
      expect(doctor.bookingType, 'scheduled');
    });
  });

  // =========================================================================
  // IV Visit and IM Visit are separate entries
  // =========================================================================
  group('Service catalog — IV Visit & IM Visit', () {
    test('IV Visit (visit-iv) and IM Visit (visit-im) are separate entries', () {
      final ivVisit = _allServices.where((s) => s.id == 'visit-iv').toList();
      final imVisit = _allServices.where((s) => s.id == 'visit-im').toList();
      expect(ivVisit.length, 1, reason: 'Expected exactly one visit-iv entry');
      expect(imVisit.length, 1, reason: 'Expected exactly one visit-im entry');
      expect(ivVisit.first.id, isNot(equals(imVisit.first.id)));
    });

    test('IV Visit has bookingType "scheduled" (not "assessment")', () {
      final ivVisit = _allServices.firstWhere((s) => s.id == 'visit-iv');
      expect(ivVisit.bookingType, 'scheduled');
      expect(ivVisit.bookingType, isNot('assessment'));
    });

    test('IM Visit has bookingType "scheduled"', () {
      final imVisit = _allServices.firstWhere((s) => s.id == 'visit-im');
      expect(imVisit.bookingType, 'scheduled');
    });
  });
}
