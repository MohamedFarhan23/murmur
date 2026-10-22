import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/share.dart';

/// Copy and Share, shown under a transcript.
class TranscriptActions extends StatefulWidget {
  const TranscriptActions({super.key, required this.text, this.subject});

  final String Function() text;

  /// A title for the shared text, e.g. the note's name.
  final String? subject;

  @override
  State<TranscriptActions> createState() => _TranscriptActionsState();
}

class _TranscriptActionsState extends State<TranscriptActions> {
  bool _copied = false;
  Timer? _copiedReset;

  @override
  void dispose() {
    _copiedReset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text()));
    HapticFeedback.lightImpact();
    _copiedReset?.cancel();
    setState(() => _copied = true);
    _copiedReset = Timer(const Duration(milliseconds: 1600),
        () => mounted ? setState(() => _copied = false) : null);
  }

  void _share() {
    HapticFeedback.selectionClick();
    shareText(widget.text(), subject: widget.subject);
  }

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _copy,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                  key: ValueKey(_copied), size: 18),
            ),
            label: Text(_copied ? 'Copied' : 'Copy'),
          ),
          FilledButton.tonalIcon(
            onPressed: _share,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share'),
          ),
        ],
      );
}
