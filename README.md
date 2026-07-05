# كدّ (Kadd)

قفل التطبيقات بالمجهود الجسدي أو بالتزام الصلاة. هذا مستودع Flutter كامل،
مع سير عمل GitHub Actions يبني ملف APK تلقائيًا بمجرد أن تدفع (push) الكود —
نفس النمط المستعمل سابقًا لـ Sufra.

## كيفاش ترفعه لـ GitHub وتبني الـ APK تلقائيًا

```bash
# داخل مجلد kadd بعد فك الضغط:
git init
git add .
git commit -m "kadd: initial scaffold"

# باستعمال GitHub CLI (الأسهل، إذا مثبّت gh ومسجّل دخول):
gh repo create kadd --private --source=. --push

# أو يدويًا: أنشئ مستودع فارغ من واجهة GitHub، ثم:
git remote add origin https://github.com/<اسمك>/kadd.git
git branch -M main
git push -u origin main
```

بعد أول push، افتح تبويب **Actions** فمستودعك على GitHub — سير العمل
`Build APK` غادي يخدم تلقائيًا، وفـ النهاية يحط ملف الـ APK كـ **Artifact**
قابل للتحميل (اسمه `kadd-apk`) من نفس صفحة التشغيل (run).

## البناء محليًا (بلا انتظار GitHub)

```bash
flutter --version   # تأكد عندك Flutter مثبّت
./scripts/build_local.sh            # نسخة debug
./scripts/build_local.sh --release  # نسخة release
```

هاد السكريبت كيدير بالضبط نفس خطوات الـ CI: يولّد مجلد `android/`، ينسخ
ملفات Kotlin، يرقّع `AndroidManifest.xml`، ثم يبني الـ APK.

## ليش `android/` مش موجود فالمستودع؟

المستودع ما فيهش مجلد `android/` جاهز — كيتولّد تلقائيًا فكل مرة (عبر
`flutter create --platforms=android .`) ثم يترقّع بملفات `android_additions/`.
هاد الاختيار مقصود: بدل ما نحافظ يدويًا على نسخة Gradle/Kotlin boilerplate
كاملة قد تتقادم مع كل تحديث لـ Flutter، الـ CI يولّدها فريش فكل مرة بأحدث
نسخة متوافقة، ويرقّعها بمكوناتنا الخاصة (الخدمة، الأنشطة، المستقبِلات).
هذا يعني أيضًا أن `android/` مذكور فـ `.gitignore` عمدًا.

## بنية المشروع

```
lib/
  theme.dart              — الألوان والخطوط (مطابقة لـ kadd-mockups.html)
  models/
    locked_app.dart        — تطبيقات القفل + تكلفة العقلات لكل صعوبة
    prayer.dart             — الصلوات الخمس + تسمياتها بالعربية
  state/
    app_state.dart          — الحالة المركزية (Provider)، تربط كل الخدمات
  services/
    prayer_times_service.dart — Aladhan API (method=21 = المغرب) + GPS
    app_usage_service.dart    — جسر MethodChannel نحو الكوتلن
    rug_classifier.dart       — تحميل وتشغيل نموذج TFLite لتصنيف السجادة
  screens/                — الشاشات السبع من المخطط (01-07)
  widgets/
    effort_ring.dart        — حلقة التقدم الدائرية (العنصر المتكرر)

android_additions/
  kotlin/
    MainActivity.kt          — يسجل الـ MethodChannel
    LockPrefs.kt              — الحالة المشتركة (SharedPreferences)
    LockForegroundService.kt  — يراقب التطبيق الحالي عبر UsageStatsManager
    LockActivity.kt            — يفتح المسار الصحيح (كاميرا عقلات أو قفل صلاة)
    AthanAlarmScheduler.kt     — منبهات AlarmManager لكل صلاة
    BootReceiver.kt             — يعيد تشغيل خدمة القفل بعد إعادة تشغيل الهاتف
  manifest_permissions.xml   — يُحقن داخل <manifest> تلقائيًا
  manifest_application.xml   — يُحقن داخل <application> تلقائيًا

scripts/
  patch_manifest.py   — يحقن الملفين أعلاه داخل AndroidManifest.xml المولَّد
  build_local.sh       — يشغّل كل خطوات البناء محليًا بأمر واحد

.github/workflows/
  build-apk.yml        — نفس خطوات build_local.sh، لكن على GitHub Actions

assets/models/
  rug_classifier.tflite  — غير موجود بعد، أنت من ستضيفه (انظر أدناه)
  labels.txt              — وهمي حاليًا، بدّله بالملف الحقيقي من Teachable Machine
```

