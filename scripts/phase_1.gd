extends Node2D

@export var follower_count: int = 10
@export var spawn_area_size: Vector2 = Vector2(800, 600)

@export var friction: float = 0.90            # 0–1; lower = more slide, higher = more damped
@export var collision_push: float = 1.5       # how strongly units push apart when overlapping

# Orbit behavior (when player is idle)
@export var idle_speed_threshold: float = 20.0    # if player speed < this, we treat as "stopped"
@export var orbit_speed: float = 1.5              # radians per second (how fast the ring rotates)
@export var orbit_base_radius: float = 64.0       # base radius of the ring
@export var orbit_radius_per_unit: float = 2.0    # extra radius per unit, so big swarms get a bigger ring

# Feel pass #1 (see PROJECT_BIBLE.md "Feel Knobs Reference")
@export var trail_distance: float = 30.0      # follow target sits this far behind the player's motion
@export var follow_spread: float = 26.0       # per-unit offset radius around the follow target
@export var speed_smoothing: float = 12.0     # EMA rate for measured player speed (higher = snappier)
@export var orbit_engage_delay: float = 0.25  # continuous idle seconds required before the ring forms
@export var orbit_breathe_amount: float = 4.0 # idle ring radius pulse, px (0 disables)
@export var orbit_breathe_speed: float = 1.2  # pulse speed, rad/s

var follower_scene: PackedScene = preload("res://scenes/FollowerUnit.tscn")
const _FollowerScript = preload("res://scripts/followerunit.gd")

# Perf pass B: collected units are rendered by ONE MultiMesh (single draw call)
# instead of 100 self-redrawing canvas items. Must match FollowerUnit radius (scene: 10).
@export var unit_visual_radius: float = 10.0

var _unit_mm: MultiMeshInstance2D
var _trail_renderer: Node2D

var collected_count: int = 0

@onready var player: Node2D = $Player   # adjust this path if your Player node is elsewhere

var _prev_player_pos: Vector2 = Vector2.ZERO
var _has_prev_player_pos: bool = false
var _orbit_time: float = 0.0

var _smoothed_speed: float = 0.0
var _player_dir: Vector2 = Vector2.ZERO   # last meaningful movement direction
var _idle_time: float = 0.0
var _was_idle: bool = false
var _slot_count: int = -1                 # swarm size when orbit slots were last assigned
var _breathe_time: float = 0.0

var _perf_label: Label
var _perf_accum: float = 0.0

# Per-frame CSV logging for offline analysis (scripts/perf_logger.gd)
@export var perf_logging: bool = true
var _perf_logger: Node = null

# Gameplay G1 — momentum-combat prototype: a trickle of dumb chasers to
# whip-crack. Enemies only start once the first unit is collected.
@export var enemies_enabled: bool = true
@export var enemy_spawn_interval: float = 4.0
@export var max_enemies: int = 6
@export var enemy_spawn_distance: float = 900.0

var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
var tail_biter_scene: PackedScene = preload("res://scenes/TailBiter.tscn")
var tank_scene: PackedScene = preload("res://scenes/HeavyTank.tscn")
var interceptor_scene: PackedScene = preload("res://scenes/Interceptor.tscn")
var kills: int = 0
var _enemy_spawn_timer: float = 2.0
var _kills_label: Label

# G2 — stakes: tail-biters eat stragglers, eaten units respawn as strays
# at the map edge, and losing the whole flock ends the run
@export var tail_biter_chance: float = 0.35   # spawn mix once the flock is big enough
@export var stray_respawn_distance: float = 1200.0

var _has_collected: bool = false
var _game_over: bool = false
var _game_over_at_ms: int = 0
var _run_start_ms: int = 0
var _peak_swarm: int = 0
var units_lost: int = 0

# G5 — score + persistence
const SAVE_PATH := "user://save.cfg"
var score: int = 0
var best_score: int = 0
var best_time_s: int = 0
var _score_tick: float = 0.0

# v0.3 — pick-3 upgrade system: every kill threshold pauses the run and
# offers 3 of these (all stack; multiplicative where sensible)
const UIS = preload("res://scripts/ui_style.gd")
const TP = preload("res://scripts/theme_palette.gd")

const UPGRADE_POOL := [
	{"id": "damage", "name": "Pointier Flock", "desc": "+20% contact damage", "color": Color(2.2, 0.8, 0.4)},
	{"id": "speed", "name": "Swift Current", "desc": "Units fly 10% faster", "color": Color(0.5, 1.8, 2.4)},
	{"id": "net", "name": "Wider Net", "desc": "+15% recruit reach", "color": Color(0.55, 2.4, 1.3)},
	{"id": "magnet", "name": "Magnet Heart", "desc": "Strays drift toward you (+150 range)", "color": Color(1.8, 0.7, 2.2)},
	{"id": "combo", "name": "Patient Hunter", "desc": "+0.5s combo window", "color": Color(2.2, 1.8, 0.6)},
	{"id": "loot", "name": "Bountiful Kills", "desc": "Kills drop +1 extra stray", "color": Color(1.6, 2.2, 0.5)},
	# Build-defining picks — these change HOW you fly, not just numbers
	{"id": "wake", "name": "Burning Wake", "desc": "Your flight path lingers as a burning ribbon", "color": Color(2.4, 1.2, 0.3)},
	{"id": "welcome", "name": "Warm Welcome", "desc": "Recruits detonate a concussive greeting", "color": Color(0.9, 2.2, 0.7)},
	{"id": "comet", "name": "Comet Core", "desc": "YOU damage enemies on contact — at speed", "color": Color(1.9, 1.1, 2.4)},
]

