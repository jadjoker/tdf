extends Node2D

# MURMURATION title screen. Everything procedural: neon glow environment,
# world grid, an ambient decorative flock, and code-built UI.
# Settings persist to user://save.cfg [settings] via game_settings.gd.

const GS = preload("res://scripts/game_settings.gd")
const _FollowerScript = preload("res://scripts/followerunit.gd")

const AMBIENT_COUNT := 56

var _t: float = 0.0
var _menu_box: VBoxContainer
var _settings_box: VBoxContainer
var _begin_btn: Button


func _ready() -> void:
	GS.apply_saved()

	var cam := Camera2D.new()
	add_child(cam)

	var env := Environment.new()
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.05
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var grid := preload("res://scripts/grid_background.gd").new()
	add_child(grid)

	_build_ui()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Ambient murmuration: deterministic per-index orbits with sine wobble
	var c: Color = _FollowerScript.COLOR_SWARM
	for i in range(AMBIENT_COUNT):
		var fi := float(i)
		var radius: float = 170.0 + fmod(fi * 47.0, 190.0)
		var speed: float = 0.10 + fmod(fi, 7.0) * 0.028
		var angle: float = _t * speed + fi * 2.39996   # golden-angle spread
		var pos := Vector2(cos(angle), sin(angle)) * radius
		pos += Vector2(sin(_t * 1.3 + fi) * 16.0, cos(_t * 1.7 + fi * 0.7) * 12.0)
		var a: float = 0.35 + 0.3 * sin(_t * 0.9 + fi)
		draw_circle(pos, 5.0, Color(c.r, c.g, c.b, a), true, -1.0, true)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "MURMURATION"
	title.add_theme_font_size_override("font_size", 64)
	title.modulate = Color(0.6, 2.6, 1.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.size = Vector2(900.0, 80.0)
	title.position += Vector2(-450.0, -220.0)
	layer.add_child(title)

	var tag := Label.new()
	tag.text = "lead the flock  ·  crack the whip"
	tag.add_theme_font_size_override("font_size", 17)
	tag.modulate = Color(0.7, 0.8, 0.9, 0.85)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tag.size = Vector2(900.0, 26.0)
	tag.position += Vector2(-450.0, -150.0)
	layer.add_child(tag)

	# Best-run line from save
	var cfg := GS.load_all()
	var bs: int = cfg.get_value("run", "best_score", 0)
	var bt: int = cfg.get_value("run", "best_time_s", 0)
	if bs > 0 or bt > 0:
		var best := Label.new()
		best.text = "best score %d   ·   longest flight %d:%02d" % [bs, bt / 60, bt % 60]
		best.add_theme_font_size_override("font_size", 14)
		best.modulate = Color(2.0, 1.6, 0.8, 0.9)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		best.size = Vector2(900.0, 22.0)
		best.position += Vector2(-450.0, -118.0)
		layer.add_child(best)

	# Main buttons
	_menu_box = VBoxContainer.new()
	_menu_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu_box.size = Vector2(280.0, 200.0)
	_menu_box.position += Vector2(-140.0, -40.0)
	_menu_box.add_theme_constant_override("separation", 14)
	layer.add_child(_menu_box)

	_begin_btn = _menu_button("BEGIN", _on_begin)
	_menu_button("SETTINGS", _on_settings)
	_menu_button("QUIT", _on_quit)
	_begin_btn.grab_focus()   # controller/keyboard navigation works out of the box

	# Settings panel (hidden until opened)
	_settings_box = VBoxContainer.new()
	_settings_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_settings_box.size = Vector2(340.0, 240.0)
	_settings_box.position += Vector2(-170.0, -60.0)
	_settings_box.add_theme_constant_override("separation", 12)
	_settings_box.visible = false
	layer.add_child(_settings_box)

	var vol_label := Label.new()
	vol_label.text = "Volume"
	_settings_box.add_child(vol_label)

	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = cfg.get_value("settings", "volume", 1.0)
	vol.custom_minimum_size = Vector2(320.0, 24.0)
	vol.value_changed.connect(_on_volume)
	_settings_box.add_child(vol)

	var fs := CheckBox.new()
	fs.text = "Fullscreen"
	fs.button_pressed = cfg.get_value("settings", "fullscreen", false)
	fs.toggled.connect(_on_fullscreen)
	_settings_box.add_child(fs)

	var vs := CheckBox.new()
	vs.text = "VSync"
	vs.button_pressed = cfg.get_value("settings", "vsync", true)
	vs.toggled.connect(_on_vsync)
	_settings_box.add_child(vs)

	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(_on_settings_back)
	_settings_box.add_child(back)


func _menu_button(label: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(280.0, 46.0)
	btn.pressed.connect(handler)
	_menu_box.add_child(btn)
	return btn


func _on_begin() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_settings() -> void:
	_menu_box.visible = false
	_settings_box.visible = true


func _on_settings_back() -> void:
	_settings_box.visible = false
	_menu_box.visible = true
	_begin_btn.grab_focus()


func _on_quit() -> void:
	get_tree().quit()


func _on_volume(v: float) -> void:
	GS.save_setting("volume", v)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(v, 0.0001, 1.0)))


func _on_fullscreen(on: bool) -> void:
	GS.save_setting("fullscreen", on)
	GS.apply_saved()


func _on_vsync(on: bool) -> void:
	GS.save_setting("vsync", on)
	GS.apply_saved()
