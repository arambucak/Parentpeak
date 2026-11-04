import 'dart:math' as math;

import 'package:flutter/material.dart';

class FamilyIllustration extends StatelessWidget {
  const FamilyIllustration({
    super.key,
    required this.childCount,
    this.familyForm,
  }) : assert(childCount >= 0);

  final int childCount;
  final String? familyForm;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: FamilyIllustrationPainter(
          childCount: childCount,
          familyForm: familyForm,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class FamilyIllustrationPainter extends CustomPainter {
  const FamilyIllustrationPainter({
    required this.childCount,
    this.familyForm,
  }) : assert(childCount >= 0);

  static const adultYellow = Color(0xFFF4AA20);
  static const adultRed = Color(0xFFE85B45);
  static const childGreen = Color(0xFF5A9B48);

  final int childCount;
  final String? familyForm;

  // The wizard stores a family form, not an adult count. Other forms,
  // including custom/unknown values, use a neutral two-adult illustration.
  int get adultCount =>
      familyForm?.trim().toLowerCase() == 'alleinerziehend' ? 1 : 2;

  @override
  void paint(Canvas canvas, Size size) {
    final naturalWidth = adultCount * 62.0 + childCount * 42.0;
    final scale = math.min(
      1.15,
      math.min(size.width / (naturalWidth + 40), size.height / 150),
    );
    final left = (size.width - naturalWidth * scale) / 2;
    final baseline = size.height / 2 + 57 * scale;
    var cursor = left;

    void figure(double slot, double height, Color color) {
      final width = (slot - 12) * scale;
      final h = height * scale;
      final x = cursor + slot * scale / 2;
      final y = baseline - h;
      final paint = Paint()..color = color;
      canvas.drawCircle(Offset(x, y + h * 0.13), width * 0.23, paint);
      final body = Path()
        ..moveTo(x - width * 0.28, y + h * 0.34)
        ..quadraticBezierTo(
          x - width * 0.58,
          y + h * 0.39,
          x - width * 0.48,
          y + h * 0.58,
        )
        ..quadraticBezierTo(
          x - width * 0.42,
          y + h * 0.63,
          x - width * 0.32,
          y + h * 0.52,
        )
        ..lineTo(x - width * 0.22, y + h * 0.94)
        ..quadraticBezierTo(
          x - width * 0.16,
          y + h * 1.02,
          x - width * 0.08,
          y + h * 0.95,
        )
        ..lineTo(x, y + h * 0.72)
        ..lineTo(x + width * 0.08, y + h * 0.95)
        ..quadraticBezierTo(
          x + width * 0.16,
          y + h * 1.02,
          x + width * 0.22,
          y + h * 0.94,
        )
        ..lineTo(x + width * 0.32, y + h * 0.52)
        ..quadraticBezierTo(
          x + width * 0.42,
          y + h * 0.63,
          x + width * 0.48,
          y + h * 0.58,
        )
        ..quadraticBezierTo(
          x + width * 0.58,
          y + h * 0.39,
          x + width * 0.28,
          y + h * 0.34,
        )
        ..quadraticBezierTo(
          x,
          y + h * 0.28,
          x - width * 0.28,
          y + h * 0.34,
        )
        ..close();
      canvas.drawPath(body, paint);
      cursor += slot * scale;
    }

    figure(62, 112, adultYellow);
    for (var i = 0; i < childCount; i++) {
      figure(42, 74, childGreen);
    }
    if (adultCount == 2) figure(62, 112, adultRed);
  }

  @override
  bool shouldRepaint(FamilyIllustrationPainter oldDelegate) =>
      oldDelegate.childCount != childCount ||
      oldDelegate.adultCount != adultCount;
}
