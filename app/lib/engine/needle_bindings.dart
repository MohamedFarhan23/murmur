import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Raw bindings for the speech half of `needle.h`.
///
/// Every function returns a negative number on failure; the reason is in
/// [lastError]. Results are JSON written into the caller's `out` buffer.
final class NeedleBindings {
  NeedleBindings(DynamicLibrary lib)
      : load = lib.lookupFunction<Int32 Function(Pointer<Uint8>, Uint64),
            int Function(Pointer<Uint8>, int)>('needle_load'),
        lastError = lib.lookupFunction<Pointer<Utf8> Function(),
            Pointer<Utf8> Function()>('needle_last_error'),
        transcribe = lib.lookupFunction<
            Int32 Function(Pointer<Float>, Int32, Pointer<Utf8>, Pointer<Utf8>,
                Int32, Pointer<Utf8>, Int32),
            int Function(Pointer<Float>, int, Pointer<Utf8>, Pointer<Utf8>, int,
                Pointer<Utf8>, int)>('needle_transcribe'),
        streamProcess = lib.lookupFunction<
            Int32 Function(Pointer<Float>, Int32, Pointer<Utf8>, Pointer<Utf8>,
                Pointer<Utf8>, Int32),
            int Function(Pointer<Float>, int, Pointer<Utf8>, Pointer<Utf8>,
                Pointer<Utf8>, int)>('needle_stream_transcribe_process'),
        streamStop = lib.lookupFunction<Int32 Function(Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, int)>('needle_stream_transcribe_stop');

  final int Function(Pointer<Uint8> cact, int n) load;
  final Pointer<Utf8> Function() lastError;
  final int Function(Pointer<Float> pcm, int samples, Pointer<Utf8> language,
      Pointer<Utf8> keywords, int wordTimestamps, Pointer<Utf8> out,
      int outCapacity) transcribe;
  final int Function(Pointer<Float> pcm, int samples, Pointer<Utf8> language,
      Pointer<Utf8> keywords, Pointer<Utf8> out, int outCapacity) streamProcess;
  final int Function(Pointer<Utf8> out, int outCapacity) streamStop;
}
