// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../config/theme.dart';
import '../../../config/app_colors.dart';
import '../../../models/models.dart';
import '../../../services/api_service.dart';
import '../../../widgets/common_widgets.dart';
import '../cards/equipment_item_card.dart';
import '../widgets/catalog_search_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/trust_badges.dart';

/// Equipment tab — loads the medical equipment & consumables catalog
/// (with fallback to the bundled JSON asset) and renders the buy / rent
/// browsing grid.
class EquipmentTab extends StatefulWidget {
  const EquipmentTab({super.key});

  @override
  State<EquipmentTab> createState() => _EquipmentTabState();
}

class _EquipmentTabState extends State<EquipmentTab> {
  List<EquipmentItem> _allItems = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _sortBy = 'Relevance';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  static const _categories = ['All', 'Sale', 'Rental'];
  static const _sortOptions = ['Relevance', 'Price: Low to High', 'Price: High to Low', 'Name A-Z'];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
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
      return const LoadingWidget();
    }

    final filtered = _filtered;

    return Column(
      children: [
        const SizedBox(height: 8),
        CatalogSearchBar(
          searchQuery: _searchQuery,
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
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
        const SizedBox(height: 8),
        // Category chips + sort dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = cat == _selectedCategory;
                      final count = cat == 'All'
                          ? _allItems.length
                          : cat == 'Sale'
                              ? _allItems.where((i) => i.availableForSale).length
                              : _allItems.where((i) => i.availableForRent).length;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? HousepitalColors.orange
                        : context.hc.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? HousepitalColors.orange
                          : context.hc.divider,
                    ),
                  ),
                  child: Text(
                    '$cat ($count)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? context.hc.white
                          : context.hc.grey,
                    ),
                  ),
                ),
              );
            },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sort dropdown
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: (v) => setState(() => _sortBy = v),
                itemBuilder: (_) => _sortOptions
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              if (s == _sortBy)
                                const Icon(Icons.check, size: 16, color: HousepitalColors.orange)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 8),
                              Text(s, style: TextStyle(
                                fontSize: 13,
                                fontWeight: s == _sortBy ? FontWeight.w600 : FontWeight.w400,
                                color: s == _sortBy ? HousepitalColors.orange : context.hc.black,
                              )),
                            ],
                          ),
                        ))
                    .toList(),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: context.hc.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.hc.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort, size: 16, color: context.hc.grey),
                      const SizedBox(width: 4),
                      Text(
                        _sortBy == 'Relevance' ? 'Sort' : _sortBy.split(':').first.trim(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.hc.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${filtered.length} items',
                style: TextStyle(
                  fontSize: 13,
                  color: context.hc.greyLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Grid
        Expanded(
          child: filtered.isEmpty
              ? const CatalogEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return EquipmentItemCard(
                      item: item,
                      icon: _iconForCategory(item.category),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
