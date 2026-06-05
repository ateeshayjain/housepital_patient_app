// Pricing utilities for Housepital commission, GST, and refund calculations.
//
// Business rules:
// - Manpower services (caretaker, nursing_deployment, japa, nanny) have NO commission.
// - Visit/instant services charge a commission to Housepital.
// - Monthly plan: flat ₹12,000/month commission.
// - 3-month plan (one-time): flat ₹30,000 commission.
// - 3-month plan with EMI: ₹10,000 × 3 months.
// - Equipment discount: 30% off for 3-month customers.
// - GST: 18% on service price.

import '../models/models.dart';

class PricingResult {
  final double commission;
  final bool isEmi;
  final int emiCount;
  final double emiAmount;

  const PricingResult({
    required this.commission,
    this.isEmi = false,
    this.emiCount = 0,
    this.emiAmount = 0,
  });
}

/// Services that are manpower-based and do NOT charge commission.
const Set<String> _manpowerServices = {
  'caretaker',
  'nursing_deployment',
  'japa',
  'nanny',
};

/// Calculate Housepital commission for a service plan.
///
/// [serviceType] — e.g. 'nursing_visit', 'caretaker', 'physio_visit'.
/// [planType] — 'monthly', '3_month', '3_month_emi'.
///
/// Returns [PricingResult] with commission details.
/// Throws [ArgumentError] for unknown plan types.
PricingResult calculateCommission({
  required String serviceType,
  required String planType,
}) {
  // Manpower services: direct salary, NO commission
  if (_manpowerServices.contains(serviceType)) {
    return const PricingResult(commission: 0);
  }

  switch (planType) {
    case 'monthly':
      return const PricingResult(commission: 12000);
    case '3_month':
      return const PricingResult(commission: 30000);
    case '3_month_emi':
      return const PricingResult(
        commission: 30000,
        isEmi: true,
        emiCount: 3,
        emiAmount: 10000,
      );
    default:
      throw ArgumentError('Unknown plan type: $planType');
  }
}

/// Calculate GST at 18% on the given service price.
///
/// Returns the GST amount (not total inclusive price).
/// Throws [ArgumentError] if [servicePrice] is negative.
double calculateGst(double servicePrice) {
  if (servicePrice < 0) {
    throw ArgumentError('Service price cannot be negative: $servicePrice');
  }
  return double.parse((servicePrice * 0.18).toStringAsFixed(2));
}

/// Calculate equipment discount for 3-month customers.
///
/// 3-month plan customers get 30% off equipment.
/// Returns the discounted price.
double calculateEquipmentDiscount({
  required double originalPrice,
  required bool isThreeMonthCustomer,
}) {
  if (originalPrice < 0) {
    throw ArgumentError('Original price cannot be negative: $originalPrice');
  }
  if (!isThreeMonthCustomer) return originalPrice;
  return double.parse((originalPrice * 0.70).toStringAsFixed(2));
}

/// Calculate refund amount based on days consumed and total plan days.
///
/// Refund = (remainingDays / totalDays) * totalPaid
/// Minimum non-refundable amount is ₹500.
double calculateRefund({
  required double totalPaid,
  required int totalDays,
  required int consumedDays,
  double minimumNonRefundable = 500,
}) {
  if (totalPaid < 0) throw ArgumentError('totalPaid cannot be negative');
  if (totalDays <= 0) throw ArgumentError('totalDays must be positive');
  if (consumedDays < 0) throw ArgumentError('consumedDays cannot be negative');

  if (consumedDays >= totalDays) return 0;

  final remainingDays = totalDays - consumedDays;
  final proportionalRefund = (remainingDays / totalDays) * totalPaid;
  final maxRefund = totalPaid - minimumNonRefundable;

  if (maxRefund <= 0) return 0;
  return double.parse(
    (proportionalRefund > maxRefund ? maxRefund : proportionalRefund)
        .toStringAsFixed(2),
  );
}

/// audit M-14: GST is computed per line item, not as a flat 18% on the whole
/// subtotal. Each [CartItem] exposes a [CartItem.gstRate] getter that returns:
///   - 0.00 for healthcare manpower (exempt under Notification 12/2017)
///   - 0.05 for diagnostic lab tests
///   - 0.18 for durable medical equipment
///
/// The cart-level [discount] is prorated across line items by share of
/// subtotal, so a coupon doesn't change any line's effective per-line rate.
/// Returns 0 for empty carts (invoice flow already bakes GST into the grand total).
int computeCartGst(List<CartItem> items, {int discount = 0}) {
  if (items.isEmpty) return 0;
  final subtotal = items.fold<int>(0, (s, i) => s + i.lineTotal);
  if (subtotal <= 0) return 0;
  return items.fold<int>(0, (sum, item) {
    final share = item.lineTotal / subtotal;
    final discountedLine = item.lineTotal - (discount * share);
    if (discountedLine <= 0) return sum;
    return sum + (discountedLine * item.gstRate).round();
  });
}
