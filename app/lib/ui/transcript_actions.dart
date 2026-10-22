import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/share.dart';

/// Copy and Share icons, shown under a transcript.
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
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    // Quiet icons; shifted left so the first lines up with the text.
    return Transform.translate(
      offset: const Offset(-8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: _copied ? 'Copied' : 'Copy',
            color: color,
            onPressed: _copy,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                  key: ValueKey(_copied), size: 20),
            ),
          ),
          IconButton(
            tooltip: 'Share',
            color: color,
            onPressed: _share,
            icon: const Icon(Icons.share_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
