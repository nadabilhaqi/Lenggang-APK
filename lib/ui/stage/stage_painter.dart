import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/collision.dart';
import '../../logic/timeline.dart';
import '../../models/app_settings.dart';
import '../../models/project.dart';
import '../pose_glyph.dart';
import '../theme.dart';

/// Pratinjau sementara saat penari sedang digeser/diputar (belum disimpan).
class DragOverride {
  const DragOverride(this.dancerId, {this.x, this.y, this.facing});

  final String dancerId;
  final double? x;
  final double? y;
  final double? facing;
}

/// Keadaan penari yang ditampilkan: hasil interpolasi + pratinjau geser.
Map<String, DancerState> effectiveStates(
  Project project,
  double playhead,
  DragOverride? drag,
) {
  final s = Timeline.stateAt(project, playhead);
  if (drag != null && s[drag.dancerId] != null) {
    s[drag.dancerId] = s[drag.dancerId]!.copyWith(
      x: drag.x,
      y: drag.y,
      facing: drag.facing,
    );
  }
  return s;
}

/// Benda panggung dengan posisi pratinjau saat sedang digeser.
List<StageObject> effectiveObjects(Project project, DragOverride? drag) => [
  for (final o in project.objects)
    if (drag != null && drag.dancerId == o.id)
      o.copyWith(x: drag.x, y: drag.y)
    else
      o,
];

/// Pemetaan meter panggung <-> piksel layar.
///
/// Penonton berada di bawah layar. `x` meter bertambah ke kanan,
/// `y` meter bertambah ke atas (menjauhi penonton).
class StageGeometry {
  StageGeometry(this.size, this.widthM, this.depthM, {required bool compact}) {
    final pad = compact
        ? const EdgeInsets.fromLTRB(6, 6, 6, 14)
        : const EdgeInsets.fromLTRB(24, 26, 14, 72);
    final availW = math.max(1.0, size.width - pad.horizontal);
    final availH = math.max(1.0, size.height - pad.vertical);
    scale = math.min(availW / widthM, availH / depthM);
    final w = widthM * scale;
    final h = depthM * scale;
    final left = pad.left + (availW - w) / 2;
    final top = pad.top + (availH - h) / 2;
    stage = Rect.fromLTWH(left, top, w, h);
  }

  final Size size;
  final double widthM;
  final double depthM;
  late final double scale;
  late final Rect stage;

  /// Kursi penonton berskala 1:1 dengan panggung (kursi 0,5 m), disusun
  /// seperti denah bioskop: dua blok dengan lorong di tengah, 1–3 baris
  /// sesuai ruang yang tersisa di bawah panggung.
  List<Rect> seatRects() {
    final seat = (0.5 * scale).clamp(9.0, 44.0);
    final gap = seat * 0.28;
    final aisle = seat * 1.2;
    final rowPitch = seat + gap * 1.3;
    final y0 = stage.bottom + 20;
    final rows = ((size.height - 2 - y0 + gap * 1.3) / rowPitch).floor().clamp(
      1,
      3,
    );
    final perSide = (((stage.width - aisle) / 2 + gap) / (seat + gap))
        .floor()
        .clamp(1, 40);
    final cx = stage.center.dx;
    final out = <Rect>[];
    for (var row = 0; row < rows; row++) {
      // Baris terdepan sedikit lebih pendek, seperti di gedung pertunjukan.
      final n = row == 0 && perSide >= 3 ? perSide - 1 : perSide;
      final y = y0 + row * rowPitch;
      for (var i = 0; i < n; i++) {
        final dx = aisle / 2 + i * (seat + gap);
        out.add(Rect.fromLTWH(cx + dx, y, seat, seat));
        out.add(Rect.fromLTWH(cx - dx - seat, y, seat, seat));
      }
    }
    return out;
  }

  Offset toScreen(double x, double y) =>
      Offset(stage.left + x * scale, stage.bottom - y * scale);

  (double, double) toStage(Offset o) =>
      ((o.dx - stage.left) / scale, (stage.bottom - o.dy) / scale);

  /// Vektor satuan arah hadap di koordinat layar.
  static Offset facingVector(double deg) {
    final r = deg * math.pi / 180;
    return Offset(math.sin(r), math.cos(r));
  }

