import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/medication_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
import '../../config/theme.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/common_widgets.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
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
      appBar: AppBar(
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
          final result = await Navigator.pushNamed(context, '/medication-add');
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
                            const Icon(Icons.medication_outlined,
                                size: 64, color: HousepitalColors.greyLight),
                            const SizedBox(height: 16),
                            const Text('No medications added yet',
                                style: TextStyle(
                                    fontSize: 16, color: HousepitalColors.grey)),
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
                        itemCount: medProv.activeMedications.length,
                        itemBuilder: (context, index) {
                          final med = medProv.activeMedications[index];
                          return _medicationCard(context, med, l, medProv);
                        },
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
              ? HousepitalColors.warning
              : HousepitalColors.divider,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(context, '/medication-add',
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
                            style: const TextStyle(
                                fontSize: 12, color: HousepitalColors.grey)),
                        if (med.prescribedBy != null)
                          Text('Prescribed by ${med.prescribedBy}',
                              style: const TextStyle(
                                  fontSize: 11, color: HousepitalColors.greyLight)),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, size: 16, color: HousepitalColors.greyLight),
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
                          color: HousepitalColors.warningLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${med.stockCount} ${med.stockUnit ?? "units"} left — refill soon',
                          style: const TextStyle(
                              fontSize: 12,
                              color: HousepitalColors.warning,
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HousepitalColors.successLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${med.stockCount} ${med.stockUnit ?? "units"} left',
                          style: const TextStyle(
                              fontSize: 12,
                              color: HousepitalColors.success,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (med.daysOfSupplyLeft != null && !med.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HousepitalColors.greyLighter,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Refill in ${med.daysOfSupplyLeft} days',
                          style: const TextStyle(
                              fontSize: 12, color: HousepitalColors.grey),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
