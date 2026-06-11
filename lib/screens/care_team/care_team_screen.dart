// lib/screens/care_team/care_team_screen.dart
//
// Care Team Hub — a single place where all queries get resolved: the
// patient's full care group (Health Manager, Supervisor, Doctor, on-duty
// staff) with one-tap Call / Chat per member, plus a visually distinct
// 24x7 Ambulance emergency row at the bottom.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../data/demo_data.dart';
import '../../providers/app_provider.dart';
import '../../providers/my_care_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';

class CareTeamScreen extends StatelessWidget {
  const CareTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final myCare = context.watch<MyCareProvider>();

    final patient = app.currentPatient ?? DemoData.patient;
    final patientId = app.currentPatient?.id ?? 'pat_demo_rajesh';
    final supervisor = DemoData.supervisor;

    final members = <_CareTeamMember>[
      _CareTeamMember(
        name: myCare.healthManager?.name ?? 'Housepital Care Team',
        role: 'Health Manager',
        phone: AppConstants.supportPhone,
        icon: Icons.support_agent,
        color: HousepitalColors.orange,
      ),
      _CareTeamMember(
        name: supervisor.name,
        role: supervisor.role,
        phone: supervisor.phone,
        icon: Icons.admin_panel_settings,
        color: context.hc.info,
      ),
      if (patient.doctorName != null && patient.doctorName!.isNotEmpty)
        _CareTeamMember(
          name: patient.doctorName!,
          role: 'Doctor',
          phone: patient.doctorPhone ?? AppConstants.supportPhone,
          icon: Icons.medical_information,
          color: HousepitalColors.servicePhysio,
        ),
      // On-duty staff — one row per active service with staff deployed.
      // ActiveService carries only staff counts; when the globally loaded
      // active deployment belongs to a service, surface the actual person.
      ...myCare.activeServices.where((s) => s.hasStaff).map((s) {
        final dep = app.activeDeployment;
        final depMatches = dep != null &&
            s.deploymentIds.contains(dep.id) &&
            dep.staffName != null;
        return _CareTeamMember(
          name: depMatches ? dep.staffName! : s.name,
          role: depMatches
              ? (dep.staffRole ?? 'On-duty staff')
              : 'On-duty staff',
          phone: AppConstants.supportPhone,
          icon: Icons.medical_services,
          color: HousepitalColors.serviceNursing,
        );
      }),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Care Team')),
      // Horizontal padding lives on each child (not the ListView) so the
      // canonical SectionHeader — which carries its own 16px horizontal
      // padding — aligns flush with the cards instead of double-indenting.
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // Group chat FIRST: one tap reaches the whole team — queries get
          // resolved in one place; individual message/call options follow.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HousepitalCard(
              onTap: () => Navigator.pushNamed(context, '/chat', arguments: {
                'patientId': patientId,
                'coordinatorName': 'Care Team',
              }),
              child: Row(
                children: [
                  const AppIconTile(
                      icon: Icons.groups, color: HousepitalColors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Care Team Group Chat',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: context.hc.black)),
                        const SizedBox(height: 2),
                        Text('One place for all your queries',
                            style: TextStyle(
                                fontSize: 12, color: context.hc.greyLight)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Open care team group chat',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/chat', arguments: {
                        'patientId': patientId,
                        'coordinatorName': 'Care Team',
                      }),
                      icon: const Icon(Icons.forum, size: 18),
                      label: const Text('Chat'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          ...members.map((m) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _MemberRow(member: m, patientId: patientId),
              )),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _AmbulanceCard(),
          ),

          // ── Past staff — read-only history (no call/chat: they are no
          // longer deployed with this patient). Canonical SectionHeader; it
          // carries its own 16px horizontal padding, which is why the ListView
          // pads children individually instead of globally.
          const SizedBox(height: 12),
          const SectionHeader(title: 'Past staff'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HousepitalCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (var i = 0; i < DemoData.pastStaff.length; i++) ...[
                    if (i > 0) const Divider(height: 16),
                    _PastStaffRow(staff: DemoData.pastStaff[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only row for a previously deployed staff member: history icon tile,
/// name, role · period, and the engagement note. Deliberately NO call/chat.
class _PastStaffRow extends StatelessWidget {
  final Map<String, String> staff;

  const _PastStaffRow({required this.staff});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconTile(icon: Icons.history, color: context.hc.greyLight),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                staff['name'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.hc.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${staff['role']} · ${staff['period']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.hc.greyLight),
              ),
              if ((staff['note'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  staff['note']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.hc.grey),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CareTeamMember {
  final String name;
  final String role;
  final String phone;
  final IconData icon;
  final Color color;

  const _CareTeamMember({
    required this.name,
    required this.role,
    required this.phone,
    required this.icon,
    required this.color,
  });
}

class _MemberRow extends StatelessWidget {
  final _CareTeamMember member;
  final String patientId;

  const _MemberRow({required this.member, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return HousepitalCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AppIconTile(icon: member.icon, color: member.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.hc.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.hc.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Call ${member.role}',
            button: true,
            child: IconButton(
              onPressed: () => launchUrl(Uri.parse('tel:${member.phone}')),
              style: IconButton.styleFrom(
                backgroundColor: HousepitalColors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.phone, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            label: 'Chat with ${member.role}',
            button: true,
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/chat', arguments: {
                  'patientId': patientId,
                  'coordinatorName': member.name,
                });
              },
              style: IconButton.styleFrom(
                backgroundColor: context.hc.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: context.hc.divider),
                ),
              ),
              icon: Icon(Icons.chat_bubble_outline,
                  size: 20, color: context.hc.black),
            ),
          ),
        ],
      ),
    );
  }
}

/// Emergency row — visually distinct (error-themed), CALL only, never a chat
/// button: in an emergency the only correct affordance is dialing.
class _AmbulanceCard extends StatelessWidget {
  const _AmbulanceCard();

  @override
  Widget build(BuildContext context) {
    // Deliberately distinct error-tinted fill + border (this card SHOULD
    // stand apart from the white cards) — but it shares the canonical
    // squircle-16 continuous-corner shape of every top-level card.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: context.hc.errorLight,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.hc.error),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(icon: Icons.emergency, color: context.hc.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ambulance — 24x7 Emergency',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.hc.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConstants.emergencyPhone,
                      style: TextStyle(
                          fontSize: 12, color: context.hc.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Call ambulance, 24x7 emergency',
            button: true,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => launchUrl(
                    Uri.parse('tel:${AppConstants.emergencyPhone}')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.hc.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1),
                ),
                icon: const Icon(Icons.phone, size: 20),
                label: const Text('CALL'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
