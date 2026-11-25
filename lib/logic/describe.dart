import '../models/project.dart';
import 'timeline.dart';

/// Menerjemahkan angka (meter, derajat) ke bahasa yang dipakai penari.
class Describe {
  Describe._();

  /// Letak di panggung dalam sembilan wilayah, mis. "depan kiri", "tengah",
  /// "belakang kanan". Kiri–kanan dilihat dari penonton.
  static String position(double x, double y, double width, double depth) {
    final col = _third(x / width);
    final row = _third(y / depth);
    final rowWord = const ['depan', 'tengah', 'belakang'][row];
    final colWord = const ['kiri', 'tengah', 'kanan'][col];
    if (row == 1 && col == 1) return 'tengah';
    if (col == 1) return '$rowWord tengah';
    if (row == 1) return 'tengah $colWord';
    return '$rowWord $colWord';
  }

  static int _third(double f) => f < 1 / 3
      ? 0
      : f <= 2 / 3
      ? 1
      : 2;

  /// Arah hadap dalam kata, dibulatkan ke 8 arah.
  static String facing(double deg) {
    final i = (Timeline.normalizeAngle(deg) / 45).round() % 8;
    return const [
      'menghadap penonton',
      'serong kanan depan',
      'menghadap kanan',
      'serong kanan belakang',
      'membelakangi penonton',
      'serong kiri belakang',
      'menghadap kiri',
      'serong kiri depan',
    ][i];
  }

  /// Ringkasan satu penari, mis. "depan tengah · menghadap penonton".
  static String dancer(DancerState s, Project p) =>
      '${position(s.x, s.y, p.stageWidth, p.stageDepth)} · ${facing(s.facing)}';
}
