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

# Palette comes from the active theme via theme_key ("chaser"/"biter"/
# "interceptor"/"tank" — subclasses set theirs before super()._ready)
const TP = preload("res://scripts/theme_palette.gd")

var theme_key: String = "chaser"
var color_body := Color(1.8, 0.5, 0.4)
var color_core := Color(0.35, 0.06, 0.10)
var color_rim := Color(2.6, 0.8, 0.5)
var color_health := Color(2.0, 0.4, 0.3, 0.8)

# Physics personality — subclasses override in _ready (see heavy_tank.gd)
var push_share: float = 0.75    # fraction of unit-overlap the ENEMY absorbs (low = plows through)
var plow_kick: float = 0.0      # velocity imparted to units per px of overlap (bowling pins)
var knock_resist: float = 0.0   # 0..1 — resistance to grind/knockback impulses
var stray_drop: int = 1         # strays left behind on death (also score weight)
var ember_bonus: int = 0        # meta-currency bounty (Sovereigns)

signal died(enemy)
signal ate_unit(world_pos: Vector2)

# The symmetry rule (bot-playtest driven): fast units deal damage AND are
# safe; SLOW units deal nothing and get devoured. Speed is offense + defense.
const EAT_RATE := 0.45   # per-second chance to devour a slow touching unit

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


var _mods: Node = null   # Phase1 — read for run-upgrade multipliers


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_pulse = randf() * TAU
	_apply_theme()
	var p: Node = get_parent()
	if p != null and "damage_mult" in p:
		_mods = p


func _apply_theme() -> void:
	color_body = TP.P[theme_key + "_body"]
	color_rim = TP.P[theme_key + "_rim"]
	color_core = Color(color_body.r * 0.15, color_body.g * 0.15, color_body.b * 0.15, 1.0)
	color_health = Color(color_rim.r, color_rim.g, color_rim.b, 0.8)
	queue_redraw()


func set_target(t: Node2D) -> void:
	_target = t


# Overridable movement — the base chaser dumbly hunts the player
func _update_movement(delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		var dir: Vector2 = (_target.global_position - global_position).normalized()
		global_position += dir * move_speed * delta


func _physics_process(delta: float) -> void:
	_update_movement(delta)

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
	_knock = (_knock + impulse * (1.0 - knock_resist)).limit_length(600.0)


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
			# Too slow to hurt us — slow enough to be eaten
			if randf() < EAT_RATE * delta:
				var upos: Vector2 = u.global_position
				u.get_eaten()
				_flash = maxf(_flash, 0.5)
				ate_unit.emit(upos)
			continue
		var frac: float = clampf((speed - min_damage_speed) / (speed_for_max - min_damage_speed), 0.0, 1.0)
		var dmg_mult: float = _mods.damage_mult if _mods != null else 1.0
		health -= max_unit_dps * frac * delta * dmg_mult
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

		# A genuine whip-crack (near-max-speed hit) throws sparks and snaps
		if strongest_frac >= 0.7 and _spark_cooldown <= 0.0:
			_spark_cooldown = 0.15
			var spark: Node2D = preload("res://scripts/hit_burst.gd").new()
			spark.scale_mult = 0.45
			spark.color = Color(3.2, 2.6, 1.6)
			get_parent().add_child(spark)
			spark.global_position = (strongest_pos + global_position) * 0.5
			if get_parent().has_method("play_sfx"):
				get_parent().play_sfx("whip")

		if health <= 0.0:
			_die()


# Damage from non-flock sources (Burning Wake, Warm Welcome, Comet Core)
func take_external_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	_flash = maxf(_flash, 0.7)
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

	var body := color_body
	if _flash > 0.0:
		body = body.lerp(Color(4.0, 4.0, 4.0), _flash * 0.8)  # hit flash, blooms hard

	draw_circle(Vector2.ZERO, r, body, true, -1.0, true)
	draw_circle(Vector2.ZERO, r * 0.45, color_core, true, -1.0, true)
	draw_circle(Vector2.ZERO, r, color_rim, false, 2.0, true)

	if health < max_health:
		var frac: float = clampf(health / max_health, 0.0, 1.0)
		draw_arc(Vector2.ZERO, r + 6.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, color_health, 2.5)
