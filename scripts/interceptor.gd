extends "res://scripts/enemy.gd"

# G4 — the line-cutter. Fast and fragile; instead of chasing where you ARE,
# it dives at where you're GOING (player position + velocity lead), so
# straight-line sprints get cut off and you're forced to carve. Carving is
# exactly what makes the whip swing — this enemy feeds the core mechanic.

@export var lead_time: float = 0.55


func _ready() -> void:
	theme_key = "interceptor"
	super()
	max_health = 40.0
	health = max_health
	body_radius = 11.0
	move_speed = 420.0


func _update_movement(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var predicted: Vector2 = _target.global_position
	if "velocity" in _target:
		predicted += _target.velocity * lead_time
	var dir: Vector2 = (predicted - global_position).normalized()
	global_position += dir * move_speed * delta
