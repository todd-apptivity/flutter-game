import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game/config/agents.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/projectile.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Needed so the asset bundle exists: the loaders expect a missing-file
  // failure, not a missing-binding failure.
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithGame<RogueAgentsGame>(
    'player spawns in the centre of the design rect',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      expect(game.player.position, GameConfig.designSize / 2);
    },
  );

  testWithGame<RogueAgentsGame>(
    'arena is inset from the design rect by the margin',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      expect(game.arena.bounds.left, GameConfig.arenaMargin);
      expect(
        game.arena.bounds.right,
        GameConfig.designWidth - GameConfig.arenaMargin,
      );
    },
  );

  testWithGame<RogueAgentsGame>(
    'held keys move the player and beat the mouse',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final start = game.player.position.clone();

      // Mouse sits to the left; keys say right. Keys win.
      game.input.pointer = Vector2(0, start.y);
      game.input.syncKeys({LogicalKeyboardKey.keyD});
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
      }

      expect(game.player.position.x, greaterThan(start.x));
      expect(game.player.position.y, closeTo(start.y, 0.001));
    },
  );

  testWithGame<RogueAgentsGame>(
    'with no keys held the player chases the pointer',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final start = game.player.position.clone();

      game.input.pointer = Vector2(start.x, start.y - 200);
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
      }

      expect(game.player.position.y, lessThan(start.y));
    },
  );

  testWithGame<RogueAgentsGame>(
    'the player cannot leave the arena',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      game.input.syncKeys({LogicalKeyboardKey.arrowLeft});
      for (var i = 0; i < 600; i++) {
        game.update(1 / 60);
      }

      final half = game.player.size.x / 2;
      expect(
        game.player.position.x,
        greaterThanOrEqualTo(game.arena.bounds.left + half - 0.001),
      );
    },
  );

  testWithGame<RogueAgentsGame>(
    'agents spawn outside the arena on the interval',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      expect(game.world.children.whereType<Agent>(), isEmpty);

      // The grace period, then one interval: exactly two spawns are due.
      game.update(GameConfig.firstSpawnDelay + 0.01);
      game.update(GameConfig.spawnInterval + 0.01);
      await game.ready();

      final agents = game.world.children.whereType<Agent>().toList();
      expect(agents, hasLength(2));
      for (final agent in agents) {
        expect(game.arena.bounds.contains(agent.position.toOffset()), isFalse);
      }
    },
  );

  testWithGame<RogueAgentsGame>(
    'a spawned agent closes on the control plane',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      final agent = game.spawner.spawn(agentSpec('scraper'));
      // onLoad is async (it tries for a sprite), so the agent only mounts and
      // starts updating once that future settles.
      await game.ready();
      final before = agent.position.distanceTo(game.player.position);

      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }

      expect(
        agent.position.distanceTo(game.player.position),
        lessThan(before - 50),
      );
    },
  );

  testWithGame<RogueAgentsGame>(
    'the weapon holds fire with nothing in range',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
      }
      await game.ready();

      // Agents spawn off-arena, well outside the Packet Cannon's range.
      expect(game.world.children.whereType<Agent>(), isNotEmpty);
      expect(game.world.children.whereType<Projectile>(), isEmpty);
    },
  );

  testWithGame<RogueAgentsGame>(
    'the weapon fires at an agent that comes into range',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final weapon = game.weapons.single;

      final agent = Agent(
        spec: agentSpec('scraper'),
        position: game.player.position + Vector2(120, 0),
      );
      await game.world.add(agent);
      await game.ready();

      expect(weapon.nearestAgent(), agent);
      game.update(weapon.cooldown + 0.01);
      await game.ready();

      final shots = game.world.children.whereType<Projectile>().toList();
      expect(shots, hasLength(1));
      // Aimed right, at the agent.
      expect(shots.single.direction.x, closeTo(1, 0.001));
      expect(shots.single.direction.y, closeTo(0, 0.001));
    },
  );

  testWithGame<RogueAgentsGame>(
    'projectiles expire at the end of their range',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final weapon = game.weapons.single;

      weapon.fireAt(game.player.position + Vector2(0, -100));
      await game.ready();
      expect(game.world.children.whereType<Projectile>(), hasLength(1));

      // Long enough to outrun the range, from the centre of the arena.
      for (var i = 0; i < 180; i++) {
        game.update(1 / 60);
      }
      await game.ready();

      expect(game.world.children.whereType<Projectile>(), isEmpty);
    },
  );
}
