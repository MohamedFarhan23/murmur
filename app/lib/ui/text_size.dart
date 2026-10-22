import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// How large the transcript text is, as a multiple of the default; set by
/// pinching, and remembered.
class TextSize extends ValueNotifier<double> {
  TextSize._(this._file, super.value);

  static const min = 0.75;
  static const max = 2.0;

  final File _file;

  static Future<TextSize> load() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/text_size.json');
    var scale = 1.0;
    if (await file.exists()) {
      try {
        scale = (jsonDecode(await file.readAsString()) as num).toDouble();
      } on FormatException {
        // Keep the default.
      }
    }
    return TextSize._(file, scale.clamp(min, max));
  }

  Future<void> save() => _file.writeAsString(jsonEncode(value));
}

/// Pinch with two fingers on [child] to resize the text, as in Google
/// Messages. Watches raw pointers rather than joining the gesture arena, so
/// scrolling and tapping words keep working.
class PinchToResize extends StatefulWidget {
  const PinchToResize({super.key, required this.size, required this.child});

  final TextSize size;
  final Widget child;

  @override
  State<PinchToResize> createState() => _PinchToResizeState();
}

class _PinchToResizeState extends State<PinchToResize> {
  final _pointers = <int, Offset>{};
  double? _startSpan;
  double _startScale = 1;

  double get _span {
    final [a, b, ...] = _pointers.values.toList();
    return (a - b).distance;
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _startSpan = _span;
      _startScale = widget.size.value;
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _startSpan;
    if (start == null || start < 1 || _pointers.length < 2) return;
    final scale =
        (_startScale * _span / start).clamp(TextSize.min, TextSize.max);
    final size = widget.size;
    if (scale != size.value &&
        (scale == TextSize.min || scale == TextSize.max)) {
      HapticFeedback.selectionClick(); // reached a limit
    }
    size.value = scale;
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2 && _startSpan != null) {
      _startSpan = null;
      widget.size.save();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: widget.child,
      );
}
