package com.gppg.ppg;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.video.FileOutputOptions;
import androidx.camera.video.Quality;
import androidx.camera.video.QualitySelector;
import androidx.camera.video.Recorder;
import androidx.camera.video.Recording;
import androidx.camera.video.VideoCapture;
import androidx.camera.video.VideoRecordEvent;
import androidx.camera.view.PreviewView;
import androidx.constraintlayout.widget.ConstraintLayout;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.view.WindowCompat;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.CountDownTimer;
import android.os.Environment;
import android.provider.Settings;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.util.Size;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

import com.github.mikephil.charting.charts.LineChart;
import com.github.mikephil.charting.components.XAxis;
import com.github.mikephil.charting.components.YAxis;
import com.github.mikephil.charting.data.Entry;
import com.github.mikephil.charting.data.LineData;
import com.github.mikephil.charting.data.LineDataSet;
import com.github.mikephil.charting.interfaces.datasets.ILineDataSet;
import com.google.android.material.switchmaterial.SwitchMaterial;
import com.google.common.util.concurrent.ListenableFuture;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** فلتر تمرير حزمة (Bandpass Filter) تقريبي (0.5Hz - 8.0Hz) ليتوافق مع ترددات Python */
class RealtimeBandpassFilter {
    private static final float LOW_PASS_ALPHA = 0.62f;  // ~8.0 Hz
    private static final float HIGH_PASS_ALPHA = 0.90f; // ~0.5 Hz

    private float lastLowPassed = 0f;
    private float prevRaw = 0f;
    private float prevFiltered = 0f;
    private boolean isFirstValue = true;

    public float apply(float newValue) {
        if (isFirstValue) {
            lastLowPassed = newValue;
            prevRaw = newValue;
            prevFiltered = newValue;
            isFirstValue = false;
            return 0f;
        }

        // 1. تطبيق Low Pass Filter
        lastLowPassed = LOW_PASS_ALPHA * newValue + (1.0f - LOW_PASS_ALPHA) * lastLowPassed;

        // 2. تطبيق High Pass Filter
        float filtered = HIGH_PASS_ALPHA * (prevFiltered + lastLowPassed - prevRaw);

        prevRaw = lastLowPassed;
        prevFiltered = filtered;

        return filtered;
    }
}

/** تطبيع الإشارة (Z-Score Normalization) باستخدام نافذة منزلقة */
class RealtimeNormalizer {
    private final int windowSize;
    private final float[] window;
    private int pointer = 0;
    private int count = 0;

    public RealtimeNormalizer(int windowSize) {
        this.windowSize = windowSize;
        this.window = new float[windowSize];
    }

    public float apply(float newValue) {
        window[pointer] = newValue;
        pointer = (pointer + 1) % windowSize;
        if (count < windowSize) count++;

        if (count < 2) return 0f;

        float sum = 0;
        for (int i = 0; i < count; i++) {
            sum += window[i];
        }
        float mean = sum / count;

        float varianceSum = 0;
        for (int i = 0; i < count; i++) {
            varianceSum += Math.pow(window[i] - mean, 2);
        }
        float std = (float) Math.sqrt(varianceSum / count);

        return (std != 0) ? (newValue - mean) / std : 0f;
    }
}

public class MainActivity extends AppCompatActivity {

    private enum AppState {
        IDLE,
        WAITING_FOR_FINGER,
        STABILIZING,
        RECORDING,
        WAITING_FOR_INPUT
    }

    private AppState currentState = AppState.IDLE;

    // Arayüz elemanları
    private View colorView;
    private SeekBar hueSeekBar;
    private SeekBar brightnessSeekBar;
    private TextView brightnessValueText;
    private PreviewView previewView;
    private LineChart realtimeChart;
    private Button newRecordButton;
    private Button saveButton;
    private ConstraintLayout recordingLayout;
    private TextView instructionsTextView;
    private EditText bloodSugarEditText;
    private SwitchMaterial recordingMethodSwitch;

    // Kamera ve analiz değişkenleri
    private ListenableFuture<ProcessCameraProvider> cameraProviderFuture;
    private ExecutorService cameraExecutor;

    // الفلاتر المتوافقة مع بايثون
    private RealtimeBandpassFilter bandpassFilter;
    private RealtimeNormalizer normalizer;

