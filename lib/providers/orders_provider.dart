import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class OrdersProvider extends ChangeNotifier {
  static const _ordersKey = 'housepital_orders';
  static const _assessmentsKey = 'housepital_assessments';

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _assessments = [];

  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);
  List<Map<String, dynamic>> get assessments => List.unmodifiable(_assessments);

  OrdersProvider() {
    _loadFromStorage();
  }

  /// Generate a booking number like HPL-BOOK-1234567.
  /// Uses a millisecond timestamp suffix (last 7 digits) to avoid the collisions
  /// the previous 5-digit random approach was prone to, and salts with a small
  /// random number so two near-simultaneous calls in the same millisecond still differ.
  static String generateBookingNumber() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = ts.substring(ts.length - 7);
    return 'HPL-BOOK-$suffix';
  }

  /// Generate a booking number guaranteed not to collide with any existing order
  /// in this provider's in-memory list. Falls back to extra randomness if needed.
  String generateUniqueBookingNumber() {
    String candidate = generateBookingNumber();
    int safety = 0;
    while (_orders.any((o) => o['id'] == candidate) && safety < 5) {
      candidate = '${generateBookingNumber()}-${Random().nextInt(99)}';
      safety++;
    }
    return candidate;
  }

  /// Add a new order (called after successful checkout)
  void addOrder({
    required List<CartItem> items,
    required int totalAmount,
    required String bookingNumber,
  }) {
    _orders.insert(0, {
      'id': bookingNumber,
      'items': items.map((i) => i.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': 'confirmed',
      'createdAt': DateTime.now().toIso8601String(),
      'type': items.any((i) => i.isService) ? 'mixed' : 'equipment',
    });
    _persistAndNotify();
  }

  /// Add assessment request
  void addAssessment({
    required String serviceId,
    required String serviceName,
    required Map<String, dynamic> formData,
  }) {
    _assessments.insert(0, {
      'id':
          'HPL-ASR-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      'serviceId': serviceId,
      'serviceName': serviceName,
      'status': 'submitted',
      'createdAt': DateTime.now().toIso8601String(),
      'formData': formData,
    });
    _persistAndNotify();
  }

  /// Update order status
  void updateOrderStatus(String orderId, String newStatus) {
    final index = _orders.indexWhere((o) => o['id'] == orderId);
    if (index >= 0) {
      _orders[index] = {..._orders[index], 'status': newStatus};
      _persistAndNotify();
    }
  }

  /// Cancel assessment
  void cancelAssessment(String assessmentId) {
    final index = _assessments.indexWhere((a) => a['id'] == assessmentId);
    if (index >= 0) {
      _assessments[index] = {
        ..._assessments[index],
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
      };
      _persistAndNotify();
    }
  }

  /// Cancel order
  void cancelOrder(String orderId, String reason) {
    final index = _orders.indexWhere((o) => o['id'] == orderId);
    if (index >= 0) {
      _orders[index] = {
        ..._orders[index],
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledAt': DateTime.now().toIso8601String(),
      };
      _persistAndNotify();
    }
  }

  /// Persist to SharedPreferences and notify listeners
  Future<void> _persistAndNotify() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ordersKey, jsonEncode(_orders));
      await prefs.setString(_assessmentsKey, jsonEncode(_assessments));
    } catch (e) {
      debugPrint('OrdersProvider: failed to persist: $e');
    }
  }

  /// Load from SharedPreferences
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final ordersJson = prefs.getString(_ordersKey);
      if (ordersJson != null) {
        final decoded = jsonDecode(ordersJson) as List;
        _orders = decoded.cast<Map<String, dynamic>>();
      }

      final assessmentsJson = prefs.getString(_assessmentsKey);
      if (assessmentsJson != null) {
        final decoded = jsonDecode(assessmentsJson) as List;
        _assessments = decoded.cast<Map<String, dynamic>>();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('OrdersProvider: failed to load: $e');
      notifyListeners();
    }
  }
}
