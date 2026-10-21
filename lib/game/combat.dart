import 'package:flame/components.dart';
import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/injection.dart';
import 'package:flutter_game/game/projectile.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';

/// Resolves every overlap in the arena once per frame.
///
/// Hit tests are plain circle-distance checks rather than Flame's collision
/// system: everything in this game is round-ish, the order of resolution stays
/// obvious, and there is no hitbox bookkeeping to get wrong when a viewer adds
/// an agent type mid-stream.
class Combat extends Component with HasGameReference<RogueAgentsGame> {
  @override
  void update(double dt) {
    _resolveInjections();

    final agents = game.world.children.whereType<Agent>().toList();
    if (agents.isEmpty) return;

    _resolveProjectiles(agents);
    _resolveContact(agents, dt);
  }

  /// Incoming payloads from ranged agents. They pay the same mercy window as
  /// contact damage, so being shot while mobbed is not instant death.
  void _resolveInjections() {
    final player = game.player;
    for (final shot in game.world.children.whereType<Injection>().toList()) {
      if (shot.isRemoving) continue;
      if (!_overlap(
        shot.position,
        shot.hitRadius,
        player.position,
        player.hitRadius,
      )) {
        continue;
      }

      shot.removeFromParent();
      if (!player.canBeHit) continue;
      game.damagePlayer(shot.damage);
      player.startMercyWindow();
    }
  }

  void _resolveProjectiles(List<Agent> agents) {
    for (final shot in game.world.children.whereType<Projectile>().toList()) {
      if (shot.isRemoving) continue;

      for (final agent in agents) {
        if (agent.isRemoving || shot.hasHit(agent)) continue;
        if (!_overlap(shot.position, shot.hitRadius, agent.position,
            agent.hitRadius)) {
          continue;
        }

        agent.takeDamage(shot.damage, crit: shot.isCrit);
        shot.registerHit(agent);
        // Pierce lets a packet carry on through the next agent behind it.
        if (shot.pierce <= 0) {
          shot.removeFromParent();
          break;
        }
        shot.pierce--;
      }
    }
  }

  /// The player takes one discrete hit, then is briefly immune. The hit comes
  /// from the hardest-hitting agent touching them, so wading into a crowd is
  /// punishing but survivable.
  void _resolveContact(List<Agent> agents, double dt) {
    final player = game.player;
    if (!player.canBeHit) return;

    Agent? worst;
    for (final agent in agents) {
      if (agent.isRemoving) continue;
      if (!_overlap(
        agent.position,
        agent.hitRadius,
        player.position,
        player.hitRadius,
      )) {
        continue;
      }
      if (worst == null || agent.spec.damage > worst.spec.damage) {
        worst = agent;
      }
    }

    if (worst == null) return;
    game.damagePlayer(worst.spec.damage);
    player.startMercyWindow();
  }

  bool _overlap(Vector2 a, double ra, Vector2 b, double rb) =>
      a.distanceToSquared(b) <= (ra + rb) * (ra + rb);
}
