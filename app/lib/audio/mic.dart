import 'dart:typed_data';

import 'package:record/record.dart';

import '../engine/whistle_engine.dart';

/// Microphone audio as 16 kHz mono 16-bit samples.
class Mic {
  final _recorder = AudioRecorder();

  /// Asks for the microphone permission if it hasn't been granted yet.
  Future<bool> requestPermission() => _recorder.hasPermission();

  Future<Stream<Int16List>> start() async {
    final pcm = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: WhistleEngine.sampleRate,
      numChannels: 1,
      // Tuned for speech recognition: no gain or effects that distort speech.
      androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition),
    ));
    return pcm.map(_toInt16);
  }

  Future<void> stop() => _recorder.stop();

  Future<void> dispose() => _recorder.dispose();

  /// Whistle's input format: floats in [-1, 1].
  static Float32List toFloat(Int16List pcm) {
    final out = Float32List(pcm.length);
    for (var i = 0; i < pcm.length; i++) {
      out[i] = pcm[i] / 32768;
    }
    return out;
  }

  static Int16List _toInt16(Uint8List pcm) {
    final data = ByteData.sublistView(pcm);
    final out = Int16List(pcm.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = data.getInt16(i * 2, Endian.little);
    }
    return out;
  }
}
