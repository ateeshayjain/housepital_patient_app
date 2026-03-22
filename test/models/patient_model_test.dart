// test/models/patient_model_test.dart
//
// Tests for the Patient model from lib/models/models.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

// ---------------------------------------------------------------------------
// Helpers — JSON factories
// ---------------------------------------------------------------------------

Map<String, dynamic> _fullPatientJson() => {
      'id': 'patient-001',
      'name': 'Raj Kumar',
      'age': 72,
      'gender': 'male',
      'conditions': ['diabetes', 'hypertension'],
      'medications': [
        {'name': 'Metformin', 'dosage': '500mg', 'schedule': 'twice daily'},
        {'name': 'Amlodipine', 'dosage': '5mg', 'schedule': 'once daily'},
      ],
      'allergies': ['Penicillin'],
      'dietary_restrictions': 'Low sodium',
      'mobility_status': 'wheelchair',
      'doctor_name': 'Dr. Sharma',
      'doctor_phone': '9876543210',
      'doctor_hospital': 'Max Hospital',
      'emergency_contacts': [
        {'name': 'Priya Kumar', 'phone': '9876543211', 'relation': 'daughter'},
      ],
      'address': '123, Green Park',
      'city': 'delhi',
      'created_at': '2024-06-15T10:30:00Z',
      'height': '170cm',
      'weight': '75kg',
      'diagnosis': 'Type 2 Diabetes with HTN',
      'iv_central_line': 'PICC',
      'discharge_summary_available': true,
      'feeding_type': 'oral',
      'mental_condition': 'alert',
      'motion_status': 'bedridden',
      'bp_sugar_insulin': 'On insulin 10 units',
      'requirement': 'ICU nurse 24 hours',
    };

