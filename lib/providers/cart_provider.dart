import 'package:flutter/material.dart';
import '../models/models.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => Map.unmodifiable(_items);
  int get itemCount => _items.values.fold(0, (sum, ci) => sum + ci.quantity);
  bool get isEmpty => _items.isEmpty;

  double get subtotal =>
      _items.values.fold(0.0, (sum, ci) => sum + ci.lineTotal);

  // Delivery charge — free above ₹999
  double get deliveryCharge => subtotal >= 999 ? 0 : 49;

  double get total => subtotal + deliveryCharge;

  void addItem(EquipmentItem item, {bool isRental = false, int rentalMonths = 1}) {
    final key = '${item.id}_${isRental ? "rent" : "buy"}';
    if (_items.containsKey(key)) {
      _items[key]!.quantity++;
    } else {
      _items[key] = CartItem(
        item: item,
        isRental: isRental,
        rentalMonths: rentalMonths,
      );
    }
    notifyListeners();
  }

  void removeItem(String cartKey) {
    _items.remove(cartKey);
    notifyListeners();
  }

  void updateQuantity(String cartKey, int quantity) {
    if (!_items.containsKey(cartKey)) return;
    if (quantity <= 0) {
      _items.remove(cartKey);
    } else {
      _items[cartKey]!.quantity = quantity;
    }
    notifyListeners();
  }

  void updateRentalMonths(String cartKey, int months) {
    if (!_items.containsKey(cartKey)) return;
    if (months < 1) months = 1;
    _items[cartKey]!.rentalMonths = months;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