    private Toast statusToast = null;

    // Video değişkenleri
    private VideoCapture<Recorder> videoCapture = null;
    private Recording currentRecording = null;

    // Kayıt süreci değişkenleri
    private CountDownTimer stabilizationTimer;
    private CountDownTimer recordingTimer;
    private List<Float> recordedPpgData;

    private static final int CAMERA_PERMISSION_REQUEST_CODE = 101;
    private static final int STORAGE_PERMISSION_REQUEST_CODE = 102;
    private static final String FOLDER_NAME = "PPG_Signals";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        getWindow().setStatusBarColor(Color.TRANSPARENT);
        setContentView(R.layout.activity_main);

        bindViews();

        // تهيئة الفلاتر الجديدة
        bandpassFilter = new RealtimeBandpassFilter();
        normalizer = new RealtimeNormalizer(90); // نافذة 90 إطار (حوالي 3 ثواني)

        recordedPpgData = new ArrayList<>();

        setupListeners();

        // ضبط اللون الافتراضي على الأخضر (Hue = 120)
        hueSeekBar.setMax(360);
        hueSeekBar.setProgress(120);
        float[] initialHsv = {120f, 1.0f, 1.0f};
        colorView.setBackgroundColor(Color.HSVToColor(initialHsv));

        checkSystemWritePermission();
        setupChart();
        cameraExecutor = Executors.newSingleThreadExecutor();
        checkCameraPermissionAndStartCamera();

        // إخفاء الزر الخاص بتغيير الطرق
        recordingMethodSwitch.setVisibility(View.GONE);

