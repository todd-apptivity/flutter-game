import 'dart:ui';

import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';

/// How a weapon delivers damage.
enum WeaponKind {
  /// Fires projectiles at the nearest agent in range.
  projectile,

  /// Spins nodes around the control plane that damage what they touch.
  orbit,
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
    this.orbitRadius = 110,
    this.orbitSpeed = 2.4,
    this.orbitNodes = 2,
    this.orbitNodeSize = 20,
    this.hitCooldown = 0.55,
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

  /// Orbit weapons only: how far out the nodes ride, how fast they sweep
  /// (radians per second), how many there are, how big they are, and how
  /// often one node may re-hit the same agent.
  final double orbitRadius;
  final double orbitSpeed;
  final int orbitNodes;
  final double orbitNodeSize;
  final double hitCooldown;

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
  WeaponSpec(
    id: 'rate_limiter',
    name: 'Rate Limiter',
    blurb: 'Throttle nodes orbit the control plane and shred what touches them.',
    kind: WeaponKind.orbit,
    cooldown: 0,
    damage: 9,
    range: 0,
    orbitRadius: 118,
    orbitSpeed: 2.3,
    orbitNodes: 2,
    orbitNodeSize: 22,
    hitCooldown: 0.5,
    spritePath: 'orbit_node.png',
  ),
];

WeaponSpec weaponSpec(String id) =>
    weaponCatalog.firstWhere((spec) => spec.id == id);
