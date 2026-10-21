import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter_game/config/agents.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/game/injection.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';
import 'package:flutter_game/util/sprite_loader.dart';

/// A rogue agent heading for the control plane.
class Agent extends PositionComponent with HasGameReference<RogueAgentsGame> {
  Agent({required this.spec, required Vector2 position})
      : super(
          position: position,
          size: spec.renderSize,
          anchor: Anchor.center,
          priority: 5,
        );

  final AgentSpec spec;

  late double hp = spec.hp;

  /// Seconds of hit-flash left.
  double _flash = 0;

  /// Collision radius, slightly inside the art so corners do not clip.
  double get hitRadius => size.x * 0.42;

  /// Applies [amount] damage, flashing white and dying at zero.
  void takeDamage(double amount, {bool crit = false}) {
    if (isRemoving) return;
    hp -= amount;
    _flash = GameConfig.hitFlashDuration;
    game.onAgentHit(this, amount, crit: crit);
    if (hp <= 0) die();
  }

  /// Removes the agent and tells the game to count it.
  void die() {
    if (isRemoving) return;
    removeFromParent();
    game.onAgentKilled(this);
  }

  SpriteAnimationTicker? _ticker;
  final _spritePaint = pixelPaint();

  /// Drives the placeholder's leg shuffle and the swarm weave.
  double _t = 0;

  /// Per-agent weave offset, so a pack does not move in lockstep.
  final double _weavePhase = math.Random().nextDouble() * math.pi * 2;

  /// Seconds until this agent may attack again. Staggered on spawn so a group
  /// of injectors does not volley in unison.
  late double _attackCooldown =
      spec.attackCooldown * (0.3 + math.Random().nextDouble() * 0.7);

  late final _bodyPaint = Paint()..color = spec.color;
  late final _trimPaint = Paint()
    ..color = spec.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  late final _eyePaint = Paint()..color = spec.eyeColor;
  late final _eyeGlowPaint = Paint()
    ..color = spec.eyeColor.withValues(alpha: 0.35);

  @override
  Future<void> onLoad() async {
    final path = spec.spritePath;
    if (path == null) return;
    final animation = await tryLoadStrip(
      path,
      frames: spec.spriteFrames,
      frameSize: Vector2.all(spec.frameSize),
      stepTime: spec.spriteStepTime,
    );
    _ticker = animation?.createTicker();
  }

  @override
  void update(double dt) {
    _t += dt;
    _flash = (_flash - dt).clamp(0, GameConfig.hitFlashDuration);
    _ticker?.update(dt);

    switch (spec.behavior) {
      case AgentBehavior.chase:
        _chase(dt);
      case AgentBehavior.swarm:
        _swarm(dt);
      case AgentBehavior.ranged:
        _standOff(dt);
    }
  }

  void _chase(double dt) {
    final delta = game.player.position - position;
    if (delta.length2 == 0) return;
    position += delta.normalized() * spec.speed * dt;
  }

  /// Chase with a sideways weave, so a pack spreads into a cloud instead of
  /// stacking into a single sprite.
  void _swarm(double dt) {
    final delta = game.player.position - position;
    if (delta.length2 == 0) return;

    final forward = delta.normalized();
    final sideways = Vector2(-forward.y, forward.x) *
        math.sin(_t * 6 + _weavePhase) *
        0.55;
    position += (forward + sideways).normalized() * spec.speed * dt;
  }

  /// Close to [AgentSpec.preferredRange], hold there, and fire on a cooldown.
  void _standOff(double dt) {
    final delta = game.player.position - position;
    final distance = delta.length;
    if (distance == 0) return;

    final direction = delta.normalized();
    // Inside a dead band it holds position, so it does not jitter in and out.
    if (distance > spec.preferredRange * 1.1) {
      position += direction * spec.speed * dt;
    } else if (distance < spec.preferredRange * 0.8) {
      position -= direction * spec.speed * 0.8 * dt;
    }

    _attackCooldown -= dt;
    if (_attackCooldown <= 0 && spec.isRanged) {
      _attackCooldown = spec.attackCooldown;
      fire(direction);
    }
  }

  /// Lobs one payload along [direction]. Public so tests can trigger it.
  void fire(Vector2 direction) {
    game.world.add(
      Injection(
        spec: spec,
        position: position.clone(),
        direction: direction.normalized(),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final frame = _ticker?.getSprite();
    if (frame != null) {
      frame.render(canvas, size: size, overridePaint: _spritePaint);
    } else {
      _renderPlaceholder(canvas);
    }
    if (_flash > 0) _renderFlash(canvas);
  }

  /// A white wash over the whole sprite, fading out — reads as a hit with or
  /// without art present.
  void _renderFlash(Canvas canvas) {
    final strength = _flash / GameConfig.hitFlashDuration;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.1, size.y * 0.12, size.x * 0.8, size.y * 0.72),
        Radius.circular(size.x * 0.12),
      ),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7 * strength),
    );
  }

  /// Boxy chassis with one red eye that looks at the control plane.
  void _renderPlaceholder(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    // Legs shuffle so the thing reads as walking even without art.
    final shuffle = math.sin(_t * 9) * w * 0.06;

    final legPaint = _bodyPaint;
    canvas.drawRect(Rect.fromLTWH(w * 0.18 + shuffle, h * 0.8, w * 0.18, h * 0.2), legPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.64 - shuffle, h * 0.8, w * 0.18, h * 0.2), legPaint);

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, h * 0.12, w * 0.8, h * 0.72),
      Radius.circular(w * 0.12),
    );
    canvas
      ..drawRRect(body, _bodyPaint)
      ..drawRRect(body.deflate(1), _trimPaint);

    // Eye tracks the player, so a swarm visibly stares you down.
    final toPlayer = game.isMounted
        ? (game.player.position - position)
        : Vector2(0, 1);
    final gaze = toPlayer.length2 == 0
        ? Vector2.zero()
        : toPlayer.normalized() * (w * 0.06);
    final eye = Offset(w / 2 + gaze.x, h * 0.46 + gaze.y);
    canvas
      ..drawCircle(eye, w * 0.22, _eyeGlowPaint)
      ..drawCircle(eye, w * 0.13, _eyePaint);
  }
}
