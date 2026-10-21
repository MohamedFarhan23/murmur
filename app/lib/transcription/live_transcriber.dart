import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/mic.dart';
import '../engine/whistle_engine.dart';

/// Streams microphone audio through Whistle and exposes the transcript as it
/// forms: [committed] words are final, [pending] may still change.
class LiveTranscriber extends ChangeNotifier {
  LiveTranscriber(this._engine);

  final WhistleEngine _engine;
  final _mic = Mic();
  final _committed = <String>[];
  final _queued = <Float32List>[];
  int _queuedSamples = 0;
  StreamSubscription<Float32List>? _audio;
  // Engine calls run strictly one after another on this chain.
  Future<void> _work = Future.value();

  String pending = '';
  bool isRecording = false;
  double seconds = 0;
  Object? error;

  String get committed => _committed.join(' ');

  /// Starts listening; false if the microphone permission was refused.
  Future<bool> start() async {
    if (isRecording) return true;
    if (!await _mic.requestPermission()) return false;
    _committed.clear();
    pending = '';
    seconds = 0;
    error = null;
    _audio = (await _mic.start()).listen(_onAudio);
    isRecording = true;
    notifyListeners();
    return true;
  }

  /// Stops listening and commits whatever is still pending.
  Future<void> stop() async {
    if (!isRecording) return;
    isRecording = false;
    notifyListeners();
    await _audio?.cancel();
    await _mic.stop();
    if (_queuedSamples > 0) _enqueue(_drain());
    _work = _work.then((_) => _run(_engine.streamStop));
    await _work;
    pending = '';
    notifyListeners();
  }

  void _onAudio(Float32List samples) {
    _queued.add(samples);
    _queuedSamples += samples.length;
    // Whistle takes live audio about one second at a time.
    if (_queuedSamples >= WhistleEngine.sampleRate) _enqueue(_drain());
  }

  void _enqueue(Float32List chunk) =>
      _work = _work.then((_) => _run(() => _engine.streamProcess(chunk)));

  Future<void> _run(Future<NeedleResult> Function() call) async {
    try {
      final result = await call();
      final text = result['text'] as String;
      if (text.isNotEmpty) _committed.add(text);
      pending = result['pending'] as String;
      seconds = (result['received'] as num).toDouble();
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  Float32List _drain() {
    final chunk = Float32List(_queuedSamples);
    var at = 0;
    for (final part in _queued) {
      chunk.setAll(at, part);
      at += part.length;
    }
    _queued.clear();
    _queuedSamples = 0;
    return chunk;
  }

  @override
  void dispose() {
    _audio?.cancel();
    _mic.dispose();
    super.dispose();
  }
}
