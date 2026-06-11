import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../utils/validators.dart';
import '../../utils/vital_classifier.dart';
import '../../widgets/glass.dart';

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

  int get _periodDays =>
      _period == '7d' ? 7 : _period == '30d' ? 30 : _period == '90d' ? 90 : 180;

  void _generateMockData() {
    final rng = Random(42);
    final now = DateTime.now();
    final days = _periodDays;

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

  /// Opens the manual-entry sheet pre-selected to the active vital tab.
  /// Shows the confirmation SnackBar after a successful save.
  Future<void> _showAddReadingSheet(BuildContext context) async {
    // The sheet lives in its own route — re-provide AppProvider so it can
    // save regardless of where the provider sits in the tree.
    final app = context.read<AppProvider>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: _AddVitalReadingSheet(
            initialVitalKey: _vitalKeys[_tabController.index]),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(this.context)!.t('reading_saved'))),
      );
    }
  }

  /// Mock baseline + manually entered readings (provider) for the selected
  /// period, oldest first — a reading saved from the entry sheet appears on
  /// the chart, stat cards, and 'Latest reading' immediately.
  List<VitalReading> _mergedVitals(List<VitalReading> manual) {
    final cutoff = DateTime.now().subtract(Duration(days: _periodDays));
    final merged = [
      ..._vitals,
      ...manual.where((r) => r.recordedAt.isAfter(cutoff)),
    ];
    merged.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vitals = _mergedVitals(context.watch<AppProvider>().vitalsHistory);

    return Scaffold(
      // No assistant FAB on this pushed route (it lives on MainShell's
      // scaffold), so the add-reading action gets the canonical extended FAB:
      // orange fill, onOrange (white) icon + label per the owner decision.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReadingSheet(context),
        backgroundColor: HousepitalColors.orange,
        foregroundColor: context.hc.onOrange,
        icon: const Icon(Icons.add),
        label: Text(l.t('add_reading')),
      ),
      appBar: GlassAppBar(
        title: Text(l.t('todays_vitals')),
        bottom: TabBar(
          controller: _tabController,
          labelColor: HousepitalColors.orange,
          unselectedLabelColor: context.hc.greyLight,
          indicatorColor: HousepitalColors.orange,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Period filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
                _buildChartPage(vitals, 'systolic', 'diastolic', 'mmHg', 'Blood Pressure'),
                _buildChartPage(vitals, 'temperature', null, '\u00B0F', 'Temperature'),
                _buildChartPage(vitals, 'spo2', null, '%', 'SpO2'),
                _buildChartPage(vitals, 'sugar', null, 'mg/dl', 'Blood Sugar'),
                _buildChartPage(vitals, 'pulse', null, 'bpm', 'Pulse'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// C5 calm pass: the 7/30/90/All chips are VIEW filters, not actions —
  /// neutral grey selected state (iOS segmented-control style); orange stays
  /// reserved for actions. greyLighter = surfaceHigh in dark, soft grey in
  /// light; explicit backgroundColor keeps the unselected chip a plain
  /// surface (the dark ChipTheme default is an orange tint).
  Widget _periodChip(String value, String label) {
    final isSelected = _period == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _period = value);
        _generateMockData();
      },
      backgroundColor: context.hc.white,
      selectedColor: context.hc.greyLighter,
      checkmarkColor: context.hc.black,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? context.hc.black : context.hc.grey,
      ),
      side: BorderSide(
        color: isSelected ? context.hc.greyLight : context.hc.divider,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  Widget _buildChartPage(List<VitalReading> vitals, String primaryKey,
      String? secondaryKey, String unit, String title) {
    if (vitals.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Extract values
    final spots = <FlSpot>[];
    final secondarySpots = <FlSpot>[];
    final values = <double>[];
    // Newest reading that actually has this vital (manual entries may carry
    // only one vital, so `vitals.last` is not always the right hero source).
    VitalReading? latestReading;

    for (int i = 0; i < vitals.length; i++) {
      final v = vitals[i];
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
        latestReading = v;
      }
      if (secValue != null) {
        secondarySpots.add(FlSpot(i.toDouble(), secValue));
      }
    }

    if (spots.isEmpty || latestReading == null) {
      return const Center(child: Text('No data'));
    }

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
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          primaryKey == 'systolic'
                              ? '${latestReading.systolic?.toInt()}/${latestReading.diastolic?.toInt()}'
                              : latest.toStringAsFixed(
                                  primaryKey == 'temperature' ? 1 : 0),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: chartColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 16,
                            color: context.hc.greyLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Latest reading',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: context.hc.greyLight),
                      ),
                      Text(
                        DateHelper.formatDate(latestReading.recordedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: context.hc.greyLight),
                      ),
                    ],
                  ),
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
                      color: context.hc.divider,
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
                          style: TextStyle(fontSize: 12, color: context.hc.greyLight),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: vitals.length > 7 ? (vitals.length / 5).ceilToDouble() : 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < vitals.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateHelper.formatDateShort(vitals[idx].recordedAt),
                                style: TextStyle(fontSize: 12, color: context.hc.greyLight),
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
                        show: vitals.length <= 14,
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
                        color: context.hc.info,
                        barWidth: 2,
                        dotData: FlDotData(show: vitals.length <= 14),
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
                          if (idx >= 0 && idx < vitals.length) {
                            dateStr = '\n${DateHelper.formatDateShort(vitals[idx].recordedAt)}';
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
                  _legendDot(context.hc.info, 'Diastolic'),
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
                _statCard('Highest', maxVal.toStringAsFixed(1), unit, context.hc.error),
                const SizedBox(width: 12),
                _statCard('Lowest', minVal.toStringAsFixed(1), unit, context.hc.info),
              ],
            ),
          ),

          // Insights
          _buildInsights(primaryKey, values),

          // Clearance so the extended FAB never covers the last insight row.
          const SizedBox(height: 88),
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
      case 'systolic': return context.hc.error;
      case 'temperature': return context.hc.warning;
      case 'spo2': return context.hc.info;
      case 'sugar': return const Color(0xFF7B1FA2);
      case 'pulse': return context.hc.error;
      default: return HousepitalColors.orange;
    }
  }

  Widget _statCard(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.hc.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.hc.divider),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: context.hc.greyLight)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(unit, style: TextStyle(fontSize: 12, color: context.hc.greyLight)),
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
      insights.add(_insightRow(Icons.check_circle, context.hc.success,
          '$label has been stable over the past $period.'));
    } else {
      insights.add(_insightRow(Icons.trending_up, context.hc.warning,
          '$label varied between ${minVal.toStringAsFixed(0)} and ${maxVal.toStringAsFixed(0)}.'));
    }

    int alertCount = 0;
    for (final val in values) {
      if (VitalHelper.getVitalStatus(primaryKey, val) == 'alert') alertCount++;
    }
    if (alertCount > 0) {
      insights.add(_insightRow(Icons.warning_amber_rounded, context.hc.error,
          'Outside safe range on $alertCount occasion${alertCount > 1 ? "s" : ""}.'));
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.hc.black)),
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
            child: Text(text, style: TextStyle(fontSize: 14, color: context.hc.grey, height: 1.4)),
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
        Text(label, style: TextStyle(fontSize: 13, color: context.hc.greyLight)),
      ],
    );
  }
}

