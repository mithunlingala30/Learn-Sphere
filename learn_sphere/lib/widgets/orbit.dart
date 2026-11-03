import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/tokens.dart';

Color orbitColor(OrbitEntry e) {
  switch (e.state) {
    case LimitState.exceeded:
      return LS.rose;
    case LimitState.warning:
      return LS.marigold;
    default:
      return appColor(e.packageName);
  }
}

/// The signature element: every app is a planet on its own ring.
/// A ring fills as the app approaches its limit (or, with no limit, relative
/// to the most used app). The arcs sweep in once when the view first appears.
class OrbitView extends StatelessWidget {
  const OrbitView({
    super.key,
    required this.entries,
    required this.size,
    required this.centerValue,
    this.centerLabel = 'on screen today',
    this.dark = true,
    this.strokeFactor = 0.028,
    this.valueFactor = 0.14,
  });

  final List<OrbitEntry> entries;
  final double size;
  final String centerValue;
  final String centerLabel;
  final bool dark;
  final double strokeFactor; // ring thickness as a fraction of [size]
  final double valueFactor; // centre number size as a fraction of [size]

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : LS.ink;
    final muted = dark ? LS.onSpaceMuted : LS.slate;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1300),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              size: Size.square(size),
              painter: _OrbitPainter(entries, t, dark, strokeFactor),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                style: display(size * valueFactor, color: fg, letterSpacing: -1),
              ),
              const SizedBox(height: 2),
              Text(
                centerLabel,
                style: body((size * 0.05).clamp(11.0, 15.0).toDouble(), color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.entries, this.t, this.dark, this.strokeFactor);

  final List<OrbitEntry> entries;
  final double t;
  final bool dark;
  final double strokeFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final stroke = size.width * strokeFactor;
    final gap = stroke * 2.2;
    final outer = size.width / 2 - stroke * 1.6;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = dark ? LS.onSpace.tint(0.09) : LS.ink.tint(0.07);

    // Empty state: a single quiet ring.
    if (entries.isEmpty) {
      canvas.drawCircle(c, outer, track);
      return;
    }

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final r = outer - i * gap;
      if (r <= stroke) break;
      canvas.drawCircle(c, r, track);

      final frac = (e.fraction.clamp(0.0, 1.0).toDouble()) * t;
      if (frac <= 0.002) continue;

      final color = orbitColor(e);
      const start = -math.pi / 2;
      final sweep = frac * 2 * math.pi;

      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = color,
      );

      final a = start + sweep;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(
        p,
        stroke * 1.15,
        Paint()
          ..color = color.tint(0.38)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(p, stroke * 0.8, Paint()..color = color);
      canvas.drawCircle(
          p, stroke * 0.3, Paint()..color = dark ? LS.space : Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) =>
      old.t != t ||
      old.dark != dark ||
      old.strokeFactor != strokeFactor ||
      !identical(old.entries, entries);
}

/// Lists the rings from outermost to innermost.
class OrbitLegend extends StatelessWidget {
  const OrbitLegend({super.key, required this.entries, this.dark = true});

  final List<OrbitEntry> entries;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : LS.ink;
    final muted = dark ? LS.onSpaceMuted : LS.slate;
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: orbitColor(e), shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(15, weight: FontWeight.w500, color: fg),
                  ),
                ),
                if (e.state == LimitState.exceeded || e.state == LimitState.warning)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      e.state == LimitState.exceeded ? 'over' : 'close',
                      style: body(12, weight: FontWeight.w600, color: orbitColor(e)),
                    ),
                  ),
                Text(
                  fmtDuration(e.seconds),
                  style: body(15, weight: FontWeight.w600, color: muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
