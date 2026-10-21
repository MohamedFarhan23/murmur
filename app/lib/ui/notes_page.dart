import 'package:flutter/material.dart';

import '../notes/note_store.dart';
import '../suggest/suggester.dart';
import '../transcription/vocabulary.dart';
import 'note_page.dart';

/// Saved notes, newest first.
class NotesPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final notes = store.notes;
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
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                title: Text(note.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.text,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${formatDate(note.created)} · ${formatClock(note.seconds)}',
                        style: theme.textTheme.labelSmall!
                            .copyWith(color: colors.outline)),
                  ],
                ),
                trailing: note.hasAudio
                    ? Icon(Icons.graphic_eq_rounded,
                        color: colors.primary, semanticLabel: 'Has audio')
                    : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotePage(
                        note: note,
                        store: store,
                        vocabulary: vocabulary,
                        suggester: suggester),
                  ),
                ),
              );
            },
          );
        },
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
