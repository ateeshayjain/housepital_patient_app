import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

/// Vertical timeline order-tracking screen.
///
/// Listens to Firestore `active_sessions/{bookingId}` for real-time updates.
/// Supports two flows:
///   - **Booking** (visit): Placed -> Confirmed -> Staff Assigned -> En Route -> Arrived -> In Progress -> Completed
///   - **Equipment**: Placed -> Confirmed -> Dispatched -> Out for Delivery -> Delivered
class OrderTrackingScreen extends StatefulWidget {
  final String bookingId;
  final String orderType; // 'booking' or 'equipment'

  const OrderTrackingScreen({
    super.key,
    required this.bookingId,
    this.orderType = 'booking',
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  Map<String, dynamic> _sessionData = {};
  bool _isLoading = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Steps for booking (visit) orders.
  static const _bookingSteps = [
    _StepInfo('Placed', 'Your booking has been placed', Icons.receipt_long),
    _StepInfo('Confirmed', 'Booking confirmed by Housepital', Icons.check_circle_outline),
    _StepInfo('Staff Assigned', 'A care professional has been assigned', Icons.person_add_alt_1),
    _StepInfo('En Route', 'Your care professional is on the way', Icons.directions_car),
    _StepInfo('Arrived', 'Care professional has arrived', Icons.location_on),
    _StepInfo('In Progress', 'Service is in progress', Icons.medical_services),
    _StepInfo('Completed', 'Service completed', Icons.task_alt),
  ];

  /// Steps for equipment orders.
  static const _equipmentSteps = [
    _StepInfo('Placed', 'Your order has been placed', Icons.receipt_long),
    _StepInfo('Confirmed', 'Order confirmed', Icons.check_circle_outline),
    _StepInfo('Dispatched', 'Equipment dispatched from warehouse', Icons.inventory_2),
    _StepInfo('Out for Delivery', 'Out for delivery to your address', Icons.local_shipping),
    _StepInfo('Delivered', 'Equipment delivered', Icons.task_alt),
  ];

  List<_StepInfo> get _steps =>
      widget.orderType == 'equipment' ? _equipmentSteps : _bookingSteps;

  int get _currentStepIndex {
    final status = (_sessionData['status'] as String?) ?? 'placed';
    final statusLower = status.toLowerCase().replaceAll('_', ' ');
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].title.toLowerCase() == statusLower) return i;
    }
    // Map common backend statuses
    final mapping = {
      'placed': 0,
      'confirmed': 1,
      'staff_assigned': 2,
      'en_route': 3,
      'arrived': 4,
      'in_progress': 5,
      'completed': 6,
      'dispatched': 2,
      'out_for_delivery': 3,
      'delivered': 4,
    };
    return mapping[status.toLowerCase()] ?? 0;
  }

  bool get _canCancel => _currentStepIndex <= 1;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _listenToFirestore();
  }

  void _listenToFirestore() {
    try {
      _firestoreSub = FirebaseFirestore.instance
          .collection('active_sessions')
          .doc(widget.bookingId)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _sessionData = snapshot.data() ?? {};
          _isLoading = false;
        });
      }, onError: (_) {
        if (!mounted) return;
        setState(() => _isLoading = false);
      });
    } catch (e) {
      debugPrint('Firestore tracking listener skipped: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Tracking')),
      // audit batch 4 (Agent L): Apple P5 (perceived performance) — replace
      // bare spinner with a Shimmer skeleton that mimics the final timeline
      // layout so the page feels populated within the same frame.
      body: _isLoading
          ? _buildSkeleton()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order ID
                  // audit M-8: guard against substring crash for booking IDs
                  // shorter than 8 chars (e.g. legacy ids, test fixtures).
                  Text(
                    'Order #${(widget.bookingId.length >= 8 ? widget.bookingId.substring(0, 8) : widget.bookingId).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.orderType == 'equipment'
                        ? 'Equipment Delivery'
                        : 'Visit Booking',
                    style: TextStyle(
                      fontSize: 14,
                      color: HousepitalColors.greyLight,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ETA section
                  _buildEtaSection(),
                  const SizedBox(height: 24),

                  // Assigned staff card (for visits, once staff assigned)
                  if (widget.orderType == 'booking' && _currentStepIndex >= 2)
                    _buildStaffCard(),

                  // Vertical timeline
                  _buildTimeline(),

                  const SizedBox(height: 32),

                  // Action buttons
                  _buildActions(),
                ],
              ),
            ),
    );
  }

  // audit batch 4 (Agent L): Shimmer skeleton — order header, ETA card,
  // assigned-staff card, and 5 timeline rows with leading 28pt circles.
  // Mirrors the post-load layout so there's no jarring shift when data arrives.
  Widget _buildSkeleton() {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;
    Widget bar({double width = double.infinity, double height = 14}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(width: 180, height: 18),
            const SizedBox(height: 8),
            bar(width: 120, height: 14),
            const SizedBox(height: 24),
            // ETA card
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            // Staff card
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            // Timeline — 5 rows
            ...List.generate(5, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bar(width: 140, height: 14),
                            const SizedBox(height: 6),
                            bar(width: 220, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEtaSection() {
    final eta = _sessionData['eta_minutes'] as int?;
    final etaText = eta != null ? '~$eta mins' : '~30 mins';
    final bool showEta =
        _currentStepIndex >= 3 && _currentStepIndex < _steps.length - 1;

    if (!showEta) return const SizedBox.shrink();

    return HousepitalCard(
      child: Row(
        children: [
          const Icon(Icons.access_time, color: HousepitalColors.orange, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expected arrival',
                style: TextStyle(fontSize: 13, color: HousepitalColors.greyLight),
              ),
              Text(
                etaText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard() {
    final staffName = _sessionData['staff_name'] as String? ?? 'Assigning...';
    final staffRole = _sessionData['staff_role'] as String? ?? 'Care Professional';
    final staffPhoto = _sessionData['staff_photo'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: HousepitalCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: HousepitalColors.orangeLight,
              backgroundImage:
                  staffPhoto != null ? NetworkImage(staffPhoto) : null,
              child: staffPhoto == null
                  ? const Icon(Icons.person, color: HousepitalColors.orange)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staffName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    staffRole,
                    style: const TextStyle(
                      fontSize: 13,
                      color: HousepitalColors.greyLight,
                    ),
                  ),
                ],
              ),
            ),
            const StatusBadge(
              text: 'Assigned',
              color: HousepitalColors.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final currentIndex = _currentStepIndex;

    return Column(
      children: List.generate(_steps.length, (index) {
        final step = _steps[index];
        final isDone = index < currentIndex;
        final isCurrent = index == currentIndex;
        final isPending = index > currentIndex;

        // Try to get timestamp for this step
        final stepKey = step.title.toLowerCase().replaceAll(' ', '_');
        final timestamp = _sessionData['${stepKey}_at'] as String?;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator column
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  // Dot / icon
                  if (isCurrent)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (_, __) => Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HousepitalColors.orange
                              .withValues(alpha: _pulseAnimation.value),
                          border: Border.all(
                              color: HousepitalColors.orange, width: 2.5),
                        ),
                        child: const Icon(Icons.circle,
                            size: 10, color: HousepitalColors.orange),
                      ),
                    )
                  else
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? HousepitalColors.success
                            : HousepitalColors.greyLighter,
                        border: Border.all(
                          color: isDone
                              ? HousepitalColors.success
                              : HousepitalColors.divider,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isDone ? Icons.check : step.icon,
                        size: 14,
                        color: isDone ? Colors.white : Colors.grey,
                      ),
                    ),
                  // Connector line
                  if (index < _steps.length - 1)
                    Container(
                      width: 2,
                      height: 48,
                      color: isDone
                          ? HousepitalColors.success
                          : HousepitalColors.divider,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isPending
                            ? Colors.grey
                            : HousepitalColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPending
                            ? Colors.grey.shade400
                            : HousepitalColors.greyLight,
                      ),
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        timestamp,
                        style: const TextStyle(
                          fontSize: 11,
                          color: HousepitalColors.greyLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, '/raise-concern'),
          icon: const Icon(Icons.help_outline),
          label: const Text('Need Help?'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HousepitalColors.orange,
            side: const BorderSide(color: HousepitalColors.orange),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        if (_canCancel) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showCancelDialog,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel Order'),
            style: OutlinedButton.styleFrom(
              foregroundColor: HousepitalColors.error,
              side: const BorderSide(color: HousepitalColors.error),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ],
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, Keep It'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // NOTE: Requires backend API — will be wired when Cloud Functions deploy.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cancellation request submitted'),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: HousepitalColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepInfo {
  final String title;
  final String subtitle;
  final IconData icon;

  const _StepInfo(this.title, this.subtitle, this.icon);
}
