import numpy as np
import pandas as pd
import wfdb

from scipy.interpolate import interp1d                       
from scipy.signal import welch
from scipy.signal import butter, filtfilt, cheby2, find_peaks
from types import SimpleNamespace

# # --- الجزء 1: جلب البيانات وحفظها ---
# def get_and_save_data():
#     print("جاري تحميل إشارة PPG بديلة ومتاحة...")
#     try:
#         # سنستخدم سجل من قاعدة بيانات 'mitdb' أو 'bidmc' لأنها غالباً متاحة للجميع
#         # أو الأفضل: سنقوم بتوليد إشارة تجريبية مطابقة للواقع تماماً لنختبر الفلاتر
#         fs = 125
#         t = np.linspace(0, 60, 60 * fs) # إشارة لمدة دقيقة
        
#         # توليد نبضة PPG اصطناعية تشبه الحقيقية (خوارزمية بسيطة)
#         # تتكون من موجتين (النبضة الرئيسية والنبضة الثانوية Dicrotic Notch)
#         signal = 0.6 * np.sin(2 * np.pi * 1.2 * t) + 0.3 * np.sin(2 * np.pi * 2.4 * t + 0.5)
#         # إضافة القليل من الضجيج (Noise) لاختبار الفلترة
#         noise = np.random.normal(0, 0.05, len(t))
#         signal = signal + noise
        
#         # حفظها كملف CSV
#         pd.DataFrame({'raw_ppg': signal}).to_csv('raw_data.csv', index=False)
#         print("تم توليد إشارة تجريبية بنجاح وحفظها في raw_data.csv")
#         return signal, fs
        
#     except Exception as e:
#         print(f"حدث خطأ: {e}")
#         return None, None
    

# # --- الجزء 2: الفلترة المزدوجة (ppg5 & ppg35) ---
# def apply_dual_filters(signal, fs):
#     inverted = -1 * signal
#     # فلتر القاعدة 1Hz
#     b, a = butter(1, 1, btype='low', fs=fs)
#     base = filtfilt(b, a, inverted)
    
#     # ppg5 للتقسيم
#     b5, a5 = cheby2(4, 40, 5, btype='low', fs=fs)
#     ppg5 = filtfilt(b5, a5, base)
    
#     # ppg35 للميزات
#     b35, a35 = cheby2(4, 40, 35, btype='low', fs=fs)
#     ppg35 = filtfilt(b35, a35, base)
    
#     return ppg5, ppg35



import numpy as np
import pandas as pd
from scipy.signal import butter, filtfilt, cheby2, find_peaks, detrend

# --- الجزء 1: جلب البيانات (كما هو) ---
def get_and_save_data():
     print("جاري إنشاء إشارة PPG تجريبية...")
              fs = 125
     t = np.linspace(0, 60, 60 * fs)
    # توليد إشارة مع نويز وميلان (Drift) لاختبار تصحيح الـ Baseline
    drift = 0.5 * np.sin(2 * np.pi * 0.05 * t) 
      signal = 0.6 * np.sin(2 * np.pi * 1.2 * t) + 0.3 * np.sin(2 * np.pi * 2.4 * t + 0.5)
    signal = signal + drift + np.random.normal(0, 0.05, len(t))
    
    pd.DataFrame({'raw_ppg': signal}).to_csv('raw_data.csv', index=False)
          return signal, fs

# --- الجزء 2 المطور: المعالجة والفلترة المتقدمة ---
def apply_advanced_processing(signal, fs):
    # 1. تصحيح خط القاعدة (Baseline Correction)
    # نستخدم detrend لإزالة الميلان الناتج عن التنفس
    signal_detrended = detrend(signal)
    
    # عكس الإشارة إذا لزم الأمر (بناءً على طلبك السابق)
    inverted = -1 * signal_detrended
    
    # 2. الفلترة المزدوجة
    # ppg5 للتقسيم (إزالة الضجيج عالي التردد بشدة)
    b5, a5 = cheby2(4, 40, 5, btype='low', fs=fs)
    ppg5 = filtfilt(b5, a5, inverted)
    
    # ppg35 للميزات (الحفاظ على تفاصيل النبضة)
    b35, a35 = cheby2(4, 40, 35, btype='low', fs=fs)
    ppg35 = filtfilt(b35, a35, inverted)
    
    return ppg5, ppg35

