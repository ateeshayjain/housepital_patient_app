// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shimmer/shimmer.dart';
import '../../../config/theme.dart';
import '../../../config/app_colors.dart';
import '../../../models/models.dart';
import '../../../services/api_service.dart';
import '../cards/equipment_item_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/equipment_category_rail.dart';
import '../widgets/trust_badges.dart';

/// Equipment tab — loads the medical equipment & consumables catalog
/// (with fallback to the bundled JSON asset) and renders a Blinkit-style
/// quick-commerce browse layout: left category rail + dense 2-column grid
/// of compact buy / rent product cards.
class EquipmentTab extends StatefulWidget {
  /// Test seam: when provided, the catalog load (API / bundled JSON) is
  /// skipped and these items are used directly.
  final List<EquipmentItem>? initialItems;

  const EquipmentTab({super.key, this.initialItems});

  @override
  State<EquipmentTab> createState() => _EquipmentTabState();
}

class _EquipmentTabState extends State<EquipmentTab> {
  List<EquipmentItem> _allItems = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _selectedRailCategory = 'All';
  // Kept non-final: search is now driven by the universal app-bar search;
  // this field remains the local filter hook for re-wiring.
  // ignore: prefer_final_fields
  String _searchQuery = '';
  String _sortBy = 'Relevance';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  static const _categories = ['All', 'Sale', 'Rental'];
  static const _sortOptions = ['Relevance', 'Price: Low to High', 'Price: High to Low', 'Name A-Z'];

