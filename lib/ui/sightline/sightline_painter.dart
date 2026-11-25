import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/collision.dart';
import '../../logic/timeline.dart';
import '../../models/app_settings.dart';
import '../../models/project.dart';
import '../theme.dart';

/// Titik 3D di ruang panggung: x ke kanan (m), y ke atas (m), z menjauhi
/// penonton (m). Tepi depan panggung berada di z = 0.
class V3 {
  const V3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

/// Kamera perspektif sederhana di kursi penonton, menghadap tengah panggung.
///
/// Proyeksi dihitung sendiri (tanpa pustaka 3D): titik diubah ke koordinat
/// kamera (kanan, atas, depan) lalu dibagi kedalamannya.
class SightlineCamera {
  SightlineCamera({
    required this.stageWidth,
    required this.stageDepth,
    required this.seatDistance,
    required this.eyeHeight,
    required Size view,
    this.seatOffset = 0,
    List<V3>? fit,
  }) {
    _ex = stageWidth / 2 + seatOffset;
    _ey = eyeHeight;
    _ez = -seatDistance;
    // Arah pandang ke tengah panggung setinggi dada.
    var fx = stageWidth / 2 - _ex, fy = 0.9 - _ey, fz = stageDepth / 2 - _ez;
    final len = math.sqrt(fx * fx + fy * fy + fz * fz);
    fx /= len;
    fy /= len;
    fz /= len;
    _f = V3(fx, fy, fz);
    // kanan = atas-dunia × depan; atas = depan × kanan.
    final rl = math.sqrt(fz * fz + fx * fx);
    _r = V3(fz / rl, 0, -fx / rl);
    _u = V3(
      fy * _r.z - fz * _r.y,
      fz * _r.x - fx * _r.z,
      fx * _r.y - fy * _r.x,
    );

    // Skala (panjang fokus dalam piksel): cukup untuk memuat titik-titik
    // [fit] (bawaan: seluruh volume panggung), tetapi dibatasi sudut pandang
    // 55° agar kursi belakang benar-benar terasa lebih jauh.
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    final points =
        fit ??
        [
          for (final x in [0.0, stageWidth])
            for (final y in [0.0, _volumeHeight])
              for (final z in [0.0, stageDepth]) V3(x, y, z),
        ];
    for (final p in points) {
      final c = _toCamera(p);
      if (c.z <= 0.05) continue;
      minX = math.min(minX, c.x / c.z);
      maxX = math.max(maxX, c.x / c.z);
      minY = math.min(minY, c.y / c.z);
      maxY = math.max(maxY, c.y / c.z);
    }
    if (minX == double.infinity) {
      minX = -1;
      maxX = 1;
      minY = -1;
      maxY = 1;
    }
    final fitW = view.width * 0.92 / math.max(maxX - minX, 1e-6);
    final fitH = view.height * 0.80 / math.max(maxY - minY, 1e-6);
    final fixed = view.width / 2 / math.tan(55 / 2 * math.pi / 180);
    // Tanpa [fit] (seluruh panggung) sudut pandang dibatasi 55°; dengan [fit]
    // boleh memperbesar hingga 3× supaya figur penari cukup besar.
    focal = math.min(math.min(fitW, fitH), fit == null ? fixed : fixed * 3);
    _cx = view.width / 2 - focal * (maxX + minX) / 2;
    _cy = view.height / 2 + focal * (maxY + minY) / 2;
  }

  static const double _volumeHeight = 2.2;

  final double stageWidth;
  final double stageDepth;

  /// Jarak kursi dari tepi depan panggung (m).
  final double seatDistance;

  /// Tinggi mata di atas lantai panggung (m).
  final double eyeHeight;

  /// Geseran kursi dari sumbu tengah (m): − kiri, + kanan.
  final double seatOffset;

  late final double focal;
  late final double _ex, _ey, _ez;
  late final V3 _f, _r, _u;
  late final double _cx, _cy;

  V3 get eye => V3(_ex, _ey, _ez);

