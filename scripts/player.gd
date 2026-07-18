extends CharacterBody2D

@export var move_speed: float = 200.0

# Drawn visual (no sprite) — crisp anti-aliased edges at any zoom,
# HDR colors bloom under the glow environment
const CORE_RADIUS := 24.0
# Screenshot review: 2.2+ core clipped to a featureless white disk — keep the
# body just under full bloom so the magenta identity survives, rim carries the glow
const CORE_COLOR := Color(1.55, 1.05, 1.85)       # magenta body, tinted not clipped
const RIM_COLOR := Color(2.6, 1.8, 3.0)           # bright rim, blooms hard
const HIGHLIGHT_COLOR := Color(2.2, 1.9, 2.4, 0.4)
const HALO_COLOR := Color(1.2, 0.7, 1.5, 0.10)    # soft light spill

# Squash & stretch driven by a damped spring, not mapped directly from speed:
# accelerating overshoots the stretch, hard stops squash past neutral and
# jiggle back — jelly, not a lookup table.
const STRETCH_MAX := 0.25          # stretch target at full speed
const STRETCH_STIFFNESS := 140.0   # spring k — higher = faster response
const STRETCH_DAMPING := 12.0      # underdamped on purpose (a couple of wobbles)
const AXIS_TURN_RATE := 14.0       # how fast the deformation axis swings toward new directions

var _pulse_time: float = 0.0
var _stretch: float = 1.0          # current stretch factor (springs toward target)
var _stretch_vel: float = 0.0
var _axis_angle: float = 0.0       # deformation axis; follows motion smoothly, held on stop


func _process(delta: float) -> void:
	_pulse_time += delta

	# Deformation axis chases the movement direction instead of snapping,
	# so turns swing the squash around organically
	if velocity.length() > 1.0:
		_axis_angle = lerp_angle(_axis_angle, velocity.angle(), 1.0 - exp(-AXIS_TURN_RATE * delta))

	# Damped spring: pull current stretch toward the speed-based target
	var speed_frac: float = clamp(velocity.length() / max(move_speed, 1.0), 0.0, 1.0)
	var target: float = 1.0 + speed_frac * STRETCH_MAX
	var accel: float = (target - _stretch) * STRETCH_STIFFNESS - _stretch_vel * STRETCH_DAMPING
	_stretch_vel += accel * delta
	_stretch = clamp(_stretch + _stretch_vel * delta, 0.6, 1.6)

	queue_redraw()


func _draw() -> void:
	var pulse: float = sin(_pulse_time * 2.2) * 1.5

	# Volume-ish preservation: elongate along motion, thin (or bulge) sideways.
	# NOTE: draw_set_transform() applies scale in SCREEN space (after rotation),
	# which pins the deformation to the screen X axis — must build the matrix
	# ourselves so the stretch axis actually rotates with movement.
	if absf(_stretch - 1.0) > 0.001:
		var deform := Transform2D(_axis_angle, Vector2(_stretch, 1.0 / sqrt(_stretch)), 0.0, Vector2.ZERO)
		draw_set_transform_matrix(deform)

	# Soft layered halo (fades outward; bloom amplifies it)
	for i in range(3):
		var r: float = CORE_RADIUS + 10.0 + float(i) * 8.0 + pulse
		var a: float = HALO_COLOR.a * (1.0 - float(i) / 3.0)
		draw_circle(Vector2.ZERO, r, Color(HALO_COLOR.r, HALO_COLOR.g, HALO_COLOR.b, a), true, -1.0, true)

	# Body
	var body_r: float = CORE_RADIUS + pulse * 0.4
	draw_circle(Vector2.ZERO, body_r, CORE_COLOR, true, -1.0, true)

	# Off-center highlight gives it a hint of depth without a texture
	draw_circle(Vector2(-CORE_RADIUS * 0.25, -CORE_RADIUS * 0.28), CORE_RADIUS * 0.45, HIGHLIGHT_COLOR, true, -1.0, true)

	# Crisp bright rim
	draw_circle(Vector2.ZERO, body_r, RIM_COLOR, false, 2.5, true)


func _physics_process(_delta: float) -> void:
	var input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# Pointer steering: hold left mouse (or touch — emulated as mouse) to drive
	# toward the cursor. Speed eases in near the pointer for fine control.
	# Keyboard input always wins if both are active.
	if input_dir == Vector2.ZERO and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var to_pointer: Vector2 = get_global_mouse_position() - global_position
		var dist: float = to_pointer.length()
		if dist > 12.0:
			input_dir = (to_pointer / dist) * clampf((dist - 12.0) / 80.0, 0.0, 1.0)

	velocity = input_dir * move_speed
	move_and_slide()
