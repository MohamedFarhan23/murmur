import 'package:flutter/material.dart';

/// Fades [child] in and lifts it into place when it first appears, after
/// [delay]; staggering the delay makes a list cascade in.
class EntranceTransition extends StatefulWidget {
  const EntranceTransition({
    super.key,
    this.delay = Duration.zero,
    this.enabled = true,
    required this.child,
  });

  final Duration delay;

  /// When false, [child] simply appears; e.g. for list items scrolled into
  /// view after the list's first appearance.
  final bool enabled;
  final Widget child;

  @override
  State<EntranceTransition> createState() => _EntranceTransitionState();
}

class _EntranceTransitionState extends State<EntranceTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  late final _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
  }
}
