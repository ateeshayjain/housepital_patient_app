import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../utils/helpers.dart';

class ReturnScreen extends StatefulWidget {
  final String orderId;
  final String itemName;
  final DateTime rentalStartDate;
  final int monthlyRate;

  const ReturnScreen({
    super.key,
    required this.orderId,
    required this.itemName,
    required this.rentalStartDate,
    required this.monthlyRate,
  });

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  String? _returnReason;
  DateTime? _pickupDate;
  String _timeSlot = 'Morning';
  String _condition = 'Good';
  String? _photoPath;
  bool _isSubmitting = false;

  // audit M-10: assumed security deposit / damage cap for the estimate. Real
  // figures come from the rental contract — these are user-visible defaults
  // until the backend ships per-order values.
  static const int _securityDepositDefault = 2000;
  static const int _damageFeeMax = 1500;

  static const _reasons = [
    'No longer needed',
    'Upgrading',
    'Moving',
    'Equipment issue',
    'Other',
  ];

  static const _timeSlots = ['Morning', 'Afternoon', 'Evening'];
  static const _conditions = ['Good', 'Minor wear', 'Damaged'];

  List<DateTime> get _availableDates {
    final now = DateTime.now();
    return List.generate(5, (i) => now.add(Duration(days: i + 3)));
  }

  // audit M-10: pro-rata refund for the remaining days of the current month
  // + security deposit, minus the worst-case damage fee if condition is bad.
  // Kept local because the shared calculateRefund() in lib/utils/pricing.dart
  // takes (totalPaid, totalDays, consumedDays) and doesn't model security
  // deposits or condition-based damage — different problem shape.
  int _estimatedRefund() {
    final now = DateTime.now();
    final pickup = _pickupDate ?? now;
    // Days remaining in the pickup month (inclusive of pickup day onwards).
    final daysInMonth = DateUtils.getDaysInMonth(pickup.year, pickup.month);
    final remainingDays = (daysInMonth - pickup.day + 1).clamp(0, daysInMonth);
    final proRata =
        ((widget.monthlyRate / daysInMonth) * remainingDays).round();
    final damage = _condition == 'Damaged' ? _damageFeeMax : 0;
    final estimate = proRata + _securityDepositDefault - damage;
    return estimate < 0 ? 0 : estimate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Return Equipment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current rental info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HousepitalColors.infoLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.itemName, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: HousepitalColors.black,
                  )),
                  const SizedBox(height: 8),
                  Text(
                    'Rented since: ${widget.rentalStartDate.day}/${widget.rentalStartDate.month}/${widget.rentalStartDate.year}',
                    style: const TextStyle(fontSize: 13, color: HousepitalColors.grey),
                  ),
                  Text(
                    'Monthly rate: ${DateHelper.formatCurrency(widget.monthlyRate)}',
                    style: const TextStyle(fontSize: 13, color: HousepitalColors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // audit M-10: refund estimate so users know roughly what's coming
            // back before they confirm the return.
            _buildRefundEstimateCard(),
            const SizedBox(height: 24),

            // Return reason
            const Text('Reason for Return', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _returnReason,
              decoration: InputDecoration(
                hintText: 'Select reason',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _returnReason = v),
            ),
            const SizedBox(height: 20),

            // Pickup date
            const Text('Preferred Pickup Date', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availableDates.map((date) {
                final isSelected = _pickupDate == date;
                return ChoiceChip(
                  label: Text('${date.day}/${date.month}'),
                  selected: isSelected,
                  selectedColor: HousepitalColors.orangeLight,
                  onSelected: (_) => setState(() => _pickupDate = date),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Time slot
            const Text('Preferred Time Slot', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _timeSlots.map((slot) {
                final isSelected = _timeSlot == slot;
                return ChoiceChip(
                  label: Text(slot),
                  selected: isSelected,
                  selectedColor: HousepitalColors.orangeLight,
                  onSelected: (_) => setState(() => _timeSlot = slot),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Equipment condition
            const Text('Equipment Condition', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _condition,
              onChanged: (v) => setState(() => _condition = v!),
              child: Column(
                children: _conditions
                    .map((c) => RadioListTile<String>(
                          value: c,
                          title: Text(c),
                          activeColor: HousepitalColors.orange,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Photo upload (optional)
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: Icon(_photoPath != null ? Icons.check_circle : Icons.camera_alt_outlined, size: 18),
              label: Text(_photoPath != null ? 'Photo Added' : 'Add Photo of Equipment (Optional)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _photoPath != null ? HousepitalColors.success : HousepitalColors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submitReturn : null,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: HousepitalColors.greyLighter,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Schedule Return Pickup',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // audit M-10: visible estimate card. Damage caveat row only shows when the
  // user has flagged the equipment as damaged.
  Widget _buildRefundEstimateCard() {
    final estimate = _estimatedRefund();
    final showDamageCaveat = _condition == 'Damaged';

    return Container(
      width: double.infinity,
      // audit batch 4 (Agent L): Apple 8pt grid (P1) — snap 14 to 16.
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HousepitalColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HousepitalColors.success.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: HousepitalColors.success, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Refund estimate',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.success,
                ),
              ),
              const Spacer(),
              Text(
                DateHelper.formatCurrency(estimate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Pro-rata refund for remaining days + security deposit.',
            style: TextStyle(
              fontSize: 12,
              color: HousepitalColors.grey,
            ),
          ),
          if (showDamageCaveat) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: HousepitalColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: HousepitalColors.warning, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Damaged condition may reduce refund by up to ${DateHelper.formatCurrency(_damageFeeMax)} (assessed at pickup).',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HousepitalColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _canSubmit =>
      _returnReason != null && _pickupDate != null && !_isSubmitting;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      setState(() => _photoPath = image.path);
    }
  }

  Future<void> _submitReturn() async {
    setState(() => _isSubmitting = true);
    try {
      await ApiService().scheduleReturn(
        orderId: widget.orderId,
        reason: _returnReason!,
        pickupDate: _pickupDate!.toIso8601String().split('T').first,
        timeSlot: _timeSlot,
        condition: _condition,
        photoUrl: _photoPath,
      );
      if (mounted) {
        // audit M-10: surface the same estimate in the success dialog so the
        // user has a concrete number to expect on their billing screen.
        final estimate = _estimatedRefund();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Return Scheduled'),
            content: Text(
              'Your return pickup is scheduled for ${_pickupDate!.day}/${_pickupDate!.month}/${_pickupDate!.year} ($_timeSlot). '
              'Our team will collect the equipment.\n\n'
              'Estimated refund: ${DateHelper.formatCurrency(estimate)} within 5–7 business days. '
              "You'll see it on your billing screen.",
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // dialog
                  Navigator.pop(context); // return screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // audit F: don't leak raw exception text (could contain SQL stack
      // traces or internal error details). Log internally; show generic UI.
      debugPrint('ReturnScreen submit failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn\'t schedule your return right now. Please try again or call our coordinator.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
