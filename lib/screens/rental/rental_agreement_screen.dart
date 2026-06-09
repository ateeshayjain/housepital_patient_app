import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class RentalAgreementScreen extends StatefulWidget {
  final String itemName;
  final int monthlyRate;
  final int durationMonths;

  const RentalAgreementScreen({
    super.key,
    required this.itemName,
    required this.monthlyRate,
    this.durationMonths = 1,
  });

  @override
  State<RentalAgreementScreen> createState() => _RentalAgreementScreenState();
}

class _RentalAgreementScreenState extends State<RentalAgreementScreen> {
  bool _agreed = false;

  int get _deposit => widget.monthlyRate;
  int get _firstPayment => widget.monthlyRate + _deposit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rental Agreement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rental Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.hc.orangeLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rental Summary',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _summaryRow('Item', widget.itemName),
                  _summaryRow('Monthly Rate', DateHelper.formatCurrency(widget.monthlyRate)),
                  _summaryRow('Duration', '${widget.durationMonths} month(s)'),
                  _summaryRow('Security Deposit', DateHelper.formatCurrency(_deposit)),
                  const Divider(height: 20),
                  _summaryRow(
                    'First Payment',
                    DateHelper.formatCurrency(_firstPayment),
                    isBold: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(Deposit + 1st month rent)',
                    style: TextStyle(fontSize: 11, color: context.hc.greyLight),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Terms & Conditions
            const Text('Terms & Conditions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _termItem(Icons.calendar_month, 'Monthly Billing',
                'Rent is billed monthly in advance. Payment is due on the 1st of each month.'),
            _termItem(Icons.shield_outlined, 'Security Deposit',
                'A refundable deposit equal to 1 month\'s rent is collected upfront. Refunded within 7 business days after return.'),
            _termItem(Icons.build_outlined, 'Damage Policy',
                'Normal wear and tear is expected. Damage beyond normal use will be deducted from the security deposit.'),
            _termItem(Icons.replay, 'Return Policy',
                'Equipment can be returned at any time with 3 days\' notice. Partial month rent is not refundable.'),
            _termItem(Icons.local_shipping_outlined, 'Delivery & Setup',
                'Free delivery and setup within 24 hours. Free pickup on return.'),
            _termItem(Icons.support_agent, 'Maintenance',
                'Free maintenance and replacement during the rental period for manufacturing defects.'),

            const SizedBox(height: 20),

            // Agreement checkbox
            CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              title: const Text(
                'I agree to the rental terms and conditions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              activeColor: HousepitalColors.orange,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),

            // Add to Cart
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _agreed ? () => Navigator.pop(context, true) : null,
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Confirm & Add to Cart',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: context.hc.greyLighter,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 14,
            color: isBold ? context.hc.black : context.hc.grey,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          )),
          Text(value, style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: isBold ? context.hc.orangeText : context.hc.black,
          )),
        ],
      ),
    );
  }

  Widget _termItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconTile(
            icon: icon,
            color: HousepitalColors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: context.hc.black,
                )),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(
                  fontSize: 13, color: context.hc.grey, height: 1.4,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
