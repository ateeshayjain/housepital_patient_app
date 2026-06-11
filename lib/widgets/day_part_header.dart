// lib/widgets/day_part_header.dart
//
// THE day-part motif. Morning/afternoon/evening grouping appears wherever the
// app lays a day out as a routine (care calendar dose groups, daily report
// medication adherence) — day-rhythm-as-structure is culturally true to Indian
// home care (subah / dopahar / raat). This widget is the single source of that
// motif: one icon set, one tint set, one label voice. Screens must use it
// instead of hand-rolling icon + 'MORNING' rows with divergent icons.
import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// The three parts of a care day. Boundaries mirror the care calendar's
/// long-standing dose grouping EXACTLY: morning < 12:00, afternoon
/// 12:00–16:59, evening 17:00+.
enum DayPart {
  morning,
  afternoon,
  evening;

  /// Maps a 24h hour to its day part (see boundary comment above).
  static DayPart fromHour(int hour) {
    if (hour < 12) return DayPart.morning;
    if (hour < 17) return DayPart.afternoon;
    return DayPart.evening;
  }
}

/// One-line group header (~28px): a 24px tinted icon tile, the bilingual
/// part label, and an optional right-aligned [trailing] count.
class DayPartHeader extends StatelessWidget {
  final DayPart part;
  final String? trailing;

  const DayPartHeader(this.part, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final hc = context.hc;
    // (icon, tile tint bg, tile icon color, label) per part. Tints reuse
    // existing token families — no new colors.
    final (IconData icon, Color tileBg, Color tileFg, String label) =
        switch (part) {
      DayPart.morning => (
          Icons.wb_sunny_outlined,
          hc.orangeLight,
          hc.orangeText,
          'Morning · Subah',
        ),
      DayPart.afternoon => (
          Icons.wb_twilight,
          hc.warningLight,
          hc.warning,
          'Afternoon · Dopahar',
        ),
      DayPart.evening => (
          Icons.nightlight_outlined,
          hc.infoLight,
          hc.info,
          'Evening · Raat',
        ),
    };

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: tileFg),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: hc.grey,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(fontSize: 12, color: hc.greyLight),
            ),
        ],
      ),
    );
  }
}
