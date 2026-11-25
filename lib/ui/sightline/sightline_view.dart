import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/app_settings.dart';
import '../../models/project.dart';
import '../../state/providers.dart';
import '../theme.dart';
import 'sightline_painter.dart';

/// Tampilan 3D dari kursi penonton.
///
/// Proyeksi perspektif dihitung sendiri di `CustomPainter`; penari digambar
/// sebagai figur setinggi posenya, diurutkan menurut kedalaman, dan ikut
/// animasi linimasa. Geser layar untuk pindah kursi (kiri–kanan) dan mengubah
/// tinggi pandang; slider mengatur hal yang sama dengan angka pasti.
class SightlineView extends ConsumerStatefulWidget {
  const SightlineView({
    super.key,
    required this.project,
    required this.playhead,
    required this.settings,
  });

  final Project project;
  final ValueNotifier<double> playhead;
  final AppSettings settings;

  @override
  ConsumerState<SightlineView> createState() => _SightlineViewState();
}

class _SightlineViewState extends ConsumerState<SightlineView> {
  static const double minSeat = 2;
  static const double maxSeat = 20;
  static const double minEye = 0.3;
  static const double maxEye = 12;

  double _seat = 8;
  double _seatAtPinchStart = 8;
  bool _controls = true;
  double _offset = 0;
  late double _eye = widget.settings.eyeHeight.clamp(minEye, maxEye);

  /// Kursi boleh bergeser hingga 6 m di luar tepi samping panggung.
  double get _maxOffset => widget.project.stageWidth / 2 + 6;

  String get _seatLabel => _seat < 6
      ? 'Depan'
      : _seat < 13
      ? 'Tengah'
      : 'Belakang';

  String get _offsetLabel => _offset.abs() < 0.5
      ? 'Tengah'
      : '${_offset < 0 ? 'Kiri' : 'Kanan'} ${fmtNum(_offset.abs(), 0)} m';

  void _saveEye() => ref
      .read(settingsProvider.notifier)
      .update(ref.read(settingsProvider).copyWith(eyeHeight: _eye));

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Satu jari: geser kursi ke samping dan ubah tinggi pandang.
                // Dua jari (cubit): maju atau mundurkan kursi.
                onScaleStart: (_) => _seatAtPinchStart = _seat,
                onScaleUpdate: (d) => setState(() {
                  if (d.pointerCount >= 2) {
                    _seat = (_seatAtPinchStart / d.scale).clamp(
                      minSeat,
                      maxSeat,
                    );
                    return;
                  }
                  // Geser ke kanan = kursi pindah ke kiri (panggung ikut jari).
                  _offset =
                      (_offset -
                              d.focalPointDelta.dx *
                                  2 *
                                  _maxOffset /
                                  size.width)
                          .clamp(-_maxOffset, _maxOffset);
                  _eye = (_eye + d.focalPointDelta.dy * 8 / size.height).clamp(
                    minEye,
                    maxEye,
                  );
                }),
                onScaleEnd: (_) => _saveEye(),
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: size,
                        painter: SightlinePainter(
                          project: p,
                          playhead: widget.playhead,
                          settings: widget.settings,
                          seatDistance: _seat,
                          eyeHeight: _eye,
                          seatOffset: _offset,
                        ),
                      ),
                    ),
                    // Tombol lipat panel kursi.
                    Positioned(
                      right: 8,
                      bottom: 4,
                      child: IconButton.filledTonal(
                        tooltip: _controls
                            ? 'Sembunyikan pengatur kursi'
                            : 'Tampilkan pengatur kursi',
                        onPressed: () => setState(() => _controls = !_controls),
                        icon: Icon(
                          _controls
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.event_seat_outlined,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 40,
                      left: 12,
                      child: _VisibilityChip(
                        project: p,
                        playhead: widget.playhead,
                        settings: widget.settings,
                        seat: _seat,
                        eye: _eye,
                        offset: _offset,
                        view: size,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_controls)
          Container(
            margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
            decoration: BoxDecoration(
              color: LColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SliderRow(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Samping',
                  value: _offset,
                  min: -_maxOffset,
                  max: _maxOffset,
                  text: _offsetLabel,
                  onChanged: (v) => setState(() => _offset = v),
                ),
                _SliderRow(
                  icon: Icons.event_seat_outlined,
                  label: 'Jarak',
                  value: _seat,
                  min: minSeat,
                  max: maxSeat,
                  text: '$_seatLabel ${fmtNum(_seat, 0)} m',
                  onChanged: (v) => setState(() => _seat = v),
                ),
                _SliderRow(
                  icon: Icons.height_rounded,
                  label: 'Tinggi',
                  value: _eye,
                  min: minEye,
                  max: maxEye,
                  text: '${fmtNum(_eye)} m',
                  onChanged: (v) => setState(() => _eye = v),
                  onChangeEnd: (_) => _saveEye(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.text,
    required this.onChanged,
    this.onChangeEnd,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final String text;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        Icon(icon, size: 20, color: LColors.muted),
        const SizedBox(width: 6),
        SizedBox(
          width: 52,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(
                color: LColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            semanticFormatterCallback: (_) => '$label $text',
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 84,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Muncul hanya bila ada penari yang kepalanya terhalang dari kursi ini.
class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({
    required this.project,
    required this.playhead,
    required this.settings,
    required this.seat,
    required this.eye,
    required this.offset,
    required this.view,
  });

  final Project project;
  final ValueNotifier<double> playhead;
  final AppSettings settings;
  final double seat;
  final double eye;
  final double offset;
  final Size view;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: playhead,
    builder: (context, p, _) {
      final cam = SightlineCamera(
        stageWidth: project.stageWidth,
        stageDepth: project.stageDepth,
        seatDistance: seat,
        eyeHeight: eye,
        seatOffset: offset,
        view: view,
        fit: SightlineScene.framing(project),
      );
      final blocked = [
        for (final f in SightlineScene.build(
          project: project,
          playhead: p,
          settings: settings,
          camera: cam,
        ))
          if (f.blockedBy.isNotEmpty) f.dancer.role,
      ];
      if (blocked.isEmpty) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.topRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: LColors.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Terhalang: ${blocked.join(', ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: LColors.base,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    },
  );
}
