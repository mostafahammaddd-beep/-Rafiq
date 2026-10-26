import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class EngineUpdate {
  const EngineUpdate({required this.text, required this.endpoint});

  /// Cumulative phoneme text of the current segment.
  final String text;

  /// True when the recognizer detected a pause and reset itself.
  final bool endpoint;
}

/// Streaming Zipformer2-CTC phoneme recognizer (sherpa-onnx).
class SherpaTajweedEngine {
  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  bool _bindingsReady = false;

  bool get isReady => _recognizer != null;

  void initialize({required String modelPath, required String tokensPath}) {
    if (_recognizer != null) {
      return;
    }
    if (!_bindingsReady) {
      sherpa_onnx.initBindings();
      _bindingsReady = true;
    }

    final sherpa_onnx.OnlineModelConfig modelConfig =
        sherpa_onnx.OnlineModelConfig(
      zipformer2Ctc: sherpa_onnx.OnlineZipformer2CtcModelConfig(model: modelPath),
      tokens: tokensPath,
      modelType: 'zipformer2_ctc',
      numThreads: 2,
      provider: 'cpu',
    );
    final sherpa_onnx.OnlineRecognizerConfig config =
        sherpa_onnx.OnlineRecognizerConfig(
      model: modelConfig,
      feat: sherpa_onnx.FeatureConfig(sampleRate: 16000, featureDim: 80),
    );
    _recognizer = sherpa_onnx.OnlineRecognizer(config);
  }

  /// Starts a fresh audio stream (call before each listening session).
  void beginSession() {
    final sherpa_onnx.OnlineRecognizer? recognizer = _recognizer;
    if (recognizer == null) {
      throw StateError('Engine is not initialized');
    }
    _stream?.free();
    _stream = recognizer.createStream();
  }

  /// Feeds Float32 samples (16 kHz) and returns the current hypothesis.
  EngineUpdate acceptWaveform(Float32List samples) {
    final sherpa_onnx.OnlineRecognizer? recognizer = _recognizer;
    final sherpa_onnx.OnlineStream? stream = _stream;
    if (recognizer == null || stream == null) {
      return const EngineUpdate(text: '', endpoint: false);
    }
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    final String text = recognizer.getResult(stream).text;
    final bool endpoint = recognizer.isEndpoint(stream);
    if (endpoint) {
      recognizer.reset(stream);
    }
    return EngineUpdate(text: text, endpoint: endpoint);
  }

  void endSession() {
    _stream?.free();
    _stream = null;
  }

  void dispose() {
    endSession();
    _recognizer?.free();
    _recognizer = null;
  }
}
