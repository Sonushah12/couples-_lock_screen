import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class TogetherScene extends StatelessWidget {
  const TogetherScene({super.key, required this.names, required this.days});
  final String names;
  final int days;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppColors.ink,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: SkyPainter())),
              const Positioned(
                top: 20,
                left: 20,
                child: Text(
                  'OUR LITTLE UNIVERSE',
                  style: TextStyle(
                    color: AppColors.peach,
                    letterSpacing: 2,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    const Icon(
                      Icons.nightlight_round,
                      color: AppColors.peach,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        names,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          color: const Color(0xFF382B4B),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(
                '$days',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.peach,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'days of us\nAnd so many more to come.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
              ),
              const Icon(Icons.auto_awesome_outlined, color: AppColors.peach),
            ],
          ),
        ),
        ],
      ),
    ),
  );
}

class _Star {
  const _Star(this.xRatio, this.y, this.radius, this.alpha);
  final double xRatio;
  final double y;
  final double radius;
  final double alpha;
}

class SkyPainter extends CustomPainter {
  const SkyPainter();

  static final List<_Star> _stars = () {
    final r = Random(42);
    return List<_Star>.generate(
      38,
      (i) => _Star(
        r.nextDouble(),
        38 + r.nextDouble() * 105,
        i % 7 == 0 ? 2 : 1,
        0.3 + r.nextDouble() * 0.6,
      ),
      growable: false,
    );
  }();

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint();
    for (final star in _stars) {
      p.color = Colors.white.withValues(alpha: star.alpha);
      canvas.drawCircle(Offset(star.xRatio * s.width, star.y), star.radius, p);
    }
    p.color = AppColors.peach;
    canvas.drawCircle(Offset(s.width * .75, 73), 25, p);
    p.color = AppColors.ink;
    canvas.drawCircle(Offset(s.width * .75 - 10, 65), 24, p);
    final path = Path()
      ..moveTo(0, 153)
      ..quadraticBezierTo(s.width * .25, 100, s.width * .53, 157)
      ..quadraticBezierTo(s.width * .78, 110, s.width, 141)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    p.color = const Color(0xFF594660);
    canvas.drawPath(path, p);
    p.color = const Color(0xFFAD8294);
    for (final x in [.44, .54]) {
      canvas.drawCircle(Offset(s.width * x, 130), 8, p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.width * x - 7, 140, 14, 22),
          const Radius.circular(6),
        ),
        p,
      );
    }
    p.strokeWidth = 3;
    canvas.drawLine(
      Offset(s.width * .44 + 6, 149),
      Offset(s.width * .54 - 6, 149),
      p,
    );
  }

  @override
  bool shouldRepaint(SkyPainter oldDelegate) => false;
}
