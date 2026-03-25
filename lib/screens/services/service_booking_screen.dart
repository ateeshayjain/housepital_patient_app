import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/document_attach_widgets.dart';
import '../checkout/address_selection_screen.dart';

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
  List<SavedAddress> _savedAddressObjects = [];
  bool _addressesLoaded = false;

  List<Map<String, String>> get _savedAddresses =>
      _savedAddressObjects.map((a) => a.toMapCompat()).toList();

  /// Each slot: { 'hour': 9, 'available': true }
  List<Map<String, dynamic>> _availableSlots = [];
  bool _slotsLoading = false;

  /// Lead time in hours — slots within this window from now are unavailable.
  static const int _leadTimeHours = 2;

  /// All possible 1-hour slot windows.
  static const List<int> _allSlotHours = [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19];

  /// Format a slot hour into a readable label.
  String _slotLabel(int hour) {
    final h = hour > 12 ? hour - 12 : hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final endHour = hour + 1 > 12 ? hour + 1 - 12 : hour + 1;
    final endAmPm = (hour + 1) >= 12 ? 'PM' : 'AM';
    return '$h:00 $amPm – $endHour:00 $endAmPm';
  }

  /// Check if a slot hour is within lead time.
  bool _isWithinLeadTime(DateTime date, int hour) {
    final slotStart = DateTime(date.year, date.month, date.day, hour);
    return slotStart.difference(DateTime.now()).inHours < _leadTimeHours;
  }

  /// Fetch slots from API; fall back to all-available on failure.
  Future<void> _fetchSlots(DateTime date) async {
    setState(() => _slotsLoading = true);
    try {
      final apiSlots = await ApiService().getAvailableSlots(
        widget.service.id,
        date,
      );
      if (!mounted) return;
      setState(() {
        _availableSlots = apiSlots;
        _slotsLoading = false;
        _selectedSlot = null;
      });
    } catch (_) {
      // Fallback: all slots available
      if (!mounted) return;
      setState(() {
        _availableSlots = _allSlotHours
            .map((h) => <String, dynamic>{'hour': h, 'available': true})
            .toList();
        _slotsLoading = false;
        _selectedSlot = null;
      });
    }
  }

  bool get _showPrescriptionSection {
    final id = widget.service.id;
    return id.startsWith('con-') ||
        id.startsWith('visit-') ||
        id.startsWith('th-');
  }

  bool get _isVisitService => widget.service.id.startsWith('visit-');
  bool get _isDoctorVisit => widget.service.id == 'con-doctor';
  bool get _isIvVisit => widget.service.id == 'visit-iv';
  bool get _isConsultationType => widget.service.id.startsWith('con-');

  /// Ongoing manpower: nurse (non-critical), caretaker, japa, nanny
  /// These need start date (48hr advance) + period (7/30 days)
  bool get _isOngoingManpower {
    final id = widget.service.id;
    return id.startsWith('mp-nurse-basic') ||
        id.startsWith('mp-nurse-adv') ||
        id.startsWith('mp-caretaker') ||
        id.startsWith('mp-japa') ||
        id.startsWith('mp-nanny');
  }

  /// Physio: pick a daytime slot + period (3/7/15/30 days)
  bool get _isPhysio => widget.service.id.startsWith('mp-physio');

  /// Whether this is any manpower service
  bool get _isManpower => widget.service.category == 'manpower';

  // Ongoing manpower state
  String _servicePeriod = '30'; // '7' or '30' days
  String _physioPeriod = '7'; // '3', '7', '15', '30' days
  static const _daytimeSlots = [9, 10, 11, 12, 13, 14, 15, 16, 17]; // 9AM-5PM only

  // Previous staff preference
  String? _preferredStaffId;
  String? _preferredStaffName;
  bool _requestSameStaff = false;

  // Autopay for recurring services
  bool _enableAutopay = false;

  // Doctor visit concern & recommendation
  final _concernController = TextEditingController();
  String? _selectedConcernCategory;
  String? _recommendedDoctor; // 'gp' or 'icu'

  // IV Visit state
  String? _selectedIvType;
  final _medicationController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _referringDoctorController = TextEditingController();
  String _ivAccess = 'fresh'; // 'fresh', 'picc', 'port'
  int _ivSessions = 1;

  // IV infusion types → nurse level mapping
  static const List<Map<String, String>> _ivInfusionTypes = [
    {'id': 'iv_push', 'label': 'Single IV Push', 'desc': 'Single medication push (~30 min)', 'level': 'basic', 'price': '900'},
    {'id': 'iv_drip_short', 'label': 'IV Drip — Short', 'desc': 'Hydration, antibiotics (1-2 hrs)', 'level': 'advanced', 'price': '1200'},
    {'id': 'iv_drip_extended', 'label': 'IV Drip — Extended', 'desc': 'Extended infusion (3-4 hrs)', 'level': 'advanced', 'price': '1200'},
    {'id': 'iv_multiple', 'label': 'Multiple IV Medications', 'desc': '2+ meds in one visit (2-4 hrs)', 'level': 'advanced', 'price': '1200'},
    {'id': 'iv_prolonged', 'label': 'Prolonged Infusion', 'desc': 'Iron, chemo supportive — up to 8 hrs', 'level': 'critical', 'price': '1500'},
    {'id': 'iv_central_line', 'label': 'Central Line / PICC Access', 'desc': 'Requires central line management', 'level': 'critical', 'price': '1500'},
  ];

  static const _nurseLevelLabel = {
    'basic': 'Basic Nurse',
    'advanced': 'Advanced Nurse',
    'critical': 'Critical Care Nurse',
  };

  static const _nurseLevelColor = {
    'basic': HousepitalColors.success,
    'advanced': HousepitalColors.warning,
    'critical': HousepitalColors.error,
  };

  String? get _ivNurseLevel {
    if (_selectedIvType == null) return null;
    return _ivInfusionTypes.firstWhere((t) => t['id'] == _selectedIvType)['level'];
  }

  int? get _ivPrice {
    if (_selectedIvType == null) return null;
    return int.parse(_ivInfusionTypes.firstWhere((t) => t['id'] == _selectedIvType)['price']!);
  }

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
  void initState() {
    super.initState();
    _loadAddresses();
    _loadSlotsForDate(DateTime.now());
  }

  Future<void> _loadSlotsForDate(DateTime date) async {
    await _fetchSlots(date);
  }

  Future<void> _loadAddresses() async {
    final addresses = await AddressHelper.loadAddresses();
    if (!mounted) return;
    setState(() {
      _savedAddressObjects = addresses;
      _addressesLoaded = true;
      // Select default address
      final defaultIndex = addresses.indexWhere((a) => a.isDefault);
      if (defaultIndex >= 0) _selectedAddressIndex = defaultIndex;
    });
  }

  @override
  void dispose() {
    _concernController.dispose();
    _promoController.dispose();
    _notesController.dispose();
    _medicationController.dispose();
    _allergiesController.dispose();
    _referringDoctorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = widget.service;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
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
                _stepDot(2, 'Review'),
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
    if (id == 'visit-iv') {
      // Dynamic inclusions based on selected IV type
      final level = _ivNurseLevel;
      if (level == 'critical') {
        return [
          'ICU-trained critical care nurse',
          'Prolonged infusion / central line management',
          'Up to 8 hours monitoring',
          'Continuous vitals & SpO2 tracking',
          'Emergency response readiness',
          'Detailed administration report',
        ];
      } else if (level == 'advanced') {
        return [
          'Experienced nurse for IV procedures',
          'IV drip / multiple medications',
          'Up to 4 hours observation',
          'Continuous vitals monitoring',
          'Adverse reaction management',
        ];
      }
      // basic or not yet selected
      return [
        'Trained nurse at your doorstep',
        'IV fluid / single medication push',
        'Up to 1 hour observation',
        'Vitals check (BP, SpO2, Pulse)',
        'Post-administration monitoring',
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
              // Hint text when no concern is selected yet
              if (_selectedConcernCategory == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Select your concern to continue',
                    style: TextStyle(
                      fontSize: 12,
                      color: HousepitalColors.greyLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
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
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please describe your concern' : null,
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

      // IV Visit: Infusion type selection & details
      if (_isIvVisit) ...[
        const SizedBox(height: 20),
        // Infusion type selector
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
                  Icon(Icons.vaccines, size: 20, color: HousepitalColors.orange),
                  SizedBox(width: 8),
                  Text('Type of IV Procedure',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the procedure — nurse level and pricing are assigned automatically',
                style: TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
              ),
              const SizedBox(height: 14),
              ..._ivInfusionTypes.map((type) {
                final selected = _selectedIvType == type['id'];
                final level = type['level']!;
                final levelColor = _nurseLevelColor[level]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedIvType = type['id']),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? HousepitalColors.orange : HousepitalColors.divider,
                          width: selected ? 2 : 1,
                        ),
                        color: selected ? HousepitalColors.orangeLight : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 20,
                            color: selected ? HousepitalColors.orange : HousepitalColors.greyLight,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(type['label']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                      color: HousepitalColors.black,
                                    )),
                                const SizedBox(height: 2),
                                Text(type['desc']!,
                                    style: const TextStyle(
                                        fontSize: 12, color: HousepitalColors.greyLight)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: levelColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              level.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: levelColor,
                              ),
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

        // Nurse level recommendation card (shown after selection)
        if (_selectedIvType != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _nurseLevelColor[_ivNurseLevel]!.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _nurseLevelColor[_ivNurseLevel]!,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user,
                    size: 28, color: _nurseLevelColor[_ivNurseLevel]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_nurseLevelLabel[_ivNurseLevel]} Assigned',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _nurseLevelColor[_ivNurseLevel],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This procedure requires a ${_nurseLevelLabel[_ivNurseLevel]?.toLowerCase()} (₹${_ivPrice}/visit). Nurse level cannot be changed.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _nurseLevelColor[_ivNurseLevel],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Additional IV visit details
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
                  Icon(Icons.assignment_outlined, size: 20, color: HousepitalColors.orange),
                  SizedBox(width: 8),
                  Text('Visit Details',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 14),

              // Medication name(s)
              TextFormField(
                controller: _medicationController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name(s) *',
                  hintText: 'e.g. Ceftriaxone 1g, NS 500ml...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 2,
                style: const TextStyle(fontSize: 14),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter medication name(s)' : null,
              ),
              const SizedBox(height: 14),

              // IV Access type
              const Text('IV Access',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: HousepitalColors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Fresh Cannulation'),
                    selected: _ivAccess == 'fresh',
                    onSelected: (_) => setState(() => _ivAccess = 'fresh'),
                    selectedColor: HousepitalColors.orangeLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: _ivAccess == 'fresh' ? HousepitalColors.orange : HousepitalColors.divider),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: _ivAccess == 'fresh' ? HousepitalColors.orange : HousepitalColors.grey,
                      fontWeight: _ivAccess == 'fresh' ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('PICC Line'),
                    selected: _ivAccess == 'picc',
                    onSelected: (_) => setState(() => _ivAccess = 'picc'),
                    selectedColor: HousepitalColors.orangeLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: _ivAccess == 'picc' ? HousepitalColors.orange : HousepitalColors.divider),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: _ivAccess == 'picc' ? HousepitalColors.orange : HousepitalColors.grey,
                      fontWeight: _ivAccess == 'picc' ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Port'),
                    selected: _ivAccess == 'port',
                    onSelected: (_) => setState(() => _ivAccess = 'port'),
                    selectedColor: HousepitalColors.orangeLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: _ivAccess == 'port' ? HousepitalColors.orange : HousepitalColors.divider),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: _ivAccess == 'port' ? HousepitalColors.orange : HousepitalColors.grey,
                      fontWeight: _ivAccess == 'port' ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Number of sessions
              const Text('Number of Sessions',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: HousepitalColors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _ivSessions > 1 ? () => setState(() => _ivSessions--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: HousepitalColors.orange,
                    iconSize: 28,
                  ),
                  Container(
                    width: 48,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: HousepitalColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_ivSessions',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _ivSessions++),
                    icon: const Icon(Icons.add_circle_outline),
                    color: HousepitalColors.orange,
                    iconSize: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _ivSessions == 1 ? 'session' : 'sessions',
                    style: const TextStyle(fontSize: 13, color: HousepitalColors.greyLight),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Known drug allergies
              TextFormField(
                controller: _allergiesController,
                decoration: const InputDecoration(
                  labelText: 'Known Drug Allergies',
                  hintText: 'e.g. Penicillin, Sulfa drugs... (leave blank if none)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 14),

              // Referring doctor
              TextFormField(
                controller: _referringDoctorController,
                decoration: const InputDecoration(
                  labelText: 'Referring Doctor / Hospital (optional)',
                  hintText: 'e.g. Dr. Sharma, Max Hospital',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
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
                _isIvVisit
                    ? 'Prescription upload is mandatory for IV visits'
                    : _isVisitService
                        ? 'Tell us why you need this visit and attach the prescription'
                        : 'Attach prescription or add notes for the visiting professional',
                style: TextStyle(
                    fontSize: 12,
                    color: _isIvVisit ? HousepitalColors.error : HousepitalColors.greyLight,
                    fontWeight: _isIvVisit ? FontWeight.w500 : FontWeight.w400),
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

              // Video Consultation option (shown when online assessment ON + consultation type)
              if (_requestOnlineAssessment && _isConsultationType)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildVideoConsultationOption(),
                ),
            ],
          ),
        ),
      ],

      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          // Doctor Visit: concern must be selected before proceeding to slot selection
          onPressed: (_isDoctorVisit && _selectedConcernCategory == null)
              ? null
              : () {
            // IV Visit validation
            if (_isIvVisit) {
              if (_selectedIvType == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select the type of IV procedure')),
                );
                return;
              }
              if (_medicationController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter the medication name(s)')),
                );
                return;
              }
              if (_attachedFiles.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prescription upload is mandatory for IV visits')),
                );
                return;
              }
            }
            setState(() => _step = 1);
          },
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
    // ── Ongoing manpower: start date (48hr+) + period (7/30 days) ──
    if (_isOngoingManpower) return _buildOngoingManpowerSlot(l);

    // ── Physio: daytime slot + period (3/7/15/30 days) ──
    if (_isPhysio) return _buildPhysioSlot(l);

    final nextDays = List.generate(
        7, (i) => DateTime.now().add(Duration(days: i + 1)));

    // Determine which slots are truly available (API + lead-time check).
    final bool allSlotsBooked = !_slotsLoading &&
        _selectedDate != null &&
        _availableSlots.every((s) {
          final hour = s['hour'] as int;
          final apiAvailable = s['available'] as bool? ?? true;
          return !apiAvailable || _isWithinLeadTime(_selectedDate!, hour);
        });

    return [
      const Text('Select Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: nextDays.map((date) {
          final isSelected = _selectedDate?.day == date.day &&
              _selectedDate?.month == date.month;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadSlotsForDate(date);
            },
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

      // Shimmer loading state
      if (_slotsLoading)
        Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: List.generate(
              9,
              (_) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),

      // Empty state
      if (!_slotsLoading && allSlotsBooked && _selectedDate != null)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: HousepitalColors.warningLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(Icons.event_busy, size: 40, color: HousepitalColors.warning),
              const SizedBox(height: 12),
              const Text(
                'No slots available',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'All slots are booked for this date. Please try another date.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: HousepitalColors.greyLight),
              ),
            ],
          ),
        ),

      // Slot grid (3 columns)
      if (!_slotsLoading && !allSlotsBooked && _selectedDate != null)
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: _availableSlots.map((slot) {
            final hour = slot['hour'] as int;
            final apiAvailable = slot['available'] as bool? ?? true;
            final withinLeadTime = _isWithinLeadTime(_selectedDate!, hour);
            final isAvailable = apiAvailable && !withinLeadTime;
            final slotValue = hour.toString();
            final isSelected = _selectedSlot == slotValue;

            return GestureDetector(
              onTap: isAvailable
                  ? () => setState(() => _selectedSlot = slotValue)
                  : null,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? HousepitalColors.orange
                      : isAvailable
                          ? HousepitalColors.white
                          : HousepitalColors.greyLighter,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? HousepitalColors.orange
                        : isAvailable
                            ? HousepitalColors.divider
                            : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  _slotLabel(hour),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : isAvailable
                            ? HousepitalColors.black
                            : Colors.grey,
                    decoration: isAvailable
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed:
              _isOngoingManpower
                  ? (_selectedDate != null ? () => setState(() => _step = 2) : null)
                  : (_selectedDate != null && _selectedSlot != null
                      ? () => setState(() => _step = 2)
                      : null),
          child: const Text('Next'),
        ),
      ),
    ];
  }

  // ── Ongoing manpower: start date (48hr min) + period (7/30 days) ──
  List<Widget> _buildOngoingManpowerSlot(AppLocalizations l) {
    // Start date must be at least 48 hours from now
    final minDate = DateTime.now().add(const Duration(hours: 48));
    final nextDays = List.generate(
        14, (i) => minDate.add(Duration(days: i)));

    return [
      const Text('Select Start Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Minimum 48 hours advance booking required',
          style: TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: nextDays.map((date) {
          final isSelected = _selectedDate?.day == date.day &&
              _selectedDate?.month == date.month;
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              child: Text(
                DateHelper.formatDateShort(date),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : HousepitalColors.black,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      const Text('Service Period',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _servicePeriod = '7'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _servicePeriod == '7'
                      ? HousepitalColors.orange
                      : HousepitalColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _servicePeriod == '7'
                        ? HousepitalColors.orange
                        : HousepitalColors.divider,
                  ),
                ),
                child: Column(
                  children: [
                    Text('7 Days',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: _servicePeriod == '7'
                              ? Colors.white : HousepitalColors.black,
                        )),
                    const SizedBox(height: 4),
                    Text('Trial / Short-term',
                        style: TextStyle(
                          fontSize: 11,
                          color: _servicePeriod == '7'
                              ? Colors.white70 : HousepitalColors.greyLight,
                        )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _servicePeriod = '30'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _servicePeriod == '30'
                      ? HousepitalColors.orange
                      : HousepitalColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _servicePeriod == '30'
                        ? HousepitalColors.orange
                        : HousepitalColors.divider,
                  ),
                ),
                child: Column(
                  children: [
                    Text('30 Days',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: _servicePeriod == '30'
                              ? Colors.white : HousepitalColors.black,
                        )),
                    const SizedBox(height: 4),
                    Text('Monthly (Recommended)',
                        style: TextStyle(
                          fontSize: 11,
                          color: _servicePeriod == '30'
                              ? Colors.white70 : HousepitalColors.greyLight,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      // Price summary
      if (widget.service.basePriceMin != null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HousepitalColors.successLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_servicePeriod} days × ₹${widget.service.basePriceMin?.toStringAsFixed(0)}/day',
                  style: const TextStyle(fontSize: 14, color: HousepitalColors.success)),
              Text('₹${((widget.service.basePriceMin ?? 0) * int.parse(_servicePeriod)).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HousepitalColors.success)),
            ],
          ),
        ),
      const SizedBox(height: 20),

      // ── Previous Staff Preference ──
      const Text('Staff Preference',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HousepitalColors.greyLighter,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HousepitalColors.divider),
        ),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Request same staff as before',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text(
                _requestSameStaff && _preferredStaffName != null
                    ? 'Preferred: $_preferredStaffName'
                    : 'We\'ll try to assign your previous caretaker/nurse',
                style: const TextStyle(fontSize: 12),
              ),
              value: _requestSameStaff,
              activeColor: HousepitalColors.orange,
              onChanged: (v) => setState(() => _requestSameStaff = v),
            ),
            if (_requestSameStaff) ...[
              const Divider(),
              // TODO: Load previous staff from API — for now show placeholder
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: HousepitalColors.orangeLight,
                  child: const Icon(Icons.person, color: HousepitalColors.orange),
                ),
                title: const Text('Your previous staff', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Based on past deployments', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: HousepitalColors.greyLight),
                onTap: () {
                  // TODO: Show previous staff list from API
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Previous staff list coming from backend')),
                  );
                },
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),

      // ── Autopay for Recurring Service ──
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HousepitalColors.infoLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HousepitalColors.info.withValues(alpha: 0.3)),
        ),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable Auto-Pay',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text(
            'Automatically renew and pay at the end of each period. Cancel anytime.',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableAutopay,
          activeColor: HousepitalColors.info,
          onChanged: (v) => setState(() => _enableAutopay = v),
        ),
      ),
      const SizedBox(height: 12),
      Text('We\'ll call back immediately after booking to confirm requirements and assign staff.',
          style: TextStyle(fontSize: 12, color: HousepitalColors.greyLight, fontStyle: FontStyle.italic)),
    ];
  }

  // ── Physio: daytime slot + period (3/7/15/30 days) ──
  List<Widget> _buildPhysioSlot(AppLocalizations l) {
    final nextDays = List.generate(
        7, (i) => DateTime.now().add(Duration(days: i + 1)));

    return [
      const Text('Select Start Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: nextDays.map((date) {
          final isSelected = _selectedDate?.day == date.day &&
              _selectedDate?.month == date.month;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadSlotsForDate(date);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? HousepitalColors.orange : HousepitalColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? HousepitalColors.orange : HousepitalColors.divider,
                ),
              ),
              child: Text(
                DateHelper.formatDateShort(date),
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : HousepitalColors.black,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      const Text('Preferred Time',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('Daytime slots only (9 AM – 5 PM)',
          style: TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
      const SizedBox(height: 12),
      if (_slotsLoading)
        const Center(child: CircularProgressIndicator(color: HousepitalColors.orange))
      else
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: _daytimeSlots.map((hour) {
            final isSelected = _selectedSlot == '$hour:00';
            return GestureDetector(
              onTap: () => setState(() => _selectedSlot = '$hour:00'),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? HousepitalColors.orange : HousepitalColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? HousepitalColors.orange : HousepitalColors.divider,
                  ),
                ),
                child: Text(
                  _slotLabel(hour),
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : HousepitalColors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      const SizedBox(height: 20),
      const Text('Number of Sessions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Row(
        children: ['3', '7', '15', '30'].map((days) {
          final isSelected = _physioPeriod == days;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _physioPeriod = days),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? HousepitalColors.orange : HousepitalColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? HousepitalColors.orange : HousepitalColors.divider,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('$days',
                          style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : HousepitalColors.black,
                          )),
                      Text('days',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? Colors.white70 : HousepitalColors.greyLight,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      if (widget.service.basePriceMin != null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HousepitalColors.successLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_physioPeriod sessions × ₹${widget.service.basePriceMin?.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 14, color: HousepitalColors.success)),
              Text('₹${((widget.service.basePriceMin ?? 0) * int.parse(_physioPeriod)).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HousepitalColors.success)),
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildReviewStep(ServiceItem s, AppLocalizations l) {
    final app = context.read<AppProvider>();
    // For IV visits, use the dynamically determined price
    final price = _isIvVisit ? _ivPrice : s.basePriceMin;
    // For IV visits with multiple sessions, multiply
    final sessionMultiplier = _isIvVisit ? _ivSessions : 1;
    final subtotal = price != null ? price * sessionMultiplier : null;
    final gst = subtotal != null ? (subtotal * 0.18).toInt() : null;
    final total = subtotal != null ? subtotal + gst! : null;

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
            // IV Visit details in review
            if (_isIvVisit && _selectedIvType != null) ...[
              _infoRow('Procedure', _ivInfusionTypes
                  .firstWhere((t) => t['id'] == _selectedIvType)['label']!),
              _infoRow('Nurse Level', _nurseLevelLabel[_ivNurseLevel] ?? ''),
              _infoRow('Medication', _medicationController.text),
              _infoRow('IV Access', _ivAccess == 'fresh' ? 'Fresh Cannulation'
                  : _ivAccess == 'picc' ? 'PICC Line' : 'Port'),
              if (_ivSessions > 1)
                _infoRow('Sessions', '$_ivSessions sessions'),
              if (_allergiesController.text.isNotEmpty)
                _infoRow('Allergies', _allergiesController.text),
              if (_referringDoctorController.text.isNotEmpty)
                _infoRow('Referring Doctor', _referringDoctorController.text),
            ],
            _infoRow('Date', _selectedDate != null
                ? DateHelper.formatDate(_selectedDate!)
                : ''),
            _infoRow('Slot', _selectedSlot != null
                ? _slotLabel(int.tryParse(_selectedSlot!) ?? 9)
                : ''),
            if (_attachedFiles.isNotEmpty)
              _infoRow('Attachments', '${_attachedFiles.length} file(s)'),
            if (_notesController.text.isNotEmpty)
              _infoRow('Notes', 'Included'),
            if (_requestOnlineAssessment)
              _infoRow('Online Assessment', 'Requested'),
            if (subtotal != null) ...[
              const Divider(height: 20),
              if (_isIvVisit && _ivSessions > 1) ...[
                _infoRow('Per Session', DateHelper.formatCurrency(price!)),
                _infoRow('Sessions', '× $_ivSessions'),
              ],
              _infoRow('Service Fee', DateHelper.formatCurrency(subtotal)),
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
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddressSelectionScreen()),
                    );
                    _loadAddresses();
                  },
                  child: const Text('Change',
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
            // For IV visits, use the dynamically determined price
            final price = _isIvVisit ? _ivPrice : widget.service.basePriceMin;
            final sessionMultiplier = _isIvVisit ? _ivSessions : 1;
            final subtotal = price != null ? price * sessionMultiplier : 0;
            final gst = (subtotal * 0.18).toInt();
            final total = subtotal + gst;

            // Build address string from selected address
            String? addressStr;
            if (_savedAddresses.isNotEmpty && _selectedAddressIndex < _savedAddresses.length) {
              final addr = _savedAddresses[_selectedAddressIndex];
              addressStr = addr['address'] ?? addr['label'] ?? '';
            }

            // Add service to cart
            final cart = Provider.of<CartProvider>(context, listen: false);
            cart.addService(
              serviceId: widget.service.id,
              serviceName: widget.service.name,
              category: widget.service.category,
              price: total,
              scheduledDate: _selectedDate ?? DateTime.now(),
              scheduledSlot: _selectedSlot ?? 'morning',
              address: addressStr,
              notes: _notesController.text.isNotEmpty ? _notesController.text : null,
              doctorType: _isDoctorVisit ? _recommendedDoctor : null,
              concern: _isDoctorVisit ? _concernController.text : null,
            );

            // Capture navigator before popping
            final nav = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);

            // Pop first, then show SnackBar on the parent screen
            nav.pop();

            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: const Text('Service added to cart'),
                  backgroundColor: HousepitalColors.success,
                  duration: const Duration(seconds: 2),
                  dismissDirection: DismissDirection.horizontal,
                  action: SnackBarAction(
                    label: 'View Cart',
                    textColor: Colors.white,
                    onPressed: () => nav.pushNamed('/cart'),
                  ),
                ),
              );
          },
          child: const Text('Confirm & Add to Cart'),
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

  Widget _buildVideoConsultationOption() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HousepitalColors.orangeLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HousepitalColors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.videocam, color: HousepitalColors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'Consultation Mode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.orangeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Home visit is the default — no extra action needed
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Home Visit selected'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.home, size: 18),
                  label: const Text('Home Visit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/video-consultation',
                        arguments: {
                          'doctorName': widget.service.name,
                          'doctorPhotoUrl': null,
                          'roomId': null,
                          'token': null,
                        });
                  },
                  icon: const Icon(Icons.videocam, size: 18),
                  label: const Text('Video'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
