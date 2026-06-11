// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../config/app_colors.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/orders_provider.dart';
import '../../../utils/helpers.dart';
import '../../../utils/permissions.dart';
import '../sheets/equipment_detail_sheet.dart';
import '../widgets/permission_dialogs.dart';

/// Compact Blinkit-style grid card shown on the Equipment tab for a single
/// [EquipmentItem]: square image area, brand/variant line, 2-line name,
/// MRP-strikethrough + % off chip, bold price, and an 'ADD' pill overlapping
/// the image's bottom edge.
///
/// Tapping the card body surfaces [EquipmentDetailSheet]; once the sheet
/// returns, the card handles the resulting action (add to cart, rent, request
/// assessment) including the role-based permission gating. The ADD pill
/// one-tap adds simple sale-only items to the cart; anything with rental /
/// assessment complexity falls back to opening the same detail sheet.
class EquipmentItemCard extends StatelessWidget {
  final EquipmentItem item;
  final IconData icon;

  const EquipmentItemCard({super.key, required this.item, required this.icon});

  /// One-tap ADD is only safe for plain sale items: a real sale price, no
  /// rental option to choose, and no mandatory clinical assessment.
  bool get _isSimpleSaleItem =>
      item.availableForSale &&
      !item.availableForRent &&
      (item.price ?? 0) > 0 &&
      !item.needsAssessment;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = item.price != null &&
        item.mrp != null &&
        item.mrp! > item.price!;

