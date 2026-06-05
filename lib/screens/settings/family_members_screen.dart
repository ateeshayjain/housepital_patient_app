import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/permissions.dart';
import '../../widgets/common_widgets.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  static final _mockMembers = [
    FamilyMember.fromJson({
      'id': 'fm1',
      'user_id': 'u1',
      'patient_id': 'p1',
      'name': 'Suresh Kumar',
      'phone': '+919876543210',
      'email': 'suresh@email.com',
      'relationship': 'Son',
      'role': 'PRIMARY_CONTACT',
      'preferred_language': 'en',
    }),
    FamilyMember.fromJson({
      'id': 'fm2',
      'user_id': 'u2',
      'patient_id': 'p1',
      'name': 'Meena Kumar',
      'phone': '+919876543211',
      'relationship': 'Daughter',
      'role': 'FAMILY_MEMBER',
      'preferred_language': 'hi',
    }),
  ];

  late List<FamilyMember> _members;

  @override
  void initState() {
    super.initState();
    _members = List.from(_mockMembers);
  }

  // audit M-13: migrated to shared confirmDestructiveAction helper for
  // consistent red CTA, haptic, and copy across destructive flows.
  Future<void> _showDeleteConfirmation(FamilyMember member) async {
    final ok = await confirmDestructiveAction(
      context,
      title: 'Remove family member?',
      message: 'Are you sure you want to remove ${member.name}?',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    setState(() {
      _members.removeWhere((m) => m.id == member.id);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${member.name} removed')),
    );
  }

  void _showAddMemberSheet(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String relationship = 'Son';
    bool notifyVitals = true;
    bool notifyAttendance = true;
    bool notifyReports = true;
    bool notifyBilling = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Family Member',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: HousepitalColors.black,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixText: '+91 ',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone is required';
                    if (v.trim().length != 10) return 'Enter a valid 10-digit number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email (optional)'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !v.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: relationship,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                  items: const [
                    DropdownMenuItem(value: 'Son', child: Text('Son')),
                    DropdownMenuItem(value: 'Daughter', child: Text('Daughter')),
                    DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                    DropdownMenuItem(value: 'Sibling', child: Text('Sibling')),
                    DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) {
                    if (v != null) setSheetState(() => relationship = v);
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Notification Preferences',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.black,
                  ),
                ),
                SwitchListTile(
                  title: const Text('Vitals Alerts'),
                  subtitle: const Text('Get notified about abnormal vitals'),
                  value: notifyVitals,
                  activeThumbColor: HousepitalColors.orange,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setSheetState(() => notifyVitals = v),
                ),
                SwitchListTile(
                  title: const Text('Attendance Updates'),
                  subtitle: const Text('Staff check-in/check-out alerts'),
                  value: notifyAttendance,
                  activeThumbColor: HousepitalColors.orange,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setSheetState(() => notifyAttendance = v),
                ),
                SwitchListTile(
                  title: const Text('Daily Reports'),
                  subtitle: const Text('Daily care report summaries'),
                  value: notifyReports,
                  activeThumbColor: HousepitalColors.orange,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setSheetState(() => notifyReports = v),
                ),
                SwitchListTile(
                  title: const Text('Billing'),
                  subtitle: const Text('Invoice and payment reminders'),
                  value: notifyBilling,
                  activeThumbColor: HousepitalColors.orange,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setSheetState(() => notifyBilling = v),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty ||
                        phoneController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Name and phone are required'),
                        ),
                      );
                      return;
                    }
                    final newMember = FamilyMember.fromJson({
                      'id': 'fm${DateTime.now().millisecondsSinceEpoch}',
                      'user_id': 'u${DateTime.now().millisecondsSinceEpoch}',
                      'patient_id': 'p1',
                      'name': nameController.text.trim(),
                      'phone': '+91${phoneController.text.trim()}',
                      'email': emailController.text.trim().isNotEmpty
                          ? emailController.text.trim()
                          : null,
                      'relationship': relationship,
                      'role': 'FAMILY_MEMBER',
                      'preferred_language': 'en',
                      'notification_preferences': {
                        'vitals': notifyVitals,
                        'attendance': notifyAttendance,
                        'reports': notifyReports,
                        'billing': notifyBilling,
                      },
                    });
                    setState(() => _members.add(newMember));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${nameController.text.trim()} added'),
                      ),
                    );
                  },
                  child: const Text('Add Member'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final role = context.watch<AppProvider>().currentUserRole;
    final canManage = canUserPerform(role, UserAction.manageFamily);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('family_members')),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showAddMemberSheet(context),
              backgroundColor: HousepitalColors.orange,
              foregroundColor: HousepitalColors.white,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Family Member'),
            )
          : null,
      body: _members.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.family_restroom,
                    size: 64,
                    color: HousepitalColors.greyLight,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No family members added',
                    style: TextStyle(
                      fontSize: 16,
                      color: HousepitalColors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add family members to share updates',
                    style: TextStyle(
                      fontSize: 14,
                      color: HousepitalColors.greyLight,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                // Only primary contacts can swipe-to-remove; everyone else sees
                // a static card.
                if (!canManage) return _buildMemberCard(member);
                return Dismissible(
                  key: Key(member.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: HousepitalColors.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: HousepitalColors.white,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    _showDeleteConfirmation(member);
                    return false;
                  },
                  child: _buildMemberCard(member),
                );
              },
            ),
    );
  }

  Widget _buildMemberCard(FamilyMember member) {
    return HousepitalCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: HousepitalColors.orangeLight,
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: HousepitalColors.orange,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HousepitalColors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      text: member.isPrimaryContact
                          ? 'PRIMARY CONTACT'
                          : member.role.replaceAll('_', ' '),
                      color: member.isPrimaryContact
                          ? HousepitalColors.orange
                          : HousepitalColors.greyLight,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  member.phone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: HousepitalColors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.relationship,
                  style: const TextStyle(
                    fontSize: 13,
                    color: HousepitalColors.greyLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
