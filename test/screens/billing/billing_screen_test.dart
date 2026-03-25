// test/screens/billing/billing_screen_test.dart
//
// Tests billing calculation logic extracted from BillingScreen:
// - totalOutstanding: sum of confirmed + in_progress orders
// - totalPaid: sum of completed orders
// - overdueCount: confirmed orders older than 7 days
// - spendSummary: groups by service vs equipment correctly
// - Zero orders: all totals are 0

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

// ---------------------------------------------------------------------------
// Extract billing calculation functions to make them testable standalone.
// These mirror the private methods in BillingScreen exactly.
// ---------------------------------------------------------------------------

int totalOutstanding(List<Map<String, dynamic>> orders) {
  return orders
      .where(
          (o) => o['status'] == 'confirmed' || o['status'] == 'in_progress')
      .fold(0, (sum, o) => sum + ((o['totalAmount'] as int?) ?? 0));
}

int totalPaid(List<Map<String, dynamic>> orders) {
  return orders
      .where((o) => o['status'] == 'completed')
      .fold(0, (sum, o) => sum + ((o['totalAmount'] as int?) ?? 0));
}

int overdueCount(List<Map<String, dynamic>> orders) {
  final now = DateTime.now();
  return orders.where((o) {
    if (o['status'] != 'confirmed') return false;
    final createdAt = DateTime.tryParse(o['createdAt'] as String? ?? '');
    if (createdAt == null) return false;
    return now.difference(createdAt).inDays > 7;
  }).length;
}

List<Map<String, dynamic>> spendSummary(List<Map<String, dynamic>> orders) {
  int serviceSpend = 0;
  int equipmentSpend = 0;

  for (final order in orders) {
    final items = order['items'] as List<dynamic>? ?? [];
    for (final itemJson in items) {
      final item =
          itemJson is Map<String, dynamic> ? CartItem.fromJson(itemJson) : null;
      if (item == null) continue;
      if (item.isService) {
        serviceSpend += item.lineTotal;
      } else {
        equipmentSpend += item.lineTotal;
      }
    }
  }

  final result = <Map<String, dynamic>>[];
  if (serviceSpend > 0) {
    result.add({'category': 'Services', 'amount': serviceSpend});
  }
  if (equipmentSpend > 0) {
    result.add({'category': 'Equipment', 'amount': equipmentSpend});
  }
  return result;
}

// -- Fixture helpers ----------------------------------------------------------

Map<String, dynamic> _makeOrder({
  String id = 'HPL-BOOK-00001',
  String status = 'confirmed',
  int totalAmount = 5000,
  DateTime? createdAt,
  List<Map<String, dynamic>>? items,
}) {
  return {
    'id': id,
    'status': status,
    'totalAmount': totalAmount,
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    'items': items ?? [],
  };
}

Map<String, dynamic> _equipmentItemJson({
  String name = 'Oxygen Concentrator',
  int unitPrice = 25000,
  int quantity = 1,
}) {
  return {
    'equipmentId': 'eq1',
    'name': name,
    'brand': 'Philips',
    'unitPrice': unitPrice,
    'quantity': quantity,
    'isRental': false,
    'rentalMonths': 1,
    'isService': false,
  };
}

Map<String, dynamic> _serviceItemJson({
  String name = 'Nursing 12hr',
  int unitPrice = 2000,
  int quantity = 1,
}) {
  return {
    'equipmentId': 'svc1',
    'name': name,
    'brand': 'Housepital',
    'unitPrice': unitPrice,
    'quantity': quantity,
    'isRental': false,
    'rentalMonths': 1,
    'isService': true,
  };
}

