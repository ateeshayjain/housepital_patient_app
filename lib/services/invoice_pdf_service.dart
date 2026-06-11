// lib/services/invoice_pdf_service.dart
//
// Builds a downloadable/shareable PDF invoice for an order (the
// Map<String, dynamic> shape persisted by OrdersProvider).
//
// Two order classes:
//  • Priced orders   → full invoice: items table with line totals, GST 18%
//    line and grand total.
//  • Quote-pending   → PRO FORMA: items listed WITHOUT any amounts (policy:
//    manpower prices are never displayed before the confirmation call, and
//    quote-pending orders must never render ₹0).
//
// buildInvoicePdf() is pure-ish (rootBundle for the logo, with a text
// fallback) so it is unit-testable; shareInvoice() wraps Printing.sharePdf
// and is only exercised on-device.

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../providers/orders_provider.dart';

class InvoicePdfService {
  static const _orange = PdfColor.fromInt(0xFFFF6B00);
  static const _grey = PdfColor.fromInt(0xFF6B7280);
  static const _greyLighter = PdfColor.fromInt(0xFFF3F4F6);

  /// Loads the brand logo from assets; null if unavailable (tests/web edge
  /// cases) — callers fall back to a text wordmark.
  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/images/housepital_logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _brandHeader(pw.MemoryImage? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null)
          pw.Image(logo, height: 36)
        else
          pw.Text('HOUSEPITAL',
              style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _orange)),
        pw.Spacer(),
        pw.Text('Housepital Home Healthcare',
            style: const pw.TextStyle(fontSize: 10, color: _grey)),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _fmtAmount(num amount) => 'Rs ${amount.round()}';

  /// Built-in Helvetica has no em/en-dash or curly-quote glyphs — swap them
  /// for ASCII so dynamic strings (item names, ids) always render.
  static String _ascii(String s) => s
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"');

  /// Line total for one item map: unitPrice x qty (x rentalMonths if rental).
  int _lineTotal(Map<String, dynamic> item) {
    final unitPrice = (item['unitPrice'] as num?)?.toInt() ?? 0;
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final isRental = item['isRental'] == true;
    final months = (item['rentalMonths'] as num?)?.toInt() ?? 1;
    return unitPrice * qty * (isRental ? months : 1);
  }

  /// Builds the invoice PDF bytes for [order]. Never displays amounts for
  /// quote-pending orders (pro forma).
  ///
  /// [compress] exists for tests only: uncompressed content streams keep the
  /// base-14-font text literal, so the no-amounts-on-pro-forma policy can be
  /// asserted against the actual bytes.
  Future<Uint8List> buildInvoicePdf(
    Map<String, dynamic> order, {
    bool compress = true,
  }) async {
    final logo = await _loadLogo();

    final orderId = order['id'] as String? ?? '';
    final status = order['status'] as String? ?? '';
    final createdAt = order['createdAt'] as String?;
    final date =
        createdAt != null ? DateTime.tryParse(createdAt) : null;
    final quotePending = OrdersProvider.isQuotePending(order);
    final items = (order['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final subtotal =
        items.fold<int>(0, (sum, item) => sum + _lineTotal(item));
    final gst = (subtotal * 0.18).round();
    final grandTotal = subtotal + gst;

    final headerStyle = pw.TextStyle(
        fontSize: 10, fontWeight: pw.FontWeight.bold, color: _grey);
    const cellStyle = pw.TextStyle(fontSize: 10);

    final doc = pw.Document(compress: compress);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _brandHeader(logo),
            pw.SizedBox(height: 16),
            pw.Text(quotePending ? 'PRO FORMA INVOICE' : 'INVOICE',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            if (quotePending) ...[
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: _greyLighter,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                    // ASCII hyphen: built-in Helvetica has no em-dash glyph.
                    'PRO FORMA - price will be confirmed on call',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ),
            ],
            pw.SizedBox(height: 12),
            // Invoice meta: order id, date, status.
            pw.Row(children: [
              pw.Text('Order: $orderId', style: cellStyle),
              pw.SizedBox(width: 24),
              if (date != null)
                pw.Text('Date: ${_fmtDate(date)}', style: cellStyle),
              pw.SizedBox(width: 24),
              pw.Text('Status: $status', style: cellStyle),
            ]),
            pw.SizedBox(height: 16),
            // Items table. Quote-pending: NO amount column at all.
            pw.Table(
              border: pw.TableBorder.all(color: _greyLighter, width: 0.5),
              columnWidths: quotePending
                  ? {
                      0: const pw.FlexColumnWidth(5),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(2),
                    }
                  : {
                      0: const pw.FlexColumnWidth(5),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(2),
                    },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _greyLighter),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Item', style: headerStyle)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Qty', style: headerStyle)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Rental', style: headerStyle)),
                    if (!quotePending)
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Line total', style: headerStyle)),
                  ],
                ),
                ...items.map((item) {
                  final isRental = item['isRental'] == true;
                  final months =
                      (item['rentalMonths'] as num?)?.toInt() ?? 1;
                  return pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                            _ascii(item['name'] as String? ?? 'Item'),
                            style: cellStyle)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                            '${(item['quantity'] as num?)?.toInt() ?? 1}',
                            style: cellStyle)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                            isRental ? '$months month(s)' : '-',
                            style: cellStyle)),
                    if (!quotePending)
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(_fmtAmount(_lineTotal(item)),
                              style: cellStyle)),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            if (!quotePending)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: ${_fmtAmount(subtotal)}',
                        style: cellStyle),
                    pw.SizedBox(height: 4),
                    pw.Text('GST (18%): ${_fmtAmount(gst)}',
                        style: cellStyle),
                    pw.SizedBox(height: 4),
                    pw.Text('Grand total: ${_fmtAmount(grandTotal)}',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              )
            else
              pw.Text(
                  'Amounts are intentionally omitted. Our coordinator will '
                  'confirm pricing with you on call before any payment.',
                  style: const pw.TextStyle(fontSize: 9, color: _grey)),
            pw.Spacer(),
            pw.Divider(color: _greyLighter),
            pw.Text(
                'Housepital - ICU-grade care at home. '
                'This is a computer-generated document.',
                style: const pw.TextStyle(fontSize: 8, color: _grey)),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// Builds and hands the invoice PDF to the platform share sheet.
  Future<void> shareInvoice(Map<String, dynamic> order) async {
    final bytes = await buildInvoicePdf(order);
    final id = order['id'] as String? ?? 'order';
    await Printing.sharePdf(bytes: bytes, filename: 'invoice-$id.pdf');
  }
}
