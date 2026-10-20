import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_game/config/agents.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';

/// Pushes rogue agents in from the edges of the arena.
///
/// Stage 9 replaces the fixed interval and single type with a wave table; the
/// spawn-position maths stays the same.
class Spawner extends Component with HasGameReference<RogueAgentsGame> {
  Spawner({Random? random}) : _random = random ?? Random();

  final Random _random;

  double _cooldown = GameConfig.firstSpawnDelay;

  /// Seconds between spawns right now.
  double get interval => GameConfig.spawnInterval;

  /// Live agents, used for the cap and later for the HUD.
  int get agentCount => game.world.children.whereType<Agent>().length;

  @override
  void update(double dt) {
    _cooldown -= dt;
    if (_cooldown > 0) return;
    _cooldown = interval;

    if (agentCount >= GameConfig.maxAgents) return;
    spawn(agentCatalog.first);
  }

  /// Adds one [spec] just outside a random edge of the arena.
  Agent spawn(AgentSpec spec) {
    final agent = Agent(spec: spec, position: randomEdgePosition(spec));
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
