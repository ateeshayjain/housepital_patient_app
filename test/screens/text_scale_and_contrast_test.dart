// test/screens/text_scale_and_contrast_test.dart
//
// Two accessibility findings that had no test of their own.

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

/// WCAG relative luminance and contrast ratio.
///
/// Present so the figures in the comments are CHECKABLE rather than asserted.
/// Three separate documents in this project have cited a retired contrast
/// number; a measurement that lives only in prose drifts silently.
double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = max(la, lb), lo = min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('system text scaling reaches the WCAG 1.4.4 minimum', () {
    final main = code('lib/main.dart');

    test('the clamp is 2.0x, not 1.4x', () {
      // 1.4x sat under a comment citing WCAG 1.4.4 — the criterion that
      // requires 200%. It failed the rule it invoked, and a user at iOS AX5
      // had their setting silently discarded on an app they may be using
      // BECAUSE they cannot read small text.
      expect(main, contains('maxScaleFactor: 2.0'));
      expect(main, isNot(contains('maxScaleFactor: 1.4')));
    });

    test('a lower bound still exists', () {
      // Unclamped shrink is its own accessibility problem.
      expect(main, contains('minScaleFactor: 0.85'));
    });

    test('the 200% claim is backed by the screen sweep, not by assertion', () {
      // The clamp is only defensible with evidence. If this row is ever
      // removed from the sweep, the number in main.dart becomes a claim.
      final sweep = code('test/screens/overflow_smoke_test.dart');
      expect(sweep, contains("'std @2.0x text 375x667'"));
      expect(sweep, contains('TextScaler.linear(_textScale)'));
      expect(sweep, contains("label.contains('@2.0x') ? 2.0 : 1.0"));
    });
  });

  group('the payment amount is not dimmed below the accepted baseline', () {
    final src = code('lib/screens/billing/payment_screen.dart');

    test('the orange hero uses onOrange, not a translucent white', () {
      // Colors.white70 over the orange gradient measures 1.82:1 — the worst
      // text contrast in the app, on the label for the amount someone is
      // about to be charged.
      expect(src, isNot(contains('color: Colors.white70')),
          reason: 'a dimmed white silently degraded an already-accepted '
              'risk by a further 22%');
      expect(src, contains('color: context.hc.onOrange'));
    });

    test('white-on-orange measures the documented 2.33:1', () {
      // The owner's explicit decision, recorded in CLAUDE.md as measured and
      // accepted. Pinned so the FIGURE cannot drift out of the docs
      // unnoticed — three separate documents have cited a retired contrast
      // number in this project already.
      const orange = Color(0xFFF39314);
      const white = Color(0xFFFFFFFF);
      expect(contrast(white, orange), closeTo(2.33, 0.03));
    });

    test('white70 on the same fill really is worse', () {
      // Guards the premise of the fix rather than just its outcome.
      const orange = Color(0xFFF39314);
      final white70 = Color.lerp(orange, const Color(0xFFFFFFFF), 0.7)!;
      final dimmed = contrast(white70, orange);
      expect(dimmed, lessThan(2.0));
      expect(dimmed, lessThan(contrast(const Color(0xFFFFFFFF), orange)));
    });
  });

  group('the accessible glass boundary tokens measure what they claim', () {
    test('light 4.26:1 on the page, dark 5.22:1 on the card', () {
      // theme.dart states both figures in a comment. A comment is not a test.
      expect(contrast(const Color(0xFF767680), const Color(0xFFF8F9FA)),
          closeTo(4.26, 0.05));
      expect(contrast(const Color(0xFF8E8E93), const Color(0xFF1C1C1E)),
          closeTo(5.22, 0.05));
    });

    test('both clear the 3:1 floor WCAG 1.4.11 sets for a UI boundary', () {
      expect(contrast(const Color(0xFF767680), const Color(0xFFF8F9FA)),
          greaterThanOrEqualTo(3.0));
      expect(contrast(const Color(0xFF8E8E93), const Color(0xFF1C1C1E)),
          greaterThanOrEqualTo(3.0));
    });
  });
}
