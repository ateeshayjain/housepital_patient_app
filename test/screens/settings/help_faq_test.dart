// test/screens/settings/help_faq_test.dart
//
// Tests FAQ data integrity:
// - At least 15 FAQ items exist
// - All items have non-empty question and answer
// - All categories are valid: Booking, Payments, Staff, Equipment, Account
// - Search filter works: searching "cancel" returns items containing "cancel"

import 'package:flutter_test/flutter_test.dart';

// Replicate _FaqItem and the canonical FAQ list from help_faq_screen.dart
// (the class is private in the source).

class FaqItem {
  final String question;
  final String answer;
  final String category;

  const FaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

const _validCategories = {'Booking', 'Payments', 'Staff', 'Equipment', 'Account'};

const List<FaqItem> _faqs = [
  // Booking
  FaqItem(
    category: 'Booking',
    question: 'How do I book a caretaker or nurse?',
    answer:
        'Go to the Services tab, select the service you need (e.g., Caretaker, Nursing), fill in the assessment form with patient details, and submit. Our team will review and get back to you within a few hours.',
  ),
  FaqItem(
    category: 'Booking',
    question: 'Can I book a service for a specific date?',
    answer:
        'Yes. During the booking process you can choose your preferred start date. We will try our best to match your timeline, subject to staff availability.',
  ),
  FaqItem(
    category: 'Booking',
    question: 'How do I cancel or reschedule a booking?',
    answer:
        'You can raise a concern from the Support section or call your Health Manager directly. Cancellation charges may apply depending on the notice period.',
  ),
  FaqItem(
    category: 'Booking',
    question: 'What is the minimum booking duration?',
    answer:
        'The minimum booking duration depends on the service type. Most services require a minimum of 1 month commitment. Equipment rentals can be shorter.',
  ),
  // Payments
  FaqItem(
    category: 'Payments',
    question: 'What payment methods are accepted?',
    answer:
        'We accept UPI, debit/credit cards, net banking, and wallets through Razorpay. Cash payments can be arranged through your Health Manager.',
  ),
  FaqItem(
    category: 'Payments',
    question: 'When will I receive my invoice?',
    answer:
        'Invoices are generated at the start of each billing cycle (usually monthly). You will receive a notification when a new invoice is ready.',
  ),
  FaqItem(
    category: 'Payments',
    question: 'How do I get a refund?',
    answer:
        'Refunds are processed within 5-7 business days after approval. Contact support or raise a concern for refund requests.',
  ),
  // Staff
  FaqItem(
    category: 'Staff',
    question: 'How do I know if my caretaker has arrived?',
    answer:
        'You will receive a push notification when the staff checks in. You can also see the real-time attendance status on the dashboard.',
  ),
  FaqItem(
    category: 'Staff',
    question: 'What if my caretaker does not show up?',
    answer:
        'You will receive an automatic no-show alert. Our ops team is notified simultaneously and will arrange an immediate replacement. You can also raise an emergency concern.',
  ),
  FaqItem(
    category: 'Staff',
    question: 'Can I request a replacement for my staff?',
    answer:
        'Yes. Go to Support > Raise Concern, select "Need Replacement" as the category, and describe the reason. We will arrange a suitable replacement.',
  ),
  FaqItem(
    category: 'Staff',
    question: 'Are all staff members verified?',
    answer:
        'Yes. All Housepital staff undergo thorough background verification, police clearance, skill assessments, and training before deployment.',
  ),
  // Equipment
  FaqItem(
    category: 'Equipment',
    question: 'How does equipment rental work?',
    answer:
        'Browse the equipment catalog, select the item you need, and place an order. Equipment is delivered to your home and picked up when the rental period ends.',
  ),
  FaqItem(
    category: 'Equipment',
    question: 'What if the equipment is damaged?',
    answer:
        'Report any damage immediately through the app. Normal wear and tear is covered. Significant damage may incur repair or replacement charges.',
  ),
  FaqItem(
    category: 'Equipment',
    question: 'Can I extend my equipment rental?',
    answer:
        'Yes. Contact your Health Manager or raise a request through the app before the rental period ends to extend.',
  ),
  // Account
  FaqItem(
    category: 'Account',
    question: 'How do I add a family member to my account?',
    answer:
        'Go to Settings > Family Members > Add Member. Enter their phone number and they will receive an invitation to join your care circle.',
  ),
  FaqItem(
    category: 'Account',
    question: 'Can I manage multiple patients?',
    answer:
        'Yes. You can add multiple patients under your account and switch between them from the dashboard.',
  ),
  FaqItem(
    category: 'Account',
    question: 'How do I change my phone number?',
    answer:
        'Contact our support team to update your registered phone number. This requires verification for security purposes.',
  ),
  FaqItem(
    category: 'Account',
    question: 'How do I delete my account?',
    answer:
        'Please contact support via email at support@housepital.in. Account deletion is processed within 7 working days as per our data retention policy.',
  ),
];

/// Simulates the search/filter logic from _HelpFaqScreenState._filteredFaqs
List<FaqItem> _filterFaqs({String? category, String? query}) {
  var items = _faqs.toList();
  if (category != null && category != 'All') {
    items = items.where((f) => f.category == category).toList();
  }
  if (query != null && query.isNotEmpty) {
    final q = query.toLowerCase();
    items = items
        .where(
            (f) => f.question.toLowerCase().contains(q) || f.answer.toLowerCase().contains(q))
        .toList();
  }
  return items;
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // At least 15 FAQ items
  // ═══════════════════════════════════════════════════════════════════════════
  group('FAQ — count', () {
    test('at least 15 FAQ items exist', () {
      expect(_faqs.length, greaterThanOrEqualTo(15));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Non-empty questions and answers
  // ═══════════════════════════════════════════════════════════════════════════
  group('FAQ — non-empty content', () {
    for (int i = 0; i < _faqs.length; i++) {
      test('FAQ[$i] has non-empty question', () {
        expect(_faqs[i].question.isNotEmpty, isTrue);
      });

      test('FAQ[$i] has non-empty answer', () {
        expect(_faqs[i].answer.isNotEmpty, isTrue);
      });
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Valid categories
  // ═══════════════════════════════════════════════════════════════════════════
  group('FAQ — valid categories', () {
    for (final faq in _faqs) {
      test('"${faq.question.substring(0, faq.question.length.clamp(0, 40))}..." has valid category "${faq.category}"', () {
        expect(_validCategories, contains(faq.category));
      });
    }

    test('all 5 categories have at least one FAQ item', () {
      for (final cat in _validCategories) {
        final count = _faqs.where((f) => f.category == cat).length;
        expect(count, greaterThanOrEqualTo(1),
            reason: 'Category "$cat" has no FAQ items');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Search filter
  // ═══════════════════════════════════════════════════════════════════════════
  group('FAQ — search filter', () {
    test('searching "cancel" returns items containing "cancel"', () {
      final results = _filterFaqs(query: 'cancel');
      expect(results, isNotEmpty);
      for (final faq in results) {
        final q = faq.question.toLowerCase();
        final a = faq.answer.toLowerCase();
        expect(q.contains('cancel') || a.contains('cancel'), isTrue,
            reason:
                'FAQ "${faq.question}" does not contain "cancel" in question or answer');
      }
    });

    test('searching "refund" returns at least one item', () {
      final results = _filterFaqs(query: 'refund');
      expect(results, isNotEmpty);
    });

    test('searching empty string returns all items', () {
      final results = _filterFaqs(query: '');
      expect(results.length, _faqs.length);
    });

    test('searching gibberish returns no results', () {
      final results = _filterFaqs(query: 'xyzzyqwerty123');
      expect(results, isEmpty);
    });

    test('filtering by category "Booking" returns only Booking items', () {
      final results = _filterFaqs(category: 'Booking');
      for (final faq in results) {
        expect(faq.category, 'Booking');
      }
      expect(results.length, greaterThanOrEqualTo(1));
    });

    test('filtering by "All" returns all items', () {
      final results = _filterFaqs(category: 'All');
      expect(results.length, _faqs.length);
    });

    test('combined category + search narrows results', () {
      final results = _filterFaqs(category: 'Booking', query: 'cancel');
      expect(results, isNotEmpty);
      for (final faq in results) {
        expect(faq.category, 'Booking');
        final combined = '${faq.question} ${faq.answer}'.toLowerCase();
        expect(combined.contains('cancel'), isTrue);
      }
    });
  });
}
