import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/clip_player.dart';
import '../engine/whistle_engine.dart';
import '../notes/draft_store.dart';
import '../notes/note_store.dart';
import '../suggest/sounds_like.dart';
import '../suggest/suggester.dart';
import '../transcription/live_transcriber.dart';
import '../transcription/vocabulary.dart';
import 'mic_button.dart';
import 'note_page.dart';
import 'notes_page.dart';
import 'save_note_dialog.dart';
import 'transcript_view.dart';
import 'vocabulary_page.dart';
import 'word_sheet.dart';

class TranscribePage extends StatefulWidget {
  const TranscribePage({
    super.key,
    required this.engine,
    required this.vocabulary,
    required this.suggester,
    required this.notes,
    required this.drafts,
  });

  final WhistleEngine engine;
  final Vocabulary vocabulary;
  final Suggester suggester;
  final NoteStore notes;
  final DraftStore drafts;

  @override
  State<TranscribePage> createState() => _TranscribePageState();
}

class _TranscribePageState extends State<TranscribePage> {
  late final _transcriber = LiveTranscriber(widget.engine, widget.vocabulary)
    ..addListener(_onChange)
    ..onPhraseFinalized = HapticFeedback.selectionClick;
  final _scroll = ScrollController();
  final _clip = ClipPlayer();
  bool _busy = false;
  bool _copied = false;
  Timer? _copiedReset;
  int? _editing; // word whose fix sheet is open
  int _savedRevision = 0;

  @override
  void initState() {
    super.initState();
    final draft = widget.drafts.restored;
    if (draft.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transcriber.loadDraft(draft);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Restored the transcript you hadn’t saved')));
    });
  }

  @override
  void dispose() {
    _copiedReset?.cancel();
    _transcriber.dispose();
    _scroll.dispose();
    _clip.dispose();
    super.dispose();
  }

  void _onChange() {
    final t = _transcriber;
    if (t.revision != _savedRevision) {
      _savedRevision = t.revision;
      // Keep the unsaved transcript as a text-only draft; an empty or saved
      // one leaves no draft behind.
      widget.drafts.save(t.dirty ? t.words : const []);
    }
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

  Future<void> _save() async {
    final t = _transcriber;
    final choice = await showSaveNoteDialog(context,
        suggestedTitle: titleFrom(t.text),
        audioSeconds: t.hasAudio ? t.seconds : null);
    if (choice == null || !mounted) return;
    final note = await widget.notes.create(
      title: choice.title,
      words: t.words,
      seconds: t.seconds,
      audio: choice.keepAudio ? t.audio : null,
    );
    t.clear();
    await widget.drafts.clear();
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Saved “${note.title}”'),
        action: SnackBarAction(label: 'View', onPressed: () => _open(note)),
      ));
  }

  /// Starts a fresh note, first offering to save unsaved changes.
  Future<void> _newNote() async {
    final t = _transcriber;
    if (t.dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save this note first?'),
          content: const Text('Starting a new note clears the current one.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, 'discard'),
                child: const Text('Discard')),
            FilledButton(
                onPressed: () => Navigator.pop(context, 'save'),
                child: const Text('Save')),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'save') return _save();
    }
    final cleared = t.clear();
    HapticFeedback.lightImpact();
    if (cleared.words.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Started a new note'),
        action: SnackBarAction(label: 'Undo', onPressed: () => t.restore(cleared)),
      ));
  }

  void _open(Note note) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotePage(
              note: note,
              store: widget.notes,
              vocabulary: widget.vocabulary,
              suggester: widget.suggester),
        ),
      );

  void _openNotes() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotesPage(
              store: widget.notes,
              vocabulary: widget.vocabulary,
              suggester: widget.suggester),
        ),
      );

  void _openVocabulary() => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VocabularyPage(vocabulary: widget.vocabulary)),
      );

  Future<void> _fixWord(int index) async {
    final t = _transcriber;
    final word = t.words[index];
    HapticFeedback.selectionClick();
    setState(() => _editing = index);
    final fix = await showWordSheet(
      context,
      word: word,
      suggestions:
          widget.suggester.suggest(word.text, custom: widget.vocabulary.words),
      onHear: t.hasAudio && word.hasTime
          ? () => _clip.play(t.audioBetween(word.start - 0.15, word.end + 0.15))
          : null,
    );
    if (!mounted) return;
    setState(() => _editing = null);
    // The transcript may have been cleared while the sheet was open.
    if (index >= t.words.length || t.words[index] != word) return;
    switch (fix) {
      case ReplaceWord(:final text, :final remember):
        t.replaceWord(index, matchShape(word.text, text));
        if (remember) await widget.vocabulary.add(text);
      case RemoveWord():
        t.removeWord(index);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Removed “${word.text}”'),
            action: SnackBarAction(
                label: 'Undo', onPressed: () => t.insertWord(index, word)),
          ));
      case null:
    }
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
              padding: const EdgeInsets.only(right: 8),
              child: ValueListenableBuilder(
                valueListenable: t.elapsed,
                builder: (context, seconds, _) => Text(_clock(seconds),
                    style: theme.textTheme.titleMedium!.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: t.isRecording ? colors.error : colors.outline)),
              ),
            ),
          ),
          IconButton(
            tooltip: 'New note',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: !t.isRecording && hasText ? _newNote : null,
          ),
          IconButton(
            tooltip: 'Notes',
            icon: const Icon(Icons.library_books_outlined),
            onPressed: _openNotes,
          ),
          PopupMenuButton<VoidCallback>(
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: _openVocabulary, child: const Text('Custom words')),
            ],
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
                  onWordTap: _fixWord,
                  highlighted: _editing,
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
                        icon: Icons.save_alt_rounded,
                        label: 'Save',
                        onPressed: _save,
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
