import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_game/audio/adaptive_music.dart';
import 'package:flutter_game/audio/techno_score.dart';
import 'package:flutter_game/audio/techno_synth.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithGame<RogueAgentsGame>(
    'game health, pause, draft and death reach the music controller',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      game.damagePlayer(75);
      game.update(0);
      expect(game.music.targetBpm, closeTo(145, 0.01));
      game.pauseEngine();
      expect(game.music.suspended, isTrue);
      game.resumeEngine();
      expect(game.music.suspended, isFalse);
      game.levelUp();
      game.update(0);
      expect(game.music.suspended, isTrue);
      game.chooseUpgrade(game.offered.first);
      game.update(0);
      expect(game.music.suspended, isFalse);
      game.damagePlayer(1000);
      game.update(0);
      expect(game.music.suspended, isTrue);
    },
  );

  test('enemies and low health independently increase musical pressure', () {
    expect(musicPressure(healthFraction: 1, enemies: 0), 0);
    final crowd = musicPressure(healthFraction: 1, enemies: 20);
    final critical = musicPressure(healthFraction: 0.25, enemies: 0);
    expect(crowd, 0.5);
    expect(critical, closeTo(0.75, 0.001));
    expect(
      musicPressure(healthFraction: 0.25, enemies: 20),
      greaterThan(critical),
    );
    expect(musicPressure(healthFraction: -4, enemies: 10000), 1);
    expect(musicPressure(healthFraction: 2, enemies: -1), 0);
  });

  test(
    'tempo ramps in tune, holds phase, and releases pressure more slowly',
    () {
      final synth = TechnoSynth(sampleRate: 22050);
      synth.setPressure(1);
      synth.render(22050);
      expect(synth.bpm, closeTo(124, 0.01));
      final firstSteps = synth.stepsPlayed;
      synth.render(22050 * 6);
      expect(synth.bpm, closeTo(154, 0.01));
      expect(synth.stepsPlayed, greaterThan(firstSteps));
      synth.setPressure(0);
      synth.render(22050);
      expect(synth.bpm, closeTo(151.5, 0.01));
    },
  );

  test('MIDI score stays in range and every step has a valid position', () {
    for (final note in TechnoScore.notes) {
      expect(note.step, inInclusiveRange(0, 127));
      expect(note.note, inInclusiveRange(0, 127));
      expect(note.velocity, inInclusiveRange(1, 127));
    }
  });

  test('PCM is audible, finite, unclipped, stereo and chunk-independent', () {
    final full = TechnoSynth()..setPressure(0.8);
    final split = TechnoSynth()..setPressure(0.8);
    final pcm = full.render(22050);
    final pieces = [...split.render(1234), ...split.render(20816)];
    expect(pieces, orderedEquals(pcm));
    expect(pcm.every((sample) => sample.isFinite && sample.abs() < 1), isTrue);
    final rms = math.sqrt(pcm.fold(0.0, (sum, x) => sum + x * x) / pcm.length);
    expect(rms, greaterThan(0.02));
  });

  test('paused, muted and defeated states suspend music without initializing audio', () async {
    final music = AdaptiveMusic();
    music.setPaused(true);
    expect(music.suspended, isTrue);
    music.setPaused(false);
    expect(music.suspended, isFalse);
    await music.toggle();
    expect(music.enabled, isFalse);
    expect(music.started, isFalse);
    music.updateDanger(healthFraction: 0, enemies: 40);
    expect(music.suspended, isTrue);
    music.dispose();
    await music.unlock();
    expect(music.started, isFalse);
  });
}
