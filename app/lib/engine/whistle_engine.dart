import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'needle_bindings.dart';

/// Engine calls return Needle's JSON result, decoded.
typedef NeedleResult = Map<String, dynamic>;

/// Whistle speech-to-text, running on its own isolate.
///
/// Needle holds one process-global, non-thread-safe model, so a single worker
/// isolate owns it and runs every call in order. Calls block that isolate, never
/// the UI one.
class WhistleEngine {
  WhistleEngine._(this._isolate, this._commands, this._replies);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;
  final _pending = <int, Completer<NeedleResult>>{};
  int _nextId = 0;

  /// Starts the worker and loads [model], the bytes of a whistle.cact.
  static Future<WhistleEngine> start(Uint8List model) async {
    final replies = ReceivePort();
    final isolate = await Isolate.spawn(_workerMain, replies.sendPort);
    final commands = Completer<SendPort>();
    WhistleEngine? engine;
    replies.listen((message) {
      if (message is SendPort) {
        commands.complete(message);
      } else {
        engine!._onReply(message as List<Object?>);
      }
    });
    engine = WhistleEngine._(isolate, await commands.future, replies);
    await engine._call('load', [TransferableTypedData.fromList([model])]);
    return engine;
  }

  /// Transcribes a whole clip of 16 kHz mono samples in one go.
  Future<NeedleResult> transcribe(Float32List pcm,
          {String language = 'en', bool wordTimestamps = false}) =>
      _call('transcribe', [_transfer(pcm), language, wordTimestamps]);

  /// Feeds about a second of live audio; returns newly committed words and the
  /// unconfirmed `pending` tail.
  Future<NeedleResult> streamProcess(Float32List pcm,
          {String language = 'en'}) =>
      _call('streamProcess', [_transfer(pcm), language]);

  /// Ends the stream, committing the pending tail.
  Future<NeedleResult> streamStop() => _call('streamStop', const []);

  void dispose() {
    _replies.close();
    _isolate.kill();
    for (final call in _pending.values) {
      call.completeError(StateError('engine disposed'));
    }
    _pending.clear();
  }

  Future<NeedleResult> _call(String op, List<Object?> args) {
    final id = _nextId++;
    final result = Completer<NeedleResult>();
    _pending[id] = result;
    _commands.send([id, op, ...args]);
    return result.future;
  }

  void _onReply(List<Object?> reply) {
    final [id as int, result, error] = reply;
    final call = _pending.remove(id)!;
    if (error != null) {
      call.completeError(NeedleException(error as String));
    } else {
      call.complete(result as NeedleResult);
    }
  }

  static TransferableTypedData _transfer(Float32List pcm) =>
      TransferableTypedData.fromList([pcm]);
}

class NeedleException implements Exception {
  NeedleException(this.message);
  final String message;

  @override
  String toString() => 'NeedleException: $message';
}

void _workerMain(SendPort replies) {
  final commands = ReceivePort();
  replies.send(commands.sendPort);
  final needle = _Needle(NeedleBindings(DynamicLibrary.open('libmurmur.so')));
  commands.listen((message) {
    final [id as int, op as String, ...args] = message as List<Object?>;
    try {
      replies.send([id, needle.run(op, args), null]);
    } catch (error) {
      replies.send([id, null, error.toString()]);
    }
  });
}

/// The worker-side state: bindings, the model bytes and the output buffer.
class _Needle {
  _Needle(this._b);

  static const _sampleRate = 16000;
  // Needle's own sizing: 4 KiB of JSON per second of audio, 256 KiB minimum.
  static const _outBytesPerSecond = 4096;
  static const _minOut = 1 << 18;

  final NeedleBindings _b;
  Pointer<Utf8> _out = calloc<Uint8>(_minOut).cast();
  int _outCapacity = _minOut;

  NeedleResult run(String op, List<Object?> args) => switch (op) {
        'load' => _load(_bytes(args[0])),
        'transcribe' => _transcribe(_bytes(args[0]).buffer.asFloat32List(),
            args[1] as String, args[2] as bool),
        'streamProcess' =>
          _streamProcess(_bytes(args[0]).buffer.asFloat32List(), args[1] as String),
        'streamStop' => _result(_b.streamStop(_out, _outCapacity)),
        _ => throw ArgumentError('unknown op $op'),
      };

  NeedleResult _load(Uint8List cact) {
    // needle.h doesn't say whether needle_load copies the archive, so the bytes
    // stay allocated for the life of the process.
    final model = malloc<Uint8>(cact.length);
    model.asTypedList(cact.length).setAll(0, cact);
    if (_b.load(model, cact.length) < 0) {
      malloc.free(model);
      throw StateError(_b.lastError().toDartString());
    }
    return {'bytes': cact.length};
  }

  NeedleResult _transcribe(
          Float32List pcm, String language, bool wordTimestamps) =>
      _withAudio(pcm, language, (samples, count, lang) => _b.transcribe(
          samples, count, lang, nullptr, wordTimestamps ? 1 : 0, _out, _outCapacity));

  NeedleResult _streamProcess(Float32List pcm, String language) =>
      _withAudio(pcm, language, (samples, count, lang) => _b.streamProcess(
          samples, count, lang, nullptr, _out, _outCapacity));

  NeedleResult _withAudio(Float32List pcm, String language,
      int Function(Pointer<Float>, int, Pointer<Utf8>) call) {
    _reserve(pcm.length);
    final samples = malloc<Float>(max(pcm.length, 1));
    final lang = language.toNativeUtf8();
    try {
      samples.asTypedList(pcm.length).setAll(0, pcm);
      return _result(call(samples, pcm.length, lang));
    } finally {
      malloc.free(samples);
      malloc.free(lang);
    }
  }

  void _reserve(int samples) {
    final needed = samples ~/ _sampleRate * _outBytesPerSecond;
    if (needed <= _outCapacity) return;
    calloc.free(_out);
    _out = calloc<Uint8>(needed).cast();
    _outCapacity = needed;
  }

  NeedleResult _result(int code) {
    if (code < 0) throw StateError(_b.lastError().toDartString());
    return jsonDecode(_out.toDartString()) as NeedleResult;
  }

  static Uint8List _bytes(Object? data) =>
      (data as TransferableTypedData).materialize().asUint8List();
}
