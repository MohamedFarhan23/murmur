import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'wav.dart';

/// Plays short clips of in-memory audio, such as a single word.
class ClipPlayer {
  final _player = AudioPlayer();

  Future<void> play(Int16List pcm) async {
    await _player.stop();
    await _player.play(BytesSource(encodeWav(pcm), mimeType: 'audio/wav'));
  }

  Future<void> dispose() => _player.dispose();
}
