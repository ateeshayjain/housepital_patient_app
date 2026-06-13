import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';
import '../../services/api_service.dart';
import '../../utils/helpers.dart';
import '../../utils/permissions.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _couponController = TextEditingController();
  String? _couponError;
  String? _appliedCouponCode;
  int _discountAmount = 0;
  bool _validatingCoupon = false;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon(CartProvider cart) async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _couponError = 'Please enter a coupon code');
      return;
    }

    setState(() {
      _validatingCoupon = true;
      _couponError = null;
    });

    // Check hardcoded test coupon first (offline support)
    if (code == 'WELCOME10') {
      final subtotal = cart.subtotal;
      int discount = (subtotal * 10 / 100).round();
      if (discount > 500) discount = 500;
      setState(() {
        _validatingCoupon = false;
        _appliedCouponCode = code;
        _discountAmount = discount;
        _couponError = null;
      });
      return;
    }

    // Try backend validation
    try {
      final coupon = await ApiService().validateCoupon(code, 'equipment', cart.subtotal);
      final discount = coupon.calculateDiscount(cart.subtotal);
      if (discount > 0) {
        setState(() {
          _validatingCoupon = false;
          _appliedCouponCode = code;
          _discountAmount = discount;
          _couponError = null;
        });
      } else {
        setState(() {
          _validatingCoupon = false;
          _couponError = 'Coupon not applicable to this order';
        });
      }
    } catch (e) {
      setState(() {
        _validatingCoupon = false;
        _couponError = 'Invalid or expired coupon code';
      });
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _discountAmount = 0;
      _couponError = null;
      _couponController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        showCart: false, // purchase funnel — cart icon would loop into itself
        title: Consumer<CartProvider>(
          builder: (_, cart, _) => Text(
            cart.isEmpty ? 'My Cart' : 'My Cart (${cart.itemCount} items)',
          ),
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (_, cart, _) => cart.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => _confirmClear(context, cart),
                    child: Text('Clear',
                        style: TextStyle(color: context.hc.greyLight)),
                  ),
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          // audit M-17: removed debugPrint from build method — build logs
          // should never run in production and the noise was masking real signals.
          if (cart.isEmpty && !cart.hasSavedItems) {
            return _buildEmptyCart(context);
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Cart items
                    if (cart.isEmpty && cart.hasSavedItems)
                      Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Your cart is empty, but you have saved items below.',
                          style: TextStyle(color: context.hc.greyLight),
                        ),
                      ),
                    for (int i = 0; i < cart.items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CartItemCard(index: i, cartItem: cart.items[i]),
                      ),

                    // Saved for Later section
                    if (cart.hasSavedItems) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.bookmark_outline,
                                size: 20, color: context.hc.greyLight),
                            const SizedBox(width: 8),
                            Text(
                              'Saved for Later (${cart.savedCount})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (int i = 0; i < cart.savedItems.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SavedItemCard(
                              index: i, cartItem: cart.savedItems[i]),
                        ),
                    ],
                  ],
                ),
              ),
              if (!cart.isEmpty) _buildOrderSummary(context, cart),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 80, color: context.hc.greyLight),
          const SizedBox(height: 16),
          const Text('Your cart is empty',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Browse services & equipment to add items',
              style: TextStyle(color: context.hc.greyLight)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Browse Products'),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.hc.orangeLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hc.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_offer_outlined,
                  size: 18, color: HousepitalColors.orange),
              SizedBox(width: 8),
              Text('Have a coupon?',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          if (_appliedCouponCode != null)
            // Applied coupon display
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.hc.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        context.hc.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 18, color: context.hc.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_appliedCouponCode!,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.hc.success)),
                        Text(
                            'You save ${DateHelper.formatCurrency(_discountAmount)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: context.hc.success)),
                      ],
                    ),
                  ),
                  // WCAG 2.5.5 — IconButton enforces 48x48 tap target.
                  IconButton(
                    onPressed: _removeCoupon,
                    icon: Icon(Icons.close,
                        size: 18, color: context.hc.greyLight),
                    tooltip: 'Remove coupon',
                    constraints: const BoxConstraints(
                        minWidth: 44, minHeight: 44),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            )
          else
            // Coupon input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      // WCAG 3.3.2 — persistent label that survives typing.
                      labelText: 'Coupon code',
                      hintText: 'Enter coupon code',
                      hintStyle: const TextStyle(fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: context.hc.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: context.hc.divider),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _validatingCoupon
                        ? null
                        : () => _applyCoupon(cart),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HousepitalColors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: _validatingCoupon
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Apply',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          if (_couponError != null) ...[
            const SizedBox(height: 6),
            Text(_couponError!,
                style: TextStyle(
                    fontSize: 12, color: context.hc.error)),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderSummary(BuildContext context, CartProvider cart) {
    final adjustedTotal = cart.subtotal - _discountAmount + cart.deliveryCharge;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Coupon section
            _buildCouponSection(cart),
            // Subtotal
            _summaryRow(
                'Subtotal (${cart.itemCount} items)',
                DateHelper.formatCurrency(cart.subtotal)),
            const SizedBox(height: 6),
            // Discount
            if (_discountAmount > 0) ...[
              _summaryRow(
                'Coupon Discount',
                '- ${DateHelper.formatCurrency(_discountAmount)}',
                valueColor: context.hc.success,
              ),
              const SizedBox(height: 6),
            ],
            // Delivery
            _summaryRow(
              'Delivery',
              cart.deliveryCharge == 0
                  ? 'FREE'
                  : DateHelper.formatCurrency(cart.deliveryCharge),
              valueColor: cart.deliveryCharge == 0
                  ? context.hc.success
                  : null,
            ),
            if (cart.deliveryCharge == 0)
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Free delivery on orders above Rs.999',
                      style: TextStyle(
                          fontSize: 11,
                          color: context.hc.success)),
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  DateHelper.formatCurrency(adjustedTotal),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.hc.orangeText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Checkout button — gated by the `pay` permission. Family members
            // and patients see a "Request Booking" button that sends the cart
            // to the primary contact for approval.
            Builder(builder: (context) {
              final role = context.watch<AppProvider>().currentUserRole;
              if (canUserPerform(role, UserAction.pay)) {
                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _checkout(context, cart, adjustedTotal),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: Text(
                      'Checkout (${DateHelper.formatCurrency(adjustedTotal)})',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HousepitalColors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                );
              }
              if (canUserPerform(role, UserAction.requestBooking)) {
                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _showRequestBookingModal(context),
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text(
                      'Request Booking',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.hc.info,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                );
              }
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: context.hc.greyLighter,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline,
                        size: 16, color: context.hc.greyLight),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ask your family caregiver to place this order.',
                        style: TextStyle(
                            fontSize: 13, color: context.hc.grey),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14, color: context.hc.greyLight)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? context.hc.black)),
      ],
    );
  }

  /// Stub: surface a confirmation that the request was "sent" to the primary
  /// contact. No real persistence yet — the backend wiring lands in the
  /// next iteration.
  void _showRequestBookingModal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: context.hc.success),
            SizedBox(width: 8),
            Expanded(child: Text('Request Sent')),
          ],
        ),
        content: const Text(
          "Booking request sent to your primary contact for approval. "
          "They'll receive a notification to confirm and pay.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _checkout(BuildContext context, CartProvider cart, int adjustedTotal) {
    // Build description for payment screen
    final itemNames =
        cart.items.map((ci) => ci.name).take(3).join(', ');
    final description = cart.itemCount <= 3
        ? itemNames
        : '$itemNames +${cart.itemCount - 3} more';

    // Always go through payment screen — it handles web/mobile differences
    Navigator.pushNamed(context, '/payment', arguments: {
      'amount': adjustedTotal,
      'description': description,
      'invoice_id': null,
      'cartItems': cart.items.toList(),
    }).then((result) {
      // If payment was successful, save order, clear cart, show confirmation
      if (result == true) {
        if (!context.mounted) return;
        final items = cart.items.toList();
        // audit M-3: use the instance method `generateUniqueBookingNumber` so the
        // booking id is guaranteed not to collide with any existing order in the
        // provider's in-memory list (PR #10 fix; the static call was a regression).
        final ordersProvider = context.read<OrdersProvider>();
        final bookingNumber = ordersProvider.generateUniqueBookingNumber();

        // Persist order to OrdersProvider
        ordersProvider.addOrder(
          items: items,
          totalAmount: adjustedTotal,
          bookingNumber: bookingNumber,
        );

        cart.clear();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // audit M-2: propagate booking number so the confirmation screen
        // does not regenerate a different one (was a UX/order-id mismatch).
        Navigator.pushReplacementNamed(context, '/booking-confirmation',
            arguments: {
              'cartItems': items,
              'totalAmount': adjustedTotal,
              'bookingNumber': bookingNumber,
            });
      }
    });
  }

  // audit M-13: replaced hand-rolled AlertDialog with shared
  // confirmDestructiveAction helper so the Clear Cart action gets the same
  // red CTA, haptic, and string format as other destructive flows. This is
  // especially important here — clearing the cart can discard ₹10k+ of items.
  Future<void> _confirmClear(BuildContext context, CartProvider cart) async {
    final ok = await confirmDestructiveAction(
      context,
      title: 'Clear cart?',
      message: 'This will remove all items from your cart.',
      confirmLabel: 'Clear',
    );
    if (!ok || !mounted) return;
    cart.clear();
    _removeCoupon();
  }
}

