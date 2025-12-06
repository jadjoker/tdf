extends Area2D

@export var strength: float = 1500.0      # how strongly this unit is pulled toward the player
@export var max_speed: float = 1800.0     # speed cap
@export var radius: float = 14.0          # used for soft collision spacing in Phase1

var vel: Vector2 = Vector2.ZERO

var is_collected: bool = false
var target: Node2D = null


func _ready() -> void:
	# Detect when the player overlaps this unit
	body_entered.connect(_on_body_entered)


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
