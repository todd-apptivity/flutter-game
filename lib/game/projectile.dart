import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/weapons.dart';
import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';
import 'package:flutter_game/util/sprite_loader.dart';

/// An outgoing packet. Travels in a straight line until it runs out of range
/// or leaves the arena; stage 5 gives it something to hit.
class Projectile extends PositionComponent
    with HasGameReference<RogueAgentsGame> {
  Projectile({
    required this.spec,
    required Vector2 position,
    required this.direction,
  }) : super(
          position: position,
          size: Vector2.all(spec.projectileSize),
          anchor: Anchor.center,
          priority: 8,
        );

  final WeaponSpec spec;

  /// Unit vector of travel.
  final Vector2 direction;

  /// Damage this packet still carries, so upgrades can scale a single shot.
  late double damage = spec.damage;

  /// How many more agents it may pass through.
  late int pierce = spec.pierce;

  /// Distance travelled, against [WeaponSpec.range].
  double _travelled = 0;

  /// Agents already hit, so a piercing packet cannot hit the same one twice.
  final _hits = <Agent>{};

  /// Collision radius; a little generous so fast packets feel fair.
  double get hitRadius => size.x * 0.45;

  bool hasHit(Agent agent) => _hits.contains(agent);

  void registerHit(Agent agent) => _hits.add(agent);

  Sprite? _sprite;
  final _spritePaint = pixelPaint();
  late final _corePaint = Paint()..color = spec.color;
  late final _glowPaint = Paint()
    ..color = spec.color.withValues(alpha: 0.3);

  @override
  Future<void> onLoad() async {
    final path = spec.spritePath;
    if (path != null) _sprite = await tryLoadSprite(path);
  }

  @override
  void update(double dt) {
    final step = spec.projectileSpeed * dt;
    position += direction * step;
    _travelled += step;

    final out = GameConfig.spawnOffscreen * 4;
    if (_travelled >= spec.range ||
        !game.arena.bounds.inflate(out).contains(position.toOffset())) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = _sprite;
    if (sprite != null) {
      sprite.render(canvas, size: size, overridePaint: _spritePaint);
      return;
    }
    final c = (size / 2).toOffset();
    canvas
      ..drawCircle(c, size.x * 0.55, _glowPaint)
      ..drawCircle(c, size.x * 0.28, _corePaint);
  }
}
