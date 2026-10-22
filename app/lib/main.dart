import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine/whistle_engine.dart';
import 'notes/draft_store.dart';
import 'notes/note_store.dart';
import 'suggest/suggester.dart';
import 'transcription/vocabulary.dart';
import 'ui/brand.dart';
import 'ui/text_size.dart';
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
    TextSize.load(),
  ).wait;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Murmur',
        theme: Brand.theme(Brightness.light),
        darkTheme: Brand.theme(Brightness.dark),
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
                final textSize,
              )
            ) =>
              TranscribePage(
                engine: engine,
                vocabulary: vocabulary,
                suggester: suggester,
                notes: notes,
                drafts: drafts,
                textSize: textSize,
              ),
            AsyncSnapshot(:final error?) => Scaffold(
                body: Center(child: Text('Murmur could not start:\n$error'))),
            _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
          },
        ),
      );
}
