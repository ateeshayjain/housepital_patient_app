// lib/screens/my_care/widgets/active_service_card.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';

class ActiveServiceCard extends StatelessWidget {
  final ActiveService service;
  final VoidCallback onTap;

  const ActiveServiceCard({
    super.key,
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = HousepitalColors.serviceColor(service.serviceCategory);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // Color-coded header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      service.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      service.isSessionBased
                          ? 'Session ${service.consumedDays} of ${service.totalDays}'
                          : 'Day ${service.consumedDays} of ${service.totalDays}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (service.hasStaff)
                        _stat('Staff Today',
                            '${service.checkedInStaff}/${service.totalStaff} ${service.checkedInStaff == service.totalStaff ? "\u2713" : ""}',
                            service.checkedInStaff == service.totalStaff
                                ? HousepitalColors.success
                                : HousepitalColors.warning),
                      if (service.showVitals && service.latestVitalLabel != null)
                        _stat('Latest', service.latestVitalLabel!,
                            _vitalColor(service.latestVitalStatus)),
                      if (service.renewalDate != null)
                        _stat('Renewal', '${service.daysRemaining} days',
                            HousepitalColors.grey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: service.progressFraction,
                      minHeight: 4,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor)),
      ],
    );
  }

  Color _vitalColor(String? status) {
    switch (status) {
      case 'critical':
        return HousepitalColors.error;
      case 'warning':
        return HousepitalColors.warning;
      default:
        return HousepitalColors.success;
    }
  }
}