  @override
  void initState() {
    super.initState();
    if (widget.initialItems != null) {
      _allItems = widget.initialItems!;
      _isLoading = false;
    } else {
      _loadCatalog();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      // Try backend first
      _allItems = await ApiService().getEquipmentCatalog();
    } catch (_) {
      // Fallback: load from bundled JSON asset
      try {
        final jsonStr =
            await rootBundle.loadString('assets/equipment_catalog.json');
        final List<dynamic> list = json.decode(jsonStr);
        _allItems = list.map((e) => EquipmentItem.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error loading equipment catalog: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<EquipmentItem> get _filtered {
    var items = _allItems;
    if (_selectedRailCategory != 'All') {
      items = items
          .where((i) => railCategoryForItem(i) == _selectedRailCategory)
          .toList();
    }
    if (_selectedCategory == 'Sale') {
      items = items.where((i) => i.availableForSale).toList();
    } else if (_selectedCategory == 'Rental') {
      items = items.where((i) => i.availableForRent).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((i) =>
              i.name.toLowerCase().contains(q) ||
              i.brand.toLowerCase().contains(q) ||
              i.useCase?.toLowerCase().contains(q) == true)
          .toList();
    }
    // Apply sorting
    switch (_sortBy) {
      case 'Price: Low to High':
        items = List.of(items)
          ..sort((a, b) => (a.price ?? double.infinity).compareTo(b.price ?? double.infinity));
        break;
      case 'Price: High to Low':
        items = List.of(items)
          ..sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
        break;
      case 'Name A-Z':
        items = List.of(items)
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      default: // Relevance — keep original order
        break;
    }
    return items;
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Equipment':
        return Icons.medical_services;
      case 'Consumable':
        return Icons.inventory_2;
      case 'Medicine':
        return Icons.medication;
      default:
        return Icons.inventory_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingSkeleton(context);
    }

    final filtered = _filtered;
    final railCategories = buildRailCategories(_allItems);
    // Sale / Rental counts are scoped to the selected rail category so the
    // chips always reflect what's actually browsable in the grid.
    final railScoped = _selectedRailCategory == 'All'
        ? _allItems
        : _allItems
            .where((i) => railCategoryForItem(i) == _selectedRailCategory)
            .toList();

    return Column(
      children: [
        // Trust badges
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TrustBadgeBar(
            badges: [
              TrustBadge(
                  icon: Icons.local_shipping,
                  text: '24hr Delivery in Delhi NCR'),
              TrustBadge(
                  icon: Icons.verified, text: '100% Genuine Products'),
            ],
          ),
        ),
        // Blinkit-style browse: left category rail + dense product grid
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EquipmentCategoryRail(
                categories: railCategories,
                selected: _selectedRailCategory,
                onSelected: (cat) =>
                    setState(() => _selectedRailCategory = cat),
              ),
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    _buildControlsRow(context, railScoped),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const CatalogEmptyState()
                          : _buildGrid(context, filtered),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Initial-catalog-load skeleton: a 6-tile grid of grey squircle blocks
  /// matching the product card shape, swept by a shimmer highlight. When the
  /// user has reduced motion enabled (MediaQuery.disableAnimations) the
  /// blocks render static instead.
  Widget _buildLoadingSkeleton(BuildContext context) {
    final grid = Semantics(
      label: 'Loading equipment catalog',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const padding = 16.0, spacing = 8.0;
          final cardWidth =
              (constraints.maxWidth - padding * 2 - spacing) / 2;
          final cardHeight = cardWidth + 122;
          return GridView.builder(
            padding: const EdgeInsets.all(padding),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: cardHeight,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.hc.greyLighter,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: cardWidth * 0.6,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.hc.greyLighter,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: cardWidth * 0.9,
                  height: 14,
                  decoration: BoxDecoration(
                    color: context.hc.greyLighter,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: cardWidth * 0.4,
                  height: 14,
                  decoration: BoxDecoration(
                    color: context.hc.greyLighter,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (MediaQuery.of(context).disableAnimations) {
      return grid; // reduced motion: static grey blocks, no shimmer sweep
    }
    return Shimmer.fromColors(
      baseColor: context.hc.greyLighter,
      highlightColor: context.hc.white,
      child: grid,
    );
  }

  /// Slim Sale / Rental chip row + sort menu shown above the grid.
  Widget _buildControlsRow(
      BuildContext context, List<EquipmentItem> railScoped) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
      child: Row(
        children: [
          Expanded(
            // 44pt-tall hit row (Apple HIG minimum); the visual pill stays
            // 32px and is vertically centred inside each full-height InkWell.
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;
                  final count = cat == 'All'
                      ? railScoped.length
                      : cat == 'Sale'
                          ? railScoped.where((i) => i.availableForSale).length
                          : railScoped.where((i) => i.availableForRent).length;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '$cat items',
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () => setState(() => _selectedCategory = cat),
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: Container(
                            height: 32,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? HousepitalColors.orange
                                  : context.hc.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? HousepitalColors.orange
                                    : context.hc.divider,
                              ),
                            ),
                            child: Text(
                              '$cat ($count)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                // Dark ink on the orange fill — white on
                                // orange fails AA (~2.3:1).
                                color: isSelected
                                    ? context.hc.onOrange
                                    : context.hc.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sort dropdown — icon form renders an internal IconButton with
          // Material's standard 48pt touch target and a 'Sort' tooltip /
          // semantics label for free.
          PopupMenuButton<String>(
            initialValue: _sortBy,
            tooltip: 'Sort',
            icon: Icon(Icons.sort, size: 20, color: context.hc.grey),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => _sortOptions
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          if (s == _sortBy)
                            const Icon(Icons.check,
                                size: 16, color: HousepitalColors.orange)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(s,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: s == _sortBy
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: s == _sortBy
                                    ? HousepitalColors.orange
                                    : context.hc.black,
                              )),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// Dense 2-column grid of compact product cards. Card height is computed
  /// from the available width (square image + fixed text block) so the
  /// layout never overflows — even at 320px-wide screens.
  Widget _buildGrid(BuildContext context, List<EquipmentItem> filtered) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const padLeft = 10.0, padRight = 12.0, spacing = 8.0;
        final cardWidth =
            (constraints.maxWidth - padLeft - padRight - spacing) / 2;
        // 8+8 card padding + square image (cardWidth-16) + 24 ADD overlap +
        // 4 + 14 brand + 2 + 34 name + 4 + 16 mrp row + 2 + 18 price (+4 slack)
        final cardHeight = cardWidth + 122;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
              padLeft, 0, padRight, 24 + MediaQuery.of(context).padding.bottom),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: cardHeight,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return EquipmentItemCard(
              item: item,
              icon: _iconForCategory(item.category),
            );
          },
        );
      },
    );
  }
}
