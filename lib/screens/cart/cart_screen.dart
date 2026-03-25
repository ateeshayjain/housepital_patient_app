import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';
import '../../services/api_service.dart';
import '../../utils/helpers.dart';

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
      appBar: AppBar(
        title: Consumer<CartProvider>(
          builder: (_, cart, __) => Text(
            cart.isEmpty ? 'My Cart' : 'My Cart (${cart.itemCount} items)',
          ),
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (_, cart, __) => cart.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => _confirmClear(context, cart),
                    child: const Text('Clear',
                        style: TextStyle(color: HousepitalColors.greyLight)),
                  ),
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          debugPrint('CartScreen BUILD: isEmpty=${cart.isEmpty}, itemCount=${cart.itemCount}, items=${cart.items.map((i) => i.name).toList()}');
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
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Your cart is empty, but you have saved items below.',
                          style: TextStyle(color: HousepitalColors.greyLight),
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
                            const Icon(Icons.bookmark_outline,
                                size: 20, color: HousepitalColors.greyLight),
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
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Your cart is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Browse services & equipment to add items',
              style: TextStyle(color: HousepitalColors.greyLight)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: HousepitalColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Browse Products'),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HousepitalColors.orangeLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HousepitalColors.divider),
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
                color: HousepitalColors.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        HousepitalColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 18, color: HousepitalColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_appliedCouponCode!,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: HousepitalColors.success)),
                        Text(
                            'You save ${DateHelper.formatCurrency(_discountAmount)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: HousepitalColors.success)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _removeCoupon,
                    child: const Icon(Icons.close,
                        size: 18, color: HousepitalColors.greyLight),
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
                      hintText: 'Enter coupon code',
                      hintStyle: const TextStyle(fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
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
                style: const TextStyle(
                    fontSize: 12, color: HousepitalColors.error)),
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
                valueColor: HousepitalColors.success,
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
                  ? HousepitalColors.success
                  : null,
            ),
            if (cart.deliveryCharge == 0)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Free delivery on orders above Rs.999',
                      style: TextStyle(
                          fontSize: 11,
                          color: HousepitalColors.success)),
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
                        fontSize: 17, fontWeight: FontWeight.w700)),
                Text(
                  DateHelper.formatCurrency(adjustedTotal),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: HousepitalColors.orangeText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Checkout button
            SizedBox(
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
            ),
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
            style: const TextStyle(
                fontSize: 14, color: HousepitalColors.greyLight)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? HousepitalColors.black)),
      ],
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
        final items = cart.items.toList();
        final bookingNumber = OrdersProvider.generateBookingNumber();

        // Persist order to OrdersProvider
        context.read<OrdersProvider>().addOrder(
              items: items,
              totalAmount: adjustedTotal,
              bookingNumber: bookingNumber,
            );

        cart.clear();
        Navigator.pushReplacementNamed(context, '/booking-confirmation',
            arguments: {
              'cartItems': items,
              'totalAmount': adjustedTotal,
              'bookingNumber': bookingNumber,
            });
      }
    });
  }

  void _confirmClear(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cart?'),
        content:
            const Text('This will remove all items from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cart.clear();
              _removeCoupon();
              Navigator.pop(ctx);
            },
            child: const Text('Clear',
                style: TextStyle(color: HousepitalColors.error)),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
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
                  ? HousepitalColors.infoLight
                  : HousepitalColors.orangeLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: cartItem.isService
                ? const Icon(Icons.calendar_today_outlined,
                    color: HousepitalColors.info, size: 28)
                : cartItem.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: cartItem.imageUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(
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
                    style: const TextStyle(
                        fontSize: 12,
                        color: HousepitalColors.greyLight)),
                const SizedBox(height: 4),
                if (cartItem.isService) ...[
                  // Service: show scheduled info
                  if (cartItem.scheduledDate != null)
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 14, color: HousepitalColors.info),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Scheduled: ${DateHelper.formatDate(cartItem.scheduledDate!)}${cartItem.scheduledSlot != null ? ', ${_formatSlotLabel(cartItem.scheduledSlot)}' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: HousepitalColors.info,
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
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: HousepitalColors.greyLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            cartItem.selectedAddress!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: HousepitalColors.greyLight),
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
                      color: HousepitalColors.infoLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Service',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: HousepitalColors.info,
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
                          ? HousepitalColors.infoLight
                          : HousepitalColors.successLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cartItem.isRental
                          ? 'Rent \u00b7 ${cartItem.rentalMonths} ${cartItem.rentalMonths == 1 ? "month" : "months"}'
                          : 'Buy',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cartItem.isRental
                            ? HousepitalColors.info
                            : HousepitalColors.success,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: HousepitalColors.orangeText,
                          ),
                        ),
                        if (hasDiscount)
                          Row(
                            children: [
                              Text(
                                DateHelper.formatCurrency(cartItem.mrp!),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HousepitalColors.greyLight,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$discountPercent% off',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: HousepitalColors.success,
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
                          border: Border.all(color: Colors.grey.shade300),
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
          // Delete button
          GestureDetector(
            onTap: () => cart.removeItem(index),
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.close,
                  size: 18, color: HousepitalColors.greyLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: HousepitalColors.greyLighter,
              borderRadius: BorderRadius.circular(10),
            ),
            child: cartItem.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: cartItem.imageUrl!,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.medical_services_outlined,
                          color: HousepitalColors.greyLight),
                    ),
                  )
                : const Icon(Icons.medical_services_outlined,
                    color: HousepitalColors.greyLight, size: 24),
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
                    style: const TextStyle(
                        fontSize: 12,
                        color: HousepitalColors.greyLight)),
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
          // Remove
          GestureDetector(
            onTap: () => cart.removeSaved(index),
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.close,
                  size: 16, color: HousepitalColors.greyLight),
            ),
          ),
        ],
      ),
    );
  }
}
