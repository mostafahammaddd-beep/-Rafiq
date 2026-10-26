import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model_loader_service.dart';
import 'phoneme_lexicon_service.dart';
import 'sherpa_tajweed_engine.dart';

final engineProvider = Provider<SherpaTajweedEngine>((ref) {
  final SherpaTajweedEngine engine = SherpaTajweedEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final lexiconProvider = Provider<PhonemeLexiconService>((ref) {
  return PhonemeLexiconService();
});

enum PrepStage { idle, working, ready, modelMissing, failed }

class PrepState {
  const PrepState({
    this.stage = PrepStage.idle,
    this.progress = 0,
    this.message = '',
  });

  final PrepStage stage;
  final double progress;
  final String message;
}

/// Prepares the acoustic model and the recognizer at startup.
class ModelPrepNotifier extends Notifier<PrepState> {
  bool _started = false;

  @override
  PrepState build() => const PrepState();

  Future<void> prepare({bool force = false}) async {
    if (_started && !force) {
      return;
    }
    _started = true;
    state = const PrepState(
      stage: PrepStage.working,
      progress: 0.02,
      message: 'جارٍ التحقق من النموذج الصوتي…',
    );

    final ModelLoaderService loader = ModelLoaderService();
    try {
      final bool bundled = await loader.isBundled();
      if (!bundled) {
        state = const PrepState(
          stage: PrepStage.modelMissing,
          progress: 1,
          message: 'النموذج الصوتي غير مضمّن في هذا الإصدار.',
        );
        return;
      }

      final ModelPaths paths = await loader.prepare((double p, String msg) {
        state = PrepState(
          stage: PrepStage.working,
          progress: 0.05 + p * 0.75,
          message: msg,
        );
      });

      state = const PrepState(
        stage: PrepStage.working,
        progress: 0.85,
        message: 'جارٍ تحميل محرك التعرف على التلاوة…',
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final SherpaTajweedEngine engine = ref.read(engineProvider);
      engine.initialize(
        modelPath: paths.modelPath,
        tokensPath: paths.tokensPath,
      );

      final String? lexiconPath = paths.lexiconPath;
      if (lexiconPath != null) {
        await ref.read(lexiconProvider).load(lexiconPath);
      }

      state = const PrepState(
        stage: PrepStage.ready,
        progress: 1,
        message: 'اكتمل التجهيز',
      );
    } catch (e) {
      state = PrepState(
        stage: PrepStage.failed,
        message: 'تعذّر تجهيز المحرك الصوتي: $e',
      );
      _started = false;
    }
  }
}

final modelPrepProvider =
    NotifierProvider<ModelPrepNotifier, PrepState>(ModelPrepNotifier.new);
