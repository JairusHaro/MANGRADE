import 'package:flutter_test/flutter_test.dart';
import 'package:mangograde/models/classification_result.dart';

void main() {
  group('ClassificationResult', () {
    test('maps each mango class to its display title', () {
      final cases = <MangoClass, String>{
        MangoClass.extra: 'EXTRA CLASS',
        MangoClass.classI: 'CLASS I',
        MangoClass.classII: 'CLASS II',
        MangoClass.reject: 'REJECT CLASS',
      };

      for (final entry in cases.entries) {
        final result = ClassificationResult(
          mangoClass: entry.key,
          confidence: 0.8,
          timestamp: DateTime(2026, 1, 1),
        );
        expect(result.title, entry.value);
      }
    });

    test('demo flag defaults to true and image path is optional', () {
      final result = ClassificationResult(
        mangoClass: MangoClass.extra,
        confidence: 0.9,
        timestamp: DateTime(2026, 1, 1),
      );

      expect(result.isDemo, isTrue);
      expect(result.imagePath, isNull);
    });

    test('can keep the selected image path on a demo result', () {
      final result = ClassificationResult(
        mangoClass: MangoClass.classI,
        confidence: 0.8,
        timestamp: DateTime(2026, 1, 1),
        imagePath: '/tmp/mango.jpg',
        isDemo: true,
      );

      expect(result.imagePath, '/tmp/mango.jpg');
      expect(result.isDemo, isTrue);
    });
  });
}
