// audit batch 4 (Agent J): TODO — migrate billing state off AppProvider and
// onto the now-wired BillingProvider (lib/providers/billing_provider.dart).
// AppProvider currently bundles billing into loadDashboard(); BillingProvider
// gives this screen a dedicated loadBillingSummary() + isLoading/error that
// don't tangle with the dashboard's lifecycle. Out of scope for this batch
// (provider wiring only) — leaving the screen wired to AppProvider for now.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/orders_provider.dart';
import '../../services/payment_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../utils/permissions.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String _filter = 'all';

  // C3 calm pass (iOS large-title pattern): the display title lives in the
  // body; the GlassAppBar title only fades in once the body title has
  // scrolled under the bar.
  final ScrollController _scrollController = ScrollController();
  bool _showBarTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show =
        _scrollController.hasClients && _scrollController.offset > 28;
    if (show != _showBarTitle) setState(() => _showBarTitle = show);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredOrders(List<Map<String, dynamic>> orders) {
    if (_filter == 'all') return orders;
    return orders.where((o) => o['status'] == _filter).toList();
  }

  int _totalOutstanding(List<Map<String, dynamic>> orders) {
    return orders
        .where((o) =>
            // Quote-pending orders have no amount yet — excluded from sums.
            !OrdersProvider.isQuotePending(o) &&
            (o['status'] == 'confirmed' || o['status'] == 'in_progress'))
        .fold(0, (sum, o) => sum + ((o['totalAmount'] as int?) ?? 0));
  }

  int _totalPaid(List<Map<String, dynamic>> orders) {
    return orders
        .where((o) =>
            !OrdersProvider.isQuotePending(o) && o['status'] == 'completed')
        .fold(0, (sum, o) => sum + ((o['totalAmount'] as int?) ?? 0));
  }

  int _overdueCount(List<Map<String, dynamic>> orders) {
    // Orders confirmed more than 7 days ago count as overdue
    final now = DateTime.now();
    return orders.where((o) {
      if (o['status'] != 'confirmed') return false;
      final createdAt = DateTime.tryParse(o['createdAt'] as String? ?? '');
      if (createdAt == null) return false;
      return now.difference(createdAt).inDays > 7;
    }).length;
  }

  /// Compute spend summary grouped by category (service vs equipment)
  List<Map<String, dynamic>> _spendSummary(List<Map<String, dynamic>> orders) {
    int serviceSpend = 0;
    int equipmentSpend = 0;

    for (final order in orders) {
      final items = order['items'] as List<dynamic>? ?? [];
      for (final itemJson in items) {
        final item = itemJson is Map<String, dynamic>
            ? CartItem.fromJson(itemJson)
            : null;
        if (item == null) continue;
        if (item.isService) {
          serviceSpend += item.lineTotal;
        } else {
          equipmentSpend += item.lineTotal;
        }
      }
    }

    final result = <Map<String, dynamic>>[];
    // Neutral categorical ramp — these are categories, not statuses, so they
    // must not borrow status colors (amber would falsely read as a warning).
    if (serviceSpend > 0) {
      result.add({
        'category': 'Services',
        'amount': serviceSpend,
        'icon': Icons.medical_services,
        'color': context.hc.orange,
      });
    }
    if (equipmentSpend > 0) {
      result.add({
        'category': 'Equipment',
        'amount': equipmentSpend,
        'icon': Icons.inventory_2,
        'color': context.hc.grey,
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ordersProvider = context.watch<OrdersProvider>();
    final role = context.watch<AppProvider>().currentUserRole;
    final canPay = canUserPerform(role, UserAction.pay);
    final orders = ordersProvider.orders;
    final filtered = _filteredOrders(orders);
    final totalDue = _totalOutstanding(orders);
    final totalPaidAmount = _totalPaid(orders);
    final overdue = _overdueCount(orders);
    final spend = _spendSummary(orders);

    return Scaffold(
      // Liquid Glass: content scrolls under the translucent app bar.
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        showHome: true, // owner: home button on every screen (only the Home tab omits it)
        // Owner (field round 4): no cart on Billing, and Transaction History
        // is icon-only — the labeled button crowded the bar until the title
        // truncated to 'Bi…'.
        showCart: false,
        // Bar title fades in only after the in-body large title scrolls
        // under the bar (iOS large-title style).
        title: AnimatedOpacity(
          opacity: _showBarTitle ? 1.0 : 0.0,
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 150),
          child: Text(l.t('billing_title')),
        ),
        actions: [
          IconButton(
            tooltip: l.t('transaction_history'),
            onPressed: () => Navigator.pushNamed(context, '/transactions'),
            icon: const Icon(Icons.receipt_long),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + kToolbarHeight + 16,
            16,
            16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Large display title (C3 calm pass) — confident in-body
            // large-title header; the bar title takes over once scrolled.
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l.t('billing_title'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.hc.black,
                ),
              ),
            ),

            // Balance card
            _buildBalanceCard(l, totalDue, overdue, canPay: canPay),
            const SizedBox(height: 16),

            // Summary stats row
            _buildSummaryRow(totalPaidAmount, orders.length, overdue),
            const SizedBox(height: 20),

            // Spend Summary section
            if (spend.isNotEmpty) ...[
              _buildSpendSummary(spend),
              const SizedBox(height: 20),
            ],

            // Orders / Invoices header + filter
            Row(
              children: [
                Expanded(
                  child: Text(l.t('my_orders'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                PopupMenuButton<String>(
                  initialValue: _filter,
                  onSelected: (v) => setState(() => _filter = v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'all', child: Text(l.t('all'))),
                    PopupMenuItem(value: 'confirmed', child: Text(l.t('status_confirmed'))),
                    PopupMenuItem(value: 'completed', child: Text(l.t('completed'))),
                  ],
                  child: Semantics(
                    label: 'Filter orders, currently showing ${_filter == 'all' ? 'All' : _filter}',
                    button: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _filter == 'all' ? l.t('all') : _filter[0].toUpperCase() + _filter.substring(1),
                            style: TextStyle(
                                fontSize: 13, color: context.hc.orangeText, fontWeight: FontWeight.w500),
                          ),
                          Icon(Icons.arrow_drop_down, color: context.hc.orangeText, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (filtered.isEmpty)
              HousepitalEmptyState(
                icon: Icons.receipt_long_outlined,
                title: l.t('billing_empty_title'),
                body: l.t('billing_empty_body'),
              )
            else
              ...filtered.map((order) => _buildOrderCard(order, l)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(AppLocalizations l, int totalDue, int overdueCount,
      {required bool canPay}) {
    return Semantics(
      label: 'Total outstanding balance: ${DateHelper.formatCurrency(totalDue)}, $overdueCount orders overdue',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [HousepitalColors.orange, context.hc.orangeDark],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total Outstanding',
                style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 4),
            Text(
              DateHelper.formatCurrency(totalDue),
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            if (overdueCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$overdueCount order${overdueCount > 1 ? 's' : ''} overdue',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
            if (totalDue > 0) ...[
              const SizedBox(height: 16),
              if (canPay)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final paymentService = PaymentService();
                      paymentService.openCheckout(
                        amount: totalDue * 100,
                        description: 'Outstanding balance payment',
                        onSuccess: () {
                          paymentService.dispose();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l.t('payment_successful')),
                                backgroundColor: context.hc.success,
                              ),
                            );
                          }
                        },
                        onFailure: (message) {
                          paymentService.dispose();
                          if (context.mounted) {
                            // Razorpay messages already start with "Payment
                            // Failed - …" — don't double the prefix.
                            final lower = message.toLowerCase();
                            final text = lower.contains('payment failed')
                                ? message
                                : '${l.t('payment_failed')}: $message';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(text),
                                backgroundColor: context.hc.error,
                              ),
                            );
                          }
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: HousepitalColors.orange,
                    ),
                    child: Text(l.t('pay_now')),
                  ),
                )
              else
                // Read-only roles see a clear hint instead of the Pay button.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Only the primary contact can pay this balance.',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(int totalPaidAmount, int totalOrders, int overdueCount) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Total paid: ${DateHelper.formatCurrency(totalPaidAmount)}',
            child: _summaryTile('Total Paid', DateHelper.formatCurrency(totalPaidAmount),
                Icons.check_circle, context.hc.success),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: 'Total orders: $totalOrders',
            child: _summaryTile('Orders', '$totalOrders',
                Icons.receipt, context.hc.grey),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: 'Overdue orders: $overdueCount',
            child: _summaryTile('Overdue', '$overdueCount',
                Icons.warning_amber, overdueCount > 0 ? context.hc.error : context.hc.greyLight),
          ),
        ),
      ],
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return HousepitalCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 12, color: context.hc.greyLight)),
        ],
      ),
    );
  }

  Widget _buildSpendSummary(List<Map<String, dynamic>> spend) {
    final totalSpend = spend.fold(0, (sum, item) => sum + (item['amount'] as int));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Spend Summary'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('By category',
              style: TextStyle(fontSize: 13, color: context.hc.greyLight)),
        ),
        const SizedBox(height: 12),

        // Stacked bar
        Semantics(
          label: 'Spend breakdown bar chart',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: spend.map((item) {
                  final fraction = totalSpend > 0
                      ? (item['amount'] as int) / totalSpend
                      : 0.0;
                  return Expanded(
                    flex: (fraction * 1000).round().clamp(1, 1000),
                    child: Container(color: item['color'] as Color),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Category rows
        ...spend.map((item) {
          final amount = item['amount'] as int;
          final percentage = totalSpend > 0
              ? ((amount / totalSpend) * 100).toStringAsFixed(1)
              : '0';
          return Semantics(
            label: '${item['category']}: ${DateHelper.formatCurrency(amount)}, $percentage percent',
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: item['color'] as Color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['category'] as String,
                      style: TextStyle(fontSize: 14, color: context.hc.grey),
                    ),
                  ),
                  Text(
                    DateHelper.formatCurrency(amount),
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: context.hc.black),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$percentage%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: context.hc.greyLight),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, AppLocalizations l) {
    final status = order['status'] as String? ?? 'confirmed';
    final totalAmount = order['totalAmount'] as int? ?? 0;
    // Quote-pending: no amount yet — never render ₹0 for these.
    final quotePending = OrdersProvider.isQuotePending(order);
    final bookingNumber = order['id'] as String? ?? '';
    final createdAt = DateTime.tryParse(order['createdAt'] as String? ?? '');
    final items = order['items'] as List<dynamic>? ?? [];
    final itemCount = items.length;
    final firstItemName = items.isNotEmpty
        ? (items.first is Map<String, dynamic>
            ? (items.first['name'] as String? ?? 'Order')
            : 'Order')
        : 'Order';

    // audit M-12: surface pending refund so users tracking a cancellation
    // know money is on the way and roughly when.
    final refundStatus = order['refundStatus'] as String?;
    final refundAmount = (order['refundAmount'] as num?)?.toInt() ?? 0;
    final refundEta = DateTime.tryParse(order['refundEta'] as String? ?? '');
    final showRefundLine =
        refundStatus == 'pending' && refundAmount > 0;

    Color statusColor;
    switch (status) {
      // Delivered/completed are GOOD outcomes — green (field report:
      // 'Why is delivered highlighted in red?'; it was falling through to
      // the warning default).
      case 'completed':
      case 'delivered':
      case 'in_progress':
        statusColor = context.hc.success;
        break;
      case 'cancelled':
        statusColor = context.hc.error;
        break;
      case 'confirmed':
      case 'assigned':
      case 'dispatched':
        statusColor = context.hc.info;
        break;
      default:
        statusColor = context.hc.warning;
    }

    final subtitle = itemCount > 1
        ? '$firstItemName + ${itemCount - 1} more'
        : firstItemName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: quotePending
            ? 'Order $bookingNumber, quote pending — price will be confirmed on call, status $status'
            : 'Order $bookingNumber, amount ${DateHelper.formatCurrency(totalAmount)}, status $status',
        button: true,
        child: HousepitalCard(
          onTap: () => Navigator.pushNamed(
            context,
            '/order-tracking',
            arguments: <String, dynamic>{
              'bookingId': order['id'] as String?,
              'orderType': order['type'] as String? ?? 'equipment',
              'quotePending': quotePending,
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppIconTile(
                    icon: Icons.receipt_long,
                    color: HousepitalColors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookingNumber,
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: context.hc.black),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: context.hc.greyLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (createdAt != null)
                          Text(
                            DateHelper.formatRelative(createdAt),
                            style: TextStyle(fontSize: 11, color: context.hc.greyLight),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Quote-pending orders never render a ₹ amount.
                      if (quotePending)
                        StatusBadge(
                            text: 'Quote pending',
                            color: context.hc.warning)
                      else
                        Text(
                          DateHelper.formatCurrency(totalAmount),
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, color: context.hc.black),
                        ),
                      const SizedBox(height: 2),
                      StatusBadge(text: status.toUpperCase(), color: statusColor),
                    ],
                  ),
                ],
              ),
              // Quote-pending hint line — replaces any money figure.
              if (quotePending) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone_in_talk_outlined,
                        size: 14, color: context.hc.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Price will be confirmed on call',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.hc.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // audit M-12: pending refund chip
              if (showRefundLine) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.hc.infoLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                          size: 14, color: context.hc.info),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          refundEta != null
                              ? 'Refund: ${DateHelper.formatCurrency(refundAmount)} pending (by ${DateHelper.formatDate(refundEta)})'
                              : 'Refund: ${DateHelper.formatCurrency(refundAmount)} pending',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.hc.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
