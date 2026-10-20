import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';

/// Run readout: integrity, uptime, and agents terminated.
///
/// Lives in the camera viewport rather than the world, so it is pinned to the
/// screen and scales with the 1280x720 letterbox — text stays the same size on
/// a viewer's phone as on the stream.
class Hud extends PositionComponent with HasGameReference<RogueAgentsGame> {
  Hud() : super(position: Vector2.zero(), size: GameConfig.designSize);

  static const _barWidth = 300.0;
  static const _barHeight = 20.0;
  static const _pad = 34.0;

  final _label = TextPaint(
    style: const TextStyle(
      color: Palette.hudDim,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.4,
    ),
  );
  final _value = TextPaint(
    style: const TextStyle(
      color: Palette.hudText,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
  final _clock = TextPaint(
    style: const TextStyle(
      color: Palette.hudText,
      fontSize: 38,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
    ),
  );

  final _barBack = Paint()..color = const Color(0xFF0E2A2A);
  final _barEdge = Paint()
    ..color = Palette.border
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    _renderIntegrity(canvas);
    _renderClock(canvas);
    _renderKills(canvas);
    _renderExperience(canvas);
  }

  /// Full-width capacity bar along the bottom, with the current tier.
  void _renderExperience(Canvas canvas) {
    const height = 14.0;
    final top = GameConfig.designHeight - _pad - height;
    final width = GameConfig.designWidth - _pad * 2;
    final back = Rect.fromLTWH(_pad, top, width, height);

    canvas
      ..drawRect(back, _barBack)
      ..drawRect(
        Rect.fromLTWH(_pad, top, width * game.levelProgress, height),
        Paint()..color = Palette.playerCore,
      )
      ..drawRect(back, _barEdge);

    _label.render(
      canvas,
      'COMPUTE TOKENS  ${game.xp}/${game.xpForNextLevel}',
      Vector2(_pad, top - 22),
    );
    _label.render(
      canvas,
      'CLEARANCE TIER ${game.level}',
      Vector2(GameConfig.designWidth - _pad, top - 22),
      anchor: Anchor.topRight,
    );
  }

  void _renderIntegrity(Canvas canvas) {
    _label.render(canvas, 'CONTROL PLANE INTEGRITY', Vector2(_pad, _pad - 14));

    final top = _pad + 12;
    final back = Rect.fromLTWH(_pad, top, _barWidth, _barHeight);
    final fraction = (game.integrity / GameConfig.maxIntegrity).clamp(0.0, 1.0);

    canvas
      ..drawRect(back, _barBack)
      ..drawRect(
        Rect.fromLTWH(_pad, top, _barWidth * fraction, _barHeight),
        Paint()..color = _integrityColor(fraction),
      )
      ..drawRect(back, _barEdge);

    _value.render(
      canvas,
      '${game.integrity.ceil()}%',
      Vector2(_pad + _barWidth + 16, top - 8),
    );
  }

  /// Teal when healthy, amber under half, red when it is nearly over.
  Color _integrityColor(double fraction) {
    if (fraction > 0.5) return Palette.player;
    if (fraction > 0.25) return const Color(0xFFE0A526);
    return Palette.agentEye;
  }

  void _renderClock(Canvas canvas) {
    final text = _formatTime(game.elapsed);
    _label.render(
      canvas,
      'UPTIME',
      Vector2(GameConfig.designWidth / 2, _pad - 14),
      anchor: Anchor.topCenter,
    );
    _clock.render(
      canvas,
      text,
      Vector2(GameConfig.designWidth / 2, _pad + 4),
      anchor: Anchor.topCenter,
    );
  }

  void _renderKills(Canvas canvas) {
    final right = GameConfig.designWidth - _pad;
    _label.render(
      canvas,
      'AGENTS TERMINATED',
      Vector2(right, _pad - 14),
      anchor: Anchor.topRight,
    );
    _value.render(
      canvas,
      '${game.kills}',
      Vector2(right, _pad + 4),
      anchor: Anchor.topRight,
    );
  }

  static String _formatTime(double seconds) {
    final total = seconds.floor();
    final m = (total ~/ 60).toString();
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