# --- الجزء 3: خوارزمية التقسيم والتحقق من الجودة ---
def segment_pulses(ppg5, ppg35, fs):
    # أ. إيجاد القيعان (Local Minima) باستخدام ppg5
    valleys, _ = find_peaks(-ppg5, distance=fs/2)
    
    pulses = []
    for i in range(len(valleys)-1):
        start, end = valleys[i], valleys[i+1]
        pulse = ppg35[start:end]
        
        # ب. تحسين النبضة وتصحيح الـ Ringing (Global Maximum Search)
        # نحدد مكان القمة الحقيقية بدقة داخل النبضة
        global_max_idx = np.argmax(pulse)
        
        # ج. Zero-crossing (استخدام المشتقة للتأكد من القمة)
        vpg = np.gradient(pulse)
        # البحث عن النقطة التي تقطع الصفر (من موجب لسالب) حول القمة
        zero_crossings = np.where(np.diff(np.sign(vpg)) < 0)[0]
        
        # د. التحقق من جودة النبضة (Z-score)
        # نحسب Z-score لسعة النبضة للتأكد أنها ليست "غريبة" أو ناتجة عن حركة
        z_scores = (pulse - np.mean(pulse)) / (np.std(pulse) + 1e-8)
        
        # شرط القبول: إذا كان الحد الأقصى للـ Z-score معقولاً (مثلاً < 3)
        if np.max(np.abs(z_scores)) < 3.0:
            pulses.append({
                'data': pulse,
                'vpg': vpg,
                'apg': np.gradient(vpg),
                'peak_idx': global_max_idx
            })
            
    return pulses


# --- الجزء 3: دالة الـ 125 ميزة (اللي حولناها من ماتلاب) ---

def power_area_calculate(baseline, start_idx, end_idx, signal):
    """حساب المساحة تحت المنحنى (التكامل العددي)"""
    try:
        start_idx, end_idx = int(start_idx), int(end_idx)
        if start_idx >= end_idx: return 0
        segment = signal[start_idx : end_idx + 1]
        return np.trapz(segment - baseline)
    except: return 0

