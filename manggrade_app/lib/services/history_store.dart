import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/classification_result.dart';

class HistoryStore {
  HistoryStore._();

  static const String _storageKey = 'manggrade_classification_history';

  /// Folder (inside the app's documents directory) that keeps copies of
  /// the photos of each saved result. The camera/gallery paths returned by
  /// image_picker are temporary cache files that Android may delete.
  static const String _photoFolder = 'manggrade_history_photos';

  static final List<ClassificationResult> _items = [];
  static bool _initialized = false;

  static List<ClassificationResult> get items =>
      List<ClassificationResult>.unmodifiable(_items);

  static Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);

    if (saved != null) {
      try {
        final decoded = jsonDecode(saved) as List<dynamic>;

        _items
          ..clear()
          ..addAll(
            decoded
                .map(
                  (entry) => ClassificationResult.fromJson(
                    Map<String, dynamic>.from(entry as Map),
                  ),
                )
                .where((result) => !result.isDemo),
          );
      } catch (_) {
        // Ignore invalid stored data instead of crashing the app.
        _items.clear();
      }
    }

    _initialized = true;
  }

  static Future<void> add(ClassificationResult result) async {
    if (result.isDemo) return;

    await initialize();
    _items.insert(0, result);
    await _save();
  }

  static Future<void> clear() async {
    await initialize();
    _items.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    // Remove the photo copies that belonged to the cleared history.
    try {
      final folder = await _photoDirectory();
      if (await folder.exists()) {
        await folder.delete(recursive: true);
      }
    } catch (error) {
      debugPrint('Could not delete saved history photos: $error');
    }
  }

  /// Copies the photos of one result into permanent app storage.
  ///
  /// [imagePaths] maps a view name ('front', 'back', 'top') to the photo's
  /// current path. Returns the same keys with the copied paths. If a photo
  /// cannot be copied, its original path is kept so nothing is lost.
  static Future<Map<String, String>> persistPhotos(
    Map<String, String> imagePaths,
    DateTime timestamp,
  ) async {
    final saved = <String, String>{};
    Directory? folder;

    try {
      folder = Directory(
        '${(await _photoDirectory()).path}/${timestamp.millisecondsSinceEpoch}',
      );
      await folder.create(recursive: true);
    } catch (error) {
      debugPrint('Could not create the history photo folder: $error');
      return Map<String, String>.from(imagePaths);
    }

    for (final entry in imagePaths.entries) {
      try {
        final copy = await File(entry.value).copy(
          '${folder.path}/${entry.key}${_extension(entry.value)}',
        );
        saved[entry.key] = copy.path;
      } catch (error) {
        debugPrint('Could not copy the ${entry.key} photo: $error');
        saved[entry.key] = entry.value;
      }
    }
    return saved;
  }

  static Future<Directory> _photoDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/$_photoFolder');
  }

  static String _extension(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot).toLowerCase() : '.jpg';
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      _items.map((item) => item.toJson()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }
}
