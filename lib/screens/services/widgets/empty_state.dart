// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';

/// Empty-state widget shown when a catalog search yields no matches.
class CatalogEmptyState extends StatelessWidget {
  const CatalogEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 56,
            color: HousepitalColors.greyLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'No services found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HousepitalColors.grey,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: HousepitalColors.greyLight,
            ),
          ),
        ],
      ),
    );
  }
}
