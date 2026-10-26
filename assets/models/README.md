# assets/models

This folder is filled automatically by `scripts/fetch_models.py` during the GitHub Actions build:

- `model.int8.onnx`  (streaming Zipformer2 CTC phoneme model)
- `tokens.txt`
- `quran_phoneme_words.json` (optional phoneme lexicon)

The files are never committed. See NOTICE.md for the model license (Quran-Lab No-Profit License).
This README keeps the folder present so the asset declaration in pubspec.yaml stays valid.
