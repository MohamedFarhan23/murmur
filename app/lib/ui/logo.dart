import 'package:flutter/material.dart';

/// The Murmur mark from the launcher icon (branding/legacy.svg): lips whose
/// sound becomes a wave, with two sparkles. Drawn in [color], which defaults
/// to the ambient icon colour.
class Logo extends StatelessWidget {
  const Logo({super.key, this.height = 24, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? IconTheme.of(context).color!;
    return Semantics(
      label: 'Murmur',
      image: true,
      child: CustomPaint(
        size: Size(height * _bounds.width / _bounds.height, height),
        painter: _LogoPainter(color),
      ),
    );
  }
}

// The art's extent in the SVG's 512-unit space, stroke included, padded
// below so the box is centred on the lips and wave (y 288) rather than on
// the art's outline: the sparkles above shouldn't push the lips down.
const _bounds = Rect.fromLTRB(55, 114, 466, 288 + (288 - 114));
const _stroke = 18.0;

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _bounds.height;
    canvas
      ..scale(scale)
      ..translate(-_bounds.left, -_bounds.top + 26); // the SVG's translate(0 26)

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    final lips = Path()
      ..moveTo(64, 262)
      ..cubicTo(86, 240, 104, 214, 124, 212)
      ..cubicTo(136, 211, 146, 220, 152, 226)
      ..cubicTo(158, 220, 168, 211, 180, 212)
      ..cubicTo(200, 214, 218, 240, 240, 262)
      ..cubicTo(220, 304, 190, 320, 152, 320)
      ..cubicTo(114, 320, 84, 304, 64, 262)
      ..close();

    final wave = Path()
      ..moveTo(64, 262)
      ..cubicTo(110, 278, 196, 278, 240, 262);
    var x = 240.0;
    for (final peak in [238, 302, 198, 350, 190, 310, 234, 274]) {
      wave.quadraticBezierTo(x + 13, peak.toDouble(), x + 26, 262);
      x += 26;
    }

    canvas
      ..drawPath(lips, line)
      ..drawPath(wave, line)
      ..drawPath(_sparkle(400, 128, 40, 4, 14), fill)
      ..drawPath(_sparkle(452, 177, 13, 1.5, 4), fill);
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
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}
