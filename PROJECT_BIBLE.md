# MURMURATION — Project Bible

> Working folder/repo: `towerdefense` / `jadjoker/tdf` (historical names — the game is **Murmuration**)

> Single source of truth. Update after every meaningful decision.
> Feel-first project: the swarm movement IS the game. Gameplay direction decided
> Jul 2026 — **momentum combat** (see Gameplay Direction) — with the standing rule
> that no mechanic may compromise the movement feel.

---

## Recent Changes

| Date | Change |
|------|--------|
| Dec 2025 | Prototype built: player movement, follower collection, force-follow physics (ported from Python prototype), idle orbit ring, soft collisions |
| Jul 2026 | Promoted to main focus — this movement is the favorite across all projects |
| Jul 2026 | Direction set: **stay a sandbox, polish the feel**. (A shepherd-tower-defense concept was drafted and parked — see Parked Ideas.) |
| Jul 2026 | Feel pass #1: comet-tail follow targets, angular orbit slot assignment (no more cross-ring churn), smoothed mode switching with engage delay, ring breathing, per-unit stat variation |
| Jul 2026 | Graphics pass #1 — **neon bloom look**: HDR 2D + glow WorldEnvironment, dark background with world grid, additive motion trails per unit, velocity squash-and-stretch, dim-stray → neon-mint-swarm color language, bright HDR player |
| Jul 2026 | Graphics pass #2 — **player ball rebuilt as vector**: pixelated placeholder sprite replaced with anti-aliased `_draw()` layers (HDR core, bright rim, off-center highlight, pulsing halo, velocity lean) in player.gd |
| Jul 2026 | Player squash & stretch upgraded to **damped-spring physics** with smooth axis chasing; fixed screen-space-scale bug in `draw_set_transform()` (deformation was pinned to screen X) |
| Jul 2026 | Graphics pass #3 — **collectables rebuilt as vector** with the same spring squash/stretch system as the player (per-unit randomized stiffness so wobbles desync); placeholder PNG no longer used anywhere |
| Jul 2026 | Perf pass A (lag at 100 collected units): spatial-hash separation with cached arrays, physics retired on collect, trails throttled to 30 Hz, debug prints removed, perf HUD added |
| Jul 2026 | Perf pass B (profiler data showed render side scaling ~8→19ms with swarm size): swarm bodies drawn by **one MultiMesh** (vector look baked to HDR texture at startup), all trails drawn by **one shared TrailRenderer**; per-unit canvas redraw eliminated. Spring/deform physics unchanged. |
| Jul 2026 | **Gameplay decided: momentum combat** ("crack the whip" + "the flock is your health bar" fused). **G1 built** — velocity-scaled contact damage on dumb chaser enemies, hit flash/knockback/death burst, trickle spawner, kill counter |
| Jul 2026 | **Steam Deck pass** (first hardware playtest found keyboard-only menu controls): all overlays button-driven with controller focus nav (pause RESUME/RESTART/MENU, game-over FLY AGAIN/MENU with 0.7s arm delay, upgrade cards with explicit wraparound focus neighbors), B backs out, hotkeys kept for desktop. Linux export pipeline live (`export_presets.cfg`, templates installed, single-file build in `dist/`) |
| Jul 2026 | **Graphics pass #4 — full UI pass** (screenshot-verified via `tools/screenshot_tool.gd`): shared neon style library (`ui_style.gd` — HDR accent borders that bloom on hover/focus), upgrade cards rebuilt with per-upgrade accent colors + procedural vector icons (`upgrade_icon.gd`) + staggered rise-in tween, styled pause/game-over panels, HUD outlines, vignette shader on every screen, menu restyle. Fixes found by LOOKING: center-anchor ordering bug (~110px off), stray palette (gray bubbles → dim mint embers), player core HDR clipping, flock now spawns around the player |
| Jul 2026 | **Physics-juice pass**: enemies physically real (shoved by units, ring grinds/carries them, solid player, no enemy stacking), jelly impact deformation on enemies, death shockwaves ripple the flock, hit-stop micro-freeze, trauma camera shake, whip-crack sparks, combo chains, kills drop recruitable strays (cap 250) |

