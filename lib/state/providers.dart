import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/templates.dart';
import '../logic/timeline.dart';
import '../models/app_settings.dart';
import '../models/project.dart';
import '../services/storage.dart';

/// Di-override di `main()` setelah kotak Hive dibuka.
final projectStoreProvider = Provider<ProjectStore>(
  (ref) => throw UnimplementedError('projectStoreProvider belum di-override'),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider belum di-override'),
);

String newId() {
  final r = math.Random();
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rnd = r.nextInt(1 << 30).toRadixString(36);
  return '$ts$rnd';
}

// --- Daftar proyek -----------------------------------------------------------

class ProjectsNotifier extends Notifier<List<Project>> {
  @override
  List<Project> build() => ref.watch(projectStoreProvider).loadAll();

  ProjectStore get _store => ref.read(projectStoreProvider);

  Future<void> save(Project p) async {
    final store = _store;
    await store.save(p);
    if (ref.mounted) state = store.loadAll();
  }

  Future<void> delete(String id) async {
    final store = _store;
    await store.delete(id);
    if (ref.mounted) state = store.loadAll();
  }

  bool exists(String id) => _store.contains(id);
}

final projectsProvider = NotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

// --- Pengaturan --------------------------------------------------------------

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsStoreProvider).load();

  void update(AppSettings s) {
    state = s;
    ref.read(settingsStoreProvider).save(s);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// --- Editor proyek yang sedang dibuka ----------------------------------------

class EditorState {
  const EditorState(
    this.project, {
    this.history = const [],
    this.future = const [],
  });

  final Project project;

  /// Riwayat untuk Urungkan (terbaru di akhir).
  final List<Project> history;

  /// Keadaan yang baru saja diurungkan, untuk Ulangi (terbaru di akhir).
  final List<Project> future;

  bool get canUndo => history.isNotEmpty;
  bool get canRedo => future.isNotEmpty;
}

class EditorNotifier extends Notifier<EditorState?> {
  static const _maxHistory = 50;

  @override
  EditorState? build() => null;

  void open(Project p) => state = EditorState(p);

  void close() => state = null;

  Project get project => state!.project;

  void _apply(Project next, {bool record = true}) {
    final cur = state;
    if (cur == null) return;
    final stamped = next.copyWith(updatedAt: DateTime.now().toUtc());
    var history = cur.history;
    if (record) {
      history = [...history, cur.project];
      if (history.length > _maxHistory) {
        history = history.sublist(history.length - _maxHistory);
      }
    }
    state = EditorState(stamped, history: history);
    ref.read(projectsProvider.notifier).save(stamped);
  }

  void undo() {
    final cur = state;
    if (cur == null || cur.history.isEmpty) return;
    final prev = cur.history.last;
    state = EditorState(
      prev,
      history: cur.history.sublist(0, cur.history.length - 1),
      future: [...cur.future, cur.project],
    );
    ref.read(projectsProvider.notifier).save(prev);
  }

  void redo() {
    final cur = state;
    if (cur == null || cur.future.isEmpty) return;
    final next = cur.future.last;
    state = EditorState(
      next,
      history: [...cur.history, cur.project],
      future: cur.future.sublist(0, cur.future.length - 1),
    );
    ref.read(projectsProvider.notifier).save(next);
  }

  /// Keyframe di [beat], dibuat dari formasi hasil interpolasi bila belum ada.
  static Map<int, Map<String, DancerState>> _withKeyframe(Project p, int beat) {
    final kf = {
      for (final e in p.keyframes.entries) e.key: {...e.value},
    };
    kf.putIfAbsent(beat, () => Timeline.stateAt(p, beat.toDouble()));
    return kf;
  }

  /// Mengubah keadaan satu penari di ketukan [beat]. Jika ketukan itu belum
  /// punya keyframe, keyframe baru dibuat dari formasi saat itu untuk SEMUA
  /// penari, sehingga perpindahan tetap "berangkat bersama, sampai bersama".
  void updateDancerAt(
    int beat,
    String dancerId,
    DancerState Function(DancerState) f,
  ) {
    final p = project;
    final kf = _withKeyframe(p, beat);
    final cur = kf[beat]![dancerId];
    if (cur == null) return;
    final next = f(cur);
    kf[beat]![dancerId] = next.copyWith(
      x: next.x.clamp(0.0, p.stageWidth),
      y: next.y.clamp(0.0, p.stageDepth),
      facing: Timeline.normalizeAngle(next.facing),
    );
    _apply(p.copyWith(keyframes: kf));
  }

  void addKeyframe(int beat) {
    final p = project;
    if (p.keyframes.containsKey(beat)) return;
    _apply(p.copyWith(keyframes: _withKeyframe(p, beat)));
  }

  void removeKeyframe(int beat) {
    final p = project;
    if (beat == 1 || !p.keyframes.containsKey(beat)) return;
    final kf = {...p.keyframes}..remove(beat);
    _apply(p.copyWith(keyframes: kf));
  }

  /// Menambah penari generik di titik terlapang pada ketukan [beat]; posisi
  /// yang sama dipakai di semua keyframe.
  String? addDancer(int beat) {
    final p = project;
    if (p.dancers.length >= ProjectTemplates.maxDancers) return null;
    final id = 'p${newId()}';
    final n = p.dancers.length + 1;
    final dancer = Dancer(
      id: id,
      role: 'Penari $n',
      color: DancerPalette.forIndex(n - 1),
    );
    final here = Timeline.stateAt(p, beat.toDouble());
    final pos = _freeSpot(p, here.values.toList());
    final kf = {
      for (final e in p.keyframes.entries) e.key: {...e.value, id: pos},
    };
    if (kf.isEmpty) kf[1] = {id: pos};
    _apply(p.copyWith(dancers: [...p.dancers, dancer], keyframes: kf));
    return id;
  }

  static DancerState _freeSpot(Project p, List<DancerState> others) {
    var best = DancerState(x: p.stageWidth / 2, y: p.stageDepth / 2);
    var bestScore = -1.0;
    const step = 0.5;
    for (var y = step; y < p.stageDepth; y += step) {
      for (var x = step; x < p.stageWidth; x += step) {
        var minD = double.infinity;
        for (final o in others) {
          minD = math.min(
            minD,
            math.sqrt(math.pow(o.x - x, 2) + math.pow(o.y - y, 2)),
          );
        }
        // Utamakan titik lapang yang dekat tengah panggung.
        final centerPenalty =
            (math.pow(x - p.stageWidth / 2, 2) +
                math.pow(y - p.stageDepth / 2, 2)) *
            0.01;
        final score = math.min(minD, 2.0) - centerPenalty;
        if (score > bestScore) {
          bestScore = score;
          best = DancerState(x: x, y: y);
        }
      }
    }
    return best;
  }

  void removeDancer(String id) {
    final p = project;
    final kf = {
      for (final e in p.keyframes.entries) e.key: {...e.value}..remove(id),
    };
    _apply(
      p.copyWith(
        dancers: p.dancers.where((d) => d.id != id).toList(),
        keyframes: kf,
      ),
    );
  }

  void updateDancer(Dancer d) {
    final p = project;
    _apply(
      p.copyWith(dancers: [for (final x in p.dancers) x.id == d.id ? d : x]),
    );
  }

  void updateMeta({String? title, String? tradition, String? choreographer}) {
    _apply(
      project.copyWith(
        title: title,
        tradition: tradition,
        choreographer: choreographer,
      ),
    );
  }

  /// Mengubah ukuran panggung.
  ///
  /// [scale] = true: pola lantai direnggangkan/dirapatkan sebanding per sumbu
  /// (formasi dari sanggar kecil mengisi panggung besar dengan proporsi sama).
  /// [scale] = false: jarak asli dipertahankan, formasi hanya dipusatkan.
  /// Benda panggung ikut berpindah dengan aturan yang sama (ukurannya tetap).
  void setStage(double width, double depth, {bool scale = true}) {
    final p = project;
    if (width == p.stageWidth && depth == p.stageDepth) return;
    _apply(resizeStage(p, width, depth, scale: scale));
  }

  static Project resizeStage(
    Project p,
    double width,
    double depth, {
    required bool scale,
  }) {
    double r(double v) => (v * 100).roundToDouble() / 100;
    double mx(double x) => r(
      (scale ? x * width / p.stageWidth : x + (width - p.stageWidth) / 2).clamp(
        0.0,
        width,
      ),
    );
    double my(double y) => r(
      (scale ? y * depth / p.stageDepth : y + (depth - p.stageDepth) / 2).clamp(
        0.0,
        depth,
      ),
    );
    return p.copyWith(
      stageWidth: width,
      stageDepth: depth,
      keyframes: {
        for (final e in p.keyframes.entries)
          e.key: {
            for (final s in e.value.entries)
              s.key: s.value.copyWith(x: mx(s.value.x), y: my(s.value.y)),
          },
      },
      objects: [for (final o in p.objects) o.copyWith(x: mx(o.x), y: my(o.y))],
    );
  }

  // --- benda panggung & properti tari ---------------------------------------

  String addObject({
    required StageObjectKind kind,
    required String label,
    required double width,
    required double depth,
  }) {
    final p = project;
    final id = 'o${newId()}';
    final w = width.clamp(0.2, p.stageWidth);
    final d = depth.clamp(0.2, p.stageDepth);
    // Benda baru diletakkan di sudut belakang-kiri, properti di tengah depan,
    // digeser sedikit bila sudah ada benda lain di titik itu.
    final n = p.objects.length;
    final x = kind == StageObjectKind.obstacle
        ? (w / 2 + 0.2 + 0.4 * (n % 4)).clamp(w / 2, p.stageWidth - w / 2)
        : (p.stageWidth / 2 + 0.6 * (n % 3 - 1)).clamp(0.0, p.stageWidth);
    final y = kind == StageObjectKind.obstacle
        ? (p.stageDepth - d / 2 - 0.2).clamp(d / 2, p.stageDepth - d / 2)
        : (0.6).clamp(0.0, p.stageDepth);
    _apply(
      p.copyWith(
        objects: [
          ...p.objects,
          StageObject(
            id: id,
            kind: kind,
            label: label,
            x: x.toDouble(),
            y: y.toDouble(),
            width: w,
            depth: d,
          ),
        ],
      ),
    );
    return id;
  }

  void updateObject(StageObject o) {
    final p = project;
    final fixed = o.copyWith(
      x: o.x.clamp(0.0, p.stageWidth),
      y: o.y.clamp(0.0, p.stageDepth),
    );
    _apply(
      p.copyWith(
        objects: [for (final x in p.objects) x.id == o.id ? fixed : x],
      ),
    );
  }

  void removeObject(String id) {
    final p = project;
    _apply(p.copyWith(objects: p.objects.where((o) => o.id != id).toList()));
  }

  void setBpm(int bpm) => _apply(project.copyWith(bpm: bpm.clamp(10, 200)));
}

final editorProvider = NotifierProvider<EditorNotifier, EditorState?>(
  EditorNotifier.new,
);