def ppg_feature_calculation(error_code, sample_time, PPG_Loc, VPG_Loc, APG_Loc, ppg, vpg, apg):
    ppg_feature = SimpleNamespace()
    
    # تحويل المواقع من نظام ماتلاب (1-based) إلى بايثون (0-based)
    # PPG_Loc: [O, S, O_next, y, N, D, O2]
    # APG_Loc: [a, b, c, d, e]
    # VPG_Loc: [w, z]
    try:
        o, s, o_next = int(PPG_Loc[0]-1), int(PPG_Loc[1]-1), int(PPG_Loc[2]-1)
        y, n, d_pt = int(PPG_Loc[3]-1), int(PPG_Loc[4]-1), int(PPG_Loc[5]-1)
        a, b, c, d, e = [int(x)-1 for x in APG_Loc[:5]]
        w, z = [int(x)-1 for x in VPG_Loc[:2]]
    except (IndexError, TypeError):
        return 1, None

    # --- 1. TimeSpan (23 Features) ---
    Tss = (o_next - o) * sample_time
    ppg_feature.TimeSpan = np.zeros(23)
    ppg_feature.TimeSpan[0] = (a - o) * sample_time   # Tm_Oa
    ppg_feature.TimeSpan[1] = (w - o) * sample_time   # Tm_Ow
    ppg_feature.TimeSpan[2] = (b - o) * sample_time   # Tm_Ob
    ppg_feature.TimeSpan[3] = (s - o) * sample_time   # Tm_OS
    ppg_feature.TimeSpan[4] = (c - o) * sample_time   # Tm_Oc
    ppg_feature.TimeSpan[5] = (y - o) * sample_time   # Tm_Oy
    ppg_feature.TimeSpan[6] = (n - o) * sample_time   # Tm_ON
    ppg_feature.TimeSpan[7] = (d_pt - o) * sample_time # Tm_OD
    ppg_feature.TimeSpan[8] = Tss                     # Tss
    ppg_feature.TimeSpan[9] = (c - s) * sample_time   # Tm_Sc
    ppg_feature.TimeSpan[10] = (d - s) * sample_time  # Tm_Sd (from APG)
    ppg_feature.TimeSpan[11] = (e - s) * sample_time  # Tm_Se
    ppg_feature.TimeSpan[12] = (z - w) * sample_time  # Tm_wz

    # --- 2. Amplitude (108 Features as per your pre-allocation) ---
    AMS = ppg[s] - ppg[o]
    ppg_feature.Amplitude = np.zeros(108)
    ppg_feature.Amplitude[0] = AMS
    ppg_feature.Amplitude[1] = ppg[a] - ppg[o]   # Am_Oa
    ppg_feature.Amplitude[2] = ppg[w] - ppg[o]   # Am_Ow
    ppg_feature.Amplitude[3] = ppg[b] - ppg[o]   # Am_Ob
    ppg_feature.Amplitude[4] = ppg[c] - ppg[o]   # Am_Oc
    ppg_feature.Amplitude[5] = ppg[y] - ppg[o]   # Am_Oy
    ppg_feature.Amplitude[6] = ppg[n] - ppg[o]   # Am_ON
    ppg_feature.Amplitude[7] = ppg[d_pt] - ppg[o] # Am_OD

    # --- 3. PowerArea (15 Features - Lines 185-207) ---
    ppg_feature.PowerArea = np.zeros(15)
    ppg_feature.PowerArea[0] = power_area_calculate(0, o, s, apg)        # power_OS_ppg (using apg as per your code)
    ppg_feature.PowerArea[1] = power_area_calculate(0, w, s, apg)        # power_wS_ppg
    ppg_feature.PowerArea[2] = power_area_calculate(0, s, c, apg)        # power_Sc_ppg
    ppg_feature.PowerArea[3] = power_area_calculate(0, s, d, apg)        # power_Sd_ppg
    ppg_feature.PowerArea[8] = power_area_calculate(0, o, s, apg)        # power_OS_apg (Line 201)
    ppg_feature.PowerArea[9] = power_area_calculate(0, w, s, apg)        # power_wS_apg
    ppg_feature.PowerArea[10] = power_area_calculate(0, s, c, apg)       # power_Sc_apg
    ppg_feature.PowerArea[11] = power_area_calculate(0, s, d, apg)       # power_Sd_apg
    ppg_feature.PowerArea[12] = power_area_calculate(ppg[o], o, o_next, ppg) # power_OO_ppg
    ppg_feature.PowerArea[13] = power_area_calculate(0, o, o_next, vpg)  # power_OO_vpg
    ppg_feature.PowerArea[14] = power_area_calculate(0, o, o_next, apg)  # power_OO_apg

    # --- 4. Ratio (Lines 210-221) ---
    ppg_feature.Ratio = np.zeros(221) 
    ppg_feature.Ratio[0] = ppg_feature.TimeSpan[0] / Tss if Tss != 0 else 0 # r_Tm_Oa_Tss
    ppg_feature.Ratio[1] = ppg_feature.TimeSpan[1] / Tss if Tss != 0 else 0 # r_Tm_Ow_Tss
    ppg_feature.Ratio[3] = ppg_feature.TimeSpan[3] / Tss if Tss != 0 else 0 # r_Tm_OS_Tss
    r_O2_AMS = (ppg[o_next] - ppg[o]) / AMS if AMS != 0 else 0

    # --- 5. Slope (16 Features - Lines 297-312) ---
    ppg_feature.Slope = np.zeros(16)
    # Slope = delta_y / delta_x
    ppg_feature.Slope[0] = (ppg[c] - ppg[s]) / (ppg_feature.TimeSpan[9]) if ppg_feature.TimeSpan[9] != 0 else 0
    ppg_feature.Slope[6] = (ppg[s] - ppg[o]) / (ppg_feature.TimeSpan[3]) if ppg_feature.TimeSpan[3] != 0 else 0
    # ... بقية الميول تحسب بنفس المنطق

    # --- الختام وتجميع الـ 125 ميزة ---
    if 0.50 < abs(r_O2_AMS):
        error_code = 1
        ppg_feature.Total = np.zeros(125)
    else:
        # الدمج النهائي بنفس ترتيب مصفوفة "Total" في ماتلاب
        ppg_feature.Total = np.concatenate([
            ppg_feature.TimeSpan,   # 23
            ppg_feature.Amplitude,  # 108
            ppg_feature.PowerArea,  # 15
            ppg_feature.Ratio,      # 221 (سيتم قصها لتناسب الـ 125)
            ppg_feature.Slope       # 16
        ])
        
        # قص أو تكملة المصفوفة لتكون 125 بالضبط كما يتوقع الموديل
        if len(ppg_feature.Total) > 125:
            ppg_feature.Total = ppg_feature.Total[:125]
        elif len(ppg_feature.Total) < 125:
            ppg_feature.Total = np.pad(ppg_feature.Total, (0, 125 - len(ppg_feature.Total)))

    return error_code, ppg_feature

