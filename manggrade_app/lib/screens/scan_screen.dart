import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/mango_view.dart';
import '../theme/app_theme.dart';
import '../widgets/mango_illustration.dart';

class ScanScreen extends StatefulWidget {
  /// Called with all three photo paths (front, back, top) once every view
  /// has been captured.
  final ValueChanged<Map<MangoView, String>> onAnalyze;

  const ScanScreen({
    super.key,
    required this.onAnalyze,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  bool cameraSelected = true;
  bool pickingImage = false;

  /// Captured photos, keyed by view.
  final Map<MangoView, XFile> _photos = {};

  /// The view the next capture will fill (or replace).
  MangoView _activeView = MangoView.front;

  bool get _allCaptured => MangoView.values.every(_photos.containsKey);

  /// First view in capture order that has no photo yet.
  MangoView? get _nextMissingView {
    for (final view in MangoView.values) {
      if (!_photos.containsKey(view)) return view;
    }
    return null;
  }

  Future<void> _pickImage(ImageSource source) async {
    if (pickingImage) return;

    // Remember which slot this capture belongs to, even if the user
    // taps another slot while the camera is open.
    final view = _activeView;

    setState(() => pickingImage = true);
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (image != null) {
        setState(() {
          _photos[view] = image;
          // Move on to the next missing view; stay put when all are done.
          _activeView = _nextMissingView ?? view;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open image source: $error')),
      );
    } finally {
      if (mounted) setState(() => pickingImage = false);
    }
  }

  Future<void> _chooseCurrentSource() async {
    await _pickImage(cameraSelected ? ImageSource.camera : ImageSource.gallery);
  }

  void _startOver() {
    setState(() {
      _photos.clear();
      _activeView = MangoView.front;
    });
  }

  void _analyze() {
    if (!_allCaptured) return;
    widget.onAnalyze({
      for (final view in MangoView.values) view: _photos[view]!.path,
    });
  }

  @override
  Widget build(BuildContext context) {
    final activePhoto = _photos[_activeView];
    final stepNumber = MangoView.values.indexOf(_activeView) + 1;
    final capturedCount = _photos.length;
    final total = MangoView.values.length;

    final String captureLabel;
    if (activePhoto != null) {
      captureLabel = 'Retake ${_activeView.label} Photo';
    } else if (cameraSelected) {
      captureLabel = 'Take ${_activeView.label} Photo';
    } else {
      captureLabel = 'Choose ${_activeView.label} Photo';
    }

    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Scan Mango',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (_photos.isNotEmpty)
                      TextButton.icon(
                        onPressed: pickingImage ? null : _startOver,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Start over'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 430,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: AppColors.camera),
                        ),
                        if (activePhoto != null)
                          Positioned.fill(
                            child: Image.file(
                              File(activePhoto.path),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text(
                                  'Could not preview this image',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          )
                        else ...[
                          Container(
                            width: 290,
                            height: 290,
                            decoration: BoxDecoration(
                              color: const Color(0xFF244F31),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          const MangoIllustration(width: 190, height: 225),
                        ],
                        if (activePhoto == null)
                          Positioned.fill(
                            child: CustomPaint(painter: _ScanFramePainter()),
                          ),
                        Positioned(
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Step $stepNumber of $total • '
                              '${_activeView.label.toUpperCase()} VIEW',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 18,
                          left: 20,
                          right: 20,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _allCaptured
                                    ? 'All 3 photos captured • ready to upload'
                                    : activePhoto != null
                                        ? '${_activeView.label} photo captured'
                                        : _activeView.instruction,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (final view in MangoView.values) ...[
                              if (view != MangoView.values.first)
                                const SizedBox(width: 10),
                              Expanded(
                                child: _ViewSlot(
                                  view: view,
                                  photo: _photos[view],
                                  active: view == _activeView,
                                  onTap: pickingImage
                                      ? null
                                      : () =>
                                          setState(() => _activeView = view),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SourceTab(
                                  label: 'Camera',
                                  selected: cameraSelected,
                                  onTap: () =>
                                      setState(() => cameraSelected = true),
                                ),
                              ),
                              Expanded(
                                child: _SourceTab(
                                  label: 'Gallery',
                                  selected: !cameraSelected,
                                  onTap: () =>
                                      setState(() => cameraSelected = false),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tips for best results',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 7),
                              Text(
                                '• Take all 3 photos of the same mango\n'
                                '• Use adequate lighting\n'
                                '• Capture the entire mango\n'
                                '• Avoid blurry images\n'
                                '• Use a plain background when possible',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed:
                                pickingImage ? null : _chooseCurrentSource,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.green,
                              side: const BorderSide(color: AppColors.green),
                            ),
                            icon: pickingImage
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(cameraSelected
                                    ? Icons.camera_alt_rounded
                                    : Icons.photo_library_rounded),
                            label: Text(
                              captureLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _allCaptured && !pickingImage
                                ? _analyze
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text(
                              _allCaptured
                                  ? 'Analyze Mango (3 photos)'
                                  : 'Capture all views ($capturedCount/$total)',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your 3 photos will be checked for quality and '
                          'graded by the MangGrade model on the server.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
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
    );
  }
}

/// One of the three Front / Back / Top tiles under the preview.
class _ViewSlot extends StatelessWidget {
  final MangoView view;
  final XFile? photo;
  final bool active;
  final VoidCallback? onTap;

  const _ViewSlot({
    required this.view,
    required this.photo,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final captured = photo != null;

    return Material(
      color: active ? AppColors.greenSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.green : AppColors.border,
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: captured
                      ? Image.file(
                          File(photo!.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : const ColoredBox(
                          color: AppColors.white,
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (captured) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    view.label,
                    style: TextStyle(
                      color:
                          active ? AppColors.green : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SourceTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.green : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 10),
      width: 300,
      height: 300,
    );
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const l = 34.0;
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(l, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, l), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-l, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, l), paint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft + const Offset(l, 0), paint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft + const Offset(0, -l), paint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight + const Offset(-l, 0), paint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight + const Offset(0, -l), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
