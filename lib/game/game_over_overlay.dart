import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';

/// End-of-run screen: what the control plane managed before it fell, and a
/// way back in.
class GameOverOverlay extends PositionComponent
    with HasGameReference<RogueAgentsGame>, TapCallbacks {
  GameOverOverlay()
      : super(size: GameConfig.designSize, priority: 2000);

  bool _visible = false;
  bool get isVisible => _visible;

  /// Short delay before input is accepted, so the click that killed you does
  /// not instantly restart the run.
  double _armingDelay = 0;
  bool get isArmed => _armingDelay <= 0;

  final _scrim = Paint()..color = const Color(0xF2020909);

  final _title = TextPaint(
    style: const TextStyle(
      color: Palette.agentEye,
      fontSize: 62,
      fontWeight: FontWeight.w900,
      letterSpacing: 6,
    ),
  );
  final _subtitle = TextPaint(
    style: const TextStyle(
      color: Palette.hudDim,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: 4,
    ),
  );
  final _statLabel = TextPaint(
    style: const TextStyle(
      color: Palette.hudDim,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.5,
    ),
  );
  final _statValue = TextPaint(
    style: const TextStyle(
      color: Palette.hudText,
      fontSize: 38,
      fontWeight: FontWeight.w800,
    ),
  );
  final _prompt = TextPaint(
    style: const TextStyle(
      color: Palette.player,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: 3,
    ),
  );

  void show() {
    _visible = true;
    _armingDelay = GameConfig.gameOverArmingDelay;
  }

  void hide() => _visible = false;

  @override
  void update(double dt) {
    // The tree is frozen on game over, so this runs off the game's own clock.
    if (_visible && _armingDelay > 0) _armingDelay -= dt;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_visible && isArmed) game.restart();
  }

  @override
  void render(Canvas canvas) {
    if (!_visible) return;

    canvas.drawRect(GameConfig.designSize.toRect(), _scrim);
    final cx = GameConfig.designWidth / 2;

    _subtitle.render(
      canvas,
      'INTEGRITY EXHAUSTED',
      Vector2(cx, 128),
      anchor: Anchor.topCenter,
    );
    _title.render(
      canvas,
      'CONTROL PLANE COMPROMISED',
      Vector2(cx, 156),
      anchor: Anchor.topCenter,
    );

    _renderStats(canvas, cx);

    if (isArmed) {
      _prompt.render(
        canvas,
        'PRESS R OR CLICK TO REDEPLOY',
        Vector2(cx, 592),
        anchor: Anchor.topCenter,
      );
    }
  }

  void _renderStats(Canvas canvas, double cx) {
    final stats = <(String, String)>[
      ('UPTIME', _formatTime(game.elapsed)),
      ('AGENTS TERMINATED', '${game.kills}'),
      ('CLEARANCE TIER', '${game.level}'),
      ('TOKENS ABSORBED', '${game.tokensCollected}'),
    ];

    const spacing = 280.0;
    final startX = cx - spacing * (stats.length - 1) / 2;

    for (var i = 0; i < stats.length; i++) {
      final (label, value) = stats[i];
      final x = startX + spacing * i;
      _statLabel.render(canvas, label, Vector2(x, 300), anchor: Anchor.topCenter);
      _statValue.render(canvas, value, Vector2(x, 322), anchor: Anchor.topCenter);
    }

    _subtitle.render(
      canvas,
      'FINAL WAVE  //  ${game.spawner.wave.label}',
      Vector2(cx, 440),
      anchor: Anchor.topCenter,
    );
  }

  static String _formatTime(double seconds) {
    final total = seconds.floor();
    final m = (total ~/ 60).toString();
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
