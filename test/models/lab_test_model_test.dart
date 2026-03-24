// test/models/lab_test_model_test.dart
//
// Tests for LabTestItem model: fromJson, toServiceItem(), boolean parsing,
// and edge cases.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

// ---------------------------------------------------------------------------
// Helpers — minimal valid JSON factories
// ---------------------------------------------------------------------------

Map<String, dynamic> _labTestJson({
  String id = 'lab-1',
  String name = 'CBC',
  int? price,
  String? category,
  String? sampleType,
  String? tube,
  bool? fastingRequired,
  String? reportTat,
  bool? homeCollection,
  String? method,
  String? description,
  String? components,
  String? alsoKnownAs,
  String? commonlyPrescribedFor,
  String? relatedTests,
}) =>
    {
      'id': id,
      'name': name,
      if (price != null) 'price': price,
      if (category != null) 'category': category,
      if (sampleType != null) 'sample_type': sampleType,
      if (tube != null) 'tube': tube,
      if (fastingRequired != null) 'fasting_required': fastingRequired,
      if (reportTat != null) 'report_tat': reportTat,
      if (homeCollection != null) 'home_collection': homeCollection,
      if (method != null) 'method': method,
      if (description != null) 'description': description,
      if (components != null) 'components': components,
      if (alsoKnownAs != null) 'also_known_as': alsoKnownAs,
      if (commonlyPrescribedFor != null)
        'commonly_prescribed_for': commonlyPrescribedFor,
      if (relatedTests != null) 'related_tests': relatedTests,
    };

// ---------------------------------------------------------------------------