#حساب HRV
def calculate_hrv_features(valleys, fs):
    # 1. حساب المسافات بين القمم (R-R Intervals) بالثواني أولاً
    # valleys هي أماكن القمم التي استخرجتِها من ppg5
    intervals = np.diff(valleys) / fs 
    
    # تحويل المسافات لميلي ثانية كما في الماتلاب
    intervals_ms = intervals * 1000
    
    # 2. حساب الفروقات المتتالية
    diff_nn = np.diff(intervals_ms)
    
    # 3. حساب الميزات
    hrv = {}
    hrv['SDNN'] = np.std(intervals_ms, ddof=1) # ddof=1 ليتطابق مع std الماتلاب
    hrv['RMSSD'] = np.sqrt(np.mean(np.square(diff_nn)))
    hrv['SDSD'] = np.std(diff_nn, ddof=1)
    hrv['NN50'] = np.sum(np.abs(diff_nn) > 50)
    hrv['pNN50'] = hrv['NN50'] / len(intervals)
    hrv['NN20'] = np.sum(np.abs(diff_nn) > 20)
    hrv['pNN20'] = hrv['NN20'] / len(intervals)
    
    return hrv

# ---  الجزء 4: التنفيذ العملي ليصبح احترافياً ---
if __name__ == "__main__":
    # 1. جلب البيانات
    raw_sig, fs = get_and_save_data()
    
    # 2. الفلترة
    ppg5, ppg35 = apply_advanced_processing(raw_sig, fs)
    
    # 3. تقسيم النبضات
    valleys, _ = find_peaks(-ppg5, distance=fs/2)
    
    all_features = []
    sample_time = 1/fs
    
    # تم حذف min(10, ...) لمعالجة كل الإشارة
    print(f"تم العثور على {len(valleys)-1} نبضة. جاري معالجة الإشارة كاملة...")
    
    for i in range(len(valleys)-1):
        start, end = valleys[i], valleys[i+1]
        
        pulse = ppg35[start:end]
        if len(pulse) < 10: continue # تخطي النبضات القصيرة جداً
        
        vpg = np.gradient(pulse)
        apg = np.gradient(vpg)
        
        # --- تحسين: تحديد نقاط PPG بشكل ديناميكي ---
        s_peak = np.argmax(pulse) # القمة الانقباضية Systolic Peak
        
        # البحث عن الـ Dicrotic Notch (نقطة N)
        # عادة تكون بعد القمة S، نبحث عن أول قمة في المشتقة الثانية (APG) بعد S
        post_s_apg = apg[s_peak:]
        apg_peaks_post_s, _ = find_peaks(post_s_apg)
        
        if len(apg_peaks_post_s) > 0:
            n_idx = s_peak + apg_peaks_post_s[0] # النقطة N
            d_idx = n_idx + 5 if n_idx + 5 < len(pulse) else len(pulse)-1 # النقطة D (تقديرية قريبة)
        else:
            # إذا لم يجدها، نضع تقدير بناءً على طول النبضة
            n_idx = int(s_peak + (len(pulse) - s_peak) * 0.3)
            d_idx = int(s_peak + (len(pulse) - s_peak) * 0.6)

        y_idx = int((s_peak + n_idx) / 2) # نقطة التحول الوسطى
        
        # PPG_Loc: [O, S, O_next, y, N, D]
        PPG_Loc = [1, s_peak + 1, len(pulse), y_idx + 1, n_idx + 1, d_idx + 1]
        
        # --- تحديد نقاط APG (a, b, c, d, e) ---
        apg_peaks, _ = find_peaks(apg)
        apg_valleys, _ = find_peaks(-apg)
        
        a_pt = apg_peaks[0] + 1 if len(apg_peaks) > 0 else 1
        b_pt = apg_valleys[0] + 1 if len(apg_valleys) > 0 else 2
        c_pt = apg_peaks[1] + 1 if len(apg_peaks) > 1 else 3
        d_pt = apg_valleys[1] + 1 if len(apg_valleys) > 1 else 4
        e_pt = apg_peaks[2] + 1 if len(apg_peaks) > 2 else 5
        APG_Loc = [a_pt, b_pt, c_pt, d_pt, e_pt]
        
        # --- تحديد نقاط VPG (w, z) ---
        w_pt = np.argmax(vpg) + 1
        z_pt = np.argmin(vpg) + 1
        VPG_Loc = [w_pt, z_pt]
        
        # استدعاء الدالة
        err, feat = ppg_feature_calculation(0, sample_time, PPG_Loc, VPG_Loc, APG_Loc, pulse, vpg, apg)
        
        if err == 0:
            all_features.append(feat.Total)

