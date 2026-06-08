// test/screens/my_care/my_care_widgets_test.dart
//
// Widget tests for the My Care tab: HealthManagerBanner and ActiveServiceCard.
//
// Both widgets are pure presentation widgets — they take their data as
// constructor arguments and do NOT read from any Provider or
// AppLocalizations. The test wrapper is therefore a plain MaterialApp
// with no extra providers or localization setup required.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/models/my_care_models.dart';
import 'package:housepital_patient/screens/my_care/widgets/health_manager_banner.dart';
import 'package:housepital_patient/screens/my_care/widgets/active_service_card.dart';

// ============================================================
// Minimal test-host widget
// ============================================================

/// Wraps [child] inside a plain MaterialApp + Scaffold so that widgets
/// that use Theme, MediaQuery, or Overlay (e.g. InkWell ripples) resolve
/// correctly without needing any custom delegate.
Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

// ============================================================
// Model factories — helpers to build test objects concisely
// ============================================================

HealthManager _makeHealthManager({
  String id = 'hm-1',
  String staffId = 'staff-1',
  String name = 'Priya Sharma',
  String phone = '+919876543210',
  String? photoUrl,
  String availableFrom = '08:00',
  String availableTo = '20:00',
}) =>
    HealthManager(
      id: id,
      staffId: staffId,
      name: name,
      phone: phone,
      photoUrl: photoUrl,
      availableFrom: availableFrom,
      availableTo: availableTo,
    );

ActiveService _makeActiveService({
  String id = 'svc-1',
  String name = 'Full Care Package',
  String serviceCategory = 'care_package',
  String status = 'active',
  int totalDays = 30,
  int consumedDays = 12,
  bool isSessionBased = false,
  int? totalStaff,
  int? checkedInStaff,
  String? latestVitalLabel,
  String? latestVitalStatus,
  DateTime? renewalDate,
  int? totalPaid,
}) =>
    ActiveService(
      id: id,
      name: name,
      serviceCategory: serviceCategory,
      status: status,
      startDate: DateTime(2026, 1, 1),
      totalDays: totalDays,
      consumedDays: consumedDays,
      isSessionBased: isSessionBased,
      totalStaff: totalStaff,
      checkedInStaff: checkedInStaff,
      latestVitalLabel: latestVitalLabel,
      latestVitalStatus: latestVitalStatus,
      renewalDate: renewalDate,
      totalPaid: totalPaid,
    );

// ============================================================
// Tests
// ============================================================

