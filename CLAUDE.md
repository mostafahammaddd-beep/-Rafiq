# CLAUDE.md — دليل العمل على مشروع رَفِيق

## طريقة العمل (Workflow)

1. Claude **لا يشغّل أوامر `flutter`** في بيئته. ينشئ الملفات برمجياً (Python) ويضغطها في `rafiq_app_stepN.zip`.
2. المستخدم يفك الضغط ويرفع المحتوى إلى **جذر** مستودع GitHub على فرع `main` (يجب أن يظهر `.github/` و`pubspec.yaml` و`lib/` و`scripts/` في الجذر).
3. GitHub Actions (`.github/workflows/android_build.yml`) ينفّذ بالترتيب: Java 17، Flutter stable، `flutter create --platforms=android`، `scripts/patch_android.py`، `scripts/fetch_models.py`، `flutter pub get`، `flutter analyze --no-fatal-infos --no-fatal-warnings`، `flutter build apk --release`، رفع الـ APK باسم `rafiq-release-apk`.
4. عند فشل البناء يلصق المستخدم سجل الخطأ ونصلحه بأصغر تعديل ممكن.
5. سر المستودع `HF_TOKEN` (Settings → Secrets → Actions) لتحميل النموذج من Quran-Lab.

## قواعد صارمة

- لا أكواد وهمية: كل ملف `.dart` و`.yaml` و`.py` سليم برمجياً.
- مجلد `android/` **يُولَّد في CI** ولا يُرفق. أي تعديل على الـ Manifest أو Gradle يتم في `scripts/patch_android.py` (يرفع `minSdk` إلى 24 على الأقل و`compileSdk` إلى 35 على الأقل دون خفضهما، ويضيف صلاحيات الميكروفون و`largeHeap`).
- ملفات النموذج (`assets/models/*.onnx` و`tokens.txt` و`quran_phoneme_words.json`) **لا تُرفع إلى Git**؛ يحمّلها `fetch_models.py` في CI.
- غياب النموذج لا يُفشل البناء (إلا بـ `require_model=true`)، والتطبيق يتعامل معه وقت التشغيل.
- التعديل على ملف موجود: أصغر تعديل ممكن، دون لمس ما لا يخصه.
- الواجهة عربية RTL. لا صلاحية إنترنت ولا تتبّع.
- أي نص قرآني جديد يوضع في `quran_seed.dart` ويُدقَّق على المصحف المطبوع.

## واجهات مكتبات صارمة

- `record` 5.x: `AudioRecorder().startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1))`.
- الصوت إلى sherpa-onnx: `Float32List` من PCM16 little-endian بالقسمة على `32768.0`.
- `sherpa_onnx`: `initBindings()` مرة واحدة، `OnlineModelConfig(zipformer2Ctc: ..., tokens, modelType: 'zipformer2_ctc', numThreads: 2, provider: 'cpu')`، و`OnlineRecognizerConfig(model, feat: FeatureConfig(sampleRate: 16000, featureDim: 80))`.

## الهيكل المعتمد

```
.
├── .github/workflows/android_build.yml
├── scripts/{patch_android.py, fetch_models.py}
├── assets/models/            # يُملأ في CI
├── PROJECT_SPEC.md  CLAUDE.md  NOTICE.md
├── test/widget_test.dart
└── lib/
    ├── main.dart
    ├── core/
    │   ├── theme/            # الثيم ووضع الليل/النهار
    │   ├── data/             # quran_seed.dart
    │   ├── database/         # sqflite + النماذج + المزودات
    │   ├── tajweed/          # تحليل النص العثماني والأحكام
    │   └── audio_engine/     # نسخ النموذج، الميكروفون، sherpa، المقيّم، المعجم
    └── features/
        ├── welcome/          # شاشة التجهيز (قاعدة البيانات + النموذج)
        ├── home/             # التنقل السفلي
        ├── mushaf/           # فهرس السور وشاشة السورة
        ├── memorize_engine/  # جلسة التلاوة والتسميع (وضعان)
        ├── teacher_dashboard/# الإحصائيات والتقارير
        └── age_modes/        # مؤجَّل
```

## معايير الكود

- Riverpod 2.x: `Notifier` و`NotifierProvider`، وأنواع صريحة.
- `const` حيثما أمكن، وأنواع صريحة للمتغيرات.
- الجلسة الصوتية تُدار بـ `ChangeNotifier` (`RecitationSessionController`) داخل الشاشة.
- تعديل خوارزمية المطابقة في `recitation_evaluator.dart` يرافقه تحديث `test/widget_test.dart`.

## نقاط معروفة للمعايرة

- عتبات القبول: 0.25 مع المعجم، 0.38 مع المولّد التقريبي (في `recitation_session_controller.dart`).
- فك الترميز يجري على الخيط الرئيسي؛ المرحلة القادمة تنقله إلى Isolate.
- صيغة `quran_phoneme_words.json` غير موثقة، والمحلل في `phoneme_lexicon_service.dart` متسامح ويتجاهل ما لا يفهمه.
