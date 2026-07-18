extends Node

# Input shim that keeps working while the tree is paused (its own node runs
# PROCESS_MODE_ALWAYS so Phase1 and everything under it can stay pausable).
# Esc = pause/resume · R = restart (pause or game over) · tap = restart (game over)

var _phase: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_phase = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	# Overlays are button-driven (focus nav + A / click). This shim only adds
	# desktop hotkeys and the global controller pause toggle.
	if _phase._game_over:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_R:
				_phase.request_restart()
			elif event.keycode == KEY_M:
				_phase.go_to_menu()
		return

	# Upgrade cards: 1/2/3 keyboard shortcuts (focus nav + A handles Deck)
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
			_phase.go_to_menu()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			_phase.toggle_pause()
		elif event.button_index == JOY_BUTTON_B and get_tree().paused:
			# B backs out of pause (Deck convention)
			_phase.toggle_pause()
