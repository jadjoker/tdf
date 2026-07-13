# tdf — Movement Sandbox Bible

> Single source of truth. Update after every meaningful decision.
> This project is a **feel-first sandbox**: the goal is to make the swarm movement
> feel as good as possible. Gameplay is deliberately parked (see bottom).

---

## Recent Changes

| Date | Change |
|------|--------|
| Dec 2025 | Prototype built: player movement, follower collection, force-follow physics (ported from Python prototype), idle orbit ring, soft collisions |
| Jul 2026 | Promoted to main focus — this movement is the favorite across all projects |
| Jul 2026 | Direction set: **stay a sandbox, polish the feel**. (A shepherd-tower-defense concept was drafted and parked — see Parked Ideas.) |
| Jul 2026 | Feel pass #1: comet-tail follow targets, angular orbit slot assignment (no more cross-ring churn), smoothed mode switching with engage delay, ring breathing, per-unit stat variation |

---

## The Sacred Mechanic

The follower system in `scripts/phase_1.gd`. Two modes, switched by measured player speed:

- **Follow (moving):** force-based — units accelerate toward a target
  (`strength`), velocity damped by `friction`, capped at `max_speed`.
  Creates the surging, liquid trail.
- **Orbit (idle):** units take evenly spaced slots on a rotating ring around the player;
  velocities lerp-steered so transitions stay smooth.
- **Soft separation:** O(n²) pairwise overlap push with NaN guard keeps the blob
  from collapsing into a point.

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

## File Structure

```
towerdefense/
├── project.godot            — 4.4, WASD input map, main scene = main.tscn
├── PROJECT_BIBLE.md         — this file
├── main.tscn                — root (Main → Phase1 instance)
├── assets/                  — follower_circle_placeholder.png
├── scenes/
│   ├── Phase1.tscn          — sandbox orchestrator (follower_count=100, collision_push=0.5)
│   ├── Player.tscn          — CharacterBody2D + Camera2D, group "player", speed 500
│   └── FollowerUnit.tscn    — Area2D pickup (strength 3000, max_speed 1500, radius 10)
├── scripts/
│   ├── main.gd              — empty stub
│   ├── player.gd            — WASD move_and_slide
│   ├── followerunit.gd      — pickup logic, per-unit physics params + variation
│   └── phase_1.gd           — THE movement system (sacred)
└── git_helper.py / .bat     — custom git convenience tooling
```

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
- **Spatial hashing** — only needed if unit counts push past ~300 (O(n²) separation).
- **Sandbox HUD** — on-screen sliders/keys to tune knobs live without the Inspector.

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
