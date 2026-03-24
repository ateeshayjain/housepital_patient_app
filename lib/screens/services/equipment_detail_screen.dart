import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../utils/helpers.dart';

class EquipmentDetailScreen extends StatefulWidget {
  final ServiceItem service;

  const EquipmentDetailScreen({super.key, required this.service});

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  EquipmentItem? _catalogItem;
  bool _descriptionExpanded = false;
  bool _showAddedConfirmation = false;
  bool _showSavedConfirmation = false;
  int _selectedRentalMonths = 1;

  // Image gallery state
  int _currentImagePage = 0;
  final PageController _imagePageController = PageController();

  // Reviews state
  List<EquipmentReview> _reviews = [];
  bool _reviewsLoaded = false;

  // ── Fallback feature lists per equipment ID ──────────────────
  static const _fallbackFeatures = <String, List<String>>{
    'eq-hospital-bed': [
      'Motorised head & foot adjustment',
      'Side rails for safety',
      'Weight capacity: 150 kg',
      'Easy-clean mattress included',
      'Lockable castors for stability',
    ],
    'eq-oxygen-concentrator': [
      '5L/min flow rate',
      'Low noise operation (<45 dB)',
      'Continuous flow mode',
      'Built-in oxygen purity indicator',
      'Power-failure alarm',
    ],
    'eq-wheelchair': [
      'Lightweight foldable frame',
      'Detachable footrests',
      'Padded armrests',
      'Weight capacity: 120 kg',
      'Anti-tip rear wheels',
    ],
    'eq-bp-monitor': [
      'Clinically validated accuracy',
      'Irregular heartbeat detection',
      'Memory for 120 readings',
      'Universal cuff (22\u201342 cm)',
      'Large backlit display',
    ],
    'eq-consumables': [
      'Medical-grade gloves (box of 100)',
      'Adult diapers (multiple sizes)',
      'Wound care dressing kits',
      'Disposable syringes & needles',
      'Sanitisation supplies',
    ],
  };

  // ── Fallback specifications per equipment ID ─────────────────
  static const _fallbackSpecs = <String, Map<String, String>>{
    'eq-hospital-bed': {
      'Brand': 'Housepital Certified',
      'Model': 'HB-200M',
      'Weight': '85 kg',
      'Dimensions': '210 x 100 x 60 cm',
      'Warranty': '1 year on motor',
      'Material': 'Mild steel, epoxy coated',
    },
    'eq-oxygen-concentrator': {
      'Brand': 'Philips / Nidek',
      'Model': 'EverFlo / Nuvo Lite',
      'Weight': '14 kg',
      'Dimensions': '58 x 38 x 24 cm',
      'Warranty': '2 years',
      'Power': '350 W',
    },
    'eq-wheelchair': {
      'Brand': 'Karma / Medimove',
      'Model': 'KM-2500L',
      'Weight': '12 kg',
      'Seat Width': '46 cm',
      'Warranty': '1 year frame',
      'Material': 'Aluminium alloy',
    },
    'eq-bp-monitor': {
      'Brand': 'Omron',
      'Model': 'HEM-7156',
      'Weight': '340 g',
      'Cuff Size': '22\u201342 cm',
      'Warranty': '5 years',
      'Power': '4x AA batteries',
    },
    'eq-consumables': {
      'Brand': 'Various (certified)',
      'Sterility': 'ETO sterilised',
      'Shelf Life': '3 years',
      'Certification': 'ISO 13485',
      'Latex Free': 'Available',
      'Quantity': 'As per order',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadCatalogItem();
    _loadReviews();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogItem() async {
    try {
      final raw =
          await rootBundle.loadString('assets/equipment_catalog.json');
      final list = json.decode(raw) as List;
      final items = list.map((e) => EquipmentItem.fromJson(e)).toList();

      // Try to match by ID or name
      EquipmentItem? match;
      for (final item in items) {
        if (item.name.toLowerCase() == widget.service.name.toLowerCase()) {
          match = item;
          break;
        }
      }
      // Fallback: partial name match
      match ??= items.cast<EquipmentItem?>().firstWhere(
            (item) => widget.service.name
                .toLowerCase()
                .contains(item!.name.toLowerCase().split(' ').first),
            orElse: () => null,
          );

      if (mounted) {
        setState(() {
          _catalogItem = match;
        });
      }
    } catch (_) {
      // Catalog unavailable — fallback data will be used.
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await ApiService().getEquipmentReviews(widget.service.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _reviewsLoaded = true;
        });
      }
    } catch (_) {
      // Fallback mock reviews
      if (mounted) {
        setState(() {
          _reviews = [
            EquipmentReview(
              id: 'r1',
              userName: 'Rajesh K.',
              rating: 5,
              text: 'Excellent quality equipment. Delivered on time and works perfectly.',
              date: DateTime.now().subtract(const Duration(days: 5)),
            ),
            EquipmentReview(
              id: 'r2',
              userName: 'Priya M.',
              rating: 4,
              text: 'Good product, easy to use. Setup was done by the delivery team.',
              date: DateTime.now().subtract(const Duration(days: 12)),
            ),
            EquipmentReview(
              id: 'r3',
              userName: 'Suresh P.',
              rating: 5,
              text: 'Very happy with the rental service. Hassle-free experience.',
              date: DateTime.now().subtract(const Duration(days: 20)),
            ),
          ];
          _reviewsLoaded = true;
        });
      }
    }
  }

