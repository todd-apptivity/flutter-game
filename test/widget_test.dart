import 'package:flame_test/flame_test.dart';
import 'package:flutter_game/config/game_config.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Needed so the asset bundle exists: the loaders expect a missing-file
  // failure, not a missing-binding failure.
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithGame<RogueAgentsGame>(
    'player spawns in the centre of the design rect',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      expect(game.player.position, GameConfig.designSize / 2);
    },
  );

  testWithGame<RogueAgentsGame>(
    'arena is inset from the design rect by the margin',
    RogueAgentsGame.new,
    (game) async {
      await game.ready();

      expect(game.arena.bounds.left, GameConfig.arenaMargin);
      expect(
        game.arena.bounds.right,
        GameConfig.designWidth - GameConfig.arenaMargin,
      );
    },
  );
}