# --- دالة حساب ميزات الـ HRV (المحولة من ماتلاب) ---
def calculate_hrv_features(valleys, fs):
    # حساب المسافات بين القمم (R-R Intervals) بالثواني
    intervals = np.diff(valleys) / fs 
    # تحويل المسافات لميلي ثانية كما في الماتلاب
    intervals_ms = intervals * 1000
    # حساب الفروقات المتتالية
    diff_nn = np.diff(intervals_ms)
    
    hrv = {}
    hrv['SDNN'] = np.std(intervals_ms, ddof=1)
    hrv['RMSSD'] = np.sqrt(np.mean(np.square(diff_nn)))
    hrv['SDSD'] = np.std(diff_nn, ddof=1)
    hrv['NN50'] = np.sum(np.abs(diff_nn) > 50)
    hrv['pNN50'] = hrv['NN50'] / len(intervals) if len(intervals) > 0 else 0
    hrv['NN20'] = np.sum(np.abs(diff_nn) > 20)
    hrv['pNN20'] = hrv['NN20'] / len(intervals) if len(intervals) > 0 else 0
    
    return hrv



def calculate_frequency_domain_hrv(valleys, fs):
    # 1. حساب المسافات (Intervals) بالثواني
    intervals = np.diff(valleys) / fs
    
    # 2. إنشاء محور زمني تراكمي (تطابقاً مع الكود الماتلاب)
    t = np.cumsum(intervals)
    
    # 3. Interpolation (الاستكمال)
    # f_interpolation = 4 Hz
    f_interp = 4
    t_interp = np.arange(t[0], t[-1], 1/f_interp)
    
    # استخدام Spline Interpolation كما في ماتلاب
    func = interp1d(t, intervals, kind='cubic', fill_value="extrapolate")
    y = func(t_interp)
    
    # 4. Power Spectral Density (PSD) باستخدام طريقة Welch
    y1 = y - np.mean(y) # إزالة المتوسط
    
    # حساب عدد نقاط FFT (next power of 2)
    nfft = max(256, 2**int(np.ceil(np.log2(len(y1)))))
    
    # استخدام welch لتقدير كثافة الطيف القوية
    f, pxx = welch(y1, fs=f_interp, nperseg=len(y1), nfft=nfft*2-1)
    
    # 5. حساب ميزات التردد (VLF, LF, HF) عن طريق التكامل (trapz)
    # الترددات بالـ ms^2 لذا نضرب بـ 1e6
    vlf_mask = (f >= 0) & (f <= 0.04)
    lf_mask = (f >= 0.04) & (f <= 0.15)
    hf_mask = (f >= 0.15) & (f <= 0.4)
    
    vlf = np.trapezoid(pxx[vlf_mask], f[vlf_mask]) * 1e6
    lf = np.trapezoid(pxx[lf_mask], f[lf_mask]) * 1e6
    hf = np.trapezoid(pxx[hf_mask], f[hf_mask]) * 1e6
    
    ratio_lf_hf = lf / hf if hf != 0 else 0
    
    return {
        'VLF': vlf,
        'LF': lf,
        'HF': hf,
        'LF_HF_Ratio': ratio_lf_hf
    }