// ====================================================================
//  CART ITEM CARD
// ====================================================================

class _CartItemCard extends StatelessWidget {
  final int index;
  final CartItem cartItem;

  const _CartItemCard({required this.index, required this.cartItem});

  String _formatSlotLabel(String? slot) {
    switch (slot) {
      case 'morning':
        return 'Morning (9 AM - 12 PM)';
      case 'afternoon':
        return 'Afternoon (12 - 4 PM)';
      case 'evening':
        return 'Evening (4 - 7 PM)';
      default:
        if (slot != null && slot.contains(':')) return slot; // hour-based slot
        return slot ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final hasDiscount = cartItem.mrp != null && cartItem.mrp! > cartItem.unitPrice;
    final discountPercent = hasDiscount
        ? ((1 - cartItem.unitPrice / cartItem.mrp!) * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hc.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cartItem.isService
                  ? context.hc.infoLight
                  : context.hc.orangeLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: cartItem.isService
                ? Icon(Icons.calendar_today_outlined,
                    color: context.hc.info, size: 28)
                : cartItem.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: cartItem.imageUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) => const Icon(
                              Icons.medical_services_outlined,
                              color: HousepitalColors.orange),
                        ),
                      )
                    : const Icon(Icons.medical_services_outlined,
                        color: HousepitalColors.orange, size: 28),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cartItem.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(cartItem.brand,
                    style: TextStyle(
                        fontSize: 12,
                        color: context.hc.greyLight)),
                const SizedBox(height: 4),
                if (cartItem.isService) ...[
                  // Service: show scheduled info
                  if (cartItem.scheduledDate != null)
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 14, color: context.hc.info),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Scheduled: ${DateHelper.formatDate(cartItem.scheduledDate!)}${cartItem.scheduledSlot != null ? ', ${_formatSlotLabel(cartItem.scheduledSlot)}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.hc.info,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (cartItem.selectedAddress != null && cartItem.selectedAddress!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: context.hc.greyLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            cartItem.selectedAddress!,
                            style: TextStyle(
                                fontSize: 11,
                                color: context.hc.greyLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Service badge
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.hc.infoLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Service',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.hc.info,
                      ),
                    ),
                  ),
                ] else ...[
                  // Equipment: mode badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cartItem.isRental
                          ? context.hc.infoLight
                          : context.hc.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cartItem.isRental
                          ? 'Rent \u00b7 ${cartItem.rentalMonths} ${cartItem.rentalMonths == 1 ? "month" : "months"}'
                          : 'Buy',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cartItem.isRental
                            ? context.hc.info
                            : context.hc.success,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Price + quantity row
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateHelper.formatCurrency(cartItem.lineTotal),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.hc.orangeText,
                          ),
                        ),
                        if (hasDiscount)
                          Row(
                            children: [
                              Text(
                                DateHelper.formatCurrency(cartItem.mrp!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.hc.greyLight,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$discountPercent% off',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.hc.success,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const Spacer(),
                    // Quantity controls (only for equipment, not services)
                    if (!cartItem.isService)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: context.hc.divider),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _qtyButton(Icons.remove, () {
                              cart.updateQuantity(
                                  index, cartItem.quantity - 1);
                            }),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: Text('${cartItem.quantity}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ),
                            _qtyButton(Icons.add, () {
                              cart.updateQuantity(
                                  index, cartItem.quantity + 1);
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Delete button — WCAG 2.5.5 tap target + destructive confirm.
          IconButton(
            tooltip: 'Remove ${cartItem.name} from cart',
            constraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.zero,
            onPressed: () async {
              final confirmed = await confirmDestructiveAction(
                context,
                title: 'Remove item?',
                message:
                    '"${cartItem.name}" will be removed from your cart.',
                confirmLabel: 'Remove',
              );
              if (confirmed) cart.removeItem(index);
            },
            icon: Icon(Icons.close,
                size: 18, color: context.hc.greyLight),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: HousepitalColors.orange),
      ),
    );
  }
}

// ====================================================================
//  SAVED FOR LATER CARD
// ====================================================================

class _SavedItemCard extends StatelessWidget {
  final int index;
  final CartItem cartItem;

  const _SavedItemCard({required this.index, required this.cartItem});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hc.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.hc.greyLighter,
              borderRadius: BorderRadius.circular(10),
            ),
            child: cartItem.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: cartItem.imageUrl!,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => Icon(
                          Icons.medical_services_outlined,
                          color: context.hc.greyLight),
                    ),
                  )
                : Icon(Icons.medical_services_outlined,
                    color: context.hc.greyLight, size: 24),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cartItem.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(cartItem.brand,
                    style: TextStyle(
                        fontSize: 12,
                        color: context.hc.greyLight)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Move to Cart button
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: () => cart.moveToCart(index),
              style: OutlinedButton.styleFrom(
                foregroundColor: HousepitalColors.orange,
                side: const BorderSide(color: HousepitalColors.orange),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Move to Cart'),
            ),
          ),
          const SizedBox(width: 4),
          // Remove — WCAG 2.5.5 tap target.
          IconButton(
            tooltip: 'Remove ${cartItem.name} from saved items',
            constraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.zero,
            onPressed: () => cart.removeSaved(index),
            icon: Icon(Icons.close,
                size: 16, color: context.hc.greyLight),
          ),
        ],
      ),
    );
  }
}
