// test/services/handover_report_service_test.dart
//
// Unit tests for HandoverReportService.buildHandoverPdf — bytes-level only.
// Printing.sharePdf is deliberately NOT exercised (platform channel).

import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/services/handover_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds non-empty, valid PDF bytes', () async {
    final bytes = await HandoverReportService().buildHandoverPdf();
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('is deterministic for a fixed "now"', () async {
    // The adherence figures are seeded off the date — same now, same doc.
    final now = DateTime(2026, 6, 10);
    final a = await HandoverReportService().buildHandoverPdf(now: now);
    final b = await HandoverReportService().buildHandoverPdf(now: now);
    expect(a.length, b.length);
  });

  test('share filename uses the SAME injected date as the report body', () {
    // audit R2: shareHandover previously called DateTime.now() a second time
    // for the filename — the injected clock must drive both PDF and filename.
    final fixed = DateTime(2026, 6, 10);
    final name = HandoverReportService().handoverFilename(fixed);
    expect(name, contains('20260610'));
    expect(name, startsWith('housepital-handover-'));
    expect(name, endsWith('.pdf'));
  });

  test('filename zero-pads single-digit month and day', () {
    final name = HandoverReportService().handoverFilename(DateTime(2026, 1, 5));
    expect(name, contains('20260105'));
  });
}
