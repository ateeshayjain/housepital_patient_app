import 'dart:ui';

import 'package:flutter/material.dart';

/// Liquid-Glass-style material primitives (Flutter approximation).
///
/// Apple's Liquid Glass is a system-rendered material; Flutter approximates
/// the structural feel with a backdrop blur + a brightness-tinted translucent
/// fill + a hairline edge highlight. Per Apple's own guidance, glass is for
/// CHROME (bars, floating controls) — never for content surfaces that carry
/// medical text, vitals, or prices (legibility first).
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;

  /// Blur strength. 20 reads as "regular" glass; keep consistent app-wide.
  final double sigma;

  /// Fill opacity over the blur. Higher = more legible, less glassy.
  final double opacity;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.sigma = 20,
    this.opacity = 0.72,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark
        ? const Color(0xFF1F1F1F).withValues(alpha: opacity)
        : Colors.white.withValues(alpha: opacity);
    // Top edge highlight sells the "pane of glass" read.
    final edge = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.6);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: borderRadius != null
                ? Border.all(color: edge, width: 0.5)
                : Border(top: BorderSide(color: edge, width: 0.5)),
          ),
          child: child,
        ),
      ),
    );
  }
}
