// Rebuild the editable MIDI and a 36-second demo using the in-game synth.
// fvm dart run tool/render_music.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_game/audio/techno_score.dart';
import 'package:flutter_game/audio/techno_synth.dart';

void main() {
  Directory('artwork/audio').createSync(recursive: true);
  final synth = TechnoSynth();
  const seconds = 36;
  final samples = Int16List(synth.sampleRate * seconds * 2);
  var peak = 0.0;
  final watch = Stopwatch()..start();
  for (var chunk = 0; chunk < seconds * 10; chunk++) {
    synth.setPressure(
      chunk < 120
          ? 0
          : chunk < 240
          ? musicPressure(healthFraction: 1, enemies: 20)
          : musicPressure(healthFraction: 0.20, enemies: 28),
    );
    final pcm = synth.render(synth.sampleRate ~/ 10);
    for (var i = 0; i < pcm.length; i++) {
      if (pcm[i].abs() > peak) peak = pcm[i].abs();
      samples[chunk * pcm.length + i] = (pcm[i] * 32767).round();
    }
    if (chunk == 119 || chunk == 239 || chunk == 359) {
      stdout.writeln(
        '${(chunk + 1) / 10}s: ${synth.bpm.toStringAsFixed(1)} BPM',
      );
    }
  }
  final header = ByteData(44);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  header.setUint32(4, 36 + samples.lengthInBytes, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 2, Endian.little);
  header.setUint32(24, synth.sampleRate, Endian.little);
  header.setUint32(28, synth.sampleRate * 4, Endian.little);
  header.setUint16(32, 4, Endian.little);
  header.setUint16(34, 16, Endian.little);
  text(36, 'data');
  header.setUint32(40, samples.lengthInBytes, Endian.little);
  File('artwork/audio/control_plane_demo.wav').writeAsBytesSync([
    ...header.buffer.asUint8List(),
    ...samples.buffer.asUint8List(),
  ]);
  File('assets/audio/control_plane.mid').writeAsBytesSync(midi());
  stdout.writeln('Rendered in ${watch.elapsedMilliseconds}ms, peak $peak');
}

List<int> variableLength(int value) {
  final bytes = [value & 127];
  while ((value >>= 7) > 0) {
    bytes.insert(0, (value & 127) | 128);
  }
  return bytes;
}

List<int> midi() {
  final out = BytesBuilder();
  void chunk(String name, List<int> data) {
    final size = ByteData(4)..setUint32(0, data.length);
    out.add(name.codeUnits);
    out.add(size.buffer.asUint8List());
    out.add(data);
  }

  chunk('MThd', [0, 1, 0, 5, 1, 224]); // format 1, five tracks, 480 PPQ
  final tempo = (60000000 / 118).round();
  chunk('MTrk', [
    0,
    255,
    81,
    3,
    tempo >> 16,
    (tempo >> 8) & 255,
    tempo & 255,
    0,
    255,
    88,
    4,
    4,
    2,
    24,
    8,
    ...variableLength(15360),
    255,
    47,
    0,
  ]);
  for (final channel in [0, 1, 2, 9]) {
    final name = [
      'Acid bass',
      'Data arpeggio',
      'Minor stabs',
      'Drum machine',
    ][channel == 9 ? 3 : channel];
    final events = <(int, List<int>)>[];
    for (final note in TechnoScore.notes.where((n) => n.channel == channel)) {
      final tick = note.step * 120;
      events.add((tick, [144 | channel, note.note, note.velocity]));
      events.add((
        tick + (channel == 9 ? 60 : (note.gate * 120).round()),
        [128 | channel, note.note, 0],
      ));
    }
    events.sort(
      (a, b) =>
          a.$1 == b.$1 ? a.$2[0].compareTo(b.$2[0]) : a.$1.compareTo(b.$1),
    );
    final track = <int>[0, 255, 3, name.length, ...name.codeUnits];
    if (channel != 9) {
      track.addAll([
        0,
        192 | channel,
        [38, 81, 89][channel],
      ]);
    }
    var last = 0;
    for (final event in events) {
      track.addAll([...variableLength(event.$1 - last), ...event.$2]);
      last = event.$1;
    }
    track.addAll([...variableLength(15360 - last), 255, 47, 0]);
    chunk('MTrk', track);
  }
  return out.takeBytes();
}
