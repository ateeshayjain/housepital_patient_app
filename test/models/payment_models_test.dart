// test/models/payment_models_test.dart
//
// Tests for Invoice, InvoiceLineItem, PaymentTransaction, Coupon,
// and BillingSummary from lib/models/models.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

// ---------------------------------------------------------------------------
// Helpers — JSON factories
// ---------------------------------------------------------------------------

Map<String, dynamic> _invoiceJson({
  String status = 'pending',
  String? pdfUrl,
}) =>
    {
      'id': 'inv-001',
      'invoice_number': 'INV-2025-0001',
      'patient_id': 'patient-001',
      'billing_period_start': '2025-01-01T00:00:00Z',
      'billing_period_end': '2025-01-31T23:59:59Z',
      'line_items': [
        {
          'description': 'Nurse (Basic) 24 Hr x 30 days',
          'amount': 30000,
          'gst': 5400,
          'total': 35400,
          'type': 'manpower',
        },
        {
          'description': 'Hospital Bed rental',
          'amount': 2500,
          'gst': 450,
          'total': 2950,
        },
      ],
      'subtotal': 32500,
      'gst_total': 5850,
      'grand_total': 38350,
      'due_date': '2025-02-10T00:00:00Z',
      if (status != 'pending') 'status': status,
      if (pdfUrl != null) 'pdf_url': pdfUrl,
    };

Map<String, dynamic> _paymentJson({
  String status = 'completed',
  String? completedAt,
}) =>
    {
      'id': 'pay-001',
      'patient_id': 'patient-001',
      'invoice_id': 'inv-001',
      'booking_id': 'bk-001',
      'amount': 38350,
      'currency': 'INR',
      'method': 'upi',
      'status': status,
      'razorpay_payment_id': 'pay_xyz123',
      'razorpay_order_id': 'order_abc456',
      'razorpay_signature': 'sig_def789',
      'failure_reason': status == 'failed' ? 'Insufficient funds' : null,
      'refund_amount': status == 'refunded' ? 38350 : null,
      'refund_id': status == 'refunded' ? 'rfnd_001' : null,
      'receipt_url': 'https://receipts.example.com/001',
      'description': 'Payment for January invoice',
      'created_at': '2025-02-01T10:00:00Z',
      if (completedAt != null) 'completed_at': completedAt,
    };

Map<String, dynamic> _couponJson({
  String type = 'percentage',
  int value = 20,
  int? maxDiscount,
  int? minOrderValue,
  String validFrom = '2025-01-01T00:00:00Z',
  String validUntil = '2027-12-31T23:59:59Z',
  int? usageLimit,
  int usedCount = 0,
  bool isActive = true,
}) =>
    {
      'id': 'coupon-001',
      'code': 'SAVE20',
      'type': type,
      'value': value,
      if (maxDiscount != null) 'max_discount': maxDiscount,
      if (minOrderValue != null) 'min_order_value': minOrderValue,
      'description': 'Save 20% on first order',
      'applicable_categories': ['manpower', 'equipment'],
      'valid_from': validFrom,
      'valid_until': validUntil,
      if (usageLimit != null) 'usage_limit': usageLimit,
      'used_count': usedCount,
      'is_active': isActive,
    };

