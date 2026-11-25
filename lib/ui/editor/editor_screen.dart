import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/collision.dart';
import '../../logic/describe.dart';
import '../../logic/timeline.dart';
import '../../models/pose.dart';
import '../../models/project.dart';
import '../../services/sound_service.dart';
import '../../state/providers.dart';
import '../pose_glyph.dart';
import '../sightline/sightline_view.dart';
import '../stage/stage_canvas.dart';
import '../stage/stage_painter.dart';
import '../theme.dart';
import 'beat_strip.dart';
import 'project_drawer.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin {
  final _playhead = ValueNotifier<double>(1);
  final _drag = ValueNotifier<DragOverride?>(null);
  final _boundaryKey = GlobalKey();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final Ticker _ticker;

  bool _playing = false;
  bool _sightline = false;
  Duration _last = Duration.zero;
  int _lastBeatIndex = 0;
  String? _selectedId;
  String? _selectedObjectId;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    SoundService.instance.init();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _playhead.dispose();
    _drag.dispose();
    super.dispose();
  }

  Project? get _project => ref.read(editorProvider)?.project;

  int get _beats => _project?.cycle.beats ?? 16;

  int get _beat => Timeline.beatAt(_playhead.value, _beats);

  // --- pemutaran ----------------------------------------------------------------

  void _togglePlay() => _playing ? _pause() : _play();

  void _play() {
    final p = _project;
    if (p == null) return;
    _drag.value = null;
    setState(() => _playing = true);
    _last = Duration.zero;
    _lastBeatIndex = _playhead.value.floor();
    _soundForBeat(Timeline.beatAt(_playhead.value, p.cycle.beats));
    _ticker.start();
  }

  void _pause() {
    if (!_playing) return;
    _ticker.stop();
    _playhead.value = _playhead.value.floorToDouble();
    setState(() => _playing = false);
  }

  void _onTick(Duration elapsed) {
    final p = _project;
    if (p == null) return;
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final beats = p.cycle.beats;
    var next = _playhead.value + dt * p.bpm / 60;
    if (next >= beats + 1) next = Timeline.wrap(next, beats);
    final idx = next.floor();
    if (idx != _lastBeatIndex) {
      _lastBeatIndex = idx;
      _soundForBeat(Timeline.beatAt(next, beats));
    }
    _playhead.value = next;
  }

  void _soundForBeat(int beat) {
    final p = _project;
    if (p == null || ref.read(settingsProvider).muted) return;
    SoundService.instance.playBeat(
      kenong: p.cycle.isKenong(beat),
      gong: p.cycle.isGong(beat),
    );
  }

  void _seek(int beat) {
    _pause();
    _playhead.value = beat.clamp(1, _beats).toDouble();
    setState(() {});
  }

  void _step(int delta) {
    var b = _beat + delta;
    if (b < 1) b = _beats;
    if (b > _beats) b = 1;
    _seek(b);
  }

  // --- ekspor ---------------------------------------------------------------------

  RenderRepaintBoundary? get _boundary =>
      _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProvider);
    final settings = ref.watch(settingsProvider);
    if (editor == null) {
      return const Scaffold(
        body: Center(child: Text('Proyek tidak ditemukan')),
      );
    }
    final p = editor.project;
    final editable = !_playing;
    final notifier = ref.read(editorProvider.notifier);
    final canEdit = !_sightline && !_playing;
    final selectedDancer = canEdit && _selectedId != null
        ? p.dancerById(_selectedId!)
        : null;
    final selectedObject = canEdit
        ? p.objects.where((o) => o.id == _selectedObjectId).firstOrNull
        : null;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _ticker.stop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawerEnableOpenDragGesture: false,
        endDrawer: ProjectDrawer(
          boundary: () => _boundary,
          currentBeat: _beat,
          onBeforeExport: () {
            _pause();
            setState(() {
              _selectedId = null;
              _selectedObjectId = null;
              _sightline = false;
            });
          },
        ),
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                '${fmtSize(p.stageWidth)} × ${fmtSize(p.stageDepth)} m · '
                '${p.dancers.length} penari',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: LColors.muted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Urungkan',
              onPressed: editor.canUndo
                  ? () {
                      _pause();
                      notifier.undo();
                    }
                  : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Ulangi',
              onPressed: editor.canRedo
                  ? () {
                      _pause();
                      notifier.redo();
                    }
                  : null,
              icon: const Icon(Icons.redo),
            ),
            IconButton(
              tooltip: 'Pengaturan proyek',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _Hud(
                project: p,
                playhead: _playhead,
                sightline: _sightline,
                onView: (v) => setState(() => _sightline = v),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _sightline
                          ? SightlineView(
                              project: p,
                              playhead: _playhead,
                              settings: settings,
                            )
                          : RepaintBoundary(
                              key: _boundaryKey,
                              child: ColoredBox(
                                color: LColors.base,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: StageCanvas(
                                    project: p,
                                    playhead: _playhead,
                                    drag: _drag,
                                    settings: settings,
                                    selectedId: _selectedId,
                                    selectedObjectId: _selectedObjectId,
                                    editable: editable,
                                    onInteract: _pause,
                                    onSelect: (id) =>
                                        setState(() => _selectedId = id),
                                    onSelectObject: (id) =>
                                        setState(() => _selectedObjectId = id),
                                    onMove: (id, x, y) =>
                                        notifier.updateDancerAt(
                                          _beat,
                                          id,
                                          (s) => s.copyWith(x: x, y: y),
                                        ),
                                    onRotate: (id, f) =>
                                        notifier.updateDancerAt(
                                          _beat,
                                          id,
                                          (s) => s.copyWith(facing: f),
                                        ),
                                    onMoveObject: (id, x, y) {
                                      for (final o in p.objects) {
                                        if (o.id == id) {
                                          notifier.updateObject(
                                            o.copyWith(x: x, y: y),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                    ),
                    // Peringatan hanya muncul saat ada masalah ruang.
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 2,
                      child: IgnorePointer(
                        child: _Warning(
                          project: p,
                          playhead: _playhead,
                          drag: _drag,
                          threshold: settings.collisionThreshold,
                        ),
                      ),
                    ),
                    if (canEdit && p.dancers.isEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: Center(
                          child: FilledButton.icon(
                            onPressed: () {
                              final id = notifier.addDancer(_beat);
                              if (id != null) setState(() => _selectedId = id);
                            },
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Tambah penari'),
                          ),
                        ),
                      ),
                    // Panel menumpang di atas denah agar ukuran kanvas tetap
                    // (titik penari tidak bergeser saat seleksi berganti).
                    if (selectedDancer != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _DancerPanel(
                          project: p,
                          dancer: selectedDancer,
                          beat: _beat,
                        ),
                      )
                    else if (selectedObject != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _ObjectPanel(
                          object: selectedObject,
                          onDelete: () {
                            notifier.removeObject(selectedObject.id);
                            setState(() => _selectedObjectId = null);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              _Dock(
                project: p,
                playhead: _playhead,
                playing: _playing,
                muted: settings.muted,
                beat: _beat,
                onTogglePlay: _togglePlay,
                onStep: _step,
                onSeek: _seek,
                onScrub: (v) {
                  if (_playing) _pause();
                  _playhead.value = v;
                },
                onScrubEnd: () {
                  _playhead.value = _playhead.value.floorToDouble().clamp(
                    1,
                    _beats.toDouble(),
                  );
                  setState(() {});
                },
                onKeyframe: () {
                  if (p.keyframes.containsKey(_beat)) {
                    notifier.removeKeyframe(_beat);
                  } else {
                    notifier.addKeyframe(_beat);
                  }
                },
                onBpm: () => _editBpm(p),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lembar "Tempo & bunyi": BPM dan sakelar bunyi ketukan.
  Future<void> _editBpm(Project p) async {
    _pause();
    var bpm = p.bpm.toDouble();
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: LColors.card,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tempo & bunyi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bpm.round()} BPM · satu gongan '
                  '${fmtNum(16 * 60 / bpm, 0)} detik',
                  style: const TextStyle(color: LColors.muted),
                ),
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Kurangi tempo',
                      onPressed: () =>
                          setS(() => bpm = (bpm - 1).clamp(10, 200)),
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Slider(
                        value: bpm,
                        min: 10,
                        max: 200,
                        divisions: 190,
                        label: '${bpm.round()}',
                        onChanged: (v) => setS(() => bpm = v),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Tambah tempo',
                      onPressed: () =>
                          setS(() => bpm = (bpm + 1).clamp(10, 200)),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final s = ref.watch(settingsProvider);
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bunyi ketukan'),
                      value: !s.muted,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .update(s.copyWith(muted: !v)),
                    );
                  },
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, bpm.round()),
                    child: const Text('Simpan tempo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && result != p.bpm) {
      ref.read(editorProvider.notifier).setBpm(result);
    }
  }
}

// --- Pilihan tampilan: denah 2D atau 3D ---------------------------------------------

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.sightline, required this.onChanged});

  final bool sightline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, IconData icon, bool value) {
      final on = sightline == value;
      return Semantics(
        button: true,
        selected: on,
        label: 'Tampilan $label',
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: on ? null : () => onChanged(value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: on ? LColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: on ? LColors.base : LColors.muted),
                const SizedBox(width: 5),
                ExcludeSemantics(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: on ? LColors.base : LColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: LColors.elevated,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg('Denah', Icons.grid_on_rounded, false),
            seg('3D', Icons.view_in_ar_rounded, true),
          ],
        ),
      ),
    );
  }
}

