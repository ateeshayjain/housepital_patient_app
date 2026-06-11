// test/widgets/care_pulse_ring_test.dart
//
// Guards the CarePulseRing contract (lib/widgets/care_pulse_ring.dart):
//   • renders the determinate ring + center child at a given value;
//   • Semantics label present (default '<percent> percent' or custom);
//   • with MediaQuery.disableAnimations the painted value is FINAL on the
//     first frame (Duration.zero — no sweep for reduced-motion users);
//   • with animations on, the sweep starts from 0 and settles at the value.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/widgets/care_pulse_ring.dart';

Widget _host({required Widget child, bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// The painted (animated) value, read off the ring's CustomPaint painter.
/// The painter class is private; its `value` field is read dynamically.
double _paintedValue(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(CarePulseRing),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.painter as dynamic).value as double;
}

void main() {
  testWidgets('renders at value 0.5 with center child after settling',
      (tester) async {
    await tester.pumpWidget(_host(
      child: const CarePulseRing(
        value: 0.5,
        size: 56,
        center: Text('50%'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CarePulseRing), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(_paintedValue(tester), closeTo(0.5, 0.001));
  });

  testWidgets('animates the sweep from 0 when animations are enabled',
      (tester) async {
    await tester.pumpWidget(_host(
      child: const CarePulseRing(value: 0.8, size: 56),
    ));
    // First frame: sweep has not arrived yet.
    expect(_paintedValue(tester), lessThan(0.8));
    await tester.pumpAndSettle();
    expect(_paintedValue(tester), closeTo(0.8, 0.001));
  });

  testWidgets('default semantics label is "<percent> percent"',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(
      child: const CarePulseRing(value: 0.86, size: 56),
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('86 percent'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('custom semanticLabel wins over the default', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(
      child: const CarePulseRing(
        value: 0.5,
        size: 56,
        semanticLabel: '3 of 6 doses taken',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('3 of 6 doses taken'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
      'disableAnimations renders the final value on the first frame '
      '(single pump, no settle)', (tester) async {
    await tester.pumpWidget(_host(
      disableAnimations: true,
      child: const CarePulseRing(value: 0.5, size: 56),
    ));
    // No pumpAndSettle — reduced motion must mean zero-duration sweep.
    expect(_paintedValue(tester), closeTo(0.5, 0.001));
  });

  test('color lerp: orange below 0.75, full green only at >= 0.95', () {
    expect(CarePulseRing.colorLerpT(0.0), 0.0);
    expect(CarePulseRing.colorLerpT(0.5), 0.0);
    expect(CarePulseRing.colorLerpT(0.75), 0.0);
    // ~0.8 is still mostly orange.
    expect(CarePulseRing.colorLerpT(0.8), lessThan(0.25));
    // Smooth in between.
    expect(CarePulseRing.colorLerpT(0.9), greaterThan(0.0));
    expect(CarePulseRing.colorLerpT(0.9), lessThan(1.0));
    expect(CarePulseRing.colorLerpT(0.95), 1.0);
    expect(CarePulseRing.colorLerpT(1.0), 1.0);
  });
}
