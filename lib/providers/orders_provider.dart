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

  /// Generate a booking number like HPL-BOOK-12345
  static String generateBookingNumber() {
    final random = Random();
    final digits = (10000 + random.nextInt(90000)).toString();
    return 'HPL-BOOK-$digits';
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
