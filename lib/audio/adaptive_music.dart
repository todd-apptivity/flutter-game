import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'techno_score.dart';
import 'techno_synth.dart';

/// Owns only this soundtrack's source; never stops other game audio globally.
/// Audio is initialized on a real input gesture to respect browser autoplay.
class AdaptiveMusic extends ChangeNotifier {
  TechnoSynth? _synth;
  AudioSource? _source;
  SoundHandle? _handle;
  Timer? _timer;
  Future<void>? _starting;
  bool _disposed = false;
  bool _paused = false;
  bool _alive = true;
  double _pressure = 0;
  bool enabled = true;
  bool started = false;
  String? error;

  double get bpm => _synth?.bpm ?? 118;
  double get targetBpm => 118 + _pressure * 36;
  double get renderedSeconds =>
      _synth == null ? 0 : _synth!.renderedFrames / _synth!.sampleRate;
  bool get suspended => _paused || !_alive || !enabled;
  int get bufferedBytes =>
      _source == null ? 0 : SoLoud.instance.getBufferSize(_source!);

  void updateDanger({required double healthFraction, required int enemies}) {
    _pressure = musicPressure(healthFraction: healthFraction, enemies: enemies);
    _synth?.setPressure(_pressure);
    final alive = healthFraction > 0;
    if (alive != _alive) {
      _alive = alive;
      _syncPause();
    }
  }

  Future<void> unlock() {
    if (_disposed || !enabled || started || error != null) {
      return Future.value();
    }
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    try {
      final engine = SoLoud.instance;
      if (!engine.isInitialized) await engine.init(sampleRate: 44100);
      if (_disposed) return;
      _synth = TechnoSynth()..setPressure(_pressure);
      _source = engine.setBufferStream(
        maxBufferSizeDuration: const Duration(seconds: 2),
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0.10,
        sampleRate: _synth!.sampleRate,
        channels: Channels.stereo,
        format: BufferType.f32le,
      );
      // A short bounded look-ahead cushions rendering stalls without making
      // danger changes lag by a whole musical phrase.
      _fillBuffer(force: true);
      _handle = engine.play(_source!, volume: 0.58, paused: suspended);
      if (!engine.getIsValidVoiceHandle(_handle!)) {
        throw StateError('Audio device did not start');
      }
      started = true;
      _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
        try {
          _fillBuffer();
        } catch (e) {
          _fail(e);
        }
      });
      notifyListeners();
    } catch (e) {
      _fail(e);
    }
  }

  void _fillBuffer({bool force = false}) {
    if (_disposed || (!force && suspended)) return;
    final synth = _synth!, source = _source!, engine = SoLoud.instance;
    final chunkFrames = synth.sampleRate ~/ 10;
    final targetBytes = (synth.sampleRate * 0.30).round() * 2 * 4;
    // At most three chunks, even after a long tab suspension.
    for (var i = 0; i < 3 && engine.getBufferSize(source) < targetBytes; i++) {
      final pcm = synth.render(chunkFrames);
      engine.addAudioDataStream(source, pcm.buffer.asUint8List());
    }
  }

  Future<void> toggle() async {
    if (_disposed) return;
    if (error != null) {
      error = null;
      enabled = true;
    } else {
      enabled = !enabled;
    }
    _syncPause();
    notifyListeners();
    if (enabled) await unlock();
  }

  void setPaused(bool value) {
    if (_disposed || value == _paused) return;
    _paused = value;
    _syncPause();
  }

  void _syncPause() {
    if (_handle == null) return;
    try {
      SoLoud.instance.setPause(_handle!, suspended);
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object failure) {
    if (_disposed) return;
    error = 'Music unavailable — tap to retry';
    debugPrint('[music] $failure');
    _release();
    notifyListeners();
  }

  void _release() {
    _timer?.cancel();
    _timer = null;
    final source = _source;
    _source = null;
    _handle = null;
    started = false;
    if (source != null) {
      unawaited(
        SoLoud.instance.disposeSource(source).catchError((Object error) {
          debugPrint('[music] cleanup: $error');
        }),
      );
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _release();
    super.dispose();
  }
}