var damage_mult: float = 1.0         # read by enemies each contact frame
var unit_speed_mult: float = 1.0
var magnet_radius: float = 0.0
var loot_bonus: int = 0
var combo_window: float = 1.6
var wake_level: int = 0              # Burning Wake stacks
var welcome_level: int = 0           # Warm Welcome stacks
var comet_level: int = 0             # Comet Core stacks
var upgrade_level: int = 0
var _kills_to_next: int = 8
var _upgrade_layer: CanvasLayer = null
var _upgrade_offer: Array = []
var _wake: Node2D = null

const WAKE_DPS := 30.0               # per stack, per burning point touched
const WAKE_RADIUS := 45.0
const COMET_DPS := 60.0              # per stack at full speed
const COMET_MIN_SPEED := 250.0

# Physics-juice pass: impact feedback systems
const SHOCKWAVE_RADIUS := 160.0      # death blast physically ripples the flock
const SHOCKWAVE_POWER := 900.0
const MAX_TOTAL_UNITS := 250         # cap on strays dropped by kills

var _cam: Camera2D
var _sfx: Node
var _pause_layer: CanvasLayer = null
var _trauma: float = 0.0             # camera shake energy, decays; shake = trauma²
var _combo: int = 0
var _combo_timer: float = 0.0
var _total_units: int = 0


func _ready() -> void:
	randomize()
	_run_start_ms = Time.get_ticks_msec()
	preload("res://scripts/game_settings.gd").apply_saved()
	TP.apply_saved()
	_apply_world_theme()
	_load_save()
	spawn_followers()
	_build_swarm_renderers()
	_build_perf_hud()
	_cam = player.get_node_or_null("Camera2D")
	_sfx = preload("res://scripts/sfx_player.gd").new()
	_sfx.name = "Sfx"
	add_child(_sfx)
	var pause_ctl := preload("res://scripts/pause_controller.gd").new()
	pause_ctl.name = "PauseController"
	add_child(pause_ctl)

	# First-flight onboarding, until the player lands their first kill ever
	var cfg := preload("res://scripts/game_settings.gd").load_all()
	if not cfg.get_value("settings", "onboarded", false):
		var ob := preload("res://scripts/onboarding.gd").new()
		ob.name = "Onboarding"
		add_child(ob)
	if perf_logging:
		_perf_logger = preload("res://scripts/perf_logger.gd").new()
		add_child(_perf_logger)


func _process(delta: float) -> void:
	# Runs at render rate (vs physics 60) so shake stays smooth at high refresh
	if _trauma > 0.0 and _cam != null:
		_trauma = maxf(_trauma - delta * 1.8, 0.0)
		var s: float = _trauma * _trauma
		_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 14.0 * s
	elif _cam != null and _cam.offset != Vector2.ZERO:
		_cam.offset = Vector2.ZERO

	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo = 0
			_update_kills_label()


func _build_swarm_renderers() -> void:
	_trail_renderer = preload("res://scripts/trail_renderer.gd").new()
	_trail_renderer.name = "TrailRenderer"
	add_child(_trail_renderer)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	var quad := QuadMesh.new()
	# The baked texture's body circle fills 82% of the quad (margin for rim + AA)
	var world_size: float = unit_visual_radius * 2.0 / 0.82
	quad.size = Vector2(world_size, world_size)
	mm.mesh = quad
	mm.instance_count = follower_count + 8   # headroom for scene-placed units
	mm.visible_instance_count = 0

	_unit_mm = MultiMeshInstance2D.new()
	_unit_mm.name = "SwarmBodies"
	_unit_mm.multimesh = mm
	_unit_mm.texture = _bake_unit_texture()
	add_child(_unit_mm)


func _bake_unit_texture(px: int = 96) -> ImageTexture:
	# Rasterize the unit's vector look ONCE at ~5x display size, in float format
	# so the HDR palette survives and blooms. One-time cost at startup.
	var img := Image.create(px, px, false, Image.FORMAT_RGBAF)
	var half: float = float(px) * 0.5
	var body_r: float = half * 0.82
	var aa: float = 2.0                       # anti-alias falloff in texture pixels
	var rim_w: float = body_r * 0.15
	var hi_center := Vector2(-body_r * 0.25, -body_r * 0.28)
	var hi_r: float = body_r * 0.42

	var body_c: Color = TP.P["swarm_body"]
	var rim_c: Color = TP.P["swarm_rim"]
	var hi_c: Color = TP.P["swarm_hi"]

	for y in range(px):
		for x in range(px):
			var p := Vector2(float(x) - half + 0.5, float(y) - half + 0.5)
			var d: float = p.length()
			var body_a: float = clampf((body_r - d) / aa, 0.0, 1.0)
			if body_a <= 0.0:
				continue   # image starts fully transparent
			var col := Color(body_c.r, body_c.g, body_c.b, 1.0)
			# Off-center highlight
			var hi_t: float = clampf((hi_r - (p - hi_center).length()) / (aa * 2.0), 0.0, 1.0) * hi_c.a
			col = col.lerp(Color(hi_c.r, hi_c.g, hi_c.b, 1.0), hi_t)
			# Bright rim at the edge
			var rim_t: float = clampf((d - (body_r - rim_w - aa)) / aa, 0.0, 1.0)
			col = col.lerp(Color(rim_c.r, rim_c.g, rim_c.b, 1.0), rim_t)
			col.a = body_a
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


