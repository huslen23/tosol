import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2563EB);
  static const active = Color(0xFF1E40AF);
  static const light = Color(0xFFEFF6FF);
  static const background = Color(0xFFF8FAFC);
  static const text = Color(0xFF0F172A);
  static const secondaryText = Color(0xFF475569);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 34});
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _HouseMark()),
  );
}

class _HouseMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeJoin = StrokeJoin.miter;
    final path = Path()
      ..moveTo(size.width * .12, size.height * .40)
      ..lineTo(size.width * .5, size.height * .08)
      ..lineTo(size.width * .88, size.height * .40)
      ..lineTo(size.width * .88, size.height * .90)
      ..lineTo(size.width * .12, size.height * .90)
      ..close();
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.fill;
    for (final x in [.39, .53]) {
      for (final y in [.48, .63]) {
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * x,
            size.height * y,
            size.width * .1,
            size.height * .1,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
