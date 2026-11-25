import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:lenggang/logic/collision.dart';
import 'package:lenggang/logic/describe.dart';
import 'package:lenggang/logic/templates.dart';
import 'package:lenggang/models/app_settings.dart';
import 'package:lenggang/models/pose.dart';
import 'package:lenggang/models/project.dart';
import 'package:lenggang/services/lenggang_format.dart';
import 'package:lenggang/services/storage.dart';
import 'package:lenggang/state/providers.dart';

void main() {
  late Directory dir;
  late Box<String> projectBox;
  late Box<String> settingsBox;
  late ProviderContainer c;

  Project srimpi() => ProjectTemplates.srimpi(
    id: 'srimpi-1',
    title: 'Srimpi',
    tradition: 'Jawa',
    choreographer: 'Uji',
    width: 8,
    depth: 6,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lenggang_test_');
    Hive.init(dir.path);
    projectBox = await Hive.openBox<String>(ProjectStore.boxName);
    settingsBox = await Hive.openBox<String>(SettingsStore.boxName);
    c = ProviderContainer(
      overrides: [
        projectStoreProvider.overrideWithValue(
          ProjectStore(HiveKv(projectBox)),
        ),
        settingsStoreProvider.overrideWithValue(
          SettingsStore(HiveKv(settingsBox)),
        ),
      ],
    );
  });

  tearDown(() async {
    c.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  EditorNotifier open() {
    final n = c.read(editorProvider.notifier);
    n.open(srimpi());
    return n;
  }

  Project current() => c.read(editorProvider)!.project;

  test('proyek tersimpan di Hive dan bisa dihapus', () async {
    final projects = c.read(projectsProvider.notifier);
    expect(c.read(projectsProvider), isEmpty);
    await projects.save(srimpi());
    expect(c.read(projectsProvider).single.title, 'Srimpi');

    // Dibaca ulang dari kotak Hive oleh store baru (seperti saat app dibuka lagi).
    final reread = ProjectStore(HiveKv(projectBox)).loadAll().single;
    expect(
      LenggangFormat.encode(reread),
      LenggangFormat.encode(
        srimpi().copyWith(
          createdAt: reread.createdAt,
          updatedAt: reread.updatedAt,
        ),
      ),
    );

    await projects.delete('srimpi-1');
    expect(c.read(projectsProvider), isEmpty);
  });

  test(
    'memindah penari di ketukan tanpa keyframe membuat keyframe untuk semua',
    () {
      final n = open();
      expect(current().keyframeBeats, [1, 8, 16]);
      final before = current().keyframes[8]!['gulu']!;

      n.updateDancerAt(4, 'batak', (s) => s.copyWith(x: 2, y: 1));

      final p = current();
      expect(p.keyframeBeats, [1, 4, 8, 16]);
      expect(p.keyframes[4]!.keys.toSet(), {
        'batak',
        'gulu',
        'dhadha',
        'buncit',
      });
      expect(p.keyframes[4]!['batak']!.x, 2);
      expect(p.keyframes[4]!['batak']!.y, 1);
      // Keyframe lain tidak berubah.
      expect(p.keyframes[8]!['gulu'], before);
    },
  );

  test('posisi dijepit ke batas panggung, arah hadap dinormalkan', () {
    final n = open();
    n.updateDancerAt(1, 'batak', (s) => s.copyWith(x: -3, y: 99, facing: -45));
    final s = current().keyframes[1]!['batak']!;
    expect(s.x, 0);
    expect(s.y, 6);
    expect(s.facing, 315);
  });

  test('pose per penari per ketukan', () {
    final n = open();
    n.updateDancerAt(8, 'buncit', (s) => s.copyWith(pose: Pose.sila));
    expect(current().keyframes[8]!['buncit']!.pose, Pose.sila);
    expect(current().keyframes[1]!['buncit']!.pose, Pose.jengkeng);
  });

  test('tambah & hapus penari generik di semua keyframe', () {
    final n = open();
    final id = n.addDancer(1)!;
    var p = current();
    expect(p.dancers.length, 5);
    expect(p.dancers.last.role, 'Penari 5');
    for (final k in p.keyframes.values) {
      expect(k.containsKey(id), isTrue);
    }
    n.removeDancer(id);
    p = current();
    expect(p.dancers.length, 4);
    for (final k in p.keyframes.values) {
      expect(k.containsKey(id), isFalse);
    }
  });

  test('batas 12 penari', () {
    final n = open();
    for (var i = 0; i < 20; i++) {
      n.addDancer(1);
    }
    expect(current().dancers.length, ProjectTemplates.maxDancers);
  });

  test('keyframe: tambah, hapus, ketukan 1 tidak bisa dihapus', () {
    final n = open();
    n.addKeyframe(12);
    expect(current().keyframeBeats, [1, 8, 12, 16]);
    n.removeKeyframe(12);
    n.removeKeyframe(1);
    expect(current().keyframeBeats, [1, 8, 16]);
  });

  test('urungkan mengembalikan keadaan sebelumnya', () {
    final n = open();
    final before = LenggangFormat.encode(current());
    n.updateDancerAt(1, 'gulu', (s) => s.copyWith(x: 7));
    n.setBpm(90);
    expect(c.read(editorProvider)!.canUndo, isTrue);
    n.undo();
    n.undo();
    expect(LenggangFormat.encode(current()), before);
    expect(c.read(editorProvider)!.canUndo, isFalse);
  });

  test('mengecilkan panggung menjepit posisi penari', () {
    final n = open();
    n.setStage(4, 3);
    final p = current();
    for (final k in p.keyframes.values) {
      for (final s in k.values) {
        expect(s.x, inInclusiveRange(0, 4));
        expect(s.y, inInclusiveRange(0, 3));
      }
    }
  });

  test('pengaturan tersimpan: ambang, radius sampur, tinggi pose', () {
    final n = c.read(settingsProvider.notifier);
    expect(c.read(settingsProvider).collisionThreshold, 0.8);
    expect(c.read(settingsProvider).sampurRadius, 1.2);
    n.update(
      const AppSettings().copyWith(
        collisionThreshold: 1.0,
        sampurRadius: 1.5,
        muted: true,
        poseHeights: {Pose.jengkeng: 1.1},
      ),
    );
    final reread = SettingsStore(HiveKv(settingsBox)).load();
    expect(reread.collisionThreshold, 1.0);
    expect(reread.sampurRadius, 1.5);
    expect(reread.muted, isTrue);
    expect(reread.heightOf(Pose.jengkeng), 1.1);
    expect(reread.heightOf(Pose.ngadeg), 1.6);
  });

  group('Ukuran panggung berubah', () {
    test('formasi diskalakan sebanding (sanggar 8×6 → panggung 16×12)', () {
      final n = open();
      final before = current().keyframes[8]!;
      n.setStage(16, 12);
      final p = current();
      expect(p.stageWidth, 16);
      expect(p.stageDepth, 12);
      for (final id in before.keys) {
        expect(p.keyframes[8]![id]!.x, closeTo(before[id]!.x * 2, 0.011));
        expect(p.keyframes[8]![id]!.y, closeTo(before[id]!.y * 2, 0.011));
        // Arah hadap dan pose tidak berubah.
        expect(p.keyframes[8]![id]!.facing, before[id]!.facing);
        expect(p.keyframes[8]![id]!.pose, before[id]!.pose);
      }
    });

    test('pilihan "jarak tetap": formasi hanya dipusatkan', () {
      final n = open();
      final before = current().keyframes[8]!;
      n.setStage(16, 12, scale: false);
      final after = current().keyframes[8]!;
      expect(
        after['gulu']!.x - after['dhadha']!.x,
        closeTo(before['gulu']!.x - before['dhadha']!.x, 1e-9),
      );
      expect(after['batak']!.x, closeTo(before['batak']!.x + 4, 1e-9));
      expect(after['batak']!.y, closeTo(before['batak']!.y + 3, 1e-9));
    });

    test('bolak-balik 8×6 → 16×12 → 8×6 mengembalikan formasi', () {
      final n = open();
      final before = current().keyframes;
      n.setStage(16, 12);
      n.setStage(8, 6);
      for (final beat in before.keys) {
        for (final id in before[beat]!.keys) {
          expect(
            current().keyframes[beat]![id]!.x,
            closeTo(before[beat]![id]!.x, 0.011),
          );
          expect(
            current().keyframes[beat]![id]!.y,
            closeTo(before[beat]![id]!.y, 0.011),
          );
        }
      }
    });
  });

  group('Benda panggung & properti', () {
    test('tambah, ubah, hapus; ikut berpindah saat panggung diubah', () {
      final n = open();
      final id = n.addObject(
        kind: StageObjectKind.obstacle,
        label: 'Speaker',
        width: 0.6,
        depth: 0.6,
      );
      var o = current().objects.single;
      expect(o.id, id);
      expect(o.left, greaterThanOrEqualTo(0));
      expect(o.back, lessThanOrEqualTo(6));

      n.updateObject(o.copyWith(x: 2, y: 3, label: 'Monitor'));
      o = current().objects.single;
      expect(o.label, 'Monitor');

      n.setStage(16, 12);
      o = current().objects.single;
      expect(o.x, 4);
      expect(o.y, 6);
      expect(o.width, 0.6); // ukuran benda tidak ikut diskalakan

      n.removeObject(id);
      expect(current().objects, isEmpty);
    });

    test('penari di dalam area benda terdeteksi; properti tidak', () {
      const speaker = StageObject(
        id: 'o1',
        kind: StageObjectKind.obstacle,
        label: 'Speaker',
        x: 2,
        y: 2,
        width: 1,
        depth: 1,
      );
      final prop = speaker.copyWith(kind: StageObjectKind.prop);
      final states = {
        'dalam': const DancerState(x: 2.2, y: 2.1),
        'tepi': const DancerState(x: 2.7, y: 2), // 0,2 m dari sisi: badan kena
        'luar': const DancerState(x: 3.5, y: 2),
      };
      final hits = ObstacleDetector.find(states, [speaker]);
      expect(hits.map((h) => h.dancerId).toSet(), {'dalam', 'tepi'});
      expect(ObstacleDetector.find(states, [prop]), isEmpty);
    });
  });

  group('Bahasa penari', () {
    test('letak di panggung dalam sembilan wilayah', () {
      expect(Describe.position(4, 1, 8, 6), 'depan tengah');
      expect(Describe.position(1, 1, 8, 6), 'depan kiri');
      expect(Describe.position(7, 5, 8, 6), 'belakang kanan');
      expect(Describe.position(4, 3, 8, 6), 'tengah');
      expect(Describe.position(7, 3, 8, 6), 'tengah kanan');
    });

    test('arah hadap dalam kata', () {
      expect(Describe.facing(0), 'menghadap penonton');
      expect(Describe.facing(90), 'menghadap kanan');
      expect(Describe.facing(180), 'membelakangi penonton');
      expect(Describe.facing(270), 'menghadap kiri');
      expect(Describe.facing(350), 'menghadap penonton');
      expect(Describe.facing(334), 'serong kiri depan');
      expect(Describe.facing(315), 'serong kiri depan');
    });
  });
}
