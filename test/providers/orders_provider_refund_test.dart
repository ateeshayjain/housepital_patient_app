// test/providers/orders_provider_refund_test.dart
//
// Tests for refund tracking on OrdersProvider.cancelOrder (audit M-12).
//
// Refund rule:
//   - cancelled within 24h of booking → totalAmount - ₹100 booking fee
//   - cancelled later                  → 50% of totalAmount
//   - totalAmount <= 0                 → ₹0 refund, status 'none'
//   - refundEta is now + 7 days
//
// Lives in a separate file from orders_provider_test.dart so the refund
// behaviour is easy to read in isolation.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/models/models.dart';

CartItem _makeItem({int unitPrice = 1000}) => CartItem(
      equipmentId: 'eq1',
      name: 'Item',
      brand: 'Brand',
      unitPrice: unitPrice,
    );

/// Manually seed an order with a back-dated createdAt timestamp so we can
/// test the "outside the 24h grace window" branch without waiting.
Future<OrdersProvider> _providerWithSeededOrder({
  required String id,
  required int totalAmount,
  required DateTime createdAt,
}) async {
  SharedPreferences.setMockInitialValues({
    'housepital_orders': jsonEncode([
      {
        'id': id,
        'items': const [],
        'totalAmount': totalAmount,
        'status': 'confirmed',
        'createdAt': createdAt.toIso8601String(),
        'type': 'equipment',
      },
    ]),
  });
  final provider = OrdersProvider();
  // _loadFromStorage is async — give it a microtask turn so orders populate.
  await Future<void>.delayed(Duration.zero);
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Within the 24h grace window — full refund minus ₹100 booking fee
  // ───────────────────────────────────────────────────────────────────────────
  group('cancelOrder within 24h grace window', () {
    test('refundAmount = totalAmount - 100, refundStatus = pending', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeItem()],
        totalAmount: 5000,
        bookingNumber: 'HPL-BOOK-1000001',
      );

      provider.cancelOrder('HPL-BOOK-1000001', 'changed my mind');

      final order = provider.orders.first;
      expect(order['status'], 'cancelled');
      expect(order['cancelReason'], 'changed my mind');
      expect(order['cancelledAt'], isNotNull);
      expect(order['refundAmount'], 5000 - 100);
      expect(order['refundStatus'], 'pending');
      expect(order['refundEta'], isNotNull);
    });

    test('refundEta is exactly 7 days after cancellation', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeItem()],
        totalAmount: 2000,
        bookingNumber: 'HPL-BOOK-1000002',
      );

      final before = DateTime.now();
      provider.cancelOrder('HPL-BOOK-1000002', 'r');
      final after = DateTime.now();

      final eta = DateTime.parse(order(provider, 'HPL-BOOK-1000002')['refundEta'] as String);
      // ETA should be ~7 days from "now"; allow a few ms slack on either side.
      expect(eta.isAfter(before.add(const Duration(days: 7) - const Duration(seconds: 1))), isTrue);
      expect(eta.isBefore(after.add(const Duration(days: 7) + const Duration(seconds: 1))), isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Outside the 24h grace window — 50% refund
  // ───────────────────────────────────────────────────────────────────────────
  group('cancelOrder after 24h grace window', () {
    test('refundAmount = totalAmount * 0.5, refundStatus = pending', () async {
      final provider = await _providerWithSeededOrder(
        id: 'HPL-BOOK-OLD-001',
        totalAmount: 4000,
        // 48 hours ago — well outside the 24h grace
        createdAt: DateTime.now().subtract(const Duration(hours: 48)),
      );

      provider.cancelOrder('HPL-BOOK-OLD-001', 'late cancel');

      final o = order(provider, 'HPL-BOOK-OLD-001');
      expect(o['status'], 'cancelled');
      expect(o['refundAmount'], (4000 * 0.5).round());
      expect(o['refundStatus'], 'pending');
    });

    test('exactly 25h after creation → 50% refund (not grace)', () async {
      final provider = await _providerWithSeededOrder(
        id: 'HPL-BOOK-OLD-002',
        totalAmount: 1000,
        createdAt: DateTime.now().subtract(const Duration(hours: 25)),
      );

      provider.cancelOrder('HPL-BOOK-OLD-002', 'r');

      final o = order(provider, 'HPL-BOOK-OLD-002');
      expect(o['refundAmount'], 500);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Edge cases — zero & negative totals
  // ───────────────────────────────────────────────────────────────────────────
  group('cancelOrder edge cases', () {
    test('totalAmount = 0 → refundAmount = 0, refundStatus = none', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeItem(unitPrice: 0)],
        totalAmount: 0,
        bookingNumber: 'HPL-BOOK-ZERO',
      );

      provider.cancelOrder('HPL-BOOK-ZERO', 'free order cancelled');

      final o = order(provider, 'HPL-BOOK-ZERO');
      expect(o['refundAmount'], 0);
      expect(o['refundStatus'], 'none');
      expect(o['status'], 'cancelled');
    });

    test('negative totalAmount → refundAmount = 0 (defensive)', () async {
      // Negative totals shouldn't happen in production, but the cancelOrder
      // path must not crash or produce a negative refund — the clamp/0-branch
      // is the defensive guard. Seed directly to bypass addOrder validation.
      SharedPreferences.setMockInitialValues({
        'housepital_orders': jsonEncode([
          {
            'id': 'HPL-BOOK-NEG',
            'items': const [],
            'totalAmount': -100,
            'status': 'confirmed',
            'createdAt': DateTime.now().toIso8601String(),
            'type': 'equipment',
          },
        ]),
      });
      final provider = OrdersProvider();
      await Future<void>.delayed(Duration.zero);

      provider.cancelOrder('HPL-BOOK-NEG', 'r');

      final o = order(provider, 'HPL-BOOK-NEG');
      expect(o['refundAmount'], 0,
          reason: 'Negative totals must defensively refund 0, never a negative.');
      expect(o['refundStatus'], 'none');
    });

    test('refund amount within 24h equals totalAmount when totalAmount > 100', () {
      // Belt-and-braces: bookingFee is exactly ₹100, no surprises.
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeItem()],
        totalAmount: 200,
        bookingNumber: 'HPL-BOOK-SMALL',
      );

      provider.cancelOrder('HPL-BOOK-SMALL', 'r');

      final o = order(provider, 'HPL-BOOK-SMALL');
      expect(o['refundAmount'], 100); // 200 - 100 booking fee
    });

    test('refund amount within 24h when totalAmount < 100 → clamped to 0', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeItem()],
        totalAmount: 50,
        bookingNumber: 'HPL-BOOK-TINY',
      );

      provider.cancelOrder('HPL-BOOK-TINY', 'r');

      final o = order(provider, 'HPL-BOOK-TINY');
      // 50 - 100 = -50, clamp(0, 50) = 0
      expect(o['refundAmount'], 0);
      expect(o['refundStatus'], 'none');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Persistence — refund fields survive to SharedPreferences
  // ───────────────────────────────────────────────────────────────────────────
  group('cancelOrder persistence', () {
    test('refund fields are persisted to SharedPreferences', () async {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeItem()],
        totalAmount: 3000,
        bookingNumber: 'HPL-BOOK-PERSIST',
      );

      provider.cancelOrder('HPL-BOOK-PERSIST', 'persist me');

      // Wait for the async _persistAndNotify to flush.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('housepital_orders');
      expect(raw, isNotNull);

      final decoded = jsonDecode(raw!) as List;
      final persisted =
          decoded.firstWhere((o) => o['id'] == 'HPL-BOOK-PERSIST');

      expect(persisted['status'], 'cancelled');
      expect(persisted['cancelReason'], 'persist me');
      expect(persisted['cancelledAt'], isNotNull);
      expect(persisted['refundAmount'], 3000 - 100);
      expect(persisted['refundStatus'], 'pending');
      expect(persisted['refundEta'], isNotNull);
    });
  });
}

// Convenience: pluck an order out of the provider by id.
Map<String, dynamic> order(OrdersProvider provider, String id) =>
    provider.orders.firstWhere((o) => o['id'] == id);
