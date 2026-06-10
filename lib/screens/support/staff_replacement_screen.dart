import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/glass.dart';

class StaffReplacementScreen extends StatefulWidget {
  final String deploymentId;
  final String staffName;
  final String staffRole;
  final String? staffPhoto;
  final DateTime? assignedSince;

  const StaffReplacementScreen({
    super.key,
    required this.deploymentId,
    required this.staffName,
    required this.staffRole,
    this.staffPhoto,
    this.assignedSince,
  });

  @override
  State<StaffReplacementScreen> createState() => _StaffReplacementScreenState();
}

class _StaffReplacementScreenState extends State<StaffReplacementScreen> {
  String? _reason;
  String _preferredGender = 'No preference';
  final _additionalController = TextEditingController();
  bool _isSubmitting = false;

  static const _reasons = [
    'Skill mismatch',
    'Behaviour',
    'Schedule conflict',
    'Personal preference',
    'Other',
  ];

  static const _genderOptions = ['Male', 'Female', 'No preference'];

  @override
  void dispose() {
    _additionalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Request Replacement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current staff card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.hc.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.hc.divider),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: context.hc.orangeLight,
                    backgroundImage: widget.staffPhoto != null
                        ? NetworkImage(widget.staffPhoto!)
                        : null,
                    child: widget.staffPhoto == null
                        ? const Icon(Icons.person, size: 28, color: HousepitalColors.orange)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.staffName, style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600,
                        )),
                        const SizedBox(height: 4),
                        Text(
                          widget.staffRole.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 12, color: context.hc.greyLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.assignedSince != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Assigned since ${widget.assignedSince!.day}/${widget.assignedSince!.month}/${widget.assignedSince!.year}',
                            style: TextStyle(fontSize: 12, color: context.hc.greyLight),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Reason
            const Text('Reason for Replacement', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(
                hintText: 'Select reason',
              ),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _reason = v),
            ),
            const SizedBox(height: 20),

            // Gender preference
            const Text('Preferred Replacement Gender', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _genderOptions.map((g) {
                final isSelected = _preferredGender == g;
                return ChoiceChip(
                  label: Text(g),
                  selected: isSelected,
                  selectedColor: context.hc.orangeLight,
                  onSelected: (_) => setState(() => _preferredGender = g),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Additional requirements
            const Text('Additional Requirements', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 8),
            TextField(
              controller: _additionalController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Any specific requirements for the replacement...',
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _reason != null && !_isSubmitting ? _submitRequest : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HousepitalColors.orange,
                  foregroundColor: context.hc.white,
                  disabledBackgroundColor: context.hc.greyLighter,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Request Replacement',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);
    try {
      await ApiService().requestReplacement(
        widget.deploymentId,
        _reason!,
        {
          'preferred_gender': _preferredGender.toLowerCase(),
          'additional_requirements': _additionalController.text,
        },
      );
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            icon: Icon(Icons.check_circle, size: 48, color: context.hc.success),
            title: const Text('Request Submitted'),
            content: const Text(
              'We\'ll assign a new professional within 24 hours. '
              'You\'ll receive a notification once the replacement is confirmed.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // dialog
                  Navigator.pop(context); // screen
                },
                style: ElevatedButton.styleFrom(backgroundColor: HousepitalColors.orange),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // audit F: don't leak raw exception text (could contain SQL stack
      // traces or internal error details). Log internally; show generic UI.
      debugPrint('StaffReplacement submit failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn\'t submit your request right now. Please try again or call our coordinator at +91-90502-00183.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
