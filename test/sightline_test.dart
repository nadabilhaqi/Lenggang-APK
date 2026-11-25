import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lenggang/logic/templates.dart';
import 'package:lenggang/models/app_settings.dart';
import 'package:lenggang/models/pose.dart';
import 'package:lenggang/models/project.dart';
import 'package:lenggang/ui/sightline/sightline_painter.dart';

Project line({double backX = 4}) =>
    ProjectTemplates.empty(
      id: 's',
      title: 'S',
      tradition: '',
      choreographer: '',
      width: 8,
      depth: 6,
      now: DateTime.utc(2026),
    ).copyWith(
      dancers: const [
        Dancer(id: 'depan', role: 'Depan', color: 0xFFFFFFFF),
        Dancer(id: 'belakang', role: 'Belakang', color: 0xFF00FF00),
      ],
      keyframes: {
        1: {
          'depan': const DancerState(x: 4, y: 2, pose: Pose.ngadeg),
          'belakang': DancerState(x: backX, y: 3.5, pose: Pose.sila),
        },
      },
    );

SightlineCamera cam({double seat = 8, double eye = 1.2}) => SightlineCamera(
  stageWidth: 8,
  stageDepth: 6,
  seatDistance: seat,
  eyeHeight: eye,
  view: const Size(360, 400),
);

void main() {
  group('Proyeksi perspektif', () {
    test('seluruh volume panggung masuk ke bidang pandang', () {
      for (final seat in [2.0, 8.0, 20.0]) {
        for (final eye in [0.3, 1.2, 4.0]) {
          final c = cam(seat: seat, eye: eye);
          for (final x in [0.0, 8.0]) {
            for (final y in [0.0, 2.0]) {
              for (final z in [0.0, 6.0]) {
                final o = c.project(V3(x, y, z))!;
                expect(o.dx, inInclusiveRange(0, 360), reason: '$seat/$eye');
                expect(o.dy, inInclusiveRange(0, 400), reason: '$seat/$eye');
              }
            }
          }
        }
      }
    });

    test(
      'yang dekat tampak lebih besar; kanan tetap di kanan; atas di atas',
      () {
        final c = cam();
        expect(
          c.pixelsPerMeter(const V3(4, 0, 0)),
          greaterThan(c.pixelsPerMeter(const V3(4, 0, 6))),
        );
        expect(
          c.project(const V3(7, 0, 3))!.dx,
          greaterThan(c.project(const V3(1, 0, 3))!.dx),
        );
        expect(
          c.project(const V3(4, 1.6, 3))!.dy,
          lessThan(c.project(const V3(4, 0, 3))!.dy),
        );
        // Tengah panggung berada di tengah layar secara mendatar.
        expect(c.project(const V3(4, 0, 3))!.dx, closeTo(180, 1e-6));
      },
    );

    test('kursi belakang membuat panggung tampak lebih kecil', () {
      double widthAt(double seat) {
        final c = cam(seat: seat);
        return c.project(const V3(8, 0, 0))!.dx -
            c.project(const V3(0, 0, 0))!.dx;
      }

      expect(widthAt(20), lessThan(widthAt(8)));
    });
  });

  group('Urutan kedalaman & halangan pandang', () {
    test('figur diurutkan dari yang terjauh', () {
      final figs = SightlineScene.build(
        project: line(),
        playhead: 1,
        settings: const AppSettings(),
        camera: cam(),
      );
      expect(figs.map((f) => f.dancer.id).toList(), ['belakang', 'depan']);
      expect(figs.first.height, 0.8); // sila
      expect(figs.last.height, 1.6); // ngadeg
    });

    test('penari sila tepat di belakang penari berdiri terhalang', () {
      final figs = SightlineScene.build(
        project: line(),
        playhead: 1,
        settings: const AppSettings(),
        camera: cam(),
      );
      final back = figs.firstWhere((f) => f.dancer.id == 'belakang');
      final front = figs.firstWhere((f) => f.dancer.id == 'depan');
      expect(back.blockedBy, ['Depan']);
      expect(front.blockedBy, isEmpty);
    });

    test('bergeser 1 m ke samping → terlihat lagi', () {
      final figs = SightlineScene.build(
        project: line(backX: 5),
        playhead: 1,
        settings: const AppSettings(),
        camera: cam(),
      );
      expect(figs.every((f) => f.blockedBy.isEmpty), isTrue);
    });

    test('tinggi pose mengikuti pengaturan pengguna', () {
      final figs = SightlineScene.build(
        project: line(),
        playhead: 1,
        settings: const AppSettings(poseHeights: {Pose.sila: 0.95}),
        camera: cam(),
      );
      expect(figs.firstWhere((f) => f.dancer.id == 'belakang').height, 0.95);
    });
  });
}
