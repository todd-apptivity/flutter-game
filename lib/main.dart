import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: MyGame()));
}

class MyGame extends FlameGame with TapCallbacks {
  @override
  Color backgroundColor() => const Color(0xFF14151A);

  @override
  Future<void> onLoad() async {
    add(Player());
  }

  @override
  void onTapDown(TapDownEvent event) {
    final player = children.whereType<Player>().first;
    player.target = event.localPosition;
  }
}

class Player extends PositionComponent with HasGameReference<MyGame> {
  Player() : super(size: Vector2.all(48), anchor: Anchor.center);

  static const speed = 300.0;
  final _paint = Paint()..color = const Color(0xFF4CC2FF);

  Vector2? target;

  @override
  Future<void> onLoad() async {
    position = game.size / 2;
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
