extends Area2D

@export var strength: float = 1500.0      # how strongly this unit is pulled toward the player
@export var max_speed: float = 1800.0     # speed cap
@export var radius: float = 14.0          # used for soft collision spacing in Phase1
@export var variation: float = 0.10       # ±fraction randomly applied to strength/max_speed per unit

var vel: Vector2 = Vector2.ZERO

var is_collected: bool = false
var target: Node2D = null

# Feel pass #1 state, driven by Phase1:
var orbit_slot: int = 0                       # ring position, assigned by angle when orbit forms
var follow_offset_norm: Vector2 = Vector2.ZERO # persistent unit offset (unit disc), scaled by follow_spread


func _ready() -> void:
	# Detect when the player overlaps this unit
	body_entered.connect(_on_body_entered)

	# Per-unit organic variation so the swarm never moves in lockstep
	strength *= randf_range(1.0 - variation, 1.0 + variation)
	max_speed *= randf_range(1.0 - variation, 1.0 + variation)

	# Uniform random point on the unit disc (sqrt for even density)
	var a: float = randf() * TAU
	follow_offset_norm = Vector2(cos(a), sin(a)) * sqrt(randf())


func _on_body_entered(body: Node) -> void:
	if is_collected:
		return

	# Only react to the player
	if body.is_in_group("player"):
		is_collected = true
		target = body

		# Visual feedback
		if has_node("Sprite2D"):
			$Sprite2D.modulate = Color(0.5, 1.0, 0.5)

		# Mark this unit as part of the swarm so Phase1 can move it
		add_to_group("swarm_unit")
		print("Follower collected:", name)
