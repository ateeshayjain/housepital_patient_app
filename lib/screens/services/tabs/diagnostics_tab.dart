// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../cards/diagnostic_card.dart';
import '../widgets/catalog_search_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/trust_badges.dart';

/// Diagnostics tab — at-home tests with equipment (ECG, X-Ray, Holter).
class DiagnosticsTab extends StatelessWidget {
  final List<ServiceItem> services;
  final Map<String, IconData> iconMap;
  final String searchQuery;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final List<ServiceItem> Function(List<ServiceItem>) filterBySearch;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const DiagnosticsTab({
    super.key,
    required this.services,
    required this.iconMap,
    required this.searchQuery,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.filterBySearch,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = filterBySearch(services);

    if (filtered.isEmpty && searchQuery.isNotEmpty) {
      return Column(
        children: [
          CatalogSearchBar(
            searchQuery: searchQuery,
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: onSearchChanged,
          ),
          const Expanded(child: CatalogEmptyState()),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom),
      children: [
        CatalogSearchBar(
          searchQuery: searchQuery,
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: onSearchChanged,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TrustBadgeBar(
            badges: [
              TrustBadge(
                  icon: Icons.workspace_premium,
                  text: 'NABL Accredited Labs'),
              TrustBadge(icon: Icons.home, text: 'Home Collection'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...filtered.map((s) => DiagnosticCard(
              service: s,
              iconMap: iconMap,
              onNavigate: onNavigate,
            )),
      ],
    );
  }
}
