import 'package:flutter/material.dart';

import '../services/manggrade_api.dart';
import '../theme/app_theme.dart';
import '../widgets/mango_illustration.dart';

class ProcessingScreen extends StatefulWidget {
  final ValueChanged<MangoApiResponse> onFinished;
  final ValueChanged<String> onError;
  final String? imagePath;

  const ProcessingScreen({
    super.key,
    required this.onFinished,
    required this.onError,
    this.imagePath,
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
    if (widget.imagePath == null) {
      widget.onError('Please select an image first.');
      return;
    }

    try {
      final result = await MangGradeApi.analyzeImage(widget.imagePath!);
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
                  'Uploading Mango Image',
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
                  'Sending your image to the MangGrade backend. '
                  'A grade will only be shown when a trained model '
                  'is connected.',
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
