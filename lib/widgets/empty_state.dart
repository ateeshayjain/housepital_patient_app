// Shared empty-state widget (generalized from the services catalog's
// CatalogEmptyState, which now wraps this).
//
// Voice rule for empty-state copy: "what this space will hold + who's behind
// it" — warm, factual, no database language, no exclamation marks.
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'common_widgets.dart';

/// Calm, consistent empty state used across screens.
///
/// Full variant (default): centered column — 40px icon in an
/// `hc.orangeLight` tile, 15px w600 title, 13px `hc.grey` body, optional
/// tonal stadium-pill CTA (visual height 32, padded ≥44pt tap target).
///
/// Compact variant ([HousepitalEmptyState.compact]): a single
/// [HousepitalCard] row (small icon tile + title/body) for inline detail
/// sections; never shows a CTA.
class HousepitalEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool _compact;

  const HousepitalEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
  }) : _compact = false;

  const HousepitalEmptyState.compact({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  })  : ctaLabel = null,
        onCta = null,
        _compact = true;

  @override
  Widget build(BuildContext context) {
    if (_compact) return _buildCompact(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.hc.orangeLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 40, color: context.hc.orangeText),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.hc.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: context.hc.grey,
              ),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 16),
              // Tonal stadium pill: small visual, but the padded Material
              // tap target keeps the interactive area ≥ 44pt.
              FilledButton.tonal(
                onPressed: onCta,
                style: FilledButton.styleFrom(
                  backgroundColor: context.hc.orangeLight,
                  foregroundColor: context.hc.orangeText,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return HousepitalCard(
      child: Row(
        children: [
          AppIconTile(icon: icon, color: context.hc.orangeText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.hc.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(fontSize: 13, color: context.hc.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
