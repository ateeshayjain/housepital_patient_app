import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';

class VitalsScreen extends StatefulWidget {
  final String? initialVital;
  const VitalsScreen({super.key, this.initialVital});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _period = '7d';
  List<VitalReading> _vitals = [];

  final List<String> _tabs = ['BP', 'Temp', 'SpO2', 'Sugar', 'Pulse'];
  final List<String> _vitalKeys = ['bp', 'temperature', 'spo2', 'sugar', 'pulse'];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialVital != null) {
      final idx = _vitalKeys.indexOf(widget.initialVital!);
      if (idx >= 0) initialIndex = idx;
    }
    _tabController = TabController(
        length: _tabs.length, vsync: this, initialIndex: initialIndex);
    _generateMockData();
  }

  void _generateMockData() {
    final rng = Random(42);
    final now = DateTime.now();
    int days = _period == '7d' ? 7 : _period == '30d' ? 30 : _period == '90d' ? 90 : 180;

    _vitals = List.generate(days, (i) {
      final date = now.subtract(Duration(days: days - 1 - i));
      return VitalReading.fromJson({
        'id': 'v$i',
        'patient_id': 'p1',
        'recorded_at': date.toIso8601String(),
        'systolic': 120.0 + rng.nextInt(20) - 5,
        'diastolic': 75.0 + rng.nextInt(15) - 5,
        'pulse': 70.0 + rng.nextInt(15) - 3,
        'spo2': 95.0 + rng.nextInt(4),
        'temperature': 97.5 + rng.nextDouble() * 2,
        'sugar': 95.0 + rng.nextInt(35),
      });
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('todays_vitals')),
        bottom: TabBar(
          controller: _tabController,
          labelColor: HousepitalColors.orange,
          unselectedLabelColor: HousepitalColors.greyLight,
          indicatorColor: HousepitalColors.orange,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Period filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _periodChip('7d', '7 Days'),
                const SizedBox(width: 8),
                _periodChip('30d', '30 Days'),
                const SizedBox(width: 8),
                _periodChip('90d', '90 Days'),
                const SizedBox(width: 8),
                _periodChip('all', 'All'),
              ],
            ),
          ),

          // Chart + insights
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChartPage('systolic', 'diastolic', 'mmHg', 'Blood Pressure'),
                _buildChartPage('temperature', null, '\u00B0F', 'Temperature'),
                _buildChartPage('spo2', null, '%', 'SpO2'),
                _buildChartPage('sugar', null, 'mg/dl', 'Blood Sugar'),
                _buildChartPage('pulse', null, 'bpm', 'Pulse'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String value, String label) {
    final isSelected = _period == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _period = value);
        _generateMockData();
      },
      selectedColor: HousepitalColors.orange,
      backgroundColor: HousepitalColors.greyLighter,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isSelected ? Colors.white : HousepitalColors.grey,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  Widget _buildChartPage(String primaryKey, String? secondaryKey, String unit, String title) {
    if (_vitals.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Extract values
    final spots = <FlSpot>[];
    final secondarySpots = <FlSpot>[];
    final values = <double>[];

    for (int i = 0; i < _vitals.length; i++) {
      final v = _vitals[i];
      double? value;
      double? secValue;

      switch (primaryKey) {
        case 'systolic':
          value = v.systolic;
          secValue = v.diastolic;
          break;
        case 'temperature':
          value = v.temperature;
          break;
        case 'spo2':
          value = v.spo2;
          break;
        case 'sugar':
          value = v.sugar;
          break;
        case 'pulse':
          value = v.pulse;
          break;
      }

      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
        values.add(value);
      }
      if (secValue != null) {
        secondarySpots.add(FlSpot(i.toDouble(), secValue));
      }
    }

    if (spots.isEmpty) return const Center(child: Text('No data'));

    final avg = values.reduce((a, b) => a + b) / values.length;
    final latest = values.last;
    final maxVal = values.reduce(max);
    final minVal = values.reduce(min);
    final chartColor = _chartColor(primaryKey);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Latest reading hero
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  primaryKey == 'systolic'
                      ? '${_vitals.last.systolic?.toInt()}/${_vitals.last.diastolic?.toInt()}'
                      : latest.toStringAsFixed(primaryKey == 'temperature' ? 1 : 0),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: chartColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 16,
                    color: HousepitalColors.greyLight,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Latest reading',
                      style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
                    ),
                    Text(
                      DateHelper.formatDate(_vitals.last.recordedAt),
                      style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chart
          SizedBox(
            height: 240,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _gridInterval(primaryKey),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: HousepitalColors.divider,
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: _vitals.length > 7 ? (_vitals.length / 5).ceilToDouble() : 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < _vitals.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateHelper.formatDateShort(_vitals[idx].recordedAt),
                                style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: chartColor,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: _vitals.length <= 14,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: chartColor,
                            strokeWidth: 1.5,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: chartColor.withValues(alpha: 0.08),
                      ),
                    ),
                    if (secondarySpots.isNotEmpty)
                      LineChartBarData(
                        spots: secondarySpots,
                        isCurved: true,
                        color: HousepitalColors.info,
                        barWidth: 2,
                        dotData: FlDotData(show: _vitals.length <= 14),
                      ),
                  ],
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final idx = spot.spotIndex;
                          String dateStr = '';
                          if (idx >= 0 && idx < _vitals.length) {
                            dateStr = '\n${DateHelper.formatDateShort(_vitals[idx].recordedAt)}';
                          }
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}$dateStr',
                            const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (secondarySpots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _legendDot(chartColor, 'Systolic'),
                  const SizedBox(width: 16),
                  _legendDot(HousepitalColors.info, 'Diastolic'),
                ],
              ),
            ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _statCard('Average', avg.toStringAsFixed(1), unit, chartColor),
                const SizedBox(width: 12),
                _statCard('Highest', maxVal.toStringAsFixed(1), unit, HousepitalColors.error),
                const SizedBox(width: 12),
                _statCard('Lowest', minVal.toStringAsFixed(1), unit, HousepitalColors.info),
              ],
            ),
          ),

          // Insights
          _buildInsights(primaryKey, values),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  double _gridInterval(String key) {
    switch (key) {
      case 'systolic': return 20;
      case 'temperature': return 1;
      case 'spo2': return 2;
      case 'sugar': return 20;
      case 'pulse': return 10;
      default: return 20;
    }
  }

  Color _chartColor(String key) {
    switch (key) {
      case 'systolic': return const Color(0xFFE53935);
      case 'temperature': return const Color(0xFFEF6C00);
      case 'spo2': return const Color(0xFF1565C0);
      case 'sugar': return const Color(0xFF7B1FA2);
      case 'pulse': return const Color(0xFFE53935);
      default: return HousepitalColors.orange;
    }
  }

  Widget _statCard(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HousepitalColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HousepitalColors.divider),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(unit, style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(String primaryKey, List<double> values) {
    if (values.isEmpty) return const SizedBox.shrink();

    final avg = values.reduce((a, b) => a + b) / values.length;
    final maxVal = values.reduce(max);
    final minVal = values.reduce(min);
    final range = maxVal - minVal;
    final label = _vitalLabel(primaryKey);
    final period = _period == '7d' ? '7 days' : _period == '30d' ? '30 days' : _period == '90d' ? '90 days' : 'period';

    final insights = <Widget>[];

    if (range < (avg * 0.1)) {
      insights.add(_insightRow(Icons.check_circle, HousepitalColors.success,
          '$label has been stable over the past $period.'));
    } else {
      insights.add(_insightRow(Icons.trending_up, HousepitalColors.warning,
          '$label varied between ${minVal.toStringAsFixed(0)} and ${maxVal.toStringAsFixed(0)}.'));
    }

    int alertCount = 0;
    for (final val in values) {
      if (VitalHelper.getVitalStatus(primaryKey, val) == 'alert') alertCount++;
    }
    if (alertCount > 0) {
      insights.add(_insightRow(Icons.warning_amber_rounded, HousepitalColors.error,
          'Outside safe range on $alertCount occasion${alertCount > 1 ? "s" : ""}.'));
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HousepitalColors.black)),
          const SizedBox(height: 8),
          ...insights,
        ],
      ),
    );
  }

  Widget _insightRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, color: HousepitalColors.grey, height: 1.4)),
          ),
        ],
      ),
    );
  }

  String _vitalLabel(String key) {
    switch (key) {
      case 'systolic': return 'Blood Pressure';
      case 'temperature': return 'Temperature';
      case 'spo2': return 'SpO2';
      case 'sugar': return 'Blood Sugar';
      case 'pulse': return 'Pulse';
      default: return key;
    }
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: HousepitalColors.greyLight)),
      ],
    );
  }
}
