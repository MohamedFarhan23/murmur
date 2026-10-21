import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../audio/wav.dart';
import '../transcription/word.dart';

class Note {
  Note({
    required this.id,
    required this.title,
    required this.created,
    required this.seconds,
    required this.words,
    required this.hasAudio,
  });

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        created: DateTime.parse(json['created'] as String),
        seconds: (json['seconds'] as num).toDouble(),
        words: [
          for (final w in json['words'] as List)
            wordFromJson(w as Map<String, dynamic>)
        ],
        hasAudio: json['hasAudio'] as bool,
      );

  final String id;
  String title;
  final DateTime created;
  final double seconds;
  List<Word> words;
  final bool hasAudio;

  String get text => words.map((w) => w.text).join(' ');

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'created': created.toIso8601String(),
        'seconds': seconds,
        'words': [for (final w in words) wordToJson(w)],
        'hasAudio': hasAudio,
      };
}

/// Saved notes, newest first: one JSON file each, plus a WAV when the user
/// chose to keep the audio. Everything stays in the app's private storage.
class NoteStore extends ChangeNotifier {
  NoteStore._(this._dir, this._notes);

  final Directory _dir;
  final List<Note> _notes;

  static Future<NoteStore> load() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/notes');
    await dir.create(recursive: true);
    final notes = <Note>[];
    await for (final file in dir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        notes.add(Note.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>));
      }
    }
    notes.sort((a, b) => b.created.compareTo(a.created));
    return NoteStore._(dir, notes);
  }

  List<Note> get notes => List.unmodifiable(_notes);

  File audioFile(Note note) => File('${_dir.path}/${note.id}.wav');

  Future<Note> create({
    required String title,
    required List<Word> words,
    required double seconds,
    Int16List? audio,
  }) async {
    final now = DateTime.now();
    final note = Note(
      id: '${now.microsecondsSinceEpoch}',
      title: title,
      created: now,
      seconds: seconds,
      // Without the audio, timings point at nothing.
      words: audio == null
          ? [for (final w in words) (text: w.text, probability: w.probability, start: noTime, end: noTime)]
          : List.of(words),
      hasAudio: audio != null,
    );
    if (audio != null) await audioFile(note).writeAsBytes(encodeWav(audio));
    await _write(note);
    _notes.insert(0, note);
    notifyListeners();
    return note;
  }

  /// Saves changes to [note]'s title or words.
  Future<void> update(Note note) async {
    await _write(note);
    notifyListeners();
  }

  Future<void> delete(Note note) async {
    _notes.remove(note);
    notifyListeners();
    await File('${_dir.path}/${note.id}.json').delete();
    final audio = audioFile(note);
    if (await audio.exists()) await audio.delete();
  }

  Future<void> _write(Note note) async {
    // Write then rename, so a crash mid-write never leaves a broken note.
    final file = File('${_dir.path}/${note.id}.json');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(note.toJson()));
    await temp.rename(file.path);
  }
}
