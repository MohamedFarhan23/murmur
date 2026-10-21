import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/wav.dart';
import 'engine/whistle_engine.dart';

const _modelAsset = 'assets/models/whistle.cact';
const _sampleAsset = 'assets/samples/sample.wav';

void main() => runApp(const MurmurApp());

class MurmurApp extends StatelessWidget {
  const MurmurApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Murmur',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
            useMaterial3: true),
        home: const BenchmarkPage(),
      );
}

/// Step 3 check: the engine runs inside the app, off the UI isolate, on a
/// bundled clip. Live mic input comes in step 4.
class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  WhistleEngine? _engine;
  final _log = <String>[];
  bool _running = false;

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  void _say(String line) => setState(() => _log.add(line));

  Future<void> _run() async {
    setState(() {
      _running = true;
      _log.clear();
    });
    try {
      final clock = Stopwatch()..start();
      if (_engine == null) {
        final model = await rootBundle.load(_modelAsset);
        _engine = await WhistleEngine.start(model.buffer.asUint8List());
        _say('Model loaded in ${clock.elapsedMilliseconds} ms');
      }
      final engine = _engine!;
      final pcm = decodeWav((await rootBundle.load(_sampleAsset)).buffer.asUint8List());
      final seconds = pcm.length / whistleSampleRate;
      _say('Sample: ${seconds.toStringAsFixed(1)} s of audio\n');

      clock.reset();
      final full = await engine.transcribe(pcm);
      _say('FULL  ${clock.elapsedMilliseconds} ms '
          '(ttft ${full['ttft_ms']} ms, ${full['decode_tps']} tok/s)\n'
          '"${full['text']}"\n');

      _say('STREAM (1 s chunks)');
      final committed = <String>[];
      for (var at = 0; at < pcm.length; at += whistleSampleRate) {
        final end = (at + whistleSampleRate).clamp(0, pcm.length);
        final r = await engine.streamProcess(pcm.sublist(at, end));
        if ((r['text'] as String).isNotEmpty) committed.add(r['text'] as String);
        _say('${r['received']} s  pass ${r['pass_ms']} ms  '
            '${committed.join(' ')} [${r['pending']}]');
      }
      final tail = await engine.streamStop();
      if ((tail['text'] as String).isNotEmpty) committed.add(tail['text'] as String);
      _say('\nStreamed: "${committed.join(' ')}"');
    } catch (error) {
      _say('Error: $error');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Murmur · engine check')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final line in _log)
              SelectableText(line,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _running ? null : _run,
          icon: _running
              ? const SizedBox.square(
                  dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow),
          label: Text(_running ? 'Running…' : 'Run'),
        ),
      );
}
