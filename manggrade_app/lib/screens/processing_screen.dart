import 'package:flutter/material.dart';

import '../models/mango_view.dart';
import '../services/manggrade_api.dart';
import '../theme/app_theme.dart';
import '../widgets/mango_illustration.dart';

class ProcessingScreen extends StatefulWidget {
  final ValueChanged<MangoApiResponse> onFinished;
  final ValueChanged<String> onError;

  /// Front, back and top photo paths.
  final Map<MangoView, String> imagePaths;

  const ProcessingScreen({
    super.key,
    required this.onFinished,
    required this.onError,
    required this.imagePaths,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    final missing = MangoView.values
        .where((view) => widget.imagePaths[view] == null)
        .map((view) => view.label)
        .toList();

    if (missing.isNotEmpty) {
      // Defer so we don't navigate during the first build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onError('Missing photo: ${missing.join(', ')}.');
        }
      });
      return;
    }

    try {
      final result = await MangGradeApi.analyzeViews(widget.imagePaths);
      if (!mounted) return;
      widget.onFinished(result);
    } catch (error) {
      if (!mounted) return;
      widget.onError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Uploading 3 Mango Photos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 168,
                        height: 168,
                        child: CircularProgressIndicator(
                          strokeWidth: 14,
                          backgroundColor: AppColors.greenSoft,
                          color: AppColors.green,
                        ),
                      ),
                      MangoIllustration(width: 92, height: 108),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sending the front, back and top photos to the MangGrade '
                  'backend for quality checks and grading.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
