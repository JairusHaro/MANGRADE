
import 'package:flutter/material.dart';
import '../models/classification_result.dart';
import '../theme/app_theme.dart';
import '../widgets/mango_illustration.dart';

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
      ),
      const _GuideData(
        MangoClass.classI,
        'Class I',
        'Good quality',
        'Slight shape and skin defects may be permitted; visible quality remains acceptable.',
      ),
      const _GuideData(
        MangoClass.classII,
        'Class II',
        'Minimum quality',
        'Shape and skin defects may be present within the allowed visual limits.',
      ),
      const _GuideData(
        MangoClass.reject,
        'Reject Class',
        'Non-compliant',
        'App-defined reject output for samples that do not meet the minimum quality threshold.',
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
            const SizedBox(height: 16),
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
                      fontSize: 11,
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

  const _GuideData(
    this.mangoClass,
    this.title,
    this.subtitle,
    this.description,
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 340;

          final illustration = Container(
            width: isNarrow ? 110 : 82,
            height: isNarrow ? 105 : 110,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: MangoIllustration(
              width: isNarrow ? 70 : 66,
              height: isNarrow ? 82 : 84,
            ),
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 6),
              Text(
                data.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: illustration),
                const SizedBox(height: 12),
                details,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              illustration,
              const SizedBox(width: 12),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}
