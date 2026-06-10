// Blinkit-style vertical category rail for the Equipment tab.
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';

/// Key used for items whose use-case doesn't map to a primary clinical group.
const String kEquipmentRailOther = 'Other';

// Generic / tiny catalog use-cases folded into the 'Other' rail entry so the
// rail stays a focused 6-12 group list (Blinkit-style).
const Set<String> _genericUseCases = {
  'General Care',
  'General Consumables',
  'General Equipment',
  'Housekeeping & Pantry',
};

/// Pure function: maps an [EquipmentItem] to its rail category key.
///
/// The bundled catalog's `use_case` field already provides a sensible
/// clinical grouping (Orthopaedic, Respiratory, Cardiac & Vascular, …), so
/// the rail is driven directly by `useCase`; only the generic long-tail
/// buckets are folded into [kEquipmentRailOther].
String railCategoryForItem(EquipmentItem item) {
  final uc = item.useCase?.trim();
  if (uc == null || uc.isEmpty) return kEquipmentRailOther;
  if (_genericUseCases.contains(uc)) return kEquipmentRailOther;
  return uc;
}

/// Pure function: derives the ordered rail entries ('All' first, then groups
/// by descending item count, 'Other' always last) from the loaded catalog.
List<String> buildRailCategories(List<EquipmentItem> items) {
  final counts = <String, int>{};
  for (final item in items) {
    counts.update(railCategoryForItem(item), (v) => v + 1, ifAbsent: () => 1);
  }
  final keys = counts.keys.where((k) => k != kEquipmentRailOther).toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  if (counts.containsKey(kEquipmentRailOther)) keys.add(kEquipmentRailOther);
  return ['All', ...keys];
}

/// Short 2-line-max display label for a rail category key.
String railLabelFor(String category) {
  switch (category) {
    case 'Orthopaedic':
      return 'Ortho Support';
    case 'Cardiac & Vascular':
      return 'Cardiac';
    case 'Post-Surgical & Wound Care':
      return 'Wound Care';
    case 'Mobility & Patient Comfort':
      return 'Mobility';
    case 'Hygiene & Sanitation':
      return 'Hygiene';
    case 'Diagnostics & Monitoring':
      return 'Monitors';
    case 'Neurological & Physiotherapy':
      return 'Physio';
    default:
      return category; // 'All', 'Respiratory', 'Other', unseen use-cases
  }
}

/// Representative token-tinted icon for a rail category key.
IconData railIconFor(String category) {
  switch (category) {
    case 'All':
      return Icons.apps;
    case 'Respiratory':
      return Icons.air;
    case 'Orthopaedic':
      return Icons.accessibility_new;
    case 'Cardiac & Vascular':
      return Icons.monitor_heart;
    case 'Post-Surgical & Wound Care':
      return Icons.healing;
    case 'Mobility & Patient Comfort':
      return Icons.accessible;
    case 'Hygiene & Sanitation':
      return Icons.sanitizer;
    case 'Diagnostics & Monitoring':
      return Icons.speed;
    case 'Neurological & Physiotherapy':
      return Icons.fitness_center;
    default:
      return Icons.inventory_2;
  }
}

/// Blinkit-style left category rail: ~72px wide, vertically scrollable list
/// of small rounded icon tiles with 2-line labels. The selected entry gets an
/// orange accent bar, tinted tile and bold label.
class EquipmentCategoryRail extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const EquipmentCategoryRail({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: context.hc.divider)),
      ),
      child: ListView.builder(
        padding: EdgeInsets.only(
            top: 4, bottom: 24 + MediaQuery.of(context).padding.bottom),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;
          return _RailEntry(
            category: category,
            isSelected: isSelected,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class _RailEntry extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;

  const _RailEntry({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${railLabelFor(category)} category',
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.hc.orangeLight
                          : context.hc.greyLighter,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      railIconFor(category),
                      size: 22,
                      color: isSelected
                          ? HousepitalColors.orange
                          : context.hc.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    railLabelFor(category),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? context.hc.orangeText
                          : context.hc.grey,
                    ),
                  ),
                ],
              ),
            ),
            // Orange accent pill on the selected entry (Blinkit-style).
            if (isSelected)
              Positioned(
                left: 0,
                top: 12,
                child: Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: HousepitalColors.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
