import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../transcription/live_transcriber.dart';
import 'transcript_view.dart';

/// What the user chose to do with a tapped word.
sealed class WordFix {
  const WordFix();
}

class ReplaceWord extends WordFix {
  const ReplaceWord(this.text, {required this.remember});
  final String text;

  /// Add [text] to the custom vocabulary.
  final bool remember;
}

class RemoveWord extends WordFix {
  const RemoveWord();
}

/// Shows the fix sheet for [word]; [suggestions] resolves to words that sound
/// like it. [onHear], when given, plays the word's audio.
Future<WordFix?> showWordSheet(BuildContext context,
        {required Word word,
        required Future<List<String>> suggestions,
        VoidCallback? onHear}) =>
    showModalBottomSheet<WordFix>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _WordSheet(word: word, suggestions: suggestions, onHear: onHear),
    );

class _WordSheet extends StatefulWidget {
  const _WordSheet(
      {required this.word, required this.suggestions, this.onHear});

  final Word word;
  final Future<List<String>> suggestions;
  final VoidCallback? onHear;

  @override
  State<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<_WordSheet> {
  late final _field = TextEditingController(text: _bare(widget.word.text));
  bool _remember = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  static String _bare(String word) =>
      word.replaceAll(RegExp(r"^[^\w']+|[^\w']+$"), '');

  void _replace(String text) {
    if (text.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.pop(context, ReplaceWord(text.trim(), remember: _remember));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final percent = (widget.word.probability * 100).round();
    final unsure = widget.word.probability < lowConfidence;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.word.text,
                    style: theme.textTheme.headlineMedium),
              ),
              if (widget.onHear case final hear?)
                IconButton.filledTonal(
                  tooltip: 'Hear it',
                  onPressed: hear,
                  icon: const Icon(Icons.volume_up_rounded),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            unsure
                ? 'Murmur wasn’t sure about this word ($percent%)'
                : 'Confidence $percent%',
            style: theme.textTheme.bodyMedium!.copyWith(
                color: unsure ? colors.tertiary : colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Text('Did you mean', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: FutureBuilder(
              future: widget.suggestions,
              builder: (context, snapshot) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (snapshot) {
                  AsyncSnapshot(:final data?) when data.isNotEmpty => ListView(
                      key: const ValueKey('chips'),
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final s in data)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                                label: Text(s), onPressed: () => _replace(s)),
                          ),
                      ],
                    ),
                  AsyncSnapshot(hasData: true) || AsyncSnapshot(hasError: true) =>
                    Align(
                      key: const ValueKey('none'),
                      alignment: Alignment.centerLeft,
                      child: Text('No similar words found',
                          style: TextStyle(color: colors.outline)),
                    ),
                  _ => Align(
                      key: const ValueKey('loading'),
                      alignment: Alignment.centerLeft,
                      child: Text('Finding similar words…',
                          style: TextStyle(color: colors.outline)),
                    ),
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _field,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Correct it',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _replace,
          ),
          CheckboxListTile(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v!),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Remember this word'),
            subtitle: const Text('Murmur will listen for it next time'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, const RemoveWord());
                },
                icon: const Icon(Icons.backspace_outlined),
                label: const Text('Remove word'),
                style: TextButton.styleFrom(foregroundColor: colors.error),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _replace(_field.text),
                child: const Text('Replace'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
