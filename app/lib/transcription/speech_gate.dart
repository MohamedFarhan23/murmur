import 'dart:typed_data';

/// Splits microphone audio into phrases using per-frame speech decisions, so
/// only speech reaches the model and each pause closes a phrase.
///
/// Speech starts after [startFrames] consecutive speech frames, and is
/// forwarded with [preRollFrames] of audio from just before it so first
/// syllables aren't clipped. A phrase ends after [endFrames] of non-speech;
/// only the first [tailFrames] of that silence are forwarded, since long
/// silence is what makes the model invent words.
class SpeechGate {
  SpeechGate({
    required this.frameSamples,
    required this.isSpeech,
    required this.onSpeech,
    required this.onPhraseEnd,
    this.startFrames = 3,
    this.preRollFrames = 10,
    this.endFrames = 20,
    this.tailFrames = 7,
  });

  final int frameSamples;
  final bool Function(Int16List frame) isSpeech;
  final void Function(Int16List audio) onSpeech;
  final void Function() onPhraseEnd;
  final int startFrames, preRollFrames, endFrames, tailFrames;

  final _recent = <Int16List>[]; // non-speech or not-yet-confirmed frames
  final _partial = <int>[];
  int _speechRun = 0;
  bool _inPhrase = false;

  bool get inPhrase => _inPhrase;

  void add(Int16List pcm) {
    _partial.addAll(pcm);
    var at = 0;
    for (; at + frameSamples <= _partial.length; at += frameSamples) {
      _frame(Int16List.fromList(_partial.sublist(at, at + frameSamples)));
    }
    _partial.removeRange(0, at);
  }

  /// Ends the current phrase, if any, as though a pause had been heard.
  void flush() {
    if (_inPhrase) _endPhrase();
    _recent.clear();
    _partial.clear();
    _speechRun = 0;
  }

  void _frame(Int16List frame) {
    final speech = isSpeech(frame);
    _recent.add(frame);
    if (_inPhrase) {
      if (speech) {
        // Speech resumed within the pause: the held silence belongs to the phrase.
        _recent.forEach(onSpeech);
        _recent.clear();
      } else if (_recent.length >= endFrames) {
        _endPhrase();
      }
      return;
    }
    _speechRun = speech ? _speechRun + 1 : 0;
    if (_recent.length > preRollFrames + startFrames) _recent.removeAt(0);
    if (_speechRun >= startFrames) {
      _inPhrase = true;
      _recent.forEach(onSpeech);
      _recent.clear();
    }
  }

  void _endPhrase() {
    _recent.take(tailFrames).forEach(onSpeech);
    _recent.clear();
    _inPhrase = false;
    _speechRun = 0;
    onPhraseEnd();
  }
}
