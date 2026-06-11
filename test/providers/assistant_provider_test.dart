// test/providers/assistant_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/models/assistant_models.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/services/assistant_service.dart';
import 'package:housepital_patient/services/i_api_service.dart';
import 'package:housepital_patient/services/voice_service.dart';
import 'package:housepital_patient/screens/assistant/assistant_executor.dart';
import 'package:housepital_patient/screens/assistant/assistant_local_actions.dart';
import 'package:housepital_patient/providers/assistant_provider.dart';
import 'package:housepital_patient/utils/permissions.dart';

/// Fake service returning a pre-set response.
class _FakeService extends AssistantService {
  AssistantResponse next = AssistantResponse.degraded('x');
  _FakeService() : super(useStub: true);
  @override
  Future<AssistantResponse> ask(AssistantRequest req) async => next;
}

class _FakeVoice implements VoiceService {
  final List<String> spoken = [];
  int listenCalls = 0;
  int stopCalls = 0;
  @override
  bool get isListening => false;
  @override
  Future<bool> initSpeech() async => true;
  @override
  Future<void> speak(String text, {String locale = 'hi-IN'}) async {
    spoken.add(text);
  }

  @override
  Future<void> listen(void Function(String) onResult,
      {String locale = 'hi_IN'}) async {
    listenCalls++;
  }

  @override
  Future<void> stopListening() async {
    stopCalls++;
  }
}

class _FakeApi implements IApiService {
  Map<String, dynamic> billing = {'amount_due': 5000};
  @override
  Future<Map<String, dynamic>> getBillingSummary(String patientId) async =>
      billing;
  @override
  Future<List<Attendance>> getAttendanceHistory(String patientId,
          {int page = 1}) async =>
      [];
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeService service;
  late _FakeVoice voice;
  late _FakeApi api;

  AssistantProvider makeProvider({
    String role = UserRole.primaryContact,
    AssistantLocalActions? local,
  }) {
    final executor = AssistantExecutor(
      api: api,
      role: role,
      patientId: 'p1',
      contacts: {
        'health_manager':
            const AssistantContact(name: 'Sunita Devi', phone: '9876500000'),
      },
      local: local,
    );
    return AssistantProvider(
      service: service,
      executor: executor,
      voice: voice,
      patientId: 'p1',
      role: role,
      locale: 'hi',
    );
  }

  setUp(() {
    service = _FakeService();
    voice = _FakeVoice();
    api = _FakeApi();
  });

  test('sendText appends a user bubble + assistant reply bubble', () async {
    service.next = const AssistantResponse(
      action: AssistantAction.getBilling,
      params: {},
      replyText: 'checking',
    );
    final p = makeProvider();
    await p.sendText('iss mahine ka bill');

    expect(p.messages.length, 2);
    expect(p.messages[0].isUser, isTrue);
    expect(p.messages[0].text, 'iss mahine ka bill');
    expect(p.messages[1].isUser, isFalse);
    expect(p.messages[1].text, contains('5000'));
  });

  test('read-only answer is spoken via VoiceService', () async {
    service.next = const AssistantResponse(
      action: AssistantAction.getBilling,
      params: {},
      replyText: 'checking',
    );
    final p = makeProvider();
    await p.sendText('bill');
    expect(voice.spoken, isNotEmpty);
    expect(voice.spoken.last, contains('5000'));
  });

  test('place_call response sets pendingConfirmation; confirm invokes callback',
      () async {
    service.next = const AssistantResponse(
      action: AssistantAction.placeCall,
      params: {'target': 'health_manager'},
      replyText: 'confirm?',
    );
    final p = makeProvider();
    String? dialed;
    p.onPlaceCall = (phone) => dialed = phone;

    await p.sendText('health manager ko call karo');
    expect(p.pendingConfirmation, isNotNull);
    expect(dialed, isNull); // not dialed until confirmed

    p.confirmPending();
    expect(dialed, '9876500000');
    expect(p.pendingConfirmation, isNull);
  });

  test('cancelPending clears pending without dialing', () async {
    service.next = const AssistantResponse(
      action: AssistantAction.placeCall,
      params: {'target': 'health_manager'},
      replyText: 'confirm?',
    );
    final p = makeProvider();
    String? dialed;
    p.onPlaceCall = (phone) => dialed = phone;

    await p.sendText('call');
    expect(p.pendingConfirmation, isNotNull);
    p.cancelPending();
    expect(p.pendingConfirmation, isNull);
    expect(dialed, isNull);
  });

  test('navigate response invokes navigate callback with route', () async {
    service.next = const AssistantResponse(
      action: AssistantAction.navigate,
      params: {'route': '/vitals'},
      replyText: 'khol raha hoon',
    );
    final p = makeProvider();
    String? navigated;
    p.onNavigate = (route) => navigated = route;

    await p.sendText('vitals dikhao');
    expect(navigated, '/vitals');
  });

