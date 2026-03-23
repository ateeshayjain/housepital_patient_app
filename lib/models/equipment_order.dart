import 'models.dart';

/// Equipment purchase or rental order.
class EquipmentOrder {
  final String id;
  final String equipmentName;
  final String? equipmentBrand;
  final String orderType; // 'purchase' or 'rental'
  final int? rentalMonths;
  final int amount; // paise
  final String status; // placed, confirmed, dispatched, delivered, cancelled
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final String? trackingInfo;

  EquipmentOrder({
    required this.id,
    required this.equipmentName,
    this.equipmentBrand,
    required this.orderType,
    this.rentalMonths,
    required this.amount,
    required this.status,
    required this.orderDate,
    this.deliveryDate,
    this.trackingInfo,
  });

  factory EquipmentOrder.fromJson(Map<String, dynamic> json) => EquipmentOrder(
        id: json['id'],
        equipmentName: json['equipment_name'],
        equipmentBrand: json['equipment_brand'],
        orderType: json['order_type'],
        rentalMonths: json['rental_months'],
        amount: json['amount'],
        status: json['status'] ?? 'placed',
        orderDate: DateTime.parse(json['order_date']),
        deliveryDate: json['delivery_date'] != null
            ? DateTime.parse(json['delivery_date'])
            : null,
        trackingInfo: json['tracking_info'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'equipment_name': equipmentName,
        'equipment_brand': equipmentBrand,
        'order_type': orderType,
        'rental_months': rentalMonths,
        'amount': amount,
        'status': status,
        'order_date': orderDate.toIso8601String(),
        'delivery_date': deliveryDate?.toIso8601String(),
        'tracking_info': trackingInfo,
      };
}

/// Unified wrapper for rendering any order type in My Orders screen.
class OrderItem {
  final String id;
  final String name;
  final String type; // 'booking', 'equipment', 'assessment'
  final String status;
  final DateTime date;
  final int? amount; // paise
  final Map<String, dynamic> metadata;

  OrderItem({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.date,
    this.amount,
    this.metadata = const {},
  });

  factory OrderItem.fromBooking(Booking b) => OrderItem(
        id: b.id,
        name: b.serviceName ?? 'Service Booking',
        type: 'booking',
        status: b.status,
        date: b.createdAt,
        amount: b.totalAmount,
        metadata: {
          'scheduled_date': b.scheduledDate,
          'scheduled_slot': b.scheduledSlot,
          'service_id': b.serviceId,
          'booking_number': b.bookingNumber,
        },
      );

  factory OrderItem.fromEquipmentOrder(EquipmentOrder o) => OrderItem(
        id: o.id,
        name: o.equipmentName,
        type: 'equipment',
        status: o.status,
        date: o.orderDate,
        amount: o.amount,
        metadata: {
          'order_type': o.orderType,
          'rental_months': o.rentalMonths,
          'tracking_info': o.trackingInfo,
          'delivery_date': o.deliveryDate?.toIso8601String(),
          'equipment_brand': o.equipmentBrand,
        },
      );

  factory OrderItem.fromAssessment(AssessmentRequest a) => OrderItem(
        id: a.id,
        name: _assessmentName(a.serviceCategory),
        type: 'assessment',
        status: a.status,
        date: a.createdAt,
        amount: _extractQuoteAmount(a.quote),
        metadata: {
          'service_category': a.serviceCategory,
          'request_number': a.requestNumber,
          'quote': a.quote,
        },
      );

  static String _assessmentName(String category) {
    switch (category) {
      case 'nursing':
        return 'Nurse';
      case 'caretaker':
        return 'Caretaker';
      case 'japa':
        return 'Japa Maid';
      case 'nanny':
        return 'Nanny';
      case 'physiotherapy':
        return 'Physiotherapy';
      case 'grief_counselling':
        return 'Grief Counselling';
      case 'psychiatry':
        return 'Psychiatrist';
      default:
        return category;
    }
  }

  static int? _extractQuoteAmount(Map<String, dynamic>? quote) {
    if (quote == null) return null;
    return quote['commission_monthly'] as int?;
  }

  /// Assessments in these statuses appear in Orders tab (Tab 1).
  static bool isOrdersTabAssessment(String status) =>
      const {'accepted', 'staff_matched', 'deployed'}.contains(status);

  /// Assessments in these statuses appear in Assessment Requests tab (Tab 2).
  static bool isPendingAssessment(String status) =>
      const {'submitted', 'in_review', 'callback_scheduled', 'quote_sent'}
          .contains(status);
}
