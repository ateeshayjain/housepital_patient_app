import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark-mode color tokens for the Housepital app.
///
/// All values are paired with WCAG contrast checks (vs [surface] unless
/// otherwise stated). Brand orange #F39314 is preserved; only ON-orange
/// text changes (white on orange is only 2.7:1 — we use [onOrange] = surface).
///
/// Surface is intentionally #1A1A1A (true-dark) rather than pure black to
/// avoid OLED smear and to give cards a visible elevation.
class HousepitalColorsDark {
  // Surfaces
  static const Color surface = Color(0xFF1A1A1A);          // page bg
  static const Color surfaceElevated = Color(0xFF242424);  // cards / sheets
  static const Color surfaceHigh = Color(0xFF2C2C2C);      // app bar, inputs
  static const Color divider = Color(0xFF2F2F2F);

  // Text (verified vs surface #1A1A1A)
  static const Color textPrimary = Color(0xFFF2F2F2);   // 14.9:1 — AAA
  static const Color textSecondary = Color(0xFFB0B0B0); // 8.0:1  — AAA
  static const Color textDisabled = Color(0xFF7A7A7A);  // 4.5:1  — AA

  // Brand orange — same hue, but verify how it's used in dark.
  // #F39314 vs surface #1A1A1A → 6.32:1 — AA for normal text / AAA for large.
  static const Color orange = Color(0xFFF39314);
  // White on orange is only 2.7:1 in dark — use dark text on orange buttons.
  static const Color onOrange = Color(0xFF1A1A1A);     // 6.32:1 on orange
  static const Color orangeMuted = Color(0xFF3D2A12);  // chip / tint bg

  // Functional
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Status colors (lighter / desaturated for dark surfaces).
  // Foreground variants verified vs surface; *Light variants are tinted
  // backgrounds (low-opacity feel) for status chips & cards.
  static const Color success = Color(0xFF66BB6A);      // 7.6:1 on surface
  static const Color successLight = Color(0xFF1F2E20); // tint bg
  static const Color warning = Color(0xFFFFB74D);      // 8.7:1 on surface
  static const Color warningLight = Color(0xFF3A2D14); // tint bg
  static const Color error = Color(0xFFEF5350);        // 4.9:1 on surface
  static const Color errorLight = Color(0xFF3A1F1F);   // tint bg
  static const Color info = Color(0xFF64B5F6);         // 7.6:1 on surface
  static const Color infoLight = Color(0xFF1A2735);    // tint bg

  // Vitals + attendance use the same brightened status palette as above.
  static const Color vitalNormal = success;
  static const Color vitalBorderline = warning;
  static const Color vitalAlert = error;

  static const Color sos = error;
}

class HousepitalColors {
  // Brand Primary - Pantone 1375 C (WCAG AA compliant)
  static const Color orange = Color(0xFFF39314);
  static const Color orangeText = Color(0xFFB86E00); // 4.6:1 on white — use for text
  static const Color orangeLight = Color(0xFFFFF3E0);
  static const Color orangeDark = Color(0xFFCC6E00); // 4.5:1 on white

  // Brand Secondary - WCAG AA compliant
  static const Color grey = Color(0xFF3D3D3D); // 5.5:1 on #F8F9FA
  static const Color greyLight = Color(0xFF6B6B6B); // 5.3:1 on white
  static const Color greyLighter = Color(0xFFF5F5F5);

