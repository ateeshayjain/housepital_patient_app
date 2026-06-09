// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../config/app_colors.dart';

/// Shared search bar used by the manpower, consultations, and diagnostics tabs
/// of the service catalog.
class CatalogSearchBar extends StatelessWidget {
  final String searchQuery;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const CatalogSearchBar({
    super.key,
    required this.searchQuery,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Semantics(
        label: 'Search services and equipment',
        textField: true,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: TextStyle(
            fontSize: 15,
            color: context.hc.black,
          ),
          decoration: InputDecoration(
            hintText: 'Search services, equipment...',
            hintStyle: TextStyle(
              fontSize: 15,
              color: context.hc.greyLight,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: context.hc.greyLight,
              size: 22,
            ),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    tooltip: 'Clear search',
                  )
                : null,
            filled: true,
            fillColor: context.hc.greyLighter,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: HousepitalColors.orange,
                width: 2,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
