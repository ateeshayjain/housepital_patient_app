import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';

/// Local (offline / demo-mode) action sink for the assistant.
///
/// The app is demo-first: every other feature works without a backend
/// (CartProvider is a local cart, OrdersProvider records quote-pending
/// bookings in SharedPreferences). This class gives the assistant executor
/// the same local capabilities so demoed actions WORK when
/// `api.housepital.in` is unreachable:
///   - equipment search over `assets/equipment_catalog.json`
///   - a real cart add (identical to the catalog ADD button)
///   - a real quote-pending service request (identical to the quote-first
///     booking path in service_booking_screen → OrdersProvider.addOrder)
///
/// Business rule: manpower prices are NEVER shown — service requests created
/// here are quote-pending with totalAmount 0 ("price confirmed on call").
/// Equipment prices ARE shown (Blinkit-style catalog pricing).
class AssistantLocalActions {
  final CartProvider cart;
  final OrdersProvider orders;

  /// Catalog loader — defaults to the bundled equipment catalog asset.
  /// Injectable so tests can supply a fixed list (no rootBundle needed).
  final Future<List<EquipmentItem>> Function() loadCatalog;

  AssistantLocalActions({
    required this.cart,
    required this.orders,
    Future<List<EquipmentItem>> Function()? loadCatalog,
  }) : loadCatalog = loadCatalog ?? _loadFromAssets;

  static Future<List<EquipmentItem>> _loadFromAssets() async {
    final raw = await rootBundle.loadString('assets/equipment_catalog.json');
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => EquipmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<EquipmentItem>? _cache;

  Future<List<EquipmentItem>> _catalog() async => _cache ??= await loadCatalog();

  /// Keyword search over the equipment catalog. Returns the best match or
  /// null. Scoring favours items that match more query tokens, then items
  /// with a real price (sellable without the Reserve flow), then shorter
  /// names ("Nebulizer" beats "Nebulizer N10" for query "nebulizer").
  Future<EquipmentItem?> findEquipment(String query) async {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length > 1)
        .toList();
    if (tokens.isEmpty) return null;

    final items = await _catalog();
    EquipmentItem? best;
    var bestScore = 0;
    for (final item in items) {
      if (item.status != 'Active') continue;
      final hay = '${item.name} ${item.brand}'.toLowerCase();
      final hayWords = hay.split(RegExp(r'[^a-z0-9]+'));
      var score = 0;
      var matchedTokens = 0;
      for (final tok in tokens) {
        if (hay.contains(tok)) {
          score += 2; // substring hit, e.g. "nebulizer" in "Nebulizer N10"
          matchedTokens++;
        } else if (tok.length >= 4 &&
            hayWords.any((w) => w.startsWith(tok) || tok.startsWith(w))) {
          score += 1; // prefix hit, e.g. "concentrator" ~ "concentrators"
          matchedTokens++;
        }
      }
      // Require at least half the tokens to land — avoids wild guesses.
      if (matchedTokens == 0 || matchedTokens * 2 < tokens.length) continue;
      final betterTie = score == bestScore &&
          best != null &&
          _tieBreaksOver(item, best);
      if (score > bestScore || betterTie) {
        bestScore = score;
        best = item;
      }
    }
    return best;
  }

  /// On equal score prefer a priced, shorter-named item.
  static bool _tieBreaksOver(EquipmentItem a, EquipmentItem b) {
    final aPriced = (a.price ?? 0) > 0;
    final bPriced = (b.price ?? 0) > 0;
    if (aPriced != bPriced) return aPriced;
    return a.name.length < b.name.length;
  }

  /// Real local cart add — same effect as the catalog ADD button.
  void addEquipmentToCart(EquipmentItem item) => cart.addItem(item);

  static const Map<String, String> _categoryNames = {
    'doctor': 'Doctor Consultation',
    'nursing': 'Nursing Care',
    'caretaker': 'Caretaker Service',
    'physiotherapy': 'Physiotherapy',
  };

  /// Creates the SAME local quote-pending request the normal quote-first
  /// booking flow creates (see service_booking_screen._confirmQuoteBooking):
  /// an OrdersProvider order with `quotePending: true`, totalAmount 0, and a
  /// zero-price service CartItem. Returns the booking number for the reply.
  String createServiceRequest({required String category, bool renewal = false}) {
    final display = _categoryNames[category] ??
        (category.isEmpty ? 'Care service' : category);
    final bookingNumber = orders.generateUniqueBookingNumber();
    final item = CartItem(
      equipmentId: 'assistant-$category',
      name: renewal ? '$display (renewal)' : display,
      brand: category,
      unitPrice: 0, // quote pending — price confirmed on call before payment
      isService: true,
      scheduledDate: DateTime.now(),
      scheduledSlot: 'Care team will call to schedule',
      serviceNotes: 'Requested via Sahayak assistant',
    );
    orders.addOrder(
      items: [item],
      totalAmount: 0,
      bookingNumber: bookingNumber,
      quotePending: true,
    );
    return bookingNumber;
  }
}
