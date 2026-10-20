import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';
import 'package:flutter_game/util/sprite_loader.dart';

/// The player: the control plane holding the arena together.
class Player extends PositionComponent {
  Player()
      : super(
          size: Vector2.all(GameConfig.playerSize),
          anchor: Anchor.center,
          priority: 10,
        );

  SpriteAnimation? _animation;
  SpriteAnimationTicker? _ticker;
  final _spritePaint = pixelPaint();

  /// Drives the placeholder pulse when no art is present.
  double _t = 0;

  final _hullPaint = Paint()..color = Palette.player;
  final _corePaint = Paint()..color = Palette.playerCore;
  final _ringPaint = Paint()
    ..color = Palette.player
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  @override
  Future<void> onLoad() async {
    _animation = await tryLoadStrip(
      'player_core.png',
      frames: 4,
      frameSize: Vector2.all(32),
      stepTime: 0.12,
    );
    _ticker = _animation?.createTicker();
  }

  @override
  void update(double dt) {
    _t += dt;
    _ticker?.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final frame = _ticker?.getSprite();
    if (frame != null) {
      frame.render(canvas, size: size, overridePaint: _spritePaint);
      return;
    }
    _renderPlaceholder(canvas);
  }

  /// Hex core with a breathing ring — stands in until player_core.png exists.
  void _renderPlaceholder(Canvas canvas) {
    final c = (size / 2).toOffset();
    final r = size.x / 2;
    canvas.drawPath(_hexPath(c, r * 0.72), _hullPaint);
    canvas.drawCircle(c, r * 0.26, _corePaint);
    final pulse = 0.82 + 0.1 * math.sin(_t * 3.4);
    canvas.drawCircle(c, r * pulse, _ringPaint);
  }

  Path _hexPath(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 3 * i - math.pi / 2;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }
}
