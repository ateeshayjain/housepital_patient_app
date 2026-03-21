import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/payment_reminder_service.dart';
import '../../utils/helpers.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<SavedPaymentMethod> _methods = [];
  bool _autoPayEnabled = false;

  @override
  void initState() {
    super.initState();
    _methods = PaymentReminderService.getSavedMethods();
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
                borderRadius: BorderRadius.circular(14),
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
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey.shade200,
                      style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.credit_card_off,
                        size: 40, color: Colors.grey.shade300),
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: HousepitalColors.orange,
                  side: const BorderSide(color: HousepitalColors.orange),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _showAddUpiDialog(context),
                icon: const Icon(Icons.account_balance, size: 20),
                label: const Text('Add UPI ID'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HousepitalColors.orange,
                  side: const BorderSide(color: HousepitalColors.orange),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Upcoming auto-pay schedule
            const Text('Upcoming Auto-pay Schedule',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...PaymentReminderService.getUpcomingReminders()
                .map((r) => _buildScheduleRow(r)),

            const SizedBox(height: 24),

            // RBI compliance note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HousepitalColors.infoLight,
                borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(6),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: method.isDefault
              ? HousepitalColors.orange
              : Colors.grey.shade200,
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
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Auto-pay ON',
                  style: TextStyle(
                      fontSize: 10,
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
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

  void _showAddCardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Card'),
        content: const Text(
            'Card details will be securely tokenized via Razorpay. You\'ll need to complete a one-time verification of ₹1 (refunded immediately) to enable auto-pay as per RBI e-mandate guidelines.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _methods.add(SavedPaymentMethod(
                  id: 'pm_1',
                  type: 'card',
                  displayName: 'HDFC •••• 4521',
                  cardNetwork: 'visa',
                  isDefault: true,
                  autoPayEnabled: true,
                ));
                _autoPayEnabled = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Card added and auto-pay enabled. You\'ll be notified 2 days before each debit.'),
                  backgroundColor: HousepitalColors.success,
                ),
              );
            },
            child: const Text('Add Card'),
          ),
        ],
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
                _autoPayEnabled = true;
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
