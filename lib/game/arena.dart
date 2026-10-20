import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';
import 'package:flutter_game/util/sprite_loader.dart';

/// The playfield floor: a circuit-board grid with a boundary. Drawn behind
/// everything else, and the thing that defines where the player may move.
class Arena extends PositionComponent {
  Arena()
      : super(
          position: Vector2.all(GameConfig.arenaMargin),
          size: GameConfig.designSize - Vector2.all(GameConfig.arenaMargin * 2),
          priority: -100,
        );

  /// Grid cell in world units.
  static const cell = 64.0;

  /// Every Nth line is drawn brighter.
  static const majorEvery = 4;

  Sprite? _tile;

  final _gridPaint = Paint()
    ..color = Palette.grid
    ..strokeWidth = 1;
  final _majorPaint = Paint()
    ..color = Palette.gridMajor
    ..strokeWidth = 2;
  final _borderPaint = Paint()
    ..color = Palette.border
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;
  final _tilePaint = pixelPaint();

  /// Rectangle the player is confined to, in world coordinates.
  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  Future<void> onLoad() async {
    _tile = await tryLoadSprite('floor_tile.png');
  }

  @override
  void render(Canvas canvas) {
    final tile = _tile;
    if (tile != null) {
      // Tile the provided art across the floor at pixel scale. Clipped, or the
      // last row and column spill past the arena border.
      canvas
        ..save()
        ..clipRect(size.toRect());
      final step = tile.srcSize * GameConfig.pixelScale;
      for (var y = 0.0; y < size.y; y += step.y) {
        for (var x = 0.0; x < size.x; x += step.x) {
          tile.render(
            canvas,
            position: Vector2(x, y),
            size: step,
            overridePaint: _tilePaint,
          );
        }
      }
      canvas.restore();
    } else {
      _renderGrid(canvas);
    }
    canvas.drawRect(size.toRect().deflate(1.5), _borderPaint);
  }

  void _renderGrid(Canvas canvas) {
    var i = 0;
    for (var x = 0.0; x <= size.x; x += cell, i++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.y),
        i % majorEvery == 0 ? _majorPaint : _gridPaint,
      );
    }
    i = 0;
    for (var y = 0.0; y <= size.y; y += cell, i++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.x, y),
        i % majorEvery == 0 ? _majorPaint : _gridPaint,
      );
    }
  }
}
