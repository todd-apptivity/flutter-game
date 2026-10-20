import 'dart:ui';

/// Every colour in the game lives here so the look can be retuned in one place.
class Palette {
  const Palette._();

  /// Arena background — near-black teal.
  static const background = Color(0xFF031212);

  /// Faint grid lines on the arena floor.
  static const grid = Color(0xFF0B2A2A);

  /// Brighter line every [Arena.majorEvery] cells.
  static const gridMajor = Color(0xFF123C3C);

  /// Arena boundary.
  static const border = Color(0xFF1A5C5C);

  /// The player: the control plane.
  static const player = Color(0xFF20B1B3);

  /// Hot centre of the player core.
  static const playerCore = Color(0xFFCFFBFB);

  /// Rogue agent chassis.
  static const agent = Color(0xFF1C2224);

  /// Rogue agent eye.
  static const agentEye = Color(0xFFBC2222);

  /// Projectiles / packets.
  static const projectile = Color(0xFF20B1B3);

  /// HUD text.
  static const hudText = Color(0xFFBFECEC);

  /// HUD dim / secondary text.
  static const hudDim = Color(0xFF4F7F7F);
}
