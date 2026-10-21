import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine/whistle_engine.dart';
import 'ui/transcribe_page.dart';

const _modelAsset = 'assets/models/whistle.cact';

void main() => runApp(const MurmurApp());

class MurmurApp extends StatefulWidget {
  const MurmurApp({super.key});

  @override
  State<MurmurApp> createState() => _MurmurAppState();
}

class _MurmurAppState extends State<MurmurApp> {
  final _engine = rootBundle
      .load(_modelAsset)
      .then((model) => WhistleEngine.start(model.buffer.asUint8List()));

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Murmur',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
            useMaterial3: true),
        home: FutureBuilder(
          future: _engine,
          builder: (context, engine) => switch (engine) {
            AsyncSnapshot(:final data?) => TranscribePage(engine: data),
            AsyncSnapshot(:final error?) => Scaffold(
                body: Center(child: Text('Could not load the model:\n$error'))),
            _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
          },
        ),
      );
}
