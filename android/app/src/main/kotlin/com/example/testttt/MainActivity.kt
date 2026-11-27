package com.example.testttt

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "ppg/method"
    private val eventChannelName = "ppg/events"
    private val cameraPermissionRequestCode = 601

    private var ppgProcessor: PPGProcessor? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingStart = false

    private var textureEntry: io.flutter.view.TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: android.view.Surface? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "createTexture" -> {
                        textureEntry = flutterEngine.renderer.createSurfaceTexture()
                        val surfaceTexture = textureEntry!!.surfaceTexture()
                        val width = 720
                        val height = 960
                        surfaceTexture.setDefaultBufferSize(width, height)
                        previewSurface = android.view.Surface(surfaceTexture)
                        
                        val reply = hashMapOf(
                            "textureId" to textureEntry!!.id(),
                            "width" to width,
                            "height" to height
                        )
                        result.success(reply)
                    }
                    "startCamera" -> {
                        // The surface is already created in createTexture, we apply it when startMeasurement is called.
                        result.success(null)
                    }
                    "stopCamera" -> {
                        if (previewSurface != null) {
                            previewSurface?.release()
                            previewSurface = null
                        }
                        if (textureEntry != null) {
                            textureEntry?.release()
                            textureEntry = null
                        }
                        ppgProcessor?.setPreviewSurface(null)
                        result.success(null)
                    }
                    "startMeasurement" -> {
                        startProcessing()
                        result.success("started")
                    }
                    "stopMeasurement" -> {
                        stopProcessing()
                        result.success("stopped")
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startProcessing() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            pendingStart = true
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                cameraPermissionRequestCode
            )
            return
        }

        if (ppgProcessor == null) {
            ppgProcessor = PPGProcessor(this, this, object : PPGProcessor.Listener {
                override fun onFrame(frame: PPGProcessor.PpgFrame) {
                    val payload = hashMapOf(
                        "avgRed" to frame.avgRed,
                        "avgGreen" to frame.avgGreen,
                        "avgBlue" to frame.avgBlue,
                        "ppgValue" to frame.ppgValue,
                        "fingerDetected" to frame.fingerDetected,
                        "timestampMs" to frame.timestampMs
                    )
                    runOnUiThread {
                        eventSink?.success(payload)
                    }
                }

                override fun onError(message: String) {
                    val payload = hashMapOf(
                        "error" to message
                    )
                    runOnUiThread {
                        eventSink?.success(payload)
                    }
                }
            })
        }

        ppgProcessor?.setPreviewSurface(previewSurface)

        if (ppgProcessor?.isRunning == false) {
            ppgProcessor?.start()
        }
    }

    private fun stopProcessing() {
        pendingStart = false
        ppgProcessor?.stop()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == cameraPermissionRequestCode) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted && pendingStart) {
                pendingStart = false
                startProcessing()
            } else if (!granted) {
                eventSink?.success(hashMapOf("error" to "Camera permission denied"))
            }
        }
    }

    override fun onDestroy() {
        stopProcessing()
        super.onDestroy()
    }
}
