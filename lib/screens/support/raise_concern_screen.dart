import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../utils/app_localizations.dart';

class RaiseConcernScreen extends StatefulWidget {
  const RaiseConcernScreen({super.key});

  @override
  State<RaiseConcernScreen> createState() => _RaiseConcernScreenState();
}

class _RaiseConcernScreenState extends State<RaiseConcernScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _category;
  String _urgency = 'medium';
  String? _resolution;

  final List<Map<String, String>> _categories = [
    {'value': 'staff_behaviour', 'label': 'Staff behaviour / व्यवहार की समस्या'},
    {'value': 'staff_not_following', 'label': 'Staff not following routine / काम ठीक से नहीं हो रहा'},
    {'value': 'staff_absent', 'label': 'Staff absent / कर्मचारी नहीं आया'},
    {'value': 'need_replacement', 'label': 'Need replacement / बदलाव चाहिए'},
    {'value': 'medical_concern', 'label': 'Medical concern / मरीज़ की तबियत'},
    {'value': 'payment_issue', 'label': 'Payment or billing issue / भुगतान की समस्या'},
    {'value': 'service_quality', 'label': 'Service quality / सेवा की गुणवत्ता'},
    {'value': 'other', 'label': 'Other / कुछ और'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('raise_concern'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(labelText: l.t('concern_category')),
                items: _categories.map((c) => DropdownMenuItem(
                  value: c['value'],
                  child: Text(c['label']!, style: const TextStyle(fontSize: 14)),
                )).toList(),
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l.t('concern_description'),
                  hintText: 'Describe the issue in detail...',
                ),
                maxLines: 4,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please describe the issue'
                    : null,
              ),
              const SizedBox(height: 16),

              // Urgency
              Text(l.t('concern_urgency'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _urgencyChip('low', 'Low', HousepitalColors.info),
                  const SizedBox(width: 8),
                  _urgencyChip('medium', 'Medium', HousepitalColors.warning),
                  const SizedBox(width: 8),
                  _urgencyChip('high', 'High', HousepitalColors.orange),
                  const SizedBox(width: 8),
                  _urgencyChip('emergency', 'Emergency', HousepitalColors.error),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _resolution,
                decoration: InputDecoration(labelText: l.t('concern_resolution')),
                items: const [
                  DropdownMenuItem(value: 'counseling', child: Text('Counseling of staff')),
                  DropdownMenuItem(value: 'replacement', child: Text('Replacement')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _resolution = v),
              ),
              const SizedBox(height: 16),

              // Photo upload placeholder
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.camera_alt),
                label: const Text('Add Photo Evidence (optional)'),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _submitConcern(context, l);
                    }
                  },
                  child: Text(l.t('submit_concern')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _urgencyChip(String value, String label, Color color) {
    final isSelected = _urgency == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgency = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : HousepitalColors.greyLighter,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : HousepitalColors.greyLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitConcern(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: HousepitalColors.success, size: 48),
        title: Text(l.t('concern_submitted')),
        content: Text(_urgency == 'emergency'
            ? 'We will respond within 2 hours.'
            : _urgency == 'high'
                ? 'We will respond within 12 hours.'
                : 'We will respond within 24-72 hours.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
