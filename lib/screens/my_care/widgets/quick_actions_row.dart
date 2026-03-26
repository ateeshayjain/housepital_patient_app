// lib/screens/my_care/widgets/quick_actions_row.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../utils/app_localizations.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _tile(
            context,
            icon: Icons.warning_amber_rounded,
            label: l.t('raise_concern'),
            subtitle: l.t('staff_service_billing'),
            color: HousepitalColors.error,
            bgColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
            onTap: () => Navigator.pushNamed(context, '/raise-concern'),
          ),
          const SizedBox(width: 10),
          _tile(
            context,
            icon: Icons.assignment_outlined,
            label: l.t('daily_reports'),
            subtitle: l.t('view_all_reports'),
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
            onTap: () => Navigator.pushNamed(context, '/report-history',
                arguments: ''), // TODO: pass primary deploymentId
          ),
          const SizedBox(width: 10),
          _tile(
            context,
            icon: Icons.description_outlined,
            label: l.t('documents'),
            subtitle: l.t('prescriptions_reports'),
            color: HousepitalColors.success,
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
            onTap: () => Navigator.pushNamed(context, '/documents'),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ),
        ),
      ),
    );
  }
}
