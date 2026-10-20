import 'package:flame/components.dart';

/// Tunables that shape the whole run. Stage configs (agents, weapons,
/// upgrades, waves) get their own files beside this one.
class GameConfig {
  const GameConfig._();

  /// The game is authored at exactly this resolution and letterboxed to fit
  /// the browser window, so a 1280x720 stream frame is pixel-for-pixel.
  static const designWidth = 1280.0;
  static const designHeight = 720.0;

  static Vector2 get designSize => Vector2(designWidth, designHeight);

  /// Playfield inset from the design edges, leaving room for the HUD.
  static const arenaMargin = 24.0;

  /// Sprites are authored small and drawn at this scale.
  static const pixelScale = 2.0;

  /// Player core: 32x32 art at [pixelScale].
  static const playerSize = 32.0 * pixelScale;

  /// Base player travel speed, world units per second.
  static const playerSpeed = 260.0;

  /// How fast the core reaches full speed / stops, in seconds-ish. Small
  /// enough to feel responsive, large enough that it doesn't snap.
  static const playerAccel = 14.0;

  /// Mouse steering ignores anything closer than this, so the core doesn't
  /// vibrate when it is sitting under the cursor.
  static const pointerDeadZone = 6.0;

  /// Seconds between agent spawns. Stage 9's wave table takes this over.
  static const spawnInterval = 0.8;

  /// Grace period before the first agent appears, so a run does not open with
  /// something already in your face.
  static const firstSpawnDelay = 1.5;

  /// How far beyond the arena edge agents appear, on top of their own size.
  static const spawnOffscreen = 16.0;

  /// Hard cap on live agents, so a long run cannot tank the frame rate.
  static const maxAgents = 120;

  /// Control plane integrity at the start of a run.
  static const maxIntegrity = 100.0;

  /// Mercy window after taking a hit. Without it, standing in a crowd applies
  /// every agent's damage every frame and a run ends in a couple of seconds.
  static const playerInvulnerability = 0.45;

  /// How long an agent flashes white after being hit.
  static const hitFlashDuration = 0.09;

  /// Player collision radius as a fraction of its drawn size.
  static const playerHitFraction = 0.34;
}
