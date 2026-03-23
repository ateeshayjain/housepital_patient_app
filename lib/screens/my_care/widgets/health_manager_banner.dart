// lib/screens/my_care/widgets/health_manager_banner.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';

class HealthManagerBanner extends StatelessWidget {
  final HealthManager manager;

  const HealthManagerBanner({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF5EB), Color(0xFFFFF0E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE0C0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: HousepitalColors.orange,
            backgroundImage: manager.photoUrl != null
                ? NetworkImage(manager.photoUrl!)
                : null,
            child: manager.photoUrl == null
                ? Text(
                    manager.name.split(' ').map((n) => n[0]).take(2).join(),
                    style: const TextStyle(
                        color: Colors.white,
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
                        color: Colors.grey[500],
                        letterSpacing: 0.5)),
                Text(manager.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                    'Available ${manager.availableFrom} – ${manager.availableTo}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                launchUrl(Uri.parse('tel:${manager.phone}')),
            style: IconButton.styleFrom(
              backgroundColor: HousepitalColors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.phone, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/chat', arguments: {
                'patientId': manager.staffId, // TODO: Replace with actual patient ID from auth
                'coordinatorName': manager.name,
                'coordinatorPhotoUrl': manager.photoUrl,
              });
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
          ),
        ],
      ),
    );
  }
}
