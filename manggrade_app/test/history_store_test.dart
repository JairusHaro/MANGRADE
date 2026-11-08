import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manggrade/models/classification_result.dart';
import 'package:manggrade/services/history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // SharedPreferences and path_provider use platform channels, which need
  // the Flutter test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // HistoryStore.clear() and persistPhotos() ask path_provider for the app
  // documents folder. Point it at a temporary folder so tests never touch
  // real user folders.
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory documents;

  setUp(() async {
    // Every test starts with empty mock storage.
    SharedPreferences.setMockInitialValues({});
    documents = await Directory.systemTemp.createTemp('manggrade_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      pathProviderChannel,
      (MethodCall call) async => documents.path,
    );
    await HistoryStore.clear();
  });

  tearDown(() async {
    await HistoryStore.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await documents.exists()) {
      await documents.delete(recursive: true);
    }
  });

  test('adds a result to the start of history', () async {
    // HistoryStore only keeps real (non-demo) results, so this is a
    // model result.
    final result = ClassificationResult(
      mangoClass: MangoClass.extra,
      confidence: 0.9,
      timestamp: DateTime(2026, 1, 1),
      isDemo: false,
    );

    await HistoryStore.add(result);

    expect(HistoryStore.items, hasLength(1));
    expect(HistoryStore.items.first, same(result));
  });

  test('clear removes all history entries', () async {
    await HistoryStore.add(
      ClassificationResult(
        mangoClass: MangoClass.classI,
        confidence: 0.8,
        timestamp: DateTime(2026, 1, 1),
        isDemo: false,
      ),
    );

    await HistoryStore.clear();

    expect(HistoryStore.items, isEmpty);
  });

  test('demo results are not saved', () async {
    await HistoryStore.add(
      ClassificationResult(
        mangoClass: MangoClass.extra,
        confidence: 0.9,
        timestamp: DateTime(2026, 1, 1),
      ),
    );

    expect(HistoryStore.items, isEmpty);
  });

  test('saved history is stored in SharedPreferences', () async {
    await HistoryStore.add(
      ClassificationResult(
        mangoClass: MangoClass.classII,
        confidence: 0.7,
        timestamp: DateTime(2026, 1, 1),
        imagePaths: const {'front': '/a/front.jpg'},
        isDemo: false,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('manggrade_classification_history');
    expect(saved, isNotNull);
    expect(saved, contains('"mangoClass":"classII"'));
    expect(saved, contains('/a/front.jpg'));
  });

  test('persistPhotos copies the three photos into app storage', () async {
    final source = await Directory.systemTemp.createTemp('manggrade_src_');
    addTearDown(() => source.delete(recursive: true));
    final paths = <String, String>{};
    for (final view in ['front', 'back', 'top']) {
      final file = File('${source.path}/picker_$view.jpg');
      await file.writeAsBytes([1, 2, 3, view.length]);
      paths[view] = file.path;
    }

    final saved = await HistoryStore.persistPhotos(
      paths,
      DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(saved.keys, unorderedEquals(['front', 'back', 'top']));
    for (final view in ['front', 'back', 'top']) {
      expect(saved[view], startsWith(documents.path));
      expect(saved[view], endsWith('$view.jpg'));
      expect(await File(saved[view]!).readAsBytes(), [1, 2, 3, view.length]);
      // The original picker file is left untouched.
      expect(await File(paths[view]!).exists(), isTrue);
    }

    await HistoryStore.clear();
    for (final view in ['front', 'back', 'top']) {
      expect(await File(saved[view]!).exists(), isFalse);
    }
  });

  test('persistPhotos keeps the original path when a copy fails', () async {
    final saved = await HistoryStore.persistPhotos(
      {'front': '/does/not/exist.jpg'},
      DateTime.fromMillisecondsSinceEpoch(2000),
    );

    expect(saved, {'front': '/does/not/exist.jpg'});
  });
}
