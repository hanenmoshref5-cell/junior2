import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:testttt/common/widgets/custom_snack_bar.dart';
import 'package:testttt/feature/measure/business/controller/measurefinger_controller.dart';
import 'package:testttt/feature/auth/data/services/auth_service.dart';
import 'package:testttt/common/constants/app_colors.dart';

const Color kDarkBrown = AppColors.darkBrown;
const Color kBeige = AppColors.beige;
const Color kRed = AppColors.red;

class Measurefinger extends StatefulWidget {
  const Measurefinger({super.key});

  @override
  State<Measurefinger> createState() => _MeasurefingerState();
}

class _MeasurefingerState extends State<Measurefinger> {
  static const MethodChannel _methodChannel = MethodChannel('ppg/method');
  static const EventChannel _eventChannel = EventChannel('ppg/events');

  final AuthService _authService = AuthService();

  final PPGController _ppgController = PPGController();

  StreamSubscription<dynamic>? _eventSubscription;

  bool isRecording = false;
  bool isStarting = false;

  Timer? _recordingTimer;
  Timer? _stabilityTimer;
  Timer? _stopTimer;
  Timer? _uiRefreshTimer;

  bool _isAbortingMeasurement = false;
  bool _measurementFinishedNormally = false;
  bool _isSendingResult = false;
  bool _sendAttempted = false;

  Map<String, dynamic>? _serverResult;

  // PPG Signal tracking
  final List<double> ppgSignal = [];
  final List<double> redSignal = [];
  final List<double> greenSignal = [];
  final List<double> blueSignal = [];

  int? _textureId;
  double _cameraAspectRatio = 3.0 / 4.0; // Default or fetched from native

  final List<double> _pendingPpg = [];
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
  double currentPpgValue = 0.0;

  // متغيرات عائشة
  String sessionName = '';
  int sessionNumber = 0;
  double sugarPercentage = 0.0;
  double heightCm = 0.0;
  double weightKg = 0.0;
  int age = 0;
  double bmi = 0.0;

  // UI State
  String status = "اضغط على فعل القياس";
  String? errorMessage;
  int recordingSeconds = 0;
  String saveStatusMessage = '';

  // Chart scroll/navigation
  int chartOffset = 0;
  double pixelsPerPoint = 3.0;

  // Finger placement detection (kept in Flutter as requested)
  static const double BRIGHTNESS_MIN = 15.0;
  static const double BRIGHTNESS_MAX = 180.0;
  static const double SOFT_MOTION_THRESHOLD = 14.0;
  static const double HARD_MOTION_THRESHOLD = 32.0;
  static const int BRIGHTNESS_WINDOW = 12;

  double lastBrightness = 0.0;
  double currentBrightness = 0.0;
  int validPlacementCount = 0;
  int invalidPlacementCount = 0;
  bool isFingerPlacedCorrectly = false;
  String placementStatus = "ضع إصبعك على الكاميرا";
  final List<double> recentBrightness = [];

  // Warmup
  static const int WARMUP_SECONDS = 10;
  int warmupCounter = 0;
  bool isWarmupComplete = false;

  // Signal stability
  static const int MOVING_AVERAGE_WINDOW = 10;
  static const double STABILITY_THRESHOLD = 2.0;
  static const double STABILITY_LOSS_THRESHOLD = 4.0;

