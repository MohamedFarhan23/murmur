import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../audio/mic.dart';
import '../audio/vad.dart';
import '../engine/whistle_engine.dart';
import 'speech_gate.dart';

/// Logs each phrase and engine result to logcat; build with
/// `--dart-define=MURMUR_DEBUG=true`.
const _debug = bool.fromEnvironment('MURMUR_DEBUG');

void _log(String Function() message) {
  if (_debug) debugPrint('MURMUR ${message()}');
}

/// Streams microphone speech through Whistle and exposes the transcript as it
/// forms: [committed] words are final, [pending] may still change.
///
/// A VAD keeps silence away from the model. Each pause ends the stream, which
/// commits the phrase and keeps the engine's re-transcribed buffer short.
class LiveTranscriber extends ChangeNotifier {
  LiveTranscriber(this._engine) {
    _gate = SpeechGate(
      frameSamples: Vad.frameSamples,
      isSpeech: (frame) {
        final speech = _vad.isSpeech(frame);
        if (speech) _speechFrames++;
        return speech;
      },
      onSpeech: _onSpeech,
      onPhraseEnd: _onPhraseEnd,
    );
  }

  final WhistleEngine _engine;
  final _mic = Mic();
  final _vad = Vad();
  late final SpeechGate _gate;
  final _committed = <String>[];
  final _queued = <Int16List>[];
  int _queuedSamples = 0;
  int _heardSamples = 0;
  int _speechFrames = 0;
  int _phraseSamples = 0;
  StreamSubscription<Int16List>? _audio;
  // Engine calls run strictly one after another on this chain.
  Future<void> _work = Future.value();

  String pending = '';
  bool isRecording = false;
  Object? error;

  String get committed => _committed.join(' ');
  double get seconds => _heardSamples / WhistleEngine.sampleRate;

  /// Starts listening; false if the microphone permission was refused.
  Future<bool> start() async {
    if (isRecording) return true;
    if (!await _mic.requestPermission()) return false;
    _committed.clear();
    pending = '';
    _heardSamples = 0;
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
    _gate.flush();
    await _work;
  }

  void _onAudio(Int16List pcm) {
    _heardSamples += pcm.length;
    _gate.add(pcm);
    notifyListeners();
  }

  void _onSpeech(Int16List audio) {
    if (_phraseSamples == 0) _log(() => 'phrase start at ${_at()}');
    _phraseSamples += audio.length;
    _queued.add(audio);
    _queuedSamples += audio.length;
    // Whistle takes live audio about one second at a time.
    if (_queuedSamples >= WhistleEngine.sampleRate) _sendQueued();
  }

  void _onPhraseEnd() {
    _log(() => 'phrase end at ${_at()}: ${_ms(_phraseSamples)} sent, '
        '${_speechFrames * 30} ms speech frames since last phrase');
    _phraseSamples = 0;
    _speechFrames = 0;
    if (_queuedSamples > 0) _sendQueued();
    _work = _work.then((_) => _run(_engine.streamStop));
  }

  void _sendQueued() {
    final chunk = Float32List(_queuedSamples);
    var at = 0;
    for (final part in _queued) {
      chunk.setAll(at, Mic.toFloat(part));
      at += part.length;
    }
    _queued.clear();
    _queuedSamples = 0;
    _work = _work.then((_) => _run(() => _engine.streamProcess(chunk)));
  }

  Future<void> _run(Future<NeedleResult> Function() call) async {
    try {
      final result = await call();
      _log(() => 'result ${jsonEncode({
            for (final k in ['text', 'pending', 'received', 'pass_ms']) k: result[k],
            'words': [
              for (final w in (result['words'] as List? ?? const []))
                '${w['word']}@${w['probability']}'
            ],
          })}');
      final text = result['text'] as String;
      if (text.isNotEmpty) _committed.add(text);
      pending = result['pending'] as String;
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  String _at() => '${seconds.toStringAsFixed(2)}s';

  static String _ms(int samples) =>
      '${samples * 1000 ~/ WhistleEngine.sampleRate} ms';

  @override
  void dispose() {
    _audio?.cancel();
    _mic.dispose();
    _vad.dispose();
    super.dispose();
  }
}
