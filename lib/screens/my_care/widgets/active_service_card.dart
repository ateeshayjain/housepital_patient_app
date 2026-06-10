// lib/screens/my_care/widgets/active_service_card.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
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
    final allPresent =
        service.hasStaff && service.checkedInStaff == service.totalStaff;
    final progressLabel = service.isSessionBased
        ? 'Session ${service.consumedDays}/${service.totalDays}'
        : 'Day ${service.consumedDays}/${service.totalDays}';

    // Compact single-block card: slim color accent + one info row + thin
    // progress bar. ~45% shorter than the old gradient-header version, and the
    // "Latest vital" stat is intentionally dropped (vitals live in the
    // dedicated Today's Vitals section \u2014 no cross-card duplication).
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Slim color accent stripe (category identity, no tall header).
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              service.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                          ),
                          Text(progressLabel,
                              style: TextStyle(
                                  fontSize: 11, color: context.hc.greyLight)),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 18, color: context.hc.greyLight),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (service.hasStaff) ...[
                            Icon(allPresent ? Icons.check_circle : Icons.schedule,
                                size: 14,
                                color: allPresent
                                    ? context.hc.success
                                    : context.hc.warning),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${service.checkedInStaff}/${service.totalStaff} on duty',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: allPresent
                                        ? context.hc.success
                                        : context.hc.warning),
                              ),
                            ),
                          ],
                          if (service.renewalDate != null) ...[
                            const Spacer(),
                            Icon(Icons.event_repeat,
                                size: 13, color: context.hc.greyLight),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text('Renews in ${service.daysRemaining}d',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.hc.grey)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: service.progressFraction,
                          minHeight: 3,
                          backgroundColor: context.hc.greyLighter,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
