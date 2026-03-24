import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../config/theme.dart';
import '../../models/models.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
import '../../data/care_packages.dart';
import '../../utils/helpers.dart';

class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key});

  /// Global key to allow switching sub-tabs from anywhere (e.g. home screen).
  static final GlobalKey<_ServiceCatalogScreenState> catalogKey =
      GlobalKey<_ServiceCatalogScreenState>();

  /// Switch to a specific sub-tab by index.
  /// 0=Manpower, 1=Equipment, 2=Consultations, 3=Visits, 4=Diagnostics, 5=Lab Tests, 6=Packages
  static void switchToSubTab(int index) {
    catalogKey.currentState?.switchSubTab(index);
  }

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  late final TabController _tabController;

  void switchSubTab(int index) {
    if (index >= 0 && index < _tabController.length) {
      _tabController.animateTo(index);
    }
  }

  // ── Real Housepital service catalog ──────────────────────────

  static final List<ServiceItem> _manpowerServices = [
    // ── Nursing Staff ──
    ServiceItem(
      id: 'mp-nurse-basic-12', name: 'Nurse (Basic) – 12 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Basic nursing care — vitals monitoring, oral medication, feeding & personal hygiene assistance.',
      basePriceMin: 900, durationMinutes: 720, iconName: 'medical_services',
    ),
    ServiceItem(
      id: 'mp-nurse-basic-24', name: 'Nurse (Basic) – 24 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Round-the-clock basic nursing for patients needing continuous monitoring and care.',
      basePriceMin: 1200, durationMinutes: 1440, iconName: 'medical_services',
    ),
    ServiceItem(
      id: 'mp-nurse-adv-12', name: 'Nurse (Advanced) – 12 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Advanced nursing — IV/IM medication, catheter care, RT feeding, sugar & BP monitoring.',
      basePriceMin: 1200, durationMinutes: 720, iconName: 'medical_services',
    ),
    ServiceItem(
      id: 'mp-nurse-adv-24', name: 'Nurse (Advanced) – 24 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Round-the-clock advanced nursing for patients needing clinical-grade care at home.',
      basePriceMin: 1500, durationMinutes: 1440, iconName: 'medical_services',
    ),
    // ── Critical Nurse — ICU setup, assessment required ──
    ServiceItem(
      id: 'mp-nurse-crit-12', name: 'Nurse (Critical) – 12 Hours',
      category: 'manpower', bookingType: 'assessment',
      description: 'Critical care nursing — tracheostomy care, ventilator management, suctioning, bed sore care.',
      iconName: 'medical_services',
    ),
    ServiceItem(
      id: 'mp-nurse-crit-24', name: 'Nurse (Critical) – 24 Hours',
      category: 'manpower', bookingType: 'assessment',
      description: 'Round-the-clock critical care nursing for ICU-like home setups and ventilator patients.',
      iconName: 'medical_services',
    ),
    // ── Care-takers ──
    ServiceItem(
      id: 'mp-caretaker-basic-12', name: 'Caretaker (Basic) – 12 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Basic caretaker — bathing, mobility assistance, feeding, companionship & medication reminders.',
      basePriceMin: 600, durationMinutes: 720, iconName: 'person',
    ),
    ServiceItem(
      id: 'mp-caretaker-basic-24', name: 'Caretaker (Basic) – 24 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Round-the-clock basic caretaker for daily living assistance and companionship.',
      basePriceMin: 800, durationMinutes: 1440, iconName: 'person',
    ),
    ServiceItem(
      id: 'mp-caretaker-adv-12', name: 'Caretaker (Advanced) – 12 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Advanced caretaker with IM injection & BP monitoring skills for patients needing medical support.',
      basePriceMin: 800, durationMinutes: 720, iconName: 'person',
    ),
    ServiceItem(
      id: 'mp-caretaker-adv-24', name: 'Caretaker (Advanced) – 24 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Round-the-clock advanced caretaker with medical assistance capabilities.',
      basePriceMin: 1000, durationMinutes: 1440, iconName: 'person',
    ),
    ServiceItem(
      id: 'mp-caretaker-crit-12', name: 'Caretaker (Critical / Semi-Nurse) – 12 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Semi-nurse level caretaker for complex care needs — RT feeding, suctioning assistance.',
      basePriceMin: 1000, durationMinutes: 720, iconName: 'person',
    ),
    ServiceItem(
      id: 'mp-caretaker-crit-24', name: 'Caretaker (Critical / Semi-Nurse) – 24 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Round-the-clock semi-nurse caretaker for patients needing intensive daily care.',
      basePriceMin: 1200, durationMinutes: 1440, iconName: 'person',
    ),
    // ── Japa Maid ──
    ServiceItem(
      id: 'mp-japa-24', name: 'Japa Maid – 24 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Post-delivery care for mother & newborn (0-7 months) — breastfeeding support, baby massage, bathing, umbilical cord care & mother\'s diet preparation.',
      basePriceMin: 800, durationMinutes: 1440, iconName: 'child_friendly',
    ),
    // ── Nanny ──
    ServiceItem(
      id: 'mp-nanny-12', name: 'Nanny – 12 Hours',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Professional nanny for infants & toddlers (7 months–5 years) — feeding, sleep routine, developmental activities, hygiene & safety supervision.',
      basePriceMin: 600, durationMinutes: 720, iconName: 'child_care',
    ),
    // ── Physiotherapy ──
    ServiceItem(
      id: 'mp-physio-basic', name: 'Physiotherapy (Basic)',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Basic physiotherapy (30-40 min) for TKR, THR, frozen shoulder, lower back pain, posture correction, sciatica & sports injuries. Therapist: 1-2 years experience.',
      basePriceMin: 900, durationMinutes: 40, iconName: 'fitness_center',
    ),
    ServiceItem(
      id: 'mp-physio-advance', name: 'Physiotherapy (Advanced)',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Advanced physiotherapy (45-50 min) for neuro rehab, antenatal/postnatal, cardiac rehab, pulmo rehab (not on O2). Therapist: 2-4 years experience.',
      basePriceMin: 1200, durationMinutes: 50, iconName: 'fitness_center',
    ),
    ServiceItem(
      id: 'mp-physio-critical', name: 'Physiotherapy (Critical)',
      category: 'manpower', bookingType: 'scheduled',
      description: 'Critical physiotherapy (50-60 min) for pulmo rehab on O2, neurosurgical cases, spinal cord injury & pediatric post-op. Therapist: 4+ years experience.',
      basePriceMin: 1500, durationMinutes: 60, iconName: 'fitness_center',
    ),
  ];

  static final List<ServiceItem> _equipmentServices = [
    ServiceItem(
      id: 'eq-hospital-bed',
      name: 'Hospital Bed',
      nameHi: '\u0905\u0938\u094d\u092a\u0924\u093e\u0932 \u092c\u0947\u0921',
      category: 'equipment',
      bookingType: 'instant',
      description:
          'Motorised hospital bed with adjustable head & foot \u2014 delivered within 24 hours in Delhi NCR.',
      descriptionHi:
          '\u090f\u0921\u091c\u0938\u094d\u091f\u0947\u092c\u0932 \u0939\u0947\u0921 \u0914\u0930 \u092b\u0941\u091f \u0915\u0947 \u0938\u093e\u0925 \u092e\u094b\u091f\u0930\u093e\u0907\u091c\u094d\u0921 \u0905\u0938\u094d\u092a\u0924\u093e\u0932 \u092c\u0947\u0921 \u2014 \u0926\u093f\u0932\u094d\u0932\u0940 NCR \u092e\u0947\u0902 24 \u0918\u0902\u091f\u0947 \u092e\u0947\u0902 \u0921\u093f\u0932\u0940\u0935\u0930\u0940\u0964',
      basePriceMin: 2500,
      leadTimeHours: 24,
      iconName: 'bed',
    ),
    ServiceItem(
      id: 'eq-oxygen-concentrator',
      name: 'Oxygen Concentrator',
      nameHi: '\u0911\u0915\u094d\u0938\u0940\u091c\u0928 \u0915\u0902\u0938\u0902\u091f\u094d\u0930\u0947\u091f\u0930',
      category: 'equipment',
      bookingType: 'instant',
      description:
          '5L/10L oxygen concentrator on rent \u2014 delivered within 24 hours in Delhi NCR.',
      descriptionHi:
          '5L/10L \u0911\u0915\u094d\u0938\u0940\u091c\u0928 \u0915\u0902\u0938\u0902\u091f\u094d\u0930\u0947\u091f\u0930 \u0915\u093f\u0930\u093e\u090f \u092a\u0930 \u2014 \u0926\u093f\u0932\u094d\u0932\u0940 NCR \u092e\u0947\u0902 24 \u0918\u0902\u091f\u0947 \u092e\u0947\u0902 \u0921\u093f\u0932\u0940\u0935\u0930\u0940\u0964',
      basePriceMin: 3000,
      leadTimeHours: 24,
      iconName: 'air',
    ),
    ServiceItem(
      id: 'eq-wheelchair',
      name: 'Wheelchair',
      nameHi: '\u0935\u094d\u0939\u0940\u0932\u091a\u0947\u092f\u0930',
      category: 'equipment',
      bookingType: 'instant',
      description:
          'Foldable wheelchair for patient mobility \u2014 buy or rent, delivered in 24 hours.',
      descriptionHi:
          '\u092e\u0930\u0940\u091c \u0915\u0940 \u0917\u0924\u093f\u0936\u0940\u0932\u0924\u093e \u0915\u0947 \u0932\u093f\u090f \u092b\u094b\u0932\u094d\u0921\u0947\u092c\u0932 \u0935\u094d\u0939\u0940\u0932\u091a\u0947\u092f\u0930 \u2014 \u0916\u0930\u0940\u0926\u0947\u0902 \u092f\u093e \u0915\u093f\u0930\u093e\u090f \u092a\u0930, 24 \u0918\u0902\u091f\u0947 \u092e\u0947\u0902 \u0921\u093f\u0932\u0940\u0935\u0930\u0940\u0964',
      basePriceMin: 4500,
      leadTimeHours: 24,
      iconName: 'accessible',
    ),
    ServiceItem(
      id: 'eq-bp-monitor',
      name: 'BP Monitor',
      nameHi: '\u092c\u0940\u092a\u0940 \u092e\u0949\u0928\u093f\u091f\u0930',
      category: 'equipment',
      bookingType: 'instant',
      description:
          'Digital blood pressure monitor for home use \u2014 delivered in 24 hours.',
      descriptionHi:
          '\u0918\u0930 \u092a\u0930 \u0909\u092a\u092f\u094b\u0917 \u0915\u0947 \u0932\u093f\u090f \u0921\u093f\u091c\u093f\u091f\u0932 \u092c\u094d\u0932\u0921 \u092a\u094d\u0930\u0947\u0936\u0930 \u092e\u0949\u0928\u093f\u091f\u0930 \u2014 24 \u0918\u0902\u091f\u0947 \u092e\u0947\u0902 \u0921\u093f\u0932\u0940\u0935\u0930\u0940\u0964',
      basePriceMin: 1200,
      leadTimeHours: 24,
      iconName: 'monitor_heart',
    ),
    ServiceItem(
      id: 'eq-consumables',
      name: 'Medical Consumables',
      nameHi: '\u092e\u0947\u0921\u093f\u0915\u0932 \u0938\u093e\u092e\u0917\u094d\u0930\u0940',
      category: 'equipment',
      bookingType: 'instant',
      description:
          'Gloves, diapers, wound care kits, syringes & more \u2014 delivered in 24 hours in Delhi NCR.',
      descriptionHi:
          '\u0926\u0938\u094d\u0924\u093e\u0928\u0947, \u0921\u093e\u092f\u092a\u0930, \u0918\u093e\u0935 \u0926\u0947\u0916\u092d\u093e\u0932 \u0915\u093f\u091f, \u0938\u093f\u0930\u093f\u0902\u091c \u0914\u0930 \u0905\u0927\u093f\u0915 \u2014 \u0926\u093f\u0932\u094d\u0932\u0940 NCR \u092e\u0947\u0902 24 \u0918\u0902\u091f\u0947 \u092e\u0947\u0902 \u0921\u093f\u0932\u0940\u0935\u0930\u0940\u0964',
      basePriceMin: 500,
      leadTimeHours: 24,
      iconName: 'inventory_2',
    ),
  ];

  // ── Diagnostics (at-home tests with equipment) ──
  static final List<ServiceItem> _diagnosticServices = [
    ServiceItem(
      id: 'dx-ecg', name: 'ECG at Home',
      category: 'diagnostics', bookingType: 'instant',
      description: '12-lead ECG performed at home by a trained technician. Report within 2 hours.',
      basePriceMin: 500, durationMinutes: 30, leadTimeHours: 4, iconName: 'monitor_heart',
    ),
    ServiceItem(
      id: 'dx-xray', name: 'X-Ray at Home',
      category: 'diagnostics', bookingType: 'instant',
      description: 'Portable digital X-Ray at your doorstep. Report shared within 4 hours.',
      basePriceMin: 800, durationMinutes: 30, leadTimeHours: 6, iconName: 'radiology',
    ),
    ServiceItem(
      id: 'dx-holter', name: 'Holter Monitoring',
      category: 'diagnostics', bookingType: 'instant',
      description: '24-hour Holter monitor fitted at home. Technician visits for setup & removal. Report in 48 hours.',
      basePriceMin: 2500, durationMinutes: 45, leadTimeHours: 12, iconName: 'monitor_heart',
    ),
  ];

  // ── Lab Tests (panels + sample collection) ──
  static final List<ServiceItem> _labServices = [
    ServiceItem(
      id: 'lab-fever', name: 'Fever Panel',
      category: 'lab', bookingType: 'instant',
      description: 'CBC, CRP, Procalcitonin, Peripheral Smear, Typhidot, Dengue NS1, COVID test, Urine Routine — comprehensive fever workup.',
      basePriceMin: 4999, basePriceMax: 4999, iconName: 'science',
    ),
    ServiceItem(
      id: 'lab-wellness', name: 'Wellness Package',
      category: 'lab', bookingType: 'instant',
      description: 'CBC, LFT, KFT, Uric Acid, Thyroid, Lipid Profile, Vitamin B12 & D, Iron, ESR, HbA1C, Folate — 14 tests for complete health check.',
      basePriceMin: 7599, basePriceMax: 7599, iconName: 'science',
    ),
    ServiceItem(
      id: 'lab-immunity', name: 'Immunity Package',
      category: 'lab', bookingType: 'instant',
      description: 'CRP, ESR, Vitamin D & B12, Iron Profile, Folate, Phosphorus, Calcium, Total Proteins — immune health assessment.',
      basePriceMin: 4599, basePriceMax: 4599, iconName: 'science',
    ),
    ServiceItem(
      id: 'lab-bone', name: 'Bone Package',
      category: 'lab', bookingType: 'instant',
      description: 'Alkaline Phosphatase, LDH, PTH, Calcium, Vitamin D — bone health and osteoporosis screening.',
      basePriceMin: 2999, basePriceMax: 2999, iconName: 'science',
    ),
    ServiceItem(
      id: 'lab-metabolic', name: 'Metabolic Package',
      category: 'lab', bookingType: 'instant',
      description: 'Random Sugar, HbA1C, GGT, Lipid Profile, CRP, Liver Profile — metabolic syndrome screening.',
      basePriceMin: 1799, basePriceMax: 1799, iconName: 'science',
    ),
    ServiceItem(
      id: 'lab-adolescent', name: 'Adolescent Package',
      category: 'lab', bookingType: 'instant',
      description: 'HbA1C, CBC, Vitamin D, TSH, Iron Profile — health check for young adults.',
      basePriceMin: 2499, basePriceMax: 2499, iconName: 'science',
    ),
    ServiceItem(
      id: 'lab-anemia', name: 'Anemia Package',
      category: 'lab', bookingType: 'instant',
      description: 'CBC, Peripheral Smear, ESR, HPLC, Ferritin, Iron Profile, Reticulocyte Count, B12, Folate — complete anemia workup.',
      basePriceMin: 4599, basePriceMax: 4599, iconName: 'science',
    ),
    ServiceItem(
      id: 'dx-sample-5km', name: 'Blood Sample Collection (0-5 km)',
      category: 'lab', bookingType: 'instant',
      description: 'Phlebotomist visits your home to collect blood samples. Reports shared digitally.',
      basePriceMin: 150, basePriceMax: 150, iconName: 'science',
    ),
    ServiceItem(
      id: 'dx-sample-10km', name: 'Blood Sample Collection (5-10 km)',
      category: 'lab', bookingType: 'instant',
      description: 'Phlebotomist visits your home to collect blood samples. Reports shared digitally.',
      basePriceMin: 200, basePriceMax: 200, iconName: 'science',
    ),
    ServiceItem(
      id: 'dx-sample-15km', name: 'Blood Sample Collection (10-15 km)',
      category: 'lab', bookingType: 'instant',
      description: 'Phlebotomist visits your home to collect blood samples. Reports shared digitally.',
      basePriceMin: 250, basePriceMax: 250, iconName: 'science',
    ),
  ];

  // ── Consultations (doctor visits, mental health, therapy) ──
  static final List<ServiceItem> _consultationServices = [
    ServiceItem(
      id: 'con-doctor', name: 'Doctor Visit',
      category: 'consultation', bookingType: 'scheduled',
      description: 'Tell us your concern — we\'ll recommend the right doctor (General Physician or ICU Specialist) for your home visit.',
      basePriceMin: 3500, basePriceMax: 5000, durationMinutes: 30, leadTimeHours: 4,
      iconName: 'stethoscope',
    ),
    ServiceItem(
      id: 'con-psychiatrist', name: 'Psychiatrist Consultation',
      category: 'consultation', bookingType: 'assessment',
      description: 'Licensed psychiatrist for mental health assessment, medication management & therapy referrals.',
      basePriceMin: 1500, durationMinutes: 45, leadTimeHours: 24, iconName: 'psychology',
    ),
    ServiceItem(
      id: 'con-grief', name: 'Grief Counselling',
      category: 'consultation', bookingType: 'assessment',
      description: 'Compassionate support for loss, bereavement & emotional recovery. In-person or video.',
      basePriceMin: 1200, durationMinutes: 60, leadTimeHours: 24, iconName: 'favorite',
    ),
    ServiceItem(
      id: 'th-sleep', name: 'Sleep Therapy',
      category: 'consultation', bookingType: 'instant',
      description: 'Certified sleep therapist visit — assessment, sleep hygiene counselling & personalised routine.',
      basePriceMin: 1500, durationMinutes: 60, leadTimeHours: 24, iconName: 'bedtime',
    ),
  ];

  // ── Visits (nursing procedures at home) ──
  static final List<ServiceItem> _visitServices = [
    ServiceItem(
      id: 'visit-iv', name: 'IV Visit',
      category: 'visit', bookingType: 'scheduled',
      description: 'Tell us the type of IV procedure — we\'ll assign the right nurse level and bill accordingly.',
      basePriceMin: 900, basePriceMax: 1500, iconName: 'vaccines',
    ),
    ServiceItem(
      id: 'visit-im', name: 'IM Injection Visit',
      category: 'visit', bookingType: 'scheduled',
      description: 'Intramuscular injection visit — nurse administers prescribed IM medication at home.',
      basePriceMin: 500, basePriceMax: 500, durationMinutes: 30, iconName: 'medical_services',
    ),
    ServiceItem(
      id: 'visit-dressing-basic', name: 'Dressing Visit (Basic)',
      category: 'visit', bookingType: 'scheduled',
      description: 'Basic wound dressing — simple wounds, surgical site care, suture line dressing.',
      basePriceMin: 1200, basePriceMax: 1200, durationMinutes: 45, iconName: 'medical_services',
    ),
    ServiceItem(
      id: 'visit-dressing-adv', name: 'Dressing Visit (Advanced)',
      category: 'visit', bookingType: 'scheduled',
      description: 'Advanced dressing — complex wounds, drain site care, negative pressure wound care.',
      basePriceMin: 1500, basePriceMax: 1500, durationMinutes: 60, iconName: 'medical_services',
    ),
    ServiceItem(
      id: 'visit-dressing-crit', name: 'Dressing Visit (Critical)',
      category: 'visit', bookingType: 'scheduled',
      description: 'Critical dressing — deep wound debridement, extensive burn care, multi-site dressing.',
      basePriceMin: 2000, basePriceMax: 2000, durationMinutes: 90, iconName: 'medical_services',
    ),
    ServiceItem(
      id: 'visit-catheter', name: 'Catheter Change',
      category: 'visit', bookingType: 'scheduled',
      description: 'Urinary catheter insertion or change by trained nurse at home.',
      basePriceMin: 1200, basePriceMax: 1200, durationMinutes: 30, iconName: 'medical_services',
    ),
    ServiceItem(
      id: 'visit-rt-change', name: 'RT (Ryles Tube) Change',
      category: 'visit', bookingType: 'scheduled',
      description: 'Nasogastric / Ryles tube insertion or change by trained nurse.',
      basePriceMin: 1200, basePriceMax: 1200, durationMinutes: 30, iconName: 'medical_services',
    ),
    ServiceItem(
      id: 'visit-tracheostomy', name: 'Tracheostomy Change',
      category: 'visit', bookingType: 'scheduled',
      description: 'Tracheostomy tube change by experienced critical care nurse.',
      basePriceMin: 5000, basePriceMax: 5000, durationMinutes: 60, iconName: 'medical_services',
    ),
  ];

  static final _iconMap = <String, IconData>{
    'medical_services': Icons.medical_services,
    'fitness_center': Icons.fitness_center,
    'bedtime': Icons.bedtime,
    'science': Icons.science,
    'person': Icons.person,
    'local_hospital': Icons.local_hospital,
    'monitor_heart': Icons.monitor_heart,
    'child_friendly': Icons.child_friendly,
    'child_care': Icons.child_care,
    'bed': Icons.bed,
    'air': Icons.air,
    'accessible': Icons.accessible,
    'inventory_2': Icons.inventory_2,
    'radiology': Icons.monitor_heart,
    'stethoscope': Icons.medical_information,
    'psychology': Icons.psychology,
    'favorite': Icons.favorite,
    'vaccines': Icons.vaccines,
    'healing': Icons.healing,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<ServiceItem> _filterBySearch(List<ServiceItem> services) {
    if (_searchQuery.isEmpty) return services;
    final q = _searchQuery.toLowerCase();
    return services.where((s) {
      return s.name.toLowerCase().contains(q) ||
          (s.nameHi?.toLowerCase().contains(q) ?? false) ||
          (s.description?.toLowerCase().contains(q) ?? false) ||
          (s.descriptionHi?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('book_services')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: HousepitalColors.orange,
          unselectedLabelColor: HousepitalColors.greyLight,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: HousepitalColors.orange,
          indicatorWeight: 3,
          dividerColor: HousepitalColors.divider,
          tabs: const [
            Tab(text: 'Manpower'),
            Tab(text: 'Equipment'),
            Tab(text: 'Consultations'),
            Tab(text: 'Visits'),
            Tab(text: 'Diagnostics'),
            Tab(text: 'Lab Tests'),
            Tab(text: 'Packages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ManpowerTab(
            services: _manpowerServices,
            iconMap: _iconMap,
            searchQuery: _searchQuery,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            onSearchChanged: _onSearchChanged,
            filterBySearch: _filterBySearch,
            onNavigate: _navigateToService,
          ),
          const _EquipmentTab(),
          _ConsultationsTab(
            services: _consultationServices,
            iconMap: _iconMap,
            searchQuery: _searchQuery,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            onSearchChanged: _onSearchChanged,
            filterBySearch: _filterBySearch,
            onNavigate: _navigateToService,
          ),
          _ConsultationsTab(
            services: _visitServices,
            iconMap: _iconMap,
            searchQuery: _searchQuery,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            onSearchChanged: _onSearchChanged,
            filterBySearch: _filterBySearch,
            onNavigate: _navigateToService,
          ),
          _DiagnosticsTab(
            services: _diagnosticServices,
            iconMap: _iconMap,
            searchQuery: _searchQuery,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            onSearchChanged: _onSearchChanged,
            filterBySearch: _filterBySearch,
            onNavigate: _navigateToService,
          ),
          _DiagnosticsTab(
            services: _labServices,
            iconMap: _iconMap,
            searchQuery: _searchQuery,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            onSearchChanged: _onSearchChanged,
            filterBySearch: _filterBySearch,
            onNavigate: _navigateToService,
          ),
          const _PackagesTab(),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim());
  }

  void _navigateToService(BuildContext context, ServiceItem service) {
    if (service.isInstant) {
      Navigator.pushNamed(context, '/service-booking', arguments: service);
    } else {
      Navigator.pushNamed(context, '/assessment-request', arguments: service);
    }
  }

  void _navigateToEquipmentDetail(BuildContext context, ServiceItem service) {
    Navigator.pushNamed(context, '/equipment-detail', arguments: service);
  }
}

// ═══════════════════════════════════════════════════════════════
//  SEARCH BAR (shared across tabs)
// ═══════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final String searchQuery;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.searchQuery,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Semantics(
        label: 'Search services and equipment',
        textField: true,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(
            fontSize: 15,
            color: HousepitalColors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Search services, equipment...',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: HousepitalColors.greyLight,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: HousepitalColors.greyLight,
              size: 22,
            ),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    tooltip: 'Clear search',
                  )
                : null,
            filled: true,
            fillColor: HousepitalColors.greyLighter,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: HousepitalColors.orange,
                width: 2,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  EMPTY STATE
// ═══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 56,
            color: HousepitalColors.greyLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'No services found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HousepitalColors.grey,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: HousepitalColors.greyLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TRUST BADGE BAR
// ═══════════════════════════════════════════════════════════════

class _TrustBadge {
  final IconData icon;
  final String text;
  const _TrustBadge({required this.icon, required this.text});
}

class _TrustBadgeBar extends StatelessWidget {
  final List<_TrustBadge> badges;
  const _TrustBadgeBar({required this.badges});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HousepitalColors.successLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: badges.expand((badge) {
          final index = badges.indexOf(badge);
          return [
            if (index > 0) ...[
              Container(
                width: 1,
                height: 16,
                color: HousepitalColors.success.withValues(alpha: 0.3),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ],
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badge.icon,
                      size: 16, color: HousepitalColors.success),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      badge.text,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HousepitalColors.success,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ];
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  MANPOWER TAB — Role-based cards
// ═══════════════════════════════════════════════════════════════

class _ServiceLevel {
  final String name;
  final List<String> included; // services included at this level
  final List<String> excluded; // services NOT included at this level

  const _ServiceLevel({
    required this.name,
    required this.included,
    this.excluded = const [],
  });
}

class _StaffRole {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_ServiceLevel> levels;
  final List<String> availableShifts;
  final double rating;
  final int reviewCount;

  const _StaffRole({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.levels,
    required this.availableShifts,
    this.rating = 4.8,
    this.reviewCount = 120,
  });

  /// Flat list of all included responsibilities across all levels.
  List<String> get allResponsibilities {
    final set = <String>{};
    for (final level in levels) {
      set.addAll(level.included);
    }
    return set.toList();
  }
}

const _staffRoles = <_StaffRole>[
  // ── Caretaker (from HOUSEPITAL/DOC/02/00/01) ──────────────
  _StaffRole(
    title: 'Caretaker',
    subtitle: 'Daily assistance & personal care',
    icon: Icons.person,
    availableShifts: ['12 Hours', '24 Hours'],
    rating: 4.8,
    reviewCount: 245,
    levels: [
      _ServiceLevel(
        name: 'Basic',
        included: [
          'Oral care',
          'Toilet assistance',
          'Personal hygiene care (including sponging)',
          'Feeding',
          'Sanitary care',
          'Diaper changing & motion cleaning',
          'Muscle strengthening exercise',
          'Movement assistance',
          'Patient dressing & undressing',
          'Administration of oral medication',
          'Raw fruit & salad cutting for the patient',
        ],
        excluded: [
          'RT feeding',
          'Patient massage',
          'Sugar monitoring',
          'Insulin administration',
          'Blood pressure monitoring',
          'IV medication',
          'Tracheostomy care',
          'RT change',
          'Catheter care & change',
          'Suctioning',
          'Stitches care',
          'Bed sores care',
          'Ventilator care',
          'Household chores (brooming, mopping, cooking)',
        ],
      ),
      _ServiceLevel(
        name: 'Advanced',
        included: [
          'All Basic services',
          'RT feeding',
          'Sugar monitoring',
          'Insulin administration',
          'Blood pressure monitoring',
        ],
        excluded: [
          'Patient massage',
          'IV medication',
          'Tracheostomy care',
          'RT change',
          'Catheter care & change',
          'Suctioning',
          'Stitches care',
          'Bed sores care',
          'Ventilator care',
          'Household chores (brooming, mopping, cooking)',
        ],
      ),
    ],
  ),
  // ── Nurse (from HOUSEPITAL/DOC/01/00/01) ───────────────────
  _StaffRole(
    title: 'Nurse',
    subtitle: 'Medical care & clinical procedures',
    icon: Icons.medical_services,
    availableShifts: ['12 Hours', '24 Hours'],
    rating: 4.9,
    reviewCount: 189,
    levels: [
      _ServiceLevel(
        name: 'Basic',
        included: [
          'Oral care',
          'Toilet assistance',
          'Personal hygiene care (including sponging)',
          'Feeding',
          'Muscle strengthening exercise',
          'Movement assistance',
          'Patient dressing & undressing',
          'Administration of oral medication',
          'Sugar monitoring',
          'Insulin administration',
          'Blood pressure monitoring',
          'Medication through IV & oral',
          'Catheter care & change',
        ],
        excluded: [
          'RT feeding',
          'Sanitary care',
          'Diaper changing & motion cleaning',
          'Patient massage',
          'Tracheostomy care',
          'RT change',
          'Suctioning',
          'Stitches care',
          'Bed sores care',
          'Ventilator care',
        ],
      ),
      _ServiceLevel(
        name: 'Advanced',
        included: [
          'All Basic services',
          'RT feeding',
          'Sanitary care',
          'Tracheostomy care',
          'RT change',
          'Suctioning',
          'Stitches care',
          'Bed sores care',
        ],
        excluded: [
          'Diaper changing & motion cleaning',
          'Patient massage',
          'Ventilator care under FIO2 45%',
        ],
      ),
      _ServiceLevel(
        name: 'Critical',
        included: [
          'All Advanced services',
          'Personal hygiene care',
          'Diaper changing & motion cleaning',
          'Ventilator care under FIO2 45%',
        ],
        excluded: [
          'Toilet assistance',
          'Patient massage',
          'Household chores',
        ],
      ),
    ],
  ),
  // ── Japa Maid (from HOUSEPITAL Scope of Services – Nanny & Japa, 0-7 months) ──
  _StaffRole(
    title: 'Japa Maid',
    subtitle: 'Post-delivery mother & newborn care (0–7 months)',
    icon: Icons.child_friendly,
    availableShifts: ['12 Hours', '24 Hours'],
    rating: 4.7,
    reviewCount: 156,
    levels: [
      _ServiceLevel(
        name: 'Standard',
        included: [
          // Feeding
          'Feeding baby at regular intervals (breastfeeding / formula)',
          'Helping mothers in lactation or breast feeding',
          'Feeding the baby (solid food)',
          'Prepare basic food for mother – daal, daliya, khichadi',
          // Grooming & hygiene
          'Taking care of umbilical cord',
          'Massaging and skin care of baby',
          'Massage for the mother',
          'Bathing, sponging and grooming – Baby',
          'Changing diapers – Baby',
          // Health safety
          'Administering medicine with parents\' consent – Baby',
          'Monitoring the baby\'s health',
          'Holding and soothing the baby',
          'Putting the child to sleep',
          // Household chores & sterilization
          'Cleaning and sterilization of baby items, toys',
          'Organising child\'s room, folding clothes, cleaning & cooking for the child',
          // Education & development
          'Engaging the child in playing activities',
          'Supervising & monitoring the safety of children',
        ],
        excluded: [
          'Toilet training – Baby',
          'Planning development activities (reading, arts & crafts)',
          'Educating the baby',
          'Dropping & picking children from/to school, parks, appointments',
        ],
      ),
    ],
  ),
  // ── Nanny (from HOUSEPITAL Scope of Services – Nanny & Japa, 7 months–5 years) ──
  _StaffRole(
    title: 'Nanny',
    subtitle: 'Infant & toddler care (7 months – 5 years)',
    icon: Icons.child_care,
    availableShifts: ['12 Hours', '24 Hours'],
    rating: 4.8,
    reviewCount: 134,
    levels: [
      _ServiceLevel(
        name: 'Standard',
        included: [
          // Feeding
          'Feeding the baby (solid food)',
          // Grooming & hygiene
          'Massaging and skin care of baby',
          'Bathing, sponging and grooming – Baby',
          'Changing diapers – Baby',
          'Toilet training – Baby',
          // Health safety
          'Administering medicine with parents\' consent – Baby',
          'Monitoring the baby\'s health',
          'Holding and soothing the baby',
          'Putting the child to sleep',
          // Household chores & sterilization
          'Cleaning and sterilization of baby items, toys',
          'Organising child\'s room, folding clothes, cleaning & cooking for the child',
          // Education & development
          'Planning development activities (reading, arts & crafts)',
          'Educating the baby',
          'Engaging the child in playing activities',
          'Supervising & monitoring the safety of children',
          'Dropping & picking children from/to school, parks, appointments',
        ],
        excluded: [
          'Feeding baby at regular intervals (breastfeeding / formula)',
          'Helping mothers in lactation or breast feeding',
          'Prepare basic food for mother – daal, daliya, khichadi',
          'Taking care of umbilical cord',
          'Massage for the mother',
        ],
      ),
    ],
  ),
  // ── Physiotherapist ────────────────────────────────────────
  _StaffRole(
    title: 'Physiotherapist',
    subtitle: 'Rehab, mobility & pain management',
    icon: Icons.fitness_center,
    availableShifts: ['Per Visit (45 min)'],
    rating: 4.9,
    reviewCount: 98,
    levels: [
      _ServiceLevel(
        name: 'Standard',
        included: [
          'Post-surgery rehabilitation exercises',
          'Joint mobility & strengthening',
          'Pain management techniques',
          'Balance & gait training',
          'Chest physiotherapy',
          'Personalised exercise plan',
        ],
      ),
    ],
  ),
];

class _ManpowerTab extends StatelessWidget {
  final List<ServiceItem> services;
  final Map<String, IconData> iconMap;
  final String searchQuery;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final List<ServiceItem> Function(List<ServiceItem>) filterBySearch;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const _ManpowerTab({
    required this.services,
    required this.iconMap,
    required this.searchQuery,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.filterBySearch,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    // Filter roles by search
    final roles = searchQuery.isEmpty
        ? _staffRoles
        : _staffRoles
            .where((r) =>
                r.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                r.subtitle.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

    if (roles.isEmpty && searchQuery.isNotEmpty) {
      return Column(
        children: [
          _SearchBar(
            searchQuery: searchQuery,
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: onSearchChanged,
          ),
          const Expanded(child: _EmptyState()),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SearchBar(
          searchQuery: searchQuery,
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: onSearchChanged,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _TrustBadgeBar(
            badges: [
              _TrustBadge(
                  icon: Icons.verified_user,
                  text: 'Housepital Guarantee'),
              _TrustBadge(
                  icon: Icons.check_circle_outline,
                  text: 'Background Verified'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...roles.map((role) => _StaffRoleCard(
              role: role,
              services: services,
              onNavigate: onNavigate,
            )),
      ],
    );
  }
}

class _StaffRoleCard extends StatelessWidget {
  final _StaffRole role;
  final List<ServiceItem> services;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const _StaffRoleCard({
    required this.role,
    required this.services,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: HousepitalColors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: () => _showRoleDetail(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: HousepitalColors.orangeLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(role.icon,
                      color: HousepitalColors.orange, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HousepitalColors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: HousepitalColors.greyLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 14, color: HousepitalColors.orange),
                          const SizedBox(width: 3),
                          Text(
                            '${role.rating}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: HousepitalColors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${role.reviewCount})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: HousepitalColors.greyLight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.schedule,
                              size: 14,
                              color: HousepitalColors.greyLight),
                          const SizedBox(width: 3),
                          Text(
                            role.availableShifts.join(' / '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: HousepitalColors.greyLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: HousepitalColors.greyLight, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRoleDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: HousepitalColors.orangeLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(role.icon,
                        color: HousepitalColors.orange, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: HousepitalColors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          role.subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: HousepitalColors.greyLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Rating
              Row(
                children: [
                  const Icon(Icons.star,
                      size: 18, color: HousepitalColors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '${role.rating}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: HousepitalColors.black,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${role.reviewCount} reviews)',
                    style: const TextStyle(
                      fontSize: 13,
                      color: HousepitalColors.greyLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Available shifts
              const Text(
                'Available Options',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: role.availableShifts
                    .map((shift) => Chip(
                          label: Text(shift),
                          avatar: const Icon(Icons.schedule,
                              size: 16,
                              color: HousepitalColors.orange),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Scope of Service — level-based
              const Text(
                'Scope of Service',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                ),
              ),
              const SizedBox(height: 10),
              ...role.levels.map((level) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (role.levels.length > 1) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: HousepitalColors.orangeLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            level.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: HousepitalColors.orangeText,
                            ),
                          ),
                        ),
                      ],
                      // Included services
                      ...level.included.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(Icons.check_circle,
                                      size: 16,
                                      color: HousepitalColors.success),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    r,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: HousepitalColors.grey,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      // Excluded services
                      if (level.excluded.isNotEmpty) ...[
                        ...level.excluded.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Icon(Icons.cancel,
                                        size: 16,
                                        color: HousepitalColors.greyLight
                                            .withOpacity(0.5)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      r,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: HousepitalColors.greyLight
                                            .withOpacity(0.7),
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      if (role.levels.length > 1)
                        const SizedBox(height: 12),
                    ],
                  )),
              const SizedBox(height: 16),

              // Trust badges
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HousepitalColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user,
                            size: 16, color: HousepitalColors.success),
                        SizedBox(width: 8),
                        Text(
                          'Background verified & Aadhaar checked',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: HousepitalColors.success,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.shield,
                            size: 16, color: HousepitalColors.success),
                        SizedBox(width: 8),
                        Text(
                          'Police verification completed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: HousepitalColors.success,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.school,
                            size: 16, color: HousepitalColors.success),
                        SizedBox(width: 8),
                        Text(
                          'Housepital trained & certified',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: HousepitalColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Request Assessment button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Find the first matching service to pass to assessment
                    final matchingService = services.firstWhere(
                      (s) => s.name.toLowerCase().contains(
                          role.title.toLowerCase().split(' ').first),
                      orElse: () => services.first,
                    );
                    Navigator.pushNamed(context, '/assessment-request',
                        arguments: matchingService);
                  },
                  child: const Text('Request Assessment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  EQUIPMENT TAB
// ═══════════════════════════════════════════════════════════════

class _EquipmentTab extends StatefulWidget {
  const _EquipmentTab();

  @override
  State<_EquipmentTab> createState() => _EquipmentTabState();
}

class _EquipmentTabState extends State<_EquipmentTab> {
  List<EquipmentItem> _allItems = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _sortBy = 'Relevance';
  final _searchController = TextEditingController();

  static const _categories = ['All', 'Equipment', 'Consumable'];
  static const _sortOptions = ['Relevance', 'Price: Low to High', 'Price: High to Low', 'Name A-Z'];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      // Try backend first
      _allItems = await ApiService().getEquipmentCatalog();
    } catch (_) {
      // Fallback: load from bundled JSON asset
      try {
        final jsonStr =
            await rootBundle.loadString('assets/equipment_catalog.json');
        final List<dynamic> list = json.decode(jsonStr);
        _allItems = list.map((e) => EquipmentItem.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error loading equipment catalog: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<EquipmentItem> get _filtered {
    var items = _allItems;
    if (_selectedCategory != 'All') {
      items = items.where((i) => i.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((i) =>
              i.name.toLowerCase().contains(q) ||
              i.brand.toLowerCase().contains(q))
          .toList();
    }
    // Apply sorting
    switch (_sortBy) {
      case 'Price: Low to High':
        items = List.of(items)
          ..sort((a, b) => (a.price ?? double.infinity).compareTo(b.price ?? double.infinity));
        break;
      case 'Price: High to Low':
        items = List.of(items)
          ..sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
        break;
      case 'Name A-Z':
        items = List.of(items)
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      default: // Relevance — keep original order
        break;
    }
    return items;
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Equipment':
        return Icons.medical_services;
      case 'Consumable':
        return Icons.inventory_2;
      case 'Medicine':
        return Icons.medication;
      default:
        return Icons.inventory_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: HousepitalColors.orange));
    }

    final filtered = _filtered;

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search equipment, consumables...',
              prefixIcon:
                  const Icon(Icons.search, color: HousepitalColors.greyLight),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: HousepitalColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        // Trust badges
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _TrustBadgeBar(
            badges: [
              _TrustBadge(
                  icon: Icons.local_shipping,
                  text: '24hr Delivery in Delhi NCR'),
              _TrustBadge(
                  icon: Icons.verified, text: '100% Genuine Products'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Category chips + sort dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = cat == _selectedCategory;
                      final count = cat == 'All'
                          ? _allItems.length
                          : _allItems.where((i) => i.category == cat).length;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? HousepitalColors.orange
                        : HousepitalColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? HousepitalColors.orange
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '$cat ($count)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? HousepitalColors.white
                          : HousepitalColors.grey,
                    ),
                  ),
                ),
              );
            },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sort dropdown
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: (v) => setState(() => _sortBy = v),
                itemBuilder: (_) => _sortOptions
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              if (s == _sortBy)
                                const Icon(Icons.check, size: 16, color: HousepitalColors.orange)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 8),
                              Text(s, style: TextStyle(
                                fontSize: 13,
                                fontWeight: s == _sortBy ? FontWeight.w600 : FontWeight.w400,
                                color: s == _sortBy ? HousepitalColors.orange : HousepitalColors.black,
                              )),
                            ],
                          ),
                        ))
                    .toList(),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: HousepitalColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 16, color: HousepitalColors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _sortBy == 'Relevance' ? 'Sort' : _sortBy.split(':').first.trim(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HousepitalColors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${filtered.length} items',
                style: const TextStyle(
                  fontSize: 13,
                  color: HousepitalColors.greyLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Grid
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _EquipmentItemCard(
                      item: item,
                      icon: _iconForCategory(item.category),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EquipmentItemCard extends StatelessWidget {
  final EquipmentItem item;
  final IconData icon;

  const _EquipmentItemCard({required this.item, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HousepitalColors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: () => _showItemDetail(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder / icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: HousepitalColors.orangeLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: item.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => Icon(icon,
                                color: HousepitalColors.orange, size: 32),
                            errorWidget: (_, __, ___) => Icon(icon,
                                color: HousepitalColors.orange, size: 32),
                          ),
                        )
                      : Icon(icon,
                          color: HousepitalColors.orange, size: 32),
                ),
              ),
              const SizedBox(height: 8),
              // Name
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              // Brand
              Text(
                item.brand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: HousepitalColors.greyLight,
                ),
              ),
              const Spacer(),
              // Price
              if (item.price != null)
                Text(
                  DateHelper.formatCurrency(item.price!.toInt()),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: HousepitalColors.orangeText,
                  ),
                )
              else
                const Text(
                  'Price on request',
                  style: TextStyle(
                    fontSize: 11,
                    color: HousepitalColors.greyLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 4),
              // Category badges
              Row(
                children: [
                  if (item.availableForRent) ...[
                    _typeBadge('Rent', HousepitalColors.infoLight,
                        HousepitalColors.info),
                    const SizedBox(width: 4),
                  ],
                  if (item.availableForSale)
                    _typeBadge('Buy', HousepitalColors.successLight,
                        HousepitalColors.success),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  void _showItemDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EquipmentDetailSheet(item: item, icon: icon),
    );
  }
}

class _EquipmentDetailSheet extends StatefulWidget {
  final EquipmentItem item;
  final IconData icon;
  const _EquipmentDetailSheet({required this.item, required this.icon});

  @override
  State<_EquipmentDetailSheet> createState() => _EquipmentDetailSheetState();
}

class _EquipmentDetailSheetState extends State<_EquipmentDetailSheet> {
  bool _isRental = false; // false = Buy, true = Rent
  int _rentalMonths = 1; // default rental duration (min 15 days = 1 month)

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final icon = widget.icon;
    final hasRental = item.availableForRent;
    final breakeven = item.breakevenDays;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: HousepitalColors.orangeLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: item.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Icon(icon,
                              color: HousepitalColors.orange, size: 28),
                        ),
                      )
                    : Icon(icon,
                        color: HousepitalColors.orange, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: HousepitalColors.black,
                      ),
                    ),
                    Text(
                      item.brand,
                      style: const TextStyle(
                        fontSize: 14,
                        color: HousepitalColors.greyLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.category == 'Equipment'
                      ? HousepitalColors.infoLight
                      : HousepitalColors.successLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.category == 'Equipment'
                        ? HousepitalColors.info
                        : HousepitalColors.success,
                  ),
                ),
              ),
            ],
          ),
          // Description (collapsible if long)
          if (item.description != null) ...[
            const SizedBox(height: 14),
            _CollapsibleText(text: item.description!),
          ],

          // Key Features (collapsible)
          if (item.keyFeatures != null) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Key Features',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HousepitalColors.black)),
              leading: const Icon(Icons.star_outline, size: 18, color: HousepitalColors.success),
              children: _splitCatalogText(item.keyFeatures!).map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: HousepitalColors.successLight,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(Icons.check, size: 12, color: HousepitalColors.success),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(f, style: const TextStyle(fontSize: 13, color: HousepitalColors.grey, height: 1.4)),
                        ),
                      ],
                    ),
                  )).toList(),
            ),
          ],

          // Ideal For (collapsible)
          if (item.idealFor != null) ...[
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Ideal For',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HousepitalColors.black)),
              leading: const Icon(Icons.check_circle_outline, size: 18, color: HousepitalColors.success),
              children: _splitCatalogText(item.idealFor!).map((use) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: HousepitalColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(use, style: const TextStyle(fontSize: 12, color: HousepitalColors.grey, height: 1.4)),
                        ),
                      ],
                    ),
                  )).toList(),
            ),
          ],

          // How to Use (expandable)
          if (item.howToUse != null) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('How to Use',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black)),
              leading: const Icon(Icons.help_outline,
                  size: 18, color: HousepitalColors.orange),
              children: _splitCatalogText(item.howToUse!).asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22, height: 22,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: HousepitalColors.orangeLight,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Center(child: Text('${entry.key + 1}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HousepitalColors.orangeText))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, color: HousepitalColors.grey, height: 1.4))),
                      ],
                    ),
                  )).toList(),
            ),
          ],

          // FAQs (expandable)
          if (item.faqs != null && item.faqs!.isNotEmpty) ...[
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('FAQs',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black)),
              leading: const Icon(Icons.question_answer_outlined,
                  size: 18, color: HousepitalColors.orange),
              children: _buildFaqItems(item.faqs!),
            ),
          ],

          // Variant info
          if (item.variantType != null && item.variantValue != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${item.variantType}: ',
                      style: const TextStyle(
                          fontSize: 12,
                          color: HousepitalColors.greyLight)),
                  Text(item.variantValue!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: HousepitalColors.black)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Rent / Buy toggle (only for Equipment with rental pricing)
          if (hasRental) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isRental = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isRental
                              ? HousepitalColors.orange
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Buy',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: !_isRental
                                  ? HousepitalColors.white
                                  : HousepitalColors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isRental = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isRental
                              ? HousepitalColors.orange
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Rent',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _isRental
                                  ? HousepitalColors.white
                                  : HousepitalColors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Price section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HousepitalColors.orangeLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isRental ? 'Rental (per month)' : 'Buy Price',
                      style: const TextStyle(
                        fontSize: 14,
                        color: HousepitalColors.grey,
                      ),
                    ),
                    Text(
                      _isRental
                          ? (item.rentalPrice != null
                              ? '${DateHelper.formatCurrency(item.rentalPrice!.toInt())}/month'
                              : 'On request')
                          : (item.price != null
                              ? DateHelper.formatCurrency(
                                  item.price!.toInt())
                              : 'On request'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: HousepitalColors.orangeText,
                      ),
                    ),
                  ],
                ),
                // Show the alternate price as comparison
                if (hasRental) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isRental ? 'Buy price' : 'Or rent at',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HousepitalColors.greyLight,
                        ),
                      ),
                      Text(
                        _isRental
                            ? DateHelper.formatCurrency(
                                item.price!.toInt())
                            : '${DateHelper.formatCurrency(item.rentalPrice!.toInt())}/month',
                        style: const TextStyle(
                          fontSize: 13,
                          color: HousepitalColors.greyLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Breakeven insight (only for Equipment with both prices)
          if (hasRental && breakeven != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HousepitalColors.infoLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HousepitalColors.infoLight),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: HousepitalColors.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: HousepitalColors.info,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: _isRental
                                ? 'After $breakeven days of renting, buying becomes cheaper. '
                                : 'Renting saves money if you need it for less than $breakeven days. ',
                          ),
                          TextSpan(
                            text: _isRental
                                ? 'Consider buying if needed long-term.'
                                : 'Consider renting for short-term use.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Rental months selector (only when renting)
          if (hasRental && _isRental) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Rental Duration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.black,
                  ),
                ),
                const Spacer(),
                _QuantityButton(
                  icon: Icons.remove,
                  onTap: () => setState(() {
                    if (_rentalMonths > 1) _rentalMonths--;
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$_rentalMonths ${_rentalMonths == 1 ? "month" : "months"}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: HousepitalColors.black,
                    ),
                  ),
                ),
                _QuantityButton(
                  icon: Icons.add,
                  onTap: () => setState(() => _rentalMonths++),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Total line
          if (_isRental && hasRental && item.rentalPrice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(
                    DateHelper.formatCurrency(
                        (item.rentalPrice! * _rentalMonths).toInt()),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: HousepitalColors.orangeText,
                    ),
                  ),
                ],
              ),
            ),

          // Ventilator/BiPAP/CPAP → assessment first; everything else → add to cart
          if (item.needsAssessment) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HousepitalColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: HousepitalColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This device requires a complimentary clinical assessment to determine the right settings and fit for the patient.',
                      style: TextStyle(fontSize: 12, color: HousepitalColors.info, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/assessment-request',
                      arguments: ServiceItem(
                        id: 'eq-${item.id}',
                        name: item.name,
                        category: 'equipment_assessment',
                        bookingType: 'assessment',
                        basePriceMin: (item.rentalPrice ?? item.price ?? 0).toInt(),
                        basePriceMax: (item.price ?? item.rentalPrice ?? 0).toInt(),
                        iconName: 'medical_services',
                      ));
                },
                icon: const Icon(Icons.assignment_outlined, size: 20),
                label: const Text('Request Complimentary Assessment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HousepitalColors.orange,
                  foregroundColor: HousepitalColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  final cart = Provider.of<CartProvider>(context, listen: false);
                  cart.addItem(item,
                      isRental: _isRental,
                      rentalMonths: _isRental ? _rentalMonths : 1);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('${item.name} added to cart'),
                        backgroundColor: HousepitalColors.success,
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'VIEW CART',
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.pushNamed(context, '/cart');
                          },
                        ),
                      ),
                    );
                },
                icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                label: Text(_isRental ? 'Add Rental to Cart' : 'Add to Cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HousepitalColors.orange,
                  foregroundColor: HousepitalColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// Splits catalog text by `|` or newline — catalog uses both formats.
List<String> _splitCatalogText(String text) {
  final sep = text.contains('|') ? '|' : '\n';
  return text.split(sep).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

/// Parses FAQ text into Q/A pairs.
/// Handles formats: "Q: ... | A: ... | Q: ..." or "Q: ... A: ... Q: ..."
List<Widget> _buildFaqItems(String faqs) {
  // Split by Q: to get each question block, handling both pipe and inline formats
  // First normalize: replace " | Q:" with "\nQ:" and " | A:" with "\nA:"
  var normalized = faqs
      .replaceAll(RegExp(r'\s*\|\s*Q:'), '\nQ:')
      .replaceAll(RegExp(r'\s*\|\s*A:'), '\nA:');
  // Also split inline "A: ... Q:" where there's no separator
  normalized = normalized.replaceAllMapped(
    RegExp(r'(A:.*?\.)\s+(Q:)'),
    (m) => '${m.group(1)}\n${m.group(2)}',
  );

  final lines = normalized.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final items = <Widget>[];
  String? currentQ;
  int qNumber = 0;

  for (final line in lines) {
    if (line.startsWith('Q:') || line.startsWith('Q.')) {
      currentQ = line.substring(2).trim();
    } else if ((line.startsWith('A:') || line.startsWith('A.')) && currentQ != null) {
      qNumber++;
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22, height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: HousepitalColors.orangeLight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(child: Text('$qNumber',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HousepitalColors.orangeText))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(currentQ, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HousepitalColors.black))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Text(line.substring(2).trim(), style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight, height: 1.4)),
            ),
          ],
        ),
      ));
      currentQ = null;
    }
  }
  if (items.isEmpty) {
    return [Text(faqs, style: const TextStyle(fontSize: 13, color: HousepitalColors.grey, height: 1.4))];
  }
  return items;
}

