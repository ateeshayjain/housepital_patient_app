// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../config/app_colors.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/permissions.dart';
import '../../../widgets/common_widgets.dart';
import '../data/staff_roles_seed.dart';
import '../widgets/permission_dialogs.dart';

/// Card surfaced in the Manpower tab summarising one staff role
/// (Caretaker, Nurse, Physiotherapist).
///
/// Tapping the card opens a bottom sheet with a need-based checklist
/// ("Select what you need"): basic staff work comes pre-selected, ticking
/// higher-level tasks live-infers the recommended staff tier, and the CTA
/// continues into the full booking wizard, which shows the rate-card price
/// (owner rule re-confirmed 2026-06-11: manpower prices are shown, direct
/// booking with payment). A secondary link offers the OPTIONAL
/// callback/assessment path instead.
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

  Color get _roleColor {
    switch (role.title) {
      case 'Nurse':
        return HousepitalColors.serviceNursing;
      case 'Caretaker':
        return HousepitalColors.serviceCaretaker;
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
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: () => _showRoleDetail(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
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
                          Text(
                            role.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.hc.black,
                            ),
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
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: HousepitalColors.orange,
                              ),
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
                    Icon(
                      Icons.chevron_right,
                      color: context.hc.greyLight,
                      size: 22,
                    ),
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
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                          ),
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
        builder: (context, scrollController) => _NeedsSelectionSheet(
          role: role,
          services: services,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// Bottom-sheet body: need-based selection checklist for one staff role.
///
/// All level-0 (Basic) tasks come pre-checked; ticking tasks from higher
/// levels live-updates the recommended staff tier shown in the pinned
/// summary card and the "Continue" CTA label.
class _NeedsSelectionSheet extends StatefulWidget {
  final StaffRole role;
  final List<ServiceItem> services;
  final ScrollController scrollController;

  const _NeedsSelectionSheet({
    required this.role,
    required this.services,
    required this.scrollController,
  });

  @override
  State<_NeedsSelectionSheet> createState() => _NeedsSelectionSheetState();
}

class _NeedsSelectionSheetState extends State<_NeedsSelectionSheet> {
  /// Meta-references like "All Basic services" are level pointers, not tasks.
  static final RegExp _metaEntry = RegExp(r'^All .+ services$');

  /// Concrete (non-meta) tasks per level, in level order.
  late final List<List<String>> _levelTasks;

  /// Selected task keys (`levelIndex::task`).
  final Set<String> _selected = {};

  String _taskKey(int levelIndex, String task) => '$levelIndex::$task';

  @override
  void initState() {
    super.initState();
    _levelTasks = widget.role.levels
        .map(
          (level) =>
              level.included.where((t) => !_metaEntry.hasMatch(t)).toList(),
        )
        .toList();
    // Basic staff work is selected by default.
    for (final task in _levelTasks.first) {
      _selected.add(_taskKey(0, task));
    }
  }

  /// Highest level that owns ANY checked task (level 0 if only basic).
  int get _recommendedLevelIndex {
    for (var i = _levelTasks.length - 1; i > 0; i--) {
      if (_levelTasks[i].any((t) => _selected.contains(_taskKey(i, t)))) {
        return i;
      }
    }
    return 0;
  }

  /// Checked tasks that belong to levels above Basic.
  int get _higherLevelSelectedCount {
    var count = 0;
    for (var i = 1; i < _levelTasks.length; i++) {
      count += _levelTasks[i]
          .where((t) => _selected.contains(_taskKey(i, t)))
          .length;
    }
    return count;
  }

  String _sectionTitle(int levelIndex) {
    final name = widget.role.levels[levelIndex].name;
    return levelIndex == 0 ? '$name care' : '$name care adds';
  }

  ServiceItem get _matchingService => widget.services.firstWhere(
    (s) => s.name.toLowerCase().contains(
      widget.role.title.toLowerCase().split(' ').first,
    ),
    orElse: () => widget.services.first,
  );

  /// Role-permission gate shared by both CTAs. Returns true when the current
  /// user may proceed; otherwise shows the request-booking stub /
  /// view-only toast and returns false.
  bool _gateBookingAction() {
    final userRole = context.read<AppProvider>().currentUserRole;
    if (!canUserPerform(userRole, UserAction.book)) {
      if (canUserPerform(userRole, UserAction.requestBooking)) {
        showRequestBookingStub(context, _matchingService.name);
      } else {
        showViewOnlyToast(context);
      }
      return false;
    }
    return true;
  }

  void _onContinue() {
    final matchingService = _matchingService;

    // The /service-booking route only accepts a bare ServiceItem argument
    // (main.dart rejects anything else), so the needs checklist cannot ride
    // along yet — we log it for now.
    // TODO(backend): attach `selectedTasks` + recommended level to the
    // quote-pending booking payload once the route/API accepts a needs list.
    final levelName = widget.role.levels[_recommendedLevelIndex].name;
    final selectedTasks = <String>[
      for (var i = 0; i < _levelTasks.length; i++)
        for (final task in _levelTasks[i])
          if (_selected.contains(_taskKey(i, task))) task,
    ];
    debugPrint(
      'StaffRole needs selection — role=${widget.role.title}, '
      'recommended=$levelName, tasks=$selectedTasks',
    );

    if (!_gateBookingAction()) return;
    // Book end-to-end: full wizard showing the rate-card per-day price and
    // the normal priced checkout (Housepital calls back post-purchase to
    // confirm requirements and assign staff).
    // Push first (context still valid), sheet auto-dismisses
    Navigator.of(
      context,
    ).pushNamed('/service-booking', arguments: matchingService);
  }

  /// Secondary path: user prefers a callback instead of booking directly.
  void _onRequestCallback() {
    if (!_gateBookingAction()) return;
    Navigator.of(
      context,
    ).pushNamed('/assessment-request', arguments: _matchingService);
  }

  @override
  Widget build(BuildContext context) {
    final recommendedIndex = _recommendedLevelIndex;
    final recommendedName = widget.role.levels[recommendedIndex].name;
    final higherCount = _higherLevelSelectedCount;
    // Exclusions of the currently RECOMMENDED level — recomputed every build,
    // so the block live-updates as ticking tasks changes the recommendation.
    final excludedTasks = widget.role.levels[recommendedIndex].excluded
        .where((t) => !_metaEntry.hasMatch(t))
        .toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    AppIconTile(
                      icon: widget.role.icon,
                      color: HousepitalColors.orange,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.role.title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: context.hc.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.role.subtitle,
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
                    const Icon(
                      Icons.star,
                      size: 18,
                      color: HousepitalColors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.role.rating}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.hc.black,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${widget.role.reviewCount} reviews)',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.hc.greyLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

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
                  children: widget.role.availableShifts
                      .map(
                        (shift) => Chip(
                          label: Text(shift),
                          avatar: const Icon(
                            Icons.schedule,
                            size: 16,
                            color: HousepitalColors.orange,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),

                // Need-based selection checklist
                Text(
                  'Select what you need',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.hc.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Basic staff work is already selected. Tick anything '
                  'extra you need — we will match the right staff level.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.hc.greyLight,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _levelTasks.length; i++) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.hc.orangeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _sectionTitle(i),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.hc.orangeText,
                      ),
                    ),
                  ),
                  ..._levelTasks[i].map((task) => _taskRow(i, task)),
                ],

                // "Not included at this level" — mirrors the printed
                // caretaker-profile PDF, where not-offered tasks are listed
                // explicitly so families know the staff member's limits.
                // Hidden when the recommended level excludes nothing.
                if (excludedTasks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Not included at this level',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.hc.greyLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...excludedTasks.map(
                    (task) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            size: 16,
                            color: context.hc.greyLight,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              task,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.hc.greyLight,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                          Icon(
                            Icons.verified_user,
                            size: 16,
                            color: context.hc.success,
                          ),
                          const SizedBox(width: 8),
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.shield,
                            size: 16,
                            color: context.hc.success,
                          ),
                          const SizedBox(width: 8),
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.school,
                            size: 16,
                            color: context.hc.success,
                          ),
                          const SizedBox(width: 8),
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
              ],
            ),
          ),
        ),

        // Pinned recommendation summary + CTA
        Container(
          decoration: BoxDecoration(
            color: context.hc.white,
            border: Border(top: BorderSide(color: context.hc.divider)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.hc.orangeLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        AppIconTile(
                          icon: widget.role.icon,
                          color: HousepitalColors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recommended: $recommendedName '
                                '${widget.role.title}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.hc.black,
                                ),
                              ),
                              if (recommendedIndex > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Includes $higherCount '
                                  '${recommendedName.toLowerCase()}-care '
                                  'task${higherCount == 1 ? '' : 's'} '
                                  'you selected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.hc.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onContinue,
                      child: Text(
                        'Continue — $recommendedName ${widget.role.title}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _onRequestCallback,
                    child: const Text(
                      'Prefer a callback? Request an assessment',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _taskRow(int levelIndex, String task) {
    final key = _taskKey(levelIndex, task);
    final selected = _selected.contains(key);
    // Semantics(checked:) so VoiceOver announces checkbox role + state.
    return Semantics(
      checked: selected,
      label: task,
      child: InkWell(
        onTap: () => setState(() {
          if (selected) {
            _selected.remove(key);
          } else {
            _selected.add(key);
          }
        }),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          // 44pt minimum tap target (Apple HIG / accessibility).
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 22,
                // Selection = orange app-wide (green is reserved for status
                // outcomes).
                color: selected
                    ? HousepitalColors.orange
                    : context.hc.greyLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? context.hc.black : context.hc.grey,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
