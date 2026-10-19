import '../models/classification_result.dart';

class MangoClassifier {
  MangoClassifier._();

  static int _demoIndex = 0;

  /// Demo inference used so the project can run before the real TFLite
  /// MobileNetV3 file is added.
  static Future<ClassificationResult> classifyDemo({String? imagePath}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1300));

    const classes = [
      MangoClass.extra,
      MangoClass.classI,
      MangoClass.classII,
      MangoClass.reject,
    ];

    const confidences = [0.9731, 0.9472, 0.8965, 0.9138];

    final index = _demoIndex % classes.length;
    _demoIndex++;

    return ClassificationResult(
      mangoClass: classes[index],
      confidence: confidences[index],
      timestamp: DateTime.now(),
      imagePath: imagePath,
      isDemo: true,
    );
  }

  /// Replace this file with the actual MobileNetV3/TFLite inference later.
  ///
  /// Recommended future flow:
  /// 1. Load mobilenetv3.tflite from assets.
  /// 2. Resize/crop image to your model's required input size.
  /// 3. Apply the exact normalization used during training.
  /// 4. Run inference.
  /// 5. Map output index to:
  ///    Extra Class / Class I / Class II / Reject Class.
}
