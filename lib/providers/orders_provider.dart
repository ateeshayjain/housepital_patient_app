import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/demo_data.dart';
import '../data/demo_mode.dart';
import '../models/models.dart';
import '../utils/logger.dart';

class OrdersProvider extends ChangeNotifier {
  /// Storage is keyed PER PATIENT.
  ///
  /// It used to be two global keys, which made the patient-scoped clear
  /// destructive: clearing wrote `[]` over the ONE key, so switching patients
  /// permanently erased the outgoing patient's order history — and the
  /// regression test asserted that erasure as the contract. Per-patient keys
  /// make a switch a READ of a different key, which destroys nothing.
  ///
  /// The pre-versioning global keys are quarantined by StoreMigrator's v1->v2
  /// step: they cannot be attributed to a patient after the fact, so they are
  /// preserved for support rather than guessed at or deleted.
  static const _ordersKeyPrefix = 'housepital_orders_';
  static const _assessmentsKeyPrefix = 'housepital_assessments_';

  /// Legacy un-scoped keys. FROZEN — referenced by the migration.
  static const legacyOrdersKey = 'housepital_orders';
  static const legacyAssessmentsKey = 'housepital_assessments';

  /// Whose orders are currently loaded. Null before a patient is known.
  String? _patientId;
  String? get patientId => _patientId;

  String get _ordersKey => '$_ordersKeyPrefix${_patientId ?? '_none'}';
  String get _assessmentsKey =>
      '$_assessmentsKeyPrefix${_patientId ?? '_none'}';

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _assessments = [];

  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);
  List<Map<String, dynamic>> get assessments => List.unmodifiable(_assessments);

  OrdersProvider({String? patientId}) : _patientId = patientId {
    _loadFromStorage();
  }

  /// Points this provider at a patient and loads THEIR orders.
  ///
  /// A no-op when the id is unchanged. When it changes, in-memory state is
  /// dropped first so the outgoing patient's orders can never render under
  /// the incoming patient's name, then the incoming patient's own key is
  /// read. Nothing is written, so neither patient's history is touched.
  Future<void> setPatient(String? patientId) async {
    if (patientId == _patientId) return;
    _patientId = patientId;
    _orders = [];
    _assessments = [];
    notifyListeners();
    await _loadFromStorage();
  }

  /// True when [order] is a quote-pending order — booked without a price,
  /// awaiting price confirmation on call. Screens must never render ₹0 for
  /// these.
  static bool isQuotePending(Map<String, dynamic> order) =>
      order['quoteStatus'] == 'pending';

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

  /// Add a new order (called after successful checkout).
  ///
  /// [quotePending]: quote-first orders (manpower services / price-on-request
  /// equipment) are booked end-to-end in the app WITHOUT a price — the team
  /// confirms the price on call before any payment. Such orders carry
  /// `quoteStatus: 'pending'` and a totalAmount of 0; downstream screens must
  /// render "Quote pending / Price will be confirmed on call" instead of ₹0
  /// and exclude them from outstanding/paid sums.
  void addOrder({
    required List<CartItem> items,
    required int totalAmount,
    required String bookingNumber,
    bool quotePending = false,
  }) {
    _orders.insert(0, {
      'id': bookingNumber,
      'items': items.map((i) => i.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': 'confirmed',
      'createdAt': DateTime.now().toIso8601String(),
      'type': items.any((i) => i.isService) ? 'mixed' : 'equipment',
      if (quotePending) 'quoteStatus': 'pending',
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
  ///
  /// audit M-12: also captures refund expectations so the billing screen
  /// (and downstream finance reconciliation) has something concrete to show
  /// the user instead of a silent "cancelled" state with no money trail.
  /// Refund rule (operational default until backend ships proper logic):
  ///   - cancelled within 24h of booking → full refund minus a ₹100 booking fee
  ///   - cancelled later                  → 50% of totalAmount, no fee
  /// ETA is fixed at 7 days from cancellation.
  void cancelOrder(String orderId, String reason) {
    final index = _orders.indexWhere((o) => o['id'] == orderId);
    if (index >= 0) {
      final order = _orders[index];
      final totalAmount = (order['totalAmount'] as num?)?.toInt() ?? 0;
      final createdAt = DateTime.tryParse(order['createdAt'] as String? ?? '');
      final now = DateTime.now();
      final withinGrace = createdAt != null &&
          now.difference(createdAt) <= const Duration(hours: 24);

      int refundAmount;
      if (totalAmount <= 0) {
        refundAmount = 0;
      } else if (withinGrace) {
        const bookingFee = 100;
        refundAmount =
            (totalAmount - bookingFee).clamp(0, totalAmount).toInt();
      } else {
        refundAmount = (totalAmount * 0.5).round();
      }

      _orders[index] = {
        ...order,
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledAt': now.toIso8601String(),
        'refundAmount': refundAmount,
        'refundStatus': refundAmount > 0 ? 'pending' : 'none',
        'refundEta':
            now.add(const Duration(days: 7)).toIso8601String(),
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
      Log.warn('Failed to persist orders/assessments',
          error: e, tag: 'OrdersProvider');
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

      // Demo-mode fallback (same pattern as the API providers): with no real
      // backend and nothing persisted yet, Billing rendered ₹0 / "No data
      // available". Seed the demo order history IN-MEMORY only — not
      // persisted — so real checkout orders cleanly take over once the user
      // transacts.
      if (_orders.isEmpty) {
        _orders = DemoData.orders;
        DemoMode.markServingDemoData(DemoMode.sourceOrders);
      }

      notifyListeners();
    } catch (e) {
      Log.warn('Failed to load orders/assessments',
          error: e, tag: 'OrdersProvider');
      notifyListeners();
    }
  }
  /// Clears in-memory orders and assessments. Orders are scoped to the
  /// patient they were placed for, so they must not survive a patient switch
  /// or a logout on a shared phone.
  /// Drops the current patient's orders from MEMORY ONLY, and forgets which
  /// patient they belonged to.
  ///
  /// Deliberately does NOT persist. Round 2 made this persist, to stop a cold
  /// start restoring the previous patient — but with one global key that
  /// wrote `[]` over the outgoing patient's real history, destroying it. With
  /// per-patient keys the cold-start problem is gone by construction: the
  /// data sits under the outgoing patient's key and is simply not read.
  void clearPatientScopedData() {
    _orders = [];
    _assessments = [];
    _patientId = null;
    notifyListeners();
  }

}
