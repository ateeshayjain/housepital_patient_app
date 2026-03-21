import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/document_attach_widgets.dart';

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
  final _notesController = TextEditingController();
  int _step = 0; // 0: detail, 1: slot, 2: review
  bool _autoRenew = true; // default ON for manpower services
  String _billingCycle = 'monthly'; // monthly, quarterly
  bool _requestOnlineAssessment = false;
  final List<String> _attachedFiles = [];
  int _selectedAddressIndex = 0;

  // Mock saved addresses — in production, fetched from user profile
  static const List<Map<String, String>> _savedAddresses = [
    {
      'label': 'Home',
      'address': 'B-42, Sector 15, Noida, UP 201301',
      'icon': 'home',
    },
    {
      'label': 'Parent\'s Home',
      'address': '12/3 Lajpat Nagar II, New Delhi 110024',
      'icon': 'family',
    },
    {
      'label': 'Office',
      'address': '5th Floor, Tower B, Cyber City, Gurugram 122002',
      'icon': 'work',
    },
  ];

  final List<String> _slots = ['Morning (9-12)', 'Afternoon (12-4)', 'Evening (4-7)'];
  final List<String> _slotValues = ['morning', 'afternoon', 'evening'];

  bool get _showPrescriptionSection {
    final id = widget.service.id;
    return id.startsWith('con-') ||
        id.startsWith('visit-') ||
        id.startsWith('th-');
  }

  bool get _isVisitService => widget.service.id.startsWith('visit-');
  bool get _isDoctorVisit => widget.service.id == 'con-doctor';

  // Doctor visit concern & recommendation
  final _concernController = TextEditingController();
  String? _selectedConcernCategory;
  String? _recommendedDoctor; // 'gp' or 'icu'

  static const List<Map<String, String>> _concernCategories = [
    {'id': 'fever', 'label': 'Fever / Cold / Flu', 'type': 'gp'},
    {'id': 'bp_sugar', 'label': 'BP / Sugar / Thyroid check-up', 'type': 'gp'},
    {'id': 'stomach', 'label': 'Stomach / Digestion issues', 'type': 'gp'},
    {'id': 'skin', 'label': 'Skin / Allergy / Infection', 'type': 'gp'},
    {'id': 'pain', 'label': 'Body pain / Joint pain', 'type': 'gp'},
    {'id': 'elderly', 'label': 'Elderly general check-up', 'type': 'gp'},
    {'id': 'post_surgery', 'label': 'Post-surgery / Post-discharge follow-up', 'type': 'icu'},
    {'id': 'ventilator', 'label': 'Ventilator / Tracheostomy patient', 'type': 'icu'},
    {'id': 'icu_home', 'label': 'ICU-at-home patient review', 'type': 'icu'},
    {'id': 'critical', 'label': 'Critical care / Bed-ridden patient', 'type': 'icu'},
    {'id': 'medication', 'label': 'Medication review / Adjustment', 'type': 'gp'},
    {'id': 'other', 'label': 'Other', 'type': 'gp'},
  ];

  void _onConcernSelected(String categoryId) {
    final cat = _concernCategories.firstWhere((c) => c['id'] == categoryId);
    setState(() {
      _selectedConcernCategory = categoryId;
      _recommendedDoctor = cat['type'];
    });
  }

  @override
  void dispose() {
    _concernController.dispose();
    _promoController.dispose();
    _notesController.dispose();
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

  bool get _isDiagnosticService =>
      widget.service.category == 'diagnostics' ||
      widget.service.id.startsWith('dx-') ||
      widget.service.id.startsWith('lab-');

  List<String> _getVisitInclusions(String id) {
    if (id.startsWith('visit-iv-basic')) {
      return [
        'Trained nurse at your doorstep',
        'IV fluid / single medication push',
        'Up to 1 hour observation',
        'Vitals check (BP, SpO2, Pulse)',
        'Post-administration monitoring',
      ];
    } else if (id.startsWith('visit-iv-adv')) {
      return [
        'Experienced nurse for complex IV',
        'Multiple IV medications administration',
        'Up to 4 hours observation',
        'Continuous vitals monitoring',
        'Adverse reaction management',
      ];
    } else if (id.startsWith('visit-iv-crit')) {
      return [
        'ICU-trained nurse',
        'Prolonged infusion / blood products',
        'Up to 8 hours monitoring',
        'Continuous vitals & SpO2 tracking',
        'Emergency response readiness',
        'Detailed administration report',
      ];
    } else if (id == 'visit-im') {
      return [
        'Certified nurse for IM injection',
        'Proper site selection & preparation',
        'Post-injection observation (15 min)',
        'Allergy/reaction monitoring',
      ];
    } else if (id.startsWith('visit-dressing-basic')) {
      return [
        'Trained nurse for wound care',
        'Sterile dressing materials included',
        'Simple wound / surgical site care',
        'Wound assessment & documentation',
      ];
    } else if (id.startsWith('visit-dressing-adv')) {
      return [
        'Experienced wound care nurse',
        'Advanced sterile dressing materials',
        'Deep wound / drain site management',
        'Infection assessment',
        'Wound measurement & photo documentation',
      ];
    } else if (id.startsWith('visit-dressing-crit')) {
      return [
        'Specialist wound care nurse',
        'Surgical-grade dressing materials',
        'Bed sore / complex wound management',
        'Negative pressure wound therapy setup',
        'Detailed wound progression report',
      ];
    } else if (id == 'visit-catheter') {
      return [
        'Certified nurse for catheter change',
        'Sterile catheter kit included',
        'Post-procedure observation',
        'Infection risk assessment',
        'Care instructions provided',
      ];
    } else if (id == 'visit-rt-change') {
      return [
        'Trained nurse for Ryles tube change',
        'Sterile RT kit included',
        'Position verification',
        'Post-procedure feeding trial',
        'Care instructions provided',
      ];
    } else if (id == 'visit-tracheostomy') {
      return [
        'ICU-trained nurse',
        'Sterile tracheostomy kit included',
        'Stoma assessment & cleaning',
        'Post-change airway verification',
        'Emergency equipment on standby',
      ];
    }
    return [];
  }

  String? _getVisitPreparation(String id) {
    if (id.startsWith('visit-iv')) {
      return 'Keep the prescription ready. Ensure a comfortable seating/lying area near a power outlet. Inform if you have a known allergy to any medication.';
    } else if (id == 'visit-im') {
      return 'Keep the prescription and medication ready. Wear loose clothing for easy access to the injection site.';
    } else if (id.startsWith('visit-dressing')) {
      return 'Do not remove existing dressing before the nurse arrives. Keep the wound area dry. Have previous discharge/wound care instructions available.';
    } else if (id == 'visit-catheter') {
      return 'Empty the current catheter bag. Keep the area clean. Inform the nurse of any discomfort or signs of infection.';
    } else if (id == 'visit-rt-change') {
      return 'Do not feed through the tube for 2 hours before the visit. Keep the area around the nose/mouth clean.';
    } else if (id == 'visit-tracheostomy') {
      return 'Do not remove the existing tube. Keep suctioning equipment nearby. Ensure a calm, well-lit environment.';
    }
    return null;
  }

  List<String> _getDiagnosticInclusions(String id) {
    if (id == 'dx-ecg') {
      return [
        '12-lead ECG recording',
        'Trained technician at your doorstep',
        'Digital report within 2 hours',
        'Cardiologist interpretation included',
      ];
    } else if (id == 'dx-xray') {
      return [
        'Portable digital X-Ray machine',
        'Certified radiographer',
        'Digital report within 4 hours',
        'Radiologist interpretation included',
      ];
    } else if (id == 'dx-holter') {
      return [
        '24-hour Holter monitor device',
        'Technician for setup & removal (2 visits)',
        'Cardiologist-reviewed report in 48 hours',
        'Real-time arrhythmia detection',
      ];
    } else if (id.startsWith('lab-')) {
      return [
        'Certified phlebotomist visit',
        'Home sample collection',
        'Digital reports on app',
        'NABL-accredited lab processing',
      ];
    } else if (id.startsWith('dx-sample-')) {
      return [
        'Trained phlebotomist',
        'Home blood draw',
        'Proper sample handling & transport',
        'Results shared digitally',
      ];
    }
    return [];
  }

  String? _getDiagnosticPreparation(String id) {
    if (id.startsWith('lab-')) {
      return 'Fasting for 10-12 hours recommended for accurate results. Water is allowed.';
    } else if (id == 'dx-ecg') {
      return 'Wear loose, comfortable clothing. Avoid applying lotion on chest area.';
    } else if (id == 'dx-holter') {
      return 'Wear a button-down shirt. Device will be attached for 24 hours — avoid showers during monitoring.';
    } else if (id == 'dx-xray') {
      return 'Remove jewellery or metal objects near the area being X-rayed. Inform if pregnant.';
    }
    return null;
  }

  List<Widget> _buildDetailStep(ServiceItem s, AppLocalizations l) {
    final isDiag = _isDiagnosticService;

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

      // Doctor Visit: Concern selection & recommendation
      if (_isDoctorVisit) ...[
        const SizedBox(height: 20),
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
              const Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      size: 20, color: HousepitalColors.orange),
                  SizedBox(width: 8),
                  Text('What is your concern?',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the closest match — we\'ll recommend the right doctor',
                style: TextStyle(
                    fontSize: 12, color: HousepitalColors.greyLight),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _concernCategories.map((cat) {
                  final selected = _selectedConcernCategory == cat['id'];
                  return ChoiceChip(
                    label: Text(cat['label']!),
                    selected: selected,
                    onSelected: (_) => _onConcernSelected(cat['id']!),
                    selectedColor: HousepitalColors.orangeLight,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: selected
                          ? HousepitalColors.orange
                          : HousepitalColors.grey,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: selected
                            ? HousepitalColors.orange
                            : HousepitalColors.divider,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_selectedConcernCategory == 'other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _concernController,
                  decoration: const InputDecoration(
                    labelText: 'Describe your concern',
                    hintText: 'e.g. Breathing difficulty at night...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
        ),

        // Recommendation card
        if (_recommendedDoctor != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _recommendedDoctor == 'icu'
                  ? HousepitalColors.errorLight
                  : HousepitalColors.successLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _recommendedDoctor == 'icu'
                    ? HousepitalColors.error
                    : HousepitalColors.success,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _recommendedDoctor == 'icu'
                      ? Icons.local_hospital
                      : Icons.person,
                  size: 28,
                  color: _recommendedDoctor == 'icu'
                      ? HousepitalColors.error
                      : HousepitalColors.success,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recommendedDoctor == 'icu'
                            ? 'ICU Specialist Recommended'
                            : 'General Physician Recommended',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _recommendedDoctor == 'icu'
                              ? HousepitalColors.error
                              : HousepitalColors.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _recommendedDoctor == 'icu'
                            ? 'Based on your concern, an ICU specialist (₹5,000) is best suited for this visit.'
                            : 'A general physician (₹3,500) can handle this visit.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _recommendedDoctor == 'icu'
                              ? HousepitalColors.error
                              : HousepitalColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],

      // Diagnostic: What's Included
      if (isDiag && _getDiagnosticInclusions(s.id).isNotEmpty) ...[
        const SizedBox(height: 20),
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
              const Row(
                children: [
                  Icon(Icons.checklist_rounded,
                      size: 20, color: HousepitalColors.orange),
                  SizedBox(width: 8),
                  Text("What's Included",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              ..._getDiagnosticInclusions(s.id).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 18, color: HousepitalColors.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: HousepitalColors.black)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],

      // Diagnostic: Preparation Instructions
      if (isDiag && _getDiagnosticPreparation(s.id) != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  const Text('Preparation Instructions',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              Text(_getDiagnosticPreparation(s.id)!,
                  style: TextStyle(
                      fontSize: 14, color: Colors.amber.shade900)),
            ],
          ),
        ),
      ],

      // Diagnostic: How it Works
      if (isDiag) ...[
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
              const Row(
                children: [
                  Icon(Icons.route_rounded,
                      size: 20, color: HousepitalColors.orange),
                  SizedBox(width: 8),
                  Text('How it Works',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 14),
              _howItWorksStep(1, 'Book a convenient slot', Icons.calendar_today),
              _howItWorksDivider(),
              _howItWorksStep(2, 'Technician visits your home', Icons.home_outlined),
              _howItWorksDivider(),
              _howItWorksStep(3, 'Get digital reports on app', Icons.description_outlined),
            ],
          ),
        ),
      ],

      // Visit services: What's Included
      if (_isVisitService && _getVisitInclusions(s.id).isNotEmpty) ...[
        const SizedBox(height: 20),
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
              const Row(
                children: [
                  Icon(Icons.checklist_rounded,
                      size: 20, color: HousepitalColors.orange),
                  SizedBox(width: 8),
                  Text("What's Included",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              ..._getVisitInclusions(s.id).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 18, color: HousepitalColors.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: HousepitalColors.black)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],

      // Visit services: Preparation Instructions
      if (_isVisitService && _getVisitPreparation(s.id) != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  const Text('Before the Visit',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              Text(_getVisitPreparation(s.id)!,
                  style: TextStyle(
                      fontSize: 14, color: Colors.amber.shade900)),
            ],
          ),
        ),
      ],

      // Visit services: How it Works
      if (_isVisitService) ...[
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
              const Row(
                children: [
                  Icon(Icons.route_rounded,
                      size: 20, color: HousepitalColors.orange),
                  SizedBox(width: 8),
                  Text('How it Works',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 14),
              _howItWorksStep(1, 'Book a convenient slot', Icons.calendar_today),
              _howItWorksDivider(),
              _howItWorksStep(2, 'Nurse arrives with equipment', Icons.medical_services_outlined),
              _howItWorksDivider(),
              _howItWorksStep(3, 'Procedure & monitoring at home', Icons.monitor_heart_outlined),
              _howItWorksDivider(),
              _howItWorksStep(4, 'Report updated on app', Icons.description_outlined),
            ],
          ),
        ),
      ],

      // Non-diagnostic preparation notes (existing behavior)
      if (!isDiag && !_isVisitService && s.preparationNotes != null) ...[
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

      // Prescription / Notes / Online Assessment section
      if (_showPrescriptionSection) ...[
        const SizedBox(height: 20),
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
                  const Icon(Icons.attach_file_rounded,
                      size: 20, color: HousepitalColors.orange),
                  const SizedBox(width: 8),
                  Text(
                      _isVisitService
                          ? 'Reason & Prescription'
                          : 'Prescription & Notes',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _isVisitService
                    ? 'Tell us why you need this visit and attach the prescription'
                    : 'Attach prescription or add notes for the visiting professional',
                style: const TextStyle(
                    fontSize: 12, color: HousepitalColors.greyLight),
              ),
              const SizedBox(height: 14),

              // Notes / Reason field (shown first for visit services)
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: _isVisitService
                      ? 'Reason for Visit *'
                      : 'Notes for the professional',
                  hintText: _isVisitService
                      ? 'e.g. Doctor prescribed 3 days IV antibiotics for UTI...'
                      : 'e.g. Patient is on blood thinners, allergic to latex...',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 14),

              // Attached files
              AttachedFilesList(
                files: _attachedFiles,
                onRemove: (i) =>
                    setState(() => _attachedFiles.removeAt(i)),
              ),

              // Attach button
              OutlinedButton.icon(
                onPressed: () => showAttachOptionsSheet(
                  context,
                  title: 'Attach Prescription',
                  attachedFiles: _attachedFiles,
                  onFileAdded: (f) =>
                      setState(() => _attachedFiles.add(f)),
                ),
                icon: const Icon(Icons.add_photo_alternate_outlined,
                    size: 20),
                label: Text(_attachedFiles.isEmpty
                    ? 'Attach Prescription'
                    : 'Add Another'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HousepitalColors.orange,
                  side: const BorderSide(color: HousepitalColors.orange),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Request online assessment toggle
              OnlineAssessmentToggle(
                value: _requestOnlineAssessment,
                onChanged: (v) =>
                    setState(() => _requestOnlineAssessment = v),
              ),
            ],
          ),
        ),
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

  Widget _howItWorksStep(int number, String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: HousepitalColors.orangeLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HousepitalColors.orange,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 18, color: HousepitalColors.greyLight),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, color: HousepitalColors.black)),
        ),
      ],
    );
  }

  Widget _howItWorksDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: Container(
        width: 2,
        height: 20,
        color: HousepitalColors.divider,
      ),
    );
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
    final price = s.basePriceMin;
    final gst = price != null ? (price * 0.18).toInt() : null;
    final total = price != null ? price + gst! : null;

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
            if (_isDoctorVisit && _recommendedDoctor != null)
              _infoRow('Doctor Type', _recommendedDoctor == 'icu'
                  ? 'ICU Specialist'
                  : 'General Physician'),
            if (_isDoctorVisit && _selectedConcernCategory != null)
              _infoRow('Concern', _concernCategories
                  .firstWhere((c) => c['id'] == _selectedConcernCategory)['label']!),
            _infoRow('Date', _selectedDate != null
                ? DateHelper.formatDate(_selectedDate!)
                : ''),
            _infoRow('Slot', _selectedSlot ?? ''),
            if (_attachedFiles.isNotEmpty)
              _infoRow('Attachments', '${_attachedFiles.length} file(s)'),
            if (_notesController.text.isNotEmpty)
              _infoRow('Notes', 'Included'),
            if (_requestOnlineAssessment)
              _infoRow('Online Assessment', 'Requested'),
            if (price != null) ...[
              const Divider(height: 20),
              _infoRow('Service Fee', DateHelper.formatCurrency(price)),
              _infoRow('GST (18%)', DateHelper.formatCurrency(gst!)),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(DateHelper.formatCurrency(total!),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: HousepitalColors.orange)),
                ],
              ),
            ] else ...[
              const Divider(height: 20),
              const Text('Pricing will be confirmed after assessment',
                  style: TextStyle(
                      fontSize: 13,
                      color: HousepitalColors.greyLight,
                      fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
      // Service address selection
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
                const Icon(Icons.location_on_outlined,
                    size: 20, color: HousepitalColors.orange),
                const SizedBox(width: 8),
                const Text('Service Address',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Add new address coming soon')),
                    );
                  },
                  child: const Text('+ Add New',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._savedAddresses.asMap().entries.map((entry) {
              final i = entry.key;
              final addr = entry.value;
              final isSelected = _selectedAddressIndex == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedAddressIndex = i),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? HousepitalColors.orangeLight
                          : HousepitalColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? HousepitalColors.orange
                            : HousepitalColors.divider,
                        width: isSelected ? 1.5 : 1,
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
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          addr['icon'] == 'home'
                              ? Icons.home_outlined
                              : addr['icon'] == 'work'
                                  ? Icons.business_outlined
                                  : Icons.family_restroom_outlined,
                          size: 18,
                          color: HousepitalColors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(addr['label']!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(addr['address']!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color:
                                          HousepitalColors.greyLight)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
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
                  color: HousepitalColors.infoLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: HousepitalColors.info, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _billingCycle == 'monthly'
                            ? 'Next payment will be auto-charged on ${DateHelper.formatDate(DateTime.now().add(const Duration(days: 30)))}'
                            : 'Next payment will be auto-charged on ${DateHelper.formatDate(DateTime.now().add(const Duration(days: 90)))}. You save 5% with quarterly billing.',
                        style: TextStyle(
                            fontSize: 12, color: HousepitalColors.info),
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
