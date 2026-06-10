// lib/screens/my_care/widgets/doctor_advice_card.dart
//
// "Doctor's Advice" card on the My Care tab — whatever the doctor
// recommended after a consultation, with one-tap Add-to-cart (equipment /
// lab) or Book (service → existing booking flow).
//
// Pricing rule: NO prices are rendered in this card. Manpower services must
// never show prices (hard business rule), and for equipment/lab the cart is
// the source of truth — omitting here keeps the card uniform and safe.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../../../config/app_colors.dart';
import '../../../config/theme.dart';
import '../../../data/demo_data.dart';
import '../../../models/doctor_recommendation.dart';
import '../../../models/models.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/common_widgets.dart';
import '../../services/data/catalog_seeds.dart';

class DoctorAdviceCard extends StatefulWidget {
  /// Injectable for tests; defaults to [DemoData.doctorRecommendations].
  final List<DoctorRecommendation>? recommendations;

  const DoctorAdviceCard({super.key, this.recommendations});

  @override
  State<DoctorAdviceCard> createState() => _DoctorAdviceCardState();
}

class _DoctorAdviceCardState extends State<DoctorAdviceCard> {
  /// Recommendation ids added to cart this session (button flips to "Added").
  final Set<String> _added = {};

  // Lazily-loaded catalogs (memoized — fetched on first add, not app start).
  Future<List<EquipmentItem>>? _equipmentCatalog;
  Future<List<LabTestItem>>? _labCatalog;

  List<DoctorRecommendation> get _recs =>
      widget.recommendations ?? DemoData.doctorRecommendations;

  Future<List<EquipmentItem>> _loadEquipmentCatalog() {
    // Same source order as equipment_tab: backend first, bundled JSON fallback.
    return _equipmentCatalog ??= () async {
      try {
        return await ApiService().getEquipmentCatalog();
      } catch (_) {
        final jsonStr =
            await rootBundle.loadString('assets/equipment_catalog.json');
        final List<dynamic> list = json.decode(jsonStr);
        return list.map((e) => EquipmentItem.fromJson(e)).toList();
      }
    }();
  }

  Future<List<LabTestItem>> _loadLabCatalog() {
    // Same source as lab_tests_tab: bundled JSON asset.
    return _labCatalog ??= () async {
      final jsonStr =
          await rootBundle.loadString('assets/lab_tests_catalog.json');
      final List<dynamic> list = json.decode(jsonStr);
      return list.map((e) => LabTestItem.fromJson(e)).toList();
    }();
  }

