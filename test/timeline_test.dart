import 'package:flutter_test/flutter_test.dart';
import 'package:lenggang/logic/collision.dart';
import 'package:lenggang/logic/templates.dart';
import 'package:lenggang/logic/timeline.dart';
import 'package:lenggang/models/pose.dart';
import 'package:lenggang/models/project.dart';

Project twoDancers() =>
    ProjectTemplates.empty(
      id: 't',
      title: 'T',
      tradition: '',
      choreographer: '',
      width: 8,
      depth: 6,
      now: DateTime.utc(2026),
    ).copyWith(
      dancers: const [
        Dancer(id: 'a', role: 'A', color: 0xFFFFFFFF),
        Dancer(id: 'b', role: 'B', color: 0xFF000000),
      ],
      keyframes: {
        1: {
          'a': const DancerState(x: 1, y: 3, facing: 350, pose: Pose.sila),
          'b': const DancerState(x: 7, y: 3, facing: 0),
        },
        9: {
          'a': const DancerState(x: 7, y: 3, facing: 10, pose: Pose.ngadeg),
          'b': const DancerState(x: 1, y: 3, facing: 180),
        },
      },
    );

void main() {
  group('Siklus Ketawang', () {
    test('kenong di ketukan 8, gong ageng di ketukan 16', () {
      const c = CycleType.ketawang16;
      expect(c.beats, 16);
      expect(
        [
          for (var b = 1; b <= 16; b++)
            if (c.isKenong(b)) b,
        ],
        [8],
      );
      expect(
        [
          for (var b = 1; b <= 16; b++)
            if (c.isGong(b)) b,
        ],
        [16],
      );
    });

    test('ketukan modulo 16', () {
      expect(Timeline.beatAt(1.0, 16), 1);
      expect(Timeline.beatAt(8.99, 16), 8);
      expect(Timeline.beatAt(16.5, 16), 16);
      expect(Timeline.beatAt(17.0, 16), 1);
      expect(Timeline.wrap(17.25, 16), closeTo(1.25, 1e-9));
      expect(Timeline.wrap(16.99, 16), closeTo(16.99, 1e-9));
    });
  });

  group('Interpolasi', () {
    test('tepat di keyframe = isi keyframe', () {
      final p = twoDancers();
      expect(Timeline.stateAt(p, 1), p.keyframes[1]);
      expect(Timeline.stateAt(p, 9), p.keyframes[9]);
    });

    test('berangkat bersama, sampai bersama (fraksi tempuh sama)', () {
      final p = twoDancers();
      for (final t in [2.0, 3.5, 5.0, 8.75]) {
        final s = Timeline.stateAt(p, t);
        final f = (t - 1) / 8;
        expect(s['a']!.x, closeTo(1 + 6 * f, 1e-9));
        expect(s['b']!.x, closeTo(7 - 6 * f, 1e-9));
      }
    });

    test('formasi ditahan setelah keyframe terakhir', () {
      final p = twoDancers();
      expect(Timeline.stateAt(p, 12.3), p.keyframes[9]);
      expect(Timeline.stateAt(p, 16.9), p.keyframes[9]);
    });

    test('arah hadap lewat busur terpendek (350° -> 10° melewati 0°)', () {
      final p = twoDancers();
      expect(Timeline.stateAt(p, 5)['a']!.facing, closeTo(0, 1e-9));
      expect(Timeline.lerpAngle(350, 10, 0.25), closeTo(355, 1e-9));
      expect(Timeline.lerpAngle(10, 350, 0.25), closeTo(5, 1e-9));
    });

    test('snap 45°', () {
      expect(Timeline.snap45(22), 0);
      expect(Timeline.snap45(23), 45);
      expect(Timeline.snap45(350), 0);
      expect(Timeline.snap45(-40), 315);
      expect(Timeline.snap45(200), 180);
    });

    test('tinggi kepala berpindah halus antar pose', () {
      final p = twoDancers();
      double h(Pose x) => x.defaultHeight;
      expect(Timeline.headHeightAt(p, 1, 'a', h), 0.8);
      expect(Timeline.headHeightAt(p, 9, 'a', h), 1.6);
      expect(Timeline.headHeightAt(p, 5, 'a', h), closeTo(1.2, 1e-9));
    });
  });

  group('Deteksi jarak', () {
    test('menandai pasangan di bawah ambang 0,8 m', () {
      final states = {
        'a': const DancerState(x: 1, y: 1),
        'b': const DancerState(x: 1.79, y: 1),
        'c': const DancerState(x: 5, y: 5),
      };
      final hits = CollisionDetector.find(states, 0.8);
      expect(hits.length, 1);
      expect(hits.first.distance, closeTo(0.79, 1e-9));
      expect(CollisionDetector.involved(hits), {'a', 'b'});
    });

    test('tepat 0,8 m belum dianggap terlalu dekat', () {
      final states = {
        'a': const DancerState(x: 1, y: 1),
        'b': const DancerState(x: 1, y: 1.8),
      };
      expect(CollisionDetector.find(states, 0.8), isEmpty);
    });

    test('dua penari yang bersilangan terdeteksi di tengah perjalanan', () {
      final p = twoDancers();
      expect(CollisionDetector.find(Timeline.stateAt(p, 1), 0.8), isEmpty);
      expect(CollisionDetector.find(Timeline.stateAt(p, 5), 0.8), isNotEmpty);
      expect(CollisionDetector.find(Timeline.stateAt(p, 9), 0.8), isEmpty);
    });

    test('preset Srimpi aman sepanjang gongan', () {
      final p = ProjectTemplates.srimpi(
        id: 's',
        title: 'S',
        tradition: '',
        choreographer: '',
        width: 8,
        depth: 6,
      );
      for (var t = 1.0; t < 17; t += 0.05) {
        expect(
          CollisionDetector.find(Timeline.stateAt(p, t), 0.8),
          isEmpty,
          reason: 't=$t',
        );
      }
    });
  });
}
