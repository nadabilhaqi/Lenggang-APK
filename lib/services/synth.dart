import 'dart:math' as math;
import 'dart:typed_data';

/// Sintesis bunyi gamelan sederhana (aditif: sinus + selubung/envelope).
///
/// Semua bunyi di Lenggang dibangkitkan dari rumus di berkas ini oleh
/// `tool/generate_sounds.dart` — bukan rekaman pihak ketiga.
class Synth {
  Synth._();

  static const int sampleRate = 22050;

  /// Satu parsial: frekuensi (Hz), amplitudo relatif, dan waktu luruh (detik,
  /// konstanta waktu eksponensial).
  static List<double> _render({
    required double seconds,
    required List<(double freq, double amp, double decay)> partials,
    double attack = 0.004,
    double noise = 0,
    double noiseDecay = 0.02,
    int seed = 7,
  }) {
    final n = (seconds * sampleRate).round();
    final out = List<double>.filled(n, 0);
    final rnd = math.Random(seed);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final a = t < attack ? t / attack : 1.0;
      var v = 0.0;
      for (final (f, amp, decay) in partials) {
        v += amp * math.exp(-t / decay) * math.sin(2 * math.pi * f * t);
      }
      if (noise > 0) {
        v += noise * math.exp(-t / noiseDecay) * (rnd.nextDouble() * 2 - 1);
      }
      out[i] = v * a;
    }
    // Pudar keluar 20 ms di ujung agar tidak ada bunyi klik.
    final fade = math.min(n, (0.02 * sampleRate).round());
    for (var i = 0; i < fade; i++) {
      out[n - 1 - i] *= i / fade;
    }
    return _normalize(out, 0.85);
  }

  static List<double> _normalize(List<double> s, double peak) {
    var m = 0.0;
    for (final v in s) {
      m = math.max(m, v.abs());
    }
    if (m == 0) return s;
    final k = peak / m;
    return [for (final v in s) v * k];
  }

  /// Ketukan dasar (bunyi "thuk" pendek seperti kethuk).
  static List<double> ketuk() => _render(
    seconds: 0.22,
    partials: const [
      (392.0, 1.0, 0.060),
      (784.0, 0.35, 0.030),
      (1176.0, 0.15, 0.015),
    ],
    noise: 0.25,
    noiseDecay: 0.006,
  );

  /// Kenong: pencon bernada tinggi, berdenging sedang.
  static List<double> kenong() => _render(
    seconds: 1.6,
    partials: const [
      (587.0, 1.0, 0.55),
      (589.5, 0.6, 0.55), // sedikit sumbang -> efek ombak/alun
      (1174.0, 0.25, 0.25),
      (1620.0, 0.18, 0.12),
      (2350.0, 0.08, 0.06),
    ],
    attack: 0.003,
    noise: 0.15,
    noiseDecay: 0.008,
  );

  /// Gong ageng: nada rendah dengan alun (beating) panjang.
  static List<double> gong() => _render(
    seconds: 4.0,
    partials: const [
      (65.0, 1.0, 1.8),
      (66.2, 0.8, 1.8), // dua nada berdekatan -> "ombak" gong
      (130.5, 0.55, 1.4),
      (196.0, 0.35, 1.0),
      (262.0, 0.18, 0.6),
      (349.0, 0.08, 0.3),
    ],
    attack: 0.02,
    noise: 0.05,
    noiseDecay: 0.03,
  );

  /// Mengemas sampel [-1, 1] menjadi berkas WAV PCM 16-bit mono.
  static Uint8List toWav(List<double> samples) {
    final dataLen = samples.length * 2;
    final b = ByteData(44 + dataLen);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        b.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little); // ukuran chunk fmt
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // mono
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    b.setUint16(32, 2, Endian.little); // block align
    b.setUint16(34, 16, Endian.little); // bit per sampel
    str(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      b.setInt16(44 + i * 2, v, Endian.little);
    }
    return b.buffer.asUint8List();
  }
}
