import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// سيرفس تسجيل الدخول والتسجيل عبر Supabase
class AuthService {
  final _supabase = Supabase.instance.client;

  // ── تسجيل حساب جديد ──────────────────────────────────────────
  Future<UserModel> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String gender,
    required DateTime birthDate,
    required double weight,
    required double height,
  }) async {
    try {
      // 1. إنشاء حساب في auth
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user == null) throw Exception('فشل إنشاء الحساب');

      // 2. حفظ بيانات المستخدم في جدول profiles
      try {
        await _supabase.from('profiles').insert({
          'id': res.user!.id,
          'first_name': firstName,
          'last_name': lastName,
          'gender': gender,
          'birth_date': birthDate.toIso8601String().split('T')[0],
          'weight': weight,
          'height': height,
        });
      } catch (profileError) {
        // حذف الحساب إذا فشلت عملية إدراج البيانات
        try {
          await _supabase.auth.admin.deleteUser(res.user!.id);
        } catch (_) {}

        if (profileError.toString().contains('404') ||
            profileError.toString().contains('Invalid path')) {
          throw Exception(
            'جدول profiles غير موجود في قاعدة البيانات. تأكد من إنشاء الجدول في Supabase',
          );
        }
        throw Exception('فشل حفظ البيانات الشخصية: $profileError');
      }

      return UserModel(
        id: res.user!.id,
        firstName: firstName,
        lastName: lastName,
        email: email,
        gender: gender,
        birthDate: birthDate,
        weight: weight,
        height: height,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ── تسجيل الدخول ─────────────────────────────────────────────
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final AuthResponse res = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (res.user == null) throw Exception('البريد أو كلمة المرور غير صحيحة');

    // جلب بيانات البروفايل
    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', res.user!.id)
        .single();

    return UserModel.fromJson({...data, 'email': email});
  }

  // ── تسجيل الخروج ─────────────────────────────────────────────
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // ── إعادة تعيين كلمة المرور ──────────────────────────────────
  // Future<void> resetPassword(String email) async {
  //   await _supabase.auth.resetPasswordForEmail(email);
  // }

  // ── التحقق من الجلسة الحالية ─────────────────────────────────
  Future<UserModel?> getCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return UserModel.fromJson({...data, 'email': user.email ?? ''});
    } catch (_) {
      return null;
    }
  }

  // ── التحقق من تسجيل الدخول ───────────────────────────────────
  bool get isLoggedIn => _supabase.auth.currentUser != null;
}
