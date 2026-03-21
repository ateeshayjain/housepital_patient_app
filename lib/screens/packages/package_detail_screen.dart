import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../utils/helpers.dart';

class PackageDetailScreen extends StatefulWidget {
  final CarePackage package;
  const PackageDetailScreen({super.key, required this.package});

  @override
  State<PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends State<PackageDetailScreen> {
  Map<int, EquipmentItem> _catalogMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/equipment_catalog.json');
      final List<dynamic> data = json.decode(jsonStr);
      final items = data.map((j) => EquipmentItem.fromJson(j)).toList();
      setState(() {
        _catalogMap = {for (var item in items) item.id: item};
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  double get _itemsTotal {
    double total = 0;
    for (final pi in widget.package.items) {
      final eq = _catalogMap[pi.equipmentId];
      if (eq == null) continue;
      if (pi.isRental) {
        total += (eq.rentalPrice ?? 0) * pi.rentalMonths * pi.quantity;
      } else {
        total += (eq.price ?? 0) * pi.quantity;
      }
    }
    return total;
  }

  double get _servicesTotal {
    return widget.package.services
        .fold(0.0, (sum, s) => sum + s.totalPrice);
  }

  double get _originalTotal => _itemsTotal + _servicesTotal;

  double get _discount =>
      _originalTotal * (widget.package.discountPercent / 100);

  double get _packagePrice => _originalTotal - _discount;

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;

    return Scaffold(
      appBar: AppBar(title: Text(pkg.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero banner
                  _buildHeroBanner(pkg),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Highlights
                        if (pkg.highlights.isNotEmpty) ...[
                          _sectionTitle('Why This Package'),
                          const SizedBox(height: 8),
                          ...pkg.highlights.map((h) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: HousepitalColors.success,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(h,
                                          style: const TextStyle(
                                              fontSize: 14, height: 1.3)),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 20),
                        ],

                        // Equipment & Consumables
                        _sectionTitle(
                            'Equipment & Consumables (${pkg.items.length} items)'),
                        const SizedBox(height: 10),
                        ...pkg.items.map((pi) => _buildPackageItemRow(pi)),

                        // Services
                        if (pkg.services.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _sectionTitle(
                              'Services (${pkg.services.length})'),
                          const SizedBox(height: 10),
                          ...pkg.services
                              .map((s) => _buildServiceRow(s)),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _loading ? null : _buildBottomBar(context, pkg),
    );
  }

  Widget _buildHeroBanner(CarePackage pkg) {
    final iconMap = <String, IconData>{
      'healing': Icons.healing,
      'bedtime': Icons.bedtime,
      'child_care': Icons.child_care,
      'psychology': Icons.psychology,
      'elderly': Icons.elderly,
      'local_hospital': Icons.local_hospital,
      'medical_services': Icons.medical_services,
      'home': Icons.home,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HousepitalColors.orange.withValues(alpha: 0.12),
            HousepitalColors.orange.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: HousepitalColors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  iconMap[pkg.icon] ?? Icons.local_hospital,
                  color: HousepitalColors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pkg.isDailyPackage)
                      Text(
                        '${DateHelper.formatCurrency(pkg.pricePerDay!)}/day',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: HousepitalColors.orangeText,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: HousepitalColors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${pkg.discountPercent.toInt()}% OFF',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      pkg.isDailyPackage
                          ? '${pkg.condition} · Min ${pkg.minDays} days'
                          : pkg.condition,
                      style: const TextStyle(
                          fontSize: 13,
                          color: HousepitalColors.greyLight)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(pkg.description,
              style: const TextStyle(
                  fontSize: 14,
                  color: HousepitalColors.grey,
                  height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildPackageItemRow(PackageItem pi) {
    final eq = _catalogMap[pi.equipmentId];
    final price = eq != null
        ? pi.isRental
            ? (eq.rentalPrice ?? 0) * pi.rentalMonths * pi.quantity
            : (eq.price ?? 0) * pi.quantity
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: HousepitalColors.orangeLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.medical_services_outlined,
                color: HousepitalColors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pi.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  pi.isRental
                      ? 'Rent · ${pi.rentalMonths} ${pi.rentalMonths == 1 ? "month" : "months"}${pi.quantity > 1 ? " × ${pi.quantity}" : ""}'
                      : 'Buy${pi.quantity > 1 ? " × ${pi.quantity}" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: pi.isRental
                        ? Colors.blue.shade700
                        : HousepitalColors.success,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateHelper.formatCurrency(price.toInt()),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: HousepitalColors.orangeText),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRow(PackageService s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${s.durationDays} days · ${DateHelper.formatCurrency(s.pricePerDay)}/day',
                  style: const TextStyle(
                      fontSize: 12, color: HousepitalColors.greyLight),
                ),
              ],
            ),
          ),
          Text(
            DateHelper.formatCurrency(s.totalPrice),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: HousepitalColors.orangeText),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, CarePackage pkg) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
            if (pkg.isDailyPackage) ...[
              // Daily package pricing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daily Rate',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    '${DateHelper.formatCurrency(pkg.pricePerDay!)}/day',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: HousepitalColors.orangeText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Minimum ${pkg.minDays} days · Billing & payment',
                      style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
                  Text(
                    'Min ${DateHelper.formatCurrency(pkg.pricePerDay! * (pkg.minDays ?? 5))}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: HousepitalColors.grey),
                  ),
                ],
              ),
            ] else ...[
              // Condition-based package pricing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Individual total',
                      style: TextStyle(
                          fontSize: 13, color: HousepitalColors.greyLight)),
                  Text(
                    DateHelper.formatCurrency(_originalTotal.toInt()),
                    style: const TextStyle(
                      fontSize: 13,
                      color: HousepitalColors.greyLight,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Package discount (${pkg.discountPercent.toInt()}%)',
                      style: const TextStyle(
                          fontSize: 13, color: HousepitalColors.success)),
                  Text(
                    '- ${DateHelper.formatCurrency(_discount.toInt())}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: HousepitalColors.success),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Package Price',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    DateHelper.formatCurrency(_packagePrice.toInt()),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: HousepitalColors.orangeText,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _addPackageToCart(context),
                icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                label: const Text('Get This Package',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
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

  void _addPackageToCart(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    int addedCount = 0;
    final assessmentItems = <String>[];

    for (final pi in widget.package.items) {
      final eq = _catalogMap[pi.equipmentId];
      if (eq == null) continue;
      // Ventilator/BiPAP/CPAP need assessment — don't add to cart directly
      if (eq.needsAssessment) {
        assessmentItems.add(eq.name);
        continue;
      }
      cart.addItem(eq,
          isRental: pi.isRental, rentalMonths: pi.rentalMonths);
      addedCount++;
    }

    // Services always require assessment — they are NOT added to cart
    final serviceNames =
        widget.package.services.map((s) => s.name).toList();

    if (!mounted) return;

    final needsAssessment =
        assessmentItems.isNotEmpty || serviceNames.isNotEmpty;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(needsAssessment
            ? '$addedCount equipment items added to cart. Services & respiratory devices require an assessment — our team will reach out.'
            : '${widget.package.name} added — $addedCount items in cart'),
        backgroundColor: HousepitalColors.success,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'VIEW CART',
          textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, '/cart'),
        ),
      ),
    );

    // If services or respiratory devices need assessment, show a dialog
    if (needsAssessment) {
      final allAssessment = [...assessmentItems, ...serviceNames];
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Assessment Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following items in this package require a clinical assessment before deployment:',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              ...allAssessment.map((name) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_outlined,
                            size: 16, color: HousepitalColors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(name,
                                style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              const Text(
                'Our team will contact you to schedule a complimentary assessment.',
                style: TextStyle(
                    fontSize: 12,
                    color: HousepitalColors.greyLight,
                    height: 1.3),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Got It'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: HousepitalColors.black));
  }
}
