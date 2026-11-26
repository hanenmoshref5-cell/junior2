import 'dart:math';

class SignalProcessingResult {
  final List<double> smoothed;
  final List<int> peakIndices;
  final List<int> dicroticNotches;
  final double qualityScore;

  const SignalProcessingResult({
    required this.smoothed,
    required this.peakIndices,
    required this.dicroticNotches,
    required this.qualityScore,
  });
}

class SignalProcessor {
  static List<int> _mergePeaksByDistance(
    List<int> a,
    List<int> b,
    int minDist,
  ) {
    final all = <int>[...a, ...b]..sort();
    if (all.isEmpty) return const [];
    final merged = <int>[all.first];
    for (int i = 1; i < all.length; i++) {
      if (all[i] - merged.last >= minDist) {
        merged.add(all[i]);
      }
    }
    return merged;
  }

  static List<double> _median3(List<double> signal) {
    if (signal.length < 3) return List<double>.from(signal);
    final out = List<double>.filled(signal.length, 0);
    out[0] = signal[0];
    out[signal.length - 1] = signal[signal.length - 1];
    for (int i = 1; i < signal.length - 1; i++) {
      final a = signal[i - 1];
      final b = signal[i];
      final c = signal[i + 1];
      final trio = [a, b, c]..sort();
      out[i] = trio[1];
    }
    return out;
  }

  static int _oddWindow(int wanted, int maxLen) {
    int w = wanted;
    if (w < 3) w = 3;
    if (w > maxLen) w = maxLen;
    if (w.isEven) w -= 1;
    if (w < 3) w = 3;
    return w;
  }

  static List<double> centeredMovingAverage(List<double> signal, int window) {
    if (signal.isEmpty || window <= 1) return List<double>.from(signal);
    final int w = _oddWindow(window, signal.length);
    final int half = w ~/ 2;
    final out = List<double>.filled(signal.length, 0);

    for (int i = 0; i < signal.length; i++) {
      double sum = 0;
      for (int k = -half; k <= half; k++) {
        int idx = i + k;
        if (idx < 0) idx = 0;
        if (idx >= signal.length) idx = signal.length - 1;
        sum += signal[idx];
      }
      out[i] = sum / w;
    }
    return out;
  }

  static List<double> removeDC(List<double> signal) {
    if (signal.isEmpty) return const [];
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    return signal.map((v) => v - mean).toList();
  }

  static List<double> movingAverage(List<double> signal, int window) {
    if (signal.isEmpty || window <= 1) return List<double>.from(signal);
    final int w = window.clamp(2, signal.length).toInt();
    final out = <double>[];
    double run = 0;
    for (int i = 0; i < signal.length; i++) {
      run += signal[i];
      if (i >= w) {
        run -= signal[i - w];
      }
      final size = i + 1 < w ? i + 1 : w;
      out.add(run / size);
    }
    return out;
  }

  static List<double> ema(List<double> signal, double alpha) {
    if (signal.isEmpty) return const [];
    final double a = alpha.clamp(0.01, 0.99).toDouble();
    final out = <double>[signal.first];
    for (int i = 1; i < signal.length; i++) {
      out.add(a * signal[i] + (1 - a) * out[i - 1]);
    }
    return out;
  }

  static List<double> smoothPpg(List<double> raw) {
    if (raw.length < 5) return List<double>.from(raw);

    // Preserve overall waveform (start/end and baseline) while removing spike noise.
    final med = _median3(raw);
    final centered = centeredMovingAverage(med, 7);
    final forward = ema(centered, 0.22);
    final backward = ema(forward.reversed.toList(), 0.22).reversed.toList();
    return backward;
  }

  static List<int> detectPrimaryPeaks(
    List<double> signal, {
    required int minDistance,
    double thresholdScale = 0.55,
  }) {
    if (signal.length < 8) return const [];

    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final variance =
        signal.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
        signal.length;
    final std = sqrt(variance);

    final threshold = mean + std * thresholdScale;
    final minProminence = std * 0.12;
    final peaks = <int>[];
    final int minDist = max(3, minDistance);
    int lastPeak = -minDist;

    for (int i = 2; i < signal.length - 2; i++) {
      if (i - lastPeak < minDist) continue;

      final isPeak =
          signal[i] > threshold &&
          signal[i] > signal[i - 1] &&
          signal[i] >= signal[i + 1] &&
          signal[i] > signal[i - 2] &&
          signal[i] >= signal[i + 2];

      if (isPeak) {
        final leftBase = min(signal[i - 1], signal[i - 2]);
        final rightBase = min(signal[i + 1], signal[i + 2]);
        final prominence = signal[i] - max(leftBase, rightBase);
        if (prominence < minProminence) {
          continue;
        }
        peaks.add(i);
        lastPeak = i;
      }
    }

    return peaks;
  }

