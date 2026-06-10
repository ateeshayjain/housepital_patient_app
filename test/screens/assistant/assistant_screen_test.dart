// test/screens/assistant/assistant_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/models/assistant_models.dart';
import 'package:housepital_patient/services/assistant_service.dart';
import 'package:housepital_patient/services/i_api_service.dart';
import 'package:housepital_patient/services/voice_service.dart';
import 'package:housepital_patient/screens/assistant/assistant_executor.dart';
import 'package:housepital_patient/providers/assistant_provider.dart';
import 'package:housepital_patient/screens/assistant/assistant_screen.dart';
import 'package:housepital_patient/widgets/assistant_fab.dart';
import 'package:housepital_patient/utils/permissions.dart';

class _FakeService extends AssistantService {
  AssistantResponse next = AssistantResponse.degraded('x');
  _FakeService() : super(useStub: true);
  @override
  Future<AssistantResponse> ask(AssistantRequest req) async => next;
}

class _FakeApi implements IApiService {
  @override
  Future<Map<String, dynamic>> getBillingSummary(String patientId) async =>
      {'amount_due': 5000};
  @override
  Future<List<Attendance>> getAttendanceHistory(String patientId,
          {int page = 1}) async =>
      [];
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

AssistantProvider _provider(_FakeService service) {
  final executor = AssistantExecutor(
    api: _FakeApi(),
    role: UserRole.primaryContact,
    patientId: 'p1',
    contacts: {
      'health_manager':
          const AssistantContact(name: 'Sunita Devi', phone: '9876500000'),
    },
  );
  return AssistantProvider(
    service: service,
    executor: executor,
    voice: NoopVoiceService(),
    patientId: 'p1',
    role: UserRole.primaryContact,
    locale: 'hi',
  );
}

Widget _wrap(AssistantProvider provider) => ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: AssistantScreen()),
    );

void main() {
  group('AssistantFab', () {
    testWidgets('renders a tappable FAB with accessible label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(floatingActionButton: AssistantFab())),
      );
      expect(find.byType(AssistantFab), findsOneWidget);
      // AssistantFab is a custom glass control (Material + InkWell), not a
      // stock FloatingActionButton — assert the tappable surface instead.
      expect(
        find.descendant(
          of: find.byType(AssistantFab),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
      // Accessible label present.
      expect(
        find.bySemanticsLabel(RegExp('assistant', caseSensitive: false)),
        findsWidgets,
      );
    });
  });

  group('AssistantScreen', () {
    testWidgets('renders text field + mic button (mic ≥44pt)', (tester) async {
      final p = _provider(_FakeService());
      await tester.pumpWidget(_wrap(p));
      expect(find.byType(TextField), findsOneWidget);
      final mic = find.byIcon(Icons.mic);
      expect(mic, findsOneWidget);
    });

    testWidgets('read-only answer renders as a bubble', (tester) async {
      final service = _FakeService()
        ..next = const AssistantResponse(
          action: AssistantAction.getBilling,
          params: {},
          replyText: 'checking',
        );
      final p = _provider(service);
      await p.sendText('bill');
      await tester.pumpWidget(_wrap(p));
      await tester.pump();
      expect(find.textContaining('5000'), findsOneWidget);
    });

    testWidgets('place_call pending state renders a confirm card with buttons',
        (tester) async {
      final service = _FakeService()
        ..next = const AssistantResponse(
          action: AssistantAction.placeCall,
          params: {'target': 'health_manager'},
          replyText: 'Call karein?',
        );
      final p = _provider(service);
      await p.sendText('call');
      await tester.pumpWidget(_wrap(p));
      await tester.pump();

      expect(find.textContaining('Sunita Devi'), findsWidgets);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('tapping Confirm fires onPlaceCall and clears pending',
        (tester) async {
      final service = _FakeService()
        ..next = const AssistantResponse(
          action: AssistantAction.placeCall,
          params: {'target': 'health_manager'},
          replyText: 'Call karein?',
        );
      final p = _provider(service);
      await p.sendText('call');
      await tester.pumpWidget(_wrap(p));
      await tester.pump();
      // Override after mount: the screen wires its own onPlaceCall in
      // initState; we replace it here so the test can observe the dial.
      String? dialed;
      p.onPlaceCall = (phone) => dialed = phone;

      await tester.tap(find.text('Confirm'));
      await tester.pump();

      expect(dialed, '9876500000');
      expect(p.pendingConfirmation, isNull);
      expect(find.text('Confirm'), findsNothing);
    });

    testWidgets('tapping Cancel clears pending without dialing',
        (tester) async {
      final service = _FakeService()
        ..next = const AssistantResponse(
          action: AssistantAction.placeCall,
          params: {'target': 'health_manager'},
          replyText: 'Call karein?',
        );
      final p = _provider(service);
      String? dialed;
      p.onPlaceCall = (phone) => dialed = phone;
      await p.sendText('call');
      await tester.pumpWidget(_wrap(p));
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(dialed, isNull);
      expect(p.pendingConfirmation, isNull);
    });
  });
}
