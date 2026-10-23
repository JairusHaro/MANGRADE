import 'package:flutter/material.dart';
import '../models/classification_result.dart';
import '../theme/app_theme.dart';

class StandardScreen extends StatelessWidget {
  const StandardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _GuideData(
        MangoClass.extra,
        'Extra Class',
        'Superior quality',
        'Practically free from defects. Very slight superficial defects only.',
        'assets/images/extra_class.png',
      ),
      const _GuideData(
        MangoClass.classI,
        'Class I',
        'Good quality',
        'Slight shape and skin defects may be permitted; visible quality remains acceptable.',
        'assets/images/class_i.png',
      ),
      const _GuideData(
        MangoClass.classII,
        'Class II',
        'Minimum quality',
        'Shape and skin defects may be present within the allowed visual limits.',
        'assets/images/class_ii.png',
      ),
      const _GuideData(
        MangoClass.reject,
        'Reject Class',
        'Non-compliant',
        'App-defined reject output for samples that do not meet the minimum quality threshold.',
        'assets/images/reject_class.png',
      ),
    ];

    return ColoredBox(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'PNS Grading Guide',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Visual quality classes used by the classifier',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            ...cards.map((data) => _GuideCard(data: data)),
            Container(
              margin: const EdgeInsets.only(top: 2, bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Important',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'The app performs image-based visual classification. Other requirements in PNS/BAFS 13:2024 may require physical, production, sizing, maturity, or inspection data.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideData {
  final MangoClass mangoClass;
  final String title;
  final String subtitle;
  final String description;
  final String imagePath;

  const _GuideData(
    this.mangoClass,
    this.title,
    this.subtitle,
    this.description,
    this.imagePath,
  );
}

class _GuideCard extends StatelessWidget {
  final _GuideData data;

  const _GuideCard({required this.data});

  Color get color {
    switch (data.mangoClass) {
      case MangoClass.extra:
        return AppColors.green;
      case MangoClass.classI:
        return AppColors.classI;
      case MangoClass.classII:
        return AppColors.classII;
      case MangoClass.reject:
        return AppColors.reject;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                data.imagePath,
                width: 100,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.image_not_supported_outlined,
                    size: 32,
                    color: AppColors.textSecondary,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
