import 'dart:convert';

import '../models/pose.dart';
import '../models/project.dart';

/// Serialisasi berkas terbuka `.lenggang` (JSON, UTF-8).
///
/// Lihat README bagian "Format berkas .lenggang" untuk spesifikasinya.
class LenggangFormat {
  static const String formatId = 'lenggang';
  static const int schemaVersion = 1;
  static const String fileExtension = 'lenggang';

  static Map<String, Object?> toJson(Project p) => {
    'format': formatId,
    'schemaVersion': schemaVersion,
    'id': p.id,
    'metadata': {
      'title': p.title,
      'tradition': p.tradition,
      'choreographer': p.choreographer,
      'createdAt': p.createdAt.toUtc().toIso8601String(),
      'updatedAt': p.updatedAt.toUtc().toIso8601String(),
    },
    'stage': {
      'unit': 'm',
      'width': p.stageWidth,
      'depth': p.stageDepth,
      'origin': 'depan-kiri (dilihat dari penonton); x ke kanan, y ke belakang',
    },
    'rhythm': {
      'cycle': p.cycle.id,
      'name': p.cycle.label,
      'beatsPerCycle': p.cycle.beats,
      'kenong': p.cycle.kenongBeats,
      'gong': p.cycle.gongBeats,
      'bpm': p.bpm,
    },
    'dancers': [
      for (final d in p.dancers)
        {
          'id': d.id,
          'role': d.role,
          'name': d.name,
          'color': colorToHex(d.color),
        },
    ],
    'objects': [
      for (final o in p.objects)
        {
          'id': o.id,
          'type': o.kind.id,
          'label': o.label,
          'x': o.x,
          'y': o.y,
          'width': o.width,
          'depth': o.depth,
        },
    ],
    'keyframes': [
      for (final e in p.keyframes.entries)
        {
          'beat': e.key,
          'positions': [
            // Urutkan sesuai urutan daftar penari agar keluaran deterministik.
            for (final d in p.dancers)
              if (e.value[d.id] case final s?)
                {
                  'dancer': d.id,
                  'x': s.x,
                  'y': s.y,
                  'facing': s.facing,
                  'pose': s.pose.id,
                },
          ],
        },
    ],
  };

  static String encode(Project p) =>
      const JsonEncoder.withIndent('  ').convert(toJson(p));

  static Project decode(String source) {
    final Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      throw const FormatException('Berkas bukan JSON yang valid.');
    }
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Struktur berkas tidak dikenali.');
    }
    return fromJson(raw);
  }

  static Project fromJson(Map<String, dynamic> j) {
    if (j['format'] != formatId) {
      throw const FormatException('Bukan berkas .lenggang.');
    }
    final version = _int(j, 'schemaVersion');
    if (version > schemaVersion) {
      throw FormatException(
        'Berkas dibuat dengan versi skema $version, '
        'aplikasi ini mendukung hingga versi $schemaVersion.',
      );
    }
    final meta = _map(j, 'metadata');
    final stage = _map(j, 'stage');
    final rhythm = _map(j, 'rhythm');
    final cycle = CycleType.fromId(_str(rhythm, 'cycle'));

    final dancers = <Dancer>[];
    final ids = <String>{};
    for (final d in _list(j, 'dancers')) {
      final m = _asMap(d, 'dancers[]');
      final id = _str(m, 'id');
      if (!ids.add(id)) throw FormatException('ID penari ganda: $id');
      dancers.add(
        Dancer(
          id: id,
          role: _str(m, 'role'),
          name: (m['name'] as String?) ?? '',
          color: colorFromHex(_str(m, 'color')),
        ),
      );
    }

    final keyframes = <int, Map<String, DancerState>>{};
    for (final k in _list(j, 'keyframes')) {
      final m = _asMap(k, 'keyframes[]');
      final beat = _int(m, 'beat');
      if (beat < 1 || beat > cycle.beats) {
        throw FormatException('Ketukan $beat di luar siklus 1–${cycle.beats}.');
      }
      final states = <String, DancerState>{};
      for (final pos in _list(m, 'positions')) {
        final pm = _asMap(pos, 'positions[]');
        final did = _str(pm, 'dancer');
        if (!ids.contains(did)) {
          throw FormatException('Keyframe merujuk penari tak dikenal: $did');
        }
        states[did] = DancerState(
          x: _num(pm, 'x'),
          y: _num(pm, 'y'),
          facing: _num(pm, 'facing'),
          pose: Pose.fromId(_str(pm, 'pose')),
        );
      }
      keyframes[beat] = states;
    }

    // Opsional: berkas lama tidak memiliki daftar benda.
    final objects = <StageObject>[];
    final rawObjects = j['objects'];
    if (rawObjects is List) {
      for (final o in rawObjects) {
        final m = _asMap(o, 'objects[]');
        final ow = _num(m, 'width');
        final od = _num(m, 'depth');
        if (ow <= 0 || od <= 0) {
          throw const FormatException('Ukuran benda harus lebih dari 0.');
        }
        objects.add(
          StageObject(
            id: _str(m, 'id'),
            kind: StageObjectKind.fromId(_str(m, 'type')),
            label: (m['label'] as String?) ?? '',
            x: _num(m, 'x'),
            y: _num(m, 'y'),
            width: ow,
            depth: od,
          ),
        );
      }
    }

    final width = _num(stage, 'width');
    final depth = _num(stage, 'depth');
    if (width <= 0 || depth <= 0) {
      throw const FormatException('Dimensi panggung harus lebih dari 0.');
    }

    return Project(
      id: _str(j, 'id'),
      title: _str(meta, 'title'),
      tradition: (meta['tradition'] as String?) ?? '',
      choreographer: (meta['choreographer'] as String?) ?? '',
      stageWidth: width,
      stageDepth: depth,
      bpm: _int(rhythm, 'bpm'),
      cycle: cycle,
      dancers: List.unmodifiable(dancers),
      keyframes: keyframes,
      createdAt: DateTime.parse(_str(meta, 'createdAt')).toUtc(),
      updatedAt: DateTime.parse(_str(meta, 'updatedAt')).toUtc(),
      objects: List.unmodifiable(objects),
    );
  }

  static String colorToHex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static int colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h, radix: 16);
    if (v == null || (h.length != 6 && h.length != 8)) {
      throw FormatException('Warna tidak valid: $hex');
    }
    return h.length == 6 ? 0xFF000000 | v : v;
  }

  // --- pembantu validasi ---------------------------------------------------

  static Map<String, dynamic> _map(Map<String, dynamic> j, String key) =>
      _asMap(j[key], key);

  static Map<String, dynamic> _asMap(Object? v, String key) {
    if (v is Map<String, dynamic>) return v;
    throw FormatException('Bagian "$key" hilang atau tidak valid.');
  }

  static List<dynamic> _list(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is List) return v;
    throw FormatException('Daftar "$key" hilang atau tidak valid.');
  }

  static String _str(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is String) return v;
    throw FormatException('Isian "$key" hilang atau bukan teks.');
  }

  static double _num(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is num && v.isFinite) return v.toDouble();
    throw FormatException('Isian "$key" hilang atau bukan angka.');
  }

  static int _int(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is int) return v;
    if (v is double && v == v.roundToDouble()) return v.toInt();
    throw FormatException('Isian "$key" hilang atau bukan bilangan bulat.');
  }
}
