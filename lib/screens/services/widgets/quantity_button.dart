// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../config/app_colors.dart';

/// Reusable +/- square button used by quantity / duration selectors
/// across the service catalog.
///
/// The visual square stays 36×36, but the tappable surface reserves an
/// invisible 44×44pt hit area around it (Apple HIG minimum touch target).
class QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// Screen-reader label. When omitted it is inferred from [icon]
  /// (Icons.add → 'Increase quantity', Icons.remove → 'Decrease quantity').
  final String? semanticLabel;

  const QuantityButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  String get _label {
    if (semanticLabel != null) return semanticLabel!;
    if (icon == Icons.add) return 'Increase quantity';
    if (icon == Icons.remove) return 'Decrease quantity';
    return 'Change quantity';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.hc.orangeLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: HousepitalColors.orange),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
