import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/payment_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String _filter = 'all';

  // Mock invoices for preview
  static final _mockInvoices = [
    Invoice.fromJson({
      'id': 'inv1',
      'invoice_number': 'INV-2026-003',
      'patient_id': 'p1',
      'billing_period_start': '2026-03-01',
      'billing_period_end': '2026-03-15',
      'line_items': [
        {'description': 'Nurse (24hr) — 15 days', 'amount': 18000, 'gst': 3240, 'total': 21240, 'type': 'manpower'},
        {'description': 'Medical consumables', 'amount': 2500, 'gst': 450, 'total': 2950, 'type': 'consumables'},
      ],
      'subtotal': 20500,
      'gst_total': 3690,
      'grand_total': 24190,
      'due_date': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      'status': 'pending',
    }),
    Invoice.fromJson({
      'id': 'inv2',
      'invoice_number': 'INV-2026-002',
      'patient_id': 'p1',
      'billing_period_start': '2026-02-16',
      'billing_period_end': '2026-02-28',
      'line_items': [
        {'description': 'Nurse (24hr) — 13 days', 'amount': 15600, 'gst': 2808, 'total': 18408, 'type': 'manpower'},
        {'description': 'ECG at Home', 'amount': 500, 'gst': 90, 'total': 590, 'type': 'diagnostics'},
      ],
      'subtotal': 16100,
      'gst_total': 2898,
      'grand_total': 18998,
      'due_date': '2026-03-10',
      'status': 'overdue',
    }),
    Invoice.fromJson({
      'id': 'inv3',
      'invoice_number': 'INV-2026-001',
      'patient_id': 'p1',
      'billing_period_start': '2026-02-01',
      'billing_period_end': '2026-02-15',
      'line_items': [
        {'description': 'Nurse (24hr) — 15 days', 'amount': 18000, 'gst': 3240, 'total': 21240, 'type': 'manpower'},
      ],
      'subtotal': 18000,
      'gst_total': 3240,
      'grand_total': 21240,
      'due_date': '2026-02-25',
      'status': 'paid',
    }),
  ];

  List<Invoice> get _filteredInvoices {
    if (_filter == 'all') return _mockInvoices;
    return _mockInvoices.where((i) => i.status == _filter).toList();
  }

  int get _totalDue => _mockInvoices
      .where((i) => i.status != 'paid')
      .fold(0, (sum, i) => sum + i.grandTotal);

  int get _totalPaid => _mockInvoices
      .where((i) => i.status == 'paid')
      .fold(0, (sum, i) => sum + i.grandTotal);

  int get _overdueCount => _mockInvoices.where((i) => i.status == 'overdue').length;

  // Mock spend summary data by category
  static const _spendSummary = [
    {'category': 'Manpower', 'amount': 51600, 'icon': Icons.people, 'color': Color(0xFF1565C0)},
    {'category': 'Equipment', 'amount': 2500, 'icon': Icons.medical_services, 'color': Color(0xFFE65100)},
    {'category': 'Diagnostics', 'amount': 500, 'icon': Icons.biotech, 'color': Color(0xFF2E7D32)},
  ];

  int get _totalSpend => _spendSummary.fold(0, (sum, item) => sum + (item['amount'] as int));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('billing_title')),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/transactions'),
            icon: const Icon(Icons.receipt_long, size: 18, color: HousepitalColors.orangeText),
            label: const Text('Transactions',
                style: TextStyle(color: HousepitalColors.orangeText, fontSize: 13)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Balance card
            _buildBalanceCard(l),
            const SizedBox(height: 16),

            // Summary stats row
            _buildSummaryRow(),
            const SizedBox(height: 20),

            // Spend Summary section
            _buildSpendSummary(),
            const SizedBox(height: 20),

            // Invoices header + filter
            Row(
              children: [
                const Expanded(
                  child: Text('Invoices',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                PopupMenuButton<String>(
                  initialValue: _filter,
                  onSelected: (v) => setState(() => _filter = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('All')),
                    PopupMenuItem(value: 'pending', child: Text('Pending')),
                    PopupMenuItem(value: 'overdue', child: Text('Overdue')),
                    PopupMenuItem(value: 'paid', child: Text('Paid')),
                  ],
                  child: Semantics(
                    label: 'Filter invoices, currently showing ${_filter == 'all' ? 'All' : _filter}',
                    button: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _filter == 'all' ? 'All' : _filter[0].toUpperCase() + _filter.substring(1),
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

            if (_filteredInvoices.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l.t('no_data'),
                      style: const TextStyle(color: HousepitalColors.greyLight)),
                ),
              )
            else
              ..._filteredInvoices.map((invoice) => _buildInvoiceCard(invoice, l)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(AppLocalizations l) {
    return Semantics(
      label: 'Total outstanding balance: ${DateHelper.formatCurrency(_totalDue)}, $_overdueCount invoices overdue',
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
              DateHelper.formatCurrency(_totalDue),
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            if (_overdueCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$_overdueCount invoice${_overdueCount > 1 ? 's' : ''} overdue',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final paymentService = PaymentService();
                  paymentService.openCheckout(
                    amount: _totalDue * 100, // Convert to paise
                    description: 'Outstanding balance payment',
                    onSuccess: () {
                      paymentService.dispose();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment successful!'),
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
                            content: Text('Payment failed: $message'),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Total paid: ${DateHelper.formatCurrency(_totalPaid)}',
            child: _summaryTile('Total Paid', DateHelper.formatCurrency(_totalPaid),
                Icons.check_circle, HousepitalColors.success),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            label: 'Total invoices: ${_mockInvoices.length}',
            child: _summaryTile('Invoices', '${_mockInvoices.length}',
                Icons.receipt, HousepitalColors.grey),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            label: 'Overdue invoices: $_overdueCount',
            child: _summaryTile('Overdue', '$_overdueCount',
                Icons.warning_amber, _overdueCount > 0 ? HousepitalColors.error : HousepitalColors.greyLight),
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

  Widget _buildSpendSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Spend Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('This month by category',
            style: const TextStyle(fontSize: 13, color: HousepitalColors.greyLight)),
        const SizedBox(height: 12),

        // Stacked bar
        Semantics(
          label: 'Spend breakdown bar chart',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: _spendSummary.map((item) {
                  final fraction = _totalSpend > 0
                      ? (item['amount'] as int) / _totalSpend
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
        ..._spendSummary.map((item) {
          final amount = item['amount'] as int;
          final percentage = _totalSpend > 0
              ? ((amount / _totalSpend) * 100).toStringAsFixed(1)
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

  Widget _buildInvoiceCard(Invoice invoice, AppLocalizations l) {
    Color statusColor;
    switch (invoice.status) {
      case 'paid':
        statusColor = HousepitalColors.success;
        break;
      case 'overdue':
        statusColor = HousepitalColors.error;
        break;
      default:
        statusColor = HousepitalColors.warning;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: 'Invoice ${invoice.invoiceNumber}, amount ${DateHelper.formatCurrency(invoice.grandTotal)}, status ${invoice.status}',
        button: true,
        child: HousepitalCard(
          onTap: () => Navigator.pushNamed(context, '/invoice-detail', arguments: invoice),
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
                      invoice.invoiceNumber,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: HousepitalColors.black),
                    ),
                    Text(
                      '${DateHelper.formatDateShort(invoice.billingPeriodStart)} – ${DateHelper.formatDateShort(invoice.billingPeriodEnd)}',
                      style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateHelper.formatCurrency(invoice.grandTotal),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: HousepitalColors.black),
                  ),
                  StatusBadge(text: invoice.status.toUpperCase(), color: statusColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
