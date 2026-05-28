import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/daimaa_theme.dart';
import '../../models/models.dart';

/// Dedicated Dai Maa landing — entry point for the mother & baby sub-brand.
///
/// Reuses the existing `mp-japa-24` and `mp-nanny-12` service items so that
/// tapping either card flows into the same assessment-request form
/// (which itself shows Dai Maa branding when serviceType is japa/nanny).
class DaiMaaLandingScreen extends StatelessWidget {
  const DaiMaaLandingScreen({super.key});

  // Canonical Japa & Nanny service items — kept in sync with
  // service_catalog_screen.dart so the assessment-request screen routes work.
  static final ServiceItem _japaService = ServiceItem(
    id: 'mp-japa-24',
    name: 'Japa Maid – 24 Hours',
    category: 'manpower',
    bookingType: 'assessment',
    description:
        'Post-delivery care for mother & newborn (0-7 months) — breastfeeding '
        'support, baby massage, bathing, umbilical cord care & mother\'s diet '
        'preparation.',
    durationMinutes: 1440,
    iconName: 'child_friendly',
  );

  static final ServiceItem _nannyService = ServiceItem(
    id: 'mp-nanny-12',
    name: 'Nanny – 12 Hours',
    category: 'manpower',
    bookingType: 'assessment',
    description:
        'Professional nanny for infants & toddlers (7 months–5 years) — '
        'feeding, sleep routine, developmental activities, hygiene & safety '
        'supervision.',
    durationMinutes: 720,
    iconName: 'child_care',
  );

  Future<void> _callCoordinator() async {
    final uri = Uri(scheme: 'tel', path: DaiMaaColors.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DaiMaaColors.cream,
      appBar: AppBar(
        backgroundColor: DaiMaaColors.plum,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Dai Maa',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DaiMaaBrandHeader(
              title: 'Mother & Baby Care',
              subtitle:
                  'Trained, vetted, female caregivers — from your first '
                  'trimester through toddler years.',
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose the care you need',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DaiMaaColors.plum,
              ),
            ),
            const SizedBox(height: 12),
            _DaiMaaServiceCard(
              icon: Icons.child_friendly,
              title: 'Japa Maid',
              ageRange: '0 – 7 months',
              description:
                  'Round-the-clock post-delivery care: breastfeeding support, '
                  'baby massage, bathing, umbilical cord care & mother\'s diet.',
              service: _japaService,
            ),
            const SizedBox(height: 12),
            _DaiMaaServiceCard(
              icon: Icons.child_care,
              title: 'Nanny',
              ageRange: '7 months – 5 years',
              description:
                  'Daytime childcare: feeding, sleep routine, developmental '
                  'play, hygiene & safety supervision.',
              service: _nannyService,
            ),
            const SizedBox(height: 24),
            // Call coordinator CTA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DaiMaaColors.pink, width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 40,
                    color: DaiMaaColors.plum,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Not sure what you need?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DaiMaaColors.plum,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Speak with a Dai Maa coordinator — '
                    'we\'ll guide you through the right fit for your family.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _callCoordinator,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DaiMaaColors.plum,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.phone, size: 20),
                      label: const Text(
                        'Call ${DaiMaaColors.phoneDisplay}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                DaiMaaColors.lockup,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: DaiMaaColors.plum,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaiMaaServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String ageRange;
  final String description;
  final ServiceItem service;

  const _DaiMaaServiceCard({
    required this.icon,
    required this.title,
    required this.ageRange,
    required this.description,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: DaiMaaColors.plum.withValues(alpha: 0.15),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/assessment-request',
          arguments: service,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DaiMaaColors.plum, width: 1.5),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: DaiMaaColors.lavender.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 30, color: DaiMaaColors.plum),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: DaiMaaColors.plum,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: DaiMaaColors.pink.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ageRange,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: DaiMaaColors.plum,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: DaiMaaColors.plum,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Book Assessment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
