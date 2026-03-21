import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../utils/helpers.dart';

class EquipmentDetailScreen extends StatelessWidget {
  final ServiceItem service;

  const EquipmentDetailScreen({super.key, required this.service});

  // ── Feature lists per equipment ID ────────────────────────────
  static const _equipmentFeatures = <String, List<String>>{
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

  // ── Specifications per equipment ID ───────────────────────────
  static const _equipmentSpecs = <String, Map<String, String>>{
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

  // ── Mock reviews ──────────────────────────────────────────────
  static const _mockReviews = [
    _Review(
      name: 'Priya S.',
      rating: 5,
      date: '12 Mar 2026',
      comment:
          'Delivered within 6 hours! The equipment was well-maintained and the delivery person explained everything clearly.',
    ),
    _Review(
      name: 'Rajesh K.',
      rating: 4,
      date: '28 Feb 2026',
      comment:
          'Good quality product. Setup was easy. Only giving 4 stars because the delivery took a bit longer than promised.',
    ),
    _Review(
      name: 'Anita M.',
      rating: 5,
      date: '15 Feb 2026',
      comment:
          'Excellent service by Housepital. The equipment is genuine and works perfectly. Highly recommended for home care.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final features =
        _equipmentFeatures[service.id] ?? ['Quality medical equipment'];
    final specs = _equipmentSpecs[service.id] ?? {};
    final priceText = service.basePriceMin != null
        ? DateHelper.formatCurrency(service.basePriceMin!)
        : 'Contact for price';
    final isRental = service.id == 'eq-hospital-bed' ||
        service.id == 'eq-oxygen-concentrator' ||
        service.id == 'eq-wheelchair';

    return Scaffold(
      appBar: AppBar(
        title: Text(service.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
            tooltip: 'Share',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero image section
                  _buildHeroSection(),

                  // 2. Product info section
                  _buildProductInfoSection(priceText, isRental),

                  const Divider(
                      height: 1, color: HousepitalColors.divider),

                  // 3. Key features
                  _buildFeaturesSection(features),

                  const Divider(
                      height: 1, color: HousepitalColors.divider),

                  // 4. Delivery info card
                  _buildDeliveryInfoCard(),

                  const Divider(
                      height: 1, color: HousepitalColors.divider),

                  // 5. Specifications table
                  if (specs.isNotEmpty) ...[
                    _buildSpecificationsSection(specs),
                    const Divider(
                        height: 1, color: HousepitalColors.divider),
                  ],

                  // 6. Reviews section
                  _buildReviewsSection(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // 7. Bottom sticky bar
          _buildBottomBar(context, priceText),
        ],
      ),
    );
  }

  // ── 1. Hero image ─────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Container(
      height: 280,
      color: HousepitalColors.orangeLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2,
              size: 80,
              color: HousepitalColors.orange,
            ),
            const SizedBox(height: 12),
            Text(
              service.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: HousepitalColors.greyLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Product info ───────────────────────────────────────────

  Widget _buildProductInfoSection(String priceText, bool isRental) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: HousepitalColors.black,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Medical Equipment',
            style: TextStyle(
              fontSize: 14,
              color: HousepitalColors.greyLight,
            ),
          ),
          const SizedBox(height: 10),

          // Star rating row
          Row(
            children: [
              ...List.generate(
                  4,
                  (_) => const Icon(Icons.star,
                      size: 18, color: Color(0xFFE65100))),
              const Icon(Icons.star_half,
                  size: 18, color: Color(0xFFE65100)),
              const SizedBox(width: 6),
              const Text(
                '4.5',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.grey,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '(142 reviews)',
                style: TextStyle(
                  fontSize: 13,
                  color: HousepitalColors.greyLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                priceText,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: HousepitalColors.orangeText,
                ),
              ),
              if (isRental) ...[
                const SizedBox(width: 4),
                const Text(
                  '/ month',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.orangeText,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Key features ───────────────────────────────────────────

  Widget _buildFeaturesSection(List<String> features) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Features',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HousepitalColors.black,
            ),
          ),
          const SizedBox(height: 12),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle,
                          size: 18, color: HousepitalColors.success),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 14,
                          color: HousepitalColors.grey,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── 4. Delivery info card ─────────────────────────────────────

  Widget _buildDeliveryInfoCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HousepitalColors.infoLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            _DeliveryInfoRow(
              icon: Icons.local_shipping,
              text: 'Free delivery in Delhi NCR',
            ),
            SizedBox(height: 10),
            _DeliveryInfoRow(
              icon: Icons.inventory_2,
              text: 'Delivered within 24 hours',
            ),
            SizedBox(height: 10),
            _DeliveryInfoRow(
              icon: Icons.replay,
              text: 'Easy returns within 7 days',
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Specifications table ───────────────────────────────────

  Widget _buildSpecificationsSection(Map<String, String> specs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Specifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HousepitalColors.black,
            ),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(3),
            },
            children: specs.entries.map((entry) {
              return TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          HousepitalColors.divider.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: HousepitalColors.greyLight,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: HousepitalColors.black,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 6. Reviews section ────────────────────────────────────────

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                ),
              ),
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Text(
                    'See all reviews',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: HousepitalColors.orangeText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._mockReviews.map((review) => _buildReviewCard(review)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(_Review review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
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
                Text(
                  review.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.black,
                  ),
                ),
                const Spacer(),
                Text(
                  review.date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: HousepitalColors.greyLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  size: 16,
                  color: const Color(0xFFE65100),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 13,
                color: HousepitalColors.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 7. Bottom sticky bar ──────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, String priceText) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: HousepitalColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Added to cart')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HousepitalColors.orange,
                    side: const BorderSide(
                        color: HousepitalColors.orange, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Add to Cart'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Razorpay payment integration \u2014 connect your API'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HousepitalColors.orange,
                    foregroundColor: HousepitalColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text('Buy Now \u2014 $priceText'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets & data classes ─────────────────────────────

class _DeliveryInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DeliveryInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: HousepitalColors.info),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HousepitalColors.info,
            ),
          ),
        ),
      ],
    );
  }
}

class _Review {
  final String name;
  final int rating;
  final String date;
  final String comment;

  const _Review({
    required this.name,
    required this.rating,
    required this.date,
    required this.comment,
  });
}
