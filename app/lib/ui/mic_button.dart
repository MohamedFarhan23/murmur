import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The record/stop button, ringed by a halo that follows the voice level and
/// brightens while the VAD hears speech.
class MicButton extends StatelessWidget {
  const MicButton({
    super.key,
    required this.recording,
    required this.speaking,
    required this.level,
    required this.onPressed,
  });

  static const size = 88.0;

  final bool recording;
  final bool speaking;
  final ValueListenable<double> level;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = recording ? colors.error : colors.primary;
    final onFill = recording ? colors.onError : colors.onPrimary;

    return SizedBox.square(
      dimension: size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ValueListenableBuilder(
            valueListenable: level,
            builder: (context, level, _) => TweenAnimationBuilder<double>(
              tween: Tween(end: recording ? level : 0),
              duration: const Duration(milliseconds: 120),
              builder: (context, level, _) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size * (1 + 0.55 * level),
                height: size * (1 + 0.55 * level),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill.withValues(alpha: speaking ? 0.32 : 0.16),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: recording ? 'Stop recording' : 'Start recording',
            child: Material(
              color: fill,
              shape: const CircleBorder(),
              elevation: recording ? 6 : 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      recording ? Icons.stop_rounded : Icons.mic_rounded,
                      key: ValueKey(recording),
                      size: 40,
                      color: onFill,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