func _apply_world_theme() -> void:
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment")
	if we != null and we.environment != null:
		TP.apply_environment(we.environment)
	var grid: Node = get_node_or_null("GridBackground")
	if grid != null:
		grid.refresh_theme()


func cycle_theme() -> void:
	# T key (desktop): flip through every aesthetic live, mid-run
	var theme_names: Array = TP.names()
	var i: int = theme_names.find(TP.current_name)
	TP.set_theme(theme_names[(i + 1) % theme_names.size()])
	refresh_theme_visuals()


func refresh_theme_visuals() -> void:
	_apply_world_theme()
	if _unit_mm != null:
		_unit_mm.texture = _bake_unit_texture()
	if _trail_renderer != null:
		_trail_renderer.rebuild_ramps()
	for s in get_tree().get_nodes_in_group("stray"):
		if is_instance_valid(s):
			s.queue_redraw()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e._apply_theme()


func _update_swarm_visuals(swarm_units: Array) -> void:
	var mm: MultiMesh = _unit_mm.multimesh
	var n: int = swarm_units.size()
	if mm.instance_count < n:
		mm.instance_count = n + 16
	mm.visible_instance_count = n
	for i in range(n):
		mm.set_instance_transform_2d(i, swarm_units[i].visual_transform())


func _build_perf_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Subtle vignette over the play field — depth without stealing attention
	UIS.add_vignette(layer, 0.34)

	# Game HUD: top-left, outlined for readability over the neon field
	_kills_label = Label.new()
	_kills_label.text = "Flock: 0   Kills: 0   Score: 0"
	_kills_label.position = Vector2(14.0, 10.0)
	_kills_label.add_theme_font_size_override("font_size", 18)
	_kills_label.modulate = Color(1.0, 0.75, 0.6)
	UIS.outline(_kills_label, 6)
	layer.add_child(_kills_label)

	# Dev perf readout: bottom-left, small and dim; hidden in release builds
	_perf_label = Label.new()
	_perf_label.add_theme_font_size_override("font_size", 11)
	_perf_label.modulate = Color(0.8, 0.9, 1.0, 0.45)
	_perf_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_perf_label.position += Vector2(10.0, -24.0)
	_perf_label.visible = OS.is_debug_build()
	layer.add_child(_perf_label)


func _update_perf_hud(delta: float) -> void:
	_perf_accum += delta
	if _perf_accum < 0.25:
		return
	_perf_accum = 0.0
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms: float = 1000.0 / max(fps, 1.0)
	var phys_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_perf_label.text = "FPS %d  |  frame %.1f ms  |  physics %.1f ms  |  swarm %d" % [int(fps), frame_ms, phys_ms, collected_count]


func spawn_followers() -> void:
	_total_units = follower_count
	# Centered on the player so the opening frame shows a field of strays
	var center: Vector2 = player.global_position if player != null else global_position
	for i in range(follower_count):
		var follower: Node2D = follower_scene.instantiate()
		add_child(follower)

		var offset := Vector2(
			randf_range(-spawn_area_size.x * 0.5, spawn_area_size.x * 0.5),
			randf_range(-spawn_area_size.y * 0.5, spawn_area_size.y * 0.5)
		)
		follower.global_position = center + offset


