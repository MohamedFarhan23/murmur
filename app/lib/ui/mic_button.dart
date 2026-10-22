import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The record/stop button. While recording it morphs from a circle to a
/// rounded square, rings ripple out from it, and a halo follows the voice
/// level, brightening while the VAD hears speech.
class MicButton extends StatefulWidget {
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
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  static const _morph = Duration(milliseconds: 280);
  static const _size = MicButton.size;

  late final _ripple = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    if (old.recording != widget.recording) _sync();
  }

  void _sync() {
    if (widget.recording) {
      _ripple.repeat();
    } else {
      _ripple.stop();
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recording = widget.recording;
    final animate = !MediaQuery.disableAnimationsOf(context);

    return SizedBox.square(
      dimension: _size * 1.6,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: recording ? colors.error : colors.primary),
        duration: _morph,
        builder: (context, fill, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (recording && animate)
              AnimatedBuilder(
                animation: _ripple,
                builder: (context, _) => CustomPaint(
                  size: const Size.square(_size * 1.6),
                  painter: _Ripples(
                    progress: _ripple.value,
                    color: fill!.withValues(alpha: widget.speaking ? 0.5 : 0.3),
                  ),
                ),
              ),
            ValueListenableBuilder(
              valueListenable: widget.level,
              builder: (context, level, _) => TweenAnimationBuilder<double>(
                tween: Tween(end: recording ? level : 0),
                duration: const Duration(milliseconds: 120),
                builder: (context, level, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _size * (1 + 0.5 * level),
                  height: _size * (1 + 0.5 * level),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill!.withValues(
                        alpha: widget.speaking ? 0.28 : 0.14),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: recording ? 'Stop recording' : 'Start recording',
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: recording ? 26 : _size / 2),
                duration: _morph,
                curve: Curves.easeOutCubic,
                builder: (context, radius, _) {
                  final shape = RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius));
                  return Material(
                    color: fill,
                    shape: shape,
                    elevation: recording ? 6 : 2,
                    child: InkWell(
                      customBorder: shape,
                      onTap: widget.onPressed,
                      child: SizedBox.square(
                        dimension: _size,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              RotationTransition(
                            turns: Tween(begin: -0.125, end: 0.0)
                                .animate(animation),
                            child: ScaleTransition(
                                scale: animation, child: child),
                          ),
                          child: Icon(
                            recording ? Icons.stop_rounded : Icons.mic_rounded,
                            key: ValueKey(recording),
                            size: 40,
                            color: recording
                                ? colors.onError
                                : colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two rings expanding from the button and fading out, half a cycle apart.
class _Ripples extends CustomPainter {
  _Ripples({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const inner = MicButton.size / 2;
    final outer = size.shortestSide / 2;
    for (final phase in [0.0, 0.5]) {
      final t = Curves.easeOut.transform((progress + phase) % 1);
      canvas.drawCircle(
        center,
        inner + (outer - inner) * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: color.a * pow(1 - t, 1.5)),
      );
    }
  }

  @override
  bool shouldRepaint(_Ripples old) =>
      old.progress != progress || old.color != color;
}
