import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'wav.dart';

const _rate = 16000;

/// The short tones played when listening starts and stops: two notes rising
/// for start, falling for stop. Synthesized, so no audio assets are needed.
class Chime {
  Chime() {
    for (final (player, notes) in [(_start, _rising), (_stop, _rising.reversed)]) {
      player
        ..setAudioContext(_context)
        ..setReleaseMode(ReleaseMode.stop)
        ..setSource(BytesSource(encodeWav(_tones(notes)), mimeType: 'audio/wav'));
    }
  }

  static const _rising = [587.33, 880.0]; // D5, A5
  static const _note = Duration(milliseconds: 75);

  /// How long a chime lasts; wait this long before recording so the
  /// microphone doesn't pick it up.
  static const length = Duration(milliseconds: 2 * 75 + 40);

  // A UI sound: it must not take audio focus away from the recorder.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  final _start = AudioPlayer();
  final _stop = AudioPlayer();

  Future<void> start() => _play(_start);
  Future<void> stop() => _play(_stop);

  Future<void> _play(AudioPlayer player) async {
    await player.seek(Duration.zero);
    await player.resume();
  }

  Future<void> dispose() async {
    await _start.dispose();
    await _stop.dispose();
  }

  static Int16List _tones(Iterable<double> frequencies) {
    final n = _rate * _note.inMilliseconds ~/ 1000;
    final out = Int16List(n * frequencies.length);
    for (final (k, f) in frequencies.indexed) {
      for (var i = 0; i < n; i++) {
        final t = i / _rate;
        // Quick attack, smooth decay, so the notes don't click.
        final envelope = min(1.0, i / (0.004 * _rate)) * pow(1 - i / n, 2);
        final wave = sin(2 * pi * f * t) + 0.25 * sin(4 * pi * f * t);
        out[k * n + i] = (0.28 * 32767 * envelope * wave / 1.25).round();
      }
    }
    return out;
  }
}
