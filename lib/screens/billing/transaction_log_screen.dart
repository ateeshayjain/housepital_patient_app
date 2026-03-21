import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class TransactionLogScreen extends StatefulWidget {
  const TransactionLogScreen({super.key});

  @override
  State<TransactionLogScreen> createState() => _TransactionLogScreenState();
}

class _TransactionLogScreenState extends State<TransactionLogScreen> {
  String _selectedFilter = 'all';

  static final _mockTransactions = [
    PaymentTransaction.fromJson({
      'id': 't1',
      'patient_id': 'p1',
      'invoice_id': 'inv1',
      'amount': 24500,
      'method': 'upi',
      'status': 'completed',
      'razorpay_payment_id': 'pay_ABC123',
      'description': 'Invoice #INV-2026-001 — March billing',
      'created_at':
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'completed_at':
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    }),
    PaymentTransaction.fromJson({
      'id': 't2',
      'patient_id': 'p1',
      'booking_id': 'b1',
      'amount': 1500,
      'method': 'card',
      'status': 'completed',
      'razorpay_payment_id': 'pay_DEF456',
      'description': 'Sleep Therapy session booking',
      'created_at':
          DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      'completed_at':
          DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
    }),
    PaymentTransaction.fromJson({
      'id': 't3',
      'patient_id': 'p1',
      'amount': 800,
      'method': 'upi',
      'status': 'failed',
      'failure_reason': 'Payment declined by bank',
      'description': 'X-Ray at Home booking',
      'created_at':
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
    }),
    PaymentTransaction.fromJson({
      'id': 't4',
      'patient_id': 'p1',
      'invoice_id': 'inv0',
      'amount': 22000,
      'method': 'netbanking',
      'status': 'completed',
      'razorpay_payment_id': 'pay_GHI789',
      'description': 'Invoice #INV-2026-000 — February billing',
      'created_at':
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      'completed_at':
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
    }),
    PaymentTransaction.fromJson({
      'id': 't5',
      'patient_id': 'p1',
      'booking_id': 'b2',
      'amount': 500,
      'method': 'upi',
      'status': 'refunded',
      'razorpay_payment_id': 'pay_JKL012',
      'refund_amount': 500,
      'refund_id': 'rfnd_001',
      'description': 'ECG at Home — cancelled',
      'created_at':
          DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
      'completed_at':
          DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
    }),
  ];

  List<PaymentTransaction> get _filteredTransactions {
    if (_selectedFilter == 'all') return _mockTransactions;
    return _mockTransactions
        .where((t) => t.status == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final transactions = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('transaction_history'))),
      body: Column(
        children: [
          // Filter chips — 44pt minimum height
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('all', l.t('all'), l),
                const SizedBox(width: 8),
                _buildFilterChip('completed', l.t('completed'), l),
                const SizedBox(width: 8),
                _buildFilterChip('pending', l.t('pending'), l),
                const SizedBox(width: 8),
                _buildFilterChip('failed', l.t('failed'), l),
                const SizedBox(width: 8),
                _buildFilterChip('refunded', l.t('refunded'), l),
              ],
            ),
          ),

          // Transaction list
          Expanded(
            child: transactions.isEmpty
                ? _buildEmptyState(l)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildTransactionCard(transactions[index], l),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, AppLocalizations l) {
    final isSelected = _selectedFilter == value;
    return SizedBox(
      height: 44,
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = value),
        selectedColor: HousepitalColors.orangeLight,
        checkmarkColor: HousepitalColors.orangeText,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isSelected ? HousepitalColors.orangeText : HousepitalColors.grey,
        ),
        side: BorderSide(
          color: isSelected ? HousepitalColors.orange : HousepitalColors.divider,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildTransactionCard(PaymentTransaction txn, AppLocalizations l) {
    return Semantics(
      label: '${txn.description}, ${DateHelper.formatCurrency(txn.amount)}, ${txn.status}, ${_methodLabel(txn.method)}, ${DateHelper.formatRelative(txn.createdAt)}',
      button: true,
      child: HousepitalCard(
        onTap: () => _showTransactionDetail(txn, l),
        child: Row(
          children: [
            // Method icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getMethodColor(txn.method).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getMethodIcon(txn.method),
                color: _getMethodColor(txn.method),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Description + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: HousepitalColors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateHelper.formatRelative(txn.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: HousepitalColors.greyLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount + status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateHelper.formatCurrency(txn.amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge(
                  text: txn.status.toUpperCase(),
                  color: _getStatusColor(txn.status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 64, color: HousepitalColors.greyLight),
          const SizedBox(height: 16),
          Text(
            l.t('no_transactions'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: HousepitalColors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.t('no_transactions_desc'),
            style: const TextStyle(
              fontSize: 13,
              color: HousepitalColors.greyLight,
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetail(PaymentTransaction txn, AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    _getMethodIcon(txn.method),
                    color: _getMethodColor(txn.method),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.t('transaction_details'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: HousepitalColors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildDetailRow(l.t('description'), txn.description),
              _buildDetailRow(
                  l.t('amount'), DateHelper.formatCurrency(txn.amount)),
              _buildDetailRow(l.t('method'), _methodLabel(txn.method)),
              _buildDetailRow(l.t('status'), txn.status.toUpperCase()),
              _buildDetailRow(
                  l.t('date'), DateHelper.formatDate(txn.createdAt)),
              if (txn.razorpayPaymentId != null)
                _buildDetailRow(l.t('razorpay_id'), txn.razorpayPaymentId!),
              if (txn.failureReason != null)
                _buildDetailRow(l.t('failure_reason'), txn.failureReason!),
              if (txn.refundId != null)
                _buildDetailRow(l.t('refund_id'), txn.refundId!),
              if (txn.refundAmount != null)
                _buildDetailRow(l.t('refund_amount'),
                    DateHelper.formatCurrency(txn.refundAmount!)),
              if (txn.receiptUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(l.t('opening_receipt'))),
                        );
                      },
                      icon: const Icon(Icons.receipt_outlined, size: 18),
                      label: Text(l.t('view_receipt')),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.t('close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: HousepitalColors.greyLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HousepitalColors.black,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'upi':
        return Icons.account_balance;
      case 'card':
        return Icons.credit_card;
      case 'netbanking':
        return Icons.language;
      case 'wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'upi':
        return HousepitalColors.info;
      case 'card':
        return HousepitalColors.orange;
      case 'netbanking':
        return HousepitalColors.success;
      case 'wallet':
        return const Color(0xFF9C27B0);
      default:
        return HousepitalColors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return HousepitalColors.success;
      case 'pending':
        return HousepitalColors.warning;
      case 'failed':
        return HousepitalColors.error;
      case 'refunded':
        return HousepitalColors.info;
      default:
        return HousepitalColors.greyLight;
    }
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Credit/Debit Card';
      case 'netbanking':
        return 'Net Banking';
      case 'wallet':
        return 'Wallet';
      default:
        return method;
    }
  }
}
