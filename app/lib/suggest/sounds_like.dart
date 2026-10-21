import 'dart:math';

/// Suggests dictionary words that sound like a misheard one.
///
/// Words are reduced to a rough pronunciation key, then compared with an edit
/// distance where similar sounds (t/d, b/p, any two vowels…) cost less than
/// unrelated ones. Common words rank above rare ones, and the user's own
/// words rank above both.
class SoundsLike {
  /// [words] maps each word to its SCOWL level: 10 is most common, 40 rarest.
  SoundsLike(Map<String, int> words)
      : _entries = [
          for (final MapEntry(key: word, value: level) in words.entries)
            _Entry(word, _key(word), _levelPenalty(level)),
        ];

  /// Parses the "word level" lines of assets/words/english.txt.
  factory SoundsLike.parse(String lines) => SoundsLike({
        for (final line in lines.split('\n'))
          if (line.indexOf(' ') case final at when at > 0)
            line.substring(0, at): int.parse(line.substring(at + 1)),
      });

  final List<_Entry> _entries;

  /// Up to [limit] words that sound like [word], best first. [custom] words
  /// are always candidates.
  List<String> suggest(String word,
      {Iterable<String> custom = const [], int limit = 5}) {
    final plain = _plain(word);
    if (plain.isEmpty) return const [];
    final key = _key(plain);
    final maxDistance = max(1.0, key.length * 0.4);
    final scored = <String, double>{};

    void consider(String candidate, String candidateKey, double bias) {
      if (candidate == plain) return;
      if ((candidateKey.length - key.length).abs() > maxDistance) return;
      final distance = _distance(key, candidateKey, maxDistance);
      if (distance > maxDistance) return;
      final score = distance + bias;
      if (score < (scored[candidate] ?? double.infinity)) scored[candidate] = score;
    }

    for (final entry in _entries) {
      consider(entry.word, entry.key, entry.penalty);
    }
    for (final custom in custom) {
      final c = _plain(custom);
      if (c.isNotEmpty) consider(custom, _key(c), -0.3);
    }
    final ranked = scored.keys.toList()
      ..sort((a, b) => scored[a]!.compareTo(scored[b]!));
    return ranked.take(limit).toList();
  }

  static double _levelPenalty(int level) => switch (level) {
        <= 10 => 0,
        <= 20 => 0.1,
        <= 35 => 0.25,
        _ => 0.4,
      };

  /// Lowercase letters and apostrophes only.
  static String _plain(String word) =>
      word.toLowerCase().replaceAll(RegExp(r"[^a-z']"), '');

  /// A rough pronunciation: spellings of the same sound collapse together.
  static String _key(String word) {
    var s = word.replaceAll("'", '');
    for (final (from, to) in _rewrites) {
      s = s.replaceAll(from, to);
    }
    // Doubled letters sound like one.
    return s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
  }

  static final _rewrites = <(Pattern, String)>[
    ('ph', 'f'),
    ('ck', 'k'),
    ('wh', 'w'),
    ('dg', 'j'),
    ('tch', 'ch'),
    (RegExp('c(?=[eiy])'), 's'),
    ('c', 'k'),
    ('q', 'k'),
    ('x', 'ks'),
    ('z', 's'),
  ];

  /// Weighted Levenshtein distance; gives up past [limit].
  static double _distance(String a, String b, double limit) {
    var previous = List<double>.generate(b.length + 1, (j) => j.toDouble());
    for (var i = 1; i <= a.length; i++) {
      final current = List<double>.filled(b.length + 1, 0)..[0] = i.toDouble();
      var rowMin = current[0];
      for (var j = 1; j <= b.length; j++) {
        final sub = previous[j - 1] + _substitution(a[i - 1], b[j - 1]);
        final del = previous[j] + _indel(a[i - 1]);
        final ins = current[j - 1] + _indel(b[j - 1]);
        current[j] = min(sub, min(del, ins));
        rowMin = min(rowMin, current[j]);
      }
      if (rowMin > limit) return double.infinity;
      previous = current;
    }
    return previous[b.length];
  }

  static const _vowels = 'aeiouy';
  static const _similar = [
    'td',
    'bp',
    'kg',
    'fv',
    'sj',
    'mn',
    'lr',
    'wv',
  ];

  // Speech models often confuse one stop consonant for another.
  static const _stops = 'bdgkpt';

  static double _substitution(String x, String y) {
    if (x == y) return 0;
    if (_vowels.contains(x) && _vowels.contains(y)) return 0.3;
    for (final pair in _similar) {
      if (pair.contains(x) && pair.contains(y)) return 0.35;
    }
    if (_stops.contains(x) && _stops.contains(y)) return 0.6;
    return 1;
  }

  // Vowels slip in and out of fast speech more easily than consonants.
  static double _indel(String c) => _vowels.contains(c) ? 0.5 : 1;
}

class _Entry {
  _Entry(this.word, this.key, this.penalty);
  final String word;
  final String key;
  final double penalty;
}

/// [replacement] in the shape of [original]: its leading capital and the
/// punctuation around it carry over, so "Disting." fixed to "testing"
/// reads "Testing.".
String matchShape(String original, String replacement) {
  final lead = RegExp(r"^[^A-Za-z0-9']*").stringMatch(original)!;
  final trail = RegExp(r"[^A-Za-z0-9']*$").stringMatch(original)!;
  final core = original.substring(lead.length, original.length - trail.length);
  var word = replacement.trim();
  if (word.isEmpty) return original;
  if (core.isNotEmpty &&
      core[0] != core[0].toLowerCase() &&
      word[0] == word[0].toLowerCase()) {
    word = word[0].toUpperCase() + word.substring(1);
  }
  return '$lead$word$trail';
}