/// Collapsible text widget — shows 3 lines with "Read more" toggle.
class _CollapsibleText extends StatefulWidget {
  final String text;
  const _CollapsibleText({required this.text});

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.text.length > 150;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? null : TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: HousepitalColors.grey, height: 1.4),
        ),
        if (isLong) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Read less' : 'Read more',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HousepitalColors.orange),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CONSULTATIONS TAB — Doctor, Psychiatrist, Grief Counselling
// ═══════════════════════════════════════════════════════════════

class _ConsultationsTab extends StatelessWidget {
  final List<ServiceItem> services;
  final Map<String, IconData> iconMap;
  final String searchQuery;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final List<ServiceItem> Function(List<ServiceItem>) filterBySearch;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const _ConsultationsTab({
    required this.services,
    required this.iconMap,
    required this.searchQuery,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.filterBySearch,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = filterBySearch(services);

    if (filtered.isEmpty && searchQuery.isNotEmpty) {
      return Column(
        children: [
          _SearchBar(
            searchQuery: searchQuery,
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: onSearchChanged,
          ),
          const Expanded(child: _EmptyState()),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SearchBar(
          searchQuery: searchQuery,
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: onSearchChanged,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _TrustBadgeBar(
            badges: [
              _TrustBadge(
                  icon: Icons.verified_user,
                  text: 'Licensed Professionals'),
              _TrustBadge(
                  icon: Icons.home,
                  text: 'Home or Video Visit'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...filtered.map((s) => _ConsultationCard(
              service: s,
              iconMap: iconMap,
              onNavigate: onNavigate,
            )),
      ],
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  final ServiceItem service;
  final Map<String, IconData> iconMap;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const _ConsultationCard({
    required this.service,
    required this.iconMap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final icon = iconMap[service.iconName] ?? Icons.medical_services;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: HousepitalColors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: () => onNavigate(context, service),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: HousepitalColors.orangeLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon,
                      color: HousepitalColors.orange, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: HousepitalColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.description ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HousepitalColors.greyLight,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (service.basePriceMin != null)
                            Text(
                              'From ${DateHelper.formatCurrency(service.basePriceMin!)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: HousepitalColors.orangeText,
                              ),
                            ),
                          const Spacer(),
                          if (service.durationMinutes != null)
                            Row(
                              children: [
                                const Icon(Icons.schedule,
                                    size: 14,
                                    color: HousepitalColors.greyLight),
                                const SizedBox(width: 4),
                                Text(
                                  '${service.durationMinutes} min',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: HousepitalColors.greyLight,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    color: HousepitalColors.greyLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  DIAGNOSTICS TAB
// ═══════════════════════════════════════════════════════════════

class _DiagnosticsTab extends StatelessWidget {
  final List<ServiceItem> services;
  final Map<String, IconData> iconMap;
  final String searchQuery;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final List<ServiceItem> Function(List<ServiceItem>) filterBySearch;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const _DiagnosticsTab({
    required this.services,
    required this.iconMap,
    required this.searchQuery,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.filterBySearch,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = filterBySearch(services);

    if (filtered.isEmpty && searchQuery.isNotEmpty) {
      return Column(
        children: [
          _SearchBar(
            searchQuery: searchQuery,
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: onSearchChanged,
          ),
          const Expanded(child: _EmptyState()),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SearchBar(
          searchQuery: searchQuery,
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: onSearchChanged,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _TrustBadgeBar(
            badges: [
              _TrustBadge(
                  icon: Icons.workspace_premium,
                  text: 'NABL Accredited Labs'),
              _TrustBadge(icon: Icons.home, text: 'Home Collection'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...filtered.map((s) => _DiagnosticCard(
              service: s,
              iconMap: iconMap,
              onNavigate: onNavigate,
            )),
      ],
    );
  }
}

class _DiagnosticCard extends StatelessWidget {
  final ServiceItem service;
  final Map<String, IconData> iconMap;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const _DiagnosticCard({
    required this.service,
    required this.iconMap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Semantics(
        label:
            '${service.name}. ${service.basePriceMin != null ? DateHelper.formatCurrency(service.basePriceMin!) : ""}. Home collection available. Tap to book slot.',
        button: true,
        child: Material(
          color: HousepitalColors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 1,
          shadowColor: Colors.black12,
          child: InkWell(
            onTap: () => onNavigate(context, service),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: HousepitalColors.infoLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconMap[service.iconName] ??
                          Icons.miscellaneous_services,
                      color: HousepitalColors.info,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: HousepitalColors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: HousepitalColors.successLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Home Collection',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HousepitalColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (service.basePriceMin != null)
                          Text(
                            DateHelper.formatCurrency(
                                service.basePriceMin!),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HousepitalColors.orangeText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => onNavigate(context, service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HousepitalColors.orange,
                        foregroundColor: HousepitalColors.white,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Book Slot'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SLEEP THERAPY TAB
// ═══════════════════════════════════════════════════════════════

class _TherapyTab extends StatelessWidget {
  final List<ServiceItem> services;
  final Map<String, IconData> iconMap;
  final String searchQuery;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final List<ServiceItem> Function(List<ServiceItem>) filterBySearch;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const _TherapyTab({
    required this.services,
    required this.iconMap,
    required this.searchQuery,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.filterBySearch,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = filterBySearch(services);

    if (filtered.isEmpty && searchQuery.isNotEmpty) {
      return Column(
        children: [
          _SearchBar(
            searchQuery: searchQuery,
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: onSearchChanged,
          ),
          const Expanded(child: _EmptyState()),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SearchBar(
          searchQuery: searchQuery,
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: onSearchChanged,
        ),
        ...filtered.map((s) => _TherapyCard(
              service: s,
              iconMap: iconMap,
              onNavigate: onNavigate,
            )),
      ],
    );
  }
}

class _TherapyCard extends StatelessWidget {
  final ServiceItem service;
  final Map<String, IconData> iconMap;
  final void Function(BuildContext, ServiceItem) onNavigate;

  const _TherapyCard({
    required this.service,
    required this.iconMap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Semantics(
        label:
            '${service.name}. ${service.description ?? ""}. ${service.basePriceMin != null ? DateHelper.formatCurrency(service.basePriceMin!) : ""}. Tap to book.',
        button: true,
        child: Material(
          color: HousepitalColors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 1,
          shadowColor: Colors.black12,
          child: InkWell(
            onTap: () => onNavigate(context, service),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconMap[service.iconName] ??
                          Icons.miscellaneous_services,
                      color: const Color(0xFF3F51B5),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: HousepitalColors.black,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          service.description ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: HousepitalColors.greyLight,
                            height: 1.3,
                          ),
                        ),
                        if (service.durationMinutes != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.schedule,
                                  size: 14,
                                  color: HousepitalColors.greyLight),
                              const SizedBox(width: 4),
                              Text(
                                '${service.durationMinutes} minutes',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HousepitalColors.greyLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (service.basePriceMin != null)
                              Text(
                                DateHelper.formatCurrency(
                                    service.basePriceMin!),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: HousepitalColors.orangeText,
                                ),
                              ),
                            const Spacer(),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: () =>
                                    onNavigate(context, service),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      HousepitalColors.orange,
                                  foregroundColor:
                                      HousepitalColors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: const Text('Book Now'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  QUANTITY BUTTON — reusable +/- circle button
// ═══════════════════════════════════════════════════════════════

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: HousepitalColors.orangeLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: HousepitalColors.orange),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Packages Tab
// ─────────────────────────────────────────────────────────────────────────────

class _PackagesTab extends StatelessWidget {
  const _PackagesTab();

  static final _iconMap = <String, IconData>{
    'local_hospital': Icons.local_hospital,
    'medical_services': Icons.medical_services,
    'home': Icons.home,
    'healing': Icons.healing,
    'bedtime': Icons.bedtime,
    'child_care': Icons.child_care,
    'psychology': Icons.psychology,
    'elderly': Icons.elderly,
  };

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: carePackages.length,
      itemBuilder: (context, index) {
        final pkg = carePackages[index];
        final icon = _iconMap[pkg.icon] ?? Icons.local_hospital;
        final isDailyRate = pkg.pricePerDay != null && pkg.pricePerDay! > 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: HousepitalColors.white,
            borderRadius: BorderRadius.circular(14),
            elevation: 1,
            shadowColor: Colors.black12,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/package-detail', arguments: pkg),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: HousepitalColors.orangeLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: HousepitalColors.orange, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pkg.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: HousepitalColors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pkg.condition,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: HousepitalColors.greyLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: HousepitalColors.success,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pkg.discountPercent.toInt()}% OFF',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Price or item count
                    if (isDailyRate)
                      Row(
                        children: [
                          Text(
                            '₹${pkg.pricePerDay!.toStringAsFixed(0)}/day',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HousepitalColors.orangeText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '· Min ${pkg.minDays} days',
                            style: const TextStyle(
                              fontSize: 13,
                              color: HousepitalColors.greyLight,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '${pkg.items.length} items + ${pkg.services.length} ${pkg.services.length == 1 ? "service" : "services"}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: HousepitalColors.orange,
                        ),
                      ),
                    const SizedBox(height: 10),
                    // Highlights chips (first 3)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: pkg.highlights.take(3).map((h) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: HousepitalColors.greyLighter,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          h,
                          style: const TextStyle(fontSize: 11, color: HousepitalColors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
                    // Arrow indicator
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.arrow_forward_ios, size: 14, color: HousepitalColors.greyLight),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
