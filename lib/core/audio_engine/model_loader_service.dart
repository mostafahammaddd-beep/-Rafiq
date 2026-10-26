import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ModelPaths {
  const ModelPaths({
    required this.modelPath,
    required this.tokensPath,
    this.lexiconPath,
  });

  final String modelPath;
  final String tokensPath;
  final String? lexiconPath;
}

/// Copies the bundled acoustic model from the asset bundle into the app's
/// support directory (the native library needs real file paths).
class ModelLoaderService {
  static const String assetModel = 'assets/models/model.int8.onnx';
  static const String assetTokens = 'assets/models/tokens.txt';
  static const String assetLexicon = 'assets/models/quran_phoneme_words.json';

  /// Bump to force a fresh copy after replacing the bundled model.
  static const String versionTag = 'v1';

  Future<bool> _isBundled(String asset) async {
    try {
      await rootBundle.load(asset);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True when the model files were included in this build.
  Future<bool> isBundled() => _isBundled(assetTokens);

  Future<ModelPaths> prepare(
    void Function(double progress, String message) onProgress,
  ) async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(support.path, 'models'));
    await dir.create(recursive: true);

    final String modelPath = p.join(dir.path, 'model.int8.onnx');
    final String tokensPath = p.join(dir.path, 'tokens.txt');
    final String lexiconPath = p.join(dir.path, 'quran_phoneme_words.json');
    final File marker = File(p.join(dir.path, '.ready_$versionTag'));

    final bool lexiconBundled = await _isBundled(assetLexicon);

    final bool alreadyCopied = await marker.exists() &&
        await File(modelPath).exists() &&
        await File(tokensPath).exists();

    if (!alreadyCopied) {
      onProgress(0.05, 'جارٍ تجهيز النموذج الصوتي لأول مرة…');
      await _copyAsset(assetTokens, tokensPath);

      if (lexiconBundled) {
        onProgress(0.15, 'جارٍ نسخ معجم الأصوات…');
        await _copyAsset(assetLexicon, lexiconPath);
      }

      onProgress(0.3, 'جارٍ نسخ النموذج (قد يستغرق لحظات)…');
      await _copyAsset(assetModel, modelPath);

      await marker.writeAsString('ok', flush: true);
    }
    onProgress(1.0, 'النموذج الصوتي جاهز');

    final bool lexiconOnDisk = lexiconBundled && await File(lexiconPath).exists();
    return ModelPaths(
      modelPath: modelPath,
      tokensPath: tokensPath,
      lexiconPath: lexiconOnDisk ? lexiconPath : null,
    );
  }

  Future<void> _copyAsset(String asset, String destination) async {
    final ByteData data = await rootBundle.load(asset);
    final File temp = File('$destination.tmp');
    await temp.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    final File target = File(destination);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(destination);
  }
}
