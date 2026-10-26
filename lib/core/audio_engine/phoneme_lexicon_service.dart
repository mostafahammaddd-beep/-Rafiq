import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Phoneme lexicon shipped with the model (quran_phoneme_words.json).
///
/// The file format is not formally documented, so parsing is tolerant: it
/// accepts a map keyed by "surah:ayah" (value = list of phonetic words, or a
/// map holding such a list), a map surah -> ayah -> words, or a list of ayah
/// entries. An ayah is only used when its word count matches the Uthmani
/// word count, otherwise the app falls back to its approximate phonetizer.
class PhonemeLexiconService {
  Map<String, List<String>> _words = <String, List<String>>{};

  bool get isLoaded => _words.isNotEmpty;

  int get ayahCount => _words.length;

  Future<void> load(String path) async {
    try {
      final String raw = await File(path).readAsString();
      _words = await compute(parseLexicon, raw);
    } catch (_) {
      _words = <String, List<String>>{};
    }
  }

  List<String>? wordsFor(int surah, int ayah) => _words['$surah:$ayah'];
}

final RegExp _ayahKey = RegExp(r'^(\d+)\s*[:_\-/]\s*(\d+)$');
final RegExp _digits = RegExp(r'^\d+$');

/// Top-level so it can run inside `compute`.
Map<String, List<String>> parseLexicon(String raw) {
  final Map<String, List<String>> result = <String, List<String>>{};
  final dynamic decoded = jsonDecode(raw);

  if (decoded is Map) {
    decoded.forEach((dynamic key, dynamic value) {
      final String k = key.toString();
      final RegExpMatch? match = _ayahKey.firstMatch(k);
      if (match != null) {
        final List<String>? words = _wordsFromValue(value);
        if (words != null && words.isNotEmpty) {
          final int s = int.parse(match.group(1)!);
          final int a = int.parse(match.group(2)!);
          result['$s:$a'] = words;
        }
      } else if (value is Map && _digits.hasMatch(k)) {
        value.forEach((dynamic ayahKey, dynamic ayahValue) {
          final String ak = ayahKey.toString();
          if (!_digits.hasMatch(ak)) {
            return;
          }
          final List<String>? words = _wordsFromValue(ayahValue);
          if (words != null && words.isNotEmpty) {
            result['${int.parse(k)}:${int.parse(ak)}'] = words;
          }
        });
      }
    });
  } else if (decoded is List) {
    for (final dynamic item in decoded) {
      if (item is! Map) {
        continue;
      }
      final int? s = _asInt(item['surah'] ?? item['sura'] ?? item['surah_id']);
      final int? a = _asInt(item['ayah'] ?? item['aya'] ?? item['ayah_number']);
      if (s == null || a == null) {
        continue;
      }
      final List<String>? words = _wordsFromValue(item);
      if (words != null && words.isNotEmpty) {
        result['$s:$a'] = words;
      }
    }
  }
  return result;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

List<String>? _wordsFromValue(dynamic value) {
  if (value is String) {
    final List<String> parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    return parts;
  }
  if (value is List) {
    final List<String> out = <String>[];
    for (final dynamic item in value) {
      if (item is String) {
        out.add(item);
      } else if (item is Map) {
        final dynamic p =
            item['phonemes'] ?? item['phoneme'] ?? item['phonetic'] ?? item['p'];
        if (p is String) {
          out.add(p);
        } else if (p is List) {
          out.add(p.join());
        } else {
          return null;
        }
      } else if (item is List) {
        out.add(item.join());
      } else {
        return null;
      }
    }
    return out;
  }
  if (value is Map) {
    const List<String> keys = <String>[
      'aya_phonemes_list',
      'phoneme_words',
      'phonetic_words',
      'words',
      'phonemes',
    ];
    for (final String key in keys) {
      if (value.containsKey(key)) {
        final List<String>? words = _wordsFromValue(value[key]);
        if (words != null && words.isNotEmpty) {
          return words;
        }
      }
    }
  }
  return null;
}
