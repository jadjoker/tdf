extends Node2D

# G1 prototype enemy: a dumb chaser that hunts the player.
# Exists to answer ONE question: is velocity-scaled contact damage
# (killing by driving well — lashes, whip-cracks, ring-grinding) fun?

@export var move_speed: float = 260.0     # slower than the player's 500 — you can always disengage
@export var max_health: float = 100.0
@export var body_radius: float = 16.0

# Velocity-scaled contact damage — the load-bearing mechanic:
#   unit speed <= min_damage_speed  -> no damage (parked swarm is harmless)
#   unit speed >= speed_for_max     -> max_unit_dps per touching unit
# Orbit ring (~400 px/s tangential) grinds slowly; a whip-crack (~1500) shreds.
@export var min_damage_speed: float = 200.0
@export var speed_for_max: float = 1500.0
@export var max_unit_dps: float = 400.0

@export var knockback_scale: float = 0.05  # fast hits shove the enemy along the unit's velocity

const COLOR_BODY := Color(1.8, 0.5, 0.4)   # HDR hostile ember
const COLOR_CORE := Color(0.35, 0.06, 0.10) # dark "eye"
const COLOR_RIM := Color(2.6, 0.8, 0.5)
const COLOR_HEALTH := Color(2.0, 0.4, 0.3, 0.8)

signal died(enemy)

var health: float = 0.0
var _target: Node2D = null
var _knock: Vector2 = Vector2.ZERO
var _flash: float = 0.0
var _pulse: float = 0.0

# Jelly impact deformation — same damped-spring family as the player/units,
# but kicked by hits instead of driven by own speed
var _deform: float = 1.0
var _deform_vel: float = 0.0
var _deform_axis: float = 0.0

var _spark_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_pulse = randf() * TAU


func set_target(t: Node2D) -> void:
	_target = t


func _physics_process(delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		var dir: Vector2 = (_target.global_position - global_position).normalized()
		global_position += dir * move_speed * delta

	# Knockback decays exponentially
	global_position += _knock * delta
	_knock = _knock.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))

	# Deformation spring relaxes back to round
	var accel: float = (1.0 - _deform) * 180.0 - _deform_vel * 10.0
	_deform_vel += accel * delta
	_deform = clampf(_deform + _deform_vel * delta, 0.55, 1.5)

	_flash = maxf(_flash - delta * 4.0, 0.0)
	_spark_cooldown = maxf(_spark_cooldown - delta, 0.0)
	_pulse += delta * 3.0
	queue_redraw()


# Physical shove from ring/flock contact — works regardless of damage threshold,
# so even a parked ring buffets and carries intruders along its rotation
func apply_grind(impulse: Vector2) -> void:
	_knock = (_knock + impulse).limit_length(600.0)


# Called by Phase1 each physics frame with the already-fetched swarm array
func process_flock_contact(swarm_units: Array, delta: float) -> void:
	var hit := false
	var strongest_frac: float = 0.0
	var strongest_vel: Vector2 = Vector2.ZERO
	var strongest_pos: Vector2 = Vector2.ZERO

	for u in swarm_units:
		if not is_instance_valid(u):
			continue
		if global_position.distance_to(u.global_position) > body_radius + u.radius:
			continue
		var speed: float = u.vel.length()
		if speed <= min_damage_speed:
			continue
		var frac: float = clampf((speed - min_damage_speed) / (speed_for_max - min_damage_speed), 0.0, 1.0)
		health -= max_unit_dps * frac * delta
		_knock += u.vel * frac * knockback_scale
		if frac > strongest_frac:
			strongest_frac = frac
			strongest_vel = u.vel
			strongest_pos = u.global_position
		hit = true

	if hit:
		_flash = 1.0
		_knock = _knock.limit_length(700.0)

		# Squash along the strongest impact — jelly reacts to being hit
		_deform_axis = strongest_vel.angle()
		_deform_vel -= 5.0 * strongest_frac

		# A genuine whip-crack (near-max-speed hit) throws sparks
		if strongest_frac >= 0.7 and _spark_cooldown <= 0.0:
			_spark_cooldown = 0.15
			var spark: Node2D = preload("res://scripts/hit_burst.gd").new()
			spark.scale_mult = 0.45
			spark.color = Color(3.2, 2.6, 1.6)
			get_parent().add_child(spark)
			spark.global_position = (strongest_pos + global_position) * 0.5

		if health <= 0.0:
			_die()


func _die() -> void:
	remove_from_group("enemies")
	died.emit(self)

	var burst: Node2D = preload("res://scripts/hit_burst.gd").new()
	get_parent().add_child(burst)
	burst.global_position = global_position

	queue_free()


func _draw() -> void:
	# Impact jelly deformation (proper local-space matrix — see player.gd gotcha)
	if absf(_deform - 1.0) > 0.003:
		draw_set_transform_matrix(Transform2D(_deform_axis, Vector2(_deform, 1.0 / sqrt(_deform)), 0.0, Vector2.ZERO))

	var r: float = body_radius + sin(_pulse) * 1.5

	var body := COLOR_BODY
	if _flash > 0.0:
		body = body.lerp(Color(4.0, 4.0, 4.0), _flash * 0.8)  # hit flash, blooms hard

	draw_circle(Vector2.ZERO, r, body, true, -1.0, true)
	draw_circle(Vector2.ZERO, r * 0.45, COLOR_CORE, true, -1.0, true)
	draw_circle(Vector2.ZERO, r, COLOR_RIM, false, 2.0, true)

	if health < max_health:
		var frac: float = clampf(health / max_health, 0.0, 1.0)
		draw_arc(Vector2.ZERO, r + 6.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, COLOR_HEALTH, 2.5)
