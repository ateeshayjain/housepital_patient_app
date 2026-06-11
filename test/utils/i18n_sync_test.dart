// test/utils/i18n_sync_test.dart
//
// Localization sync guard. A missing key renders as raw key text in the UI —
// this shipped once ("today_report" appeared literally on the My Care screen
// because the key existed in code but not in en.json). This test makes that
// class of bug impossible to merge:
//   1. en.json and hi.json must contain EXACTLY the same key sets.
//   2. Every {param} placeholder must appear in both translations of a key
//      (a missing placeholder silently drops user data from the string).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> hi;

  setUpAll(() {
    en = json.decode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>;
    hi = json.decode(File('assets/i18n/hi.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('en.json and hi.json contain identical key sets', () {
    final enKeys = en.keys.toSet();
    final hiKeys = hi.keys.toSet();

    expect(enKeys.difference(hiKeys), isEmpty,
        reason: 'Keys present in en.json but MISSING from hi.json — Hindi '
            'users would see raw key text');
    expect(hiKeys.difference(enKeys), isEmpty,
        reason: 'Keys present in hi.json but missing from en.json — dead '
            'translations (or English users see raw keys)');
  });

  test('placeholders match between en and hi for every key', () {
    final placeholder = RegExp(r'\{([a-zA-Z0-9_]+)\}');
    final mismatches = <String>[];

    for (final key in en.keys) {
      final enVal = en[key];
      final hiVal = hi[key];
      if (enVal is! String || hiVal is! String) continue;
      final enParams =
          placeholder.allMatches(enVal).map((m) => m.group(1)).toSet();
      final hiParams =
          placeholder.allMatches(hiVal).map((m) => m.group(1)).toSet();
      if (enParams.length != hiParams.length ||
          !enParams.containsAll(hiParams)) {
        mismatches.add('$key: en=$enParams hi=$hiParams');
      }
    }

    expect(mismatches, isEmpty,
        reason: 'Placeholder sets differ — interpolated values would be '
            'silently dropped in one language');
  });

  test('no empty translations', () {
    final emptyEn = en.entries
        .where((e) => e.value is String && (e.value as String).trim().isEmpty)
        .map((e) => e.key)
        .toList();
    final emptyHi = hi.entries
        .where((e) => e.value is String && (e.value as String).trim().isEmpty)
        .map((e) => e.key)
        .toList();
    expect(emptyEn, isEmpty, reason: 'Empty English strings');
    expect(emptyHi, isEmpty, reason: 'Empty Hindi strings');
  });
}