  V3 _toCamera(V3 p) {
    final vx = p.x - _ex, vy = p.y - _ey, vz = p.z - _ez;
    return V3(
      vx * _r.x + vy * _r.y + vz * _r.z,
      vx * _u.x + vy * _u.y + vz * _u.z,
      vx * _f.x + vy * _f.y + vz * _f.z,
    );
  }

  /// Kedalaman titik dari kamera (m); ≤ 0 berarti di belakang kamera.
  double depthOf(V3 p) => _toCamera(p).z;

  /// Proyeksi ke layar; `null` bila titik berada di belakang kamera.
  Offset? project(V3 p) {
    final c = _toCamera(p);
    if (c.z <= 0.05) return null;
    return Offset(_cx + focal * c.x / c.z, _cy - focal * c.y / c.z);
  }

  /// Piksel per meter pada kedalaman titik [p].
  double pixelsPerMeter(V3 p) {
    final z = depthOf(p);
    return z <= 0.05 ? 0 : focal / z;
  }
}

/// Satu penari siap gambar.
class SightFigure {
  SightFigure({
    required this.dancer,
    required this.state,
    required this.height,
    required this.depth,
  });

  final Dancer dancer;
  final DancerState state;

  /// Tinggi kepala (m).
  final double height;

  /// Jarak dari kamera (m) untuk depth sorting.
  final double depth;

  /// Peran penari yang menghalangi kepala penari ini (kosong = terlihat).
  final List<String> blockedBy = [];
}

class SightlineScene {
  SightlineScene._();

  static const double bodyRadius = 0.2;

  /// Titik-titik yang harus masuk bingkai: ruang gerak semua penari di semua
  /// keyframe (plus margin), supaya figur tampil sebesar mungkin dan bingkai
  /// tidak "bernapas" selama animasi. Tanpa penari: seluruh panggung.
  static List<V3>? framing(Project project) {
    var minX = double.infinity, maxX = -double.infinity;
    var minZ = double.infinity, maxZ = -double.infinity;
    for (final k in project.keyframes.values) {
      for (final s in k.values) {
        minX = math.min(minX, s.x);
        maxX = math.max(maxX, s.x);
        minZ = math.min(minZ, s.y);
        maxZ = math.max(maxZ, s.y);
      }
    }
    if (minX == double.infinity) return null;
    const margin = 1.0;
    // Simetris terhadap sumbu tengah agar tengah panggung tetap di tengah.
    final half =
        math.max(
          (project.stageWidth / 2 - minX).abs(),
          (maxX - project.stageWidth / 2).abs(),
        ) +
        margin;
    final x0 = project.stageWidth / 2 - half,
        x1 = project.stageWidth / 2 + half;
    final z0 = math.max(0.0, minZ - margin);
    final z1 = math.min(project.stageDepth, maxZ + margin);
    return [
      for (final x in [x0, x1])
        for (final y in [0.0, 2.1])
          for (final z in [z0, z1]) V3(x, y, z),
    ];
  }

  /// Menyusun figur terurut dari yang terjauh (painter's algorithm) dan
  /// menandai penari yang kepalanya terhalang penari lain dari kursi ini.
  static List<SightFigure> build({
    required Project project,
    required double playhead,
    required AppSettings settings,
    required SightlineCamera camera,
  }) {
    final states = Timeline.stateAt(project, playhead);
    final figures = <SightFigure>[];
    for (final d in project.dancers) {
      final s = states[d.id];
      if (s == null) continue;
      final h = Timeline.headHeightAt(
        project,
        playhead,
        d.id,
        settings.heightOf,
      );
      figures.add(
        SightFigure(
          dancer: d,
          state: s,
          height: h,
          depth: camera.depthOf(V3(s.x, h / 2, s.y)),
        ),
      );
    }
    final e = camera.eye;
    for (final a in figures) {
      // Sinar dari mata ke tengah kepala penari a.
      final hx = a.state.x, hy = a.height - 0.11, hz = a.state.y;
      final dx = hx - e.x, dy = hy - e.y, dz = hz - e.z;
      final len2 = dx * dx + dz * dz;
      if (len2 < 1e-9) continue;
      for (final b in figures) {
        if (identical(a, b)) continue;
        final t = ((b.state.x - e.x) * dx + (b.state.y - e.z) * dz) / len2;
        if (t <= 0.02 || t >= 0.97) continue; // b tidak berada di antara
        final px = e.x + dx * t, pz = e.z + dz * t;
        final side = math.sqrt(
          math.pow(px - b.state.x, 2) + math.pow(pz - b.state.y, 2),
        );
        final rayY = e.y + dy * t;
        if (side < bodyRadius && rayY < b.height && rayY > 0) {
          a.blockedBy.add(b.dancer.role);
        }
      }
    }
    figures.sort((p, q) => q.depth.compareTo(p.depth));
    return figures;
  }
}

class SightlinePainter extends CustomPainter {
  SightlinePainter({
    required this.project,
    required this.playhead,
    required this.settings,
    required this.seatDistance,
    required this.eyeHeight,
    this.seatOffset = 0,
  }) : super(repaint: playhead);

