import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/audio_engine/audio_capture_service.dart';
import '../../core/audio_engine/phoneme_lexicon_service.dart';
import '../../core/audio_engine/recitation_evaluator.dart';
import '../../core/audio_engine/sherpa_tajweed_engine.dart';
import '../../core/audio_engine/tajweed_checker.dart';
import '../../core/database/models.dart';
import '../../core/database/rafiq_database.dart';
import '../../core/tajweed/tajweed_rule.dart';

enum WordStatus { pending, correct, warning, incorrect }

class TajweedFeedback {
  const TajweedFeedback({
    required this.title,
    required this.message,
    required this.verdict,
    required this.wordText,
  });

  final String title;
  final String message;
  final WordVerdict verdict;
  final String wordText;
}

/// Drives one recitation session (live correction or hands-free memorization)
/// over the ayahs of a single surah.
class RecitationSessionController extends ChangeNotifier {
  RecitationSessionController({
    required this.database,
    required this.engine,
    required this.capture,
    required this.lexicon,
    required this.surah,
    required this.ayahs,
    required this.mode,
    required this.engineAvailable,
    int startAyahIndex = 0,
  }) {
    _prepareAyah(startAyahIndex, 0);
  }

  final RafiqDatabase database;
  final SherpaTajweedEngine engine;
  final AudioCaptureService capture;
  final PhonemeLexiconService lexicon;
  final Surah surah;
  final List<Ayah> ayahs;
  final EvaluationMode mode;
  final bool engineAvailable;

  int ayahIndex = 0;
  late List<WordTarget> targets;
  late RecitationEvaluator _evaluator;
  List<WordStatus> statuses = <WordStatus>[];
  List<int> shakeTokens = <int>[];
  bool usingLexicon = false;

  bool listening = false;
  bool busy = false;
  bool ayahComplete = false;
  bool surahComplete = false;
  bool showFirstLetter = false;
  String hypothesis = '';
  String? errorMessage;
  TajweedFeedback? feedback;
  final List<double> levels = List<double>.filled(48, 0.0);

  int _wordsChecked = 0;
  int _wordsCorrect = 0;
  int _tajweedChecked = 0;
  int _tajweedPassed = 0;
  int _lastHypothesisLength = 0;
  Timer? _advanceTimer;
  bool _disposed = false;

  Ayah get currentAyah => ayahs[ayahIndex];

  int get currentWordIndex =>
      _evaluator.cursor >= targets.length ? targets.length - 1 : _evaluator.cursor;

  // ------------------------------------------------------------- ayah state

  void _prepareAyah(int index, int carryConsumed) {
    ayahIndex = index;
    final Ayah ayah = ayahs[index];

    final List<String>? lex = lexicon.wordsFor(surah.id, ayah.number);
    final List<String>? usable =
        (lex != null && lex.length == ayah.words.length) ? lex : null;
    usingLexicon = usable != null;

    targets = <WordTarget>[
      for (int i = 0; i < ayah.words.length; i++)
        WordTarget(
          index: i,
          text: ayah.words[i].text,
          phonemes: usable != null ? usable[i] : ayah.words[i].phonemes,
          rules: ayah.words[i].rules,
        ),
    ];

    _evaluator = RecitationEvaluator(
      words: targets,
      mode: mode,
      checker: TajweedChecker(lexiconMode: usingLexicon),
      acceptRatio: usingLexicon ? 0.25 : 0.38,
    );
    _evaluator.setConsumed(carryConsumed);

    statuses = List<WordStatus>.filled(targets.length, WordStatus.pending);
    shakeTokens = List<int>.filled(targets.length, 0);
    ayahComplete = false;
    feedback = null;
    _wordsChecked = 0;
    _wordsCorrect = 0;
    _tajweedChecked = 0;
    _tajweedPassed = 0;
  }

  void goToAyah(int index) {
    if (index < 0 || index >= ayahs.length) {
      return;
    }
    _advanceTimer?.cancel();
    surahComplete = false;
    _prepareAyah(index, _lastHypothesisLength);
    _notify();
  }

  void nextAyah() => goToAyah(ayahIndex + 1);

  void previousAyah() => goToAyah(ayahIndex - 1);

  void restartAyah() => goToAyah(ayahIndex);

  void toggleFirstLetter() {
    showFirstLetter = !showFirstLetter;
    _notify();
  }

  // -------------------------------------------------------------- listening