  static List<int> detectDicroticNotches(List<double> signal, List<int> peaks) {
    if (peaks.length < 2 || signal.length < 10) return const [];

    final notches = <int>[];
    final derivative = <double>[];
    for (int i = 1; i < signal.length; i++) {
      derivative.add(signal[i] - signal[i - 1]);
    }

    for (int i = 0; i < peaks.length - 1; i++) {
      final p1 = peaks[i];
      final p2 = peaks[i + 1];
      final interval = p2 - p1;
      if (interval < 6) continue;

      // Dicrotic notch is usually in early-mid diastole, not very close to next beat.
      final int start = p1 + max(1, (interval * 0.10).round());
      final int end = p1 + max(2, (interval * 0.62).round());
      if (end >= signal.length || start >= end) continue;

      // Pulse amplitude for this beat (peak to valley before next peak).
      double nextValley = signal[p1];
      for (int j = p1 + 1; j <= p2; j++) {
        if (signal[j] < nextValley) {
          nextValley = signal[j];
        }
      }
      final pulseAmplitude = max(1e-6, signal[p1] - nextValley);

      int bestIdx = -1;
      double bestScore = -1e9;
      double bestDepth = 0.0;

      for (int j = max(start + 1, 2); j < min(end, signal.length - 2); j++) {
        final isLocalMin =
            signal[j] <= signal[j - 1] && signal[j] < signal[j + 1];
        final zeroCross = derivative[j - 1] < 0 && derivative[j] >= 0;
        if (!isLocalMin && !zeroCross) continue;

        final depth = signal[p1] - signal[j];
        final earlyBias = 1.0 - ((j - start) / max(1, end - start));
        final score = depth + earlyBias * (0.20 * pulseAmplitude);
        if (score > bestScore) {
          bestScore = score;
          bestDepth = depth;
          bestIdx = j;
        }
      }

      if (bestIdx == -1) continue;

      final normalizedDepth = bestDepth / pulseAmplitude;
      if (normalizedDepth >= 0.05 && normalizedDepth <= 0.82) {
        notches.add(bestIdx);
      }
    }

    return notches;
  }

  static double qualityScore(List<double> raw, List<double> smoothed) {
    if (raw.length < 10 || smoothed.length < 10) return 0.0;

    final rawMean = raw.reduce((a, b) => a + b) / raw.length;
    final noise =
        raw
            .asMap()
            .entries
            .map((e) => (e.value - smoothed[e.key]).abs())
            .reduce((a, b) => a + b) /
        raw.length;
    final amp = smoothed.reduce(max) - smoothed.reduce(min);

    if (amp <= 0) return 0.0;

    final double snrLike = (amp / (noise + 1e-6)).clamp(0.0, 30.0).toDouble();
    final double stability =
        (1 - (noise / (rawMean.abs() + 20)).clamp(0.0, 1.0)).toDouble();
    final double score = (snrLike / 30.0) * 70.0 + stability * 30.0;
    return score.clamp(0.0, 100.0).toDouble();
  }

  static SignalProcessingResult analyze(
    List<double> raw,
    double durationSeconds,
  ) {
    final smoothed = smoothPpg(raw);
    // Lighter smoothing path dedicated for dicrotic notch preservation.
    final notchSignal = ema(_median3(raw), 0.40);
    final double samplingRate = durationSeconds > 0
        ? raw.length / durationSeconds
        : 20.0;
    final int minDistance = max(4, (samplingRate * 0.32).round());

    final trend = centeredMovingAverage(
      smoothed,
      _oddWindow((samplingRate * 1.1).round(), smoothed.length),
    );
    final acSignal = <double>[];
    for (int i = 0; i < smoothed.length; i++) {
      acSignal.add(smoothed[i] - trend[i]);
    }

    final targetMin = durationSeconds > 0
        ? max(14, (durationSeconds * 0.80).round())
        : 14;
    final targetMax = durationSeconds > 0
        ? max(22, (durationSeconds * 1.10).round())
        : 22;

    double dynamicThreshold = 0.45;
    List<int> peaks = const [];
    for (int t = 0; t < 8; t++) {
      peaks = detectPrimaryPeaks(
        acSignal,
        minDistance: minDistance,
        thresholdScale: dynamicThreshold,
      );
      if (peaks.length > targetMax) {
        dynamicThreshold += 0.08;
      } else if (peaks.length < targetMin) {
        dynamicThreshold -= 0.06;
      } else {
        break;
      }
      dynamicThreshold = dynamicThreshold.clamp(0.25, 1.2).toDouble();
    }

    if (peaks.length < targetMin) {
      final secondaryPeaks = detectPrimaryPeaks(
        acSignal,
        minDistance: max(3, (minDistance * 0.85).round()),
        thresholdScale: max(0.20, dynamicThreshold - 0.10),
      );
      peaks = _mergePeaksByDistance(
        peaks,
        secondaryPeaks,
        max(3, minDistance - 1),
      );
    }

    final notches = detectDicroticNotches(notchSignal, peaks);
    final quality = qualityScore(raw, smoothed);

    return SignalProcessingResult(
      smoothed: smoothed,
      peakIndices: peaks,
      dicroticNotches: notches,
      qualityScore: quality,
    );
  }
}
