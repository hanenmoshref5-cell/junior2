# ملاحظات تقنية إضافية

## البنية الرياضية للدوال

### 1. Moving Average Filter
```
للنقطة i:
y[i] = (1/(2k+1)) * Σ(x[j]) for j in [i-k, i+k]

حيث k = windowSize / 2

مثال (windowSize=7):
y[3] = (x[0] + x[1] + x[2] + x[3] + x[4] + x[5] + x[6]) / 7
```

### 2. Exponential Low-Pass Filter
```
y[0] = x[0]
y[i] = α * x[i] + (1 - α) * y[i-1]

حيث α = معامل التنعيم (0.2)

المعنى:
- α كبير (0.7+) = سريع الاستجابة، أقل تنعيماً
- α صغير (0.1-) = بطيء الاستجابة، أكثر تنعيماً
```

### 3. Peak Detection Algorithm
```
لكل نقطة i (1 < i < length-1):
  إذا (signal[i] > signal[i-1]) AND 
     (signal[i] > signal[i+1]) AND
     (signal[i] > threshold)
  {
    إذا (peaks.isEmpty || i - peaks[-1] >= minDistance)
    {
      peaks.add(i)
    }
  }
```

### 4. Adaptive Threshold
```
μ = mean(signal)
σ = stdDev(signal)
threshold = μ + 0.5 * σ

التفسير:
- تقسم الإشارة إلى قسمين
- تأخذ أعلى 30% من الإشارة تقريباً كقمم محتملة
```

### 5. BPM Calculation
```
intervals = [فاصل زمني بين كل قمتين متتاليتين]

تصفية الشواذ (IQR Method):
  Q1 = عنصر 25% من intervals المرتبة
  Q3 = عنصر 75% من intervals المرتبة
  IQR = Q3 - Q1
  lower_bound = Q1 - 1.5 * IQR
  upper_bound = Q3 + 1.5 * IQR

المتوسط:
  avg_interval = mean(intervals داخل الحدود)

BPM:
  BPM = 60 / avg_interval
```

---

## معدل العينات ومعايرة الوقت

### الحساب الحالي:
```dart
final samplingRate = 30.0;  // إطار/ثانية تقريبي

// لتحديد أكثر دقة، استخدم:
Stopwatch sw = Stopwatch()..start();
int frameCount = 0;
// ... بعد التقاط X إطارات
sw.stop();
double actualRate = frameCount / (sw.elapsedMilliseconds / 1000.0);
```

### التحويلات الزمنية:
```
1 second = 30 frames (@ 30 Hz)
0.5 seconds = 15 frames
1 BPM = 1 beat per 60 seconds

إذا كان لديك:
- 18 قمة في 17 ثانية
- المتوسط = 17/18 = 0.944 ثانية/قمة
- BPM = 60/0.944 = 63.5 نبضة/دقيقة
```

---

## اعتبارات الأداء (Performance)

### Complexity Analysis:

| الدالة | Time | Space |
|-------|------|-------|
| `_removeDC()` | O(n) | O(n) |
| `_applyMovingAverage()` | O(n*w) | O(n) |
| `_applyLowPassFilter()` | O(n) | O(n) |
| `_detectPeaks()` | O(n) | O(k) |
| `_calculateBPM()` | O(k log k) | O(k) |

حيث:
- n = عدد النقاط في الإشارة
- w = حجم النافذة (7)
- k = عدد القمم

### التحسينات المستقبلية:
```dart
// استخدام Convolution بدلاً من Moving Average (أسرع)
List<double> _applyMovingAverageOptimized(List<double> signal) {
  // باستخدام cumulative sum
  List<double> cumsum = [0.0];
  for (double v in signal) {
    cumsum.add(cumsum.last + v);
  }
  
  List<double> filtered = [];
  int w = 7;
  for (int i = 0; i < signal.length; i++) {
    int start = max(0, i - w ~/ 2);
    int end = min(signal.length, i + w ~/ 2 + 1);
    filtered.add((cumsum[end] - cumsum[start]) / (end - start));
  }
  return filtered;
}
```

---

## اختبار الواقعية (Sanity Checks)

قبل الاعتماد على النتائج، تحقق:

