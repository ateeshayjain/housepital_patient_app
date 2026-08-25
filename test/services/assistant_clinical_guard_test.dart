// test/services/assistant_clinical_guard_test.dart
//
// Round 4 found that "bleeding ho raha hai" was answered with "Staff ki duty
// check kar raha hoon…". The duty-days branch matched the unanchored pattern
// `din`, and "blee-din-g" contains "din".
//
// Two things are pinned here, and they are not the same thing:
//   1. The specific collision is gone (word boundaries).
//   2. A medical situation never reaches the intent matcher AT ALL, on either
//      the stub or the cloud path. That is the guard, and it is the part that
//      survives someone adding a new short keyword later.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/assistant_models.dart';
import 'package:housepital_patient/services/assistant_service.dart';

void main() {
  final service = AssistantService();

  Future<AssistantResponse> ask(String text) => service.ask(AssistantRequest(
        text: text,
        patientId: 'p1',
        role: 'patient',
        locale: 'en',
      ));

  group('emergencies are intercepted before any intent routing', () {
    const emergencies = <String>[
      'bleeding ho raha hai',
      'papa ko bleeding ho rahi hai',
      'seene mein dard hai',
      'chest pain ho raha hai',
      'saans nahi aa rahi',
      'patient behosh ho gaye',
      'unconscious ho gaye hain',
      'fits aa rahe hain',
      'lakwa mar gaya',
      'ambulance bhejo',
    ];

    for (final phrase in emergencies) {
      test('"$phrase" offers the SOS call, never a task', () async {
        final r = await ask(phrase);
        expect(r.action, AssistantAction.placeCall,
            reason: 'an emergency must not be routed to an app task');
        expect(r.params['target'], 'sos');
        expect(r.action, isNot(AssistantAction.getDutyDays));
      });
    }

    test('the exact reported failure: bleeding must NOT reach duty-days',
        () async {
      final r = await ask('bleeding ho raha hai');
      expect(r.action, isNot(AssistantAction.getDutyDays),
          reason: 'the `din` substring inside "bleeding" is what did this');
      expect(r.replyText.toLowerCase(), contains('sos'));
    });
  });

  group('clinical symptoms are answered by a human, not by the app', () {
    const symptoms = <String>[
      'bukhar hai',
      'fever hai',
      'ulti ho rahi hai',
      'chakkar aa rahe hain',
      'ghaav se pus nikal raha hai',
    ];

    for (final phrase in symptoms) {
      test('"$phrase" does nothing side-effectful and gives no advice',
          () async {
        final r = await ask(phrase);
        expect(r.action, AssistantAction.none,
            reason: 'the executor must do nothing side-effectful for none');
        expect(r.replyText.toLowerCase(), contains('medical salah nahi'));
      });
    }
  });

  group('ordinary intents still route correctly', () {
    test('duty-days still works for a real duty question', () async {
      final r = await ask('staff kitne din aaya iss mahine');
      expect(r.action, AssistantAction.getDutyDays);
    });

    test('billing still works', () async {
      final r = await ask('mera bill kitna hai');
      expect(r.action, AssistantAction.getBilling);
    });

    test('add-to-cart still works', () async {
      final r = await ask('nebulizer cart mein daal do');
      expect(r.action, AssistantAction.addToCart);
    });

    test('a nurse call is still a nurse call, not an SOS', () async {
      final r = await ask('nurse ko call karo');
      expect(r.action, AssistantAction.placeCall);
      expect(r.params['target'], 'nurse');
    });

    test('a word merely CONTAINING din does not become a duty query',
        () async {
      final r = await ask('reading kaise dekhu');
      expect(r.action, isNot(AssistantAction.getDutyDays));
    });
  });
}
