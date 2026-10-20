import 'dart:math' as math;
import 'dart:typed_data';

import 'techno_score.dart';

/// A small MIDI-note sampler/synth. Tempo changes the sequencer clock, never
/// sample playback speed, so the bass and melody stay in tune under pressure.
class TechnoSynth {
  TechnoSynth({this.sampleRate = 22050}) {
    for (final note in TechnoScore.notes) {
      _samples.putIfAbsent((
        note.channel,
        note.note,
      ), () => _makeSample(note.channel, note.note));
    }
    _delayL = Float32List((sampleRate * 0.1875).round());
    _delayR = Float32List((sampleRate * 0.28125).round());
  }

  final int sampleRate;
  final _samples = <(int, int), Float32List>{};
  final _voices = <_Voice>[];
  late final Float32List _delayL;
  late final Float32List _delayR;
  int _delayIndex = 0;
  int _step = 0;
  double _untilStep = 0;
  double _kick = 0;
  double _fadeIn = 0;
  double _pressure = 0;
  double _targetPressure = 0;
  double bpm = 118;
  int renderedFrames = 0;
  int stepsPlayed = 0;

  double get pressure => _pressure;
  double get targetBpm => 118 + 36 * _targetPressure;

  void setPressure(double value) {
    _targetPressure = value.isFinite ? value.clamp(0.0, 1.0) : 0;
  }

  /// Interleaved stereo float PCM; rendering chunks of any size produces the
  /// same timing. The fractional sample countdown never resets on tempo changes.
  Float32List render(int frames) {
    final out = Float32List(frames * 2);
    final rise = 6 / sampleRate;
    final fall = 2.5 / sampleRate;
    for (var i = 0; i < frames; i++) {
      bpm += (targetBpm - bpm).clamp(-fall, rise);
      _pressure += (_targetPressure - _pressure) / (sampleRate * 1.5);
      if (_untilStep <= 0) {
        _triggerStep();
        _untilStep += sampleRate * 60 / bpm / 4;
      }
      _untilStep--;
      var left = 0.0, right = 0.0, send = 0.0;
      final duck = 1 - _kick * 0.48;
      for (final voice in _voices) {
        if (voice.position >= voice.length) continue;
        final remaining = voice.length - voice.position;
        final release = math.min(1.0, remaining / (sampleRate * 0.018));
        final gain = voice.gain * release * (voice.channel == 9 ? 1 : duck);
        final value = voice.samples[voice.position++] * gain;
        left += value * voice.left;
        right += value * voice.right;
        if (voice.channel == 1 || voice.channel == 2) send += value * 0.22;
      }
      _voices.removeWhere((voice) => voice.position >= voice.length);
      final li = _delayIndex % _delayL.length,
          ri = _delayIndex % _delayR.length;
      final echoL = _delayL[li], echoR = _delayR[ri];
      _delayL[li] = send + echoR * 0.3;
      _delayR[ri] = send + echoL * 0.3;
      _delayIndex++;
      left += echoL;
      right += echoR;
      _fadeIn = math.min(1, _fadeIn + 1 / (sampleRate * 0.06));
      // Soft saturation with a strict bound; leaves headroom for future SFX.
      out[i * 2] = left / (1 + left.abs()) * _fadeIn;
      out[i * 2 + 1] = right / (1 + right.abs()) * _fadeIn;
      _kick *= 0.9993;
    }
    renderedFrames += frames;
    return out;
  }

  void _triggerStep() {
    for (final note in TechnoScore.byStep[_step]) {
      if (_pressure < note.pressure) continue;
      final sample = _samples[(note.channel, note.note)]!;
      final pan = note.channel == 1 ? (_step.isEven ? -0.35 : 0.35) : 0.0;
      final length = note.channel == 9
          ? sample.length
          : math.min(
              sample.length,
              (note.gate * sampleRate * 60 / bpm / 4).round(),
            );
      if (note.channel == 9 && note.note == 36) _kick = 1;
      _voices.add(
        _Voice(
          sample,
          length,
          note.channel,
          note.velocity / 127,
          math.sqrt((1 - pan) / 2),
          math.sqrt((1 + pan) / 2),
        ),
      );
    }
    _step = (_step + 1) % TechnoScore.steps;
    stepsPlayed++;
  }

  Float32List _makeSample(int channel, int note) {
    final frequency = 440 * math.pow(2, (note - 69) / 12);
    final duration = channel == 9 ? (note == 46 ? 0.23 : 0.30) : 0.5;
    final data = Float32List((sampleRate * duration).ceil());
    final random = math.Random(note * 31 + channel);
    var phase = 0.0, low = 0.0, band = 0.0, previousNoise = 0.0;
    for (var i = 0; i < data.length; i++) {
      final t = i / sampleRate;
      final attack = math.min(1.0, t / 0.003);
      final tail = math.min(1.0, (data.length - i) / (sampleRate * 0.012));
      var value = 0.0;
      if (channel == 9) {
        final noise = random.nextDouble() * 2 - 1;
        final high = (noise - previousNoise) * 0.5;
        previousNoise = noise;
        if (note == 36) {
          phase += 2 * math.pi * (46 + 145 * math.exp(-t * 47)) / sampleRate;
          value =
              1.25 * math.sin(phase) * math.exp(-t * 14) +
              high * 0.12 * math.exp(-t * 220);
        } else if (note == 38 || note == 39) {
          final clap =
              math.exp(-t * 30) +
              (t > 0.012 ? 0.6 * math.exp(-(t - 0.012) * 80) : 0) +
              (t > 0.025 ? 0.5 * math.exp(-(t - 0.025) * 80) : 0);
          value =
              high * clap * 0.55 +
              math.sin(2 * math.pi * 180 * t) * math.exp(-t * 40) * 0.10;
        } else {
          value = high * math.exp(-t * (note == 46 ? 22 : 80)) * 0.40;
        }
      } else if (channel == 0) {
        // Resonant low-pass acid bass: band-limited saw, punchy filter envelope.
        var saw = 0.0;
        for (var h = 1; h <= 8; h++) {
          saw += math.sin(2 * math.pi * frequency * h * t) / h;
        }
        final cutoff = 260 + 1700 * math.exp(-t * 23);
        final f = 2 * math.sin(math.pi * cutoff / sampleRate);
        low += f * band;
        final high = saw * 0.5 - low - band * 0.65;
        band += f * high;
        value =
            (low * 0.55 + math.sin(2 * math.pi * frequency * t) * 0.25) *
            math.exp(-t * 8);
      } else if (channel == 1) {
        final phase = 2 * math.pi * frequency * t;
        value =
            (math.sin(phase) +
                0.28 * math.sin(phase * 2) +
                0.12 * math.sin(phase * 3)) *
            math.exp(-t * 19) *
            0.35;
      } else {
        final phase = 2 * math.pi * frequency * t;
        value =
            (math.sin(phase) +
                math.sin(phase * 1.004) * 0.5 +
                math.sin(phase * 2) * 0.25) *
            math.exp(-t * 12) *
            0.20;
      }
      data[i] = value * attack * tail;
    }
    return data;
  }
}

class _Voice {
  _Voice(
    this.samples,
    this.length,
    this.channel,
    this.gain,
    this.left,
    this.right,
  );
  final Float32List samples;
  final int length;
  final int channel;
  final double gain;
  final double left;
  final double right;
  int position = 0;
}
