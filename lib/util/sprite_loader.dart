import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Pixel art must never be smoothed, so every sprite we draw uses this paint.
Paint pixelPaint() => Paint()..filterQuality = FilterQuality.none;

/// Loads an image from assets/images, returning null instead of throwing when
/// the file is missing. Art arrives asset-by-asset during the stream, so every
/// caller draws a shape when it gets null back.
///
/// We read the bytes ourselves rather than calling `Flame.images.load`, because
/// that cache stores the *failed* future and rethrows it to every later
/// listener as an unhandled error. Decoded images are still handed to the cache
/// so a second request for the same file is free.
Future<ui.Image?> tryLoadImage(String path) async {
  if (Flame.images.containsKey(path)) return Flame.images.fromCache(path);
  try {
    final data = await rootBundle.load('assets/images/$path');
    final image = await decodeImageFromList(data.buffer.asUint8List());
    Flame.images.add(path, image);
    return image;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[assets] missing "$path" — drawing placeholder. ($e)');
    }
    return null;
  }
}

/// Single-frame sprite, or null when the file is not there yet.
Future<Sprite?> tryLoadSprite(String path) async {
  final image = await tryLoadImage(path);
  return image == null ? null : Sprite(image);
}

/// Same contract for a horizontal animation strip of [frames] frames.
Future<SpriteAnimation?> tryLoadStrip(
  String path, {
  required int frames,
  required Vector2 frameSize,
  required double stepTime,
  bool loop = true,
}) async {
  final image = await tryLoadImage(path);
  if (image == null) return null;
  return SpriteAnimation.fromFrameData(
    image,
    SpriteAnimationData.sequenced(
      amount: frames,
      stepTime: stepTime,
      textureSize: frameSize,
      loop: loop,
    ),
  );
}
