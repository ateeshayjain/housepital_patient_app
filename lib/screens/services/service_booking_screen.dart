import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';

class ServiceBookingScreen extends StatefulWidget {
  final ServiceItem service;
  const ServiceBookingScreen({super.key, required this.service});

  @override
  State<ServiceBookingScreen> createState() => _ServiceBookingScreenState();
}

class _ServiceBookingScreenState extends State<ServiceBookingScreen> {
  DateTime? _selectedDate;
  String? _selectedSlot;
  final _promoController = TextEditingController();
  int _step = 0; // 0: detail, 1: slot, 2: review
  bool _autoRenew = true; // default ON for manpower services
  String _billingCycle = 'monthly'; // monthly, quarterly

  final List<String> _slots = ['Morning (9-12)', 'Afternoon (12-4)', 'Evening (4-7)'];
  final List<String> _slotValues = ['morning', 'afternoon', 'evening'];

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = widget.service;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step indicator
            Row(
              children: [
                _stepDot(0, 'Details'),
                _stepLine(),
                _stepDot(1, 'Select Slot'),
                _stepLine(),
                _stepDot(2, 'Review & Pay'),
              ],
            ),
            const SizedBox(height: 24),

            if (_step == 0) ..._buildDetailStep(s, l),
            if (_step == 1) ..._buildSlotStep(l),
            if (_step == 2) ..._buildReviewStep(s, l),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDetailStep(ServiceItem s, AppLocalizations l) {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HousepitalColors.orangeLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(s.description ?? '',
                style: const TextStyle(color: HousepitalColors.grey)),
            if (s.durationMinutes != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 16, color: HousepitalColors.greyLight),
                  const SizedBox(width: 4),
                  Text('${s.durationMinutes} minutes',
                      style: const TextStyle(
                          fontSize: 13, color: HousepitalColors.grey)),
                ],
              ),
            ],
            if (s.basePriceMin != null) ...[
              const SizedBox(height: 8),
              Text(
                '${DateHelper.formatCurrency(s.basePriceMin!)} - ${DateHelper.formatCurrency(s.basePriceMax ?? s.basePriceMin!)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
      if (s.preparationNotes != null) ...[
        const SizedBox(height: 16),
        const Text('What to Prepare',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HousepitalColors.black)),
        const SizedBox(height: 8),
        Text(s.preparationNotes!,
            style: const TextStyle(
                fontSize: 14, color: HousepitalColors.grey)),
      ],
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: () => setState(() => _step = 1),
          child: const Text('Select Slot'),
        ),
      ),
    ];
  }

  List<Widget> _buildSlotStep(AppLocalizations l) {
    final nextDays = List.generate(
        7, (i) => DateTime.now().add(Duration(days: i + 1)));

    return [
      const Text('Select Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: nextDays.map((date) {
          final isSelected = _selectedDate?.day == date.day;
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? HousepitalColors.orange
                    : HousepitalColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? HousepitalColors.orange
                      : HousepitalColors.divider,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    DateHelper.formatDateShort(date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : HousepitalColors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      const Text('Select Time Slot',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ...List.generate(_slots.length, (i) {
        final isSelected = _selectedSlot == _slotValues[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () =>
                setState(() => _selectedSlot = _slotValues[i]),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? HousepitalColors.orangeLight
                    : HousepitalColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? HousepitalColors.orange
                      : HousepitalColors.divider,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? HousepitalColors.orange
                        : HousepitalColors.greyLight,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _slots[i],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: HousepitalColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed:
              _selectedDate != null && _selectedSlot != null
                  ? () => setState(() => _step = 2)
                  : null,
          child: const Text('Review & Pay'),
        ),
      ),
    ];
  }

  List<Widget> _buildReviewStep(ServiceItem s, AppLocalizations l) {
    final app = context.read<AppProvider>();
    final price = s.basePriceMin ?? 0;
    final gst = (price * 0.18).toInt();
    final total = price + gst;

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HousepitalColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HousepitalColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _infoRow('Patient', app.currentPatient?.name ?? ''),
            _infoRow('Date', _selectedDate != null
                ? DateHelper.formatDate(_selectedDate!)
                : ''),
            _infoRow('Slot', _selectedSlot ?? ''),
            _infoRow(
                'Address', app.currentPatient?.address ?? 'On file'),
            const Divider(height: 20),
            _infoRow('Service Fee', DateHelper.formatCurrency(price)),
            _infoRow('GST (18%)', DateHelper.formatCurrency(gst)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(DateHelper.formatCurrency(total),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: HousepitalColors.orange)),
              ],
            ),
          ],
        ),
      ),
      // Auto-renew section for manpower services
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HousepitalColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HousepitalColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.autorenew,
                    color: HousepitalColors.orange, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto-Renew Service',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text(
                          'Automatically renew and pay at end of each cycle',
                          style: TextStyle(
                              fontSize: 12,
                              color: HousepitalColors.greyLight)),
                    ],
                  ),
                ),
                Switch(
                  value: _autoRenew,
                  onChanged: (v) => setState(() => _autoRenew = v),
                  activeColor: HousepitalColors.orange,
                ),
              ],
            ),
            if (_autoRenew) ...[
              const SizedBox(height: 14),
              const Text('Billing Cycle',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _billingCycleChip('monthly', 'Monthly'),
                  const SizedBox(width: 10),
                  _billingCycleChip('quarterly', 'Quarterly (5% off)'),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _billingCycle == 'monthly'
                            ? 'Next payment will be auto-charged on ${DateHelper.formatDate(DateTime.now().add(const Duration(days: 30)))}'
                            : 'Next payment will be auto-charged on ${DateHelper.formatDate(DateTime.now().add(const Duration(days: 90)))}. You save 5% with quarterly billing.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can cancel auto-renewal anytime from Settings',
                style: TextStyle(
                    fontSize: 11, color: HousepitalColors.greyLight),
              ),
            ],
          ],
        ),
      ),

      const SizedBox(height: 16),
      TextField(
        controller: _promoController,
        decoration: InputDecoration(
          hintText: 'Promo code (optional)',
          suffixIcon: TextButton(
            onPressed: () {},
            child: const Text('Apply',
                style: TextStyle(color: HousepitalColors.orange)),
          ),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_autoRenew
                    ? 'Service booked with auto-renewal (${_billingCycle}). Payment will be processed.'
                    : 'Service booked. Payment will be processed.'),
                backgroundColor: HousepitalColors.success,
              ),
            );
          },
          child: Text(l.t('pay_now')),
        ),
      ),
    ];
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: HousepitalColors.greyLight)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, color: HousepitalColors.black)),
        ],
      ),
    );
  }

  Widget _billingCycleChip(String value, String label) {
    final isSelected = _billingCycle == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _billingCycle = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? HousepitalColors.orange
                : HousepitalColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? HousepitalColors.orange
                  : HousepitalColors.divider,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : HousepitalColors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _step >= step;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive
                  ? HousepitalColors.orange
                  : HousepitalColors.greyLighter,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${step + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : HousepitalColors.greyLight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: HousepitalColors.greyLight)),
        ],
      ),
    );
  }

  Widget _stepLine() {
    return Container(
      width: 24,
      height: 2,
      color: HousepitalColors.divider,
    );
  }
}
