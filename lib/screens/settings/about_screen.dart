import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../widgets/common_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _appVersion = '1.0.0';
  static const _companyName = 'Housepital Pvt Ltd';
  static const _address =
      'First Floor, B1/A32, Mohan Cooperative Industrial Estate, Badarpur, New Delhi – 110044';
  static const _cin = 'CIN: U85100DL2019PTC357830';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: context.hc.orangeLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                size: 56,
                color: HousepitalColors.orange,
              ),
            ),
            const SizedBox(height: 20),

            // App name
            Text(
              'Housepital',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: context.hc.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hospital-like expertise. Home-like care.',
              style: TextStyle(
                fontSize: 14,
                color: context.hc.greyLight,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.hc.greyLighter,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Version $_appVersion',
                style: TextStyle(
                  fontSize: 13,
                  color: context.hc.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Company info
            _infoRow(context, Icons.business, _companyName),
            const SizedBox(height: 12),
            _infoRow(context, Icons.location_on, _address),
            const SizedBox(height: 12),
            _infoRow(context, Icons.badge_outlined, _cin),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Links
            _linkTile(
              context,
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              url: 'https://housepital.in/terms',
            ),
            _linkTile(
              context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              url: 'https://housepital.in/privacy',
            ),
            _linkTile(
              context,
              icon: Icons.language,
              title: 'Website',
              url: 'https://housepital.in',
            ),

            const SizedBox(height: 40),

            // Made with love
            Text(
              'Made with \u2764\uFE0F in India',
              style: TextStyle(
                fontSize: 14,
                color: context.hc.greyLight,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.hc.grey),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.hc.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _linkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String url,
  }) {
    return ListTile(
      leading: AppIconTile(icon: icon, color: HousepitalColors.orange, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: Icon(Icons.open_in_new,
          size: 18, color: context.hc.greyLight),
      onTap: () => _launchUrl(context, url),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }
}
