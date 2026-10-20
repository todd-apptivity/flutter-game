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
}