Map<String, dynamic> _minimalPatientJson() => {
      'id': 'patient-002',
      'name': 'Test Patient',
    };

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // fromJson — all fields
  // =========================================================================
  group('Patient.fromJson — all fields', () {
    test('parses all fields correctly', () {
      final patient = Patient.fromJson(_fullPatientJson());

      expect(patient.id, 'patient-001');
      expect(patient.name, 'Raj Kumar');
      expect(patient.age, 72);
      expect(patient.gender, 'male');
      expect(patient.conditions, ['diabetes', 'hypertension']);
      expect(patient.medications, isNotNull);
      expect(patient.medications!.length, 2);
      expect(patient.medications![0].name, 'Metformin');
      expect(patient.medications![0].dosage, '500mg');
      expect(patient.medications![1].name, 'Amlodipine');
      expect(patient.allergies, ['Penicillin']);
      expect(patient.dietaryRestrictions, 'Low sodium');
      expect(patient.mobilityStatus, 'wheelchair');
      expect(patient.doctorName, 'Dr. Sharma');
      expect(patient.doctorPhone, '9876543210');
      expect(patient.doctorHospital, 'Max Hospital');
      expect(patient.emergencyContacts, isNotNull);
      expect(patient.emergencyContacts!.length, 1);
      expect(patient.emergencyContacts![0].name, 'Priya Kumar');
      expect(patient.emergencyContacts![0].relation, 'daughter');
      expect(patient.address, '123, Green Park');
      expect(patient.city, 'delhi');
      expect(patient.createdAt, isNotNull);
      expect(patient.height, '170cm');
      expect(patient.weight, '75kg');
      expect(patient.diagnosis, 'Type 2 Diabetes with HTN');
      expect(patient.ivCentralLine, 'PICC');
      expect(patient.dischargeSummaryAvailable, isTrue);
      expect(patient.feedingType, 'oral');
      expect(patient.mentalCondition, 'alert');
      expect(patient.motionStatus, 'bedridden');
      expect(patient.bpSugarInsulin, 'On insulin 10 units');
      expect(patient.requirement, 'ICU nurse 24 hours');
    });
  });

  // =========================================================================
  // fromJson — minimal fields (nullable defaults)
  // =========================================================================
  group('Patient.fromJson — minimal fields', () {
    test('parses with only required fields', () {
      final patient = Patient.fromJson(_minimalPatientJson());

      expect(patient.id, 'patient-002');
      expect(patient.name, 'Test Patient');
      expect(patient.age, isNull);
      expect(patient.gender, isNull);
      expect(patient.conditions, isNull);
      expect(patient.medications, isNull);
      expect(patient.allergies, isNull);
      expect(patient.dietaryRestrictions, isNull);
      expect(patient.mobilityStatus, isNull);
      expect(patient.doctorName, isNull);
      expect(patient.doctorPhone, isNull);
      expect(patient.doctorHospital, isNull);
      expect(patient.emergencyContacts, isNull);
      expect(patient.address, isNull);
      expect(patient.city, isNull);
      expect(patient.createdAt, isNull);
      expect(patient.height, isNull);
      expect(patient.weight, isNull);
      expect(patient.diagnosis, isNull);
      expect(patient.ivCentralLine, isNull);
      expect(patient.dischargeSummaryAvailable, isNull);
      expect(patient.feedingType, isNull);
      expect(patient.mentalCondition, isNull);
      expect(patient.motionStatus, isNull);
      expect(patient.bpSugarInsulin, isNull);
      expect(patient.requirement, isNull);
    });
  });

  // =========================================================================
  // toJson round-trip
  // =========================================================================
  group('Patient toJson round-trip', () {
    test('fromJson -> toJson preserves required fields', () {
      final original = _fullPatientJson();
      final patient = Patient.fromJson(original);
      final output = patient.toJson();

      expect(output['id'], original['id']);
      expect(output['name'], original['name']);
      expect(output['age'], original['age']);
      expect(output['gender'], original['gender']);
      expect(output['conditions'], original['conditions']);
      expect(output['allergies'], original['allergies']);
      expect(output['dietary_restrictions'], original['dietary_restrictions']);
      expect(output['mobility_status'], original['mobility_status']);
      expect(output['doctor_name'], original['doctor_name']);
      expect(output['doctor_phone'], original['doctor_phone']);
      expect(output['doctor_hospital'], original['doctor_hospital']);
      expect(output['address'], original['address']);
      expect(output['city'], original['city']);
      expect(output['height'], original['height']);
      expect(output['weight'], original['weight']);
      expect(output['diagnosis'], original['diagnosis']);
      expect(output['iv_central_line'], original['iv_central_line']);
      expect(output['discharge_summary_available'], original['discharge_summary_available']);
      expect(output['feeding_type'], original['feeding_type']);
      expect(output['mental_condition'], original['mental_condition']);
      expect(output['motion_status'], original['motion_status']);
      expect(output['bp_sugar_insulin'], original['bp_sugar_insulin']);
      expect(output['requirement'], original['requirement']);
    });

    test('medications survive round-trip', () {
      final patient = Patient.fromJson(_fullPatientJson());
      final output = patient.toJson();

      expect(output['medications'], isList);
      expect((output['medications'] as List).length, 2);
      expect((output['medications'] as List)[0]['name'], 'Metformin');
    });

    test('emergency contacts survive round-trip', () {
      final patient = Patient.fromJson(_fullPatientJson());
      final output = patient.toJson();

      expect(output['emergency_contacts'], isList);
      expect((output['emergency_contacts'] as List).length, 1);
      expect((output['emergency_contacts'] as List)[0]['phone'], '9876543211');
    });
  });

  // =========================================================================
  // Edge cases
  // =========================================================================
  group('Patient — edge cases', () {
    test('empty conditions list', () {
      final json = _minimalPatientJson()..['conditions'] = <String>[];
      final patient = Patient.fromJson(json);
      expect(patient.conditions, isEmpty);
    });

    test('null doctor info fields', () {
      final patient = Patient.fromJson(_minimalPatientJson());
      expect(patient.doctorName, isNull);
      expect(patient.doctorPhone, isNull);
      expect(patient.doctorHospital, isNull);
    });

    test('empty medications list', () {
      final json = _minimalPatientJson()..['medications'] = [];
      final patient = Patient.fromJson(json);
      expect(patient.medications, isNotNull);
      expect(patient.medications, isEmpty);
    });

    test('empty emergency contacts list', () {
      final json = _minimalPatientJson()..['emergency_contacts'] = [];
      final patient = Patient.fromJson(json);
      expect(patient.emergencyContacts, isNotNull);
      expect(patient.emergencyContacts, isEmpty);
    });
  });

  // =========================================================================
  // Medication sub-model
  // =========================================================================
  group('Medication', () {
    test('fromJson parses all fields', () {
      final med = Medication.fromJson({
        'name': 'Aspirin',
        'dosage': '75mg',
        'schedule': 'once daily',
      });
      expect(med.name, 'Aspirin');
      expect(med.dosage, '75mg');
      expect(med.schedule, 'once daily');
    });

    test('fromJson handles null optional fields', () {
      final med = Medication.fromJson({'name': 'Crocin'});
      expect(med.name, 'Crocin');
      expect(med.dosage, isNull);
      expect(med.schedule, isNull);
    });

    test('toJson round-trip', () {
      final med = Medication(name: 'Test', dosage: '10mg', schedule: 'daily');
      final json = med.toJson();
      expect(json['name'], 'Test');
      expect(json['dosage'], '10mg');
      expect(json['schedule'], 'daily');
    });
  });

  // =========================================================================
  // EmergencyContact sub-model
  // =========================================================================
  group('EmergencyContact', () {
    test('fromJson parses all fields', () {
      final ec = EmergencyContact.fromJson({
        'name': 'Amit',
        'phone': '9999999999',
        'relation': 'son',
      });
      expect(ec.name, 'Amit');
      expect(ec.phone, '9999999999');
      expect(ec.relation, 'son');
    });

    test('fromJson handles null relation', () {
      final ec = EmergencyContact.fromJson({
        'name': 'Amit',
        'phone': '9999999999',
      });
      expect(ec.relation, isNull);
    });

    test('toJson round-trip', () {
      final ec = EmergencyContact(name: 'Test', phone: '1234567890', relation: 'spouse');
      final json = ec.toJson();
      expect(json['name'], 'Test');
      expect(json['phone'], '1234567890');
      expect(json['relation'], 'spouse');
    });
  });
}
