// audit batch 4 (Agent K): extracted from service_catalog_screen.dart.
// Now a thin wrapper over the shared HousepitalEmptyState
// (lib/widgets/empty_state.dart) so every empty state shares one calm style.
import 'package:flutter/material.dart';
import '../../../widgets/empty_state.dart';

/// Empty-state widget shown when a catalog search yields no matches.
class CatalogEmptyState extends StatelessWidget {
  const CatalogEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const HousepitalEmptyState(
      icon: Icons.search_off,
      title: 'No services found',
      body: 'Try a different search term',
    );
  }
}
