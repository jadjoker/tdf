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
		# Tap/click restart, delayed so the death click doesn't skip the screen
		elif event is InputEventMouseButton and event.pressed \
				and Time.get_ticks_msec() - _phase._game_over_at_ms > 800:
			restart = true
		if restart:
			_phase.request_restart()
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_phase.toggle_pause()
		elif event.keycode == KEY_R and get_tree().paused:
			_phase.request_restart()
