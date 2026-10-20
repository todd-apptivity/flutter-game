import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, KeyEventResult;
import 'package:flutter_game/audio/adaptive_music.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';
import 'package:flutter_game/config/upgrades.dart';
import 'package:flutter_game/config/waves.dart';
import 'package:flutter_game/config/weapons.dart';
import 'package:flutter_game/game/agent.dart';
import 'package:flutter_game/game/arena.dart';
import 'package:flutter_game/game/combat.dart';
import 'package:flutter_game/game/draft_overlay.dart';
import 'package:flutter_game/game/game_over_overlay.dart';
import 'package:flutter_game/game/injection.dart';
import 'package:flutter_game/game/orbit_node.dart';
import 'package:flutter_game/game/projectile.dart';
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
  /// Replaced wholesale on restart, so not final.
  late Spawner spawner;
  late final DraftOverlay draftOverlay;
  late final GameOverOverlay gameOverOverlay;

  final music = AdaptiveMusic();
  bool _musicInBackground = false;

  void _syncMusicPause() =>
      music.setPaused(paused || isDrafting || _musicInBackground);

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

  /// Pickup radius, widened by upgrades.
  double magnetRadius = GameConfig.magnetRadius;

  /// Player movement scaling from upgrades.
  double playerSpeedMultiplier = 1;

  /// Upgrade effects that must also apply to weapons equipped *later*, so a
  /// second cannon picked up at tier 6 is not stuck at base stats.
  double weaponCooldownMultiplier = 1;
  double weaponDamageMultiplier = 1;
  int weaponExtraProjectiles = 0;
  int weaponExtraPierce = 0;

  /// Run-wide combat scaling, read live by weapons and projectiles.
  double weaponRangeMultiplier = 1;
  double projectileSpeedMultiplier = 1;

  /// Chance (0..1) for a packet to crit, and what a crit multiplies damage by.
  double critChance = 0;
  double critMultiplier = 2;

  /// Integrity repaired per second.
  double regenPerSecond = 0;

  /// Incoming contact damage is scaled by this.
  double damageTakenMultiplier = 1;

  /// XP multiplier applied as tokens are absorbed.
  double tokenValueMultiplier = 1;

  /// Maximum integrity, which some upgrades raise.
  double maxIntegrity = GameConfig.maxIntegrity;

  /// Rolls a crit for one packet.
  bool rollCrit() => critChance > 0 && _random.nextDouble() < critChance;

  /// Banner text for the wave that just started, and how long it stays up.
  String? waveBanner;
  double waveBannerTimer = 0;

  /// Called by the spawner when the wave table moves on.
  void onWaveChanged(WaveSpec wave) {
    waveBanner = wave.label;
    waveBannerTimer = GameConfig.waveBannerDuration;
  }

  /// How many times each upgrade has been taken.
  final upgradesTaken = <String, int>{};

  /// Level-ups banked but not yet drafted.
  int pendingLevelUps = 0;

  /// The three cards currently on offer, empty when the game is running.
  final offered = <UpgradeSpec>[];

  /// True while the draft screen is up and the simulation is frozen.
  bool get isDrafting => offered.isNotEmpty;

  /// True once integrity has run out. The run is over until [restart].
  bool isOver = false;

  /// Anything that stops the arena advancing.
  bool get isFrozen => isDrafting || isOver;

  final _random = Random();

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

    draftOverlay = DraftOverlay();
    gameOverOverlay = GameOverOverlay();

    await world.addAll([arena, input, player, spawner, Combat()]);
    await camera.viewport.addAll([Hud(), draftOverlay, gameOverOverlay]);
    await equip(weaponSpec('packet_cannon'));
  }

  /// Freezes the arena while the draft is up by handing every component a dt
  /// of zero. Lifecycle, input and rendering carry on, so the cards are live
  /// while agents, packets and cooldowns are all stopped dead.
  ///
  /// The game-over screen is exempt: it needs its own clock to arm its input,
  /// so it is ticked directly with the real dt.
  @override
  void updateTree(double dt) {
    super.updateTree(isFrozen ? 0 : dt);
    if (isOver) gameOverOverlay.update(dt);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncMusicPause();
    if (isFrozen) return;
    elapsed += dt;
    if (regenPerSecond > 0) repairPlayer(regenPerSecond * dt);
    if (waveBannerTimer > 0) {
      waveBannerTimer -= dt;
      if (waveBannerTimer <= 0) waveBanner = null;
    }
    music.updateDanger(
      healthFraction: integrity / maxIntegrity,
      enemies: world.children
          .whereType<Agent>()
          .where((agent) => !agent.isRemoving && agent.hp > 0)
          .length,
    );
  }

  /// Contact damage from an agent standing on the control plane.
  void damagePlayer(double amount) {
    if (amount <= 0 || isOver) return;
    final applied =
        (amount * damageTakenMultiplier).clamp(0.0, integrity);
    integrity -= applied;
    integrityLost += applied;

    if (integrity <= 0) endRun();
  }

  /// The control plane is gone: freeze everything and show the result.
  void endRun() {
    if (isOver) return;
    isOver = true;
    integrity = 0;

    // A draft left open would fight the game-over screen for the same input.
    offered.clear();
    pendingLevelUps = 0;
    draftOverlay.hide();

    gameOverOverlay.show();
  }

  /// Resumes a finished run without resetting it. Only the dev bridge calls
  /// this: the game itself has no revive.
  void reviveForTesting() {
    if (!isOver) return;
    isOver = false;
    gameOverOverlay.hide();
  }

  /// Tears the run down and starts a fresh one in place.
  ///
  /// Everything that a run accumulates is either a field reset here or a
  /// component removed here; the arena, input and camera survive untouched.
  Future<void> restart() async {
    gameOverOverlay.hide();
    draftOverlay.hide();

    for (final component in world.children.toList()) {
      if (component is Agent ||
          component is Projectile ||
          component is Injection ||
          component is Token ||
          component is OrbitNode ||
          component is Weapon ||
          component is Spawner) {
        component.removeFromParent();
      }
    }
    weapons.clear();
    upgradesTaken.clear();
    offered.clear();
    pendingLevelUps = 0;

    integrity = GameConfig.maxIntegrity;
    maxIntegrity = GameConfig.maxIntegrity;
    integrityLost = 0;
    kills = 0;
    elapsed = 0;
    level = 1;
    xp = 0;
    tokensCollected = 0;

    magnetRadius = GameConfig.magnetRadius;
    playerSpeedMultiplier = 1;
    weaponCooldownMultiplier = 1;
    weaponDamageMultiplier = 1;
    weaponExtraProjectiles = 0;
    weaponExtraPierce = 0;
    weaponRangeMultiplier = 1;
    projectileSpeedMultiplier = 1;
    critChance = 0;
    critMultiplier = 2;
    regenPerSecond = 0;
    damageTakenMultiplier = 1;
    tokenValueMultiplier = 1;

    waveBanner = null;
    waveBannerTimer = 0;

    player
      ..position = GameConfig.designSize / 2
      ..velocity.setZero()
      ..clearMercyWindow();

    // A fresh spawner restarts the grace period and the wave tracking.
    spawner = Spawner();
    await world.add(spawner);
    await equip(weaponSpec('packet_cannon'));

    isOver = false;
  }

  /// Called by an agent as it dies.
  void onAgentKilled(Agent agent) {
    kills++;
    world.add(Token(position: agent.position.clone(), value: agent.spec.xp));
  }

  /// Called by a token as it is absorbed.
  void collectToken(Token token) {
    tokensCollected++;
    xp += (token.value * tokenValueMultiplier).round();

    while (xp >= xpForNextLevel) {
      xp -= xpForNextLevel;
      levelUp();
    }
  }

  /// Banks a tier and opens the draft (or queues it if one is already up).
  void levelUp() {
    level++;
    pendingLevelUps++;
    if (!isDrafting) openDraft();
  }

  /// Picks three distinct eligible upgrades and freezes the arena.
  void openDraft() {
    final pool = upgradeCatalog.where(isUpgradeAvailable).toList();
    if (pool.isEmpty) {
      pendingLevelUps = 0;
      return;
    }

    offered
      ..clear()
      ..addAll(_drawWeighted(pool, 3));
    draftOverlay.show(offered);
  }

  /// Draws [count] distinct specs, weighted by [UpgradeSpec.weight], so rare
  /// cards stay rare without ever being unreachable.
  List<UpgradeSpec> _drawWeighted(List<UpgradeSpec> pool, int count) {
    final remaining = [...pool];
    final drawn = <UpgradeSpec>[];

    while (drawn.length < count && remaining.isNotEmpty) {
      final total = remaining.fold<int>(0, (sum, s) => sum + s.weight);
      var roll = _random.nextInt(total);
      var picked = remaining.last;
      for (final spec in remaining) {
        roll -= spec.weight;
        if (roll < 0) {
          picked = spec;
          break;
        }
      }
      drawn.add(picked);
      remaining.remove(picked);
    }
    return drawn;
  }

  bool isUpgradeAvailable(UpgradeSpec spec) {
    if ((upgradesTaken[spec.id] ?? 0) >= spec.maxStacks) return false;
    return spec.available?.call(this) ?? true;
  }

  /// Applies the chosen card, then either re-opens for a queued tier or
  /// resumes the run.
  void chooseUpgrade(UpgradeSpec spec) {
    if (!offered.contains(spec)) return;

    spec.apply(this);
    upgradesTaken.update(spec.id, (n) => n + 1, ifAbsent: () => 1);
    pendingLevelUps = (pendingLevelUps - 1).clamp(0, 99);

    offered.clear();
    draftOverlay.hide();

    if (pendingLevelUps > 0) openDraft();
  }

  /// Repairs the control plane, never above the maximum.
  void repairPlayer(double amount) {
    integrity = (integrity + amount).clamp(0.0, maxIntegrity);
  }

  /// Gives the player a weapon. Upgrades call this to add a second one.
  Future<Weapon> equip(WeaponSpec spec) async {
    // Inherit everything the player has already unlocked.
    final weapon = Weapon(spec)
      ..cooldownMultiplier = weaponCooldownMultiplier
      ..damageMultiplier = weaponDamageMultiplier
      ..extraProjectiles = weaponExtraProjectiles
      ..extraPierce = weaponExtraPierce;
    weapons.add(weapon);
    await world.add(weapon);
    return weapon;
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      // R redeploys once the end-of-run screen has armed.
      if (isOver) {
        if (event.logicalKey == LogicalKeyboardKey.keyR &&
            gameOverOverlay.isArmed) {
          unawaited(restart());
        }
        return KeyEventResult.handled;
      }

      // 1-3 pick a card while the draft is up.
      final picks = {
        LogicalKeyboardKey.digit1: 0,
        LogicalKeyboardKey.digit2: 1,
        LogicalKeyboardKey.digit3: 2,
      };
      final pick = picks[event.logicalKey];
      if (isDrafting && pick != null) {
        draftOverlay.chooseByIndex(pick);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyM) {
        unawaited(music.toggle());
      } else {
        unawaited(music.unlock());
      }
    }
    input.syncKeys(keysPressed);
    return KeyEventResult.handled;
  }

  @override
  set paused(bool value) {
    super.paused = value;
    _syncMusicPause();
  }

  @override
  void pauseEngine() {
    super.pauseEngine();
    _syncMusicPause();
  }

  @override
  void resumeEngine() {
    super.resumeEngine();
    _syncMusicPause();
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    _musicInBackground = state != AppLifecycleState.resumed;
    super.lifecycleStateChange(state);
    _syncMusicPause();
  }

  @override
  void onRemove() {
    music.dispose();
    super.onRemove();
  }
}
