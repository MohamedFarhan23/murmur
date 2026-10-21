import 'package:flutter/material.dart';

/// Asks for a title and whether to keep the audio; null if cancelled.
Future<({String title, bool keepAudio})?> showSaveNoteDialog(
  BuildContext context, {
  required String suggestedTitle,
  required double? audioSeconds,
}) =>
    showDialog(
      context: context,
      builder: (context) => _SaveNoteDialog(
          suggestedTitle: suggestedTitle, audioSeconds: audioSeconds),
    );

/// A title from the transcript's first few words.
String titleFrom(String text) {
  final words = text
      .replaceAll(RegExp(r"[^\w\s'-]"), '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(6)
      .join(' ');
  if (words.isEmpty) return 'Untitled note';
  return words[0].toUpperCase() + words.substring(1);
}

class _SaveNoteDialog extends StatefulWidget {
  const _SaveNoteDialog({required this.suggestedTitle, this.audioSeconds});

  final String suggestedTitle;

  /// Length of the audio that could be kept; null if there is none.
  final double? audioSeconds;

  @override
  State<_SaveNoteDialog> createState() => _SaveNoteDialogState();
}

class _SaveNoteDialogState extends State<_SaveNoteDialog> {
  late final _title = TextEditingController(text: widget.suggestedTitle)
    ..selection =
        TextSelection(baseOffset: 0, extentOffset: widget.suggestedTitle.length);
  bool _keepAudio = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    Navigator.pop(context, (
      title: title.isEmpty ? widget.suggestedTitle : title,
      keepAudio: _keepAudio && widget.audioSeconds != null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.audioSeconds;
    // 16 kHz, 16-bit mono WAV.
    final megabytes = seconds == null ? 0 : seconds * 32000 / 1e6;
    return AlertDialog(
      title: const Text('Save note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
                labelText: 'Title', border: OutlineInputBorder()),
            onSubmitted: (_) => _save(),
          ),
          if (seconds != null)
            SwitchListTile(
              value: _keepAudio,
              onChanged: (v) => setState(() => _keepAudio = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep the audio'),
              subtitle: Text('Replay the note later · '
                  '${megabytes < 0.1 ? '<0.1' : megabytes.toStringAsFixed(1)} MB'),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
