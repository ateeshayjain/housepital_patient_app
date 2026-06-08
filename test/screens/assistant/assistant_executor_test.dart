// test/screens/assistant/assistant_executor_test.dart
//
// Safety-critical tests for the assistant tool executor.
// These MUST pass and must NOT be weakened:
//   - confirm-before-act for place_call
//   - permission gating via canUserPerform
//   - malformed params / unknown action → safe degradation
//   - no phone on file → no dial, no crash

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/models/assistant_models.dart';
import 'package:housepital_patient/services/i_api_service.dart';
import 'package:housepital_patient/screens/assistant/assistant_executor.dart';
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
  }) =>
      AssistantExecutor(
        api: api,
        role: role,
        patientId: patientId,
        contacts: contacts,
        deploymentId: deploymentId,
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
}
