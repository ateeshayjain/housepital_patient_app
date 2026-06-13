import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:provider/provider.dart';
import '../../models/care_event.dart';
import '../../models/medication_models.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/medication_provider.dart';
import '../../services/handover_report_service.dart';
import '../../config/app_colors.dart';
import '../../utils/app_localizations.dart';
import '../../utils/permissions.dart';
import '../../widgets/care_pulse_ring.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/empty_state.dart';
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
      final patientId =
          context.read<AppProvider>().currentPatient?.id ?? 'pat_demo_rajesh';
      context.read<MedicationProvider>().loadMedications(patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final medProv = context.watch<MedicationProvider>();
    final role = context.watch<AppProvider>().currentUserRole;

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(l.t('medications')),
        actions: [
          // Doctor Handover Report — same share as the My Care entry card.
          // audit R2: role-gated like the My Care card — hidden entirely for
          // roles that may not export the full medical history.
          if (canUserPerform(role, UserAction.shareHandover))
            IconButton(
              tooltip: 'Share Doctor Handover Report',
              icon: const Icon(Icons.ios_share, size: 20),
              onPressed: () => HandoverReportService().shareHandover(),
            ),
          TextButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/medication-schedule'),
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
          ? HousepitalEmptyState(
              icon: Icons.medication_outlined,
              title: l.t('meds_empty_title'),
              body: l.t('meds_empty_body'),
            )
          : RefreshIndicator(
              onRefresh: () async {
                final patientId = context
                    .read<AppProvider>()
                    .currentPatient
                    ?.id;
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
                  final med = medProv.activeMedications[index - 1];
                  return _medicationCard(context, med, l, medProv);
                },
              ),
            ),
    );
  }

  // ── Weekly adherence header ─────────────────────────────────────────────
  // Visual: a 56px progress ring with the % inside (left) + the week's dose
  // count and a labelled 7-day dot row (right). Past 6 days keep the seeded
  // demo calc; TODAY is live MedicationProvider state so the single-tap
  // "Log dose" action visibly moves the ring, the dose line and today's dot.
  // Tapping the card still opens the Care Calendar.
  Widget _adherenceHeader(BuildContext context) {
    final medProv = context.watch<MedicationProvider>();
    final perDay = dosesPerDay();
    final weekTotal = perDay * 7;
    final today = dateOnly(DateTime.now());
    var weekTaken = 0;
    for (var i = 1; i <= 6; i++) {
      final day = today.subtract(Duration(days: i));
      weekTaken += (perDay * adherencePercentFor(day) / 100).round();
    }
    final todayTaken = medProv.dosesMarkedTakenToday.clamp(0, perDay);
    weekTaken += todayTaken;
    final pct = weekTotal == 0 ? 0 : (weekTaken * 100 / weekTotal).round();
    // Weekday initials/names indexed by DateTime.weekday - 1 (Mon=1 … Sun=7).
    const dayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    // HousepitalCard(onTap:) — not a bare GestureDetector wrapper — so the
    // card keeps its press-scale feedback and tap Semantics.
    return HousepitalCard(
      onTap: () => Navigator.pushNamed(context, '/care-calendar'),
      child: Row(
        children: [
          // 56px Care Pulse adherence ring with the percentage centred inside.
          CarePulseRing(
            value: pct / 100,
            size: 56,
            strokeWidth: 6,
            semanticLabel: '$pct percent weekly adherence',
            center: Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "This week's adherence",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$weekTaken of $weekTotal doses',
                  style: TextStyle(fontSize: 12, color: context.hc.greyLight),
                ),
                const SizedBox(height: 8),
                // 7-day row, oldest → today: weekday initial above a dot.
                // Deterministic demo state: full adherence = FILLED green
                // circle, partial = OUTLINED orange ring (shape + colour,
                // never colour alone; same seeded calc as Care Calendar).
                Row(
                  children: List.generate(7, (i) {
                    final day = today.subtract(Duration(days: 6 - i));
                    // Today's dot is live provider state; past days seeded.
                    final full = i == 6
                        ? perDay > 0 && todayTaken >= perDay
                        : adherencePercentFor(day) >= 90;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dayInitials[day.weekday - 1],
                            style: TextStyle(
                              fontSize: 11,
                              color: context.hc.greyLight,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Semantics(
                            label:
                                '${dayNames[day.weekday - 1]}: '
                                '${full ? 'full' : 'partial'} adherence',
                            child: Icon(
                              full ? Icons.circle : Icons.circle_outlined,
                              size: 8,
                              color: full
                                  ? context.hc.success
                                  : context.hc.warning,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Single-tap dose logging (owner request) ─────────────────────────────
  // One tap on the pill logs today's next pending dose for the med — no
  // navigation, no dialog. Pill → "Logged ✓" morph uses the same 200ms
  // scale+fade mark-taken ceremony as the Care Calendar dose rows.
  Widget _logDoseAction(
    BuildContext context,
    MedicationFull med,
    AppLocalizations l,
    MedicationProvider medProv,
  ) {
    if (med.timeSlots.isEmpty) return const SizedBox.shrink();
    final pending = medProv.nextPendingSlotToday(med.id);
    final total = med.timeSlots.length;
    final logged = med.timeSlots
        .where((s) => medProv.isSlotLoggedToday(med.id, s))
        .length;

    final Widget child;
    if (pending == null) {
      // All of today's doses logged — done state instead of the pill.
      child = Semantics(
        key: ValueKey('dose-logged-${med.id}'),
        label: 'All doses logged today for ${med.name}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: context.hc.success),
            const SizedBox(width: 6),
            Text(
              l.t('logged_done'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.hc.success,
              ),
            ),
          ],
        ),
      );
    } else {
      // Tonal stadium pill (doctor_advice_card _pillStyle grammar): small
      // visual, padded Material tap target keeps the area ≥ 44pt. Keyed on
      // the pending slot so multi-dose meds re-fire the morph on each log.
      child = Row(
        key: ValueKey('dose-pending-${med.id}-$pending'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Log dose for ${med.name}',
            button: true,
            child: FilledButton.tonalIcon(
              onPressed: () {
                HapticFeedback.lightImpact();
                medProv.logNextDoseToday(med.id);
              },
              icon: const Icon(Icons.check, size: 16),
              label: Text(l.t('log_dose')),
              style: FilledButton.styleFrom(
                backgroundColor: context.hc.orangeLight,
                foregroundColor: context.hc.orangeText,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.padded,
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (logged > 0) ...[
            const SizedBox(width: 8),
            Text(
              l.t('logged_today_count',
                  {'n': '$logged', 'm': '$total'}),
              style: TextStyle(fontSize: 12, color: context.hc.greyLight),
            ),
          ],
        ],
      );
    }

    return AnimatedSwitcher(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }

  // ── Refill quick action ─────────────────────────────────────────────────

  /// Case-insensitive lookup of the medication in the bundled pharmacy /
  /// equipment catalog (loaded lazily, like equipment_tab).
  Future<EquipmentItem?> _findCatalogItem(String medName) async {
    try {
      _catalog ??=
          (json.decode(
                    await rootBundle.loadString(
                      'assets/equipment_catalog.json',
                    ),
                  )
                  as List)
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to cart for refill')));
      return;
    }

    // Otherwise route the request to the Health Manager via the concerns API.
    await medProv.requestRefill(patientId, med);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refill request sent to your Health Manager'),
      ),
    );
  }

  Widget _refillAction(
    BuildContext context,
    MedicationFull med,
    MedicationProvider medProv,
  ) {
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
    // Tonal stadium pill (matches doctor_advice_card's add/book grammar):
    // small visual, padded Material tap target keeps the area ≥ 44pt.
    return FilledButton.tonalIcon(
      onPressed: () => _onRefillTap(med),
      icon: const Icon(Icons.local_pharmacy, size: 16),
      label: const Text('Request refill'),
      style: FilledButton.styleFrom(
        backgroundColor: context.hc.orangeLight,
        foregroundColor: context.hc.orangeText,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _medicationCard(
    BuildContext context,
    MedicationFull med,
    AppLocalizations l,
    MedicationProvider medProv,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: med.isLowStock ? context.hc.warning : context.hc.divider,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            '/add-medication',
            arguments: med,
          );
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
                        Text(
                          '${med.name} ${med.dosage}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${med.form} · ${med.frequencyLabel} · ${med.instructions ?? ""}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.hc.grey,
                          ),
                        ),
                        if (med.prescribedBy != null)
                          Text(
                            'Prescribed by ${med.prescribedBy}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.hc.greyLight,
                            ),
                          ),
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
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.hc.warningLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${med.stockCount} ${med.stockUnit ?? "units"} left — refill soon',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.hc.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.hc.successLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${med.stockCount} ${med.stockUnit ?? "units"} left',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.hc.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (med.daysOfSupplyLeft != null && !med.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.hc.greyLighter,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Refill in ${med.daysOfSupplyLeft} days',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.hc.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (med.timeSlots.isNotEmpty) ...[
                const SizedBox(height: 8),
                _logDoseAction(context, med, l, medProv),
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
