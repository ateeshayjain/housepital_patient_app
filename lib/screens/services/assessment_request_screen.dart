import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/daimaa_theme.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/orders_provider.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/document_attach_widgets.dart';

enum _ServiceType {
  nurse,
  caretaker,
  japa,
  nanny,
  physio,
  griefCounselling,
  psychiatry,
  generic,
}

class AssessmentRequestScreen extends StatefulWidget {
  final ServiceItem service;
  const AssessmentRequestScreen({super.key, required this.service});

  @override
  State<AssessmentRequestScreen> createState() =>
      _AssessmentRequestScreenState();
}

class _AssessmentRequestScreenState extends State<AssessmentRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  DateTime? _startDate;

  // --- Nurse / Caretaker fields ---
  String _condition = 'elderly_daily_care';
  String _mobility = 'ambulatory';
  String _shiftType = '24hr';
  String _staffGender = 'female';
  final Set<String> _careNeeds = {};

  // --- Japa fields ---
  String _babyAge = '';
  String _motherCondition = 'normal_delivery';
  String _feedingType = 'breastfeeding';
  final Set<String> _japaNeeds = {};

  // --- Nanny fields ---
  String _childAge = '';
  String _numberOfChildren = '1';
  String _careSchedule = 'daytime';
  final Set<String> _nannyActivities = {};

  // --- Physio fields ---
  String _physioConditionType = 'chronic_pain';
  String _affectedArea = 'back';
  String _issueDuration = '';
  String _currentMobilityLevel = 'moderate';
  String _preferredVisitTime = 'morning';

  // --- Grief Counselling fields ---
  String _lossType = 'recent_bereavement';
  String _sessionFormat = 'in_person';
  String _preferredTiming = 'morning';
  String _previousCounselling = 'no';

  // --- Psychiatry fields ---
  String _primaryConcern = 'anxiety';
  String _symptomDuration = '';
  String _currentlyOnMedication = 'no';
  String _psychiatrySessionFormat = 'in_person';

  // --- Prescription / Documents ---
  final List<String> _attachedFiles = [];
  bool _requestOnlineAssessment = false;

  late _ServiceType _serviceType;

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

  // Care needs categorised by required staff level
  static const _basicCareNeeds = [
    'Bathing',
    'Feeding',
    'Medication reminders',
    'Walking support',
    'Diaper changing',
    'Companionship',
  ];
  static const _advancedCareNeeds = [
    'Wound dressing',
    'Injection (IV/IM)',
    'Catheter care',
    'RT feeding',
    'Sugar & BP monitoring',
    'Oxygen support',
  ];
  static const _criticalCareNeeds = [
    'Tracheostomy care',
    'Ventilator management',
    'Suctioning',
    'Bed sore care',
    'Post-ICU monitoring',
    'Central line care',
  ];

  /// Returns 'basic', 'advanced', or 'critical' based on selected care needs.
  String get _recommendedNurseLevel {
    if (_careNeeds.any((n) => _criticalCareNeeds.contains(n))) {
      return 'critical';
    }
    if (_careNeeds.any((n) => _advancedCareNeeds.contains(n))) {
      return 'advanced';
    }
    return 'basic';
  }

  static const _nurseLevelLabels = {
    'basic': 'Basic Nurse',
    'advanced': 'Advanced Nurse',
    'critical': 'Critical Care Nurse',
  };

  static const _nurseLevelDescriptions = {
    'basic': 'Handles vitals monitoring, oral medication, feeding, hygiene & companionship.',
    'advanced': 'All basic duties + IV/IM injections, catheter care, RT feeding, wound dressing.',
    'critical': 'All advanced duties + tracheostomy, ventilator management, suctioning, post-ICU care.',
  };

  // What a lower-level nurse CANNOT do
  static const _cannotDoWarnings = {
    'basic': [
      'IV/IM injections',
      'Catheter care',
      'Wound dressing',
      'RT feeding',
      'Tracheostomy care',
      'Ventilator management',
    ],
    'advanced': [
      'Tracheostomy care',
      'Ventilator management',
      'Suctioning',
      'Central line care',
      'Post-ICU monitoring',
    ],
  };

  final List<String> _japaNeedOptions = [
    'Baby massage',
    'Cord care',
    'Cooking for mother',
    'Breastfeeding support',
    'Diaper changing',
    'Night-time baby care',
    'Bathing the baby',
    'House cleaning',
  ];

  final List<String> _nannyActivityOptions = [
    'Feeding',
    'Bathing',
    'School drop/pick',
    'Play activities',
    'Homework help',
    'Bedtime routine',
    'Meal preparation',
    'Outdoor activities',
  ];

  @override
  void initState() {
    super.initState();
    _serviceType = _resolveServiceType();
    _autoPopulateFromPatient();
  }

  bool get _isDaiMaa =>
      _serviceType == _ServiceType.japa ||
      _serviceType == _ServiceType.nanny;

  _ServiceType _resolveServiceType() {
    final id = widget.service.id;
    if (id.startsWith('mp-nurse-')) return _ServiceType.nurse;
    if (id.startsWith('mp-caretaker-')) return _ServiceType.caretaker;
    if (id.startsWith('mp-japa-')) return _ServiceType.japa;
    if (id.startsWith('mp-nanny-')) return _ServiceType.nanny;
    if (id.startsWith('mp-physio-')) return _ServiceType.physio;
    if (id.startsWith('con-grief')) return _ServiceType.griefCounselling;
    if (id.startsWith('con-psychiatrist')) return _ServiceType.psychiatry;
    return _ServiceType.generic;
  }

  void _autoPopulateFromPatient() {
    final patient =
        Provider.of<AppProvider>(context, listen: false).currentPatient;
    if (patient == null) return;

    // Auto-populate mobility for nurse/caretaker
    if (_serviceType == _ServiceType.nurse ||
        _serviceType == _ServiceType.caretaker ||
        _serviceType == _ServiceType.generic) {
      if (patient.mobilityStatus != null) {
        final validMobilities = [
          'ambulatory',
          'needs_support',
          'wheelchair',
          'bedridden',
        ];
        if (validMobilities.contains(patient.mobilityStatus)) {
          _mobility = patient.mobilityStatus!;
        }
      }

      // Auto-populate condition from patient's conditions list
      if (patient.conditions != null && patient.conditions!.isNotEmpty) {
        final patientConds =
            patient.conditions!.map((c) => c.toLowerCase()).toList();
        // Try to match patient conditions to our dropdown options
        for (final entry in _conditionLabels.entries) {
          final label = entry.value.toLowerCase();
          for (final pc in patientConds) {
            if (label.contains(pc) || pc.contains(label)) {
              _condition = entry.key;
              return;
            }
          }
        }
        // Check keyword matches
        for (final pc in patientConds) {
          if (pc.contains('surgery') || pc.contains('post-op')) {
            _condition = 'post_surgery_recovery';
            return;
          }
          if (pc.contains('dementia') || pc.contains('alzheimer')) {
            _condition = 'dementia_alzheimers';
            return;
          }
          if (pc.contains('paralysis') || pc.contains('stroke')) {
            _condition = 'paralysis_stroke';
            return;
          }
          if (pc.contains('elderly') || pc.contains('old age')) {
            _condition = 'elderly_daily_care';
            return;
          }
          if (pc.contains('chronic') || pc.contains('diabetes') ||
              pc.contains('hypertension')) {
            _condition = 'chronic_condition';
            return;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _getFormTitle() {
    switch (_serviceType) {
      case _ServiceType.japa:
        return 'Tell us about your newborn care needs';
      case _ServiceType.nanny:
        return 'Tell us about your childcare needs';
      case _ServiceType.physio:
        return 'Tell us about your physiotherapy needs';
      case _ServiceType.griefCounselling:
        return 'Help us understand your needs';
      case _ServiceType.psychiatry:
        return 'Help us understand your needs';
      default:
        return 'Tell us about your care needs';
    }
  }

  String _getFormSubtitle() {
    switch (_serviceType) {
      case _ServiceType.griefCounselling:
      case _ServiceType.psychiatry:
        return 'This helps us match you with the right specialist';
      default:
        return 'This helps us match the right professional';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    // Dai Maa surface adapts to the active theme (cream in light,
    // plum-tinted dark in dark). App bar stays plum in both modes so the
    // sub-brand still owns the top of the screen.
    return Scaffold(
      backgroundColor: _isDaiMaa ? daiMaaScaffold(context) : null,
      appBar: AppBar(
        title: Text(widget.service.name),
        backgroundColor: _isDaiMaa ? DaiMaaColors.plum : null,
        foregroundColor: _isDaiMaa ? Colors.white : null,
        iconTheme:
            _isDaiMaa ? const IconThemeData(color: Colors.white) : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isDaiMaa) ...[
                DaiMaaBrandHeader(
                  title: _serviceType == _ServiceType.japa
                      ? 'Japa Maid'
                      : 'Nanny',
                  subtitle: _serviceType == _ServiceType.japa
                      ? 'Mother & newborn care (0 – 7 months)'
                      : 'Childcare (7 months – 5 years)',
                ),
                const SizedBox(height: 20),
              ],
              Text(
                _getFormTitle(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  // daiMaaPrimaryText() returns plum in light, a lightened
                  // brand variant in dark to maintain AA contrast.
                  color: _isDaiMaa
                      ? daiMaaPrimaryText(context)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getFormSubtitle(),
                style: const TextStyle(
                    fontSize: 13, color: HousepitalColors.greyLight),
              ),
              const SizedBox(height: 20),

              // Contextual form fields
              ..._buildContextualForm(),

              const SizedBox(height: 16),

              // Notes (common to all)
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Any special requirements',
                  hintText: 'Tell us anything else...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Prescription & Documents section
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
                        Icon(Icons.attach_file_rounded,
                            size: 20, color: HousepitalColors.orange),
                        SizedBox(width: 8),
                        Text('Attach Documents',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload prescription, discharge summary, or medical reports',
                      style: TextStyle(
                          fontSize: 12,
                          color: HousepitalColors.greyLight),
                    ),
                    const SizedBox(height: 14),

                    // Attached files list
                    AttachedFilesList(
                      files: _attachedFiles,
                      onRemove: (i) => setState(
                          () => _attachedFiles.removeAt(i)),
                    ),

                    // Attach button
                    OutlinedButton.icon(
                      onPressed: () => showAttachOptionsSheet(
                        context,
                        title: 'Attach Document',
                        attachedFiles: _attachedFiles,
                        onFileAdded: (name) =>
                            setState(() => _attachedFiles.add(name)),
                      ),
                      icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 20),
                      label: Text(_attachedFiles.isEmpty
                          ? 'Attach Prescription / Report'
                          : 'Add Another'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HousepitalColors.orange,
                        side: const BorderSide(
                            color: HousepitalColors.orange),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Online assessment toggle
                    OnlineAssessmentToggle(
                      value: _requestOnlineAssessment,
                      onChanged: (v) => setState(
                          () => _requestOnlineAssessment = v),
                      subtitle:
                          'Get a video consultation instead of in-person visit',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: _isDaiMaa
                      ? ElevatedButton.styleFrom(
                          backgroundColor: DaiMaaColors.plum,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        )
                      : null,
                  onPressed: () => _submitRequest(context, l),
                  child: Text(l.t('submit')),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                _isDaiMaa
                    ? 'Our Dai Maa coordinator will call you within 2 hours at ${DaiMaaColors.phoneDisplay}.'
                    : 'Our care coordinator will call you within 2 hours to discuss details and pricing.',
                style: const TextStyle(
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

  List<Widget> _buildContextualForm() {
    switch (_serviceType) {
      case _ServiceType.nurse:
      case _ServiceType.caretaker:
      case _ServiceType.generic:
        return _buildNurseCaretakerForm();
      case _ServiceType.japa:
        return _buildJapaForm();
      case _ServiceType.nanny:
        return _buildNannyForm();
      case _ServiceType.physio:
        return _buildPhysioForm();
      case _ServiceType.griefCounselling:
        return _buildGriefCounsellingForm();
      case _ServiceType.psychiatry:
        return _buildPsychiatryForm();
    }
  }

  // ──────────────────────────────────────────────
  //  Section card wrapper
  // ──────────────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              Icon(icon, size: 20, color: HousepitalColors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: HousepitalColors.greyLight)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _careNeedChipGroup({
    required String groupLabel,
    required List<String> options,
    required Color badgeColor,
    required String levelTag,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(levelTag,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor)),
            ),
            const SizedBox(width: 8),
            Text(groupLabel,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HousepitalColors.greyLight)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((need) {
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
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  Nurse / Caretaker / Generic form
  // ──────────────────────────────────────────────
  List<Widget> _buildNurseCaretakerForm() {
    final recommended = _careNeeds.isNotEmpty ? _recommendedNurseLevel : null;
    final isNurse = _serviceType == _ServiceType.nurse;

    return [
      // ── Section 1: Patient Condition ──
      _sectionCard(
        icon: Icons.person_outline,
        title: 'Patient Condition',
        subtitle: 'Helps us understand the patient\'s current state',
        children: [
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
          const SizedBox(height: 14),
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
        ],
      ),

      // ── Section 2: Care Requirements ──
      _sectionCard(
        icon: Icons.checklist_rounded,
        title: 'What care does the patient need?',
        subtitle: isNurse
            ? 'Select all that apply — we\'ll recommend the right nurse level'
            : 'Select all that apply',
        children: [
          _careNeedChipGroup(
            groupLabel: 'Daily care',
            options: _basicCareNeeds,
            badgeColor: HousepitalColors.success,
            levelTag: 'BASIC',
          ),
          const SizedBox(height: 14),
          _careNeedChipGroup(
            groupLabel: 'Clinical care',
            options: _advancedCareNeeds,
            badgeColor: HousepitalColors.warning,
            levelTag: 'ADVANCED',
          ),
          const SizedBox(height: 14),
          _careNeedChipGroup(
            groupLabel: 'Critical care',
            options: _criticalCareNeeds,
            badgeColor: HousepitalColors.error,
            levelTag: 'CRITICAL',
          ),
        ],
      ),

      // ── Recommendation card ──
      if (isNurse && recommended != null) ...[
        _buildNurseRecommendation(recommended),
        const SizedBox(height: 16),
      ],

      // ── Section 3: Schedule & Preference ──
      _sectionCard(
        icon: Icons.schedule,
        title: 'Schedule & Preference',
        children: [
          DropdownButtonFormField<String>(
            value: _shiftType,
            decoration:
                const InputDecoration(labelText: 'Shift Type'),
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
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _staffGender,
            decoration: const InputDecoration(
                labelText: 'Preferred Staff Gender'),
            items: const [
              DropdownMenuItem(
                  value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(
                  value: 'any', child: Text('No preference')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _staffGender = v);
            },
          ),
          const SizedBox(height: 14),
          _buildDatePicker('Preferred Start Date'),
        ],
      ),
    ];
  }

  Widget _buildNurseRecommendation(String recommended) {
    final label = _nurseLevelLabels[recommended]!;
    final desc = _nurseLevelDescriptions[recommended]!;
    final color = recommended == 'critical'
        ? HousepitalColors.error
        : recommended == 'advanced'
            ? HousepitalColors.warning
            : HousepitalColors.success;
    final bgColor = recommended == 'critical'
        ? HousepitalColors.errorLight
        : recommended == 'advanced'
            ? HousepitalColors.warningLight
            : HousepitalColors.successLight;

    // Check if the service they tapped is a lower level than recommended
    final serviceId = widget.service.id;
    String? tappedLevel;
    if (serviceId.contains('-basic-')) tappedLevel = 'basic';
    if (serviceId.contains('-adv-')) tappedLevel = 'advanced';
    if (serviceId.contains('-crit-')) tappedLevel = 'critical';

    final levels = ['basic', 'advanced', 'critical'];
    final tappedIdx = tappedLevel != null ? levels.indexOf(tappedLevel) : -1;
    final recIdx = levels.indexOf(recommended);
    final isUnderqualified = tappedIdx >= 0 && tappedIdx < recIdx;

    return Column(
      children: [
        // Recommendation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, size: 24, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$label Recommended',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color,
                        )),
                    const SizedBox(height: 4),
                    Text(desc,
                        style: TextStyle(fontSize: 13, color: color)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Warning if they picked a lower level
        if (isUnderqualified) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HousepitalColors.warningLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: HousepitalColors.warning.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: HousepitalColors.warning),
                    const SizedBox(width: 8),
                    Text('A ${_nurseLevelLabels[tappedLevel]} cannot do:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HousepitalColors.warning,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                ...(_cannotDoWarnings[tappedLevel] ?? [])
                    .where((item) {
                      // Only show warnings relevant to what they selected
                      return _careNeeds.any((need) =>
                          need.toLowerCase().contains(
                              item.toLowerCase().split('/').first.trim()) ||
                          item.toLowerCase().contains(
                              need.toLowerCase().split(' ').first));
                    })
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.close,
                                  size: 14,
                                  color: HousepitalColors.error),
                              const SizedBox(width: 8),
                              Text(item,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: HousepitalColors.grey)),
                            ],
                          ),
                        )),
                const SizedBox(height: 6),
                Text(
                  'We recommend upgrading to $label for the care you need.',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: HousepitalColors.greyLight,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  Japa Maid form
  // ──────────────────────────────────────────────
  List<Widget> _buildJapaForm() {
    return [
      _sectionCard(
        icon: Icons.child_care,
        title: 'Baby & Mother Details',
        children: [
          TextFormField(
            initialValue: _babyAge,
            decoration: const InputDecoration(
              labelText: 'Baby\'s Age (in months)',
              hintText: 'e.g. 2',
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => _babyAge = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Please enter baby\'s age' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _motherCondition,
            decoration:
                const InputDecoration(labelText: 'Mother\'s Condition'),
            items: const [
              DropdownMenuItem(
                  value: 'normal_delivery', child: Text('Normal delivery')),
              DropdownMenuItem(
                  value: 'c_section', child: Text('Post C-section')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _motherCondition = v);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _feedingType,
            decoration: const InputDecoration(labelText: 'Feeding Type'),
            items: const [
              DropdownMenuItem(
                  value: 'breastfeeding', child: Text('Breastfeeding')),
              DropdownMenuItem(value: 'formula', child: Text('Formula')),
              DropdownMenuItem(value: 'both', child: Text('Both')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _feedingType = v);
            },
          ),
        ],
      ),
      _sectionCard(
        icon: Icons.checklist_rounded,
        title: 'What help do you need?',
        subtitle: 'Select all that apply',
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _japaNeedOptions.map((need) {
              final isSelected = _japaNeeds.contains(need);
              return FilterChip(
                label: Text(need),
                selected: isSelected,
                selectedColor: HousepitalColors.orangeLight,
                checkmarkColor: HousepitalColors.orange,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _japaNeeds.add(need);
                    } else {
                      _japaNeeds.remove(need);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
      _sectionCard(
        icon: Icons.schedule,
        title: 'Schedule',
        children: [
          _buildDatePicker('Preferred Start Date'),
        ],
      ),
      const SizedBox(height: 16),

      // Staff gender
      DropdownButtonFormField<String>(
        value: _staffGender,
        decoration:
            const InputDecoration(labelText: 'Preferred Staff Gender'),
        items: const [
          DropdownMenuItem(value: 'female', child: Text('Female')),
          DropdownMenuItem(value: 'male', child: Text('Male')),
          DropdownMenuItem(value: 'any', child: Text('No preference')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _staffGender = v);
        },
      ),
    ];
  }

  // ──────────────────────────────────────────────
  //  Nanny form
  // ──────────────────────────────────────────────
  List<Widget> _buildNannyForm() {
    return [
      _sectionCard(
        icon: Icons.child_friendly,
        title: 'Child Details',
        children: [
          TextFormField(
            initialValue: _childAge,
            decoration: const InputDecoration(
              labelText: 'Child\'s Age',
              hintText: 'e.g. 3 years or 8 months',
            ),
            onChanged: (v) => _childAge = v,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Please enter child\'s age' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _numberOfChildren,
            decoration:
                const InputDecoration(labelText: 'Number of Children'),
            items: const [
              DropdownMenuItem(value: '1', child: Text('1')),
              DropdownMenuItem(value: '2', child: Text('2')),
              DropdownMenuItem(value: '3', child: Text('3')),
              DropdownMenuItem(value: '4+', child: Text('4 or more')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _numberOfChildren = v);
            },
          ),
        ],
      ),
      _sectionCard(
        icon: Icons.checklist_rounded,
        title: 'Activities Needed',
        subtitle: 'Select all that apply',
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _nannyActivityOptions.map((activity) {
              final isSelected = _nannyActivities.contains(activity);
              return FilterChip(
                label: Text(activity),
                selected: isSelected,
                selectedColor: HousepitalColors.orangeLight,
                checkmarkColor: HousepitalColors.orange,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _nannyActivities.add(activity);
                    } else {
                      _nannyActivities.remove(activity);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
      _sectionCard(
        icon: Icons.schedule,
        title: 'Schedule & Preference',
        children: [
          DropdownButtonFormField<String>(
            value: _careSchedule,
            decoration:
                const InputDecoration(labelText: 'Care Schedule'),
            items: const [
              DropdownMenuItem(
                  value: 'daytime', child: Text('Daytime')),
              DropdownMenuItem(
                  value: 'overnight', child: Text('Overnight')),
              DropdownMenuItem(
                  value: '24hr', child: Text('24 hours')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _careSchedule = v);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _staffGender,
            decoration: const InputDecoration(
                labelText: 'Preferred Staff Gender'),
            items: const [
              DropdownMenuItem(
                  value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(
                  value: 'any', child: Text('No preference')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _staffGender = v);
            },
          ),
          const SizedBox(height: 14),
          _buildDatePicker('Preferred Start Date'),
        ],
      ),
    ];
  }

  // ──────────────────────────────────────────────
  //  Physiotherapy form
  // ──────────────────────────────────────────────
  List<Widget> _buildPhysioForm() {
    return [
      _sectionCard(
        icon: Icons.accessibility_new,
        title: 'Condition Details',
        children: [
          DropdownButtonFormField<String>(
            value: _physioConditionType,
            decoration:
                const InputDecoration(labelText: 'Condition Type'),
            items: const [
              DropdownMenuItem(
                  value: 'post_surgery',
                  child: Text('Post-surgery rehab')),
              DropdownMenuItem(
                  value: 'chronic_pain', child: Text('Chronic pain')),
              DropdownMenuItem(
                  value: 'neuro_rehab',
                  child: Text('Neuro rehabilitation')),
              DropdownMenuItem(
                  value: 'sports_injury',
                  child: Text('Sports injury')),
              DropdownMenuItem(
                  value: 'other', child: Text('Other')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _physioConditionType = v);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _affectedArea,
            decoration:
                const InputDecoration(labelText: 'Affected Area'),
            items: const [
              DropdownMenuItem(value: 'knee', child: Text('Knee')),
              DropdownMenuItem(value: 'hip', child: Text('Hip')),
              DropdownMenuItem(
                  value: 'shoulder', child: Text('Shoulder')),
              DropdownMenuItem(value: 'back', child: Text('Back')),
              DropdownMenuItem(value: 'ankle', child: Text('Ankle')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _affectedArea = v);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: _issueDuration,
            decoration: const InputDecoration(
              labelText: 'Duration of Issue',
              hintText: 'e.g. 3 months, 1 year',
            ),
            onChanged: (v) => _issueDuration = v,
            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter the duration of your issue' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _currentMobilityLevel,
            decoration: const InputDecoration(
                labelText: 'Current Mobility Level'),
            items: const [
              DropdownMenuItem(
                  value: 'full', child: Text('Full mobility')),
              DropdownMenuItem(
                  value: 'moderate',
                  child: Text('Moderate - some difficulty')),
              DropdownMenuItem(
                  value: 'limited',
                  child: Text('Limited - needs assistance')),
              DropdownMenuItem(
                  value: 'minimal',
                  child: Text('Minimal - mostly immobile')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _currentMobilityLevel = v);
            },
          ),
        ],
      ),
      _sectionCard(
        icon: Icons.schedule,
        title: 'Schedule',
        children: [
          DropdownButtonFormField<String>(
            value: _preferredVisitTime,
            decoration: const InputDecoration(
                labelText: 'Preferred Visit Time'),
            items: const [
              DropdownMenuItem(
                  value: 'morning',
                  child: Text('Morning (8am - 12pm)')),
              DropdownMenuItem(
                  value: 'afternoon',
                  child: Text('Afternoon (12pm - 4pm)')),
              DropdownMenuItem(
                  value: 'evening',
                  child: Text('Evening (4pm - 8pm)')),
              DropdownMenuItem(
                  value: 'any', child: Text('No preference')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _preferredVisitTime = v);
            },
          ),
        ],
      ),
    ];
  }

  // ──────────────────────────────────────────────
  //  Grief Counselling form
  // ──────────────────────────────────────────────
  List<Widget> _buildGriefCounsellingForm() {
    return [
      _sectionCard(
        icon: Icons.favorite_border,
        title: 'About Your Situation',
        children: [
          DropdownButtonFormField<String>(
            value: _lossType,
            decoration:
                const InputDecoration(labelText: 'Type of Loss'),
            items: const [
              DropdownMenuItem(
                  value: 'recent_bereavement',
                  child: Text('Recent bereavement')),
              DropdownMenuItem(
                  value: 'terminal_diagnosis',
                  child: Text('Terminal diagnosis')),
              DropdownMenuItem(
                  value: 'caregiver_burnout',
                  child: Text('Caregiver burnout')),
              DropdownMenuItem(
                  value: 'other', child: Text('Other')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _lossType = v);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _previousCounselling,
            decoration: const InputDecoration(
                labelText: 'Any Previous Counselling?'),
            items: const [
              DropdownMenuItem(value: 'yes', child: Text('Yes')),
              DropdownMenuItem(value: 'no', child: Text('No')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _previousCounselling = v);
            },
          ),
        ],
      ),
      _sectionCard(
        icon: Icons.schedule,
        title: 'Session Preference',
        children: [
          DropdownButtonFormField<String>(
            value: _sessionFormat,
            decoration: const InputDecoration(
                labelText: 'Preferred Session Format'),
            items: const [
              DropdownMenuItem(
                  value: 'in_person', child: Text('In-person')),
              DropdownMenuItem(
                  value: 'video', child: Text('Video call')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _sessionFormat = v);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _preferredTiming,
            decoration: const InputDecoration(
                labelText: 'Preferred Timing'),
            items: const [
              DropdownMenuItem(
                  value: 'morning',
                  child: Text('Morning (8am - 12pm)')),
              DropdownMenuItem(
                  value: 'afternoon',
                  child: Text('Afternoon (12pm - 4pm)')),
              DropdownMenuItem(
                  value: 'evening',
                  child: Text('Evening (4pm - 8pm)')),
              DropdownMenuItem(
                  value: 'any', child: Text('No preference')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _preferredTiming = v);
            },
          ),
        ],
      ),
    ];
  }

  // ──────────────────────────────────────────────
  //  Psychiatry form
  // ──────────────────────────────────────────────
  List<Widget> _buildPsychiatryForm() {
    return [
      _sectionCard(
        icon: Icons.psychology,
        title: 'About Your Concern',
        children: [
          DropdownButtonFormField<String>(
            value: _primaryConcern,
            decoration:
                const InputDecoration(labelText: 'Primary Concern'),
            items: const [
              DropdownMenuItem(
                  value: 'anxiety', child: Text('Anxiety')),
              DropdownMenuItem(
                  value: 'depression', child: Text('Depression')),
              DropdownMenuItem(
                  value: 'sleep', child: Text('Sleep issues')),
              DropdownMenuItem(
                  value: 'medication_review',
                  child: Text('Medication review')),
              DropdownMenuItem(
                  value: 'other', child: Text('Other')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _primaryConcern = v);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: _symptomDuration,
            decoration: const InputDecoration(
              labelText: 'Duration of Symptoms',
              hintText: 'e.g. 2 weeks, 6 months',
            ),
            onChanged: (v) => _symptomDuration = v,
            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter the duration of your symptoms' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _currentlyOnMedication,
            decoration: const InputDecoration(
                labelText: 'Currently on Medication?'),
            items: const [
              DropdownMenuItem(value: 'yes', child: Text('Yes')),
              DropdownMenuItem(value: 'no', child: Text('No')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _currentlyOnMedication = v);
            },
          ),
        ],
      ),
      _sectionCard(
        icon: Icons.schedule,
        title: 'Session Preference',
        children: [
          DropdownButtonFormField<String>(
            value: _psychiatrySessionFormat,
            decoration: const InputDecoration(
                labelText: 'Preferred Session Format'),
            items: const [
              DropdownMenuItem(
                  value: 'in_person', child: Text('In-person')),
              DropdownMenuItem(
                  value: 'video', child: Text('Video call')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _psychiatrySessionFormat = v);
              }
            },
          ),
        ],
      ),
    ];
  }

  // ──────────────────────────────────────────────
  //  Shared widgets
  // ──────────────────────────────────────────────
  Widget _buildDatePicker(String label) {
    return GestureDetector(
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
        decoration: InputDecoration(labelText: label),
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
    );
  }

  void _submitRequest(BuildContext context, AppLocalizations l) {
    if (!_formKey.currentState!.validate()) return;

    // Validate start date
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a preferred start date'),
          backgroundColor: HousepitalColors.error,
        ),
      );
      return;
    }
    if (_startDate!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start date must be in the future'),
          backgroundColor: HousepitalColors.error,
        ),
      );
      return;
    }

    // Save assessment to OrdersProvider
    context.read<OrdersProvider>().addAssessment(
          serviceId: widget.service.id,
          serviceName: widget.service.name,
          formData: {
            'serviceType': _serviceType.name,
            'startDate': _startDate?.toIso8601String(),
            'notes': _notesController.text,
          },
        );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle,
          // Use the dark-adaptive Dai Maa accent so the icon stays visible
          // on dark dialog surfaces.
          color: _isDaiMaa
              ? daiMaaAccent(context)
              : HousepitalColors.success,
          size: 48,
        ),
        title: Text(l.t('concern_submitted')),
        content: Text(
          _isDaiMaa
              ? 'Your request has been received. Our Dai Maa coordinator will call you within 2 hours at ${DaiMaaColors.phoneDisplay}.'
              : 'Your request has been received. Our care coordinator will call you within 2 hours to discuss details and pricing.',
        ),
        actions: [
          ElevatedButton(
            style: _isDaiMaa
                ? ElevatedButton.styleFrom(
                    backgroundColor: DaiMaaColors.plum,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pushReplacementNamed(
                context,
                '/booking-history',
                arguments: 1, // Assessment Requests tab
              );
            },
            child: const Text('Track in My Orders'),
          ),
        ],
      ),
    );
  }
}
