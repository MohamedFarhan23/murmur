import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../transcription/word.dart';

/// The unsaved transcript, kept as text only so that a crash or a closed app
/// doesn't lose it. The audio is never written until the user saves a note.
class DraftStore {
  DraftStore._(this._file, this.restored);

  final File _file;
  Timer? _pending;

  /// The draft found at startup, empty if there was none.
  final List<Word> restored;

  static Future<DraftStore> open() async {
    final file =
        File('${(await getApplicationSupportDirectory()).path}/draft.json');
    var words = <Word>[];
    if (await file.exists()) {
      try {
        words = [
          for (final w in jsonDecode(await file.readAsString()) as List)
            wordFromJson(w as Map<String, dynamic>)
        ];
      } on FormatException {
        // A draft cut off mid-write; nothing to restore.
      }
    }
    return DraftStore._(file, words);
  }

  /// Saves [words] shortly, coalescing bursts of changes into one write.
  void save(List<Word> words) {
    _pending?.cancel();
    final snapshot = [
      for (final w in words)
        wordToJson((text: w.text, probability: w.probability, start: noTime, end: noTime))
    ];
    _pending = Timer(const Duration(milliseconds: 500), () async {
      if (snapshot.isEmpty) {
        if (await _file.exists()) await _file.delete();
      } else {
        await _file.writeAsString(jsonEncode(snapshot));
      }
    });
  }

  Future<void> clear() async {
    _pending?.cancel();
    if (await _file.exists()) await _file.delete();
  }
}
