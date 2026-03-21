import 'package:flutter/material.dart';
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
                onTap: () => _makeCall(AppConstants.emergencyPhone),
              ),
              const SizedBox(height: 16),

              // Staff Emergency
              _sosOption(
                context,
                icon: Icons.person_off,
                title: l.t('sos_staff'),
                subtitle: 'Alert Housepital Ops',
                onTap: () => _makeCall(AppConstants.supportPhone),
              ),
              const SizedBox(height: 16),

              // 112
              _sosOption(
                context,
                icon: Icons.call,
                title: l.t('sos_112'),
                subtitle: 'National Emergency Number',
                onTap: () => _makeCall(AppConstants.emergencyNumber112),
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
          padding: const EdgeInsets.all(18),
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

  Future<void> _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
