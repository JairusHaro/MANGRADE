import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/classification_result.dart';

class HistoryStore {
  HistoryStore._();

  static const String _storageKey = 'manggrade_classification_history';

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
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      _items.map((item) => item.toJson()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }
}
