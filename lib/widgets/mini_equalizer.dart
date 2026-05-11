import 'package:flutter/material.dart';

class MiniEqualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  const MiniEqualizer({super.key, required this.isPlaying, required this.color});

  @override
  State<MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<MiniEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MiniEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(0.4 + 0.6 * _controller.value),
            const SizedBox(width: 2),
            _bar(1.0 - 0.5 * _controller.value),
            const SizedBox(width: 2),
            _bar(0.7 + 0.3 * (1 - _controller.value)),
          ],
        );
      },
    );
  }

  Widget _bar(double heightFactor) {
    return Container(
      width: 3,
      height: 14 * heightFactor,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
