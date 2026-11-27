import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/models/user_model.dart';

/// سيرفس البروفايل - حفظ وجلب بيانات المستخدم
class ProfileService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── تحديث بيانات البروفايل ────────────────────────────────────
  Future<UserModel> updateProfile({
    required String firstName,
    required String lastName,
    double? weight,
    double? height,
  }) async {
    final updates = {
      'first_name': firstName,
      'last_name': lastName,
      if (weight != null) 'weight': weight,
      if (height != null) 'height': height,
    };

    final data = await _supabase
        .from('profiles')
        .update(updates)
        .eq('id', _userId)
        .select()
        .single();

    return UserModel.fromJson({
      ...data,
      'email': _supabase.auth.currentUser?.email ?? '',
    });
  }

  // ── رفع صورة البروفايل ────────────────────────────────────────
  Future<String> uploadProfileImage(File imageFile) async {
    try {
      final String fileName = 'avatar_$_userId.jpg';
      final String storagePath = 'avatars/$fileName';

      // رفع الصورة على Supabase Storage
      await _supabase.storage
          .from('profiles')
          .upload(
            storagePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      // جيب الـ public URL
      final String publicUrl = _supabase.storage
          .from('profiles')
          .getPublicUrl(storagePath);

      // حفظ الـ URL بجدول profiles
      await _supabase
          .from('profiles')
          .update({'profile_image_url': publicUrl})
          .eq('id', _userId);

      return publicUrl;
    } catch (e) {
      print('Upload Image Error: $e');
      if (e.toString().contains('Not Found') || e.toString().contains('404')) {
        throw Exception('Bucket "profiles" غير موجود في Supabase Storage');
      } else if (e.toString().contains('Permission') ||
          e.toString().contains('403')) {
        throw Exception('لا توجد صلاحيات كافية لرفع الصورة');
      }
      rethrow;
    }
  }

  // ── جلب بيانات البروفايل ─────────────────────────────────────
  Future<UserModel> getProfile() async {
    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', _userId)
        .single();

    return UserModel.fromJson({
      ...data,
      'email': _supabase.auth.currentUser?.email ?? '',
    });
  }
}
