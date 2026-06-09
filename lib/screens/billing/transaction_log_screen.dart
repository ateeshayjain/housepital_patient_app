import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/paginated_list.dart';

class TransactionLogScreen extends StatefulWidget {
  const TransactionLogScreen({super.key});

  @override
  State<TransactionLogScreen> createState() => _TransactionLogScreenState();
}

class _TransactionLogScreenState extends State<TransactionLogScreen> {
  String _selectedFilter = 'all';
  Key _listKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final patientId = context.read<AppProvider>().currentPatient?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l.t('transaction_history'))),
      body: Column(
        children: [
          // Filter chips
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

          // Paginated transaction list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PaginatedListView<PaymentTransaction>(
                key: _listKey,
                pageSize: 20,
                showEmptyOnError: true,
                fetchPage: (page, pageSize) =>
                    ApiService().getTransactionsPaginated(
                  patientId,
                  status: _selectedFilter == 'all' ? null : _selectedFilter,
                  page: page,
                  pageSize: pageSize,
                ),
                itemBuilder: (txn) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildTransactionCard(txn, l),
                ),
                emptyWidget: _buildEmptyState(l),
              ),
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
        onSelected: (_) {
          setState(() {
            _selectedFilter = value;
            _listKey = UniqueKey(); // force refresh
          });
        },
        selectedColor: context.hc.orangeLight,
        checkmarkColor: context.hc.orangeText,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isSelected ? context.hc.orangeText : context.hc.grey,
        ),
        side: BorderSide(
          color: isSelected ? HousepitalColors.orange : context.hc.divider,
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
            AppIconTile(
              icon: _getMethodIcon(txn.method),
              color: _getMethodColor(txn.method),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.hc.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateHelper.formatRelative(txn.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.hc.greyLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateHelper.formatCurrency(txn.amount),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.hc.black,
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
          Icon(Icons.receipt_long_outlined,
              size: 64, color: context.hc.greyLight),
          const SizedBox(height: 16),
          Text(
            l.t('no_transactions'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.hc.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.t('no_transactions_desc'),
            style: TextStyle(
              fontSize: 13,
              color: context.hc.greyLight,
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.hc.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow(l.t('description'), txn.description),
              _buildDetailRow(l.t('amount'), DateHelper.formatCurrency(txn.amount)),
              _buildDetailRow(l.t('method'), _methodLabel(txn.method)),
              _buildDetailRow(l.t('status'), txn.status.toUpperCase()),
              _buildDetailRow(l.t('date'), DateHelper.formatDate(txn.createdAt)),
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
                          SnackBar(content: Text(l.t('opening_receipt'))),
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
                height: 52,
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
            style: TextStyle(fontSize: 12, color: context.hc.greyLight),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.hc.black,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'upi': return Icons.account_balance;
      case 'card': return Icons.credit_card;
      case 'netbanking': return Icons.language;
      case 'wallet': return Icons.account_balance_wallet;
      default: return Icons.payment;
    }
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'upi': return context.hc.info;
      case 'card': return HousepitalColors.orange;
      case 'netbanking': return context.hc.success;
      case 'wallet': return const Color(0xFF9C27B0);
      default: return context.hc.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return context.hc.success;
      case 'pending': return context.hc.warning;
      case 'failed': return context.hc.error;
      case 'refunded': return context.hc.info;
      default: return context.hc.greyLight;
    }
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'upi': return 'UPI';
      case 'card': return 'Credit/Debit Card';
      case 'netbanking': return 'Net Banking';
      case 'wallet': return 'Wallet';
      default: return method;
    }
  }
}
