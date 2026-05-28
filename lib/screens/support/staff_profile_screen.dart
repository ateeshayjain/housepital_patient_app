import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/common_widgets.dart';

class StaffProfileScreen extends StatefulWidget {
  final String staffId;
  const StaffProfileScreen({super.key, required this.staffId});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  StaffProfile? _staff;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      _staff = await ApiService().getStaffProfile(widget.staffId);
    } catch (e) {
      debugPrint('Error loading staff profile: $e');
      // Mock data for preview
      _staff = StaffProfile.fromJson({
        'id': widget.staffId,
        'name': 'Priya Mehra',
        'role': 'nurse',
        'photo_url': null,
        'rating': 4.8,
        'total_reviews': 142,
        'id_verified': true,
        'training_complete': true,
        'police_verified': true,
        'languages': ['Hindi', 'English'],
        'experience': '5 years',
        'assigned_since':
            DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'documents': [
          {
            'type': 'aadhaar',
            'label': 'Aadhaar Card',
            'status': 'verified',
            'verified_at': DateTime.now()
                .subtract(const Duration(days: 120))
                .toIso8601String(),
          },
          {
            'type': 'police_verification',
            'label': 'Police Verification',
            'status': 'verified',
            'verified_at': DateTime.now()
                .subtract(const Duration(days: 90))
                .toIso8601String(),
          },
          {
            'type': 'training_certificate',
            'label': 'Nursing Training Certificate',
            'status': 'verified',
            'verified_at': DateTime.now()
                .subtract(const Duration(days: 200))
                .toIso8601String(),
          },
          {
            'type': 'medical_certificate',
            'label': 'Medical Fitness Certificate',
            'status': 'verified',
            'verified_at': DateTime.now()
                .subtract(const Duration(days: 60))
                .toIso8601String(),
          },
        ],
        'reviews': [
          {
            'id': 'r1',
            'patient_name': 'Ramesh K.',
            'rating': 5.0,
            'comment':
                'Priya is very caring and attentive. She always makes sure my father takes his medication on time.',
            'date': DateTime.now()
                .subtract(const Duration(days: 3))
                .toIso8601String(),
          },
          {
            'id': 'r2',
            'patient_name': 'Suresh G.',
            'rating': 4.5,
            'comment':
                'Very professional. Good at wound dressing and vitals monitoring. Highly recommend.',
            'date': DateTime.now()
                .subtract(const Duration(days: 18))
                .toIso8601String(),
          },
          {
            'id': 'r3',
            'patient_name': 'Anita S.',
            'rating': 5.0,
            'comment': 'Excellent care for my mother post-surgery. Very gentle and patient.',
            'date': DateTime.now()
                .subtract(const Duration(days: 45))
                .toIso8601String(),
          },
          {
            'id': 'r4',
            'patient_name': 'Vikram P.',
            'rating': 4.0,
            'comment': null,
            'date': DateTime.now()
                .subtract(const Duration(days: 60))
                .toIso8601String(),
          },
        ],
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('staff_profile'))),
      bottomNavigationBar: _staff != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/staff-replacement', arguments: {
                      'deploymentId': _staff!.id,
                      'staffName': _staff!.name,
                      'staffRole': _staff!.role,
                      'staffPhoto': _staff!.photoUrl,
                      'assignedSince': _staff!.assignedSince,
                    });
                  },
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Request Replacement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HousepitalColors.warning,
                    side: const BorderSide(color: HousepitalColors.warning),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const LoadingWidget()
          : _staff == null
              ? ErrorRetryWidget(
                  message: l.t('error_occurred'),
                  onRetry: _loadProfile,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildInfoSection(l),
                      const SizedBox(height: 24),
                      _buildVerificationSection(l),
                      const SizedBox(height: 24),
                      _buildAttendanceCalendar(l),
                      const SizedBox(height: 24),
                      _buildDocumentsSection(l),
                      const SizedBox(height: 24),
                      _buildReviewsSection(l),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Header — avatar, name, role, badges, rating
  // ---------------------------------------------------------------------------
  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 48,
          backgroundColor: HousepitalColors.orangeLight,
          backgroundImage: _staff!.photoUrl != null
              ? NetworkImage(_staff!.photoUrl!)
              : null,
          child: _staff!.photoUrl == null
              ? Text(
                  _staff!.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 36,
                    color: HousepitalColors.orange,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          _staff!.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _staff!.role.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            color: HousepitalColors.greyLight,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        // Rating summary
        if (_staff!.rating != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ..._buildRatingStars(_staff!.rating!),
              const SizedBox(width: 8),
              Text(
                _staff!.rating!.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.black,
                ),
              ),
              if (_staff!.totalReviews != null) ...[
                const SizedBox(width: 6),
                Text(
                  '(${_staff!.totalReviews} reviews)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: HousepitalColors.greyLight,
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 12),
        // Badges
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (_staff!.idVerified)
              const StatusBadge(
                text: 'ID Verified',
                color: HousepitalColors.success,
                icon: Icons.verified_user,
              ),
            if (_staff!.policeVerified)
              const StatusBadge(
                text: 'Police Verified',
                color: HousepitalColors.info,
                icon: Icons.shield,
              ),
            if (_staff!.trainingComplete)
              const StatusBadge(
                text: 'Training Complete',
                color: HousepitalColors.success,
                icon: Icons.school,
              ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Info Section — languages, experience, assigned since
  // ---------------------------------------------------------------------------
  Widget _buildInfoSection(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: HousepitalColors.black,
          ),
        ),
        const SizedBox(height: 8),
        _infoTile(Icons.language, l.t('languages'),
            _staff!.languages?.join(', ') ?? '-'),
        _infoTile(
            Icons.work, l.t('experience'), _staff!.experience ?? '-'),
        if (_staff!.assignedSince != null)
          _infoTile(
            Icons.calendar_today,
            l.t('assigned_since'),
            '${_staff!.assignedSince!.day}/${_staff!.assignedSince!.month}/${_staff!.assignedSince!.year}',
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Verification Section — trust indicators
  // ---------------------------------------------------------------------------
  Widget _buildVerificationSection(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verification Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: HousepitalColors.black,
          ),
        ),
        const SizedBox(height: 8),
        HousepitalCard(
          child: Column(
            children: [
              _verificationRow(
                Icons.badge,
                'Aadhaar Card',
                _staff!.idVerified,
              ),
              const Divider(height: 1),
              _verificationRow(
                Icons.shield,
                'Police Verification',
                _staff!.policeVerified,
              ),
              const Divider(height: 1),
              _verificationRow(
                Icons.school,
                'Training Certificate',
                _staff!.trainingComplete,
              ),
              const Divider(height: 1),
              _verificationRow(
                Icons.medical_services,
                'Medical Fitness',
                true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _verificationRow(IconData icon, String label, bool verified) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: HousepitalColors.orange, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: HousepitalColors.black,
              ),
            ),
          ),
          Icon(
            verified ? Icons.check_circle : Icons.pending,
            color: verified ? HousepitalColors.success : HousepitalColors.warning,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            verified ? 'Verified' : 'Pending',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: verified ? HousepitalColors.success : HousepitalColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Attendance Calendar — monthly calendar view of staff attendance
  // ---------------------------------------------------------------------------
  Widget _buildAttendanceCalendar(AppLocalizations l) {
    // Generate mock attendance data for the current month
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final attendanceMap = <DateTime, StaffAttendance>{};

    // Fill mock attendance: present most days, a few absences and half days
    for (int i = 0; i < now.day; i++) {
      final date = firstDay.add(Duration(days: i));
      final dayOfWeek = date.weekday;
      // Sundays off
      if (dayOfWeek == DateTime.sunday) {
        attendanceMap[DateTime(date.year, date.month, date.day)] =
            StaffAttendance(
          date: date,
          status: 'leave',
        );
      } else if (i == 4 || i == 15) {
        // A couple of absences
        attendanceMap[DateTime(date.year, date.month, date.day)] =
            StaffAttendance(
          date: date,
          status: 'absent',
        );
      } else if (i == 9) {
        // One half day
        attendanceMap[DateTime(date.year, date.month, date.day)] =
            StaffAttendance(
          date: date,
          status: 'half_day',
          checkIn: '8:00 AM',
          checkOut: '2:00 PM',
          hoursWorked: 6,
        );
      } else {
        attendanceMap[DateTime(date.year, date.month, date.day)] =
            StaffAttendance(
          date: date,
          status: 'present',
          checkIn: '8:00 AM',
          checkOut: '8:00 PM',
          hoursWorked: 12,
        );
      }
    }

    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstWeekday = firstDay.weekday; // 1=Mon, 7=Sun
    // We use Monday as first column
    final leadingBlanks = firstWeekday - 1;

    final presentCount =
        attendanceMap.values.where((a) => a.status == 'present').length;
    final absentCount =
        attendanceMap.values.where((a) => a.status == 'absent').length;
    final halfDayCount =
        attendanceMap.values.where((a) => a.status == 'half_day').length;
    final leaveCount =
        attendanceMap.values.where((a) => a.status == 'leave').length;

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month,
                size: 20, color: HousepitalColors.orange),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Attendance',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.black,
                ),
              ),
            ),
            Text(
              '${months[now.month - 1]} ${now.year}',
              style: const TextStyle(
                fontSize: 13,
                color: HousepitalColors.greyLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Summary row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: HousepitalColors.orangeLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _attendanceStat('Present', '$presentCount', HousepitalColors.success),
              _attendanceStat('Absent', '$absentCount', HousepitalColors.error),
              _attendanceStat('Half Day', '$halfDayCount', Colors.orange),
              _attendanceStat('Leave', '$leaveCount', HousepitalColors.greyLight),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Day headers
        Container(
          decoration: BoxDecoration(
            color: HousepitalColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((d) => SizedBox(
                          width: 36,
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: d == 'S'
                                    ? HousepitalColors.greyLight
                                    : HousepitalColors.grey,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              // Calendar grid
              ...List.generate(
                ((leadingBlanks + daysInMonth) / 7).ceil(),
                (week) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (col) {
                        final dayIndex = week * 7 + col - leadingBlanks + 1;
                        if (dayIndex < 1 || dayIndex > daysInMonth) {
                          return const SizedBox(width: 36, height: 36);
                        }
                        final date =
                            DateTime(now.year, now.month, dayIndex);
                        final attendance = attendanceMap[date];
                        final isFuture = dayIndex > now.day;
                        final isToday = dayIndex == now.day;

                        Color dotColor;
                        if (isFuture) {
                          dotColor = Colors.transparent;
                        } else if (attendance == null) {
                          dotColor = Colors.transparent;
                        } else {
                          switch (attendance.status) {
                            case 'present':
                              dotColor = HousepitalColors.success;
                              break;
                            case 'absent':
                              dotColor = HousepitalColors.error;
                              break;
                            case 'half_day':
                              dotColor = Colors.orange;
                              break;
                            case 'leave':
                              dotColor = HousepitalColors.greyLight;
                              break;
                            default:
                              dotColor = Colors.transparent;
                          }
                        }

                        return GestureDetector(
                          onTap: attendance != null && !isFuture
                              ? () => _showAttendanceDetail(
                                  context, date, attendance)
                              : null,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? HousepitalColors.orangeLight
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isToday
                                  ? Border.all(
                                      color: HousepitalColors.orange,
                                      width: 1.5)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayIndex',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isFuture
                                        ? HousepitalColors.greyLight
                                        : HousepitalColors.black,
                                  ),
                                ),
                                if (!isFuture && attendance != null)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(HousepitalColors.success, 'Present'),
            const SizedBox(width: 14),
            _legendDot(HousepitalColors.error, 'Absent'),
            const SizedBox(width: 14),
            _legendDot(Colors.orange, 'Half Day'),
            const SizedBox(width: 14),
            _legendDot(HousepitalColors.greyLight, 'Leave'),
          ],
        ),
      ],
    );
  }

  Widget _attendanceStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: HousepitalColors.greyLight,
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: HousepitalColors.greyLight,
          ),
        ),
      ],
    );
  }

  void _showAttendanceDetail(
      BuildContext context, DateTime date, StaffAttendance attendance) {
    final dayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (attendance.status) {
      case 'present':
        statusColor = HousepitalColors.success;
        statusLabel = 'Present';
        statusIcon = Icons.check_circle;
        break;
      case 'absent':
        statusColor = HousepitalColors.error;
        statusLabel = 'Absent';
        statusIcon = Icons.cancel;
        break;
      case 'half_day':
        statusColor = Colors.orange;
        statusLabel = 'Half Day';
        statusIcon = Icons.timelapse;
        break;
      default:
        statusColor = HousepitalColors.greyLight;
        statusLabel = 'Leave / Off';
        statusIcon = Icons.event_busy;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${dayNames[date.weekday - 1]}, ${date.day} ${monthNames[date.month - 1]}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HousepitalColors.black,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // audit M-19: withOpacity → withValues (deprecated since Flutter 3.27)
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        if (attendance.hoursWorked != null)
                          Text(
                            '${attendance.hoursWorked!.toStringAsFixed(0)} hours worked',
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
            ),
            if (attendance.checkIn != null || attendance.checkOut != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (attendance.checkIn != null)
                    Expanded(
                      child: _timeCard(
                          'Check In', attendance.checkIn!, Icons.login),
                    ),
                  if (attendance.checkIn != null && attendance.checkOut != null)
                    const SizedBox(width: 12),
                  if (attendance.checkOut != null)
                    Expanded(
                      child: _timeCard(
                          'Check Out', attendance.checkOut!, Icons.logout),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeCard(String label, String time, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: HousepitalColors.orange),
          const SizedBox(height: 6),
          Text(
            time,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: HousepitalColors.black,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: HousepitalColors.greyLight,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Documents Section — viewable documents
  // ---------------------------------------------------------------------------
  Widget _buildDocumentsSection(AppLocalizations l) {
    final docs = _staff!.documents;
    if (docs == null || docs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documents',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: HousepitalColors.black,
          ),
        ),
        const SizedBox(height: 8),
        ...docs.map((doc) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HousepitalCard(
                onTap: () => _showDocumentDetail(doc),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        // audit M-19: withOpacity → withValues (deprecated since Flutter 3.27)
                        color: _docIconColor(doc.type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _docIcon(doc.type),
                        color: _docIconColor(doc.type),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: HousepitalColors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (doc.verifiedAt != null)
                            Text(
                              'Verified on ${doc.verifiedAt!.day}/${doc.verifiedAt!.month}/${doc.verifiedAt!.year}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: HousepitalColors.greyLight,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _statusChip(doc.status),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right,
                        size: 18, color: HousepitalColors.greyLight),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  IconData _docIcon(String type) {
    switch (type) {
      case 'aadhaar':
        return Icons.badge;
      case 'police_verification':
        return Icons.shield;
      case 'training_certificate':
        return Icons.school;
      case 'medical_certificate':
        return Icons.medical_services;
      default:
        return Icons.description;
    }
  }

  Color _docIconColor(String type) {
    switch (type) {
      case 'aadhaar':
        return HousepitalColors.info;
      case 'police_verification':
        return HousepitalColors.success;
      case 'training_certificate':
        return HousepitalColors.orange;
      case 'medical_certificate':
        return HousepitalColors.error;
      default:
        return HousepitalColors.grey;
    }
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'verified':
        color = HousepitalColors.success;
        label = 'Verified';
        break;
      case 'expired':
        color = HousepitalColors.error;
        label = 'Expired';
        break;
      default:
        color = HousepitalColors.warning;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // audit M-19: withOpacity → withValues (deprecated since Flutter 3.27)
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _showDocumentDetail(StaffDocument doc) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_docIcon(doc.type), color: _docIconColor(doc.type), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    doc.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('Status', doc.status == 'verified' ? 'Verified' : doc.status == 'expired' ? 'Expired' : 'Pending'),
            if (doc.verifiedAt != null)
              _detailRow('Verified On', '${doc.verifiedAt!.day}/${doc.verifiedAt!.month}/${doc.verifiedAt!.year}'),
            _detailRow('Document Type', doc.type.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')),
            const SizedBox(height: 16),
            // Placeholder for actual document view
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: HousepitalColors.greyLighter,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HousepitalColors.divider),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_docIcon(doc.type), size: 48, color: HousepitalColors.greyLight),
                  const SizedBox(height: 8),
                  const Text(
                    'Document preview',
                    style: TextStyle(
                      fontSize: 13,
                      color: HousepitalColors.greyLight,
                    ),
                  ),
                  const Text(
                    'Verified by Housepital',
                    style: TextStyle(
                      fontSize: 12,
                      color: HousepitalColors.greyLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: HousepitalColors.greyLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: HousepitalColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reviews Section — past feedback from other patients
  // ---------------------------------------------------------------------------
  Widget _buildReviewsSection(AppLocalizations l) {
    final reviews = _staff!.reviews;
    if (reviews == null || reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Reviews & Feedback',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HousepitalColors.black,
              ),
            ),
            const Spacer(),
            Text(
              '${reviews.length} reviews',
              style: const TextStyle(
                fontSize: 13,
                color: HousepitalColors.greyLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...reviews.map((review) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HousepitalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: HousepitalColors.orangeLight,
                          child: Text(
                            review.patientName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: HousepitalColors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.patientName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: HousepitalColors.black,
                                ),
                              ),
                              Text(
                                _timeAgo(review.date),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HousepitalColors.greyLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                size: 16, color: HousepitalColors.orange),
                            const SizedBox(width: 4),
                            Text(
                              review.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: HousepitalColors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (review.comment != null &&
                        review.comment!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        review.comment!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: HousepitalColors.grey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )),
      ],
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HousepitalCard(
        child: Row(
          children: [
            Icon(icon, color: HousepitalColors.orange, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: HousepitalColors.greyLight)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: HousepitalColors.black)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRatingStars(double rating) {
    final List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      if (rating >= i) {
        stars.add(const Icon(Icons.star,
            size: 18, color: HousepitalColors.orange));
      } else if (rating >= i - 0.5) {
        stars.add(const Icon(Icons.star_half,
            size: 18, color: HousepitalColors.orange));
      } else {
        stars.add(const Icon(Icons.star_border,
            size: 18, color: HousepitalColors.greyLight));
      }
    }
    return stars;
  }
}
