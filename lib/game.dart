import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class MyGame extends FlameGame with TapCallbacks {
  @override
  Color backgroundColor() => const Color(0xFF14151A);

  @override
  Future<void> onLoad() async {
    add(Player());
  }

  Player get player => children.whereType<Player>().first;

  /// Where the agent starts and returns to. Sits below the landing copy so it
  /// never covers the headline on first paint.
  Vector2 get spawnPoint => Vector2(size.x / 2, size.y * 0.72);

  @override
  void onTapDown(TapDownEvent event) {
    moveTo(event.localPosition);
  }

  /// Sends the agent toward [point]. Shared by real taps and the dev API.
  void moveTo(Vector2 point) {
    player.target = point;
  }

  /// Returns the agent to its spawn point and clears its target.
  void reset() {
    player
      ..position = spawnPoint
      ..target = null;
  }
}

class Player extends PositionComponent with HasGameReference<MyGame> {
  Player() : super(size: Vector2.all(48), anchor: Anchor.center);

  static const speed = 300.0;
  final _paint = Paint()..color = const Color(0xFF4CC2FF);

  Vector2? target;

  @override
  Future<void> onLoad() async {
    position = game.spawnPoint;
  }

  @override
  void update(double dt) {
    final target = this.target;
    if (target == null) return;

    final delta = target - position;
    if (delta.length < speed * dt) {
      position = target;
      this.target = null;
      return;
    }
    position += delta.normalized() * speed * dt;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10)),
      _paint,
    );
  }
}
