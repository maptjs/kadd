# كدّ (Kadd)

قفل التطبيقات بالمجهود الجسدي أو بالتزام الصلاة. هذا سقالة (scaffold) أولية
مبنية على مخططات الواجهة (kadd-mockups.html) — تعمل الشاشات وحالة التطبيق،
لكن جزءين تقنيين حساسين ما زالا يحتاجان عملًا حقيقيًا قبل أن يشتغل التطبيق
بشكل كامل. اقرأ قسم "الحالة الحقيقية" أدناه قبل ما تبدأ.

## طريقة التشغيل

1. أنشئ مشروع Flutter فارغ ليأخذ الـ Gradle/Kotlin boilerplate القياسي:
   ```
   flutter create kadd_project --org com.comptaflow --platforms=android
   cd kadd_project
   ```
2. استبدل `pubspec.yaml` بالملف الموجود هنا، ثم `flutter pub get`.
3. استبدل مجلد `lib/` بالكامل بمجلد `lib/` من هذا المشروع.
4. انسخ ملفات `android_additions/kotlin/*.kt` إلى
   `android/app/src/main/kotlin/com/comptaflow/kadd/` (أنشئ المسار إذا لم يكن موجودًا).
5. ادمج محتوى `android_additions/AndroidManifest_additions.xml` يدويًا داخل
   `android/app/src/main/AndroidManifest.xml` (الأذونات داخل `<manifest>`،
   الخدمة والنشاط والمستقبِلَين — `AthanLockReceiver` و`BootReceiver` —
   داخل `<application>`).
6. انسخ `assets/models/` كما هي (فارغة حاليًا إلا من README) — أضف
   `rug_classifier.tflite` لاحقًا حسب الخطة في `assets/models/README.md`.

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
  screens/                — الشاشات السبع من المخطط (01-07)
  widgets/
    effort_ring.dart        — حلقة التقدم الدائرية (العنصر المتكرر)

android_additions/
  kotlin/
    MainActivity.kt          — يسجل الـ MethodChannel
    LockPrefs.kt              — الحالة المشتركة (SharedPreferences)
    LockForegroundService.kt  — يراقب التطبيق الحالي عبر UsageStatsManager
    LockActivity.kt            — نشاط يفتح فوق التطبيق المقفل
    AthanAlarmScheduler.kt     — منبهات AlarmManager لكل صلاة
    BootReceiver.kt             — يعيد تشغيل خدمة القفل بعد إعادة تشغيل الهاتف
  AndroidManifest_additions.xml
```

## القرارات التقنية المهمة

- **القفل عبر UsageStatsManager + Foreground Service، وليس AccessibilityService.**
  سياسة Google Play تقيّد استعمال Accessibility API لحالات إتاحة حقيقية،
  وتطبيقات قفل الشاشة رُفضت/أُزيلت سابقًا لاستعمالها كحل بديل. النهج المستعمل
  هنا (مراقبة كل ثانية + نشاط كامل الشاشة) هو ما تستعمله أغلب التطبيقات
  المتوافقة مع سياسة المتجر.
- **مواقيت الصلاة عبر Aladhan API بطريقة الحساب رقم 21** (وزارة الأوقاف
  المغربية)، مبنية على GPS مباشرة بدل اختيار مدينة يدويًا.
- **عد التكرارات (عقلات) عبر زاوية المرفق** من نقاط ML Kit Pose Detection —
  منطق بسيط (down/up state machine) بدل نموذج مدرَّب، لأنه يكفي ويعمل فورًا.

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
   BroadcastReceiver عادية. الحل المؤقت: `AppState.init()` يعيد الجلب
   والجدولة عند كل فتح للتطبيق، وهذا يكفي عمليًا لأن أغلب الناس تفتح هاتفها
   قبل الظهر بكثير. إذا صار مشكل حقيقي فالاختبار، الحل الصحيح موثّق كتعليق
   داخل `BootReceiver.kt` (مهمة WorkManager بشرط اتصال بالشبكة).
3. **اختبار المنبهات على أجهزة Xiaomi/Huawei/Samsung** — هذه الشركات معروفة
   بتقييد التنبيهات الخلفية بقوة؛ قد تحتاج توجيه المستخدم يدويًا لتعطيل توفير
   الطاقة للتطبيق.

**منجز الآن:**
- تحويل `CameraImage` إلى `InputImage` في `rep_camera_screen.dart` (دوران + NV21 كاملين)
- حفظ تفعيل/تعطيل التطبيقات والصلوات فعليًا على القرص (`SharedPreferences`)،
  وليس فالذاكرة فقط
- `LockActivity.kt` صار يفتح الشاشة الصحيحة فعليًا: `/lock/rep?package=...`
  أو `/lock/prayer?prayer=...` حسب حالة `LockPrefs`، ويقابله `onGenerateRoute`
  فـ `main.dart` اللي يبني `RepCameraScreen`/`PrayerLockScreen` مباشرة بلا
  المرور عبر `RootNav`
- `BootReceiver.kt` يعيد تشغيل خدمة القفل بعد إعادة تشغيل الهاتف (بالحدود
  المذكورة أعلاه بخصوص منبهات الأذان)

جرّب كشف الوضعية مباشرة على جهاز حقيقي:
1. `imageFormatGroup: ImageFormatGroup.nv21` مطبّق مسبقًا فالكود
2. أعطِ صلاحية الكاميرا عند أول تشغيل
3. ابدأ بالوضع الرأسي (portraitUp) — إلا عد العقلات خدم صحيح، جرب تدوير
   الهاتف للتأكد أن معالجة `sensorOrientation`/`deviceOrientation` صحيحة على
   جهازك تحديدًا (بعض الأجهزة الصينية تُبلّغ `sensorOrientation` بقيم غير
   معتادة، فاختبر قبل الاعتماد الكامل)
4. الكاميرا الأمامية قد تعكس الصورة أفقيًا (mirroring) — هذا لا يؤثر على حساب
   زاوية المرفق لأنه تناظري، لكن انتبه له إذا أضفت لاحقًا رسم نقاط الهيكل فوق
   المعاينة (overlay) لأن الإحداثيات ستحتاج عكسًا أفقيًا مطابقًا

## الخطوة التالية المقترحة

اختر واحدة: (أ) ابدأ فعليًا بجمع صور سجادة الصلاة ورفعها على Teachable Machine
لتصدير أول نسخة من `rug_classifier.tflite` (الكود المستقبِل جاهز وينتظر
الملف فقط)، أو (ب) اختبر خدمة القفل نفسها (`LockForegroundService`) بتطبيق
وهمي واحد قبل ربط باقي الميزات، أو (ج) اضبط عتبات زاوية المرفق
(`_downAngleThreshold` / `_upAngleThreshold` في `rep_camera_screen.dart`) بعد
تجربة العدّ على جهاز حقيقي — القيم الحالية (90° / 160°) تقديرية وقد تحتاج
تعديلًا حسب زاوية الكاميرا الفعلية.
