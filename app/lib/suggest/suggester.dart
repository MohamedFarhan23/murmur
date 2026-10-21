import 'dart:isolate';

import 'sounds_like.dart';

/// "Sounds like" suggestions, computed on their own isolate: a scan of the
/// dictionary takes long enough to stutter the UI.
class Suggester {
  Suggester._(this._requests);

  final SendPort _requests;

  /// [wordList] is the text of assets/words/english.txt.
  static Future<Suggester> start(String wordList) async {
    final ready = ReceivePort();
    await Isolate.spawn(_serve, (ready.sendPort, wordList));
    return Suggester._(await ready.first as SendPort);
  }

  Future<List<String>> suggest(String word,
      {List<String> custom = const []}) async {
    final reply = ReceivePort();
    _requests.send((word, custom, reply.sendPort));
    return (await reply.first as List).cast<String>();
  }

  static void _serve((SendPort, String) args) {
    final (ready, wordList) = args;
    final soundsLike = SoundsLike.parse(wordList);
    final requests = ReceivePort();
    ready.send(requests.sendPort);
    requests.listen((message) {
      final (word, custom, reply) = message as (String, List<String>, SendPort);
      reply.send(soundsLike.suggest(word, custom: custom));
    });
  }
}
