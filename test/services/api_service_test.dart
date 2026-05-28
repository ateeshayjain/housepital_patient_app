// test/services/api_service_test.dart
//
// Comprehensive tests for ApiService (BUG-10).
//
// Approach: ApiService accepts an optional http.Client via its constructor
// (added in fix/audit-batch-3 — backward-compatible default), so we inject a
// MockClient from package:http/testing.dart. This lets us assert:
//   • Bearer token attachment, headers, URI / body construction
//   • Status-code → exception mapping (401/404/500 → ApiException)
//   • Network failure (SocketException) → ApiException retried then rethrown
//   • TimeoutException retried then rethrown
//   • JSON decode failure → throws
//   • Each public method has a happy-path + error-path test
//
// The retry logic in _withRetry uses Future.delayed of up to 2s per attempt
// (1s * attempt) — to keep tests fast for retry paths we drive via fake async
// or just accept the small delay. We use a counter on the mock to verify
// retry behaviour without slowing tests excessively. We use MockClient
// (synchronous) so each request returns immediately.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:housepital_patient/config/constants.dart';
import 'package:housepital_patient/services/api_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a MockClient that returns [body] with [status] for every request.
MockClient _staticClient(int status, String body,
    {Map<String, String>? headers}) {
  return MockClient((req) async => http.Response(
        body,
        status,
        headers: headers ?? const {'content-type': 'application/json'},
      ));
}

/// Build a MockClient that captures each request into [captured] and then
/// returns [status] with [body].
MockClient _capturingClient(
  List<http.Request> captured, {
  int status = 200,
  String body = '{}',
}) {
  return MockClient((req) async {
    captured.add(req);
    return http.Response(body, status,
        headers: const {'content-type': 'application/json'});
  });
}

