import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

// Dark Mode Colors
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

  // PPG Signal tracking
  List<double> redSignal = [];
  List<double> greenSignal = [];
  List<double> blueSignal = [];
  double averageRed = 0.0;
  double averageGreen = 0.0;
  double averageBlue = 0.0;

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
        }
      }
    } catch (e) {
      print('خطأ في تهيئة الكاميرا: $e');
    }
  }

  Future<void> startMeasurement() async {
    if (!cameraInitialized || _cameraController == null) {
      setState(() {
        status = "الكاميرا لم تتم تهيئتها";
      });
      return;
    }

    // إيقاف الـ stream السابق إذا كان شغال
    if (_cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // تفعيل الفلاش عند بدء القياس
    // try {
    //   await _cameraController!.setFlashMode(FlashMode.torch);
    // } catch (e) {
    //   print('خطأ في تفعيل الفلاش: $e');
    // }

    setState(() {
      isRecording = true;
      status = "جاري التسجيل...";
      recordingSeconds = 0;
      redSignal.clear();
      greenSignal.clear();
      blueSignal.clear();
      chartOffset = 0; // إعادة ضبط الـ offset
    });

    // بدء التقاط الإطارات
    _captureFrames();

    // إيقاف التسجيل بعد 20 ثانية
    Timer(const Duration(seconds: 20), () {
      stopMeasurement();
    });

    // تحديث العداد
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isRecording) {
        timer.cancel();
      } else {
        setState(() {
          recordingSeconds++;
        });
      }
    });
  }

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

          if (mounted) {
            setState(() {
              redSignal.add(avgRed);
              greenSignal.add(avgGreen);
              blueSignal.add(avgBlue);
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

  /// حساب الحد الأدنى والأعلى للبيانات المرئية مع padding
  Map<String, double> getVisibleYRange(int visiblePoints) {
    // جمع كل البيانات المرئية من الإشارات المفعلة
    List<double> visibleValues = [];

    // حساب نطاق البيانات المرئية
    int endIndex = redSignal.length - chartOffset;
    if (endIndex < 0) endIndex = 0;
    if (endIndex > redSignal.length) endIndex = redSignal.length;
    int startIndex = endIndex > visiblePoints ? endIndex - visiblePoints : 0;

    // جمع القيم من الإشارات المفعلة فقط
    if (showRedLine && redSignal.isNotEmpty) {
      for (int i = startIndex; i < endIndex && i < redSignal.length; i++) {
        visibleValues.add(redSignal[i]);
      }
    }
    if (showGreenLine && greenSignal.isNotEmpty) {
      for (int i = startIndex; i < endIndex && i < greenSignal.length; i++) {
        visibleValues.add(greenSignal[i]);
      }
    }
    if (showBlueLine && blueSignal.isNotEmpty) {
      for (int i = startIndex; i < endIndex && i < blueSignal.length; i++) {
        visibleValues.add(blueSignal[i]);
      }
    }

    // إذا ما في بيانات، ارجع قيم افتراضية
    if (visibleValues.isEmpty) {
      return {'minY': 0, 'maxY': 255};
    }

    // حساب الحد الأدنى والأعلى
    double minVal = visibleValues.reduce((a, b) => a < b ? a : b);
    double maxVal = visibleValues.reduce((a, b) => a > b ? a : b);

    // الفرق بين أعلى وأدنى قيمة (AC component)
    double range = maxVal - minVal;

    // إذا كانت الإشارة مسطحة جداً (فرق أقل من 0.5)، أضف نطاق صغير حول المركز
    if (range < 0.5) {
      double center = (minVal + maxVal) / 2;
      return {
        'minY': (center - 2).clamp(0.0, 255.0),
        'maxY': (center + 2).clamp(0.0, 255.0),
      };
    }

    // إضافة padding 20% للأعلى والأسفل لرؤية التغيرات الصغيرة بوضوح
    double padding = range * 0.2;

    // التأكد من عدم تجاوز الحدود المنطقية (0-255)
    double finalMinY = (minVal - padding).clamp(0.0, 255.0);
    double finalMaxY = (maxVal + padding).clamp(0.0, 255.0);

    return {'minY': finalMinY, 'maxY': finalMaxY};
  }

  @override
  void dispose() {
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

              // زر فعل القياس
              ElevatedButton.icon(
                onPressed: isRecording ? null : startMeasurement,
                icon: const Icon(Icons.favorite),
                label: const Text('فعل القياس'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  backgroundColor: isRecording ? Colors.grey : kRed,
                  disabledBackgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              // عداد الثواني
              if (isRecording)
                Text(
                  'الوقت المتبقي: ${20 - recordingSeconds} ثانية',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kBeige,
                  ),
                ),

              const SizedBox(height: 20),

              // معاينة الكاميرا
              if (cameraInitialized && _cameraController != null)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: kBeige, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CameraPreview(_cameraController!),
                  ),
                ),

              const SizedBox(height: 20),

              // حالة التسجيل
              Text(
                status,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: kBeige,
                ),
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
              if (redSignal.isNotEmpty)
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
                                  // عرض معلومات الإطارات
                                  // Positioned(
                                  //   top: 5,
                                  //   left: 10,
                                  //   child: Container(
                                  //     padding: const EdgeInsets.symmetric(
                                  //       horizontal: 8,
                                  //       vertical: 4,
                                  //     ),
                                  //     decoration: BoxDecoration(
                                  //       color: kDarkBrown,
                                  //       borderRadius: BorderRadius.circular(10),
                                  //     ),
                                  //     child: Text(
                                  //       '${redSignal.length} نقطة',
                                  //       style: const TextStyle(
                                  //         color: kBeige,
                                  //         fontSize: 10,
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 15),
                  ],
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
}
