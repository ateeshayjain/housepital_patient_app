// test/providers/orders_provider_test.dart
//
// Unit tests for OrdersProvider:
// - addOrder: creates order with booking number, items, total, status 'confirmed'
// - addOrder: orders list grows, newest first
// - addAssessment: creates assessment with serviceId, serviceName, status 'submitted'
// - cancelOrder: changes status to 'cancelled', adds cancellation reason
// - updateOrderStatus: changes status correctly
// - generateBookingNumber: format HPL-BOOK-XXXXXXX (7-digit timestamp suffix)
// - generateBookingNumber: each call produces unique number
// - Empty state: no orders initially

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/models/models.dart';

// -- Fixture helpers ----------------------------------------------------------

CartItem _makeCartItem({
  String id = 'eq1',
  String name = 'Oxygen Concentrator',
  int unitPrice = 25000,
  bool isService = false,
}) {
  return CartItem(
    equipmentId: id,
    name: name,
    brand: 'Philips',
    unitPrice: unitPrice,
    isService: isService,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // generateBookingNumber
  // ---------------------------------------------------------------------------
  group('generateBookingNumber', () {
    test('format is HPL-BOOK-XXXXXXX (7-digit timestamp suffix)', () {
      final booking = OrdersProvider.generateBookingNumber();
      expect(booking, matches(RegExp(r'^HPL-BOOK-\d{7}$')));
    });

    test('suffix is numeric and non-empty', () {
      final booking = OrdersProvider.generateBookingNumber();
      final digits = booking.split('-').last;
      expect(digits.length, 7);
      expect(int.tryParse(digits), isNotNull);
    });

    test('generateUniqueBookingNumber avoids collisions with existing orders', () {
      final provider = OrdersProvider();
      final existing = OrdersProvider.generateBookingNumber();
      provider.addOrder(
        items: [_makeCartItem()],
        totalAmount: 1000,
        bookingNumber: existing,
      );
      // generateUniqueBookingNumber should never return the same id as one in the list.
      for (var i = 0; i < 5; i++) {
        final next = provider.generateUniqueBookingNumber();
        expect(next, isNot(existing));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------
  group('empty state', () {
    test('no orders initially', () {
      final provider = OrdersProvider();
      expect(provider.orders, isEmpty);
    });

    test('no assessments initially', () {
      final provider = OrdersProvider();
      expect(provider.assessments, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // addOrder
  // ---------------------------------------------------------------------------
  group('addOrder', () {
    test('creates order with booking number, items, total, and confirmed status', () {
      final provider = OrdersProvider();
      final items = [_makeCartItem()];
      const bookingNumber = 'HPL-BOOK-12345';

      provider.addOrder(
        items: items,
        totalAmount: 25000,
        bookingNumber: bookingNumber,
      );

      expect(provider.orders.length, 1);
      final order = provider.orders.first;
      expect(order['id'], bookingNumber);
      expect(order['totalAmount'], 25000);
      expect(order['status'], 'confirmed');
      expect(order['items'], isA<List>());
      expect((order['items'] as List).length, 1);
      expect(order['createdAt'], isNotNull);
    });

    test('orders list grows, newest first', () {
      final provider = OrdersProvider();

      provider.addOrder(
        items: [_makeCartItem(name: 'First Item')],
        totalAmount: 1000,
        bookingNumber: 'HPL-BOOK-00001',
      );

      provider.addOrder(
        items: [_makeCartItem(name: 'Second Item')],
        totalAmount: 2000,
        bookingNumber: 'HPL-BOOK-00002',
      );

      expect(provider.orders.length, 2);
      // Newest first (insert at 0)
      expect(provider.orders[0]['id'], 'HPL-BOOK-00002');
      expect(provider.orders[1]['id'], 'HPL-BOOK-00001');
    });

    test('order type is "equipment" when all items are equipment', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeCartItem(isService: false)],
        totalAmount: 1000,
        bookingNumber: 'HPL-BOOK-10001',
      );
      expect(provider.orders.first['type'], 'equipment');
    });

    test('order type is "mixed" when at least one item is a service', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [
          _makeCartItem(isService: false),
          _makeCartItem(id: 'svc1', isService: true),
        ],
        totalAmount: 3000,
        bookingNumber: 'HPL-BOOK-10002',
      );
      expect(provider.orders.first['type'], 'mixed');
    });
  });

  // ---------------------------------------------------------------------------
  // addOrder — quotePending (quote-first manpower / price-on-request orders)
  // ---------------------------------------------------------------------------
  group('addOrder quotePending', () {
    test('quotePending:true stamps quoteStatus pending with totalAmount 0', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeCartItem(unitPrice: 0, isService: true)],
        totalAmount: 0,
        bookingNumber: 'HPL-BOOK-70001',
        quotePending: true,
      );

      final order = provider.orders.first;
      expect(order['quoteStatus'], 'pending');
      expect(order['totalAmount'], 0);
      expect(order['status'], 'confirmed');
      expect(OrdersProvider.isQuotePending(order), isTrue);
    });

    test('default addOrder carries no quoteStatus key', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeCartItem()],
        totalAmount: 1000,
        bookingNumber: 'HPL-BOOK-70002',
      );

      final order = provider.orders.first;
      expect(order.containsKey('quoteStatus'), isFalse);
      expect(OrdersProvider.isQuotePending(order), isFalse);
    });

    test('isQuotePending only matches the pending state', () {
      expect(OrdersProvider.isQuotePending({'quoteStatus': 'pending'}), isTrue);
      expect(
          OrdersProvider.isQuotePending({'quoteStatus': 'confirmed'}), isFalse);
      expect(OrdersProvider.isQuotePending({}), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // addAssessment
  // ---------------------------------------------------------------------------
  group('addAssessment', () {
    test('creates assessment with serviceId, serviceName, and submitted status', () {
      final provider = OrdersProvider();

      provider.addAssessment(
        serviceId: 'svc-nurse-12h',
        serviceName: 'Nursing Care 12hr',
        formData: {'patientAge': 65, 'condition': 'post-surgery'},
      );

      expect(provider.assessments.length, 1);
      final assessment = provider.assessments.first;
      expect(assessment['serviceId'], 'svc-nurse-12h');
      expect(assessment['serviceName'], 'Nursing Care 12hr');
      expect(assessment['status'], 'submitted');
      expect(assessment['formData'], isA<Map>());
      expect(assessment['createdAt'], isNotNull);
      expect((assessment['id'] as String).startsWith('HPL-ASR-'), isTrue);
    });

    test('assessments list grows, newest first', () {
      final provider = OrdersProvider();

      provider.addAssessment(
        serviceId: 'svc1',
        serviceName: 'First',
        formData: {},
      );

      provider.addAssessment(
        serviceId: 'svc2',
        serviceName: 'Second',
        formData: {},
      );

      expect(provider.assessments.length, 2);
      expect(provider.assessments[0]['serviceId'], 'svc2');
      expect(provider.assessments[1]['serviceId'], 'svc1');
    });
  });

  // ---------------------------------------------------------------------------
  // cancelOrder
  // ---------------------------------------------------------------------------
  group('cancelOrder', () {
    test('changes status to cancelled and adds cancellation reason', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeCartItem()],
        totalAmount: 5000,
        bookingNumber: 'HPL-BOOK-99999',
      );

      provider.cancelOrder('HPL-BOOK-99999', 'No longer needed');

      final order = provider.orders.first;
      expect(order['status'], 'cancelled');
      expect(order['cancelReason'], 'No longer needed');
      expect(order['cancelledAt'], isNotNull);
    });

    test('does nothing if orderId not found', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeCartItem()],
        totalAmount: 5000,
        bookingNumber: 'HPL-BOOK-11111',
      );

      provider.cancelOrder('HPL-BOOK-NONEXISTENT', 'reason');

      expect(provider.orders.first['status'], 'confirmed');
    });
  });

  // ---------------------------------------------------------------------------
  // updateOrderStatus
  // ---------------------------------------------------------------------------
  group('updateOrderStatus', () {
    test('changes status correctly', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeCartItem()],
        totalAmount: 5000,
        bookingNumber: 'HPL-BOOK-22222',
      );

      provider.updateOrderStatus('HPL-BOOK-22222', 'in_progress');
      expect(provider.orders.first['status'], 'in_progress');

      provider.updateOrderStatus('HPL-BOOK-22222', 'completed');
      expect(provider.orders.first['status'], 'completed');
    });

    test('does nothing if orderId not found', () {
      final provider = OrdersProvider();
      provider.addOrder(
        items: [_makeCartItem()],
        totalAmount: 5000,
        bookingNumber: 'HPL-BOOK-33333',
      );

      provider.updateOrderStatus('HPL-BOOK-NONEXISTENT', 'completed');
      expect(provider.orders.first['status'], 'confirmed');
    });
  });

  // ---------------------------------------------------------------------------
  // orders list is unmodifiable
  // ---------------------------------------------------------------------------
  test('orders list is unmodifiable', () {
    final provider = OrdersProvider();
    provider.addOrder(
      items: [_makeCartItem()],
      totalAmount: 1000,
      bookingNumber: 'HPL-BOOK-44444',
    );

    expect(() => provider.orders.add({}), throwsUnsupportedError);
  });

  test('assessments list is unmodifiable', () {
    final provider = OrdersProvider();
    provider.addAssessment(
      serviceId: 'svc1',
      serviceName: 'Test',
      formData: {},
    );

    expect(() => provider.assessments.add({}), throwsUnsupportedError);
  });
}
