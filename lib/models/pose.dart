/// Lima level pose penari tradisi, dari yang tertinggi ke terendah.
///
/// Tinggi kepala bawaan (meter) dipakai untuk tampilan sightline dan bisa
/// diubah pengguna di Pengaturan.
enum Pose {
  ngadeg('ngadeg', 'Ngadeg', 'berdiri', 'N', 1.6),
  mendhak('mendhak', 'Mendhak', 'merendah', 'M', 1.3),
  jengkeng('jengkeng', 'Jengkeng', 'berlutut satu kaki', 'J', 1.0),
  timpuh('timpuh', 'Timpuh', 'bersimpuh', 'T', 0.8),
  sila('sila', 'Sila', 'bersila', 'S', 0.8);

  const Pose(this.id, this.label, this.plain, this.short, this.defaultHeight);

  /// Padanan sehari-hari, mis. "berlutut satu kaki".
  final String plain;

  /// Pengenal stabil yang ditulis ke berkas `.lenggang`.
  final String id;

  /// Nama yang ditampilkan di UI.
  final String label;

  /// Satu huruf untuk lencana di titik penari.
  final String short;

  /// Tinggi kepala bawaan dalam meter.
  final double defaultHeight;

  static Pose fromId(String id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    throw FormatException('Pose tidak dikenal: "$id"');
  }
}
