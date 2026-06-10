// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../cards/consultation_card.dart';
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
      return const CatalogEmptyState();
    }

    return ListView(
      padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom),
      children: [
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
