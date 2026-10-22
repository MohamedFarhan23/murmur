import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/chime.dart';
import '../audio/clip_player.dart';
import '../engine/whistle_engine.dart';
import '../notes/draft_store.dart';
import '../notes/note_store.dart';
import '../suggest/sounds_like.dart';
import '../suggest/suggester.dart';
import '../transcription/live_transcriber.dart';
import '../transcription/vocabulary.dart';
import 'mic_button.dart';
import 'logo.dart';
import 'note_page.dart';
import 'notes_page.dart';
import 'save_note_dialog.dart';
import 'text_size.dart';
import 'toast.dart';
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
    required this.textSize,
  });

  final WhistleEngine engine;
  final Vocabulary vocabulary;
  final Suggester suggester;
  final NoteStore notes;
  final DraftStore drafts;
  final TextSize textSize;

  @override
  State<TranscribePage> createState() => _TranscribePageState();
}

class _TranscribePageState extends State<TranscribePage> {
  late final _transcriber = LiveTranscriber(widget.engine, widget.vocabulary)
    ..addListener(_onChange)
    ..onPhraseFinalized = HapticFeedback.selectionClick
    ..beforeListening = (() async {
      HapticFeedback.mediumImpact();
      await _chime.start();
      await Future<void>.delayed(Chime.length);
    })
    ..afterListening = _chime.stop;
  final _chime = Chime();
  final _scroll = ScrollController();
  final _clip = ClipPlayer();
  bool _busy = false;
  bool _copied = false;
  Timer? _copiedReset;
  int? _editing; // word whose fix sheet is open
  int _savedRevision = 0;
  // Hold to talk: the mic starts on press; held past _holdDelay, release stops.
  static const _holdDelay = Duration(milliseconds: 400);
  Timer? _holdTimer;
  bool _holding = false;
  bool _pressStartedRecording = false;
  Future<void>? _starting;

  @override
  void initState() {
    super.initState();
    final draft = widget.drafts.restored;
    if (draft.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transcriber.loadDraft(draft);
      showToast(context, 'Restored the transcript you hadn’t saved');
    });
  }

  @override
  void dispose() {
    _copiedReset?.cancel();
    _holdTimer?.cancel();
    _transcriber.dispose();
    _scroll.dispose();
    _clip.dispose();
    _chime.dispose();
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
      } else if (!await _transcriber.start() && mounted) {
        showToast(context, 'Allow microphone access to start transcribing.');
      }
    } finally {
      _busy = false;
    }
  }

  void _pressDown() {
    _pressStartedRecording = !_transcriber.isRecording;
    if (!_pressStartedRecording) return; // a tap while recording stops it
    // Start right away, so the first words aren't lost to the hold delay.
    _starting = _toggle();
    _holdTimer = Timer(_holdDelay, () => setState(() => _holding = true));
  }

  Future<void> _pressUp() async {
    _holdTimer?.cancel();
    if (!_pressStartedRecording) return _toggle();
    if (!_holding) return; // a tap: keep listening
    setState(() => _holding = false);
    await _starting;
    if (_transcriber.isRecording) await _toggle();
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
    showToast(context, 'Saved “${note.title}”',
        actionLabel: 'View', onAction: () => _open(note));
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
    _discard('Started a new note');
  }

  /// Empties the transcript and its audio without saving, offering Undo.
  void _discard(String message) {
    final t = _transcriber;
    final cleared = t.clear();
    HapticFeedback.lightImpact();
    if (cleared.words.isEmpty) return;
    showToast(context, message,
        actionLabel: 'Undo', onAction: () => t.restore(cleared));
  }

  void _open(Note note) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotePage(
              note: note,
              store: widget.notes,
              vocabulary: widget.vocabulary,
              suggester: widget.suggester,
              textSize: widget.textSize),
        ),
      );

  void _openNotes() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotesPage(
              store: widget.notes,
              vocabulary: widget.vocabulary,
              suggester: widget.suggester,
              textSize: widget.textSize),
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
        showToast(context, 'Removed “${word.text}”',
            actionLabel: 'Undo', onAction: () => t.insertWord(index, word));
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
        ? (_holding
            ? 'Release to stop'
            : t.isSpeaking
                ? 'Hearing you'
                : 'Listening…')
        : hasText
            ? 'Paused · tap to continue'
            : 'Tap, or hold to talk';

    return Scaffold(
      appBar: AppBar(
        title: Logo(height: 32, color: colors.onSurface),
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
            tooltip: _copied ? 'Copied' : 'Copy',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  key: ValueKey(_copied)),
            ),
            onPressed: !t.isRecording && hasText ? _copy : null,
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
      body: PinchToResize(
        size: widget.textSize,
        child: SingleChildScrollView(
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
      ),
      // In the bottom bar, so toasts float above the controls.
      bottomNavigationBar: SafeArea(
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
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                            begin: const Offset(0, 0.4), end: Offset.zero)
                        .animate(animation),
                    child: child,
                  ),
                ),
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
                    icon: Icons.delete_outline_rounded,
                    label: 'Clear',
                    destructive: true,
                    onPressed: () => _discard('Cleared'),
                  ),
                  MicButton(
                    recording: t.isRecording,
                    speaking: t.isSpeaking,
                    level: t.level,
                    onPressed: _toggle,
                    onPressDown: _pressDown,
                    onPressUp: _pressUp,
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
    );
  }

  static String _clock(double seconds) {
    final s = seconds.floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// Clear and Save, beside the mic; they appear only once there's something
/// to act on and recording has stopped.
class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.visible,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final bool visible;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Tinted red, for actions that throw something away.
  final bool destructive;

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
                  style: destructive
                      ? IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.error.withValues(alpha: 0.16),
                          foregroundColor: theme.colorScheme.error)
                      : null,
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
