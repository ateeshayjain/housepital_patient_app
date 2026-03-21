import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../services/payment_service.dart';
import '../../utils/helpers.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late PaymentService _paymentService;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
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
          if (cart.isEmpty) return _buildEmptyCart(context);
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = cart.items.entries.elementAt(index);
                    return _CartItemCard(
                      cartKey: entry.key,
                      cartItem: entry.value,
                    );
                  },
                ),
              ),
              _buildOrderSummary(context, cart),
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

  Widget _buildOrderSummary(BuildContext context, CartProvider cart) {
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
            // Subtotal
            _summaryRow(
                'Subtotal (${cart.itemCount} items)',
                DateHelper.formatCurrency(cart.subtotal.toInt())),
            const SizedBox(height: 6),
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
                  DateHelper.formatCurrency(cart.total.toInt()),
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
    final amountInPaise = (cart.total * 100).toInt();
    final itemNames = cart.items.values
        .map((ci) => ci.item.name)
        .take(3)
        .join(', ');
    final description = cart.itemCount <= 3
        ? itemNames
        : '$itemNames +${cart.itemCount - 3} more';

    _paymentService.openCheckout(
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
                        ? 'Rent · ${cartItem.rentalMonths} ${cartItem.rentalMonths == 1 ? "month" : "months"}'
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
