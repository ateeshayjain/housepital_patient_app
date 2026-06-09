// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../models/models.dart';
import '../cards/consultation_card.dart';
import '../widgets/catalog_search_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/trust_badges.dart';

/// Consultations tab — used for both the "Consultations" (doctor /
/// psychiatrist / grief counselling) and "Visits" (IV, IM, dressing, etc.)
/// sub-tabs. Different seed lists are passed via [services].
class ConsultationsTab extends StatelessWidget {
  final List<ServiceItem> services;
  final Map<String, IconData> iconMap;
  final String searchQuery;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final List<ServiceItem> Function(List<ServiceItem>) filterBySearch;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const ConsultationsTab({
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
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Visual category hero header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.hc.info, Color(0xFF42A5F5)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expert Medical Consultations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Doctor visits, mental health & therapy',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                  icon: Icons.verified_user,
                  text: 'Licensed Professionals'),
              TrustBadge(
                  icon: Icons.home,
                  text: 'Home or Video Visit'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...filtered.map((s) => ConsultationCard(
              service: s,
              iconMap: iconMap,
              onNavigate: onNavigate,
            )),
      ],
    );
  }
}
