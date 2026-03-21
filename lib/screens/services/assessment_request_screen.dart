import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(widget.service.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _getFormTitle(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
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
  //  Nurse / Caretaker / Generic form
  // ──────────────────────────────────────────────
  List<Widget> _buildNurseCaretakerForm() {
    return [
      // Primary condition
      DropdownButtonFormField<String>(
        value: _condition,
        decoration: const InputDecoration(labelText: 'Primary Condition'),
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
        decoration: const InputDecoration(labelText: 'Mobility Status'),
        items: const [
          DropdownMenuItem(value: 'ambulatory', child: Text('Ambulatory')),
          DropdownMenuItem(
              value: 'needs_support', child: Text('Needs support')),
          DropdownMenuItem(value: 'wheelchair', child: Text('Wheelchair')),
          DropdownMenuItem(value: 'bedridden', child: Text('Bedridden')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _mobility = v);
        },
      ),
      const SizedBox(height: 16),

      // Care needs
      const Text('Care Needs (select all that apply)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
          DropdownMenuItem(value: '12hr_day', child: Text('12hr Day')),
          DropdownMenuItem(value: '12hr_night', child: Text('12hr Night')),
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
      const SizedBox(height: 16),

      // Start date
      _buildDatePicker('Preferred Start Date'),
    ];
  }

  // ──────────────────────────────────────────────
  //  Japa Maid form
  // ──────────────────────────────────────────────
  List<Widget> _buildJapaForm() {
    return [
      // Baby's age
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
      const SizedBox(height: 16),

      // Mother's condition
      DropdownButtonFormField<String>(
        value: _motherCondition,
        decoration: const InputDecoration(labelText: 'Mother\'s Condition'),
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
      const SizedBox(height: 16),

      // Feeding type
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
      const SizedBox(height: 16),

      // Specific needs
      const Text('Specific Needs (select all that apply)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
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
      const SizedBox(height: 16),

      // Start date
      _buildDatePicker('Preferred Start Date'),
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
      // Child's age
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
      const SizedBox(height: 16),

      // Number of children
      DropdownButtonFormField<String>(
        value: _numberOfChildren,
        decoration: const InputDecoration(labelText: 'Number of Children'),
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
      const SizedBox(height: 16),

      // Care schedule
      DropdownButtonFormField<String>(
        value: _careSchedule,
        decoration: const InputDecoration(labelText: 'Care Schedule'),
        items: const [
          DropdownMenuItem(value: 'daytime', child: Text('Daytime')),
          DropdownMenuItem(value: 'overnight', child: Text('Overnight')),
          DropdownMenuItem(value: '24hr', child: Text('24 hours')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _careSchedule = v);
        },
      ),
      const SizedBox(height: 16),

      // Activities needed
      const Text('Activities Needed (select all that apply)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
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
      const SizedBox(height: 16),

      // Start date
      _buildDatePicker('Preferred Start Date'),
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
  //  Physiotherapy form
  // ──────────────────────────────────────────────
  List<Widget> _buildPhysioForm() {
    return [
      // Condition type
      DropdownButtonFormField<String>(
        value: _physioConditionType,
        decoration: const InputDecoration(labelText: 'Condition Type'),
        items: const [
          DropdownMenuItem(
              value: 'post_surgery', child: Text('Post-surgery rehab')),
          DropdownMenuItem(
              value: 'chronic_pain', child: Text('Chronic pain')),
          DropdownMenuItem(
              value: 'neuro_rehab', child: Text('Neuro rehabilitation')),
          DropdownMenuItem(
              value: 'sports_injury', child: Text('Sports injury')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _physioConditionType = v);
        },
      ),
      const SizedBox(height: 16),

      // Affected area
      DropdownButtonFormField<String>(
        value: _affectedArea,
        decoration: const InputDecoration(labelText: 'Affected Area'),
        items: const [
          DropdownMenuItem(value: 'knee', child: Text('Knee')),
          DropdownMenuItem(value: 'hip', child: Text('Hip')),
          DropdownMenuItem(value: 'shoulder', child: Text('Shoulder')),
          DropdownMenuItem(value: 'back', child: Text('Back')),
          DropdownMenuItem(value: 'ankle', child: Text('Ankle')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _affectedArea = v);
        },
      ),
      const SizedBox(height: 16),

      // Duration of issue
      TextFormField(
        initialValue: _issueDuration,
        decoration: const InputDecoration(
          labelText: 'Duration of Issue',
          hintText: 'e.g. 3 months, 1 year',
        ),
        onChanged: (v) => _issueDuration = v,
      ),
      const SizedBox(height: 16),

      // Current mobility level
      DropdownButtonFormField<String>(
        value: _currentMobilityLevel,
        decoration:
            const InputDecoration(labelText: 'Current Mobility Level'),
        items: const [
          DropdownMenuItem(value: 'full', child: Text('Full mobility')),
          DropdownMenuItem(
              value: 'moderate', child: Text('Moderate - some difficulty')),
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
      const SizedBox(height: 16),

      // Preferred visit time
      DropdownButtonFormField<String>(
        value: _preferredVisitTime,
        decoration:
            const InputDecoration(labelText: 'Preferred Visit Time'),
        items: const [
          DropdownMenuItem(
              value: 'morning', child: Text('Morning (8am - 12pm)')),
          DropdownMenuItem(
              value: 'afternoon', child: Text('Afternoon (12pm - 4pm)')),
          DropdownMenuItem(
              value: 'evening', child: Text('Evening (4pm - 8pm)')),
          DropdownMenuItem(value: 'any', child: Text('No preference')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _preferredVisitTime = v);
        },
      ),
    ];
  }

  // ──────────────────────────────────────────────
  //  Grief Counselling form
  // ──────────────────────────────────────────────
  List<Widget> _buildGriefCounsellingForm() {
    return [
      // Type of loss
      DropdownButtonFormField<String>(
        value: _lossType,
        decoration: const InputDecoration(labelText: 'Type of Loss'),
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
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _lossType = v);
        },
      ),
      const SizedBox(height: 16),

      // Preferred session format
      DropdownButtonFormField<String>(
        value: _sessionFormat,
        decoration:
            const InputDecoration(labelText: 'Preferred Session Format'),
        items: const [
          DropdownMenuItem(value: 'in_person', child: Text('In-person')),
          DropdownMenuItem(value: 'video', child: Text('Video call')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _sessionFormat = v);
        },
      ),
      const SizedBox(height: 16),

      // Preferred timing
      DropdownButtonFormField<String>(
        value: _preferredTiming,
        decoration:
            const InputDecoration(labelText: 'Preferred Timing'),
        items: const [
          DropdownMenuItem(
              value: 'morning', child: Text('Morning (8am - 12pm)')),
          DropdownMenuItem(
              value: 'afternoon', child: Text('Afternoon (12pm - 4pm)')),
          DropdownMenuItem(
              value: 'evening', child: Text('Evening (4pm - 8pm)')),
          DropdownMenuItem(value: 'any', child: Text('No preference')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _preferredTiming = v);
        },
      ),
      const SizedBox(height: 16),

      // Previous counselling
      DropdownButtonFormField<String>(
        value: _previousCounselling,
        decoration:
            const InputDecoration(labelText: 'Any Previous Counselling?'),
        items: const [
          DropdownMenuItem(value: 'yes', child: Text('Yes')),
          DropdownMenuItem(value: 'no', child: Text('No')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _previousCounselling = v);
        },
      ),
    ];
  }

  // ──────────────────────────────────────────────
  //  Psychiatry form
  // ──────────────────────────────────────────────
  List<Widget> _buildPsychiatryForm() {
    return [
      // Primary concern
      DropdownButtonFormField<String>(
        value: _primaryConcern,
        decoration: const InputDecoration(labelText: 'Primary Concern'),
        items: const [
          DropdownMenuItem(value: 'anxiety', child: Text('Anxiety')),
          DropdownMenuItem(value: 'depression', child: Text('Depression')),
          DropdownMenuItem(
              value: 'sleep', child: Text('Sleep issues')),
          DropdownMenuItem(
              value: 'medication_review',
              child: Text('Medication review')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _primaryConcern = v);
        },
      ),
      const SizedBox(height: 16),

      // Duration of symptoms
      TextFormField(
        initialValue: _symptomDuration,
        decoration: const InputDecoration(
          labelText: 'Duration of Symptoms',
          hintText: 'e.g. 2 weeks, 6 months',
        ),
        onChanged: (v) => _symptomDuration = v,
      ),
      const SizedBox(height: 16),

      // Currently on medication
      DropdownButtonFormField<String>(
        value: _currentlyOnMedication,
        decoration:
            const InputDecoration(labelText: 'Currently on Medication?'),
        items: const [
          DropdownMenuItem(value: 'yes', child: Text('Yes')),
          DropdownMenuItem(value: 'no', child: Text('No')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _currentlyOnMedication = v);
        },
      ),
      const SizedBox(height: 16),

      // Preferred session format
      DropdownButtonFormField<String>(
        value: _psychiatrySessionFormat,
        decoration:
            const InputDecoration(labelText: 'Preferred Session Format'),
        items: const [
          DropdownMenuItem(value: 'in_person', child: Text('In-person')),
          DropdownMenuItem(value: 'video', child: Text('Video call')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _psychiatrySessionFormat = v);
        },
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