/// Spec for one numeric input of the manual-entry sheet.
class _VitalFieldSpec {
  const _VitalFieldSpec(this.labelKey, this.min, this.max,
      {this.decimal = false});
  final String labelKey; // i18n key, e.g. 'systolic_mmhg'
  final double min;
  final double max;
  final bool decimal; // temperature allows one decimal place
}

/// Manual vitals entry sheet (owner request: "Add option to add vitals
/// here"). Pre-selected to the chart tab that was active when opened; the
/// type can still be switched via chips. Saves through
/// [AppProvider.addVitalReading] and pops `true` so the caller shows the
/// confirmation SnackBar.
class _AddVitalReadingSheet extends StatefulWidget {
  const _AddVitalReadingSheet({required this.initialVitalKey});

  final String initialVitalKey;

  @override
  State<_AddVitalReadingSheet> createState() => _AddVitalReadingSheetState();
}

class _AddVitalReadingSheetState extends State<_AddVitalReadingSheet> {
  // Clinical entry bounds per vital (values outside are treated as typos).
  static const Map<String, List<_VitalFieldSpec>> _fields = {
    'bp': [
      _VitalFieldSpec('systolic_mmhg', 60, 260),
      _VitalFieldSpec('diastolic_mmhg', 30, 200),
    ],
    'temperature': [_VitalFieldSpec('temperature_f', 90, 110, decimal: true)],
    'spo2': [_VitalFieldSpec('spo2_percent', 50, 100)],
    'sugar': [_VitalFieldSpec('sugar_mgdl', 30, 600)],
    'pulse': [_VitalFieldSpec('pulse_bpm', 20, 250)],
  };

