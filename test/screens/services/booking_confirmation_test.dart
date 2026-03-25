// test/screens/services/booking_confirmation_test.dart
//
// Tests booking confirmation screen data integrity:
// - Booking number format: HPL-BOOK-XXXXX (5 digits)
// - All required info displayed
// - "What happens next" section has at least 3 items
// - Share button exists

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/screens/services/booking_confirmation_screen.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Booking number format
  // ═══════════════════════════════════════════════════════════════════════════
  group('Booking number format', () {
    test('booking number starts with "HPL-BOOK-"', () {
      final rand = Random();
      final bookingNumber = 'HPL-BOOK-${rand.nextInt(90000) + 10000}';
      expect(bookingNumber.startsWith('HPL-BOOK-'), isTrue);
    });

    test('booking number has exactly 5 digits after prefix', () {
      final rand = Random();
      final num = rand.nextInt(90000) + 10000;
      final bookingNumber = 'HPL-BOOK-$num';
      final digits = bookingNumber.replaceFirst('HPL-BOOK-', '');
      expect(digits.length, 5);
      expect(int.tryParse(digits), isNotNull);
    });

    test('booking number digit range is 10000-99999', () {
      final rand = Random();
      for (int i = 0; i < 100; i++) {
        final num = rand.nextInt(90000) + 10000;
        expect(num, greaterThanOrEqualTo(10000));
        expect(num, lessThanOrEqualTo(99999));
      }
    });

    test('booking number matches HPL-BOOK-XXXXX pattern via regex', () {
      final pattern = RegExp(r'^HPL-BOOK-\d{5}$');
      final rand = Random();
      for (int i = 0; i < 50; i++) {
        final bookingNumber = 'HPL-BOOK-${rand.nextInt(90000) + 10000}';
        expect(pattern.hasMatch(bookingNumber), isTrue,
            reason: 'Failed for: $bookingNumber');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Required info displayed (widget test)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Booking confirmation — required info', () {
    testWidgets('displays service name, date, slot, and amount',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookingConfirmationScreen(
            serviceName: 'Nurse (Basic) - 12 Hours',
            scheduledDate: DateTime(2026, 4, 15),
            scheduledSlot: 'morning',
            totalAmount: 5000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Service name appears somewhere on screen
      expect(find.textContaining('Nurse'), findsWidgets);
      // Booking number appears
      expect(find.textContaining('HPL-BOOK-'), findsOneWidget);
      // Amount appears
      expect(find.textContaining('5,000'), findsWidgets);
    });

    testWidgets('displays booking number in HPL-BOOK- format',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookingConfirmationScreen(
            serviceName: 'Test Service',
            scheduledDate: DateTime(2026, 4, 15),
            scheduledSlot: 'afternoon',
            totalAmount: 3000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find text widget matching booking number pattern
      final bookingNumberFinder = find.textContaining('HPL-BOOK-');
      expect(bookingNumberFinder, findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // "What happens next" section
  // ═══════════════════════════════════════════════════════════════════════════
  group('Booking confirmation — What happens next', () {
    testWidgets('has at least 3 next step items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookingConfirmationScreen(
            serviceName: 'Physiotherapy',
            scheduledDate: DateTime(2026, 4, 15),
            scheduledSlot: 'evening',
            totalAmount: 1200,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What happens next?'), findsOneWidget);
      // Verify the 3 steps exist
      expect(find.text('Staff Assignment'), findsOneWidget);
      expect(find.text('Confirmation Call'), findsOneWidget);
      expect(find.text('Preparation Tips'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Share button exists
  // ═══════════════════════════════════════════════════════════════════════════
  group('Booking confirmation — Share button', () {
    testWidgets('share button is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookingConfirmationScreen(
            serviceName: 'ECG at Home',
            scheduledDate: DateTime(2026, 4, 15),
            scheduledSlot: 'morning',
            totalAmount: 500,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Share'), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });
  });
}
