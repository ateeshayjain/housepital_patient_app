import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../services/payment_service.dart';
import '../../utils/helpers.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  PaymentService? _paymentService;
  final _couponController = TextEditingController();
  String? _couponError;
  String? _appliedCouponCode;
  int _discountAmount = 0;
  bool _validatingCoupon = false;

  @override
  void initState() {
    super.initState();
    // Razorpay doesn't work on web — guard initialization
    if (!kIsWeb) {
      _paymentService = PaymentService();
    }
  }

  @override
  void dispose() {
    _paymentService?.dispose();
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
      final subtotal = cart.subtotal.toInt();
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
      final coupon = await ApiService().validateCoupon(code, 'equipment', cart.subtotal.toInt());
      final discount = coupon.calculateDiscount(cart.subtotal.toInt());
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
        title: const Text('My Cart'),
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
                        child: Text('Your cart is empty, but you have saved items below.',
                            style: TextStyle(color: HousepitalColors.greyLight)),
                      ),
                    ...cart.items.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CartItemCard(
                        cartKey: entry.key,
                        cartItem: entry.value,
                      ),
                    )),

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
                      ...cart.savedForLater.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SavedItemCard(
                          savedKey: entry.key,
                          cartItem: entry.value,
                        ),
                      )),
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
          const Text('Browse equipment & consumables to add items',
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
              Icon(Icons.local_offer_outlined, size: 18, color: HousepitalColors.orange),
              SizedBox(width: 8),
              Text('Have a coupon?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          if (_appliedCouponCode != null)
            // Applied coupon display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: HousepitalColors.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HousepitalColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: HousepitalColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_appliedCouponCode!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: HousepitalColors.success)),
                        Text('You save ${DateHelper.formatCurrency(_discountAmount)}',
                            style: const TextStyle(fontSize: 12, color: HousepitalColors.success)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _removeCoupon,
                    child: const Icon(Icons.close, size: 18, color: HousepitalColors.greyLight),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _validatingCoupon ? null : () => _applyCoupon(cart),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HousepitalColors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: _validatingCoupon
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Apply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          if (_couponError != null) ...[
            const SizedBox(height: 6),
            Text(_couponError!, style: const TextStyle(fontSize: 12, color: HousepitalColors.error)),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                DateHelper.formatCurrency(cart.subtotal.toInt())),
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
                  : DateHelper.formatCurrency(cart.deliveryCharge.toInt()),
              valueColor: cart.deliveryCharge == 0
                  ? HousepitalColors.success
                  : null,
            ),
            if (cart.deliveryCharge == 0)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Free delivery on orders above ₹999',
                      style: TextStyle(
                          fontSize: 11, color: HousepitalColors.success)),
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
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(
                  DateHelper.formatCurrency(adjustedTotal.toInt()),
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
                onPressed: () => _checkout(context, cart),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Proceed to Pay',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  void _checkout(BuildContext context, CartProvider cart) {
    final adjustedTotal = cart.subtotal - _discountAmount + cart.deliveryCharge;
    final amountInPaise = (adjustedTotal * 100).toInt();
    final itemNames = cart.items.values
        .map((ci) => ci.item.name)
        .take(3)
        .join(', ');
    final description = cart.itemCount <= 3
        ? itemNames
        : '$itemNames +${cart.itemCount - 3} more';

    if (_paymentService == null) {
      // Web fallback — Razorpay not available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payments require the mobile app. Use the Housepital app on Android/iOS.'),
          backgroundColor: HousepitalColors.warning,
        ),
      );
      return;
    }

    _paymentService!.openCheckout(
      amount: amountInPaise,
      description: description,
      onSuccess: () {
        cart.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Your order is confirmed.'),
            backgroundColor: HousepitalColors.success,
          ),
        );
        Navigator.pop(context);
      },
      onFailure: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $msg'),
            backgroundColor: HousepitalColors.error,
          ),
        );
      },
    );
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

// ═══════════════════════════════════════════════════════════════
//  CART ITEM CARD
// ═══════════════════════════════════════════════════════════════

class _CartItemCard extends StatelessWidget {
  final String cartKey;
  final CartItem cartItem;

  const _CartItemCard({required this.cartKey, required this.cartItem});

  @override
  Widget build(BuildContext context) {
    final item = cartItem.item;
    final cart = Provider.of<CartProvider>(context, listen: false);

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
          // Image
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: HousepitalColors.orangeLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl!,
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
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.brand,
                    style: const TextStyle(
                        fontSize: 12, color: HousepitalColors.greyLight)),
                const SizedBox(height: 4),
                // Mode badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                const SizedBox(height: 8),
                // Price + quantity row
                Row(
                  children: [
                    Text(
                      DateHelper.formatCurrency(cartItem.lineTotal.toInt()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HousepitalColors.orangeText,
                      ),
                    ),
                    const Spacer(),
                    // Quantity controls
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
                                cartKey, cartItem.quantity - 1);
                          }),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('${cartItem.quantity}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ),
                          _qtyButton(Icons.add, () {
                            cart.updateQuantity(
                                cartKey, cartItem.quantity + 1);
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
            onTap: () => cart.removeItem(cartKey),
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.close, size: 18, color: HousepitalColors.greyLight),
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

// ═══════════════════════════════════════════════════════════════
//  SAVED FOR LATER CARD
// ═══════════════════════════════════════════════════════════════

class _SavedItemCard extends StatelessWidget {
  final String savedKey;
  final CartItem cartItem;

  const _SavedItemCard({required this.savedKey, required this.cartItem});

  @override
  Widget build(BuildContext context) {
    final item = cartItem.item;
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
            child: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl!,
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
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.brand,
                    style: const TextStyle(
                        fontSize: 12, color: HousepitalColors.greyLight)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Move to Cart button
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: () => cart.moveToCart(savedKey),
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
            onTap: () => cart.removeSaved(savedKey),
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.close, size: 16, color: HousepitalColors.greyLight),
            ),
          ),
        ],
      ),
    );
  }
}
