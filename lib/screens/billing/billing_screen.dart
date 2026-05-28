import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/orders_provider.dart';
import '../../services/payment_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../utils/permissions.dart';
import '../../widgets/common_widgets.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String _filter = 'all';

  List<Map<String, dynamic>> _filteredOrders(List<Map<String, dynamic>> orders) {
    if (_filter == 'all') return orders;
    return orders.where((o) => o['status'] == _filter).toList();
  }

  int _totalOutstanding(List<Map<String, dynamic>> orders) {
    return orders
        .where((o) =>
            o['status'] == 'confirmed' || o['status'] == 'in_progress')
        .fold(0, (sum, o) => sum + ((o['totalAmount'] as int?) ?? 0));
  }

  int _totalPaid(List<Map<String, dynamic>> orders) {
    return orders
        .where((o) => o['status'] == 'completed')
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
    if (serviceSpend > 0) {
      result.add({
        'category': 'Services',
        'amount': serviceSpend,
        'icon': Icons.medical_services,
        'color': const Color(0xFF1565C0),
      });
    }
    if (equipmentSpend > 0) {
      result.add({
        'category': 'Equipment',
        'amount': equipmentSpend,
        'icon': Icons.inventory_2,
        'color': const Color(0xFFE65100),
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
      appBar: AppBar(
        title: Text(l.t('billing_title')),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/transactions'),
            icon: const Icon(Icons.receipt_long, size: 18, color: HousepitalColors.orangeText),
            label: Text(l.t('transaction_history'),
                style: const TextStyle(color: HousepitalColors.orangeText, fontSize: 13)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                            style: const TextStyle(
                                fontSize: 13, color: HousepitalColors.orangeText, fontWeight: FontWeight.w500),
                          ),
                          const Icon(Icons.arrow_drop_down, color: HousepitalColors.orangeText, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 48, color: HousepitalColors.greyLight),
                      const SizedBox(height: 12),
                      Text(l.t('no_data'),
                          style: const TextStyle(color: HousepitalColors.greyLight)),
                    ],
                  ),
                ),
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
          gradient: const LinearGradient(
            colors: [HousepitalColors.orange, HousepitalColors.orangeDark],
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
                                backgroundColor: HousepitalColors.success,
                              ),
                            );
                          }
                        },
                        onFailure: (message) {
                          paymentService.dispose();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('${l.t('payment_failed')}: $message'),
                                backgroundColor: HousepitalColors.error,
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
                Icons.check_circle, HousepitalColors.success),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            label: 'Total orders: $totalOrders',
            child: _summaryTile('Orders', '$totalOrders',
                Icons.receipt, HousepitalColors.grey),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            label: 'Overdue orders: $overdueCount',
            child: _summaryTile('Overdue', '$overdueCount',
                Icons.warning_amber, overdueCount > 0 ? HousepitalColors.error : HousepitalColors.greyLight),
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
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
        ],
      ),
    );
  }

  Widget _buildSpendSummary(List<Map<String, dynamic>> spend) {
    final totalSpend = spend.fold(0, (sum, item) => sum + (item['amount'] as int));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Spend Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('By category',
            style: TextStyle(fontSize: 13, color: HousepitalColors.greyLight)),
        const SizedBox(height: 12),

        // Stacked bar
        Semantics(
          label: 'Spend breakdown bar chart',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['category'] as String,
                      style: const TextStyle(fontSize: 14, color: HousepitalColors.grey),
                    ),
                  ),
                  Text(
                    DateHelper.formatCurrency(amount),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: HousepitalColors.black),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$percentage%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
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
    final bookingNumber = order['id'] as String? ?? '';
    final createdAt = DateTime.tryParse(order['createdAt'] as String? ?? '');
    final items = order['items'] as List<dynamic>? ?? [];
    final itemCount = items.length;
    final firstItemName = items.isNotEmpty
        ? (items.first is Map<String, dynamic>
            ? (items.first['name'] as String? ?? 'Order')
            : 'Order')
        : 'Order';

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = HousepitalColors.success;
        break;
      case 'cancelled':
        statusColor = HousepitalColors.error;
        break;
      default:
        statusColor = HousepitalColors.warning;
    }

    final subtitle = itemCount > 1
        ? '$firstItemName + ${itemCount - 1} more'
        : firstItemName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: 'Order $bookingNumber, amount ${DateHelper.formatCurrency(totalAmount)}, status $status',
        button: true,
        child: HousepitalCard(
          onTap: () => Navigator.pushNamed(
            context,
            '/order-tracking',
            arguments: <String, dynamic>{
              'bookingId': order['id'] as String?,
              'orderType': order['type'] as String? ?? 'equipment',
            },
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HousepitalColors.orangeLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: HousepitalColors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookingNumber,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: HousepitalColors.black),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null)
                      Text(
                        DateHelper.formatRelative(createdAt),
                        style: const TextStyle(fontSize: 11, color: HousepitalColors.greyLight),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateHelper.formatCurrency(totalAmount),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: HousepitalColors.black),
                  ),
                  StatusBadge(text: status.toUpperCase(), color: statusColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