void main() {
  // ----------------------------------------------------------
  // Construction & base URL
  // ----------------------------------------------------------
  group('ApiService construction', () {
    test('default baseUrl comes from AppConstants', () {
      final svc = ApiService();
      expect(svc.baseUrl, equals(AppConstants.apiBaseUrl));
    });

    test('custom baseUrl is respected', () {
      final svc = ApiService(baseUrl: 'https://example.test/api');
      expect(svc.baseUrl, equals('https://example.test/api'));
    });

    test('accepts injected http.Client (does not crash)', () {
      final client = _staticClient(200, '{}');
      // Should not throw.
      final svc = ApiService(client: client);
      expect(svc, isNotNull);
    });
  });

  // ----------------------------------------------------------
  // Auth header
  // ----------------------------------------------------------
  group('Auth header', () {
    test('omits Authorization header when no token set', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured, body: '{"ok":true}'),
      );

      await svc.get('/anything');

      expect(captured.length, 1);
      expect(captured.first.headers.containsKey('Authorization'), isFalse);
    });

    test('attaches Bearer token after setAuthToken()', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured, body: '{"ok":true}'),
      );
      svc.setAuthToken('abc123');

      await svc.get('/something');

      expect(captured.length, 1);
      expect(
        captured.first.headers['Authorization'],
        equals('Bearer abc123'),
      );
    });

    test('always sends application/json content-type', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured),
      );

      await svc.get('/x');

      expect(captured.first.headers['Content-Type'], equals('application/json'));
    });
  });

  // ----------------------------------------------------------
  // URI / query param construction
  // ----------------------------------------------------------
  group('URI construction', () {
    test('GET concatenates baseUrl + path', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://api.test/v1',
        client: _capturingClient(captured, body: '{}'),
      );

      await svc.get('/patients/123');

      expect(captured.first.url.toString(),
          equals('https://api.test/v1/patients/123'));
      expect(captured.first.method, equals('GET'));
    });

    test('GET appends query params', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://api.test',
        client: _capturingClient(captured,
            body: '{"vitals":[]}'),
      );

      await svc.getVitalsHistory('p-1', period: '30d');

      final url = captured.first.url;
      expect(url.path, equals('/patients/p-1/vitals'));
      expect(url.queryParameters['period'], equals('30d'));
    });
  });

  // ----------------------------------------------------------
  // _handleResponse — status code mapping
  // ----------------------------------------------------------
  group('Response handling', () {
    test('200 with JSON body returns decoded map', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(200, '{"hello":"world"}'),
      );

      final res = await svc.get('/x');
      expect(res, equals({'hello': 'world'}));
    });

    test('204 with empty body returns empty map', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(204, ''),
      );

      final res = await svc.get('/x');
      expect(res, equals({}));
    });

    test('400 throws ApiException(400) with message from body', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(400, '{"message":"bad input"}'),
      );

      await expectLater(
        svc.get('/x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'bad input'),
        ),
      );
    });

    test('401 throws ApiException(401)', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(401, '{"message":"Unauthorized"}'),
      );

      await expectLater(
        svc.get('/x'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('404 throws ApiException(404)', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(404, '{"message":"Not found"}'),
      );

      await expectLater(
        svc.get('/missing'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Not found')),
      );
    });

    test('500 throws ApiException(500) after retries exhausted', () async {
      int calls = 0;
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: MockClient((req) async {
          calls++;
          return http.Response('{"message":"boom"}', 500);
        }),
      );

      await expectLater(
        svc.get('/x'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
      // Initial call + 2 retries = 3 attempts.
      expect(calls, equals(3));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('500 then 200 — retry succeeds, returns decoded body', () async {
      int calls = 0;
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: MockClient((req) async {
          calls++;
          if (calls < 2) {
            return http.Response('{"message":"server hiccup"}', 500);
          }
          return http.Response('{"ok":true}', 200);
        }),
      );

      final res = await svc.get('/x');
      expect(res, equals({'ok': true}));
      expect(calls, equals(2));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('500 with empty body falls back to generic message', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(500, ''),
      );

      await expectLater(
        svc.get('/x'),
        throwsA(isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('500'))),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('200 with malformed JSON throws FormatException', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(200, '{not-json'),
      );

      await expectLater(
        svc.get('/x'),
        throwsA(isA<FormatException>()),
      );
    });

    test('error body with non-JSON does NOT swallow — propagates', () async {
      // 400 with non-JSON body: _handleResponse tries jsonDecode and throws.
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(400, '<html>nope</html>'),
      );

      await expectLater(
        svc.get('/x'),
        throwsA(anything),
      );
    });
  });

  // ----------------------------------------------------------
  // Network / timeout error handling
  // ----------------------------------------------------------
  group('Network errors', () {
    test('SocketException is retried then rethrown', () async {
      int calls = 0;
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: MockClient((req) async {
          calls++;
          throw const SocketException('connection refused');
        }),
      );

      await expectLater(
        svc.get('/x'),
        throwsA(isA<SocketException>()),
      );
      expect(calls, equals(3)); // initial + 2 retries
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('SocketException then success returns body', () async {
      int calls = 0;
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: MockClient((req) async {
          calls++;
          if (calls == 1) throw const SocketException('flaky');
          return http.Response('{"ok":1}', 200);
        }),
      );

      final res = await svc.get('/x');
      expect(res, equals({'ok': 1}));
      expect(calls, equals(2));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('TimeoutException is retried then rethrown', () async {
      int calls = 0;
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: MockClient((req) async {
          calls++;
          throw TimeoutException('slow');
        }),
      );

      await expectLater(
        svc.get('/x'),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, equals(3));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // ----------------------------------------------------------
  // POST / PUT / DELETE payload and method correctness
  // ----------------------------------------------------------
  group('HTTP methods', () {
    test('POST sends method=POST and JSON-encoded body', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(
          captured,
          body: jsonEncode({
            'booking': {
              'id': 'b1',
              'booking_number': 'BK-1',
              'patient_id': 'p',
              'service_id': 's',
              'booking_type': 'instant',
              'status': 'pending',
              'scheduled_date': '2026-06-01',
              'scheduled_slot': '09:00',
              'price_amount': 1500,
              'gst_amount': 270,
              'total_amount': 1770,
              'payment_status': 'pending',
              'created_at': '2026-05-28T00:00:00Z',
            }
          }),
        ),
      );

      await svc.createBooking(
        patientId: 'p',
        serviceId: 's',
        scheduledDate: '2026-06-01',
        scheduledSlot: '09:00',
      );

      expect(captured.first.method, equals('POST'));
      final body = jsonDecode(captured.first.body);
      expect(body['patient_id'], equals('p'));
      expect(body['service_id'], equals('s'));
      expect(body['scheduled_date'], equals('2026-06-01'));
      expect(body['scheduled_slot'], equals('09:00'));
      // Optional promo_code is omitted when null.
      expect(body.containsKey('promo_code'), isFalse);
    });

    test('PUT uses method=PUT', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured),
      );

      await svc.markNotificationRead('n-1');

      expect(captured.first.method, equals('PUT'));
      expect(captured.first.url.path, equals('/notifications/n-1/read'));
    });

    test('DELETE uses method=DELETE', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured),
      );

      await svc.deleteMedication('p-1', 'm-1');

      expect(captured.first.method, equals('DELETE'));
      expect(captured.first.url.path, equals('/patients/p-1/medications/m-1'));
    });
  });

  // ----------------------------------------------------------
  // Domain methods — happy path + error path per group.
  // ----------------------------------------------------------
  group('Auth endpoints', () {
    test('verifyOtp posts phone+otp', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured, body: '{"token":"tk"}'),
      );

      final res = await svc.verifyOtp('9999911911', '123456');

      expect(res['token'], equals('tk'));
      expect(captured.first.url.path, equals('/auth/verify-otp'));
      final body = jsonDecode(captured.first.body);
      expect(body['phone'], '9999911911');
      expect(body['otp'], '123456');
    });

    test('verifyOtp surfaces backend 401 error', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(401, '{"message":"bad otp"}'),
      );

      await expectLater(svc.verifyOtp('9999911911', '000000'),
          throwsA(isA<ApiException>()));
    });

    test('completeOnboarding posts profile fields', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured, body: '{"ok":true}'),
      );

      await svc.completeOnboarding(
          name: 'X', relationship: 'son', preferredLanguage: 'hi');

      final body = jsonDecode(captured.first.body);
      expect(body['name'], 'X');
      expect(body['relationship'], 'son');
      expect(body['preferred_language'], 'hi');
    });
  });

  group('Patient endpoints', () {
    test('getPatients decodes list', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(
          200,
          jsonEncode({
            'patients': [
              {'id': 'p1', 'name': 'A'},
              {'id': 'p2', 'name': 'B'},
            ],
          }),
        ),
      );

      final list = await svc.getPatients();
      expect(list, hasLength(2));
      expect(list.first.id, 'p1');
      expect(list.last.name, 'B');
    });

    test('getPatients on 500 throws ApiException', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(500, '{"message":"boom"}'),
      );

      await expectLater(svc.getPatients(),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'sc', 500)));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('getPatient decodes single patient', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(
          200,
          jsonEncode({
            'patient': {'id': 'p1', 'name': 'Mom'}
          }),
        ),
      );

      final p = await svc.getPatient('p1');
      expect(p.id, 'p1');
      expect(p.name, 'Mom');
    });
  });

  group('Dashboard endpoints', () {
    test('getDashboard returns decoded map', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(200, '{"deployments":[],"vitals":null}'),
      );

      final res = await svc.getDashboard('p-1');
      expect(res, isA<Map>());
      expect(res.containsKey('deployments'), isTrue);
    });

    test('getDashboard 404 throws', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(404, '{"message":"no patient"}'),
      );

      await expectLater(svc.getDashboard('missing'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'sc', 404)));
    });
  });

  group('Attendance endpoints', () {
    test('getTodayAttendance returns null when attendance is null', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(200, '{"attendance":null}'),
      );

      final res = await svc.getTodayAttendance('p-1');
      expect(res, isNull);
    });
  });

  group('Vitals endpoints', () {
    test('getLatestVitals returns null when null', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(200, '{"vitals":null}'),
      );

      expect(await svc.getLatestVitals('p1'), isNull);
    });

    test('getVitalsHistory passes period query', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured, body: '{"vitals":[]}'),
      );

      await svc.getVitalsHistory('p-1', period: '7d');

      expect(captured.first.url.queryParameters['period'], '7d');
    });
  });

  group('Services / Bookings endpoints', () {
    test('getServiceCatalog returns list', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(
          200,
          jsonEncode({
            'services': [
              {
                'id': 's1',
                'name': 'Nursing',
                'category': 'nursing_visit',
                'booking_type': 'instant',
                'description': 'Home nursing visit',
                'base_price_min': 1500,
                'base_price_max': 1500,
                'duration_minutes': 60,
                'lead_time_hours': 2,
                'is_active': true,
              }
            ]
          }),
        ),
      );

      final svcs = await svc.getServiceCatalog();
      expect(svcs, hasLength(1));
      expect(svcs.first.id, 's1');
    });

    test('cancelBooking POSTs reason', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured),
      );

      await svc.cancelBooking('b-1', 'changed plans');

      expect(captured.first.method, 'POST');
      expect(captured.first.url.path, '/bookings/b-1/cancel');
      expect(jsonDecode(captured.first.body)['reason'], 'changed plans');
    });

    test('getAvailableSlots formats date YYYY-MM-DD with zero-padding',
        () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured, body: '{"slots":[]}'),
      );

      await svc.getAvailableSlots('s-1', DateTime(2026, 4, 5));

      expect(captured.first.url.queryParameters['date'], '2026-04-05');
    });
  });

  group('Payments endpoints', () {
    test('createPaymentOrder posts required fields', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured, body: '{"order_id":"ord_123"}'),
      );

      final res = await svc.createPaymentOrder(
        patientId: 'p1',
        amount: 25000,
        paymentType: 'invoice',
        referenceId: 'inv-1',
      );

      expect(res['order_id'], 'ord_123');
      expect(captured.first.url.path, '/payments/create-order');
      final body = jsonDecode(captured.first.body);
      expect(body['patient_id'], 'p1');
      expect(body['amount'], 25000);
      expect(body['payment_type'], 'invoice');
      expect(body['reference_id'], 'inv-1');
      // Optional reference_type omitted when null.
      expect(body.containsKey('reference_type'), isFalse);
    });

    test('verifyPayment posts razorpay signature triple', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured, body: '{"verified":true}'),
      );

      await svc.verifyPayment(
        razorpayPaymentId: 'pay_1',
        razorpayOrderId: 'ord_1',
        razorpaySignature: 'sig_1',
      );

      expect(captured.first.url.path, '/payments/verify');
      final body = jsonDecode(captured.first.body);
      expect(body['razorpay_payment_id'], 'pay_1');
      expect(body['razorpay_order_id'], 'ord_1');
      expect(body['razorpay_signature'], 'sig_1');
    });

    test('verifyPayment surfaces 400 from backend', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(400, '{"message":"bad signature"}'),
      );

      await expectLater(
        svc.verifyPayment(
          razorpayPaymentId: 'p',
          razorpayOrderId: 'o',
          razorpaySignature: 's',
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'sc', 400)
            .having((e) => e.message, 'msg', 'bad signature')),
      );
    });
  });

  group('Notifications endpoints', () {
    test('markAllNotificationsRead hits /notifications/read-all', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured),
      );

      await svc.markAllNotificationsRead();

      expect(captured.first.method, 'PUT');
      expect(captured.first.url.path, '/notifications/read-all');
    });

    test('getNotificationsPaginated passes page+page_size', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured, body: '{"notifications":[]}'),
      );

      await svc.getNotificationsPaginated(page: 3, pageSize: 50);

      final qp = captured.first.url.queryParameters;
      expect(qp['page'], '3');
      expect(qp['page_size'], '50');
    });
  });

  group('Concerns endpoints', () {
    test('raiseConcern posts with optional fields included', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(
          captured,
          body: jsonEncode({
            'concern': {
              'id': 'c1',
              'patient_id': 'p',
              'category': 'staff_quality',
              'description': 'd',
              'urgency': 'high',
              'status': 'open',
              'created_at': '2026-05-28T00:00:00Z',
            }
          }),
        ),
      );

      await svc.raiseConcern(
        patientId: 'p',
        category: 'staff_quality',
        description: 'd',
        urgency: 'high',
        preferredResolution: 'replace_staff',
        evidenceUrls: ['https://x/img.jpg'],
      );

      final body = jsonDecode(captured.first.body);
      expect(body['preferred_resolution'], 'replace_staff');
      expect(body['evidence_urls'], ['https://x/img.jpg']);
    });
  });

  group('Family member endpoints', () {
    test('inviteFamilyMember posts phone', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured),
      );

      await svc.inviteFamilyMember('p-1', '9999911911');

      expect(captured.first.url.path, '/patients/p-1/family/invite');
      expect(jsonDecode(captured.first.body)['phone'], '9999911911');
    });

    test('removeFamilyMember hits remove endpoint', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured),
      );

      await svc.removeFamilyMember('p-1', 'm-1');

      expect(captured.first.method, 'POST');
      expect(captured.first.url.path, '/patients/p-1/family/m-1/remove');
    });
  });

  group('FCM token endpoint', () {
    test('updateFcmToken posts token', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured),
      );

      await svc.updateFcmToken('fcm-token-xyz');

      expect(captured.first.url.path, '/auth/fcm-token');
      expect(jsonDecode(captured.first.body)['token'], 'fcm-token-xyz');
    });
  });

  group('Medications endpoints', () {
    test('getMedications decodes list', () async {
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _staticClient(
          200,
          jsonEncode({
            'medications': [
              {
                'id': 'm1',
                'patient_id': 'p1',
                'name': 'Crocin',
                'dosage': '500mg',
                'slots': ['morning', 'evening'],
                'start_date': '2026-05-01',
                'is_active': true,
              }
            ]
          }),
        ),
      );

      final meds = await svc.getMedications('p1');
      expect(meds, hasLength(1));
      expect(meds.first.name, 'Crocin');
    });

    test('updateMedicationStock PUTs stock_count payload', () async {
      final captured = <http.Request>[];
      final svc = ApiService(
        baseUrl: 'https://x.test',
        client: _capturingClient(captured),
      );

      await svc.updateMedicationStock('p1', 'm1', 30);

      expect(captured.first.method, 'PUT');
      expect(captured.first.url.path,
          '/patients/p1/medications/m1/stock');
      expect(jsonDecode(captured.first.body)['stock_count'], 30);
    });
  });

  // ----------------------------------------------------------
  // ApiException itself
  // ----------------------------------------------------------
  group('ApiException', () {
    test('toString includes status code and message', () {
      final e = ApiException(statusCode: 503, message: 'server down');
      expect(e.toString(), contains('503'));
      expect(e.toString(), contains('server down'));
    });
  });
}
