import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum MangoClass {
  extra,
  classI,
  classII,
  reject,
}

class ClassificationResult {
  final MangoClass mangoClass;
  final double confidence;
  final DateTime timestamp;

  const ClassificationResult({
    required this.mangoClass,
    required this.confidence,
    required this.timestamp,
  });

  String get title {
    switch (mangoClass) {
      case MangoClass.extra:
        return 'EXTRA CLASS';
      case MangoClass.classI:
        return 'CLASS I';
      case MangoClass.classII:
        return 'CLASS II';
      case MangoClass.reject:
        return 'REJECT CLASS';
    }
  }

  String get subtitle {
    switch (mangoClass) {
      case MangoClass.extra:
        return 'Superior quality';
      case MangoClass.classI:
        return 'Good quality';
      case MangoClass.classII:
        return 'Meets minimum requirements';
      case MangoClass.reject:
        return 'Non-compliant';
    }
  }

  Color get color {
    switch (mangoClass) {
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

  List<String> get criteria {
    switch (mangoClass) {
      case MangoClass.extra:
        return const [
          'Practically free from visible defects',
          'Only very slight superficial defects',
          'Visual appearance is consistent with Extra Class',
        ];
      case MangoClass.classI:
        return const [
          'Slight shape defects may be present',
          'Slight skin defects may be present',
          'Visible defects should not substantially affect quality',
        ];
      case MangoClass.classII:
        return const [
          'Shape defects may be visible',
          'Skin defects may be visible within allowed limits',
          'Still meets the minimum visual quality requirements',
        ];
      case MangoClass.reject:
        return const [
          'Does not meet the minimum visual quality requirements',
          'Major defects or damage may be visible',
          'Separated from the three PNS quality classes by the app',
        ];
    }
  }
}
