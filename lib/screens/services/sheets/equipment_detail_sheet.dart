// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../utils/helpers.dart';
import '../widgets/catalog_text_helpers.dart';
import '../widgets/collapsible_text.dart';
import '../widgets/quantity_button.dart';

/// Bottom sheet shown when an [EquipmentItem] card is tapped from the
/// Equipment tab. Lets the user toggle Buy / Rent, pick rental duration,
/// and either add to cart, request an assessment, or hit the "price on
/// request" disabled state.
///
/// The sheet pops with a `Map<String, dynamic>` describing the user's intent
/// (action: 'add_to_cart' | 'rent' | route navigation). The parent widget
/// is responsible for the actual cart mutation / navigation so this widget
/// stays purely presentational.
class EquipmentDetailSheet extends StatefulWidget {
  final EquipmentItem item;
  final IconData icon;
  const EquipmentDetailSheet(
      {super.key, required this.item, required this.icon});

  @override
  State<EquipmentDetailSheet> createState() => _EquipmentDetailSheetState();
}

class _EquipmentDetailSheetState extends State<EquipmentDetailSheet> {
  bool _isRental = false; // false = Buy, true = Rent
  int _rentalMonths = 1; // default rental duration (min 15 days = 1 month)

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final icon = widget.icon;
    final hasRental = item.availableForRent;
    final breakeven = item.breakevenDays;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: HousepitalColors.greyLighter,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.close, size: 18, color: HousepitalColors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: HousepitalColors.orangeLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: item.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) => Icon(icon,
                              color: HousepitalColors.orange, size: 28),
                        ),
                      )
                    : Icon(icon,
                        color: HousepitalColors.orange, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: HousepitalColors.black,
                      ),
                    ),
                    Text(
                      item.brand,
                      style: const TextStyle(
                        fontSize: 14,
                        color: HousepitalColors.greyLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.category == 'Equipment'
                      ? HousepitalColors.infoLight
                      : HousepitalColors.successLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.category == 'Equipment'
                        ? HousepitalColors.info
                        : HousepitalColors.success,
                  ),
                ),
              ),
            ],
          ),
          // Description (collapsible if long)
          if (item.description != null) ...[
            const SizedBox(height: 14),
            CollapsibleText(text: item.description!),
          ],

          // Key Features (collapsible)
          if (item.keyFeatures != null) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Key Features',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HousepitalColors.black)),
              leading: const Icon(Icons.star_outline, size: 18, color: HousepitalColors.orange),
              children: splitCatalogText(item.keyFeatures!).map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: HousepitalColors.successLight,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(Icons.check, size: 12, color: HousepitalColors.success),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(f, style: const TextStyle(fontSize: 13, color: HousepitalColors.grey, height: 1.4)),
                        ),
                      ],
                    ),
                  )).toList(),
            ),
          ],

          // Ideal For (collapsible)
          if (item.idealFor != null) ...[
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Ideal For',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HousepitalColors.black)),
              leading: const Icon(Icons.check_circle_outline, size: 18, color: HousepitalColors.orange),
              children: splitCatalogText(item.idealFor!).map((use) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: HousepitalColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(use, style: const TextStyle(fontSize: 12, color: HousepitalColors.grey, height: 1.4)),
                        ),
                      ],
                    ),
                  )).toList(),
            ),
          ],

          // How to Use (expandable)
          if (item.howToUse != null) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('How to Use',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black)),
              leading: const Icon(Icons.help_outline,
                  size: 18, color: HousepitalColors.orange),
              children: splitCatalogText(item.howToUse!).asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22, height: 22,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: HousepitalColors.orangeLight,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Center(child: Text('${entry.key + 1}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HousepitalColors.orangeText))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, color: HousepitalColors.grey, height: 1.4))),
                      ],
                    ),
                  )).toList(),
            ),
          ],

          // FAQs (expandable)
          if (item.faqs != null && item.faqs!.isNotEmpty) ...[
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('FAQs',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black)),
              leading: const Icon(Icons.question_answer_outlined,
                  size: 18, color: HousepitalColors.orange),
              children: buildFaqItems(item.faqs!),
            ),
          ],

          // Variant info
          if (item.variantType != null && item.variantValue != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${item.variantType}: ',
                      style: const TextStyle(
                          fontSize: 12,
                          color: HousepitalColors.greyLight)),
                  Text(item.variantValue!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: HousepitalColors.black)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Rent / Buy toggle (only for Equipment with rental pricing)
          if (hasRental) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isRental = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isRental
                              ? HousepitalColors.orange
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Buy',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: !_isRental
                                  ? HousepitalColors.white
                                  : HousepitalColors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isRental = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isRental
                              ? HousepitalColors.orange
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Rent',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _isRental
                                  ? HousepitalColors.white
                                  : HousepitalColors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Price section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HousepitalColors.orangeLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isRental ? 'Rental (per month)' : 'Buy Price',
                      style: const TextStyle(
                        fontSize: 14,
                        color: HousepitalColors.grey,
                      ),
                    ),
                    Text(
                      _isRental
                          ? (item.rentalPrice != null
                              ? '${DateHelper.formatCurrency(item.rentalPrice!.toInt())}/month'
                              : 'On request')
                          : (item.price != null
                              ? DateHelper.formatCurrency(
                                  item.price!.toInt())
                              : 'On request'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: HousepitalColors.orangeText,
                      ),
                    ),
                  ],
                ),
                // Show the alternate price as comparison
                if (hasRental) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isRental ? 'Buy price' : 'Or rent at',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HousepitalColors.greyLight,
                        ),
                      ),
                      Text(
                        _isRental
                            ? (item.price != null
                                ? DateHelper.formatCurrency(item.price!.toInt())
                                : 'On request')
                            : (item.rentalPrice != null
                                ? '${DateHelper.formatCurrency(item.rentalPrice!.toInt())}/month'
                                : 'On request'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: HousepitalColors.greyLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Breakeven insight (only for Equipment with both prices)
          if (hasRental && breakeven != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HousepitalColors.infoLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HousepitalColors.infoLight),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: HousepitalColors.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: HousepitalColors.info,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: _isRental
                                ? 'After $breakeven days of renting, buying becomes cheaper. '
                                : 'Renting saves money if you need it for less than $breakeven days. ',
                          ),
                          TextSpan(
                            text: _isRental
                                ? 'Consider buying if needed long-term.'
                                : 'Consider renting for short-term use.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Rental months selector (only when renting)
          if (hasRental && _isRental) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Rental Duration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.black,
                  ),
                ),
                const Spacer(),
                QuantityButton(
                  icon: Icons.remove,
                  onTap: () => setState(() {
                    if (_rentalMonths > 1) _rentalMonths--;
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$_rentalMonths ${_rentalMonths == 1 ? "month" : "months"}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: HousepitalColors.black,
                    ),
                  ),
                ),
                QuantityButton(
                  icon: Icons.add,
                  onTap: () => setState(() => _rentalMonths++),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Total line
          if (_isRental && hasRental && item.rentalPrice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(
                    item.rentalPrice != null
                        ? DateHelper.formatCurrency(
                            (item.rentalPrice! * _rentalMonths).toInt())
                        : 'On request',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: HousepitalColors.orangeText,
                    ),
                  ),
                ],
              ),
            ),

          // Ventilator/BiPAP/CPAP → assessment first; everything else → add to cart
          if (item.needsAssessment) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: HousepitalColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: HousepitalColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This device requires a complimentary clinical assessment to determine the right settings and fit for the patient.',
                      style: TextStyle(fontSize: 12, color: HousepitalColors.info, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop<Map<String, dynamic>>({
                    'route': '/assessment-request',
                    'args': ServiceItem(
                        id: 'eq-${item.id}',
                        name: item.name,
                        category: 'equipment_assessment',
                        bookingType: 'assessment',
                        basePriceMin: (item.rentalPrice ?? item.price ?? 0).toInt(),
                        basePriceMax: (item.price ?? item.rentalPrice ?? 0).toInt(),
                        iconName: 'medical_services',
                      ),
                  });
                },
                icon: const Icon(Icons.assignment_outlined, size: 20),
                label: const Text('Request Complimentary Assessment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HousepitalColors.orange,
                  foregroundColor: HousepitalColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ] else ...[
            // Check if price is available
            if ((_isRental && (item.rentalPrice == null || item.rentalPrice == 0)) ||
                (!_isRental && (item.price == null || item.price == 0)))
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.phone_outlined, size: 20),
                  label: const Text('Price on request — contact us'),
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade600,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_isRental) {
                      // Rental → pop with 'rent' action; parent navigates to rental agreement
                      Navigator.of(context).pop<Map<String, dynamic>>({
                        'action': 'rent',
                        'monthlyRate': (item.rentalPrice ?? 0).toInt(),
                        'rentalMonths': _rentalMonths,
                      });
                    } else {
                      // Buy → add to cart directly via parent context
                      Navigator.of(context).pop<Map<String, dynamic>>({
                        'action': 'add_to_cart',
                        'itemId': item.id,
                        'itemName': item.name,
                        'itemBrand': item.brand,
                        'itemImageUrl': item.imageUrl,
                        'unitPrice': (item.price?.toInt() ?? 0),
                        'mrp': item.mrp?.toInt(),
                        'isRental': false,
                        'rentalMonths': 1,
                      });
                    }
                  },
                  icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                  label: Text(_isRental ? 'Add Rental to Cart' : 'Add to Cart'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HousepitalColors.orange,
                    foregroundColor: HousepitalColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
      ),
    );
  }
}
