import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_game/config/agents.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';

/// An adversarial payload lobbed at the control plane by a ranged agent.
///
/// Deliberately slow and clearly red: it is meant to be dodged, which is what
/// makes a Prompt Injector different from something that just walks at you.
class Injection extends PositionComponent
    with HasGameReference<RogueAgentsGame> {
  Injection({
    required this.spec,
    required Vector2 position,
    required this.direction,
  }) : super(
          position: position,
          size: Vector2.all(GameConfig.injectionSize),
          anchor: Anchor.center,
          priority: 7,
        );

  final AgentSpec spec;
  final Vector2 direction;

  double get damage => spec.projectileDamage;
  double get hitRadius => size.x * 0.4;

  double _t = 0;

  late final _corePaint = Paint()..color = spec.eyeColor;
  late final _glowPaint = Paint()
    ..color = spec.eyeColor.withValues(alpha: 0.3);

  @override
  void update(double dt) {
    _t += dt;
    position += direction * spec.projectileSpeed * dt;

    final out = GameConfig.spawnOffscreen * 4;
    if (!game.arena.bounds.inflate(out).contains(position.toOffset())) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final c = (size / 2).toOffset();
    final pulse = 0.85 + 0.15 * math.sin(_t * 14);
    canvas
      ..drawCircle(c, size.x * 0.5 * pulse, _glowPaint)
      ..drawCircle(c, size.x * 0.26, _corePaint);

    // A tiny cross makes it read as a payload rather than a bullet.
    final arm = size.x * 0.18;
    final stroke = Paint()
      ..color = spec.eyeColor
      ..strokeWidth = 2;
    canvas
      ..drawLine(c.translate(-arm, 0), c.translate(arm, 0), stroke)
      ..drawLine(c.translate(0, -arm), c.translate(0, arm), stroke);
  }
}
