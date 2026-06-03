import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VolumeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final Color activeColor;

  const VolumeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          value == 0
              ? Icons.volume_off_rounded
              : value < 0.5
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
          color: Colors.white.withValues(alpha: 0.5),
          size: 22,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4, // Thicker, premium track
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
                elevation: 4,
                pressedElevation: 8,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                boxShadow: [
                  // Subtle glow around the slider area
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Slider(
                value: value,
                onChanged: (v) {
                  // Haptic "ticks" for volume steps
                  if ((v * 10).round() != (value * 10).round()) {
                    HapticFeedback.lightImpact();
                  }
                  onChanged(v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
