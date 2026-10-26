import '../tajweed/tajweed_rule.dart';
import 'recitation_evaluator.dart';

class TajweedFinding {
  const TajweedFinding({required this.rule, required this.message});

  final TajweedRule rule;
  final String message;
}

/// Compares the phonemes heard for an (otherwise accepted) word with the
/// expected phonemes, looking only at the tajweed rules the word carries.
///
/// In [lexiconMode] the expected phonemes come from the model's own lexicon,
/// so length (madd) and nasal (ghunna / ikhfa) checks are reliable. In the
/// approximate mode only the checks that do not depend on the model's
/// exact encoding are enabled (qalqala letter present, heavy letter kept).
class TajweedChecker {
  const TajweedChecker({required this.lexiconMode});

  final bool lexiconMode;

  static const String _maddLetters = 'اويى';
  static const String _nasalLetters = 'نمںۨ';
  static const String _qalqalaLetters = 'قطبجد';

  static const Map<String, String> _lightPairs = <String, String>{
    'ص': 'س',
    'ض': 'د',
    'ط': 'ت',
    'ظ': 'ذ',
    'غ': 'ع',
    'خ': 'ح',
    'ق': 'ك',
  };

  TajweedFinding? check(WordTarget target, String heard) {
    final String expected = target.phonemes;
    for (final TajweedRule rule in target.rules) {
      if (rule.isMadd) {
        if (!lexiconMode) {
          continue;
        }
        final int expectedRun = _maxRun(expected, _maddLetters);
        if (expectedRun >= 2) {
          final int heardRun = _maxRun(heard, _maddLetters);
          if (heardRun * 2 < expectedRun) {
            return TajweedFinding(rule: rule, message: rule.hint);
          }
        }
      } else if (rule == TajweedRule.ghunna || rule == TajweedRule.ikhfa) {
        if (lexiconMode && _hasAny(expected, _nasalLetters) && !_hasAny(heard, _nasalLetters)) {
          return TajweedFinding(rule: rule, message: rule.hint);
        }
      } else if (rule == TajweedRule.qalqala) {
        if (_hasAny(expected, _qalqalaLetters) && !_hasAny(heard, _qalqalaLetters)) {
          return TajweedFinding(rule: rule, message: rule.hint);
        }
      } else if (rule == TajweedRule.tafkhim) {
        for (final MapEntry<String, String> pair in _lightPairs.entries) {
          if (expected.contains(pair.key) &&
              !heard.contains(pair.key) &&
              heard.contains(pair.value) &&
              !expected.contains(pair.value)) {
            return TajweedFinding(rule: rule, message: rule.hint);
          }
        }
      }
    }
    return null;
  }

  static bool _hasAny(String text, String letters) {
    for (final int rune in text.runes) {
      if (letters.contains(String.fromCharCode(rune))) {
        return true;
      }
    }
    return false;
  }

  static int _maxRun(String text, String letters) {
    int best = 0;
    int current = 0;
    int previous = -1;
    for (final int rune in text.runes) {
      if (letters.contains(String.fromCharCode(rune))) {
        if (rune == previous) {
          current++;
        } else {
          current = 1;
        }
        previous = rune;
        if (current > best) {
          best = current;
        }
      } else {
        current = 0;
        previous = -1;
      }
    }
    return best;
  }
}
