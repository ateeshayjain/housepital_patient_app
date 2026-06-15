// lib/screens/my_care/widgets/active_service_card.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
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
    final allPresent =
        service.hasStaff && service.checkedInStaff == service.totalStaff;
    final progressLabel = service.isSessionBased
        ? 'Session ${service.consumedDays}/${service.totalDays}'
        : 'Day ${service.consumedDays}/${service.totalDays}';

    // Compact single-block card: one info row + progress bar. Still markedly
    // shorter than the old gradient-header version, but rebalanced after
    // over-compaction: flagship-weight title (14.5), readable meta (12), 5px
    // progress bar. The "Latest vital" stat remains intentionally dropped
    // (vitals live in the dedicated Today's Vitals section \u2014 no
    // cross-card duplication).
    //
    // Calm pass: the per-service-type color stripe + progress tint were
    // DECORATIVE identity color and are retired. Progress is always the one
    // orange accent; the only color that varies is the semantic status line
    // (green = all on duty, amber = waiting).
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  Text(
                    progressLabel,
                    style: TextStyle(fontSize: 11, color: context.hc.greyLight),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.hc.greyLight,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (service.hasStaff) ...[
                    Icon(
                      allPresent ? Icons.check_circle : Icons.schedule,
                      size: 14,
                      color: allPresent
                          ? context.hc.success
                          : context.hc.warning,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${service.checkedInStaff}/${service.totalStaff} on duty',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: allPresent
                              ? context.hc.success
                              : context.hc.warning,
                        ),
                      ),
                    ),
                  ],
                  // Renewal reminder only surfaces when it's actually
                  // actionable — within 5 days of renewal (owner: don't show
                  // it on day 15/30). Spacer right-aligns it.
                  if (service.renewalDate != null &&
                      service.daysRemaining <= 5) ...[
                    const Spacer(),
                    Icon(
                      Icons.event_repeat,
                      size: 13,
                      color: context.hc.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      service.daysRemaining <= 0
                          ? 'Renews today'
                          : 'Renews in ${service.daysRemaining}d',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.hc.warning),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2.5),
                child: LinearProgressIndicator(
                  value: service.progressFraction,
                  minHeight: 5,
                  // One accent: orange fill on the orange tint track for ALL
                  // services (dark mode resolves orangeLight → orangeMuted).
                  backgroundColor: context.hc.orangeLight,
                  valueColor: AlwaysStoppedAnimation(context.hc.orange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
