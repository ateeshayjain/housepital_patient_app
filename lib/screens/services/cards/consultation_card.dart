// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../config/app_colors.dart';
import '../../../models/models.dart';
import '../../../utils/helpers.dart';
import '../../../widgets/common_widgets.dart';

/// Card shown in the Consultations / Visits tab for a single
/// [ServiceItem] (doctor visit, psychiatrist, IV/IM visit, etc).
class ConsultationCard extends StatelessWidget {
  final ServiceItem service;
  final Map<String, IconData> iconMap;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const ConsultationCard({
    super.key,
    required this.service,
    required this.iconMap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final icon = iconMap[service.iconName] ?? Icons.medical_services;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: context.hc.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: () => onNavigate(context, service),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AppIconTile(
                  icon: icon,
                  color: HousepitalColors.orange,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.hc.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.description ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.hc.greyLight,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // audit M-1: manpower services must never display
                          // an upfront price — show "Price on assessment"
                          // instead (user rule: caretaker/nursing/japa/nanny
                          // pricing is conversation-gated).
                          if (service.category == 'manpower')
                            Text(
                              'Price on assessment',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.hc.orangeText,
                              ),
                            )
                          else if (service.basePriceMin != null)
                            Text(
                              'From ${DateHelper.formatCurrency(service.basePriceMin!)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.hc.orangeText,
                              ),
                            ),
                          const Spacer(),
                          if (service.durationMinutes != null)
                            Row(
                              children: [
                                Icon(Icons.schedule,
                                    size: 14,
                                    color: context.hc.greyLight),
                                const SizedBox(width: 4),
                                Text(
                                  '${service.durationMinutes} min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.hc.greyLight,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right,
                    color: context.hc.greyLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
