import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:math';
import '../signal_processing.dart';

// Dark Mode Colors Configuration

const Color kDarkBrown = Color.fromARGB(255, 63, 56, 55);

const Color kBeige = Color(0xFFE8DCC4);

const Color kRed = Color.fromARGB(255, 220, 53, 69);

class Measurefinger extends StatefulWidget {
  const Measurefinger({super.key});

  @override
  State<Measurefinger> createState() => _MeasurefingerState();
}

class _MeasurefingerState extends State<Measurefinger> {
  CameraController? _cameraController;

  bool isRecording = false;

  bool cameraInitialized = false;

  bool isAutoDetectionMode = false; // 🎯 وضع البحث التلقائي عن إصبع صحيح

  // ===== إدارة التايمرات =====

  Timer? _recordingTimer; // عداد الثواني

  Timer? _stabilityTimer; // عداد استقرار الإشارة

  Timer? _stopTimer; // مؤقت الإيقاف بعد 20 ثانية

  Timer? _autoMonitorTimer; // مراقبة تلقائية لبدء القياس

  Timer? _uiRefreshTimer; // تحديث الرسم بشكل مجمع وليس لحظي

  bool _isAbortingMeasurement = false;

  // PPG Signal tracking

  List<double> redSignal = [];

  List<double> greenSignal = [];

  List<double> blueSignal = [];

  final List<double> _pendingRed = [];

  final List<double> _pendingGreen = [];

  final List<double> _pendingBlue = [];

  static const int UI_UPDATE_INTERVAL_MS = 250;

  static const double ZOOM_SMOOTHING_ALPHA = 0.18;

  double? _smoothedMinY;

  double? _smoothedMaxY;

  double averageRed = 0.0;

  double averageGreen = 0.0;

  double averageBlue = 0.0;

  // ===== نتائج معالجة الإشارة =====

  int detectedPulses = 0; // عدد النبضات المكتشفة

  double estimatedHeartRate = 0.0; // معدل النبض التقريبي (BPM)

  double signalAmplitude = 0.0; // السعة (السعة القصوى للإشارة)

  double signalStandardDeviation = 0.0; // الانحراف المعياري

  double coefficientOfVariation = 0.0; // معامل الاختلاف (CV%)

  double hrvValue = 0.0; // Heart Rate Variability

  double signalQuality = 0.0; // جودة الإشارة 0..100

  int detectedDicroticNotches = 0; // عدد الشقوق الديكروتية

  List<double> processedGreenSignal = [];

  List<int> processedPeakIndices = [];

  // UI State

  String status = "اضغط على فعل القياس";

  int recordingSeconds = 0;

  // Chart line visibility

  bool showRedLine = true;

  bool showGreenLine = true;

  bool showBlueLine = true;

  // Chart scroll/navigation

  int chartOffset = 0; // كم نقطة نرجع للخلف

  double pixelsPerPoint = 3.0; // عرض كل نقطة بالبكسل - كلما قل الرقم زادت الدقة

  // ===== كشف وضع الإصبع (Finger Placement Detection) =====

  // نطاق الإضاءة المقبول عند تغطية العدسة بالإصبع

  static const double BRIGHTNESS_MIN = 15.0;

  static const double BRIGHTNESS_MAX = 180.0;

  // عتبات الحركة (نستخدم عتبة تكيفية + عتبة صلبة)

  static const double SOFT_MOTION_THRESHOLD = 14.0;

  static const double HARD_MOTION_THRESHOLD = 32.0;

  static const int BRIGHTNESS_WINDOW = 12;

  // static const int MOTION_CONSECUTIVE_LIMIT = 8;

  double lastBrightness = 0.0;

  double currentBrightness = 0.0;

  int validPlacementCount = 0;

  int invalidPlacementCount = 0;

  bool isFingerPlacedCorrectly = false;

  String placementStatus = "ضع إصبعك على الكاميرا";

  final List<double> recentBrightness = [];

  // فترة التسخين (Warmup Period) - الفترة التي ننتظرها قبل عرض الإشارة

  static const int WARMUP_SECONDS = 3; // الانتظار 3 ثواني

  int warmupCounter = 0; // عداد ثواني التسخين

  bool isWarmupComplete = false; // هل انتهت فترة التسخين

  // استقرار الإشارة (Signal Stability)

  static const int MOVING_AVERAGE_WINDOW = 10; // عدد النقاط للمتوسط المتحرك

  static const double STABILITY_THRESHOLD =
      2.0; // حد الاستقرار (معدل التغير المقبول)

  static const double STABILITY_LOSS_THRESHOLD =
      4.0; // الحد الأقصى للكشف عن فقدان الاستقرار المفاجئ

  double signalStability = 0.0; // مقياس استقرار الإشارة (0-100%)

  double previousStability = -1.0; // الاستقرار السابق

  bool isSignalStable = false; // هل الإشارة مستقرة

  bool wasStableLastCheck = false; // لتتبع تغيير حالة الاستقرار

  int consecutiveUnstableCount = 0; // عدد مرات عدم الاستقرار المتتالية

  @override
  void initState() {
    super.initState();

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isNotEmpty) {
        final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,

          orElse: () => cameras.first,
        );

