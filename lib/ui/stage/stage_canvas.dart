import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/timeline.dart';
import '../../models/app_settings.dart';
import '../../models/project.dart';
import 'stage_painter.dart';

/// Kanvas panggung interaktif: ketuk untuk memilih, geser untuk memindah,
/// tarik tuas kuning untuk memutar arah hadap (snap 45°).
class StageCanvas extends StatefulWidget {
  const StageCanvas({
    super.key,
    required this.project,
    required this.playhead,
    required this.drag,
    required this.settings,
    required this.selectedId,
    required this.selectedObjectId,
    required this.editable,
    required this.onSelect,
    required this.onSelectObject,
    required this.onMove,
    required this.onRotate,
    required this.onMoveObject,
    required this.onInteract,
  });

  final Project project;
  final ValueNotifier<double> playhead;
  final ValueNotifier<DragOverride?> drag;
  final AppSettings settings;
  final String? selectedId;
  final String? selectedObjectId;
  final bool editable;
  final ValueChanged<String?> onSelect;

  /// Benda panggung/properti diketuk (atau `null` saat seleksi dilepas).
  final ValueChanged<String?> onSelectObject;
  final void Function(String id, double x, double y) onMove;
  final void Function(String id, double facing) onRotate;

  /// Benda panggung/properti selesai digeser ke pusat baru (meter).
  final void Function(String id, double x, double y) onMoveObject;

  /// Dipanggil saat pengguna menyentuh kanvas (mis. untuk menjeda pemutaran).
  final VoidCallback onInteract;

  @override
  State<StageCanvas> createState() => _StageCanvasState();
}

enum _Mode { none, move, rotate, moveObject }

class _StageCanvasState extends State<StageCanvas> {
  StageGeometry? _geo;
  _Mode _mode = _Mode.none;
  String? _dragId;
  Offset _grab = Offset.zero;

  Map<String, DancerState> get _states =>
      Timeline.stateAt(widget.project, widget.playhead.value);

  String? _hitDancer(Offset pos) {
    final g = _geo;
    if (g == null) return null;
    String? best;
    var bestD = StageGeometry.hitRadius;
    final states = _states;
    // Penari terakhir digambar paling atas -> diperiksa dengan prioritas sama,
    // dipilih yang pusatnya paling dekat dengan jari.
    for (final d in widget.project.dancers) {
      final s = states[d.id];
      if (s == null) continue;
      final dist = (g.toScreen(s.x, s.y) - pos).distance;
      if (dist <= bestD) {
        bestD = dist;
        best = d.id;
      }
    }
    return best;
  }

  /// Benda di bawah jari; area sentuhnya minimal 48 dp.
  StageObject? _hitObject(Offset pos) {
    final g = _geo;
    if (g == null) return null;
    for (final o in widget.project.objects.reversed) {
      final c = g.toScreen(o.x, o.y);
      final hw = (o.width * g.scale / 2).clamp(24.0, double.infinity);
      final hh = (o.depth * g.scale / 2).clamp(24.0, double.infinity);
      if ((pos.dx - c.dx).abs() <= hw && (pos.dy - c.dy).abs() <= hh) return o;
    }
    return null;
  }

  bool _hitHandle(Offset pos) {
    final g = _geo;
    final id = widget.selectedId;
    if (g == null || id == null) return false;
    final s = _states[id];
    if (s == null) return false;
    return (g.handlePosition(s) - pos).distance <= 26;
  }

  void _onPanStart(DragStartDetails d) {
    widget.onInteract();
    if (!widget.editable) return;
    final pos = d.localPosition;
    if (_hitHandle(pos)) {
      _mode = _Mode.rotate;
      _dragId = widget.selectedId;
      return;
    }
    final id = _hitDancer(pos);
    if (id == null) {
      final o = _hitObject(pos);
      if (o == null) {
        _mode = _Mode.none;
        return;
      }
      _mode = _Mode.moveObject;
      _dragId = o.id;
      widget.onSelect(null);
      widget.onSelectObject(o.id);
      _grab = _geo!.toScreen(o.x, o.y) - pos;
      widget.drag.value = DragOverride(o.id, x: o.x, y: o.y);
      return;
    }
    final s = _states[id]!;
    _mode = _Mode.move;
    _dragId = id;
    _grab = _geo!.toScreen(s.x, s.y) - pos;
    if (widget.selectedId != id) widget.onSelect(id);
    if (widget.selectedObjectId != null) widget.onSelectObject(null);
    widget.drag.value = DragOverride(id, x: s.x, y: s.y);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final g = _geo;
    final id = _dragId;
    if (g == null || id == null) return;
    final p = widget.project;
    if (_mode == _Mode.move) {
      final (x, y) = g.toStage(d.localPosition + _grab);
      widget.drag.value = DragOverride(
        id,
        x: _round(x.clamp(0.0, p.stageWidth)),
        y: _round(y.clamp(0.0, p.stageDepth)),
      );
    } else if (_mode == _Mode.moveObject) {
      StageObject? o;
      for (final x in p.objects) {
        if (x.id == id) o = x;
      }
      if (o == null) return;
      final (x, y) = g.toStage(d.localPosition + _grab);
      final hx = (o.width / 2).clamp(0.0, p.stageWidth / 2);
      final hy = (o.depth / 2).clamp(0.0, p.stageDepth / 2);
      widget.drag.value = DragOverride(
        id,
        x: _round(x.clamp(hx, p.stageWidth - hx)),
        y: _round(y.clamp(hy, p.stageDepth - hy)),
      );
    } else if (_mode == _Mode.rotate) {
      final s = _states[id];
      if (s == null) return;
      final v = d.localPosition - g.toScreen(s.x, s.y);
      if (v.distance < 4) return;
      widget.drag.value = DragOverride(
        id,
        facing: Timeline.snap45(StageGeometry.facingFromVector(v)),
      );
    }
  }

  void _onPanEnd() {
    final o = widget.drag.value;
    final id = _dragId;
    if (o != null && id != null) {
      if (_mode == _Mode.move && o.x != null && o.y != null) {
        widget.onMove(id, o.x!, o.y!);
      } else if (_mode == _Mode.moveObject && o.x != null && o.y != null) {
        widget.onMoveObject(id, o.x!, o.y!);
      } else if (_mode == _Mode.rotate && o.facing != null) {
        widget.onRotate(id, o.facing!);
      }
    }
    widget.drag.value = null;
    _mode = _Mode.none;
    _dragId = null;
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        _geo = StageGeometry(
          size,
          widget.project.stageWidth,
          widget.project.stageDepth,
          compact: false,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (d) {
            widget.onInteract();
            if (_hitHandle(d.localPosition)) return;
            final dancer = _hitDancer(d.localPosition);
            widget.onSelect(dancer);
            widget.onSelectObject(
              dancer == null && widget.editable
                  ? _hitObject(d.localPosition)?.id
                  : null,
            );
          },
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: CustomPaint(
            size: size,
            isComplex: true,
            painter: StagePainter(
              project: widget.project,
              playhead: widget.playhead,
              drag: widget.drag,
              settings: widget.settings,
              selectedId: widget.selectedId,
              selectedObjectId: widget.selectedObjectId,
              showHandle: widget.editable,
            ),
          ),
        );
      },
    );
  }
}
