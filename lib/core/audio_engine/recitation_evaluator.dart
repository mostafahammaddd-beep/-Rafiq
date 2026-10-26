import 'dart:math' as math;

import '../tajweed/tajweed_rule.dart';
import 'tajweed_checker.dart';

enum EvaluationMode { recite, memorize }

enum WordVerdict { correct, tajweedWarning, incorrect }

/// Removes whitespace and invisible direction marks so that phoneme strings
/// can be compared character by character.
String normalizePhonemes(String text) {
  return text.replaceAll(RegExp(r'[\s\u200B-\u200F\u202A-\u202E]'), '');
}

/// One word of the ayah being recited, with its expected phonemes.
class WordTarget {
  WordTarget({
    required this.index,
    required this.text,
    required String phonemes,
    required this.rules,
  })  : phonemes = normalizePhonemes(phonemes),
        units = normalizePhonemes(phonemes).codeUnits;

  final int index;
  final String text;
  final String phonemes;
  final List<int> units;
  final List<TajweedRule> rules;
}

class WordEvaluation {
  const WordEvaluation({
    required this.wordIndex,
    required this.verdict,
    required this.advanced,
    this.rule,
    this.message,
  });

  final int wordIndex;
  final WordVerdict verdict;

  /// Whether the cursor moved on to the next word.
  final bool advanced;
  final TajweedRule? rule;
  final String? message;
}

class _Match {
  const _Match(this.distance, this.start, this.end);

  final int distance;
  final int start;
  final int end;
}

/// Aligns the streaming phoneme hypothesis against the expected words of an
/// ayah using an approximate substring search (edit distance), one word at a
/// time.
class RecitationEvaluator {
  RecitationEvaluator({
    required this.words,
    required this.mode,
    required this.checker,
    this.acceptRatio = 0.35,
  });

  final List<WordTarget> words;
  final EvaluationMode mode;
  final TajweedChecker checker;

  /// Maximum edit-distance ratio (distance / expected length) to accept a word.
  final double acceptRatio;

  int _cursor = 0;
  int _consumed = 0;

  int get cursor => _cursor;
  int get consumed => _consumed;
  bool get isComplete => _cursor >= words.length;

  void setConsumed(int value) {
    _consumed = value < 0 ? 0 : value;
  }

  /// The recognizer reset its stream (pause detected): the hypothesis starts over.
  void onSegmentReset() {
    _consumed = 0;
  }

  List<WordEvaluation> update(String hypothesis) {
    final List<int> hyp = normalizePhonemes(hypothesis).codeUnits;
    if (_consumed > hyp.length) {
      _consumed = 0;
    }
    final List<WordEvaluation> events = <WordEvaluation>[];

    int guard = 0;
    while (!isComplete && guard < 32) {
      guard++;
      final WordTarget target = words[_cursor];
      final List<int> pattern = target.units;

      if (pattern.isEmpty) {
        events.add(WordEvaluation(
          wordIndex: target.index,
          verdict: WordVerdict.correct,
          advanced: true,
        ));
        _cursor++;
        continue;
      }

      final int available = hyp.length - _consumed;
      if (available <= 0) {
        break;
      }
      final List<int> window = hyp.sublist(_consumed);
      final _Match match = _bestMatch(pattern, window);
      final double ratio =
          (match.distance + math.max(0, match.start - 2)) / pattern.length;

      if (ratio <= acceptRatio && available >= (pattern.length * 0.5).ceil()) {
        final String heard =
            String.fromCharCodes(window.sublist(match.start, match.end));
        final TajweedFinding? finding = checker.check(target, heard);
        events.add(WordEvaluation(
          wordIndex: target.index,
          verdict: finding == null
              ? WordVerdict.correct
              : WordVerdict.tajweedWarning,
          advanced: true,
          rule: finding?.rule,
          message: finding?.message,
        ));
        _consumed += match.end;
        _cursor++;
        continue;
      }

      final int slack = math.max(3, pattern.length ~/ 2);
      if (available < pattern.length + slack) {
        break;
      }

      // Enough was said but it does not match this word.
      if (mode == EvaluationMode.memorize) {
        events.add(WordEvaluation(
          wordIndex: target.index,
          verdict: WordVerdict.incorrect,
          advanced: false,
          message: 'خطأ في نطق الكلمة أو التشكيل',
        ));
        _consumed = hyp.length;
        break;
      }

      int skip = math.min(available, pattern.length);
      if (_cursor + 1 < words.length) {
        final List<int> nextPattern = words[_cursor + 1].units;
        if (nextPattern.isNotEmpty) {
          final _Match nm = _bestMatch(nextPattern, window);
          final double nr = nm.distance / nextPattern.length;
          if (nr <= acceptRatio * 0.8 && nm.start >= (pattern.length * 0.4).floor()) {
            skip = nm.start;
          }
        }
      }
      events.add(WordEvaluation(
        wordIndex: target.index,
        verdict: WordVerdict.incorrect,
        advanced: true,
        message: 'خطأ في نطق الكلمة أو التشكيل',
      ));
      _consumed += skip;
      _cursor++;
    }
    return events;
  }

  /// Finds the substring of [text] closest to [pattern] (Sellers algorithm).
  /// On ties the latest end position wins, so repeated trailing letters are
  /// consumed together with the word.
  static _Match _bestMatch(List<int> pattern, List<int> text) {
    final int m = pattern.length;
    final int n = text.length;
    List<int> prev = List<int>.filled(n + 1, 0);
    List<int> prevStart = List<int>.generate(n + 1, (int j) => j);

    for (int i = 1; i <= m; i++) {
      final List<int> cur = List<int>.filled(n + 1, 0);
      final List<int> curStart = List<int>.filled(n + 1, 0);
      cur[0] = i;
      curStart[0] = 0;
      for (int j = 1; j <= n; j++) {
        final int sub = prev[j - 1] + (pattern[i - 1] == text[j - 1] ? 0 : 1);
        final int del = prev[j] + 1;
        final int ins = cur[j - 1] + 1;
        int best = sub;
        int bestStart = prevStart[j - 1];
        if (del < best) {
          best = del;
          bestStart = prevStart[j];
        }
        if (ins < best) {
          best = ins;
          bestStart = curStart[j - 1];
        }
        cur[j] = best;
        curStart[j] = bestStart;
      }
      prev = cur;
      prevStart = curStart;
    }

    int bestJ = 0;
    int bestD = prev[0];
    for (int j = 1; j <= n; j++) {
      if (prev[j] <= bestD) {
        bestD = prev[j];
        bestJ = j;
      }
    }
    return _Match(bestD, prevStart[bestJ], bestJ);
  }
}
