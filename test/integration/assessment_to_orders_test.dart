// test/integration/assessment_to_orders_test.dart
//
// Integration-style test for the assessment submission flow:
// submit assessment -> verify in assessments list -> verify NOT in orders -> cancel

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/providers/orders_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('assessment submission flow: submit, verify in assessments, not in orders, cancel', () {
    final orders = OrdersProvider();

    // 1. Submit an assessment (nurse, basic, 12hr)
    orders.addAssessment(
      serviceId: 'svc-nurse-basic-12h',
      serviceName: 'Nursing Care - Basic 12hr',
      formData: {
        'serviceType': 'nurse',
        'level': 'basic',
        'shift': '12hr',
        'patientAge': 72,
        'condition': 'post-surgery recovery',
      },
    );

    // 2. Verify it appears in assessments list with status 'submitted'
    expect(orders.assessments.length, 1);
    final assessment = orders.assessments.first;
    expect(assessment['status'], 'submitted');
    expect(assessment['serviceId'], 'svc-nurse-basic-12h');
    expect(assessment['serviceName'], 'Nursing Care - Basic 12hr');
    expect((assessment['id'] as String).startsWith('HPL-ASR-'), isTrue);

    // 3. Verify it does NOT appear in orders list
    expect(orders.orders, isEmpty);

    // 4. Cancel the assessment and verify status changes
    final assessmentId = assessment['id'] as String;
    orders.cancelAssessment(assessmentId);
    expect(orders.assessments.first['status'], 'cancelled');
    expect(orders.assessments.first['cancelledAt'], isNotNull);

    // 5. Still not in orders
    expect(orders.orders, isEmpty);
  });
}
