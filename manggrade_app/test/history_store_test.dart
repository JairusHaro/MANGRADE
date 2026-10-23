import 'package:flutter_test/flutter_test.dart';
import 'package:manggrade/models/classification_result.dart';
import 'package:manggrade/services/history_store.dart';

void main() {
  setUp(() {
    HistoryStore.clear();
  });

  tearDown(() {
    HistoryStore.clear();
  });

  test('adds a result to the start of history', () {
    final result = ClassificationResult(
      mangoClass: MangoClass.extra,
      confidence: 0.9,
      timestamp: DateTime(2026, 1, 1),
    );

    HistoryStore.add(result);

    expect(HistoryStore.items, hasLength(1));
    expect(HistoryStore.items.first, same(result));
  });

  test('clear removes all history entries', () {
    HistoryStore.add(
      ClassificationResult(
        mangoClass: MangoClass.classI,
        confidence: 0.8,
        timestamp: DateTime(2026, 1, 1),
      ),
    );

    HistoryStore.clear();

    expect(HistoryStore.items, isEmpty);
  });
}