        resetToIdleState();
    }

    private void bindViews() {
        colorView = findViewById(R.id.colorView);
        hueSeekBar = findViewById(R.id.hueSeekBar);
        brightnessSeekBar = findViewById(R.id.brightnessSeekBar);
        brightnessValueText = findViewById(R.id.brightnessValueText);
        previewView = findViewById(R.id.camera_preview);
        realtimeChart = findViewById(R.id.realtime_chart);
        newRecordButton = findViewById(R.id.newRecordButton);
        saveButton = findViewById(R.id.saveButton);
        recordingLayout = findViewById(R.id.recordingLayout);
        instructionsTextView = findViewById(R.id.instructionsTextView);
        bloodSugarEditText = findViewById(R.id.bloodSugarEditText);
        recordingMethodSwitch = findViewById(R.id.recordingMethodSwitch);
    }

    private void setupListeners() {
        hueSeekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                float currentHue = (float) progress;
                float[] hsv = {currentHue, 1.0f, 1.0f};
                colorView.setBackgroundColor(Color.HSVToColor(hsv));
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        newRecordButton.setOnClickListener(v -> {
            currentState = AppState.WAITING_FOR_FINGER;
            updateUiForState();
            resetMeasurementProcess();
        });

        saveButton.setOnClickListener(v -> checkAndRequestStoragePermission());

        bloodSugarEditText.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                if (currentState == AppState.WAITING_FOR_INPUT) {
                    saveButton.setEnabled(s.length() > 0);
                }
            }
            @Override
            public void afterTextChanged(Editable s) {}
        });
    }

    private void updateUiForState() {
        runOnUiThread(() -> {
            switch (currentState) {
                case IDLE:
                    newRecordButton.setVisibility(View.VISIBLE);
                    recordingLayout.setVisibility(View.GONE);
                    break;
                case WAITING_FOR_FINGER:
                case STABILIZING:
                case RECORDING:
                    newRecordButton.setVisibility(View.GONE);
                    recordingLayout.setVisibility(View.VISIBLE);
                    bloodSugarEditText.setEnabled(false);
                    saveButton.setEnabled(false);
                    break;
                case WAITING_FOR_INPUT:
                    newRecordButton.setVisibility(View.GONE);
                    recordingLayout.setVisibility(View.VISIBLE);
                    bloodSugarEditText.setEnabled(true);
                    saveButton.setEnabled(bloodSugarEditText.getText().length() > 0);
                    break;
            }
        });
    }

    private void resetMeasurementProcess() {
        if (stabilizationTimer != null) stabilizationTimer.cancel();
        if (recordingTimer != null) recordingTimer.cancel();

        stopVideoRecording();

        recordedPpgData.clear();
        if (realtimeChart.getData() != null) {
            realtimeChart.getData().clearValues();
            realtimeChart.notifyDataSetChanged();
            realtimeChart.invalidate();
        }

        instructionsTextView.setText("Parmağınızı kameraya doğru şekilde yerleştirin");
        bloodSugarEditText.setText("");

        if (currentState != AppState.IDLE) {
            currentState = AppState.WAITING_FOR_FINGER;
        }
        updateUiForState();
    }

    private void resetToIdleState() {
        currentState = AppState.IDLE;
        resetMeasurementProcess();
        updateUiForState();
        instructionsTextView.setText("Yeni bir kayıt başlatmak için basın");
    }

    private void startStabilizationTimer() {
        currentState = AppState.STABILIZING;
        stabilizationTimer = new CountDownTimer(10000, 1000) {
            @Override
            public void onTick(long millisUntilFinished) {
                instructionsTextView.setText("Sinyal iyi! Sabit tutun... " + (millisUntilFinished / 1000));
            }
            @Override
            public void onFinish() {
                startRecordingTimer();
            }
        }.start();
    }

    private void startRecordingTimer() {
        currentState = AppState.RECORDING;
        recordedPpgData.clear();

        startVideoRecording();

        recordingTimer = new CountDownTimer(30000, 1000) {
            @Override
            public void onTick(long millisUntilFinished) {
                instructionsTextView.setText("Kayıt yapılıyor... " + (millisUntilFinished / 1000));
            }
            @Override
            public void onFinish() {
                stopVideoRecording();

                currentState = AppState.WAITING_FOR_INPUT;
                instructionsTextView.setText("Kayıt tamamlandı. Kan şekeri değerini girin ve kaydet'e basın.");
                updateUiForState();
                Toast.makeText(MainActivity.this, "30 saniyelik veri başarıyla kaydedildi", Toast.LENGTH_SHORT).show();
            }
        }.start();
    }

    private void startVideoRecording() {
        if (videoCapture == null) return;

        String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
        String fileName = "PPG_Video_" + timeStamp + ".mp4";

        File documentsFolder = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS);
        File appFolder = new File(documentsFolder, FOLDER_NAME);
        if (!appFolder.exists() && !appFolder.mkdirs()) {
            return;
        }
        File videoFile = new File(appFolder, fileName);

        FileOutputOptions fileOutputOptions = new FileOutputOptions.Builder(videoFile).build();

        currentRecording = videoCapture.getOutput()
                .prepareRecording(this, fileOutputOptions)
                .start(ContextCompat.getMainExecutor(this), videoRecordEvent -> {
                    if (videoRecordEvent instanceof VideoRecordEvent.Start) {
                        Log.d("VideoCapture", "تم بدء تسجيل الفيديو بنجاح");
                    } else if (videoRecordEvent instanceof VideoRecordEvent.Finalize) {
                        VideoRecordEvent.Finalize finalizeEvent = (VideoRecordEvent.Finalize) videoRecordEvent;
                        if (!finalizeEvent.hasError()) {
                            Log.d("VideoCapture", "تم حفظ الفيديو في: " + videoFile.getAbsolutePath());
                        } else {
                            Log.e("VideoCapture", "خطأ أثناء تسجيل الفيديو: " + finalizeEvent.getError());
                        }
                    }
                });
    }

    private void stopVideoRecording() {
        if (currentRecording != null) {
            currentRecording.stop();
            currentRecording = null;
        }
    }

    @SuppressLint("UnsafeOptInUsageError")
    void bindPreview(@NonNull ProcessCameraProvider cameraProvider) {
        cameraProvider.unbindAll();

        Preview preview = new Preview.Builder().build();
        preview.setSurfaceProvider(previewView.getSurfaceProvider());

        ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                .setTargetResolution(new Size(120, 160))
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build();

        Recorder recorder = new Recorder.Builder()
                .setQualitySelector(QualitySelector.from(Quality.LOWEST))
                .build();
        videoCapture = VideoCapture.withOutput(recorder);

        imageAnalysis.setAnalyzer(cameraExecutor, image -> {
            ImageProxy.PlaneProxy yPlane = image.getPlanes()[0];
            ImageProxy.PlaneProxy uPlane = image.getPlanes()[1];
            ImageProxy.PlaneProxy vPlane = image.getPlanes()[2];

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
            boolean isFingerDetected = (avgLuminance > 10f);

            if (isFingerDetected) {
                // المربع المركزي (40%)
                int boxWidth = (int) (width * 0.40);
                int boxHeight = (int) (height * 0.40);
                int startX = (width - boxWidth) / 2;

                int startY = (height - boxHeight) / 2;
                int endX = startX + boxWidth;
                int endY = startY + boxHeight;

                long sum = 0;
                int count = 0;

                // الحلقة تقرأ الآن من الأسفل (endY - 1) إلى الأعلى (startY)
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

                        // استخراج القناة الخضراء
                        int greenValue = (int) (yValue - 0.344f * uValue - 0.714f * vValue);
                        greenValue = Math.max(0, Math.min(255, greenValue));

                        sum += greenValue;
                        count++;
                    }
                }

                // 1. حساب المتوسط وعكس الإشارة (-np.mean)
                float rawAverage = (count > 0) ? (float) -sum / count : 0;

                // 2. تطبيق فلتر Bandpass
                float bandpassedSignal = bandpassFilter.apply(rawAverage);

                // 3. تطبيع الإشارة (Z-Score)
                float normalizedSignal = normalizer.apply(bandpassedSignal);

                final float[] dataToSend = new float[]{normalizedSignal};

                boolean isSignalGood = (normalizedSignal >= -4.0f && normalizedSignal <= 4.0f);

                runOnUiThread(() -> handleSignalState(isSignalGood, dataToSend));

            } else {
                runOnUiThread(() -> handleSignalState(false, null));
            }
            image.close();
        });

        CameraSelector cameraSelector = new CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
                .build();

        cameraProvider.bindToLifecycle(this, cameraSelector, preview, imageAnalysis, videoCapture);
    }

    private void handleSignalState(boolean isSignalGood, float[] data) {
        if (currentState == AppState.IDLE || currentState == AppState.WAITING_FOR_INPUT) {
            return;
        }

        if (isSignalGood) {
            realtimeChart.setVisibility(View.VISIBLE);
            if (statusToast != null) statusToast.cancel();

            for (float value : data) {
                addChartEntry(value);
            }

            if (currentState == AppState.WAITING_FOR_FINGER) {
                startStabilizationTimer();
            } else if (currentState == AppState.RECORDING) {
                for (float value : data) {
                    recordedPpgData.add(value);
                }
            }
        } else {
            realtimeChart.setVisibility(View.INVISIBLE);
            showStatusToast("Lütfen parmağınızın konumunu ayarlayın veya kamerayı tamamen kapatın");

            if (currentState == AppState.STABILIZING || currentState == AppState.RECORDING) {
                Toast.makeText(this, "Sinyal kesildi! İşlem yeniden başlatılıyor.", Toast.LENGTH_SHORT).show();
                resetMeasurementProcess();
            }
        }
    }

    private void showStatusToast(String message) {
        if (statusToast == null) {
            statusToast = Toast.makeText(MainActivity.this, message, Toast.LENGTH_SHORT);
        } else {
            statusToast.setText(message);
        }
        statusToast.show();
    }

    private void saveDataToCsv() {
        saveButton.setEnabled(false);

        String bloodSugarValue = bloodSugarEditText.getText().toString();
        if (bloodSugarValue.isEmpty()) {
            Toast.makeText(this, "Lütfen önce kan şekeri değerini girin!", Toast.LENGTH_SHORT).show();
            saveButton.setEnabled(true);
            return;
        }

        if (recordedPpgData.isEmpty()) {
            Toast.makeText(this, "Kaydedilecek veri bulunmuyor!", Toast.LENGTH_SHORT).show();
            resetToIdleState();
            return;
        }

        StringBuilder fileContent = new StringBuilder();
        fileContent.append("recording_method\n");
        fileContent.append("CENTER_BOX_NORMALIZED\n");
        fileContent.append("blood_sugar_value\n");
        fileContent.append(bloodSugarValue).append("\n");
        fileContent.append("ppg_data\n");
        for (Float dataPoint : recordedPpgData) {
            fileContent.append(dataPoint).append("\n");
        }

        try {
            File documentsFolder = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS);
            File appFolder = new File(documentsFolder, FOLDER_NAME);
            if (!appFolder.exists() && !appFolder.mkdirs()) {
                Log.e("SaveFile", "Klasör oluşturulamadı!");
                Toast.makeText(this, "Klasör oluşturma başarısız", Toast.LENGTH_SHORT).show();
                runOnUiThread(() -> saveButton.setEnabled(true));
                return;
            }

            String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
            String fileName = "PPG_Signal_" + timeStamp + ".csv";
            File file = new File(appFolder, fileName);

            FileWriter writer = new FileWriter(file);
            writer.write(fileContent.toString());
            writer.flush();
            writer.close();

            Toast.makeText(this, "Başarıyla kaydedildi: " + file.getAbsolutePath(), Toast.LENGTH_LONG).show();
            Log.d("SaveFile", "Dosya başarıyla kaydedildi: " + file.getAbsolutePath());

            resetToIdleState();

        } catch (IOException e) {
            Log.e("SaveFile", "Dosya kaydedilirken hata oluştu", e);
            Toast.makeText(this, "Dosya kaydedilemedi: " + e.getMessage(), Toast.LENGTH_LONG).show();
            if (currentState != AppState.IDLE) {
                runOnUiThread(() -> saveButton.setEnabled(true));
            }
        }
    }

    private void setupChart() {
        realtimeChart.getDescription().setEnabled(false);
        realtimeChart.setTouchEnabled(true);
        realtimeChart.setDragEnabled(true);
        realtimeChart.setScaleEnabled(true);
        realtimeChart.setDrawGridBackground(false);
        realtimeChart.setPinchZoom(true);
        realtimeChart.setBackgroundColor(Color.TRANSPARENT);
        realtimeChart.setVisibility(View.INVISIBLE);

        LineData data = new LineData();
        data.setValueTextColor(Color.WHITE);
        realtimeChart.setData(data);

        XAxis xl = realtimeChart.getXAxis();
        xl.setTextColor(Color.DKGRAY);
        xl.setDrawGridLines(false);
        xl.setAvoidFirstLastClipping(true);
        xl.setEnabled(true);
        xl.setPosition(XAxis.XAxisPosition.BOTTOM);

        YAxis leftAxis = realtimeChart.getAxisLeft();
        leftAxis.setTextColor(Color.DKGRAY);
        leftAxis.setDrawGridLines(true);
        leftAxis.setAxisMinimum(-4f);
        leftAxis.setAxisMaximum(4f);

        realtimeChart.getAxisRight().setEnabled(false);
        realtimeChart.getLegend().setEnabled(false);
    }

    private void addChartEntry(float value) {
        LineData data = realtimeChart.getData();
        if (data == null) return;

        ILineDataSet set = data.getDataSetByIndex(0);
        if (set == null) {
            set = createSet();
            data.addDataSet(set);
        }

        data.addEntry(new Entry(set.getEntryCount(), value), 0);
        data.notifyDataChanged();
        realtimeChart.notifyDataSetChanged();

        realtimeChart.setVisibleXRangeMaximum(150);
        realtimeChart.moveViewToX(data.getEntryCount());
    }

    private LineDataSet createSet() {
        LineDataSet set = new LineDataSet(null, "PPG Sinyali");
        set.setAxisDependency(YAxis.AxisDependency.LEFT);
        set.setColor(Color.RED);
        set.setLineWidth(2.5f);
        set.setDrawCircles(false);
        set.setDrawValues(false);
        set.setMode(LineDataSet.Mode.CUBIC_BEZIER);
        return set;
    }

    private float calculateAverage(ByteBuffer buffer) {
        long sum = 0;
        int count = 0;
        buffer.rewind();
        while (buffer.hasRemaining()) {
            sum += buffer.get() & 0xFF;
            count++;
        }
        return (count > 0) ? (float) sum / count : 0;
    }

    private void checkCameraPermissionAndStartCamera() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            startCamera();
        } else {
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.CAMERA}, CAMERA_PERMISSION_REQUEST_CODE);
        }
    }

    private void startCamera() {
        cameraProviderFuture = ProcessCameraProvider.getInstance(this);
        cameraProviderFuture.addListener(() -> {
            try {
                ProcessCameraProvider cameraProvider = cameraProviderFuture.get();
                bindPreview(cameraProvider);
            } catch (ExecutionException | InterruptedException e) {
                Log.e("CameraX", "Kamera başlatılamadı.", e);
                Toast.makeText(this, "Kamera başlatılamadı", Toast.LENGTH_SHORT).show();
            }
        }, ContextCompat.getMainExecutor(this));
    }

    private void checkSystemWritePermission() {
        boolean permissionGranted = (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) || Settings.System.canWrite(this);
        if (permissionGranted) {
            setupBrightnessSlider();
        } else {
            showPermissionDialog();
        }
    }

    private void showPermissionDialog() {
        new AlertDialog.Builder(this)
                .setTitle("İzin Gerekli")
                .setMessage("Uygulamanın ekran parlaklığını kontrol edebilmesi için sistem ayarlarını değiştirme iznine ihtiyacı var.")
                .setPositiveButton("Ayarlara Git", (dialog, which) -> {
                    Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS);
                    intent.setData(Uri.parse("package:" + getPackageName()));
                    startActivity(intent);
                })
                .setNegativeButton("İptal", (dialog, which) -> {
                    Toast.makeText(this, "Bu izin olmadan ekran parlaklığı kontrol edilemez.", Toast.LENGTH_LONG).show();
                    brightnessSeekBar.setEnabled(false);
                    brightnessValueText.setText("Mevcut Değil");
                })
                .setCancelable(false)
                .show();
    }

    private void setupBrightnessSlider() {
        brightnessSeekBar.setEnabled(true);
        brightnessSeekBar.setMax(255);
        try {
            // فرض أعلى سطوع تلقائياً (255)
            int maxBrightness = 255;
            Settings.System.putInt(getContentResolver(), Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
            Settings.System.putInt(getContentResolver(), Settings.System.SCREEN_BRIGHTNESS, maxBrightness);

            brightnessSeekBar.setProgress(maxBrightness);
            updateBrightnessText(maxBrightness);
        } catch (Exception e) {
            e.printStackTrace();
        }

        brightnessSeekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (fromUser) {
                    Settings.System.putInt(getContentResolver(), Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
                    Settings.System.putInt(getContentResolver(), Settings.System.SCREEN_BRIGHTNESS, progress);
                    updateBrightnessText(progress);
                }
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });
    }

    private void updateBrightnessText(int brightnessValue) {
        int percentage = (int) ((brightnessValue / 255.0) * 100);
        brightnessValueText.setText(percentage + "%");
    }

    private void checkAndRequestStoragePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                try {
                    Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
                    intent.addCategory("android.intent.category.DEFAULT");
                    intent.setData(Uri.parse(String.format("package:%s", getApplicationContext().getPackageName())));
                    startActivityForResult(intent, STORAGE_PERMISSION_REQUEST_CODE);
                } catch (Exception e) {
                    Intent intent = new Intent();
                    intent.setAction(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION);
                    startActivityForResult(intent, STORAGE_PERMISSION_REQUEST_CODE);
                }
            } else {
                saveDataToCsv();
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                        new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE},
                        STORAGE_PERMISSION_REQUEST_CODE);
            } else {
                saveDataToCsv();
            }
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        switch (requestCode) {
            case CAMERA_PERMISSION_REQUEST_CODE:
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    startCamera();
                } else {
                    Toast.makeText(this, "Kamera izni gereklidir.", Toast.LENGTH_LONG).show();
                }
                break;
            case STORAGE_PERMISSION_REQUEST_CODE:
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Toast.makeText(this, "Depolama izni verildi.", Toast.LENGTH_SHORT).show();
                    saveDataToCsv();
                } else {
                    Toast.makeText(this, "Dosyayı kaydetmek için depolama izni gereklidir.", Toast.LENGTH_LONG).show();
                }
                break;
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == STORAGE_PERMISSION_REQUEST_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                if (Environment.isExternalStorageManager()) {
                    Toast.makeText(this, "Dosya erişim izni verildi.", Toast.LENGTH_SHORT).show();
                    saveDataToCsv();
                } else {
                    Toast.makeText(this, "Kaydetmek için dosya erişim izni gereklidir.", Toast.LENGTH_LONG).show();
                }
            }
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        checkSystemWritePermission();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        cameraExecutor.shutdown();
        if (stabilizationTimer != null) stabilizationTimer.cancel();
        if (recordingTimer != null) recordingTimer.cancel();
        stopVideoRecording();
    }
}