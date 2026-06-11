// test/models/assistant_models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/assistant_models.dart';

void main() {
  group('AssistantAction.fromString', () {
    test('maps known action strings', () {
      expect(AssistantAction.fromString('get_billing'), AssistantAction.getBilling);
      expect(AssistantAction.fromString('get_duty_days'), AssistantAction.getDutyDays);
      expect(AssistantAction.fromString('place_call'), AssistantAction.placeCall);
      expect(AssistantAction.fromString('navigate'), AssistantAction.navigate);
      expect(AssistantAction.fromString('add_to_cart'), AssistantAction.addToCart);
    });

    test('unknown / null action degrades to none', () {
      expect(AssistantAction.fromString('launch_rockets'), AssistantAction.none);
      expect(AssistantAction.fromString(null), AssistantAction.none);
      expect(AssistantAction.fromString(''), AssistantAction.none);
    });
  });

  group('AssistantResponse.fromJson', () {
    test('valid get_billing action parses', () {
      final r = AssistantResponse.fromJson({
        'action': 'get_billing',
        'reply_text': 'Aapka bill ready hai.',
      });
      expect(r.action, AssistantAction.getBilling);
      expect(r.replyText, 'Aapka bill ready hai.');
      expect(r.params, isEmpty);
    });

    test('unknown action degrades to none', () {
      final r = AssistantResponse.fromJson(
          {'action': 'launch_rockets', 'reply_text': 'x'});
      expect(r.action, AssistantAction.none);
    });

    test('valid action with missing params still parses, params empty', () {
      final r = AssistantResponse.fromJson(
          {'action': 'place_call', 'reply_text': 'Calling…'});
      expect(r.action, AssistantAction.placeCall);
      expect(r.params, isEmpty);
    });

    test('valid action with non-map params degrades params to empty', () {
      final r = AssistantResponse.fromJson({
        'action': 'place_call',
        'params': 'not-a-map',
        'reply_text': 'Calling…',
      });
      expect(r.action, AssistantAction.placeCall);
      expect(r.params, isEmpty);
    });

    test('place_call parses target param', () {
      final r = AssistantResponse.fromJson({
        'action': 'place_call',
        'params': {'target': 'health_manager'},
        'reply_text': 'Calling…',
      });
      expect(r.action, AssistantAction.placeCall);
      expect(r.params['target'], 'health_manager');
    });

    test('missing reply_text degrades to empty string, never null', () {
      final r = AssistantResponse.fromJson({'action': 'get_billing'});
      expect(r.replyText, isA<String>());
    });
  });

  group('AssistantRequest', () {
    test('toJson serializes all fields', () {
      final req = AssistantRequest(
        text: 'iss mahine ka bill',
        patientId: 'p1',
        role: 'PRIMARY_CONTACT',
        locale: 'hi',
      );
      final json = req.toJson();
      expect(json['text'], 'iss mahine ka bill');
      expect(json['patient_id'], 'p1');
      expect(json['role'], 'PRIMARY_CONTACT');
      expect(json['locale'], 'hi');
    });
  });

  group('AssistantMessage', () {
    test('user and assistant messages carry text + role', () {
      final user = AssistantMessage.user('hello');
      final bot = AssistantMessage.assistant('hi there');
      expect(user.isUser, isTrue);
      expect(user.text, 'hello');
      expect(bot.isUser, isFalse);
      expect(bot.text, 'hi there');
    });

    test('assistant message can carry a pending action', () {
      final r = AssistantResponse(
        action: AssistantAction.placeCall,
        params: const {'target': 'health_manager'},
        replyText: 'Confirm?',
      );
      final msg = AssistantMessage.assistant('Confirm?', pendingAction: r);
      expect(msg.pendingAction, r);
    });
  });
}
