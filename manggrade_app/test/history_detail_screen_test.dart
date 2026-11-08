import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manggrade/models/classification_result.dart';
import 'package:manggrade/models/mango_view.dart';
import 'package:manggrade/screens/history_detail_screen.dart';
import 'package:manggrade/screens/history_screen.dart';
import 'package:manggrade/services/history_store.dart';
import 'package:manggrade/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A valid 1x1 PNG, used as a stand-in for a saved mango photo.
final List<int> _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwAD'
  'hgGAWjR9awAAAABJRU5ErkJggg==',
);

const _placeholderMessages = [
  'Photo not saved',
  'Photo unavailable',
  'Photo could not be opened',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Map<MangoView, String> viewPhotos;
  late String singlePhoto;
  late String listLegacyPhoto;
  late String corruptPhoto;
  late String missingPhoto;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('manggrade_history_test_');

    viewPhotos = {
      for (final view in MangoView.values)
        view: (File('${tempDir.path}/${view.apiField}.png')
              ..writeAsBytesSync(_pngBytes))
            .path,
    };
    singlePhoto = (File('${tempDir.path}/single.png')
          ..writeAsBytesSync(_pngBytes))
        .path;
    // Separate file so an image load started in one test never shares an
    // image-cache entry with another test.
    listLegacyPhoto = (File('${tempDir.path}/list_legacy.png')
          ..writeAsBytesSync(_pngBytes))
        .path;
    corruptPhoto = (File('${tempDir.path}/corrupt.jpg')
          ..writeAsStringSync('this is not an image'))
        .path;
    missingPhoto = '${tempDir.path}/deleted_photo.jpg';

    SharedPreferences.setMockInitialValues({});

    // HistoryStore.clear() asks path_provider for the documents folder.
    // Point it at the temp folder so no real app data is touched.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Replaces the saved history with [newestFirst] (same order as the list).
  Future<void> replaceHistory(List<ClassificationResult> newestFirst) async {
    await HistoryStore.clear();
    for (final result in newestFirst.reversed) {
      await HistoryStore.add(result);
    }
  }

  Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

  /// Pumps the detail screen and lets every Image.file finish loading
  /// (or fail), so success and error states can both be checked.
  Future<void> pumpDetailAndLoadImages(
    WidgetTester tester,
    ClassificationResult result,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app(HistoryDetailScreen(result: result)));
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage(
          (element.widget as Image).image,
          element,
          onError: (error, stackTrace) {},
        );
      }
    });
    await tester.pump();
  }

  String? fileImagePath(WidgetTester tester, Finder photo) {
    final image = find.descendant(of: photo, matching: find.byType(Image));
    if (image.evaluate().isEmpty) return null;
    final provider = tester.widget<Image>(image).image;
    return provider is FileImage ? provider.file.path : null;
  }

  Finder photoSlot(String name) =>
      find.byKey(ValueKey<String>('history-photo-$name'));

  group('History list', () {
    testWidgets('history cards are tappable and open the selected result',
        (tester) async {
      final newer = ClassificationResult(
        mangoClass: MangoClass.extra,
        confidence: 0.9375,
        timestamp: DateTime(2026, 11, 2, 16, 40),
        isDemo: false,
      );
      final older = ClassificationResult(
        mangoClass: MangoClass.classII,
        confidence: 0.75,
        timestamp: DateTime(2026, 10, 1, 8, 5),
        isDemo: false,
      );
      await tester.runAsync(() => replaceHistory([newer, older]));

      await tester.pumpWidget(app(const Scaffold(body: HistoryScreen())));

      // Both cards are rendered as tappable InkWells.
      for (final index in [0, 1]) {
        final card = find.byKey(ValueKey<String>('history-card-$index'));
        expect(card, findsOneWidget);
        expect(tester.widget<InkWell>(card).onTap, isNotNull);
      }

      final olderCard = find.byKey(const ValueKey<String>('history-card-1'));
      expect(
        find.descendant(of: olderCard, matching: find.text('CLASS II')),
        findsOneWidget,
      );

      await tester.tap(olderCard);
      await tester.pumpAndSettle();

      // The detail screen received exactly the tapped result.
      final detail = tester.widget<HistoryDetailScreen>(
        find.byType(HistoryDetailScreen),
      );
      expect(detail.result, same(older));

      expect(find.text('Saved Result'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('history-detail-grade')),
            )
            .data,
        'CLASS II',
      );
      expect(find.text('75.00%'), findsOneWidget);
      expect(find.text('2026-10-01 08:05'), findsOneWidget);
    });

    testWidgets('an older single-photo entry opens from the list',
        (tester) async {
      final legacy = ClassificationResult.fromJson({
        'mangoClass': 'classI',
        'confidence': 0.875,
        'timestamp': '2026-06-15T10:30:00.000',
        'imagePath': listLegacyPhoto,
        'isDemo': false,
      });
      await tester.runAsync(() => replaceHistory([legacy]));

      await tester.pumpWidget(app(const Scaffold(body: HistoryScreen())));
      await tester.tap(find.byKey(const ValueKey<String>('history-card-0')));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryDetailScreen), findsOneWidget);
      expect(find.text('CLASS I'), findsOneWidget);
      expect(fileImagePath(tester, photoSlot('single')), listLegacyPhoto);
    });
  });

  group('HistoryDetailScreen', () {
    testWidgets('shows the saved grade, confidence and date only',
        (tester) async {
      final result = ClassificationResult(
        mangoClass: MangoClass.classI,
        confidence: 0.875,
        timestamp: DateTime(2026, 3, 4, 9, 7),
        isDemo: false,
      );

      await tester.pumpWidget(app(HistoryDetailScreen(result: result)));

      final grade = tester.widget<Text>(
        find.byKey(const ValueKey<String>('history-detail-grade')),
      );
      expect(grade.data, 'CLASS I');
      expect(grade.style?.color, AppColors.classI);
      expect(find.text('Good quality'), findsOneWidget);

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('history-detail-confidence')),
            )
            .data,
        '87.50%',
      );
      expect(find.text('2026-03-04 09:07'), findsOneWidget);
      expect(find.text(result.criteria.first), findsOneWidget);

      // Historical view: no new-scan, save, demo or model-status content.
      expect(find.text('Save Result'), findsNothing);
      expect(find.text('Scan Another Mango'), findsNothing);
      expect(find.text('Classify Another'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.textContaining('Demo'), findsNothing);
      expect(find.textContaining('DEMO'), findsNothing);
      expect(find.textContaining('Not connected'), findsNothing);
      expect(find.textContaining('Prediction Received'), findsNothing);
    });

    testWidgets('shows Front, Back and Top photos when available',
        (tester) async {
      final result = ClassificationResult(
        mangoClass: MangoClass.extra,
        confidence: 0.9375,
        timestamp: DateTime(2026, 11, 8, 14, 32),
        imagePath: viewPhotos[MangoView.front],
        imagePaths: {
          for (final entry in viewPhotos.entries) entry.key.apiField: entry.value,
        },
        isDemo: false,
      );

      await pumpDetailAndLoadImages(tester, result);

      for (final view in MangoView.values) {
        expect(find.text(view.label), findsOneWidget);
        expect(photoSlot(view.apiField), findsOneWidget);
        expect(fileImagePath(tester, photoSlot(view.apiField)),
            viewPhotos[view]);
      }
      for (final message in _placeholderMessages) {
        expect(find.text(message), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing or unreadable photos show a placeholder',
        (tester) async {
      final result = ClassificationResult(
        mangoClass: MangoClass.reject,
        confidence: 0.75,
        timestamp: DateTime(2026, 11, 8, 14, 32),
        imagePath: missingPhoto,
        imagePaths: {
          'front': missingPhoto, // file was deleted
          'back': corruptPhoto, // file exists but is not an image
          // 'top' was never saved
        },
        isDemo: false,
      );

      await pumpDetailAndLoadImages(tester, result);

      expect(
        find.descendant(
          of: photoSlot('front'),
          matching: find.text('Photo unavailable'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: photoSlot('back'),
          matching: find.text('Photo could not be opened'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: photoSlot('top'),
          matching: find.text('Photo not saved'),
        ),
        findsOneWidget,
      );
      // The grade is still shown and nothing crashed.
      expect(find.text('REJECT CLASS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The saved file is left untouched.
      expect(File(corruptPhoto).readAsStringSync(), 'this is not an image');
    });

    testWidgets('older single-image entries show their one photo',
        (tester) async {
      // JSON in the format saved before imagePaths existed.
      final legacy = ClassificationResult.fromJson({
        'mangoClass': 'classII',
        'confidence': 0.75,
        'timestamp': '2026-06-15T10:30:00.000',
        'imagePath': singlePhoto,
        'isDemo': false,
      });
      expect(legacy.imagePaths, isNull);

      await pumpDetailAndLoadImages(tester, legacy);

      expect(find.text('Photo'), findsOneWidget);
      expect(fileImagePath(tester, photoSlot('single')), singlePhoto);
      expect(find.text('Front'), findsNothing);
      expect(find.text('Back'), findsNothing);
      expect(find.text('Top'), findsNothing);
      for (final message in _placeholderMessages) {
        expect(find.text(message), findsNothing);
      }
      expect(find.text('2026-06-15 10:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('older entries with a deleted or no photo do not crash',
        (tester) async {
      final deleted = ClassificationResult(
        mangoClass: MangoClass.classI,
        confidence: 0.75,
        timestamp: DateTime(2026, 5, 1, 7, 0),
        imagePath: missingPhoto,
        isDemo: false,
      );
      await tester.pumpWidget(app(HistoryDetailScreen(result: deleted)));
      expect(
        find.descendant(
          of: photoSlot('single'),
          matching: find.text('Photo unavailable'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      final noPhoto = ClassificationResult(
        mangoClass: MangoClass.classI,
        confidence: 0.75,
        timestamp: DateTime(2026, 5, 1, 7, 0),
        isDemo: false,
      );
      await tester.pumpWidget(app(HistoryDetailScreen(result: noPhoto)));
      expect(find.text('No photo was saved with this result.'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