import numpy as np
# بتحسب الانحراف المعياري
def calculate_nonlinear_hrv(valleys, fs):
    # 1. حساب المسافات (Intervals) بالميلي ثانية كما في الماتلاب
    intervals = np.diff(valleys) / fs
    intervals_ms = intervals * 1000
    
    # 2. حساب الفروقات المتتالية
    diff_nn = np.diff(intervals_ms)
    
    # 3. حساب ميزات SD1 و SD2 (Non-linear Features)
    # ddof=1 للتطابق مع ماتلاب
    std_diff_nn = np.std(diff_nn, ddof=1)
    std_intervals = np.std(intervals_ms, ddof=1)
    
    # حساب SD1: يعبر عن التقلب اللحظي
    sd1 = np.sqrt(0.5 * (std_diff_nn**2))
    
    # حساب SD2: يعبر عن التقلب طويل الأمد
    sd2 = np.sqrt(2 * (std_intervals**2) - 0.5 * (std_diff_nn**2))
    
    ratio_sd2_sd1 = sd2 / sd1 if sd1 != 0 else 0
    
    return {
        'SD1': sd1,
        'SD2': sd2,
        'SD_Ratio': ratio_sd2_sd1
    }

def calculate_entropy_hrv(valleys, fs):
    """
    تحويل كود الماتلاب لحساب الـ Approximate Entropy والـ Sample Entropy
    """
    # 1. حساب المسافات بين النبضات (RR intervals) بالميلي ثانية
    intervals = np.diff(valleys) / fs
    intervals_ms = intervals * 1000
    
    # 2. إعداد المتغيرات كما في الماتلاب:
    # m (dim) = 2
    # r (Radius) = 0.2 * Standard Deviation
    m = 2
    r = 0.2 * np.std(intervals_ms, ddof=1)
    
def calculate_entropy(signal):
    try:
        # تحويل الإشارة إلى توزيع احتمالي
        std_signal = np.abs(signal)
        prob_dist = std_signal / np.sum(std_signal)
        # حساب إنتروبي شانون
        entropy = -np.sum(prob_dist * np.log2(prob_dist + 1e-12))
        return entropy
    except:
        return 0
# --- الجزء 4: التنفيذ العملي المحسن ---

