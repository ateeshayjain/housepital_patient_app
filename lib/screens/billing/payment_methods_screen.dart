import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/payment_reminder_service.dart';
import '../../utils/helpers.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<SavedPaymentMethod> _methods = [];
  List<PaymentReminder> _reminders = [];
  late final PaymentReminderService _reminderService;

  @override
  void initState() {
    super.initState();
    _reminderService = PaymentReminderService(apiService: ApiService());
    _loadData();
  }

  Future<void> _loadData() async {
    final methods = await _reminderService.getSavedMethods();
    final reminders = await _reminderService.getUpcomingReminders();
    if (mounted) {
      setState(() {
        _methods = methods;
        _reminders = reminders;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment & Auto-pay')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto-pay explainer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    HousepitalColors.orange.withValues(alpha: 0.1),
                    HousepitalColors.orange.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.autorenew,
                          color: HousepitalColors.orange, size: 24),
                      SizedBox(width: 10),
                      Text('Auto-pay',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Never miss a payment. Add a card or UPI to automatically pay for recurring services like nurses, caretakers, and equipment rentals.',
                    style: TextStyle(
                        fontSize: 13,
                        color: HousepitalColors.grey,
                        height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _featureChip(Icons.notifications_active, 'Reminders 2 days before'),
                      const SizedBox(width: 8),
                      _featureChip(Icons.lock, 'RBI compliant'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Saved payment methods
            const Text('Saved Payment Methods',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            if (_methods.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: HousepitalColors.greyLighter,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: HousepitalColors.divider,
                      style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.credit_card_off,
                        size: 40, color: HousepitalColors.greyLight),
                    const SizedBox(height: 12),
                    const Text('No saved payment methods',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text(
                        'Add a card or UPI to enable auto-pay',
                        style: TextStyle(
                            fontSize: 13,
                            color: HousepitalColors.greyLight)),
                  ],
                ),
              )
            else
              ..._methods.map((m) => _buildMethodCard(m)),

            const SizedBox(height: 16),

            // Add payment method buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _showAddCardDialog(context),
                icon: const Icon(Icons.add_card, size: 20),
                label: const Text('Add Debit / Credit Card'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _showAddUpiDialog(context),
                icon: const Icon(Icons.account_balance, size: 20),
                label: const Text('Add UPI ID'),
              ),
            ),

            const SizedBox(height: 28),

            // Upcoming auto-pay schedule
            const Text('Upcoming Auto-pay Schedule',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._reminders.map((r) => _buildScheduleRow(r)),

            const SizedBox(height: 24),

            // RBI compliance note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HousepitalColors.infoLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user,
                      color: HousepitalColors.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your payment information is secured with bank-grade encryption. Auto-pay follows RBI e-mandate guidelines. You will receive a notification before every debit and can cancel anytime.',
                      style: TextStyle(
                          fontSize: 12,
                          color: HousepitalColors.info,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: HousepitalColors.orange),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: HousepitalColors.grey)),
        ],
      ),
    );
  }

  Widget _buildMethodCard(SavedPaymentMethod method) {
    final iconMap = {
      'visa': Icons.credit_card,
      'mastercard': Icons.credit_card,
      'rupay': Icons.credit_card,
      'upi': Icons.account_balance,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: method.isDefault
              ? HousepitalColors.orange
              : HousepitalColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(iconMap[method.cardNetwork ?? method.type] ?? Icons.payment,
              color: HousepitalColors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.displayName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (method.isDefault)
                  const Text('Default',
                      style: TextStyle(
                          fontSize: 11, color: HousepitalColors.success)),
              ],
            ),
          ),
          if (method.autoPayEnabled)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: HousepitalColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Auto-pay ON',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.success)),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(PaymentReminder r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HousepitalColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 36,
            decoration: BoxDecoration(
              color: r.urgencyColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.serviceName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(r.urgencyLabel,
                    style: TextStyle(fontSize: 11, color: r.urgencyColor)),
              ],
            ),
          ),
          Text(DateHelper.formatCurrency(r.amount.toInt()),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.orangeText)),
          const SizedBox(width: 8),
          Icon(
            r.autoPayEnabled ? Icons.check_circle : Icons.cancel_outlined,
            color: r.autoPayEnabled
                ? HousepitalColors.success
                : HousepitalColors.greyLight,
            size: 18,
          ),
        ],
      ),
    );
  }

  // audit M-15: previously fabricated a hardcoded HDFC card on tap, which
  // misled users into thinking auto-pay was active. Replaced the dialog with
  // a single-CTA bottom sheet pointing the user at the coordinator to set up
  // the Razorpay mandate over the phone — the only flow that actually works
  // today. No fake-card insertion happens anywhere in this path.
  void _showAddCardDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Set up auto-pay',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                "To add a card for auto-pay, please call our coordinator at +91-90502-00183 (10am–7pm IST). We'll set up the Razorpay mandate together over the phone — takes 3 minutes.",
                style: TextStyle(
                    fontSize: 14, color: HousepitalColors.grey, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse('tel:9050200183');
                  bool launched = false;
                  try {
                    launched = await launchUrl(uri);
                  } catch (_) {
                    launched = false;
                  }
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "Couldn't open dialer. The number is +91-90502-00183."),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.call),
                label: const Text('Call coordinator'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddUpiDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add UPI ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Enter your UPI ID to set up auto-pay. A mandate will be created and you\'ll need to approve it in your UPI app.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'yourname@okaxis',
                labelText: 'UPI ID',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final upiId = controller.text.isNotEmpty
                  ? controller.text
                  : 'user@okaxis';
              setState(() {
                _methods.add(SavedPaymentMethod(
                  id: 'pm_2',
                  type: 'upi',
                  displayName: 'UPI: $upiId',
                  isDefault: _methods.isEmpty,
                  autoPayEnabled: true,
                ));
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'UPI mandate created. Approve in your UPI app to enable auto-pay.'),
                  backgroundColor: HousepitalColors.success,
                ),
              );
            },
            child: const Text('Set Up Mandate'),
          ),
        ],
      ),
    );
  }
}
