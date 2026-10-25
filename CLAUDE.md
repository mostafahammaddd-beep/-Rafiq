# CLAUDE.md — دليل العمل على مشروع رَفِيق

## طريقة العمل (Workflow)

1. Claude **لا يشغّل أوامر `flutter`** في بيئته. ينشئ ملفات المشروع برمجياً (Python) ويضغطها في `rafiq_app_stepN.zip`.
2. المستخدم يفك الضغط ويرفع المحتوى إلى **جذر** مستودع GitHub على فرع `main`، بحيث يظهر `.github/` و`pubspec.yaml` و`lib/` في الجذر مباشرة.
3. GitHub Actions (`.github/workflows/android_build.yml`) ينفّذ: Java 17، Flutter stable، `flutter create --platforms=android .`، `flutter pub get`، `flutter analyze`، `flutter build apk --release`، ثم يرفع الـ APK باسم `rafiq-release-apk`.
4. عند فشل البناء يلصق المستخدم سجل الخطأ، ونصلحه بأصغر تعديل ممكن.

## قواعد صارمة

- لا أكواد وهمية: كل ملف `.dart` و`.yaml` سليم برمجياً 100%.
- `flutter analyze` يجب أن يمر بلا أخطاء ولا تحذيرات.
- لا تُضاف مكتبة إلا في مرحلتها، وبإصدارات مستقرة.
- التعديل على ملف موجود: أصغر تعديل ممكن، دون لمس ما لا يخصه.
- مجلد `android/` **يُولَّد في CI** ولا يُرفق في الـ ZIP. أي تعديل على `AndroidManifest.xml` أو ملفات Gradle (مثل صلاحية الميكروفون أو `minSdk`) يتم عبر سكربت (مثل `scripts/patch_android.py`) تُضاف خطوة تشغيله في الـ workflow **بعد** `flutter create`.
- الواجهة عربية بالكامل واتجاهها RTL.
- لا صلاحية إنترنت في الإصدار النهائي، ولا أي تتبّع.

## الهيكل المعتمد للمجلدات

```
.
├── .github/workflows/android_build.yml
├── pubspec.yaml
├── analysis_options.yaml
├── PROJECT_SPEC.md
├── CLAUDE.md
├── test/widget_test.dart
└── lib/
    ├── main.dart
    ├── core/
    │   └── theme/
    │       ├── app_theme.dart
    │       └── theme_mode_provider.dart
    └── features/
        ├── welcome/welcome_screen.dart
        ├── mushaf/
        ├── memorize_engine/
        ├── age_modes/
        └── teacher_dashboard/
```

داخل كل Feature عند التنفيذ:

```
feature_name/
├── data/          # مصادر البيانات والمستودعات (SQLite، ملفات، نماذج)
├── domain/        # النماذج والمنطق الصرف دون اعتماد على Flutter
└── presentation/  # الشاشات والـ Widgets ومزودات Riverpod
```

مجلد `core/` للأشياء المشتركة بين الـ features (ثيم، أدوات، ثوابت). لا يعتمد أي feature على feature آخر مباشرة، بل عبر `core/` أو مزودات Riverpod.

## معايير الكود

- Riverpod 2.x: نستخدم `Notifier` و`NotifierProvider` مع تحديد الأنواع صراحةً.
- `const` حيثما أمكن، وأنواع صريحة للمتغيرات والمعاملات.
- نصوص الواجهة بالعربية، وأسماء الملفات والأصناف بالإنجليزية (snake_case للملفات).
- الخطوط العربية (مثل Amiri أو خط المصحف العثماني) تُضاف كـ assets محلية في مرحلة المصحف، لا من الإنترنت.

## مراجع

- الرؤية والإخلاء الشرعي وخطة المراحل: `PROJECT_SPEC.md`.