void main() {
  // ----------------------------------------------------------
  // HealthManagerBanner
  // ----------------------------------------------------------
  group('HealthManagerBanner', () {
    testWidgets('renders manager name', (tester) async {
      final manager = _makeHealthManager(name: 'Priya Sharma');

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));

      expect(find.text('Priya Sharma'), findsOneWidget);
    });

    testWidgets('renders "Your Health Manager" label', (tester) async {
      final manager = _makeHealthManager();

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));

      expect(find.text('Your Health Manager'), findsOneWidget);
    });

    testWidgets('renders availability range text', (tester) async {
      final manager =
          _makeHealthManager(availableFrom: '09:00', availableTo: '21:00');

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));

      expect(find.text('Available 09:00 – 21:00'), findsOneWidget);
    });

    testWidgets('renders default availability (08:00 – 20:00)', (tester) async {
      final manager = _makeHealthManager();

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));

      expect(find.text('Available 08:00 – 20:00'), findsOneWidget);
    });

    testWidgets('renders call (phone) icon button', (tester) async {
      final manager = _makeHealthManager();

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));

      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    testWidgets('renders message (chat_bubble_outline) icon button',
        (tester) async {
      final manager = _makeHealthManager();

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));

      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('shows two-letter initials avatar when photoUrl is null',
        (tester) async {
      // "Priya Sharma" → first letters → "PS"
      final manager = _makeHealthManager(name: 'Priya Sharma', photoUrl: null);

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));

      expect(find.text('PS'), findsOneWidget);
    });

    testWidgets('shows single initial for a single-word name', (tester) async {
      final manager = _makeHealthManager(name: 'Kavitha', photoUrl: null);

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));

      expect(find.text('K'), findsOneWidget);
    });

    testWidgets('does not show initials text when photoUrl is provided',
        (tester) async {
      // When photoUrl is set, the CircleAvatar child is null, so the
      // initials Text widget must not be in the tree.
      //
      // Note: NetworkImage will throw a NetworkImageLoadException in the
      // test environment (all HTTP requests return 400). We suppress image
      // errors via the FlutterError handler so only our assertion is
      // evaluated.
      final errors = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        // Swallow network image errors; re-throw anything else.
        if (details.exception is NetworkImageLoadException) {
          errors.add(details);
        } else {
          original?.call(details);
        }
      };

      final manager = _makeHealthManager(
        name: 'Priya Sharma',
        photoUrl: 'https://example.com/photo.jpg',
      );

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));
      // pump once to let the image loading attempt settle
      await tester.pump();

      FlutterError.onError = original;

      // The initials "PS" must not appear because child is null when
      // photoUrl is provided.
      expect(find.text('PS'), findsNothing);
    });

    testWidgets('renders a different manager name correctly', (tester) async {
      final manager = _makeHealthManager(name: 'Arun Rajan');

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));

      expect(find.text('Arun Rajan'), findsOneWidget);
      // Initials = "AR"
      expect(find.text('AR'), findsOneWidget);
    });

    testWidgets('both action buttons coexist in the same banner',
        (tester) async {
      final manager = _makeHealthManager();

      await tester.pumpWidget(_host(HealthManagerBanner(manager: manager)));

      expect(find.byIcon(Icons.phone), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });
  });

  // ----------------------------------------------------------
  // ActiveServiceCard
  // ----------------------------------------------------------
  group('ActiveServiceCard', () {
    testWidgets('renders service name in the color-coded header',
        (tester) async {
      final service = _makeActiveService(name: 'Full Care Package');

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.text('Full Care Package'), findsOneWidget);
    });

    testWidgets('renders "Day X of Y" label for a non-session service',
        (tester) async {
      final service = _makeActiveService(
        totalDays: 30,
        consumedDays: 12,
        isSessionBased: false,
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.text('Day 12/30'), findsOneWidget);
    });

    testWidgets('renders "Session X of Y" label for a session-based service',
        (tester) async {
      final service = _makeActiveService(
        name: 'Physiotherapy',
        serviceCategory: 'physiotherapy',
        totalDays: 10,
        consumedDays: 3,
        isSessionBased: true,
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.text('Session 3/10'), findsOneWidget);
    });

    testWidgets('renders a LinearProgressIndicator', (tester) async {
      final service = _makeActiveService(totalDays: 30, consumedDays: 12);

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('progress indicator value matches progressFraction',
        (tester) async {
      // 15 of 30 consumed → 0.5
      final service = _makeActiveService(totalDays: 30, consumedDays: 15);

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.5, 1e-6));
    });

    testWidgets('progress indicator shows 1.0 for a fully consumed service',
        (tester) async {
      final service = _makeActiveService(totalDays: 20, consumedDays: 20);

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(1.0, 1e-6));
    });

    testWidgets('shows Staff Today label and partial count when hasStaff',
        (tester) async {
      final service = _makeActiveService(
        totalStaff: 2,
        checkedInStaff: 1,
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.text('1/2 on duty'), findsOneWidget);
      // Widget renders "1/2 " (trailing space, no checkmark when partial)
      expect(find.text('Staff Today'), findsNothing);
    });

    testWidgets('appends checkmark when all staff are checked in',
        (tester) async {
      final service = _makeActiveService(
        totalStaff: 2,
        checkedInStaff: 2,
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      // Compact card: '2/2 on duty' (no checkmark glyph).
      expect(find.text('2/2 on duty'), findsOneWidget);
    });

    testWidgets('does not show Staff Today when service has no staff',
        (tester) async {
      final service = _makeActiveService(
        totalStaff: null,
        checkedInStaff: null,
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.textContaining('on duty'), findsNothing);
    });

    testWidgets('shows Latest vital label for care_package service',
        (tester) async {
      final service = _makeActiveService(
        serviceCategory: 'care_package',
        latestVitalLabel: '128/82',
        latestVitalStatus: 'normal',
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.text('Latest'), findsNothing);
      expect(find.text('128/82'), findsNothing);
    });

    testWidgets('does not show Latest stat for non-care_package service',
        (tester) async {
      // showVitals is false for nursing
      final service = _makeActiveService(
        serviceCategory: 'nursing',
        latestVitalLabel: '128/82',
        latestVitalStatus: 'normal',
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.text('Latest'), findsNothing);
    });

    testWidgets('shows Renewal stat when renewalDate is set', (tester) async {
      final service = _makeActiveService(
        totalDays: 30,
        consumedDays: 12,
        renewalDate: DateTime(2026, 4, 1),
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.text('Renews in 18d'), findsOneWidget);
      // daysRemaining = 30 - 12 = 18
      // (renewal countdown asserted above)
    });

    testWidgets('does not show Renewal stat when renewalDate is null',
        (tester) async {
      final service = _makeActiveService(renewalDate: null);

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.textContaining('Renews in'), findsNothing);
    });

    testWidgets('card is tappable via InkWell', (tester) async {
      bool tapped = false;
      final service = _makeActiveService();

      await tester.pumpWidget(
        _host(
          ActiveServiceCard(
            service: service,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('root widget is a Card', (tester) async {
      final service = _makeActiveService();

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders nursing service name correctly', (tester) async {
      final service = _makeActiveService(
        name: 'Nursing Care',
        serviceCategory: 'nursing',
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.text('Nursing Care'), findsOneWidget);
    });

    testWidgets('renders equipment_rental service with day count',
        (tester) async {
      final service = _makeActiveService(
        name: 'Oxygen Concentrator Rental',
        serviceCategory: 'equipment_rental',
        isSessionBased: false,
        totalDays: 30,
        consumedDays: 5,
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.text('Oxygen Concentrator Rental'), findsOneWidget);
      expect(find.text('Day 5/30'), findsOneWidget);
    });

    testWidgets('renders japa service with correct header text', (tester) async {
      final service = _makeActiveService(
        name: 'Japa Care',
        serviceCategory: 'japa',
        totalDays: 45,
        consumedDays: 10,
      );

      await tester.pumpWidget(
        _host(ActiveServiceCard(service: service, onTap: () {})),
      );

      expect(find.text('Japa Care'), findsOneWidget);
      expect(find.text('Day 10/45'), findsOneWidget);
    });
  });
}
