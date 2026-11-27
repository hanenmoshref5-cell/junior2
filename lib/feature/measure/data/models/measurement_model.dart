import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ════════════════════════════════════════════════════════════════
// موديل القياس
// ════════════════════════════════════════════════════════════════
class MeasurementModel {
  final String? id;
  final String userId;
  final double value;
  final String unit;
  final String method; // 'manual' أو 'camera'
  final bool isFasting;
  final String status; // 'normal' / 'high' / 'very_high' / 'low' / 'very_low'
  final DateTime measuredAt;

  const MeasurementModel({
    this.id,
    required this.userId,
    required this.value,
    this.unit = 'mg/dL',
    required this.method,
    this.isFasting = false,
    required this.status,
    required this.measuredAt,
  });

  /// تحديد الحالة تلقائياً بناءً على القيمة والصيام
  static String calculateStatus(double value, bool isFasting) {
    if (isFasting) {
      if (value < 70) return 'very_low';
      if (value <= 100) return 'normal';
      if (value <= 125) return 'high';
      return 'very_high';
    } else {
      if (value < 70) return 'very_low';
      if (value <= 140) return 'normal';
      if (value <= 199) return 'high';
      return 'very_high';
    }
  }

  /// نص الحالة بالعربي
  String get statusLabel {
    switch (status) {
      case 'normal':
        return 'طبيعي';
      case 'high':
        return 'مرتفع';
      case 'very_high':
        return 'مرتفع جداً';
      case 'low':
        return 'منخفض';
      case 'very_low':
        return 'منخفض جداً';
      default:
        return 'غير محدد';
    }
  }

  factory MeasurementModel.fromJson(Map<String, dynamic> json) =>
      MeasurementModel(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        value: (json['value'] as num).toDouble(),
        unit: json['unit'] as String? ?? 'mg/dL',
        method: json['method'] as String,
        isFasting: json['is_fasting'] as bool? ?? false,
        status: json['status'] as String? ?? 'normal',
        measuredAt: DateTime.parse(json['measured_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'value': value,
    'unit': unit,
    'method': method,
    'is_fasting': isFasting,
    'status': status,
    'measured_at': measuredAt.toIso8601String(),
  };
}

// ════════════════════════════════════════════════════════════════
// سيرفس القياسات
// ════════════════════════════════════════════════════════════════
class MeasurementService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── حفظ قياس جديد ────────────────────────────────────────────
  Future<MeasurementModel> saveMeasurement({
    required double value,
    required String method,
    bool isFasting = false,
  }) async {
    final status = MeasurementModel.calculateStatus(value, isFasting);

    final measurement = MeasurementModel(
      userId: _userId,
      value: value,
      method: method,
      isFasting: isFasting,
      status: status,
      measuredAt: DateTime.now(),
    );

    final data = await _supabase
        .from('measurements')
        .insert(measurement.toJson())
        .select()
        .single();

    return MeasurementModel.fromJson(data);
  }

  // ── جلب آخر قياس ─────────────────────────────────────────────
  Future<MeasurementModel?> getLatestMeasurement() async {
    try {
      final data = await _supabase
          .from('measurements')
          .select()
          .eq('user_id', _userId)
          .order('measured_at', ascending: false)
          .limit(1);

      if (data.isEmpty) return null;
      return MeasurementModel.fromJson(data.first);
    } catch (e) {
      debugPrint('❌ خطأ في جلب آخر قياس: $e');
      return null;
    }
  }

  // ── جلب القياسات حسب الفترة الزمنية ─────────────────────────
  Future<List<MeasurementModel>> getMeasurements({
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _supabase
        .from('measurements')
        .select()
        .eq('user_id', _userId)
        .gte('measured_at', from.toIso8601String())
        .lte('measured_at', to.toIso8601String())
        .order('measured_at', ascending: true);

    return (data as List).map((e) => MeasurementModel.fromJson(e)).toList();
  }

  // ── جلب قياسات اليوم ─────────────────────────────────────────
  Future<List<MeasurementModel>> getTodayMeasurements() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return getMeasurements(from: start, to: end);
  }

  // ── جلب قياسات آخر X أيام ────────────────────────────────────
  Future<List<MeasurementModel>> getLastDays(int days) {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));
    return getMeasurements(from: from, to: now);
  }
}