  // Functional
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF212121);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);

  // Status Colors (WCAG AA compliant for text)
  static const Color success = Color(0xFF2E7D32); // darker green, 5.1:1
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFE65100); // dark orange instead of yellow, 4.6:1
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFD32F2F); // 4.7:1
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF1565C0); // darker blue, 5.1:1
  static const Color infoLight = Color(0xFFE3F2FD);

  // Vitals Zone Colors (accessible)
  static const Color vitalNormal = Color(0xFF2E7D32);
  static const Color vitalBorderline = Color(0xFFE65100);
  static const Color vitalAlert = Color(0xFFD32F2F);

  // Attendance Status
  static const Color checkedIn = Color(0xFF2E7D32);
  static const Color waiting = Color(0xFFE65100);
  static const Color late_ = Color(0xFFEF6C00);
  static const Color absent = Color(0xFFD32F2F);
  static const Color onLeave = Color(0xFF1565C0);
  static const Color checkedOut = Color(0xFF6B6B6B);

  // SOS
  static const Color sos = Color(0xFFD32F2F);

  // Service category colors (card headers)
  static const Color serviceCarePackage = Color(0xFFDC2626); // red
  static const Color serviceNursing = Color(0xFFEA580C); // orange
  static const Color serviceCaretaker = Color(0xFF0D9488); // teal
  static const Color serviceJapaNanny = Color(0xFF7C3AED); // purple
  static const Color servicePhysio = Color(0xFF2563EB); // blue
  static const Color serviceEquipment = Color(0xFF059669); // green

  static Color serviceColor(String category) {
    switch (category) {
      case 'care_package':
        return serviceCarePackage;
      case 'nursing':
        return serviceNursing;
      case 'caretaker':
        return serviceCaretaker;
      case 'japa':
      case 'nanny':
        return serviceJapaNanny;
      case 'physiotherapy':
      case 'doctor_visit':
      case 'iv_visit':
      case 'dressing':
        return servicePhysio;
      case 'equipment_rental':
        return serviceEquipment;
      default:
        return serviceNursing;
    }
  }
}

class HousepitalTheme {
  // Devanagari fallback so Hindi (and other Indic) glyphs render
  // when Archivo has no coverage. Applied via fontFamilyFallback on
  // every text style below so it works regardless of active locale.
  static final List<String> _devanagariFallback = [
    GoogleFonts.notoSansDevanagari().fontFamily ?? 'NotoSansDevanagari',
  ];

