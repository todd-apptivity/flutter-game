/// Original eight-bar E-minor techno score. Channels follow MIDI conventions:
/// 0 = acid bass, 1 = arpeggio, 2 = chord stabs, 9 = GM percussion.
class MidiNote {
  const MidiNote(
    this.step,
    this.channel,
    this.note,
    this.velocity, {
    this.gate = 0.75,
    this.pressure = 0,
  });

  final int step;
  final int channel;
  final int note;
  final int velocity;
  final double gate;
  final double pressure;
}

class TechnoScore {
  static const steps = 128;
  static final notes = _compose();
  static final byStep = List.generate(
    steps,
    (step) => notes.where((note) => note.step == step).toList(),
  );

  static List<MidiNote> _compose() {
    final notes = <MidiNote>[];
    const roots = [28, 28, 26, 26, 24, 24, 26, 26];
    const bass = [0, -1, 0, 12, -1, 0, 7, -1, 0, -1, 12, 0, -1, 7, 0, 12];
    const arp = [0, 7, 12, 15, 7, 12, 19, 12, 0, 7, 15, 12, 19, 15, 12, 7];
    for (var bar = 0; bar < 8; bar++) {
      final root = roots[bar];
      for (var s = 0; s < 16; s++) {
        final step = bar * 16 + s;
        if (s % 4 == 0) notes.add(MidiNote(step, 9, 36, 115));
        if (s == 4 || s == 12) notes.add(MidiNote(step, 9, 39, 84));
        if (s % 4 == 2) notes.add(MidiNote(step, 9, 46, 62));
        if (s.isOdd) {
          notes.add(
            MidiNote(step, 9, 42, s % 4 == 3 ? 56 : 38, pressure: 0.22),
          );
        }
        if (bar % 4 == 3 && s >= 14) {
          notes.add(MidiNote(step, 9, 38, 50 + (s - 14) * 15, pressure: 0.55));
        }
        if (bass[s] >= 0) {
          notes.add(
            MidiNote(
              step,
              0,
              root + bass[s],
              s % 4 == 0 ? 108 : 82,
              gate: s == 14 ? 1.3 : 0.7,
            ),
          );
        }
        if (s % 4 == 2 || s % 4 == 3) {
          notes.add(
            MidiNote(
              step,
              1,
              root + 36 + arp[s],
              66,
              pressure: s.isOdd ? 0.58 : 0,
            ),
          );
        }
        if (s == 0 || s == 10) {
          // D bars use a major third; E and C use a minor/darker voicing.
          for (final interval in [0, root == 26 || root == 24 ? 4 : 3, 7, 14]) {
            notes.add(
              MidiNote(
                step,
                2,
                root + 24 + interval,
                48,
                gate: 2.4,
                pressure: 0.1,
              ),
            );
          }
        }
      }
    }
    return List.unmodifiable(notes);
  }
}

/// Continuous pressure avoids abrupt switches when one enemy dies.
double musicPressure({required double healthFraction, required int enemies}) {
  final health = healthFraction.isFinite ? healthFraction.clamp(0.0, 1.0) : 1.0;
  final crowd = (enemies / 40).clamp(0.0, 1.0);
  final danger = ((0.55 - health) / 0.40).clamp(0.0, 1.0);
  return 1 - (1 - crowd) * (1 - danger);
}
