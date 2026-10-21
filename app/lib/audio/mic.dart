import 'dart:typed_data';

import 'package:record/record.dart';

import '../engine/whistle_engine.dart';

/// Microphone audio as 16 kHz mono float samples, the format Whistle expects.
class Mic {
  final _recorder = AudioRecorder();

  /// Asks for the microphone permission if it hasn't been granted yet.
  Future<bool> requestPermission() => _recorder.hasPermission();

  Future<Stream<Float32List>> start() async {
    final pcm = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: WhistleEngine.sampleRate,
      numChannels: 1,
      // Tuned for speech recognition: no gain or effects that distort speech.
      androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition),
    ));
    return pcm.map(_toFloat);
  }

  Future<void> stop() => _recorder.stop();

  Future<void> dispose() => _recorder.dispose();

  static Float32List _toFloat(Uint8List pcm) {
    final data = ByteData.sublistView(pcm);
    final out = Float32List(pcm.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768;
    }
    return out;
  }
}