```dart
// 1. عدد القمم معقول؟
assert(detectedPeaks.length > 0, "No peaks detected");
assert(detectedPeaks.length < signalLength / 5, "Too many peaks");

// 2. BPM في النطاق المعقول؟
assert(calculatedBPM >= 30 && calculatedBPM <= 200, "BPM out of range");

// 3. الفواصل الزمنية متشابهة؟
double cv = calculateCoefficientOfVariation(intervals);
assert(cv < 0.5, "Intervals too variable");

// 4. الإشارة المفلترة أقل ضجيجاً من الأصلية؟
double noiseOriginal = calculateVariance(greenSignal);
double noiseFiltered = calculateVariance(filteredGreenSignal);
assert(noiseFiltered < noiseOriginal, "Filtering didn't reduce noise");
```

---

## حالات خاصة من المشاكل

### مشكلة: الإشارة مسطحة تماماً
```
السبب: الكاميرا مغلقة أو بدون إضاءة
الحل: تأكد من استخدام الكاميرا الأمامية والإضاءة كافية
```

### مشكلة: نبضات في أوقات عشوائية
```
السبب: الضجيج كبير جداً أو الإصبع يتحرك
الحل: ثبت الإصبع بشكل أفضل، أو قلل معامل العتبة
```

### مشكلة: BPM يتغير كثيراً
```
السبب: تحركات عضلية أو اهتزازات
الحل: استخدم averaging على عدة قياسات
```

---

## الصيغ الإحصائية المستخدمة

### المتوسط (Mean):
```
μ = (1/n) * Σx[i]
```

### الانحراف المعياري (Standard Deviation):
```
σ = √[ (1/n) * Σ(x[i] - μ)² ]
```

### الربيعيات (Quartiles):
```
Q1 = median(نصف البيانات الأقل)
Q3 = median(نصف البيانات الأكثر)
IQR = Q3 - Q1
```

### معامل الاختلاف (Coefficient of Variation):
```
CV = σ / μ
```
يشير إلى **الاتساق** - CV منخفضة = قمم متسقة

---

## تحسينات مستقبلية ممكنة

### 1. استخدام FFT (Fast Fourier Transform)
```dart
// للكشف عن التردد الأساسي بدلاً من البحث عن القمم
// يعطي نتائج أفضل في الضجيج العالي
```

### 2. Kalman Filter
```dart
// لتتبع القيمة وإزالة الضجيج بكفاءة أعلى
```

### 3. Wavelet Transform
```dart
// لتحليل متعدد الدقة (Multi-resolution analysis)
```

### 4. Machine Learning
```dart
// تدريب نموذج على بيانات حقيقية للكشف الأفضل
```

### 5. Multisensor Fusion
```dart
// دمج بيانات من حساسات متعددة للدقة الأعلى
```

---

## المراجع والمعايير

### معايير قياس النبض الطبي:
```
الراحة (عادي):        60-100 BPM
الرياضي المدرب:       40-60 BPM
الرضع والأطفال:       100-160 BPM
الحوامل:             70-80+ BPM
المرضى:              قد يتجاوز 120 BPM
```

### معدل أخذ العينات الموصى به:
```
Nyquist Theorem: fs >= 2 * f_max

للقلب (أقصى تردد ≈ 10 Hz):
fs >= 20 Hz

نحن نستخدم ≈ 30 Hz (كافٍ)
```

### معايير الدقة:
```
±5 BPM = ممتاز (احترافي)
±10 BPM = جيد (استهلاكي)
±20 BPM = مقبول
>20 BPM = غير موثوق
```

---

## ملاحظات تصحيح الأخطاء الشائعة

### ❌ خطأ شائع 1: استخدام القيمة الأولى كـ threshold ثابت
```dart
// ❌ خطأ:
double threshold = signal[0] * 1.5;

// ✅ صحيح:
double mean = signal.reduce((a,b)=>a+b) / signal.length;
double stdDev = calculateStdDev(signal);
double threshold = mean + 0.5 * stdDev;
```

### ❌ خطأ شائع 2: عدم تصفية القيم الشاذة
```dart
// ❌ خطأ:
double avg = intervals.reduce((a,b)=>a+b) / intervals.length;

// ✅ صحيح:
// استخدام IQR كما في _calculateBPM()
```

### ❌ خطأ شائع 3: عدم التحقق من المسافة الدنيا
```dart
// ❌ خطأ:
if (signal[i] > threshold) peaks.add(i);

// ✅ صحيح:
if (signal[i] > threshold && 
    (peaks.isEmpty || i - peaks.last >= minDistance)) {
  peaks.add(i);
}
```

---

## الخلاصة

تم تطبيق دوال معالجة إشارة متقدمة وفقاً لأفضل الممارسات:
- ✅ إزالة التشويش بشكل فعال
- ✅ اكتشاف دقيق للقمم
- ✅ حساب BPM مستقر
- ✅ معالجة الحالات الحدية
- ✅ أداء جيدة

