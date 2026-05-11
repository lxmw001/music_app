import 'dart:math';
import 'package:flutter/material.dart';

class MeshGradient extends StatefulWidget {
  final Color color;
  const MeshGradient({super.key, required this.color});

  @override
  State<MeshGradient> createState() => _MeshGradientState();
}

class _MeshGradientState extends State<MeshGradient> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _MeshPainter(
            color: widget.color,
            t: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _MeshPainter extends CustomPainter {
  final Color color;
  final double t;

  _MeshPainter({required this.color, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    // Multiple moving glowing orbs to create a mesh feel
    final orbs = [
      _Orb(
        center: Offset(
          size.width * (0.5 + 0.4 * sin(t * 2 * pi)),
          size.height * (0.3 + 0.2 * cos(t * 2 * pi)),
        ),
        radius: size.width * 0.8,
        opacity: 0.15,
      ),
      _Orb(
        center: Offset(
          size.width * (0.2 + 0.3 * cos(t * 2 * pi + 1)),
          size.height * (0.7 + 0.2 * sin(t * 2 * pi + 1)),
        ),
        radius: size.width * 0.6,
        opacity: 0.12,
      ),
      _Orb(
        center: Offset(
          size.width * (0.8 + 0.2 * sin(t * 4 * pi)),
          size.height * (0.5 + 0.3 * cos(t * 2 * pi)),
        ),
        radius: size.width * 0.7,
        opacity: 0.1,
      ),
    ];

    for (final orb in orbs) {
      paint.color = color.withValues(alpha: orb.opacity);
      canvas.drawCircle(orb.center, orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Orb {
  final Offset center;
  final double radius;
  final double opacity;
  _Orb({required this.center, required this.radius, required this.opacity});
}
