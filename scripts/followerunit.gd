extends Area2D

@export var follow_speed: float = 150.0
@export var follow_distance: float = 24.0

var is_collected: bool = false
var target: Node2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	# If already collected, ignore further collisions
	if is_collected:
		return

	# Only respond to the player
	if body.is_in_group("player"):
		is_collected = true
		target = body
		# Optional: visually show it's collected (e.g. scale or modulate)
		if has_node("Sprite2D"):
			$Sprite2D.modulate = Color(0.5, 1.0, 0.5)  # light green tint


func _process(delta: float) -> void:
	if not is_collected or target == null:
		return

	var desired_pos: Vector2 = target.global_position
	var distance: float = global_position.distance_to(desired_pos)

	if distance > follow_distance:
		var dir: Vector2 = global_position.direction_to(desired_pos)
		global_position += dir * follow_speed * delta
