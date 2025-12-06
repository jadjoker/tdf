extends CharacterBody2D

@export var move_speed: float = 200.0

func _physics_process(_delta: float) -> void:
	var input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	velocity = input_dir * move_speed
	move_and_slide()
