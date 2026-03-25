import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class CartProvider extends ChangeNotifier {
  static const _cartKey = 'housepital_cart_items';
  static const _savedKey = 'housepital_saved_items';

  final List<CartItem> _items = [];
  final List<CartItem> _savedItems = [];

  List<CartItem> get items => List.unmodifiable(_items);
  List<CartItem> get savedItems => List.unmodifiable(_savedItems);
  int get itemCount => _items.length;
  int get savedCount => _savedItems.length;
  bool get isEmpty => _items.isEmpty;
  bool get hasSavedItems => _savedItems.isNotEmpty;

  /// Subtotal in rupees.
  int get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);

  /// Delivery: free above 999.
  int get deliveryCharge => subtotal >= 999 ? 0 : 49;

  /// Total.
  int get total => subtotal + deliveryCharge;

  // ── Cart operations ─────────────────────────────────────────

  void addItem(EquipmentItem equipment, {bool isRental = false, int rentalMonths = 1}) {
    debugPrint('CartProvider.addItem: ${equipment.name}, id=${equipment.id}, isRental=$isRental, price=${equipment.price}, rentalPrice=${equipment.rentalPrice}');
    // Check if already in cart (same equipment + same mode)
    final existingIndex = _items.indexWhere(
      (i) => i.equipmentId == equipment.id && i.isRental == isRental,
    );
    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + 1,
      );
    } else {
      _items.add(CartItem(
        equipmentId: equipment.id,
        name: equipment.name,
        brand: equipment.brand,
        imageUrl: equipment.imageUrl,
        unitPrice: isRental
            ? (equipment.rentalPrice?.toInt() ?? 0)
            : (equipment.price?.toInt() ?? 0),
        mrp: equipment.mrp?.toInt(),
        isRental: isRental,
        rentalMonths: rentalMonths,
        quantity: 1,
      ));
    }
    // Remove from saved list if it was there
    _savedItems.removeWhere(
      (i) => i.equipmentId == equipment.id && i.isRental == isRental,
    );
    _persist();
    notifyListeners();
  }

  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    _persist();
    notifyListeners();
  }

  void updateQuantity(int index, int qty) {
    if (index < 0 || index >= _items.length) return;
    if (qty <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: qty);
    }
    _persist();
    notifyListeners();
  }

  void updateRentalMonths(int index, int months) {
    if (index < 0 || index >= _items.length) return;
    if (months < 1) months = 1;
    _items[index] = _items[index].copyWith(rentalMonths: months);
    _persist();
    notifyListeners();
  }

  void saveForLater(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items.removeAt(index);
    // Avoid duplicates in saved list
    if (!_savedItems.any((i) => i.equipmentId == item.equipmentId && i.isRental == item.isRental)) {
      _savedItems.add(item);
    }
    _persist();
    notifyListeners();
  }

  void moveToCart(int index) {
    if (index < 0 || index >= _savedItems.length) return;
    final item = _savedItems.removeAt(index);
    // Check if already in cart
    final existingIndex = _items.indexWhere(
      (i) => i.equipmentId == item.equipmentId && i.isRental == item.isRental,
    );
    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + item.quantity,
      );
    } else {
      _items.add(item);
    }
    _persist();
    notifyListeners();
  }

  void removeSaved(int index) {
    if (index < 0 || index >= _savedItems.length) return;
    _savedItems.removeAt(index);
    _persist();
    notifyListeners();
  }

  void clearSaved() {
    _savedItems.clear();
    _persist();
    notifyListeners();
  }

  /// Convenience: save an equipment item directly to the saved list
  /// (used from equipment detail screen where the item is not yet in cart).
  void saveItemForLater(EquipmentItem equipment, {bool isRental = false, int rentalMonths = 1}) {
    // Remove from cart if it was there
    _items.removeWhere(
      (i) => i.equipmentId == equipment.id && i.isRental == isRental,
    );
    // Avoid duplicates in saved list
    if (!_savedItems.any((i) => i.equipmentId == equipment.id && i.isRental == isRental)) {
      _savedItems.add(CartItem(
        equipmentId: equipment.id,
        name: equipment.name,
        brand: equipment.brand,
        imageUrl: equipment.imageUrl,
        unitPrice: isRental
            ? (equipment.rentalPrice?.toInt() ?? 0)
            : (equipment.price?.toInt() ?? 0),
        mrp: equipment.mrp?.toInt(),
        isRental: isRental,
        rentalMonths: rentalMonths,
        quantity: 1,
      ));
    }
    _persist();
    notifyListeners();
  }

  bool isInCart(String equipmentId) =>
      _items.any((i) => i.equipmentId == equipmentId);

  bool isSaved(String equipmentId) =>
      _savedItems.any((i) => i.equipmentId == equipmentId);

  void clear() {
    _items.clear();
    _persist();
    notifyListeners();
  }

  // ── SharedPreferences persistence ─────────────────────────

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cartKey,
        json.encode(_items.map((i) => i.toJson()).toList()),
      );
      await prefs.setString(
        _savedKey,
        json.encode(_savedItems.map((i) => i.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Cart persist error: $e');
    }
  }

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cartStr = prefs.getString(_cartKey);
      if (cartStr != null) {
        final List<dynamic> cartList = json.decode(cartStr);
        for (final entry in cartList) {
          try {
            _items.add(CartItem.fromJson(entry as Map<String, dynamic>));
          } catch (_) {
            // Skip corrupt entries
          }
        }
      }

      final savedStr = prefs.getString(_savedKey);
      if (savedStr != null) {
        final List<dynamic> savedList = json.decode(savedStr);
        for (final entry in savedList) {
          try {
            _savedItems.add(CartItem.fromJson(entry as Map<String, dynamic>));
          } catch (_) {
            // Skip corrupt entries
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
