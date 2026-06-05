import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/medication_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
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
          ? const Center(child: LoadingWidget())
          : medProv.error != null
              ? Center(child: Text(l.t('error_load_data')))
              : medProv.activeMedications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.medication_outlined,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('No medications added yet',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[600])),
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
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: med.isLowStock
              ? const Color(0xFFFDE68A)
              : const Color(0xFFE5E7EB),
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
        borderRadius: BorderRadius.circular(10),
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
                                fontSize: 12, color: Colors.grey[600])),
                        if (med.prescribedBy != null)
                          Text('Prescribed by ${med.prescribedBy}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, size: 16, color: Colors.grey),
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
                          color: const Color(0xFFFEFCE8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${med.stockCount} ${med.stockUnit ?? "units"} left — refill soon',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFCA8A04),
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${med.stockCount} ${med.stockUnit ?? "units"} left',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (med.daysOfSupplyLeft != null && !med.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Refill in ${med.daysOfSupplyLeft} days',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
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
