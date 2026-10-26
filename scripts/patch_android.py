import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent

def patch_manifest():
    manifest = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.exists():
        print("AndroidManifest.xml not found")
        return
    text = manifest.read_text(encoding="utf-8")
    perms = [
        '<uses-permission android:name="android.permission.RECORD_AUDIO" />',
        '<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />',
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
    ]
    for p in perms:
        if p not in text:
            text = text.replace("<application", f"    {p}\n    <application", 1)
    if 'android:largeHeap="true"' not in text:
        text = text.replace("<application", '<application\n        android:largeHeap="true"', 1)
    manifest.write_text(text, encoding="utf-8")
    print("Patched AndroidManifest.xml successfully.")

def patch_gradle_kts(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"compileSdk\s*=\s*[^\n]+", "compileSdk = 35", text)
    text = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 24", text)
    text = re.sub(r"targetSdk\s*=\s*[^\n]+", "targetSdk = 35", text)

    if "isCoreLibraryDesugaringEnabled" not in text:
        text = text.replace(
            "compileOptions {",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            1,
        )
    if "desugar_jdk_libs" not in text:
        text += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'

    path.write_text(text, encoding="utf-8")
    print("Patched build.gradle.kts with Core Library Desugaring.")

def patch_gradle_groovy(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"compileSdk(?:Version)?\s+[=\s]*[^\n]+", "compileSdk = 35", text)
    text = re.sub(r"minSdk(?:Version)?\s+[=\s]*[^\n]+", "minSdk = 24", text)
    text = re.sub(r"targetSdk(?:Version)?\s+[=\s]*[^\n]+", "targetSdk = 35", text)

    if "coreLibraryDesugaringEnabled" not in text:
        text = text.replace(
            "compileOptions {",
            "compileOptions {\n        coreLibraryDesugaringEnabled true",
            1,
        )
    if "desugar_jdk_libs" not in text:
        text += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"

    path.write_text(text, encoding="utf-8")
    print("Patched build.gradle with Core Library Desugaring.")

def main():
    patch_manifest()
    kts = ROOT / "android" / "app" / "build.gradle.kts"
    groovy = ROOT / "android" / "app" / "build.gradle"
    if kts.exists():
        patch_gradle_kts(kts)
    if groovy.exists():
        patch_gradle_groovy(groovy)

if __name__ == "__main__":
    main()
