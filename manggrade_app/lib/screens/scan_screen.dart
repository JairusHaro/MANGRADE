import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/mango_illustration.dart';

class ScanScreen extends StatefulWidget {
  final ValueChanged<String?> onAnalyze;

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
  XFile? selectedImage;
  bool pickingImage = false;

  Future<void> _pickImage(ImageSource source) async {
    if (pickingImage) return;
    setState(() => pickingImage = true);
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (image != null) {
        setState(() => selectedImage = image);
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

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(
              height: 56,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Scan Mango',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
                        if (selectedImage != null)
                          Positioned.fill(
                            child: Image.file(
                              File(selectedImage!.path),
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
                        if (selectedImage == null)
                          Positioned.fill(
                            child: CustomPaint(painter: _ScanFramePainter()),
                          ),
                        Positioned(
                          bottom: 18,
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
                              selectedImage == null
                                  ? 'Choose a photo to begin'
                                  : 'Image selected • ready to upload',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
                              selectedImage == null
                                  ? (cameraSelected
                                      ? 'Take Photo'
                                      : 'Choose from Gallery')
                                  : 'Retake / Choose Another Image',
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
                            onPressed: selectedImage == null
                                ? null
                                : () => widget.onAnalyze(selectedImage!.path),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: const Text(
                              'Analyze Mango Image',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your image will be uploaded for validation. '
                          'Mango grading will be available once the trained model is connected.',
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