// --- Bilah status: ketukan + pilihan tampilan ----------------------------------------

class _Hud extends StatelessWidget {
  const _Hud({
    required this.project,
    required this.playhead,
    required this.sightline,
    required this.onView,
  });

  final Project project;
  final ValueNotifier<double> playhead;
  final bool sightline;
  final ValueChanged<bool> onView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: ValueListenableBuilder<double>(
              valueListenable: playhead,
              builder: (context, p, _) {
                final beat = Timeline.beatAt(p, project.cycle.beats);
                final onKey =
                    p == p.floorToDouble() &&
                    project.keyframes.containsKey(beat);
                var accent = '';
                if (project.cycle.isKenong(beat)) accent = ' · Kenong';
                if (project.cycle.isGong(beat)) accent = ' · Gong';
                return _Pill(
                  color: LColors.elevated,
                  child: Text.rich(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Ketukan $beat/${project.cycle.beats}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text: accent,
                          style: const TextStyle(
                            color: LColors.pink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: onKey ? '  ◆' : '',
                          style: const TextStyle(
                            color: LColors.accent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          _ViewToggle(sightline: sightline, onChanged: onView),
        ],
      ),
    );
  }
}

/// Peringatan ruang; kosong saat semua aman.
class _Warning extends StatelessWidget {
  const _Warning({
    required this.project,
    required this.playhead,
    required this.drag,
    required this.threshold,
  });

  final Project project;
  final ValueNotifier<double> playhead;
  final ValueNotifier<DragOverride?> drag;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([playhead, drag]),
      builder: (context, _) {
        final states = effectiveStates(project, playhead.value, drag.value);
        final col = CollisionDetector.find(states, threshold);
        final blocked = ObstacleDetector.find(
          states,
          effectiveObjects(project, drag.value),
        );
        String? warning;
        if (col.isNotEmpty) {
          final more = col.length + blocked.length - 1;
          warning =
              '${_name(col.first.a)}–${_name(col.first.b)} '
              '${fmtMeters(col.first.distance)}'
              '${more > 0 ? ' (+$more)' : ''}';
        } else if (blocked.isNotEmpty) {
          final h = blocked.first;
          final more = blocked.length - 1;
          warning =
              '${_name(h.dancerId)} di area ${_object(h.objectId)}'
              '${more > 0 ? ' (+$more)' : ''}';
        }
        if (warning == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: _Pill(
            color: LColors.danger,
            child: Text(
              '⚠ $warning',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  String _name(String id) => project.dancerById(id)?.role ?? '?';

  String _object(String id) {
    for (final o in project.objects) {
      if (o.id == id) return o.label.isEmpty ? o.kind.label : o.label;
    }
    return '?';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}

// --- Panel penari / benda terpilih (menumpang di atas denah) -------------------------

BoxDecoration _panelDecoration() => BoxDecoration(
  color: LColors.card,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: LColors.border),
  boxShadow: const [
    BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
  ],
);

class _DancerPanel extends ConsumerWidget {
  const _DancerPanel({
    required this.project,
    required this.dancer,
    required this.beat,
  });

  final Project project;
  final Dancer dancer;
  final int beat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = dancer;
    final s = Timeline.stateAt(project, beat.toDouble())[d.id];
    if (s == null) return const SizedBox.shrink();
    final n = ref.read(editorProvider.notifier);

    void update(DancerState Function(DancerState) f) =>
        n.updateDancerAt(beat, d.id, f);

    return Container(
      height: 124,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Color(d.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      Describe.dancer(s, project),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Putar kiri 45°',
                onPressed: () =>
                    update((s) => s.copyWith(facing: s.facing + 45)),
                icon: const Icon(Icons.rotate_left),
              ),
              IconButton(
                tooltip: 'Putar kanan 45°',
                onPressed: () =>
                    update((s) => s.copyWith(facing: s.facing - 45)),
                icon: const Icon(Icons.rotate_right),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  for (final pose in Pose.values)
                    Expanded(
                      child: _PoseTile(
                        pose: pose,
                        selected: s.pose == pose,
                        onTap: () => update((s) => s.copyWith(pose: pose)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectPanel extends StatelessWidget {
  const _ObjectPanel({required this.object, required this.onDelete});

  final StageObject object;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final o = object;
    final name = o.label.isEmpty ? o.kind.label : o.label;
    final obstacle = o.kind == StageObjectKind.obstacle;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Icon(
            obstacle ? Icons.block : Icons.category_outlined,
            color: obstacle ? LColors.muted : LColors.pink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${o.kind.label} · ${fmtNum(o.width)} × ${fmtNum(o.depth)} m',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: LColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus $name',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

/// Tombol pose: sosok kecil + nama, supaya level tubuh langsung terbayang.
class _PoseTile extends StatelessWidget {
  const _PoseTile({
    required this.pose,
    required this.selected,
    required this.onTap,
  });

  final Pose pose;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? LColors.base : LColors.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: '${pose.label}: ${pose.plain}',
        child: Material(
          color: selected ? LColors.accent : LColors.elevated,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Semantics(
              selected: selected,
              button: true,
              label: 'Pose ${pose.label}, ${pose.plain}',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PoseGlyph(pose: pose, color: fg, size: 30),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        pose.label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Dok linimasa bawah ------------------------------------------------------------

class _Dock extends StatelessWidget {
  const _Dock({
    required this.project,
    required this.playhead,
    required this.playing,
    required this.muted,
    required this.beat,
    required this.onTogglePlay,
    required this.onStep,
    required this.onSeek,
    required this.onScrub,
    required this.onScrubEnd,
    required this.onKeyframe,
    required this.onBpm,
  });

  final Project project;
  final ValueNotifier<double> playhead;
  final bool playing;
  final bool muted;
  final int beat;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onStep;
  final ValueChanged<int> onSeek;
  final ValueChanged<double> onScrub;
  final VoidCallback onScrubEnd;
  final VoidCallback onKeyframe;
  final VoidCallback onBpm;

  @override
  Widget build(BuildContext context) {
    final hasKey = project.keyframes.containsKey(beat);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: LColors.deep,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BeatStrip(
            project: project,
            playhead: playhead,
            onSeek: onSeek,
            onScrub: onScrub,
            onScrubEnd: onScrubEnd,
          ),
          const SizedBox(height: 6),
          // Sisi kiri dan kanan sama lebar, jadi tombol putar persis di tengah.
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: onBpm,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Semantics(
                        label:
                            'Tempo ${project.bpm} BPM, bunyi '
                            '${muted ? 'mati' : 'nyala'}',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              muted ? Icons.volume_off : Icons.volume_up,
                              size: 18,
                              color: muted ? LColors.dimmed : LColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${project.bpm}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: LColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ketukan sebelumnya',
                      onPressed: () => onStep(-1),
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: IconButton.filled(
                    tooltip: playing ? 'Jeda' : 'Putar',
                    style: IconButton.styleFrom(
                      backgroundColor: LColors.accent,
                      foregroundColor: LColors.base,
                    ),
                    onPressed: onTogglePlay,
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 34,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Ketukan berikutnya',
                      onPressed: () => onStep(1),
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                    IconButton(
                      tooltip: hasKey
                          ? (beat == 1
                                ? 'Formasi awal tidak bisa dihapus'
                                : 'Hapus formasi ketukan $beat')
                          : 'Simpan formasi di ketukan $beat',
                      onPressed: playing || (hasKey && beat == 1)
                          ? null
                          : onKeyframe,
                      icon: Icon(
                        hasKey
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
