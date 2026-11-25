import 'dart:math' as math;

import '../models/pose.dart';
import '../models/project.dart';

/// Logika linimasa siklus gongan.
///
/// Posisi playhead dinyatakan dalam "ketukan kontinu" `p` di rentang
/// `[1, beats + 1)`: ketukan ke-n menempati `[n, n + 1)`. Saat berhenti,
/// playhead berada tepat di bilangan bulat.
class Timeline {
  Timeline._();

  /// Ketukan (1..beats) yang sedang berbunyi pada playhead [p].
  static int beatAt(double p, int beats) => (p.floor() - 1) % beats + 1;

  /// Membungkus playhead agar tetap di `[1, beats + 1)` (modulo siklus).
  static double wrap(double p, int beats) {
    final v = (p - 1) % beats;
    return v + 1;
  }

  /// Keadaan semua penari pada playhead [p] dengan interpolasi linear antar
  /// keyframe. Semua penari berangkat dari keyframe yang sama dan tiba di
  /// keyframe berikutnya pada saat yang sama ("berangkat bersama, sampai
  /// bersama"). Sebelum keyframe pertama dan sesudah keyframe terakhir,
  /// formasi ditahan.
  static Map<String, DancerState> stateAt(Project project, double p) {
    final beats = project.keyframeBeats;
    final result = <String, DancerState>{};
    if (beats.isEmpty) return result;

    int? prev;
    int? next;
    for (final b in beats) {
      if (b <= p) {
        prev = b;
      } else {
        next = b;
        break;
      }
    }

    if (prev == null) {
      return Map.of(project.keyframes[next]!);
    }
    final a = project.keyframes[prev]!;
    if (next == null || p == prev) {
      return Map.of(a);
    }
    final b = project.keyframes[next]!;
    final t = ((p - prev) / (next - prev)).clamp(0.0, 1.0);

    for (final d in project.dancers) {
      final sa = a[d.id];
      final sb = b[d.id];
      if (sa == null && sb == null) continue;
      if (sa == null || sb == null) {
        result[d.id] = (sa ?? sb)!;
        continue;
      }
      result[d.id] = lerpState(sa, sb, t);
    }
    return result;
  }

  static DancerState lerpState(DancerState a, DancerState b, double t) =>
      DancerState(
        x: a.x + (b.x - a.x) * t,
        y: a.y + (b.y - a.y) * t,
        facing: lerpAngle(a.facing, b.facing, t),
        pose: t < 0.5 ? a.pose : b.pose,
      );

  /// Interpolasi sudut lewat busur terpendek, hasil di [0, 360).
  static double lerpAngle(double a, double b, double t) {
    var d = (b - a) % 360;
    if (d > 180) d -= 360;
    return normalizeAngle(a + d * t);
  }

  static double normalizeAngle(double deg) {
    final v = deg % 360;
    return v < 0 ? v + 360 : v;
  }

  /// Membulatkan sudut ke kelipatan 45° terdekat.
  static double snap45(double deg) => normalizeAngle((deg / 45).round() * 45.0);

  /// Tinggi kepala (m) yang diinterpolasi antar keyframe, untuk sightline.
  static double headHeightAt(
    Project project,
    double p,
    String dancerId,
    double Function(Pose) heightOf,
  ) {
    final beats = project.keyframeBeats;
    int? prev;
    int? next;
    for (final b in beats) {
      if (b <= p) {
        prev = b;
      } else {
        next = b;
        break;
      }
    }
    final ka = prev == null ? null : project.keyframes[prev]?[dancerId];
    final kb = next == null ? null : project.keyframes[next]?[dancerId];
    if (ka == null && kb == null) return heightOf(Pose.ngadeg);
    if (ka == null || kb == null || prev == null || next == null) {
      return heightOf((ka ?? kb)!.pose);
    }
    final t = ((p - prev) / (next - prev)).clamp(0.0, 1.0);
    final ha = heightOf(ka.pose);
    final hb = heightOf(kb.pose);
    // Perubahan level tubuh diperhalus dengan kurva smoothstep.
    final s = t * t * (3 - 2 * t);
    return ha + (hb - ha) * s;
  }

  /// Durasi satu ketukan dalam detik.
  static double secondsPerBeat(int bpm) => 60 / math.max(1, bpm);
}
