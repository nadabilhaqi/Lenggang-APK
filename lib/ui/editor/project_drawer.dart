import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/templates.dart';
import '../../logic/timeline.dart';
import '../../models/project.dart';
import '../../services/export_service.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Laci proyek: Pentas · Penari · Benda · Ekspor.
class ProjectDrawer extends ConsumerWidget {
  const ProjectDrawer({
    super.key,
    required this.boundary,
    required this.currentBeat,
    required this.onBeforeExport,
  });

  final RenderRepaintBoundary? Function() boundary;
  final int currentBeat;
  final VoidCallback onBeforeExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(editorProvider);
    if (editor == null) return const SizedBox.shrink();
    final p = editor.project;
    return Drawer(
      width: 340,
      backgroundColor: LColors.base,
      child: SafeArea(
        child: DefaultTabController(
          length: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelPadding: EdgeInsets.zero,
                tabs: [
                  Tab(text: 'Pentas'),
                  Tab(text: 'Penari'),
                  Tab(text: 'Benda'),
                  Tab(text: 'Ekspor'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _StageTab(project: p),
                    _DancersTab(project: p, beat: currentBeat),
                    _ObjectsTab(project: p),
                    _ExportTab(
                      project: p,
                      boundary: boundary,
                      beat: currentBeat,
                      onBeforeExport: onBeforeExport,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Tab Pentas ---------------------------------------------------------------------

class _StageTab extends ConsumerWidget {
  const _StageTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(editorProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final sn = ref.read(settingsProvider.notifier);
    final p = project;
    final scale = settings.scaleFormation;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('Ukuran panggung'),
        StepperRow(
          leading: const SpanIcon(axis: Axis.horizontal),
          label: 'Panjang (kiri–kanan)',
          value: p.stageWidth,
          unit: 'm',
          min: 2,
          max: 30,
          step: 0.5,
          onChanged: (v) => n.setStage(v, p.stageDepth, scale: scale),
        ),
        const SizedBox(height: 10),
        StepperRow(
          leading: const SpanIcon(axis: Axis.vertical),
          label: 'Lebar (depan–belakang)',
          value: p.stageDepth,
          unit: 'm',
          min: 2,
          max: 30,
          step: 0.5,
          onChanged: (v) => n.setStage(p.stageWidth, v, scale: scale),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Formasi ikut menyesuaikan'),
          value: scale,
          onChanged: (v) => sn.update(settings.copyWith(scaleFormation: v)),
        ),
        const SizedBox(height: 12),
        const SectionTitle('Tempo'),
        StepperRow(
          leading: const Icon(Icons.speed_rounded, color: LColors.accent),
          label: 'Tempo',
          value: p.bpm.toDouble(),
          unit: 'BPM',
          min: 10,
          max: 200,
          step: 5,
          digits: 0,
          onChanged: (v) => n.setBpm(v.round()),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Panduan ruang'),
        ValueRow(
          leading: const Icon(Icons.social_distance, color: LColors.accent),
          label: 'Jarak aman',
          value: settings.collisionThreshold,
          unit: 'm',
          min: 0.3,
          max: 2,
          step: 0.1,
          onChanged: (v) => sn.update(settings.copyWith(collisionThreshold: v)),
        ),
        const SizedBox(height: 10),
        ValueRow(
          leading: const Icon(Icons.adjust_rounded, color: LColors.accent),
          label: 'Radius sampur',
          value: settings.sampurRadius,
          unit: 'm',
          min: 0.4,
          max: 3,
          step: 0.1,
          onChanged: (v) => sn.update(settings.copyWith(sampurRadius: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lingkaran sampur'),
          value: settings.showSampur,
          onChanged: (v) => sn.update(settings.copyWith(showSampur: v)),
        ),
        const SizedBox(height: 12),
        const SectionTitle('Identitas'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(p.title),
          subtitle: Text(
            [
              if (p.tradition.isNotEmpty) p.tradition,
              if (p.choreographer.isNotEmpty) 'Penata tari: ${p.choreographer}',
            ].join('\n'),
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editMeta(context, ref, p),
        ),
      ],
    );
  }

  Future<void> _editMeta(BuildContext context, WidgetRef ref, Project p) async {
    final title = TextEditingController(text: p.title);
    final trad = TextEditingController(text: p.tradition);
    final chor = TextEditingController(text: p.choreographer);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Identitas proyek'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Nama tarian'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: trad,
                decoration: const InputDecoration(labelText: 'Gaya tradisi'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chor,
                decoration: const InputDecoration(labelText: 'Penata tari'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      ref
          .read(editorProvider.notifier)
          .updateMeta(
            title: title.text.trim(),
            tradition: trad.text.trim(),
            choreographer: chor.text.trim(),
          );
    }
  }
}

// --- Tab Penari ---------------------------------------------------------------------

class _DancersTab extends ConsumerWidget {
  const _DancersTab({required this.project, required this.beat});

  final Project project;
  final int beat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(editorProvider.notifier);
    final full = project.dancers.length >= ProjectTemplates.maxDancers;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle('Penari (${project.dancers.length})'),
        for (final d in project.dancers)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 12, right: 4),
              leading: CircleAvatar(
                backgroundColor: Color(d.color),
                child: Text(
                  d.code,
                  style: const TextStyle(
                    color: LColors.base,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: Text(
                d.role,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: d.name.isEmpty ? null : Text(d.name),
              onTap: () => _edit(context, ref, d),
              trailing: IconButton(
                tooltip: 'Hapus ${d.role}',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: 'Hapus ${d.role}?',
                    message: 'Penari hilang dari semua formasi.',
                    action: 'Hapus penari',
                  );
                  if (ok) n.removeDancer(d.id);
                },
              ),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: full ? null : () => n.addDancer(beat),
          icon: const Icon(Icons.person_add_alt_1),
          label: Text(
            full
                ? 'Maksimal ${ProjectTemplates.maxDancers} penari'
                : 'Tambah penari',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Ketuk penari untuk mengubah peran, nama, atau warna.',
          style: TextStyle(color: LColors.dimmed, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Dancer d) async {
    final role = TextEditingController(text: d.role);
    final name = TextEditingController(text: d.name);
    var color = d.color;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Ubah penari'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: role,
                  decoration: const InputDecoration(labelText: 'Peran'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final r in const ['Batak', 'Gulu', 'Dhadha', 'Buncit'])
                      ActionChip(
                        label: Text(r),
                        onPressed: () => setS(() => role.text = r),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nama penari (opsional)',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Warna'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in DancerPalette.choices)
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setS(() => color = c),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c == color
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: c == color
                              ? const Icon(Icons.check, color: LColors.base)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && role.text.trim().isNotEmpty) {
      ref
          .read(editorProvider.notifier)
          .updateDancer(
            d.copyWith(
              role: role.text.trim(),
              name: name.text.trim(),
              color: color,
            ),
          );
    }
  }
}

// --- Tab Benda: benda panggung & properti tari ---------------------------------------

class _ObjectsTab extends ConsumerWidget {
  const _ObjectsTab({required this.project});

  final Project project;

  static const _presets = <(String, double, double)>[
    ('Speaker', 0.6, 0.6),
    ('Monitor', 0.6, 0.4),
    ('Tiang', 0.4, 0.4),
    ('Gamelan', 3.0, 2.0),
    ('Benda lain', 1.0, 1.0),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(editorProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle('Benda & properti (${project.objects.length})'),
        for (final o in project.objects)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 12, right: 4),
              leading: Icon(
                o.kind == StageObjectKind.obstacle
                    ? Icons.block
                    : Icons.category_outlined,
                color: o.kind == StageObjectKind.obstacle
                    ? LColors.muted
                    : LColors.pink,
              ),
              title: Text(
                o.label.isEmpty ? o.kind.label : o.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${fmtNum(o.width)} × ${fmtNum(o.depth)} m'),
              onTap: () => _edit(context, ref, o),
              trailing: IconButton(
                tooltip: 'Hapus ${o.label.isEmpty ? o.kind.label : o.label}',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: 'Hapus ${o.label.isEmpty ? o.kind.label : o.label}?',
                    message: 'Benda hilang dari denah.',
                    action: 'Hapus benda',
                  );
                  if (ok) n.removeObject(o.id);
                },
              ),
            ),
          ),
        const SizedBox(height: 4),
        const Text(
          'Benda panggung',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        const Text(
          'Areanya terhalang. Penari yang masuk diberi peringatan.',
          style: TextStyle(color: LColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (label, w, d) in _presets)
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text(label),
                onPressed: () => n.addObject(
                  kind: StageObjectKind.obstacle,
                  label: label == 'Benda lain' ? 'Benda' : label,
                  width: w,
                  depth: d,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => n.addObject(
            kind: StageObjectKind.prop,
            label: 'Properti',
            width: 0.5,
            depth: 0.5,
          ),
          icon: const Icon(Icons.category_outlined),
          label: const Text('Tambah properti tari'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Ketuk benda di denah untuk menggeser atau menghapusnya.',
          style: TextStyle(color: LColors.dimmed, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, StageObject o) async {
    final label = TextEditingController(text: o.label);
    var kind = o.kind;
    var width = o.width;
    var depth = o.depth;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Ubah benda'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'Nama'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Area terhalang'),
                  subtitle: Text(
                    kind == StageObjectKind.obstacle
                        ? 'Penari yang masuk diberi peringatan.'
                        : 'Hanya penanda properti tari.',
                  ),
                  value: kind == StageObjectKind.obstacle,
                  onChanged: (v) => setS(
                    () => kind = v
                        ? StageObjectKind.obstacle
                        : StageObjectKind.prop,
                  ),
                ),
                const SizedBox(height: 8),
                StepperRow(
                  leading: const SpanIcon(axis: Axis.horizontal),
                  label: 'Panjang (kiri–kanan)',
                  value: width,
                  unit: 'm',
                  min: 0.2,
                  max: 10,
                  step: 0.1,
                  onChanged: (v) => setS(() => width = v),
                ),
                const SizedBox(height: 10),
                StepperRow(
                  leading: const SpanIcon(axis: Axis.vertical),
                  label: 'Lebar (depan–belakang)',
                  value: depth,
                  unit: 'm',
                  min: 0.2,
                  max: 10,
                  step: 0.1,
                  onChanged: (v) => setS(() => depth = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      ref
          .read(editorProvider.notifier)
          .updateObject(
            o.copyWith(
              label: label.text.trim(),
              kind: kind,
              width: width,
              depth: depth,
            ),
          );
    }
  }
}

// --- Tab Ekspor ---------------------------------------------------------------------

class _ExportTab extends StatelessWidget {
  const _ExportTab({
    required this.project,
    required this.boundary,
    required this.beat,
    required this.onBeforeExport,
  });

  final Project project;
  final RenderRepaintBoundary? Function() boundary;
  final int beat;
  final VoidCallback onBeforeExport;

  Future<void> _run(
    BuildContext context,
    Future<String?> Function() job,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final scaffold = Scaffold.of(context);
    // Tutup laci dulu agar pesan di bawah layar tidak tertutup.
    void say(String text) {
      scaffold.closeEndDrawer();
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }

    try {
      final msg = await job();
      if (msg != null) say(msg);
    } catch (e) {
      debugPrint('Ekspor gagal: $e');
      say('Ekspor gagal. Coba lagi.');
    }
  }

  Future<Uint8List?> _png() async {
    onBeforeExport();
    // Tunggu satu frame: seleksi hilang dan tampilan denah sudah tergambar.
    await WidgetsBinding.instance.endOfFrame;
    var b = boundary();
    if (b == null) {
      await WidgetsBinding.instance.endOfFrame;
      b = boundary();
    }
    if (b == null) return null;
    return ExportService.capturePlanPng(
      boundary: b,
      project: project,
      beat: beat,
      states: Timeline.stateAt(project, beat.toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('Lembar denah'),
        Text(
          'Gambar formasi ketukan $beat untuk dibagikan ke penari.',
          style: const TextStyle(color: LColors.muted),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          icon: const Icon(Icons.image_outlined),
          label: const Text('Simpan PNG'),
          onPressed: () => _run(context, () async {
            final bytes = await _png();
            if (bytes == null) return 'Denah belum siap. Coba lagi.';
            final ok = await ExportService.saveAs(
              ExportService.pngName(project, beat),
              bytes,
              'image/png',
            );
            return ok ? 'PNG tersimpan' : null;
          }),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.share_outlined),
          label: const Text('Bagikan PNG'),
          onPressed: () => _run(context, () async {
            final bytes = await _png();
            if (bytes == null) return 'Denah belum siap. Coba lagi.';
            await ExportService.share(
              ExportService.pngName(project, beat),
              bytes,
              'image/png',
              text: 'Denah ${project.title} · ketukan $beat',
            );
            return null;
          }),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Berkas proyek'),
        const Text(
          'Arsip .lenggang yang bisa dibuka lagi di Lenggang.',
          style: TextStyle(color: LColors.muted),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          icon: const Icon(Icons.save_alt),
          label: const Text('Simpan berkas'),
          onPressed: () => _run(context, () async {
            final ok = await ExportService.saveAs(
              ExportService.fileName(project),
              ExportService.encodeProject(project),
              'application/json',
            );
            return ok ? 'Berkas tersimpan' : null;
          }),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.share_outlined),
          label: const Text('Bagikan berkas'),
          onPressed: () => _run(context, () async {
            await ExportService.share(
              ExportService.fileName(project),
              ExportService.encodeProject(project),
              'application/json',
              text: 'Proyek ${project.title} (Lenggang)',
            );
            return null;
          }),
        ),
      ],
    );
  }
}
