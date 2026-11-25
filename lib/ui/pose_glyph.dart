import 'package:material_ui/material_ui.dart';

import '../models/pose.dart';

/// Gambar sosok kecil (tampak samping) untuk tiap level pose, supaya nama
/// pose langsung terbayang: berdiri, merendah, berlutut satu kaki, bersimpuh,
/// dan bersila. Tinggi sosok mengikuti tinggi posenya.
class PoseGlyph extends StatelessWidget {
  const PoseGlyph({
    super.key,
    required this.pose,
    required this.color,
    this.size = 28,
  });

  final Pose pose;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _PoseGlyphPainter(pose, color),
  );

  /// Kepala (pusat) dan garis-garis badan dalam kotak satuan; y ke bawah,
  /// lantai di y = 1.
  static (Offset, List<List<Offset>>) _shape(Pose pose) => switch (pose) {
    Pose.ngadeg => (
      const Offset(0.50, 0.10),
      const [
        [Offset(0.50, 0.22), Offset(0.50, 0.58), Offset(0.50, 0.96)],
        [Offset(0.50, 0.30), Offset(0.66, 0.52)],
      ],
    ),
    Pose.mendhak => (
      const Offset(0.46, 0.24),
      const [
        [
          Offset(0.46, 0.36),
          Offset(0.44, 0.64),
          Offset(0.66, 0.78),
          Offset(0.54, 0.96),
        ],
        [Offset(0.46, 0.44), Offset(0.66, 0.58)],
      ],
    ),
    Pose.jengkeng => (
      const Offset(0.46, 0.38),
      const [
        // Badan + kaki depan menekuk tegak.
        [
          Offset(0.46, 0.50),
          Offset(0.46, 0.76),
          Offset(0.74, 0.76),
          Offset(0.74, 0.96),
        ],
        // Kaki belakang: lutut di lantai.
        [Offset(0.46, 0.76), Offset(0.40, 0.96), Offset(0.14, 0.96)],
      ],
    ),
    Pose.timpuh => (
      const Offset(0.44, 0.48),
      const [
        // Badan, paha ke lutut di depan, tungkai terlipat di bawah.
        [
          Offset(0.44, 0.60),
          Offset(0.40, 0.84),
          Offset(0.76, 0.94),
          Offset(0.30, 0.97),
        ],
      ],
    ),
    Pose.sila => (
      const Offset(0.50, 0.48),
      const [
        [Offset(0.50, 0.60), Offset(0.50, 0.84)],
        // Kaki bersilang.
        [Offset(0.50, 0.84), Offset(0.84, 0.90), Offset(0.38, 0.97)],
        [Offset(0.50, 0.84), Offset(0.16, 0.90), Offset(0.62, 0.97)],
      ],
    ),
  };

  /// Menggambar sosok di dalam [rect] pada kanvas apa pun (dipakai juga oleh
  /// lencana pose di denah).
  static void paint(Canvas canvas, Rect rect, Pose pose, Color color) {
    final (head, lines) = _shape(pose);
    final s = rect.shortestSide;
    Offset at(Offset o) => rect.topLeft + Offset(o.dx * s, o.dy * s);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final line in lines) {
      final path = Path()..moveTo(at(line.first).dx, at(line.first).dy);
      for (final p in line.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(path, stroke);
    }
    canvas.drawCircle(at(head), s * 0.11, Paint()..color = color);
  }
}

class _PoseGlyphPainter extends CustomPainter {
  _PoseGlyphPainter(this.pose, this.color);

  final Pose pose;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      PoseGlyph.paint(canvas, Offset.zero & size, pose, color);

  @override
  bool shouldRepaint(_PoseGlyphPainter old) =>
      old.pose != pose || old.color != color;
}
