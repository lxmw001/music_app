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
              ? Icons.volume_mute_rounded
              : value < 0.5
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
          color: Colors.white54,
          size: 20,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value,
              onChanged: (v) {
                if ((v - value).abs() > 0.1) {
                  HapticFeedback.selectionClick();
                }
                onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
