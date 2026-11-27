package com.example.testttt

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity - نقطة الدخول الرئيسية للتطبيق (Flutter)
 * 
 * المسؤولية:
 * - تشغيل محرك Flutter
 * - توفير MethodChannel للتواصل بين Flutter و Android
 * - معالجة فتح PPGActivity عند استدعاء من Flutter
 */
class MainActivity: FlutterActivity() {

    // اسم القناة (Channel) - يجب أن يطابق ما في كود Flutter
    private val CHANNEL = "ppg_channel"

    /**
     * تكوين محرك Flutter
     * 
     * هنا نضع كل قنوات Method و Event
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // إنشاء MethodChannel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            
            // التحقق من اسم الأسلوب المطلوب
            when (call.method) {
                "openPPG" -> {
                    try {
                        // إنشاء Intent لفتح PPGActivity
                        val intent = Intent(this, PPGActivity::class.java)
                        
                        // فتح Activity جديد
                        startActivity(intent)
                        
                        // إرسال استجابة النجاح إلى Flutter
                        result.success("PPG Activity opened successfully")
                        
                    } catch (e: Exception) {
                        // إرسال رسالة خطأ إلى Flutter
                        result.error(
                            "ACTIVITY_ERROR",
                            "Failed to open PPG Activity: ${e.message}",
                            null
                        )
                    }
                }
                else -> {
                    // أسلوب غير معروف
                    result.notImplemented()
                }
            }
        }
    }
}
