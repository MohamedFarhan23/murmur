import 'package:flutter/material.dart';

import '../transcription/vocabulary.dart';

/// The words Murmur has been taught: add, or swipe away.
class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key, required this.vocabulary});

  final Vocabulary vocabulary;

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _add(String word) async {
    await widget.vocabulary.add(word);
    _field.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Custom words')),
      body: ListenableBuilder(
        listenable: widget.vocabulary,
        builder: (context, _) {
          final words = widget.vocabulary.words;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  'Names, places and jargon Murmur should listen for. '
                  'They also come first in suggestions.',
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _field,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Add a word',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => _add(_field.text),
                    ),
                  ),
                  onSubmitted: _add,
                ),
              ),
              const SizedBox(height: 8),
              if (words.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No custom words yet.',
                      style: TextStyle(color: theme.colorScheme.outline)),
                ),
              for (final word in words.reversed)
                Dismissible(
                  key: ValueKey(word),
                  onDismissed: (_) => widget.vocabulary.remove(word),
                  background: Container(
                    color: theme.colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Icon(Icons.delete_outline_rounded,
                        color: theme.colorScheme.onErrorContainer),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(word),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => widget.vocabulary.remove(word),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