  // Same short labels as the chart tabs.
  static const Map<String, String> _typeLabels = {
    'bp': 'BP',
    'temperature': 'Temp',
    'spo2': 'SpO2',
    'sugar': 'Sugar',
    'pulse': 'Pulse',
  };

  late String _vitalKey;
  final TextEditingController _primary = TextEditingController();
  final TextEditingController _secondary = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vitalKey =
        _fields.containsKey(widget.initialVitalKey) ? widget.initialVitalKey : 'bp';
    // Re-evaluate Save enablement (and the live status row) on every change.
    _primary.addListener(_onChanged);
    _secondary.addListener(_onChanged);
  }

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  List<_VitalFieldSpec> get _specs => _fields[_vitalKey]!;

  String? _validate(int index, String? text) => Validators.numberInRange(text,
      min: _specs[index].min, max: _specs[index].max);

  bool get _isValid {
    if (_validate(0, _primary.text) != null) return false;
    if (_specs.length > 1 && _validate(1, _secondary.text) != null) {
      return false;
    }
    return true;
  }

  /// vital_classifier.dart status ('green'/'yellow'/'red') of the current
  /// valid input — a dangerous entry shows its warning state right in the
  /// sheet (and, once saved, wherever latest-vitals status is rendered).
  String? get _status {
    if (!_isValid) return null;
    final value = double.parse(_primary.text.trim());
    return classifyVital(
        _vitalKey == 'bp' ? 'bp_systolic' : _vitalKey, value);
  }

  void _save() {
    final app = context.read<AppProvider>();
    final now = DateTime.now();
    final primary = double.parse(_primary.text.trim());
    final secondary =
        _specs.length > 1 ? double.parse(_secondary.text.trim()) : null;
    final reading = VitalReading(
      id: 'manual_${now.microsecondsSinceEpoch}',
      patientId: app.currentPatient?.id ?? 'pat_demo_rajesh',
      recordedAt: now,
      systolic: _vitalKey == 'bp' ? primary : null,
      diastolic: _vitalKey == 'bp' ? secondary : null,
      temperature: _vitalKey == 'temperature' ? primary : null,
      spo2: _vitalKey == 'spo2' ? primary : null,
      sugar: _vitalKey == 'sugar' ? primary : null,
      sugarType: _vitalKey == 'sugar' ? 'random' : null,
      pulse: _vitalKey == 'pulse' ? primary : null,
    );
    // Local state + notifyListeners happen synchronously inside; the API
    // post that follows is fire-and-forget with tolerated failure (demo).
    unawaited(app.addVitalReading(reading));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = _status;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('add_reading'),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.hc.black),
          ),
          const SizedBox(height: 12),
          // Vital type selector — pre-selected to the active chart tab.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final key in _fields.keys) ...[
                  _typeChip(key),
                  if (key != _fields.keys.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_specs.length == 1)
            _field(0, _primary, l)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(0, _primary, l)),
                const SizedBox(width: 12),
                Expanded(child: _field(1, _secondary, l)),
              ],
            ),
          if (status != null) ...[
            const SizedBox(height: 12),
            _statusRow(status, l),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isValid ? _save : null,
              child: Text(l.t('save_reading')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String key) {
    final isSelected = _vitalKey == key;
    return ChoiceChip(
      label: Text(_typeLabels[key]!),
      selected: isSelected,
      onSelected: (_) => setState(() {
        if (_vitalKey == key) return;
        _vitalKey = key;
        _primary.clear();
        _secondary.clear();
      }),
      selectedColor: context.hc.orangeLight,
      checkmarkColor: context.hc.orangeText,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isSelected ? context.hc.orangeText : context.hc.grey,
      ),
      side: BorderSide(
        color: isSelected ? HousepitalColors.orange : context.hc.divider,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  // House form styling: label above, ~50pt input (theme contentPadding),
  // validator below via autovalidate.
  Widget _field(int index, TextEditingController controller,
      AppLocalizations l) {
    final spec = _specs[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t(spec.labelKey),
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.hc.grey),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: spec.decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                spec.decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]')),
            LengthLimitingTextInputFormatter(spec.decimal ? 5 : 3),
          ],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) => _validate(index, value),
        ),
      ],
    );
  }

  Widget _statusRow(String status, AppLocalizations l) {
    final Color color;
    final String label;
    if (status == 'red') {
      color = context.hc.error;
      label = l.t('vital_status_alert');
    } else if (status == 'yellow') {
      color = context.hc.warning;
      label = l.t('vital_status_borderline');
    } else {
      color = context.hc.success;
      label = l.t('vital_status_normal');
    }
    return Row(
      children: [
        Icon(status == 'green' ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 18, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
