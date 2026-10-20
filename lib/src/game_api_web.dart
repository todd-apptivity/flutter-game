import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/projectile.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';
import 'package:flutter_game/game/token.dart';

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

  JSObject stateOf() =>
      {
            'ready': isReady(),
            'paused': game.paused,
            'player': isReady()
                ? {'x': game.player.position.x, 'y': game.player.position.y}
                : null,
            'agents': isReady()
                ? game.world.children
                      .whereType<Agent>()
                      .map(
                        (a) => {
                          'id': a.spec.id,
                          'x': a.position.x,
                          'y': a.position.y,
                          'hp': a.hp,
                        },
                      )
                      .toList()
                : <Object>[],
            'projectiles': isReady()
                ? game.world.children
                      .whereType<Projectile>()
                      .map((p) => {'x': p.position.x, 'y': p.position.y})
                      .toList()
                : <Object>[],
            'tokens': isReady()
                ? game.world.children
                      .whereType<Token>()
                      .map((t) => {'x': t.position.x, 'y': t.position.y})
                      .toList()
                : <Object>[],
            'xp': game.xp,
            'level': game.level,
            'drafting': game.isDrafting,
            'offered': game.offered.map((u) => u.id).toList(),
            'upgradesTaken': Map<String, int>.from(game.upgradesTaken),
            'tokensCollected': game.tokensCollected,
            'integrity': game.integrity,
            'kills': game.kills,
            'elapsed': game.elapsed,
            'music': {
              'enabled': game.music.enabled,
              'started': game.music.started,
              'suspended': game.music.suspended,
              'bpm': game.music.bpm,
              'targetBpm': game.music.targetBpm,
              'bufferedBytes': game.music.bufferedBytes,
              'renderedSeconds': game.music.renderedSeconds,
              'error': game.music.error,
            },
          }.jsify()
          as JSObject;

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
