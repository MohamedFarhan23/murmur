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
import 'word.dart';

export 'word.dart';

/// Logs each phrase and engine result to logcat; build with
/// `--dart-define=MURMUR_DEBUG=true`.
const _debug = bool.fromEnvironment('MURMUR_DEBUG');

void _log(String Function() message) {
  if (_debug) debugPrint('MURMUR ${message()}');
}

/// What [LiveTranscriber.clear] took away, for [LiveTranscriber.restore].
typedef Cleared = ({List<Word> words, List<Int16List> audio, int samples, bool dirty});

/// Streams microphone speech through Whistle and exposes the transcript as it
/// forms: [words] are final, [pending] may still change.
///
/// A VAD keeps silence away from the model. Each pause ends the stream, which
/// commits the phrase and keeps the engine's re-transcribed buffer short.
/// Recording can be stopped and resumed; the transcript carries on until
/// [clear]. The recording's audio is kept in memory only, so the user can
/// hear words back and choose to keep it when saving.
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
  final _recording = <Int16List>[];
  int _recordedSamples = 0;
  final _queued = <Int16List>[];
  int _queuedSamples = 0;
  int _speechFrames = 0;
  int _phraseSamples = 0;
  double _phraseOffset = 0; // seconds into the recording the phrase starts
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

  /// Awaited once the microphone is allowed, just before it opens.
  Future<void> Function()? beforeListening;

  /// Called once the microphone has closed.
  VoidCallback? afterListening;

  String pending = '';
  bool isRecording = false;
  Object? error;

  /// Whether the transcript changed since it was last saved or cleared.
  bool dirty = false;

  /// Bumped on every change to [words], so listeners can tell edits apart
  /// from other updates.
  int revision = 0;

  List<Word> get words => List.unmodifiable(_words);
  String get text => _words.map((w) => w.text).join(' ');
  bool get isEmpty => _words.isEmpty && pending.isEmpty;

  /// Whether the VAD currently hears speech.
  bool get isSpeaking => isRecording && _gate.inPhrase;

  double get seconds => _recordedSamples / WhistleEngine.sampleRate;

  bool get hasAudio => _recordedSamples > 0;

  /// The whole recording so far.
  Int16List get audio => _join(_recording, _recordedSamples);

  /// The recording between [start] and [end] seconds.
  Int16List audioBetween(double start, double end) {
    final from = (start * WhistleEngine.sampleRate).round().clamp(0, _recordedSamples);
    final to = (end * WhistleEngine.sampleRate).round().clamp(from, _recordedSamples);
    return Int16List.sublistView(audio, from, to);
  }

  /// Starts or resumes listening; false if the microphone permission was refused.
  Future<bool> start() async {
    if (isRecording) return true;
    if (!await _mic.requestPermission()) return false;
    await beforeListening?.call();
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
    afterListening?.call();
    _gate.flush();
    await _work;
  }

  /// Empties the transcript and the recording while not recording, and
  /// returns what they held, for [restore].
  Cleared clear() {
    assert(!isRecording);
    final cleared = (
      words: List<Word>.of(_words),
      audio: List<Int16List>.of(_recording),
      samples: _recordedSamples,
      dirty: dirty,
    );
    _words.clear();
    _recording.clear();
    _recordedSamples = 0;
    _gate.reset();
    pending = '';
    elapsed.value = 0;
    dirty = false;
    _changed();
    return cleared;
  }

  /// Puts back what [clear] took, if nothing has been recorded since.
  void restore(Cleared cleared) {
    if (isRecording || _words.isNotEmpty || hasAudio) return;
    _words.addAll(cleared.words);
    _recording.addAll(cleared.audio);
    _recordedSamples = cleared.samples;
    elapsed.value = seconds;
    dirty = cleared.dirty;
    _changed();
  }

  /// Starts from a text-only draft left by an earlier session.
  void loadDraft(List<Word> words) {
    if (_words.isNotEmpty || hasAudio || words.isEmpty) return;
    _words.addAll(words);
    dirty = true;
    _changed();
  }

  /// Marks the transcript as saved.
  void markSaved() {
    dirty = false;
    notifyListeners();
  }

  /// Replaces the word at [index] with the user's correction, keeping its timing.
  void replaceWord(int index, String text) {
    final w = _words[index];
    _words[index] = (text: text, probability: 1, start: w.start, end: w.end);
    dirty = true;
    _changed();
  }

  void removeWord(int index) {
    _words.removeAt(index);
    dirty = true;
    _changed();
  }

  void insertWord(int index, Word word) {
    _words.insert(index, word);
    dirty = true;
    _changed();
  }

  void _changed() {
    revision++;
    notifyListeners();
  }

  void _onAudio(Int16List pcm) {
    _recording.add(pcm);
    _recordedSamples += pcm.length;
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
    if (_phraseSamples == 0) {
      _log(() => 'phrase start at ${_at()}');
      // The engine times words from the start of each stream, which is
      // where this phrase's forwarded audio begins.
      _phraseOffset = _gate.phraseStart / WhistleEngine.sampleRate;
    }
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
    final offset = _phraseOffset;
    _work = _work.then((_) async {
      final before = _words.length;
      await _run(offset, _engine.streamStop);
      if (_words.length > before) onPhraseFinalized?.call();
    });
  }

  void _sendQueued() {
    final chunk = Mic.toFloat(_join(_queued, _queuedSamples));
    _queued.clear();
    _queuedSamples = 0;
    final offset = _phraseOffset;
    _work = _work.then((_) => _run(offset,
        () => _engine.streamProcess(chunk, keywords: _vocabulary.words)));
  }

  /// Runs an engine call and commits its words, timed from [offset] seconds.
  Future<void> _run(double offset, Future<NeedleResult> Function() call) async {
    try {
      final result = await call();
      _log(() => 'result ${jsonEncode({
            for (final k in ['text', 'pending', 'received', 'pass_ms']) k: result[k],
            'words': [
              for (final w in (result['words'] as List? ?? const []))
                '${w['word']}@${w['probability']}'
            ],
          })}');
      final words = _wordsOf(result, offset).toList();
      if (words.isNotEmpty) {
        _words.addAll(words);
        dirty = true;
        revision++;
      }
      pending = result['pending'] as String;
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  static Iterable<Word> _wordsOf(NeedleResult result, double offset) {
    final words = result['words'] as List?;
    if (words != null && words.isNotEmpty) {
      return [
        for (final w in words)
          (
            text: (w['word'] as String).trim(),
            probability: (w['probability'] as num).toDouble(),
            start: offset + (w['start'] as num).toDouble(),
            end: offset + (w['end'] as num).toDouble(),
          ),
      ];
    }
    // No per-word detail: treat the committed text as certain.
    return (result['text'] as String)
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => (text: w, probability: 1.0, start: offset, end: offset));
  }

  static Int16List _join(List<Int16List> parts, int length) {
    final out = Int16List(length);
    var at = 0;
    for (final part in parts) {
      out.setAll(at, part);
      at += part.length;
    }
    return out;
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
