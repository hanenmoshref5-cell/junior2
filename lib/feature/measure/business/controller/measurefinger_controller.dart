import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:testttt/feature/measure/data/services/measurefinger_service.dart';

class PPGController {
  final List<double> red = [];

  void _logYellow(String message) {
    debugPrint('\x1B[33m$message\x1B[0m');
  }

  void _logError(String message) {
    debugPrint('\x1B[31m$message\x1B[0m');
  }

  // // إضافة قيمة جديدة للمصفوفة
  void addData(double redValue) {
    red.add(redValue);
  }

  // إرسال الإشارة فقط
  Future<Map<String, dynamic>?> sendToServer() async {
    if (red.isEmpty) {
      _logYellow('⚠️ المصفوفة فارغة، لن يتم الإرسال');
      return null;
    }

    _logYellow('🚀 SENDING RED ONLY...');
    _logYellow('Signal size: ${red.length}');

    // نأخذ نسخة من البيانات قبل المسح لضمان عدم حدوث مشاكل تزامن
    List<double> dataToSend = List.from(red);
    red.clear(); // نمسح المصفوفة الأصلية فوراً لبدء قياس جديد

    // استدعاء النسخة الخامّة من الطلب حتى نتمكّن من فحص statusCode و body
    final response = await ApiService.sendSignalRaw(signalList: dataToSend);

    if (response == null) {
      _logError('❌ لا توجد استجابة من السيرفر (null response)');
      return null;
    }

    _logYellow('HTTP status: ${response.statusCode}');
    _logYellow('Raw body: ${response.body}');

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);

        final num? glucoseValue = data['glucose'] as num?;
        final num? pulsesValue = data['pulses'] as num?;
        final List pulses = data['glucose_per_pulse'] is List
            ? List.from(data['glucose_per_pulse'] as List)
            : [];

        if (pulsesValue == null) {
          _logError('❌ استجابة السيرفر ناقصة: pulses=$pulsesValue');
          _logError('❌ Raw parsed data: $data');
          return null;
        }

        final double? glucose = glucoseValue?.toDouble();
        final int count = pulsesValue.toInt();

        _logYellow('Parsed glucose: $glucose');
        _logYellow('Parsed pulses count: $count');
        _logYellow('Parsed pulses list: $pulses');

        // يمكنك هنا إعادة البيانات أو تحويلها إلى Map ليتعامل معها باقي التطبيق
        return {
          'glucose': glucose,
          'glucose_per_pulse': pulses,
          'pulses': count,
        };
      } catch (e) {
        _logError('❌ خطأ عند تحليل استجابة السيرفر: $e');
        return null;
      }
    } else {
      _logError('❌ Server Error ${response.statusCode}: ${response.body}');
      return null;
    }
  }

  // إرسال الإشارة مع البيانات الإضافية (هذا الذي نستخدمه لتوليد الـ Dataset)
  Future<Map<String, dynamic>?> sendToServerWithMetadata({
    required List<double> signalList,
    required String patientId,
    required String sessionId,
    required double glucoseLevel,
    required int age,
    required double BMI,
  }) async {
    if (signalList.length < 60) {
      _logYellow(
        '⚠️ الإشارة قصيرة جداً (${signalList.length})، يفضل جمع المزيد من البيانات',
      );
      
    }

    _logYellow('🚀 SENDING WITH METADATA...');
    _logYellow('Signal size: ${signalList.length}');
    _logYellow('Patient ID: $patientId | Session ID: $sessionId');
    _logYellow('Glucose input: $glucoseLevel | Age: $age | BMI: $BMI');

    final response = await ApiService.sendSignalWithMetadataRaw(
      signalList: signalList,
      patientId: patientId,
      sessionId: sessionId,
      age: age,
      glucoseLevel: glucoseLevel,
      BMI: BMI,
    );

    if (response == null) {
      _logError('❌ لا توجد استجابة من السيرفر (null response)');
      return null;
    }

    _logYellow('HTTP status: ${response.statusCode}');
    _logYellow('Raw body: ${response.body}');

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);

        final num? glucoseValue = data['glucose'] as num?;
        final num? pulsesValue = data['pulses'] as num?;
        final List pulses = data['glucose_per_pulse'] is List
            ? List.from(data['glucose_per_pulse'] as List)
            : [];

        if (pulsesValue == null) {
          _logError('❌ استجابة السيرفر ناقصة: pulses=$pulsesValue');
          _logError('❌ Raw parsed data: $data');
          return null;
        }

        final double? glucose = glucoseValue?.toDouble();
        final int count = pulsesValue.toInt();

        _logYellow('Parsed glucose: $glucose');
        _logYellow('Parsed pulses count: $count');
        _logYellow('Parsed pulses list: $pulses');

        return {
          'glucose': glucose,
          'glucose_per_pulse': pulses,
          'pulses': count,
        };
      } catch (e) {
        _logError('❌ خطأ عند تحليل استجابة السيرفر: $e');
        return null;
      }
    } else {
      _logError('❌ Server Error ${response.statusCode}: ${response.body}');
      return null;
    }
  }

  // دالة مساعدة لمسح البيانات يدوياً إذا لزم الأمر
  void reset() {
    red.clear();
  }
}
