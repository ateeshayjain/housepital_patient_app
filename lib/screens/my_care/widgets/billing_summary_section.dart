// lib/screens/my_care/widgets/billing_summary_section.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/helpers.dart';
import '../../../utils/app_localizations.dart';

class BillingSummarySection extends StatelessWidget {
  final List<ActiveService> services;

  const BillingSummarySection({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Aggregate billing from all services
    final totalPaid =
        services.fold<int>(0, (sum, s) => sum + (s.totalPaid ?? 0));
    final totalConsumed =
        services.fold<int>(0, (sum, s) => sum + (s.totalConsumed ?? 0));
    final remaining =
        services.fold<int>(0, (sum, s) => sum + (s.remaining ?? 0));
    final progress =
        totalPaid > 0 ? (totalConsumed / totalPaid).clamp(0.0, 1.0) : 0.0;

    // Earliest renewal date
    final renewalDates = services
        .where((s) => s.renewalDate != null)
        .map((s) => s.renewalDate!)
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('billing_summary'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Package Paid',
                              style: TextStyle(
                                  fontSize: 11, color: context.hc.greyLight)),
                          Text(DateHelper.formatCurrency(totalPaid),
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Consumed',
                              style: TextStyle(
                                  fontSize: 11, color: context.hc.greyLight)),
                          Text(DateHelper.formatCurrency(totalConsumed),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: HousepitalColors.orange)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: context.hc.greyLighter,
                      valueColor: const AlwaysStoppedAnimation(
                          HousepitalColors.orange),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          '${DateHelper.formatCurrency(totalConsumed)} consumed',
                          style: TextStyle(
                              fontSize: 12, color: context.hc.grey)),
                      Text(
                          '${DateHelper.formatCurrency(remaining)} remaining',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.hc.success,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (renewalDates.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Next renewal',
                            style: TextStyle(
                                fontSize: 12, color: context.hc.grey)),
                        Text(DateHelper.formatDate(renewalDates.first),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/billing'),
                      child: Text(l.t('view_invoices')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