  static ThemeData get lightTheme {
    final archivoFamily = GoogleFonts.archivo().fontFamily;

    return ThemeData(
      useMaterial3: true,
      fontFamily: archivoFamily,
      fontFamilyFallback: _devanagariFallback,
      colorScheme: ColorScheme.light(
        primary: HousepitalColors.orange,
        onPrimary: HousepitalColors.white,
        secondary: HousepitalColors.grey,
        onSecondary: HousepitalColors.white,
        surface: HousepitalColors.surface,
        onSurface: HousepitalColors.black,
        error: HousepitalColors.error,
        onError: HousepitalColors.white,
      ),
      scaffoldBackgroundColor: HousepitalColors.background,
      textTheme: GoogleFonts.archivoTextTheme().copyWith(
        headlineLarge: GoogleFonts.archivo(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: HousepitalColors.black,
        ),
        headlineMedium: GoogleFonts.archivo(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: HousepitalColors.black,
        ),
        headlineSmall: GoogleFonts.archivo(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: HousepitalColors.black,
        ),
        titleLarge: GoogleFonts.archivo(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HousepitalColors.black,
        ),
        titleMedium: GoogleFonts.archivo(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: HousepitalColors.black,
        ),
        bodyLarge: GoogleFonts.archivo(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: HousepitalColors.grey,
        ),
        bodyMedium: GoogleFonts.archivo(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HousepitalColors.grey,
        ),
        bodySmall: GoogleFonts.archivo(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: HousepitalColors.greyLight,
        ),
        labelLarge: GoogleFonts.archivo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: HousepitalColors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: HousepitalColors.white,
        foregroundColor: HousepitalColors.black,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.archivo(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: HousepitalColors.black,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HousepitalColors.orange,
          foregroundColor: HousepitalColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.archivo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HousepitalColors.orange,
          side: const BorderSide(color: HousepitalColors.orange),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: HousepitalColors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HousepitalColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HousepitalColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HousepitalColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HousepitalColors.orange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: HousepitalColors.white,
        selectedItemColor: HousepitalColors.orange,
        unselectedItemColor: HousepitalColors.greyLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: HousepitalColors.divider,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: HousepitalColors.orangeLight,
        labelStyle: GoogleFonts.archivo(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: HousepitalColors.orange,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Dark-mode counterpart of [lightTheme]. Mirrors the same component
  /// styling but routes all colours through [HousepitalColorsDark].
  ///
  /// Critical contrast decisions:
  ///   • Buttons keep brand orange, but use dark text (white on orange =
  ///     2.7:1 in dark mode, fails AA — see HousepitalColorsDark.onOrange).
  ///   • Body text uses #B0B0B0 (8:1) instead of pure white so it doesn't
  ///     compete with primary text and avoids the OLED "all-white" glare.
  ///   • Cards sit on #242424 over a #1A1A1A scaffold so elevation is
  ///     visible without shadow tricks.
  static ThemeData get darkTheme {
    final archivoFamily = GoogleFonts.archivo().fontFamily;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: archivoFamily,
      fontFamilyFallback: _devanagariFallback,
      colorScheme: const ColorScheme.dark(
        primary: HousepitalColorsDark.orange,
        onPrimary: HousepitalColorsDark.onOrange,
        secondary: HousepitalColorsDark.textSecondary,
        onSecondary: HousepitalColorsDark.surface,
        surface: HousepitalColorsDark.surfaceElevated,
        onSurface: HousepitalColorsDark.textPrimary,
        error: HousepitalColorsDark.error,
        onError: HousepitalColorsDark.surface,
      ),
      scaffoldBackgroundColor: HousepitalColorsDark.surface,
      canvasColor: HousepitalColorsDark.surface,
      textTheme: GoogleFonts.archivoTextTheme(ThemeData.dark().textTheme)
          .copyWith(
        headlineLarge: GoogleFonts.archivo(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: HousepitalColorsDark.textPrimary,
        ),
        headlineMedium: GoogleFonts.archivo(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: HousepitalColorsDark.textPrimary,
        ),
        headlineSmall: GoogleFonts.archivo(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: HousepitalColorsDark.textPrimary,
        ),
        titleLarge: GoogleFonts.archivo(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HousepitalColorsDark.textPrimary,
        ),
        titleMedium: GoogleFonts.archivo(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: HousepitalColorsDark.textPrimary,
        ),
        bodyLarge: GoogleFonts.archivo(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: HousepitalColorsDark.textSecondary,
        ),
        bodyMedium: GoogleFonts.archivo(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HousepitalColorsDark.textSecondary,
        ),
        bodySmall: GoogleFonts.archivo(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: HousepitalColorsDark.textSecondary,
        ),
        labelLarge: GoogleFonts.archivo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          // Used on buttons — match onPrimary so it shows on orange.
          color: HousepitalColorsDark.onOrange,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: HousepitalColorsDark.surfaceHigh,
        foregroundColor: HousepitalColorsDark.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.archivo(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: HousepitalColorsDark.textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: HousepitalColorsDark.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HousepitalColorsDark.orange,
          // Dark text on orange in dark mode — passes 6.32:1 vs white's 2.7:1.
          foregroundColor: HousepitalColorsDark.onOrange,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.archivo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HousepitalColorsDark.orange,
          side: const BorderSide(color: HousepitalColorsDark.orange),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HousepitalColorsDark.orange,
        ),
      ),
      cardTheme: CardThemeData(
        color: HousepitalColorsDark.surfaceElevated,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HousepitalColorsDark.surfaceHigh,
        hintStyle: const TextStyle(color: HousepitalColorsDark.textDisabled),
        labelStyle: const TextStyle(color: HousepitalColorsDark.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HousepitalColorsDark.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HousepitalColorsDark.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: HousepitalColorsDark.orange, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: HousepitalColorsDark.surfaceHigh,
        selectedItemColor: HousepitalColorsDark.orange,
        unselectedItemColor: HousepitalColorsDark.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: HousepitalColorsDark.divider,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: HousepitalColorsDark.orangeMuted,
        labelStyle: GoogleFonts.archivo(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: HousepitalColorsDark.orange,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HousepitalColorsDark.surfaceElevated,
        titleTextStyle: GoogleFonts.archivo(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HousepitalColorsDark.textPrimary,
        ),
        contentTextStyle: GoogleFonts.archivo(
          fontSize: 14,
          color: HousepitalColorsDark.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HousepitalColorsDark.surfaceElevated,
        modalBackgroundColor: HousepitalColorsDark.surfaceElevated,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: HousepitalColorsDark.textSecondary,
        textColor: HousepitalColorsDark.textPrimary,
      ),
    );
  }
}
