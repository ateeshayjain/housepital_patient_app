// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../cards/staff_role_card.dart';
import '../data/staff_roles_seed.dart';
import '../widgets/catalog_search_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/trust_badges.dart';

/// Manpower tab — surfaces the role-based catalog (Caretaker, Nurse,
/// Japa Maid, Nanny, Physiotherapist) instead of individual SKUs.
class ManpowerTab extends StatelessWidget {
  final List<ServiceItem> services;
  final Map<String, IconData> iconMap;
  final String searchQuery;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final List<ServiceItem> Function(List<ServiceItem>) filterBySearch;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const ManpowerTab({
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
    // Filter roles by search
    final roles = searchQuery.isEmpty
        ? staffRoles
        : staffRoles
            .where((r) =>
                r.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                r.subtitle.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

    if (roles.isEmpty && searchQuery.isNotEmpty) {
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF8C00), Color(0xFFFF6B35)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Professional Care at Home',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Background-verified nurses, caretakers & specialists',
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
                  text: 'Housepital Guarantee'),
              TrustBadge(
                  icon: Icons.check_circle_outline,
                  text: 'Background Verified'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...roles.map((role) => StaffRoleCard(
              role: role,
              services: services,
              onNavigate: onNavigate,
            )),
      ],
    );
  }
}
