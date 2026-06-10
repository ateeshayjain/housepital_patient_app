// lib/models/doctor_recommendation.dart
//
// A single item the doctor recommended after a consultation — an equipment
// item to rent/buy, a lab test to repeat, or a service to book. Rendered on
// the My Care tab ("Doctor's Advice" card) with an Add-to-cart / Book CTA.

class DoctorRecommendation {
  final String id;
  final String title;
  final String note;

  /// 'equipment' | 'lab' | 'service'
  final String type;

  /// Id of the underlying catalog entry:
  ///  • equipment → assets/equipment_catalog.json item id
  ///  • lab       → assets/lab_tests_catalog.json item id
  ///  • service   → ServiceItem id from catalog_seeds
  final String catalogId;

  final bool isRental;

  const DoctorRecommendation({
    required this.id,
    required this.title,
    required this.note,
    required this.type,
    required this.catalogId,
    this.isRental = false,
  });
}
