import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/suggest/sounds_like.dart';

void main() {
  final soundsLike =
      SoundsLike.parse(File('assets/words/english.txt').readAsStringSync());

  // The mishearings from testing on the phone, all of "testing".
  for (final heard in ['Disting.', 'Desting.', 'besting.']) {
    test('"$heard" suggests testing', () {
      expect(soundsLike.suggest(heard), contains('testing'));
    });
  }

  test('ignores punctuation and case', () {
    expect(soundsLike.suggest('Helo,'), contains('hello'));
  });

  test('never suggests the word itself', () {
    expect(soundsLike.suggest('testing'), isNot(contains('testing')));
  });

  test('custom words are candidates and rank first', () {
    expect(soundsLike.suggest('Murmor', custom: ['Murmur']).first, 'Murmur');
  });

  test('a non-word suggests nothing', () {
    expect(soundsLike.suggest('123'), isEmpty);
  });

  group('matchShape', () {
    test('keeps capital and punctuation', () {
      expect(matchShape('Disting.', 'testing'), 'Testing.');
    });
    test('keeps a lowercase original lowercase', () {
      expect(matchShape('besting,', 'testing'), 'testing,');
    });
    test('keeps the replacement own capitals', () {
      expect(matchShape('murmor', 'Murmur'), 'Murmur');
    });
    test('empty replacement leaves the word alone', () {
      expect(matchShape('word.', '  '), 'word.');
    });
  });
}
