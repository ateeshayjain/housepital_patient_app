// test/widgets/day_part_header_test.dart
//
// Guards the app-wide day-part motif (lib/widgets/day_part_header.dart):
// the three bilingual labels render, the per-part icons are the canonical
// set, and DayPart.fromHour mirrors the care calendar's dose-group
// boundaries EXACTLY (<12 morning, <17 afternoon, else evening).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/config/theme.dart';
import 'package:housepital_patient/widgets/day_part_header.dart';

Widget _host(Widget child) => MaterialApp(
      theme: HousepitalTheme.lightTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('DayPartHeader', () {
    testWidgets('morning renders its bilingual label and icon',
        (tester) async {
      await tester.pumpWidget(_host(const DayPartHeader(DayPart.morning)));

      expect(find.text('Morning · Subah'), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    });

    testWidgets('afternoon renders its bilingual label and icon',
        (tester) async {
      await tester.pumpWidget(_host(const DayPartHeader(DayPart.afternoon)));

      expect(find.text('Afternoon · Dopahar'), findsOneWidget);
      expect(find.byIcon(Icons.wb_twilight), findsOneWidget);
    });

    testWidgets('evening renders its bilingual label and icon',
        (tester) async {
      await tester.pumpWidget(_host(const DayPartHeader(DayPart.evening)));

      expect(find.text('Evening · Raat'), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_outlined), findsOneWidget);
    });

    testWidgets('renders the optional trailing count text', (tester) async {
      await tester.pumpWidget(
        _host(const DayPartHeader(DayPart.morning, trailing: '3 doses')),
      );

      expect(find.text('3 doses'), findsOneWidget);
    });
  });

  group('DayPart.fromHour boundaries (mirror calendar dose groups)', () {
    test('11 -> morning', () {
      expect(DayPart.fromHour(11), DayPart.morning);
    });

    test('12 -> afternoon', () {
      expect(DayPart.fromHour(12), DayPart.afternoon);
    });

    test('16 -> afternoon', () {
      expect(DayPart.fromHour(16), DayPart.afternoon);
    });

    test('17 -> evening', () {
      expect(DayPart.fromHour(17), DayPart.evening);
    });
  });
}
