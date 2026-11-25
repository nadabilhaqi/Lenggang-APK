import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/timeline.dart';
import '../../models/project.dart';
import '../theme.dart';

/// Strip 16 ketukan Ketawang: ketuk untuk melompat, geser untuk scrub.
/// Penanda kenong (N) di ketukan 8 dan gong ageng (G) di ketukan 16; wajik
/// kuning menandai ketukan yang memiliki keyframe formasi.
class BeatStrip extends StatelessWidget {
  const BeatStrip({
    super.key,
    required this.project,
    required this.playhead,
    required this.onSeek,
    required this.onScrub,
    required this.onScrubEnd,
  });

  final Project project;
  final ValueListenable<double> playhead;
  final ValueChanged<int> onSeek;
  final ValueChanged<double> onScrub;
  final VoidCallback onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final beats = project.cycle.beats;
    return LayoutBuilder(
      builder: (context, c) {
        final cell = c.maxWidth / beats;
        double toP(Offset o) => (1 + o.dx / cell).clamp(1.0, beats + 0.999);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (d) => onSeek(toP(d.localPosition).floor()),
          onHorizontalDragStart: (d) => onScrub(toP(d.localPosition)),
          onHorizontalDragUpdate: (d) => onScrub(toP(d.localPosition)),
          onHorizontalDragEnd: (_) => onScrubEnd(),
          onHorizontalDragCancel: onScrubEnd,
          child: Semantics(
            label: 'Linimasa ${project.cycle.label} $beats ketukan',
            child: CustomPaint(
              size: Size(c.maxWidth, 62),
              painter: _BeatStripPainter(project, playhead),
            ),
          ),
        );
      },
    );
  }
}

class _BeatStripPainter extends CustomPainter {
  _BeatStripPainter(this.project, this.playhead) : super(repaint: playhead);

  final Project project;
  final ValueListenable<double> playhead;

  @override
  void paint(Canvas canvas, Size size) {
    final cycle = project.cycle;
    final n = cycle.beats;
    final cell = size.width / n;
    final p = playhead.value;
    final cur = Timeline.beatAt(p, n);

    for (var i = 0; i < n; i++) {
      final beat = i + 1;
      final r = Rect.fromLTWH(i * cell + 1.5, 0, cell - 3, size.height);
      final isCur = beat == cur;
      final kenong = cycle.isKenong(beat);
      final gong = cycle.isGong(beat);
      Color bg = LColors.card;
      if (kenong) bg = LColors.pink.withValues(alpha: 0.16);
      if (gong) bg = LColors.accent.withValues(alpha: 0.16);
      if (isCur) bg = LColors.accent;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(7)),
        Paint()..color = bg,
      );
      if (kenong || gong) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(7)),
          Paint()
            ..color = gong ? LColors.accent : LColors.pink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        _text(
          canvas,
          gong ? 'G' : 'N',
          Offset(r.center.dx, 10),
          10,
          isCur ? LColors.base : (gong ? LColors.accent : LColors.pink),
          FontWeight.w900,
        );
      }
      _text(
        canvas,
        '$beat',
        Offset(r.center.dx, 29),
        cell < 24 ? 12 : 14,
        isCur ? LColors.base : LColors.text,
        FontWeight.w800,
      );
      if (project.keyframes.containsKey(beat)) {
        final c = Offset(r.center.dx, 49);
        final path = Path()
          ..moveTo(c.dx, c.dy - 5)
          ..lineTo(c.dx + 5, c.dy)
          ..lineTo(c.dx, c.dy + 5)
          ..lineTo(c.dx - 5, c.dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()..color = isCur ? LColors.base : LColors.accent,
        );
      }
    }

    // Garis playhead kontinu.
    final x = (p - 1) * cell;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
  }

  void _text(
    Canvas canvas,
    String s,
    Offset c,
    double size,
    Color color,
    FontWeight w,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: w),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_BeatStripPainter old) =>
      old.project != project || old.playhead != playhead;
}
