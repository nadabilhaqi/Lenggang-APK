import 'package:material_ui/material_ui.dart';

import 'theme.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: LColors.accent,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

/// Baris nilai dengan tombol − / + berukuran sentuh 48 dp.
class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.digits = 1,
    this.leading,
  });

  /// Ikon pengganti teks label. Bila diisi, [label] hanya dipakai untuk
  /// pembaca layar dan tooltip tombol.
  final Widget? leading;

  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final double step;
  final int digits;
  final ValueChanged<double> onChanged;

  double _snap(double v) {
    final r = (v / step).round() * step;
    return double.parse(r.clamp(min, max).toStringAsFixed(3));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: LColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LColors.border),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Semantics(label: label, child: leading),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fmtNum(value, digits)} $unit',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (leading == null)
                  Text(
                    label,
                    style: const TextStyle(color: LColors.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Kurangi $label',
            onPressed: value <= min + 1e-9
                ? null
                : () => onChanged(_snap(value - step)),
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'Tambah $label',
            onPressed: value >= max - 1e-9
                ? null
                : () => onChanged(_snap(value + step)),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: LColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Ikon rentang: garis dengan panah di kedua ujung (mendatar = kiri–kanan,
/// tegak = depan–belakang).
class SpanIcon extends StatelessWidget {
  const SpanIcon({super.key, required this.axis, this.size = 28});

  final Axis axis;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SpanIconPainter(axis));
}

class _SpanIconPainter extends CustomPainter {
  _SpanIconPainter(this.axis);

  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = LColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    if (axis == Axis.vertical) {
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(1.5707963267948966);
      canvas.translate(-size.width / 2, -size.height / 2);
    }
    final y = size.height / 2;
    final a = size.width * 0.08, b = size.width * 0.92, h = size.width * 0.2;
    canvas.drawLine(Offset(a, y), Offset(b, y), p);
    canvas.drawPath(
      Path()
        ..moveTo(a + h, y - h)
        ..lineTo(a, y)
        ..lineTo(a + h, y + h),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(b - h, y - h)
        ..lineTo(b, y)
        ..lineTo(b - h, y + h),
      p,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpanIconPainter old) => old.axis != axis;
}

/// Nilai yang jarang diubah: tampil ringkas dengan ikon, dan baru bisa
/// diatur setelah ikon edit diketuk.
class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.leading,
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.digits = 1,
  });

  final Widget leading;
  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final double step;
  final int digits;
  final ValueChanged<double> onChanged;

  Future<void> _edit(BuildContext context) async {
    var v = value;
    final result = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: LColors.card,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                StepperRow(
                  leading: leading,
                  label: label,
                  value: v,
                  unit: unit,
                  min: min,
                  max: max,
                  step: step,
                  digits: digits,
                  onChanged: (x) => setS(() => v = x),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, v),
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && result != value) onChanged(result);
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 2, 2, 2),
    decoration: BoxDecoration(
      color: LColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: LColors.border),
    ),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${fmtNum(value, digits)} $unit',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: LColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Ubah $label',
          onPressed: () => _edit(context),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
  );
}
