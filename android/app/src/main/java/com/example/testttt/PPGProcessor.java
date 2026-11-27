package com.example.testttt;

import androidx.annotation.NonNull;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.LifecycleOwner;

import android.content.Context;
import android.util.Size;

import com.google.common.util.concurrent.ListenableFuture;

import java.nio.ByteBuffer;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Native PPG processing engine (no UI, no XML).
 * Owns CameraX + realtime signal processing and emits frames to Flutter.
 */
public class PPGProcessor {
    public interface Listener {
        void onFrame(@NonNull PpgFrame frame);
        void onError(@NonNull String message);
    }
    
    public static final class PpgFrame {
        public final float avgRed;
        public final float avgGreen;
        public final float avgBlue;
        public final float ppgValue;
        public final boolean fingerDetected;
        public final long timestampMs;

        public PpgFrame(float avgRed, float avgGreen, float avgBlue, float ppgValue, boolean fingerDetected, long timestampMs) {
            this.avgRed = avgRed;
            this.avgGreen = avgGreen;
            this.avgBlue = avgBlue;
            this.ppgValue = ppgValue;
            this.fingerDetected = fingerDetected;
            this.timestampMs = timestampMs;
        }
    }

    /** Bandpass filter (approx 0.5Hz - 8.0Hz). */
    private static final class RealtimeBandpassFilter {
        private static final float LOW_PASS_ALPHA = 0.62f;  // ~8.0 Hz
        private static final float HIGH_PASS_ALPHA = 0.90f; // ~0.5 Hz

        private float lastLowPassed = 0f;
        private float prevRaw = 0f;
        private float prevFiltered = 0f;
        private boolean isFirstValue = true;

        float apply(float newValue) {
            if (isFirstValue) {
                lastLowPassed = newValue;
                prevRaw = newValue;
                prevFiltered = newValue;
                isFirstValue = false;
                return 0f;
            }

            lastLowPassed = LOW_PASS_ALPHA * newValue + (1.0f - LOW_PASS_ALPHA) * lastLowPassed;
            float filtered = HIGH_PASS_ALPHA * (prevFiltered + lastLowPassed - prevRaw);

            prevRaw = lastLowPassed;
            prevFiltered = filtered;

            return filtered;
        }
    }

    /** Z-Score normalization with sliding window. */
    private static final class RealtimeNormalizer {
        private final int windowSize;
        private final float[] window;
        private int pointer = 0;
        private int count = 0;

        RealtimeNormalizer(int windowSize) {
            this.windowSize = windowSize;
            this.window = new float[windowSize];
        }

        float apply(float newValue) {
            window[pointer] = newValue;
            pointer = (pointer + 1) % windowSize;
            if (count < windowSize) count++;
            if (count < 2) return 0f;

            float sum = 0f;
            for (int i = 0; i < count; i++) {
                sum += window[i];
            }
            float mean = sum / count;

            float varianceSum = 0f;
            for (int i = 0; i < count; i++) {
                float d = window[i] - mean;
                varianceSum += d * d;
            }
            float std = (float) Math.sqrt(varianceSum / count);

            return (std != 0f) ? (newValue - mean) / std : 0f;
        }
    }

    private final Context context;
    private final LifecycleOwner lifecycleOwner;
    private final Listener listener;

    private ExecutorService cameraExecutor;
    private ProcessCameraProvider cameraProvider;
    private ListenableFuture<ProcessCameraProvider> cameraProviderFuture;

    private RealtimeBandpassFilter bandpassFilter;
    private RealtimeNormalizer normalizer;

    private boolean isRunning = false;
    private android.view.Surface previewSurface;

    public PPGProcessor(@NonNull Context context, @NonNull LifecycleOwner lifecycleOwner, @NonNull Listener listener) {
        this.context = context;
        this.lifecycleOwner = lifecycleOwner;
        this.listener = listener;
    }

    public void setPreviewSurface(android.view.Surface surface) {
        this.previewSurface = surface;
    }

    public boolean isRunning() {
        return isRunning;
    }

    public void start() {
        if (isRunning) return;

        isRunning = true;
        bandpassFilter = new RealtimeBandpassFilter();
        normalizer = new RealtimeNormalizer(90);

        if (cameraExecutor == null || cameraExecutor.isShutdown()) {
            cameraExecutor = Executors.newSingleThreadExecutor();
        }

        cameraProviderFuture = ProcessCameraProvider.getInstance(context);
        cameraProviderFuture.addListener(() -> {
            try {
                cameraProvider = cameraProviderFuture.get();
                bindCamera();
            } catch (ExecutionException | InterruptedException e) {
                isRunning = false;
                listener.onError("CameraX initialization failed: " + e.getMessage());
            }
        }, ContextCompat.getMainExecutor(context));
    }

    public void stop() {
        isRunning = false;

        if (cameraProvider != null) {
            cameraProvider.unbindAll();
        }

        if (cameraExecutor != null && !cameraExecutor.isShutdown()) {
            cameraExecutor.shutdown();
        }
    }

