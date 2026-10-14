# BONK ARENA — 3D arena brawler (BAPBAP-like, original)

Built in Armory3D (Blender 4.5 + Armory SDK 26.02), exported to HTML5.

## The formula (from BAPBAP's broad design, all characters/powers original)
- 4 fighters in an arena: you + 3 bots (no multiplayer)
- Pick a character: each has a unique kit — stat modifiers + a special ability on cooldown
- Knockback is the core mechanic: heavy hits launch fighters, ring-outs kill
- Shrinking danger zone — outside it you take damage over time
- Fast skill-shot combat, everything dodgeable — dash has i-frames
- Last one standing wins the round
- Between rounds: draft 1 of 3 random powers, builds stack across rounds
- First to 3 round wins takes the match

## Characters (original)
1. **Bonk Boy** (blue) — melee brawler. Special: **Ground Slam** (8s) — AoE damage + radial knockback
2. **Captain Wobble** (green) — tanky gunner, 140 HP. Special: **Shockwave** (10s) — radial bullet burst
3. **Dame Dash** (purple) — fragile speedster, 80 HP. Special: **Blink Strike** (7s) — teleport with i-frames, strikes on arrival
4. **Wumbo** (orange) — heavy hitter, 150 HP. Special: **Grow** (14s) — giant form 6s (+damage, +knockback)

Bots get random unique kits each match.

## Camera & controls
- 3D arena, camera angled top-down
- Desktop: WASD/arrows move | mouse aim | hold click fire | **Space/E or BONK button: melee** | **Q or button: special** | Shift/right-click: dash
- Touch: one finger = move/aim/fire | double-tap = dash | on-screen BONK + special buttons

## Combat
- Fire: projectile speed 18 u/s, damage 12, knockback, cooldown 0.45s
- Melee bonk: short range frontal arc, 22 damage, HUGE knockback (0.75s cooldown)
- Knockback stacks and decays; flying bodies (speed > 10) ignore the arena clamp
- **Ring-out**: knocked past r=26.5 → eliminated, kill credit to whoever hit you last
- Dash: 6u burst, i-frames, charge-based (1 base, +1 per Second Dash power)
- Hit-stop + camera shake on melee/special connects

## The zone
- Arena radius 24 (wall), ring-out at 26.5. Zone starts at r=22, shrinks in 3 phases (to r=6)
- Phase timing: 20s calm → 15s shrink → 12s calm → 12s shrink → 10s calm → final shrink
- Outside zone: 8 HP/s, ticking faster each phase
- Sudden death after 25s overtime → highest HP% wins the round

## Power draft (pick 1 of 3, stacks across rounds — 18 total)
Damage: Rapid Fire, Big Bullets, Multishot, Rage (more damage when hurt)
Survivability: Heavy Body, Regen, Vampire, Thorns, Anchor (+HP, knock resist), Second Wind (cheat death 1/round)
Mobility: Swift Boots, Long Dash, Second Dash (+1 dash charge)
Chaos: Blitz (dash damages), Giant (size/damage/knockback), Bonk Aura (melee up), Shrapnel (kills explode), Heavy Hits (+knockback)

Bots draft too (weighted: damage/knockback first).

## Bot AI
Think tick ~8Hz with reaction delay:
- ENGAGE: keep preferred range, strafe orbit, fire with lead prediction
- MELEE: bonk when in range; fire special by kit (slam when close, shockwave at mid, blink to engage, grow when brawling)
- DODGE: projectile intercept prediction → dash perpendicular
- FLEE: HP < 30% → disengage; always respect zone + arena edge (ring-outs are real)
- Personalities: Aggro / Sniper / Ninja (reaction stats), crossed with random kits

## Rounds & match flow
1. Character select → countdown 3-2-1-GO → fight
2. Last fighter standing (or sudden-death timeout → highest HP%) takes the round
3. Draft screen: 3 random powers, click/tap/1-3 to pick (bots auto-pick)
4. Next round: positions reset, builds kept
5. First to 3 round wins → victory screen → rematch (back to character select)

## HUD
- Kill feed, round number + win pips, zone timer
- Player: HP bar, character name, special cooldown bar, power icons, BONK/special buttons

## Tech notes (Armory)
- Traits (Haxe): `Game` (state machine, select/draft/HUD), `Fighter` (health/damage/knockback/melee/specials),
  `Player` (desktop + real-touch input via kha.input.Surface), `Bot`, `Projectile`, `Zone`,
  `CharKit` (character defs), `Powers`/`PowerDef`, `CameraRig`
- Kinematic movement (manual circle collision), no Bullet physics — reliable headless
- Touch done right: iron's `Input.getSurface()` is aliased to Mouse, so touch uses `kha.input.Surface` directly

## Out of scope
Real multiplayer, more arenas, sound beyond synth SFX.
