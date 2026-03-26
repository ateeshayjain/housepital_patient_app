// test/integration/billing_from_orders_test.dart
//
// Integration-style test: billing totals computed from orders data.
// Verifies totalOutstanding (confirmed only) and totalPaid (completed only)
// exclude cancelled orders.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/models/models.dart';

// -- Fixture helpers ----------------------------------------------------------

CartItem _makeCartItem({
  String id = 'eq1',
  String name = 'Test Item',
  int unitPrice = 1000,
}) {
  return CartItem(
    equipmentId: id,
    name: name,
    brand: 'Test',
    unitPrice: unitPrice,
  );
}

// -- Billing calculation (mirrors what the billing screen does) ----------------

int _totalOutstanding(List<Map<String, dynamic>> orders) {
  return orders
      .where((o) => o['status'] == 'confirmed')
      .fold<int>(0, (sum, o) => sum + (o['totalAmount'] as int));
}

int _totalPaid(List<Map<String, dynamic>> orders) {
  return orders
      .where((o) => o['status'] == 'completed')
      .fold<int>(0, (sum, o) => sum + (o['totalAmount'] as int));
}

// -- Tests --------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('billing from orders: totalOutstanding, totalPaid, cancelled excluded', () {
    final orders = OrdersProvider();

    // 1. Add 3 orders with different statuses
    // Order 1: completed, 5000
    orders.addOrder(
      items: [_makeCartItem(id: 'eq1', name: 'Wheelchair', unitPrice: 5000)],
      totalAmount: 5000,
      bookingNumber: 'HPL-BOOK-10001',
    );
    orders.updateOrderStatus('HPL-BOOK-10001', 'completed');

    // Order 2: confirmed (outstanding), 3000
    orders.addOrder(
      items: [_makeCartItem(id: 'eq2', name: 'BP Monitor', unitPrice: 3000)],
      totalAmount: 3000,
      bookingNumber: 'HPL-BOOK-10002',
    );
    // Status stays 'confirmed' by default

    // Order 3: cancelled, 2000
    orders.addOrder(
      items: [_makeCartItem(id: 'eq3', name: 'Nebulizer', unitPrice: 2000)],
      totalAmount: 2000,
      bookingNumber: 'HPL-BOOK-10003',
    );
    orders.cancelOrder('HPL-BOOK-10003', 'Changed my mind');

    // 2. Verify we have all 3 orders
    expect(orders.orders.length, 3);

    // 3. Verify totalOutstanding = 3000 (only confirmed)
    expect(_totalOutstanding(orders.orders), 3000);

    // 4. Verify totalPaid = 5000 (only completed)
    expect(_totalPaid(orders.orders), 5000);

    // 5. Verify cancelled doesn't count in either
    final cancelledTotal = orders.orders
        .where((o) => o['status'] == 'cancelled')
        .fold<int>(0, (sum, o) => sum + (o['totalAmount'] as int));
    expect(cancelledTotal, 2000);
    // But it shouldn't be in outstanding or paid
    expect(_totalOutstanding(orders.orders) + _totalPaid(orders.orders), 8000);
    // Total of all orders is 10000, but only 8000 counts
  });
}
