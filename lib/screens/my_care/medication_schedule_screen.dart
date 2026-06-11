import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/theme.dart';
import '../../models/medication_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
import '../../services/medication_reminder_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';

class MedicationScheduleScreen extends StatefulWidget {
  const MedicationScheduleScreen({super.key});

  @override
  State<MedicationScheduleScreen> createState() =>
      _MedicationScheduleScreenState();
}

class _MedicationScheduleScreenState extends State<MedicationScheduleScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final patientId = context.read<AppProvider>().currentPatient?.id;
      if (patientId != null) {
        context.read<MedicationProvider>().loadTodaySchedule(patientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final medProv = context.watch<MedicationProvider>();

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(l.t('medication_schedule')),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Care Calendar',
            onPressed: () => Navigator.pushNamed(context, '/care-calendar'),
          ),
        ],
      ),
      body: medProv.isLoading
          ? const LoadingWidget()
          : medProv.error != null
              ? ErrorRetryWidget(
                  message: l.t('error_load_data'),
                  onRetry: () {
                    final patientId =
                        context.read<AppProvider>().currentPatient?.id;
                    if (patientId != null) {
                      medProv.loadTodaySchedule(patientId);
                    }
                  },
                )
              : medProv.schedule.isEmpty
                  ? const Center(child: Text('No medications scheduled today'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        final patientId =
                            context.read<AppProvider>().currentPatient?.id;
                        if (patientId != null) {
                          await medProv.loadTodaySchedule(patientId);
                        }
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _nextReminderCard(medProv),
                          ...medProv.schedule
                              .map((slot) => _slotSection(slot, l)),
                        ],
                      ),
                    ),
    );
  }

  Widget _nextReminderCard(MedicationProvider medProv) {
    final nextReminder = MedicationReminderService.getNextReminder(
      medProv.activeMedications,
    );

    if (nextReminder == null) {
      // Check if all slots are in the past — show "All done" card
      final allTaken = medProv.schedule.every((s) => s.allGiven);
      if (medProv.schedule.isNotEmpty && allTaken) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.hc.successLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.hc.successLight),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: context.hc.success, size: 20),
              const SizedBox(width: 8),
              Text(
                'All medications taken for today!',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.hc.success,
                ),
              ),
            ],
          ),
        );
      }

      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.hc.orangeLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hc.orangeLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active,
              color: HousepitalColors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Next reminder: ${nextReminder.medicationName} ${nextReminder.dosage} at ${_formatSlotTime(nextReminder.time)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.hc.orangeText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotSection(MedicationScheduleSlot slot, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(slot.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('${slot.label} — ${_formatSlotTime(slot.time)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                slot.summaryLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: slot.allGiven
                      ? context.hc.success
                      : HousepitalColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...slot.medications.map((sm) => _medItem(sm, slot.time)),
        ],
      ),
    );
  }

  Widget _medItem(ScheduledMedication sm, String slotTime) {
    final isGiven = sm.log?.wasGiven ?? false;
    final isMissed = sm.log?.wasMissed ?? false;

    Color bgColor;
    Color borderColor;
    if (isGiven) {
      bgColor = context.hc.successLight;
      borderColor = context.hc.successLight;
    } else if (isMissed) {
      bgColor = context.hc.errorLight;
      borderColor = context.hc.errorLight;
    } else {
      bgColor = context.hc.greyLighter;
      borderColor = context.hc.divider;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 28),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isGiven
                ? Icons.check
                : isMissed
                    ? Icons.warning_amber
                    : Icons.radio_button_unchecked,
            size: 16,
            color: isGiven
                ? context.hc.success
                : isMissed
                    ? context.hc.error
                    : context.hc.greyLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${sm.medication.name} ${sm.medication.dosage}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sm.isPast && !isGiven
                          ? context.hc.greyLight
                          : context.hc.black,
                    )),
                Text('${sm.medication.form} · ${sm.medication.instructions ?? ""}',
                    style: TextStyle(fontSize: 11, color: context.hc.greyLight)),
              ],
            ),
          ),
          _medTrailing(sm, slotTime),
        ],
      ),
    );
  }

  /// Trailing affordance for a dose row. Pending (no log) doses get the
  /// single-tap "Log dose" tonal pill (Care Calendar mark-taken grammar);
  /// the pill → "Given" swap shares the calendar's 200ms scale+fade
  /// ceremony. Given doses show who/when; missed doses show nothing extra.
  Widget _medTrailing(ScheduledMedication sm, String slotTime) {
    final isGiven = sm.log?.wasGiven ?? false;
    final isMissed = sm.log?.wasMissed ?? false;
    final med = sm.medication;

    final Widget child;
    if (isGiven && sm.log != null) {
      child = Column(
        key: ValueKey('given-${med.id}-$slotTime'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
              'Given ${DateHelper.formatTime(sm.log!.actualTime ?? sm.log!.scheduledTime)}',
              style: TextStyle(fontSize: 11, color: context.hc.success)),
          if (sm.log!.staffName != null)
            Text('by ${sm.log!.staffName}',
                style: TextStyle(fontSize: 11, color: context.hc.greyLight)),
        ],
      );
    } else if (isMissed) {
      // Missed — row icon/colour already says it; no trailing (as before).
      child = SizedBox.shrink(key: ValueKey('missed-${med.id}-$slotTime'));
    } else if (sm.log != null) {
      // Skipped — already resolved by staff; keep the plain label.
      child = Text(l.t('scheduled'),
          key: ValueKey('resolved-${med.id}-$slotTime'),
          style: TextStyle(fontSize: 11, color: context.hc.greyLight));
    } else {
      // Pending — tonal stadium pill (doctor_advice_card _pillStyle
      // grammar): small visual, padded tap target keeps the area ≥ 44pt.
      child = Semantics(
        key: ValueKey('log-${med.id}-$slotTime'),
        label: 'Log dose for ${med.name}',
        button: true,
        child: FilledButton.tonalIcon(
          onPressed: () {
            HapticFeedback.lightImpact();
            context.read<MedicationProvider>().logDoseToday(med.id, slotTime);
          },
          icon: const Icon(Icons.check, size: 16),
          label: Text(l.t('log_dose')),
          style: FilledButton.styleFrom(
            backgroundColor: context.hc.orangeLight,
            foregroundColor: context.hc.orangeText,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
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

  AppLocalizations get l => AppLocalizations.of(context)!;

  String _formatSlotTime(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:$minute $period';
  }
}
