import 'dart:ui';

import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';

/// How a weapon delivers damage. Stage 10 adds the orbiting kind.
enum WeaponKind {
  /// Fires projectiles at the nearest agent in range.
  projectile,
}

/// One automatic defense. Adding a weapon is one entry in [weaponCatalog].
class WeaponSpec {
  const WeaponSpec({
    required this.id,
    required this.name,
    required this.blurb,
    required this.cooldown,
    required this.damage,
    required this.range,
    this.kind = WeaponKind.projectile,
    this.projectileSpeed = 520,
    this.projectileCount = 1,
    this.spread = 0.18,
    this.pierce = 0,
    this.projectileFrameSize = 8,
    this.color = Palette.projectile,
    this.spritePath,
  });

  final String id;
  final String name;
  final String blurb;

  /// Seconds between volleys.
  final double cooldown;

  /// Damage per projectile.
  final double damage;

  /// Nothing outside this radius is targeted.
  final double range;

  final WeaponKind kind;
  final double projectileSpeed;

  /// Projectiles per volley; above one they fan out by [spread] radians.
  final int projectileCount;
  final double spread;

  /// Extra agents a projectile passes through before expiring.
  final int pierce;

  final double projectileFrameSize;
  final Color color;
  final String? spritePath;

  /// On-screen projectile size in world units.
  double get projectileSize => projectileFrameSize * GameConfig.pixelScale;
}

/// The armoury. Add a row to add a weapon.
const weaponCatalog = <WeaponSpec>[
  WeaponSpec(
    id: 'packet_cannon',
    name: 'Packet Cannon',
    blurb: 'Drops malformed requests before they reach the API.',
    cooldown: 0.55,
    damage: 5,
    range: 420,
    spritePath: 'proj_packet.png',
  ),
];

WeaponSpec weaponSpec(String id) =>
    weaponCatalog.firstWhere((spec) => spec.id == id);
