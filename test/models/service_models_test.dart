// test/models/service_models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

// ---------------------------------------------------------------------------
// Helpers — minimal valid JSON factories
// ---------------------------------------------------------------------------

Map<String, dynamic> _serviceItemJson({
  String id = 'svc-1',
  String name = 'Test Service',
  String? nameHi,
  String category = 'visit',
  String bookingType = 'instant',
  String? description,
  String? descriptionHi,
  int? basePriceMin,
  int? basePriceMax,
  int? durationMinutes,
  String? preparationNotes,
  String? preparationNotesHi,
  int? leadTimeHours,
  bool? isActive,
  String? iconName,
}) =>
    {
      'id': id,
      'name': name,
      if (nameHi != null) 'name_hi': nameHi,
      'category': category,
      'booking_type': bookingType,
      if (description != null) 'description': description,
      if (descriptionHi != null) 'description_hi': descriptionHi,
      if (basePriceMin != null) 'base_price_min': basePriceMin,
      if (basePriceMax != null) 'base_price_max': basePriceMax,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (preparationNotes != null) 'preparation_notes': preparationNotes,
      if (preparationNotesHi != null) 'preparation_notes_hi': preparationNotesHi,
      if (leadTimeHours != null) 'lead_time_hours': leadTimeHours,
      if (isActive != null) 'is_active': isActive,
      if (iconName != null) 'icon_name': iconName,
    };

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // ServiceItem — isInstant
  // =========================================================================
  group('ServiceItem', () {
    group('isInstant', () {
      test('returns true for bookingType "instant"', () {
        final item = ServiceItem(
          id: 'test-1',
          name: 'Test',
          category: 'visit',
          bookingType: 'instant',
        );
        expect(item.isInstant, isTrue);
      });

      test('returns true for bookingType "scheduled"', () {
        final item = ServiceItem(
          id: 'test-2',
          name: 'Test',
          category: 'visit',
          bookingType: 'scheduled',
        );
        expect(item.isInstant, isTrue);
      });

      test('returns false for bookingType "assessment"', () {
        final item = ServiceItem(
          id: 'test-3',
          name: 'Test',
          category: 'manpower',
          bookingType: 'assessment',
        );
        expect(item.isInstant, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // fromJson
    // -----------------------------------------------------------------------
    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = _serviceItemJson(
          id: 'visit-iv',
          name: 'IV Visit',
          nameHi: 'IV विजिट',
          category: 'visit',
          bookingType: 'scheduled',
          description: 'IV procedure at home',
          descriptionHi: 'घर पर IV प्रक्रिया',
          basePriceMin: 900,
          basePriceMax: 1500,
          durationMinutes: 60,
          preparationNotes: 'Keep prescription ready',
          preparationNotesHi: 'प्रिस्क्रिप्शन तैयार रखें',
          leadTimeHours: 4,
          isActive: true,
          iconName: 'vaccines',
        );

        final item = ServiceItem.fromJson(json);

        expect(item.id, 'visit-iv');
        expect(item.name, 'IV Visit');
        expect(item.nameHi, 'IV विजिट');
        expect(item.category, 'visit');
        expect(item.bookingType, 'scheduled');
        expect(item.description, 'IV procedure at home');
        expect(item.descriptionHi, 'घर पर IV प्रक्रिया');
        expect(item.basePriceMin, 900);
        expect(item.basePriceMax, 1500);
        expect(item.durationMinutes, 60);
        expect(item.preparationNotes, 'Keep prescription ready');
        expect(item.preparationNotesHi, 'प्रिस्क्रिप्शन तैयार रखें');
        expect(item.leadTimeHours, 4);
        expect(item.isActive, isTrue);
        expect(item.iconName, 'vaccines');
      });

      test('applies default leadTimeHours=24 when absent', () {
        final json = _serviceItemJson();
        final item = ServiceItem.fromJson(json);
        expect(item.leadTimeHours, 24);
      });

      test('applies default isActive=true when absent', () {
        final json = _serviceItemJson();
        final item = ServiceItem.fromJson(json);
        expect(item.isActive, isTrue);
      });

      test('basePriceMin is null when absent from JSON', () {
        final json = _serviceItemJson();
        final item = ServiceItem.fromJson(json);
        expect(item.basePriceMin, isNull);
      });

      test('basePriceMax is null when absent from JSON', () {
        final json = _serviceItemJson();
        final item = ServiceItem.fromJson(json);
        expect(item.basePriceMax, isNull);
      });

      test('nullable fields default to null when absent', () {
        final json = {
          'id': 'min-svc',
          'name': 'Minimal',
          'category': 'visit',
          'booking_type': 'instant',
        };

        final item = ServiceItem.fromJson(json);

        expect(item.nameHi, isNull);
        expect(item.description, isNull);
        expect(item.descriptionHi, isNull);
        expect(item.basePriceMin, isNull);
        expect(item.basePriceMax, isNull);
        expect(item.durationMinutes, isNull);
        expect(item.preparationNotes, isNull);
        expect(item.preparationNotesHi, isNull);
        expect(item.iconName, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // Constructor defaults
    // -----------------------------------------------------------------------
    group('constructor defaults', () {
      test('leadTimeHours defaults to 24', () {
        final item = ServiceItem(
          id: 'test',
          name: 'Test',
          category: 'visit',
          bookingType: 'instant',
        );
        expect(item.leadTimeHours, 24);
      });

      test('isActive defaults to true', () {
        final item = ServiceItem(
          id: 'test',
          name: 'Test',
          category: 'visit',
          bookingType: 'instant',
        );
        expect(item.isActive, isTrue);
      });

      test('basePriceMin and basePriceMax are nullable and default to null', () {
        final item = ServiceItem(
          id: 'test',
          name: 'Test',
          category: 'visit',
          bookingType: 'instant',
        );
        expect(item.basePriceMin, isNull);
        expect(item.basePriceMax, isNull);
      });
    });
  });
}
