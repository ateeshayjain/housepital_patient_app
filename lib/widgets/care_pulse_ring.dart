// lib/widgets/care_pulse_ring.dart
//
// CARE PULSE RING — Housepital's signature progress ring. ONE widget for
// every determinate progress ring in the app (adherence, task completion,
// report progress), the way Apple owns Activity rings.
//
// Visual canon:
//   • Round (capped) stroke ends — soft, clinical-calm.
//   • Track in context.hc.orangeLight (brand-warm, low-contrast base).
//   • Arc sweeps clockwise from 12 o'clock.
//   • Arc color glides orange → success-green as value approaches 1.0:
//     pure orange below ~0.75, full green only at ≥ 0.95, eased in between —
//     "nearly there" still reads warm-orange, "done" reads green.
//   • Optional center child (e.g. '86%' or '3/5').
//
// Motion: on first build the sweep animates 0 → value over 600ms easeOutCubic,
// once per widget lifecycle (TweenAnimationBuilder). When the platform asks
// for reduced motion (MediaQuery.disableAnimations) the ring renders its
// final value immediately (Duration.zero) — no sweep, no flash.
//
// Implemented with a CustomPainter because CircularProgressIndicator can't do
// capped stroke ends + a lerped arc color cleanly.
//
// NEVER use this for indeterminate loading spinners — those stay
// CircularProgressIndicator.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class CarePulseRing extends StatelessWidget {
  /// Progress, 0.0–1.0 (clamped).
  final double value;

  /// Outer diameter of the ring.
  final double size;

  /// Stroke width. Defaults to a size-proportional width (size / 10,
  /// clamped 3–8) so small and large rings stay visually consistent.
  final double? strokeWidth;

  /// Optional widget centred inside the ring (e.g. Text('86%')).
  final Widget? center;

  /// Accessibility label. Defaults to "[value] percent" (e.g. '86 percent').
  final String? semanticLabel;

  /// Override for the track color. Defaults to context.hc.orangeLight.
  /// Only override when the ring sits on a surface where the brand track
  /// can't hold contrast (e.g. white-on-orange hero headers).
  final Color? trackColor;

  /// Fixed arc color override. When set, the orange → green lerp is
  /// disabled. Only for surfaces where the lerped arc can't hold contrast.
  final Color? color;

  const CarePulseRing({
    super.key,
    required this.value,
    required this.size,
    this.strokeWidth,
    this.center,
    this.semanticLabel,
    this.trackColor,
    this.color,
  });

  /// Orange → success-green interpolation factor for [value]:
  /// 0 below 0.75, eased ramp 0.75–0.95, 1 at ≥ 0.95.
  static double colorLerpT(double value) {
    if (value >= 0.95) return 1.0; // full green from 95% up — exactly.
    final t = ((value - 0.75) / 0.20).clamp(0.0, 1.0);
    return Curves.easeIn.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    final clamped = value.clamp(0.0, 1.0);
    final stroke = strokeWidth ?? (size / 10).clamp(3.0, 8.0);
    final track = trackColor ?? hc.orangeLight;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: semanticLabel ?? '${(clamped * 100).round()} percent',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          // Animates 0 → value once on first build; later value changes
          // glide from the currently painted value (calm, no restart).
          tween: Tween<double>(begin: 0, end: clamped),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, child) => CustomPaint(
            painter: _CarePulseRingPainter(
              value: animatedValue,
              trackColor: track,
              // Lerp the arc color along WITH the sweep so the ring never
              // flashes green before it has visually arrived.
              arcColor: color ??
                  Color.lerp(
                    hc.orange,
                    hc.success,
                    colorLerpT(animatedValue),
                  )!,
              strokeWidth: stroke,
            ),
            child: child,
          ),
          child: center == null ? null : Center(child: center),
        ),
      ),
    );
  }
}

class _CarePulseRingPainter extends CustomPainter {
  final double value;
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  const _CarePulseRingPainter({
    required this.value,
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    final sweep = value.clamp(0.0, 1.0) * 2 * math.pi;
    // Skip near-zero sweeps: a capped zero-length arc would paint a dot.
    if (sweep <= 0.001) return;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    // Start at 12 o'clock (-pi/2), sweep clockwise.
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(_CarePulseRingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.arcColor != arcColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
