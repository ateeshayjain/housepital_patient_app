// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../data/care_packages.dart';
import '../../../widgets/common_widgets.dart';

/// Packages tab — surfaces the curated care packages (post-op, mother &
/// baby, etc.) from `lib/data/care_packages.dart`.
class PackagesTab extends StatelessWidget {
  const PackagesTab({super.key});

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
            borderRadius: BorderRadius.circular(12),
            elevation: 1,
            shadowColor: Colors.black12,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/package-detail', arguments: pkg),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIconTile(icon: icon, color: HousepitalColors.orange),
                        const SizedBox(width: 16),
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
                            borderRadius: BorderRadius.circular(8),
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
                          borderRadius: BorderRadius.circular(8),
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