void main() {
  // ===========================================================================
  // fromJson — full fields
  // ===========================================================================
  group('LabTestItem.fromJson with all fields', () {
    test('parses all fields correctly', () {
      final json = _labTestJson(
        id: 'lab-cbc',
        name: 'Complete Blood Count',
        price: 450,
        category: 'haematology',
        sampleType: 'Blood',
        tube: 'EDTA',
        fastingRequired: true,
        reportTat: '6 hours',
        homeCollection: true,
        method: 'Automated',
        description: 'Measures blood cell counts',
        components: 'RBC|WBC|Platelets|Hemoglobin',
        alsoKnownAs: 'Full Blood Count',
        commonlyPrescribedFor: 'Anaemia screening',
        relatedTests: 'ESR|Peripheral Smear',
      );

      final item = LabTestItem.fromJson(json);

      expect(item.id, 'lab-cbc');
      expect(item.name, 'Complete Blood Count');
      expect(item.price, 450);
      expect(item.category, 'haematology');
      expect(item.sampleType, 'Blood');
      expect(item.tube, 'EDTA');
      expect(item.fastingRequired, isTrue);
      expect(item.reportTat, '6 hours');
      expect(item.homeCollection, isTrue);
      expect(item.method, 'Automated');
      expect(item.description, 'Measures blood cell counts');
      expect(item.components, 'RBC|WBC|Platelets|Hemoglobin');
      expect(item.alsoKnownAs, 'Full Blood Count');
      expect(item.commonlyPrescribedFor, 'Anaemia screening');
      expect(item.relatedTests, 'ESR|Peripheral Smear');
    });
  });

  // ===========================================================================
  // fromJson — minimal fields (nullables)
  // ===========================================================================
  group('LabTestItem.fromJson with minimal fields', () {
    test('parses with only id and name', () {
      final json = <String, dynamic>{
        'id': 'lab-min',
        'name': 'Minimal Test',
      };

      final item = LabTestItem.fromJson(json);

      expect(item.id, 'lab-min');
      expect(item.name, 'Minimal Test');
      expect(item.price, isNull);
      expect(item.category, isNull);
      expect(item.sampleType, isNull);
      expect(item.tube, isNull);
      expect(item.fastingRequired, isFalse);
      expect(item.reportTat, isNull);
      expect(item.homeCollection, isFalse);
      expect(item.method, isNull);
      expect(item.description, isNull);
      expect(item.components, isNull);
      expect(item.alsoKnownAs, isNull);
      expect(item.commonlyPrescribedFor, isNull);
      expect(item.relatedTests, isNull);
    });

    test('handles empty id and name gracefully', () {
      final json = <String, dynamic>{};
      final item = LabTestItem.fromJson(json);
      expect(item.id, isEmpty);
      expect(item.name, isEmpty);
    });
  });

  // ===========================================================================
  // Boolean parsing
  // ===========================================================================
  group('Boolean field parsing', () {
    test('fasting_required true is parsed correctly', () {
      final item = LabTestItem.fromJson(_labTestJson(fastingRequired: true));
      expect(item.fastingRequired, isTrue);
    });

    test('fasting_required false is parsed correctly', () {
      final item = LabTestItem.fromJson(_labTestJson(fastingRequired: false));
      expect(item.fastingRequired, isFalse);
    });

    test('fasting_required defaults to false when absent', () {
      final item = LabTestItem.fromJson(_labTestJson());
      expect(item.fastingRequired, isFalse);
    });

    test('home_collection true is parsed correctly', () {
      final item = LabTestItem.fromJson(_labTestJson(homeCollection: true));
      expect(item.homeCollection, isTrue);
    });

    test('home_collection false is parsed correctly', () {
      final item = LabTestItem.fromJson(_labTestJson(homeCollection: false));
      expect(item.homeCollection, isFalse);
    });

    test('home_collection defaults to false when absent', () {
      final item = LabTestItem.fromJson(_labTestJson());
      expect(item.homeCollection, isFalse);
    });
  });

  // ===========================================================================
  // Price validation
  // ===========================================================================
  group('Price field', () {
    test('price is always positive integer when present', () {
      final item = LabTestItem.fromJson(_labTestJson(price: 350));
      expect(item.price, isA<int>());
      expect(item.price!, greaterThan(0));
    });

    test('price is null when absent', () {
      final item = LabTestItem.fromJson(_labTestJson());
      expect(item.price, isNull);
    });

    test('large price values work correctly', () {
      final item = LabTestItem.fromJson(_labTestJson(price: 99999));
      expect(item.price, equals(99999));
    });
  });

  // ===========================================================================
  // toServiceItem()
  // ===========================================================================
  group('LabTestItem.toServiceItem()', () {
    test('converts to ServiceItem with correct fields', () {
      final labTest = LabTestItem.fromJson(_labTestJson(
        id: 'lab-lipid',
        name: 'Lipid Panel',
        price: 800,
        description: 'Measures cholesterol levels',
      ));

      final service = labTest.toServiceItem();

      expect(service.id, equals('lab-lipid'));
      expect(service.name, equals('Lipid Panel'));
      expect(service.category, equals('lab'));
      expect(service.bookingType, equals('instant'));
      expect(service.description, equals('Measures cholesterol levels'));
      expect(service.basePriceMin, equals(800));
      expect(service.basePriceMax, equals(800));
      expect(service.iconName, equals('science'));
    });

    test('toServiceItem sets both basePriceMin and basePriceMax to price', () {
      final labTest = LabTestItem.fromJson(_labTestJson(price: 1200));
      final service = labTest.toServiceItem();
      expect(service.basePriceMin, equals(service.basePriceMax));
      expect(service.basePriceMin, equals(1200));
    });

    test('toServiceItem with null price sets null price fields', () {
      final labTest = LabTestItem.fromJson(_labTestJson());
      final service = labTest.toServiceItem();
      expect(service.basePriceMin, isNull);
      expect(service.basePriceMax, isNull);
    });

    test('toServiceItem always sets category to lab', () {
      final labTest = LabTestItem.fromJson(
          _labTestJson(category: 'haematology'));
      final service = labTest.toServiceItem();
      expect(service.category, equals('lab'));
    });

    test('toServiceItem always sets bookingType to instant', () {
      final labTest = LabTestItem.fromJson(_labTestJson());
      final service = labTest.toServiceItem();
      expect(service.bookingType, equals('instant'));
      expect(service.isInstant, isTrue);
    });
  });
}
