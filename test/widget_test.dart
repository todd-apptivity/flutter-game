import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game/config/agents.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/upgrades.dart';
import 'package:flutter_game/config/weapons.dart';
import 'package:flutter_game/config/waves.dart';
import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/injection.dart';
import 'package:flutter_game/game/projectile.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';
import 'package:flutter_game/game/token.dart';
import 'package:flutter_test/flutter_test.dart';

/// Advances [frames] frames, letting the component tree settle between them.
///
/// A bare loop of `game.update()` never yields to the event loop, so any
/// component with an async `onLoad` (everything that tries for a sprite) stays
/// queued and blocks its parent's add/remove events. Awaiting `ready()` each
/// frame is what a real browser frame does for free.
Future<void> tick(RogueAgentsGame game, int frames, {double dt = 1 / 60}) async {
  for (var i = 0; i < frames; i++) {
    game.update(dt);
    await game.ready();
  }
}

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

      // The grace period, then one interval: exactly two spawn events are due.
      game.update(GameConfig.firstSpawnDelay + 0.01);
      game.update(waveTable.first.interval + 0.01);
      await game.ready();

      // Wave one is Scrapers only, which spawn one at a time.
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

  testWithGame<RogueAgentsGame>(
    'packets damage an agent and kill it at zero hp',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final spec = agentSpec('scraper');

      final agent = Agent(
        spec: spec,
        position: game.player.position + Vector2(80, 0),
      );
      await game.world.add(agent);
      await game.ready();

      // Damage is exact, and a survivable hit does not count as a kill.
      agent.takeDamage(spec.hp - 1);
      expect(agent.hp, closeTo(1, 0.001));
      expect(game.kills, 0);

      // The cannon finishes it off on its own.
      await tick(game, 120);

      expect(agent.isMounted, isFalse);
      expect(game.kills, greaterThanOrEqualTo(1));
    },
  );

  testWithGame<RogueAgentsGame>(
    'a packet is spent on the agent it hits',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      final agent = Agent(
        spec: agentSpec('scraper'),
        position: game.player.position + Vector2(80, 0),
      );
      await game.world.add(agent);
      await game.ready();

      game.weapons.single.fireAt(agent.position);
      await game.ready();
      final shot = game.world.children.whereType<Projectile>().last;

      // It reaches the agent, deals its damage, and is consumed — pierce is 0.
      await tick(game, 10);

      expect(shot.isMounted, isFalse);
      expect(agent.hp, lessThan(agentSpec('scraper').hp));
    },
  );

  testWithGame<RogueAgentsGame>(
    'standing in an agent drains integrity',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      expect(game.integrity, GameConfig.maxIntegrity);

      await game.world.add(
        Agent(spec: agentSpec('scraper'), position: game.player.position.clone()),
      );
      await game.ready();

      final hit = agentSpec('scraper').damage;

      // One frame of contact: a single discrete hit, not per-frame damage.
      await tick(game, 1);
      expect(game.integrity, closeTo(GameConfig.maxIntegrity - hit, 0.001));

      // Still touching, but inside the mercy window: no further damage.
      await tick(game, 10);
      expect(game.integrity, closeTo(GameConfig.maxIntegrity - hit, 0.001));

      // Once the window lapses, the next hit lands.
      await tick(game, (GameConfig.playerInvulnerability * 60).ceil() + 2);
      expect(game.integrity, closeTo(GameConfig.maxIntegrity - hit * 2, 0.001));
    },
  );

  testWithGame<RogueAgentsGame>(
    'integrity never goes below zero',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      game.damagePlayer(10_000);

      expect(game.integrity, 0);
      expect(game.integrityLost, GameConfig.maxIntegrity);
    },
  );

  testWithGame<RogueAgentsGame>(
    'a dead agent drops a token worth its xp',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      final agent = Agent(
        spec: agentSpec('scraper'),
        position: game.player.position + Vector2(300, 0),
      );
      await game.world.add(agent);
      await game.ready();

      agent.die();
      await game.ready();

      final tokens = game.world.children.whereType<Token>().toList();
      expect(tokens, hasLength(1));
      expect(tokens.single.value, agentSpec('scraper').xp);
      expect(tokens.single.position, agent.position);
    },
  );

  testWithGame<RogueAgentsGame>(
    'tokens outside the magnet radius stay put',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      final token = Token(
        position: game.player.position + Vector2(game.magnetRadius + 60, 0),
        value: 1,
      );
      await game.world.add(token);
      await game.ready();
      final start = token.position.clone();

      await tick(game, 30);

      expect(token.position.x, closeTo(start.x, 0.001));
      expect(game.xp, 0);
    },
  );

  testWithGame<RogueAgentsGame>(
    'a token inside the magnet radius is pulled in and banked',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      await game.world.add(
        Token(
          position: game.player.position + Vector2(game.magnetRadius - 10, 0),
          value: 3,
        ),
      );
      await game.ready();

      await tick(game, 60);

      expect(game.world.children.whereType<Token>(), isEmpty);
      expect(game.tokensCollected, 1);
      expect(game.xp, 3);
    },
  );

  testWithGame<RogueAgentsGame>(
    'banking enough xp raises the clearance tier',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      expect(game.level, 1);
      final cost = game.xpForNextLevel;

      game.collectToken(Token(position: Vector2.zero(), value: cost));
      expect(game.level, 2);
      expect(game.xp, 0);

      // A single huge pickup can carry more than one level.
      game.collectToken(
        Token(position: Vector2.zero(), value: game.xpForNextLevel * 3),
      );
      expect(game.level, greaterThanOrEqualTo(3));
      expect(game.levelProgress, lessThanOrEqualTo(1.0));
    },
  );

  testWithGame<RogueAgentsGame>(
    'levelling up opens a draft of three cards and freezes the arena',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      expect(game.isDrafting, isFalse);

      final agent = Agent(
        spec: agentSpec('scraper'),
        position: game.player.position + Vector2(260, 0),
      );
      await game.world.add(agent);
      await game.ready();

      game.levelUp();
      await game.ready();

      expect(game.isDrafting, isTrue);
      expect(game.offered, hasLength(3));
      expect(game.offered.toSet(), hasLength(3));
      expect(game.draftOverlay.isVisible, isTrue);

      // Nothing moves while the cards are up.
      final agentAt = agent.position.clone();
      final clock = game.elapsed;
      await tick(game, 30);
      expect(agent.position, agentAt);
      expect(game.elapsed, clock);
    },
  );

  testWithGame<RogueAgentsGame>(
    'picking a card applies it and resumes the run',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final before = game.weapons.single.cooldown;

      game.levelUp();
      await game.ready();

      // Force a known card onto the table so the assertion is not random.
      game.offered
        ..clear()
        ..add(upgradeSpec('throughput'));
      game.chooseUpgrade(upgradeSpec('throughput'));
      await game.ready();

      expect(game.isDrafting, isFalse);
      expect(game.draftOverlay.isVisible, isFalse);
      expect(game.upgradesTaken['throughput'], 1);
      expect(game.weapons.single.cooldown, lessThan(before));

      // The arena is running again.
      await tick(game, 10);
      expect(game.elapsed, greaterThan(0));
    },
  );

  testWithGame<RogueAgentsGame>(
    'two tiers at once draft twice',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      game.levelUp();
      game.levelUp();
      await game.ready();
      expect(game.pendingLevelUps, 2);

      game.chooseUpgrade(game.offered.first);
      await game.ready();

      // Still drafting: the second tier re-opened immediately.
      expect(game.isDrafting, isTrue);
      expect(game.pendingLevelUps, 1);

      game.chooseUpgrade(game.offered.first);
      await game.ready();

      expect(game.isDrafting, isFalse);
      expect(game.pendingLevelUps, 0);
    },
  );

  testWithGame<RogueAgentsGame>(
    'an upgrade stops being offered once it is maxed',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final spec = upgradeSpec('zero_copy');

      game.upgradesTaken[spec.id] = spec.maxStacks;

      expect(game.isUpgradeAvailable(spec), isFalse);
      game.openDraft();
      expect(game.offered, isNot(contains(spec)));
    },
  );

  testWithGame<RogueAgentsGame>(
    'a weapon equipped after an upgrade inherits it',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      upgradeSpec('payload').apply(game);
      final second = await game.equip(weaponSpec('packet_cannon'));

      expect(second.damageMultiplier, closeTo(1.25, 0.001));
      expect(second.damage, closeTo(game.weapons.first.damage, 0.001));
    },
  );

  testWithGame<RogueAgentsGame>(
    'Hot Patch repairs but never exceeds full integrity',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      game.damagePlayer(80);
      upgradeSpec('hot_patch').apply(game);
      expect(game.integrity, closeTo(55, 0.001));

      upgradeSpec('hot_patch').apply(game);
      expect(game.integrity, closeTo(90, 0.001));

      // The next one would overshoot, so it caps.
      upgradeSpec('hot_patch').apply(game);
      expect(game.integrity, GameConfig.maxIntegrity);
    },
  );

  testWithGame<RogueAgentsGame>(
    'every upgrade in the catalog applies without blowing up',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      for (final spec in upgradeCatalog) {
        spec.apply(game);
      }

      // Sanity: nothing produced a nonsense stat.
      expect(game.weapons.single.cooldown, greaterThan(0));
      expect(game.weapons.single.damage, greaterThan(0));
      expect(game.critChance, inInclusiveRange(0, 1));
      expect(game.integrity, lessThanOrEqualTo(game.maxIntegrity));
      expect(game.playerSpeedMultiplier, greaterThan(1));
    },
  );

  testWithGame<RogueAgentsGame>(
    'capacity raises the ceiling and repairs to match',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      game.damagePlayer(50);
      upgradeSpec('capacity').apply(game);

      expect(game.maxIntegrity, GameConfig.maxIntegrity + 30);
      expect(game.integrity, closeTo(80, 0.001));
    },
  );

  testWithGame<RogueAgentsGame>(
    'hardening reduces incoming damage',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      upgradeSpec('hardening').apply(game);
      game.damagePlayer(100);

      expect(game.integrity, closeTo(GameConfig.maxIntegrity - 82, 0.001));
    },
  );

  testWithGame<RogueAgentsGame>(
    'self-healing regenerates over time but not past the cap',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      game.damagePlayer(40);
      upgradeSpec('self_healing').apply(game);
      await tick(game, 60);

      expect(game.integrity, closeTo(61.2, 0.1));

      // Near the ceiling, a second of regen cannot overshoot it. (Ticking for
      // a full minute instead would just let the swarm kill the player.)
      game.integrity = game.maxIntegrity - 0.5;
      await tick(game, 60);
      expect(game.integrity, game.maxIntegrity);
    },
  );

  testWithGame<RogueAgentsGame>(
    'token arbitrage scales banked xp',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      upgradeSpec('token_arbitrage').apply(game);
      game.collectToken(Token(position: Vector2.zero(), value: 2));

      expect(game.xp, 3);
    },
  );

  testWithGame<RogueAgentsGame>(
    'crit upgrades change what a packet carries',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      expect(game.rollCrit(), isFalse);

      // Guaranteed crits, so the assertion is deterministic.
      game.critChance = 1;
      upgradeSpec('root_access').apply(game);

      game.weapons.single.fireAt(game.player.position + Vector2(100, 0));
      await game.ready();

      final shot = game.world.children.whereType<Projectile>().last;
      expect(shot.isCrit, isTrue);
      expect(shot.damage, closeTo(game.weapons.single.damage * 3.5, 0.001));
    },
  );

  testWithGame<RogueAgentsGame>(
    'Root Access is only offered once a crit chance exists',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final root = upgradeSpec('root_access');

      expect(game.isUpgradeAvailable(root), isFalse);

      upgradeSpec('speculative_exec').apply(game);
      expect(game.isUpgradeAvailable(root), isTrue);
    },
  );

  testWithGame<RogueAgentsGame>(
    'tail latency speeds up and extends packets',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final weapon = game.weapons.single;
      final baseRange = weapon.range;
      final baseSpeed = weapon.projectileSpeed;

      upgradeSpec('tail_latency').apply(game);

      expect(weapon.range, closeTo(baseRange * 1.2, 0.001));
      expect(weapon.projectileSpeed, closeTo(baseSpeed * 1.3, 0.001));

      weapon.fireAt(game.player.position + Vector2(0, -100));
      await game.ready();
      final shot = game.world.children.whereType<Projectile>().last;
      expect(shot.speed, closeTo(baseSpeed * 1.3, 0.001));
    },
  );

  test('the wave table escalates and every id it names exists', () {
    expect(waveAt(0).weights.keys, ['scraper']);
    expect(waveAt(1000), waveTable.last);

    for (var i = 1; i < waveTable.length; i++) {
      final previous = waveTable[i - 1];
      final wave = waveTable[i];
      expect(wave.from, greaterThan(previous.from));
      expect(wave.interval, lessThan(previous.interval));
      for (final id in wave.weights.keys) {
        expect(() => agentSpec(id), returnsNormally);
      }
    }
  });

  testWithGame<RogueAgentsGame>(
    'a swarm wave spawns a whole group at once',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final swarm = agentSpec('swarmlet');
      expect(swarm.groupSize, greaterThan(1));

      final spawned = game.spawner.spawnFromWave(
        const WaveSpec(
          from: 0,
          interval: 1,
          weights: {'swarmlet': 1},
          label: 'TEST',
        ),
      );
      await game.ready();

      expect(spawned, hasLength(swarm.groupSize));
      // Scattered, not stacked on one point.
      expect(
        spawned.map((a) => a.position.x).toSet(),
        hasLength(swarm.groupSize),
      );
    },
  );

  testWithGame<RogueAgentsGame>(
    'a ranged agent holds its distance and fires',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final spec = agentSpec('injector');

      // Starts well outside its preferred range.
      final agent = Agent(
        spec: spec,
        position: game.player.position + Vector2(spec.preferredRange + 240, 0),
      );
      await game.world.add(agent);
      await game.ready();

      await tick(game, 60 * 5);

      // Closed to roughly its stand-off distance, not onto the player.
      final distance = agent.position.distanceTo(game.player.position);
      expect(distance, greaterThan(spec.preferredRange * 0.7));
      expect(distance, lessThan(spec.preferredRange * 1.25));

      // And it has been shooting.
      expect(game.world.children.whereType<Injection>(), isNotEmpty);
    },
  );

  testWithGame<RogueAgentsGame>(
    'an injection that lands damages the player and is consumed',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      final spec = agentSpec('injector');

      await game.world.add(
        Injection(
          spec: spec,
          position: game.player.position + Vector2(40, 0),
          direction: Vector2(-1, 0),
        ),
      );
      await game.ready();

      await tick(game, 30);

      expect(game.world.children.whereType<Injection>(), isEmpty);
      expect(
        game.integrity,
        closeTo(GameConfig.maxIntegrity - spec.projectileDamage, 0.001),
      );
    },
  );

  testWithGame<RogueAgentsGame>(
    'crossing a wave boundary raises a banner',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();
      expect(game.waveBanner, isNull);

      // Jump the clock past the second wave's start.
      game.elapsed = waveTable[1].from + 0.1;
      await tick(game, 2);

      expect(game.waveBanner, waveTable[1].label);
      expect(game.waveBannerTimer, greaterThan(0));
    },
  );
}
