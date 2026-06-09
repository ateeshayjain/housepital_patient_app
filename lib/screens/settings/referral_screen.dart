import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';

class ReferralScreen extends StatelessWidget {
  final String? userId;

  const ReferralScreen({super.key, this.userId});

  String get _referralCode {
    final id = userId ?? 'USER';
    final suffix = id.hashCode.abs().toString().padLeft(5, '0').substring(0, 5);
    return 'HOUSE-$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refer & Earn')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Hero illustration
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.hc.orangeLight, Color(0xFFFFE0B2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: context.hc.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: HousepitalColors.orange.withValues(alpha: 0.2),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.card_giftcard, size: 40, color: HousepitalColors.orange),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Refer a friend & earn',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your code and earn \u20B9500 when they complete their first booking!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: context.hc.grey, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Referral code card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.hc.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HousepitalColors.orange, width: 2),
              ),
              child: Column(
                children: [
                  Text('Your Referral Code',
                      style: TextStyle(fontSize: 13, color: context.hc.greyLight)),
                  const SizedBox(height: 8),
                  Text(
                    _referralCode,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: context.hc.orangeText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _referralCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Referral code copied!')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Code'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: HousepitalColors.orange,
                            side: const BorderSide(color: HousepitalColors.orange),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            SharePlus.instance.share(ShareParams(
                              text: 'Get hospital-like care at home with Housepital! '
                                  'Use my referral code $_referralCode to get started. '
                                  'Download now: https://housepital.in/app',
                            ));
                          },
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HousepitalColors.orange,
                            foregroundColor: context.hc.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Referral stats
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Your Referrals', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
              )),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard(context, 'Total\nReferred', '0', Icons.people_outline, context.hc.info),
                const SizedBox(width: 12),
                _statCard(context, 'Successful', '0', Icons.check_circle_outline, context.hc.success),
                const SizedBox(width: 12),
                _statCard(context, 'Earnings', '\u20B90', Icons.account_balance_wallet_outlined, HousepitalColors.orange),
              ],
            ),
            const SizedBox(height: 24),

            // How it works
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('How it Works', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
              )),
            ),
            const SizedBox(height: 12),
            _howItWorksStep(context, '1', 'Share your referral code with friends and family'),
            _howItWorksStep(context, '2', 'They sign up and enter your code during their first booking'),
            _howItWorksStep(context, '3', 'You earn \u20B9500 once they complete their first booking'),
          ],
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: color,
            )),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(
              fontSize: 11, color: context.hc.greyLight,
            )),
          ],
        ),
      ),
    );
  }

  Widget _howItWorksStep(BuildContext context, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.hc.orangeLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(number, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: HousepitalColors.orange,
              )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(
              fontSize: 14, color: context.hc.grey, height: 1.4,
            )),
          ),
        ],
      ),
    );
  }
}
