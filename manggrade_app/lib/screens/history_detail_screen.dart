import 'dart:io';

import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../models/mango_view.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Shows one saved classification from the history.
///
/// This screen only displays what was stored when the mango was scanned:
/// the grade, the confidence, the date and time, and the saved photos.
/// It never calls the backend, never runs the model again and never
/// changes the saved photos.
class HistoryDetailScreen extends StatelessWidget {
  final ClassificationResult result;

  const HistoryDetailScreen({
    super.key,
    required this.result,
  });

  static const double _photoHeight = 200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text(
          'Saved Result',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHistoricalNotice(),
              const SizedBox(height: 13),
              _buildGradeRow(),
              const SizedBox(height: 13),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildPhotoSection(),
                ),
              ),
              const SizedBox(height: 13),
              _buildCriteriaCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoricalNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.history_rounded,
            color: AppColors.textSecondary,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Classified on',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(result.timestamp),
                  key: const ValueKey<String>('history-detail-date'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This is a saved result from an earlier scan. '
                  'It is shown as it was recorded and was not analyzed again.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.title,
                key: const ValueKey<String>('history-detail-grade'),
                style: TextStyle(
                  color: result.color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                result.subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 108,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                'Confidence',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${(result.confidence * 100).toStringAsFixed(2)}%',
                key: const ValueKey<String>('history-detail-confidence'),
                style: TextStyle(
                  color: result.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPhotoSection() {
    final imagePaths = result.imagePaths;

    final header = <Widget>[
      const Text(
        'Saved Photos',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
    ];

    // Three-photo result: show Front, Back and Top separately.
    if (imagePaths != null) {
      return [
        ...header,
        for (final view in MangoView.values) ...[
          _PhotoLabel(view.label),
          const SizedBox(height: 6),
          _SavedPhoto(
            key: ValueKey<String>('history-photo-${view.apiField}'),
            // Older three-photo entries always kept the front photo in
            // imagePath too, so use it if the map has no front entry.
            path: imagePaths[view.apiField] ??
                (view == MangoView.front ? result.imagePath : null),
            semanticLabel: '${view.label} photo of the mango',
            height: _photoHeight,
          ),
          if (view != MangoView.values.last) const SizedBox(height: 14),
        ],
      ];
    }

    // Older result saved with a single photo.
    if (result.imagePath != null) {
      return [
        ...header,
        const _PhotoLabel('Photo'),
        const SizedBox(height: 6),
        _SavedPhoto(
          key: const ValueKey<String>('history-photo-single'),
          path: result.imagePath,
          semanticLabel: 'Photo of the mango',
          height: _photoHeight,
        ),
        const SizedBox(height: 8),
        const Text(
          'This result was saved before MangGrade kept separate '
          'Front, Back and Top photos.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ];
    }

    // No photo was stored with this result.
    return [
      ...header,
      const _PhotoPlaceholder(
        key: ValueKey<String>('history-photo-none'),
        message: 'No photo was saved with this result.',
        height: 120,
      ),
    ];
  }

  Widget _buildCriteriaCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PNS/BAFS 13:2024 — Visual Reference',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...result.criteria.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Same format as the History list: yyyy-MM-dd HH:mm.
  static String _formatDateTime(DateTime d) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}

class _PhotoLabel extends StatelessWidget {
  final String text;

  const _PhotoLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// One saved photo, read from local storage with [Image.file].
///
/// Shows a placeholder when no path was saved, when the file no longer
/// exists, or when the file cannot be decoded as an image. The file itself
/// is only read, never changed.
class _SavedPhoto extends StatelessWidget {
  final String? path;
  final String semanticLabel;
  final double height;

  const _SavedPhoto({
    super.key,
    required this.path,
    required this.semanticLabel,
    required this.height,
  });

  static bool _fileExists(File file) {
    try {
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedPath = path;

    if (savedPath == null || savedPath.isEmpty) {
      return _PhotoPlaceholder(message: 'Photo not saved', height: height);
    }

    final file = File(savedPath);
    if (!_fileExists(file)) {
      return _PhotoPlaceholder(message: 'Photo unavailable', height: height);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: AppColors.greenSoft,
        child: Image.file(
          file,
          height: height,
          width: double.infinity,
          fit: BoxFit.contain,
          semanticLabel: semanticLabel,
          errorBuilder: (context, error, stackTrace) => _PhotoPlaceholder(
            message: 'Photo could not be opened',
            height: height,
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final String message;
  final double height;

  const _PhotoPlaceholder({
    super.key,
    required this.message,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.textSecondary,
            size: 32,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
