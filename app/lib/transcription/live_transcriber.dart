import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../audio/mic.dart';
import '../audio/vad.dart';
import '../engine/whistle_engine.dart';
import 'speech_gate.dart';
import 'vocabulary.dart';

/// Logs each phrase and engine result to logcat; build with
/// `--dart-define=MURMUR_DEBUG=true`.
const _debug = bool.fromEnvironment('MURMUR_DEBUG');

void _log(String Function() message) {
  if (_debug) debugPrint('MURMUR ${message()}');
}

/// A committed word and how sure the model was of it, from 0 to 1.
typedef Word = ({String text, double probability});

/// Streams microphone speech through Whistle and exposes the transcript as it
/// forms: [words] are final, [pending] may still change.
///
/// A VAD keeps silence away from the model. Each pause ends the stream, which
/// commits the phrase and keeps the engine's re-transcribed buffer short.
/// Recording can be stopped and resumed; the transcript carries on until
/// [clear].
class LiveTranscriber extends ChangeNotifier {
  LiveTranscriber(this._engine, this._vocabulary) {
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
  final Vocabulary _vocabulary;
  final _mic = Mic();
  final _vad = Vad();
  late final SpeechGate _gate;
  final _words = <Word>[];
  final _queued = <Int16List>[];
  int _queuedSamples = 0;
  int _heardSamples = 0;
  int _speechFrames = 0;
  int _phraseSamples = 0;
  StreamSubscription<Int16List>? _audio;
  // Engine calls run strictly one after another on this chain.
  Future<void> _work = Future.value();

  /// Microphone loudness from 0 (silence) to 1, updated with every audio chunk.
  final level = ValueNotifier<double>(0);

  /// Seconds of audio recorded since the transcript was last cleared, updated
  /// with every audio chunk.
  final elapsed = ValueNotifier<double>(0);

  /// Called each time a phrase is finalized with at least one word.
  VoidCallback? onPhraseFinalized;

  String pending = '';
  bool isRecording = false;
  Object? error;

  List<Word> get words => List.unmodifiable(_words);
  String get text => _words.map((w) => w.text).join(' ');
  bool get isEmpty => _words.isEmpty && pending.isEmpty;

  /// Whether the VAD currently hears speech.
  bool get isSpeaking => isRecording && _gate.inPhrase;

  double get seconds => _heardSamples / WhistleEngine.sampleRate;

  /// Starts or resumes listening; false if the microphone permission was refused.
  Future<bool> start() async {
    if (isRecording) return true;
    if (!await _mic.requestPermission()) return false;
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
    level.value = 0;
    notifyListeners();
    await _audio?.cancel();
    await _mic.stop();
    _gate.flush();
    await _work;
  }

  /// Empties the transcript and returns what it held, for [restore].
  List<Word> clear() {
    final cleared = List<Word>.of(_words);
    _words.clear();
    pending = '';
    _heardSamples = 0;
    elapsed.value = 0;
    notifyListeners();
    return cleared;
  }

  /// Replaces the word at [index] with the user's correction.
  void replaceWord(int index, String text) {
    _words[index] = (text: text, probability: 1);
    notifyListeners();
  }

  void removeWord(int index) {
    _words.removeAt(index);
    notifyListeners();
  }

  void insertWord(int index, Word word) {
    _words.insert(index, word);
    notifyListeners();
  }

  /// Puts back a transcript taken by [clear], ahead of anything said since.
  void restore(List<Word> words) {
    _words.insertAll(0, words);
    notifyListeners();
  }

  void _onAudio(Int16List pcm) {
    _heardSamples += pcm.length;
    elapsed.value = seconds;
    _updateLevel(pcm);
    final wasSpeaking = _gate.inPhrase;
    _gate.add(pcm);
    if (wasSpeaking != _gate.inPhrase) notifyListeners();
  }

  void _updateLevel(Int16List pcm) {
    if (pcm.isEmpty) return;
    var sum = 0.0;
    for (final s in pcm) {
      sum += s * s;
    }
    final rms = sqrt(sum / pcm.length) / 32768;
    // -60 dBFS (quiet room) .. -15 dBFS (close speech) mapped to 0..1.
    final db = 20 * log(max(rms, 1e-6)) / ln10;
    final target = ((db + 60) / 45).clamp(0.0, 1.0);
    // Rise fast, fall slowly, so the meter follows speech without flicker.
    final rate = target > level.value ? 0.6 : 0.15;
    level.value += (target - level.value) * rate;
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
    final before = _words.length;
    _work = _work.then((_) async {
      await _run(_engine.streamStop);
      if (_words.length > before) onPhraseFinalized?.call();
    });
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
    _work = _work.then((_) => _run(() =>
        _engine.streamProcess(chunk, keywords: _vocabulary.words)));
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
      _words.addAll(_wordsOf(result));
      pending = result['pending'] as String;
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  static Iterable<Word> _wordsOf(NeedleResult result) {
    final words = result['words'] as List?;
    if (words != null && words.isNotEmpty) {
      return [
        for (final w in words)
          (
            text: (w['word'] as String).trim(),
            probability: (w['probability'] as num).toDouble(),
          ),
      ];
    }
    // No per-word detail: treat the committed text as certain.
    return (result['text'] as String)
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => (text: w, probability: 1.0));
  }

  String _at() => '${seconds.toStringAsFixed(2)}s';

  static String _ms(int samples) =>
      '${samples * 1000 ~/ WhistleEngine.sampleRate} ms';

  @override
  void dispose() {
    _audio?.cancel();
    _mic.dispose();
    _vad.dispose();
    level.dispose();
    elapsed.dispose();
    super.dispose();
  }
}
