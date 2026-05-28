// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../utils/helpers.dart';

/// Card shown in the Diagnostics tab (and reused at the top of the Lab Tests
/// tab as a "Popular Packages" row) for a single diagnostic [ServiceItem].
class DiagnosticCard extends StatelessWidget {
  final ServiceItem service;
  final Map<String, IconData> iconMap;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const DiagnosticCard({
    super.key,
    required this.service,
    required this.iconMap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Semantics(
        // audit M-1: suppress price in semantics label for manpower services.
        label:
            '${service.name}. ${service.category == 'manpower' ? 'Price on assessment' : (service.basePriceMin != null ? DateHelper.formatCurrency(service.basePriceMin!) : "")}. Home collection available. Tap to book slot.',
        button: true,
        child: Material(
          color: HousepitalColors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 1,
          shadowColor: Colors.black12,
          child: InkWell(
            onTap: () => onNavigate(context, service),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: HousepitalColors.infoLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconMap[service.iconName] ??
                          Icons.miscellaneous_services,
                      color: HousepitalColors.info,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: HousepitalColors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: HousepitalColors.successLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Home Collection',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HousepitalColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // audit M-1: manpower → "Price on assessment".
                        if (service.category == 'manpower')
                          const Text(
                            'Price on assessment',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HousepitalColors.orangeText,
                            ),
                          )
                        else if (service.basePriceMin != null)
                          Text(
                            DateHelper.formatCurrency(
                                service.basePriceMin!),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HousepitalColors.orangeText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => onNavigate(context, service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HousepitalColors.orange,
                        foregroundColor: HousepitalColors.white,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Book Slot'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
