import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';

/// How an agent decides where to go.
enum AgentBehavior {
  /// Walks straight at the control plane.
  chase,

  /// Chases, but weaves as it goes — reads as a cloud rather than a line.
  swarm,

  /// Closes to [AgentSpec.preferredRange] and lobs injections from there.
  ranged,
}

/// Everything that makes one kind of rogue agent different from another.
/// Adding a new agent type is one entry in [agentCatalog].
class AgentSpec {
  const AgentSpec({
    required this.id,
    required this.name,
    required this.blurb,
    required this.hp,
    required this.speed,
    required this.damage,
    required this.xp,
    required this.frameSize,
    this.behavior = AgentBehavior.chase,
    this.color = Palette.agent,
    this.eyeColor = Palette.agentEye,
    this.spritePath,
    this.spriteFrames = 2,
    this.spriteStepTime = 0.18,
    this.groupSize = 1,
    this.preferredRange = 0,
    this.attackCooldown = 2,
    this.projectileSpeed = 200,
    this.projectileDamage = 0,
  });

  /// Stable key, also used in logs and the HUD.
  final String id;

  /// Shown to the player.
  final String name;

  /// Flavour text for the eventual bestiary / kill feed.
  final String blurb;

  final double hp;

  /// World units per second.
  final double speed;

  /// Integrity removed per second of contact with the control plane.
  final double damage;

  /// Tokens worth of XP dropped on death.
  final int xp;

  /// Art frame size in source pixels; drawn at [GameConfig.pixelScale].
  final double frameSize;

  final AgentBehavior behavior;
  final Color color;
  final Color eyeColor;

  /// Sprite strip under assets/images, or null to always draw the placeholder.
  final String? spritePath;
  final int spriteFrames;
  final double spriteStepTime;

  /// How many spawn together. Swarms arrive as a pack from one edge.
  final int groupSize;

  /// Ranged agents hold this far from the control plane.
  final double preferredRange;

  /// Seconds between ranged attacks.
  final double attackCooldown;

  /// Speed and damage of this agent's own projectile.
  final double projectileSpeed;
  final double projectileDamage;

  bool get isRanged =>
      behavior == AgentBehavior.ranged && projectileDamage > 0;

  /// On-screen size in world units.
  Vector2 get renderSize =>
      Vector2.all(frameSize * GameConfig.pixelScale);
}

/// The bestiary. Add a row to add an enemy.
const agentCatalog = <AgentSpec>[
  AgentSpec(
    id: 'scraper',
    name: 'Scraper',
    blurb: 'Crawls the arena for anything left unauthenticated.',
    hp: 12,
    speed: 88,
    damage: 8,
    xp: 1,
    frameSize: 24,
    spritePath: 'agent_scraper.png',
  ),
  AgentSpec(
    id: 'swarmlet',
    name: 'Swarm-let',
    blurb: 'A forked sub-agent. Cheap, disposable, never alone.',
    hp: 5,
    speed: 142,
    damage: 5,
    xp: 1,
    frameSize: 12,
    behavior: AgentBehavior.swarm,
    groupSize: 5,
    spritePath: 'agent_swarmlet.png',
    spriteStepTime: 0.09,
  ),
  AgentSpec(
    id: 'crawler',
    name: 'Crawler',
    blurb: 'Indexes your whole surface area. Slow, armoured, relentless.',
    hp: 70,
    speed: 48,
    damage: 18,
    xp: 5,
    frameSize: 40,
    spritePath: 'agent_crawler.png',
    spriteStepTime: 0.3,
  ),
  AgentSpec(
    id: 'injector',
    name: 'Prompt Injector',
    blurb: 'Stands off and lobs adversarial payloads at your context.',
    hp: 26,
    speed: 74,
    damage: 10,
    xp: 4,
    frameSize: 28,
    behavior: AgentBehavior.ranged,
    preferredRange: 300,
    attackCooldown: 2.1,
    projectileSpeed: 260,
    projectileDamage: 9,
    spritePath: 'agent_injector.png',
  ),
];

/// Lookup by id, for waves and upgrades that name a type.
AgentSpec agentSpec(String id) =>
    agentCatalog.firstWhere((spec) => spec.id == id);
