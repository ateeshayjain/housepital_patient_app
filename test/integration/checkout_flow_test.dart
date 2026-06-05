// test/integration/checkout_flow_test.dart
//
// Integration-style test for the full checkout flow:
// cart -> subtotal -> coupon -> checkout -> order created -> cart cleared

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/models/models.dart';

// -- Fixture helpers ----------------------------------------------------------

EquipmentItem _makeEquipment({
  String id = 'eq1',
  String name = 'Oxygen Concentrator',
  double? price = 25000,
  double? rentalPrice = 3000,
}) {
  return EquipmentItem(
    id: id,
    name: name,
    brand: 'Philips',
    category: 'Equipment',
    availableForSale: true,
    availableForRent: true,
    price: price,
    rentalPrice: rentalPrice,
  );
}

// -- Tests --------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('full checkout flow: add items, verify subtotal, apply coupon, checkout, verify order, verify cart cleared', () {
    final cart = CartProvider();
    final orders = OrdersProvider();

    // 1. Add 2 equipment items
    final eq1 = _makeEquipment(id: 'bp-monitor', name: 'BP Monitor', price: 3000);
    final eq2 = _makeEquipment(id: 'nebulizer', name: 'Nebulizer', price: 2500);
    cart.addItem(eq1);
    cart.addItem(eq2);
    expect(cart.itemCount, 2);

    // 2. Add 1 service
    cart.addService(
      serviceId: 'svc-nurse-12h',
      serviceName: 'Nursing Care 12hr',
      category: 'Nursing',
      price: 4500,
    );
    expect(cart.itemCount, 3);

    // 3. Verify subtotal calculation
    // 3000 + 2500 + 4500 = 10000
    expect(cart.subtotal, 10000);

    // 4. Apply WELCOME10 coupon (10% discount)
    final discount = (cart.subtotal * 0.10).round();
    expect(discount, 1000);
    final discountedTotal = cart.subtotal - discount;
    expect(discountedTotal, 9000);

    // 5. Checkout: create order in OrdersProvider
    final bookingNumber = OrdersProvider.generateBookingNumber();
    orders.addOrder(
      items: cart.items.toList(),
      totalAmount: discountedTotal,
      bookingNumber: bookingNumber,
    );

    // 6. Verify OrdersProvider has the order
    expect(orders.orders.length, 1);
    final order = orders.orders.first;
    expect(order['totalAmount'], 9000);
    expect(order['status'], 'confirmed');
    expect((order['items'] as List).length, 3);

    // 7. Verify booking number format
    // Updated to 7-digit timestamp suffix (was 5-digit random); see
    // orders_provider.dart::generateBookingNumber which now uses the last 7
    // digits of millisecondsSinceEpoch to reduce collision probability.
    expect(bookingNumber, matches(RegExp(r'^HPL-BOOK-\d{7}$')));
    expect(order['id'], bookingNumber);

    // 8. Clear cart after checkout
    cart.clear();
    expect(cart.isEmpty, isTrue);
    expect(cart.itemCount, 0);
    expect(cart.subtotal, 0);
  });
}
