import 'package:flutter_game/game/rogue_agents_game.dart';

/// One choice on the level-up screen.
///
/// Adding an upgrade is one entry in [upgradeCatalog]: a name, a line of
/// flavour, and a function that nudges live state. Nothing else to wire.
class UpgradeSpec {
  const UpgradeSpec({
    required this.id,
    required this.name,
    required this.blurb,
    required this.apply,
    this.tag = 'PATCH',
    this.maxStacks = 99,
    this.available,
  });

  final String id;
  final String name;

  /// One readable line, shown on the card.
  final String blurb;

  /// Mutates the running game. Called once when the card is picked.
  final void Function(RogueAgentsGame game) apply;

  /// Short category chip on the card.
  final String tag;

  /// How many times this may be taken in one run.
  final int maxStacks;

  /// Extra condition on top of [maxStacks], e.g. "only if you own a cannon".
  final bool Function(RogueAgentsGame game)? available;
}

/// The upgrade pool. Stage 8 fills this out; keep each entry one small change.
const upgradeCatalog = <UpgradeSpec>[
  UpgradeSpec(
    id: 'throughput',
    name: 'Increase Throughput',
    blurb: 'Every weapon fires 18% faster.',
    tag: 'SCALING',
    apply: _throughput,
  ),
  UpgradeSpec(
    id: 'payload',
    name: 'Heavier Payload',
    blurb: 'Every weapon deals 25% more damage.',
    tag: 'SCALING',
    apply: _payload,
  ),
  UpgradeSpec(
    id: 'fanout',
    name: 'Request Fan-Out',
    blurb: 'Each weapon fires one extra packet per volley.',
    tag: 'TOPOLOGY',
    maxStacks: 4,
    apply: _fanout,
  ),
  UpgradeSpec(
    id: 'zero_copy',
    name: 'Zero-Copy Routing',
    blurb: 'Packets pass through one more agent before being consumed.',
    tag: 'TOPOLOGY',
    maxStacks: 3,
    apply: _zeroCopy,
  ),
  UpgradeSpec(
    id: 'autoscale',
    name: 'Autoscale Core',
    blurb: 'The control plane moves 15% faster.',
    tag: 'RUNTIME',
    maxStacks: 5,
    apply: _autoscale,
  ),
  UpgradeSpec(
    id: 'gc_sweep',
    name: 'Garbage Collection',
    blurb: 'Compute tokens are pulled in from 40% further out.',
    tag: 'RUNTIME',
    maxStacks: 4,
    apply: _gcSweep,
  ),
  UpgradeSpec(
    id: 'hot_patch',
    name: 'Hot Patch',
    blurb: 'Restore 35 integrity, right now.',
    tag: 'REPAIR',
    apply: _hotPatch,
  ),
];

UpgradeSpec upgradeSpec(String id) =>
    upgradeCatalog.firstWhere((spec) => spec.id == id);

void _throughput(RogueAgentsGame game) {
  for (final weapon in game.weapons) {
    weapon.cooldownMultiplier *= 0.82;
  }
  game.weaponCooldownMultiplier *= 0.82;
}

void _payload(RogueAgentsGame game) {
  for (final weapon in game.weapons) {
    weapon.damageMultiplier *= 1.25;
  }
  game.weaponDamageMultiplier *= 1.25;
}

void _fanout(RogueAgentsGame game) {
  for (final weapon in game.weapons) {
    weapon.extraProjectiles += 1;
  }
  game.weaponExtraProjectiles += 1;
}

void _zeroCopy(RogueAgentsGame game) {
  for (final weapon in game.weapons) {
    weapon.extraPierce += 1;
  }
  game.weaponExtraPierce += 1;
}

void _autoscale(RogueAgentsGame game) => game.playerSpeedMultiplier *= 1.15;

void _gcSweep(RogueAgentsGame game) => game.magnetRadius *= 1.4;

void _hotPatch(RogueAgentsGame game) => game.repairPlayer(35);
