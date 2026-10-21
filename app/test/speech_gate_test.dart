import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/transcription/speech_gate.dart';

/// Frames are one sample long; the sample's value is the frame index and a
/// positive value marks speech, so tests can see exactly what was forwarded.
void main() {
  late List<int> forwarded;
  late List<int> phraseEnds;
  late SpeechGate gate;

  setUp(() {
    forwarded = [];
    phraseEnds = [];
    gate = SpeechGate(
      frameSamples: 1,
      isSpeech: (frame) => frame[0] > 0,
      onSpeech: (audio) => forwarded.addAll(audio),
      onPhraseEnd: () => phraseEnds.add(forwarded.length),
      startFrames: 2,
      preRollFrames: 2,
      endFrames: 4,
      tailFrames: 1,
    );
  });

  // Speech frames are numbered upwards from 1, silence downwards from -1.
  var speech = 0, silence = 0;
  Int16List frames(String pattern) => Int16List.fromList([
        for (final c in pattern.split('')) c == 's' ? ++speech : --silence,
      ]);

  setUp(() => speech = silence = 0);

  test('drops silence that never turns into speech', () {
    gate.add(frames('......'));
    expect(forwarded, isEmpty);
    expect(phraseEnds, isEmpty);
  });

  test('ignores speech shorter than startFrames', () {
    gate.add(frames('..s..s..'));
    expect(forwarded, isEmpty);
  });

  test('forwards the pre-roll with speech once it starts', () {
    gate.add(frames('....ss'));
    expect(forwarded, [-3, -4, 1, 2]);
    expect(gate.inPhrase, isTrue);
  });

  test('a pause ends the phrase, forwarding only the first tail frames', () {
    gate.add(frames('ss....'));
    expect(forwarded, [1, 2, -1]);
    expect(phraseEnds, [3]);
    expect(gate.inPhrase, isFalse);
  });

  test('speech resuming within a pause keeps the held silence', () {
    gate.add(frames('ss..s'));
    expect(forwarded, [1, 2, -1, -2, 3]);
    expect(phraseEnds, isEmpty);
  });

  test('flush ends an open phrase', () {
    gate.add(frames('ss..'));
    gate.flush();
    expect(forwarded, [1, 2, -1]);
    expect(phraseEnds, [3]);
    gate.flush();
    expect(phraseEnds, [3]);
  });

  test('frames split across chunks', () {
    final gate = SpeechGate(
      frameSamples: 3,
      isSpeech: (frame) => frame.every((s) => s > 0),
      onSpeech: (audio) => forwarded.addAll(audio),
      onPhraseEnd: () {},
      startFrames: 1,
      preRollFrames: 0,
    );
    gate.add(Int16List.fromList([1, 1]));
    gate.add(Int16List.fromList([1, 2, 2]));
    expect(forwarded, [1, 1, 1]);
  });
}
