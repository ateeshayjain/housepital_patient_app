// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../config/theme.dart';
import '../../../config/app_colors.dart';
import '../../../models/models.dart';
import '../../../utils/helpers.dart';
import '../../../widgets/common_widgets.dart';
import '../cards/diagnostic_card.dart';
import '../sheets/lab_test_detail_sheet.dart';
import '../widgets/catalog_search_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/trust_badges.dart';

/// Lab Tests tab — loads `assets/lab_tests_catalog.json` and surfaces an
/// individually-searchable lab test catalog, with the existing "popular
/// packages" (Fever Panel, Wellness, etc.) pinned at the top of the list
/// when no filter is active.
class LabTestsTab extends StatefulWidget {
  /// The existing lab packages (Fever Panel, Wellness, etc.) shown as
  /// "Popular Packages" at the top.
  final List<ServiceItem> packageServices;
  final Map<String, IconData> iconMap;
  final void Function(BuildContext, ServiceItem) onNavigateService;

  const LabTestsTab({
    super.key,
    required this.packageServices,
    required this.iconMap,
    required this.onNavigateService,
  });

  @override
  State<LabTestsTab> createState() => _LabTestsTabState();
}

class _LabTestsTabState extends State<LabTestsTab> {
  List<LabTestItem> _allTests = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _sortBy = 'Name A-Z';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  List<String> _categories = ['All'];

  static const _sortOptions = [
    'Name A-Z',
    'Price: Low to High',
    'Price: High to Low',
  ];

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
      final jsonStr =
          await rootBundle.loadString('assets/lab_tests_catalog.json');
      final List<dynamic> list = json.decode(jsonStr);
      _allTests = list.map((e) => LabTestItem.fromJson(e)).toList();
      // Build category list
      final cats = <String>{};
      for (final t in _allTests) {
        if (t.category != null) cats.add(t.category!);
      }
      _categories = ['All', ...cats.toList()..sort()];
    } catch (e) {
      debugPrint('Error loading lab tests catalog: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<LabTestItem> get _filtered {
    var items = _allTests;
    // Category filter
    if (_selectedCategory != 'All') {
      items = items.where((i) => i.category == _selectedCategory).toList();
    }
    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((i) =>
              i.name.toLowerCase().contains(q) ||
              (i.alsoKnownAs?.toLowerCase().contains(q) ?? false) ||
              (i.commonlyPrescribedFor?.toLowerCase().contains(q) ?? false) ||
              (i.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    // Sort
    switch (_sortBy) {
      case 'Price: Low to High':
        items = List.of(items)
          ..sort((a, b) =>
              (a.price ?? 999999).compareTo(b.price ?? 999999));
        break;
      case 'Price: High to Low':
        items = List.of(items)
          ..sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
        break;
      default: // Name A-Z
        items = List.of(items)
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
    return items;
  }

  void _showLabTestDetail(BuildContext context, LabTestItem test) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LabTestDetailSheet(
        test: test,
        onBook: () {
          widget.onNavigateService(context, test.toServiceItem());
        },
        onRelatedTap: (name) {
          Navigator.of(context).pop();
          setState(() {
            _searchQuery = name.trim();
            _searchController.text = name.trim();
            _selectedCategory = 'All';
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget();
    }

    final filtered = _filtered;
    final packages = widget.packageServices;

    return Column(
      children: [
        // Search
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
              TrustBadge(icon: Icons.workspace_premium, text: 'NABL Accredited Labs'),
              TrustBadge(icon: Icons.home, text: 'Home Collection'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Category chips + sort
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
                          ? _allTests.length
                          : _allTests.where((i) => i.category == cat).length;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
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
              PopupMenuButton<String>(
                icon: Icon(Icons.sort, color: context.hc.grey),
                onSelected: (v) => setState(() => _sortBy = v),
                itemBuilder: (_) => _sortOptions
                    .map((o) => PopupMenuItem(
                          value: o,
                          child: Row(
                            children: [
                              if (o == _sortBy)
                                const Icon(Icons.check,
                                    size: 18, color: HousepitalColors.orange)
                              else
                                const SizedBox(width: 18),
                              const SizedBox(width: 8),
                              Text(o),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filtered.length} tests found',
              style: TextStyle(
                  fontSize: 13, color: context.hc.greyLight),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Content list
        Expanded(
          child: filtered.isEmpty
              ? const CatalogEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount:
                      (packages.isNotEmpty && _searchQuery.isEmpty && _selectedCategory == 'All')
                          ? filtered.length + packages.length + 2
                          : filtered.length,
                  itemBuilder: (context, index) {
                    // Show packages section at the top when no search/filter active
                    if (packages.isNotEmpty &&
                        _searchQuery.isEmpty &&
                        _selectedCategory == 'All') {
                      if (index == 0) {
                        return Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            'Popular Packages',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: context.hc.black,
                            ),
                          ),
                        );
                      }
                      if (index <= packages.length) {
                        final pkg = packages[index - 1];
                        return DiagnosticCard(
                          service: pkg,
                          iconMap: widget.iconMap,
                          onNavigate: widget.onNavigateService,
                        );
                      }
                      if (index == packages.length + 1) {
                        return Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'All Individual Tests',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: context.hc.black,
                            ),
                          ),
                        );
                      }
                      // Offset for individual tests
                      final testIndex = index - packages.length - 2;
                      final test = filtered[testIndex];
                      return _LabTestCard(
                        test: test,
                        onTap: () => _showLabTestDetail(context, test),
                      );
                    }
                    // No packages header — just individual tests
                    final test = filtered[index];
                    return _LabTestCard(
                      test: test,
                      onTap: () => _showLabTestDetail(context, test),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Lab Test Card ────────────────────────────────────────────────────────────

class _LabTestCard extends StatelessWidget {
  final LabTestItem test;
  final VoidCallback onTap;

  const _LabTestCard({required this.test, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: context.hc.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                AppIconTile(
                    icon: Icons.science, color: context.hc.info),
                const SizedBox(width: 12),
                // Name + badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.hc.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (test.sampleType != null)
                            _MiniChip(
                                icon: Icons.colorize, label: test.sampleType!),
                          if (test.reportTat != null)
                            _MiniChip(
                                icon: Icons.schedule, label: test.reportTat!),
                          if (test.fastingRequired)
                            _MiniChip(
                                icon: Icons.no_food,
                                label: 'Fasting',
                                color: context.hc.warning),
                          if (test.homeCollection)
                            _MiniChip(
                                icon: Icons.home,
                                label: 'Home',
                                color: context.hc.success),
                        ],
                      ),
                    ],
                  ),
                ),
                // Price
                if (test.price != null)
                  Text(
                    DateHelper.formatCurrency(test.price!),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.hc.orangeText,
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    color: context.hc.greyLight, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MiniChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.hc.greyLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
