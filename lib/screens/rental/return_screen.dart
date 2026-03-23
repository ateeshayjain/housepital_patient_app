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
            const SizedBox(height: 24),

            // Return reason
            const Text('Reason for Return', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _returnReason,
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
            ...(_conditions.map((c) => RadioListTile<String>(
              value: c,
              groupValue: _condition,
              title: Text(c),
              activeColor: HousepitalColors.orange,
              onChanged: (v) => setState(() => _condition = v!),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ))),
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
                  backgroundColor: HousepitalColors.orange,
                  foregroundColor: HousepitalColors.white,
                  disabledBackgroundColor: HousepitalColors.greyLighter,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Return Scheduled'),
            content: Text(
              'Your return pickup is scheduled for ${_pickupDate!.day}/${_pickupDate!.month}/${_pickupDate!.year} (${ _timeSlot}). '
              'Our team will collect the equipment.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // dialog
                  Navigator.pop(context); // return screen
                },
                style: ElevatedButton.styleFrom(backgroundColor: HousepitalColors.orange),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule return: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