    private void bindCamera() {
        if (cameraProvider == null) return;

        cameraProvider.unbindAll();

        ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                .setTargetResolution(new Size(120, 160))
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build();

        imageAnalysis.setAnalyzer(cameraExecutor, this::analyzeFrame);

        CameraSelector cameraSelector = new CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
                .build();

        androidx.camera.core.Preview preview = null;
        if (previewSurface != null) {
            preview = new androidx.camera.core.Preview.Builder()
                    .setTargetResolution(new Size(720, 960))
                    .build();
            preview.setSurfaceProvider(request -> {
                request.provideSurface(previewSurface, ContextCompat.getMainExecutor(context), result -> {
                    // Handle surface release or errors if necessary
                });
            });
        }

        if (preview != null) {
            cameraProvider.bindToLifecycle(lifecycleOwner, cameraSelector, preview, imageAnalysis);
        } else {
            cameraProvider.bindToLifecycle(lifecycleOwner, cameraSelector, imageAnalysis);
        }
    }

    private void analyzeFrame(@NonNull ImageProxy image) {
        try {
            if (!isRunning) return;

            ImageProxy.PlaneProxy[] planes = image.getPlanes();
            if (planes.length < 3) {
                listener.onError("Unsupported image planes: " + planes.length);
                return;
            }

            ImageProxy.PlaneProxy yPlane = planes[0];
            ImageProxy.PlaneProxy uPlane = planes[1];
            ImageProxy.PlaneProxy vPlane = planes[2];

            ByteBuffer yBuffer = yPlane.getBuffer();
            ByteBuffer uBuffer = uPlane.getBuffer();
            ByteBuffer vBuffer = vPlane.getBuffer();

            int yRowStride = yPlane.getRowStride();
            int yPixelStride = yPlane.getPixelStride();
            int uvRowStride = uPlane.getRowStride();
            int uvPixelStride = uPlane.getPixelStride();

            int width = image.getWidth();
            int height = image.getHeight();

            float avgLuminance = calculateAverage(yBuffer);
            boolean fingerDetected = avgLuminance > 10f;

            float avgRed = 0f;
            float avgGreen = 0f;
            float avgBlue = 0f;
            float ppgValue = 0f;

            if (fingerDetected) {
                int boxWidth = (int) (width * 0.40);
                int boxHeight = (int) (height * 0.40);
                int startX = (width - boxWidth) / 2;
                int startY = (height - boxHeight) / 2;
                int endX = startX + boxWidth;
                int endY = startY + boxHeight;

                long sumRed = 0;
                long sumGreen = 0;
                long sumBlue = 0;
                int count = 0;

                // Sample center region and convert YUV -> RGB.
                for (int y = endY - 1; y >= startY; y--) {
                    for (int x = startX; x < endX; x++) {
                        int yIndex = y * yRowStride + x * yPixelStride;
                        if (yIndex >= yBuffer.limit()) continue;
                        int yValue = yBuffer.get(yIndex) & 0xFF;

                        int uvX = x / 2;
                        int uvY = y / 2;
                        int uvIndex = uvY * uvRowStride + uvX * uvPixelStride;
                        if (uvIndex >= uBuffer.limit() || uvIndex >= vBuffer.limit()) continue;

                        int uValue = (uBuffer.get(uvIndex) & 0xFF) - 128;
                        int vValue = (vBuffer.get(uvIndex) & 0xFF) - 128;

                        int r = (int) (yValue + 1.370705f * vValue);
                        int g = (int) (yValue - 0.337633f * uValue - 0.698001f * vValue);
                        int b = (int) (yValue + 1.732446f * uValue);

                        r = clamp255(r);
                        g = clamp255(g);
                        b = clamp255(b);

                        sumRed += r;
                        sumGreen += g;
                        sumBlue += b;
                        count++;
                    }
                }

                if (count > 0) {
                    avgRed = (float) sumRed / count;
                    avgGreen = (float) sumGreen / count;
                    avgBlue = (float) sumBlue / count;

                    // Raw PPG uses green channel average with inversion.
                    float rawAverage = -avgGreen;
                    float bandpassed = bandpassFilter.apply(rawAverage);
                    ppgValue = normalizer.apply(bandpassed);
                }
            }
        
            // Emit frame to Flutter via EventChannel.
            listener.onFrame(new PpgFrame(avgRed, avgGreen, avgBlue, ppgValue, fingerDetected, System.currentTimeMillis()));
        } catch (Exception e) {
            listener.onError("Frame processing failed: " + e.getMessage());
        } finally {
            image.close();
        }
    }

    private static int clamp255(int v) {
        if (v < 0) return 0;
        if (v > 255) return 255;
        return v;
    }

    private float calculateAverage(@NonNull ByteBuffer buffer) {
        long sum = 0;
        int count = 0;
        buffer.rewind();
        while (buffer.hasRemaining()) {
            sum += buffer.get() & 0xFF;
            count++;
        }
        return (count > 0) ? (float) sum / count : 0f;
    }
}
