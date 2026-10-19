import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_game/game.dart';

/// Set by `--dart-define=BUILD_REF=...` in CI so a deployed page can be
/// checked against the commit it came from.
const buildRef = String.fromEnvironment('BUILD_REF', defaultValue: 'local');

class LandingPage extends StatelessWidget {
  const LandingPage({required this.game, super.key});

  final MyGame game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14151A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: game),
          // Taps belong to the game, not the copy sitting on top of it.
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Text(
                    'ROGUE AGENT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFF2F4F8),
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(width: 72, height: 2, color: const Color(0xFF4CC2FF)),
                  const SizedBox(height: 20),
                  const Text(
                    'Coming soon',
                    style: TextStyle(
                      color: Color(0xFF9AA3B2),
                      fontSize: 18,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'tap anywhere to move the agent',
                    style: TextStyle(color: Color(0xFF5A6474), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'build $buildRef',
                    style: const TextStyle(
                      color: Color(0xFF3A4150),
                      fontSize: 11,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
