import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_game/game/rogue_agents_game.dart';
import 'package:flutter_game/game_api.dart';

void main() {
  final game = RogueAgentsGame();
  installGameApi(game);

  runApp(
    MaterialApp(
      title: 'Rogue Agents',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: GameWidget(game: game),
      ),
    ),
  );
}