  double signalStability = 0.0;
  double previousStability = -1.0;
  bool isSignalStable = false;
  bool wasStableLastCheck = false;
  int consecutiveUnstableCount = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToNativeEvents();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          sessionName = user.fullName;
          weightKg = user.weight;
          heightCm = user.height;
          age = user.age;
          sugarPercentage = 0.0; // server will predict
          if (heightCm > 0 && weightKg > 0) {
            final h = heightCm / 100.0;
            bmi = weightKg / (h * h);
          } else {
            bmi = 0.0;
          }
        });
      }
    } catch (_) {
      // ignore - keep defaults
    }
  }

  void _subscribeToNativeEvents() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _handleNativeEvent(event);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          errorMessage = error.toString();
          status = "حدث خطأ في البث";
        });
      },
    );
  }

  Future<void> startMeasurement() async {
    if (isRecording || isStarting) return;

    _cancelAllTimers();

    setState(() {
      isStarting = true;
      errorMessage = null;
      status = "جاري تجهيز المعالجة...";
      recordingSeconds = 0;
      ppgSignal.clear();
      redSignal.clear();
      greenSignal.clear();
      blueSignal.clear();
      _pendingPpg.clear();
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
      lastBrightness = 0.0;
      currentBrightness = 0.0;
      recentBrightness.clear();
      validPlacementCount = 0;
      invalidPlacementCount = 0;
      isFingerPlacedCorrectly = false;
      placementStatus = "ضع إصبعك على الكاميرا";
      _measurementFinishedNormally = false;
      _serverResult = null;
      _isSendingResult = false;
      _sendAttempted = false;
    });

    try {
      // 1. Create Texture
      final textureResult = await _methodChannel.invokeMethod('createTexture');
      if (textureResult != null) {
        setState(() {
          _textureId = textureResult['textureId'] as int;
          final width = textureResult['width'] as num;
          final height = textureResult['height'] as num;
          _cameraAspectRatio = width > 0 && height > 0
              ? width / height
              : 3.0 / 4.0;
          if (_cameraAspectRatio < 1.0) {
            _cameraAspectRatio =
                1.0 / _cameraAspectRatio; // Ensure portrait aspect
          }
        });
      }

      // 2. Start Camera with Texture
      if (_textureId != null) {
        await _methodChannel.invokeMethod('startCamera', {
          'textureId': _textureId,
        });
      }

      // 3. Keep starting the main measurement process
      await _methodChannel.invokeMethod('startMeasurement');
      if (!mounted) return;
      setState(() {
        isRecording = true;
        isStarting = false;
        status = "جاري التسخين... رجاءً انتظر...";
        // sessionNumber derived from current time: hour concatenated with minute (e.g. 1:30 -> 130)
        final now = DateTime.now();
        sessionNumber = now.hour * 100 + now.minute;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isStarting = false;
        isRecording = false;
        errorMessage = e.toString();
        status = "فشل بدء المعالجة";
      });
      return;
    }

    _startUiRefreshTimer();

    _stopTimer = Timer(const Duration(seconds: 40), () {
      stopMeasurement();
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isRecording) {
        timer.cancel();
      } else {
        setState(() {
          recordingSeconds++;
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

  Future<void> stopMeasurement() async {
    _cancelAllTimers();
    _flushPendingSignalToUi(forceRebuild: false);

    await _stopCameraAndMeasurement();

    final bool canSendMetadata =
        !_isAbortingMeasurement &&
        isWarmupComplete &&
        isFingerPlacedCorrectly &&
        ppgSignal.isNotEmpty;

    if (!mounted) return;
    setState(() {
      _textureId = null;
      isRecording = false;
      isStarting = false;

      if (ppgSignal.isNotEmpty) {
        averageRed = redSignal.reduce((a, b) => a + b) / redSignal.length;
        averageGreen = greenSignal.reduce((a, b) => a + b) / greenSignal.length;
        averageBlue = blueSignal.reduce((a, b) => a + b) / blueSignal.length;
        status = "تم اكتمال القياس";
      } else {
        status = "لم يتم التقاط أي بيانات";
      }
    });

    if (!canSendMetadata) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _measurementFinishedNormally = true;
    });
  }

  Future<void> _sendMeasurementResults() async {
    if (_isSendingResult || ppgSignal.isEmpty) return;
    // Use BMI loaded from user profile (set in _loadUserProfile()).
    final double bmiValue = bmi;

    final String patientId = sessionName.isNotEmpty ? sessionName : 'unknown';
    final String sessionId = sessionNumber.toString();

    setState(() {
      _isSendingResult = true;
      errorMessage = null;
      _sendAttempted = true;
    });

    try {
      final result = await _ppgController.sendToServerWithMetadata(
        signalList: List<double>.from(ppgSignal),
        patientId: patientId,
        sessionId: sessionId,
        glucoseLevel: sugarPercentage,
        age: age,
        BMI: bmiValue,
      );

      if (!mounted) return;
      setState(() {
        _serverResult = result;
      });

      if (result != null) {
        CustomSnackBar.success(context, 'تم توليد الداتا ست من Flask بنجاح');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'فشل إرسال النتائج: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingResult = false;
        });
      }
    }
  }

  void _handleNativeEvent(Map<dynamic, dynamic> event) {
    if (event['error'] != null) {
      if (!mounted) return;
      setState(() {
        errorMessage = event['error'].toString();
        status = "حدث خطأ من المعالجة";
      });
      return;
    }

    if (!isRecording) return;

    final double avgRed = (event['avgRed'] as num?)?.toDouble() ?? 0.0;
    final double avgGreen = (event['avgGreen'] as num?)?.toDouble() ?? 0.0;
    final double avgBlue = (event['avgBlue'] as num?)?.toDouble() ?? 0.0;
    final double ppgValue = (event['ppgValue'] as num?)?.toDouble() ?? 0.0;

    currentPpgValue = ppgValue;

    final bool fingerPlaced = _analyzeFingerPlacement(
      avgRed,
      avgGreen,
      avgBlue,
    );

    if (isWarmupComplete && fingerPlaced) {
      _pendingPpg.add(ppgValue);
      _pendingRed.add(avgRed);
      _pendingGreen.add(avgGreen);
      _pendingBlue.add(avgBlue);
    } else if (isWarmupComplete && !fingerPlaced && mounted) {
      setState(() {
        status = placementStatus;
      });
    }
  }

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
    if (_pendingPpg.isEmpty &&
        _pendingRed.isEmpty &&
        _pendingGreen.isEmpty &&
        _pendingBlue.isEmpty) {
      return;
    }

    ppgSignal.addAll(_pendingPpg);
    redSignal.addAll(_pendingRed);
    greenSignal.addAll(_pendingGreen);
    blueSignal.addAll(_pendingBlue);

    _pendingPpg.clear();
    _pendingRed.clear();
    _pendingGreen.clear();
    _pendingBlue.clear();

    if (forceRebuild && mounted) {
      setState(() {});
    }
  }

  double _calculateStandardDeviation(List<double> signal) {
    if (signal.length < 2) return 0.0;

    int windowSize = min(MOVING_AVERAGE_WINDOW, signal.length);
    double mean = 0.0;

    for (int i = signal.length - windowSize; i < signal.length; i++) {
      mean += signal[i];
    }

    mean /= windowSize;
    double variance = 0.0;

    for (int i = signal.length - windowSize; i < signal.length; i++) {
      double diff = signal[i] - mean;
      variance += diff * diff;
    }

    variance /= windowSize;
    return sqrt(variance);
  }

  void _updateSignalStability() {
    if (ppgSignal.length < MOVING_AVERAGE_WINDOW * 2) {
      isSignalStable = false;
      signalStability = 0.0;
      return;
    }

    double stdDev = _calculateStandardDeviation(ppgSignal);
    double maxStdDev = 20.0;

    signalStability = ((1.0 - (stdDev / maxStdDev).clamp(0.0, 1.0)) * 100)
        .clamp(0.0, 100.0);

    if (previousStability < 0) {
      previousStability = signalStability;
      isSignalStable = signalStability > 35.0;
      return;
    }

    double stabilityDrop = previousStability - signalStability;

    if (recordingSeconds > WARMUP_SECONDS &&
        signalStability < 30.0 &&
        stabilityDrop > (STABILITY_LOSS_THRESHOLD * 8.5)) {
      _abortMeasurementImmediate(
        "⚠️ تم اكتشاف حركة/اهتزاز في الإصبع. أعد القياس.",
      );
      return;
    } else {
      if (signalStability > 52.0) {
        consecutiveUnstableCount = 0;
      }
    }

    isSignalStable = signalStability > STABILITY_THRESHOLD * 20;
    previousStability = signalStability;
    wasStableLastCheck = isSignalStable;
  }

  bool _analyzeFingerPlacement(double avgRed, double avgGreen, double avgBlue) {
    currentBrightness = (avgRed + avgGreen + avgBlue) / 3.0;

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

    bool isCovered =
        currentBrightness >= BRIGHTNESS_MIN &&
        currentBrightness <= BRIGHTNESS_MAX;

    // Stricter check: red should be dominant over green and blue
    // and also exceed a small absolute threshold to avoid ambient noise.
    bool hasFingerColorProfile =
        avgRed > (avgGreen * 1.05) &&
        avgRed > (avgBlue * 1.05) &&
        avgRed > 30.0;

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

    bool isValid = isCovered && hasFingerColorProfile && !isMotionDetected;

    if (isValid) {
      validPlacementCount++;
      invalidPlacementCount = 0;

      if (validPlacementCount >= 4) {
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

      // Avoid aborting immediately on a single transient invalid reading.
      // Only abort after repeated invalids and after warmup completes.
      if (isRecording && isWarmupComplete && invalidPlacementCount >= 3) {
        _abortMeasurementImmediate(placementStatus);
        return false;
      }
    }

    lastBrightness = currentBrightness;
    return isValid;
  }

  void _abortMeasurementImmediate(String reason) {
    if (_isAbortingMeasurement || !isRecording) return;

    _isAbortingMeasurement = true;
    _measurementFinishedNormally = false;
    _cancelAllTimers();

    _stopCameraAndMeasurement();

    if (mounted) {
      setState(() {
        isRecording = false;
        ppgSignal.clear();
        redSignal.clear();
        greenSignal.clear();
        blueSignal.clear();
        _pendingPpg.clear();
        _pendingRed.clear();
        _pendingGreen.clear();
        _pendingBlue.clear();
        _smoothedMinY = null;
        _smoothedMaxY = null;
        chartOffset = 0;
        isWarmupComplete = false;
        isSignalStable = false;
        signalStability = 0.0;
        placementStatus = reason;
        status = reason;
      });
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      _isAbortingMeasurement = false;
    });
  }

  Future<void> _stopCameraAndMeasurement() async {
    try {
      await _methodChannel.invokeMethod('stopMeasurement');
      await _methodChannel.invokeMethod('stopCamera');
    } catch (_) {
      // Keep UI responsive even if native stop fails.
    }

    if (mounted) {
      setState(() {
        _textureId = null;
      });
    } else {
      _textureId = null;
    }
  }

  List<FlSpot> _getSignalSpots(List<double> signal, int visiblePoints) {
    final spots = <FlSpot>[];
    if (signal.isEmpty) return spots;

    int endIndex = signal.length - chartOffset;
    if (endIndex < 0) endIndex = 0;
    if (endIndex > signal.length) endIndex = signal.length;

    int startIndex = endIndex > visiblePoints ? endIndex - visiblePoints : 0;

    for (int i = startIndex; i < endIndex; i++) {
      double xValue = i.toDouble();
      spots.add(FlSpot(xValue, signal[i]));
    }

    return spots;
  }

  int getMaxOffset(int visiblePoints) {
    if (ppgSignal.length <= visiblePoints) return 0;
    return ppgSignal.length - visiblePoints;
  }

  double getMinX(int visiblePoints) {
    if (ppgSignal.isEmpty) return 0;

    int endIndex = ppgSignal.length - chartOffset;
    int startIndex = endIndex > visiblePoints ? endIndex - visiblePoints : 0;

    return startIndex.toDouble();
  }

  double getMaxX(int visiblePoints) {
    if (ppgSignal.isEmpty) return visiblePoints.toDouble();

    int endIndex = ppgSignal.length - chartOffset;
    if (endIndex < visiblePoints) return visiblePoints.toDouble();

    return endIndex.toDouble();
  }

  //Autozooming
  Map<String, double> getVisibleYRange(int visiblePoints) {
    int endIndex = ppgSignal.length - chartOffset;
    if (endIndex < 0) endIndex = 0;
    if (endIndex > ppgSignal.length) endIndex = ppgSignal.length;

    int startIndex = endIndex > visiblePoints ? endIndex - visiblePoints : 0;

    List<double> visibleValues = [];

    for (int i = startIndex; i < endIndex && i < ppgSignal.length; i++) {
      visibleValues.add(ppgSignal[i]);
    }

    if (visibleValues.isEmpty) {
      return {'minY': -5.0, 'maxY': 5.0};
    }

    double mean = visibleValues.reduce((a, b) => a + b) / visibleValues.length;
    double variance =
        visibleValues
            .map((x) => (x - mean) * (x - mean))
            .reduce((a, b) => a + b) /
        visibleValues.length;

    double sd = sqrt(variance);

    if (sd < 0.2) {
      sd = 0.2;
    } else if (sd > 3.0) {
      sd = 3.0;
    }

    double minY = mean - (2.0 * sd);
    double maxY = mean + (2.0 * sd);

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

  // session form removed - values are populated from AuthService/profile

  String _formatServerGlucose() {
    final value = _serverResult?['glucose'];
    if (value == null) {
      return 'null';
    }
    if (value is num) {
      return value.toDouble().toStringAsFixed(2);
    }
    return value.toString();
  }

  String _formatServerPulses() {
    final value = _serverResult?['pulses'];
    if (value is num) {
      return value.toInt().toString();
    }
    return '--';
  }

  @override
  void dispose() {
    _cancelAllTimers();
    _eventSubscription?.cancel();
    _methodChannel.invokeMethod('stopMeasurement');
    super.dispose();
  }

  //---------------------------------------------------------
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

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (isRecording || isStarting) {
                        stopMeasurement();
                      } else {
                        startMeasurement();
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
                            : isStarting
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
                                : isStarting
                                ? Icons.hourglass_top
                                : Icons.play_circle,
                            color: kBeige,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isRecording
                                ? 'الغي التسجيل'
                                : isStarting
                                ? 'جارِ التشغيل'
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
              if (errorMessage != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(80),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
              if (isRecording)
                Column(
                  children: [
                    Text(
                      'الوقت المتبقي: ${40 - recordingSeconds} ثانية',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBeige,
                      ),
                    ),
                    const SizedBox(height: 10),
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
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black, // Black background before pressing start
                  border: Border.all(color: kBeige, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: _textureId != null
                        ? AspectRatio(
                            aspectRatio:
                                3.0 /
                                4.0, // standard portrait ratio or use _cameraAspectRatio
                            child: Texture(textureId: _textureId!),
                          )
                        : const SizedBox.shrink(), // Empty black box when idle
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // if (_textureId == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, color: kBeige, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isRecording ? 'Native Camera Active' : 'Camera Idle',
                    style: TextStyle(
                      color: kBeige,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
              if (isWarmupComplete && ppgSignal.length > MOVING_AVERAGE_WINDOW)
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
                          final chartWidth = constraints.maxWidth;
                          final visiblePoints = (chartWidth / pixelsPerPoint)
                              .floor();
                          final maxOff = getMaxOffset(visiblePoints);
                          final yRange = getVisibleYRange(visiblePoints);
                          final dynamicMinY = yRange['minY']!;
                          final dynamicMaxY = yRange['maxY']!;

                          return GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                if (details.delta.dx > 0) {
                                  chartOffset = (chartOffset + 2).clamp(
                                    0,
                                    maxOff,
                                  );
                                } else if (details.delta.dx < 0) {
                                  chartOffset = (chartOffset - 2).clamp(
                                    0,
                                    maxOff,
                                  );
                                }
                              });
                            },
                            onDoubleTap: () {
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
                                        clipData: FlClipData.all(),
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
                                          LineChartBarData(
                                            spots: _getSignalSpots(
                                              ppgSignal,
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
                                        ],
                                      ),
                                    ),
                                  ),
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

              const SizedBox.shrink(),
              if (averageRed > 0)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  elevation: 5,
                  color: kDarkBrown,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 40,
                      left: 40,
                      right: 40,
                      bottom: 60,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '(نسبة سكرك الحالية )نتائج القياس',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kBeige,
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (_measurementFinishedNormally &&
                            _serverResult == null)
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSendingResult
                                      ? null
                                      : _sendMeasurementResults,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kRed,
                                    foregroundColor: kBeige,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isSendingResult
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: kBeige,
                                          ),
                                        )
                                      : const Text(
                                          'إرسال النتائج للسيرفر',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        if (_serverResult != null) ...[
                          Text(
                            'Glucose: ${_formatServerGlucose()}',
                            style: const TextStyle(
                              color: kBeige,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pulses: ${_formatServerPulses()}',
                            style: const TextStyle(color: kBeige, fontSize: 14),
                          ),
                        ] else if (_measurementFinishedNormally &&
                            !_sendAttempted)
                          const Text(
                            ' تم حفظ الاشارة بنجاح ولم تُرجع النتيجة بعد اضغط الزر لارسال الاشارة والحصول على النتيجة ',
                            style: TextStyle(color: kBeige, fontSize: 14),
                          )
                        else if (_sendAttempted && !_isSendingResult)
                          const Text(
                            'السيرفر فشل في معالجة البيانات أو لم يستجب، حاول مرة أخرى لاحقاً',
                            style: TextStyle(color: kBeige, fontSize: 14),
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
}
