import 'pose.dart';

/// Jenis siklus gongan. MVP hanya mendukung Ketawang 16 ketukan.
enum CycleType {
  ketawang16('ketawang16', 'Ketawang', 16, [8], [16]);

  const CycleType(
    this.id,
    this.label,
    this.beats,
    this.kenongBeats,
    this.gongBeats,
  );

  final String id;
  final String label;
  final int beats;
  final List<int> kenongBeats;
  final List<int> gongBeats;

  bool isKenong(int beat) => kenongBeats.contains(beat);
  bool isGong(int beat) => gongBeats.contains(beat);

  static CycleType fromId(String id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    throw FormatException('Tipe siklus tidak didukung: "$id"');
  }
}

/// Posisi, arah hadap, dan pose satu penari pada satu ketukan.
///
/// Koordinat dalam meter dengan titik asal di sudut depan-kiri panggung
/// (dilihat dari penonton): `x` bertambah ke kanan, `y` bertambah ke belakang
/// (menjauhi penonton).
///
/// `facing` dalam derajat [0, 360): 0 = menghadap penonton, 90 = menghadap
/// kanan (dilihat dari penonton), 180 = membelakangi penonton, 270 = kiri.
class DancerState {
  const DancerState({
    required this.x,
    required this.y,
    this.facing = 0,
    this.pose = Pose.ngadeg,
  });

  final double x;
  final double y;
  final double facing;
  final Pose pose;

  DancerState copyWith({double? x, double? y, double? facing, Pose? pose}) =>
      DancerState(
        x: x ?? this.x,
        y: y ?? this.y,
        facing: facing ?? this.facing,
        pose: pose ?? this.pose,
      );

  @override
  bool operator ==(Object other) =>
      other is DancerState &&
      other.x == x &&
      other.y == y &&
      other.facing == facing &&
      other.pose == pose;

  @override
  int get hashCode => Object.hash(x, y, facing, pose);

  @override
  String toString() =>
      'DancerState(x: $x, y: $y, facing: $facing, pose: ${pose.id})';
}

/// Identitas penari: peran tradisi dan warna penanda.
class Dancer {
  const Dancer({
    required this.id,
    required this.role,
    required this.color,
    this.name = '',
  });

  final String id;

  /// Peran tradisi, mis. Batak, Gulu, Dhadha, Buncit, atau "Penari".
  final String role;

  /// Nama penari (opsional), mis. "Dewi".
  final String name;

  /// Warna ARGB 32-bit.
  final int color;

  Dancer copyWith({String? role, String? name, int? color}) => Dancer(
    id: id,
    role: role ?? this.role,
    name: name ?? this.name,
    color: color ?? this.color,
  );

  /// Kode pendek di dalam titik penari.
  String get code {
    final r = role.trim();
    const known = {'Batak': 'Bt', 'Gulu': 'Gl', 'Dhadha': 'Dh', 'Buncit': 'Bc'};
    if (known.containsKey(r)) return known[r]!;
    if (r.isEmpty) return '?';
    final m = RegExp(r'(\d+)$').firstMatch(r);
    if (m != null) return 'P${m.group(1)}';
    return r.length == 1 ? r.toUpperCase() : r.substring(0, 2);
  }

  String get displayName =>
      name.trim().isEmpty ? role : '$role (${name.trim()})';

  @override
  bool operator ==(Object other) =>
      other is Dancer &&
      other.id == id &&
      other.role == role &&
      other.name == name &&
      other.color == color;

  @override
  int get hashCode => Object.hash(id, role, name, color);
}

/// Jenis benda yang dipetakan di denah.
enum StageObjectKind {
  /// Benda panggung (speaker, monitor, tiang, gamelan): areanya terhalang,
  /// penari yang masuk memicu peringatan.
  obstacle('obstacle', 'Benda panggung'),

