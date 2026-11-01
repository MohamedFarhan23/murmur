import 'package:flutter/material.dart';

/// The Murmur mark from the launcher icon (branding/legacy.svg): lips whose
/// sound becomes a wave, with a sparkle. The lips are drawn in [color], which
/// defaults to the ambient icon colour, and the rest in [accent], which
/// defaults to the theme's primary colour.
class Logo extends StatelessWidget {
  const Logo({super.key, this.height = 24, this.color, this.accent});

  final double height;
  final Color? color;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? IconTheme.of(context).color!;
    final accent = this.accent ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Murmur',
      image: true,
      child: CustomPaint(
        size: Size(height * _bounds.width / _bounds.height, height),
        painter: _LogoPainter(color, accent),
      ),
    );
  }
}

// The art's extent in the SVG's 512-unit space, stroke included, padded
// below so the box is centred on the lips and wave (y 300) rather than on
// the art's outline: the sparkle above shouldn't push the lips down.
const _bounds = Rect.fromLTRB(85, 165, 428, 300 + (300 - 165));
const _stroke = 20.0;

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color, this.accent);

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _bounds.height;
    canvas
      ..scale(scale)
      ..translate(-_bounds.left, -_bounds.top);

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final lips = Path()
      ..moveTo(95, 299)
      ..cubicTo(111, 283.5, 124, 265, 138, 263.5)
      ..cubicTo(146.5, 262.5, 153.5, 269, 158, 273.5)
      ..cubicTo(162.5, 269, 169.5, 262.5, 178, 263.5)
      ..cubicTo(192, 265, 205, 283.5, 221, 299)
      ..cubicTo(206.5, 329, 185, 340.5, 158, 340.5)
      ..cubicTo(131, 340.5, 109.5, 329, 95, 299)
      ..close();

    // The mouth line, then a wave through each peak and trough in turn,
    // level at every one.
    final wave = Path()
      ..moveTo(95, 299)
      ..cubicTo(128, 310.5, 189.5, 310.5, 221, 299)
      ..cubicTo(227, 297, 229, 287.5, 235, 287.5);
    var from = const Offset(235, 287.5);
    for (final to in const [
      Offset(258.5, 316.5),
      Offset(282.5, 269),
      Offset(308, 339.5),
      Offset(332, 265),
      Offset(356, 320.5),
      Offset(380, 285.5),
      Offset(404, 304),
      Offset(418, 298.5),
    ]) {
      final mid = (from.dx + to.dx) / 2;
      wave.cubicTo(mid, from.dy, mid, to.dy, to.dx, to.dy);
      from = to;
    }

    canvas
      ..drawPath(lips, line)
      ..drawPath(wave, line..color = accent)
      ..drawPath(_sparkle(364.75, 203, 37.25, 3.7, 13), Paint()..color = accent);
  }

  /// A four-pointed sparkle centred on (cx, cy) with tips [r] away; each
  /// edge curves through (cx + p, cy - q) and (cx + q, cy - p), mirrored.
  static Path _sparkle(double cx, double cy, double r, double p, double q) =>
      Path()
        ..moveTo(cx, cy - r)
        ..cubicTo(cx + p, cy - q, cx + q, cy - p, cx + r, cy)
        ..cubicTo(cx + q, cy + p, cx + p, cy + q, cx, cy + r)
        ..cubicTo(cx - p, cy + q, cx - q, cy + p, cx - r, cy)
        ..cubicTo(cx - q, cy - p, cx - p, cy - q, cx, cy - r)
        ..close();

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.color != color || old.accent != accent;
}