void main() {
  // ---------------------------------------------------------------------------
  // Zero orders
  // ---------------------------------------------------------------------------
  group('zero orders', () {
    test('totalOutstanding is 0', () {
      expect(totalOutstanding([]), 0);
    });

    test('totalPaid is 0', () {
      expect(totalPaid([]), 0);
    });

    test('overdueCount is 0', () {
      expect(overdueCount([]), 0);
    });

    test('spendSummary is empty', () {
      expect(spendSummary([]), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // totalOutstanding
  // ---------------------------------------------------------------------------
  group('totalOutstanding', () {
    test('sums confirmed orders', () {
      final orders = [
        _makeOrder(id: 'A', status: 'confirmed', totalAmount: 1000),
        _makeOrder(id: 'B', status: 'confirmed', totalAmount: 2000),
      ];
      expect(totalOutstanding(orders), 3000);
    });

    test('sums in_progress orders', () {
      final orders = [
        _makeOrder(id: 'A', status: 'in_progress', totalAmount: 3000),
      ];
      expect(totalOutstanding(orders), 3000);
    });

    test('sums confirmed + in_progress together', () {
      final orders = [
        _makeOrder(id: 'A', status: 'confirmed', totalAmount: 1000),
        _makeOrder(id: 'B', status: 'in_progress', totalAmount: 2000),
        _makeOrder(id: 'C', status: 'completed', totalAmount: 5000),
        _makeOrder(id: 'D', status: 'cancelled', totalAmount: 8000),
      ];
      expect(totalOutstanding(orders), 3000);
    });

    test('excludes completed and cancelled', () {
      final orders = [
        _makeOrder(id: 'A', status: 'completed', totalAmount: 5000),
        _makeOrder(id: 'B', status: 'cancelled', totalAmount: 3000),
      ];
      expect(totalOutstanding(orders), 0);
    });

    test('handles null totalAmount gracefully', () {
      final orders = [
        {'id': 'A', 'status': 'confirmed', 'totalAmount': null, 'createdAt': DateTime.now().toIso8601String()},
      ];
      expect(totalOutstanding(orders), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // totalPaid
  // ---------------------------------------------------------------------------
  group('totalPaid', () {
    test('sums completed orders only', () {
      final orders = [
        _makeOrder(id: 'A', status: 'completed', totalAmount: 5000),
        _makeOrder(id: 'B', status: 'completed', totalAmount: 3000),
        _makeOrder(id: 'C', status: 'confirmed', totalAmount: 1000),
      ];
      expect(totalPaid(orders), 8000);
    });

    test('returns 0 when no completed orders', () {
      final orders = [
        _makeOrder(id: 'A', status: 'confirmed', totalAmount: 5000),
      ];
      expect(totalPaid(orders), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // overdueCount
  // ---------------------------------------------------------------------------
  group('overdueCount', () {
    test('counts confirmed orders older than 7 days', () {
      final orders = [
        _makeOrder(
          id: 'A',
          status: 'confirmed',
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
        _makeOrder(
          id: 'B',
          status: 'confirmed',
          createdAt: DateTime.now().subtract(const Duration(days: 8)),
        ),
      ];
      expect(overdueCount(orders), 2);
    });

    test('does not count orders 7 days old or newer', () {
      final orders = [
        _makeOrder(
          id: 'A',
          status: 'confirmed',
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
        _makeOrder(
          id: 'B',
          status: 'confirmed',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];
      expect(overdueCount(orders), 0);
    });

    test('does not count non-confirmed orders even if old', () {
      final orders = [
        _makeOrder(
          id: 'A',
          status: 'completed',
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
        _makeOrder(
          id: 'B',
          status: 'in_progress',
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
        ),
      ];
      expect(overdueCount(orders), 0);
    });

    test('handles invalid date string gracefully', () {
      final orders = [
        {'id': 'A', 'status': 'confirmed', 'createdAt': 'not-a-date'},
      ];
      expect(overdueCount(orders), 0);
    });

    test('handles missing createdAt gracefully', () {
      final orders = [
        {'id': 'A', 'status': 'confirmed'},
      ];
      expect(overdueCount(orders), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // spendSummary
  // ---------------------------------------------------------------------------
  group('spendSummary', () {
    test('groups service and equipment spend correctly', () {
      final orders = [
        _makeOrder(items: [
          _equipmentItemJson(unitPrice: 10000),
          _serviceItemJson(unitPrice: 2000),
        ]),
      ];
      final summary = spendSummary(orders);

      expect(summary.length, 2);
      final equipment = summary.firstWhere((s) => s['category'] == 'Equipment');
      final services = summary.firstWhere((s) => s['category'] == 'Services');
      expect(equipment['amount'], 10000);
      expect(services['amount'], 2000);
    });

    test('returns only equipment when no services', () {
      final orders = [
        _makeOrder(items: [_equipmentItemJson(unitPrice: 5000)]),
      ];
      final summary = spendSummary(orders);
      expect(summary.length, 1);
      expect(summary.first['category'], 'Equipment');
      expect(summary.first['amount'], 5000);
    });

    test('returns only services when no equipment', () {
      final orders = [
        _makeOrder(items: [_serviceItemJson(unitPrice: 3000)]),
      ];
      final summary = spendSummary(orders);
      expect(summary.length, 1);
      expect(summary.first['category'], 'Services');
      expect(summary.first['amount'], 3000);
    });

    test('sums across multiple orders', () {
      final orders = [
        _makeOrder(id: 'A', items: [_equipmentItemJson(unitPrice: 1000)]),
        _makeOrder(id: 'B', items: [_equipmentItemJson(unitPrice: 2000)]),
      ];
      final summary = spendSummary(orders);
      expect(summary.length, 1);
      expect(summary.first['amount'], 3000);
    });

    test('handles quantity multiplier', () {
      final orders = [
        _makeOrder(items: [_equipmentItemJson(unitPrice: 500, quantity: 3)]),
      ];
      final summary = spendSummary(orders);
      expect(summary.first['amount'], 1500);
    });

    test('returns empty list when orders have no items', () {
      final orders = [_makeOrder(items: [])];
      expect(spendSummary(orders), isEmpty);
    });
  });
}