  Future<void> toggleListening() async {
    if (listening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  Future<void> startListening() async {
    if (listening || busy) {
      return;
    }
    if (!engineAvailable || !engine.isReady) {
      errorMessage = 'التصحيح الصوتي غير متاح: النموذج غير مضمّن في هذا الإصدار.';
      _notify();
      return;
    }
    busy = true;
    errorMessage = null;
    _notify();
    try {
      final bool granted = await capture.requestPermission();
      if (!granted) {
        errorMessage = 'يلزم السماح باستخدام الميكروفون من إعدادات الجهاز.';
        return;
      }
      engine.beginSession();
      hypothesis = '';
      _lastHypothesisLength = 0;
      _evaluator.setConsumed(0);
      await capture.start(_onAudio);
      listening = true;
    } catch (e) {
      errorMessage = 'تعذّر تشغيل الميكروفون: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> stopListening() async {
    if (!listening) {
      return;
    }
    listening = false;
    await capture.stop();
    engine.endSession();
    for (int i = 0; i < levels.length; i++) {
      levels[i] = 0.0;
    }
    _notify();
  }

  void _onAudio(Float32List samples, double level) {
    if (_disposed || !listening) {
      return;
    }
    levels.removeAt(0);
    levels.add(level);

    final EngineUpdate update = engine.acceptWaveform(samples);
    hypothesis = update.text;
    _lastHypothesisLength = update.text.replaceAll(RegExp(r'\s'), '').length;

    if (!ayahComplete) {
      final List<WordEvaluation> events = _evaluator.update(update.text);
      for (final WordEvaluation event in events) {
        _apply(event);
      }
      if (_evaluator.isComplete) {
        _completeAyah();
      }
    }
    if (update.endpoint) {
      _evaluator.onSegmentReset();
      _lastHypothesisLength = 0;
    }
    _notify();
  }

  // ------------------------------------------------------------- evaluation

  void _apply(WordEvaluation event) {
    final int i = event.wordIndex;
    final WordTarget target = targets[i];
    final bool hasRules = target.rules.isNotEmpty;

    if (event.verdict == WordVerdict.correct) {
      statuses[i] = WordStatus.correct;
      _wordsChecked++;
      _wordsCorrect++;
      if (hasRules) {
        _tajweedChecked++;
        _tajweedPassed++;
      }
      return;
    }

    if (event.verdict == WordVerdict.tajweedWarning) {
      final TajweedRule rule = event.rule ?? TajweedRule.maddTabii;
      statuses[i] = WordStatus.warning;
      _wordsChecked++;
      _wordsCorrect++;
      _tajweedChecked++;
      feedback = TajweedFeedback(
        title: rule.arabicName,
        message: event.message ?? rule.hint,
        verdict: WordVerdict.tajweedWarning,
        wordText: target.text,
      );
      HapticFeedback.lightImpact();
      _logMistake(target, rule.code, event.message ?? rule.hint);
      return;
    }

    // incorrect word
    if (event.advanced) {
      statuses[i] = WordStatus.incorrect;
    }
    shakeTokens[i] = shakeTokens[i] + 1;
    _wordsChecked++;
    if (hasRules) {
      _tajweedChecked++;
    }
    final String message = event.message ?? 'خطأ في نطق الكلمة أو التشكيل';
    feedback = TajweedFeedback(
      title: 'خطأ في النطق',
      message: message,
      verdict: WordVerdict.incorrect,
      wordText: target.text,
    );
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    _logMistake(target, kPronunciationCode, message);
  }

  void _logMistake(WordTarget target, String ruleType, String message) {
    unawaited(
      database
          .logMistake(
            ayahId: currentAyah.id,
            wordPosition: target.index,
            wordText: target.text,
            ruleType: ruleType,
            message: message,
          )
          .catchError((Object error) {}),
    );
  }

  void _completeAyah() {
    ayahComplete = true;
    unawaited(
      database
          .recordAyahResult(
            ayahId: currentAyah.id,
            wordsChecked: _wordsChecked,
            wordsCorrect: _wordsCorrect,
            tajweedChecked: _tajweedChecked,
            tajweedPassed: _tajweedPassed,
          )
          .catchError((Object error) {}),
    );

    if (ayahIndex >= ayahs.length - 1) {
      surahComplete = true;
      unawaited(stopListening());
      return;
    }
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 1200), () {
      if (_disposed) {
        return;
      }
      final int carry = _evaluator.consumed;
      _prepareAyah(ayahIndex + 1, carry);
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _advanceTimer?.cancel();
    if (listening) {
      listening = false;
      engine.endSession();
    }
    unawaited(capture.dispose());
    super.dispose();
  }
}
