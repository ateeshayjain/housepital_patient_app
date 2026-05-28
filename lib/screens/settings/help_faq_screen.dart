import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';

class _FaqItem {
  final String question;
  final String answer;
  final String category;

  const _FaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

class HelpFaqScreen extends StatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  State<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends State<HelpFaqScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const _categories = [
    'All',
    'Booking',
    'Payments',
    'Staff',
    'Equipment',
    'Account',
  ];

  static const List<_FaqItem> _faqs = [
    // Booking
    _FaqItem(
      category: 'Booking',
      question: 'How do I book a caretaker or nurse?',
      answer:
          'Go to the Services tab, select the service you need (e.g., Caretaker, Nursing), fill in the assessment form with patient details, and submit. Our team will review and get back to you within a few hours.',
    ),
    _FaqItem(
      category: 'Booking',
      question: 'Can I book a service for a specific date?',
      answer:
          'Yes. During the booking process you can choose your preferred start date. We will try our best to match your timeline, subject to staff availability.',
    ),
    _FaqItem(
      category: 'Booking',
      question: 'How do I cancel or reschedule a booking?',
      answer:
          'You can raise a concern from the Support section or call your Health Manager directly. Cancellation charges may apply depending on the notice period.',
    ),
    _FaqItem(
      category: 'Booking',
      question: 'What is the minimum booking duration?',
      answer:
          'The minimum booking duration depends on the service type. Most services require a minimum of 1 month commitment. Equipment rentals can be shorter.',
    ),

    // Payments
    _FaqItem(
      category: 'Payments',
      question: 'What payment methods are accepted?',
      answer:
          'We accept UPI, debit/credit cards, net banking, and wallets through Razorpay. Cash payments can be arranged through your Health Manager.',
    ),
    _FaqItem(
      category: 'Payments',
      question: 'When will I receive my invoice?',
      answer:
          'Invoices are generated at the start of each billing cycle (usually monthly). You will receive a notification when a new invoice is ready.',
    ),
    _FaqItem(
      category: 'Payments',
      question: 'How do I get a refund?',
      answer:
          'Refunds are processed within 5-7 business days after approval. Contact support or raise a concern for refund requests.',
    ),

    // Staff
    _FaqItem(
      category: 'Staff',
      question: 'How do I know if my caretaker has arrived?',
      answer:
          'You will receive a push notification when the staff checks in. You can also see the real-time attendance status on the dashboard.',
    ),
    _FaqItem(
      category: 'Staff',
      question: 'What if my caretaker does not show up?',
      answer:
          'You will receive an automatic no-show alert. Our ops team is notified simultaneously and will arrange an immediate replacement. You can also raise an emergency concern.',
    ),
    _FaqItem(
      category: 'Staff',
      question: 'Can I request a replacement for my staff?',
      answer:
          'Yes. Go to Support > Raise Concern, select "Need Replacement" as the category, and describe the reason. We will arrange a suitable replacement.',
    ),
    _FaqItem(
      category: 'Staff',
      question: 'Are all staff members verified?',
      answer:
          'Yes. All Housepital staff undergo thorough background verification, police clearance, skill assessments, and training before deployment.',
    ),

    // Equipment
    _FaqItem(
      category: 'Equipment',
      question: 'How does equipment rental work?',
      answer:
          'Browse the equipment catalog, select the item you need, and place an order. Equipment is delivered to your home and picked up when the rental period ends.',
    ),
    _FaqItem(
      category: 'Equipment',
      question: 'What if the equipment is damaged?',
      answer:
          'Report any damage immediately through the app. Normal wear and tear is covered. Significant damage may incur repair or replacement charges.',
    ),
    _FaqItem(
      category: 'Equipment',
      question: 'Can I extend my equipment rental?',
      answer:
          'Yes. Contact your Health Manager or raise a request through the app before the rental period ends to extend.',
    ),

    // Account
    _FaqItem(
      category: 'Account',
      question: 'How do I add a family member to my account?',
      answer:
          'Go to Settings > Family Members > Add Member. Enter their phone number and they will receive an invitation to join your care circle.',
    ),
    _FaqItem(
      category: 'Account',
      question: 'Can I manage multiple patients?',
      answer:
          'Yes. You can add multiple patients under your account and switch between them from the dashboard.',
    ),
    _FaqItem(
      category: 'Account',
      question: 'How do I change my phone number?',
      answer:
          'Contact our support team to update your registered phone number. This requires verification for security purposes.',
    ),
    _FaqItem(
      category: 'Account',
      question: 'How do I delete my account?',
      answer:
          'Please contact support via email at wecare@housepital.in. Account deletion is processed within 7 working days as per our data retention policy.',
    ),
  ];

  List<_FaqItem> get _filteredFaqs {
    var items = _faqs;
    if (_selectedCategory != 'All') {
      items = items.where((f) => f.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((f) =>
              f.question.toLowerCase().contains(q) ||
              f.answer.toLowerCase().contains(q))
          .toList();
    }
    return items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFaqs;

    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search questions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: HousepitalColors.divider),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Category chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final cat = _categories[index];
                final selected = cat == _selectedCategory;
                return FilterChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : HousepitalColors.grey,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: selected,
                  selectedColor: HousepitalColors.orange,
                  backgroundColor: HousepitalColors.greyLighter,
                  checkmarkColor: Colors.white,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // FAQ list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: HousepitalColors.greyLight),
                        const SizedBox(height: 12),
                        const Text('No matching questions found',
                            style: TextStyle(
                                color: HousepitalColors.greyLight)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length + 1, // +1 for contact section
                    itemBuilder: (_, index) {
                      if (index == filtered.length) {
                        return _buildContactSection();
                      }
                      final faq = filtered[index];
                      return _buildFaqTile(faq);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(_FaqItem faq) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: HousepitalColors.divider),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: const Border(),
        title: Text(
          faq.question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: HousepitalColors.orangeLight,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            faq.category,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HousepitalColors.orange),
          ),
        ),
        children: [
          Text(
            faq.answer,
            style: const TextStyle(
                fontSize: 13,
                color: HousepitalColors.grey,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Still need help?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Contact our support team',
            style:
                TextStyle(fontSize: 13, color: HousepitalColors.greyLight),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _contactButton(
                icon: Icons.phone,
                label: 'Call',
                color: HousepitalColors.success,
                onTap: () => _launchUrl('tel:+919999999999'),
              ),
              _contactButton(
                icon: Icons.email,
                label: 'Email',
                color: Colors.blue,
                onTap: () => _launchUrl('mailto:wecare@housepital.in'),
              ),
              _contactButton(
                icon: Icons.chat,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => _launchUrl(
                    'https://wa.me/919999999999?text=Hi,%20I%20need%20help%20with%20Housepital%20app'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _contactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }
}
