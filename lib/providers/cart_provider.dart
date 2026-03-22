import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class CartProvider extends ChangeNotifier {
  static const _cartKey = 'housepital_cart_items';
  static const _savedKey = 'housepital_saved_items';

  final Map<String, CartItem> _items = {};
  final Map<String, CartItem> _savedForLater = {};

  CartProvider() {
    _loadPersistedCart();
  }

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
    _persistCart();
  }

  void removeItem(String cartKey) {
    _items.remove(cartKey);
    notifyListeners();
    _persistCart();
  }

  void updateQuantity(String cartKey, int quantity) {
    if (!_items.containsKey(cartKey)) return;
    if (quantity <= 0) {
      _items.remove(cartKey);
    } else {
      _items[cartKey]!.quantity = quantity;
    }
    notifyListeners();
    _persistCart();
  }

  void updateRentalMonths(String cartKey, int months) {
    if (!_items.containsKey(cartKey)) return;
    if (months < 1) months = 1;
    _items[cartKey]!.rentalMonths = months;
    notifyListeners();
    _persistCart();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _persistCart();
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
    _persistCart();
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
    _persistCart();
  }

  /// Move a cart item into the saved-for-later list.
  void moveToSaved(String cartKey) {
    final ci = _items.remove(cartKey);
    if (ci == null) return;
    _savedForLater[cartKey] = ci;
    notifyListeners();
    _persistCart();
  }

  /// Remove a saved-for-later item entirely.
  void removeSaved(String savedKey) {
    _savedForLater.remove(savedKey);
    notifyListeners();
    _persistCart();
  }

  /// Clear all saved-for-later items.
  void clearSaved() {
    _savedForLater.clear();
    notifyListeners();
    _persistCart();
  }

  // ── Persistence ─────────────────────────────────────────────

  Map<String, dynamic> _cartItemToJson(String key, CartItem ci) => {
        'key': key,
        'item': ci.item.toJson(),
        'isRental': ci.isRental,
        'quantity': ci.quantity,
        'rentalMonths': ci.rentalMonths,
      };

  CartItem? _cartItemFromJson(Map<String, dynamic> json) {
    try {
      return CartItem(
        item: EquipmentItem.fromJson(json['item'] as Map<String, dynamic>),
        isRental: json['isRental'] as bool? ?? false,
        quantity: json['quantity'] as int? ?? 1,
        rentalMonths: json['rentalMonths'] as int? ?? 1,
      );
    } catch (_) {
      return null; // Skip corrupt data
    }
  }

  Future<void> _persistCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cartList = _items.entries
          .map((e) => _cartItemToJson(e.key, e.value))
          .toList();
      await prefs.setString(_cartKey, json.encode(cartList));

      final savedList = _savedForLater.entries
          .map((e) => _cartItemToJson(e.key, e.value))
          .toList();
      await prefs.setString(_savedKey, json.encode(savedList));
    } catch (e) {
      debugPrint('Cart persist error: $e');
    }
  }

  Future<void> _loadPersistedCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cartStr = prefs.getString(_cartKey);
      if (cartStr != null) {
        final List<dynamic> cartList = json.decode(cartStr);
        for (final entry in cartList) {
          final map = entry as Map<String, dynamic>;
          final key = map['key'] as String?;
          final ci = _cartItemFromJson(map);
          if (key != null && ci != null) {
            _items[key] = ci;
          }
        }
      }

      final savedStr = prefs.getString(_savedKey);
      if (savedStr != null) {
        final List<dynamic> savedList = json.decode(savedStr);
        for (final entry in savedList) {
          final map = entry as Map<String, dynamic>;
          final key = map['key'] as String?;
          final ci = _cartItemFromJson(map);
          if (key != null && ci != null) {
            _savedForLater[key] = ci;
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Cart load error: $e');
      // Ignore corrupt data — start fresh
    }
  }
}