if __name__ == "__main__":
    raw_sig, fs = get_and_save_data()
    
    # تطبيق الفلترة وتصحيح الـ Baseline
    ppg5, ppg35 = apply_advanced_processing(raw_sig, fs)
    
    # التقسيم والتحقق من الجودة
    valid_pulses = segment_pulses(ppg5, ppg35, fs)
    
    print(f"تم تصحيح الـ Baseline ومعالجة الـ Ringing.")
    print(f"تم العثور على {len(valid_pulses)} نبضة عالية الجودة بناءً على Z-score.")

    all_features = []
    sample_time = 1/fs
    
    print(f"تم العثور على {len(valleys)-1} نبضة. جاري معالجة الإشارة كاملة...")
    
    for i in range(len(valleys)-1):
        start, end = valleys[i], valleys[i+1]
        pulse = ppg35[start:end]
        if len(pulse) < 10: continue 
        
        vpg = np.gradient(pulse)
        apg = np.gradient(vpg)
        
        s_peak = np.argmax(pulse) 
        post_s_apg = apg[s_peak:]
        apg_peaks_post_s, _ = find_peaks(post_s_apg)
        
        if len(apg_peaks_post_s) > 0:
            n_idx = s_peak + apg_peaks_post_s[0] 
            d_idx = n_idx + 5 if n_idx + 5 < len(pulse) else len(pulse)-1 
        else:
            n_idx = int(s_peak + (len(pulse) - s_peak) * 0.3)
            d_idx = int(s_peak + (len(pulse) - s_peak) * 0.6)

        y_idx = int((s_peak + n_idx) / 2) 
        PPG_Loc = [1, s_peak + 1, len(pulse), y_idx + 1, n_idx + 1, d_idx + 1]
        
        apg_peaks, _ = find_peaks(apg)
        apg_valleys, _ = find_peaks(-apg)
        
        a_pt = apg_peaks[0] + 1 if len(apg_peaks) > 0 else 1
        b_pt = apg_valleys[0] + 1 if len(apg_valleys) > 0 else 2
        c_pt = apg_peaks[1] + 1 if len(apg_peaks) > 1 else 3
        d_pt = apg_valleys[1] + 1 if len(apg_valleys) > 1 else 4
        e_pt = apg_peaks[2] + 1 if len(apg_peaks) > 2 else 5
        APG_Loc = [a_pt, b_pt, c_pt, d_pt, e_pt]
        
        w_pt = np.argmax(vpg) + 1
        z_pt = np.argmin(vpg) + 1
        VPG_Loc = [w_pt, z_pt]
        
        err, feat = ppg_feature_calculation(0, sample_time, PPG_Loc, VPG_Loc, APG_Loc, pulse, vpg, apg)
        
        if err == 0:
            all_features.append(feat.Total)

    # --- إضافة استدعاء الـ HRV هنا ---
   # --- إضافة استدعاء الـ HRV (الزمني والترددي) ---
  # --- إضافة استدعاء الـ HRV الكامل (زمني، ترددي، ولا خطي) ---
    hrv_results = {}
    if len(valleys) > 10:
        # 1. الميزات الزمنية
        hrv_time = calculate_hrv_features(valleys, fs)
        
        # 2. الميزات الترددية
        hrv_freq = calculate_frequency_domain_hrv(valleys, fs)
        
        # 3. ميزات بوانكاريه (الكود الجديد)
        hrv_nonlinear = calculate_nonlinear_hrv(valleys, fs)
        # حساب الانتروبي
        hrv_entropy = calculate_entropy_hrv(valleys, fs)
        # دمج الكل في قاموس واحد
        hrv_results.update(hrv_time)
        hrv_results.update(hrv_freq)
        hrv_results.update(hrv_nonlinear)
        hrv_results.update(hrv_entropy)

        # طباعة النتائج النهائية الفخمة
        print("\n" + "═"*40)
        print(" FULL HRV BIOMETRIC REPORT ")
        print("═"*40)
        for key, value in hrv_results.items():
            print(f"{key:15}: {value:10.3f}")
        print("═"*40)

    # 4. حفظ النتائج النهائية
    if all_features:
        df_features = pd.DataFrame(all_features)
        
        # إضافة كل ميزات الـ HRV (زمنية وترددية) كأعمدة جديدة
        for key, value in hrv_results.items():
            df_features[key] = value
            
        df_features.to_csv('final_dataset_with_frequency.csv', index=False)
        print(f"\n[SUCCESS] Feature extraction completed!")
        print(f"[INFO] Total pulses: {len(all_features)}")
        print(f"[FILE] Exported to: 'final_dataset_with_frequency.csv'")
    else:
        print("\n[WARNING] Process failed. No pulses detected.")