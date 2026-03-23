import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/medication_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
import '../../services/medication_reminder_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

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
      appBar: AppBar(title: Text(l.t('medication_schedule'))),
      body: medProv.isLoading
          ? const Center(child: LoadingWidget())
          : medProv.error != null
              ? Center(child: Text(l.t('error_load_data')))
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
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 10),
              Text(
                'All medications taken for today!',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[800],
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
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active,
              color: Color(0xFFF97316), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Next reminder: ${nextReminder.medicationName} ${nextReminder.dosage} at ${_formatSlotTime(nextReminder.time)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A3412),
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
                      ? HousepitalColors.success
                      : HousepitalColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...slot.medications.map((sm) => _medItem(sm)),
        ],
      ),
    );
  }

  Widget _medItem(ScheduledMedication sm) {
    final isGiven = sm.log?.wasGiven ?? false;
    final isMissed = sm.log?.wasMissed ?? false;

    Color bgColor;
    Color borderColor;
    if (isGiven) {
      bgColor = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFFBBF7D0);
    } else if (isMissed) {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
    } else {
      bgColor = const Color(0xFFF9FAFB);
      borderColor = const Color(0xFFE5E7EB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 28),
      padding: const EdgeInsets.all(10),
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
                ? HousepitalColors.success
                : isMissed
                    ? HousepitalColors.error
                    : Colors.grey[400],
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
                          ? Colors.grey[400]
                          : Colors.grey[900],
                    )),
                Text('${sm.medication.form} · ${sm.medication.instructions ?? ""}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          if (isGiven && sm.log != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    'Given ${DateHelper.formatTime(sm.log!.actualTime ?? sm.log!.scheduledTime)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF16A34A))),
                if (sm.log!.staffName != null)
                  Text('by ${sm.log!.staffName}',
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            )
          else if (!isGiven && !isMissed)
            Text(l.t('scheduled'),
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ],
      ),
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
