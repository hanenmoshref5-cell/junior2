import 'dart:convert';
import 'dart:async';
import 'dart:ffi';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = "https://AishaGhoniem.pythonanywhere.com";

  static void _logError(String message) {
    debugPrint('\x1B[31m$message\x1B[0m');
  }

  // 1. الدالة التي ترسل الإشارة فقط (بدون بيانات إضافية)
  static Future<Map<String, dynamic>?> sendSignal(List<double> red) async {
    var url = Uri.parse("$baseUrl/process");

    try {
      var response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"red": red}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // إضافة رقم الخطأ يساعدك في تشخيص المشكلة بسرعة
        _logError("❌ Server Error ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      _logError("🚨 Connection Error: $e");
      return null;
    }
  }

  // 2. الدالة التي ترسل الإشارة مع Metadata (لتوليد الداتا سيت)
  static Future<Map<String, dynamic>?> sendSignalWithMetadata({
    required List<double> red,
    required String patientId,
    required String sessionId,
    required Float glucoseLevel,
    required int age,
    required double BMI,
  }) async {
    var url = Uri.parse("$baseUrl/process");

    try {
      var body = jsonEncode({
        "red": red,
        "patient_id": patientId,
        "session_id": sessionId,

        "age": age,
        "glucose": glucoseLevel,
        "BMI": BMI,
      });

      var response = await http
          .post(url, headers: {"Content-Type": "application/json"}, body: body)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _logError("❌ Error in sendSignalWithMetadata: ${response.body}");
        return null;
      }
    } catch (e) {
      _logError("🚨 Connection Error: $e");
      return null;
    }
  }

  // نسخة خام من إرسال الـ metadata لتحليل response داخل الكونترولر.
  static Future<http.Response?> sendSignalWithMetadataRaw({
    required List<double> signalList,
    required String patientId,
    required String sessionId,
    required double glucoseLevel,
    required int age,
    required double BMI,
  }) async {
    var url = Uri.parse("$baseUrl/process");

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "red": signalList,
              "patient_id": patientId.toString(),
              "session_id": sessionId,
              "age": age,
              "glucose_level": glucoseLevel,
              "BMI": BMI,
            }),
          )
          .timeout(const Duration(seconds: 60));

      return response;
    } catch (e) {
      _logError("🚨 Connection Error (metadata raw): $e");
      return null;
    }
  }

  // 3. دالة ترسل الإشارة وتُعيد الـ `http.Response` الخام بحيث يمكن
  static Future<http.Response?> sendSignalRaw({
    required List<double> signalList,
    String patientId = "1",
  }) async {
    var url = Uri.parse("$baseUrl/process");

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"red": signalList, "patient_id": patientId}),
          )
          .timeout(const Duration(seconds: 60));

      return response;
    } catch (e) {
      _logError("🚨 Connection Error (raw): $e");
      return null;
    }
  }
}
