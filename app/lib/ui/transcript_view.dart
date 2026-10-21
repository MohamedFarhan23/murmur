import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../transcription/live_transcriber.dart';

/// Words below this probability get a dotted underline: the model was unsure.
const lowConfidence = 0.6;

const _fadeIn = Duration(milliseconds: 280);

/// The transcript: committed words fade in as they arrive, unsure words are
/// underlined, and the pending tail is dimmed.
class TranscriptView extends StatefulWidget {
  const TranscriptView({
    super.key,
    required this.words,
    required this.pending,
    required this.placeholder,
    required this.selectable,
  });

  final List<Word> words;
  final String pending;
  final String placeholder;
  final bool selectable;

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView>
    with SingleTickerProviderStateMixin {
  final _clock = Stopwatch()..start();
  // When each word, by index, first appeared.
  final _appearedAt = <int>[];
  late final Ticker _ticker = createTicker((_) {
    if (_animating) {
      setState(() {});
    } else {
      _ticker.stop();
    }
  });

  bool get _animating =>
      _appearedAt.isNotEmpty &&
      _clock.elapsedMilliseconds - _appearedAt.last < _fadeIn.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _track();
  }

  @override
  void didUpdateWidget(TranscriptView old) {
    super.didUpdateWidget(old);
    _track();
  }

  void _track() {
    final count = widget.words.length;
    if (count < _appearedAt.length) _appearedAt.removeRange(count, _appearedAt.length);
    final now = _clock.elapsedMilliseconds;
    while (_appearedAt.length < count) {
      _appearedAt.add(now);
    }
    if (_animating && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = theme.textTheme.headlineSmall!
        .copyWith(height: 1.45, color: colors.onSurface);
    final animate = !MediaQuery.disableAnimationsOf(context);
    final now = _clock.elapsedMilliseconds;

    if (widget.words.isEmpty && widget.pending.isEmpty) {
      return Text(widget.placeholder, style: base.copyWith(color: colors.outline));
    }

    final spans = <InlineSpan>[
      for (final (i, word) in widget.words.indexed)
        TextSpan(
          text: i == 0 ? word.text : ' ${word.text}',
          style: TextStyle(
            color: colors.onSurface.withValues(
                alpha: animate
                    ? Curves.easeOut.transform(
                        ((now - _appearedAt[i]) / _fadeIn.inMilliseconds)
                            .clamp(0.0, 1.0))
                    : 1),
            decoration: word.probability < lowConfidence
                ? TextDecoration.underline
                : null,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: colors.tertiary,
            decorationThickness: 2,
          ),
        ),
      if (widget.pending.isNotEmpty)
        TextSpan(
          text: widget.words.isEmpty ? widget.pending : ' ${widget.pending}',
          style: TextStyle(color: colors.outline),
        ),
    ];
    final text = Text.rich(TextSpan(style: base, children: spans));
    return widget.selectable ? SelectionArea(child: text) : text;
  }
}
