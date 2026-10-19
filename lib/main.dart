import 'package:flutter/material.dart';
import 'package:flutter_game/game.dart';
import 'package:flutter_game/game_api.dart';
import 'package:flutter_game/landing_page.dart';

void main() {
  final game = MyGame();
  installGameApi(game);

  runApp(
    MaterialApp(
      title: 'Rogue Agent',
      debugShowCheckedModeBanner: false,
      home: LandingPage(game: game),
    ),
  );
}
