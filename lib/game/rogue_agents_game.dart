import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';
import 'package:flutter_game/config/weapons.dart';
import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/arena.dart';
import 'package:flutter_game/game/combat.dart';
import 'package:flutter_game/game/hud.dart';
import 'package:flutter_game/game/input_controller.dart';
import 'package:flutter_game/game/player.dart';
import 'package:flutter_game/game/spawner.dart';
import 'package:flutter_game/game/token.dart';
import 'package:flutter_game/game/weapon.dart';

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
  late final Spawner spawner;

  /// Weapons the player currently owns. Stage 7 upgrades add to this.
  final weapons = <Weapon>[];

  /// Control plane health. Stage 11 ends the run when it reaches zero.
  double integrity = GameConfig.maxIntegrity;

  /// Agents destroyed this run.
  int kills = 0;

  /// Seconds since the run began.
  double elapsed = 0;

  /// Damage taken, for the eventual game-over readout.
  double integrityLost = 0;

  /// Current level, and XP banked toward the next one.
  int level = 1;
  int xp = 0;

  /// Tokens absorbed this run.
  int tokensCollected = 0;

  /// Pickup radius, widened by upgrades in stage 7.
  double magnetRadius = GameConfig.magnetRadius;

  /// XP required to go from [level] to the next one. Grows geometrically so
  /// early levels come fast and the pace settles later in a run.
  int get xpForNextLevel {
    var cost = GameConfig.baseLevelCost.toDouble();
    for (var i = 1; i < level; i++) {
      cost *= GameConfig.levelCostGrowth;
    }
    return cost.round();
  }

  /// Progress toward the next level, 0..1.
  double get levelProgress => (xp / xpForNextLevel).clamp(0.0, 1.0);

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
    spawner = Spawner();

    await world.addAll([arena, input, player, spawner, Combat()]);
    await camera.viewport.add(Hud());
    await equip(weaponSpec('packet_cannon'));
  }

  @override
  void update(double dt) {
    super.update(dt);
    elapsed += dt;
  }

  /// Contact damage from an agent standing on the control plane.
  void damagePlayer(double amount) {
    if (amount <= 0) return;
    final applied = amount.clamp(0.0, integrity);
    integrity -= applied;
    integrityLost += applied;
  }

  /// Called by an agent as it dies.
  void onAgentKilled(Agent agent) {
    kills++;
    world.add(Token(position: agent.position.clone(), value: agent.spec.xp));
  }

  /// Called by a token as it is absorbed.
  void collectToken(Token token) {
    tokensCollected++;
    xp += token.value;

    while (xp >= xpForNextLevel) {
      xp -= xpForNextLevel;
      levelUp();
    }
  }

  /// Stage 7 turns this into the upgrade draft; for now it just banks a level.
  void levelUp() {
    level++;
  }

  /// Gives the player a weapon. Upgrades call this to add a second one.
  Future<Weapon> equip(WeaponSpec spec) async {
    final weapon = Weapon(spec);
    weapons.add(weapon);
    await world.add(weapon);
    return weapon;
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
