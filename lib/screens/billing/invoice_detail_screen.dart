import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../models/models.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  // Mock invoice for development
  static Invoice get _mockInvoice => Invoice(
        id: 'inv1',
        invoiceNumber: 'INV-2026-001',
        patientId: 'p1',
        billingPeriodStart: DateTime(2026, 3, 1),
        billingPeriodEnd: DateTime(2026, 3, 31),
        lineItems: [
          InvoiceLineItem(
            description: 'Attendant — Day Shift (31 days)',
            amount: 1860000,
            gst: 334800,
            total: 2194800,
            type: 'attendant',
          ),
          InvoiceLineItem(
            description: 'Physiotherapy Session x4',
            amount: 200000,
            gst: 36000,
            total: 236000,
            type: 'service',
          ),
          InvoiceLineItem(
            description: 'ECG at Home',
            amount: 50000,
            gst: 9000,
            total: 59000,
            type: 'service',
          ),
          InvoiceLineItem(
            description: 'Medical Supplies',
            amount: 15000,
            gst: 2700,
            total: 17700,
            type: 'supplies',
          ),
        ],
        subtotal: 2125000,
        gstTotal: 382500,
        grandTotal: 2507500,
        dueDate: DateTime(2026, 4, 5),
        status: 'pending',
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final invoice = _mockInvoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('invoice_details')),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l.t('download_pdf'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.t('downloading_pdf'))),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: l.t('share'),
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'Invoice ${invoice.invoiceNumber} — ${DateHelper.formatCurrency(invoice.grandTotal)}',
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Invoice header
            _buildHeader(context, invoice, l),
            const SizedBox(height: 20),

            // Line items
            SectionHeader(title: l.t('line_items')),
            const SizedBox(height: 8),
            ...invoice.lineItems
                .map((item) => _buildLineItem(context, item))
                ,
            const SizedBox(height: 16),

            // Totals
            const Divider(),
            const SizedBox(height: 8),
            _buildTotalRow(context, l.t('subtotal'), invoice.subtotal),
            const SizedBox(height: 6),
            _buildTotalRow(context, l.t('gst'), invoice.gstTotal),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildTotalRow(
              context,
              l.t('grand_total'),
              invoice.grandTotal,
              isBold: true,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: invoice.status != 'paid'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/payment',
                      arguments: {
                        'amount': invoice.grandTotal,
                        'description':
                            '${invoice.invoiceNumber} — ${DateHelper.formatDateShort(invoice.billingPeriodStart)} to ${DateHelper.formatDateShort(invoice.billingPeriodEnd)}',
                        'invoiceId': invoice.id,
                      },
                    );
                  },
                  child: Text(
                    '${l.t('pay_now')} ${DateHelper.formatCurrency(invoice.grandTotal)}',
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context, Invoice invoice, AppLocalizations l) {
    Color statusColor;
    switch (invoice.status) {
      case 'paid':
        statusColor = context.hc.success;
        break;
      case 'overdue':
        statusColor = context.hc.error;
        break;
      default:
        statusColor = context.hc.warning;
    }

    return HousepitalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  invoice.invoiceNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.hc.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                text: invoice.status.toUpperCase(),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 16, color: context.hc.greyLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${l.t('billing_period')}: ${DateHelper.formatDateShort(invoice.billingPeriodStart)} - ${DateHelper.formatDateShort(invoice.billingPeriodEnd)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.hc.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event,
                  size: 16, color: context.hc.greyLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${l.t('due_date')}: ${DateHelper.formatDate(invoice.dueDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.hc.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineItem(BuildContext context, InvoiceLineItem item) {
    IconData typeIcon;
    switch (item.type) {
      case 'attendant':
        typeIcon = Icons.person;
        break;
      case 'service':
        typeIcon = Icons.medical_services;
        break;
      case 'supplies':
        typeIcon = Icons.inventory_2;
        break;
      default:
        typeIcon = Icons.receipt;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HousepitalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIconTile(
                  icon: typeIcon,
                  color: HousepitalColors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.hc.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: _buildItemDetail(context,
                        'Amount', DateHelper.formatCurrency(item.amount))),
                Expanded(
                    child: _buildItemDetail(context,
                        'GST', DateHelper.formatCurrency(item.gst))),
                Expanded(
                  child: _buildItemDetail(
                    context,
                    'Total',
                    DateHelper.formatCurrency(item.total),
                    isBold: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetail(BuildContext context, String label, String value,
      {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: context.hc.greyLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: context.hc.black,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(BuildContext context, String label, int amount,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isBold ? 16 : 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color: isBold ? context.hc.black : context.hc.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateHelper.formatCurrency(amount),
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: context.hc.black,
            ),
          ),
        ],
      ),
    );
  }
}