Map<String, dynamic> _billingSummaryJson() => {
      'total_due': 50000,
      'total_paid': 120000,
      'overdue_amount': 10000,
      'next_due_date': '2025-03-10T00:00:00Z',
      'invoice_count': 5,
      'overdue_count': 1,
    };

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Invoice
  // =========================================================================
  group('Invoice.fromJson', () {
    test('parses all fields correctly', () {
      final invoice = Invoice.fromJson(_invoiceJson());

      expect(invoice.id, 'inv-001');
      expect(invoice.invoiceNumber, 'INV-2025-0001');
      expect(invoice.patientId, 'patient-001');
      expect(invoice.billingPeriodStart.year, 2025);
      expect(invoice.billingPeriodEnd.month, 1);
      expect(invoice.lineItems.length, 2);
      expect(invoice.subtotal, 32500);
      expect(invoice.gstTotal, 5850);
      expect(invoice.grandTotal, 38350);
      expect(invoice.dueDate.month, 2);
      expect(invoice.status, 'pending');
      expect(invoice.pdfUrl, isNull);
    });

    test('parses with explicit status', () {
      final invoice = Invoice.fromJson(_invoiceJson(status: 'paid'));
      expect(invoice.status, 'paid');
    });

    test('parses with pdf url', () {
      final invoice = Invoice.fromJson(_invoiceJson(pdfUrl: 'https://example.com/inv.pdf'));
      expect(invoice.pdfUrl, 'https://example.com/inv.pdf');
    });

    test('defaults status to "pending" when absent', () {
      final json = _invoiceJson();
      json.remove('status');
      final invoice = Invoice.fromJson(json);
      expect(invoice.status, 'pending');
    });
  });

  // =========================================================================
  // InvoiceLineItem
  // =========================================================================
  group('InvoiceLineItem.fromJson', () {
    test('parses all fields', () {
      final item = InvoiceLineItem.fromJson({
        'description': 'Nurse 24 Hr',
        'amount': 1000,
        'gst': 180,
        'total': 1180,
        'type': 'manpower',
      });
      expect(item.description, 'Nurse 24 Hr');
      expect(item.amount, 1000);
      expect(item.gst, 180);
      expect(item.total, 1180);
      expect(item.type, 'manpower');
    });

    test('type is null when absent', () {
      final item = InvoiceLineItem.fromJson({
        'description': 'Misc',
        'amount': 100,
        'gst': 18,
        'total': 118,
      });
      expect(item.type, isNull);
    });
  });

  // =========================================================================
  // PaymentTransaction
  // =========================================================================
  group('PaymentTransaction.fromJson', () {
    test('parses completed payment', () {
      final tx = PaymentTransaction.fromJson(_paymentJson());

      expect(tx.id, 'pay-001');
      expect(tx.patientId, 'patient-001');
      expect(tx.invoiceId, 'inv-001');
      expect(tx.bookingId, 'bk-001');
      expect(tx.amount, 38350);
      expect(tx.currency, 'INR');
      expect(tx.method, 'upi');
      expect(tx.status, 'completed');
      expect(tx.razorpayPaymentId, 'pay_xyz123');
      expect(tx.razorpayOrderId, 'order_abc456');
      expect(tx.razorpaySignature, 'sig_def789');
      expect(tx.description, 'Payment for January invoice');
      expect(tx.createdAt.year, 2025);
    });

    test('isSuccess is true for completed', () {
      final tx = PaymentTransaction.fromJson(_paymentJson(status: 'completed'));
      expect(tx.isSuccess, isTrue);
      expect(tx.isFailed, isFalse);
      expect(tx.isRefunded, isFalse);
    });

    test('isFailed is true for failed', () {
      final tx = PaymentTransaction.fromJson(_paymentJson(status: 'failed'));
      expect(tx.isSuccess, isFalse);
      expect(tx.isFailed, isTrue);
      expect(tx.failureReason, 'Insufficient funds');
    });

    test('isRefunded is true for refunded', () {
      final tx = PaymentTransaction.fromJson(_paymentJson(status: 'refunded'));
      expect(tx.isRefunded, isTrue);
      expect(tx.refundAmount, 38350);
      expect(tx.refundId, 'rfnd_001');
    });

    test('currency defaults to INR when absent', () {
      final json = _paymentJson();
      json.remove('currency');
      final tx = PaymentTransaction.fromJson(json);
      expect(tx.currency, 'INR');
    });

    test('completedAt is null when absent', () {
      final tx = PaymentTransaction.fromJson(_paymentJson());
      expect(tx.completedAt, isNull);
    });

    test('completedAt is parsed when present', () {
      final tx = PaymentTransaction.fromJson(
          _paymentJson(completedAt: '2025-02-01T10:05:00Z'));
      expect(tx.completedAt, isNotNull);
      expect(tx.completedAt!.minute, 5);
    });

    test('nullable fields default to null when absent', () {
      final json = {
        'id': 'pay-min',
        'patient_id': 'p1',
        'amount': 100,
        'method': 'upi',
        'status': 'initiated',
        'description': 'test',
        'created_at': '2025-01-01T00:00:00Z',
      };
      final tx = PaymentTransaction.fromJson(json);
      expect(tx.invoiceId, isNull);
      expect(tx.bookingId, isNull);
      expect(tx.razorpayPaymentId, isNull);
      expect(tx.razorpayOrderId, isNull);
      expect(tx.razorpaySignature, isNull);
      expect(tx.failureReason, isNull);
      expect(tx.refundAmount, isNull);
      expect(tx.refundId, isNull);
      expect(tx.receiptUrl, isNull);
      expect(tx.completedAt, isNull);
    });
  });

  // =========================================================================
  // Coupon
  // =========================================================================
  group('Coupon.fromJson', () {
    test('parses all fields', () {
      final coupon = Coupon.fromJson(_couponJson(
        maxDiscount: 5000,
        minOrderValue: 1000,
        usageLimit: 100,
      ));

      expect(coupon.id, 'coupon-001');
      expect(coupon.code, 'SAVE20');
      expect(coupon.type, 'percentage');
      expect(coupon.value, 20);
      expect(coupon.maxDiscount, 5000);
      expect(coupon.minOrderValue, 1000);
      expect(coupon.description, 'Save 20% on first order');
      expect(coupon.applicableCategories, ['manpower', 'equipment']);
      expect(coupon.usageLimit, 100);
      expect(coupon.usedCount, 0);
      expect(coupon.isActive, isTrue);
    });

    test('defaults usedCount to 0 when absent', () {
      final json = _couponJson();
      json.remove('used_count');
      final coupon = Coupon.fromJson(json);
      expect(coupon.usedCount, 0);
    });

    test('defaults isActive to true when absent', () {
      final json = _couponJson();
      json.remove('is_active');
      final coupon = Coupon.fromJson(json);
      expect(coupon.isActive, isTrue);
    });

    test('nullable fields default to null when absent', () {
      final json = {
        'id': 'c1',
        'code': 'TEST',
        'type': 'flat',
        'value': 100,
        'valid_from': '2025-01-01T00:00:00Z',
        'valid_until': '2027-12-31T00:00:00Z',
      };
      final coupon = Coupon.fromJson(json);
      expect(coupon.maxDiscount, isNull);
      expect(coupon.minOrderValue, isNull);
      expect(coupon.description, isNull);
      expect(coupon.applicableCategories, isNull);
      expect(coupon.usageLimit, isNull);
    });
  });

  // =========================================================================
  // Coupon — calculateDiscount
  // =========================================================================
  group('Coupon.calculateDiscount', () {
    test('percentage discount without cap', () {
      final coupon = Coupon.fromJson(_couponJson(type: 'percentage', value: 10));
      // 10% of 10000 = 1000
      expect(coupon.calculateDiscount(10000), 1000);
    });

    test('percentage discount with max cap', () {
      final coupon = Coupon.fromJson(_couponJson(
        type: 'percentage',
        value: 50,
        maxDiscount: 2000,
      ));
      // 50% of 10000 = 5000, but capped at 2000
      expect(coupon.calculateDiscount(10000), 2000);
    });

    test('flat discount', () {
      final coupon = Coupon.fromJson(_couponJson(type: 'flat', value: 500));
      expect(coupon.calculateDiscount(10000), 500);
    });

    test('flat discount cannot exceed order amount', () {
      final coupon = Coupon.fromJson(_couponJson(type: 'flat', value: 5000));
      expect(coupon.calculateDiscount(3000), 3000);
    });

    test('returns 0 when below min order value', () {
      final coupon = Coupon.fromJson(_couponJson(
        type: 'percentage',
        value: 10,
        minOrderValue: 5000,
      ));
      expect(coupon.calculateDiscount(4000), 0);
    });

    test('returns 0 when coupon is inactive', () {
      final coupon = Coupon.fromJson(_couponJson(isActive: false));
      expect(coupon.calculateDiscount(10000), 0);
    });

    test('returns 0 when coupon has expired', () {
      final coupon = Coupon.fromJson(_couponJson(
        validUntil: '2020-01-01T00:00:00Z',
      ));
      expect(coupon.calculateDiscount(10000), 0);
    });

    test('returns 0 when usage limit exceeded', () {
      final coupon = Coupon.fromJson(_couponJson(
        usageLimit: 5,
        usedCount: 5,
      ));
      expect(coupon.calculateDiscount(10000), 0);
    });
  });

  // =========================================================================
  // BillingSummary
  // =========================================================================
  group('BillingSummary.fromJson', () {
    test('parses all fields', () {
      final summary = BillingSummary.fromJson(_billingSummaryJson());

      expect(summary.totalDue, 50000);
      expect(summary.totalPaid, 120000);
      expect(summary.overdueAmount, 10000);
      expect(summary.nextDueDate, isNotNull);
      expect(summary.nextDueDate!.month, 3);
      expect(summary.invoiceCount, 5);
      expect(summary.overdueCount, 1);
    });

    test('defaults numeric fields to 0 when absent', () {
      final summary = BillingSummary.fromJson({});
      expect(summary.totalDue, 0);
      expect(summary.totalPaid, 0);
      expect(summary.overdueAmount, 0);
      expect(summary.invoiceCount, 0);
      expect(summary.overdueCount, 0);
    });

    test('nextDueDate is null when absent', () {
      final summary = BillingSummary.fromJson({});
      expect(summary.nextDueDate, isNull);
    });
  });
}