  test('network-degraded response shows degradation bubble, no crash',
      () async {
    service.next = AssistantResponse.degraded('Connection issue');
    final p = makeProvider();
    await p.sendText('bla');
    expect(p.messages.last.isUser, isFalse);
    expect(p.messages.last.text, isNotEmpty);
    expect(p.pendingConfirmation, isNull);
  });

  test('family member place_call creates a pending confirmation (not blocked)',
      () async {
    // Calling is non-destructive — a family member may call the care team;
    // confirm-before-dial is the safety control, so a pending action appears.
    service.next = const AssistantResponse(
      action: AssistantAction.placeCall,
      params: {'target': 'health_manager'},
      replyText: 'confirm?',
    );
    final p = makeProvider(role: UserRole.familyMember);
    await p.sendText('call');
    expect(p.pendingConfirmation, isA<CallAction>());
    expect(p.messages.last.text, isNotEmpty);
  });

  test('isThinking toggles false after sendText completes', () async {
    service.next = AssistantResponse.degraded('x');
    final p = makeProvider();
    await p.sendText('hi');
    expect(p.isThinking, isFalse);
  });

  test('startVoice/stopVoice delegate to VoiceService', () async {
    final p = makeProvider();
    await p.startVoice();
    expect(voice.listenCalls, 1);
    await p.stopVoice();
    expect(voice.stopCalls, 1);
  });

  // ── Typed confirmation: "haan/yes" must execute, "nahi" must cancel ──────

  group('typed confirmation of a pending action', () {
    test('typed "haan" confirms a pending call (Confirm button not required)',
        () async {
      service.next = const AssistantResponse(
        action: AssistantAction.placeCall,
        params: {'target': 'health_manager'},
        replyText: 'confirm?',
      );
      final p = makeProvider();
      String? dialed;
      p.onPlaceCall = (phone) => dialed = phone;

      await p.sendText('health manager ko call karo');
      expect(p.pendingConfirmation, isNotNull);

      await p.sendText('haan');
      expect(dialed, '9876500000');
      expect(p.pendingConfirmation, isNull);
    });

    test('typed "yes" confirms a pending booking → OrdersProvider gains the '
        'local quote-pending request (demo mode)', () async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();
      final orders = OrdersProvider();
      await Future<void>.delayed(Duration.zero);
      final initialCount = orders.orders.length;

      service.next = const AssistantResponse(
        action: AssistantAction.bookService,
        params: {'service_category': 'doctor'},
        replyText: 'doctor ke liye request bhej dun? Confirm karein.',
      );
      final p = makeProvider(
        local: AssistantLocalActions(
          cart: cart,
          orders: orders,
          loadCatalog: () async => const [],
        ),
      );

      await p.sendText('book a doctor consultation');
      expect(p.pendingConfirmation, isA<SubmitAction>());

      await p.sendText('yes');
      expect(p.pendingConfirmation, isNull);
      // The request was recorded locally — never "bhej nahi paya".
      expect(orders.orders.length, initialCount + 1);
      expect(OrdersProvider.isQuotePending(orders.orders.first), isTrue);
      expect(p.messages.last.text, isNot(contains('bhej nahi paya')));
    });

    test('typed "nahi" cancels the pending action without executing',
        () async {
      service.next = const AssistantResponse(
        action: AssistantAction.placeCall,
        params: {'target': 'health_manager'},
        replyText: 'confirm?',
      );
      final p = makeProvider();
      String? dialed;
      p.onPlaceCall = (phone) => dialed = phone;

      await p.sendText('call karo');
      expect(p.pendingConfirmation, isNotNull);

      await p.sendText('nahi');
      expect(dialed, isNull);
      expect(p.pendingConfirmation, isNull);
      expect(p.messages.last.isUser, isFalse);
      expect(p.messages.last.text.toLowerCase(), contains('cancel'));
    });

    test('unrelated text while pending → treated as a new request, pending '
        'cleared (old behavior preserved)', () async {
      service.next = const AssistantResponse(
        action: AssistantAction.placeCall,
        params: {'target': 'health_manager'},
        replyText: 'confirm?',
      );
      final p = makeProvider();
      String? dialed;
      p.onPlaceCall = (phone) => dialed = phone;

      await p.sendText('call karo');
      expect(p.pendingConfirmation, isNotNull);

      service.next = const AssistantResponse(
        action: AssistantAction.getBilling,
        params: {},
        replyText: 'checking',
      );
      await p.sendText('nahi yaar pehle bill batao');
      expect(dialed, isNull);
      expect(p.pendingConfirmation, isNull);
      expect(p.messages.last.text, contains('5000'));
    });
  });
}
