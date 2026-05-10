import 'dart:math';
import 'package:flutter/material.dart';

class WaveformProgressBar extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final bool isPlaying;
  final ValueChanged<double>? onSeek;
  final Color color;

  const WaveformProgressBar({
    super.key,
    required this.progress,
    required this.isPlaying,
    this.onSeek,
    required this.color,
  });

  @override
  State<WaveformProgressBar> createState() => _WaveformProgressBarState();
}

class _WaveformProgressBarState extends State<WaveformProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(WaveformProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final x = details.localPosition.dx;
        final p = (x / box.size.width).clamp(0.0, 1.0);
        widget.onSeek?.call(p);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final x = details.localPosition.dx;
        final p = (x / box.size.width).clamp(0.0, 1.0);
        widget.onSeek?.call(p);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            height: 60,
            width: double.infinity,
            color: Colors.transparent,
            child: CustomPaint(
              painter: _WaveformPainter(
                progress: widget.progress,
                color: widget.color,
                isPlaying: widget.isPlaying,
                animationValue: _controller.value,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isPlaying;
  final double animationValue;

  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.isPlaying,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    const barWidth = 3.0;
    const gap = 2.0;
    final count = (size.width / (barWidth + gap)).floor();

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + gap);
      final normalizedX = i / count;
      
      // Dynamic height factor
      double heightFactor = 0.2 + 
          0.3 * sin(i * 0.2 + animationValue * 2 * pi) + 
          0.2 * cos(i * 0.5 - animationValue * pi);
      
      heightFactor = heightFactor.clamp(0.1, 1.0);
      final barHeight = size.height * heightFactor;
      
      paint.color = normalizedX <= progress 
          ? color 
          : color.withValues(alpha: 0.2);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + barWidth / 2, size.height / 2),
            width: barWidth,
            height: barHeight,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return true; // Re-paint on every animation frame
  }
}
