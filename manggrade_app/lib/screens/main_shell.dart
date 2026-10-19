import 'package:flutter/material.dart';
import '../models/classification_result.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'about_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'processing_screen.dart';
import 'result_screen.dart';
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

  void _go(int value) {
    setState(() => index = value);
  }

  void _startAnalysis(String? imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProcessingScreen(
          imagePath: imagePath,
          onFinished: (ClassificationResult result) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => ResultScreen(
                  result: result,
                  onClassifyAnother: () {
                    Navigator.of(context).pop();
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
      ScanScreen(onAnalyze: _startAnalysis),
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
