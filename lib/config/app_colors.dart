import 'package:flutter/material.dart';
import 'theme.dart';

/// Theme-aware color resolver for dark-mode support.
///
/// The app's screens historically hardcoded the LIGHT palette
/// (`HousepitalColors.white/black/grey/divider/…`), so in dark mode dark text
/// rendered on dark backgrounds and white cards stayed white. This resolver
/// maps each brightness-sensitive token to its correct value for the current
/// `Theme.of(context).brightness`.
///
/// Usage: replace `HousepitalColors.<token>` with `context.hc.<token>` for any
/// color that must differ between light and dark (surfaces, text, dividers,
/// status families, orange tints). Brand-CONSTANT colors that read fine on both
/// backgrounds — `HousepitalColors.orange` and the `service*` category colors —
/// can stay as static references.
extension HcColors on BuildContext {
  HcPalette get hc => Theme.of(this).brightness == Brightness.dark
      ? const HcPalette.dark()
      : const HcPalette.light();
}

/// Decorative hero-gradient stops. These are the ONLY sanctioned gradient
/// hexes (mirrored in the allowlist of scripts/check_design_consistency.sh) —
/// screens must reference these named constants instead of re-typing the
/// literals. Each `*End` is the lighter end-stop paired with a token start
/// (orange / hc.info / hc.success).
class HeroGradient {
  HeroGradient._();

  static const Color orangeStart = Color(0xFFFF8C00);
  static const Color orangeEnd = Color(0xFFFF6B35);
  static const Color blueEnd = Color(0xFF42A5F5);
  static const Color greenEnd = Color(0xFF66BB6A);
}

class HcPalette {
  // Neutrals
  final Color background; // page background
  final Color surface; // card / sheet surface
  final Color white; // alias of surface (most call sites say "white")
  final Color greyLighter; // subtle fill / chip background
  final Color black; // primary text
  final Color grey; // secondary text
  final Color greyLight; // tertiary text / icons
  final Color divider;

  // Status families (foreground + tint background)
  final Color success;
  final Color successLight;
  final Color warning;
  final Color warningLight;
  final Color error;
  final Color errorLight;
  /// Text/icons ON an error fill — flips with appearance (see theme.dart).
  final Color onError;
  final Color info;
  final Color infoLight;

  // Orange family (orange itself is constant; text/dark/tint variants differ)
  final Color orange;
  final Color orangeText;
  /// Brand orange safe for SMALL text on light surfaces (5.38:1).
  final Color orangeStrong;
  final Color orangeDark;
  final Color orangeLight;
  // Text/icons ON an orange fill. White on orange fails AA (~2.3:1), so both
  /// Text/icons ON an orange fill. WHITE in both appearances by explicit owner
  /// decision — measured 2.33:1, recorded as an accepted risk. The older
  /// comment here claimed dark ink at 6.3:1, which described a palette that no
  /// longer exists and read as a standing justification to revert the owner's
  /// call. Do not.
  final Color onOrange;

  // Misc semantic
  final Color sos;
  final Color checkedIn;
  final Color vitalNormal;
  final Color vitalBorderline;
  final Color vitalAlert;

  const HcPalette.light()
      : background = HousepitalColors.background,
        surface = HousepitalColors.surface,
        white = HousepitalColors.white,
        greyLighter = HousepitalColors.greyLighter,
        black = HousepitalColors.black,
        grey = HousepitalColors.grey,
        greyLight = HousepitalColors.greyLight,
        divider = HousepitalColors.divider,
        success = HousepitalColors.success,
        successLight = HousepitalColors.successLight,
        warning = HousepitalColors.warning,
        warningLight = HousepitalColors.warningLight,
        error = HousepitalColors.error,
        errorLight = HousepitalColors.errorLight,
        onError = HousepitalColors.onError,
        info = HousepitalColors.info,
        infoLight = HousepitalColors.infoLight,
        orange = HousepitalColors.orange,
        orangeText = HousepitalColors.orangeText,
        orangeStrong = HousepitalColors.orangeStrong,
        orangeDark = HousepitalColors.orangeDark,
        orangeLight = HousepitalColors.orangeLight,
        onOrange = HousepitalColors.onOrange,
        sos = HousepitalColors.sos,
        checkedIn = HousepitalColors.checkedIn,
        vitalNormal = HousepitalColors.vitalNormal,
        vitalBorderline = HousepitalColors.vitalBorderline,
        vitalAlert = HousepitalColors.vitalAlert;

  const HcPalette.dark()
      : background = HousepitalColorsDark.surface,
        surface = HousepitalColorsDark.surfaceElevated,
        white = HousepitalColorsDark.surfaceElevated,
        greyLighter = HousepitalColorsDark.surfaceHigh,
        black = HousepitalColorsDark.textPrimary,
        grey = HousepitalColorsDark.textSecondary,
        greyLight = HousepitalColorsDark.textDisabled,
        divider = HousepitalColorsDark.divider,
        success = HousepitalColorsDark.success,
        successLight = HousepitalColorsDark.successLight,
        warning = HousepitalColorsDark.warning,
        warningLight = HousepitalColorsDark.warningLight,
        error = HousepitalColorsDark.error,
        errorLight = HousepitalColorsDark.errorLight,
        onError = HousepitalColorsDark.onError,
        info = HousepitalColorsDark.info,
        infoLight = HousepitalColorsDark.infoLight,
        orange = HousepitalColorsDark.orange,
        orangeText = HousepitalColorsDark.orange,
        orangeStrong = HousepitalColorsDark.orangeStrong,
        orangeDark = HousepitalColorsDark.orange,
        orangeLight = HousepitalColorsDark.orangeMuted,
        onOrange = HousepitalColorsDark.onOrange,
        sos = HousepitalColorsDark.sos,
        checkedIn = HousepitalColorsDark.success,
        vitalNormal = HousepitalColorsDark.vitalNormal,
        vitalBorderline = HousepitalColorsDark.vitalBorderline,
        vitalAlert = HousepitalColorsDark.vitalAlert;
}
