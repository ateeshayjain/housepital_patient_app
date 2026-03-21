import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../utils/app_localizations.dart';

class AssessmentRequestScreen extends StatefulWidget {
  final ServiceItem service;
  const AssessmentRequestScreen({super.key, required this.service});

  @override
  State<AssessmentRequestScreen> createState() =>
      _AssessmentRequestScreenState();
}

class _AssessmentRequestScreenState extends State<AssessmentRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String _condition = 'elderly_daily_care';
  String _mobility = 'ambulatory';
  String _shiftType = '24hr';
  String _staffGender = 'female';
  final _notesController = TextEditingController();
  DateTime? _startDate;
  final Set<String> _careNeeds = {};

  final List<String> _conditions = [
    'post_surgery_recovery',
    'elderly_daily_care',
    'chronic_condition',
    'dementia_alzheimers',
    'paralysis_stroke',
    'other',
  ];

  final Map<String, String> _conditionLabels = {
    'post_surgery_recovery': 'Post-surgery recovery',
    'elderly_daily_care': 'Elderly daily care',
    'chronic_condition': 'Chronic condition management',
    'dementia_alzheimers': 'Dementia / Alzheimer\'s',
    'paralysis_stroke': 'Paralysis / Stroke',
    'other': 'Other',
  };

  final List<String> _careNeedOptions = [
    'Bathing',
    'Feeding',
    'Medication reminders',
    'Walking support',
    'Diaper changing',
    'Companionship',
    'Wound dressing',
    'Injection',
    'Catheter care',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.service.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about your care needs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'This helps us match the right professional',
                style: TextStyle(fontSize: 13, color: HousepitalColors.greyLight),
              ),
              const SizedBox(height: 20),

              // Primary condition
              DropdownButtonFormField<String>(
                value: _condition,
                decoration:
                    const InputDecoration(labelText: 'Primary Condition'),
                items: _conditions.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(_conditionLabels[c] ?? c),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _condition = v);
                },
              ),
              const SizedBox(height: 16),

              // Mobility
              DropdownButtonFormField<String>(
                value: _mobility,
                decoration:
                    const InputDecoration(labelText: 'Mobility Status'),
                items: const [
                  DropdownMenuItem(
                      value: 'ambulatory', child: Text('Ambulatory')),
                  DropdownMenuItem(
                      value: 'needs_support', child: Text('Needs support')),
                  DropdownMenuItem(
                      value: 'wheelchair', child: Text('Wheelchair')),
                  DropdownMenuItem(
                      value: 'bedridden', child: Text('Bedridden')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _mobility = v);
                },
              ),
              const SizedBox(height: 16),

              // Care needs
              const Text('Care Needs (select all that apply)',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _careNeedOptions.map((need) {
                  final isSelected = _careNeeds.contains(need);
                  return FilterChip(
                    label: Text(need),
                    selected: isSelected,
                    selectedColor: HousepitalColors.orangeLight,
                    checkmarkColor: HousepitalColors.orange,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _careNeeds.add(need);
                        } else {
                          _careNeeds.remove(need);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Shift type
              DropdownButtonFormField<String>(
                value: _shiftType,
                decoration: const InputDecoration(labelText: 'Shift Type'),
                items: const [
                  DropdownMenuItem(
                      value: '12hr_day', child: Text('12hr Day')),
                  DropdownMenuItem(
                      value: '12hr_night', child: Text('12hr Night')),
                  DropdownMenuItem(value: '24hr', child: Text('24hr')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _shiftType = v);
                },
              ),
              const SizedBox(height: 16),

              // Staff gender
              DropdownButtonFormField<String>(
                value: _staffGender,
                decoration: const InputDecoration(
                    labelText: 'Preferred Staff Gender'),
                items: const [
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(
                      value: 'any', child: Text('No preference')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _staffGender = v);
                },
              ),
              const SizedBox(height: 16),

              // Start date
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 2)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (date != null) setState(() => _startDate = date);
                },
                child: InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Preferred Start Date'),
                  child: Text(
                    _startDate != null
                        ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                        : 'Select date',
                    style: TextStyle(
                      color: _startDate != null
                          ? HousepitalColors.black
                          : HousepitalColors.greyLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Any special requirements',
                  hintText: 'Tell us anything else...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _submitRequest(context, l),
                  child: Text(l.t('submit')),
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                'Our care coordinator will call you within 2 hours to discuss details and pricing.',
                style: TextStyle(
                  fontSize: 12,
                  color: HousepitalColors.greyLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitRequest(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle,
            color: HousepitalColors.success, size: 48),
        title: Text(l.t('concern_submitted')),
        content: const Text(
          'Your request has been received. Our care coordinator will call you within 2 hours to discuss details and pricing.',
        ),
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
