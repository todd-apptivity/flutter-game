import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_game/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWithGame<MyGame>('player spawns at the spawn point', MyGame.new, (
    game,
  ) async {
    await game.ready();

    final player = game.children.whereType<Player>().single;
    expect(player.position, game.spawnPoint);
  });

  testWithGame<MyGame>('moveTo sets the player target', MyGame.new, (
    game,
  ) async {
    await game.ready();

    game.moveTo(Vector2(10, 20));
    expect(game.player.target, Vector2(10, 20));
  });

  testWithGame<MyGame>('reset recentres and clears the target', MyGame.new, (
    game,
  ) async {
    await game.ready();

    game.player.position = Vector2(5, 5);
    game.moveTo(Vector2(10, 20));
    game.reset();

    expect(game.player.position, game.spawnPoint);
    expect(game.player.target, isNull);
  });
}
