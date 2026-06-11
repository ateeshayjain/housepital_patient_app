// test/services/invoice_pdf_service_test.dart
//
// Unit tests for InvoicePdfService.buildInvoicePdf — bytes-level only.
// Printing.sharePdf is deliberately NOT exercised (platform channel).
//
//  • priced order  → non-empty, valid %PDF bytes
//  • quote-pending → builds the PRO FORMA variant without throwing
//    (the no-amounts policy is enforced structurally: the amounts column
//    and totals block are never built on that code path)

import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/services/invoice_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('priced demo order builds non-empty PDF bytes', () async {
    final bytes =
        await InvoicePdfService().buildInvoicePdf(DemoData.orders.first);
    expect(bytes, isNotEmpty);
    // Valid PDF magic header.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('every demo order builds without throwing', () async {
    for (final order in DemoData.orders) {
      final bytes = await InvoicePdfService().buildInvoicePdf(order);
      expect(bytes, isNotEmpty, reason: 'order ${order['id']} built empty');
    }
  });

  test('quote-pending (manpower) order builds the pro forma path', () async {
    // Manpower booking awaiting the pricing call — no unitPrice anywhere,
    // mirroring how assessment-accepted orders are persisted.
    final order = <String, dynamic>{
      'id': 'HPL-BOOK-9999999',
      'quoteStatus': 'pending',
      'status': 'pending',
      'createdAt': DateTime(2026, 6, 1).toIso8601String(),
      'type': 'manpower',
      'items': [
        {
          'equipmentId': 'mp-caretaker-basic',
          'name': 'Caretaker (Basic) 12 Hours',
          'quantity': 1,
          'isService': true,
        },
      ],
    };

    final bytes = await InvoicePdfService().buildInvoicePdf(order);
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('order with missing/odd fields still builds (defensive)', () async {
    final bytes = await InvoicePdfService().buildInvoicePdf(<String, dynamic>{
      'id': 'HPL-BOOK-0000000',
      'items': <dynamic>[],
    });
    expect(bytes, isNotEmpty);
  });
}
