extends Node

# Input shim that keeps working while the tree is paused (its own node runs
# PROCESS_MODE_ALWAYS so Phase1 and everything under it can stay pausable).
# Esc = pause/resume · R = restart (pause or game over) · tap = restart (game over)

var _phase: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_phase = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if _phase._game_over:
		var restart := false
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			restart = true
		elif event is InputEventKey and event.pressed and event.keycode == KEY_M:
			_go_to_menu()
			return
		# Tap/click/gamepad-A restart, delayed so the death input doesn't skip the screen
		elif (event is InputEventMouseButton or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A)) \
				and event.pressed and Time.get_ticks_msec() - _phase._game_over_at_ms > 800:
			restart = true
		if restart:
			_phase.request_restart()
		return

	# Upgrade cards: 1/2/3 pick; clicks and controller focus-navigation (dpad/stick
	# + A) also work because the layer is ALWAYS-mode and the first card grabs focus
	if _phase._upgrade_layer != null:
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_1: _phase.pick_upgrade(0)
				KEY_2: _phase.pick_upgrade(1)
				KEY_3: _phase.pick_upgrade(2)
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_phase.toggle_pause()
		elif event.keycode == KEY_R and get_tree().paused:
			_phase.request_restart()
		elif event.keycode == KEY_M and get_tree().paused:
			_go_to_menu()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		_phase.toggle_pause()


func _go_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
