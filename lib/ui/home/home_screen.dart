import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/project.dart';
import '../../services/export_service.dart';
import '../../state/providers.dart';
import '../editor/editor_screen.dart';
import '../settings/settings_screen.dart';
import '../stage/stage_painter.dart';
import '../theme.dart';
import '../widgets.dart';
import 'new_project_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, Project p) {
    ref.read(editorProvider.notifier).open(p);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const EditorScreen()));
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final p = await Navigator.of(context).push(
      MaterialPageRoute<Project>(builder: (_) => const NewProjectScreen()),
    );
    if (p == null || !context.mounted) return;
    await ref.read(projectsProvider.notifier).save(p);
    if (context.mounted) _open(context, ref, p);
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      var p = await ExportService.pickProject();
      if (p == null || !context.mounted) return;
      final notifier = ref.read(projectsProvider.notifier);
      if (notifier.exists(p.id)) {
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Proyek sudah ada'),
            content: Text('"${p!.title}" sudah ada di HP ini.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'copy'),
                child: const Text('Simpan salinan'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'replace'),
                child: const Text('Ganti'),
              ),
            ],
          ),
        );
        if (choice == null) return;
        if (choice == 'copy') {
          p = p.copyWith(id: newId(), title: '${p.title} (salinan)');
        }
      }
      await notifier.save(p);
      messenger.showSnackBar(SnackBar(content: Text('Proyek dibuka')));
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Berkas tidak bisa dibuka. ${e.message}')),
      );
    } catch (e) {
      debugPrint('Impor gagal: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Berkas tidak bisa dibuka. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/brand/logo.png',
                width: 38,
                height: 38,
                cacheWidth: 152,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Lenggang',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buka berkas .lenggang',
            onPressed: () => _import(context, ref),
            icon: const Icon(Icons.file_open_outlined),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LColors.accent,
        foregroundColor: LColors.base,
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(
          'Buat proyek',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: projects.isEmpty
          ? _Empty(onImport: () => _import(context, ref))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: projects.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Proyek (${projects.length})',
                      style: const TextStyle(
                        color: LColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                final p = projects[i - 1];
                return _ProjectCard(
                  project: p,
                  onOpen: () => _open(context, ref, p),
                  onShare: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ExportService.share(
                        ExportService.fileName(p),
                        ExportService.encodeProject(p),
                        'application/json',
                        text: 'Proyek ${p.title} (Lenggang)',
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Berkas gagal dibagikan. Coba lagi.'),
                        ),
                      );
                    }
                  },
                  onDelete: () async {
                    final ok = await confirm(
                      context,
                      title: 'Hapus "${p.title}"?',
                      message: 'Proyek hilang dari HP ini dan tidak bisa dikembalikan.',
                      action: 'Hapus proyek',
                    );
                    if (ok) {
                      await ref.read(projectsProvider.notifier).delete(p.id);
                    }
                  },
                );
              },
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_on_rounded, size: 56, color: LColors.dimmed),
          const SizedBox(height: 16),
          const Text(
            'Belum ada proyek',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Buat proyek pertama untuk menyusun formasi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LColors.muted),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Buka berkas'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    ),
  );
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  static final _first = ValueNotifier<double>(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = project;
    final settings = ref.watch(settingsProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: LColors.base,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LColors.border),
                ),
                child: CustomPaint(
                  painter: StagePainter(
                    project: p,
                    playhead: _first,
                    settings: settings,
                    compact: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (p.tradition.isNotEmpty) p.tradition,
                        if (p.choreographer.isNotEmpty) p.choreographer,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${fmtSize(p.stageWidth)} × ${fmtSize(p.stageDepth)} m · '
                      '${p.dancers.length} penari',
                      style: const TextStyle(
                        color: LColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Diedit ${_ago(p.updatedAt)}',
                      style: const TextStyle(
                        color: LColors.dimmed,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Menu proyek',
                onSelected: (v) => switch (v) {
                  'open' => onOpen(),
                  'share' => onShare(),
                  _ => onDelete(),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('Buka')),
                  PopupMenuItem(value: 'share', child: Text('Bagikan berkas')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().toUtc().difference(t);
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inHours < 1) return '${d.inMinutes} menit lalu';
    if (d.inDays < 1) return '${d.inHours} jam lalu';
    if (d.inDays < 30) return '${d.inDays} hari lalu';
    final l = t.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }
}
