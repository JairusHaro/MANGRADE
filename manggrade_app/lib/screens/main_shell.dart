import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../models/mango_view.dart';
import '../services/history_store.dart';
import '../services/manggrade_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'about_screen.dart';
import 'api_result_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'processing_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'standard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  /// Changing this gives ScanScreen a fresh state (clears the 3 photos).
  int _scanSession = 0;

  void _go(int value) {
    setState(() => index = value);
  }

  /// Opens the Scan tab with empty Front/Back/Top slots.
  void _startNewScan() {
    setState(() {
      _scanSession++;
      index = 2;
    });
  }

  MangoClass? _parseMangoClass(String grade) {
    switch (grade.trim().toUpperCase()) {
      case 'EXTRA':
      case 'EXTRA CLASS':
        return MangoClass.extra;

      case 'CLASS I':
      case 'CLASS 1':
        return MangoClass.classI;

      case 'CLASS II':
      case 'CLASS 2':
        return MangoClass.classII;

      case 'REJECT':
      case 'REJECT CLASS':
        return MangoClass.reject;

      default:
        return null;
    }
  }

  void _startAnalysis(Map<MangoView, String> imagePaths) {
    // The front photo represents the mango on the result screen and in
    // history; history also keeps all three photos (imagePaths).
    final frontImagePath = imagePaths[MangoView.front];

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProcessingScreen(
          imagePaths: imagePaths,
          onFinished: (MangoApiResponse response) async {
            final grade = response.predictedGrade;
            final confidence = response.confidence;

            if (response.predictionAvailable &&
                grade != null &&
                confidence != null &&
                confidence >= 0 &&
                confidence <= 1) {
              final mangoClass = _parseMangoClass(grade);

              if (mangoClass != null) {
                try {
                  final timestamp = DateTime.now();
                  // Copy the photos out of the temporary picker cache so the
                  // history keeps them.
                  final savedPaths = await HistoryStore.persistPhotos(
                    {
                      for (final entry in imagePaths.entries)
                        entry.key.apiField: entry.value,
                    },
                    timestamp,
                  );
                  await HistoryStore.add(
                    ClassificationResult(
                      mangoClass: mangoClass,
                      confidence: confidence,
                      timestamp: timestamp,
                      imagePath:
                          savedPaths[MangoView.front.apiField] ?? frontImagePath,
                      imagePaths: savedPaths,
                      isDemo: false,
                    ),
                  );
                } catch (error) {
                  debugPrint('Could not save classification history: $error');
                }
              }
            }

            if (!mounted) return;

            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ApiResultScreen(
                  response: response,
                  imagePath: frontImagePath,
                  onClassifyAnother: () {
                    Navigator.of(context).pop();
                    // Upload succeeded: next mango starts with empty slots.
                    _startNewScan();
                  },
                ),
              ),
            );
          },
          onError: (String message) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ApiResultScreen(
                  errorMessage: message,
                  imagePath: frontImagePath,
                  onClassifyAnother: () {
                    Navigator.of(context).pop();
                    // Upload failed: keep the 3 photos so the user can retry.
                    _go(2);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _go),
      const HistoryScreen(),
      ScanScreen(
        key: ValueKey<int>(_scanSession),
        onAnalyze: _startAnalysis,
      ),
      const StandardScreen(),
      AboutScreen(onOpenSettings: _openSettings),
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: IndexedStack(
        index: index,
        children: screens,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        onChanged: _go,
      ),
    );
  }
}