func _physics_process(delta: float) -> void:
	if _game_over:
		return

	_update_perf_hud(delta)

	if player == null:
		return

	var swarm_units: Array = get_tree().get_nodes_in_group("swarm_unit")
	if swarm_units.is_empty():
		if _has_collected:
			_trigger_game_over()
		return
	_has_collected = true
	_peak_swarm = maxi(_peak_swarm, swarm_units.size())

	var player_pos: Vector2 = player.global_position
	var player_speed: float = 0.0

	if _has_prev_player_pos:
		var frame_move: Vector2 = player_pos - _prev_player_pos
		# approximate speed in pixels/second
		player_speed = frame_move.length() / max(delta, 0.0001)
		if frame_move.length() > 0.5:
			_player_dir = frame_move.normalized()
	_prev_player_pos = player_pos
	_has_prev_player_pos = true

	# Smooth the noisy per-frame speed so mode switching doesn't flicker
	_smoothed_speed = lerpf(_smoothed_speed, player_speed, 1.0 - exp(-speed_smoothing * delta))

	# Ring only forms after a short continuous stillness (quick taps don't flash it)
	if _smoothed_speed < idle_speed_threshold:
		_idle_time += delta
	else:
		_idle_time = 0.0
	var is_idle: bool = _idle_time >= orbit_engage_delay

	var slots_reassigned := false
	var t_sim: int = Time.get_ticks_usec()

	if is_idle:
		# (Re)assign ring slots by current angle when orbit starts or the swarm changes size,
		# so every unit slides into its nearest gap instead of cutting across the ring
		if not _was_idle or swarm_units.size() != _slot_count:
			_assign_orbit_slots(swarm_units)
			slots_reassigned = true
		_update_orbit(swarm_units, delta)
	else:
		_update_swarm_follow(swarm_units, delta)
	_was_idle = is_idle

	var t_sep: int = Time.get_ticks_usec()

	# Soft collision resolution (keeps blob from overlapping too much)
	resolve_collisions(swarm_units)

	if _perf_logger != null:
		var t_end: int = Time.get_ticks_usec()
		_perf_logger.record(swarm_units.size(), t_sep - t_sim, t_end - t_sep, slots_reassigned)

	# Push position + spring deformation of every unit into the MultiMesh
	_update_swarm_visuals(swarm_units)

	_update_enemies(swarm_units, delta)

	# Magnet Heart: strays inside the radius drift to you on their own
	if magnet_radius > 0.0:
		for s in get_tree().get_nodes_in_group("stray"):
			if not is_instance_valid(s):
				continue
			var d: Vector2 = player.global_position - s.global_position
			var dist: float = d.length()
			if dist < magnet_radius and dist > 1.0:
				s.global_position += (d / dist) * 240.0 * delta

	# Survival score: +1/second while the flock lives
	_score_tick += delta
	if _score_tick >= 1.0:
		_score_tick -= 1.0
		score += 1
		_update_kills_label()

	# Track count for the HUD (print() here caused hitches during collect bursts)
	var new_count: int = swarm_units.size()
	if new_count != collected_count:
		if new_count > collected_count:
			# Recruit ping rises subtly with flock size
			play_sfx("collect", 1.0 + minf(float(new_count) * 0.004, 0.6))
		collected_count = new_count
		_update_kills_label()


func _update_enemies(swarm_units: Array, delta: float) -> void:
	if not enemies_enabled:
		return

	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	# G5 difficulty curve: spawns quicken and the cap grows as minutes pass
	var minutes: float = float(Time.get_ticks_msec() - _run_start_ms) / 60000.0
	var interval: float = maxf(enemy_spawn_interval / (1.0 + minutes * 0.35), 1.2)
	var cap: int = mini(max_enemies + int(minutes * 2.0), 16)

	if enemies.size() < cap:
		_enemy_spawn_timer -= delta
		if _enemy_spawn_timer <= 0.0:
			_enemy_spawn_timer = interval
			_spawn_enemy(minutes)

	# Burning Wake: the player's lingering path damages enemies crossing it
	if _wake != null and wake_level > 0:
		_wake.track(player.global_position, delta)

	for e in enemies:
		e.process_flock_contact(swarm_units, delta)

		if not is_instance_valid(e):
			continue

		if _wake != null and wake_level > 0:
			for p in _wake.points:
				if e.global_position.distance_to(p.pos) < WAKE_RADIUS:
					e.take_external_damage(WAKE_DPS * wake_level * delta)
					break

		# Comet Core: the leader itself is a weapon — at speed
		if comet_level > 0 and is_instance_valid(e):
			var pspeed: float = player.velocity.length()
			if pspeed > COMET_MIN_SPEED \
					and e.global_position.distance_to(player.global_position) < e.body_radius + 28.0:
				var frac: float = clampf(pspeed / 500.0, 0.0, 1.0)
				e.take_external_damage(COMET_DPS * comet_level * frac * delta)

	_resolve_enemy_collisions(swarm_units, enemies)


# Enemies are physically real: units shove them (the ring is a flexing wall
# that sweeps intruders along its rotation), the player is a solid body, and
# enemies can't stack inside each other. ≤6 enemies × 100 units — no grid needed.
const PLAYER_BODY_RADIUS := 26.0
const ENEMY_PUSH_SHARE := 0.75    # enemy takes most of the overlap; units flex a little
const GRIND_TRANSFER := 0.03      # fraction of unit velocity imparted per touching unit per frame

func _resolve_enemy_collisions(swarm_units: Array, enemies: Array) -> void:
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var e_pos: Vector2 = e.global_position
		var er: float = e.body_radius

		# vs swarm units — physical contact regardless of damage threshold
		for u in swarm_units:
			var d: Vector2 = e_pos - u.global_position
			var dist: float = d.length()
			var min_d: float = er + u.radius
			if dist < min_d and dist > 0.001:
				var nrm: Vector2 = d / dist
				var overlap: float = min_d - dist
				e_pos += nrm * overlap * e.push_share
				u.global_position -= nrm * overlap * (1.0 - e.push_share)
				# plowers (tank) hurl units aside like bowling pins
				if e.plow_kick > 0.0:
					u.vel -= nrm * overlap * e.plow_kick
				# grind: the ring's motion carries the enemy along
				e.apply_grind(u.vel * GRIND_TRANSFER)

		# vs player — solid body, enemy is fully expelled
		var dp: Vector2 = e_pos - player.global_position
		var pdist: float = dp.length()
		var pmin: float = er + PLAYER_BODY_RADIUS
		if pdist < pmin and pdist > 0.001:
			e_pos += (dp / pdist) * (pmin - pdist)

		e.global_position = e_pos

	# vs each other — no stacking into one super-blob
	for i in range(enemies.size()):
		for j in range(i + 1, enemies.size()):
			var a: Node2D = enemies[i]
			var b: Node2D = enemies[j]
			if not is_instance_valid(a) or not is_instance_valid(b):
				continue
			var d2: Vector2 = b.global_position - a.global_position
			var dist2: float = d2.length()
			var min2: float = a.body_radius + b.body_radius
			if dist2 < min2 and dist2 > 0.001:
				var push: Vector2 = (d2 / dist2) * (min2 - dist2) * 0.5
				a.global_position -= push
				b.global_position += push


