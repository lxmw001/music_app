import 'dart:math';
import 'package:flutter/material.dart';

class FloatingParticles extends StatefulWidget {
  final Color color;
  const FloatingParticles({super.key, required this.color});

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = List.generate(20, (_) => _Particle());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
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
          painter: _ParticlePainter(particles: _particles, color: widget.color, progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  double x = Random().nextDouble();
  double y = Random().nextDouble();
  double size = Random().nextDouble() * 4 + 2;
  double speed = Random().nextDouble() * 0.05 + 0.02;
  double drift = Random().nextDouble() * 0.2 - 0.1;
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;
  final double progress;

  _ParticlePainter({required this.particles, required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    for (final p in particles) {
      final currentY = (p.y - (progress * p.speed)) % 1.0;
      final currentX = (p.x + (sin(progress * 2 * pi) * p.drift)) % 1.0;
      
      paint.color = color.withValues(alpha: 0.15 * (1.0 - currentY)); // Fade out as they go up
      canvas.drawCircle(
        Offset(currentX * size.width, currentY * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
