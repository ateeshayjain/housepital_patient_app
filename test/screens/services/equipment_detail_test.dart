// test/screens/services/equipment_detail_test.dart
//
// Tests the _splitCatalogText and FAQ parsing logic from
// equipment_detail_screen.dart.
// Since these are private methods, we replicate the logic here and verify it.

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Replicated helpers — must match equipment_detail_screen.dart logic exactly.
// ---------------------------------------------------------------------------

/// Splits catalog text by `|` or newline — catalog uses both formats.
List<String> splitCatalogText(String text) {
  final sep = text.contains('|') ? '|' : '\n';
  return text
      .split(sep)
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// Represents a FAQ entry with question and answer.
class FaqEntry {
  final String question;
  final String answer;
  const FaqEntry({required this.question, required this.answer});
}

/// Parses FAQ text into a list of FaqEntry objects.
/// FAQs may use | or \n as separator between entries.
List<FaqEntry> parseFaqs(String text) {
  if (text.isEmpty) return [];
  final sep = text.contains('|') ? '|' : '\n';
  final parts = text.split(sep).map((e) => e.trim()).where((e) => e.isNotEmpty);
  final faqs = <FaqEntry>[];
  String? currentQ;
  for (final part in parts) {
    if (part.startsWith('Q:') || part.startsWith('Q.')) {
      currentQ = part.substring(2).trim();
    } else if ((part.startsWith('A:') || part.startsWith('A.')) &&
        currentQ != null) {
      faqs.add(FaqEntry(question: currentQ, answer: part.substring(2).trim()));
      currentQ = null;
    }
  }
  return faqs;
}

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // splitCatalogText
  // =========================================================================
  group('splitCatalogText', () {
    test('handles pipe delimiters', () {
      expect(splitCatalogText('a|b|c'), ['a', 'b', 'c']);
    });

    test('handles newline delimiters', () {
      expect(splitCatalogText('a\nb\nc'), ['a', 'b', 'c']);
    });

    test('trims whitespace around entries', () {
      expect(splitCatalogText(' a | b | c '), ['a', 'b', 'c']);
    });

    test('trims whitespace with newline delimiters', () {
      expect(splitCatalogText(' a \n b \n c '), ['a', 'b', 'c']);
    });

    test('filters empty entries from pipe-delimited text', () {
      expect(splitCatalogText('a||b|||c'), ['a', 'b', 'c']);
    });

    test('filters empty entries from newline-delimited text', () {
      expect(splitCatalogText('a\n\nb\n\n\nc'), ['a', 'b', 'c']);
    });

    test('returns single-element list for text without delimiters', () {
      expect(splitCatalogText('single item'), ['single item']);
    });

    test('returns empty list for whitespace-only input', () {
      expect(splitCatalogText('  \n  \n  '), isEmpty);
    });

    test('pipe takes priority over newline when both present', () {
      // If text contains |, it splits by | regardless of newlines
      final result = splitCatalogText('a|b\nc');
      expect(result, ['a', 'b\nc']);
    });

    test('handles real-world catalog feature text', () {
      const features = 'Motorised height adjustment|Anti-bedsore mattress|Side rails|IV pole attachment';
      final result = splitCatalogText(features);
      expect(result.length, 4);
      expect(result.first, 'Motorised height adjustment');
      expect(result.last, 'IV pole attachment');
    });
  });

  // =========================================================================
  // FAQ parser
  // =========================================================================
  group('FAQ parser', () {
    test('parses pipe-delimited Q: ... A: ... format', () {
      const text = 'Q: What is included? | A: Bed, mattress, side rails | Q: How long is delivery? | A: Within 24 hours';
      final faqs = parseFaqs(text);
      expect(faqs.length, 2);
      expect(faqs[0].question, 'What is included?');
      expect(faqs[0].answer, 'Bed, mattress, side rails');
      expect(faqs[1].question, 'How long is delivery?');
      expect(faqs[1].answer, 'Within 24 hours');
    });

    test('parses newline-delimited Q: ... A: ... format (no pipe)', () {
      const text = 'Q: What is included?\nA: Bed, mattress, side rails\nQ: How long is delivery?\nA: Within 24 hours';
      final faqs = parseFaqs(text);
      expect(faqs.length, 2);
      expect(faqs[0].question, 'What is included?');
      expect(faqs[0].answer, 'Bed, mattress, side rails');
      expect(faqs[1].question, 'How long is delivery?');
      expect(faqs[1].answer, 'Within 24 hours');
    });

    test('handles Q. and A. prefixes (dot variant)', () {
      const text = 'Q. Can I buy it?\nA. Yes, purchase option available\nQ. Is delivery free?\nA. Yes for Delhi NCR';
      final faqs = parseFaqs(text);
      expect(faqs.length, 2);
      expect(faqs[0].question, 'Can I buy it?');
      expect(faqs[0].answer, 'Yes, purchase option available');
    });

    test('trims whitespace from questions and answers', () {
      const text = 'Q:   Spacious question?  | A:   Spacious answer.  ';
      final faqs = parseFaqs(text);
      expect(faqs.length, 1);
      expect(faqs[0].question, 'Spacious question?');
      expect(faqs[0].answer, 'Spacious answer.');
    });

    test('returns empty list for empty input', () {
      expect(parseFaqs(''), isEmpty);
    });

    test('skips orphaned questions without matching answers', () {
      const text = 'Q: Question without answer\nQ: Another question\nA: Answer for second';
      final faqs = parseFaqs(text);
      // The first Q is replaced by the second Q before an A is found
      expect(faqs.length, 1);
      expect(faqs[0].question, 'Another question');
      expect(faqs[0].answer, 'Answer for second');
    });

    test('skips orphaned answers without preceding questions', () {
      const text = 'A: Answer without question\nQ: Real question\nA: Real answer';
      final faqs = parseFaqs(text);
      expect(faqs.length, 1);
      expect(faqs[0].question, 'Real question');
      expect(faqs[0].answer, 'Real answer');
    });
  });
}
