import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../utils/app_localizations.dart';

class SOSScreen extends StatelessWidget {
  const SOSScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: HousepitalColors.sos,
      appBar: AppBar(
        backgroundColor: HousepitalColors.sos,
        foregroundColor: Colors.white,
        title: Text(l.t('sos_title')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emergency, color: Colors.white, size: 72),
              const SizedBox(height: 24),
              Text(
                l.t('sos_title'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),

              // Medical Emergency
              _sosOption(
                context,
                icon: Icons.local_hospital,
                title: l.t('sos_medical'),
                subtitle: 'Call ${AppConstants.emergencyPhone}',
                onTap: () => _makeCall(context, AppConstants.emergencyPhone),
              ),
              const SizedBox(height: 16),

              // Staff Emergency
              _sosOption(
                context,
                icon: Icons.person_off,
                title: l.t('sos_staff'),
                subtitle: 'Alert Housepital Ops',
                onTap: () => _makeCall(context, AppConstants.supportPhone),
              ),
              const SizedBox(height: 16),

              // 112
              _sosOption(
                context,
                icon: Icons.call,
                title: l.t('sos_112'),
                subtitle: 'National Emergency Number',
                onTap: () =>
                    _makeCall(context, AppConstants.emergencyNumber112),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sosOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: HousepitalColors.sos,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: HousepitalColors.sos.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCall(BuildContext context, String number) async {
    final uri = Uri.parse('tel:$number');
    bool dialerOpened = false;
    try {
      if (await canLaunchUrl(uri)) {
        dialerOpened = await launchUrl(uri);
      }
    } catch (_) {
      dialerOpened = false;
    }

    if (dialerOpened) return;
    if (!context.mounted) return;

    // Dialer unavailable — emergency screen must NOT silently fail.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Could not auto-dial'),
        content: Text(
          'Your device could not open the phone dialer.\n\n'
          'Please dial $number manually.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: number));
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('$number copied to clipboard')),
              );
            },
            child: const Text('Copy Number'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
