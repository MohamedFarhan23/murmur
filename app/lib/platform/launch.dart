import 'package:flutter/services.dart';

const _channel = MethodChannel('com.farhan.murmur/launch');

/// Whether the home-screen widget asked for a quick transcribe since this was
/// last called; each request is reported once.
Future<bool> consumeQuickTranscribe() async =>
    await _channel.invokeMethod<bool>('consumeQuick') ?? false;

/// Calls [onRequest] when the widget is tapped while Murmur is running.
void listenForQuickTranscribe(void Function() onRequest) =>
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'quick') onRequest();
    });

/// Sends Murmur to the background, back to whatever was on screen before.
Future<void> moveToBack() => _channel.invokeMethod('moveToBack');
