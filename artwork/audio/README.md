# Control Plane

Original eight-bar techno music for Rogue Agents: E-minor acid bass, a data-like
arpeggio, chord stabs, four-on-the-floor kick, clap, and metallic hats. No external
recordings or soundfonts are used. The instruments are synthesized from oscillators,
filtered noise, and envelopes.

## Listen

- `control_plane_demo.mp3`: compact listening preview.
- `control_plane_demo.wav`: lossless stereo preview, 22,050 Hz / 16-bit.
- `../../assets/audio/control_plane.mid`: editable Standard MIDI File, format 1,
  480 ticks per quarter note, four instrument tracks plus the tempo track.

The 36-second demo uses the actual game synthesizer:

| Time | Situation | Tempo |
|---|---|---|
| 0–12 s | Healthy, empty arena | 118 BPM |
| 12–24 s | Healthy, 20 enemies | Ramps to 136 BPM |
| 24–36 s | 20% health, 28 enemies | Ramps to 152.7 BPM |

## In-game behavior

Music starts after the first click/tap or keypress. Press **M** or use the speaker
button to mute/unmute. Pausing, opening an upgrade draft, hiding the app, or
reaching zero health suspends the music. Resuming preserves its musical position.

Enemy pressure grows from 0 to 1 over 0–40 live enemies. Health pressure starts
below 55% integrity and reaches 1 at 15%. These combine as
`1 - (1 - crowd) * (1 - healthDanger)`, producing a target of 118–154 BPM.
Tempo rises at up to 6 BPM per second and relaxes at 2.5 BPM per second. Extra
sixteenth-note hats, arpeggio notes and drum fills enter with increasing pressure.
All instruments share one sample clock; tempo never changes the pitch of a note.

The runtime uses the MIDI-note score in `lib/audio/techno_score.dart` and renders
through `lib/audio/techno_synth.dart`, streaming a bounded 0.3-second look-ahead to
SoLoud. Consumed audio is released, so long runs do not accumulate a recording.
The MIDI file is an export of the same score with all intensity layers enabled;
editing it in a DAW does not modify the runtime Dart score. General MIDI players
use their own instrument sounds, while the WAV/MP3 preserves our custom synth.

## Rebuild and verify

```sh
fvm dart run tool/render_music.dart
ffmpeg -y -i artwork/audio/control_plane_demo.wav -codec:a libmp3lame -b:a 128k artwork/audio/control_plane_demo.mp3
fvm flutter test
fvm flutter analyze
fvm flutter build web --release
node tool/check_music.mjs
```

SoLoud initialization for web follows its [official setup instructions](https://docs.page/alnitak/flutter_soloud_docs/get_started/setup).
The runtime bundles the engine locally and needs no external music service.
