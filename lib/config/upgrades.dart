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
    this.weight = 10,
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

  /// Relative odds of appearing in a draft. 10 is common, 3 is rare.
  final int weight;

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
  UpgradeSpec(
    id: 'speculative_exec',
    name: 'Speculative Execution',
    blurb: 'Packets have a 12% chance to crit for double damage.',
    tag: 'SCALING',
    maxStacks: 5,
    weight: 7,
    apply: _speculativeExec,
  ),
  UpgradeSpec(
    id: 'tail_latency',
    name: 'Tail Latency Fix',
    blurb: 'Packets fly 30% faster and reach 20% further.',
    tag: 'TOPOLOGY',
    maxStacks: 3,
    apply: _tailLatency,
  ),
  UpgradeSpec(
    id: 'self_healing',
    name: 'Self-Healing Mesh',
    blurb: 'Regenerate 1.2 integrity per second, forever.',
    tag: 'REPAIR',
    maxStacks: 4,
    weight: 7,
    apply: _selfHealing,
  ),
  UpgradeSpec(
    id: 'capacity',
    name: 'Provision Capacity',
    blurb: 'Maximum integrity +30, and repair that much now.',
    tag: 'REPAIR',
    maxStacks: 4,
    apply: _capacity,
  ),
  UpgradeSpec(
    id: 'hardening',
    name: 'Kernel Hardening',
    blurb: 'Take 18% less damage from every breach.',
    tag: 'RUNTIME',
    maxStacks: 4,
    weight: 7,
    apply: _hardening,
  ),
  UpgradeSpec(
    id: 'token_arbitrage',
    name: 'Token Arbitrage',
    blurb: 'Every compute token is worth 50% more.',
    tag: 'ECONOMY',
    maxStacks: 3,
    weight: 6,
    apply: _tokenArbitrage,
  ),
  UpgradeSpec(
    id: 'cold_start',
    name: 'Eliminate Cold Starts',
    blurb: 'Weapons fire 30% faster, but each packet hits 10% softer.',
    tag: 'TRADE-OFF',
    maxStacks: 3,
    weight: 6,
    apply: _coldStart,
  ),
  UpgradeSpec(
    id: 'root_access',
    name: 'Root Access',
    blurb: 'Crits deal 3.5x instead of 2x. Needs a crit chance first.',
    tag: 'SCALING',
    maxStacks: 1,
    weight: 3,
    available: _hasCrit,
    apply: _rootAccess,
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

void _speculativeExec(RogueAgentsGame game) {
  // Additive, so stacking it is predictable: 12%, 24%, 36%...
  game.critChance = (game.critChance + 0.12).clamp(0.0, 1.0);
}

void _tailLatency(RogueAgentsGame game) {
  game.projectileSpeedMultiplier *= 1.3;
  game.weaponRangeMultiplier *= 1.2;
}

void _selfHealing(RogueAgentsGame game) => game.regenPerSecond += 1.2;

void _capacity(RogueAgentsGame game) {
  game.maxIntegrity += 30;
  game.repairPlayer(30);
}

void _hardening(RogueAgentsGame game) =>
    game.damageTakenMultiplier *= 0.82;

void _tokenArbitrage(RogueAgentsGame game) =>
    game.tokenValueMultiplier *= 1.5;

void _coldStart(RogueAgentsGame game) {
  for (final weapon in game.weapons) {
    weapon.cooldownMultiplier *= 0.7;
    weapon.damageMultiplier *= 0.9;
  }
  game.weaponCooldownMultiplier *= 0.7;
  game.weaponDamageMultiplier *= 0.9;
}

void _rootAccess(RogueAgentsGame game) => game.critMultiplier = 3.5;

bool _hasCrit(RogueAgentsGame game) => game.critChance > 0;
