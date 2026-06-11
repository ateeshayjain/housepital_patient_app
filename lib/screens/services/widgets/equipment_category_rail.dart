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

/// Name-keyword override: maps well-known product names to their clinical
/// rail bucket, regardless of the catalog's hand-entered `use_case`.
///
/// Product names are far more reliable than `use_case` — the shipped catalog
/// tags every wheelchair/walker/crutch as 'Orthopaedic' and parks AMBU bags
/// under 'General Care'. Checked BEFORE the use_case fold in
/// [railCategoryForItem]. Returns null when no keyword matches.
String? _railCategoryFromName(String name) {
  final n = name.toLowerCase();
  bool has(String k) => n.contains(k);

  // Exception first: a 'walker boot' is an orthopaedic cast boot, not a
  // mobility walker — it must not be caught by the 'walker' keyword below.
  if (has('walker boot')) return 'Orthopaedic';

  // Mobility aids + patient beds/furniture.
  if (has('wheelchair') ||
      has('walker') ||
      has('walking stick') ||
      has('crutch') ||
      has('cane') ||
      has('commode') ||
      has('hospital bed') ||
      has('mattress') ||
      has('backrest')) {
    return 'Mobility & Patient Comfort';
  }

  // Respiratory therapy & oxygen.
  if (has('bipap') ||
      has('bi-pap') ||
      has('cpap') ||
      has('c-pap') ||
      has('vpap') ||
      has('oxygen') ||
      has('o2 cylinder') ||
      has('ventilat') || // Ventilator / Ventilation System
      has('nebuli') || // Nebulizer / Nebulization Mask
      has('ambu bag') ||
      has('steamer') ||
      has('air filter')) {
    return 'Respiratory';
  }

  // Cardiac & vascular monitoring.
  if (has('pulse oximeter') ||
      has('ecg') ||
      has('bp monitor') ||
      has('bp cuff') ||
      has('bp instrument') ||
      has('bp appratus')) {
    return 'Cardiac & Vascular';
  }

  // Wound care & post-surgical.
  if (has('dressing') || has('suction')) {
    return 'Post-Surgical & Wound Care';
  }

  // Hygiene & sanitation consumables.
  if (has('diaper') ||
      has('underpad') ||
      has('seat raiser') ||
      has('toilet seat') ||
      has('bed pan') ||
      has('bedpan') ||
      has('n95') ||
      has('3 ply mask')) {
    return 'Hygiene & Sanitation';
  }

  // Ortho supports — generic terms last so the buckets above win first.
  if (has('brace') || has('splint') || has('collar') || has('belt')) {
    return 'Orthopaedic';
  }

  return null;
}

/// Pure function: maps an [EquipmentItem] to its rail category key.
///
/// Resolution order:
/// 1. Name-keyword override ([_railCategoryFromName]) — product names are
///    more reliable than the catalog's hand-entered `use_case`.
/// 2. The catalog's `use_case` clinical grouping (Orthopaedic, Respiratory,
///    Cardiac & Vascular, …).
/// 3. Generic long-tail use-cases (and missing ones) fold into
///    [kEquipmentRailOther].
String railCategoryForItem(EquipmentItem item) {
  final byName = _railCategoryFromName(item.name);
  if (byName != null) return byName;
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

/// Rail width. 80px (up from 72) lets 'Respiratory' render on a single
/// unbroken line at the full 11px label size on device.
const double kEquipmentRailWidth = 80;

/// Blinkit-style left category rail: 80px wide, vertically scrollable list
/// of small rounded icon tiles with centred labels (single-word labels stay
/// on one line and scale down instead of wrapping mid-word). The selected
/// entry gets an orange accent bar, tinted tile and bold label.
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
      width: kEquipmentRailWidth,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: context.hc.divider)),
      ),
      child: ListView.builder(
        // Vertical rhythm: the first icon tile top-aligns with the Sale/Rental
        // chip pills next to it. Pill top = 4 (spacer) + 2 (44px chip strip
        // centred in the 48px controls row) + 6 (32px pill centred in 44) =
        // 12; rail tile top = 4 (this padding) + 8 (entry padding) = 12.
        // Bottom: same extendBody clearance as the product grid, so the last
        // tile ('Hygiene'/'Other') clears the glass bottom nav.
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
    final label = railLabelFor(category);
    final isSingleWord = !label.contains(' ');
    final labelStyle = TextStyle(
      fontSize: 11,
      height: 1.1,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      color: isSelected ? context.hc.orangeText : context.hc.grey,
    );
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label category',
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              // One shared horizontal inset for tile + label; both are
              // centred on the rail's vertical axis by the Column below.
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  // Single-word labels ('Respiratory', 'Hygiene') must never
                  // wrap mid-word ('Respirator / y'): force one line and let
                  // FittedBox scale down on the rare width that needs it.
                  // Multi-word labels ('Ortho Support') wrap naturally onto
                  // two lines at full size.
                  if (isSingleWord)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: labelStyle,
                      ),
                    )
                  else
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
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
