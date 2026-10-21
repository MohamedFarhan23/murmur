import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Words the user taught Murmur. Whistle favours them through keyword
/// biasing, and suggestions offer them first.
class Vocabulary extends ChangeNotifier {
  Vocabulary._(this._file, this._words);

  final File _file;
  final List<String> _words;

  static Future<Vocabulary> load() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/vocabulary.json');
    final words = await file.exists()
        ? (jsonDecode(await file.readAsString()) as List).cast<String>()
        : <String>[];
    return Vocabulary._(file, words);
  }

  List<String> get words => List.unmodifiable(_words);

  /// Adds [word] without surrounding punctuation; no-op if already known.
  Future<void> add(String word) async {
    final clean = word.replaceAll(RegExp(r"^[^\w']+|[^\w']+$"), '');
    final known = _words.any((w) => w.toLowerCase() == clean.toLowerCase());
    if (clean.isEmpty || known) return;
    _words.add(clean);
    await _save();
  }

  Future<void> remove(String word) async {
    if (_words.remove(word)) await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    await _file.writeAsString(jsonEncode(_words));
  }
}
