import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _doctorNameController;
  late TextEditingController _doctorPhoneController;
  late TextEditingController _allergiesController;
  late TextEditingController _dietaryController;
  late TextEditingController _addressController;
  String _gender = 'male';
  String _mobility = 'ambulatory';
  String _city = 'Delhi NCR';

  // Emergency contacts
  late List<_EmergencyContactEntry> _emergencyContacts;

  // Medical conditions
  late List<String> _conditions;
  final TextEditingController _conditionController = TextEditingController();

  // Medications
  late List<_MedicationEntry> _medications;

  static const _cities = [
    'Delhi NCR',
    'Mumbai',
    'Bangalore',
    'Hyderabad',
    'Chennai',
    'Other',
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
    _gender = patient?.gender ?? 'male';
    _mobility = patient?.mobilityStatus ?? 'ambulatory';
    _city = patient?.city ?? 'Delhi NCR';
    if (!_cities.contains(_city)) _city = 'Other';

    // Initialize emergency contacts from patient data
    _emergencyContacts = (patient?.emergencyContacts ?? [])
        .map((ec) => _EmergencyContactEntry(
              nameController: TextEditingController(text: ec.name),
              phoneController: TextEditingController(text: ec.phone),
              relationController: TextEditingController(text: ec.relation ?? ''),
            ))
        .toList();

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

  void _addMedication() {
    setState(() {
      _medications.add(_MedicationEntry(
        nameController: TextEditingController(),
        dosageController: TextEditingController(),
        scheduleController: TextEditingController(),
      ));
    });
  }

  void _removeMedication(int index) {
    setState(() {
      _medications[index].dispose();
      _medications.removeAt(index);
    });
  }

  void _saveProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully'),
        backgroundColor: HousepitalColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('patient_profile')),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text(l.t('save'),
                style: const TextStyle(color: HousepitalColors.orange)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==================== Basic Info ====================
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Patient Name'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
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
              value: _mobility,
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
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _city,
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
            ),

            // ==================== Emergency Contacts ====================
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Emergency Contacts',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: ec.phoneController,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(labelText: 'Phone'),
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
                const Text('Current Medications',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
