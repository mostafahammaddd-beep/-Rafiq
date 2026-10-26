import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_app/core/audio_engine/recitation_evaluator.dart';
import 'package:rafiq_app/core/audio_engine/tajweed_checker.dart';
import 'package:rafiq_app/core/tajweed/arabic_text.dart';
import 'package:rafiq_app/core/tajweed/phonetic_script_builder.dart';
import 'package:rafiq_app/core/tajweed/tajweed_rule.dart';

RecitationEvaluator _evaluator(EvaluationMode mode) {
  final List<WordTarget> words = <WordTarget>[
    WordTarget(
      index: 0,
      text: 'قُلْ',
      phonemes: 'قُل',
      rules: const <TajweedRule>[],
    ),
    WordTarget(
      index: 1,
      text: 'هُوَ',
      phonemes: 'هُوَ',
      rules: const <TajweedRule>[],
    ),
  ];
  return RecitationEvaluator(
    words: words,
    mode: mode,
    checker: const TajweedChecker(lexiconMode: false),
    acceptRatio: 0.3,
  );
}

void main() {
  test('exact phonemes advance through all words', () {
    final RecitationEvaluator evaluator = _evaluator(EvaluationMode.recite);
    final List<WordEvaluation> events = evaluator.update('قُلهُوَ');
    expect(events.length, 2);
    expect(evaluator.isComplete, isTrue);
  });

  test('memorize mode does not advance on a wrong word', () {
    final RecitationEvaluator evaluator = _evaluator(EvaluationMode.memorize);
    final List<WordEvaluation> events = evaluator.update('ززززززز');
    expect(events.length, 1);
    expect(events.first.verdict, WordVerdict.incorrect);
    expect(events.first.advanced, isFalse);
    expect(evaluator.cursor, 0);
  });

  test('arabic helpers', () {
    expect(splitAyahWords('وَٱسْتَغْفِرْهُ ۚ إِنَّهُۥ').length, 2);
    expect(buildPhoneticScript('قُلْ', atWaqf: false), 'قُل');
    expect(toArabicDigits(12), '١٢');
  });
}
