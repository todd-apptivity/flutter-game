import 'package:flame_test/flame_test.dart';
import 'package:flutter_game/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWithGame<MyGame>('player spawns centered', MyGame.new, (game) async {
    await game.ready();

    final player = game.children.whereType<Player>().single;
    expect(player.position, game.size / 2);
  });
}