  /// Properti tari yang diletakkan di lantai: hanya penanda.
  prop('prop', 'Properti tari');

  const StageObjectKind(this.id, this.label);

  final String id;
  final String label;

  static StageObjectKind fromId(String id) {
    for (final k in values) {
      if (k.id == id) return k;
    }
    throw FormatException('Jenis benda tidak dikenal: "$id"');
  }
}

/// Benda panggung atau properti tari berbentuk persegi panjang, diam
/// sepanjang gongan. `x`,`y` adalah pusatnya (meter).
class StageObject {
  const StageObject({
    required this.id,
    required this.kind,
    required this.label,
    required this.x,
    required this.y,
    required this.width,
    required this.depth,
  });

  final String id;
  final StageObjectKind kind;
  final String label;
  final double x;
  final double y;

  /// Ukuran kiri–kanan (meter).
  final double width;

  /// Ukuran depan–belakang (meter).
  final double depth;

  double get left => x - width / 2;
  double get right => x + width / 2;
  double get front => y - depth / 2;
  double get back => y + depth / 2;

  StageObject copyWith({
    StageObjectKind? kind,
    String? label,
    double? x,
    double? y,
    double? width,
    double? depth,
  }) => StageObject(
    id: id,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    depth: depth ?? this.depth,
  );

  @override
  bool operator ==(Object other) =>
      other is StageObject &&
      other.id == id &&
      other.kind == kind &&
      other.label == label &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(id, kind, label, x, y, width, depth);
}

/// Satu proyek tata panggung.
class Project {
  Project({
    required this.id,
    required this.title,
    required this.tradition,
    required this.choreographer,
    required this.stageWidth,
    required this.stageDepth,
    required this.bpm,
    required this.cycle,
    required this.dancers,
    required Map<int, Map<String, DancerState>> keyframes,
    required this.createdAt,
    required this.updatedAt,
    this.objects = const [],
  }) : keyframes = Map.unmodifiable({
         for (final k in (keyframes.keys.toList()..sort()))
           k: Map<String, DancerState>.unmodifiable(keyframes[k]!),
       });

  final String id;

  /// Nama tarian / proyek.
  final String title;

  /// Gaya tradisi, mis. "Jawa – Surakarta".
  final String tradition;

  /// Penata tari.
  final String choreographer;

  /// Panjang panggung kiri–kanan (meter).
  final double stageWidth;

  /// Lebar/kedalaman panggung depan–belakang (meter).
  final double stageDepth;

  final int bpm;
  final CycleType cycle;
  final List<Dancer> dancers;

  /// Keyframe formasi: ketukan (1..beats) -> id penari -> keadaan.
  /// Kunci selalu terurut naik.
  final Map<int, Map<String, DancerState>> keyframes;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Benda panggung dan properti tari yang dipetakan di denah.
  final List<StageObject> objects;

  List<int> get keyframeBeats => keyframes.keys.toList();

  Dancer? dancerById(String id) {
    for (final d in dancers) {
      if (d.id == id) return d;
    }
    return null;
  }

  Project copyWith({
    String? title,
    String? tradition,
    String? choreographer,
    double? stageWidth,
    double? stageDepth,
    int? bpm,
    CycleType? cycle,
    List<Dancer>? dancers,
    Map<int, Map<String, DancerState>>? keyframes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
    List<StageObject>? objects,
  }) => Project(
    id: id ?? this.id,
    title: title ?? this.title,
    tradition: tradition ?? this.tradition,
    choreographer: choreographer ?? this.choreographer,
    stageWidth: stageWidth ?? this.stageWidth,
    stageDepth: stageDepth ?? this.stageDepth,
    bpm: bpm ?? this.bpm,
    cycle: cycle ?? this.cycle,
    dancers: List.unmodifiable(dancers ?? this.dancers),
    keyframes: keyframes ?? this.keyframes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    objects: List.unmodifiable(objects ?? this.objects),
  );
}
