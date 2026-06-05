import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/medication_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/medication_provider.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/common_widgets.dart';

class AddEditMedicationScreen extends StatefulWidget {
  final MedicationFull? medication; // null = add mode

  const AddEditMedicationScreen({super.key, this.medication});

  @override
  State<AddEditMedicationScreen> createState() =>
      _AddEditMedicationScreenState();
}

class _AddEditMedicationScreenState extends State<AddEditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _instructionsCtrl;
  late final TextEditingController _prescribedByCtrl;
  late final TextEditingController _stockCtrl;

  late String _form;
  late String _frequency;
  late String _stockUnit;
  late List<String> _timeSlots;
  late bool _remindersEnabled;

  bool get isEditing => widget.medication != null;

  static const _forms = ['tablet', 'injection', 'syrup', 'inhaler', 'drops'];
  static const _frequencies = [
    'once_daily',
    'twice_daily',
    'thrice_daily',
    'four_times_daily',
    'as_needed',
  ];
  static const _stockUnits = ['tablets', 'units', 'ml', 'puffs'];
  static const _defaultSlots = {
    'once_daily': ['08:00'],
    'twice_daily': ['08:00', '20:00'],
    'thrice_daily': ['08:00', '14:00', '21:00'],
    'four_times_daily': ['06:00', '12:00', '18:00', '22:00'],
    'as_needed': <String>[],
  };

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    _nameCtrl = TextEditingController(text: med?.name ?? '');
    _dosageCtrl = TextEditingController(text: med?.dosage ?? '');
    _instructionsCtrl = TextEditingController(text: med?.instructions ?? '');
    _prescribedByCtrl = TextEditingController(text: med?.prescribedBy ?? '');
    _stockCtrl = TextEditingController(
        text: med?.stockCount != null ? '${med!.stockCount}' : '');
    _form = med?.form ?? 'tablet';
    _frequency = med?.frequency ?? 'once_daily';
    _stockUnit = med?.stockUnit ?? 'tablets';
    _timeSlots =
        med?.timeSlots ?? List.from(_defaultSlots[_frequency] ?? ['08:00']);
    _remindersEnabled = med?.remindersEnabled ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _instructionsCtrl.dispose();
    _prescribedByCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final medProv = context.watch<MedicationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l.t('edit_medication') : l.t('add_medication')),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(medProv, l),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Medication Name'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dosageCtrl,
              decoration:
                  const InputDecoration(labelText: 'Dosage (e.g., 500mg)'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Dosage is required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _form,
              decoration: const InputDecoration(labelText: 'Form'),
              items: _forms
                  .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f[0].toUpperCase() + f.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _form = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: _frequencies
                  .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(MedicationFull(
                              id: '',
                              patientId: '',
                              name: '',
                              dosage: '',
                              frequency: f)
                          .frequencyLabel)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _frequency = v!;
                  _timeSlots = List.from(_defaultSlots[v] ?? ['08:00']);
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(
                  labelText: 'Instructions (e.g., After meals)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prescribedByCtrl,
              decoration: const InputDecoration(labelText: 'Prescribed by'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _stockCtrl,
                    decoration: const InputDecoration(labelText: 'Stock count'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        final n = int.tryParse(v);
                        if (n == null || n < 0) return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _stockUnit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: _stockUnits
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _stockUnit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Enable Reminders'),
              subtitle: const Text('Get notified when it\'s time to take this medication'),
              value: _remindersEnabled,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _remindersEnabled = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: medProv.isSaving ? null : () => _save(medProv),
              child: medProv.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(l.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(MedicationProvider medProv) async {
    if (!_formKey.currentState!.validate()) return;

    final patientId = context.read<AppProvider>().currentPatient?.id;
    if (patientId == null) return;

    final body = {
      'name': _nameCtrl.text.trim(),
      'dosage': _dosageCtrl.text.trim(),
      'form': _form,
      'frequency': _frequency,
      'time_slots': _timeSlots,
      'instructions': _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      'prescribed_by': _prescribedByCtrl.text.trim().isEmpty
          ? null
          : _prescribedByCtrl.text.trim(),
      'stock_count': _stockCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_stockCtrl.text.trim()),
      'stock_unit': _stockUnit,
      'reminders_enabled': _remindersEnabled,
    };

    bool success;
    if (isEditing) {
      success =
          await medProv.updateMedication(patientId, widget.medication!.id, body);
    } else {
      success = await medProv.addMedication(patientId, body);
    }

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  // audit M-13: migrated to shared confirmDestructiveAction helper. This is
  // the edit-screen delete path; PR #10 only wired the profile screen path.
  Future<void> _confirmDelete(
      MedicationProvider medProv, AppLocalizations l) async {
    final ok = await confirmDestructiveAction(
      context,
      title: l.t('delete'),
      message: l.t('confirm_delete_medication'),
      confirmLabel: l.t('delete'),
      cancelLabel: l.t('cancel'),
    );
    if (!ok || !mounted) return;
    final patientId = context.read<AppProvider>().currentPatient?.id;
    if (patientId != null) {
      await medProv.deleteMedication(patientId, widget.medication!.id);
    }
    if (!mounted) return;
    Navigator.pop(context, true); // pop screen
  }
}
