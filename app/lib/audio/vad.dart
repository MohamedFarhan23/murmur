import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// WebRTC voice activity detection (libfvad) on 30 ms frames of 16 kHz audio.
class Vad {
  Vad({int mode = 3}) {
    _inst = _fvadNew();
    if (_inst == nullptr) throw StateError('fvad_new failed');
    if (_fvadSetMode(_inst, mode) < 0 || _fvadSetSampleRate(_inst, 16000) < 0) {
      throw ArgumentError('invalid VAD mode $mode');
    }
  }

  /// Samples per frame: 30 ms at 16 kHz.
  static const frameSamples = 480;

  late final Pointer<Void> _inst;
  final _frame = malloc<Int16>(frameSamples);

  /// Whether [frame], exactly [frameSamples] long, contains speech.
  bool isSpeech(Int16List frame) {
    _frame.asTypedList(frameSamples).setAll(0, frame);
    return _fvadProcess(_inst, _frame, frameSamples) == 1;
  }

  void dispose() {
    _fvadFree(_inst);
    malloc.free(_frame);
  }
}

final _lib = DynamicLibrary.open('libmurmur.so');
final _fvadNew = _lib.lookupFunction<Pointer<Void> Function(),
    Pointer<Void> Function()>('fvad_new');
final _fvadFree = _lib.lookupFunction<Void Function(Pointer<Void>),
    void Function(Pointer<Void>)>('fvad_free');
final _fvadSetMode = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32),
    int Function(Pointer<Void>, int)>('fvad_set_mode');
final _fvadSetSampleRate = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Int32),
    int Function(Pointer<Void>, int)>('fvad_set_sample_rate');
final _fvadProcess = _lib.lookupFunction<
    Int32 Function(Pointer<Void>, Pointer<Int16>, Size),
    int Function(Pointer<Void>, Pointer<Int16>, int)>('fvad_process');
