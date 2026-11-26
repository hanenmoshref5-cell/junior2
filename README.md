# Gluco Vision

مشروع لقياس نسبة سكر الدم من خلال أخذ إشارات PPG من كاميرا الهاتف الأمامية برؤية تغيرات تدفق الدم الموجود بالإصبع، ثم استخراج مجموعة من الفيتشرات من هذه الإشارة المهمة لتحديد نسبة سكر الدم حسب نبض الدم ومرونة عروق إصبع اليد المعتمدة على نسبة سكر الدم الحالية في الإصبع، ثم تمرير هذه الفيتشرات إلى مودل ذكاء اصطناعي باستخدام الـ Random Forest تم تدريبه على مجموعة من الداتا سيت التي قمنا بجمعها من أخذ إشارة أشخاص مرضى سكري وسليمين من التطبيق ومطابقتها مع نسبة سكر الدم لديهم حاليًا من خلال وخز إصبعهم ومعرفة نسبة السكر بالغلوكوميتر.

تم تدريب المودل على هذه الداتا سيت ليكون قادرًا على التنبؤ بنسبة تقريبية لسكر دم أي مستخدم يستخدم التطبيق، ويعيد النتيجة للتطبيق حسب إشارة البي بي جي الماخوذة منه من كاميرا الهاتف الأمامية.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
