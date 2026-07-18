extends Area2D

@export var strength: float = 1500.0      # how strongly this unit is pulled toward the player
@export var max_speed: float = 1800.0     # speed cap
@export var radius: float = 14.0          # visual size AND soft collision spacing in Phase1
@export var variation: float = 0.10       # ±fraction randomly applied to strength/max_speed per unit

var vel: Vector2 = Vector2.ZERO

var is_collected: bool = false
var target: Node2D = null

# Feel pass #1 state, driven by Phase1:
var orbit_slot: int = 0                       # ring position, assigned by angle when orbit forms
var follow_offset_norm: Vector2 = Vector2.ZERO # persistent unit offset (unit disc), scaled by follow_spread

# Palette — values above 1.0 are HDR and bloom under the glow environment.
# Collected units are RENDERED BY PHASE1'S MULTIMESH (perf pass B), which bakes
# the swarm palette into a shared texture; only strays draw themselves (once).
# Strays are unlit embers of the swarm palette — clearly the same species,
# clearly waiting to be lit (screenshot review: gray-blue read as dull bubbles)
const COLOR_STRAY := Color(0.16, 0.34, 0.26, 1.0)
const COLOR_SWARM := Color(0.55, 2.40, 1.30, 1.0)
const RIM_STRAY := Color(0.38, 0.85, 0.58, 1.0)
const RIM_SWARM := Color(0.90, 3.00, 1.80, 1.0)
const HIGHLIGHT_STRAY := Color(0.45, 0.90, 0.65, 0.30)
const HIGHLIGHT_SWARM := Color(1.40, 2.80, 2.00, 0.30)

# Spring-driven squash & stretch (same system as the player ball)
const STRETCH_MAX := 0.8           # stretch target at full speed
const STRETCH_STIFFNESS := 170.0   # spring k (randomized per unit so wobbles desync)
const STRETCH_DAMPING := 11.0      # underdamped — jelly wobble
const AXIS_TURN_RATE := 16.0       # deformation axis chase speed

var _stretch: float = 1.0
var _stretch_vel: float = 0.0
var _axis_angle: float = 0.0
var _spring_k: float = STRETCH_STIFFNESS


func _ready() -> void:
	add_to_group("stray")   # uncollected units; Magnet Heart pulls this group

	# Detect when the player overlaps this unit
	body_entered.connect(_on_body_entered)

	# Per-unit organic variation so the swarm never moves (or wobbles) in lockstep
	strength *= randf_range(1.0 - variation, 1.0 + variation)
	max_speed *= randf_range(1.0 - variation, 1.0 + variation)
	_spring_k = STRETCH_STIFFNESS * randf_range(0.85, 1.15)

	# Uniform random point on the unit disc (sqrt for even density)
	var a: float = randf() * TAU
	follow_offset_norm = Vector2(cos(a), sin(a)) * sqrt(randf())


func _process(delta: float) -> void:
	if not is_collected:
		return

	# Deformation axis chases the motion direction instead of snapping
	if vel.length() > 1.0:
		_axis_angle = lerp_angle(_axis_angle, vel.angle(), 1.0 - exp(-AXIS_TURN_RATE * delta))

	# Damped spring toward the speed-based stretch target
	var speed_frac: float = clamp(vel.length() / max_speed, 0.0, 1.0)
	var spring_target: float = 1.0 + speed_frac * STRETCH_MAX
	var accel: float = (spring_target - _stretch) * _spring_k - _stretch_vel * STRETCH_DAMPING
	_stretch_vel += accel * delta
	_stretch = clamp(_stretch + _stretch_vel * delta, 0.5, 2.0)
	# No queue_redraw — Phase1's MultiMesh reads visual_transform() instead


func get_eaten() -> void:
	# Bitten by a tail-biter: leaves the swarm and this instance dies.
	# Phase1 respawns a replacement stray at the map edge (the unit is
	# banished, not destroyed — the flock can be won back).
	remove_from_group("swarm_unit")
	queue_free()


func visual_transform() -> Transform2D:
	# Position + spring deformation, consumed by Phase1's MultiMesh each frame
	return Transform2D(_axis_angle, Vector2(_stretch, 1.0 / sqrt(_stretch)), 0.0, global_position)


func _draw() -> void:
	# Strays only — they never move, so this draws exactly once.
	# Collected units return early (the MultiMesh renders them).
	if is_collected:
		return
	draw_circle(Vector2.ZERO, radius, COLOR_STRAY, true, -1.0, true)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.28), radius * 0.42, HIGHLIGHT_STRAY, true, -1.0, true)
	draw_circle(Vector2.ZERO, radius, RIM_STRAY, false, 1.5, true)


func _on_body_entered(body: Node) -> void:
	if is_collected:
		return

	# Only react to the player
	if body.is_in_group("player"):
		is_collected = true
		target = body

		# Clear the stray drawing — from here the MultiMesh renders this unit
		queue_redraw()

		# Pickup is done — retire this Area2D from the physics broadphase
		# so a full swarm doesn't drag 100 live monitored areas around
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)

		# Mark this unit as part of the swarm so Phase1 can move it
		# (the trail renderer and MultiMesh pick it up from this group)
		remove_from_group("stray")
		add_to_group("swarm_unit")
