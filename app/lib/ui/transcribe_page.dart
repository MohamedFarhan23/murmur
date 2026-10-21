import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/whistle_engine.dart';
import '../transcription/live_transcriber.dart';
import 'mic_button.dart';
import 'transcript_view.dart';

class TranscribePage extends StatefulWidget {
  const TranscribePage({super.key, required this.engine});

  final WhistleEngine engine;

  @override
  State<TranscribePage> createState() => _TranscribePageState();
}

class _TranscribePageState extends State<TranscribePage> {
  late final _transcriber = LiveTranscriber(widget.engine)
    ..addListener(_onChange)
    ..onPhraseFinalized = HapticFeedback.selectionClick;
  final _scroll = ScrollController();
  bool _busy = false;
  bool _copied = false;
  Timer? _copiedReset;

  @override
  void dispose() {
    _copiedReset?.cancel();
    _transcriber.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    // Follow new words only if the reader is already at the end.
    final following =
        !_scroll.hasClients || _scroll.position.extentAfter < 48;
    setState(() {});
    if (!following) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;
    try {
      if (_transcriber.isRecording) {
        HapticFeedback.mediumImpact();
        await _transcriber.stop();
      } else if (await _transcriber.start()) {
        HapticFeedback.mediumImpact();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Allow microphone access to start transcribing.')));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _transcriber.text));
    HapticFeedback.lightImpact();
    _copiedReset?.cancel();
    setState(() => _copied = true);
    _copiedReset = Timer(const Duration(milliseconds: 1600),
        () => mounted ? setState(() => _copied = false) : null);
  }

  void _clear() {
    final cleared = _transcriber.clear();
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Transcript cleared'),
        action: SnackBarAction(
            label: 'Undo', onPressed: () => _transcriber.restore(cleared)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final t = _transcriber;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasText = t.words.isNotEmpty;
    final showActions = !t.isRecording && hasText;

    final status = t.isRecording
        ? (t.isSpeaking ? 'Hearing you' : 'Listening…')
        : hasText
            ? 'Paused · tap to continue'
            : 'Tap to start';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Murmur'),
        actions: [
          AnimatedOpacity(
            opacity: t.isRecording || hasText ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: ValueListenableBuilder(
                valueListenable: t.elapsed,
                builder: (context, seconds, _) => Text(_clock(seconds),
                    style: theme.textTheme.titleMedium!.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: t.isRecording ? colors.error : colors.outline)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: TranscriptView(
                  words: t.words,
                  pending: t.pending,
                  placeholder: t.isRecording
                      ? 'Start speaking…'
                      : 'Your words will appear here.',
                  selectable: !t.isRecording,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text('${t.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error)),
                    ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(status,
                        key: ValueKey(status),
                        style: theme.textTheme.labelLarge!
                            .copyWith(color: colors.onSurfaceVariant)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SideAction(
                        visible: showActions,
                        icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                        label: _copied ? 'Copied' : 'Copy',
                        onPressed: _copy,
                      ),
                      MicButton(
                        recording: t.isRecording,
                        speaking: t.isSpeaking,
                        level: t.level,
                        onPressed: _toggle,
                      ),
                      _SideAction(
                        visible: showActions,
                        icon: Icons.delete_outline_rounded,
                        label: 'Clear',
                        onPressed: _clear,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _clock(double seconds) {
    final s = seconds.floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// Copy and Clear, beside the mic; they appear only once there's something
/// to act on and recording has stopped.
class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.visible,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool visible;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 88,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: AnimatedScale(
            scale: visible ? 1 : 0.85,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  onPressed: onPressed,
                  iconSize: 26,
                  padding: const EdgeInsets.all(14),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(icon, key: ValueKey(icon)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: theme.textTheme.labelMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
