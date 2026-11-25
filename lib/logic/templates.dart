import 'dart:math' as math;

import '../models/pose.dart';
import '../models/project.dart';

/// Palet warna kontras tinggi untuk latar gelap.
class DancerPalette {
  DancerPalette._();

  static const int batak = 0xFFFFD54F; // kuning
  static const int gulu = 0xFF4FC3F7; // biru muda
  static const int dhadha = 0xFFF48FB1; // merah muda
  static const int buncit = 0xFFA7FFEB; // hijau mint

  /// Warna untuk penari generik (bergiliran).
  static const List<int> generic = [
    0xFFFFFFFF,
    0xFFCE93D8,
    0xFFFFCC80,
    0xFF80DEEA,
    0xFFE6EE9C,
    0xFFBCAAA4,
    0xFF90CAF9,
    0xFFF8BBD0,
  ];

  static int forIndex(int i) => generic[i % generic.length];

  static const List<int> choices = [batak, gulu, dhadha, buncit, ...generic];
}

class ProjectTemplates {
  ProjectTemplates._();

  static const int maxDancers = 12;

  /// Proyek kosong tanpa penari, satu keyframe di ketukan 1.
  static Project empty({
    required String id,
    required String title,
    required String tradition,
    required String choreographer,
    required double width,
    required double depth,
    int bpm = 60,
    DateTime? now,
  }) {
    final t = (now ?? DateTime.now()).toUtc();
    return Project(
      id: id,
      title: title,
      tradition: tradition,
      choreographer: choreographer,
      stageWidth: width,
      stageDepth: depth,
      bpm: bpm,
      cycle: CycleType.ketawang16,
      dancers: const [],
      keyframes: const {1: {}},
      createdAt: t,
      updatedAt: t,
    );
  }

  /// Preset rujukan Srimpi 4 penari: Batak, Gulu, Dhadha, Buncit.
  ///
  /// Contoh tiga gawang (dapat diubah bebas):
  /// - ketukan 1: lajur berbanjar menghadap penonton, posisi jengkeng;
  /// - ketukan 8 (kenong): belah ketupat — Batak depan, Gulu sayap kanan,
  ///   Dhadha sayap kiri, Buncit belakang — Gulu & Dhadha berhadapan;
  /// - ketukan 16 (gong ageng): segi empat, semua menghadap penonton.
  static Project srimpi({
    required String id,
    required String title,
    required String tradition,
    required String choreographer,
    required double width,
    required double depth,
    int bpm = 60,
    DateTime? now,
  }) {
    final base = empty(
      id: id,
      title: title,
      tradition: tradition,
      choreographer: choreographer,
      width: width,
      depth: depth,
      bpm: bpm,
      now: now,
    );
    const dancers = [
      Dancer(id: 'batak', role: 'Batak', color: DancerPalette.batak),
      Dancer(id: 'gulu', role: 'Gulu', color: DancerPalette.gulu),
      Dancer(id: 'dhadha', role: 'Dhadha', color: DancerPalette.dhadha),
      Dancer(id: 'buncit', role: 'Buncit', color: DancerPalette.buncit),
    ];
    final cx = width / 2;
    final cy = depth / 2;
    // Pola dirancang di panggung rujukan 8 × 6 m lalu direnggangkan sebanding
    // dengan ukuran panggung yang dipilih; batas bawah menjaga jarak antar
    // penari tetap di atas ambang aman pada panggung kecil.
    final kx = math.max(width / 8.0, 0.65);
    final ky = math.max(depth / 6.0, 0.9);

    DancerState at(
      double dx,
      double dy, {
      double facing = 0,
      Pose pose = Pose.ngadeg,
    }) => DancerState(
      x: _clamp(cx + dx * kx, width),
      y: _clamp(cy + dy * ky, depth),
      facing: facing,
      pose: pose,
    );

    final keyframes = <int, Map<String, DancerState>>{
      1: {
        'batak': at(0, -1.5, pose: Pose.jengkeng),
        'gulu': at(0, -0.5, pose: Pose.jengkeng),
        'dhadha': at(0, 0.5, pose: Pose.jengkeng),
        'buncit': at(0, 1.5, pose: Pose.jengkeng),
      },
      8: {
        'batak': at(0, -1.4, pose: Pose.mendhak),
        'gulu': at(1.4, 0, facing: 270, pose: Pose.mendhak),
        'dhadha': at(-1.4, 0, facing: 90, pose: Pose.mendhak),
        'buncit': at(0, 1.4, pose: Pose.mendhak),
      },
      16: {
        'batak': at(-0.7, -0.7, pose: Pose.ngadeg),
        'gulu': at(0.7, -0.7, pose: Pose.ngadeg),
        'dhadha': at(-0.7, 0.7, pose: Pose.ngadeg),
        'buncit': at(0.7, 0.7, pose: Pose.ngadeg),
      },
    };
    return base.copyWith(dancers: dancers, keyframes: keyframes);
  }

  static double _clamp(double v, double max) {
    final r = v.clamp(0.0, max);
    return (r * 100).roundToDouble() / 100;
  }
}