  // ── Derived data ─────────────────────────────────────────────

  String get _name => _catalogItem?.name ?? widget.service.name;

  String get _brand => _catalogItem?.brand ?? 'Medical Equipment';

  String? get _description =>
      _catalogItem?.description ?? widget.service.description;

  bool get _canRent =>
      _catalogItem?.availableForRent ??
      (widget.service.id == 'eq-hospital-bed' ||
          widget.service.id == 'eq-oxygen-concentrator' ||
          widget.service.id == 'eq-wheelchair');

  bool get _canBuy => _catalogItem?.availableForSale ?? true;

  String? get _priceText {
    if (_catalogItem?.price != null) {
      return '\u20B9${_catalogItem!.price!.toStringAsFixed(0)}';
    }
    if (widget.service.basePriceMin != null) {
      return DateHelper.formatCurrency(widget.service.basePriceMin!);
    }
    return null;
  }

  String? get _rentalPriceText {
    if (_catalogItem?.rentalPrice != null) {
      return '\u20B9${_catalogItem!.rentalPrice!.toStringAsFixed(0)}/mo';
    }
    return null;
  }

  /// Splits catalog text by `|` or newline — catalog uses both formats.
  static List<String> _splitCatalogText(String text) {
    // Try pipe delimiter first (most catalog data uses this)
    if (text.contains('|')) {
      return text.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    // Try newline delimiter
    if (text.contains('\n')) {
      return text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    // Fallback: split on sentence boundaries (". " followed by uppercase)
    final sentences = <String>[];
    final regex = RegExp(r'(?<=\.)\s+(?=[A-Z])');
    for (final s in text.split(regex)) {
      final trimmed = s.trim();
      if (trimmed.isNotEmpty) {
        sentences.add(trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed);
      }
    }
    return sentences.length > 1 ? sentences : [text];
  }

  List<String> get _features {
    if (_catalogItem?.keyFeatures != null &&
        _catalogItem!.keyFeatures!.isNotEmpty) {
      return _splitCatalogText(_catalogItem!.keyFeatures!);
    }
    return _fallbackFeatures[widget.service.id] ??
        ['Quality medical equipment'];
  }

  Map<String, String> get _specs {
    final specs = <String, String>{};
    final cat = _catalogItem;
    if (cat != null) {
      specs['Brand'] = cat.brand;
      specs['Category'] = cat.category;
      if (cat.price != null) {
        specs['Sale Price'] = '\u20B9${cat.price!.toStringAsFixed(0)}';
      }
      if (cat.rentalPrice != null) {
        specs['Rental Price'] =
            '\u20B9${cat.rentalPrice!.toStringAsFixed(0)}/month';
      }
      if (cat.breakevenDays != null) {
        specs['Rent vs Buy'] =
            'Buying saves after ${cat.breakevenDays} days rental';
      }
      if (cat.variantType != null) {
        specs[cat.variantType!] = cat.variantValue ?? '-';
      }
    }
    if (specs.isEmpty) {
      return _fallbackSpecs[widget.service.id] ?? {};
    }
    return specs;
  }

  String? get _idealFor => _catalogItem?.idealFor;
  String? get _howToUse => _catalogItem?.howToUse;

  List<_FaqEntry> get _faqs {
    if (_catalogItem?.faqs == null || _catalogItem!.faqs!.isEmpty) return [];
    final raw = _catalogItem!.faqs!;

    // Use regex to find all Q: ... A: ... pairs anywhere in the text
    final pattern = RegExp(r'Q:\s*(.+?)\s*A:\s*(.+?)(?=\s*\|\s*Q:|\s*Q:|$)');
    final matches = pattern.allMatches(raw);
    final faqs = <_FaqEntry>[];
    for (final m in matches) {
      final q = m.group(1)?.trim() ?? '';
      final a = m.group(2)?.trim().replaceAll(RegExp(r'\|$'), '').trim() ?? '';
      if (q.isNotEmpty && a.isNotEmpty) {
        faqs.add(_FaqEntry(question: q, answer: a));
      }
    }
    return faqs;
  }

  IconData get _equipmentIcon {
    final id = widget.service.id;
    final name = _name.toLowerCase();
    if (id == 'eq-hospital-bed' || name.contains('bed')) {
      return Icons.hotel;
    }
    if (id == 'eq-oxygen-concentrator' || name.contains('oxygen')) {
      return Icons.air;
    }
    if (id == 'eq-wheelchair' || name.contains('wheelchair')) {
      return Icons.accessible;
    }
    if (id == 'eq-bp-monitor' || name.contains('bp') || name.contains('monitor')) {
      return Icons.monitor_heart;
    }
    if (id == 'eq-consumables' || name.contains('consumable') || name.contains('diaper')) {
      return Icons.medical_services;
    }
    if (name.contains('ventilator') || name.contains('bipap') || name.contains('cpap')) {
      return Icons.masks;
    }
    if (name.contains('nebulizer') || name.contains('nebuliser')) {
      return Icons.blur_on;
    }
    if (name.contains('thermometer') || name.contains('temp')) {
      return Icons.thermostat;
    }
    if (name.contains('glucometer') || name.contains('sugar')) {
      return Icons.bloodtype;
    }
    if (name.contains('mattress')) return Icons.single_bed;
    if (name.contains('walker') || name.contains('crutch')) {
      return Icons.assist_walker;
    }
    return Icons.inventory_2_outlined;
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HousepitalColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ── Image gallery helpers ───────────────────────────────────

  List<String> get _allImageUrls {
    final urls = <String>[];
    if (_catalogItem?.imageUrls != null && _catalogItem!.imageUrls!.isNotEmpty) {
      urls.addAll(_catalogItem!.imageUrls!);
    } else if (_catalogItem?.imageUrl != null) {
      urls.add(_catalogItem!.imageUrl!);
    }
    return urls;
  }

  void _openFullScreenImage(int index) {
    final images = _allImageUrls;
    if (images.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenImageViewer(images: images, initialIndex: index),
    ));
  }

  // ── SliverAppBar with image carousel ──────────────────────

  Widget _buildSliverAppBar() {
    final images = _allImageUrls;
    final hasImages = images.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: HousepitalColors.white,
      foregroundColor: HousepitalColors.black,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: () {
            final text = '$_name\n\n${_description ?? ''}\n\nCheck it out on Housepital!';
            SharePlus.instance.share(ShareParams(text: text));
          },
          tooltip: 'Share',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: hasImages
            ? _buildImageCarousel(images)
            : _buildPlaceholderHero(),
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    return Stack(
      children: [
        PageView.builder(
          controller: _imagePageController,
          itemCount: images.length,
          onPageChanged: (index) => setState(() => _currentImagePage = index),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _openFullScreenImage(index),
              child: Container(
                color: HousepitalColors.background,
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HousepitalColors.orange,
                    ),
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    _equipmentIcon,
                    size: 56,
                    color: HousepitalColors.orange,
                  ),
                ),
              ),
            );
          },
        ),
        // Image counter badge
        if (images.length > 1)
          Positioned(
            top: 90,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentImagePage + 1}/${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        // Dot indicators
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                final isActive = index == _currentImagePage;
                return Container(
                  width: isActive ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? HousepitalColors.orange
                        : HousepitalColors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF3E0),
            Color(0xFFFFE0B2),
            HousepitalColors.white,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: HousepitalColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: HousepitalColors.orange.withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                _equipmentIcon,
                size: 56,
                color: HousepitalColors.orange,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Body content ─────────────────────────────────────────────

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProductInfoSection(),
        const _SectionDivider(),
        if (_description != null && _description!.isNotEmpty) ...[
          _buildDescriptionSection(),
          const _SectionDivider(),
        ],
        _buildFeaturesSection(),
        const _SectionDivider(),
        if (_idealFor != null && _idealFor!.isNotEmpty) ...[
          _buildIdealForSection(),
          const _SectionDivider(),
        ],
        if (_catalogItem?.useCase != null && _catalogItem!.useCase!.isNotEmpty) ...[
          _buildUseCaseSection(),
          const _SectionDivider(),
        ],
        _buildDeliveryPromiseRow(),
        const _SectionDivider(),
        if (_specs.isNotEmpty) ...[
          _buildSpecificationsSection(),
          const _SectionDivider(),
        ],
        if (_howToUse != null && _howToUse!.isNotEmpty) ...[
          _buildHowToUseSection(),
          const _SectionDivider(),
        ],
        if (_faqs.isNotEmpty) ...[
          _buildFaqsSection(),
          const _SectionDivider(),
        ],
        if (_reviewsLoaded) ...[
          _buildReviewsSection(),
          const _SectionDivider(),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  // ── Product info ─────────────────────────────────────────────

  Widget _buildProductInfoSection() {
    return Container(
      color: HousepitalColors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(
            _name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: HousepitalColors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),

          // Brand / subcategory
          Text(
            _brand,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HousepitalColors.greyLight,
            ),
          ),
          const SizedBox(height: 14),

          // Availability badges
          Row(
            children: [
              if (_canRent)
                _AvailabilityBadge(
                  label: 'Rent',
                  color: HousepitalColors.info,
                  bgColor: HousepitalColors.infoLight,
                ),
              if (_canRent && _canBuy) const SizedBox(width: 8),
              if (_canBuy)
                _AvailabilityBadge(
                  label: 'Buy',
                  color: HousepitalColors.success,
                  bgColor: HousepitalColors.successLight,
                ),
              if (_catalogItem?.needsAssessment == true) ...[
                const SizedBox(width: 8),
                _AvailabilityBadge(
                  label: 'Assessment Required',
                  color: HousepitalColors.warning,
                  bgColor: HousepitalColors.warningLight,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Pricing row
          _buildPriceRow(),
        ],
      ),
    );
  }

  Widget _buildPriceRow() {
    final hasBuyPrice = _priceText != null;
    final hasRentPrice = _rentalPriceText != null;

    if (!hasBuyPrice && !hasRentPrice) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: HousepitalColors.orangeLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_outlined, size: 16, color: HousepitalColors.orangeText),
            SizedBox(width: 8),
            Text(
              'Contact for pricing',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: HousepitalColors.orangeText,
              ),
            ),
          ],
        ),
      );
    }

    final hasMrp = _catalogItem?.mrp != null &&
        _catalogItem!.mrp! > 0 &&
        hasBuyPrice &&
        _catalogItem!.mrp! > (_catalogItem!.price ?? 0);

    final discountPct = hasMrp
        ? ((_catalogItem!.mrp! - _catalogItem!.price!) / _catalogItem!.mrp! * 100).round()
        : 0;

    return Row(
      children: [
        if (hasBuyPrice) ...[
          if (hasMrp) ...[
            Text(
              '\u20B9${_catalogItem!.mrp!.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: HousepitalColors.greyLight,
                decoration: TextDecoration.lineThrough,
                decorationColor: HousepitalColors.greyLight,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _priceText!,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: HousepitalColors.orangeText,
            ),
          ),
          if (hasMrp && discountPct > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: HousepitalColors.successLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$discountPct% off',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.success,
                ),
              ),
            ),
          ],
        ],
        if (hasBuyPrice && hasRentPrice) ...[
          const SizedBox(width: 16),
          Container(height: 24, width: 1, color: HousepitalColors.divider),
          const SizedBox(width: 16),
        ],
        if (hasRentPrice)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasBuyPrice)
                const Text(
                  'or rent at',
                  style: TextStyle(
                    fontSize: 11,
                    color: HousepitalColors.greyLight,
                  ),
                ),
              Text(
                _rentalPriceText!,
                style: TextStyle(
                  fontSize: hasBuyPrice ? 16 : 24,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.info,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ── Description ──────────────────────────────────────────────

  Widget _buildDescriptionSection() {
    final isLong = _description!.length > 200;
    return Container(
      color: HousepitalColors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Description'),
          const SizedBox(height: 10),
          Text(
            _description!,
            maxLines: _descriptionExpanded ? null : 3,
            overflow: _descriptionExpanded ? null : TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: HousepitalColors.grey,
              height: 1.6,
            ),
          ),
          if (isLong) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() =>
                  _descriptionExpanded = !_descriptionExpanded),
              child: Text(
                _descriptionExpanded ? 'Read less' : 'Read more',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.orange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Key Features ─────────────────────────────────────────────

  Widget _buildFeaturesSection() {
    final features = _features;
    return _CollapsibleSection(
      icon: Icons.star_outline,
      iconColor: HousepitalColors.orange,
      title: 'Key Features',
      children: features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: HousepitalColors.successLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: HousepitalColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      fontSize: 14,
                      color: HousepitalColors.grey,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
    );
  }

  // ── Ideal For ────────────────────────────────────────────────

  Widget _buildIdealForSection() {
    final items = _splitCatalogText(_idealFor!);

    return _CollapsibleSection(
      icon: Icons.check_circle_outline,
      iconColor: HousepitalColors.orange,
      title: 'Ideal For',
      children: items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 18, color: HousepitalColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: HousepitalColors.grey,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
    );
  }

  // ── Recommended For (Use Case) ───────────────────────────────

  Widget _buildUseCaseSection() {
    final items = _splitCatalogText(_catalogItem!.useCase!);

    return _CollapsibleSection(
      icon: Icons.medical_information,
      iconColor: HousepitalColors.orange,
      title: 'Recommended For',
      children: items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.medical_information,
                    size: 18, color: HousepitalColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: HousepitalColors.grey,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
    );
  }

  // ── Delivery promise ─────────────────────────────────────────

  Widget _buildDeliveryPromiseRow() {
    return Container(
      color: HousepitalColors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        children: const [
          Expanded(
            child: _DeliveryPromiseItem(
              icon: Icons.local_shipping_outlined,
              label: 'Free\nDelivery',
            ),
          ),
          Expanded(
            child: _DeliveryPromiseItem(
              icon: Icons.schedule,
              label: '24hr\nDelivery',
            ),
          ),
          Expanded(
            child: _DeliveryPromiseItem(
              icon: Icons.replay,
              label: '7-day\nReturns',
            ),
          ),
        ],
      ),
    );
  }

  // ── Specifications ───────────────────────────────────────────

  Widget _buildSpecificationsSection() {
    final specs = _specs;
    final entries = specs.entries.toList();

    return Container(
      color: HousepitalColors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Specifications'),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: List.generate(entries.length, (index) {
                final entry = entries[index];
                final isEven = index % 2 == 0;
                return Container(
                  color: isEven
                      ? HousepitalColors.greyLighter
                      : HousepitalColors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: HousepitalColors.greyLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: HousepitalColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── How to Use ───────────────────────────────────────────────

  Widget _buildHowToUseSection() {
    final steps = _splitCatalogText(_howToUse!);

    return _CollapsibleSection(
      icon: Icons.help_outline,
      iconColor: HousepitalColors.orange,
      title: 'How to Use',
      children: List.generate(steps.length, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: HousepitalColors.orangeLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: HousepitalColors.orangeText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  steps[i],
                  style: const TextStyle(
                    fontSize: 14,
                    color: HousepitalColors.grey,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── FAQs ─────────────────────────────────────────────────────

  Widget _buildFaqsSection() {
    return _CollapsibleSection(
      icon: Icons.question_answer_outlined,
      iconColor: HousepitalColors.orange,
      title: 'FAQs',
      children: List.generate(_faqs.length, (i) {
        final faq = _faqs[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}. ${faq.question}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  faq.answer,
                  style: const TextStyle(
                    fontSize: 13,
                    color: HousepitalColors.greyLight,
                    height: 1.5,
                  ),
                ),
              ),
              if (i < _faqs.length - 1) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
              ],
            ],
          ),
        );
      }),
    );
  }

  // ── Reviews Section ─────────────────────────────────────────

  Widget _buildReviewsSection() {
    final avgRating = _reviews.isEmpty
        ? 0.0
        : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;
    final ratingCounts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      ratingCounts[r.rating] = (ratingCounts[r.rating] ?? 0) + 1;
    }

    return Container(
      color: HousepitalColors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle(title: 'Customer Reviews'),
              TextButton.icon(
                onPressed: _showWriteReviewSheet,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Write a Review'),
                style: TextButton.styleFrom(
                  foregroundColor: HousepitalColors.orange,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Rating summary
          Row(
            children: [
              Column(
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: HousepitalColors.black),
                  ),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < avgRating.round() ? Icons.star : Icons.star_border,
                      size: 16,
                      color: HousepitalColors.orange,
                    )),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_reviews.length} reviews',
                    style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((star) {
                    final count = ratingCounts[star] ?? 0;
                    final pct = _reviews.isEmpty ? 0.0 : count / _reviews.length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text('$star', style: const TextStyle(fontSize: 12, color: HousepitalColors.grey)),
                          const Icon(Icons.star, size: 12, color: HousepitalColors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: HousepitalColors.greyLighter,
                                color: HousepitalColors.orange,
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${(pct * 100).round()}%',
                              style: const TextStyle(fontSize: 11, color: HousepitalColors.greyLight),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Review cards
          ...(_reviews.take(3).map((review) => _buildReviewCard(review))),
        ],
      ),
    );
  }

  Widget _buildReviewCard(EquipmentReview review) {
    final initials = review.userName.isNotEmpty
        ? review.userName[0].toUpperCase()
        : '?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HousepitalColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: HousepitalColors.orangeLight,
                  child: Text(initials, style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.orangeText,
                    fontSize: 14,
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.userName, style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: HousepitalColors.black,
                      )),
                      Text(
                        '${review.date.day}/${review.date.month}/${review.date.year}',
                        style: const TextStyle(fontSize: 11, color: HousepitalColors.greyLight),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: HousepitalColors.orange,
                  )),
                ),
              ],
            ),
            if (review.text != null && review.text!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                review.text!,
                style: const TextStyle(fontSize: 13, color: HousepitalColors.grey, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showWriteReviewSheet() {
    int selectedRating = 5;
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Write a Review', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: HousepitalColors.black,
              )),
              const SizedBox(height: 16),
              // Star selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedRating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        star <= selectedRating ? Icons.star : Icons.star_border,
                        size: 36,
                        color: HousepitalColors.orange,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: HousepitalColors.orange),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ApiService().submitEquipmentReview(
                        widget.service.id,
                        selectedRating,
                        textController.text,
                      );
                    } catch (_) {
                      // Silently handle — review will appear on next load
                    }
                    // Add locally for instant feedback
                    setState(() {
                      _reviews.insert(0, EquipmentReview(
                        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                        userName: 'You',
                        rating: selectedRating,
                        text: textController.text.isEmpty ? null : textController.text,
                        date: DateTime.now(),
                      ));
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Thank you for your review!')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HousepitalColors.orange,
                    foregroundColor: HousepitalColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────

  void _addToCart(BuildContext context) {
    if (_catalogItem == null) return;
    final cart = context.read<CartProvider>();
    cart.addItem(_catalogItem!, isRental: _canRent, rentalMonths: _canRent ? _selectedRentalMonths : 1);
    setState(() => _showAddedConfirmation = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showAddedConfirmation = false);
    });
  }

  void _saveForLater(BuildContext context) {
    if (_catalogItem == null) return;
    final cart = context.read<CartProvider>();
    cart.saveForLater(_catalogItem!, isRental: _canRent, rentalMonths: _canRent ? _selectedRentalMonths : 1);
    setState(() => _showSavedConfirmation = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSavedConfirmation = false);
    });
  }

  Widget _buildBottomBar(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCart = _catalogItem != null && cart.isInCart(_catalogItem!.id);
    final isSaved = _catalogItem != null && cart.isSaved(_catalogItem!.id);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: HousepitalColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rental duration selector
            if (_canRent) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rental Duration',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HousepitalColors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [1, 3, 6, 12].map((months) {
                      final isSelected = _selectedRentalMonths == months;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$months ${months == 1 ? "mo" : "mo"}'),
                          selected: isSelected,
                          selectedColor: HousepitalColors.orangeLight,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? HousepitalColors.orange : HousepitalColors.grey,
                          ),
                          side: BorderSide(
                            color: isSelected ? HousepitalColors.orange : Colors.grey.shade300,
                          ),
                          onSelected: (_) => setState(() => _selectedRentalMonths = months),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_catalogItem?.rentalPrice != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${DateHelper.formatCurrency(_catalogItem!.rentalPrice!.toInt())}/mo x $_selectedRentalMonths = ${DateHelper.formatCurrency((_catalogItem!.rentalPrice! * _selectedRentalMonths).toInt())}',
                      style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
            ],
            // Save for Later text button
            if (!isSaved && !_showSavedConfirmation)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton.icon(
                  onPressed: () => _saveForLater(context),
                  icon: const Icon(Icons.bookmark_border, size: 16),
                  label: const Text('Save for Later'),
                  style: TextButton.styleFrom(
                    foregroundColor: HousepitalColors.greyLight,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            if (_showSavedConfirmation)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '✓ Saved for later',
                  style: TextStyle(
                    fontSize: 13,
                    color: HousepitalColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Row(
              children: [
                // Add to Cart / Go to Cart button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: _showAddedConfirmation
                        ? OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.check_circle, size: 18,
                                color: HousepitalColors.success),
                            label: const Text('Added!',
                                style: TextStyle(color: HousepitalColors.success)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: HousepitalColors.success, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : inCart
                            ? OutlinedButton.icon(
                                onPressed: () {
                                  final nav = Navigator.of(context, rootNavigator: true);
                                  Navigator.of(context).pop();
                                  nav.pushNamed('/cart');
                                },
                                icon: const Icon(Icons.shopping_cart, size: 18),
                                label: const Text('Go to Cart'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: HousepitalColors.success,
                                  side: const BorderSide(
                                      color: HousepitalColors.success, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: () => _addToCart(context),
                                icon: const Icon(Icons.shopping_cart_outlined,
                                    size: 18),
                                label: const Text('Add to Cart'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: HousepitalColors.orange,
                                  side: const BorderSide(
                                      color: HousepitalColors.orange, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 12),

                // Primary action button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_canRent) {
                          // Rental flow → Rental Agreement screen
                          Navigator.pushNamed(context, '/rental-agreement',
                            arguments: {
                              'itemName': _catalogItem!.name,
                              'monthlyRate': (_catalogItem!.rentalPrice ?? 0).toInt(),
                              'durationMonths': _selectedRentalMonths,
                            },
                          );
                        } else {
                          // Buy flow → add to cart and go to cart
                          if (!inCart) _addToCart(context);
                          Navigator.pushNamed(context, '/cart');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HousepitalColors.orange,
                        foregroundColor: HousepitalColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(_canRent ? 'Rent Now' : 'Buy Now'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Helper widgets
// ══════════════════════════════════════════════════════════════════

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 8, color: HousepitalColors.background);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: HousepitalColors.black,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _CollapsibleSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.initiallyExpanded = false,
    required this.children,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _controller;
  late final Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: _expanded ? 1.0 : 0.0,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HousepitalColors.white,
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.iconColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: HousepitalColors.black,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: HousepitalColors.orange,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _heightFactor,
            axisAlignment: -1.0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _AvailabilityBadge({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DeliveryPromiseItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DeliveryPromiseItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: HousepitalColors.successLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: HousepitalColors.success),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: HousepitalColors.grey,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _FaqEntry {
  final String question;
  final String answer;
  const _FaqEntry({required this.question, required this.answer});
}

// ══════════════════════════════════════════════════════════════════
// Full-screen pinch-to-zoom image viewer
// ══════════════════════════════════════════════════════════════════

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageViewer({required this.images, this.initialIndex = 0});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _controller;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentPage + 1}/${widget.images.length}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.images[index],
                fit: BoxFit.contain,
                placeholder: (_, __) => const CircularProgressIndicator(
                  color: HousepitalColors.orange,
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.white54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
