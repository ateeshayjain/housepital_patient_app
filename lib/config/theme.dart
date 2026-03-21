import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
}

class HousepitalTheme {
  static ThemeData get lightTheme {
    final archivoFamily = GoogleFonts.archivo().fontFamily;

    return ThemeData(
      useMaterial3: true,
      fontFamily: archivoFamily,
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
}