        _cameraController = CameraController(
          frontCamera,

          ResolutionPreset.high,

          enableAudio: false,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            cameraInitialized = true;
          });

          // 🔧 لا تبدأ البحث التلقائي تلقائياً - سيبدأ عند الضغط على الزر
        }
      }
    } catch (e) {
      print('خطأ في تهيئة الكاميرا: $e');
    }
  }

  /// 🎯 بدء البحث التلقائي عن وضع إصبع صحيح ثم البدء بالتسجيل
  void _startAutoDetectionMode() {
    _autoMonitorTimer?.cancel();

    setState(() {
      isAutoDetectionMode = true;
      status = "🔍 جاري البحث... ضع إصبعك على الكاميرا بشكل صحيح";
    });

    _autoMonitorTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // إيقاف إذا ألغى المستخدم الوضع التلقائي
      if (!isAutoDetectionMode) {
        timer.cancel();
        return;
      }

      // إذا كان هناك تسجيل، لا تفعل شيء (دع التسجيل يكمل)
      if (isRecording) {
        return;
      }

      // إيقاف البحث والزر بعد 60 ثانية من البحث
      // بهذه الطريقة لا ننسى أن نوقفه
      // (في حالة لم يتمكن من وضع الإصبع بشكل صحيح)
      return;
    });
  }

  /// ❌ إيقاف البحث التلقائي والتسجيل
  void _stopAutoDetectionMode() {
    _autoMonitorTimer?.cancel();
    _autoMonitorTimer = null;

    setState(() {
      isAutoDetectionMode = false;
      status = "تم إيقاف البحث التلقائي";
    });

    // إيقاف التسجيل إن كان قيد الجري
    if (isRecording) {
      stopMeasurement();
    }
  }

  /// 🎯 التبديل بين بدء البحث التلقائي وإيقافه
  void _toggleAutoDetectionMode() {
    if (isAutoDetectionMode) {
      // إيقاف البحث التلقائي والتسجيل
      _stopAutoDetectionMode();
    } else {
      // بدء البحث التلقائي
      _startAutoDetectionMode();
      _captureFramesForAutoDetection();
    }
  }

  /// 🎯 بدء التقاط الإطارات + مراقبة وضع الإصبع للبحث التلقائي
  void _captureFramesForAutoDetection() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        !isAutoDetectionMode) {
      return;
    }

    try {
      // إيقاف stream قديم
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
      } catch (e) {
        print('معلومة: لا توجد stream سابقة');
      }

      // استخدام image stream لمراقبة وضع الإصبع
      int correctPlacementFrames = 0;
      const int REQUIRED_CORRECT_FRAMES = 10; // 10 إطارات صحيحة متتالية

      await _cameraController!.startImageStream((CameraImage image) async {
        // إيقاف إذا توقف البحث التلقائي
        if (!isAutoDetectionMode || isRecording) {
          return;
        }

        _processImageForDetection(image, (isCorrect) {
          if (isCorrect) {
            correctPlacementFrames++;
            print('✅ إطار صحيح: $correctPlacementFrames');

            if (correctPlacementFrames >= REQUIRED_CORRECT_FRAMES &&
                isAutoDetectionMode &&
                !isRecording) {
              // بدء التسجيل!
              print('🎬 تم كشف وضع صحيح! بدء التسجيل...');
              startMeasurement();
              correctPlacementFrames = 0;
            }
          } else {
            correctPlacementFrames = 0;
            print('❌ وضع خاطئ، إعادة عداد');
          }
        });
      });
    } catch (e) {
      print('خطأ في مراقبة الإصبع: $e');
    }
  }

  /// فحص صورة واحدة للتحقق من وضع الإصبع
  void _processImageForDetection(CameraImage image, Function(bool) onResult) {
    try {
      final width = image.width;
      final height = image.height;

      int totalRed = 0;
      int totalGreen = 0;
      int totalBlue = 0;
      int pixelCount = 0;

      // تحديد نطاق العينة من الوسط
      final centerX = (width / 2).toInt();
      final centerY = (height / 2).toInt();
      final sampleSize = 100;
      final minX = (centerX - sampleSize).clamp(0, width - 1);
      final maxX = (centerX + sampleSize).clamp(0, width);
      final minY = (centerY - sampleSize).clamp(0, height - 1);
      final maxY = (centerY + sampleSize).clamp(0, height);

      if (image.planes.isNotEmpty) {
        final plane = image.planes[0];

        // معالجة BGRA8888 أو RGBA8888
        if (image.format.group == ImageFormatGroup.bgra8888) {
          final pixelStride = plane.bytesPerPixel ?? 4;
          final isBGRA = image.format.group == ImageFormatGroup.bgra8888;

          for (int y = minY; y < maxY; y++) {
            for (int x = minX; x < maxX; x++) {
              final index = (y * plane.bytesPerRow) + (x * pixelStride);

              if (index + 2 < plane.bytes.length) {
                final int r = isBGRA
                    ? plane.bytes[index + 2]
                    : plane.bytes[index];
                final int g = plane.bytes[index + 1];
                final int b = isBGRA
                    ? plane.bytes[index]
                    : plane.bytes[index + 2];

                totalRed += r;
                totalGreen += g;
                totalBlue += b;
                pixelCount++;
              }
            }
          }
        } else if (image.format.group == ImageFormatGroup.nv21 ||
            image.format.group == ImageFormatGroup.yuv420) {
          final yPlane = image.planes[0];
          final uPlane = image.planes[1];
          final vPlane = image.planes.length > 2 ? image.planes[2] : null;

          final uvPixelStride = uPlane.bytesPerPixel ?? 1;

          for (int y = minY; y < maxY; y++) {
            for (int x = minX; x < maxX; x++) {
              final yIndex = y * yPlane.bytesPerRow + x;

              if (yIndex < yPlane.bytes.length) {
                final yVal = yPlane.bytes[yIndex].toDouble();

                final uvX = x ~/ 2;
                final uvY = y ~/ 2;
                final uvIndex = uvY * uPlane.bytesPerRow + uvX * uvPixelStride;

                if (uvIndex >= uPlane.bytes.length) continue;

                double uVal = uPlane.bytes[uvIndex].toDouble();
                double vVal = 0.0;

                if (vPlane != null && uvIndex < vPlane.bytes.length) {
                  vVal = vPlane.bytes[uvIndex].toDouble();
                } else if (image.format.group == ImageFormatGroup.nv21 &&
                    uvIndex + 1 < uPlane.bytes.length) {
                  vVal = uPlane.bytes[uvIndex + 1].toDouble();
                } else {
                  continue;
                }

                final yNorm = (yVal - 16) / 255.0;
                final uNorm = (uVal - 128) / 255.0;
                final vNorm = (vVal - 128) / 255.0;

                var r = (yNorm + 1.4075 * vNorm).clamp(0.0, 1.0) * 255.0;
                var g =
                    (yNorm - 0.3455 * uNorm - 0.7169 * vNorm).clamp(0.0, 1.0) *
                    255.0;
                var b = (yNorm + 1.7790 * uNorm).clamp(0.0, 1.0) * 255.0;

                totalRed += r.toInt();
                totalGreen += g.toInt();
                totalBlue += b.toInt();
                pixelCount++;
              }
            }
          }
        }

        if (pixelCount > 0) {
          final avgRed = totalRed / pixelCount;
          final avgGreen = totalGreen / pixelCount;
          final avgBlue = totalBlue / pixelCount;

          // فحص وضع الإصبع
          bool isCorrect = _analyzeFingerPlacement(avgRed, avgGreen, avgBlue);
          onResult(isCorrect);
        }
      }
    } catch (e) {
      print('خطأ في فحص الصورة: $e');
    }
  }

  Future<void> startMeasurement() async {
    if (!cameraInitialized || _cameraController == null) {
      setState(() {
        status = "الكاميرا لم تتم تهيئتها";
      });

      return;
    }

    // إيقاف أي قياس سابق

    _cancelAllTimers();

    // إيقاف الـ stream السابق إذا كان شغال

    if (_cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();

      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() {
      isRecording = true;

      _isAbortingMeasurement = false;

      status = "جاري التسخين... رجاءً انتظر...";

      recordingSeconds = 0;

      redSignal.clear();

      greenSignal.clear();

      blueSignal.clear();

      _pendingRed.clear();

      _pendingGreen.clear();

      _pendingBlue.clear();

      _smoothedMinY = null;

      _smoothedMaxY = null;

      chartOffset = 0;

      warmupCounter = 0;

      isWarmupComplete = false;

      isSignalStable = false;

      signalStability = 0.0;

      previousStability = -1.0;

      wasStableLastCheck = false;

      consecutiveUnstableCount = 0;

      // ✅ إعادة تعيين متغيرات النتائج

      detectedPulses = 0;

      estimatedHeartRate = 0.0;

      signalAmplitude = 0.0;

      signalStandardDeviation = 0.0;

      coefficientOfVariation = 0.0;

      hrvValue = 0.0;

      signalQuality = 0.0;

      detectedDicroticNotches = 0;

      processedGreenSignal.clear();

      processedPeakIndices.clear();

      // ✅ إعادة تعيين متغيرات فحص الإصبع

      lastBrightness = 0.0;

      currentBrightness = 0.0;

      recentBrightness.clear();

      validPlacementCount = 0;

      invalidPlacementCount = 0;

      isFingerPlacedCorrectly = false;

      placementStatus = "ضع إصبعك على الكاميرا";
    });

    // بدء التقاط الإطارات

    _captureFrames();

    _startUiRefreshTimer();

    // إيقاف التسجيل بعد 20 ثانية

    _stopTimer = Timer(const Duration(seconds: 20), () {
      stopMeasurement();
    });

    // تحديث العداد وفترة التسخين

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isRecording) {
        timer.cancel();
      } else {
        setState(() {
          recordingSeconds++;

          // إدارة فترة التسخين

          if (!isWarmupComplete && warmupCounter < WARMUP_SECONDS) {
            warmupCounter++;

            if (warmupCounter >= WARMUP_SECONDS) {
              isWarmupComplete = true;

              status = "جاري البحث عن استقرار الإشارة...";
            }
          }
        });
      }
    });

    // تحديث مستوى الاستقرار كل 0.5 ثانية

    _stabilityTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (!isRecording) {
        timer.cancel();
      } else {
        setState(() {
          _updateSignalStability();
        });
      }
    });
  }

  /// إلغاء جميع التايمرات

  void _cancelAllTimers() {
    _recordingTimer?.cancel();

    _stabilityTimer?.cancel();

    _stopTimer?.cancel();

    _uiRefreshTimer?.cancel();

    _recordingTimer = null;

    _stabilityTimer = null;

    _stopTimer = null;

    _uiRefreshTimer = null;
  }

  void _startUiRefreshTimer() {
    _uiRefreshTimer?.cancel();

    _uiRefreshTimer = Timer.periodic(
      const Duration(milliseconds: UI_UPDATE_INTERVAL_MS),

      (timer) {
        if (!isRecording || !mounted) {
          timer.cancel();

          return;
        }

        _flushPendingSignalToUi();
      },
    );
  }

  void _flushPendingSignalToUi({bool forceRebuild = true}) {
    if (_pendingRed.isEmpty && _pendingGreen.isEmpty && _pendingBlue.isEmpty) {
      return;
    }

    redSignal.addAll(_pendingRed);

    greenSignal.addAll(_pendingGreen);

    blueSignal.addAll(_pendingBlue);

    _pendingRed.clear();

    _pendingGreen.clear();

    _pendingBlue.clear();

    if (forceRebuild && mounted) {
      setState(() {});
    }
  }

  // ===== دوال حساب استقرار الإشارة =====

  /// حساب الانحراف المعياري (Standard Deviation)

  double _calculateStandardDeviation(List<double> signal) {
    if (signal.length < 2) return 0.0;

    // استخدام آخر MOVING_AVERAGE_WINDOW نقطة فقط

    int windowSize = min(MOVING_AVERAGE_WINDOW, signal.length);

    // حساب المتوسط

    double mean = 0.0;

    for (int i = signal.length - windowSize; i < signal.length; i++) {
      mean += signal[i];
    }

    mean /= windowSize;

    // حساب الانحراف المعياري

    double variance = 0.0;

    for (int i = signal.length - windowSize; i < signal.length; i++) {
      double diff = signal[i] - mean;

      variance += diff * diff;
    }

    variance /= windowSize;

    return sqrt(variance);
  }

  /// تحديث مستوى الاستقرار والتحقق من استقرار الإشارة

  void _updateSignalStability() {
    if (greenSignal.length < MOVING_AVERAGE_WINDOW * 2) {
      isSignalStable = false;

      signalStability = 0.0;

      return;
    }

    // ✅ طريقة محسّنة: حساب الانحراف المعياري (Standard Deviation)

    // بدلاً من معدل التغير البسيط

    double stdDev = _calculateStandardDeviation(greenSignal);

    // حساب مستوى الاستقرار: كلما قل الانحراف، كلما كانت الإشارة أكثر استقراراً

    // نحول الانحراف إلى نسبة استقرار (0-100%)

    // إذا كان stdDev = 5، الاستقرار = 100%

    // إذا كان stdDev = 25، الاستقرار = 0%

    double maxStdDev = 20.0; // الحد الأقصى المتوقع للانحراف

    signalStability = ((1.0 - (stdDev / maxStdDev).clamp(0.0, 1.0)) * 100)
        .clamp(0.0, 100.0);

    if (previousStability < 0) {
      // أول قراءة بعد التسخين: لا نعتبرها هبوطا مفاجئا

      previousStability = signalStability;

      isSignalStable = signalStability > 35.0;

      return;
    }

    // 🔍 الكشف عن انخفاض مفاجئ في الاستقرار (حركة مفاجئة)

    double stabilityDrop = previousStability - signalStability;

    print(
      '📊 Stability: ${signalStability.toStringAsFixed(1)}% | '
      'Previous: ${previousStability.toStringAsFixed(1)}% | '
      'Drop: ${stabilityDrop.toStringAsFixed(1)}% | '
      'StdDev: ${stdDev.toStringAsFixed(2)}',
    );

    // ✅ عند هبوط حاد في الاستقرار بعد التسخين: إيقاف فوري

    if (recordingSeconds > WARMUP_SECONDS &&
        signalStability < 30.0 &&
        stabilityDrop > (STABILITY_LOSS_THRESHOLD * 8.5)) {
      _abortMeasurementImmediate(
        "⚠️ تم اكتشاف حركة/اهتزاز في الإصبع. أعد القياس.",
      );

      return;
    } else {
      // إعادة تعيين العداد إذا عادت الإشارة للاستقرار

      if (signalStability > 52.0) {
        consecutiveUnstableCount = 0;
      }
    }

    isSignalStable =
        signalStability > STABILITY_THRESHOLD * 20; // 40% استقرار أو أكثر

    previousStability = signalStability;

    wasStableLastCheck = isSignalStable;
  }

  /// فحص موضع الإصبع على الكاميرا

  /// يتحقق من: السطوع، التجانس، الحركة

  bool _analyzeFingerPlacement(double avgRed, double avgGreen, double avgBlue) {
    // حساب السطوع (متوسط قيم RGB)

    currentBrightness = (avgRed + avgGreen + avgBlue) / 3.0;

    // تحديث نافذة السطوع

    recentBrightness.add(currentBrightness);

    if (recentBrightness.length > BRIGHTNESS_WINDOW) {
      recentBrightness.removeAt(0);
    }

    double meanBrightness = recentBrightness.isEmpty
        ? currentBrightness
        : recentBrightness.reduce((a, b) => a + b) / recentBrightness.length;

    double variance = 0.0;

    for (final v in recentBrightness) {
      final d = v - meanBrightness;

      variance += d * d;
    }

    final rollingStd = recentBrightness.isEmpty
        ? 0.0
        : sqrt(variance / recentBrightness.length);

    // 1️⃣ فحص السطوع: مرن ويقبل التغير الطبيعي

    bool isCovered =
        currentBrightness >= BRIGHTNESS_MIN &&
        currentBrightness <= BRIGHTNESS_MAX;

    bool hasFingerColorProfile = avgRed >= (avgBlue * 0.85);

    // 2️⃣ فحص الحركة: عتبة تكيفية تمنع رفض نبضات PPG الطبيعية

    double brightnessDifference = lastBrightness == 0.0
        ? 0.0
        : (currentBrightness - lastBrightness).abs();

    double adaptiveMotionThreshold = max(
      SOFT_MOTION_THRESHOLD,

      rollingStd * 3.8,
    );

    bool isMotionDetected =
        brightnessDifference > HARD_MOTION_THRESHOLD ||
        (brightnessDifference > adaptiveMotionThreshold &&
            validPlacementCount > 3);

    // ✅ الشروط الصحيحة

    bool isValid = isCovered && hasFingerColorProfile && !isMotionDetected;

    // 🔍 Debug Print

    print(
      '📸 Brightness: ${currentBrightness.toStringAsFixed(1)} | '
      'Diff: ${brightnessDifference.toStringAsFixed(1)} | '
      'Std: ${rollingStd.toStringAsFixed(1)} | '
      'Covered: $isCovered | Motion: $isMotionDetected | Valid: $isValid',
    );

    // تحديث عداد الإطارات الصحيحة

    if (isValid) {
      validPlacementCount++;

      invalidPlacementCount = 0; // إعادة تعيين عداد الأخطاء

      if (validPlacementCount >= 4) {
        // 5 إطارات متتالية صحيحة

        isFingerPlacedCorrectly = true;

        placementStatus = "✅ الإصبع موضوع بشكل صحيح";
      }
    } else {
      invalidPlacementCount++;

      if (invalidPlacementCount >= 2) {
        validPlacementCount = 0;
      }

      isFingerPlacedCorrectly = false;

      if (!isCovered) {
        placementStatus = "❌ ضع إصبعك على الكاميرا بالكامل";
      } else if (!hasFingerColorProfile) {
        placementStatus = "⚠️ اضغط إصبعك بالكامل على العدسة";
      } else if (isMotionDetected) {
        placementStatus = "⚠️ ثبت إصبعك! تجنب الحركة";
      }

      // إيقاف فوري عند إزالة الإصبع أو تحركه/اهتزازه

      if (isRecording) {
        _abortMeasurementImmediate(placementStatus);

        return false;
      }
    }

    lastBrightness = currentBrightness;

    return isValid;
  }

  /// إيقاف فوري للتسجيل والعرض عند فقدان شرط القياس

  void _abortMeasurementImmediate(String reason) {
    if (_isAbortingMeasurement || !isRecording) return;

    _isAbortingMeasurement = true;

    _cancelAllTimers();

    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }

    if (mounted) {
      setState(() {
        isRecording = false;

        redSignal.clear();

        greenSignal.clear();

        blueSignal.clear();

        _pendingRed.clear();

        _pendingGreen.clear();

        _pendingBlue.clear();

        _smoothedMinY = null;

        _smoothedMaxY = null;

        chartOffset = 0;

        isWarmupComplete = false;

        isSignalStable = false;

        signalStability = 0.0;

        detectedPulses = 0;

        estimatedHeartRate = 0.0;

        signalAmplitude = 0.0;

        signalStandardDeviation = 0.0;

        coefficientOfVariation = 0.0;

        hrvValue = 0.0;

        signalQuality = 0.0;

        detectedDicroticNotches = 0;

        processedGreenSignal.clear();

        processedPeakIndices.clear();

        placementStatus = reason;

        status = reason;
      });
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      _isAbortingMeasurement = false;
    });
  }

  /// إعادة بدء القياس عند فقدان الاستقرار
  // void _restartMeasurement() {
  //   if (!isRecording) return;

  //   print('🔄 إعادة بدء القياس بسبب فقدان الاستقرار...');

  //   setState(() {
  //     isRecording = false; // ✅ إيقاف التسجيل فوراً
  //   });

  //   // ✅ إيقاف جميع التايمرات

  //   _cancelAllTimers();

  //   // ✅ إيقاف stream الكاميرا

  //   if (_cameraController != null &&
  //       _cameraController!.value.isStreamingImages) {
  //     _cameraController!.stopImageStream();
  //   }

  //   // ✅ الانتظار قليلاً ثم بدء قياس جديد

  //   Future.delayed(const Duration(milliseconds: 800), () {
  //     if (mounted) {
  //       // إعادة تعيين جميع المتغيرات

  //       setState(() {
  //         redSignal.clear();

  //         greenSignal.clear();

  //         blueSignal.clear();

  //         _pendingRed.clear();

  //         _pendingGreen.clear();

  //         _pendingBlue.clear();

  //         _smoothedMinY = null;

  //         _smoothedMaxY = null;

  //         chartOffset = 0;

  //         warmupCounter = 0;

  //         isWarmupComplete = false;

  //         isSignalStable = false;

  //         wasStableLastCheck = false;

  //         consecutiveUnstableCount = 0;

  //         signalStability = 0.0;

  //         previousStability = -1.0;

  //         recordingSeconds = 0;

  //         // ✅ إعادة تعيين متغيرات فحص الإصبع

  //         lastBrightness = 0.0;

  //         currentBrightness = 0.0;

  //         recentBrightness.clear();

  //         validPlacementCount = 0;

  //         invalidPlacementCount = 0;

  //         isFingerPlacedCorrectly = false;

  //         placementStatus = "ضع إصبعك على الكاميرا";

  //         status = "⚠️ تم اكتشاف حركة! بدء القياس من جديد...";
  //       });

  //       // بدء قياس جديد تماماً

  //       Future.delayed(const Duration(milliseconds: 500), () {
  //         if (mounted) {
  //           startMeasurement();
  //         }
  //       });
  //     }
  //   });
  // }

  void _captureFrames() async {
    if (!isRecording ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // استخدام image stream لالتقاط الإطارات

      _cameraController!.startImageStream((CameraImage image) async {
        if (isRecording) {
          _processImage(image);
        }
      });
    } catch (e) {
      print('خطأ في التقاط الإطارات: $e');
    }
  }

  void _processImage(CameraImage image) {
    try {
      final width = image.width;

      final height = image.height;

      int totalRed = 0;

      int totalGreen = 0;

      int totalBlue = 0;

      int pixelCount = 0;

      // تحديد نطاق العينة من الوسط

      final centerX = (width / 2).toInt();

      final centerY = (height / 2).toInt();

      final sampleSize = 100;

      final minX = (centerX - sampleSize).clamp(0, width - 1);

      final maxX = (centerX + sampleSize).clamp(0, width);

      final minY = (centerY - sampleSize).clamp(0, height - 1);

      final maxY = (centerY + sampleSize).clamp(0, height);

      print(
        'Image format: ${image.format.group}, Size: ${width}x$height, Planes: ${image.planes.length}',
      );

      if (image.planes.isNotEmpty) {
        final plane = image.planes[0];

        // معالجة BGRA8888 أو RGBA8888

        if (image.format.group == ImageFormatGroup.bgra8888) {
          print('Processing BGRA8888/RGBA8888 format');

          final pixelStride = plane.bytesPerPixel ?? 4;

          // فحص هل الترتيب يبدأ بـ Blue أم Red؟

          // نظام iOS غالباً BGRA، بعض الأندرويد RGBA

          final isBGRA = image.format.group == ImageFormatGroup.bgra8888;

          for (int y = minY; y < maxY; y++) {
            for (int x = minX; x < maxX; x++) {
              final index = (y * plane.bytesPerRow) + (x * pixelStride);

              if (index + 2 < plane.bytes.length) {
                // في BGRA: الخانة 0 هي b، والخانة 2 هي r

                // في RGBA: الخانة 0 هي r، والخانة 2 هي b

                final int r = isBGRA
                    ? plane.bytes[index + 2]
                    : plane.bytes[index];

                final int g =
                    plane.bytes[index + 1]; // الأخضر دائماً في المنتصف

                final int b = isBGRA
                    ? plane.bytes[index]
                    : plane.bytes[index + 2];

                totalRed += r;

                totalGreen += g;

                totalBlue += b;

                pixelCount++;
              }
            }
          }
        }
        // معالجة NV21 و YUV420
        else if (image.format.group == ImageFormatGroup.nv21 ||
            image.format.group == ImageFormatGroup.yuv420) {
          print('Processing NV21/YUV420 format');

          final yPlane = image.planes[0];

          final uPlane = image.planes[1];

          final vPlane = image.planes.length > 2 ? image.planes[2] : null;

          final uvPixelStride = uPlane.bytesPerPixel ?? 1;

          for (int y = minY; y < maxY; y++) {
            for (int x = minX; x < maxX; x++) {
              final yIndex = y * yPlane.bytesPerRow + x;

              if (yIndex < yPlane.bytes.length) {
                final yVal = yPlane.bytes[yIndex].toDouble();

                // الحصول على U و V بشكل صحيح

                final uvX = x ~/ 2;

                final uvY = y ~/ 2;

                final uvIndex = uvY * uPlane.bytesPerRow + uvX * uvPixelStride;

                // قراءة القيم الفعلية من البيانات بدون استخدام قيم افتراضية

                double uVal = 0.0;

                double vVal = 0.0;

                if (uvIndex >= uPlane.bytes.length) {
                  // إذا كانت البيانات غير متوفرة، تجاهل هذا البكسل

                  continue;
                }

                uVal = uPlane.bytes[uvIndex].toDouble();

                if (vPlane != null && uvIndex < vPlane.bytes.length) {
                  vVal = vPlane.bytes[uvIndex].toDouble();
                } else if (image.format.group == ImageFormatGroup.nv21 &&
                    uvIndex + 1 < uPlane.bytes.length) {
                  // في NV21، V يأتي بعد U مباشرة في نفس الـ plane

                  vVal = uPlane.bytes[uvIndex + 1].toDouble();
                } else {
                  // إذا لم نتمكن من الحصول على V، تجاهل هذا البكسل

                  continue;
                }

                // تحويل YUV إلى RGB باستخدام الصيغة الصحيحة

                final yNorm = (yVal - 16) / 255.0;

                final uNorm = (uVal - 128) / 255.0;

                final vNorm = (vVal - 128) / 255.0;

                var r = (yNorm + 1.4075 * vNorm).clamp(0.0, 1.0) * 255.0;

                var g =
                    (yNorm - 0.3455 * uNorm - 0.7169 * vNorm).clamp(0.0, 1.0) *
                    255.0;

                var b = (yNorm + 1.7790 * uNorm).clamp(0.0, 1.0) * 255.0;

                totalRed += r.toInt();

                totalGreen += g.toInt();

                totalBlue += b.toInt();

                pixelCount++;
              }
            }
          }
        }
        // معالجة افتراضية للصيغ الأخرى
        //بجوز بلمستقبل شيلو وحط بدالو سناك بار انو موبايلك بيعطي صيغ صور غير معروفة ومافيك تستتخدم التطبيق
        else {
          print('Processing unknown format: ${image.format.group}');

          final pixelStride = plane.bytesPerPixel ?? 1;

          for (int y = minY; y < maxY; y++) {
            for (int x = minX; x < maxX; x++) {
              final index = (y * plane.bytesPerRow) + (x * pixelStride);

              if (index + 2 < plane.bytes.length) {
                totalRed += plane.bytes[index];

                totalGreen += plane.bytes[index + 1];

                totalBlue += plane.bytes[index + 2];

                pixelCount++;
              }
            }
          }
        }

        if (pixelCount > 0) {
          final avgRed = totalRed / pixelCount;

          final avgGreen = totalGreen / pixelCount;

          final avgBlue = totalBlue / pixelCount;

          print(
            'Frame processed: pixelCount=$pixelCount, RGB=(${avgRed.toInt()}, ${avgGreen.toInt()}, ${avgBlue.toInt()})',
          );

          // ✅ فحص موضع الإصبع على الكاميرا

          bool fingerPlaced = _analyzeFingerPlacement(
            avgRed,

            avgGreen,

            avgBlue,
          );

          // ✅ إضافة البيانات فقط إذا:

          // 1. انتهت فترة التسخين

          // 2. الإصبع موضوع بشكل صحيح

          if (isWarmupComplete && fingerPlaced) {
            // تجميع العينات لتحديث الرسم بشكل دفعات لتجنب التشوه اللحظي

            _pendingRed.add(avgRed);

            _pendingGreen.add(avgGreen);

            _pendingBlue.add(avgBlue);
          } else if (isWarmupComplete && !fingerPlaced && mounted) {
            // تحديث رسالة الحالة

            setState(() {
              status = placementStatus;
            });
          }
        } else {
          print('No pixels processed in this frame');
        }
      }
    } catch (e) {
      print('خطأ في معالجة الصورة: $e');
    }
  }

  void stopMeasurement() async {
    // ✅ إيقاف جميع التايمرات أولاً

    _cancelAllTimers();

    // تضمين العينات المجمعة قبل حساب المتوسطات

    _flushPendingSignalToUi(forceRebuild: false);

    // ✅ إيقاف stream الكاميرا

    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    setState(() {
      isRecording = false;

      if (redSignal.isNotEmpty) {
        averageRed = redSignal.reduce((a, b) => a + b) / redSignal.length;

        averageGreen = greenSignal.reduce((a, b) => a + b) / greenSignal.length;

        averageBlue = blueSignal.reduce((a, b) => a + b) / blueSignal.length;

        // 🔬 حساب نتائج معالجة الإشارة

        _calculateSignalMetrics(greenSignal);

        status = "تم اكتمال القياس";
      } else {
        status = "لم يتم التقاط أي بيانات";
      }
    });

    // إيقاف الفلاش

    // if (_cameraController != null) {

    //   await _cameraController!.setFlashMode(FlashMode.off);

    // }
  }

  /// 🔬 حساب معاييس الإشارة (النبض والـ HRV والسعة وغيرها)

  void _calculateSignalMetrics(List<double> signal) {
    if (signal.length < 10) return;

    final recordingDurationSeconds = recordingSeconds > 0
        ? recordingSeconds.toDouble()
        : 20.0;

    final analysis = SignalProcessor.analyze(signal, recordingDurationSeconds);

    processedGreenSignal = analysis.smoothed;
    processedPeakIndices = analysis.peakIndices;
    detectedDicroticNotches = analysis.dicroticNotches.length;
    signalQuality = analysis.qualityScore;

    // إظهار الإشارة المنعّمة في الرسم بعد انتهاء القياس لتوضيح القمم.
    if (!isRecording && processedGreenSignal.isNotEmpty) {
      greenSignal = List<double>.from(processedGreenSignal);
    }

    final metricSignal = processedGreenSignal.isNotEmpty
        ? processedGreenSignal
        : signal;

    final minSignal = metricSignal.reduce((a, b) => a < b ? a : b);
    final maxSignal = metricSignal.reduce((a, b) => a > b ? a : b);
    signalAmplitude = maxSignal - minSignal;

    final mean = metricSignal.reduce((a, b) => a + b) / metricSignal.length;
    final variance =
        metricSignal
            .map((x) => (x - mean) * (x - mean))
            .reduce((a, b) => a + b) /
        metricSignal.length;
    signalStandardDeviation = sqrt(variance);

    final rawMean = signal.reduce((a, b) => a + b) / signal.length;
    coefficientOfVariation = rawMean.abs() > 1e-6
        ? (signalStandardDeviation / rawMean.abs()) * 100
        : 0;

    detectedPulses = processedPeakIndices.length;
    estimatedHeartRate =
        (detectedPulses.toDouble() / recordingDurationSeconds) * 60.0;

    final samplingRate = signal.length / recordingDurationSeconds;
    hrvValue = _calculateHRVFromPeaks(processedPeakIndices, samplingRate);

    print(
      '📊 Signal Metrics:\n'
      '  Amplitude: ${signalAmplitude.toStringAsFixed(2)}\n'
      '  SD: ${signalStandardDeviation.toStringAsFixed(2)}\n'
      '  CV: ${coefficientOfVariation.toStringAsFixed(2)}%\n'
      '  Detected Pulses: $detectedPulses\n'
      '  Est. HR: ${estimatedHeartRate.toStringAsFixed(1)} BPM\n'
      '  HRV: ${hrvValue.toStringAsFixed(2)}\n'
      '  Signal Quality: ${signalQuality.toStringAsFixed(1)}%\n'
      '  Dicrotic Notches: $detectedDicroticNotches',
    );
  }

  /// SDNN based HRV from detected peak-to-peak intervals.
  double _calculateHRVFromPeaks(List<int> peakIndices, double samplingRate) {
    if (peakIndices.length < 3 || samplingRate <= 0) return 0.0;

    final intervalsMs = <double>[];
    for (int i = 1; i < peakIndices.length; i++) {
      final deltaSamples = peakIndices[i] - peakIndices[i - 1];
      if (deltaSamples <= 0) continue;
      final ms = (deltaSamples / samplingRate) * 1000.0;
      // Physiological guard: keep only plausible RR intervals.
      if (ms >= 300.0 && ms <= 2000.0) {
        intervalsMs.add(ms);
      }
    }

    if (intervalsMs.length < 2) return 0.0;

    // Remove extreme outliers using simple trimmed bounds.
    final sorted = List<double>.from(intervalsMs)..sort();
    final q1 = sorted[(sorted.length * 0.25).floor()];
    final q3 = sorted[(sorted.length * 0.75).floor()];
    final iqr = q3 - q1;
    final low = q1 - 1.5 * iqr;
    final high = q3 + 1.5 * iqr;
    final filtered = sorted.where((v) => v >= low && v <= high).toList();

    if (filtered.length < 2) return 0.0;

    final mean = filtered.reduce((a, b) => a + b) / filtered.length;
    final variance =
        filtered.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
        filtered.length;
    return sqrt(variance);
  }

  List<FlSpot> _getSignalSpots(List<double> signal, int visiblePoints) {
    final spots = <FlSpot>[];

    if (signal.isEmpty) return spots;

    // حساب نقطة النهاية مع مراعاة الـ offset

    int endIndex = signal.length - chartOffset;

    if (endIndex < 0) endIndex = 0;

    if (endIndex > signal.length) endIndex = signal.length;

    // حساب نقطة البداية

    int startIndex = endIndex > visiblePoints ? endIndex - visiblePoints : 0;

    for (int i = startIndex; i < endIndex; i++) {
      // استخدام الـ index الفعلي كقيمة X للحفاظ على الدقة

      double xValue = i.toDouble();

      spots.add(FlSpot(xValue, signal[i]));
    }

    return spots;
  }

  // الحد الأقصى للـ offset

  int getMaxOffset(int visiblePoints) {
    if (redSignal.length <= visiblePoints) return 0;

    return redSignal.length - visiblePoints;
  }

  // حساب حدود المحور X

  double getMinX(int visiblePoints) {
    if (redSignal.isEmpty) return 0;

    int endIndex = redSignal.length - chartOffset;

    int startIndex = endIndex > visiblePoints ? endIndex - visiblePoints : 0;

    return startIndex.toDouble();
  }

  double getMaxX(int visiblePoints) {
    if (redSignal.isEmpty) return visiblePoints.toDouble();

    int endIndex = redSignal.length - chartOffset;

    if (endIndex < visiblePoints) return visiblePoints.toDouble();

    return endIndex.toDouble();
  }

  // ====== Auto-Zoom: Dynamic Y-Axis Scaling ======

  /// حساب الحد الأدنى والأعلى للبيانات المرئية باستخدام التحجيم الإحصائي

  /// Statistical Auto-Scaling: Mean ± 2σ لحل مشكلة سحق النطاق الديناميكي

  Map<String, double> getVisibleYRange(int visiblePoints) {
    // 1️⃣ تحديد النطاق المرئي

    int endIndex = redSignal.length - chartOffset;

    if (endIndex < 0) endIndex = 0;

    if (endIndex > redSignal.length) endIndex = redSignal.length;

    int startIndex = endIndex > visiblePoints ? endIndex - visiblePoints : 0;

    // 2️⃣ استخراج البيانات (Prioritize Green -> Red)

    List<double> visibleValues = [];

    // الأولوية للقناة الخضراء (الأوضح للنبض)

    if (showGreenLine && greenSignal.isNotEmpty) {
      for (int i = startIndex; i < endIndex && i < greenSignal.length; i++) {
        visibleValues.add(greenSignal[i]);
      }
    }

    // إذا كانت الخضراء مخفية أو فارغة، استخدم الحمراء

    if (visibleValues.isEmpty && showRedLine && redSignal.isNotEmpty) {
      for (int i = startIndex; i < endIndex && i < redSignal.length; i++) {
        visibleValues.add(redSignal[i]);
      }
    }

    // 3️⃣ حالة الصفر: إذا ما في بيانات، ارجع نطاق افتراضي صغير

    if (visibleValues.isEmpty) {
      return {'minY': -5.0, 'maxY': 5.0};
    }

    // 4️⃣ حساب المتوسط (Mean - μ)

    double mean = visibleValues.reduce((a, b) => a + b) / visibleValues.length;

    // 5️⃣ حساب الانحراف المعياري (Standard Deviation - σ)

    double variance =
        visibleValues
            .map((x) => (x - mean) * (x - mean))
            .reduce((a, b) => a + b) /
        visibleValues.length;

    double sd = sqrt(variance);

    // 6️⃣ حماية النطاق (Anti-Crushing Logic)

    // منع الزوم المبالغ فيه والضجيج القوي

    if (sd < 0.2) {
      sd = 0.2; // منع الشاشة من التسطح
    } else if (sd > 3.0) {
      sd = 3.0; // تجاهل الضجيج القوي
    }

    // 7️⃣ ضبط الحدود: mean ± 2σ

    // هذا يملأ الشاشة بالنبضة بوضوح مع إزالة الضجيج الشديد

    double minY = mean - (2.0 * sd);

    double maxY = mean + (2.0 * sd);

    // تنعيم الزوم لمنع القفز اللحظي في العرض

    if (_smoothedMinY == null || _smoothedMaxY == null) {
      _smoothedMinY = minY;

      _smoothedMaxY = maxY;
    } else {
      _smoothedMinY =
          _smoothedMinY! + (minY - _smoothedMinY!) * ZOOM_SMOOTHING_ALPHA;

      _smoothedMaxY =
          _smoothedMaxY! + (maxY - _smoothedMaxY!) * ZOOM_SMOOTHING_ALPHA;
    }

    return {'minY': _smoothedMinY!, 'maxY': _smoothedMaxY!};
  }

  @override
  void dispose() {
    // ✅ إيقاف جميع التايمرات

    _cancelAllTimers();

    _autoMonitorTimer?.cancel();

    // ✅ إيقاف stream الكاميرا

    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }

    _cameraController?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBrown,

      appBar: AppBar(
        title: const Text(''),

        centerTitle: true,

        backgroundColor: kRed,

        actions: [],
      ),

      body: Container(
        color: kDarkBrown,

        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // 🎯 الزر الرئيسي: فعل القياس / الغي القياس / الغي التسجيل
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (isRecording) {
                        // إيقاف التسجيل
                        stopMeasurement();
                      } else if (isAutoDetectionMode) {
                        // إيقاف البحث التلقائي
                        _toggleAutoDetectionMode();
                      } else {
                        // بدء البحث التلقائي
                        _toggleAutoDetectionMode();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: isRecording
                            ? Colors.red.withAlpha(200)
                            : isAutoDetectionMode
                            ? Colors.orange.withAlpha(200)
                            : kRed,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBeige, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(100),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRecording
                                ? Icons.stop_circle
                                : isAutoDetectionMode
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            color: kBeige,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isRecording
                                ? 'الغي التسجيل'
                                : isAutoDetectionMode
                                ? 'الغي القياس'
                                : 'فعل القياس',
                            style: const TextStyle(
                              color: kBeige,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // حالة البحث التلقائي
              if (isAutoDetectionMode && !isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(100),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'جاري البحث عن وضع صحيح...',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // حالة التسجيل
              if (isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(100),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.record_voice_over,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'جاري التسجيل...',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // عداد الثواني وحالة الاستقرار
              if (isRecording)
                Column(
                  children: [
                    Text(
                      'الوقت المتبقي: ${20 - recordingSeconds} ثانية',

                      style: const TextStyle(
                        fontSize: 16,

                        fontWeight: FontWeight.bold,

                        color: kBeige,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // عرض حالة الاستقرار
                    if (isWarmupComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,

                          vertical: 8,
                        ),

                        decoration: BoxDecoration(
                          color: isSignalStable
                              ? Colors.green.withAlpha(100)
                              : Colors.orange.withAlpha(100),

                          borderRadius: BorderRadius.circular(10),

                          border: Border.all(
                            color: isSignalStable
                                ? Colors.green
                                : Colors.orange,

                            width: 2,
                          ),
                        ),

                        child: Row(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Icon(
                              isSignalStable
                                  ? Icons.check_circle
                                  : Icons.hourglass_top,

                              color: isSignalStable
                                  ? Colors.green
                                  : Colors.orange,

                              size: 20,
                            ),

                            const SizedBox(width: 8),

                            Text(
                              isSignalStable
                                  ? '✓ الإشارة مستقرة'
                                  : '⏳ بحث عن الاستقرار...',

                              style: TextStyle(
                                fontSize: 14,

                                fontWeight: FontWeight.bold,

                                color: isSignalStable
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),

                            const SizedBox(width: 8),

                            Text(
                              '${signalStability.toStringAsFixed(0)}%',

                              style: TextStyle(
                                fontSize: 12,

                                fontWeight: FontWeight.bold,

                                color: isSignalStable
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 20),

              // معاينة الكاميرا
              if (cameraInitialized)
                Container(
                  width: 100,

                  height: 100,

                  decoration: BoxDecoration(
                    border: Border.all(color: kBeige, width: 2),

                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),

                    child: _cameraController != null
                        ? CameraPreview(_cameraController!)
                        : const Center(
                            child: Icon(Icons.camera_alt, color: kBeige),
                          ),
                  ),
                ),

              const SizedBox(height: 20),

              // حالة التسجيل وموضع الإصبع
              Column(
                children: [
                  Text(
                    status,

                    style: const TextStyle(
                      fontSize: 14,

                      fontStyle: FontStyle.italic,

                      color: kBeige,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // عرض حالة موضع الإصبع (بعد انتهاء التسخين)
                  if (isWarmupComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,

                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: isFingerPlacedCorrectly
                            ? Colors.green.withAlpha(100)
                            : Colors.red.withAlpha(100),

                        borderRadius: BorderRadius.circular(8),

                        border: Border.all(
                          color: isFingerPlacedCorrectly
                              ? Colors.green
                              : Colors.red,

                          width: 2,
                        ),
                      ),

                      child: Text(
                        placementStatus,

                        style: TextStyle(
                          fontSize: 12,

                          fontWeight: FontWeight.bold,

                          color: isFingerPlacedCorrectly
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  SizedBox(width: 20),

                  const Text("rgp:   ", style: TextStyle(color: kBeige)),

                  // الأحمر
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showRedLine = !showRedLine;
                      });
                    },

                    child: Container(
                      width: 20,

                      height: 20,

                      decoration: BoxDecoration(
                        color: showRedLine
                            ? const Color.fromARGB(255, 238, 122, 116)
                            : const Color.fromARGB(77, 238, 122, 116),

                        borderRadius: BorderRadius.circular(3),

                        border: Border.all(
                          color: showRedLine ? Colors.red : Colors.grey,

                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Text(
                    'الأحمر',

                    style: TextStyle(fontSize: 12, color: kBeige),
                  ),

                  const SizedBox(width: 20),

                  // الأخضر
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showGreenLine = !showGreenLine;
                      });
                    },

                    child: Container(
                      width: 20,

                      height: 20,

                      decoration: BoxDecoration(
                        color: showGreenLine
                            ? const Color.fromARGB(255, 103, 159, 106)
                            : const Color.fromARGB(77, 103, 159, 106),

                        borderRadius: BorderRadius.circular(3),

                        border: Border.all(
                          color: showGreenLine ? Colors.green : Colors.grey,

                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Text(
                    'الأخضر',

                    style: TextStyle(fontSize: 12, color: kBeige),
                  ),

                  const SizedBox(width: 20),

                  // الأزرق
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showBlueLine = !showBlueLine;
                      });
                    },

                    child: Container(
                      width: 20,

                      height: 20,

                      decoration: BoxDecoration(
                        color: showBlueLine
                            ? const Color.fromARGB(255, 137, 191, 236)
                            : const Color.fromARGB(77, 137, 191, 236),

                        borderRadius: BorderRadius.circular(3),

                        border: Border.all(
                          color: showBlueLine ? Colors.blue : Colors.grey,

                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Text(
                    'الأزرق',

                    style: TextStyle(fontSize: 12, color: kBeige),
                  ),
                ],
              ),

              // الرسم البياني للإشارة (جميع الألوان في جدول واحد)

              // عرض الرسم البياني فقط بعد انتهاء فترة التسخين واستقرار الإشارة
              if (isWarmupComplete &&
                  greenSignal.length > MOVING_AVERAGE_WINDOW)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,

                        horizontal: 10,
                      ),

                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // حساب عدد النقاط المرئية بناءً على عرض الشاشة

                          final chartWidth = constraints.maxWidth;

                          final visiblePoints = (chartWidth / pixelsPerPoint)
                              .floor();

                          final maxOff = getMaxOffset(visiblePoints);

                          // Auto-Zoom: حساب النطاق الديناميكي للمحور Y

                          final yRange = getVisibleYRange(visiblePoints);

                          final dynamicMinY = yRange['minY']!;

                          final dynamicMaxY = yRange['maxY']!;

                          return GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                // السحب لليمين = رجوع للخلف (زيادة offset)

                                // السحب لليسار = للأمام (تقليل offset)

                                if (details.delta.dx > 0) {
                                  // سحب لليمين - عرض البيانات الأقدم

                                  chartOffset = (chartOffset + 2).clamp(
                                    0,

                                    maxOff,
                                  );
                                } else if (details.delta.dx < 0) {
                                  // سحب لليسار - عرض البيانات الأحدث

                                  chartOffset = (chartOffset - 2).clamp(
                                    0,

                                    maxOff,
                                  );
                                }
                              });
                            },

                            onDoubleTap: () {
                              // نقرتين للعودة للبيانات الحالية

                              setState(() {
                                chartOffset = 0;
                              });
                            },

                            child: Container(
                              height: 250,

                              width: double.infinity,

                              decoration: BoxDecoration(
                                color: kDarkBrown,

                                border: Border(
                                  top: BorderSide(color: kBeige, width: 3),

                                  bottom: BorderSide(color: kBeige, width: 3),
                                ),
                              ),

                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),

                                    child: LineChart(
                                      LineChartData(
                                        minY: dynamicMinY,

                                        maxY: dynamicMaxY,

                                        minX: getMinX(visiblePoints),

                                        maxX: getMaxX(visiblePoints),

                                        clipData:
                                            FlClipData.all(), // قص البيانات خارج الحدود

                                        gridData: FlGridData(show: true),

                                        titlesData: FlTitlesData(
                                          show: true,

                                          topTitles: const AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),

                                          rightTitles: const AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),

                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                            ),
                                          ),

                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,

                                              reservedSize: 40,

                                              interval: 50,
                                            ),
                                          ),
                                        ),

                                        borderData: FlBorderData(show: false),

                                        lineBarsData: [
                                          // خط أحمر
                                          if (showRedLine)
                                            LineChartBarData(
                                              spots: _getSignalSpots(
                                                redSignal,

                                                visiblePoints,
                                              ),

                                              isCurved:
                                                  false, // خط مستقيم للدقة

                                              color: const Color.fromARGB(
                                                255,

                                                235,

                                                101,

                                                91,
                                              ),

                                              barWidth: 1.5,

                                              dotData: FlDotData(show: false),
                                            ),

                                          // خط أخضر
                                          if (showGreenLine)
                                            LineChartBarData(
                                              spots: _getSignalSpots(
                                                greenSignal,

                                                visiblePoints,
                                              ),

                                              isCurved: false,

                                              color: const Color.fromARGB(
                                                255,

                                                83,

                                                150,

                                                86,
                                              ),

                                              barWidth: 1.5,

                                              dotData: FlDotData(show: false),
                                            ),

                                          // خط أزرق
                                          if (showBlueLine)
                                            LineChartBarData(
                                              spots: _getSignalSpots(
                                                blueSignal,

                                                visiblePoints,
                                              ),

                                              isCurved: false,

                                              color: Color.fromARGB(
                                                255,

                                                107,

                                                177,

                                                235,
                                              ),

                                              barWidth: 1.5,

                                              dotData: FlDotData(show: false),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // مؤشر الموقع الحالي
                                  if (chartOffset > 0)
                                    Positioned(
                                      top: 5,

                                      right: 10,

                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,

                                          vertical: 4,
                                        ),

                                        decoration: BoxDecoration(
                                          color: kDarkBrown,

                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),

                                        child: Text(
                                          'قبل $chartOffset إطار',

                                          style: const TextStyle(
                                            color: kBeige,

                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 15),
                  ],
                )
              else if (isRecording && !isWarmupComplete)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),

                  padding: const EdgeInsets.all(15),

                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(80),

                    borderRadius: BorderRadius.circular(10),

                    border: Border.all(color: Colors.orange, width: 2),
                  ),

                  child: Column(
                    children: [
                      const Text(
                        'جاري فترة التسخين...',

                        style: TextStyle(
                          fontSize: 14,

                          fontWeight: FontWeight.bold,

                          color: Colors.orange,
                        ),
                      ),

                      const SizedBox(height: 8),

                      LinearProgressIndicator(
                        value: warmupCounter / WARMUP_SECONDS,

                        minHeight: 8,

                        backgroundColor: Colors.orange.withAlpha(100),

                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'الانتظار: ${WARMUP_SECONDS - warmupCounter} ثانية',

                        style: const TextStyle(
                          fontSize: 12,

                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

              if (averageRed > 0)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20),

                  elevation: 5,

                  color: kDarkBrown,

                  child: Padding(
                    padding: const EdgeInsets.all(20),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,

                      children: [
                        const Text(
                          'نتائج القياس',

                          style: TextStyle(
                            fontSize: 18,

                            fontWeight: FontWeight.bold,

                            color: kBeige,
                          ),
                        ),

                        const SizedBox(height: 15),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                          children: [
                            _buildRGBContainer('الأحمر', averageRed),

                            _buildRGBContainer('الأخضر', averageGreen),

                            _buildRGBContainer('الأزرق', averageBlue),
                          ],
                        ),

                        const SizedBox(height: 30),

                        const Divider(color: kBeige),

                        const SizedBox(height: 20),

                        const Text(
                          'نتائج معالجة الإشارة',

                          style: TextStyle(
                            fontSize: 18,

                            fontWeight: FontWeight.bold,

                            color: kBeige,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // شبكة لعرض النتائج بشكل منظم
                        GridView.count(
                          crossAxisCount: 2,

                          shrinkWrap: true,

                          physics: const NeverScrollableScrollPhysics(),

                          mainAxisSpacing: 15,

                          crossAxisSpacing: 15,

                          childAspectRatio: 1.2,

                          children: [
                            _buildMetricCard(
                              'عدد النبضات',
                              detectedPulses.toString(),
                              'نبضة',
                              Icons.favorite,
                            ),

                            _buildMetricCard(
                              'معدل النبض',
                              estimatedHeartRate.toStringAsFixed(1),
                              'BPM',
                              Icons.monitor_heart,
                            ),

                            _buildMetricCard(
                              'السعة',
                              signalAmplitude.toStringAsFixed(2),
                              '',
                              Icons.show_chart,
                            ),

                            _buildMetricCard(
                              'الانحراف المعياري',
                              signalStandardDeviation.toStringAsFixed(2),
                              '',
                              Icons.stacked_line_chart,
                            ),

                            _buildMetricCard(
                              'معامل الاختلاف',
                              coefficientOfVariation.toStringAsFixed(2),
                              '%',
                              Icons.assessment,
                            ),

                            _buildMetricCard(
                              'HRV',
                              hrvValue.toStringAsFixed(2),
                              '',
                              Icons.trending_up,
                            ),

                            _buildMetricCard(
                              'جودة الإشارة',
                              signalQuality.toStringAsFixed(1),
                              '%',
                              Icons.auto_graph,
                            ),

                            _buildMetricCard(
                              'الشق الديكروتي',
                              detectedDicroticNotches.toString(),
                              '',
                              Icons.timeline,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRGBContainer(String label, double value) {
    return Container(
      width: 80,

      height: 80,

      decoration: BoxDecoration(
        color: kBeige.withAlpha((value / 255 * 150).toInt()),

        border: Border.all(color: kBeige, width: 2),

        borderRadius: BorderRadius.circular(10),
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Text(
            label,

            style: const TextStyle(
              fontWeight: FontWeight.bold,

              color: kDarkBrown,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            value.toStringAsFixed(1),

            style: const TextStyle(
              fontWeight: FontWeight.bold,

              fontSize: 14,

              color: kDarkBrown,
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة لعرض معيار واحد من معايير الإشارة

  Widget _buildMetricCard(
    String label,
    String value,
    String unit,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: kDarkBrown,

        border: Border.all(color: kBeige, width: 2),

        borderRadius: BorderRadius.circular(12),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      padding: const EdgeInsets.all(12),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          Icon(icon, color: kBeige, size: 24),

          const SizedBox(height: 8),

          Text(
            label,

            textAlign: TextAlign.center,

            style: const TextStyle(
              fontSize: 12,

              color: kBeige,

              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,

                  style: const TextStyle(
                    fontSize: 16,

                    fontWeight: FontWeight.bold,

                    color: kRed,
                  ),
                ),

                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',

                    style: const TextStyle(
                      fontSize: 10,

                      color: kBeige,

                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
