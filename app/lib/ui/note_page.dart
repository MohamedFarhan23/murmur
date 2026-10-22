import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/clip_player.dart';
import '../audio/wav.dart';
import '../engine/whistle_engine.dart';
import '../notes/note_store.dart';
import '../suggest/sounds_like.dart';
import '../suggest/suggester.dart';
import '../transcription/vocabulary.dart';
import '../transcription/word.dart';
import 'notes_page.dart';
import 'text_size.dart';
import 'toast.dart';
import 'transcript_view.dart';
import 'word_sheet.dart';

/// One saved note: read, fix words, rename, copy, delete, and play it back
/// with the spoken word highlighted.
class NotePage extends StatefulWidget {
  const NotePage({
    super.key,
    required this.note,
    required this.store,
    required this.vocabulary,
    required this.suggester,
    required this.textSize,
  });

  final Note note;
  final NoteStore store;
  final Vocabulary vocabulary;
  final Suggester suggester;
  final TextSize textSize;

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final _player = AudioPlayer();
  final _clip = ClipPlayer();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  int? _editing;

  Note get _note => widget.note;

  @override
  void initState() {
    super.initState();
    if (!_note.hasAudio) return;
    _subscriptions.addAll([
      _player.onPositionChanged.listen((p) => setState(() => _position = p)),
      _player.onDurationChanged.listen((d) => setState(() => _duration = d)),
      _player.onPlayerStateChanged.listen(
          (s) => setState(() => _playing = s == PlayerState.playing)),
      _player.onPlayerComplete
          .listen((_) => setState(() => _position = Duration.zero)),
    ]);
    _player.setSource(DeviceFileSource(widget.store.audioFile(_note).path));
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    _clip.dispose();
    super.dispose();
  }

  /// The word being spoken during playback.
  int? get _speaking {
    if (!_playing && _position == Duration.zero) return null;
    final t = _position.inMilliseconds / 1000;
    for (final (i, w) in _note.words.indexed) {
      if (w.hasTime && t >= w.start && t <= w.end + 0.1) return i;
    }
    return null;
  }

  Future<void> _togglePlay() async {
    HapticFeedback.selectionClick();
    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _hear(Word word) async {
    await _player.pause();
    const pad = 0.15;
    final start = ((word.start - pad) * WhistleEngine.sampleRate).round();
    final end = ((word.end + pad) * WhistleEngine.sampleRate).round();
    await _clip.play(await readWavSamples(
        widget.store.audioFile(_note), start, end - start));
  }

  Future<void> _fixWord(int index) async {
    final word = _note.words[index];
    HapticFeedback.selectionClick();
    setState(() => _editing = index);
    final fix = await showWordSheet(
      context,
      word: word,
      suggestions: widget.suggester
          .suggest(word.text, custom: widget.vocabulary.words),
      onHear: _note.hasAudio && word.hasTime ? () => _hear(word) : null,
    );
    if (!mounted) return;
    setState(() => _editing = null);
    final words = List<Word>.of(_note.words);
    switch (fix) {
      case ReplaceWord(:final text, :final remember):
        words[index] = (
          text: matchShape(word.text, text),
          probability: 1,
          start: word.start,
          end: word.end,
        );
        if (remember) await widget.vocabulary.add(text);
      case RemoveWord():
        words.removeAt(index);
      case null:
        return;
    }
    _note.words = words;
    await widget.store.update(_note);
    if (mounted) setState(() {});
  }

  Future<void> _rename() async {
    final field = TextEditingController(text: _note.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename note'),
        content: TextField(
          controller: field,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, field.text),
              child: const Text('Rename')),
        ],
      ),
    );
    field.dispose();
    if (title == null || title.trim().isEmpty) return;
    _note.title = title.trim();
    await widget.store.update(_note);
    if (mounted) setState(() {});
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _note.text));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    showToast(context, 'Copied');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Text(_note.hasAudio
            ? 'Its text and audio will be deleted from this phone.'
            : 'Its text will be deleted from this phone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _player.stop();
    HapticFeedback.mediumImpact();
    await widget.store.delete(_note);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = _duration.inMilliseconds > 0
        ? _duration
        : Duration(milliseconds: (_note.seconds * 1000).round());

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _rename,
          child: Text(_note.title, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          IconButton(
              tooltip: 'Copy',
              onPressed: _copy,
              icon: const Icon(Icons.copy_rounded)),
          PopupMenuButton<VoidCallback>(
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(value: _rename, child: const Text('Rename')),
              PopupMenuItem(value: _delete, child: const Text('Delete')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  '${formatDate(_note.created)} · ${formatClock(_note.seconds)}',
                  style: theme.textTheme.labelMedium!
                      .copyWith(color: colors.outline)),
            ),
          ),
          Expanded(
            child: PinchToResize(
              size: widget.textSize,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ValueListenableBuilder(
                    valueListenable: widget.textSize,
                    builder: (context, scale, _) => TranscriptView(
                      scale: scale,
                      words: _note.words,
                      pending: '',
                      placeholder: 'This note is empty.',
                      selectable: true,
                      onWordTap: _fixWord,
                      highlighted: _editing ?? _speaking,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_note.hasAudio)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 24, 12),
                child: Row(
                  children: [
                    IconButton.filled(
                      iconSize: 32,
                      tooltip: _playing ? 'Pause' : 'Play',
                      onPressed: _togglePlay,
                      icon: Icon(_playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                    ),
                    Expanded(
                      child: Slider(
                        value: _position.inMilliseconds
                            .clamp(0, total.inMilliseconds)
                            .toDouble(),
                        max: total.inMilliseconds.toDouble().clamp(1, double.infinity),
                        onChanged: (v) => _player
                            .seek(Duration(milliseconds: v.round())),
                      ),
                    ),
                    Text(
                      formatClock(_position.inMilliseconds / 1000),
                      style: theme.textTheme.labelLarge!.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