  /// Sudut hadap (derajat) dari vektor layar.
  static double facingFromVector(Offset v) =>
      Timeline.normalizeAngle(math.atan2(v.dx, v.dy) * 180 / math.pi);

  /// Jari-jari visual titik penari (px).
  double get tokenRadius => (0.4 * scale).clamp(16.0, 22.0);

  /// Jari-jari area sentuh (px) — target sentuh minimal 56 dp.
  static const double hitRadius = 28;

  Offset handlePosition(DancerState s) =>
      toScreen(s.x, s.y) + facingVector(s.facing) * (tokenRadius + 30);
}

class StagePainter extends CustomPainter {
  StagePainter({
    required this.project,
    required this.playhead,
    required this.settings,
    this.drag,
    this.selectedId,
    this.selectedObjectId,
    this.compact = false,
    this.showHandle = false,
  }) : super(repaint: Listenable.merge([playhead, ?drag]));

  final Project project;
  final ValueListenable<double> playhead;
  final ValueListenable<DragOverride?>? drag;
  final AppSettings settings;
  final String? selectedId;
  final String? selectedObjectId;
  final bool compact;
  final bool showHandle;

  @override
  void paint(Canvas canvas, Size size) {
    final g = StageGeometry(
      size,
      project.stageWidth,
      project.stageDepth,
      compact: compact,
    );
    final states = effectiveStates(project, playhead.value, drag?.value);
    final collisions = CollisionDetector.find(
      states,
      settings.collisionThreshold,
    );
    final objects = effectiveObjects(project, drag?.value);
    final blocked = ObstacleDetector.find(states, objects);
    final hot = {
      ...CollisionDetector.involved(collisions),
      for (final h in blocked) h.dancerId,
    };
    final hitObjects = {for (final h in blocked) h.objectId};

    _paintStage(canvas, size, g);
    for (final o in objects) {
      _paintObject(canvas, g, o, hitObjects.contains(o.id));
      if (!compact && o.id == selectedObjectId) {
        final rect = Rect.fromLTRB(
          g.toScreen(o.left, 0).dx,
          g.toScreen(0, o.back).dy,
          g.toScreen(o.right, 0).dx,
          g.toScreen(0, o.front).dy,
        ).inflate(4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    if (settings.showSampur && !compact) {
      _paintSampur(canvas, g, states);
    }
    _paintCollisionLinks(canvas, g, states, collisions);
    for (final d in project.dancers) {
      final s = states[d.id];
      if (s == null) continue;
      _paintDancer(canvas, g, d, s, hot.contains(d.id));
    }
    if (!compact) {
      for (final d in project.dancers) {
        final s = states[d.id];
        if (s != null) {
          _paintLabel(canvas, g, d, s, hot.contains(d.id), states);
        }
      }
    }
    if (!compact && selectedId != null && states[selectedId] != null) {
      _paintSelection(canvas, g, states[selectedId]!);
    }
    final dv = drag?.value;
    if (!compact && dv != null && states[dv.dancerId] != null) {
      _paintDragReadout(canvas, g, states[dv.dancerId]!, dv.facing != null);
    }
  }

  // --- panggung ---------------------------------------------------------------

  void _paintStage(Canvas canvas, Size size, StageGeometry g) {
    final r = g.stage;
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(4)),
      Paint()..color = LColors.stageFloor,
    );

    final minor = Paint()
      ..color = LColors.border.withValues(alpha: 0.45)
      ..strokeWidth = 0.7;
    final major = Paint()
      ..color = LColors.border
      ..strokeWidth = 1.1;

    final showMinor = g.scale >= 36 && !compact;
    final step = showMinor ? 0.5 : 1.0;
    for (var x = step; x < project.stageWidth - 1e-6; x += step) {
      final isMajor = (x - x.roundToDouble()).abs() < 1e-6;
      final px = r.left + x * g.scale;
      canvas.drawLine(
        Offset(px, r.top),
        Offset(px, r.bottom),
        isMajor ? major : minor,
      );
    }
    for (var y = step; y < project.stageDepth - 1e-6; y += step) {
      final isMajor = (y - y.roundToDouble()).abs() < 1e-6;
      final py = r.bottom - y * g.scale;
      canvas.drawLine(
        Offset(r.left, py),
        Offset(r.right, py),
        isMajor ? major : minor,
      );
    }

    // Garis tengah panggung.
    final center = Paint()
      ..color = LColors.muted.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final c = r.center;
    _dashedLine(canvas, Offset(c.dx, r.top), Offset(c.dx, r.bottom), center);
    _dashedLine(canvas, Offset(r.left, c.dy), Offset(r.right, c.dy), center);

    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(4)),
      Paint()
        ..color = LColors.muted.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Sisi penonton (depan) — garis tebal kuning di tepi bawah.
    canvas.drawLine(
      r.bottomLeft,
      r.bottomRight,
      Paint()
        ..color = LColors.accent
        ..strokeWidth = compact ? 2.5 : 3.5
        ..strokeCap = StrokeCap.round,
    );

    if (compact) return;

    // Label ukuran meter.
    final labelEvery = g.scale < 24 ? 2 : 1;
    for (var x = 0; x <= project.stageWidth.floor(); x += labelEvery) {
      _text(
        canvas,
        '$x',
        Offset(r.left + x * g.scale, r.bottom + 5),
        size: 9.5,
        color: LColors.dimmed,
        align: _Align.topCenter,
      );
    }
    for (var y = 0; y <= project.stageDepth.floor(); y += labelEvery) {
      _text(
        canvas,
        '$y',
        Offset(r.left - 5, r.bottom - y * g.scale),
        size: 9.5,
        color: LColors.dimmed,
        align: _Align.centerRight,
      );
    }

    // Sisi belakang (pengrawih / gamelan).
    _text(
      canvas,
      'PENGRAWIH · BELAKANG',
      Offset(r.center.dx, r.top - 6),
      size: 10,
      color: LColors.muted,
      weight: FontWeight.w700,
      align: _Align.bottomCenter,
      letterSpacing: 1.2,
    );

    // Sisi penonton: kursi berskala 1:1, seperti denah bioskop.
    final seatPaint = Paint()..color = const Color(0xFF6F6880);
    for (final seat in g.seatRects()) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(seat, Radius.circular(seat.width * 0.28)),
        seatPaint,
      );
    }
  }

  // --- sampur & tabrakan --------------------------------------------------------

  void _paintSampur(
    Canvas canvas,
    StageGeometry g,
    Map<String, DancerState> states,
  ) {
    final rad = settings.sampurRadius * g.scale;
    for (final d in project.dancers) {
      final s = states[d.id];
      if (s == null) continue;
      final c = g.toScreen(s.x, s.y);
      final col = Color(d.color);
      canvas.drawCircle(c, rad, Paint()..color = col.withValues(alpha: 0.05));
      _dashedCircle(
        canvas,
        c,
        rad,
        Paint()
          ..color = col.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _paintCollisionLinks(
    Canvas canvas,
    StageGeometry g,
    Map<String, DancerState> states,
    List<Collision> collisions,
  ) {
    for (final c in collisions) {
      final a = g.toScreen(states[c.a]!.x, states[c.a]!.y);
      final b = g.toScreen(states[c.b]!.x, states[c.b]!.y);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = LColors.danger
          ..strokeWidth = compact ? 2 : 3
          ..strokeCap = StrokeCap.round,
      );
      if (!compact) {
        final mid = Offset.lerp(a, b, 0.5)!;
        final label = fmtMeters(c.distance);
        final tp = _layout(label, 11, Colors.white, FontWeight.w800);
        final box = Rect.fromCenter(
          center: mid + const Offset(0, -16),
          width: tp.width + 12,
          height: tp.height + 6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(6)),
          Paint()..color = LColors.danger,
        );
        tp.paint(canvas, box.topLeft + const Offset(6, 3));
      }
    }
  }

  // --- penari -------------------------------------------------------------------

  void _paintDancer(
    Canvas canvas,
    StageGeometry g,
    Dancer d,
    DancerState s,
    bool hot,
  ) {
    final c = g.toScreen(s.x, s.y);
    final r = compact ? math.max(5.0, g.tokenRadius * 0.6) : g.tokenRadius;
    final col = Color(d.color);
    final fill = hot ? LColors.danger : col;

    // Panah arah hadap.
    final v = StageGeometry.facingVector(s.facing);
    final perp = Offset(-v.dy, v.dx);
    final tip = c + v * (r + (compact ? 5 : 11));
    final baseC = c + v * (r - 1);
    final arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(baseC.dx + perp.dx * r * 0.62, baseC.dy + perp.dy * r * 0.62)
      ..lineTo(baseC.dx - perp.dx * r * 0.62, baseC.dy - perp.dy * r * 0.62)
      ..close();
    canvas.drawPath(arrow, Paint()..color = fill);

    if (hot && !compact) {
      canvas.drawCircle(
        c,
        r + 7,
        Paint()
          ..color = LColors.danger.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }

    canvas.drawCircle(c, r, Paint()..color = fill);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = hot ? Colors.white : LColors.base
        ..style = PaintingStyle.stroke
        ..strokeWidth = hot ? 2.5 : 2,
    );

    if (compact) return;

    _text(
      canvas,
      d.code,
      c,
      size: r * 0.78,
      color: hot ? Colors.white : LColors.base,
      weight: FontWeight.w900,
      align: _Align.center,
    );

    // Lencana pose: sosok kecil di kanan atas titik.
    const br = 10.5;
    final bc = c + Offset(r * 0.85, -r * 0.85);
    canvas.drawCircle(bc, br, Paint()..color = LColors.base);
    canvas.drawCircle(
      bc,
      br,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    PoseGlyph.paint(
      canvas,
      Rect.fromCenter(center: bc, width: 14, height: 14),
      s.pose,
      Colors.white,
    );
  }

  // --- benda panggung & properti -------------------------------------------------

  void _paintObject(Canvas canvas, StageGeometry g, StageObject o, bool hit) {
    final rect = Rect.fromLTRB(
      g.toScreen(o.left, 0).dx,
      g.toScreen(0, o.back).dy,
      g.toScreen(o.right, 0).dx,
      g.toScreen(0, o.front).dy,
    );
    final isProp = o.kind == StageObjectKind.prop;
    final base = hit ? LColors.danger : (isProp ? LColors.pink : LColors.muted);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(isProp ? 6 : 3));
    canvas.drawRRect(
      rr,
      Paint()..color = base.withValues(alpha: hit ? 0.35 : 0.16),
    );
    if (!isProp) {
      // Arsir diagonal: area terhalang.
      canvas.save();
      canvas.clipRRect(rr);
      final hatch = Paint()
        ..color = base.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      for (var d = -rect.height; d < rect.width; d += 7) {
        canvas.drawLine(
          Offset(rect.left + d, rect.bottom),
          Offset(rect.left + d + rect.height, rect.top),
          hatch,
        );
      }
      canvas.restore();
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..color = base
        ..style = PaintingStyle.stroke
        ..strokeWidth = hit ? 2.5 : 1.4,
    );
    if (compact || o.label.isEmpty) return;
    final tp = _layout(o.label, 9.5, Colors.white, FontWeight.w700);
    final box = Rect.fromCenter(
      center: rect.center,
      width: tp.width + 8,
      height: tp.height + 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(5)),
      Paint()
        ..color = (hit ? LColors.danger : LColors.deep).withValues(alpha: 0.85),
    );
    tp.paint(canvas, box.topLeft + const Offset(4, 1));
  }

  /// Nama peran, digambar setelah semua titik agar selalu terbaca. Dari empat
  /// posisi (bawah, atas, kanan, kiri) dipilih yang paling sedikit menutup
  /// panah sendiri maupun titik/panah penari lain.
  void _paintLabel(
    Canvas canvas,
    StageGeometry g,
    Dancer d,
    DancerState s,
    bool hot,
    Map<String, DancerState> states,
  ) {
    final c = g.toScreen(s.x, s.y);
    final r = g.tokenRadius;
    final v = StageGeometry.facingVector(s.facing);
    final tp = _layout(d.role, 10, Colors.white, FontWeight.w700);
    final w = tp.width + 8, h = tp.height + 2;

    // (arah, pusat kotak, penalti dasar) — urutan = urutan preferensi.
    final candidates = <(Offset, Offset, double)>[
      (const Offset(0, 1), c + Offset(0, r + 4 + h / 2), 0),
      (const Offset(0, -1), c - Offset(0, r + 4 + h / 2), 0.4),
      (const Offset(1, 0), c + Offset(r + 5 + w / 2, 0), 0.6),
      (const Offset(-1, 0), c - Offset(r + 5 + w / 2, 0), 0.7),
    ];
    var best = candidates.first.$2;
    var bestScore = double.infinity;
    for (final (dir, center, base) in candidates) {
      final box = Rect.fromCenter(center: center, width: w, height: h);
      var score = base;
      // Panah sendiri.
      if (dir.dx * v.dx + dir.dy * v.dy > 0.6) score += 3;
      for (final e in states.entries) {
        if (e.key == d.id) continue;
        final oc = g.toScreen(e.value.x, e.value.y);
        if (box.overlaps(Rect.fromCircle(center: oc, radius: r + 1))) {
          score += 4;
        }
        final tip = oc + StageGeometry.facingVector(e.value.facing) * (r + 6);
        if (box.overlaps(Rect.fromCircle(center: tip, radius: 7))) score += 3;
      }
      if (score < bestScore) {
        bestScore = score;
        best = center;
      }
    }
    final box = Rect.fromCenter(center: best, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(5)),
      Paint()
        ..color = (hot ? LColors.danger : LColors.deep).withValues(alpha: 0.82),
    );
    tp.paint(canvas, box.topLeft + const Offset(4, 1));
  }

  void _paintSelection(Canvas canvas, StageGeometry g, DancerState s) {
    final c = g.toScreen(s.x, s.y);
    final r = g.tokenRadius;
    _dashedCircle(
      canvas,
      c,
      r + 5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    if (!showHandle) return;
    final h = g.handlePosition(s);
    canvas.drawLine(
      c,
      h,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(h, 14, Paint()..color = LColors.accent);
    canvas.drawCircle(
      h,
      14,
      Paint()
        ..color = LColors.base
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final icon = Icons.rotate_right;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 18,
          color: LColors.base,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, h - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintDragReadout(
    Canvas canvas,
    StageGeometry g,
    DancerState s,
    bool rotating,
  ) {
    final label = rotating
        ? 'Hadap ${s.facing.round()}°'
        : 'x ${fmtNum(s.x, 2)} · y ${fmtNum(s.y, 2)} m';
    final tp = _layout(label, 12, LColors.base, FontWeight.w800);
    final c = g.toScreen(s.x, s.y);
    var box = Rect.fromCenter(
      center: c + Offset(0, -g.tokenRadius - 34),
      width: tp.width + 16,
      height: tp.height + 8,
    );
    if (box.top < 2) box = box.shift(Offset(0, 2 - box.top));
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(8)),
      Paint()..color = Colors.white,
    );
    tp.paint(canvas, box.topLeft + const Offset(8, 4));
  }

  // --- pembantu gambar -----------------------------------------------------------

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
    const dash = 5.0, gap = 5.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final e = math.min(d + dash, total);
      canvas.drawLine(a + dir * d, a + dir * e, p);
      d = e + gap;
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint p) {
    final segs = math.max(12, (2 * math.pi * r / 9).round());
    final sweep = 2 * math.pi / segs;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < segs; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, p);
    }
  }

  TextPainter _layout(
    String s,
    double size,
    Color color,
    FontWeight weight, {
    double letterSpacing = 0,
    bool shadow = false,
  }) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        shadows: shadow
            ? const [Shadow(color: Colors.black, blurRadius: 3)]
            : null,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w500,
    _Align align = _Align.center,
    double letterSpacing = 0,
    bool shadow = false,
  }) {
    final tp = _layout(
      s,
      size,
      color,
      weight,
      letterSpacing: letterSpacing,
      shadow: shadow,
    );
    final o = switch (align) {
      _Align.center => at - Offset(tp.width / 2, tp.height / 2),
      _Align.topCenter => at - Offset(tp.width / 2, 0),
      _Align.bottomCenter => at - Offset(tp.width / 2, tp.height),
      _Align.centerLeft => at - Offset(0, tp.height / 2),
      _Align.centerRight => at - Offset(tp.width, tp.height / 2),
    };
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(StagePainter old) =>
      old.project != project ||
      old.settings != settings ||
      old.selectedId != selectedId ||
      old.selectedObjectId != selectedObjectId ||
      old.compact != compact ||
      old.showHandle != showHandle ||
      old.playhead != playhead ||
      old.drag != drag;
}

enum _Align { center, topCenter, bottomCenter, centerLeft, centerRight }
