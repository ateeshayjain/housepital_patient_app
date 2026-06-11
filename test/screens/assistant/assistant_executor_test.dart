// test/screens/assistant/assistant_executor_test.dart
//
// Safety-critical tests for the assistant tool executor.
// These MUST pass and must NOT be weakened:
//   - confirm-before-act for place_call
//   - permission gating via canUserPerform
//   - malformed params / unknown action → safe degradation
//   - no phone on file → no dial, no crash

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/models/assistant_models.dart';
import 'package:housepital_patient/providers/cart_provider.dart';
import 'package:housepital_patient/providers/orders_provider.dart';
import 'package:housepital_patient/services/i_api_service.dart';
import 'package:housepital_patient/screens/assistant/assistant_executor.dart';
import 'package:housepital_patient/screens/assistant/assistant_local_actions.dart';
import 'package:housepital_patient/utils/permissions.dart';

/// Minimal fake — only overrides what the executor touches.
/// Everything else throws via noSuchMethod (so accidental calls are caught).
class _FakeApi implements IApiService {
  Map<String, dynamic> billing = {'amount_due': 12500, 'due_date': null};
  List<Attendance> attendance = [];
  bool throwOnBilling = false;

  @override
  Future<Map<String, dynamic>> getBillingSummary(String patientId) async {
    if (throwOnBilling) throw Exception('billing down');
    return billing;
  }

