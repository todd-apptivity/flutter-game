import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game/config/game_config.dart';

/// Single source of truth for "where does the player want to go".
///
/// Keyboard wins while any movement key is held; otherwise the player chases
/// the mouse. Sized to the whole design rect so pointer events anywhere on the
/// canvas reach it.
class InputController extends PositionComponent with PointerMoveCallbacks {
  InputController()
      : super(size: GameConfig.designSize, priority: -200);

  static final _up = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.arrowUp,
  };
  static final _down = {
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.arrowDown,
  };
  static final _left = {
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.arrowLeft,
  };
  static final _right = {
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowRight,
  };

  final _pressed = <LogicalKeyboardKey>{};

  /// Last known pointer position in world coordinates, or null if the mouse
  /// has not been over the canvas yet.
  Vector2? pointer;

  /// True while any movement key is held, so the mouse is ignored.
  bool get usingKeyboard => keyboardDirection.length2 > 0;

  /// Unit-ish vector from the held keys. Zero when nothing is held.
  Vector2 get keyboardDirection {
    final d = Vector2.zero();
    if (_pressed.any(_up.contains)) d.y -= 1;
    if (_pressed.any(_down.contains)) d.y += 1;
    if (_pressed.any(_left.contains)) d.x -= 1;
    if (_pressed.any(_right.contains)) d.x += 1;
    return d.length2 > 0 ? d.normalized() : d;
  }

  /// Fed by the game's key handler. Tracking the raw set (rather than reacting
  /// to each event) keeps diagonals and key-release order correct.
  void syncKeys(Set<LogicalKeyboardKey> keysPressed) {
    _pressed
      ..clear()
      ..addAll(keysPressed);
  }

  /// Desired travel direction for [from], or zero to stand still.
  Vector2 directionFor(Vector2 from) {
    final keys = keyboardDirection;
    if (keys.length2 > 0) return keys;

    final target = pointer;
    if (target == null) return Vector2.zero();

    final delta = target - from;
    // Dead zone stops the jitter you get when the core sits on the cursor.
    return delta.length <= GameConfig.pointerDeadZone
        ? Vector2.zero()
        : delta.normalized();
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    pointer = event.localPosition;
  }
}