## القرارات التقنية المهمة

- **القفل عبر UsageStatsManager + Foreground Service، وليس AccessibilityService.**
  سياسة Google Play تقيّد استعمال Accessibility API لحالات إتاحة حقيقية،
  وتطبيقات قفل الشاشة رُفضت/أُزيلت سابقًا لاستعمالها كحل بديل.
- **مواقيت الصلاة عبر Aladhan API بطريقة الحساب رقم 21** (وزارة الأوقاف
  المغربية)، مبنية على GPS مباشرة بدل اختيار مدينة يدويًا.
- **عد التكرارات (عقلات) عبر زاوية المرفق** من نقاط ML Kit Pose Detection.
- **`android/` غير مُصدَّر بالمستودع** — يتولّد ويترقّع تلقائيًا (انظر أعلاه).

## الحالة الحقيقية — ما ينقص قبل الإطلاق

1. **نموذج تصنيف السجادة (الملف نفسه) غير موجود بعد** — الكود اللي يحمّله
   ويشغّله جاهز بالكامل (`lib/services/rug_classifier.dart`، يتعامل تلقائيًا
   مع float32 وquantized). الناقص فقط هو `assets/models/rug_classifier.tflite`
   نفسه — راجع `assets/models/README.md` لخطة جمع البيانات والتدريب
   (Teachable Machine كحل سريع للنسخة الأولى). حتى يوجد الملف، `RugScanScreen`
   يفشل بصمت ويرجّع ثقة 0.0 دائمًا — فشل آمن، لا فتح خاطئ.
2. **منبهات الأذان بعد إعادة تشغيل الهاتف غير مُعاد جدولتها تلقائيًا** —
   `BootReceiver.kt` يعيد تشغيل خدمة القفل (فيشتغل قفل العقلات مباشرة)، لكن
   قفل الصلاة يحتاج شبكة + GPS جديدين لجلب المواقيت، وهذا ما تقدرش تضمنه
   BroadcastReceiver عادية. `AppState.init()` يعيد الجلب والجدولة عند كل
   فتح للتطبيق، وهذا يكفي عمليًا للإصدار الأول.
3. **لم يُختبَر بعد على جهاز حقيقي** — كل شيء هنا كُتب ودُقّق منطقيًا لكن ما
   تشغّلش على جهاز فعلي بعد (لا Flutter SDK متوفر فبيئة الكتابة). أول تشغيل
   حقيقي قد يكشف تفاصيل صغيرة تحتاج تعديلًا (خصوصًا: عتبات زاوية المرفق فـ
   `rep_camera_screen.dart`، وسلوك `sensorOrientation` على أجهزة معيّنة).
4. **اختبار المنبهات على أجهزة Xiaomi/Huawei/Samsung** — هذه الشركات معروفة
   بتقييد التنبيهات الخلفية بقوة؛ قد تحتاج توجيه المستخدم يدويًا لتعطيل توفير
   الطاقة للتطبيق.

## الخطوة التالية المقترحة

ادفع المستودع لـ GitHub وشوف واش سير العمل يخدم أول مرة بلا مشاكل — هذا
أول اختبار حقيقي للمشروع كامل. إذا فشل البناء، الأرجح أن يكون بسبب توافق
إصدار Flutter/Gradle مع `tflite_flutter` أو `google_mlkit_pose_detection`
(يحتاجان أحيانًا رفع `minSdkVersion` أو NDK معيّن) — أرسل لي رسالة الخطأ من
تبويب Actions ونحلها.