  final Project project;
  final ValueListenable<double> playhead;
  final AppSettings settings;
  final double seatDistance;
  final double eyeHeight;
  final double seatOffset;

  static const _skin = Color(0xFFF3D9B9);
  static const _hair = Color(0xFF17121F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final cam = SightlineCamera(
      stageWidth: project.stageWidth,
      stageDepth: project.stageDepth,
      seatDistance: seatDistance,
      eyeHeight: eyeHeight,
      seatOffset: seatOffset,
      view: size,
      fit: SightlineScene.framing(project),
    );
    _paintRoom(canvas, size, cam);
    final figures = SightlineScene.build(
      project: project,
      playhead: playhead.value,
      settings: settings,
      camera: cam,
    );
    final hot = {
      ...CollisionDetector.involved(
        CollisionDetector.find(
          Timeline.stateAt(project, playhead.value),
          settings.collisionThreshold,
        ),
      ),
    };
    final blocked = ObstacleDetector.find(
      Timeline.stateAt(project, playhead.value),
      project.objects,
    );
    hot.addAll([for (final h in blocked) h.dancerId]);
    final hitObjects = {for (final h in blocked) h.objectId};
    for (final f in figures) {
      _paintFloorMarks(canvas, cam, f, hot.contains(f.dancer.id));
    }
    // Penari dan benda digambar bersama dari yang terjauh (depth sorting).
    final drawables = <(double, void Function())>[
      for (final f in figures)
        (
          f.depth,
          () => _paintFigure(canvas, cam, f, hot.contains(f.dancer.id)),
        ),
      for (final o in project.objects)
        (
          cam.depthOf(V3(o.x, 0, o.y)),
          () => _paintBox(canvas, cam, o, hitObjects.contains(o.id)),
        ),
    ]..sort((p, q) => q.$1.compareTo(p.$1));
    for (final d in drawables) {
      d.$2();
    }
    _paintLabels(canvas, cam, figures, hot);
    canvas.restore();
  }

  // --- ruang & lantai -----------------------------------------------------------

