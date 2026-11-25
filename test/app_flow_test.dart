import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lenggang/logic/timeline.dart';
import 'package:lenggang/main.dart';
import 'package:lenggang/models/pose.dart';
import 'package:lenggang/models/project.dart';
import 'package:lenggang/services/sound_service.dart';
import 'package:lenggang/services/storage.dart';
import 'package:lenggang/state/providers.dart';
import 'package:lenggang/ui/pose_glyph.dart';
import 'package:lenggang/ui/sightline/sightline_view.dart';
import 'package:lenggang/ui/stage/stage_canvas.dart';
import 'package:lenggang/ui/stage/stage_painter.dart';
import 'package:material_ui/material_ui.dart';

/// Uji alur utama di layar ponsel kecil (360 × 760 dp): beranda → proyek baru
/// → editor (geser, putar, pose, peringatan jarak, putar linimasa, laci).
void main() {
  late MemoryKv projectKv;

  setUpAll(() => SoundService.enabled = false);

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    projectKv = MemoryKv();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectStoreProvider.overrideWithValue(ProjectStore(projectKv)),
          settingsStoreProvider.overrideWithValue(SettingsStore(MemoryKv())),
        ],
        child: const LenggangApp(),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(LenggangApp)));

  Project project(WidgetTester tester) =>
      container(tester).read(editorProvider)!.project;

  Future<void> openNewSrimpi(WidgetTester tester) async {
    await tester.tap(find.text('Buat proyek'));
    await tester.pumpAndSettle();
    expect(find.text('Srimpi · 4 penari'), findsOneWidget);
    await tester.tap(find.text('Buat proyek'));
    await settle(tester);
  }

  /// Posisi layar global pusat penari [id] pada ketukan [beat].
  Offset dancerOnScreen(WidgetTester tester, String id, double beat) {
    final rect = tester.getRect(find.byType(StageCanvas));
    final p = project(tester);
    final g = StageGeometry(
      rect.size,
      p.stageWidth,
      p.stageDepth,
      compact: false,
    );
    final s = Timeline.stateAt(p, beat)[id]!;
    return rect.topLeft + g.toScreen(s.x, s.y);
  }

  double scale(WidgetTester tester) {
    final rect = tester.getRect(find.byType(StageCanvas));
    final p = project(tester);
    return StageGeometry(
      rect.size,
      p.stageWidth,
      p.stageDepth,
      compact: false,
    ).scale;
  }

  testWidgets('beranda kosong → proyek Srimpi → editor tampil', (tester) async {
    await boot(tester);
    expect(find.text('Lenggang'), findsOneWidget);
    expect(find.text('Belum ada proyek'), findsOneWidget);

    await openNewSrimpi(tester);

    expect(find.byType(StageCanvas), findsOneWidget);
    expect(
      find.textContaining('Ketukan 1/16', findRichText: true),
      findsOneWidget,
    );
    // Saat aman tidak ada tulisan status apa pun.
    expect(find.textContaining('Jarak aman'), findsNothing);
    expect(find.textContaining('⚠'), findsNothing);
    final p = project(tester);
    expect(p.dancers.map((d) => d.role), ['Batak', 'Gulu', 'Dhadha', 'Buncit']);
    expect(p.stageWidth, 8);
    expect(p.stageDepth, 6);

    // Kembali: proyek tercantum di beranda (tersimpan di Hive).
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Srimpi'), findsOneWidget);
    expect(find.textContaining('4 penari'), findsOneWidget);
    expect(ProjectStore(projectKv).loadAll().single.title, 'Srimpi');
  });

  testWidgets('geser penari memindah posisi sesuai skala meter', (
    tester,
  ) async {
    await boot(tester);
    await openNewSrimpi(tester);

    final before = project(tester).keyframes[1]!['batak']!;
    final start = dancerOnScreen(tester, 'batak', 1);
    final k = scale(tester);
    // Mulai 12 px dari pusat titik: tetap kena (area sentuh 28 px) dan
    // titik tidak boleh melompat ke posisi jari.
    await tester.dragFrom(
      start + const Offset(12, 0),
      Offset(k * 1.5, -k * 1.0),
    );
    await settle(tester);

    final after = project(tester).keyframes[1]!['batak']!;
    expect(after.x, closeTo(before.x + 1.5, 0.02));
    expect(after.y, closeTo(before.y + 1.0, 0.02));
    // Panel penari menampilkan penari yang digeser.
    expect(find.text('Batak'), findsWidgets);
    expect(find.byTooltip('Putar kanan 45°'), findsOneWidget);
  });

  testWidgets('putar arah hadap (tombol & tuas) dan ubah pose', (tester) async {
    await boot(tester);
    await openNewSrimpi(tester);

    await tester.tapAt(dancerOnScreen(tester, 'gulu', 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Putar kanan 45°'));
    await settle(tester);
    expect(project(tester).keyframes[1]!['gulu']!.facing, 315);
    await tester.tap(find.byTooltip('Putar kiri 45°'));
    await tester.tap(find.byTooltip('Putar kiri 45°'));
    await settle(tester);
    expect(project(tester).keyframes[1]!['gulu']!.facing, 45);

    // Tarik tuas putar ke arah belakang panggung (atas layar) → 180°.
    final rect = tester.getRect(find.byType(StageCanvas));
    final p = project(tester);
    final g = StageGeometry(
      rect.size,
      p.stageWidth,
      p.stageDepth,
      compact: false,
    );
    final s = p.keyframes[1]!['gulu']!;
    final handle = rect.topLeft + g.handlePosition(s);
    final center = rect.topLeft + g.toScreen(s.x, s.y);
    await tester.dragFrom(handle, center + const Offset(3, -70) - handle);
    await settle(tester);
    expect(project(tester).keyframes[1]!['gulu']!.facing, 180);

    await tester.tap(find.text('Sila'));
    await settle(tester);
    expect(project(tester).keyframes[1]!['gulu']!.pose, Pose.sila);
    // Pose penari lain dan keyframe lain tidak ikut berubah.
    expect(project(tester).keyframes[1]!['batak']!.pose, Pose.jengkeng);
    expect(project(tester).keyframes[8]!['gulu']!.pose, Pose.mendhak);
  });

  testWidgets('dua penari < 0,8 m memunculkan peringatan', (tester) async {
    await boot(tester);
    await openNewSrimpi(tester);
    expect(find.textContaining('⚠'), findsNothing);

    final from = dancerOnScreen(tester, 'gulu', 1);
    final to = dancerOnScreen(tester, 'batak', 1);
    final k = scale(tester);
    // Geser Gulu hingga 0,5 m dari Batak.
    await tester.dragFrom(from, to - from + Offset(0, -0.5 * k));
    await settle(tester);

    expect(find.textContaining('⚠ Batak–Gulu 0,50 m'), findsOneWidget);
    expect(find.textContaining('Jarak aman'), findsNothing);

    // Urungkan → aman kembali.
    await tester.tap(find.byTooltip('Urungkan'));
    await settle(tester);
    expect(find.textContaining('⚠'), findsNothing);
  });

  testWidgets('linimasa: lompat ketukan, keyframe baru, putar & jeda', (
    tester,
  ) async {
    await boot(tester);
    await openNewSrimpi(tester);

    await tester.tap(find.byTooltip('Ketukan berikutnya'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Ketukan 2/16', findRichText: true),
      findsOneWidget,
    );

    // Mengedit di ketukan 2 (belum ada keyframe) membuat keyframe di sana.
    expect(project(tester).keyframeBeats, [1, 8, 16]);
    final at = dancerOnScreen(tester, 'buncit', 2);
    await tester.dragFrom(at, const Offset(30, 0));
    await settle(tester);
    expect(project(tester).keyframeBeats, [1, 2, 8, 16]);

    await tester.tap(find.byTooltip('Hapus formasi ketukan 2'));
    await settle(tester);
    expect(project(tester).keyframeBeats, [1, 8, 16]);

    // Putar: playhead maju mengikuti BPM (60 BPM → 1 ketukan/detik).
    await tester.tap(find.byTooltip('Putar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.byTooltip('Jeda'), findsOneWidget);
    expect(
      find.textContaining('Ketukan 4/16', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Jeda'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Putar'), findsOneWidget);

    // Lompat mundur dari ketukan 4 ke 3, lalu ke kenong (8) lewat tombol.
    await tester.tap(find.byTooltip('Ketukan sebelumnya'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Ketukan 3/16', findRichText: true),
      findsOneWidget,
    );
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Ketukan berikutnya'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Ketukan 8/16 · Kenong', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('laci proyek: tambah & hapus penari, ukuran panggung', (
    tester,
  ) async {
    await boot(tester);
    await openNewSrimpi(tester);

    await tester.tap(find.byTooltip('Pengaturan proyek'));
    await tester.pumpAndSettle();
    expect(find.text('Pentas'), findsOneWidget);
    expect(find.text('8,0 m'), findsOneWidget);
    expect(find.text('6,0 m'), findsOneWidget);
    await tester.tap(find.byTooltip('Tambah Panjang (kiri–kanan)'));
    await settle(tester);
    expect(project(tester).stageWidth, 8.5);

    await tester.tap(find.text('Penari'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah penari'));
    await settle(tester);
    expect(project(tester).dancers.length, 5);
    expect(find.text('Penari 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus Penari 5'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus penari'));
    await settle(tester);
    expect(project(tester).dancers.length, 4);

    await tester.tap(find.text('Ekspor'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan PNG'), findsOneWidget);
    expect(find.text('Simpan berkas'), findsOneWidget);
  });
  testWidgets('toggle Denah/3D ada di editor dan 3D ikut linimasa', (
    tester,
  ) async {
    await boot(tester);
    await openNewSrimpi(tester);
    expect(find.text('Denah'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);

    await tester.tap(find.text('3D'));
    await tester.pumpAndSettle();
    expect(find.byType(SightlineView), findsOneWidget);
    expect(find.byType(StageCanvas), findsNothing);
    expect(find.text('Samping'), findsOneWidget);
    expect(find.text('Jarak'), findsOneWidget);
    expect(find.text('Tinggi'), findsOneWidget);

    // Geser layar: kursi pindah ke samping dan pandangan naik.
    await tester.drag(find.byType(SightlineView), const Offset(-80, 60));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kanan'), findsOneWidget);

    await tester.tap(find.byTooltip('Putar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.byTooltip('Jeda'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Denah'));
    await tester.pumpAndSettle();
    expect(find.byType(StageCanvas), findsOneWidget);
  });

  testWidgets('pemilih pose bergambar dan keterangan berbahasa penari', (
    tester,
  ) async {
    await boot(tester);
    await openNewSrimpi(tester);
    await tester.tapAt(dancerOnScreen(tester, 'batak', 1));
    await tester.pumpAndSettle();
    expect(find.byType(PoseGlyph), findsNWidgets(5));
    // Batak berada di depan tengah menghadap penonton: tanpa x/y/derajat.
    expect(find.text('depan tengah · menghadap penonton'), findsOneWidget);
    expect(find.textContaining('°'), findsNothing);
  });

  testWidgets('ubah ukuran panggung: formasi ikut merenggang', (tester) async {
    await boot(tester);
    await openNewSrimpi(tester);
    final before = project(tester).keyframes[8]!;
    final spread = before['gulu']!.x - before['dhadha']!.x;

    await tester.tap(find.byTooltip('Pengaturan proyek'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Tambah Panjang (kiri–kanan)'));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final p = project(tester);
    expect(p.stageWidth, 10);
    final after = p.keyframes[8]!;
    expect(
      after['gulu']!.x - after['dhadha']!.x,
      closeTo(spread * 10 / 8, 0.03),
    );
    // Tetap simetris terhadap tengah panggung.
    expect(after['batak']!.x, closeTo(5, 0.02));
  });

  testWidgets(
    'benda panggung: tambah dari laci, penari masuk area → peringatan',
    (tester) async {
      await boot(tester);
      await openNewSrimpi(tester);
      await tester.tap(find.byTooltip('Pengaturan proyek'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Benda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speaker'));
      await tester.pumpAndSettle();
      final o = project(tester).objects.single;
      expect(o.label, 'Speaker');
      expect(o.kind, StageObjectKind.obstacle);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('⚠'), findsNothing);

      // Geser Buncit ke tengah area speaker.
      final rect = tester.getRect(find.byType(StageCanvas));
      final g = StageGeometry(rect.size, 8, 6, compact: false);
      final from = dancerOnScreen(tester, 'buncit', 1);
      final to = rect.topLeft + g.toScreen(o.x, o.y);
      await tester.dragFrom(from, to - from);
      await tester.pumpAndSettle();
      expect(find.textContaining('⚠ Buncit di area Speaker'), findsOneWidget);
    },
  );

  testWidgets('urungkan lalu ulangi', (tester) async {
    await boot(tester);
    await openNewSrimpi(tester);
    final start = project(tester).keyframes[1]!['batak']!;
    final at = dancerOnScreen(tester, 'batak', 1);
    await tester.dragFrom(at, Offset(scale(tester), 0));
    await tester.pumpAndSettle();
    final moved = project(tester).keyframes[1]!['batak']!;
    expect(moved.x, closeTo(start.x + 1, 0.02));

    await tester.tap(find.byTooltip('Urungkan'));
    await tester.pumpAndSettle();
    expect(project(tester).keyframes[1]!['batak']!.x, start.x);

    await tester.tap(find.byTooltip('Ulangi'));
    await tester.pumpAndSettle();
    expect(project(tester).keyframes[1]!['batak']!.x, moved.x);
    // Perubahan baru menghapus antrean "ulangi".
    await tester.tap(find.byTooltip('Urungkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Putar kanan 45°'));
    await tester.pumpAndSettle();
    expect(container(tester).read(editorProvider)!.canRedo, isFalse);
  });

  testWidgets(
    'tombol putar persis di tengah; tanpa panel saat tak ada pilihan',
    (tester) async {
      await boot(tester);
      await openNewSrimpi(tester);
      final play = tester.getCenter(find.byTooltip('Putar'));
      expect(play.dx, closeTo(180, 0.5));
      expect(find.byTooltip('Putar kanan 45°'), findsNothing);
      expect(find.textContaining('Ketuk penari'), findsNothing);
      // Toggle tampilan berada di baris status, bukan di atas kanvas.
      final toggle = tester.getRect(find.text('3D'));
      final canvas = tester.getRect(find.byType(StageCanvas));
      expect(toggle.bottom, lessThanOrEqualTo(canvas.top));
    },
  );

  testWidgets('benda dipilih dan dihapus langsung dari denah', (tester) async {
    await boot(tester);
    await openNewSrimpi(tester);
    container(tester)
        .read(editorProvider.notifier)
        .addObject(
          kind: StageObjectKind.prop,
          label: 'Dhadhap',
          width: 0.5,
          depth: 0.5,
        );
    await tester.pumpAndSettle();
    final o = project(tester).objects.single;
    final rect = tester.getRect(find.byType(StageCanvas));
    final g = StageGeometry(rect.size, 8, 6, compact: false);
    await tester.tapAt(rect.topLeft + g.toScreen(o.x, o.y));
    await tester.pumpAndSettle();
    expect(find.text('Dhadhap'), findsOneWidget);
    await tester.tap(find.byTooltip('Hapus Dhadhap'));
    await tester.pumpAndSettle();
    expect(project(tester).objects, isEmpty);
    expect(find.text('Dhadhap'), findsNothing);
    // Bisa dikembalikan dengan Urungkan.
    await tester.tap(find.byTooltip('Urungkan'));
    await tester.pumpAndSettle();
    expect(project(tester).objects.single.label, 'Dhadhap');
  });

  testWidgets('pengatur kursi 3D bisa disembunyikan', (tester) async {
    await boot(tester);
    await openNewSrimpi(tester);
    await tester.tap(find.text('3D'));
    await tester.pumpAndSettle();
    expect(find.text('Samping'), findsOneWidget);
    await tester.tap(find.byTooltip('Sembunyikan pengatur kursi'));
    await tester.pumpAndSettle();
    expect(find.text('Samping'), findsNothing);
    expect(find.text('Jarak'), findsNothing);
    await tester.tap(find.byTooltip('Tampilkan pengatur kursi'));
    await tester.pumpAndSettle();
    expect(find.text('Tinggi'), findsOneWidget);
  });

  testWidgets('panduan ruang baru bisa diubah lewat ikon edit', (tester) async {
    await boot(tester);
    await openNewSrimpi(tester);
    await tester.tap(find.byTooltip('Pengaturan proyek'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Ubah Jarak aman'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tambah Jarak aman'), findsNothing);
    await tester.tap(find.byTooltip('Ubah Jarak aman'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah Jarak aman'));
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(
      container(tester).read(settingsProvider).collisionThreshold,
      closeTo(0.9, 1e-9),
    );
  });

  testWidgets('cubit dua jari di 3D memajukan kursi', (tester) async {
    await boot(tester);
    await openNewSrimpi(tester);
    await tester.tap(find.text('3D'));
    await tester.pumpAndSettle();
    expect(find.text('Tengah 8 m'), findsOneWidget);

    final c =
        tester.getRect(find.byType(SightlineView)).topCenter +
        const Offset(0, 150);
    final a = await tester.startGesture(c - const Offset(30, 0), pointer: 1);
    final b = await tester.startGesture(c + const Offset(30, 0), pointer: 2);
    await tester.pump();
    await a.moveBy(const Offset(-60, 0));
    await b.moveBy(const Offset(60, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    expect(find.text('Tengah 8 m'), findsNothing);
    expect(find.textContaining('Depan'), findsOneWidget);
  });

  test('kursi penonton berskala 1:1 dengan panggung (0,5 m per kursi)', () {
    final g = StageGeometry(const Size(352, 500), 8, 6, compact: false);
    final seats = g.seatRects();
    expect(seats, isNotEmpty);
    for (final s in seats) {
      expect(s.width, closeTo(0.5 * g.scale, 1e-9));
      expect(s.height, s.width);
      expect(s.left, greaterThanOrEqualTo(g.stage.left - 0.5));
      expect(s.right, lessThanOrEqualTo(g.stage.right + 0.5));
      expect(s.top, greaterThan(g.stage.bottom));
      expect(s.bottom, lessThanOrEqualTo(500));
    }
    // Minimal dua baris pada layar ponsel.
    expect(seats.map((s) => s.top).toSet().length, greaterThanOrEqualTo(2));
  });
}
