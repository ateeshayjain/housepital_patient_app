// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../utils/helpers.dart';
import '../../../utils/permissions.dart';
import '../sheets/equipment_detail_sheet.dart';
import '../widgets/permission_dialogs.dart';

/// Grid card shown on the Equipment tab for a single [EquipmentItem].
///
/// Tapping the card surfaces [EquipmentDetailSheet]; once the sheet returns,
/// the card handles the resulting action (add to cart, rent, request
/// assessment) including the role-based permission gating.
class EquipmentItemCard extends StatelessWidget {
  final EquipmentItem item;
  final IconData icon;

  const EquipmentItemCard({super.key, required this.item, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HousepitalColors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: () => _showItemDetail(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder / icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: HousepitalColors.orangeLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: item.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: item.imageUrl!.startsWith('assets/')
                              ? Image.asset(
                                  item.imageUrl!,
                                  fit: BoxFit.contain,
                                  semanticLabel: '${item.name} product photo',
                                  errorBuilder: (_, __, ___) => Icon(icon,
                                      color: HousepitalColors.orange, size: 32),
                                )
                              : CachedNetworkImage(
                                  imageUrl: item.imageUrl!,
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => Icon(icon,
                                      color: HousepitalColors.orange, size: 32),
                                  errorWidget: (_, __, ___) => Icon(icon,
                                      color: HousepitalColors.orange, size: 32),
                                ),
                        )
                      : Icon(icon,
                          color: HousepitalColors.orange, size: 32),
                ),
              ),
              const SizedBox(height: 8),
              // Name
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              // Brand
              Text(
                item.brand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: HousepitalColors.greyLight,
                ),
              ),
              const Spacer(),
              // Price with MRP strikethrough
              if (item.price != null) ...[
                if (item.mrp != null && item.mrp! > item.price!) ...[
                  Row(
                    children: [
                      Text(
                        DateHelper.formatCurrency(item.mrp!.toInt()),
                        style: const TextStyle(
                          fontSize: 11,
                          color: HousepitalColors.greyLight,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: HousepitalColors.greyLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: HousepitalColors.successLight,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '${(((item.mrp! - item.price!) / item.mrp!) * 100).round()}% off',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: HousepitalColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  DateHelper.formatCurrency(item.price!.toInt()),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: HousepitalColors.orangeText,
                  ),
                ),
              ] else
                const Text(
                  'Price on request',
                  style: TextStyle(
                    fontSize: 11,
                    color: HousepitalColors.greyLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 4),
              // Category badges
              Row(
                children: [
                  if (item.availableForRent) ...[
                    _typeBadge('Rent', HousepitalColors.infoLight,
                        HousepitalColors.info),
                    const SizedBox(width: 4),
                  ],
                  if (item.availableForSale)
                    _typeBadge('Buy', HousepitalColors.successLight,
                        HousepitalColors.success),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
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
          result['action'] == 'add_to_cart';
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
                backgroundColor: HousepitalColors.success,
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
              backgroundColor: HousepitalColors.success,
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'View Cart',
                textColor: Colors.white,
                onPressed: () => navigator.pushNamed('/cart'),
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
