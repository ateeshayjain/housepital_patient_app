// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../utils/helpers.dart';
import '../../../widgets/common_widgets.dart';

/// Bottom sheet shown when a [LabTestItem] row is tapped on the Lab Tests
/// tab. Surfaces description, components, method, related tests, and a
/// Book Now CTA.
class LabTestDetailSheet extends StatelessWidget {
  final LabTestItem test;
  final VoidCallback onBook;
  final void Function(String) onRelatedTap;

  const LabTestDetailSheet({
    super.key,
    required this.test,
    required this.onBook,
    required this.onRelatedTap,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: HousepitalColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HousepitalColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Name + Price header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppIconTile(
                            icon: Icons.science,
                            color: HousepitalColors.info),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                test.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: HousepitalColors.black,
                                ),
                              ),
                              if (test.alsoKnownAs != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  test.alsoKnownAs!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: HousepitalColors.greyLight,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (test.price != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: HousepitalColors.orangeLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              DateHelper.formatCurrency(test.price!),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: HousepitalColors.orangeText,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Info chips row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (test.sampleType != null)
                          _InfoChip(
                              icon: Icons.colorize, label: test.sampleType!),
                        _InfoChip(
                          icon: test.fastingRequired
                              ? Icons.no_food
                              : Icons.restaurant,
                          label: test.fastingRequired
                              ? 'Fasting Required'
                              : 'No Fasting',
                          color: test.fastingRequired
                              ? HousepitalColors.warning
                              : HousepitalColors.success,
                        ),
                        if (test.reportTat != null)
                          _InfoChip(
                              icon: Icons.schedule,
                              label: 'Report: ${test.reportTat!}'),
                        _InfoChip(
                          icon: test.homeCollection
                              ? Icons.home
                              : Icons.local_hospital,
                          label: test.homeCollection
                              ? 'Home Collection'
                              : 'Lab Visit',
                          color: test.homeCollection
                              ? HousepitalColors.success
                              : HousepitalColors.greyLight,
                        ),
                        if (test.tube != null)
                          _InfoChip(icon: Icons.science, label: test.tube!),
                        if (test.category != null)
                          _InfoChip(
                              icon: Icons.category, label: test.category!),
                      ],
                    ),
                    if (test.description != null) ...[
                      const SizedBox(height: 20),
                      const Text('Description',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HousepitalColors.black)),
                      const SizedBox(height: 6),
                      Text(test.description!,
                          style: const TextStyle(
                              fontSize: 14,
                              color: HousepitalColors.grey,
                              height: 1.5)),
                    ],
                    if (test.components != null) ...[
                      const SizedBox(height: 16),
                      const Text('Components / Parameters',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HousepitalColors.black)),
                      const SizedBox(height: 6),
                      Text(test.components!,
                          style: const TextStyle(
                              fontSize: 14,
                              color: HousepitalColors.grey,
                              height: 1.5)),
                    ],
                    if (test.method != null) ...[
                      const SizedBox(height: 16),
                      const Text('Method',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HousepitalColors.black)),
                      const SizedBox(height: 6),
                      Text(test.method!,
                          style: const TextStyle(
                              fontSize: 14, color: HousepitalColors.grey)),
                    ],
                    if (test.commonlyPrescribedFor != null) ...[
                      const SizedBox(height: 16),
                      const Text('Commonly Prescribed For',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HousepitalColors.black)),
                      const SizedBox(height: 6),
                      Text(test.commonlyPrescribedFor!,
                          style: const TextStyle(
                              fontSize: 14,
                              color: HousepitalColors.grey,
                              height: 1.5)),
                    ],
                    if (test.relatedTests != null) ...[
                      const SizedBox(height: 16),
                      const Text('Related Tests',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HousepitalColors.black)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: test.relatedTests!
                            .split(',')
                            .map((t) => t.trim())
                            .where((t) => t.isNotEmpty)
                            .map(
                              (t) => ActionChip(
                                label: Text(t,
                                    style: const TextStyle(fontSize: 12)),
                                onPressed: () => onRelatedTap(t),
                                backgroundColor: HousepitalColors.infoLight,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
              ),
              // Book Now button
              if (test.price != null)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: onBook,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                            'Book Now  •  ${DateHelper.formatCurrency(test.price!)}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HousepitalColors.orange,
                          foregroundColor: HousepitalColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = HousepitalColors.info,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style:
                TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
