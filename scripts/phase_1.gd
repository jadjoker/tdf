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


func _ready() -> void:
	randomize()
	spawn_followers()


func spawn_followers() -> void:
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

	if is_idle:
		# (Re)assign ring slots by current angle when orbit starts or the swarm changes size,
		# so every unit slides into its nearest gap instead of cutting across the ring
		if not _was_idle or swarm_units.size() != _slot_count:
			_assign_orbit_slots(swarm_units)
		_update_orbit(swarm_units, delta)
	else:
		_update_swarm_follow(swarm_units, delta)
	_was_idle = is_idle

	# Soft collision resolution (keeps blob from overlapping too much)
	resolve_collisions(swarm_units)

	# Update count (for debugging / future UI)
	var new_count: int = swarm_units.size()
	if new_count != collected_count:
		collected_count = new_count
		print("Collected units:", collected_count)


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


func resolve_collisions(particles: Array) -> void:
	var n: int = particles.size()
	for i in range(n):
		for j in range(i + 1, n):
			var a = particles[i]
			var b = particles[j]

			var pa: Vector2 = a.global_position
			var pb: Vector2 = b.global_position

			var dx: float = pb.x - pa.x
			var dy: float = pb.y - pa.y
			var dist_sq: float = dx * dx + dy * dy

			var min_dist: float = a.radius + b.radius

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
				pa.x -= nx * (overlap * 0.5)
				pa.y -= ny * (overlap * 0.5)
				pb.x += nx * (overlap * 0.5)
				pb.y += ny * (overlap * 0.5)

				a.global_position = pa
				b.global_position = pb
