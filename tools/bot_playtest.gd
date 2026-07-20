extends SceneTree

# Robot playtester: drives a full run headless with a simple competent policy
# (recruit → orbit-strafe enemies → sling on cooldown → pulse when swarmed),
# then prints one JSON metrics line and quits. Balance validation without
# a human in the loop.
#
# Usage: godot --headless --script tools/bot_playtest.gd [-- <time_scale>]
# Sim caps at 480s game-time ("survived cap" = late difficulty too soft).

const SIM_CAP_S := 480.0

var _phase: Node = null
var _player: Node = null
var _sling_timer: float = 0.0
var _sovereigns_seen: int = 0
var _done: bool = false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Engine.time_scale = float(args[0]) if args.size() >= 1 else 8.0
	Engine.max_physics_steps_per_frame = 16
	change_scene_to_file("res://main.tscn")


func _process(delta: float) -> bool:
	if _done or current_scene == null:
		return false
	if _phase == null or not is_instance_valid(_phase):
		_phase = current_scene.get_node_or_null("Phase1")
		if _phase == null:
			return false
		_player = _phase.get_node_or_null("Player")
		return false

	if _phase._game_over:
		_report("died")
		return false
	if _phase.run_time >= SIM_CAP_S:
		_report("survived_cap")
		return false

	# Upgrade screen: always take the first card
	if _phase._upgrade_layer != null:
		_phase.pick_upgrade(0)
		return false

	_drive(delta * Engine.time_scale)
	return false


func _drive(delta: float) -> void:
	var ppos: Vector2 = _player.global_position
	var target: Vector2 = ppos
	var flock: int = _phase.collected_count

	var nearest_enemy: Node2D = _nearest_in_group("enemies", ppos)
	if nearest_enemy != null and nearest_enemy.ember_bonus > 0:
		_sovereigns_seen = maxi(_sovereigns_seen, 1)

	if flock < 15:
		var stray: Node2D = _nearest_in_group("stray", ppos)
		if stray != null:
			target = stray.global_position
	elif nearest_enemy != null:
		# Orbit-strafe: aim past the enemy, not at it — the flock whips across
		var to_e: Vector2 = nearest_enemy.global_position - ppos
		target = nearest_enemy.global_position + to_e.orthogonal().normalized() * 220.0
		# Pulse when crowded
		if to_e.length() < 130.0:
			_phase._do_pulse()
		# Sling on a rhythm once the flock is big
		_sling_timer -= delta
		if flock >= 25 and _sling_timer <= 0.0:
			_sling_timer = 3.0
			_phase._sling_charge = 1.0
			_phase._release_sling(to_e.normalized())
	else:
		var stray2: Node2D = _nearest_in_group("stray", ppos)
		if stray2 != null:
			target = stray2.global_position

	# Convert desired direction into real input actions
	var dir: Vector2 = (target - ppos)
	_set_axis("move_left", "move_right", dir.x)
	_set_axis("move_up", "move_down", dir.y)


func _set_axis(neg: String, pos: String, v: float) -> void:
	if v < -20.0:
		Input.action_press(neg)
		Input.action_release(pos)
	elif v > 20.0:
		Input.action_press(pos)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _nearest_in_group(group: String, from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for n in get_nodes_in_group(group):
		if not is_instance_valid(n):
			continue
		var d: float = from.distance_squared_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _report(outcome: String) -> void:
	_done = true
	print(JSON.stringify({
		"outcome": outcome,
		"survived_s": snappedf(_phase.run_time, 0.1),
		"kills": _phase.kills,
		"score": _phase.score,
		"peak_flock": _phase._peak_swarm,
		"units_lost": _phase.units_lost,
		"run_embers": _phase.run_embers,
		"upgrade_level": _phase.upgrade_level,
	}))
	quit()
