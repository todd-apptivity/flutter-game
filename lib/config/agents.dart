import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/config/palette.dart';

/// How an agent decides where to go. Stage 9 adds the rest.
enum AgentBehavior {
  /// Walks straight at the control plane.
  chase,
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
    hp: 10,
    speed: 70,
    damage: 8,
    xp: 1,
    frameSize: 24,
    spritePath: 'agent_scraper.png',
  ),
];

/// Lookup by id, for waves and upgrades that name a type.
AgentSpec agentSpec(String id) =>
    agentCatalog.firstWhere((spec) => spec.id == id);
