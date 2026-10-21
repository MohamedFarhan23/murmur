import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine/whistle_engine.dart';
import 'notes/draft_store.dart';
import 'notes/note_store.dart';
import 'suggest/suggester.dart';
import 'transcription/vocabulary.dart';
import 'ui/transcribe_page.dart';

const _modelAsset = 'assets/models/whistle.cact';
const _wordsAsset = 'assets/words/english.txt';

void main() => runApp(const MurmurApp());

class MurmurApp extends StatefulWidget {
  const MurmurApp({super.key});

  @override
  State<MurmurApp> createState() => _MurmurAppState();
}

class _MurmurAppState extends State<MurmurApp> {
  final _ready = (
    rootBundle
        .load(_modelAsset)
        .then((model) => WhistleEngine.start(model.buffer.asUint8List())),
    Vocabulary.load(),
    rootBundle.loadString(_wordsAsset).then(Suggester.start),
    NoteStore.load(),
    DraftStore.open(),
  ).wait;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Murmur',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
            useMaterial3: true),
        home: FutureBuilder(
          future: _ready,
          builder: (context, ready) => switch (ready) {
            AsyncSnapshot(
              data: (
                final engine,
                final vocabulary,
                final suggester,
                final notes,
                final drafts,
              )
            ) =>
              TranscribePage(
                engine: engine,
                vocabulary: vocabulary,
                suggester: suggester,
                notes: notes,
                drafts: drafts,
              ),
            AsyncSnapshot(:final error?) => Scaffold(
                body: Center(child: Text('Murmur could not start:\n$error'))),
            _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
          },
        ),
      );
}