func _spawn_enemy(minutes: float = 0.0) -> void:
	var e: Node2D = _pick_enemy_scene(minutes).instantiate()
	add_child(e)
	var a: float = randf() * TAU
	e.global_position = player.global_position + Vector2(cos(a), sin(a)) * enemy_spawn_distance
	e.set_target(player)
	# Late-run enemies get tougher (visible in their health arcs)
	e.max_health *= 1.0 + minutes * 0.15
	e.health = e.max_health
	e.died.connect(_on_enemy_died)
	if e.has_signal("ate_unit"):
		e.ate_unit.connect(_on_unit_eaten)


func _pick_enemy_scene(minutes: float) -> PackedScene:
	# Roster unlocks over the run: chasers → biters (flock ≥5) → interceptors
	# (1 min) → tanks (2 min). One roll, exclusive bands; a locked band falls
	# back to a chaser rather than inflating the other types' odds.
	var r: float = randf()
	if r < 0.12:
		return tank_scene if minutes >= 2.0 else enemy_scene
	if r < 0.34:
		return interceptor_scene if minutes >= 1.0 else enemy_scene
	if r < 0.34 + tail_biter_chance:
		return tail_biter_scene if collected_count >= 5 else enemy_scene
	return enemy_scene


func on_unit_collected(pos: Vector2) -> void:
	# Warm Welcome: every recruit detonates a concussive greeting
	if welcome_level <= 0:
		return
	var radius: float = 120.0 + 30.0 * float(welcome_level)
	var dmg: float = 30.0 * float(welcome_level)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: Vector2 = e.global_position - pos
		var dist: float = d.length()
		if dist < radius:
			e.take_external_damage(dmg)
			if is_instance_valid(e) and dist > 0.001:
				e.apply_grind((d / dist) * 420.0)
	add_trauma(0.12)
	var burst: Node2D = preload("res://scripts/hit_burst.gd").new()
	burst.color = Color(0.9, 2.2, 0.7)
	burst.scale_mult = 0.8
	add_child(burst)
	burst.global_position = pos


func _on_unit_eaten(pos: Vector2) -> void:
	units_lost += 1
	add_trauma(0.22)
	play_sfx("gulp")

	var burst: Node2D = preload("res://scripts/hit_burst.gd").new()
	burst.color = Color(2.0, 0.5, 2.4)   # violet gulp — losing feels different from killing
	burst.scale_mult = 0.5
	add_child(burst)
	burst.global_position = pos

	# The bitten unit is banished, not destroyed: a replacement stray appears
	# far away at the "map edge" — go win it back
	var f: Node2D = follower_scene.instantiate()
	add_child(f)
	var a: float = randf() * TAU
	f.global_position = player.global_position + Vector2(cos(a), sin(a)) * stray_respawn_distance
	f.max_speed *= unit_speed_mult
	f.strength *= unit_speed_mult


func _on_enemy_died(e) -> void:
	kills += 1

	# Combo chain: kills within the window multiply the spectacle AND the score
	_combo = _combo + 1 if _combo_timer > 0.0 else 1
	_combo_timer = combo_window
	score += 10 * e.stray_drop * _combo
	_update_kills_label()

	var pos: Vector2 = e.global_position

	# Impact feedback scales with the chain
	add_trauma(0.3 + 0.08 * float(_combo))
	_hit_stop()
	_death_shockwave(pos)
	play_sfx("kill")

	# Loot: heavier enemies pay out more strays
	for i in range(e.stray_drop + loot_bonus):
		_drop_stray(pos)

	# Level up on kill thresholds
	if kills >= _kills_to_next:
		_kills_to_next += 8 + 6 * upgrade_level
		upgrade_level += 1
		call_deferred("_show_upgrade_choice")


func _update_kills_label() -> void:
	if _combo >= 2:
		_kills_label.text = "Flock: %d   Kills: %d   Score: %d   x%d!" % [collected_count, kills, score, _combo]
		_kills_label.modulate = Color(2.0, 1.4, 0.8)   # blooms while the chain is alive
	else:
		_kills_label.text = "Flock: %d   Kills: %d   Score: %d" % [collected_count, kills, score]
		_kills_label.modulate = Color(1.0, 0.75, 0.6)


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = cfg.get_value("run", "best_score", 0)
		best_time_s = cfg.get_value("run", "best_time_s", 0)


func _write_save() -> void:
	# Load-modify-save: the same file holds [settings] — don't clobber it
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("run", "best_score", best_score)
	cfg.set_value("run", "best_time_s", best_time_s)
	cfg.save(SAVE_PATH)


