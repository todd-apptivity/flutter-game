import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_game/game/rogue_agents_game.dart';

@JS('globalThis')
external JSObject get _globalThis;

/// The shape handed to JS as `window.rogueAgent`.
extension type _RogueAgentApi._(JSObject _) implements JSObject {
  external factory _RogueAgentApi({
    JSFunction ready,
    JSFunction state,
    JSFunction setPaused,
    JSFunction step,
  });
}

/// Publishes `window.rogueAgent` so a Chromium driver can inspect and drive the
/// game without clicking canvas pixels. Driver-facing contract:
///
/// ```js
/// rogueAgent.ready()        // true once the game tree is mounted
/// rogueAgent.state()        // { ready, paused, player: {x, y} }
/// rogueAgent.setPaused(true)
/// rogueAgent.step(0.016)    // advance one deterministic frame while paused
/// ```
void installGameApi(RogueAgentsGame game) {
  bool isReady() => game.isMounted;

  JSObject stateOf() => {
        'ready': isReady(),
        'paused': game.paused,
        'player': isReady()
            ? {'x': game.player.position.x, 'y': game.player.position.y}
            : null,
      }.jsify() as JSObject;

  _globalThis.setProperty(
    'rogueAgent'.toJS,
    _RogueAgentApi(
      ready: (() => isReady().toJS).toJS,
      state: (() => stateOf()).toJS,
      setPaused: ((bool paused) => game.paused = paused).toJS,
      // Manual tick: the engine skips update() while paused, so a driver can
      // advance the simulation by an exact dt and get reproducible positions.
      step: ((double dt) {
        if (isReady()) game.update(dt);
      }).toJS,
    ),
  );
}
