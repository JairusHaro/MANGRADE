import 'dart:io';

import 'package:flutter/material.dart';

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
            const Icon(
              Icons.cloud_done_outlined,
              size: 64,
              color: AppColors.green,
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
            if (response?.predictionAvailable == true) ...[
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
