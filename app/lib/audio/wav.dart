import 'dart:typed_data';

const whistleSampleRate = 16000;

/// Decodes a 16-bit PCM, 16 kHz WAV into mono float samples in [-1, 1].
Float32List decodeWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') {
    throw const FormatException('not a WAV file');
  }
  int? channels, rate, bits;
  for (var at = 12; at + 8 <= bytes.length;) {
    final id = _tag(bytes, at);
    final size = data.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ') {
      channels = data.getUint16(body + 2, Endian.little);
      rate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (bits != 16 || rate != whistleSampleRate || channels == null) {
        throw FormatException(
            'need 16-bit 16 kHz PCM, got $bits-bit $rate Hz');
      }
      final frames = size ~/ (2 * channels);
      final out = Float32List(frames);
      for (var f = 0; f < frames; f++) {
        var sum = 0;
        for (var c = 0; c < channels; c++) {
          sum += data.getInt16(body + (f * channels + c) * 2, Endian.little);
        }
        out[f] = sum / channels / 32768;
      }
      return out;
    }
    at = body + size + (size & 1);
  }
  throw const FormatException('WAV has no data chunk');
}

String _tag(Uint8List bytes, int at) =>
    String.fromCharCodes(bytes.sublist(at, at + 4));
