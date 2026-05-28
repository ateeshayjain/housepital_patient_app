import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
// audit batch 4 (Agent I): centralized validators for name + age.
import '../../utils/validators.dart';

/// Add a new patient that the current user will care for as primary contact.
///
/// Mirrors the form patterns used in [PatientProfileScreen] for visual
/// consistency — name + age/gender row, relationship dropdown, condition chips,
/// city dropdown of NCR cities.
class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _conditionController = TextEditingController();

  String _gender = 'male';
  String _relationship = 'Parent';
  String _city = 'Delhi';

  final List<String> _conditions = [];
  bool _isSaving = false;

  static const _cities = [
    'Delhi',
    'Faridabad',
    'Gurgaon',
    'Noida',
    'Ghaziabad',
  ];

  static const _relationships = [
    'Parent',
    'Spouse',
    'Child',
    'Sibling',
    'Grandparent',
    'In-law',
    'Other',
  ];

  // Common condition suggestions to make chip-add fast.
  static const _commonConditions = [
    'Diabetes',
    'Hypertension',
    'Cardiac',
    'Stroke recovery',
    'Cancer',
    'Post-surgery',
    'Dementia',
    'Parkinson\'s',
    'COPD',
    'Kidney disease',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  void _addCondition([String? text]) {
    final value = (text ?? _conditionController.text).trim();
    if (value.isEmpty || _conditions.contains(value)) return;
    setState(() {
      _conditions.add(value);
      _conditionController.clear();
    });
  }

  void _removeCondition(String value) {
    setState(() => _conditions.remove(value));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final newPatient = Patient(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()),
      gender: _gender,
      conditions: List<String>.from(_conditions),
      city: _city,
      createdAt: DateTime.now(),
      // Stash relationship in requirement so it's preserved without changing
      // the Patient model schema; future iterations can add a dedicated field.
      requirement: 'Relationship: $_relationship',
    );

    await context.read<AppProvider>().addPatient(newPatient);

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Patient added. You're now their primary contact."),
        backgroundColor: HousepitalColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Patient'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _submit,
                  child: const Text('Save',
                      style: TextStyle(color: HousepitalColors.orange)),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          // audit batch 4 (Agent I): Apple framework P7 fix — onUserInteraction
          // surfaces validation as the user types/leaves a field rather than
          // only on submit.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Intro card
              Container(
                // audit batch 4 (Agent I): 14 → 16 per 8pt grid.
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HousepitalColors.orangeLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: HousepitalColors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "You'll be set as the primary contact for this patient — "
                        'able to book services, pay bills, and manage their care.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ==================== Basic Info ====================
              const Text('Basic Info',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Patient Name'),
                // audit batch 4 (Agent I): centralized name validator.
                validator: Validators.name,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                      // audit batch 4 (Agent I): centralized age validator
                      // (same messages as before — tests still pass).
                      validator: Validators.age,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _gender = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                decoration:
                    const InputDecoration(labelText: 'Relationship to you'),
                items: _relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _relationship = v);
                },
              ),

              // ==================== Location ====================
              const SizedBox(height: 24),
              const Text('Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _city,
                decoration: const InputDecoration(labelText: 'City'),
                items: _cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _city = v);
                },
              ),

              // ==================== Conditions ====================
              const SizedBox(height: 24),
              const Text('Conditions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                'Tap a suggestion or type your own',
                style: TextStyle(
                    fontSize: 12, color: HousepitalColors.greyLight),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _conditionController,
                      decoration: const InputDecoration(
                        labelText: 'Add condition',
                        hintText: 'e.g. Diabetes',
                      ),
                      onFieldSubmitted: (_) => _addCondition(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addCondition,
                    icon: const Icon(Icons.add_circle,
                        color: HousepitalColors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Selected conditions
              if (_conditions.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _conditions
                      .map((c) => Chip(
                            label: Text(c),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeCondition(c),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              // Suggestion chips (excluding already-added)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _commonConditions
                    .where((c) => !_conditions.contains(c))
                    .map((c) => ActionChip(
                          label: Text(c, style: const TextStyle(fontSize: 12)),
                          onPressed: () => _addCondition(c),
                          backgroundColor: HousepitalColors.greyLighter,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ))
                    .toList(),
              ),

              const SizedBox(height: 32),

              // Save button (mirrors the AppBar action — easier reach on small screens)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Patient'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HousepitalColors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