---

## The Sacred Mechanic

The follower system in `scripts/phase_1.gd`. Two modes, switched by measured player speed:

- **Follow (moving):** force-based — units accelerate toward a target
  (`strength`), velocity damped by `friction`, capped at `max_speed`.
  Creates the surging, liquid trail.
- **Orbit (idle):** units take evenly spaced slots on a rotating ring around the player;
  velocities lerp-steered so transitions stay smooth.
- **Soft separation:** pairwise overlap push with NaN guard keeps the blob from
  collapsing into a point (spatial-hashed since perf pass A — same behavior, O(n·k)).

Any change must preserve this feel. Tune via exports, not hardcoded numbers.

---

## Feel Knobs Reference

All tunable in the Inspector (Phase1 node unless noted). Feel pass #1 knobs marked ★.

| Knob | Default | What it does |
|---|---|---|
| `friction` | 0.90 | Velocity damping per physics frame. Lower = more slide/overshoot. |
| `collision_push` | 0.5 (scene) | Separation strength. Higher = stiffer blob. |
| `idle_speed_threshold` | 20 px/s | Below this (smoothed) speed the player counts as idle. |
| `orbit_speed` | 1.5 rad/s | Ring rotation speed. |
| `orbit_base_radius` | 64 | Ring radius floor. |
| `orbit_radius_per_unit` | 2 | Ring growth per unit — big swarms get big rings. |
| ★ `trail_distance` | 30 | Follow target sits this far *behind* the player's motion — comet tail, not dot-pile. |
| ★ `follow_spread` | 26 | Per-unit random offset radius around the follow target — teardrop volume. |
| ★ `speed_smoothing` | 12 | EMA rate for measured player speed. Higher = snappier mode switching. |
| ★ `orbit_engage_delay` | 0.25 s | Must be idle this long before the ring forms — quick taps don't flash the ring. |
| ★ `orbit_breathe_amount` | 4 px | Idle ring radius pulse amplitude. 0 disables. |
| ★ `orbit_breathe_speed` | 1.2 rad/s | Pulse speed. |
| ★ `variation` (FollowerUnit) | 0.10 | ±10% per-unit randomization of `strength`/`max_speed` — organic, non-uniform motion. |
| `strength` (FollowerUnit) | 3000 (scene) | Acceleration toward target. |
| `max_speed` (FollowerUnit) | 1500 (scene) | Unit speed cap. |
| `follower_count` | 100 (scene) | Units spawned in the sandbox. |

## Feel Pass #1 — what changed and why

1. **Comet-tail follow.** All units used to target the player's exact position, so the
   swarm collapsed into a bunched dot fighting the separation solver. Now the shared
   target sits `trail_distance` behind the player's motion direction, and each unit adds
   its own persistent random offset (uniform-disc, scaled by `follow_spread`). The swarm
   reads as a flowing teardrop.
2. **Angular orbit slots.** Slots were assigned by array index, so units could be handed
   a slot on the far side of the ring and cut straight through the middle. Slots are now
   assigned by sorting units by their current angle around the player whenever orbit mode
   begins (or the swarm grows) — everyone slides to the *nearest* gap. This was the
   biggest single feel win.
3. **Smoothed mode switching.** Raw per-frame speed was noisy, causing follow/orbit
   flicker at the threshold. Speed is now exponentially smoothed (`speed_smoothing`), and
   the ring only engages after `orbit_engage_delay` of continuous idleness.
4. **Ring breathing.** The idle ring radius pulses gently (`orbit_breathe_amount`) so a
   parked swarm still feels alive.
