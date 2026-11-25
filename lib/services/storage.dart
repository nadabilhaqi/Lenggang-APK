import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';

import '../models/app_settings.dart';
import '../models/project.dart';
import 'lenggang_format.dart';

/// Antarmuka kunci-nilai kecil agar penyimpanan bisa diganti di pengujian.
abstract class KvStore {
  Iterable<String> get keys;
  String? get(String key);
  bool containsKey(String key);
  Future<void> put(String key, String value);
  Future<void> delete(String key);
}

/// Implementasi produksi: kotak Hive di penyimpanan perangkat.
class HiveKv implements KvStore {
  HiveKv(this._box);

  final Box<String> _box;

  @override
  Iterable<String> get keys => _box.keys.cast<String>();

  @override
  String? get(String key) => _box.get(key);

  @override
  bool containsKey(String key) => _box.containsKey(key);

  @override
  Future<void> put(String key, String value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);
}

/// Implementasi dalam memori untuk widget test.
class MemoryKv implements KvStore {
  final Map<String, String> _data = {};

  @override
  Iterable<String> get keys => _data.keys.toList();

  @override
  String? get(String key) => _data[key];

  @override
  bool containsKey(String key) => _data.containsKey(key);

  @override
  Future<void> put(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// Penyimpanan lokal offline-first berbasis Hive.
///
/// Setiap proyek disimpan sebagai string JSON `.lenggang` (skema yang sama
/// dengan berkas ekspor), sehingga data di perangkat selalu bisa dibaca
/// ulang dan dipindahkan tanpa konversi.
class ProjectStore {
  ProjectStore(this._box);

  static const boxName = 'projects';
  final KvStore _box;

  List<Project> loadAll() {
    final out = <Project>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        out.add(LenggangFormat.decode(raw));
      } on FormatException {
        // Lewati entri rusak alih-alih membuat aplikasi gagal dibuka.
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Project? load(String id) {
    final raw = _box.get(id);
    return raw == null ? null : LenggangFormat.decode(raw);
  }

  bool contains(String id) => _box.containsKey(id);

  Future<void> save(Project p) => _box.put(p.id, LenggangFormat.encode(p));

  Future<void> delete(String id) => _box.delete(id);
}

class SettingsStore {
  SettingsStore(this._box);

  static const boxName = 'settings';
  static const _key = 'app';
  final KvStore _box;

  AppSettings load() {
    final raw = _box.get(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings s) => _box.put(_key, jsonEncode(s.toJson()));
}
