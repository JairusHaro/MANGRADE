import '../models/classification_result.dart';

class HistoryStore {
  HistoryStore._();

  static final List<ClassificationResult> _items = [
    ClassificationResult(
      mangoClass: MangoClass.extra,
      confidence: 0.9731,
      timestamp: DateTime(2026, 10, 5, 10, 24),
    ),
    ClassificationResult(
      mangoClass: MangoClass.classI,
      confidence: 0.9472,
      timestamp: DateTime(2026, 10, 4, 14, 15),
    ),
    ClassificationResult(
      mangoClass: MangoClass.classII,
      confidence: 0.8965,
      timestamp: DateTime(2026, 10, 4, 11, 3),
    ),
  ];

  static List<ClassificationResult> get items =>
      List<ClassificationResult>.unmodifiable(_items);

  static void add(ClassificationResult result) {
    _items.insert(0, result);
  }

  static void clear() {
    _items.clear();
  }
}