5. **Per-unit variation.** Each unit randomizes its `strength` and `max_speed` by
   ±`variation` on spawn — uniform robotic motion becomes organic.

---

## Graphics Pass #1 — the neon bloom look

Principle: **no art assets, just light**. Everything below is engine settings + code.

| Piece | Where | Notes |
|---|---|---|
| HDR 2D + dark clear color | `project.godot` `[rendering]` | `viewport/hdr_2d=true` is required for 2D glow; near-black navy background |
| Glow | WorldEnvironment in Phase1.tscn | intensity 1.0, strength 1.05, bloom 0.05, blend Screen, threshold 1.1 — only HDR colors (>1.0 channels) bloom |
| World grid | `scripts/grid_background.gd` | static world-space grid (cell 120, extent ±3000, z_index −10) so speed is readable |
| Color language | `followerunit.gd` constants | `COLOR_STRAY` dim gray-blue (waiting) → `COLOR_SWARM` neon mint `(0.55, 2.4, 1.3)` HDR (glows); player is HDR magenta-white |
| Motion trails | `followerunit.gd` `_make_trail()` | per-unit Line2D, 12 points, world-space (`top_level`), gradient fade, **additive blend** — trails stack where the swarm flows |
| Unit bodies (pass #3) | strays: `followerunit.gd` `_draw()`; swarm: baked texture on `SwarmBodies` MultiMesh | vector circles at `radius` (10 via scene — matches separation spacing exactly): body + off-center highlight + rim. Stray palette drawn per-node (static); swarm palette baked into the shared HDR texture (perf pass B) |
| Unit squash & stretch | `followerunit.gd` `_process()` | same damped-spring system as the player (`STRETCH_MAX` 0.8, stiffness 170 ±15% per unit, damping 11, axis chase 16) — springs toward speed target, wobbles on stops, desynced across the swarm |
| Player ball (pass #2) | `player.gd` `_draw()` constants | no sprite — anti-aliased vector circles: HDR core (radius 24), crisp rim, off-center highlight, 3-layer pulsing halo. Crisp at any zoom. |
| Spring squash & stretch | `player.gd` `_process()` | stretch is a **damped spring** (`STRETCH_STIFFNESS` 140, `STRETCH_DAMPING` 12, underdamped) toward the speed target — launches overshoot, hard stops squash below neutral and jiggle back. Deformation axis (`_axis_angle`) chases the motion direction at `AXIS_TURN_RATE` and is held on stop. Stretch clamped 0.6–1.6. **Gotcha:** `draw_set_transform()` scales in screen space (post-rotation) — deformation must use `draw_set_transform_matrix()` with `Transform2D(rot, scale, skew, pos)` or the squash pins to the screen X axis. |

Tuning: bloom intensity/threshold on the WorldEnvironment node; trail length/alpha and
stretch amount are constants at the top of `followerunit.gd`. To kill the whole look,
disable glow on the WorldEnvironment and set `STRETCH_MAX` to 0 / skip `_make_trail()`.

### UI look (graphics pass #4)

| Piece | Where | Notes |
|---|---|---|
| Style library | `scripts/ui_style.gd` | StyleBoxFlat recipes: dark translucent panels, thin accent borders that switch to HDR on hover/focus (bloom = affordance). `MINT`/`GOLD`/`VIOLET` shared accents. `centered_panel()` = anchors-center + grow-both. |
| Upgrade cards | `phase_1._show_upgrade_choice` | per-upgrade accent color from `UPGRADE_POOL`, procedural icon (`upgrade_icon.gd`), name/desc/key-hint stack, staggered rise+fade tween (pause-immune) |
| Vignette | `ui_style.add_vignette()` | tiny canvas_item shader, radial darkening; on gameplay (0.34), menus (0.4), overlays (0.5+) |
| HUD | phase_1 `_build_perf_hud` | outlined game HUD top-left; dev perf readout bottom-left, small + dim |
| Screenshot review loop | `tools/screenshot_tool.gd` | `godot --script tools/screenshot_tool.gd -- <scene> <out.png> [upgrade\|gameover\|pause]` — capture any screen, LOOK at it, iterate. **Center-anchor gotcha:** set a Control's `size` BEFORE `set_anchors_and_offsets_preset(PRESET_CENTER, KEEP_SIZE)` or it centers the pre-size min-width (~110px drift). |

---

## File Structure

```
towerdefense/
├── project.godot            — 4.4, input map (WASD + arrows), main scene = main.tscn
│                              movement also via hold-LMB/touch pointer steering (player.gd)
├── PROJECT_BIBLE.md         — this file
├── main.tscn                — root (Main → Phase1 instance)
├── assets/                  — follower_circle_placeholder.png (unused since graphics pass #3 — everything is vector-drawn)
├── scenes/
│   ├── Phase1.tscn          — sandbox orchestrator (follower_count=100, collision_push=0.5)
│   ├── Player.tscn          — CharacterBody2D + Camera2D, group "player", speed 500
│   └── FollowerUnit.tscn    — Area2D pickup (strength 3000, max_speed 1500, radius 10)
├── scripts/
│   ├── main.gd              — empty stub
│   ├── player.gd            — WASD move_and_slide
│   ├── followerunit.gd      — pickup logic, per-unit params/variation, spring deform, palette
│   ├── grid_background.gd   — world-space grid backdrop
│   ├── trail_renderer.gd    — ALL swarm trails in one canvas item (perf pass B)
│   ├── perf_logger.gd       — buffered per-frame CSV profiler (toggle on Phase1)
│   ├── enemy.gd             — enemy base + chaser: velocity damage intake, grind, jelly, juice
│   ├── tail_biter.gd        — G2 straggler hunter: stalk→coil→lunge, eats units, digests
│   ├── heavy_tank.gd        — G4 wall: plows the flock, grind-only kill, triple loot
│   ├── interceptor.gd       — G4 line-cutter: dives at predicted player position
│   ├── sfx_player.gd        — pooled playback of the procedural SFX set
│   ├── pause_controller.gd  — always-on input shim: Esc pause, R/tap restart
│   ├── hit_burst.gd         — one-shot expanding ring (death burst / spark / gulp)
│   └── phase_1.gd           — THE movement system (sacred) + renderers + enemy spawner
└── git_helper.py / .bat     — custom git convenience tooling
```

---

## Roguelite Loop (v0.4.0, Jul 2026 — "I want it to be a roguelike")

Run → death → **Embers** banked (score/10 + Sovereign bounties) → spend in
**The Roost** (main-menu meta shop, `meta_progress.gd`, save.cfg [meta]) →
stronger next run. Perks (3 levels each): Head Start (begin with 10 units
flocked/lvl), Sharp Flock (+10% damage/lvl), Swift Blood (+5% unit speed/lvl),
Rich Air (+25 strays/lvl).

**The Sovereign** (`sovereign.gd`, extends tank): descends at 2:30 then every
~2:10 — 1400 HP (+20%/min), radius 46, near-immovable, plows everything.
Bounty: 8 strays + 50 Embers + fanfare. Center-screen announce system
(`_announce`) heralds arrivals and bounties.

---

## Flock Verbs (added Jul 2026 — playtest: "travel time is boring")

Two active commands fill the dead air between moving and ring-forming, both
temporary modifiers on the sacred follow physics (never replacements):

- **Sling** — hold RMB / RB: flock coils tight around the player
  (strength ×2.5, spread ×0.25 — visible anticipation), release: every unit
  launched at `SLING_IMPULSE_MIN..MAX` (1100–2000 by charge, 0.6s to full)
  toward cursor (mouse) or facing (pad); follow forces drop to 12% for
  `SLING_BALLISTIC_TIME` (0.45s) so the spear flies. Speed-is-damage does the rest.
- **Pulse** — Space / B, 4s cooldown: radial `PULSE_UNIT_KICK` (750) to own
  units + `PULSE_ENEMY_KICK` shove and 10 chip damage to enemies within 260.
  Defensive burst; counters biter lunges; springs reel the bloom back in.

Charging or ballistic flight suppresses ring formation (the flock is busy).
Pause screen lists the controls.

---

## Gameplay Direction — Momentum Combat (decided Jul 2026)

**Fantasy:** you lead a murmuration — anything that touches it gets flayed by the current.
Your body language is the entire combat kit: no buttons, no abilities. Aim by driving.

**The load-bearing rule:** damage = unit contact scaled by unit *velocity*.
- Parked/slow swarm (< `min_damage_speed` 200 px/s) → harmless
- Orbit ring (~400 px/s tangential) → slow grinder for close defense
- Sprint-by lash / whip-crack on sharp turns (up to 1500 px/s) → shreds
- Tail-end units genuinely swing fastest in turns (real whip dynamics, free from the physics)

**The second pillar (G2+):** enemies don't hurt *you* — they eat your **stragglers**.
The flock is health, weapon, and spectacle at once. Strays in the world are the
pickup economy. Defense and offense are the same verb: moving well.

### Gameplay Milestones
1. ✅ **G1 — the core question (Jul 2026):** velocity-scaled contact damage on dumb
   chaser enemies (`enemy.gd`, spawner in phase_1, kill counter). Tuning exports on
   Enemy: `min_damage_speed`, `speed_for_max`, `max_unit_dps`. Juice: hit flash,
   velocity knockback, expanding-ring death burst (`hit_burst.gd`).
   *Verdict pending playtest: is whip-cracking fun?*
1b. ✅ **G1.5 — physics-juice pass (Jul 2026):** enemies are physically real —
   units shove them (`_resolve_enemy_collisions` in phase_1: enemy takes 75% of
   overlap, units flex 25%, `GRIND_TRANSFER` carries them along the ring's spin),
   player is a solid body, enemies don't stack. Impact feedback: jelly deformation
   kick on enemies, death shockwave (`SHOCKWAVE_RADIUS/POWER`) blooms the flock,
   hit-stop (0.05s @ 5% time scale), trauma-based camera shake (shake = trauma²),
   whip-crack sparks (hits ≥0.7 frac), combo chains (`COMBO_WINDOW` 1.6s), kills
   drop a recruitable stray (`MAX_TOTAL_UNITS` 250).
2. ✅ **G2 — stakes (Jul 2026):** violet **tail-biters** (`tail_biter.gd` extends
   enemy.gd) ignore the player and hunt the straggler farthest from you; eating
   banishes the unit — a replacement stray respawns `stray_respawn_distance` (1200)
   away, so the flock is won back, not lost forever. **Lunge rework (playtest #1
   found stalkers could never catch the flock):** stalk 340 → coil `windup_time`
   0.35s (visible swell + pulsing threat line) → straight lunge at 950 px/s with
   direction locked at fire — a sharp turn dodges it. Bites the first unit touched
   mid-lunge. Fragile (60 HP), sluggish for `digest_time` (1.2s) after a bite.
   A violet threat line always marks its prey. Spawn mix
   `tail_biter_chance` (0.35) once flock ≥ 5. Losing the whole flock = game-over
   overlay with run stats (time, kills, peak flock, units lost); R or tap restarts.
   HUD shows Flock + Kills + combo.
3. ⬜ **G3 — economy:** finite strays per area, risky retrieval runs (partially
   covered: kills drop strays weighted by `stray_drop`, banished units respawn far)
4. ✅ **G4 — enemy variety (Jul 2026):** four-role roster, each with physics
   personality via base-class vars (`push_share`/`plow_kick`/`knock_resist`/`stray_drop`):
   - **Chaser** (ember) — dumb pressure toward you
   - **Tail-biter** (violet) — stalks stragglers, telegraphed 950px/s lunge
   - **Interceptor** (acid gold, 1 min) — dives at your PREDICTED position
     (`lead_time` 0.55s), cuts straight-line sprints, forces the carve
   - **Heavy tank** (bronze, 2 min) — 500 HP wall, `push_share` 0.08 +
     `plow_kick` 30 plows through the flock like bowling pins, 90% knock-resist
     (grind it down, don't whip it); drops 3 strays
5. ✅ **G5 — structure (Jul 2026):** difficulty curve (spawn interval shrinks
   ~35%/min to 1.2s floor, enemy cap 6→16, enemy HP +15%/min), **score**
   (+1/s survival, +10 × stray_drop × combo per kill, on HUD), best score/time
   persisted via ConfigFile to `user://save.cfg`, death screen shows Score/Best/BEST!
6. ✅ **G6 — audio (Jul 2026):** six procedural SFX generated from scratch by
   script (scratchpad `gen_sfx.py` → `assets/sfx/*.wav`, 100% original, ship-safe):
   collect (rising ping, pitch climbs with flock size), kill boom, whip snap
   (plays on spark-grade hits), gulp, lunge warning, gameover drone. Pooled
   playback in `sfx_player.gd` (8 players, ±6% pitch jitter, −8 dB).
   **Pause shell:** Esc pause overlay + R restart via `pause_controller.gd`
   (PROCESS_MODE_ALWAYS input shim so the tree stays cleanly pausable).

### Physics Toys Backlog (lean into what's cool)
- **Heavy tank enemy** — plows *through* the flock physically (reverse push share),
  scattering units like bowling pins; kill it by sustained grind, not whip-cracks
- **Gravity wells** — map features that bend the flock's flow (and enemies) around them;
  slingshot maneuvers for free speed = free damage
- **Bouncy arena walls** — elastic reflection so the whip can be banked off boundaries
- **Breakable obstacles** — crates/crystals that shatter into collectible shards with
  momentum inherited from the hit
- **Enemy corpses with momentum** — death burst throws debris shards along the killing
  unit's velocity vector
- **Tether mode** — hold a key to stiffen the swarm into an elastic net between
  you and a anchor point (physics rope of units)

### Parked (recorded, not the direction)
- Shepherd tower defense (base + waves — may return as G5+ structure)
- Comet courier / gauntlet levels (could be a bonus mode)

---

## Road to Steam (goal set Jul 2026: real commercial release)

**Goal:** ship a genuinely good, paid game on Steam. Solo dev, part-time,
scope-small-polish-hard (same principle as Swarm Director's bible).

### Positioning & market honesty
- **Genre shelf:** one-mechanic arcade action roguelite — sits near Vampire
  Survivors-likes, Nova Drift, Geometry Wars. Healthy niche, buyer expectation
  ~$4.99–$9.99, high tolerance for abstract visuals, LOW tolerance for thin content.
- **The hook (marketing = the game):** "lead a murmuration; your flock is your health
  bar AND your weapon." Every whip-crack kill is a 5-second clip. Short-form video
  (TikTok/Shorts/Twitter GIFs) is the primary channel — this game demos itself.
- **Honest math:** median indie games earn very little. What moves the needle:
  a free demo, Steam Next Fest, and wishlists (several thousand at launch for the
  algorithm to notice). Plan the demo as a first-class product, not an afterthought.
- **Name LOCKED (Jul 2026): MURMURATION.** "Murmur" was rejected after a Steam
  search check found an exact-title collision ([ MURMUR ], Oct 2025 horror game)
  plus two other murmur-titled games; "Murmuration" came back clean and names the
  core fantasy. TODO: grab itch.io page + domain + social handles.
- **Timeline commitment:** 6–12 months of development (stated Jul 2026) — v1.0 can
  be deep: full enemy roster, physics toys (gravity wells, tank), unlock track,
  maybe the courier-gauntlet as a bonus mode. Don't let scope eat the polish.

### Production milestones (v-numbers ship in this order)
- **v0.2 — a game exists:** G2 stakes (stragglers eaten, game over) + G3 economy +
  G4 enemy variety (chaser/interceptor/armored/tank) + G5 run structure
  (waves, score, difficulty curve, death screen with stats)
- **v0.3 — a run matters:** ✅ core built Jul 2026 — pick-3 upgrade choices on kill
  thresholds (8, +8+6/level): Pointier Flock (+20% dmg), Swift Current (+10% unit
  speed), Wider Net (+15% recruit reach), Magnet Heart (stray attraction, +150/stack),
  Patient Hunter (+0.5s combo), Bountiful Kills (+1 loot). Cards pause the run,
  keys 1/2/3 or click. **Build-defining trio added:** Burning Wake (flight path
  lingers as damaging ribbon — `wake_renderer.gd`), Warm Welcome (recruits detonate:
  damage + radial shove), Comet Core (the leader damages on contact above 250 px/s,
  scaling with speed). **Onboarding:** three do-to-dismiss prompts on first flights
  (`onboarding.gd`), gone forever after the first-ever kill (settings/onboarded).
  Still open: unlock track across runs, endless + timed modes
- **v0.4 — shippable shell:** ✅ mostly built Jul 2026 — audio (v0.2), main menu
  (`main_menu.gd`: procedural title screen with ambient decorative flock, best-run
  line, BEGIN/SETTINGS/QUIT with controller focus nav), settings (volume/fullscreen/
  vsync persisted to save.cfg [settings] via `game_settings.gd`, applied on boot),
  pause (Esc/Start) with R-restart and M-to-menu, gamepad (left stick movement,
  Start pause, A restart, focus-nav upgrade cards), 1280×720 canvas_items stretch
  (Steam Deck ready). Still open: rebindable keys (post-playtest)
- **v0.5 — DEMO build:** first 10 minutes, polished to death; this is the marketing
- **v1.0 — launch:** 3–5 hours of content depth, achievements, launch discount

### Steamworks logistics checklist
- [ ] Steamworks account + $100 app fee (recoupable after $1k revenue)
- [ ] Tax interview + bank info (needed before the page can go live)
- [ ] Store page: capsule art (the ONE paid-artist purchase worth making),
      6+ screenshots, 30s trailer cut from gameplay GIF moments
- [ ] Page live ASAP once v0.3 exists — wishlists accrue while you build
- [ ] Steam requires ~2 weeks "Coming Soon" minimum before launch; page and
      build each go through human review (days, not hours)
- [ ] Next Fest (one-time per game) timed for ~1–2 months pre-launch with the demo
- [ ] Price: $4.99 launch (raiseable later) or $6.99 if v1.0 content is deep
- **Legit-ness:** all code/art is original & procedural (no asset-pack or license
  risk); keep it that way or track licenses for any audio you bring in
  (freesound CC0 / paid packs with commercial rights only).

---

## Performance Strategy

**Budget:** 60 fps with a full swarm. Watch the perf HUD (top-left: FPS, frame ms,
physics ms, swarm count) — measure before optimizing further.

**Data collection:** `scripts/perf_logger.gd` (toggle: `perf_logging` export on Phase1,
default on) writes buffered per-frame CSVs to
`%APPDATA%\Godot\app_userdata\TowerDefense\perf_logs\` — columns: t_ms, units, fps,
process_ms, physics_ms, sim_us (follow/orbit section), sep_us (separation section),
slots_reassigned. Play a session, then analyze offline (percentiles + spike correlation).

### Phase A — done (Jul 2026), targets ~100–250 units
1. **Spatial-hash separation** — `resolve_collisions` buckets units into a grid
   (cell = max touch distance) and only tests same-cell + forward-neighbor pairs:
   ~4,950 pair checks at n=100 → a few hundred. Node state is read into packed local
   arrays once and written back only for moved units, because *cross-object property
   access is the dominant GDScript cost* — the O(n²) loop was doing ~30k of them per frame.
2. **Physics retirement on collect** — a collected unit's Area2D job is over; monitoring,
   monitorable, and both collision masks are zeroed so the broadphase stops tracking it.
3. **Trail throttling** — Line2D points recorded at 30 Hz with random per-unit phase,
   8 points (~0.27s). Halves tessellation cost, spreads it across frames.
4. **No prints in hot paths** — collect-burst `print()` calls caused visible hitches;
   the perf HUD replaces them.

### Phase B — built Jul 2026 (profiler data: render side scaled ~8→19ms over 0→100 units)
- ✅ **MultiMesh bodies**: collected units render via one `MultiMeshInstance2D`
  (`SwarmBodies` under Phase1) — single draw call, per-instance `Transform2D` carries
  position + spring deformation (`FollowerUnit.visual_transform()`). The vector look is
  baked once at startup into a 96px FORMAT_RGBAF texture (`_bake_unit_texture`) so HDR
  bloom survives. Strays still `_draw()` themselves — they're static, so it costs one
  draw ever. Units keep their spring `_process` (measured cheap) but never `queue_redraw`.
- ✅ **Shared TrailRenderer** (`scripts/trail_renderer.gd`): one node owns every trail's
  ring buffer and draws all of them with `draw_polyline_colors` in a single `_draw()` —
  replaces 100 Line2D nodes. Self-syncs with the `swarm_unit` group, 30 Hz staggered.

### Phase C — if it's ever needed
- Reuse the Phase A spatial grid for future neighbor queries (boids alignment, combat).
- If simulation math itself becomes the wall: C# or GDExtension for the integration
  loop — but profile first; current architecture should reach ~1,000 units.

---

## Feel Backlog (future passes — pick by taste, not order)

- **Player weight** — player.gd is instant start/stop; slight accel/decel would let the
  swarm's lag read even better against the player's motion.
- **Orbit hand-off** — when leaving orbit, units currently snap to follow; could inherit
  tangential velocity for a "sling" out of the ring.
- **Boids alignment term** — small neighbor-velocity matching in follow mode for flockier motion.
- **Speed-reactive spread** — widen `follow_spread` / `trail_distance` with player speed.
- **Visual trails** — per-unit ghosting or Line2D trails; would make the flow readable.
- **Controller input** — analog stick movement (feel test on gamepad).
- **Two-ring orbit** — big swarms split into inner/outer counter-rotating rings.
- **Sandbox HUD** — on-screen sliders/keys to tune knobs live without the Inspector
  (perf HUD already exists; this would add tuning).

---

## Parked Ideas (not the focus — recorded so they're not lost)

- **Shepherd tower defense** (chosen concept, July 2026, then parked): waves march at a
  base; you recruit strays and position the orbit ring as a mobile wall. The M1 draft
  (base + enemy scripts + wave spawner in phase_1) was written and then reverted —
  recoverable from session history / knowledge base if ever wanted.
- Alternative concepts considered: orbital arena survival (ring as whirling shield),
  swarm escort convoy.

---

## Technical Notes & Gotchas

- Units are **Area2D**, no physics bodies — all movement is manual position integration
  in `phase_1.gd`.
- Entity discovery is group-based (`"player"`, `"swarm_unit"`, `"prey"` unused).
- Exported values in **.tscn override script defaults** (Phase1 sets follower_count=100
  over the script's 10) — check the scene before assuming a script default is live.
- Godot binary: `C:\Users\smitt\Projects\godot\Godot_v4.4.1-stable_win64.exe`.
  Headless check: `Godot_v4.4.1-stable_win64_console.exe --headless --path . --quit`.
