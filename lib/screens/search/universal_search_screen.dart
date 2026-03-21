import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../data/care_packages.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../utils/helpers.dart';

/// Unified search result types.
enum SearchResultType { equipment, manpower, consultation, diagnostic, package }

class SearchResult {
  final SearchResultType type;
  final String name;
  final String subtitle;
  final String? price;
  final IconData icon;
  final Color iconColor;
  final dynamic data; // EquipmentItem, ServiceItem, or CarePackage

  SearchResult({
    required this.type,
    required this.name,
    required this.subtitle,
    this.price,
    required this.icon,
    required this.iconColor,
    this.data,
  });
}

class UniversalSearchScreen extends StatefulWidget {
  const UniversalSearchScreen({super.key});

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  List<EquipmentItem> _equipment = [];
  bool _loaded = false;

  // Service data — mirrors ServiceCatalogScreen's static lists (HPL Tariff Annexure)
  // No prices for caretaker/nursing/japa/nanny — assessment first
  static final _manpowerServices = [
    // Nursing (no prices — assessment first)
    _svc('Nurse (Basic) – 12 Hours', 'manpower', 'medical_services', 0, 0),
    _svc('Nurse (Basic) – 24 Hours', 'manpower', 'medical_services', 0, 0),
    _svc('Nurse (Advanced) – 12 Hours', 'manpower', 'medical_services', 0, 0),
    _svc('Nurse (Advanced) – 24 Hours', 'manpower', 'medical_services', 0, 0),
    _svc('Nurse (Critical) – 12 Hours', 'manpower', 'medical_services', 0, 0),
    _svc('Nurse (Critical) – 24 Hours', 'manpower', 'medical_services', 0, 0),
    // Care-takers (no prices — assessment first)
    _svc('Caretaker (Basic) – 12 Hours', 'manpower', 'person', 0, 0),
    _svc('Caretaker (Basic) – 24 Hours', 'manpower', 'person', 0, 0),
    _svc('Caretaker (Advanced) – 12 Hours', 'manpower', 'person', 0, 0),
    _svc('Caretaker (Advanced) – 24 Hours', 'manpower', 'person', 0, 0),
    _svc('Caretaker (Critical / Semi-Nurse) – 12 Hours', 'manpower', 'person', 0, 0),
    _svc('Caretaker (Critical / Semi-Nurse) – 24 Hours', 'manpower', 'person', 0, 0),
    // Japa & Nanny (no prices — assessment first)
    _svc('Japa Maid – 24 Hours', 'manpower', 'child_friendly', 0, 0),
    _svc('Nanny – 12 Hours', 'manpower', 'child_care', 0, 0),
    // Physiotherapy (prices shown — per-session visit)
    _svc('Physiotherapy (Basic)', 'manpower', 'fitness_center', 900, 900),
    _svc('Physiotherapy (Advanced)', 'manpower', 'fitness_center', 1200, 1200),
    _svc('Physiotherapy (Critical)', 'manpower', 'fitness_center', 1500, 1500),
  ];

  static final _consultationServices = [
    // Doctor visits
    _svc('Doctor Visit – General Physician', 'consultation', 'stethoscope', 3500, 3500),
    _svc('Doctor Visit – ICU Specialist', 'consultation', 'stethoscope', 5000, 5000),
    _svc('Psychiatrist Consultation', 'consultation', 'psychology', 1500, 1500),
    _svc('Grief Counselling', 'consultation', 'favorite', 1200, 1200),
    // IV Visits
    _svc('IV Visit (Basic)', 'consultation', 'medical_services', 900, 900),
    _svc('IV Visit (Advanced)', 'consultation', 'medical_services', 1200, 1200),
    _svc('IV Visit (Critical)', 'consultation', 'medical_services', 1500, 1500),
    // IM Visit
    _svc('IM Injection Visit', 'consultation', 'medical_services', 500, 500),
    // Dressing
    _svc('Dressing Visit (Basic)', 'consultation', 'medical_services', 1200, 1200),
    _svc('Dressing Visit (Advanced)', 'consultation', 'medical_services', 1500, 1500),
    _svc('Dressing Visit (Critical)', 'consultation', 'medical_services', 2000, 2000),
    // Specialized
    _svc('Catheter Change', 'consultation', 'medical_services', 1200, 1200),
    _svc('RT (Ryles Tube) Change', 'consultation', 'medical_services', 1200, 1200),
    _svc('Tracheostomy Change', 'consultation', 'medical_services', 5000, 5000),
  ];

