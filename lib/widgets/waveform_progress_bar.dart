import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WaveformProgressBar extends StatefulWidget {
  final double progress; 
  final bool isPlaying;
  final ValueChanged<double>? onSeek;
  final Color color;
  final String songId;

  const WaveformProgressBar({
    super.key,
    required this.progress,
    required this.isPlaying,
    this.onSeek,
    required this.color,
    required this.songId,
  });

  @override
  State<WaveformProgressBar> createState() => _WaveformProgressBarState();
}

class _WaveformProgressBarState extends State<WaveformProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _baseHeights;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // Slow, cinematic cycle
    );
    _generateWaveform();
    if (widget.isPlaying) _controller.repeat();
  }

  void _generateWaveform() {
    final random = Random(widget.songId.hashCode);
    // 55 bars for a high-density "Elite" resolution
    _baseHeights = List.generate(55, (_) => 0.2 + random.nextDouble() * 0.6);
  }

  @override
  void didUpdateWidget(WaveformProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songId != oldWidget.songId) {
      _generateWaveform();
    }
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
        final p = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
        if ((p - widget.progress).abs() > 0.05) HapticFeedback.selectionClick();
        widget.onSeek?.call(p);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final p = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
        HapticFeedback.lightImpact();
        widget.onSeek?.call(p);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            height: 60,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CustomPaint(
              painter: _WaveformPainter(
                progress: widget.progress,
                color: widget.color,
                heights: _baseHeights,
                // Loop t ensure bit-identical start/end states by sampling a 2D circle
                t: _controller.value,
                isPlaying: widget.isPlaying,
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
  final List<double> heights;
  final double t; 
  final bool isPlaying;

  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.heights,
    required this.t,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final count = heights.length;
    final spacing = size.width / count;
    final barWidth = spacing * 0.55;

    // We use "Circular Sampling" to guarantee perfect seamless loops.
    // nx and ny rotate on a 2D circle as t goes 0 -> 1.
    final nx = cos(t * 2 * pi);
    final ny = sin(t * 2 * pi);

    for (int i = 0; i < count; i++) {
      final x = i * spacing + spacing / 2;
      final normalizedX = i / count;
      
      double h = heights[i];
      
      if (isPlaying) {
        // LIQUID DYNAMICS
        // Sample overlapping harmonic waves keyed to the circular path (nx, ny)
        final phase = i * 0.2;
        final wave = 0.15 * (sin(phase + nx * 1.5) + cos(phase * 0.5 + ny * 2.0));
        h = (h + wave).clamp(0.12, 1.0);
      }

      final isPlayed = normalizedX <= progress;
      final barHeight = size.height * h;

      // Track (Background)
      paint.color = color.withValues(alpha: 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, size.height / 2), width: barWidth, height: size.height * 0.7),
          const Radius.circular(2),
        ),
        paint,
      );

      // Played track (Foreground)
      if (isPlayed) {
        // Vertical glow gradient on bars
        final barRect = Rect.fromCenter(center: Offset(x, size.height / 2), width: barWidth, height: barHeight);
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.75), color, color.withValues(alpha: 0.75)],
        ).createShader(barRect);

        canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(3)), paint);
        paint.shader = null;

        // Subtle reflection for glass-floor look
        final reflectionPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.2), Colors.transparent],
          ).createShader(Rect.fromLTWH(x - barWidth/2, size.height * 0.8, barWidth, size.height * 0.2));
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - barWidth/2, size.height * 0.8, barWidth, barHeight * 0.2),
            const Radius.circular(1),
          ),
          reflectionPaint,
        );
      }
    }

    // THE LASER PLAYHEAD
    final playheadX = progress * size.width;
    
    // Playhead Glow Bloom
    final bloomPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(Offset(playheadX, size.height / 2), 16, bloomPaint);

    // Playhead Laser Vertical Line
    final laserPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(playheadX, size.height / 2), width: 2.2, height: size.height + 14),
        const Radius.circular(1.1),
      ),
      laserPaint,
    );
    
    // Solid Core
    paint.shader = null;
    paint.color = Colors.white;
    canvas.drawCircle(Offset(playheadX, size.height / 2), 3.5, paint);
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) => 
      isPlaying || oldDelegate.progress != progress;
}
