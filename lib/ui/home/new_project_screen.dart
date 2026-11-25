import 'package:material_ui/material_ui.dart';

import '../../logic/templates.dart';
import '../../models/project.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Formulir proyek baru: identitas, ukuran panggung, dan formasi awal.
class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _title = TextEditingController(text: 'Srimpi');
  final _tradition = TextEditingController(text: 'Jawa Klasik – Surakarta');
  final _choreographer = TextEditingController();
  double _width = 8;
  double _depth = 6;
  double _bpm = 60;
  bool _srimpi = true;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _tradition.dispose();
    _choreographer.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Isi nama tarian');
      return;
    }
    final build = _srimpi ? ProjectTemplates.srimpi : ProjectTemplates.empty;
    final Project p = build(
      id: newId(),
      title: title,
      tradition: _tradition.text.trim(),
      choreographer: _choreographer.text.trim(),
      width: _width,
      depth: _depth,
      bpm: _bpm.round(),
    );
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proyek baru')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _submit,
            child: const Text('Buat proyek'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Identitas'),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nama tarian',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tradition,
            decoration: const InputDecoration(labelText: 'Gaya tradisi'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _choreographer,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Penata tari'),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Ukuran panggung'),
          StepperRow(
            leading: const SpanIcon(axis: Axis.horizontal),
            label: 'Panjang (kiri–kanan)',
            value: _width,
            unit: 'm',
            min: 2,
            max: 30,
            step: 0.5,
            onChanged: (v) => setState(() => _width = v),
          ),
          const SizedBox(height: 10),
          StepperRow(
            leading: const SpanIcon(axis: Axis.vertical),
            label: 'Lebar (depan–belakang)',
            value: _depth,
            unit: 'm',
            min: 2,
            max: 30,
            step: 0.5,
            onChanged: (v) => setState(() => _depth = v),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Tempo'),
          StepperRow(
            leading: const Icon(Icons.speed_rounded, color: LColors.accent),
            label: 'Tempo',
            value: _bpm,
            unit: 'BPM',
            min: 10,
            max: 200,
            step: 5,
            digits: 0,
            onChanged: (v) => setState(() => _bpm = v),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Formasi awal'),
          _TemplateTile(
            selected: _srimpi,
            title: 'Srimpi · 4 penari',
            subtitle: 'Batak, Gulu, Dhadha, Buncit.',
            onTap: () => setState(() => _srimpi = true),
          ),
          const SizedBox(height: 8),
          _TemplateTile(
            selected: !_srimpi,
            title: 'Kanvas kosong',
            subtitle: 'Tambah penari sendiri.',
            onTap: () => setState(() => _srimpi = false),
          ),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: LColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? LColors.accent : LColors.border,
        width: selected ? 2 : 1,
      ),
    ),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? LColors.accent : LColors.dimmed,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
    ),
  );
}
