# Rogue Agents: staged build

## Building For
I'm building a game live on YouTube with a co-host. The audience is a mix of experienced engineers and non-technical founders. I have 25 years of software experience, but I have never used Flutter, Dart, or Flame, and I have never written game logic. Viewers will watch the game take shape stage by stage.

## Reason
The point of the session is to show what it looks like to build with AI in unfamiliar territory, where I can't rely on experience to judge your decisions. So when you make a meaningful technical choice, tell me what you chose, what the main alternative was, and why, in two or three plain sentences. Skip this for routine code.

## Intended Experience
Rogue Agents is a survivors-style game. The player is the "control plane," a lone defender in the middle of an arena. Rogue AI agents spawn at the edges of the screen and move toward the player. The player's defenses fire automatically at the nearest agent. Destroyed agents drop collectibles. Collecting enough triggers a level-up, where the game pauses and the player picks one of three upgrades. Pressure builds as more and tougher agents appear. Really play into the malicious bots attacking the control plane theme with fun jargon and relevant concepts. 

Controls: support both keyboard (WASD and arrow keys) and mouse. When movement keys are held, keyboard controls movement. When no keys are held, the player moves toward the mouse cursor.

How a run ends is your call. Propose two or three options in the plan and recommend one.

Make it easy to add new agent types, weapons, and upgrades during the stream, since viewers will suggest them. Keep their stats in a simple config so each new one is a small, readable change.

The game runs in Chrome. Size it to look good in a 1280x720 stream window, with UI text large enough to read on a viewer's screen.

## Examples
Visual direction for placeholders: dark, near-black teal background (#031212), the player in bright aqua (#20b1b3), agents as boxy shapes with a single red eye (#bc2222), projectiles in aqua. I've also attached some visual inspiration.

## Fences
- Use Flutter for web with the Flame game engine. Flutter is already installed. Check the current stable Flame version on pub.dev and write code for that version's API, since older tutorials use APIs that have changed.
- Don't add packages beyond Flame without asking me first.
- No backend, accounts, network calls, ads, or analytics.
- Keep earlier stages working. Don't rewrite previous work unless a stage requires it, and tell me when it does.
- Make a git commit at the end of every stage with a clear message, so we can roll back on stream if something breaks.

## Art assets
All art will be pixel art generated separately by another tool. Until an asset exists, draw a simple shape in its place. The game must run with any combination of assets present or missing, so load each one with a fallback instead of crashing.

Keep a file called ASSETS.md in the project root. For every asset the game uses, list:
- File name and path
- Pixel dimensions
- Number of animation frames and layout (single image or horizontal strip)
- Whether it needs a transparent background
- A prompt I can hand to an image generator
- Status: placeholder or provided

Render pixel art without smoothing so it stays crisp when scaled up. Update ASSETS.md whenever a stage adds a new asset.

## How we'll work: stages
Stage 0 is planning only. Write no game code yet. Give me:
1. A proposed list of stages. Each stage should take roughly 2 to 5 minutes and end with something new and visible on screen. The whole build should fit in about an hour, leaving time for viewer suggestions.
2. Your run-ending options and recommendation.
3. The initial ASSETS.md contents.
4. Any decisions you need from me.

Then stop and wait for my go-ahead.

At the end of every stage after that:
1. Make sure the game runs in Chrome.
2. Tell me in a few sentences what changed and what to look for on screen.
3. List any meaningful technical decisions you made, as described under Reason.
4. Note any assets added to ASSETS.md.
5. Commit.
6. Stop and wait for me to say "go" before starting the next stage.

If something doesn't work, say so plainly rather than moving on.