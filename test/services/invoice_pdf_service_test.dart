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

  // ───────────────────────────────────────────────────────────────────────
  // Content-policy assertions. With compress: false the base-14-font text
  // stays literal in the content streams, so the inviolable no-manpower-
  // prices rule can be checked against the ACTUAL bytes, not just the
  // code path.
  // ───────────────────────────────────────────────────────────────────────
  group('pro-forma content policy (uncompressed bytes)', () {
    final quoteOrder = <String, dynamic>{
      'id': 'HPL-BOOK-7777777',
      'quoteStatus': 'pending',
      'status': 'pending',
      'createdAt': DateTime(2026, 6, 1).toIso8601String(),
      'type': 'manpower',
      'items': [
        {
          'equipmentId': 'mp-caretaker-adv',
          'name': 'Caretaker (Advanced) 24 Hours',
          'quantity': 1,
          'isService': true,
          // Even if a price somehow leaks onto the order map (this is the
          // exact key the renderer reads), the PDF must not render it for a
          // quote-pending order.
          'unitPrice': 35000,
        },
      ],
    };

    test('quote-pending: PRO FORMA title, item listed, ZERO amounts',
        () async {
      final bytes = await InvoicePdfService()
          .buildInvoicePdf(quoteOrder, compress: false);
      final text = String.fromCharCodes(bytes);

      // dart_pdf emits each WORD as its own (word)Tj op, so assertions are
      // word-token level, not phrase level.
      expect(text, contains('(FORMA)'));
      expect(text, contains('(INVOICE)'));
      expect(text, contains('(Caretaker)'));
      expect(text, contains('(confirmed)')); // "…confirmed on call"

      // The policy core: no rupee amounts anywhere on a pro forma.
      // Amounts render as the word token "(Rs)" followed by a number token.
      expect(text, isNot(contains('(Rs)')),
          reason: 'PRO FORMA must not contain any "Rs" amount token');
      expect(text, isNot(contains('GST')));
      expect(text, isNot(contains('35000')));
    });

    test('priced order: full invoice WITH amounts and GST', () async {
      final pricedOrder = <String, dynamic>{
        'id': 'HPL-EQP-1234567',
        'status': 'paid',
        'createdAt': DateTime(2026, 6, 2).toIso8601String(),
        'items': [
          {
            'equipmentId': 'eq-wheelchair',
            'name': 'Wheelchair Foldable',
            'quantity': 2,
            'unitPrice': 4500,
          },
        ],
      };
      final bytes = await InvoicePdfService()
          .buildInvoicePdf(pricedOrder, compress: false);
      final text = String.fromCharCodes(bytes);

      expect(text, contains('(INVOICE)'));
      expect(text, isNot(contains('(FORMA)')));
      expect(text, contains('GST'));
      // subtotal 9000, GST 1620, total 10620 — all visible as number tokens.
      expect(text, contains('(Rs)'));
      expect(text, contains('9000'));
      expect(text, contains('1620'));
      expect(text, contains('10620'));
    });

    test('deterministic content: same order builds identical PDFs modulo /ID',
        () async {
      // The CONTENT must not embed a wall clock (date comes from the order).
      // The one legitimately varying byte range is the standard PDF /ID file
      // identifier in the trailer — strip it, then require equality.
      String norm(List<int> bytes) => String.fromCharCodes(bytes)
          .replaceAll(RegExp(r'/ID\[<[0-9a-f]+><[0-9a-f]+>\]'), '/ID[]');
      final a = await InvoicePdfService()
          .buildInvoicePdf(quoteOrder, compress: false);
      final b = await InvoicePdfService()
          .buildInvoicePdf(quoteOrder, compress: false);
      expect(norm(a), equals(norm(b)),
          reason: 'PDF content differs across builds — a DateTime.now() or '
              'random value crept into the document body');
    });
  });
}
