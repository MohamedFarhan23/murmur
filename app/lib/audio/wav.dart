import 'dart:io';
import 'dart:typed_data';

const _headerBytes = 44;

/// A 16-bit mono PCM WAV file of [pcm].
Uint8List encodeWav(Int16List pcm, {int sampleRate = 16000}) {
  final dataBytes = pcm.length * 2;
  final header = ByteData(_headerBytes)
    ..setUint32(0, 0x52494646) // "RIFF"
    ..setUint32(4, 36 + dataBytes, Endian.little)
    ..setUint32(8, 0x57415645) // "WAVE"
    ..setUint32(12, 0x666d7420) // "fmt "
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x64617461) // "data"
    ..setUint32(40, dataBytes, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm.buffer.asUint8List(pcm.offsetInBytes, dataBytes)))
      .takeBytes();
}

/// [count] samples from [start] of a WAV written by [encodeWav].
Future<Int16List> readWavSamples(File file, int start, int count) async {
  final raf = await file.open();
  try {
    final total = (await raf.length() - _headerBytes) ~/ 2;
    start = start.clamp(0, total);
    count = count.clamp(0, total - start);
    await raf.setPosition(_headerBytes + start * 2);
    final bytes = await raf.read(count * 2);
    return Int16List.fromList(bytes.buffer.asInt16List(bytes.offsetInBytes, count));
  } finally {
    await raf.close();
  }
}
