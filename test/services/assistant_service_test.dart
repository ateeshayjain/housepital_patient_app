// test/services/assistant_service_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:housepital_patient/models/assistant_models.dart';
import 'package:housepital_patient/services/assistant_service.dart';

AssistantRequest _req(String text) => AssistantRequest(
      text: text,
      patientId: 'p1',
      role: 'PRIMARY_CONTACT',
      locale: 'hi',
    );

void main() {
  group('AssistantService stub mode', () {
    late AssistantService service;

    setUp(() {
      service = AssistantService(useStub: true);
    });

    test('bill / mahine keyword → get_billing', () async {
      final r = await service.ask(_req('iss mahine ka bill kitna hai'));
      expect(r.action, AssistantAction.getBilling);
      expect(r.replyText, isNotEmpty);
    });

    test('duty / din keyword → get_duty_days', () async {
      final r = await service.ask(_req('staff kitne din aaya iss mahine'));
      expect(r.action, AssistantAction.getDutyDays);
    });

    test('call / phone keyword → place_call with target', () async {
      final r = await service.ask(_req('health manager ko call karo'));
      expect(r.action, AssistantAction.placeCall);
      expect(r.params['target'], isNotNull);
    });

    test('navigate keyword → navigate with route', () async {
      final r = await service.ask(_req('reports dikhao'));
      expect(r.action, AssistantAction.navigate);
      expect(r.params['route'], isNotNull);
    });

    test('unmatched text → none with Hinglish fallback', () async {
      final r = await service.ask(_req('blah blah xyz'));
      expect(r.action, AssistantAction.none);
      expect(r.replyText, isNotEmpty);
    });

    // ── Demo-mode action intents (field-report regressions) ────────────────

    test('"add a nebulizer to my cart" → add_to_cart with item query',
        () async {
      final r = await service.ask(_req('add a nebulizer to my cart'));
      expect(r.action, AssistantAction.addToCart);
      expect(r.params['query'], 'nebulizer');
    });

    test('Hinglish "oxygen concentrator cart mein daal do" → add_to_cart',
        () async {
      final r =
          await service.ask(_req('oxygen concentrator cart mein daal do'));
      expect(r.action, AssistantAction.addToCart);
      expect(r.params['query'], 'oxygen concentrator');
    });

    test('add-to-cart with no item named → safe none, asks for the item',
        () async {
      final r = await service.ask(_req('cart mein daal do'));
      expect(r.action, AssistantAction.none);
      expect(r.replyText, isNotEmpty);
    });

    test('"cart kholo" (no add-verb) still routes to navigate /cart',
        () async {
      final r = await service.ask(_req('cart kholo'));
      expect(r.action, AssistantAction.navigate);
      expect(r.params['route'], '/cart');
    });

    test('"book a doctor consultation" → book_service with doctor category',
        () async {
      final r = await service.ask(_req('book a doctor consultation'));
      expect(r.action, AssistantAction.bookService);
      expect(r.params['service_category'], 'doctor');
    });
  });

  group('AssistantService backend mode', () {
    test('parses a valid backend response', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'action': 'get_billing',
            'params': {},
            'reply_text': 'Bill ready',
          }),
          200,
        );
      });
      final service =
          AssistantService(useStub: false, client: client, baseUrl: 'https://x');
      final r = await service.ask(_req('bill'));
      expect(r.action, AssistantAction.getBilling);
      expect(r.replyText, 'Bill ready');
    });

    test('HTTP 500 → safe none + degradation message (never throws)', () async {
      final client = MockClient((req) async => http.Response('boom', 500));
      final service =
          AssistantService(useStub: false, client: client, baseUrl: 'https://x');
      final r = await service.ask(_req('bill'));
      expect(r.action, AssistantAction.none);
      expect(r.replyText, isNotEmpty);
    });

    test('network error → safe none + degradation message', () async {
      final client = MockClient((req) async => throw Exception('no network'));
      final service =
          AssistantService(useStub: false, client: client, baseUrl: 'https://x');
      final r = await service.ask(_req('bill'));
      expect(r.action, AssistantAction.none);
      expect(r.replyText, isNotEmpty);
    });

    test('malformed JSON body → safe none', () async {
      final client = MockClient((req) async => http.Response('not json', 200));
      final service =
          AssistantService(useStub: false, client: client, baseUrl: 'https://x');
      final r = await service.ask(_req('bill'));
      expect(r.action, AssistantAction.none);
      expect(r.replyText, isNotEmpty);
    });
  });
}
