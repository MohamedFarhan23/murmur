import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../notes/note_store.dart';
import '../suggest/suggester.dart';
import '../transcription/vocabulary.dart';
import 'entrance.dart';
import 'note_page.dart';
import 'toast.dart';

/// Saved notes, newest first. Long-press a note to select several, then copy
/// or delete them together.
class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    required this.store,
    required this.vocabulary,
    required this.suggester,
  });

  final NoteStore store;
  final Vocabulary vocabulary;
  final Suggester suggester;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _selected = <String>{}; // note ids
  final _opened = Stopwatch()..start();

  bool get _selecting => _selected.isNotEmpty;

  List<Note> get _selectedNotes =>
      [for (final n in widget.store.notes) if (_selected.contains(n.id)) n];

  void _toggle(Note note) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(note.id)) _selected.add(note.id);
    });
  }

  void _open(Note note) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotePage(
              note: note,
              store: widget.store,
              vocabulary: widget.vocabulary,
              suggester: widget.suggester),
        ),
      );

  void _selectAll() => setState(
      () => _selected.addAll([for (final n in widget.store.notes) n.id]));

  Future<void> _copy() async {
    final notes = _selectedNotes;
    await Clipboard.setData(ClipboardData(
        text: [for (final n in notes) '${n.title}\n${n.text}'].join('\n\n')));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(_selected.clear);
    showToast(context,
        notes.length == 1 ? 'Copied 1 note' : 'Copied ${notes.length} notes');
  }

  Future<void> _delete() async {
    final notes = _selectedNotes;
    final count = notes.length == 1 ? '1 note' : '${notes.length} notes';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count?'),
        content: const Text(
            'Their text and any audio will be deleted from this phone.'),
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
    HapticFeedback.mediumImpact();
    for (final note in notes) {
      await widget.store.delete(note);
    }
    if (!mounted) return;
    setState(_selected.clear);
    showToast(context, 'Deleted $count');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(_selected.clear))
              : null,
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
                _selecting ? '${_selected.length} selected' : 'Notes',
                key: ValueKey(_selecting ? _selected.length : -1)),
          ),
          backgroundColor: _selecting ? colors.surfaceContainerHigh : null,
          actions: _selecting
              ? [
                  if (_selected.length < widget.store.notes.length)
                    IconButton(
                        tooltip: 'Select all',
                        icon: const Icon(Icons.select_all_rounded),
                        onPressed: _selectAll),
                  IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: _copy),
                  IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: _delete),
                ]
              : null,
        ),
        body: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final notes = widget.store.notes;
            if (notes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notes_rounded, size: 48, color: colors.outline),
                      const SizedBox(height: 12),
                      Text('No saved notes yet',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Record something, then tap Save.',
                          style: TextStyle(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 24),
              itemBuilder: (context, i) {
                final note = notes[i];
                final selected = _selected.contains(note.id);
                return EntranceTransition(
                  key: ValueKey(note.id),
                  delay: Duration(milliseconds: 40 * i),
                  // Only the first screenful cascades in.
                  enabled: _opened.elapsedMilliseconds < 400,
                  child: ListTile(
                    selected: selected,
                    selectedTileColor: colors.secondaryContainer,
                    selectedColor: colors.onSecondaryContainer,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    leading: _selecting ? _SelectMark(selected: selected) : null,
                    title: Text(note.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.text,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                            '${formatDate(note.created)} · ${formatClock(note.seconds)}',
                            style: theme.textTheme.labelSmall!
                                .copyWith(color: colors.outline)),
                      ],
                    ),
                    trailing: note.hasAudio
                        ? Icon(Icons.graphic_eq_rounded,
                            color: colors.primary, semanticLabel: 'Has audio')
                        : null,
                    onTap: () => _selecting ? _toggle(note) : _open(note),
                    onLongPress: () => _toggle(note),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The check circle beside each note while selecting.
class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          selected
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          key: ValueKey(selected),
          color: selected ? colors.primary : colors.outline,
        ),
      ),
    );
  }
}

String formatClock(double seconds) {
  final s = seconds.floor();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime t) {
  final now = DateTime.now();
  final time = '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  if (day == today) return 'Today $time';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday $time';
  final date = '${t.day} ${_months[t.month - 1]}';
  return t.year == now.year ? '$date, $time' : '$date ${t.year}';
}
