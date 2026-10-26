#!/usr/bin/env python3
"""Download the on-device Quran phoneme model into assets/models/.

Order of attempts:
  1. Quran-Lab/zipformer_p-arabic-v3 (gated) using the HF_TOKEN environment variable.
  2. Open fallback repo Synthesium/quran-recitation-v2-onnx (zipformer-p-phoneme/).

Target files (always saved under these names):
  assets/models/model.int8.onnx            (required)
  assets/models/tokens.txt                 (required)
  assets/models/quran_phoneme_words.json   (optional lexicon)

Exit code is 0 even when the model is unavailable (the app handles a missing
model at runtime), unless REQUIRE_MODEL=true, in which case a missing required
file fails the step.
"""

import json
import os
import pathlib
import sys
import urllib.error
import urllib.parse
import urllib.request

OUT_DIR = pathlib.Path("assets/models")
MODEL = OUT_DIR / "model.int8.onnx"
TOKENS = OUT_DIR / "tokens.txt"
LEXICON = OUT_DIR / "quran_phoneme_words.json"

PRIMARY_BASE = "https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3/resolve/main/"
PRIMARY_FILES = (
    ("zipformer_p_arabic_v3.1.int8.onnx", MODEL),
    ("tokens.txt", TOKENS),
)

FALLBACK_BASE = (
    "https://huggingface.co/Synthesium/quran-recitation-v2-onnx/resolve/main/zipformer-p-phoneme/"
)
FALLBACK_FILES = (
    ("zipformer_p_arabic_v3.int8.onnx", MODEL),
    ("tokens.txt", TOKENS),
    ("quran_phoneme_words.json", LEXICON),
)

MIN_MODEL_BYTES = 10 * 1024 * 1024
MIN_TOKENS_BYTES = 100


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


_OPENER = urllib.request.build_opener(_NoRedirect)


def _is_hf_host(host):
    return bool(host) and (host == "huggingface.co" or host.endswith(".huggingface.co"))


def download(url, dest, token=None):
    """Returns the HTTP status code (200 on success) or -1 on a network error."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(dest.name + ".part")
    current = url
    for _ in range(8):
        host = urllib.parse.urlparse(current).hostname
        headers = {"User-Agent": "rafiq-ci/1.0"}
        # Never forward the token to third-party CDN hosts.
        if token and _is_hf_host(host) and host == "huggingface.co":
            headers["Authorization"] = "Bearer " + token
        request = urllib.request.Request(current, headers=headers)
        try:
            response = _OPENER.open(request, timeout=180)
        except urllib.error.HTTPError as err:
            if err.code in (301, 302, 303, 307, 308):
                location = err.headers.get("Location")
                if not location:
                    return err.code
                current = urllib.parse.urljoin(current, location)
                continue
            return err.code
        except (urllib.error.URLError, OSError, TimeoutError) as err:
            print("  network error: {0}".format(err))
            return -1
        try:
            with response, open(tmp, "wb") as out:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    out.write(chunk)
        except (OSError, TimeoutError) as err:
            print("  download interrupted: {0}".format(err))
            if tmp.exists():
                tmp.unlink()
            return -1
        os.replace(tmp, dest)
        return 200
    return -1


def valid(path):
    if not path.exists():
        return False
    size = path.stat().st_size
    if path == MODEL:
        return size >= MIN_MODEL_BYTES
    if path == TOKENS:
        return size >= MIN_TOKENS_BYTES
    if path == LEXICON:
        try:
            with open(path, "r", encoding="utf-8") as handle:
                json.load(handle)
            return True
        except (OSError, ValueError):
            return False
    return size > 0


def remove(path):
    try:
        if path.exists():
            path.unlink()
    except OSError:
        pass


def try_source(label, base, files, token):
    print("Trying {0} ...".format(label))
    all_ok = True
    for remote_name, dest in files:
        required = dest in (MODEL, TOKENS)
        if valid(dest):
            print("  {0}: already present".format(dest.name))
            continue
        status = download(base + remote_name, dest, token)
        if status == 200 and valid(dest):
            print("  {0}: OK ({1:.1f} MB)".format(dest.name, dest.stat().st_size / 1048576.0))
        else:
            print("  {0}: FAILED (status {1})".format(dest.name, status))
            remove(dest)
            if required:
                all_ok = False
    return all_ok


def write_output(key, value):
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a", encoding="utf-8") as handle:
            handle.write("{0}={1}\n".format(key, value))


def main():
    token = os.environ.get("HF_TOKEN", "").strip()
    require = os.environ.get("REQUIRE_MODEL", "false").strip().lower() == "true"
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    if not (valid(MODEL) and valid(TOKENS)):
        if token:
            ok = try_source("Quran-Lab/zipformer_p-arabic-v3 (HF_TOKEN)", PRIMARY_BASE, PRIMARY_FILES, token)
            if not ok:
                print("Primary source unavailable (401/403 means the access request is still pending).")
                remove(MODEL)
                remove(TOKENS)
        else:
            print("HF_TOKEN is empty: skipping the Quran-Lab source.")

        if not (valid(MODEL) and valid(TOKENS)):
            try_source("fallback Synthesium/quran-recitation-v2-onnx", FALLBACK_BASE, FALLBACK_FILES, None)

    # Lexicon is optional: try the fallback repo for it if still missing.
    if not valid(LEXICON):
        remove(LEXICON)
        if valid(MODEL) and valid(TOKENS):
            status = download(FALLBACK_BASE + "quran_phoneme_words.json", LEXICON, None)
            if not (status == 200 and valid(LEXICON)):
                remove(LEXICON)

    model_ok = valid(MODEL)
    tokens_ok = valid(TOKENS)
    lexicon_ok = valid(LEXICON)

    # All-or-nothing for the required pair, so the app never sees half a model.
    if model_ok != tokens_ok:
        remove(MODEL)
        remove(TOKENS)
        model_ok = tokens_ok = False

    print("")
    print("assets/models verification:")
    print("  model.int8.onnx           : {0}".format("OK" if model_ok else "MISSING"))
    print("  tokens.txt                : {0}".format("OK" if tokens_ok else "MISSING"))
    print("  quran_phoneme_words.json  : {0}".format("OK" if lexicon_ok else "MISSING (optional)"))

    ready = model_ok and tokens_ok
    write_output("models_ready", "true" if ready else "false")

    if not ready:
        message = (
            "Acoustic model not downloaded. The APK will still build, but live recitation "
            "checking stays disabled until Quran-Lab grants access to HF_TOKEN."
        )
        if require:
            print("::error::" + message)
            return 1
        print("::warning::" + message)
    elif not lexicon_ok:
        print("::warning::quran_phoneme_words.json missing: the app will use approximate phoneme matching.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
