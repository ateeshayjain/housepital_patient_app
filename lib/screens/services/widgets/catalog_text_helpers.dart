// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// Splits catalog text by `|` or newline — catalog uses both formats.
List<String> splitCatalogText(String text) {
  // Try pipe delimiter first (most catalog data uses this)
  if (text.contains('|')) {
    return text.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  // Try newline delimiter
  if (text.contains('\n')) {
    return text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  // Fallback: split on sentence boundaries (". " followed by uppercase)
  // This turns paragraphs into individual steps
  final sentences = <String>[];
  final regex = RegExp(r'(?<=\.)\s+(?=[A-Z])');
  for (final s in text.split(regex)) {
    final trimmed = s.trim();
    if (trimmed.isNotEmpty) {
      // Remove trailing period for cleaner display
      sentences.add(trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed);
    }
  }
  return sentences.length > 1 ? sentences : [text];
}

/// Parses FAQ text into Q/A pairs.
/// Handles formats: "Q: ... | A: ... | Q: ..." or "Q: ... A: ... Q: ..."
List<Widget> buildFaqItems(BuildContext context, String faqs) {
  // Extract Q/A pairs using a regex that finds "Q:" followed by "A:" patterns
  // Handles: "Q: q1? A: a1. | Q: q2? A: a2." and "Q: q1? A: a1. Q: q2? A: a2."
  final pairs = <Map<String, String>>[];

  // Find all Q: ... A: ... pairs using regex
  final qaRegex = RegExp(
    r'Q[:.]\s*(.*?)\s*A[:.]\s*(.*?)(?=\s*\|?\s*Q[:.]\s|$)',
    dotAll: true,
  );

  for (final match in qaRegex.allMatches(faqs)) {
    final question = match.group(1)?.trim() ?? '';
    final answer = match.group(2)?.trim() ?? '';
    if (question.isNotEmpty && answer.isNotEmpty) {
      // Clean trailing pipe or period from answer
      final cleanAnswer = answer.endsWith('|')
          ? answer.substring(0, answer.length - 1).trim()
          : answer;
      pairs.add({'q': question, 'a': cleanAnswer});
    }
  }

  if (pairs.isEmpty) {
    return [Text(faqs, style: TextStyle(fontSize: 13, color: context.hc.grey, height: 1.4))];
  }

  return pairs.asMap().entries.map((entry) {
    final idx = entry.key + 1;
    final q = entry.value['q']!;
    final a = entry.value['a']!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22, height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: context.hc.orangeLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(child: Text('$idx',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.hc.orangeText))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(q, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.hc.black, height: 1.4))),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(a, style: TextStyle(fontSize: 12, color: context.hc.greyLight, height: 1.5)),
          ),
        ],
      ),
    );
  }).toList();
}
