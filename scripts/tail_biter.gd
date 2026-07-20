extends "res://scripts/enemy.gd"

# G2 — the stakes-maker. Ignores the player and hunts the STRAGGLER at the
# back of the flock. Too slow to run anyone down (the flock outpaces it by
# design) — instead it stalks close, coils up, and LUNGES. The wind-up is
# the tell; the lunge direction locks when it fires, so a sharp turn dodges.
# Eating banishes the unit to the map edge (Phase1 respawns a stray).

@export var stalk_speed: float = 340.0
@export var lunge_speed: float = 950.0     # faster than anything alive — but straight
@export var lunge_range: float = 260.0     # coils when this close to prey
@export var windup_time: float = 0.35      # the dodge-reaction window
@export var lunge_time: float = 0.35
@export var digest_time: float = 1.2       # sluggish after a bite — revenge window
@export var retarget_interval: float = 0.6

enum State { STALK, WINDUP, LUNGE, DIGEST }

var _state: State = State.STALK
var _state_timer: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _prey: Node2D = null
var _retarget_timer: float = 0.0


func _ready() -> void:
	theme_key = "biter"
	super()
	max_health = 60.0
	health = max_health
	body_radius = 13.0


func _update_movement(delta: float) -> void:
	match _state:
		State.STALK:
			_update_stalk(delta)
		State.WINDUP:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.LUNGE
				_state_timer = lunge_time
				# Direction locks NOW — a sharp turn after the coil dodges the dash
				if _is_prey_valid():
					_lunge_dir = (_prey.global_position - global_position).normalized()
				elif _lunge_dir == Vector2.ZERO:
					_lunge_dir = Vector2.RIGHT.rotated(randf() * TAU)
		State.LUNGE:
			_state_timer -= delta
			global_position += _lunge_dir * lunge_speed * delta
			if _state_timer <= 0.0:
				_state = State.STALK
		State.DIGEST:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.STALK


func _update_stalk(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not _is_prey_valid():
		_acquire_prey()
		_retarget_timer = retarget_interval

	if _prey == null:
		# No flock to hunt — stalk the player like a base chaser
		super._update_movement(delta)
		return

	var to_prey: Vector2 = _prey.global_position - global_position
	var dist: float = to_prey.length()
	global_position += (to_prey / maxf(dist, 0.001)) * stalk_speed * delta

	if dist <= lunge_range:
		_state = State.WINDUP
		_state_timer = windup_time
		_flash = 0.6
		_deform_axis = to_prey.angle()
		_deform_vel += 3.0   # visible coil/swell — the tell
		if get_parent().has_method("play_sfx"):
			get_parent().play_sfx("lunge")


func _is_prey_valid() -> bool:
	return _prey != null and is_instance_valid(_prey) and _prey.is_in_group("swarm_unit")


func _acquire_prey() -> void:
	_prey = null
	if _target == null or not is_instance_valid(_target):
		return
	# The straggler = the collected unit farthest from the player
	var anchor: Vector2 = _target.global_position
	var best_d: float = -1.0
	for u in get_tree().get_nodes_in_group("swarm_unit"):
		if not is_instance_valid(u):
			continue
		var d: float = anchor.distance_squared_to(u.global_position)
		if d > best_d:
			best_d = d
			_prey = u


# While lunging, bite the first unit touched (not just the marked prey)
func process_flock_contact(swarm_units: Array, delta: float) -> void:
	super(swarm_units, delta)
	if health <= 0.0 or _state != State.LUNGE:
		return
	for u in swarm_units:
		if not is_instance_valid(u):
			continue
		if global_position.distance_to(u.global_position) <= body_radius + u.radius:
			_eat(u)
			return


func _eat(u: Node2D) -> void:
	var pos: Vector2 = u.global_position
	u.get_eaten()
	_prey = null
	_state = State.DIGEST
	_state_timer = digest_time

	# Gulp feedback: flash + a bulge kick on the jelly spring
	_flash = 1.0
	_deform_axis = randf() * TAU
	_deform_vel += 4.0

	ate_unit.emit(pos)


func _draw() -> void:
	# Threat line to the marked prey — drawn BEFORE super() sets the deform
	# transform. Brightens and pulses during the wind-up so the lunge reads.
	if _is_prey_valid() and (_state == State.STALK or _state == State.WINDUP):
		var alpha: float = 0.18
		if _state == State.WINDUP:
			alpha = 0.45 + sin(_pulse * 9.0) * 0.25
		var lc := Color(color_rim.r * 0.7, color_rim.g * 0.7, color_rim.b * 0.7, alpha)
		draw_line(Vector2.ZERO, to_local(_prey.global_position), lc, 1.5, true)
	super()
