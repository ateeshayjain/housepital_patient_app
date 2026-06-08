import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/orders_provider.dart';
import '../../utils/helpers.dart';
import '../../utils/permissions.dart';
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
  String _orderFilter = 'all';

  static const _orderFilters = ['all', 'active', 'completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==================== FILTER LOGIC ====================

  List<Map<String, dynamic>> _filteredOrders(
      List<Map<String, dynamic>> orders) {
    if (_orderFilter == 'all') return orders;
    return orders.where((o) {
      final status = o['status'] as String? ?? '';
      switch (_orderFilter) {
        case 'active':
          return _isActiveStatus(status);
        case 'completed':
          return _isCompletedStatus(status);
        case 'cancelled':
          return _isCancelledStatus(status);
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
    }.contains(status);
  }

  bool _isCompletedStatus(String status) {
    return const {'completed', 'delivered'}.contains(status);
  }

  bool _isCancelledStatus(String status) {
    return const {'cancelled'}.contains(status);
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
      case 'completed':
      case 'delivered':
        return HousepitalColors.success;
      case 'cancelled':
        return HousepitalColors.error;
      case 'submitted':
      case 'in_review':
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
      case 'submitted':
        return 'Submitted';
      case 'in_review':
        return 'In Review';
      case 'quote_sent':
        return 'Quote Sent';
      case 'declined':
        return 'Declined';
      case 'expired':
        return 'Expired';
      default:
        return status;
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
    final ordersProvider = context.watch<OrdersProvider>();
    final allOrders = ordersProvider.orders;
    final filtered = _filteredOrders(allOrders);

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
            separatorBuilder: (_, _) => const SizedBox(width: 8),
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

        // Orders list
        Expanded(
          child: filtered.isEmpty
              ? _buildOrdersEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      _buildOrderCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'confirmed';
    final orderId = order['id'] as String? ?? '';
    final totalAmount = order['totalAmount'] as int? ?? 0;
    final createdAt = order['createdAt'] as String?;
    final orderType = order['type'] as String? ?? 'equipment';
    final itemsList = order['items'] as List<dynamic>? ?? [];

    // Parse items for display
    final itemNames = itemsList
        .take(3)
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item['name'] as String? ?? 'Item';
          }
          return 'Item';
        })
        .toList();

    final itemsSummary = itemNames.join(', ') +
        (itemsList.length > 3 ? ' +${itemsList.length - 3} more' : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HousepitalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + booking number + type badge
            Row(
              children: [
                Icon(
                  orderType == 'equipment'
                      ? Icons.precision_manufacturing_outlined
                      : orderType == 'mixed'
                          ? Icons.shopping_bag_outlined
                          : Icons.medical_services_outlined,
                  size: 20,
                  color: HousepitalColors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    orderId,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HousepitalColors.greyLighter,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    orderType.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: HousepitalColors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Items summary
            Text(
              itemsSummary,
              style: const TextStyle(
                fontSize: 14,
                color: HousepitalColors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Status badge
            StatusBadge(
              text: _statusLabel(status),
              color: _statusColor(status),
            ),
            const SizedBox(height: 8),

            // Date + amount row
            Row(
              children: [
                if (createdAt != null) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: HousepitalColors.greyLight),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      DateHelper.formatDate(DateTime.parse(createdAt)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: HousepitalColors.greyLight,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 16),
                const Icon(Icons.payment_outlined,
                    size: 14, color: HousepitalColors.greyLight),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    DateHelper.formatCurrency(totalAmount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black,
                    ),
                  ),
                ),
              ],
            ),

            // Cancel button for active orders — only available to roles
            // that can pay (i.e., PRIMARY_CONTACT). Other roles see no action.
            if (_isActiveStatus(status) &&
                canUserPerform(
                    context.watch<AppProvider>().currentUserRole,
                    UserAction.pay)) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _actionButton(
                    'Cancel',
                    Icons.cancel_outlined,
                    HousepitalColors.error,
                    () => _showCancelDialog(orderId),
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

  Future<void> _showCancelDialog(String orderId) async {
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
                  orderId,
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
                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (v) {
                    setModalState(() => selectedReason = v);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: reasons
                        .map((reason) => RadioListTile<String>(
                              title: Text(reason,
                                  style: const TextStyle(fontSize: 14)),
                              value: reason,
                              activeColor: HousepitalColors.orange,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ))
                        .toList(),
                  ),
                ),
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
      context.read<OrdersProvider>().cancelOrder(orderId, selectedReason!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully'),
          backgroundColor: HousepitalColors.success,
        ),
      );
    }
  }

  Widget _buildOrdersEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: HousepitalColors.greyLight,
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
    final ordersProvider = context.watch<OrdersProvider>();
    final assessments = ordersProvider.assessments;

    if (assessments.isEmpty) {
      return _buildAssessmentsEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assessments.length,
      itemBuilder: (_, i) => _buildAssessmentCard(assessments[i]),
    );
  }

  Widget _buildAssessmentCard(Map<String, dynamic> assessment) {
    final status = assessment['status'] as String? ?? 'submitted';
    final serviceName = assessment['serviceName'] as String? ?? 'Assessment';
    final serviceId = assessment['serviceId'] as String? ?? '';
    final assessmentId = assessment['id'] as String? ?? '';
    final createdAt = assessment['createdAt'] as String?;
    // audit M-11: only let users mutate requests still in early lifecycle.
    final isPending = status == 'submitted' || status == 'in_review';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HousepitalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 20,
                  color: HousepitalColors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    serviceName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Assessment ID
            Text(
              assessmentId,
              style: const TextStyle(
                fontSize: 12,
                color: HousepitalColors.greyLight,
              ),
            ),
            const SizedBox(height: 8),

            // Status badge
            StatusBadge(
              text: _statusLabel(status),
              color: _statusColor(status),
            ),
            const SizedBox(height: 8),

            // Date
            if (createdAt != null)
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: HousepitalColors.greyLight),
                  const SizedBox(width: 6),
                  Text(
                    DateHelper.formatDate(DateTime.parse(createdAt)),
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
              _assessmentStatusMessage(status),
              style: const TextStyle(
                fontSize: 13,
                color: HousepitalColors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),

            // audit M-11: edit / cancel actions while still actionable.
            if (isPending) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _editAssessment(serviceId, serviceName),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit request',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: HousepitalColors.orange,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _cancelAssessment(assessmentId),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel request',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: HousepitalColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // audit M-11: rebuild a minimal ServiceItem from persisted id/name so the
  // request screen has something to render. The screen only reads .id and
  // .name from widget.service (id drives the subtype switch).
  void _editAssessment(String serviceId, String serviceName) {
    if (serviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot edit this request — service no longer available.')),
      );
      return;
    }
    final stub = ServiceItem(
      id: serviceId,
      name: serviceName,
      category: 'manpower',
      bookingType: 'assessment',
    );
    Navigator.pushNamed(context, '/assessment-request', arguments: stub);
  }

  // audit M-11: destructive confirm before flipping the assessment to
  // cancelled. Uses the shared confirmDestructiveAction helper for parity
  // with cart/order cancellation flows.
  Future<void> _cancelAssessment(String assessmentId) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Cancel request?',
      message:
          'This will withdraw your assessment request. Our team will stop following up.',
      confirmLabel: 'Cancel request',
      cancelLabel: 'Keep it',
    );
    if (!confirmed || !mounted) return;
    context.read<OrdersProvider>().cancelAssessment(assessmentId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assessment request cancelled'),
        backgroundColor: HousepitalColors.success,
      ),
    );
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

  Widget _buildAssessmentsEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: HousepitalColors.greyLight,
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
}
