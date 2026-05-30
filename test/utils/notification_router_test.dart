import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/utils/notification_router.dart';

void main() {
  group('NotificationRouter.handleNotification', () {
    late String? pushedRoute;

    setUp(() {
      pushedRoute = null;
    });

    /// Builds a minimal MaterialApp that captures Navigator.pushNamed calls.
    Widget buildTestApp(Map<String, dynamic> data) {
      return MaterialApp(
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          return MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('target')),
            settings: settings,
          );
        },
        home: Builder(
          builder: (context) {
            // Trigger navigation in post-frame callback so context is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              NotificationRouter.handleNotification(context, data);
            });
            return const Scaffold(body: Text('home'));
          },
        ),
      );
    }

    testWidgets('routes booking_confirmed to /order-tracking', (tester) async {
      await tester.pumpWidget(buildTestApp({'type': 'booking_confirmed', 'id': 'b123'}));
      await tester.pumpAndSettle();
      expect(pushedRoute, equals('/order-tracking'));
    });

    testWidgets('routes staff_assigned to /order-tracking', (tester) async {
      await tester.pumpWidget(buildTestApp({'type': 'staff_assigned', 'id': 's456'}));
      await tester.pumpAndSettle();
      expect(pushedRoute, equals('/order-tracking'));
    });

    testWidgets('routes staff_arrived to /staff-otp', (tester) async {
      await tester.pumpWidget(buildTestApp({'type': 'staff_arrived', 'id': 'a789'}));
      await tester.pumpAndSettle();
      expect(pushedRoute, equals('/staff-otp'));
    });

    testWidgets('routes vitals_alert to /vitals', (tester) async {
      await tester.pumpWidget(buildTestApp({'type': 'vitals_alert'}));
      await tester.pumpAndSettle();
      expect(pushedRoute, equals('/vitals'));
    });

    testWidgets('routes report_ready to /report-detail', (tester) async {
      await tester.pumpWidget(buildTestApp({'type': 'report_ready', 'id': 'r123'}));
      await tester.pumpAndSettle();
      expect(pushedRoute, equals('/report-detail'));
    });

    testWidgets('routes payment_due to /billing', (tester) async {
      await tester.pumpWidget(buildTestApp({'type': 'payment_due'}));
      await tester.pumpAndSettle();
      expect(pushedRoute, equals('/billing'));
    });

    testWidgets('routes assessment_quote to /booking-history', (tester) async {
      await tester.pumpWidget(buildTestApp({'type': 'assessment_quote'}));
      await tester.pumpAndSettle();
      expect(pushedRoute, equals('/booking-history'));
    });

    testWidgets('routes chat_message to /chat', (tester) async {
      await tester.pumpWidget(buildTestApp({'type': 'chat_message', 'id': 'c999'}));
      await tester.pumpAndSettle();
      expect(pushedRoute, equals('/chat'));
    });

    testWidgets('unknown type does not crash', (tester) async {
      await tester.pumpWidget(buildTestApp({'type': 'unknown_xyz'}));
      await tester.pumpAndSettle();
      // Should not push any route for unknown type
      // (only the initial '/' route is generated, not our unknown one)
      expect(pushedRoute, isNot(equals('/unknown_xyz')));
    });

    testWidgets('null type does not crash', (tester) async {
      await tester.pumpWidget(buildTestApp({}));
      await tester.pumpAndSettle();
      // No navigation should occur
    });

    testWidgets('empty data does not crash', (tester) async {
      await tester.pumpWidget(buildTestApp(<String, dynamic>{}));
      await tester.pumpAndSettle();
    });
  });
}
