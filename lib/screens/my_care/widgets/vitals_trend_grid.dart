// lib/screens/my_care/widgets/vitals_trend_grid.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/app_localizations.dart';

class VitalsTrendGrid extends StatelessWidget {
  final VitalsSummary vitals;

  const VitalsTrendGrid({super.key, required this.vitals});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('vitals_trend'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              _vitalCard(context, 'BP', vitals.bp),
              _vitalCard(context, 'SpO2', vitals.spo2),
              _vitalCard(context, 'Pulse', vitals.pulse),
              _vitalCard(context, 'Temp', vitals.temperature),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalCard(BuildContext context, String title, VitalCard card) {
    final statusColor = _statusColor(card.status);

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/vitals', arguments: title.toLowerCase()),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: card.status == 'critical'
                ? HousepitalColors.error
                : const Color(0xFFE5E7EB),
          ),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    card.status[0].toUpperCase() + card.status.substring(1),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(card.label,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (card.sparkline.length > 1) ...[
              const Spacer(),
              SizedBox(
                height: 24,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: card.sparkline
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        isCurved: true,
                        color: statusColor,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: statusColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
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
