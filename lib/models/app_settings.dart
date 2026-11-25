import 'pose.dart';

/// Preferensi aplikasi (disimpan di Hive).
class AppSettings {
  const AppSettings({
    this.collisionThreshold = 0.8,
    this.sampurRadius = 1.2,
    this.showSampur = true,
    this.muted = false,
    this.poseHeights = const {},
    this.scaleFormation = true,
    this.eyeHeight = 1.2,
  });

  /// Ambang jarak aman antarpusat penari (meter).
  final double collisionThreshold;

  /// Radius lingkaran panduan sampur (meter).
  final double sampurRadius;

  final bool showSampur;
  final bool muted;

  /// Tinggi kepala per pose (meter); yang tidak ada memakai bawaan.
  final Map<Pose, double> poseHeights;

  /// Saat ukuran panggung diubah, formasi ikut diskalakan sebanding.
  /// Bila `false`, jarak asli dipertahankan (formasi hanya dipusatkan).
  final bool scaleFormation;

  /// Tinggi mata penonton (meter) untuk sightline.
  final double eyeHeight;

  double heightOf(Pose p) => poseHeights[p] ?? p.defaultHeight;

  AppSettings copyWith({
    double? collisionThreshold,
    double? sampurRadius,
    bool? showSampur,
    bool? muted,
    Map<Pose, double>? poseHeights,
    bool? scaleFormation,
    double? eyeHeight,
  }) => AppSettings(
    collisionThreshold: collisionThreshold ?? this.collisionThreshold,
    sampurRadius: sampurRadius ?? this.sampurRadius,
    showSampur: showSampur ?? this.showSampur,
    muted: muted ?? this.muted,
    poseHeights: poseHeights ?? this.poseHeights,
    scaleFormation: scaleFormation ?? this.scaleFormation,
    eyeHeight: eyeHeight ?? this.eyeHeight,
  );

  Map<String, Object?> toJson() => {
    'collisionThreshold': collisionThreshold,
    'sampurRadius': sampurRadius,
    'showSampur': showSampur,
    'muted': muted,
    'poseHeights': {for (final e in poseHeights.entries) e.key.id: e.value},
    'scaleFormation': scaleFormation,
    'eyeHeight': eyeHeight,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    final heights = <Pose, double>{};
    final ph = j['poseHeights'];
    if (ph is Map) {
      for (final p in Pose.values) {
        final v = ph[p.id];
        if (v is num) heights[p] = v.toDouble();
      }
    }
    const def = AppSettings();
    return AppSettings(
      collisionThreshold: d('collisionThreshold') ?? def.collisionThreshold,
      sampurRadius: d('sampurRadius') ?? def.sampurRadius,
      showSampur: (j['showSampur'] as bool?) ?? def.showSampur,
      muted: (j['muted'] as bool?) ?? def.muted,
      poseHeights: heights,
      scaleFormation: (j['scaleFormation'] as bool?) ?? def.scaleFormation,
      eyeHeight: d('eyeHeight') ?? def.eyeHeight,
    );
  }
}
