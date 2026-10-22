import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/chime.dart';
import '../engine/whistle_engine.dart';
import '../platform/launch.dart';
import '../transcription/live_transcriber.dart';
import '../transcription/vocabulary.dart';
import 'mic_button.dart';
import 'text_size.dart';
import 'transcript_view.dart';

/// Opened from the home-screen widget: listens straight away, and one tap
/// copies the text and steps out of the way. Uses its own transcriber, so the
/// main transcript and its draft are left alone.
class QuickTranscribePage extends StatefulWidget {
  const QuickTranscribePage({
    super.key,
    required this.engine,
    required this.vocabulary,
    required this.textSize,
  });

  final WhistleEngine engine;
  final Vocabulary vocabulary;
  final TextSize textSize;

  @override
  State<QuickTranscribePage> createState() => _QuickTranscribePageState();
}

class _QuickTranscribePageState extends State<QuickTranscribePage> {
  final _chime = Chime();
  late final _transcriber = LiveTranscriber(widget.engine, widget.vocabulary)
    ..addListener(_onChange)
    ..onPhraseFinalized = HapticFeedback.selectionClick
    ..beforeListening = (() async {
      HapticFeedback.mediumImpact();
      await _chime.start();
      await Future<void>.delayed(Chime.length);
    })
    ..afterListening = _chime.stop;
  final _scroll = ScrollController();
  bool _finishing = false;
  bool _copied = false;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final started = await _transcriber.start();
      if (!started && mounted) setState(() => _denied = true);
    });
  }

  @override
  void dispose() {
    _transcriber.dispose();
    _scroll.dispose();
    _chime.dispose();
    super.dispose();
  }

  void _onChange() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  /// Stops, copies whatever was said, and leaves.
  Future<void> _done() async {
    if (_finishing) return;
    _finishing = true;
    await _transcriber.stop();
    final text = _transcriber.text;
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
      HapticFeedback.lightImpact();
      if (mounted) setState(() => _copied = true);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    await _leave();
  }

  Future<void> _cancel() async {
    if (_finishing) return;
    _finishing = true;
    await _transcriber.stop();
    await _leave();
  }

  Future<void> _leave() async {
    if (!mounted) return;
    Navigator.pop(context);
    await moveToBack();
  }

  @override
  Widget build(BuildContext context) {
    final t = _transcriber;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = _denied
        ? 'Allow microphone access to transcribe.'
        : _copied
            ? 'Copied to clipboard'
            : t.isRecording
                ? 'Tap to stop and copy'
                : _finishing
                    ? 'Finishing…'
                    : 'Starting…';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close_rounded),
              onPressed: _cancel),
          title: const Text('Quick transcribe'),
        ),
        body: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: ValueListenableBuilder(
              valueListenable: widget.textSize,
              builder: (context, scale, _) => TranscriptView(
                scale: scale,
                words: t.words,
                pending: t.pending,
                placeholder: 'Start speaking…',
                selectable: false,
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(status,
                      key: ValueKey(status),
                      style: theme.textTheme.labelLarge!.copyWith(
                          color: _denied
                              ? colors.error
                              : colors.onSurfaceVariant)),
                ),
                MicButton(
                  recording: t.isRecording && !_copied,
                  speaking: t.isSpeaking,
                  level: t.level,
                  onPressed: t.isRecording ? _done : null,
                  onPressDown: null,
                  onPressUp: t.isRecording ? _done : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