  void _paintRoom(Canvas canvas, Size size, SightlineCamera cam) {
    final w = project.stageWidth, d = project.stageDepth;
    canvas.drawRect(Offset.zero & size, Paint()..color = LColors.deep);

    // Dinding/tirai belakang.
    final wall = _quad(cam, [
      V3(0, 0, d),
      V3(w, 0, d),
      V3(w, 3.2, d),
      V3(0, 3.2, d),
    ]);
    if (wall != null) {
      canvas.drawPath(wall, Paint()..color = const Color(0xFF1D1727));
    }

    // Lantai panggung.
    final floor = _quad(cam, [
      V3(0, 0, 0),
      V3(w, 0, 0),
      V3(w, 0, d),
      V3(0, 0, d),
    ]);
    if (floor != null) {
      canvas.drawPath(floor, Paint()..color = LColors.stageFloor);
    }
    final grid = Paint()
      ..color = LColors.border
      ..strokeWidth = 1;
    for (var x = 0.0; x <= w + 1e-6; x += 1) {
      _line(canvas, cam, V3(x, 0, 0), V3(x, 0, d), grid);
    }
    for (var z = 0.0; z <= d + 1e-6; z += 1) {
      _line(canvas, cam, V3(0, 0, z), V3(w, 0, z), grid);
    }
    final center = Paint()
      ..color = LColors.muted.withValues(alpha: 0.45)
      ..strokeWidth = 1.2;
    _line(canvas, cam, V3(w / 2, 0, 0), V3(w / 2, 0, d), center);
    _line(canvas, cam, V3(0, 0, d / 2), V3(w, 0, d / 2), center);

    // Tepi belakang & samping lantai.
    final edge = Paint()
      ..color = LColors.muted.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    _line(canvas, cam, V3(0, 0, d), V3(w, 0, d), edge);
    _line(canvas, cam, V3(0, 0, 0), V3(0, 0, d), edge);
    _line(canvas, cam, V3(w, 0, 0), V3(w, 0, d), edge);

    // Bibir panggung (sisi penonton) + tepi depan kuning.
    final apron = _quad(cam, [
      V3(0, 0, 0),
      V3(w, 0, 0),
      V3(w, -0.6, 0),
      V3(0, -0.6, 0),
    ]);
    if (apron != null) {
      canvas.drawPath(apron, Paint()..color = const Color(0xFF0D0A12));
    }
    _line(
      canvas,
      cam,
      V3(0, 0, 0),
      V3(w, 0, 0),
      Paint()
        ..color = LColors.accent
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  Path? _quad(SightlineCamera cam, List<V3> pts) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = cam.project(pts[i]);
      if (o == null) return null;
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    return path..close();
  }

  void _line(Canvas canvas, SightlineCamera cam, V3 a, V3 b, Paint p) {
    final pa = cam.project(a), pb = cam.project(b);
    if (pa == null || pb == null) return;
    canvas.drawLine(pa, pb, p);
  }

  // --- benda panggung -----------------------------------------------------------

  /// Benda panggung sebagai kotak setinggi 1,1 m; properti tari sebagai
  /// kotak rendah 0,35 m.
  void _paintBox(Canvas canvas, SightlineCamera cam, StageObject o, bool hit) {
    final isProp = o.kind == StageObjectKind.prop;
    final h = isProp ? 0.35 : 1.1;
    final base = hit
        ? LColors.danger
        : (isProp ? LColors.pink : const Color(0xFF8C82A0));
    final e = cam.eye;
    Path? face(List<V3> pts) => _quad(cam, pts);
    V3 c(double x, double y, double z) => V3(x, y, z);
    final l = o.left, r = o.right, f = o.front, b = o.back;
    // Sisi yang menghadap kamera saja yang digambar.
    final faces = <(Path?, double)>[
      if (e.x < l)
        (face([c(l, 0, f), c(l, 0, b), c(l, h, b), c(l, h, f)]), 0.55),
      if (e.x > r)
        (face([c(r, 0, f), c(r, 0, b), c(r, h, b), c(r, h, f)]), 0.55),
      if (e.z < f)
        (face([c(l, 0, f), c(r, 0, f), c(r, h, f), c(l, h, f)]), 0.75),
      if (e.y > h)
        (face([c(l, h, f), c(r, h, f), c(r, h, b), c(l, h, b)]), 1.0),
    ];
    for (final (path, shade) in faces) {
      if (path == null) continue;
      canvas.drawPath(
        path,
        Paint()..color = Color.lerp(LColors.deep, base, 0.25 + 0.5 * shade)!,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = LColors.deep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    if (o.label.isEmpty) return;
    final top = cam.project(V3(o.x, h, o.y));
    if (top == null) return;
    final tp = TextPainter(
      text: TextSpan(
        text: o.label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(
      center: Offset(top.dx, top.dy - 9),
      width: tp.width + 8,
      height: tp.height + 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(5)),
      Paint()
        ..color = (hit ? LColors.danger : LColors.deep).withValues(alpha: 0.8),
    );
    tp.paint(canvas, box.topLeft + const Offset(4, 1));
  }

  // --- penari -------------------------------------------------------------------

  /// Arah hadap di ruang panggung: 0° = menghadap penonton (−z).
  static (double, double) _facingXZ(double deg) {
    final r = deg * math.pi / 180;
    return (math.sin(r), -math.cos(r));
  }

  void _paintFloorMarks(
    Canvas canvas,
    SightlineCamera cam,
    SightFigure f,
    bool hot,
  ) {
    final s = f.state;
    final color = hot ? LColors.danger : Color(f.dancer.color);

    // Bayangan/alas lingkaran di lantai (radius badan).
    final ring = Path();
    const n = 20;
    for (var i = 0; i <= n; i++) {
      final a = i / n * 2 * math.pi;
      final o = cam.project(
        V3(s.x + 0.3 * math.cos(a), 0, s.y + 0.3 * math.sin(a)),
      );
      if (o == null) return;
      if (i == 0) {
        ring.moveTo(o.dx, o.dy);
      } else {
        ring.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      ring,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    if (hot) {
      canvas.drawPath(
        ring,
        Paint()
          ..color = LColors.danger
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Panah arah hadap di lantai.
    final (dx, dz) = _facingXZ(s.facing);
    final px = -dz, pz = dx; // tegak lurus
    final tip = cam.project(V3(s.x + dx * 0.72, 0, s.y + dz * 0.72));
    final b1 = cam.project(
      V3(s.x + dx * 0.36 + px * 0.16, 0, s.y + dz * 0.36 + pz * 0.16),
    );
    final b2 = cam.project(
      V3(s.x + dx * 0.36 - px * 0.16, 0, s.y + dz * 0.36 - pz * 0.16),
    );
    if (tip == null || b1 == null || b2 == null) return;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b2.dx, b2.dy)
        ..close(),
      Paint()..color = color.withValues(alpha: 0.9),
    );
  }

  void _paintFigure(
    Canvas canvas,
    SightlineCamera cam,
    SightFigure f,
    bool hot,
  ) {
    final s = f.state;
    final foot = cam.project(V3(s.x, 0, s.y));
    final top = cam.project(V3(s.x, f.height, s.y));
    final k = cam.pixelsPerMeter(V3(s.x, f.height / 2, s.y));
    if (foot == null || top == null || k <= 0) return;

    final color = hot ? LColors.danger : Color(f.dancer.color);
    final (dx, dz) = _facingXZ(s.facing);
    // Seberapa "menghadap kamera": 1 = menghadap penonton, −1 = membelakangi.
    final e = cam.eye;
    var cxz = e.x - s.x, czz = e.z - s.y;
    final cl = math.sqrt(cxz * cxz + czz * czz);
    cxz /= cl;
    czz /= cl;
    final front = dx * cxz + dz * czz;
    // Komponen menyamping di layar: + = menghadap kanan layar.
    final lateral = dx * (-czz) + dz * cxz;

    final headR = 0.115 * k;
    if (foot.dy - top.dy < headR * 3.2) {
      // Dilihat hampir dari atas: bahu sebagai elips, kepala di tengahnya.
      final mid = Offset.lerp(foot, top, 0.6)!;
      canvas.drawOval(
        Rect.fromCenter(center: mid, width: 0.52 * k, height: 0.34 * k),
        Paint()..color = color,
      );
      canvas.drawOval(
        Rect.fromCenter(center: mid, width: 0.52 * k, height: 0.34 * k),
        Paint()
          ..color = LColors.deep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.drawCircle(top, headR, Paint()..color = _hair);
      return;
    }

    // Badan kapsul: bahu lebar saat menghadap/membelakangi, pipih saat
    // menyamping; pose rendah (jengkeng/timpuh/sila) melebar di bawah.
    final shoulder = (0.13 + 0.10 * front.abs()) * k;
    final low = ((1.6 - f.height) / 0.8).clamp(0.0, 1.0);
    final hip = shoulder * (1 + 0.75 * low);
    final neckY = top.dy + headR * 2.05;
    final body = Path()
      ..moveTo(foot.dx - hip, foot.dy - hip * 0.35)
      ..quadraticBezierTo(foot.dx - hip, foot.dy, foot.dx, foot.dy)
      ..quadraticBezierTo(
        foot.dx + hip,
        foot.dy,
        foot.dx + hip,
        foot.dy - hip * 0.35,
      )
      ..lineTo(foot.dx + shoulder, neckY + shoulder * 0.6)
      ..quadraticBezierTo(foot.dx + shoulder, neckY, foot.dx, neckY)
      ..quadraticBezierTo(
        foot.dx - shoulder,
        neckY,
        foot.dx - shoulder,
        neckY + shoulder * 0.6,
      )
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    // Sisi gelap untuk kesan volume.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      Rect.fromLTRB(
        foot.dx + (lateral >= 0 ? -hip : hip * 0.25),
        top.dy,
        foot.dx + (lateral >= 0 ? -hip * 0.25 : hip),
        foot.dy,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    // Sampur: selempang menyilang di dada (terlihat dari depan).
    if (front > 0.15) {
      canvas.drawLine(
        Offset(foot.dx - shoulder, neckY + shoulder * 0.4),
        Offset(foot.dx + shoulder * 0.9, (neckY + foot.dy) / 2),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55 * front)
          ..strokeWidth = math.max(1.5, 0.05 * k),
      );
    }
    canvas.restore();
    canvas.drawPath(
      body,
      Paint()
        ..color = LColors.deep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Kepala: rambut dulu, lalu wajah yang bergeser sesuai arah hadap
    // (hilang saat membelakangi kamera).
    final hc = Offset(top.dx, top.dy + headR);
    canvas.drawCircle(hc, headR, Paint()..color = _hair);
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: hc, radius: headR)),
    );
    final shift = (lateral >= 0 ? 1 : -1) * headR * (1 - front) * 1.05;
    canvas.drawCircle(
      hc + Offset(shift, headR * 0.12),
      headR * 0.9,
      Paint()..color = _skin,
    );
    canvas.restore();
    canvas.drawCircle(
      hc,
      headR,
      Paint()
        ..color = LColors.deep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Sanggul di belakang kepala.
    if (front < 0.6) {
      final bun =
          hc +
          Offset(
            -(lateral >= 0 ? 1 : -1) * headR * (1 - front.abs()) * 0.9,
            headR * 0.25,
          );
      canvas.drawCircle(bun, headR * 0.5, Paint()..color = _hair);
    }
  }

  /// Label peran di atas kepala. Penari terdekat diberi tempat lebih dulu;
  /// label yang bertabrakan dinaikkan dan diberi garis penunjuk.
  void _paintLabels(
    Canvas canvas,
    SightlineCamera cam,
    List<SightFigure> figures,
    Set<String> hot,
  ) {
    final placed = <Rect>[];
    for (final f in figures.reversed) {
      final top = cam.project(V3(f.state.x, f.height, f.state.y));
      if (top == null) continue;
      final blocked = f.blockedBy.isNotEmpty;
      final isHot = hot.contains(f.dancer.id);
      final tp = TextPainter(
        text: TextSpan(
          text: blocked ? '${f.dancer.role} · terhalang' : f.dancer.role,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: blocked ? LColors.base : Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      var box = Rect.fromCenter(
        center: Offset(top.dx, top.dy - 12),
        width: tp.width + 10,
        height: tp.height + 3,
      );
      var guard = 0;
      while (placed.any((r) => r.inflate(1).overlaps(box)) && guard++ < 12) {
        box = box.shift(Offset(0, -(box.height + 2)));
      }
      placed.add(box);
      if (box.bottom < top.dy - 6) {
        canvas.drawLine(
          Offset(top.dx, box.bottom),
          Offset(top.dx, top.dy - 2),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..strokeWidth = 1,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(5)),
        Paint()
          ..color = blocked
              ? LColors.accent
              : (isHot ? LColors.danger : LColors.deep.withValues(alpha: 0.85)),
      );
      tp.paint(canvas, box.topLeft + const Offset(5, 1.5));
    }
  }

  @override
  bool shouldRepaint(SightlinePainter old) =>
      old.project != project ||
      old.settings != settings ||
      old.seatDistance != seatDistance ||
      old.eyeHeight != eyeHeight ||
      old.seatOffset != seatOffset ||
      old.playhead != playhead;
}
