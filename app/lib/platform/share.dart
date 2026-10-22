import 'package:flutter/services.dart';

const _channel = MethodChannel('com.farhan.murmur/share');

/// Opens Android's share sheet with [text]; [subject] becomes the title in
/// apps that use one, such as email.
Future<void> shareText(String text, {String? subject}) =>
    _channel.invokeMethod('text', {'text': text, 'subject': subject});
