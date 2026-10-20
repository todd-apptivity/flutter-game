import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_game/config/weapons.dart';
import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';
import 'package:flutter_game/game/weapon.dart';
import 'package:flutter_game/util/sprite_loader.dart';

/// One throttle node riding the Rate Limiter's orbit.
///
/// Unlike packets, a node is never consumed: it sweeps continuously and
/// re-hits the same agent on a per-agent cooldown, so standing in the ring is
/// a steady grind rather than one big hit.
class OrbitNode extends PositionComponent
    with HasGameReference<RogueAgentsGame> {
  OrbitNode({required this.weapon, required this.phase})
      : super(
          size: Vector2.all(weapon.spec.orbitNodeSize),
          anchor: Anchor.center,
          priority: 9,
        );

  final Weapon weapon;

  /// Starting angle, so nodes are spread evenly around the ring.
  final double phase;

  WeaponSpec get spec => weapon.spec;

  double _angle = 0;

  /// Per-agent re-hit timers, keyed by the agent itself.
  final _cooldowns = <Agent, double>{};

  Sprite? _sprite;
  final _spritePaint = pixelPaint();
  late final _corePaint = Paint()..color = spec.color;
  late final _glowPaint = Paint()..color = spec.color.withValues(alpha: 0.25);

  double get hitRadius => size.x * 0.5;

  @override
  Future<void> onLoad() async {
    _angle = phase;
    final path = spec.spritePath;
    if (path != null) _sprite = await tryLoadSprite(path);
    _reposition();
  }

  @override
  void update(double dt) {
    _angle += spec.orbitSpeed * dt;
    _reposition();

    _cooldowns.removeWhere((agent, _) => !agent.isMounted);
    _cooldowns.updateAll((_, remaining) => remaining - dt);

    for (final agent in game.world.children.whereType<Agent>()) {
      if (agent.isRemoving) continue;
      if ((_cooldowns[agent] ?? 0) > 0) continue;

      final reach = hitRadius + agent.hitRadius;
      if (agent.position.distanceToSquared(position) > reach * reach) continue;

      final crit = game.rollCrit();
      agent.takeDamage(crit ? weapon.damage * game.critMultiplier : weapon.damage);
      _cooldowns[agent] = spec.hitCooldown;
    }
  }

  void _reposition() {
    final radius = spec.orbitRadius * game.weaponRangeMultiplier;
    position = game.player.position +
        Vector2(math.cos(_angle), math.sin(_angle)) * radius;
  }

  @override
  void render(Canvas canvas) {
    final sprite = _sprite;
    if (sprite != null) {
      sprite.render(canvas, size: size, overridePaint: _spritePaint);
      return;
    }

    // Placeholder: a bright node with a trailing arc in the sweep direction.
    final c = (size / 2).toOffset();
    canvas
      ..drawCircle(c, size.x * 0.5, _glowPaint)
      ..drawCircle(c, size.x * 0.3, _corePaint);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: size.x * 0.44),
      -math.pi * 0.9,
      math.pi * 0.8,
      false,
      Paint()
        ..color = spec.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}