  @override
  Future<List<Attendance>> getAttendanceHistory(String patientId,
      {int page = 1}) async {
    return attendance;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Attendance _att(String status, DateTime date) => Attendance(
      id: 'a-${date.toIso8601String()}',
      deploymentId: 'd1',
      staffId: 's1',
      date: date,
      status: status,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeApi api;
  const patientId = 'p1';

  final contacts = {
    'health_manager': const AssistantContact(name: 'Sunita Devi', phone: '9876500000'),
    'nurse': const AssistantContact(name: 'Nurse Anita', phone: '9876511111'),
    // sos intentionally has no phone on file → tests safe degradation
  };

  AssistantExecutor makeExecutor({
    String role = UserRole.primaryContact,
    String? deploymentId = 'dep1',
    AssistantLocalActions? local,
  }) =>
      AssistantExecutor(
        api: api,
        role: role,
        patientId: patientId,
        contacts: contacts,
        deploymentId: deploymentId,
        local: local,
      );

  setUp(() {
    api = _FakeApi();
  });

  group('get_billing', () {
    test('reads billing summary → Answer containing the amount, no confirm',
        () async {
      api.billing = {'amount_due': 12500, 'due_date': null};
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.getBilling,
        params: {},
        replyText: '',
      ));
      expect(r, isA<Answer>());
      expect((r as Answer).text, contains('12500'));
    });

    test('billing API failure → Degraded, no crash', () async {
      api.throwOnBilling = true;
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.getBilling,
        params: {},
        replyText: '',
      ));
      expect(r, isA<Degraded>());
    });
  });

  group('get_duty_days', () {
    test('computes days-present client-side for the period', () async {
      final now = DateTime.now();
      api.attendance = [
        _att('checked_out', DateTime(now.year, now.month, 1)),
        _att('checked_in', DateTime(now.year, now.month, 2)),
        _att('absent', DateTime(now.year, now.month, 3)),
        _att('late', DateTime(now.year, now.month, 4)),
        _att('on_leave', DateTime(now.year, now.month, 5)),
      ];
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.getDutyDays,
        params: {},
        replyText: '',
      ));
      expect(r, isA<Answer>());
      // present = checked_out + checked_in + late = 3
      expect((r as Answer).text, contains('3'));
    });
  });

  group('place_call (confirm-before-act)', () {
    test('valid target → RequiresConfirmation with name + number, no auto-dial',
        () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.placeCall,
        params: {'target': 'health_manager'},
        replyText: '',
      ));
      expect(r, isA<RequiresConfirmation>());
      final rc = r as RequiresConfirmation;
      expect(rc.text, contains('Sunita Devi'));
      expect(rc.action, isA<CallAction>());
      expect((rc.action as CallAction).phone, '9876500000');
      // confirm-before-act: nothing dialed yet — the result merely DESCRIBES
      // the action; the caller dials only after the user confirms.
    });

    test('target with no phone on file → safe Degraded, no confirm, no crash',
        () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.placeCall,
        params: {'target': 'sos'},
        replyText: '',
      ));
      expect(r, isA<Degraded>());
      expect(r, isNot(isA<RequiresConfirmation>()));
    });

    test('missing/malformed target param → safe Degraded', () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.placeCall,
        params: {},
        replyText: '',
      ));
      expect(r, isA<Degraded>());
    });

    test('FAMILY_MEMBER CAN place a call (calling is not a managed action)',
        () async {
      // Placing a call is non-destructive — any role with app access may call
      // the care team (confirm-before-dial is the safety control).
      final r = await makeExecutor(role: UserRole.familyMember).execute(
          const AssistantResponse(
        action: AssistantAction.placeCall,
        params: {'target': 'health_manager'},
        replyText: '',
      ));
      expect(r, isA<RequiresConfirmation>());
    });

    test('SOS call is NEVER blocked, even for a view-only role', () async {
      // sos has no phone in the test contacts → Degraded (no phone), but it
      // must NOT be Blocked — emergency calls are never permission-gated.
      final r = await makeExecutor(role: UserRole.patientSelf).execute(
          const AssistantResponse(
        action: AssistantAction.placeCall,
        params: {'target': 'sos'},
        replyText: '',
      ));
      expect(r, isNot(isA<Blocked>()));
    });
  });

  group('navigate (light confirm)', () {
    test('route param → Navigate carrying the route', () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.navigate,
        params: {'route': '/vitals'},
        replyText: 'Khol raha hoon…',
      ));
      expect(r, isA<Navigate>());
      expect((r as Navigate).route, '/vitals');
    });

    test('missing route → safe Degraded', () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.navigate,
        params: {},
        replyText: '',
      ));
      expect(r, isA<Degraded>());
    });
  });

  group('unknown / none action', () {
    test('none action → Degraded, no side effects', () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.none,
        params: {},
        replyText: 'Samajh nahi aaya',
      ));
      expect(r, isA<Degraded>());
      expect((r as Degraded).text, isNotEmpty);
    });
  });

  group('state-changing actions — confirm-first + permission gating', () {
    test('raise_concern with description → RequiresConfirmation(SubmitAction)',
        () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.raiseConcern,
        params: {'description': 'Nurse late aayi do din se'},
        replyText: 'Bhej dun?',
      ));
      expect(r, isA<RequiresConfirmation>());
      final action = (r as RequiresConfirmation).action;
      expect(action, isA<SubmitAction>());
      expect((action as SubmitAction).kind, ConfirmedKind.raiseConcern);
      expect(action.data['description'], 'Nurse late aayi do din se');
    });

    test('raise_concern with empty description → Degraded (asks for detail)',
        () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.raiseConcern,
        params: {'description': ''},
        replyText: '',
      ));
      expect(r, isA<Degraded>());
    });

    test('book_service with category → RequiresConfirmation(SubmitAction)',
        () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.bookService,
        params: {'service_category': 'nursing'},
        replyText: '',
      ));
      expect(r, isA<RequiresConfirmation>());
      expect((r as RequiresConfirmation).action, isA<SubmitAction>());
    });

    test('book_service without category → Degraded', () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.bookService,
        params: {},
        replyText: '',
      ));
      expect(r, isA<Degraded>());
    });

    test('replace_staff with no active deployment → Degraded (nothing to do)',
        () async {
      final r = await makeExecutor(deploymentId: null).execute(
        const AssistantResponse(
          action: AssistantAction.replaceStaff,
          params: {'reason': 'Behaviour'},
          replyText: '',
        ),
      );
      expect(r, isA<Degraded>());
    });

    test('replace_staff with deployment → RequiresConfirmation(SubmitAction)',
        () async {
      final r = await makeExecutor().execute(const AssistantResponse(
        action: AssistantAction.replaceStaff,
        params: {'reason': 'Behaviour'},
        replyText: '',
      ));
      expect(r, isA<RequiresConfirmation>());
      expect((r as RequiresConfirmation).action, isA<SubmitAction>());
    });

    test('view-only role is Blocked from raising a concern via assistant',
        () async {
      // PATIENT_SELF cannot raise concerns (per permission matrix).
      final r = await makeExecutor(role: UserRole.patientSelf).execute(
        const AssistantResponse(
          action: AssistantAction.raiseConcern,
          params: {'description': 'something'},
          replyText: '',
        ),
      );
      expect(r, isA<Blocked>());
    });
  });

  // ── Demo-mode local actions (field-report regressions) ────────────────────
  // The app is demo-first: with no backend, add-to-cart must be a REAL local
  // cart add and a confirmed booking must create the same local quote-pending
  // order the normal flow creates — never "Request abhi bhej nahi paya".

  group('add_to_cart (demo local action)', () {
    late CartProvider cart;
    late OrdersProvider orders;

    final catalog = [
      EquipmentItem(
        id: 'NDK-NEBULI',
        name: 'Nebulizer',
        brand: 'Niscomed',
        category: 'Equipment',
        price: 3200,
        mrp: 4200,
      ),
      EquipmentItem(
        id: 'BPL-NEBUN10-10',
        name: 'Nebulizer N10',
        brand: 'BPL',
        category: 'Equipment',
        price: null, // price-on-request → Reserve flow
        mrp: 3000,
      ),
      EquipmentItem(
        id: 'PHL-OXYCON',
        name: 'Oxygen Concentrator 5L',
        brand: 'Philips',
        category: 'Equipment',
        price: 45000,
      ),
    ];

    AssistantLocalActions makeLocal() => AssistantLocalActions(
          cart: cart,
          orders: orders,
          loadCatalog: () async => catalog,
        );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cart = CartProvider();
      orders = OrdersProvider();
      // Let async storage loads settle before asserting.
      await Future<void>.delayed(Duration.zero);
    });

    test('nebulizer query → REAL cart add + Answer with name, price, cart path',
        () async {
      final r = await makeExecutor(local: makeLocal()).execute(
        const AssistantResponse(
          action: AssistantAction.addToCart,
          params: {'query': 'nebulizer'},
          replyText: '',
        ),
      );
      expect(r, isA<Answer>());
      final text = (r as Answer).text;
      expect(text, contains('Nebulizer'));
      expect(text, contains('3200'));
      expect(text.toLowerCase(), contains('cart'));
      // CartProvider actually gained the item — same as the catalog ADD.
      expect(cart.items, hasLength(1));
      expect(cart.items.first.equipmentId, 'NDK-NEBULI');
      expect(cart.items.first.unitPrice, 3200);
    });

    test('priced match is preferred over a price-on-request variant', () async {
      // "Nebulizer" (₹3200) and "Nebulizer N10" (no price) both match;
      // the priced item must win so a real cart add happens.
      final r = await makeExecutor(local: makeLocal()).execute(
        const AssistantResponse(
          action: AssistantAction.addToCart,
          params: {'query': 'nebulizer'},
          replyText: '',
        ),
      );
      expect((r as Answer).text, isNot(contains('N10')));
    });

    test('price-on-request item → honest Reserve guidance, NOT added',
        () async {
      final r = await makeExecutor(local: makeLocal()).execute(
        const AssistantResponse(
          action: AssistantAction.addToCart,
          params: {'query': 'nebulizer n10'},
          replyText: '',
        ),
      );
      expect(r, isA<Answer>());
      expect((r as Answer).text, contains('Reserve'));
      expect(cart.items, isEmpty); // never add with a fabricated price
    });

    test('no catalog match → plain "not found" message, cart untouched',
        () async {
      final r = await makeExecutor(local: makeLocal()).execute(
        const AssistantResponse(
          action: AssistantAction.addToCart,
          params: {'query': 'quantum flux capacitor'},
          replyText: '',
        ),
      );
      expect(r, isA<Degraded>());
      expect(cart.items, isEmpty);
    });

    test('empty query → asks which item, no crash', () async {
      final r = await makeExecutor(local: makeLocal()).execute(
        const AssistantResponse(
          action: AssistantAction.addToCart,
          params: {},
          replyText: '',
        ),
      );
      expect(r, isA<Degraded>());
    });

    test('no local sink wired → safe capability message, no crash', () async {
      final r = await makeExecutor().execute(
        const AssistantResponse(
          action: AssistantAction.addToCart,
          params: {'query': 'nebulizer'},
          replyText: '',
        ),
      );
      expect(r, isA<Degraded>());
    });
  });

  group('book_service demo fallback (performConfirmed)', () {
    late CartProvider cart;
    late OrdersProvider orders;
    late int initialOrderCount;

    AssistantLocalActions makeLocal() => AssistantLocalActions(
          cart: cart,
          orders: orders,
          loadCatalog: () async => const [],
        );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cart = CartProvider();
      orders = OrdersProvider();
      await Future<void>.delayed(Duration.zero);
      initialOrderCount = orders.orders.length;
    });

    test(
        'doctor booking with backend down → local quote-pending order in '
        'OrdersProvider, success reply (never "bhej nahi paya")', () async {
      // _FakeApi.createAssessmentRequest throws (noSuchMethod) — the demo
      // fallback must record the request locally and report success.
      final r = await makeExecutor(local: makeLocal()).performConfirmed(
        const SubmitAction(
          kind: ConfirmedKind.bookService,
          label: 'book doctor',
          data: {'service_category': 'doctor'},
        ),
      );
      expect(r, isA<Answer>());
      final text = (r as Answer).text;
      expect(text, isNot(contains('nahi')));
      expect(text, contains('My Orders'));

      expect(orders.orders.length, initialOrderCount + 1);
      final order = orders.orders.first;
      expect(OrdersProvider.isQuotePending(order), isTrue);
      expect(order['totalAmount'], 0); // manpower rule: no price, ever
      final items = order['items'] as List;
      expect((items.first as Map)['name'], contains('Doctor'));
    });

    test('renewal with backend down → local quote-pending renewal request',
        () async {
      final r = await makeExecutor(local: makeLocal()).performConfirmed(
        const SubmitAction(
          kind: ConfirmedKind.renewService,
          label: 'renew nursing',
          data: {'service_category': 'nursing'},
        ),
      );
      expect(r, isA<Answer>());
      expect(orders.orders.length, initialOrderCount + 1);
      expect(OrdersProvider.isQuotePending(orders.orders.first), isTrue);
    });

    test('backend down + no local sink → honest guidance, not a silent crash',
        () async {
      final r = await makeExecutor().performConfirmed(
        const SubmitAction(
          kind: ConfirmedKind.bookService,
          label: 'book doctor',
          data: {'service_category': 'doctor'},
        ),
      );
      expect(r, isA<Degraded>());
      expect((r as Degraded).text.toLowerCase(),
          anyOf(contains('services'), contains('call')));
    });

    test('raise_concern with backend down → honest capability message, '
        'points at a working path (no fake retry-later)', () async {
      final r = await makeExecutor(local: makeLocal()).performConfirmed(
        const SubmitAction(
          kind: ConfirmedKind.raiseConcern,
          label: 'concern',
          data: {'description': 'Nurse late aayi'},
        ),
      );
      expect(r, isA<Degraded>());
      final text = (r as Degraded).text;
      expect(text, isNot(contains('thodi der baad')));
      expect(text.toLowerCase(),
          anyOf(contains('concern'), contains('call')));
    });
  });
}