  static final _diagnosticServices = [
    // Lab panels
    _svc('Fever Panel', 'diagnostic', 'science', 4999, 4999),
    _svc('Wellness Package', 'diagnostic', 'science', 7599, 7599),
    _svc('Immunity Package', 'diagnostic', 'science', 4599, 4599),
    _svc('Bone Package', 'diagnostic', 'science', 2999, 2999),
    _svc('Metabolic Package', 'diagnostic', 'science', 1799, 1799),
    _svc('Adolescent Package', 'diagnostic', 'science', 2499, 2499),
    _svc('Anemia Package', 'diagnostic', 'science', 4599, 4599),
    // Diagnostics
    _svc('ECG at Home', 'diagnostic', 'science', 500, 500),
    _svc('X-Ray at Home', 'diagnostic', 'science', 800, 800),
    _svc('Holter Monitoring', 'diagnostic', 'science', 2500, 2500),
    // Sample collection
    _svc('Blood Sample Collection (0-5 km)', 'diagnostic', 'science', 150, 150),
    _svc('Blood Sample Collection (5-10 km)', 'diagnostic', 'science', 200, 200),
  ];

  static ServiceItem _svc(String name, String cat, String icon, int min, int max) {
    return ServiceItem(
      id: name.toLowerCase().replaceAll(' ', '-'),
      name: name,
      category: cat,
      bookingType: cat == 'consultation' ? 'instant' : 'assessment',
      basePriceMin: min,
      basePriceMax: max,
      iconName: icon,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadEquipment();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEquipment() async {
    try {
      _equipment = await ApiService().getEquipmentCatalog();
    } catch (_) {
      try {
        final jsonStr =
            await rootBundle.loadString('assets/equipment_catalog.json');
        final List<dynamic> list = json.decode(jsonStr);
        _equipment = list.map((e) => EquipmentItem.fromJson(e)).toList();
      } catch (_) {}
    }
    if (mounted) setState(() => _loaded = true);
  }

  List<SearchResult> get _results {
    if (_query.length < 2) return [];
    final q = _query.toLowerCase();
    final results = <SearchResult>[];

    // Search equipment/consumables
    for (final item in _equipment) {
      if (item.name.toLowerCase().contains(q) ||
          item.brand.toLowerCase().contains(q) ||
          (item.description?.toLowerCase().contains(q) ?? false)) {
        results.add(SearchResult(
          type: SearchResultType.equipment,
          name: item.name,
          subtitle: '${item.brand} · ${item.category}',
          price: item.price != null
              ? DateHelper.formatCurrency(item.price!.toInt())
              : null,
          icon: item.category == 'Equipment'
              ? Icons.medical_services
              : Icons.inventory_2,
          iconColor: item.category == 'Equipment'
              ? Colors.blue.shade700
              : HousepitalColors.success,
          data: item,
        ));
      }
    }

    // Search manpower services
    for (final svc in _manpowerServices) {
      if (svc.name.toLowerCase().contains(q) ||
          (svc.description?.toLowerCase().contains(q) ?? false)) {
        results.add(SearchResult(
          type: SearchResultType.manpower,
          name: svc.name,
          subtitle: 'Manpower Service',
          price: (svc.basePriceMin != null && svc.basePriceMin! > 0)
              ? '${DateHelper.formatCurrency(svc.basePriceMin!)}/session'
              : null,
          icon: Icons.person,
          iconColor: HousepitalColors.orange,
          data: svc,
        ));
      }
    }

    // Search consultations
    for (final svc in _consultationServices) {
      if (svc.name.toLowerCase().contains(q)) {
        results.add(SearchResult(
          type: SearchResultType.consultation,
          name: svc.name,
          subtitle: 'Consultation',
          price: svc.basePriceMin != null
              ? DateHelper.formatCurrency(svc.basePriceMin!)
              : null,
          icon: Icons.medical_information,
          iconColor: Colors.teal,
          data: svc,
        ));
      }
    }

    // Search diagnostics
    for (final svc in _diagnosticServices) {
      if (svc.name.toLowerCase().contains(q)) {
        results.add(SearchResult(
          type: SearchResultType.diagnostic,
          name: svc.name,
          subtitle: 'Lab Test',
          price: svc.basePriceMin != null
              ? DateHelper.formatCurrency(svc.basePriceMin!)
              : null,
          icon: Icons.science,
          iconColor: Colors.purple,
          data: svc,
        ));
      }
    }

    // Search care packages
    for (final pkg in carePackages) {
      if (pkg.name.toLowerCase().contains(q) ||
          pkg.condition.toLowerCase().contains(q) ||
          pkg.description.toLowerCase().contains(q)) {
        results.add(SearchResult(
          type: SearchResultType.package,
          name: pkg.name,
          subtitle: '${pkg.condition} · ${pkg.discountPercent.toInt()}% OFF',
          price: null,
          icon: Icons.card_giftcard,
          iconColor: HousepitalColors.success,
          data: pkg,
        ));
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    // Group results by type
    final grouped = <SearchResultType, List<SearchResult>>{};
    for (final r in results) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search services, equipment, packages...',
            hintStyle: const TextStyle(
                fontSize: 15, color: HousepitalColors.greyLight),
            border: InputBorder.none,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: _query.length < 2
          ? _buildSuggestions()
          : results.isEmpty
              ? _buildNoResults()
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: grouped.entries.expand((entry) {
                    return [
                      _sectionHeader(entry.key, entry.value.length),
                      ...entry.value.map((r) => _buildResultTile(r)),
                    ];
                  }).toList(),
                ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      _Suggestion('CPAP Machine', Icons.bedtime),
      _Suggestion('Nurse', Icons.local_hospital),
      _Suggestion('Wheelchair', Icons.accessible),
      _Suggestion('Blood Test', Icons.science),
      _Suggestion('Baby Care', Icons.child_care),
      _Suggestion('Walker', Icons.directions_walk),
      _Suggestion('BP Monitor', Icons.monitor_heart),
      _Suggestion('Physiotherapist', Icons.fitness_center),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Popular Searches',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.black)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map((s) => ActionChip(
                      avatar: Icon(s.icon, size: 16, color: HousepitalColors.orange),
                      label: Text(s.text,
                          style: const TextStyle(fontSize: 13)),
                      onPressed: () {
                        _controller.text = s.text;
                        setState(() => _query = s.text);
                      },
                      backgroundColor: HousepitalColors.orangeLight,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 28),
          // Recent searches placeholder
          const Text('Quick Links',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.black)),
          const SizedBox(height: 12),
          _quickLink(Icons.card_giftcard, 'Care Packages',
              'Bundled kits for specific conditions', () {
            Navigator.pop(context);
            // Could navigate to packages tab
          }),
          _quickLink(Icons.medical_services, 'Equipment Catalog',
              '477 items — rent or buy', () {
            Navigator.pop(context);
          }),
          _quickLink(Icons.credit_card, 'Auto-pay Setup',
              'Set up automatic payments', () {
            Navigator.pushReplacementNamed(context, '/payment-methods');
          }),
        ],
      ),
    );
  }

  Widget _quickLink(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: HousepitalColors.orangeLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: HousepitalColors.orange, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 12, color: HousepitalColors.greyLight)),
      trailing: const Icon(Icons.chevron_right,
          size: 18, color: HousepitalColors.greyLight),
      onTap: onTap,
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text('No results for "$_query"',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Try a different search term',
              style: TextStyle(
                  fontSize: 13, color: HousepitalColors.greyLight)),
        ],
      ),
    );
  }

  Widget _sectionHeader(SearchResultType type, int count) {
    final labels = {
      SearchResultType.equipment: 'Equipment & Consumables',
      SearchResultType.manpower: 'Manpower Services',
      SearchResultType.consultation: 'Consultations',
      SearchResultType.diagnostic: 'Lab Tests',
      SearchResultType.package: 'Care Packages',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            labels[type] ?? '',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HousepitalColors.grey),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: HousepitalColors.orangeLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(SearchResult r) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: r.iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: r.type == SearchResultType.equipment &&
                (r.data as EquipmentItem).imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: (r.data as EquipmentItem).imageUrl!,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) =>
                      Icon(r.icon, color: r.iconColor, size: 20),
                ),
              )
            : Icon(r.icon, color: r.iconColor, size: 20),
      ),
      title: Text(r.name,
          style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(r.subtitle,
          style: const TextStyle(
              fontSize: 12, color: HousepitalColors.greyLight)),
      trailing: r.price != null
          ? Text(r.price!,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.orangeText))
          : r.type == SearchResultType.package
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: HousepitalColors.success,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(r.data as CarePackage).discountPercent.toInt()}% OFF',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                )
              : null,
      onTap: () => _handleTap(r),
    );
  }

  void _handleTap(SearchResult r) {
    switch (r.type) {
      case SearchResultType.equipment:
        // Show equipment detail bottom sheet
        final item = r.data as EquipmentItem;
        Navigator.pop(context, {'type': 'equipment', 'item': item});
        break;
      case SearchResultType.manpower:
        // Manpower services always require assessment first
        final svc = r.data as ServiceItem;
        Navigator.pushNamed(context, '/assessment-request', arguments: svc);
        break;
      case SearchResultType.consultation:
        final svc = r.data as ServiceItem;
        Navigator.pushNamed(context, '/service-booking', arguments: svc);
        break;
      case SearchResultType.diagnostic:
        final svc = r.data as ServiceItem;
        Navigator.pushNamed(context, '/service-booking', arguments: svc);
        break;
      case SearchResultType.package:
        final pkg = r.data as CarePackage;
        Navigator.pushNamed(context, '/package-detail', arguments: pkg);
        break;
    }
  }
}

class _Suggestion {
  final String text;
  final IconData icon;
  const _Suggestion(this.text, this.icon);
}
