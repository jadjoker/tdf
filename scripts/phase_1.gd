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
var kills: int = 0
var _enemy_spawn_timer: float = 2.0
var _kills_label: Label

# Physics-juice pass: impact feedback systems
const COMBO_WINDOW := 1.6            # seconds between kills to keep the chain
const SHOCKWAVE_RADIUS := 160.0      # death blast physically ripples the flock
const SHOCKWAVE_POWER := 900.0
const MAX_TOTAL_UNITS := 250         # cap on strays dropped by kills

var _cam: Camera2D
var _trauma: float = 0.0             # camera shake energy, decays; shake = trauma²
var _combo: int = 0
var _combo_timer: float = 0.0
var _total_units: int = 0


func _ready() -> void:
	randomize()
	spawn_followers()
	_build_swarm_renderers()
	_build_perf_hud()
	_cam = player.get_node_or_null("Camera2D")
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

	var body_c: Color = _FollowerScript.COLOR_SWARM
	var rim_c: Color = _FollowerScript.RIM_SWARM
	var hi_c: Color = _FollowerScript.HIGHLIGHT_SWARM

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
	_perf_label = Label.new()
	_perf_label.position = Vector2(8.0, 6.0)
	_perf_label.add_theme_font_size_override("font_size", 13)
	_perf_label.modulate = Color(0.8, 0.9, 1.0, 0.8)
	layer.add_child(_perf_label)

	_kills_label = Label.new()
	_kills_label.text = "Kills: 0"
	_kills_label.position = Vector2(8.0, 26.0)
	_kills_label.add_theme_font_size_override("font_size", 16)
	_kills_label.modulate = Color(1.0, 0.75, 0.6)
	layer.add_child(_kills_label)


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
	for i in range(follower_count):
		var follower: Node2D = follower_scene.instantiate()
		add_child(follower)

		# Random position within a box centered on Phase1
		var offset := Vector2(
			randf_range(-spawn_area_size.x * 0.5, spawn_area_size.x * 0.5),
			randf_range(-spawn_area_size.y * 0.5, spawn_area_size.y * 0.5)
		)
		follower.global_position = global_position + offset


func _physics_process(delta: float) -> void:
	_update_perf_hud(delta)

	if player == null:
		return

	var swarm_units: Array = get_tree().get_nodes_in_group("swarm_unit")
	if swarm_units.is_empty():
		return

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

	# Track count for the perf HUD (print() here caused hitches during collect bursts)
	var new_count: int = swarm_units.size()
	if new_count != collected_count:
		collected_count = new_count


func _update_enemies(swarm_units: Array, delta: float) -> void:
	if not enemies_enabled:
		return

	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	if enemies.size() < max_enemies:
		_enemy_spawn_timer -= delta
		if _enemy_spawn_timer <= 0.0:
			_enemy_spawn_timer = enemy_spawn_interval
			_spawn_enemy()

	for e in enemies:
		e.process_flock_contact(swarm_units, delta)

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
				e_pos += nrm * overlap * ENEMY_PUSH_SHARE
				u.global_position -= nrm * overlap * (1.0 - ENEMY_PUSH_SHARE)
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


func _spawn_enemy() -> void:
	var e: Node2D = enemy_scene.instantiate()
	add_child(e)
	var a: float = randf() * TAU
	e.global_position = player.global_position + Vector2(cos(a), sin(a)) * enemy_spawn_distance
	e.set_target(player)
	e.died.connect(_on_enemy_died)


func _on_enemy_died(e) -> void:
	kills += 1

	# Combo chain: kills within the window multiply the spectacle
	_combo = _combo + 1 if _combo_timer > 0.0 else 1
	_combo_timer = COMBO_WINDOW
	_update_kills_label()

	var pos: Vector2 = e.global_position

	# Impact feedback scales with the chain
	add_trauma(0.3 + 0.08 * float(_combo))
	_hit_stop()
	_death_shockwave(pos)
	_drop_stray(pos)


func _update_kills_label() -> void:
	if _combo >= 2:
		_kills_label.text = "Kills: %d   x%d!" % [kills, _combo]
		_kills_label.modulate = Color(2.0, 1.4, 0.8)   # blooms while the chain is alive
	else:
		_kills_label.text = "Kills: %d" % kills
		_kills_label.modulate = Color(1.0, 0.75, 0.6)


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
