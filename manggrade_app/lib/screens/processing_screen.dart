import 'package:flutter/material.dart';
import '../models/classification_result.dart';
import '../services/mango_classifier.dart';
import '../theme/app_theme.dart';
import '../widgets/mango_illustration.dart';

class ProcessingScreen extends StatefulWidget {
  final ValueChanged<ClassificationResult> onFinished;
  final String? imagePath;

  const ProcessingScreen({
    super.key,
    required this.onFinished,
    this.imagePath,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    _classify();
  }

  Future<void> _classify() async {
    final result = await MangoClassifier.classifyDemo(imagePath: widget.imagePath);
    if (!mounted) return;
    widget.onFinished(result);
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
                  'Analyzing Mango',
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
                  "Demo mode is active. This screen does not run the trained MobileNetV3 model yet.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.memory_rounded, color: AppColors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Simulated demo result',
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Not a real model prediction.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
