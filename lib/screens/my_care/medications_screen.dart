import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../../models/care_event.dart';
import '../../models/medication_models.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/medication_provider.dart';
import '../../config/app_colors.dart';
import '../../config/theme.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  /// Lazily-loaded pharmacy/equipment catalog (only fetched on first
  /// refill tap), mirroring equipment_tab's bundled-JSON fallback.
  List<EquipmentItem>? _catalog;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final patientId = context.read<AppProvider>().currentPatient?.id ?? 'pat_demo_rajesh';
      context.read<MedicationProvider>().loadMedications(patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final medProv = context.watch<MedicationProvider>();

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(l.t('medications')),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/medication-schedule'),
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(l.t('medication_schedule')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Route fix: registered route is '/add-medication' ('/medication-add'
          // fell through onGenerateRoute's default and opened MainShell).
          final result = await Navigator.pushNamed(context, '/add-medication');
          if (result == true) {
            if (!context.mounted) return;
            final patientId = context.read<AppProvider>().currentPatient?.id;
            if (patientId != null) {
              medProv.loadMedications(patientId);
            }
          }
        },
        child: const Icon(Icons.add),
      ),
      body: medProv.isLoading
          ? const LoadingWidget()
          : medProv.error != null
              ? ErrorRetryWidget(
                  message: l.t('error_load_data'),
                  onRetry: () {
                    final patientId =
                        context.read<AppProvider>().currentPatient?.id ??
                            'pat_demo_rajesh';
                    medProv.loadMedications(patientId);
                  },
                )
              : medProv.activeMedications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.medication_outlined,
                                size: 64, color: context.hc.greyLight),
                            const SizedBox(height: 16),
                            Text('No medications added yet',
                                style: TextStyle(
                                    fontSize: 16, color: context.hc.grey)),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        final patientId =
                            context.read<AppProvider>().currentPatient?.id;
                        if (patientId != null) {
                          await medProv.loadMedications(patientId);
                        }
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        // +1 for the weekly-adherence header card.
                        itemCount: medProv.activeMedications.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) return _adherenceHeader(context);
                          final med =
                              medProv.activeMedications[index - 1];
                          return _medicationCard(context, med, l, medProv);
                        },
                      ),
                    ),
    );
  }

  // ── Weekly adherence header (deterministic demo calc) ──────────────────
  // Tapping the card opens the Care Calendar (full history + day detail).
  Widget _adherenceHeader(BuildContext context) {
    final pct = weeklyAdherencePercent();
    final perDay = dosesPerDay();
    final weekTotal = perDay * 7;
    final weekTaken = (weekTotal * pct / 100).round();
    final today = dateOnly(DateTime.now());

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/care-calendar'),
      child: HousepitalCard(
        child: Row(
          children: [
            const AppIconTile(
                icon: Icons.task_alt, color: HousepitalColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("This week's adherence",
                      style: TextStyle(fontSize: 12, color: context.hc.grey)),
                  const SizedBox(height: 2),
                  Text('$pct% · $weekTaken of $weekTotal doses',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  // 7 day-dots, oldest → today. Deterministic demo state:
                  // success = full adherence day, warning = partial.
                  Row(
                    children: List.generate(7, (i) {
                      final day = today.subtract(Duration(days: 6 - i));
                      final full = adherencePercentFor(day) >= 90;
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: full
                              ? context.hc.success
                              : context.hc.warning,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: context.hc.grey),
          ],
        ),
      ),
    );
  }

  // ── Refill quick action ─────────────────────────────────────────────────

  /// Case-insensitive lookup of the medication in the bundled pharmacy /
  /// equipment catalog (loaded lazily, like equipment_tab).
  Future<EquipmentItem?> _findCatalogItem(String medName) async {
    try {
      _catalog ??=
          (json.decode(await rootBundle.loadString(
                      'assets/equipment_catalog.json')) as List)
              .map((e) => EquipmentItem.fromJson(e as Map<String, dynamic>))
              .toList();
    } catch (_) {
      return null;
    }
    // Case-insensitive CONTAINS match either way round, so "Insulin" finds
    // "Insulin Syringes 1ml" and "Paracetamol 500mg" finds "Paracetamol".
    final q = medName.toLowerCase().trim();
    for (final item in _catalog!) {
      final n = item.name.toLowerCase().trim();
      if (n.contains(q) || q.contains(n)) return item;
    }
    return null;
  }

  Future<void> _onRefillTap(MedicationFull med) async {
    final medProv = context.read<MedicationProvider>();
    final patientId =
        context.read<AppProvider>().currentPatient?.id ?? 'pat_demo_rajesh';

    // If the medicine is sold in our catalog, add it straight to the cart.
    final catalogItem = await _findCatalogItem(med.name);
    if (!mounted) return;
    if (catalogItem != null) {
      context.read<CartProvider>().addItem(catalogItem);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart for refill')),
      );
      return;
    }

    // Otherwise route the request to the Health Manager via the concerns API.
    await medProv.requestRefill(patientId, med);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Refill request sent to your Health Manager')),
    );
  }

  Widget _refillAction(BuildContext context, MedicationFull med,
      MedicationProvider medProv) {
    if (medProv.isRefillRequested(med.id)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: context.hc.success),
          const SizedBox(width: 6),
          Text(
            'Refill requested ✓',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.hc.success,
            ),
          ),
        ],
      );
    }
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: () => _onRefillTap(med),
        icon: const Icon(Icons.local_pharmacy, size: 16),
        label: const Text('Request refill',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.hc.orangeText,
          side: BorderSide(color: HousepitalColors.orange),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  Widget _medicationCard(BuildContext context, MedicationFull med,
      AppLocalizations l, MedicationProvider medProv) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: med.isLowStock
              ? context.hc.warning
              : context.hc.divider,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(context, '/add-medication',
              arguments: med);
          if (result == true) {
            if (!context.mounted) return;
            final patientId = context.read<AppProvider>().currentPatient?.id;
            if (patientId != null) medProv.loadMedications(patientId);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${med.name} ${med.dosage}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                            '${med.form} · ${med.frequencyLabel} · ${med.instructions ?? ""}',
                            style: TextStyle(
                                fontSize: 12, color: context.hc.grey)),
                        if (med.prescribedBy != null)
                          Text('Prescribed by ${med.prescribedBy}',
                              style: TextStyle(
                                  fontSize: 11, color: context.hc.greyLight)),
                      ],
                    ),
                  ),
                  Icon(Icons.edit, size: 16, color: context.hc.greyLight),
                ],
              ),
              if (med.stockCount != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    if (med.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.hc.warningLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${med.stockCount} ${med.stockUnit ?? "units"} left — refill soon',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.hc.warning,
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.hc.successLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${med.stockCount} ${med.stockUnit ?? "units"} left',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.hc.success,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (med.daysOfSupplyLeft != null && !med.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.hc.greyLighter,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Refill in ${med.daysOfSupplyLeft} days',
                          style: TextStyle(
                              fontSize: 12, color: context.hc.grey),
                        ),
                      ),
                  ],
                ),
              ],
              if (med.isLowStock) ...[
                const SizedBox(height: 8),
                _refillAction(context, med, medProv),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
