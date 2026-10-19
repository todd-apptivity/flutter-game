import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flame/components.dart';
import 'package:flutter_game/game.dart';

@JS('globalThis')
external JSObject get _globalThis;

/// The shape handed to JS as `window.rogueAgent`.
extension type _RogueAgentApi._(JSObject _) implements JSObject {
  external factory _RogueAgentApi({
    JSFunction ready,
    JSFunction state,
    JSFunction tap,
    JSFunction reset,
    JSFunction setPaused,
    JSFunction step,
  });
}

/// Publishes `window.rogueAgent`. Driver-facing contract:
///
/// ```js
/// await rogueAgent.ready()          // true once the game tree is mounted
/// rogueAgent.state()                // { ready, paused, width, height, player, target }
/// rogueAgent.tap(120, 240)          // same effect as tapping that point
/// rogueAgent.setPaused(true)        // stop the rAF-driven loop
/// rogueAgent.step(0.016)            // advance one deterministic frame while paused
/// rogueAgent.reset()                // agent back to centre, target cleared
/// ```
void installGameApi(MyGame game) {
  bool isReady() => game.isMounted && game.children.whereType<Player>().isNotEmpty;

  JSObject stateOf() {
    final target = isReady() ? game.player.target : null;
    return {
      'ready': isReady(),
      'paused': game.paused,
      'width': game.size.x,
      'height': game.size.y,
      'player': isReady()
          ? {'x': game.player.position.x, 'y': game.player.position.y}
          : null,
      'target': target == null ? null : {'x': target.x, 'y': target.y},
    }.jsify() as JSObject;
  }

  _globalThis.setProperty(
    'rogueAgent'.toJS,
    _RogueAgentApi(
      ready: (() => isReady().toJS).toJS,
      state: (() => stateOf()).toJS,
      tap: ((double x, double y) {
        if (isReady()) game.moveTo(Vector2(x, y));
      }).toJS,
      reset: (() {
        if (isReady()) game.reset();
      }).toJS,
      setPaused: ((bool paused) => game.paused = paused).toJS,
      // Manual tick: the engine skips update() while paused, so a driver can
      // advance the simulation by an exact dt and get reproducible positions.
      step: ((double dt) {
        if (isReady()) game.update(dt);
      }).toJS,
    ),
  );
}
