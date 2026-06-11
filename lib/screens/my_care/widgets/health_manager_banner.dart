// lib/screens/my_care/widgets/health_manager_banner.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_colors.dart';
import '../../../models/my_care_models.dart';

class HealthManagerBanner extends StatelessWidget {
  final HealthManager manager;

  const HealthManagerBanner({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    // My Care's ONE solid-orange ribbon (one per screen, like Home's hero
    // call-caregiver card and Billing's balance card). Text/icons on the
    // orange fill use onOrange — white on orange fails AA (~2.3:1).
    final onOrange = context.hc.onOrange;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: context.hc.orange,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            // Surface disc so the avatar reads on the orange fill.
            backgroundColor: context.hc.surface,
            backgroundImage: manager.photoUrl != null
                ? NetworkImage(manager.photoUrl!)
                : null,
            child: manager.photoUrl == null
                ? Text(
                    manager.name.split(' ').map((n) => n[0]).take(2).join(),
                    style: TextStyle(
                        color: context.hc.orangeText,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Health Manager',
                    style: TextStyle(
                        fontSize: 11,
                        color: onOrange.withValues(alpha: 0.7),
                        letterSpacing: 0.5)),
                Text(manager.name,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: onOrange)),
                Text(
                    'Available ${manager.availableFrom} – ${manager.availableTo}',
                    style: TextStyle(fontSize: 12, color: onOrange)),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                launchUrl(Uri.parse('tel:${manager.phone}')),
            style: IconButton.styleFrom(
              backgroundColor: context.hc.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(Icons.phone, color: context.hc.orangeText, size: 20),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/chat', arguments: {
                'patientId': manager.staffId, // FUTURE: Replace with actual patient ID from auth provider
                'coordinatorName': manager.name,
                'coordinatorPhotoUrl': manager.photoUrl,
              });
            },
            style: IconButton.styleFrom(
              backgroundColor: context.hc.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: Icon(Icons.chat_bubble_outline,
                size: 20, color: context.hc.orangeText),
          ),
        ],
      ),
    );
  }
}
