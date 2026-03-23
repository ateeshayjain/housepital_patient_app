import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/theme.dart';
import '../../models/models.dart';
import '../../models/equipment_order.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class MyOrdersScreen extends StatefulWidget {
  final int initialTab;

  const MyOrdersScreen({super.key, this.initialTab = 0});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Orders tab state ---
  List<OrderItem> _orders = [];
  bool _ordersLoading = true;
  String? _ordersError; // partial failure banner
  String _orderFilter = 'all';

  // --- Assessment Requests tab state ---
  List<AssessmentRequest> _pendingAssessments = [];
  bool _assessmentsLoading = true;
  String? _assessmentsError;

  // Track individual API failures for partial-failure banner
  String? _bookingsError;
  String? _equipmentError;
  String? _assessmentsFetchError;

  static const _orderFilters = ['all', 'active', 'completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final appProvider = context.read<AppProvider>();
    final patientId = appProvider.currentPatient?.id;
    if (patientId == null) {
      setState(() {
        _ordersLoading = false;
        _assessmentsLoading = false;
        _ordersError = 'No patient selected';
        _assessmentsError = 'No patient selected';
      });
      return;
    }

    setState(() {
      _ordersLoading = true;
      _assessmentsLoading = true;
      _ordersError = null;
      _assessmentsError = null;
      _bookingsError = null;
      _equipmentError = null;
      _assessmentsFetchError = null;
    });

    // Fetch all three in parallel
    final results = await Future.wait([
      _fetchBookings(patientId),
      _fetchEquipmentOrders(patientId),
      _fetchAssessments(patientId),
    ]);

    if (!mounted) return;

    final bookings = results[0] as List<Booking>?;
    final equipmentOrders = results[1] as List<EquipmentOrder>?;
    final assessments = results[2] as List<AssessmentRequest>?;

    // Build orders list (bookings + equipment + accepted assessments)
    final orders = <OrderItem>[];

    if (bookings != null) {
      orders.addAll(bookings.map(OrderItem.fromBooking));
    }
    if (equipmentOrders != null) {
      orders.addAll(equipmentOrders.map(OrderItem.fromEquipmentOrder));
    }
    if (assessments != null) {
      // Accepted/staff_matched/deployed assessments go to Orders tab
      orders.addAll(
        assessments
            .where((a) => OrderItem.isOrdersTabAssessment(a.status))
            .map(OrderItem.fromAssessment),
      );
    }

    // Sort newest first
    orders.sort((a, b) => b.date.compareTo(a.date));

    // Build pending assessments list
    final pending = <AssessmentRequest>[];
    if (assessments != null) {
      pending.addAll(
        assessments.where(
          (a) =>
              OrderItem.isPendingAssessment(a.status) ||
              a.status == 'declined' ||
              a.status == 'expired',
        ),
      );
      pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // Determine partial failure messages
    final partialErrors = <String>[];
    if (_bookingsError != null) partialErrors.add('bookings');
    if (_equipmentError != null) partialErrors.add('equipment orders');
    if (_assessmentsFetchError != null) partialErrors.add('assessments');

    setState(() {
      _orders = orders;
      _ordersLoading = false;
      _ordersError = partialErrors.isNotEmpty
          ? "Some orders couldn't be loaded. Pull down to retry."
          : null;

      _pendingAssessments = pending;
      _assessmentsLoading = false;
      _assessmentsError = _assessmentsFetchError != null
          ? "Couldn't load assessment requests. Pull down to retry."
          : null;
    });
  }

  Future<List<Booking>?> _fetchBookings(String patientId) async {
    try {
      return await ApiService().getBookings(patientId);
    } catch (e) {
      _bookingsError = e.toString();
      return null;
    }
  }

  Future<List<EquipmentOrder>?> _fetchEquipmentOrders(
      String patientId) async {
    try {
      return await ApiService().getEquipmentOrders(patientId);
    } catch (e) {
      _equipmentError = e.toString();
      return null;
    }
  }

  Future<List<AssessmentRequest>?> _fetchAssessments(
      String patientId) async {
    try {
      return await ApiService().getAssessments(patientId);
    } catch (e) {
      _assessmentsFetchError = e.toString();
      return null;
    }
  }

  // ==================== FILTER LOGIC ====================

  List<OrderItem> get _filteredOrders {
    if (_orderFilter == 'all') return _orders;
    return _orders.where((o) {
      switch (_orderFilter) {
        case 'active':
          return _isActiveStatus(o.status);
        case 'completed':
          return _isCompletedStatus(o.status);
        case 'cancelled':
          return _isCancelledStatus(o.status);
        default:
          return true;
      }
    }).toList();
  }

  bool _isActiveStatus(String status) {
    return const {
      'pending',
      'placed',
      'confirmed',
      'assigned',
      'dispatched',
      'in_progress',
      'accepted',
      'staff_matched',
      'deployed',
    }.contains(status);
  }

  bool _isCompletedStatus(String status) {
    return const {'completed', 'delivered'}.contains(status);
  }

  bool _isCancelledStatus(String status) {
    return const {'cancelled', 'no_show'}.contains(status);
  }

  // ==================== STATUS HELPERS ====================

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
      case 'placed':
        return HousepitalColors.warning;
      case 'confirmed':
      case 'assigned':
      case 'dispatched':
        return HousepitalColors.info;
      case 'in_progress':
      case 'deployed':
      case 'staff_matched':
      case 'accepted':
        return HousepitalColors.success;
      case 'completed':
      case 'delivered':
        return HousepitalColors.success;
      case 'cancelled':
      case 'no_show':
        return HousepitalColors.error;
      case 'submitted':
      case 'in_review':
      case 'callback_scheduled':
        return HousepitalColors.warning;
      case 'quote_sent':
        return HousepitalColors.orange;
      case 'declined':
      case 'expired':
        return HousepitalColors.error;
      default:
        return HousepitalColors.greyLight;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'placed':
        return 'Placed';
      case 'confirmed':
        return 'Confirmed';
      case 'assigned':
        return 'Assigned';
      case 'dispatched':
        return 'Dispatched';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'no_show':
        return 'No Show';
      case 'submitted':
        return 'Submitted';
      case 'in_review':
        return 'In Review';
      case 'callback_scheduled':
        return 'Callback Scheduled';
      case 'quote_sent':
        return 'Quote Sent';
      case 'accepted':
        return 'Accepted';
      case 'staff_matched':
        return 'Staff Matched';
      case 'deployed':
        return 'Active';
      case 'declined':
        return 'Declined';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }

  String _typeBadgeLabel(String type) {
    switch (type) {
      case 'booking':
        return 'BOOKING';
      case 'equipment':
        return 'EQUIPMENT';
      case 'assessment':
        return 'SERVICE';
      default:
        return type.toUpperCase();
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'booking':
        return Icons.medical_services_outlined;
      case 'equipment':
        return Icons.precision_manufacturing_outlined;
      case 'assessment':
        return Icons.people_outline;
      default:
        return Icons.receipt_long;
    }
  }

  // ==================== ACTIONS ====================

  bool _canCancel(OrderItem order) {
    // Only bookings in pending/confirmed can be cancelled
    // Equipment in placed can be cancelled
    if (order.type == 'booking') {
      if (order.status != 'pending' && order.status != 'confirmed') {
        return false;
      }
      // Check >2hr rule
      final scheduledDate =
          order.metadata['scheduled_date'] as DateTime?;
      if (scheduledDate != null) {
        return scheduledDate.difference(DateTime.now()).inHours > 2;
      }
      return true;
    }
    if (order.type == 'equipment') {
      return order.status == 'placed';
    }
    return false;
  }

  bool _canRate(OrderItem order) {
    return (order.status == 'completed' || order.status == 'delivered') &&
        order.type == 'booking';
  }

  bool _canRebook(OrderItem order) {
    return order.status == 'completed' ||
        order.status == 'delivered' ||
        order.status == 'cancelled' ||
        order.status == 'no_show';
  }

  bool _canViewInMyCare(OrderItem order) {
    return order.status == 'in_progress' ||
        order.status == 'deployed' ||
        order.status == 'staff_matched';
  }

  bool _canTrack(OrderItem order) {
    return order.type == 'equipment' && order.status == 'dispatched';
  }

  Future<void> _showCancelDialog(OrderItem order) async {
    String? selectedReason;
    final reasons = [
      'Schedule conflict',
      'Found alternative',
      'No longer needed',
      'Other',
    ];

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cancel Order',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: HousepitalColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  order.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: HousepitalColors.greyLight,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reason for cancellation',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.black,
                  ),
                ),
                const SizedBox(height: 10),
                ...reasons.map((reason) => RadioListTile<String>(
                      title:
                          Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: selectedReason,
                      activeColor: HousepitalColors.orange,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (v) {
                        setModalState(() => selectedReason = v);
                      },
                    )),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Keep Order'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HousepitalColors.error,
                          ),
                          onPressed: selectedReason == null
                              ? null
                              : () => Navigator.pop(ctx, true),
                          child: const Text('Cancel Order'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );

    if (confirmed == true && selectedReason != null && mounted) {
      try {
        await ApiService().cancelBooking(order.id, selectedReason!);
        _loadAll();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: HousepitalColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel order'),
            backgroundColor: HousepitalColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showRatingSheet(OrderItem order) async {
    int rating = 0;
    final commentController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rate this Service',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: HousepitalColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  order.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: HousepitalColors.greyLight,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setModalState(() => rating = index + 1);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 40,
                          color: index < rating
                              ? HousepitalColors.orange
                              : HousepitalColors.divider,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Share your experience (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Skip'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: rating == 0
                              ? null
                              : () async {
                                  try {
                                    await ApiService().submitRating(
                                      bookingId: order.id,
                                      rating: rating,
                                      comment:
                                          commentController.text.isNotEmpty
                                              ? commentController.text
                                              : null,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _loadAll();
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Failed to submit rating'),
                                          backgroundColor:
                                              HousepitalColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: const Text('Rate'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
    commentController.dispose();
  }

  void _rebookOrder(OrderItem order) {
    switch (order.type) {
      case 'booking':
        final service = ServiceItem(
          id: order.metadata['service_id'] ?? '',
          name: order.name,
          category: 'general',
          bookingType: 'instant',
        );
        Navigator.pushNamed(context, '/service-booking', arguments: service);
        break;
      case 'equipment':
        final service = ServiceItem(
          id: order.id,
          name: order.name,
          category: 'equipment_rental',
          bookingType: 'instant',
        );
        Navigator.pushNamed(context, '/equipment-detail',
            arguments: service);
        break;
      case 'assessment':
        final service = ServiceItem(
          id: order.id,
          name: order.name,
          category: order.metadata['service_category'] ?? 'nursing',
          bookingType: 'assessment',
        );
        Navigator.pushNamed(context, '/assessment-request',
            arguments: service);
        break;
    }
  }

  void _viewInMyCare(OrderItem order) {
    // Navigate to service detail — would need an ActiveService, use placeholder
    Navigator.pushNamed(context, '/service-detail');
  }

  void _trackOrder(OrderItem order) {
    final tracking = order.metadata['tracking_info'] as String?;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tracking ?? 'Tracking info not available yet'),
        backgroundColor: HousepitalColors.info,
      ),
    );
  }

  // ==================== ASSESSMENT ACTIONS ====================

  Future<void> _acceptAssessment(AssessmentRequest assessment) async {
    // In full implementation this would open Razorpay first.
    // For now, call the accept API directly.
    try {
      await ApiService().acceptAssessment(assessment.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assessment accepted successfully'),
          backgroundColor: HousepitalColors.success,
        ),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to accept assessment'),
          backgroundColor: HousepitalColors.error,
        ),
      );
    }
  }

  Future<void> _declineAssessment(AssessmentRequest assessment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Quote'),
        content: const Text(
            'Are you sure you want to decline this quote? You can re-request an assessment later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: HousepitalColors.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService().declineAssessment(assessment.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote declined'),
            backgroundColor: HousepitalColors.info,
          ),
        );
        _loadAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decline assessment'),
            backgroundColor: HousepitalColors.error,
          ),
        );
      }
    }
  }

  void _reRequestAssessment(AssessmentRequest assessment) {
    final service = ServiceItem(
      id: assessment.id,
      name: OrderItem.fromAssessment(assessment).name,
      category: assessment.serviceCategory,
      bookingType: 'assessment',
    );
    Navigator.pushNamed(context, '/assessment-request', arguments: service);
  }

  String _assessmentStatusMessage(String status) {
    switch (status) {
      case 'submitted':
        return 'Coordinator will call within 2 hrs';
      case 'in_review':
        return 'Being reviewed by our care team';
      case 'callback_scheduled':
        return 'Callback scheduled';
      case 'quote_sent':
        return 'Review and accept your quote below';
      case 'declined':
        return 'You declined this quote';
      case 'expired':
        return 'This quote has expired';
      default:
        return '';
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: HousepitalColors.orange,
          unselectedLabelColor: HousepitalColors.greyLight,
          indicatorColor: HousepitalColors.orange,
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Assessment Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersTab(),
          _buildAssessmentsTab(),
        ],
      ),
    );
  }

  // ==================== ORDERS TAB ====================

  Widget _buildOrdersTab() {
    if (_ordersLoading) {
      return _buildShimmerList();
    }

    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _orderFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final filter = _orderFilters[i];
              final selected = _orderFilter == filter;
              return FilterChip(
                label: Text(
                  filter[0].toUpperCase() + filter.substring(1),
                ),
                selected: selected,
                selectedColor: HousepitalColors.orangeLight,
                checkmarkColor: HousepitalColors.orange,
                onSelected: (_) {
                  setState(() => _orderFilter = filter);
                },
              );
            },
          ),
        ),

        // Partial failure banner
        if (_ordersError != null) _buildErrorBanner(_ordersError!),

        // Orders list
        Expanded(
          child: _filteredOrders.isEmpty
              ? _buildOrdersEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredOrders.length,
                    itemBuilder: (_, i) =>
                        _buildOrderCard(_filteredOrders[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(OrderItem order) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HousepitalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + name + type badge
            Row(
              children: [
                Icon(
                  _typeIcon(order.type),
                  size: 20,
                  color: HousepitalColors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: HousepitalColors.greyLighter,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _typeBadgeLabel(order.type),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: HousepitalColors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status badge
            StatusBadge(
              text: _statusLabel(order.status),
              color: _statusColor(order.status),
            ),
            const SizedBox(height: 8),

            // Date + amount row
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: HousepitalColors.greyLight),
                const SizedBox(width: 6),
                Text(
                  DateHelper.formatDate(order.date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: HousepitalColors.greyLight,
                  ),
                ),
                if (order.amount != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.payment_outlined,
                      size: 14, color: HousepitalColors.greyLight),
                  const SizedBox(width: 6),
                  Text(
                    DateHelper.formatCurrencyPaise(order.amount!),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black,
                    ),
                  ),
                ],
              ],
            ),

            // Action buttons
            if (_canCancel(order) ||
                _canRate(order) ||
                _canRebook(order) ||
                _canViewInMyCare(order) ||
                _canTrack(order)) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (_canCancel(order))
                    _actionButton(
                      'Cancel',
                      Icons.cancel_outlined,
                      HousepitalColors.error,
                      () => _showCancelDialog(order),
                    ),
                  if (_canRate(order))
                    _actionButton(
                      'Rate',
                      Icons.star_outline,
                      HousepitalColors.orange,
                      () => _showRatingSheet(order),
                    ),
                  if (_canRebook(order))
                    _actionButton(
                      'Re-book',
                      Icons.replay,
                      HousepitalColors.info,
                      () => _rebookOrder(order),
                    ),
                  if (_canViewInMyCare(order))
                    _actionButton(
                      'View in My Care',
                      Icons.visibility_outlined,
                      HousepitalColors.success,
                      () => _viewInMyCare(order),
                    ),
                  if (_canTrack(order))
                    _actionButton(
                      'Track',
                      Icons.local_shipping_outlined,
                      HousepitalColors.info,
                      () => _trackOrder(order),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 32,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  Widget _buildOrdersEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: HousepitalColors.divider,
          ),
          const SizedBox(height: 16),
          const Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HousepitalColors.greyLight,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Book a service or add equipment to your cart to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: HousepitalColors.greyLight,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.add),
            label: const Text('Book a Service'),
          ),
        ],
      ),
    );
  }

  // ==================== ASSESSMENTS TAB ====================

  Widget _buildAssessmentsTab() {
    if (_assessmentsLoading) {
      return _buildShimmerList();
    }

    if (_assessmentsError != null && _pendingAssessments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_assessmentsError!,
                style: const TextStyle(color: HousepitalColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadAll,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pendingAssessments.isEmpty) {
      return _buildAssessmentsEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingAssessments.length,
        itemBuilder: (_, i) =>
            _buildAssessmentCard(_pendingAssessments[i]),
      ),
    );
  }

  Widget _buildAssessmentCard(AssessmentRequest assessment) {
    final orderItem = OrderItem.fromAssessment(assessment);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HousepitalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 20,
                  color: HousepitalColors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    orderItem.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status badge
            StatusBadge(
              text: _statusLabel(assessment.status),
              color: _statusColor(assessment.status),
            ),
            const SizedBox(height: 8),

            // Date
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: HousepitalColors.greyLight),
                const SizedBox(width: 6),
                Text(
                  DateHelper.formatDate(assessment.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: HousepitalColors.greyLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status message
            Text(
              _assessmentStatusMessage(assessment.status),
              style: const TextStyle(
                fontSize: 13,
                color: HousepitalColors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),

            // Quote display for quote_sent
            if (assessment.status == 'quote_sent' &&
                assessment.quote != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HousepitalColors.orangeLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Quoted: ${DateHelper.formatCurrencyPaise(assessment.quote!['commission_monthly'] as int? ?? 0)}/month',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.orangeText,
                  ),
                ),
              ),
            ],

            // Action buttons
            if (assessment.status == 'quote_sent') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => _declineAssessment(assessment),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HousepitalColors.error,
                          side: const BorderSide(
                              color: HousepitalColors.error),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () =>
                            _acceptAssessment(assessment),
                        child: const Text('Accept & Pay'),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Re-request for declined/expired
            if (assessment.status == 'declined' ||
                assessment.status == 'expired') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () => _reRequestAssessment(assessment),
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Re-request Assessment'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentsEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: HousepitalColors.divider,
          ),
          const SizedBox(height: 16),
          const Text(
            'No pending requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HousepitalColors.greyLight,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Request an assessment for nursing, caretaker, or other manpower services.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: HousepitalColors.greyLight,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.add),
            label: const Text('Request Assessment'),
          ),
        ],
      ),
    );
  }

  // ==================== SHARED WIDGETS ====================

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HousepitalColors.warningLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: HousepitalColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: HousepitalColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