func _trigger_game_over() -> void:
	_game_over = true
	_game_over_at_ms = Time.get_ticks_msec()
	Engine.time_scale = 1.0
	play_sfx("gameover")

	# Persist bests
	var secs_run: int = int(float(Time.get_ticks_msec() - _run_start_ms) / 1000.0)
	var new_best: bool = score > best_score
	if new_best:
		best_score = score
	best_time_s = maxi(best_time_s, secs_run)
	_write_save()

	get_tree().paused = true

	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.04, 0.74)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	UIS.add_vignette(layer, 0.55)

	var panel := UIS.centered_panel(UIS.VIOLET)
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	var title := Label.new()
	title.text = "THE FLOCK IS GONE"
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = UIS.VIOLET
	UIS.outline(title, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var secs: int = int((Time.get_ticks_msec() - _run_start_ms) / 1000.0)
	var score_lbl := Label.new()
	if score >= best_score:
		score_lbl.text = "Score %d   —   NEW BEST" % score
		score_lbl.modulate = UIS.GOLD
	else:
		score_lbl.text = "Score %d   ·   best %d" % [score, best_score]
		score_lbl.modulate = UIS.TEXT
	score_lbl.add_theme_font_size_override("font_size", 22)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(score_lbl)

	var stats := Label.new()
	stats.text = "survived %d:%02d   ·   kills %d   ·   peak flock %d   ·   lost %d" \
		% [secs / 60, secs % 60, kills, _peak_swarm, units_lost]
	stats.add_theme_font_size_override("font_size", 15)
	stats.modulate = UIS.TEXT_DIM
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	box.add_child(spacer)

	# Buttons: stick/dpad + A on Deck, click on desktop, R/M as shortcuts.
	# Briefly disabled so an A-press during the death moment can't skip the screen.
	var fly_btn := _overlay_button(box, "FLY AGAIN", request_restart)
	var menu_btn := _overlay_button(box, "MENU", go_to_menu)
	fly_btn.disabled = true
	menu_btn.disabled = true
	var arm := get_tree().create_timer(0.7, true, false, true)
	arm.timeout.connect(func() -> void:
		fly_btn.disabled = false
		menu_btn.disabled = false
		fly_btn.grab_focus())

	var hint := Label.new()
	hint.text = "R · M"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(UIS.TEXT_DIM.r, UIS.TEXT_DIM.g, UIS.TEXT_DIM.b, 0.6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _show_upgrade_choice() -> void:
	if _game_over or _upgrade_layer != null:
		return
	get_tree().paused = true
	play_sfx("collect", 0.7)

	# Offer 3 distinct upgrades from the pool
	var pool: Array = UPGRADE_POOL.duplicate()
	pool.shuffle()
	_upgrade_offer = pool.slice(0, 3)

	_upgrade_layer = CanvasLayer.new()
	_upgrade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_upgrade_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.04, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upgrade_layer.add_child(overlay)
	UIS.add_vignette(_upgrade_layer, 0.5)

	var title := Label.new()
	title.text = "THE MURMURATION GROWS"
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = UIS.MINT
	UIS.outline(title, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(800.0, 46.0)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	title.position += Vector2(0.0, -186.0)
	_upgrade_layer.add_child(title)

	var sub := Label.new()
	sub.text = "level %d — choose an instinct" % upgrade_level
	sub.add_theme_font_size_override("font_size", 15)
	sub.modulate = UIS.TEXT_DIM
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(800.0, 24.0)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	sub.position += Vector2(0.0, -142.0)
	_upgrade_layer.add_child(sub)

	var card_w := 252.0
	var card_h := 200.0
	var gap := 26.0
	var cards: Array[Button] = []
	for i in range(_upgrade_offer.size()):
		var up: Dictionary = _upgrade_offer[i]
		var accent: Color = up["color"]

		var btn := Button.new()
		UIS.style_button(btn, accent, 16)
		btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		btn.size = Vector2(card_w, card_h)
		btn.position += Vector2(-(card_w * 1.5 + gap) + float(i) * (card_w + gap), -card_h * 0.45)
		btn.pressed.connect(pick_upgrade.bind(i))
		_upgrade_layer.add_child(btn)
		cards.append(btn)

		# Card content (mouse-transparent so clicks land on the button)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 8)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		btn.add_child(box)

		var icon: Control = preload("res://scripts/upgrade_icon.gd").new()
		icon.icon_id = up["id"]
		icon.accent = accent
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = up["name"]
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.modulate = accent
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = up["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.modulate = UIS.TEXT_DIM
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(card_w - 40.0, 0.0)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(desc_lbl)

		var hint := Label.new()
		hint.text = "[ %d ]" % (i + 1)
		hint.add_theme_font_size_override("font_size", 12)
		hint.modulate = Color(UIS.TEXT_DIM.r, UIS.TEXT_DIM.g, UIS.TEXT_DIM.b, 0.7)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(hint)

		if i == 0:
			btn.grab_focus()   # controller: dpad/stick between cards, A to pick

		# Entry: staggered rise + fade (runs while the tree is paused)
		btn.modulate.a = 0.0
		var end_y: float = btn.position.y
		btn.position.y += 26.0
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(0.05 * float(i))
		tw.set_parallel(true)
		tw.tween_property(btn, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(btn, "position:y", end_y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Explicit focus wiring (with wraparound) so stick/dpad navigation between
	# cards is guaranteed on Deck — don't rely on positional inference
	var n_cards: int = cards.size()
	for i in range(n_cards):
		cards[i].focus_neighbor_left = cards[(i - 1 + n_cards) % n_cards].get_path()
		cards[i].focus_neighbor_right = cards[(i + 1) % n_cards].get_path()


func pick_upgrade(index: int) -> void:
	if _upgrade_layer == null or index >= _upgrade_offer.size():
		return
	var id: String = _upgrade_offer[index]["id"]
	match id:
		"damage":
			damage_mult *= 1.20
		"speed":
			unit_speed_mult *= 1.10
			for u in get_tree().get_nodes_in_group("swarm_unit") + get_tree().get_nodes_in_group("stray"):
				if is_instance_valid(u):
					u.max_speed *= 1.10
					u.strength *= 1.10
		"net":
			var shape: Node = player.get_node_or_null("CollisionShape2D")
			if shape:
				shape.scale *= 1.15
		"magnet":
			magnet_radius += 150.0
		"combo":
			combo_window += 0.5
		"loot":
			loot_bonus += 1
		"wake":
			wake_level += 1
			if _wake == null:
				_wake = preload("res://scripts/wake_renderer.gd").new()
				_wake.name = "WakeRenderer"
				add_child(_wake)
		"welcome":
			welcome_level += 1
		"comet":
			comet_level += 1

	_upgrade_layer.queue_free()
	_upgrade_layer = null
	_upgrade_offer = []
	get_tree().paused = false
	play_sfx("collect", 1.3)


func request_restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _overlay_button(parent: Container, label: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	UIS.style_button(btn, UIS.MINT, 18)
	btn.custom_minimum_size = Vector2(240.0, 44.0)
	btn.pressed.connect(handler)
	parent.add_child(btn)
	return btn


func toggle_pause() -> void:
	if _game_over or _upgrade_layer != null:
		return
	var pausing: bool = not get_tree().paused
	get_tree().paused = pausing
	if pausing:
		_pause_layer = CanvasLayer.new()
		_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_pause_layer)

		var overlay := ColorRect.new()
		overlay.color = Color(0.0, 0.0, 0.04, 0.62)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pause_layer.add_child(overlay)

		var panel := UIS.centered_panel(UIS.MINT)
		_pause_layer.add_child(panel)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(box)

		var lbl := Label.new()
		lbl.text = "PAUSED"
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.modulate = UIS.MINT
		UIS.outline(lbl, 6)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(lbl)

		# Real buttons — stick/dpad navigates, A activates (Deck friendly);
		# Esc/R/M remain as desktop shortcuts
		var resume := _overlay_button(box, "RESUME", toggle_pause)
		_overlay_button(box, "RESTART", request_restart)
		_overlay_button(box, "MENU", go_to_menu)
		resume.grab_focus()

		var hint := Label.new()
		hint.text = "Esc · R · M"
		hint.add_theme_font_size_override("font_size", 12)
		hint.modulate = Color(UIS.TEXT_DIM.r, UIS.TEXT_DIM.g, UIS.TEXT_DIM.b, 0.6)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hint)
	elif _pause_layer != null:
		_pause_layer.queue_free()
		_pause_layer = null


func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if _sfx != null:
		_sfx.play(sfx_name, pitch)


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _hit_stop(duration: float = 0.05, time_scale: float = 0.05) -> void:
	# Micro-freeze on kills — makes impacts land. Timer ignores time_scale
	# so the freeze doesn't stretch itself.
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = time_scale
	var t := get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(func(): Engine.time_scale = 1.0)


func _death_shockwave(pos: Vector2) -> void:
	# The kill physically blooms the murmuration outward — the flock's own
	# springs and friction pull it back together
	for u in get_tree().get_nodes_in_group("swarm_unit"):
		if not is_instance_valid(u):
			continue
		var d: Vector2 = u.global_position - pos
		var dist: float = d.length()
		if dist < SHOCKWAVE_RADIUS and dist > 0.001:
			u.vel += (d / dist) * SHOCKWAVE_POWER * (1.0 - dist / SHOCKWAVE_RADIUS)


func _drop_stray(pos: Vector2) -> void:
	# Kills feed the flock: each enemy leaves a stray to recruit
	if _total_units >= MAX_TOTAL_UNITS:
		return
	_total_units += 1
	var f: Node2D = follower_scene.instantiate()
	add_child(f)
	var a: float = randf() * TAU
	f.global_position = pos + Vector2(cos(a), sin(a)) * randf_range(10.0, 40.0)
	# Late-spawned units inherit the run's Swift Current stacks
	f.max_speed *= unit_speed_mult
	f.strength *= unit_speed_mult


func _update_swarm_follow(swarm_units: Array, delta: float) -> void:
	# Shared target trails behind the player's motion; each unit adds its own
	# persistent offset so the swarm flows as a teardrop instead of a bunched dot
	var base_target: Vector2 = player.global_position - _player_dir * trail_distance

	for u in swarm_units:
		var target_pos: Vector2 = base_target + u.follow_offset_norm * follow_spread
		var pos: Vector2 = u.global_position
		var to_target: Vector2 = target_pos - pos
		var dist: float = to_target.length()

		if dist > 0.01:
			var dir: Vector2 = to_target / dist
			u.vel += dir * u.strength * delta

		# Apply friction
		u.vel *= friction

		# Limit speed
		if u.vel.length() > u.max_speed:
			u.vel = u.vel.normalized() * u.max_speed

		# Move
		pos += u.vel * delta
		u.global_position = pos


func _assign_orbit_slots(swarm_units: Array) -> void:
	# Hand out ring slots in angular order around the player so each unit
	# steers to its nearest gap instead of crossing through the middle
	var center: Vector2 = player.global_position
	var sorted_units: Array = swarm_units.duplicate()
	sorted_units.sort_custom(func(a, b):
		return (a.global_position - center).angle() < (b.global_position - center).angle())
	for i in range(sorted_units.size()):
		sorted_units[i].orbit_slot = i
	_slot_count = sorted_units.size()


func _update_orbit(swarm_units: Array, delta: float) -> void:
	var n: int = swarm_units.size()
	if n == 0:
		return

	_orbit_time += delta * orbit_speed
	_breathe_time += delta * orbit_breathe_speed

	var center: Vector2 = player.global_position

	# Base ring radius grows slightly with swarm size, plus a gentle idle pulse
	var ring_radius: float = orbit_base_radius + orbit_radius_per_unit * float(n) \
		+ sin(_breathe_time) * orbit_breathe_amount

	for i in range(n):
		var u = swarm_units[i]
		var pos: Vector2 = u.global_position

		# Spread units evenly around the circle, at their angle-assigned slot
		var t: float = float(u.orbit_slot) / float(n)  # 0..1
		var angle: float = _orbit_time + TAU * t

		var target_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * ring_radius
		var to_target: Vector2 = target_pos - pos
		var dist: float = to_target.length()

		if dist > 1.0:
			var dir: Vector2 = to_target / dist
			# Smoothly steer velocity toward the orbit path
			var desired_speed: float = min(u.max_speed * 0.7, dist / delta)
			var desired_vel: Vector2 = dir * desired_speed

			# Blend current velocity toward desired velocity for smooth motion
			u.vel = u.vel.lerp(desired_vel, 0.15)
		else:
			# Close enough; gently slow down
			u.vel *= 0.8

		pos += u.vel * delta
		u.global_position = pos


# Forward-neighbor cells only (E, S, SE, SW) so every pair is tested exactly once
const _SEP_NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]


func resolve_collisions(particles: Array) -> void:
	var n: int = particles.size()
	if n < 2:
		return

	# Read node state into local arrays ONCE — repeated cross-object property
	# access is the dominant GDScript cost once pair counts grow
	var pos: PackedVector2Array = PackedVector2Array()
	pos.resize(n)
	var rad: PackedFloat32Array = PackedFloat32Array()
	rad.resize(n)
	var moved: Array = []
	moved.resize(n)
	var max_r: float = 1.0
	for i in range(n):
		var p = particles[i]
		pos[i] = p.global_position
		rad[i] = p.radius
		if p.radius > max_r:
			max_r = p.radius
		moved[i] = false

	# Spatial hash: two overlapping units are always within one cell of each
	# other (cell = max possible touch distance), so only same-cell and
	# forward-neighbor pairs need testing — O(n·k) instead of O(n²)
	var cell_size: float = max_r * 2.0
	var grid: Dictionary = {}
	for i in range(n):
		var key: Vector2i = Vector2i(floori(pos[i].x / cell_size), floori(pos[i].y / cell_size))
		if grid.has(key):
			grid[key].append(i)
		else:
			grid[key] = [i]

	for key in grid:
		var bucket: Array = grid[key]
		var bn: int = bucket.size()
		for a_i in range(bn):
			for b_i in range(a_i + 1, bn):
				_resolve_pair(bucket[a_i], bucket[b_i], pos, rad, moved)
		for off in _SEP_NEIGHBORS:
			var nkey: Vector2i = key + off
			if not grid.has(nkey):
				continue
			var nbucket: Array = grid[nkey]
			for a_i in range(bn):
				for b_i in range(nbucket.size()):
					_resolve_pair(bucket[a_i], nbucket[b_i], pos, rad, moved)

	# Write back only the nodes that actually moved
	for i in range(n):
		if moved[i]:
			particles[i].global_position = pos[i]


func _resolve_pair(i: int, j: int, pos: PackedVector2Array, rad: PackedFloat32Array, moved: Array) -> void:
	var dx: float = pos[j].x - pos[i].x
	var dy: float = pos[j].y - pos[i].y
	var dist_sq: float = dx * dx + dy * dy

	var min_dist: float = rad[i] + rad[j]

	if dist_sq == 0.0:
		# Prevent NaNs by giving a tiny random offset
		dx = randf_range(-0.01, 0.01)
		dy = randf_range(-0.01, 0.01)
		dist_sq = dx * dx + dy * dy

	if dist_sq < min_dist * min_dist:
		var dist: float = sqrt(dist_sq)
		var nx: float = dx / dist
		var ny: float = dy / dist
		var overlap: float = (min_dist - dist) * collision_push

		# Push each unit half the overlap apart
		pos[i] += Vector2(-nx * overlap * 0.5, -ny * overlap * 0.5)
		pos[j] += Vector2(nx * overlap * 0.5, ny * overlap * 0.5)
		moved[i] = true
		moved[j] = true