    return Material(
      color: context.hc.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: () => _showItemDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Square image area with the ADD pill overlapping its bottom
              // edge (the stack reserves 24px below the image so the pill's
              // full 44pt hit area stays inside hit-test bounds without
              // covering the brand/name text below).
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.hc.greyLighter,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildImage(context),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _AddPill(
                      itemName: item.name,
                      onPressed: () => _handleAdd(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Brand / variant line
              SizedBox(
                height: 14,
                child: Text(
                  item.variantValue != null
                      ? '${item.brand} · ${item.variantValue}'
                      : item.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: context.hc.greyLight,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Name (2 lines)
              SizedBox(
                height: 34,
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.hc.black,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Struck-through MRP + green % off chip
              SizedBox(
                height: 16,
                child: hasDiscount
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateHelper.formatCurrency(item.mrp!.toInt()),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.hc.greyLight,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: context.hc.greyLight,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: context.hc.successLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(((item.mrp! - item.price!) / item.mrp!) * 100).round()}% off',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.hc.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : (item.availableForRent && item.rentalPrice != null
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Rent ${DateHelper.formatCurrency(item.rentalPrice!.toInt())}/mo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: context.hc.info,
                              ),
                            ),
                          )
                        : const SizedBox.shrink()),
              ),
              const SizedBox(height: 2),
              // Bold price
              SizedBox(
                height: 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: item.price != null
                      ? Text(
                          DateHelper.formatCurrency(item.price!.toInt()),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.hc.black,
                          ),
                        )
                      : Text(
                          'Price on request',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.hc.greyLight,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (item.imageUrl == null) {
      return Center(
          child: Icon(icon, color: HousepitalColors.orange, size: 32));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: item.imageUrl!.startsWith('assets/')
          ? Image.asset(
              item.imageUrl!,
              fit: BoxFit.contain,
              semanticLabel: '${item.name} product photo',
              errorBuilder: (_, _, _) =>
                  Icon(icon, color: HousepitalColors.orange, size: 32),
            )
          : CachedNetworkImage(
              imageUrl: item.imageUrl!,
              fit: BoxFit.contain,
              placeholder: (_, _) =>
                  Icon(icon, color: HousepitalColors.orange, size: 32),
              errorWidget: (_, _, _) =>
                  Icon(icon, color: HousepitalColors.orange, size: 32),
            ),
    );
  }

  /// ADD pill action: one-tap add-to-cart for simple sale items (same cart
  /// call + role gating the detail sheet flow uses); items with rental /
  /// assessment / price-on-request complexity open the detail sheet instead.
  void _handleAdd(BuildContext context) {
    if (!_isSimpleSaleItem) {
      _showItemDetail(context);
      return;
    }
    // Same role gating as the post-sheet add-to-cart path below.
    final role = context.read<AppProvider>().currentUserRole;
    if (!canUserPerform(role, UserAction.book)) {
      if (canUserPerform(role, UserAction.requestBooking)) {
        showRequestBookingStub(context, item.name);
      } else {
        showViewOnlyToast(context);
      }
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final cart = context.read<CartProvider>();
    cart.addItem(item, isRental: false, rentalMonths: 1);
    // SnackBar supports a single action — Undo wins over View Cart here
    // (error prevention beats navigation for a one-tap add).
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.name} added to cart'),
          backgroundColor: context.hc.success,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => _undoAdd(cart),
          ),
        ),
      );
  }

  /// Reverts the one-tap ADD: the add either appended a new cart line or
  /// bumped the quantity of an existing one, so undo decrements the quantity
  /// (removing the line when it hits zero). Index is resolved at undo time —
  /// the cart may have changed while the SnackBar was visible.
  void _undoAdd(CartProvider cart) {
    final index = cart.items.indexWhere(
      (i) => i.equipmentId == item.id && !i.isRental,
    );
    if (index < 0) return; // already removed elsewhere
    cart.updateQuantity(index, cart.items[index].quantity - 1);
  }

  void _showItemDetail(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EquipmentDetailSheet(item: item, icon: icon),
    );
    // Handle result AFTER bottom sheet is fully closed, using parent context.
    // Capture navigator & scaffold messenger eagerly — the card's context may
    // become unmounted by the time the user taps the SnackBar action because
    // EquipmentItemCard lives inside a GridView.builder (widgets get recycled).
    if (result != null && context.mounted) {
      final navigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.maybeOf(context);
      // Gate any write action (add-to-cart / rental commitment) by role.
      final role = context.read<AppProvider>().currentUserRole;
      final isWriteAction = result['action'] == 'rent' ||
          result['action'] == 'add_to_cart' ||
          result['action'] == 'reserve';
      if (isWriteAction && !canUserPerform(role, UserAction.book)) {
        if (canUserPerform(role, UserAction.requestBooking)) {
          showRequestBookingStub(context, item.name);
        } else {
          showViewOnlyToast(context);
        }
        return;
      }
      if (result['action'] == 'rent') {
        // Rental flow: navigate to rental agreement for confirmation
        final agreed = await navigator.pushNamed('/rental-agreement', arguments: {
          'itemName': item.name,
          'monthlyRate': result['monthlyRate'],
          'durationMonths': result['rentalMonths'],
        });
        if (agreed == true && context.mounted) {
          final cart = Provider.of<CartProvider>(context, listen: false);
          cart.addItem(item, isRental: true, rentalMonths: result['rentalMonths'] as int);
          messenger
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('${item.name} rental added to cart'),
                backgroundColor: context.hc.success,
                duration: const Duration(seconds: 2),
                dismissDirection: DismissDirection.horizontal,
                action: SnackBarAction(
                  label: 'View Cart',
                  textColor: Colors.white,
                  onPressed: () => navigator.pushNamed('/cart'),
                ),
              ),
            );
        }
      } else if (result['action'] == 'add_to_cart') {
        // Buy flow: add to cart directly
        final cart = Provider.of<CartProvider>(context, listen: false);
        cart.addItem(
          item,
          isRental: false,
          rentalMonths: 1,
        );
        final itemName = result['itemName'] as String;
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$itemName added to cart'),
              backgroundColor: context.hc.success,
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'View Cart',
                textColor: Colors.white,
                onPressed: () => navigator.pushNamed('/cart'),
              ),
            ),
          );
      } else if (result['action'] == 'reserve') {
        // Price-on-request flow: create a quote-pending order directly via
        // OrdersProvider — no price shown, the team confirms it on call
        // before any payment.
        final orders = context.read<OrdersProvider>();
        final bookingNumber = orders.generateUniqueBookingNumber();
        orders.addOrder(
          items: [
            CartItem(
              equipmentId: item.id,
              name: item.name,
              brand: item.brand,
              imageUrl: item.imageUrl,
              unitPrice: 0, // quote pending — confirmed on call
              isRental: result['isRental'] as bool? ?? false,
              rentalMonths: result['rentalMonths'] as int? ?? 1,
            ),
          ],
          totalAmount: 0,
          bookingNumber: bookingNumber,
          quotePending: true,
        );
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                  'Reserved — our team will confirm the price shortly ($bookingNumber)'),
              backgroundColor: context.hc.success,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'My Orders',
                textColor: Colors.white,
                onPressed: () => navigator.pushNamed('/my-orders'),
              ),
            ),
          );
      } else if (result.containsKey('route')) {
        final route = result['route'] as String;
        navigator.pushNamed(route, arguments: result['args']);
      }
    }
  }
}

/// Blinkit-style compact 'ADD' pill: outlined orange on a white chip, sized
/// to sit overlapping the bottom edge of the card's image area. The visual
/// chip stays 30px tall, but the tappable surface reserves an invisible
/// 64×44pt hit area around it (Apple HIG minimum touch target).
class _AddPill extends StatelessWidget {
  final String itemName;
  final VoidCallback onPressed;

  const _AddPill({required this.itemName, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add $itemName to cart',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
            child: Center(
              child: Material(
                color: context.hc.white,
                elevation: 2,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: HousepitalColors.orange, width: 1.2),
                  ),
                  child: Text(
                    'ADD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: context.hc.orangeText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
