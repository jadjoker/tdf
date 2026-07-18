extends SceneTree

# Dev tool: boot a scene, wait for it to settle, save a viewport screenshot, quit.
# Usage:
#   godot --path . --script tools/screenshot_tool.gd -- <scene.tscn> <out.png> [screen] [theme]
# screen: "upgrade" | "gameover" | "pause" | "none" — forces that UI open first
# theme: pins a theme_palette theme for the capture (ignores the saved one)

var _frames: int = 0
var _out_path: String = "screenshot.png"
var _forced_screen: String = ""
var _done: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2:
		_out_path = args[1]
	if args.size() >= 3 and args[2] != "none":
		_forced_screen = args[2]
	if args.size() >= 4:
		preload("res://scripts/theme_palette.gd").lock_theme(args[3])
	if args.size() >= 1:
		change_scene_to_file(args[0])


func _process(_delta: float) -> bool:
	_frames += 1
	# Store/marketing captures never want the dev perf readout
	if _frames == 30 and current_scene != null:
		var ph: Node = current_scene.get_node_or_null("Phase1")
		if ph != null and ph._perf_label != null:
			ph._perf_label.visible = false

	if _frames == 45 and _forced_screen != "" and current_scene != null:
		var phase: Node = current_scene.get_node_or_null("Phase1")
		if phase != null:
			match _forced_screen:
				"upgrade": phase._show_upgrade_choice()
				"gameover": phase._trigger_game_over()
				"pause": phase.toggle_pause()
	if _frames >= 100 and not _done:
		_done = true
		var img: Image = root.get_texture().get_image()
		img.save_png(_out_path)
		print("screenshot saved: ", _out_path)
		quit()
	return false
