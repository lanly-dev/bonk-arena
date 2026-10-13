# BONK! — 3D arena brawler (BAPBAP-like)

Built in Armory3D (Blender 4.5 + Armory SDK 26.02), exported to HTML5.

## The formula (from BAPBAP)
- 4 fighters in an arena: you + 3 bots (no multiplayer in v1)
- Shrinking danger zone — outside it you take damage over time
- Fast skill-shot combat, everything dodgeable — dash has i-frames
- Last one standing wins the round
- Between rounds: draft 1 of 3 random powers, builds stack across rounds
- First to 3 round wins takes the match

## Camera & controls
- 3D arena, camera angled top-down (BAPBAP readability, true 3D depth)
- WASD / arrows: move | Mouse: aim | Click or Space: fire | Shift or Right-click: dash
- Touch: left-half virtual stick to move, right-half tap to fire at touch point, swipe to dash (v1: keyboard+mouse first, touch if time)

## Combat
- Fighters: capsule body + team color ring, HP 100
- Fire: projectile speed 18 u/s, damage 12, small knockback, cooldown 0.45s
- Dash: 6u burst, 0.25s i-frames, 2.2s cooldown
- Projectiles are dodgeable spheres with trails; hit = particles + hit-stop (60ms) + sound

## The zone
- Circle arena radius 22u. Zone starts at r=22, shrinks in 3 phases (to r=6)
- Phase timing: 20s calm → 15s shrink → 12s calm → 12s shrink → 10s calm → final shrink
- Outside zone: 8 HP/s, ticking faster each phase (+4/phase)
- Zone rendered as a glowing ring wall + darkened outside ground

## Power draft (pick 1 of 3, stacks across rounds)
1. Rapid Fire — +35% fire rate
2. Big Bullets — +60% damage & size
3. Swift Boots — +20% move speed
4. Long Dash — +50% dash range, −25% cooldown
5. Vampire — heal 20% of damage dealt
6. Thorns — reflect 30% of damage taken
7. Multishot — +1 projectile per shot (spread)
8. Heavy Body — +50 max HP, knockback resist
9. Blitz — dash damages enemies you pass through
10. Regen — +4 HP/s

Bots draft too (random pick, weighted by their personality).

## Bot AI
State machine, ticked at 10Hz with per-bot reaction delay:
- ENGAGE: nearest living enemy in 25u → keep 8–14u distance, strafe orbit, fire with
  lead prediction + inaccuracy scaled by difficulty
- DODGE: if a projectile will intersect within 0.35s and random < dodgeSkill → dash perpendicular
- FLEE: HP < 30% or outside zone → run to zone center / nearest safe point, fire backwards
- Personalities: Aggro (close range, more fire), Sniper (keeps distance, accurate), Coward (flees early, fast)

## Rounds & match flow
1. Countdown 3-2-1-GO → fight
2. Last fighter standing (or timeout → lowest HP% wins) takes the round
3. Draft screen: 3 random powers, click to pick (bots auto-pick)
4. Next round: arena resets, builds kept
5. First to 3 round wins → victory screen, rematch button

## HUD
- HP bar + power icons above each fighter (3D), screen-space HP bar for player
- Top: round number, round wins (pips), zone timer + next-shrink warning
- Draft overlay, countdown, kill feed ("YOU bonked Sniper-Bot!")

## Tech notes (Armory)
- Traits (Haxe): `Player`, `Bot`, `Fighter` (shared health/damage/dash), `Projectile`,
  `Zone`, `Game` (round/match state machine), `DraftUI`, `HUD`, `Audio` (synth SFX via Kha)
- Movement: kinematic (manual circle collision), no Bullet physics — reliable headless
- Ground: single plane + grid shader-ish material; arena props: a few low-poly pillars (cover)
- Render path: Forward, one directional light + hemisphere; HTML5-friendly poly counts

## Out of scope for v1
Real multiplayer, more arenas, character select, sound beyond synth SFX, mobile touch tuning.
