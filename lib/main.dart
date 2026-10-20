import 'dart:async';

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
        body: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: (_) => unawaited(game.music.unlock()),
                child: GameWidget(game: game),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 12,
              child: SafeArea(
                child: ListenableBuilder(
                  listenable: game.music,
                  builder: (context, _) => IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip:
                        game.music.error ??
                        (game.music.enabled
                            ? 'Mute music (M)'
                            : 'Enable music (M)'),
                    onPressed: () => unawaited(game.music.toggle()),
                    color: const Color(0xFF7DB9BA),
                    iconSize: 20,
                    icon: Icon(
                      game.music.error != null
                          ? Icons.music_off
                          : game.music.enabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
