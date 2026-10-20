import 'package:flame/components.dart';
import 'package:flutter_game/config/weapons.dart';
import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/projectile.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';

/// An automatic defense bolted to the control plane. One of these per weapon
/// the player owns; upgrades mutate the multipliers rather than the spec, so
/// the catalog stays const.
class Weapon extends Component with HasGameReference<RogueAgentsGame> {
  Weapon(this.spec);

  final WeaponSpec spec;

  /// Upgrade hooks (stage 7+). 1.0 means "as specified".
  double cooldownMultiplier = 1;
  double damageMultiplier = 1;
  int extraProjectiles = 0;
  int extraPierce = 0;

  double _cooldown = 0;

  double get cooldown => spec.cooldown * cooldownMultiplier;
  double get damage => spec.damage * damageMultiplier;
  int get projectileCount => spec.projectileCount + extraProjectiles;

  @override
  void update(double dt) {
    _cooldown -= dt;
    if (_cooldown > 0) return;

    final target = nearestAgent();
    if (target == null) return;

    _cooldown = cooldown;
    fireAt(target.position);
  }

  /// Closest agent within range, or null when nothing is worth shooting.
  Agent? nearestAgent() {
    Agent? best;
    var bestDistance = spec.range;
    final origin = game.player.position;

    for (final agent in game.world.children.whereType<Agent>()) {
      // Only shoot at what the player can see: agents are still walking in
      // from off-arena, and sniping them out there reads as a bug.
      if (!game.arena.bounds.contains(agent.position.toOffset())) continue;

      final distance = agent.position.distanceTo(origin);
      if (distance < bestDistance) {
        best = agent;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Fires one volley toward [point]. Extra projectiles fan out around it.
  void fireAt(Vector2 point) {
    final origin = game.player.position;
    final aim = point - origin;
    if (aim.length2 == 0) return;

    final count = projectileCount;
    // Centre the fan on the aim line: one shot is dead on, two straddle it.
    final start = -spec.spread * (count - 1) / 2;

    for (var i = 0; i < count; i++) {
      final direction = aim.normalized()..rotate(start + spec.spread * i);
      game.world.add(
        Projectile(
          spec: spec,
          position: origin.clone(),
          direction: direction,
        )
          ..damage = damage
          ..pierce = spec.pierce + extraPierce,
      );
    }
  }
}
