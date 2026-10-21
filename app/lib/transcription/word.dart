/// A transcribed word, how sure the model was of it (0 to 1), and where it was
/// said, in seconds from the start of the recording.
typedef Word = ({String text, double probability, double start, double end});

/// [Word.start] of a word with no audio behind it, such as one restored from a
/// text-only draft.
const noTime = -1.0;

extension WordTiming on Word {
  bool get hasTime => start >= 0;
}

Map<String, Object> wordToJson(Word w) =>
    {'t': w.text, 'p': w.probability, 's': w.start, 'e': w.end};

Word wordFromJson(Map<String, dynamic> json) => (
      text: json['t'] as String,
      probability: (json['p'] as num).toDouble(),
      start: (json['s'] as num).toDouble(),
      end: (json['e'] as num).toDouble(),
    );
