import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';
import 'package:flutter_game/util/sprite_loader.dart';

/// A compute token dropped by a destroyed agent. Sits still until the control
/// plane gets close, then is pulled in and absorbed.
class Token extends PositionComponent with HasGameReference<RogueAgentsGame> {
  Token({required Vector2 position, required this.value})
      : super(
          position: position,
          size: Vector2.all(
            GameConfig.tokenFrameSize * GameConfig.pixelScale,
          ),
          anchor: Anchor.center,
          priority: 3,
        );

  /// XP granted when absorbed.
  final int value;

  SpriteAnimationTicker? _ticker;
  final _spritePaint = pixelPaint();

  /// Seconds alive, for the idle bob.
  double _t = 0;

  /// True once the magnet has grabbed it: from then on it never lets go.
  bool _attracted = false;

  final _corePaint = Paint()..color = Palette.player;
  final _glowPaint = Paint()
    ..color = Palette.player.withValues(alpha: 0.28);

  @override
  Future<void> onLoad() async {
    final animation = await tryLoadStrip(
      'pickup_token.png',
      frames: 4,
      frameSize: Vector2.all(GameConfig.tokenFrameSize),
      stepTime: 0.14,
    );
    _ticker = animation?.createTicker();
  }

  @override
  void update(double dt) {
    _t += dt;
    _ticker?.update(dt);

    final toPlayer = game.player.position - position;
    final distance = toPlayer.length;

    if (!_attracted && distance <= game.magnetRadius) _attracted = true;

    if (_attracted && distance > 0) {
      // Accelerates as it closes, so a pickup snaps in rather than drifting.
      final pull = GameConfig.tokenPullSpeed *
          (1 + (game.magnetRadius - distance) / game.magnetRadius);
      position += toPlayer.normalized() * pull * dt;
    }

    if (distance <= game.player.hitRadius + size.x * 0.4) {
      removeFromParent();
      game.collectToken(this);
    }
  }

  @override
  void render(Canvas canvas) {
    // A slow bob keeps dropped tokens readable against the grid.
    final bob = math.sin(_t * 4) * size.y * 0.08;
    canvas.translate(0, bob);

    final frame = _ticker?.getSprite();
    if (frame != null) {
      frame.render(canvas, size: size, overridePaint: _spritePaint);
      return;
    }
    final c = (size / 2).toOffset();
    canvas
      ..drawCircle(c, size.x * 0.5, _glowPaint)
      ..drawCircle(c, size.x * 0.26, _corePaint);
  }
}
