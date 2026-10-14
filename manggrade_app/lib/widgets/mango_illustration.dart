import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MangoIllustration extends StatelessWidget {
  final double width;
  final double height;

  const MangoIllustration({
    super.key,
    this.width = 160,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MangoPainter(),
      ),
    );
  }
}

class _MangoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 160;
    final sy = size.height / 190;
    canvas.save();
    canvas.scale(sx, sy);

    final mangoPath = Path()
      ..moveTo(70, 34)
      ..cubicTo(108, 25, 140, 47, 146, 81)
      ..cubicTo(156, 134, 117, 184, 74, 184)
      ..cubicTo(31, 184, 6, 150, 15, 106)
      ..cubicTo(23, 67, 40, 43, 70, 34)
      ..close();

    final mangoPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFE082),
          AppColors.mangoYellow,
          Color(0xFFC8A20A),
        ],
        stops: [0, 0.55, 1],
      ).createShader(const Rect.fromLTWH(10, 30, 140, 155));

    canvas.drawPath(mangoPath, mangoPaint);

    final shine = Paint()..color = const Color(0x66FFF4B8);
    canvas.drawOval(const Rect.fromLTWH(37, 45, 36, 62), shine);

    final stemPaint = Paint()
      ..color = const Color(0xFF5E4A21)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final stem = Path()
      ..moveTo(83, 33)
      ..cubicTo(79, 18, 85, 8, 99, 2);
    canvas.drawPath(stem, stemPaint);

    final leafPaint = Paint()..color = AppColors.green600;
    final leaf = Path()
      ..moveTo(93, 14)
      ..cubicTo(111, 0, 131, 4, 145, 18)
      ..cubicTo(125, 21, 110, 29, 98, 43)
      ..cubicTo(93, 34, 92, 24, 93, 14)
      ..close();
    canvas.drawPath(leaf, leafPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
