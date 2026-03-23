import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/equipment_order.dart';
import 'package:housepital_patient/models/models.dart';

void main() {
  group('EquipmentOrder', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'eo-001',
        'equipment_name': 'Hospital Bed',
        'equipment_brand': 'Medline',
        'order_type': 'rental',
        'rental_months': 3,
        'amount': 250000,
        'status': 'dispatched',
        'order_date': '2026-03-20T10:00:00Z',
        'delivery_date': '2026-03-21',
        'tracking_info': 'Shipped via BlueDart',
      };
      final order = EquipmentOrder.fromJson(json);
      expect(order.id, 'eo-001');
      expect(order.equipmentName, 'Hospital Bed');
      expect(order.equipmentBrand, 'Medline');
      expect(order.orderType, 'rental');
      expect(order.rentalMonths, 3);
      expect(order.amount, 250000);
      expect(order.status, 'dispatched');
      expect(order.trackingInfo, 'Shipped via BlueDart');
    });

    test('fromJson handles minimal fields', () {
      final json = {
        'id': 'eo-002',
        'equipment_name': '3 Ply Mask',
        'order_type': 'purchase',
        'amount': 5000,
        'status': 'placed',
        'order_date': '2026-03-22T10:00:00Z',
      };
      final order = EquipmentOrder.fromJson(json);
      expect(order.equipmentBrand, isNull);
      expect(order.rentalMonths, isNull);
      expect(order.deliveryDate, isNull);
      expect(order.trackingInfo, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = EquipmentOrder(
        id: 'eo-003',
        equipmentName: 'CPAP',
        orderType: 'rental',
        amount: 500000,
        status: 'confirmed',
        orderDate: DateTime.parse('2026-03-20T10:00:00Z'),
      );
      final json = original.toJson();
      final restored = EquipmentOrder.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.equipmentName, original.equipmentName);
      expect(restored.amount, original.amount);
    });

    test('status defaults to placed when null', () {
      final json = {
        'id': 'eo-004',
        'equipment_name': 'Mask',
        'order_type': 'purchase',
        'amount': 100,
        'order_date': '2026-03-22T10:00:00Z',
      };
      final order = EquipmentOrder.fromJson(json);
      expect(order.status, 'placed');
    });
  });

  group('OrderItem', () {
    test('fromBooking maps all fields', () {
      final booking = Booking.fromJson({
        'id': 'b-001',
        'booking_number': 'HPL-BOOK-12345',
        'patient_id': 'p-001',
        'service_id': 'con-doctor',
        'service_name': 'Doctor Visit',
        'booking_type': 'scheduled',
        'status': 'confirmed',
        'scheduled_date': '2026-03-24',
        'scheduled_slot': 'morning',
        'price_amount': 350000,
        'gst_amount': 63000,
        'total_amount': 413000,
        'payment_status': 'paid',
        'created_at': '2026-03-22T10:00:00Z',
      });
      final item = OrderItem.fromBooking(booking);
      expect(item.id, 'b-001');
      expect(item.name, 'Doctor Visit');
      expect(item.type, 'booking');
      expect(item.status, 'confirmed');
      expect(item.amount, 413000);
      expect(item.metadata['scheduled_slot'], 'morning');
    });

    test('fromEquipmentOrder maps all fields', () {
      final order = EquipmentOrder(
        id: 'eo-001',
        equipmentName: 'Hospital Bed',
        equipmentBrand: 'Medline',
        orderType: 'rental',
        rentalMonths: 3,
        amount: 250000,
        status: 'dispatched',
        orderDate: DateTime.parse('2026-03-20T10:00:00Z'),
      );
      final item = OrderItem.fromEquipmentOrder(order);
      expect(item.type, 'equipment');
      expect(item.name, 'Hospital Bed');
      expect(item.metadata['order_type'], 'rental');
      expect(item.metadata['rental_months'], 3);
    });

    test('fromAssessment maps all fields', () {
      final assessment = AssessmentRequest.fromJson({
        'id': 'asr-001',
        'request_number': 'HPL-ASR-123456',
        'patient_id': 'p-001',
        'service_category': 'nursing',
        'status': 'quote_sent',
        'questionnaire_responses': <String, dynamic>{},
        'quote': {'commission_monthly': 1200000},
        'created_at': '2026-03-20T10:00:00Z',
      });
      final item = OrderItem.fromAssessment(assessment);
      expect(item.type, 'assessment');
      expect(item.status, 'quote_sent');
      expect(item.metadata['service_category'], 'nursing');
      expect(item.metadata['quote'], isNotNull);
      expect(item.amount, 1200000);
    });

    test('assessment name maps categories correctly', () {
      for (final entry in {
        'nursing': 'Nurse',
        'caretaker': 'Caretaker',
        'japa': 'Japa Maid',
        'nanny': 'Nanny',
        'physiotherapy': 'Physiotherapy',
        'grief_counselling': 'Grief Counselling',
        'psychiatry': 'Psychiatrist',
      }.entries) {
        final a = AssessmentRequest.fromJson({
          'id': 'a-1',
          'request_number': 'HPL-ASR-1',
          'patient_id': 'p-1',
          'service_category': entry.key,
          'questionnaire_responses': <String, dynamic>{},
          'created_at': '2026-03-20T10:00:00Z',
        });
        expect(OrderItem.fromAssessment(a).name, entry.value);
      }
    });

    test('isOrdersTabAssessment returns true for accepted/staff_matched/deployed', () {
      for (final status in ['accepted', 'staff_matched', 'deployed']) {
        expect(OrderItem.isOrdersTabAssessment(status), isTrue,
            reason: '$status should be in Orders tab');
      }
    });

    test('isOrdersTabAssessment returns false for pending statuses', () {
      for (final status in [
        'submitted',
        'in_review',
        'callback_scheduled',
        'quote_sent'
      ]) {
        expect(OrderItem.isOrdersTabAssessment(status), isFalse,
            reason: '$status should NOT be in Orders tab');
      }
    });

    test('isPendingAssessment returns true for tab 2 statuses', () {
      for (final status in [
        'submitted',
        'in_review',
        'callback_scheduled',
        'quote_sent'
      ]) {
        expect(OrderItem.isPendingAssessment(status), isTrue);
      }
    });

    test('isPendingAssessment returns false for terminal/accepted statuses', () {
      for (final status in [
        'accepted',
        'declined',
        'expired',
        'staff_matched',
        'deployed'
      ]) {
        expect(OrderItem.isPendingAssessment(status), isFalse);
      }
    });
  });
}
