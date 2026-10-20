# ASSETS.md — Rogue Agents

Pixel art only. Every asset is loaded with a fallback (`lib/util/sprite_loader.dart`):
if the file is absent the game logs one line and draws a shape instead, so any
combination of present/missing assets runs.

- Drop files in `assets/images/` — paths below are relative to that folder.
- Rendering uses `FilterQuality.none`, so art stays crisp when scaled.
- Sprites are authored small and drawn at **2x** (`GameConfig.pixelScale`).
- Palette: background `#031212` · player `#20b1b3` · agent eye `#bc2222` ·
  projectile `#20b1b3` · agent chassis `#1c2224`

| Asset | Path | Size (px) | Frames | Transparent | Stage | Status |
|---|---|---|---|---|---|---|
| Control plane core | `assets/images/player_core.png` | 32x32 | 4 (h-strip, 128x32) | yes | 1 | placeholder |
| Arena floor tile | `assets/images/floor_tile.png` | 32x32 | 1 | no | 1 | placeholder |
| Scraper agent | `assets/images/agent_scraper.png` | 24x24 | 2 (h-strip, 48x24) | yes | 3 | placeholder |
| Packet projectile | `assets/images/proj_packet.png` | 8x8 | 1 | yes | 4 | placeholder |

Assets below are planned by later stages and not loaded yet; they are listed so
art can be generated ahead of time.

| Asset | Path | Size (px) | Frames | Transparent | Stage | Status |
|---|---|---|---|---|---|---|
| Token pickup | `assets/images/pickup_token.png` | 12x12 | 4 (h-strip, 48x12) | yes | 6 | placeholder |
| Crawler agent | `assets/images/agent_crawler.png` | 40x40 | 2 (h-strip, 80x40) | yes | 9 | placeholder |
| Swarm-let agent | `assets/images/agent_swarmlet.png` | 12x12 | 2 (h-strip, 24x12) | yes | 9 | placeholder |
| Injector agent | `assets/images/agent_injector.png` | 28x28 | 2 (h-strip, 56x28) | yes | 9 | placeholder |

## Generator prompts

**player_core.png** — "Pixel art sprite sheet, 4 frames horizontal, each 32x32, transparent
background. A hovering hexagonal server core in bright aqua #20b1b3 with a glowing white center
ring and three small orbiting data nodes. Frames show the ring pulsing and the nodes rotating.
Clean 1px outline, limited palette, dark teal shadows, no anti-aliasing, no background."

**floor_tile.png** — "Pixel art seamless tile, 32x32, opaque. Near-black teal #031212
circuit-board floor with faint darker teal grid lines and a few tiny dim aqua trace dots. Very low
contrast, tiles seamlessly, no anti-aliasing."

**agent_scraper.png** — "Pixel art sprite sheet, 2 frames horizontal, each 24x24, transparent
background. A small boxy malicious robot, dark charcoal body with grey panel lines, one large
glowing red cyclops eye #bc2222 centered. Two stubby legs; frames alternate the leg step. Menacing,
crisp 1px outline, no anti-aliasing."

**agent_crawler.png** — "Pixel art sprite sheet, 2 frames horizontal, each 40x40, transparent
background. A heavy armored crawler bot, thick dark steel plating with rivets, wide tank treads,
single red slit eye #bc2222. Bulky and slow-looking. Frames alternate tread position."

**agent_swarmlet.png** — "Pixel art sprite sheet, 2 frames horizontal, each 12x12, transparent
background. A tiny gnat-like drone bot, dark body, one red pixel eye #bc2222, two blurred rotor
wings. Frames alternate rotor blur."

**agent_injector.png** — "Pixel art sprite sheet, 2 frames horizontal, each 28x28, transparent
background. A floating boxy bot with a forward-facing emitter barrel, dark purple-charcoal body,
red eye #bc2222, small antenna. Frames alternate a charging glow in the barrel."

**proj_packet.png** — "Pixel art, single 8x8 frame, transparent background. A small glowing aqua
#20b1b3 data packet: bright square core with a faint white highlight and a 1px darker aqua outline."

**pickup_token.png** — "Pixel art sprite sheet, 4 frames horizontal, each 12x12, transparent
background. A spinning aqua #20b1b3 hexagonal token coin with a white highlight, shown rotating
through four stages (wide, narrow, wide, narrow). Crisp, no anti-aliasing."
