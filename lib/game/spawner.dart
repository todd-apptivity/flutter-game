import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_game/config/agents.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/waves.dart';
import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';

/// Pushes rogue agents in from the edges of the arena, following the wave
/// table in lib/config/waves.dart.
class Spawner extends Component with HasGameReference<RogueAgentsGame> {
  Spawner({Random? random}) : _random = random ?? Random();

  final Random _random;

  double _cooldown = GameConfig.firstSpawnDelay;

  /// The wave that was live last frame, so a change can be announced.
  WaveSpec? _lastWave;

  /// The wave in force right now.
  WaveSpec get wave => waveAt(game.elapsed);

  /// Seconds between spawn events right now.
  double get interval => wave.interval;

  /// Live agents, used for the cap and the HUD.
  int get agentCount => game.world.children.whereType<Agent>().length;

  /// The boss is a one-off on the clock, not a wave-table entry.
  bool bossSpawned = false;

  @override
  void update(double dt) {
    final current = wave;
    if (_lastWave != null && !identical(current, _lastWave)) {
      game.onWaveChanged(current);
    }
    _lastWave = current;

    // After the wave check, so the boss banner is not immediately overwritten
    // by the wave that happens to start at the same moment.
    if (!bossSpawned && game.elapsed >= GameConfig.bossTime) {
      bossSpawned = true;
      game.onBossArrived(spawn(agentSpec('orchestrator')));
    }

    _cooldown -= dt;
    if (_cooldown > 0) return;
    _cooldown = interval;

    if (agentCount >= GameConfig.maxAgents) return;
    spawnFromWave(current);
  }

  /// Rolls one agent type from [wave] and spawns its whole group.
  List<Agent> spawnFromWave(WaveSpec wave) {
    final spec = agentSpec(_rollType(wave));
    final anchor = randomEdgePosition(spec);

    // A group arrives together, scattered a little so they do not overlap
    // perfectly and read as one sprite.
    return [
      for (var i = 0; i < spec.groupSize; i++)
        spawnAt(
          spec,
          spec.groupSize == 1
              ? anchor
              : anchor +
                  Vector2(
                    (_random.nextDouble() - 0.5) * spec.renderSize.x * 4,
                    (_random.nextDouble() - 0.5) * spec.renderSize.y * 4,
                  ),
        ),
    ];
  }

  String _rollType(WaveSpec wave) {
    final total = wave.weights.values.fold<int>(0, (sum, w) => sum + w);
    var roll = _random.nextInt(total);
    for (final entry in wave.weights.entries) {
      roll -= entry.value;
      if (roll < 0) return entry.key;
    }
    return wave.weights.keys.last;
  }

  /// Adds one [spec] just outside a random edge of the arena.
  Agent spawn(AgentSpec spec) => spawnAt(spec, randomEdgePosition(spec));

  Agent spawnAt(AgentSpec spec, Vector2 position) {
    final agent = Agent(spec: spec, position: position);
    game.world.add(agent);
    return agent;
  }

  /// A point just off the arena, so agents walk into view rather than popping
  /// into existence in front of the player.
  Vector2 randomEdgePosition(AgentSpec spec) {
    final bounds = game.arena.bounds;
    final out = spec.renderSize.x + GameConfig.spawnOffscreen;

    return switch (_random.nextInt(4)) {
      0 => Vector2(_between(bounds.left, bounds.right), bounds.top - out),
      1 => Vector2(_between(bounds.left, bounds.right), bounds.bottom + out),
      2 => Vector2(bounds.left - out, _between(bounds.top, bounds.bottom)),
      _ => Vector2(bounds.right + out, _between(bounds.top, bounds.bottom)),
    };
  }

  double _between(double a, double b) => a + _random.nextDouble() * (b - a);
}
