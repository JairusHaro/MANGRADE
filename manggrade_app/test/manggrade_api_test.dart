import 'package:flutter_test/flutter_test.dart';
import 'package:manggrade/models/classification_result.dart';
import 'package:manggrade/services/manggrade_api.dart';

// Response SHAPES from backend main.py 0.5.0. The numbers are made up for
// the test; they are not model results.
Map<String, dynamic> _multiviewResponse({bool viewsAgree = false}) => {
      'views': {
        'front': {
          'filename': 'front.jpg',
          'width': 1600,
          'height': 2125,
          'validation': {'status': 'accepted'},
          'prediction': {
            'grade': 'Class I',
            'confidence': 0.6,
            'probabilities': {
              'Extra Class': 0.3,
              'Class I': 0.6,
              'Class II': 0.1,
              'Reject': 0.0,
            },
          },
        },
        'back': {
          'prediction': {
            'grade': 'Extra Class',
            'confidence': 0.5,
            'probabilities': {
              'Extra Class': 0.5,
              'Class I': 0.4,
              'Class II': 0.1,
              'Reject': 0.0,
            },
          },
        },
        'top': {
          'prediction': {
            'grade': 'Class I',
            'confidence': 0.7,
            'probabilities': {
              'Extra Class': 0.2,
              'Class I': 0.7,
              'Class II': 0.1,
              'Reject': 0.0,
            },
          },
        },
      },
      'view_order': ['front', 'back', 'top'],
      'predicted_grade': 'Class I',
      'confidence': 0.566667,
      'probabilities': {
        'Extra Class': 0.333333,
        'Class I': 0.566667,
        'Class II': 0.1,
        'Reject': 0.0,
      },
      'views_agree': viewsAgree,
      'aggregation': {
        'method': 'mean_probability',
        'views_used': ['front', 'back', 'top'],
        'note': 'Provisional: not yet validated.',
      },
      'grades': ['Extra Class', 'Class I', 'Class II', 'Reject'],
      'model_status': 'loaded',
      'prediction_is_real': true,
      'message': 'Predicted grade: Class I (average of the front, back and top photos).',
      'confidence_note': 'Not a calibrated accuracy estimate.',
    };

void main() {
  group('MangoApiResponse.fromJson', () {
    test('reads the final grade and the per-photo results', () {
      final response = MangoApiResponse.fromJson(_multiviewResponse());

      expect(response.predictionAvailable, isTrue);
      expect(response.predictedGrade, 'Class I');
      expect(response.confidence, closeTo(0.566667, 1e-9));
      expect(response.probabilities!['Class I'], closeTo(0.566667, 1e-9));
      expect(response.viewsAgree, isFalse);
      expect(response.aggregationNote, 'Provisional: not yet validated.');
      expect(response.confidenceNote, isNotNull);
      expect(response.viewPredictions!.keys.toList(), ['front', 'back', 'top']);
      expect(response.viewPredictions!['back']!.grade, 'Extra Class');
      expect(response.viewPredictions!['top']!.confidence, 0.7);
      expect(
        response.viewPredictions!['front']!.probabilities['Extra Class'],
        0.3,
      );
    });

    test('still reads an old response without the new fields', () {
      final response = MangoApiResponse.fromJson({
        'filename': 'mango.jpg',
        'width': 640,
        'height': 480,
        'predicted_grade': null,
        'confidence': null,
        'prediction_is_real': false,
        'message': 'No grade was predicted because the trained model is not connected.',
      });

      expect(response.predictionAvailable, isFalse);
      expect(response.imageWidth, 640);
      expect(response.viewPredictions, isNull);
      expect(response.probabilities, isNull);
      expect(response.viewsAgree, isNull);
    });

    test('a grade without prediction_is_real is not treated as a prediction', () {
      final data = _multiviewResponse()..['prediction_is_real'] = false;
      expect(MangoApiResponse.fromJson(data).predictionAvailable, isFalse);
    });
  });

  group('ClassificationResult image paths', () {
    test('keeps all three photo paths through JSON', () {
      final result = ClassificationResult(
        mangoClass: MangoClass.classI,
        confidence: 0.57,
        timestamp: DateTime(2026, 11, 6),
        imagePath: '/data/photos/front.jpg',
        imagePaths: const {
          'front': '/data/photos/front.jpg',
          'back': '/data/photos/back.jpg',
          'top': '/data/photos/top.jpg',
        },
        isDemo: false,
      );

      final restored = ClassificationResult.fromJson(result.toJson());
      expect(restored.imagePath, '/data/photos/front.jpg');
      expect(restored.imagePaths, result.imagePaths);
      expect(restored.isDemo, isFalse);
    });

    test('reads history saved before imagePaths existed', () {
      final restored = ClassificationResult.fromJson({
        'mangoClass': 'extra',
        'confidence': 0.9,
        'timestamp': '2026-11-01T10:00:00.000',
        'imagePath': '/cache/front.jpg',
        'isDemo': false,
      });
      expect(restored.imagePath, '/cache/front.jpg');
      expect(restored.imagePaths, isNull);
    });
  });
}
