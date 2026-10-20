import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';
import 'package:flutter_game/config/upgrades.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';

/// The level-up draft: three cards, pick one, resume.
///
/// Built from Flame components in the camera viewport rather than a Flutter
/// overlay, so it letterboxes with the rest of the 1280x720 design and the
/// card text is the same size on every screen.
class DraftOverlay extends PositionComponent
    with HasGameReference<RogueAgentsGame> {
  DraftOverlay()
      : super(size: GameConfig.designSize, priority: 1000);

  static const cardWidth = 300.0;
  static const cardHeight = 330.0;
  static const cardGap = 36.0;

  bool _visible = false;
  bool get isVisible => _visible;

  final _cards = <UpgradeCard>[];

  final _scrim = Paint()..color = const Color(0xE6010A0A);

  final _title = TextPaint(
    style: const TextStyle(
      color: Palette.hudText,
      fontSize: 46,
      fontWeight: FontWeight.w900,
      letterSpacing: 3,
    ),
  );
  final _subtitle = TextPaint(
    style: const TextStyle(
      color: Palette.hudDim,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 3,
    ),
  );
  final _footer = TextPaint(
    style: const TextStyle(
      color: Palette.hudDim,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 2,
    ),
  );

  /// Lays out one card per offered upgrade and freezes the run.
  void show(List<UpgradeSpec> offers) {
    _visible = true;
    for (final card in _cards) {
      card.removeFromParent();
    }
    _cards.clear();

    final totalWidth =
        offers.length * cardWidth + (offers.length - 1) * cardGap;
    var x = (GameConfig.designWidth - totalWidth) / 2;

    for (var i = 0; i < offers.length; i++) {
      final card = UpgradeCard(
        spec: offers[i],
        index: i,
        position: Vector2(x, (GameConfig.designHeight - cardHeight) / 2 + 24),
      );
      _cards.add(card);
      add(card);
      x += cardWidth + cardGap;
    }
  }

  void hide() {
    _visible = false;
    for (final card in _cards) {
      card.removeFromParent();
    }
    _cards.clear();
  }

  /// Keyboard shortcut: 1, 2, 3 pick the matching card.
  void chooseByIndex(int index) {
    if (!_visible || index < 0 || index >= _cards.length) return;
    game.chooseUpgrade(_cards[index].spec);
  }

  @override
  void render(Canvas canvas) {
    if (!_visible) return;

    canvas.drawRect(GameConfig.designSize.toRect(), _scrim);

    final cx = GameConfig.designWidth / 2;
    _subtitle.render(
      canvas,
      'PRIVILEGE ESCALATION AVAILABLE',
      Vector2(cx, 96),
      anchor: Anchor.topCenter,
    );
    _title.render(
      canvas,
      'CLEARANCE TIER ${game.level}',
      Vector2(cx, 122),
      anchor: Anchor.topCenter,
    );
    _footer.render(
      canvas,
      game.pendingLevelUps > 1
          ? 'CLICK A PATCH OR PRESS 1-3   ·   ${game.pendingLevelUps - 1} MORE QUEUED'
          : 'CLICK A PATCH OR PRESS 1-3',
      Vector2(cx, GameConfig.designHeight - 96),
      anchor: Anchor.topCenter,
    );
  }
}

/// One selectable upgrade card.
class UpgradeCard extends PositionComponent
    with HasGameReference<RogueAgentsGame>, TapCallbacks, HoverCallbacks {
  UpgradeCard({
    required this.spec,
    required this.index,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2(DraftOverlay.cardWidth, DraftOverlay.cardHeight),
        );

  final UpgradeSpec spec;
  final int index;

  final _panel = Paint()..color = const Color(0xFF07201F);
  final _edge = Paint()
    ..color = Palette.border
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _edgeHot = Paint()
    ..color = Palette.player
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final _chip = Paint()..color = const Color(0xFF0E3B3A);

  final _key = TextPaint(
    style: const TextStyle(
      color: Palette.player,
      fontSize: 20,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    ),
  );
  final _tag = TextPaint(
    style: const TextStyle(
      color: Palette.hudDim,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.5,
    ),
  );
  final _name = TextPaint(
    style: const TextStyle(
      color: Palette.hudText,
      fontSize: 27,
      fontWeight: FontWeight.w800,
      height: 1.15,
    ),
  );
  final _blurb = TextPaint(
    style: const TextStyle(
      color: Color(0xFF8FC4C4),
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.35,
    ),
  );
  final _stacks = TextPaint(
    style: const TextStyle(
      color: Palette.hudDim,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );

  @override
  void onTapDown(TapDownEvent event) => game.chooseUpgrade(spec);

  @override
  void render(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      size.toRect().deflate(1.5),
      const Radius.circular(10),
    );
    canvas
      ..drawRRect(body, _panel)
      ..drawRRect(body, isHovered ? _edgeHot : _edge);

    // Number chip, so the keyboard shortcut is obvious.
    final chip = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 18, 36, 32),
      const Radius.circular(6),
    );
    canvas.drawRRect(chip, _chip);
    _key.render(canvas, '${index + 1}', Vector2(36, 24), anchor: Anchor.topCenter);

    _tag.render(canvas, spec.tag, Vector2(66, 27));

    _name.render(
      canvas,
      spec.name,
      Vector2(20, 84),
      anchor: Anchor.topLeft,
    );
    _blurb.render(
      canvas,
      _wrap(spec.blurb, 26),
      Vector2(20, 168),
      anchor: Anchor.topLeft,
    );

    final taken = game.upgradesTaken[spec.id] ?? 0;
    if (taken > 0) {
      _stacks.render(
        canvas,
        'INSTALLED x$taken',
        Vector2(20, size.y - 36),
      );
    }
  }

  /// Flame's TextPaint does not wrap, so break the blurb by hand.
  static String _wrap(String text, int columns) {
    final words = text.split(' ');
    final lines = <String>[];
    var line = '';
    for (final word in words) {
      if (line.isEmpty) {
        line = word;
      } else if (line.length + 1 + word.length <= columns) {
        line = '$line $word';
      } else {
        lines.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines.join('\n');
  }
}
