// lib/screens/my_care/widgets/equipment_deployed_section.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/my_care_models.dart';
import '../../../utils/app_localizations.dart';
import '../../../utils/helpers.dart';
import '../../../widgets/common_widgets.dart';

class EquipmentDeployedSection extends StatelessWidget {
  final List<EquipmentDeployed> equipment;

  const EquipmentDeployedSection({super.key, required this.equipment});

  @override
  Widget build(BuildContext context) {
    if (equipment.isEmpty) return const SizedBox.shrink();

    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('equipment_deployed'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...equipment.map((eq) => Card(
                child: ListTile(
                  leading: const Icon(Icons.medical_services_outlined,
                      color: HousepitalColors.serviceEquipment),
                  title: Text(eq.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${DateHelper.formatCurrency(eq.monthlyRate)}/month · Since ${DateHelper.formatDateShort(eq.startDate)}'),
                  trailing: StatusBadge(
                    text: eq.status == 'active' ? 'Active' : 'Returned',
                    color: eq.status == 'active'
                        ? HousepitalColors.success
                        : Colors.grey,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
