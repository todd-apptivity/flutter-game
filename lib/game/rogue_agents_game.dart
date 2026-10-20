import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';
import 'package:flutter_game/game/arena.dart';
import 'package:flutter_game/game/input_controller.dart';
import 'package:flutter_game/game/player.dart';

/// Rogue Agents: you are the control plane. Everything else wants in.
class RogueAgentsGame extends FlameGame with KeyboardEvents {
  RogueAgentsGame()
      : super(
          // Authored at 1280x720 and letterboxed, so world coordinates are
          // always design pixels no matter how big the browser window is.
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.designWidth,
            height: GameConfig.designHeight,
          ),
        );

  late final Arena arena;
  late final Player player;
  late final InputController input;

  @override
  Color backgroundColor() => Palette.background;

  @override
  Future<void> onLoad() async {
    // The fixed-resolution camera looks at the origin by default, so shift it
    // to the middle of the design rect and author everything in 0..1280/0..720.
    camera.viewfinder.position = GameConfig.designSize / 2;

    arena = Arena();
    input = InputController();
    player = Player()..position = GameConfig.designSize / 2;

    await world.addAll([arena, input, player]);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    input.syncKeys(keysPressed);
    return KeyEventResult.handled;
  }
}
