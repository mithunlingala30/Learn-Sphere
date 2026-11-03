import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Two partial orbits and one planet: the Learn Sphere mark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(color),
      );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.width;
    final stroke = s * 0.1;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;

    final outer = s * 0.42;
    final inner = s * 0.24;
    canvas.drawArc(Rect.fromCircle(center: c, radius: outer), -math.pi / 2,
        math.pi * 1.5, false, paint);
    canvas.drawArc(Rect.fromCircle(center: c, radius: inner), math.pi / 2,
        math.pi * 1.2, false, paint..color = color.tint(0.6));

    const end = -math.pi / 2 + math.pi * 1.5;
    final p = c + Offset(math.cos(end), math.sin(end)) * outer;
    canvas.drawCircle(p, stroke * 0.95, Paint()..color = LS.marigold);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.color != color;
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.color = Colors.white, this.size = 22});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(size: size * 1.4, color: color),
          const SizedBox(width: 10),
          Text('Learn Sphere', style: display(size, color: color, letterSpacing: -0.3)),
        ],
      );
}
