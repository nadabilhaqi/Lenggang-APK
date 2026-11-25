import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Memutar bunyi sintetis ketukan, kenong, dan gong ageng.
///
/// Berkas WAV di `assets/audio/` dibangkitkan oleh `tool/generate_sounds.dart`
/// dari rumus di `lib/services/synth.dart`.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  AudioPool? _ketuk;
  AudioPool? _kenong;
  AudioPool? _gong;
  Future<void>? _loading;

  /// Dimatikan pada widget test (tidak ada kanal platform audio).
  static bool enabled = true;

  Future<void> init() =>
      enabled ? (_loading ??= _load()) : Future<void>.value();

  Future<void> _load() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
      _ketuk = await AudioPool.createFromAsset(
        path: 'audio/ketuk.wav',
        maxPlayers: 3,
        playerMode: PlayerMode.lowLatency,
      );
      _kenong = await AudioPool.createFromAsset(
        path: 'audio/kenong.wav',
        maxPlayers: 2,
        playerMode: PlayerMode.lowLatency,
      );
      _gong = await AudioPool.createFromAsset(
        path: 'audio/gong.wav',
        maxPlayers: 2,
        playerMode: PlayerMode.lowLatency,
      );
    } catch (e) {
      // Tanpa audio pun aplikasi tetap berjalan.
      debugPrint('Gagal memuat bunyi: $e');
    }
  }

  /// Bunyikan ketukan ke-[beat]; tambah kenong/gong bila jatuh di ketukan itu.
  void playBeat({required bool kenong, required bool gong}) {
    _play(_ketuk, gong || kenong ? 0.5 : 0.9);
    if (kenong) _play(_kenong, 0.9);
    if (gong) _play(_gong, 1.0);
  }

  void _play(AudioPool? pool, double volume) {
    if (pool == null) return;
    pool.start(volume: volume).catchError((Object e) {
      debugPrint('Gagal memutar bunyi: $e');
      return () async {};
    });
  }
}
