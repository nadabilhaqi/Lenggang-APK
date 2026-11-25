import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/app_settings.dart';
import '../../models/pose.dart';
import '../../state/providers.dart';
import '../pose_glyph.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Panduan ruang'),
          ValueRow(
            leading: const Icon(Icons.social_distance, color: LColors.accent),
            label: 'Jarak aman',
            value: s.collisionThreshold,
            unit: 'm',
            min: 0.3,
            max: 2,
            step: 0.1,
            onChanged: (v) => n.update(s.copyWith(collisionThreshold: v)),
          ),
          const SizedBox(height: 10),
          ValueRow(
            leading: const Icon(Icons.adjust_rounded, color: LColors.accent),
            label: 'Radius sampur',
            value: s.sampurRadius,
            unit: 'm',
            min: 0.4,
            max: 3,
            step: 0.1,
            onChanged: (v) => n.update(s.copyWith(sampurRadius: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lingkaran sampur'),
            value: s.showSampur,
            onChanged: (v) => n.update(s.copyWith(showSampur: v)),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Tinggi kepala'),
          for (final p in Pose.values) ...[
            ValueRow(
              leading: PoseGlyph(pose: p, color: LColors.accent, size: 26),
              label: p.label,
              value: s.heightOf(p),
              unit: 'm',
              min: 0.4,
              max: 2.2,
              step: 0.05,
              digits: 2,
              onChanged: (v) =>
                  n.update(s.copyWith(poseHeights: {...s.poseHeights, p: v})),
            ),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => n.update(s.copyWith(poseHeights: const {})),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Kembalikan tinggi awal'),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Bunyi'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bunyi ketukan'),
            value: !s.muted,
            onChanged: (v) => n.update(s.copyWith(muted: !v)),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Tentang'),
          const Text(
            'Lenggang 1.0.0. Semua data tersimpan di HP ini.',
            style: TextStyle(color: LColors.muted),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => n.update(const AppSettings()),
              icon: const Icon(Icons.settings_backup_restore),
              label: const Text('Kembalikan pengaturan awal'),
            ),
          ),
        ],
      ),
    );
  }
}
