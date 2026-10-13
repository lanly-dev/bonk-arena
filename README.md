# BONK ARENA

A 3D arena brawler built with Armory3D (Blender-integrated game engine).
You vs 3 bots. Last one standing takes the round — first to 3 round wins
takes the match. Between rounds, draft 1 of 3 stackable powers.

Inspired by the *formula* of party arena battlers (shrinking zone,
dodgeable projectiles, dashing, power drafts) — all art and code here is
original.

## Play it

Open `index.html` in the `html5/` folder. It runs entirely in the browser —
no install, no server needed. Double-click it, or serve the folder:

    python3 -m http.server 8000
    # then open http://localhost:8000

## Controls

**Desktop**
- Move: WASD / arrow keys
- Aim: mouse
- Fire: hold left click
- Dash (brief invulnerability): right click or Shift
- Draft pick: click a card, or press 1 / 2 / 3

**Touch (phones/tablets)**
- One finger: move toward finger, aim and auto-fire at it
- Double-tap: dash toward aim
- Draft: tap a card

## The rules

- 4 fighters spawn around a circular arena with 5 cover pillars.
- A glowing zone shrinks over the round; standing outside it burns you.
- Projectiles can be dodged. Dashing gives i-frames.
- Kill feed, round score, and your health bar are on screen.
- After each round: pick 1 of 3 powers. They stack across rounds.
  10 powers exist: Rapid Fire, Big Rounds, Heavy Hitter, Blitz Dash,
  Vampire, Thick Skin, Speed Boots, Thorns, Regen, Multishot.
- Bots have personalities: Aggro, Sniper, and Ninja (dodges projectiles).

## Project layout

- `bonk.blend` — the Blender scene (arena, fighters, camera, lights)
- `make_game.py` — regenerates the scene and exports the HTML5 build
- `Sources/arm/` — all game code (Haxe traits)
- `build_bonk/html5/` — the exported playable build

## Rebuilding

Needs Blender 4.5 LTS and the Armory SDK (26.02):

    ./blender --background --python make_game.py

This regenerates `bonk.blend` from scratch, compiles the Haxe traits, and
exports a fresh HTML5 build to `build_bonk/html5/`.

Have fun. Don't get zoned.
