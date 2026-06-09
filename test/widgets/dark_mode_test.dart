// test/widgets/dark_mode_test.dart
//
// Guards dark-mode support. The app's screens were migrated from hardcoded
// light colors (HousepitalColors.black/white/…) to the theme-aware resolver
// `context.hc.<token>` (lib/config/app_colors.dart), which returns the correct
// value for Theme.of(context).brightness. These tests prove the resolver
// actually flips between palettes AND that the shared widgets pick it up — so a
// future regression back to a static light color fails CI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/config/app_colors.dart';
import 'package:housepital_patient/config/theme.dart';
import 'package:housepital_patient/widgets/common_widgets.dart';

/// Pumps [child] under a MaterialApp forced to [brightness] and returns the
/// resolved Color of the first Text descendant.
Future<Color?> _firstTextColor(
    WidgetTester tester, Brightness brightness, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: brightness == Brightness.dark
        ? HousepitalTheme.darkTheme
        : HousepitalTheme.lightTheme,
    home: Scaffold(body: child),
  ));
  final text = tester.widget<Text>(find.byType(Text).first);
  return text.style?.color;
}

void main() {
  group('HcPalette resolver', () {
    testWidgets('resolves the LIGHT palette under a light theme',
        (tester) async {
      late HcPalette p;
      await tester.pumpWidget(MaterialApp(
        theme: HousepitalTheme.lightTheme,
        home: Builder(builder: (context) {
          p = context.hc;
          return const SizedBox();
        }),
      ));
      expect(p.black, HousepitalColors.black);
      expect(p.white, HousepitalColors.white);
      expect(p.divider, HousepitalColors.divider);
      expect(p.success, HousepitalColors.success);
    });

    testWidgets('resolves the DARK palette under a dark theme', (tester) async {
      late HcPalette p;
      await tester.pumpWidget(MaterialApp(
        theme: HousepitalTheme.darkTheme,
        home: Builder(builder: (context) {
          p = context.hc;
          return const SizedBox();
        }),
      ));
      // In dark mode "black" (primary text) must become the light text color,
      // and "white" (surface) must become the dark elevated surface.
      expect(p.black, HousepitalColorsDark.textPrimary);
      expect(p.white, HousepitalColorsDark.surfaceElevated);
      expect(p.divider, HousepitalColorsDark.divider);
      expect(p.success, HousepitalColorsDark.success);
      // Sanity: dark "black" is NOT the literal light black (the old bug).
      expect(p.black, isNot(HousepitalColors.black));
    });
  });

  // One pump per test: pumping the same `const` widget twice in a single test
  // is short-circuited by Dart's const canonicalization (the element is reused
  // and never rebuilt under the new theme), so light/dark are split apart.
  group('shared widgets adapt to dark mode', () {
    testWidgets('SectionHeader title is dark text in LIGHT mode',
        (tester) async {
      final c = await _firstTextColor(
          tester, Brightness.light, const SectionHeader(title: 'Vitals'));
      expect(c, HousepitalColors.black);
    });

    testWidgets('SectionHeader title is light text in DARK mode',
        (tester) async {
      final c = await _firstTextColor(
          tester, Brightness.dark, const SectionHeader(title: 'Vitals'));
      expect(c, HousepitalColorsDark.textPrimary);
      // The regression we're guarding against: invisible dark-on-dark label.
      expect(c, isNot(HousepitalColors.black));
    });
  });
}
