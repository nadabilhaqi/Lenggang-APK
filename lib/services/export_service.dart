import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/describe.dart';
import '../models/project.dart';
import '../ui/pose_glyph.dart';
import '../ui/stage/stage_painter.dart';
import 'lenggang_format.dart';

/// Ekspor PNG denah & berkas `.lenggang`, serta impor `.lenggang`.
class ExportService {
  ExportService._();

  /// Menangkap kanvas panggung dari [RepaintBoundary] lalu menyusunnya
  /// menjadi lembar denah PNG: kepala (judul, ketukan, ukuran panggung),
  /// gambar denah, dan tabel posisi tiap penari.
  static Future<Uint8List> capturePlanPng({
    required RenderRepaintBoundary boundary,
    required Project project,
    required int beat,
    required Map<String, DancerState> states,
    double pixelRatio = 3,
  }) async {
    final plan = await boundary.toImage(pixelRatio: pixelRatio);
    final k = pixelRatio;
    final w = plan.width.toDouble();
    final headerH = 86 * k;
    final rowH = 36 * k;
    final legendH = (project.dancers.length * rowH) + 34 * k;
    // Hanya bagian denah yang berisi panggung (plus label dan kursi) yang
    // dipakai, supaya lembar tidak penuh ruang kosong.
    final geo = StageGeometry(
      ui.Size(plan.width / k - 8, plan.height / k),
      project.stageWidth,
      project.stageDepth,
      compact: false,
    );
    final cropTop = ((geo.stage.top - 26) * k).clamp(0.0, plan.height * 1.0);
    var seatsBottom = geo.stage.bottom + 20;
    for (final seat in geo.seatRects()) {
      if (seat.bottom > seatsBottom) seatsBottom = seat.bottom;
    }
    final cropBottom = ((seatsBottom + 10) * k).clamp(
      cropTop + 1,
      plan.height * 1.0,
    );
    final planH = cropBottom - cropTop;
    final h = headerH + planH + legendH;

    const bg = ui.Color(0xFF181420);
    const accent = ui.Color(0xFFF9D565);
    const muted = ui.Color(0xFFB5A9C7);
    const white = ui.Color(0xFFFFFFFF);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w, h), ui.Paint()..color = bg);

    TextPainter text(
      String s,
      double size,
      ui.Color color, {
      FontWeight weight = FontWeight.w500,
      double? maxWidth,
    }) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size * k, color: color, fontWeight: weight),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? w);

    final pad = 16 * k;
    var accentName = '';
    if (project.cycle.isKenong(beat)) accentName = ' · Kenong';
    if (project.cycle.isGong(beat)) accentName = ' · Gong';
    final right1 = text(
      'Ketukan $beat/${project.cycle.beats}$accentName',
      13,
      accent,
      weight: FontWeight.w800,
    );
    final right2 = text(
      'Panggung ${_n(project.stageWidth, 1)} × ${_n(project.stageDepth, 1)} m',
      10.5,
      muted,
    );
    final leftW = w - pad * 3 - right1.width;
    text(
      'LENGGANG · DENAH FORMASI',
      9.5,
      accent,
      weight: FontWeight.w800,
    ).paint(canvas, ui.Offset(pad, 12 * k));
    text(
      project.title,
      18,
      white,
      weight: FontWeight.w800,
      maxWidth: leftW,
    ).paint(canvas, ui.Offset(pad, 25 * k));
    final sub = [
      if (project.tradition.isNotEmpty) project.tradition,
      if (project.choreographer.isNotEmpty)
        'Penata tari: ${project.choreographer}',
    ].join(' · ');
    text(
      sub,
      10.5,
      muted,
      maxWidth: w - pad * 2,
    ).paint(canvas, ui.Offset(pad, 49 * k));
    right1.paint(canvas, ui.Offset(w - pad - right1.width, 27 * k));
    right2.paint(canvas, ui.Offset(pad, 65 * k));

    canvas.drawImageRect(
      plan,
      ui.Rect.fromLTRB(0, cropTop, w, cropBottom),
      ui.Rect.fromLTWH(0, headerH, w, planH),
      ui.Paint(),
    );

    // Tabel untuk penari: letak, arah hadap, dan pose dalam kata — tanpa
    // koordinat atau derajat.
    var y = headerH + planH + 8 * k;
    for (final d in project.dancers) {
      final s = states[d.id];
      if (s == null) continue;
      canvas.drawCircle(
        ui.Offset(pad + 6 * k, y + 9 * k),
        5.5 * k,
        ui.Paint()..color = ui.Color(d.color),
      );
      // Baris 1: nama di kiri, pose (sosok + kata) di kanan.
      final pose = text(s.pose.plain, 11, white, weight: FontWeight.w600);
      text(
        d.displayName,
        12,
        white,
        weight: FontWeight.w700,
        maxWidth: w - pad * 2 - 18 * k - pose.width - 26 * k,
      ).paint(canvas, ui.Offset(pad + 18 * k, y + 1 * k));
      pose.paint(canvas, ui.Offset(w - pad - pose.width, y + 1.5 * k));
      PoseGlyph.paint(
        canvas,
        ui.Rect.fromLTWH(w - pad - pose.width - 20 * k, y, 15 * k, 15 * k),
        s.pose,
        white,
      );
      // Baris 2: letak dan arah hadap.
      text(
        Describe.dancer(s, project),
        10.5,
        muted,
        maxWidth: w - pad * 2 - 18 * k,
      ).paint(canvas, ui.Offset(pad + 18 * k, y + 17 * k));
      y += rowH;
    }
    text(
      'Kiri–kanan dilihat dari penonton · dibuat dengan Lenggang',
      9,
      muted,
    ).paint(canvas, ui.Offset(pad, y + 6 * k));

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.round(), h.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    plan.dispose();
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }

  static String _n(double v, int digits) =>
      v.toStringAsFixed(digits).replaceAll('.', ',');

  static String safeName(String s) {
    final cleaned = s
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'lenggang' : cleaned;
  }

  static String pngName(Project p, int beat) =>
      '${safeName(p.title)}_ketukan$beat.png';

  static String fileName(Project p) =>
      '${safeName(p.title)}.${LenggangFormat.fileExtension}';

  static Uint8List encodeProject(Project p) =>
      Uint8List.fromList(utf8.encode(LenggangFormat.encode(p)));

  /// Dialog "Simpan sebagai" sistem. Mengembalikan `true` bila tersimpan.
  static Future<bool> saveAs(
    String fileName,
    Uint8List bytes,
    String mimeType,
  ) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: 'Simpan $fileName',
    );
    return uri != null;
  }

  /// Membagikan berkas lewat lembar bagikan Android/iOS.
  static Future<void> share(
    String fileName,
    Uint8List bytes,
    String mimeType, {
    String? text,
  }) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$fileName');
    await f.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, mimeType: mimeType, name: fileName)],
        text: text,
        subject: fileName,
      ),
    );
  }

  /// Memilih berkas `.lenggang` dan mengurainya. `null` bila dibatalkan.
  /// Melempar [FormatException] bila isi berkas tidak valid.
  static Future<Project?> pickProject() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Pilih berkas .lenggang',
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException('Berkas bukan teks UTF-8.');
    }
    return LenggangFormat.decode(text);
  }
}
