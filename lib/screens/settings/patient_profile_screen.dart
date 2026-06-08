import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/permissions.dart';
// audit batch 4 (Agent I): centralized validators for name/age/phone.
import '../../utils/validators.dart';
import '../../widgets/common_widgets.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _doctorNameController;
  late TextEditingController _doctorPhoneController;
  late TextEditingController _allergiesController;
  late TextEditingController _dietaryController;
  late TextEditingController _addressController;
  String _gender = 'male';
  String _mobility = 'ambulatory';
  String _city = 'Delhi';

  // Emergency contacts
  late List<_EmergencyContactEntry> _emergencyContacts;

  // Profile photo
  String? _profilePhotoPath;

  // Medical conditions
  late List<String> _conditions;
  final TextEditingController _conditionController = TextEditingController();

  // Medications
  late List<_MedicationEntry> _medications;

  static const _cities = [
    'Delhi',
    'Faridabad',
    'Gurgaon',
    'Noida',
    'Ghaziabad',
  ];

  @override
  void initState() {
    super.initState();
    final patient = context.read<AppProvider>().currentPatient;
    _nameController = TextEditingController(text: patient?.name ?? '');
    _ageController =
        TextEditingController(text: patient?.age?.toString() ?? '');
    _doctorNameController =
        TextEditingController(text: patient?.doctorName ?? '');
    _doctorPhoneController =
        TextEditingController(text: patient?.doctorPhone ?? '');
    _allergiesController =
        TextEditingController(text: patient?.allergies?.join(', ') ?? '');
    _dietaryController =
        TextEditingController(text: patient?.dietaryRestrictions ?? '');
    _addressController =
        TextEditingController(text: patient?.address ?? '');
    // Normalise to the lowercase keys the dropdown items use — the backend /
    // demo data may send 'Male' / 'Female', which would otherwise have no
    // matching DropdownMenuItem and trip DropdownButton's single-match assert.
    _gender = (patient?.gender ?? 'male').toLowerCase();
    if (!const {'male', 'female', 'other'}.contains(_gender)) _gender = 'male';
    _mobility = patient?.mobilityStatus ?? 'ambulatory';
    if (!const {'ambulatory', 'needs_support', 'wheelchair', 'bedridden'}
        .contains(_mobility)) {
      _mobility = 'ambulatory';
    }
    _city = patient?.city ?? 'Delhi';
    if (!_cities.contains(_city)) _city = 'Delhi';

    // Initialize emergency contacts from patient data
    _emergencyContacts = (patient?.emergencyContacts ?? [])
        .map((ec) => _EmergencyContactEntry(
              nameController: TextEditingController(text: ec.name),
              phoneController: TextEditingController(text: ec.phone),
              relationController: TextEditingController(text: ec.relation ?? ''),
            ))
        .toList();

    // Load profile photo
    _loadProfilePhoto();

    // Initialize conditions
    _conditions = List<String>.from(patient?.conditions ?? []);

    // Initialize medications
    _medications = (patient?.medications ?? [])
        .map((m) => _MedicationEntry(
              nameController: TextEditingController(text: m.name),
              dosageController: TextEditingController(text: m.dosage ?? ''),
              scheduleController: TextEditingController(text: m.schedule ?? ''),
            ))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _doctorNameController.dispose();
    _doctorPhoneController.dispose();
    _allergiesController.dispose();
    _dietaryController.dispose();
    _addressController.dispose();
    _conditionController.dispose();
    for (final ec in _emergencyContacts) {
      ec.dispose();
    }
    for (final m in _medications) {
      m.dispose();
    }
    super.dispose();
  }

  void _addEmergencyContact() {
    setState(() {
      _emergencyContacts.add(_EmergencyContactEntry(
        nameController: TextEditingController(),
        phoneController: TextEditingController(),
        relationController: TextEditingController(),
      ));
    });
  }

  void _removeEmergencyContact(int index) {
    setState(() {
      _emergencyContacts[index].dispose();
      _emergencyContacts.removeAt(index);
    });
  }

  void _addCondition() {
    final text = _conditionController.text.trim();
    if (text.isNotEmpty && !_conditions.contains(text)) {
      setState(() {
        _conditions.add(text);
        _conditionController.clear();
      });
    }
  }

  void _removeCondition(int index) {
    setState(() {
      _conditions.removeAt(index);
    });
  }

  Future<void> _loadProfilePhoto() async {
    final path = context.read<AppProvider>().profilePhotoPath;
    if (path != null && File(path).existsSync() && mounted) {
      setState(() => _profilePhotoPath = path);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Change Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: HousepitalColors.orange),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: HousepitalColors.orange),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
    if (image == null) return;

    if (!mounted) return;
    await context.read<AppProvider>().setProfilePhotoPath(image.path);
    if (mounted) {
      setState(() => _profilePhotoPath = image.path);
    }
  }

  void _addMedication() {
    setState(() {
      _medications.add(_MedicationEntry(
        nameController: TextEditingController(),
        dosageController: TextEditingController(),
        scheduleController: TextEditingController(),
      ));
    });
  }

  Future<void> _removeMedication(int index) async {
    final entry = _medications[index];
    final medName = entry.nameController.text.trim().isEmpty
        ? 'this medication'
        : '"${entry.nameController.text.trim()}"';
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Remove medication?',
      message: 'Remove $medName from the list?',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _medications[index].dispose();
      _medications.removeAt(index);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final patient = context.read<AppProvider>().currentPatient;
    if (patient == null) return;

    setState(() => _isSaving = true);

    final updates = <String, dynamic>{
      'name': _nameController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()),
      'gender': _gender,
      'mobility_status': _mobility,
      'address': _addressController.text.trim(),
      'city': _city,
      'doctor_name': _doctorNameController.text.trim(),
      'doctor_phone': _doctorPhoneController.text.trim(),
      'allergies': _allergiesController.text
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList(),
      'dietary_restrictions': _dietaryController.text.trim(),
      'conditions': _conditions,
      'emergency_contacts': _emergencyContacts
          .map((ec) => {
                'name': ec.nameController.text.trim(),
                'phone': ec.phoneController.text.trim(),
                'relation': ec.relationController.text.trim(),
              })
          .toList(),
      'medications': _medications
          .map((m) => {
                'name': m.nameController.text.trim(),
                'dosage': m.dosageController.text.trim(),
                'schedule': m.scheduleController.text.trim(),
              })
          .toList(),
    };

    try {
      await context.read<AppProvider>().apiService.updatePatient(patient.id, updates);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: HousepitalColors.success,
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${e.message}'),
          backgroundColor: HousepitalColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: HousepitalColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final role = context.watch<AppProvider>().currentUserRole;
    final canEdit = canUserPerform(role, UserAction.editPatient);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('patient_profile')),
        actions: [
          if (canEdit)
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
                    onPressed: _saveProfile,
                    child: Text(l.t('save'),
                        style: const TextStyle(color: HousepitalColors.orange)),
                  ),
        ],
      ),
      body: AbsorbPointer(
        // Lock all fields and inline buttons for view-only roles.
        absorbing: !canEdit,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            // audit batch 4 (Agent I): onUserInteraction so errors surface
            // inline as the user edits, matching the other patient forms.
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canEdit) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HousepitalColors.infoLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 18, color: HousepitalColors.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'View only — only the primary contact can edit this profile.',
                          style: TextStyle(
                              fontSize: 13, color: HousepitalColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            // ==================== Profile Photo ====================
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: GestureDetector(
                  onTap: _pickProfilePhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: HousepitalColors.orangeLight,
                        backgroundImage: _profilePhotoPath != null
                            ? FileImage(File(_profilePhotoPath!))
                            : null,
                        child: _profilePhotoPath == null
                            ? Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: HousepitalColors.orange,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: HousepitalColors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: HousepitalColors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: HousepitalColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ==================== Basic Info ====================
            TextFormField(
              controller: _nameController,
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
                    // — age is optional here, so required:false.
                    validator: (v) => Validators.age(v, required: false),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
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
              initialValue: _mobility,
              decoration: const InputDecoration(labelText: 'Mobility Status'),
              items: const [
                DropdownMenuItem(
                    value: 'ambulatory', child: Text('Ambulatory')),
                DropdownMenuItem(
                    value: 'needs_support', child: Text('Needs Support')),
                DropdownMenuItem(
                    value: 'wheelchair', child: Text('Wheelchair')),
                DropdownMenuItem(
                    value: 'bedridden', child: Text('Bedridden')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _mobility = v);
              },
            ),

            // ==================== Address ====================
            const SizedBox(height: 24),
            const Text('Address',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
              validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 16),
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

            // ==================== Doctor Details ====================
            const SizedBox(height: 24),
            const Text('Doctor Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _doctorNameController,
              decoration: const InputDecoration(labelText: 'Doctor Name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _doctorPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Doctor Phone'),
              // audit batch 4 (Agent I): optional phone — only validates
              // shape if user enters something. Catches typos like 8-digit
              // numbers / landline 0-prefix.
              validator: (v) => Validators.indianMobile(v, required: false),
            ),

            // ==================== Emergency Contacts ====================
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Emergency Contacts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: _addEmergencyContact,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: HousepitalColors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._emergencyContacts.asMap().entries.map((entry) {
              final index = entry.key;
              final ec = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HousepitalColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HousepitalColors.divider),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Contact ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: HousepitalColors.grey,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeEmergencyContact(index),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: HousepitalColors.error, size: 20),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: ec.nameController,
                        decoration:
                            const InputDecoration(labelText: 'Name'),
                        // audit batch 4 (Agent I): optional name shape check.
                        validator: (v) => Validators.name(v, required: false),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: ec.phoneController,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(labelText: 'Phone'),
                        // audit batch 4 (Agent I): optional emergency phone
                        // shape check — empty is allowed (rows may be
                        // half-filled by intent).
                        validator: (v) =>
                            Validators.indianMobile(v, required: false),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: ec.relationController,
                        decoration:
                            const InputDecoration(labelText: 'Relation'),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // ==================== Health Details ====================
            const SizedBox(height: 24),
            const Text('Health Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _allergiesController,
              decoration: const InputDecoration(
                labelText: 'Allergies',
                hintText: 'Comma separated',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dietaryController,
              decoration: const InputDecoration(
                labelText: 'Dietary Restrictions',
              ),
            ),

            // ==================== Medical Conditions ====================
            const SizedBox(height: 24),
            const Text('Medical Conditions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _conditionController,
                    decoration: const InputDecoration(
                      labelText: 'Add condition',
                      hintText: 'e.g. Diabetes, Hypertension',
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _conditions.asMap().entries.map((entry) {
                return Chip(
                  label: Text(entry.value),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeCondition(entry.key),
                );
              }).toList(),
            ),

            // ==================== Current Medications ====================
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Current Medications',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: _addMedication,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: HousepitalColors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._medications.asMap().entries.map((entry) {
              final index = entry.key;
              final med = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HousepitalColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HousepitalColors.divider),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Medication ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: HousepitalColors.grey,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeMedication(index),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: HousepitalColors.error, size: 20),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: med.nameController,
                        decoration: const InputDecoration(
                            labelText: 'Medication Name'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: med.dosageController,
                              decoration: const InputDecoration(
                                  labelText: 'Dosage',
                                  hintText: 'e.g. 500mg'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: med.scheduleController,
                              decoration: const InputDecoration(
                                  labelText: 'Schedule',
                                  hintText: 'e.g. Twice daily'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Bottom spacing for scroll comfort
            const SizedBox(height: 40),
          ],
        ),
        ),
        ),
      ),
    );
  }
}

class _EmergencyContactEntry {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController relationController;

  _EmergencyContactEntry({
    required this.nameController,
    required this.phoneController,
    required this.relationController,
  });

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    relationController.dispose();
  }
}

class _MedicationEntry {
  final TextEditingController nameController;
  final TextEditingController dosageController;
  final TextEditingController scheduleController;

  _MedicationEntry({
    required this.nameController,
    required this.dosageController,
    required this.scheduleController,
  });

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    scheduleController.dispose();
  }
}
