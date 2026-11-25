import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lenggang/logic/templates.dart';
import 'package:lenggang/models/pose.dart';
import 'package:lenggang/models/project.dart';
import 'package:lenggang/services/lenggang_format.dart';

Project sample() {
  final base = ProjectTemplates.srimpi(
    id: 'uji-123',
    title: 'Srimpi Uji "Kutipan" & Ünïcode',
    tradition: 'Jawa Klasik – Surakarta',
    choreographer: 'Penata Uji',
    width: 10,
    depth: 7.5,
    bpm: 72,
    now: DateTime.utc(2026, 11, 25, 15, 4, 5, 123, 456),
  );
  // Tambah penari generik dan keyframe dengan nilai pecahan "sulit".
  const extra = Dancer(
    id: 'p5',
    role: 'Penari 5',
    name: 'Dewi',
    color: 0xFFCE93D8,
  );
  final kf = {
    for (final e in base.keyframes.entries)
      e.key: {
        ...e.value,
        'p5': DancerState(
          x: 0.1 + 0.2 * e.key, // 0.30000000000000004 dst.
          y: 1 / 3 * e.key % 7.5,
          facing: (45.0 * e.key) % 360,
          pose: Pose.values[e.key % Pose.values.length],
        ),
      },
    5: {
      'batak': const DancerState(
        x: 1.23,
        y: 4.56,
        facing: 315,
        pose: Pose.sila,
      ),
      'gulu': const DancerState(x: 0, y: 0, facing: 0, pose: Pose.timpuh),
      'dhadha': const DancerState(x: 10, y: 7.5, facing: 180),
      'buncit': const DancerState(
        x: 9.99,
        y: 0.01,
        facing: 90,
        pose: Pose.jengkeng,
      ),
      'p5': const DancerState(x: 5, y: 3.75, facing: 225, pose: Pose.mendhak),
    },
  };
  return base.copyWith(
    dancers: [...base.dancers, extra],
    keyframes: kf,
    updatedAt: DateTime.utc(2026, 11, 26, 1, 2, 3),
    objects: const [
      StageObject(
        id: 'o1',
        kind: StageObjectKind.obstacle,
        label: 'Speaker kiri',
        x: 0.5,
        y: 6.9,
        width: 0.6,
        depth: 0.6,
      ),
      StageObject(
        id: 'o2',
        kind: StageObjectKind.prop,
        label: 'Dhadhap',
        x: 5.25,
        y: 1 / 3,
        width: 0.5,
        depth: 0.5,
      ),
    ],
  );
}

void expectSameProject(Project a, Project b) {
  expect(b.id, a.id);
  expect(b.title, a.title);
  expect(b.tradition, a.tradition);
  expect(b.choreographer, a.choreographer);
  expect(b.stageWidth, a.stageWidth);
  expect(b.stageDepth, a.stageDepth);
  expect(b.bpm, a.bpm);
  expect(b.cycle, a.cycle);
  expect(b.createdAt, a.createdAt);
  expect(b.updatedAt, a.updatedAt);
  expect(b.dancers, a.dancers);
  expect(b.objects, a.objects);
  expect(b.keyframes.keys.toList(), a.keyframes.keys.toList());
  for (final beat in a.keyframes.keys) {
    expect(b.keyframes[beat], a.keyframes[beat], reason: 'ketukan $beat');
  }
}

void main() {
  group('Format .lenggang', () {
    test('round-trip ekspor -> impor menghasilkan proyek identik', () {
      final original = sample();
      final text = LenggangFormat.encode(original);
      final restored = LenggangFormat.decode(text);

      expectSameProject(original, restored);
      // Ekspor ulang harus identik byte demi byte.
      expect(LenggangFormat.encode(restored), text);
    });

    test('round-trip proyek kosong tanpa penari', () {
      final original = ProjectTemplates.empty(
        id: 'kosong',
        title: 'Kosong',
        tradition: '',
        choreographer: '',
        width: 4,
        depth: 4,
        now: DateTime.utc(2026, 11, 25),
      );
      final restored = LenggangFormat.decode(LenggangFormat.encode(original));
      expectSameProject(original, restored);
    });

    test('berkas lama tanpa daftar benda tetap bisa dibuka', () {
      final j =
          jsonDecode(LenggangFormat.encode(sample())) as Map<String, dynamic>
            ..remove('objects');
      final p = LenggangFormat.fromJson(j);
      expect(p.objects, isEmpty);
      expect(p.dancers.length, 5);
    });

    test('berkas memuat seluruh bagian skema', () {
      final j =
          jsonDecode(LenggangFormat.encode(sample())) as Map<String, dynamic>;
      expect(j['format'], 'lenggang');
      expect(j['schemaVersion'], 1);
      expect(j['metadata']['title'], contains('Srimpi'));
      expect(j['metadata']['tradition'], isNotEmpty);
      expect(j['metadata']['choreographer'], 'Penata Uji');
      expect(j['stage']['width'], 10);
      expect(j['stage']['depth'], 7.5);
      expect(j['stage']['unit'], 'm');
      expect(j['rhythm']['cycle'], 'ketawang16');
      expect(j['rhythm']['beatsPerCycle'], 16);
      expect(j['rhythm']['kenong'], [8]);
      expect(j['rhythm']['gong'], [16]);
      expect(j['rhythm']['bpm'], 72);
      final roles = [for (final d in j['dancers'] as List) d['role']];
      expect(roles, containsAllInOrder(['Batak', 'Gulu', 'Dhadha', 'Buncit']));
      final kf = (j['keyframes'] as List).first as Map<String, dynamic>;
      expect(kf['beat'], 1);
      final pos = (kf['positions'] as List).first as Map<String, dynamic>;
      expect(pos.keys, containsAll(['dancer', 'x', 'y', 'facing', 'pose']));
    });

    test('menolak berkas yang bukan .lenggang atau rusak', () {
      expect(() => LenggangFormat.decode('bukan json'), throwsFormatException);
      expect(() => LenggangFormat.decode('[]'), throwsFormatException);
      expect(
        () => LenggangFormat.decode('{"format":"lain"}'),
        throwsFormatException,
      );
      final j =
          jsonDecode(LenggangFormat.encode(sample())) as Map<String, dynamic>;
      expect(
        () => LenggangFormat.fromJson({...j, 'schemaVersion': 99}),
        throwsFormatException,
      );
      final badPose = jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
      badPose['keyframes'][0]['positions'][0]['pose'] = 'terbang';
      expect(() => LenggangFormat.fromJson(badPose), throwsFormatException);
      final badBeat = jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
      badBeat['keyframes'][0]['beat'] = 17;
      expect(() => LenggangFormat.fromJson(badBeat), throwsFormatException);
    });
  });

  group('Preset Srimpi', () {
    test('empat peran dengan ejaan baku', () {
      final p = sample();
      expect(p.dancers.take(4).map((d) => d.role).toList(), [
        'Batak',
        'Gulu',
        'Dhadha',
        'Buncit',
      ]);
    });

    test('lima pose dengan tinggi kepala bawaan', () {
      expect(Pose.values.length, 5);
      expect(Pose.ngadeg.defaultHeight, 1.6);
      expect(Pose.mendhak.defaultHeight, 1.3);
      expect(Pose.jengkeng.defaultHeight, 1.0);
      expect(Pose.timpuh.defaultHeight, 0.8);
      expect(Pose.sila.defaultHeight, 0.8);
    });
  });
}
