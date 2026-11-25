// Membangkitkan berkas bunyi sintetis Lenggang ke assets/audio/.
//
// Jalankan dari akar repo:  dart tool/generate_sounds.dart
import 'dart:io';

// ignore: avoid_relative_lib_imports
import '../lib/services/synth.dart';

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);
  final sounds = {
    'ketuk.wav': Synth.ketuk(),
    'kenong.wav': Synth.kenong(),
    'gong.wav': Synth.gong(),
  };
  for (final e in sounds.entries) {
    final f = File('${dir.path}/${e.key}');
    f.writeAsBytesSync(Synth.toWav(e.value));
    stdout.writeln('${f.path}  ${f.lengthSync()} byte');
  }
}