  /// Adds an equipment/lab recommendation to the cart. Returns true on
  /// success. 'service' recommendations never come here — they Book instead.
  Future<bool> _addToCart(DoctorRecommendation rec) async {
    final cart = context.read<CartProvider>();
    try {
      switch (rec.type) {
        case 'equipment':
          final catalog = await _loadEquipmentCatalog();
          final eq = catalog.firstWhere((e) => e.id == rec.catalogId);
          // Guard: only honour the rental flag if the item is actually
          // rentable — otherwise add as a purchase (a ₹0 rental line would
          // corrupt the cart total).
          final asRental = rec.isRental && eq.availableForRent;
          cart.addItem(eq, isRental: asRental);
          return true;
        case 'lab':
          final catalog = await _loadLabCatalog();
          final test = catalog.firstWhere((t) => t.id == rec.catalogId);
          final price = test.price;
          if (price == null) return false;
          // Mirror the booking flow's cart contract: lab line = price + GST.
          final total = price + (price * 0.18).toInt();
          cart.addService(
            serviceId: test.id,
            serviceName: test.name,
            category: 'lab',
            price: total,
          );
          return true;
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _onAdd(DoctorRecommendation rec) async {
    final messenger = ScaffoldMessenger.of(context);
    final successColor = context.hc.success;
    final errorColor = context.hc.error;
    final ok = await _addToCart(rec);
    if (!mounted) return;
    if (ok) {
      setState(() => _added.add(rec.id));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Added to cart'),
          backgroundColor: successColor,
          duration: const Duration(seconds: 2),
        ));
    } else {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Could not add — please try from the catalog'),
          backgroundColor: errorColor,
          duration: const Duration(seconds: 2),
        ));
    }
  }

  Future<void> _onAddAll() async {
    final addable = _recs
        .where((r) => r.type != 'service' && !_added.contains(r.id))
        .toList();
    if (addable.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final successColor = context.hc.success;
    var addedCount = 0;
    for (final rec in addable) {
      final ok = await _addToCart(rec);
      if (!mounted) return;
      if (ok) {
        setState(() => _added.add(rec.id));
        addedCount++;
      }
    }
    if (addedCount > 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Added to cart'),
          backgroundColor: successColor,
          duration: const Duration(seconds: 2),
        ));
    }
  }

  void _onBook(DoctorRecommendation rec) {
    // Services go through the existing booking flow (scheduling, address,
    // price-on-assessment guards) — exactly what the catalog cards do.
    final service =
        manpowerServices.where((s) => s.id == rec.catalogId).firstOrNull;
    if (service != null) {
      Navigator.pushNamed(context, '/service-booking', arguments: service);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'equipment':
        return Icons.medical_services;
      case 'lab':
        return Icons.science;
      default:
        return Icons.healing;
    }
  }

  Color _colorFor(BuildContext context, String type) {
    switch (type) {
      case 'equipment':
        return HousepitalColors.serviceNursing;
      case 'lab':
        return context.hc.info;
      default:
        return HousepitalColors.servicePhysio;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recs = _recs;
    if (recs.isEmpty) return const SizedBox.shrink();

    final hasAddable =
        recs.any((r) => r.type != 'service' && !_added.contains(r.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: "Doctor's Advice"),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HousepitalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < recs.length; i++) ...[
                  if (i > 0)
                    Divider(height: 20, color: context.hc.divider),
                  _RecommendationRow(
                    rec: recs[i],
                    icon: _iconFor(recs[i].type),
                    color: _colorFor(context, recs[i].type),
                    isAdded: _added.contains(recs[i].id),
                    onAdd: () => _onAdd(recs[i]),
                    onBook: () => _onBook(recs[i]),
                  ),
                ],
                if (hasAddable) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('advice-add-all'),
                      onPressed: _onAddAll,
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Add all to cart'),
                      style: TextButton.styleFrom(
                        foregroundColor: context.hc.orangeText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  final DoctorRecommendation rec;
  final IconData icon;
  final Color color;
  final bool isAdded;
  final VoidCallback onAdd;
  final VoidCallback onBook;

  const _RecommendationRow({
    required this.rec,
    required this.icon,
    required this.color,
    required this.isAdded,
    required this.onAdd,
    required this.onBook,
  });

  /// Compact tonal pill (FilledButton.tonal style): small visual, but the
  /// padded Material tap target keeps the interactive area ≥ 44pt.
  ButtonStyle _pillStyle(BuildContext context) => FilledButton.styleFrom(
        backgroundColor: context.hc.orangeLight,
        foregroundColor: context.hc.orangeText,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );

  @override
  Widget build(BuildContext context) {
    final isService = rec.type == 'service';

    final Widget trailing;
    if (isService) {
      trailing = Semantics(
        label: 'Book ${rec.title}',
        button: true,
        child: FilledButton.tonalIcon(
          key: Key('advice-book-${rec.id}'),
          onPressed: onBook,
          style: _pillStyle(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Book'),
        ),
      );
    } else if (isAdded) {
      trailing = Semantics(
        label: '${rec.title} added to cart',
        child: TextButton.icon(
          key: Key('advice-added-${rec.id}'),
          onPressed: null,
          icon: Icon(Icons.check, size: 16, color: context.hc.success),
          label: Text(
            'Added',
            style: TextStyle(fontSize: 13, color: context.hc.success),
          ),
        ),
      );
    } else {
      trailing = Semantics(
        label: 'Add ${rec.title} to cart',
        button: true,
        child: FilledButton.tonalIcon(
          key: Key('advice-add-${rec.id}'),
          onPressed: onAdd,
          style: _pillStyle(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add'),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconTile(icon: icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rec.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.hc.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rec.note,
                style: TextStyle(fontSize: 12, color: context.hc.grey),
              ),
              const SizedBox(height: 2),
              Text(
                'Recommended by Dr. Ananya Sharma · 2 days ago',
                style: TextStyle(fontSize: 11, color: context.hc.greyLight),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}
