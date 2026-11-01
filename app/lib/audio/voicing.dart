import 'dart:math';
import 'dart:typed_data';

/// Whether [frame] is voiced: it repeats at a pitch between 60 and 400 Hz, as
/// vowels do. Rustling, handling noise, clicks and hiss don't, though the VAD
/// can take them for speech. Assumes 16 kHz audio.
bool isVoiced(Int16List frame) {
  final n = frame.length - 1;
  if (n <= _maxLag || _rms(frame) < _floor) return false;
  // First difference: tilts the frame towards the pitch's harmonics, so a
  // low rumble doesn't pass for a voice.
  final x = Float64List(n);
  for (var i = 0; i < n; i++) {
    x[i] = (frame[i + 1] - frame[i]).toDouble();
  }
  for (var lag = _minLag; lag <= _maxLag; lag++) {
    var ab = 0.0, aa = 0.0, bb = 0.0;
    for (var i = 0; i + lag < n; i++) {
      final a = x[i], b = x[i + lag];
      ab += a * b;
      aa += a * a;
      bb += b * b;
    }
    if (ab > 0 && ab * ab > _threshold * _threshold * aa * bb) return true;
  }
  return false;
}

const _minLag = 40; // 400 Hz
const _maxLag = 267; // 60 Hz
const _threshold = 0.4; // normalised autocorrelation

// -55 dBFS: quieter frames are near silence.
final _floor = 32768 * pow(10, -55 / 20);

double _rms(Int16List frame) {
  var sum = 0.0, mean = 0.0;
  for (final s in frame) {
    mean += s;
  }
  mean /= frame.length;
  for (final s in frame) {
    sum += (s - mean) * (s - mean);
  }
  return sqrt(sum / frame.length);
}
