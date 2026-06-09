// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/daimaa_theme.dart';
import '../../../config/theme.dart';
import '../../../config/app_colors.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/permissions.dart';
import '../../../widgets/common_widgets.dart';
import '../data/staff_roles_seed.dart';
import '../widgets/permission_dialogs.dart';

/// Card surfaced in the Manpower tab summarising one staff role
/// (Caretaker, Nurse, Japa Maid, Nanny, Physiotherapist).
///
/// Tapping the card opens a bottom sheet detailing the full scope of service
/// across each level, with a "Request Assessment" CTA.
class StaffRoleCard extends StatelessWidget {
  final StaffRole role;
  final List<ServiceItem> services;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const StaffRoleCard({
    super.key,
    required this.role,
    required this.services,
    required this.onNavigate,
  });

  bool get _isDaiMaa => role.title == 'Japa Maid' || role.title == 'Nanny';

  Color get _roleColor {
    switch (role.title) {
      case 'Nurse':
        return HousepitalColors.serviceNursing;
      case 'Caretaker':
        return HousepitalColors.serviceCaretaker;
      case 'Japa Maid':
      case 'Nanny':
        // Dai Maa sub-brand — use plum so the role inherits brand color
        return DaiMaaColors.plum;
      case 'Physiotherapist':
        return HousepitalColors.servicePhysio;
      default:
        return HousepitalColors.serviceNursing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: context.hc.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: _isDaiMaa
            ? DaiMaaColors.plum.withValues(alpha: 0.18)
            : Colors.black12,
        child: InkWell(
          onTap: () => _showRoleDetail(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: _isDaiMaa
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: DaiMaaColors.plum, width: 1.5),
                  )
                : null,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    AppIconTile(icon: role.icon, color: color),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  role.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _isDaiMaa
                                        ? DaiMaaColors.plum
                                        : context.hc.black,
                                  ),
                                ),
                              ),
                              if (_isDaiMaa) ...[
                                const SizedBox(width: 8),
                                const DaiMaaBadge(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.hc.greyLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 14, color: HousepitalColors.orange),
                              const SizedBox(width: 3),
                              Text(
                                '${role.rating}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.hc.grey,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${role.reviewCount} reviews)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.hc.greyLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: context.hc.greyLight, size: 22),
                  ],
                ),
                const SizedBox(height: 8),
                // Shift chips
                Row(
                  children: role.availableShifts.map((shift) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: color.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          shift,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRoleDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  AppIconTile(
                      icon: role.icon, color: HousepitalColors.orange),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.hc.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          role.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.hc.greyLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Rating
              Row(
                children: [
                  const Icon(Icons.star,
                      size: 18, color: HousepitalColors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '${role.rating}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.hc.black,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${role.reviewCount} reviews)',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.hc.greyLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Available shifts
              Text(
                'Available Options',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.hc.black,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: role.availableShifts
                    .map((shift) => Chip(
                          label: Text(shift),
                          avatar: const Icon(Icons.schedule,
                              size: 16,
                              color: HousepitalColors.orange),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Scope of Service — level-based
              Text(
                'Scope of Service',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.hc.black,
                ),
              ),
              const SizedBox(height: 10),
              ...role.levels.map((level) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (role.levels.length > 1) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.hc.orangeLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            level.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.hc.orangeText,
                            ),
                          ),
                        ),
                      ],
                      // Included services
                      ...level.included.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(Icons.check_circle,
                                      size: 16,
                                      color: context.hc.success),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    r,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.hc.grey,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      // Excluded services
                      if (level.excluded.isNotEmpty) ...[
                        ...level.excluded.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Icon(Icons.cancel,
                                        size: 16,
                                        // audit M-19: withOpacity → withValues (deprecated since Flutter 3.27)
                                        color: context.hc.greyLight
                                            .withValues(alpha: 0.5)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      r,
                                      style: TextStyle(
                                        fontSize: 14,
                                        // audit M-19: withOpacity → withValues (deprecated since Flutter 3.27)
                                        color: context.hc.greyLight
                                            .withValues(alpha: 0.7),
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      if (role.levels.length > 1)
                        const SizedBox(height: 12),
                    ],
                  )),
              const SizedBox(height: 16),

              // Trust badges
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.hc.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user,
                            size: 16, color: context.hc.success),
                        SizedBox(width: 8),
                        Text(
                          'Background verified & Aadhaar checked',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.hc.success,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.shield,
                            size: 16, color: context.hc.success),
                        SizedBox(width: 8),
                        Text(
                          'Police verification completed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.hc.success,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.school,
                            size: 16, color: context.hc.success),
                        SizedBox(width: 8),
                        Text(
                          'Housepital trained & certified',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.hc.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Request Assessment button — gated by booking permission so
              // family members get the "request booking" stub instead.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final matchingService = services.firstWhere(
                      (s) => s.name.toLowerCase().contains(
                          role.title.toLowerCase().split(' ').first),
                      orElse: () => services.first,
                    );
                    final userRole =
                        context.read<AppProvider>().currentUserRole;
                    if (!canUserPerform(userRole, UserAction.book)) {
                      if (canUserPerform(
                          userRole, UserAction.requestBooking)) {
                        showRequestBookingStub(
                            context, matchingService.name);
                      } else {
                        showViewOnlyToast(context);
                      }
                      return;
                    }
                    // Push first (context still valid), sheet auto-dismisses
                    Navigator.of(context).pushNamed('/assessment-request',
                        arguments: matchingService);
                  },
                  child: const Text('Request Assessment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
