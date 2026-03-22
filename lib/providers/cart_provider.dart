import 'package:flutter/material.dart';
import '../models/models.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  final Map<String, CartItem> _savedForLater = {};

  Map<String, CartItem> get items => Map.unmodifiable(_items);
  Map<String, CartItem> get savedForLater => Map.unmodifiable(_savedForLater);

  int get itemCount => _items.values.fold(0, (sum, ci) => sum + ci.quantity);
  int get savedCount => _savedForLater.length;
  bool get isEmpty => _items.isEmpty;
  bool get hasSavedItems => _savedForLater.isNotEmpty;

  double get subtotal =>
      _items.values.fold(0.0, (sum, ci) => sum + ci.lineTotal);

  // Delivery charge — free above ₹999
  double get deliveryCharge => subtotal >= 999 ? 0 : 49;

  double get total => subtotal + deliveryCharge;

  // ── Helper getters ──────────────────────────────────────────

  /// Check if any variant of this service/equipment is already in the cart.
  bool isInCart(String serviceId) {
    return _items.keys.any((key) => key.startsWith('${serviceId}_'));
  }

  /// Check if any variant of this service/equipment is saved for later.
  bool isSaved(String serviceId) {
    return _savedForLater.keys.any((key) => key.startsWith('${serviceId}_'));
  }

  // ── Cart operations ─────────────────────────────────────────

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
    // Remove from saved list if it was there
    _savedForLater.remove(key);
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

  // ── Save for Later operations ───────────────────────────────

  /// Save an equipment item for later (wishlist).
  void saveForLater(EquipmentItem item, {bool isRental = false, int rentalMonths = 1}) {
    final key = '${item.id}_${isRental ? "rent" : "buy"}';
    if (!_savedForLater.containsKey(key)) {
      _savedForLater[key] = CartItem(
        item: item,
        isRental: isRental,
        rentalMonths: rentalMonths,
      );
    }
    // Remove from cart if it was there
    _items.remove(key);
    notifyListeners();
  }

  /// Move an item from the saved list into the cart.
  void moveToCart(String savedKey) {
    final ci = _savedForLater.remove(savedKey);
    if (ci == null) return;
    if (_items.containsKey(savedKey)) {
      _items[savedKey]!.quantity += ci.quantity;
    } else {
      _items[savedKey] = ci;
    }
    notifyListeners();
  }

  /// Move a cart item into the saved-for-later list.
  void moveToSaved(String cartKey) {
    final ci = _items.remove(cartKey);
    if (ci == null) return;
    _savedForLater[cartKey] = ci;
    notifyListeners();
  }

  /// Remove a saved-for-later item entirely.
  void removeSaved(String savedKey) {
    _savedForLater.remove(savedKey);
    notifyListeners();
  }

  /// Clear all saved-for-later items.
  void clearSaved() {
    _savedForLater.clear();
    notifyListeners();
  }
}
