import 'package:flutter/material.dart';

import '../engine/whistle_engine.dart';
import '../transcription/live_transcriber.dart';

class TranscribePage extends StatefulWidget {
  const TranscribePage({super.key, required this.engine});

  final WhistleEngine engine;

  @override
  State<TranscribePage> createState() => _TranscribePageState();
}

class _TranscribePageState extends State<TranscribePage> {
  late final _transcriber = LiveTranscriber(widget.engine)
    ..addListener(_onChange);
  final _scroll = ScrollController();

  @override
  void dispose() {
    _transcriber.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    setState(() {});
    // Keep the newest words in view as the transcript grows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _toggle() async {
    if (_transcriber.isRecording) {
      await _transcriber.stop();
    } else if (!await _transcriber.start() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Murmur needs the microphone to transcribe.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _transcriber;
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineSmall!.copyWith(height: 1.4);
    final empty = t.committed.isEmpty && t.pending.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Murmur'),
        actions: [
          if (t.isRecording)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${t.seconds.toStringAsFixed(0)} s',
                  style: theme.textTheme.titleMedium),
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 160),
        child: empty
            ? Text(
                t.isRecording ? 'Listening…' : 'Tap the mic and start speaking.',
                style: style.copyWith(color: theme.colorScheme.outline))
            : Text.rich(TextSpan(style: style, children: [
                TextSpan(text: t.committed),
                if (t.pending.isNotEmpty)
                  TextSpan(
                      text: '${t.committed.isEmpty ? '' : ' '}${t.pending}',
                      style: TextStyle(color: theme.colorScheme.outline)),
              ])),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('${t.error}',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          FloatingActionButton.large(
            onPressed: _toggle,
            backgroundColor: t.isRecording
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.primaryContainer,
            child: Icon(t.isRecording ? Icons.stop_rounded : Icons.mic_rounded),
          ),
        ],
      ),
    );
  }
}
