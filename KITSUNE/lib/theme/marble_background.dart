import 'dart:math';
import 'package:flutter/material.dart';
import 'marble_theme.dart';

class MarbleBackground extends StatelessWidget {
  const MarbleBackground({super.key, required this.child, required this.dark});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: dark ? MarbleColors.charcoal : MarbleColors.paper),
        CustomPaint(painter: _VeinPainter(dark: dark)),
        child,
      ],
    );
  }
}

class _VeinPainter extends CustomPainter {
  _VeinPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(7);
    for (var i = 0; i < 14; i++) {
      final path = Path();
      var x = size.width * random.nextDouble();
      var y = -20.0;
      path.moveTo(x, y);
      while (y < size.height + 40) {
        x += sin(y / 70 + i) * 18 + (random.nextDouble() - 0.5) * 10;
        y += 16;
        path.lineTo(x, y);
      }
      final paint = Paint()
        ..color = (dark ? MarbleColors.vein : const Color(0xFF8A8A8A))
            .withValues(alpha: dark ? 0.18 : 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 + random.nextDouble() * 1.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawPath(path, paint);
    }
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [Colors.white.withValues(alpha: 0.04), Colors.black.withValues(alpha: 0.25)]
            : [Colors.white.withValues(alpha: 0.35), const Color(0xFFB0B0B0).withValues(alpha: 0.12)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
