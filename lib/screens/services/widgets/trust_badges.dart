// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// A single trust badge shown inside a [TrustBadgeBar].
class TrustBadge {
  final IconData icon;
  final String text;
  const TrustBadge({required this.icon, required this.text});
}

/// Horizontal bar showing trust badges (verified, NABL accredited, etc.)
/// across the top of each catalog tab.
class TrustBadgeBar extends StatelessWidget {
  final List<TrustBadge> badges;
  const TrustBadgeBar({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.hc.successLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: badges.expand((badge) {
          final index = badges.indexOf(badge);
          return [
            if (index > 0) ...[
              Container(
                width: 1,
                height: 16,
                color: context.hc.success.withValues(alpha: 0.3),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ],
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badge.icon,
                      size: 16, color: context.hc.success),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      badge.text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.hc.success,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ];
        }).toList(),
      ),
    );
  }
}
