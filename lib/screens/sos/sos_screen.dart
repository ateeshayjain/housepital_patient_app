import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';

class SOSScreen extends StatelessWidget {
  const SOSScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // audit M-4: surface patient address up top so dispatchers (and the user)
    // can see where help will go before they tap a call button.
    final patient = context.watch<AppProvider>().currentPatient;
    final address = patient?.address;

    return Scaffold(
      backgroundColor: HousepitalColors.sos,
      appBar: AppBar(
        backgroundColor: HousepitalColors.sos,
        foregroundColor: Colors.white,
        title: Text(l.t('sos_title')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emergency, color: Colors.white, size: 72),
              const SizedBox(height: 16),
              Text(
                l.t('sos_title'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // audit M-4: address card / prompt to add one.
              _buildAddressCard(context, address),
              const SizedBox(height: 24),

              // Medical Emergency
              _sosOption(
                context,
                icon: Icons.local_hospital,
                title: l.t('sos_medical'),
                subtitle: 'Call ${AppConstants.emergencyPhone}',
                onTap: () => _makeCall(context, AppConstants.emergencyPhone),
              ),
              const SizedBox(height: 12),

              // Staff Emergency
              _sosOption(
                context,
                icon: Icons.person_off,
                title: l.t('sos_staff'),
                subtitle: 'Alert Housepital Ops',
                onTap: () => _makeCall(context, AppConstants.supportPhone),
              ),
              const SizedBox(height: 12),

              // 112
              _sosOption(
                context,
                icon: Icons.call,
                title: l.t('sos_112'),
                subtitle: 'National Emergency Number',
                onTap: () =>
                    _makeCall(context, AppConstants.emergencyNumber112),
              ),
              const SizedBox(height: 12),

              // audit M-4: Book Housepital Ambulance. No bookable ambulance
              // ServiceItem exists in the catalog seeds (care_packages.dart
              // mentions ACLS ambulance only as a package inclusion, not a
              // standalone service). Falling back to /raise-concern so ops
              // gets a logged ticket instead of a dead nav.
              _sosOption(
                context,
                icon: Icons.medical_services,
                title: 'Book Housepital Ambulance',
                subtitle: 'Request ACLS ambulance dispatch',
                onTap: () => _bookAmbulance(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // audit M-4: show patient address with copy action, or prompt to add one.
  Widget _buildAddressCard(BuildContext context, String? address) {
    final hasAddress = address != null && address.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      // audit batch 4 (Agent L): Apple 8pt grid (P1) — snap 14 to 16.
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: hasAddress
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on,
                    color: HousepitalColors.sos, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dispatch address',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: HousepitalColors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HousepitalColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy address',
                  icon: const Icon(Icons.copy,
                      color: HousepitalColors.sos, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: address));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied')),
                    );
                  },
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.location_off,
                    color: HousepitalColors.warning, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Add your address in Profile so we can dispatch faster',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: HousepitalColors.black,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/patient-profile'),
                  style: TextButton.styleFrom(
                    foregroundColor: HousepitalColors.sos,
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
    );
  }

  // audit M-4: Ambulance request — falls back to the concern screen because
  // there is no standalone ambulance ServiceItem in care_packages.dart yet.
  // The /service-booking route requires a ServiceItem arg, so routing there
  // would crash. /raise-concern accepts no args today; we open it directly
  // and the user can pick "Medical concern" — the form is the same one ops
  // already triages from.
  void _bookAmbulance(BuildContext context) {
    Navigator.pushNamed(context, '/raise-concern');
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
