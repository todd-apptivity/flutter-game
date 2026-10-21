import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';

/// Camera shake, driven by whatever just happened.
///
/// Rides on the camera viewfinder rather than moving the world, so the HUD and
/// the overlays stay rock steady while the arena jolts.
class ScreenShake extends Component with HasGameReference<RogueAgentsGame> {
  final _random = math.Random();

  double _amplitude = 0;
  double _remaining = 0;
  double _duration = 0;

  late final Vector2 _home = GameConfig.designSize / 2;

  /// Shakes for [duration] seconds, starting at [amplitude] pixels. A bigger
  /// shake always wins; a smaller one never cuts an existing one short.
  void shake({required double amplitude, double duration = 0.22}) {
    if (amplitude <= _amplitude && _remaining > 0) return;
    _amplitude = amplitude;
    _duration = duration;
    _remaining = duration;
  }

  @override
  void update(double dt) {
    if (_remaining <= 0) {
      if (game.camera.viewfinder.position != _home) {
        game.camera.viewfinder.position = _home;
      }
      return;
    }

    _remaining -= dt;
    final strength = _amplitude * (_remaining / _duration).clamp(0.0, 1.0);
    game.camera.viewfinder.position = _home +
        Vector2(
          (_random.nextDouble() * 2 - 1) * strength,
          (_random.nextDouble() * 2 - 1) * strength,
        );
  }
}

/// A short-lived spray of pixels, thrown when something dies or takes a hit.
class HitBurst extends PositionComponent {
  HitBurst({
    required Vector2 position,
    required this.color,
    this.count = 8,
    this.speed = 160,
    this.life = 0.38,
    this.pixel = 3,
  }) : super(position: position, priority: 20) {
    final random = math.Random();
    for (var i = 0; i < count; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final velocity = Vector2(math.cos(angle), math.sin(angle)) *
          speed *
          (0.35 + random.nextDouble());
      _parts.add(_Part(velocity));
    }
  }

  final Color color;
  final int count;
  final double speed;
  final double life;
  final double pixel;

  final _parts = <_Part>[];
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= life) {
      removeFromParent();
      return;
    }
    for (final part in _parts) {
      part.offset += part.velocity * dt;
      // Drag, so the spray decelerates instead of flying off evenly.
      part.velocity *= 1 - 3.2 * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final fade = 1 - (_age / life);
    final paint = Paint()..color = color.withValues(alpha: fade);
    for (final part in _parts) {
      canvas.drawRect(
        Rect.fromCenter(
          center: part.offset.toOffset(),
          width: pixel,
          height: pixel,
        ),
        paint,
      );
    }
  }
}

class _Part {
  _Part(this.velocity);
  Vector2 offset = Vector2.zero();
  Vector2 velocity;
}

/// Text that drifts upward and fades: damage numbers, tier-ups, call-outs.
class FloatingText extends PositionComponent {
  FloatingText({
    required this.text,
    required Vector2 position,
    required this.color,
    this.fontSize = 20,
    this.life = 0.7,
    this.rise = 46,
    this.weight = FontWeight.w800,
  }) : super(position: position, priority: 30);

  final String text;
  final Color color;
  final double fontSize;
  final double life;
  final double rise;
  final FontWeight weight;

  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / life).clamp(0.0, 1.0);
    // Ease out: most of the travel happens immediately, then it hangs.
    final lift = rise * (1 - math.pow(1 - progress, 2.2)).toDouble();
    final fade = progress < 0.65 ? 1.0 : 1 - (progress - 0.65) / 0.35;

    TextPaint(
      style: TextStyle(
        color: color.withValues(alpha: fade.clamp(0.0, 1.0)),
        fontSize: fontSize,
        fontWeight: weight,
        letterSpacing: 0.5,
      ),
    ).render(canvas, text, Vector2(0, -lift), anchor: Anchor.center);
  }
}
