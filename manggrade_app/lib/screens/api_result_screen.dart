import 'dart:io';

import 'package:flutter/material.dart';

import '../models/mango_view.dart';
import '../services/manggrade_api.dart';
import '../theme/app_theme.dart';

class ApiResultScreen extends StatelessWidget {
  final MangoApiResponse? response;
  final String? imagePath;
  final String? errorMessage;
  final VoidCallback onClassifyAnother;

  const ApiResultScreen({
    super.key,
    required this.onClassifyAnother,
    this.response,
    this.imagePath,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final message = errorMessage ??
        response?.message ??
        'No response was received from the backend.';
    final hasPrediction =
        errorMessage == null && response?.predictionAvailable == true;
    final viewPredictions = response?.viewPredictions;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Scan Result'),
        backgroundColor: AppColors.cream,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(imagePath!),
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 100,
                    child: Center(child: Text('Image preview unavailable')),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Icon(
              errorMessage != null
                  ? Icons.error_outline_rounded
                  : hasPrediction
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
              size: 64,
              color: errorMessage != null
                  ? AppColors.reject
                  : hasPrediction
                      ? AppColors.green
                      : AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage != null
                  ? 'Connection or Upload Error'
                  : response?.predictionAvailable == true
                      ? 'Prediction Received'
                      : 'Model Not Connected',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (hasPrediction) ...[
              const SizedBox(height: 20),
              Text(
                'Grade: ${response!.predictedGrade}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
              if (response!.confidence != null)
                Text(
                  'Confidence: '
                  '${(response!.confidence! * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                ),
              if (viewPredictions != null && viewPredictions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Result for each photo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final view in MangoView.values)
                        if (viewPredictions[view.apiField] != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    view.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    viewPredictions[view.apiField]!.grade,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(viewPredictions[view.apiField]!.confidence * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      if (response!.viewsAgree == false) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'The three photos did not all give the same grade. '
                          'The final grade uses the average of all three.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              for (final note in [
                response!.aggregationNote,
                response!.confidenceNote,
              ])
                if (note != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    note,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onClassifyAnother,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Scan Another Mango'),
            ),
          ],
        ),
      ),
    );
  }
}
