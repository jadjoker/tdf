extends Node2D

# MURMURATION title screen. Everything procedural: neon glow environment,
# world grid, an ambient decorative flock, and code-built UI.
# Settings persist to user://save.cfg [settings] via game_settings.gd.

const GS = preload("res://scripts/game_settings.gd")
const UIS = preload("res://scripts/ui_style.gd")
const TP = preload("res://scripts/theme_palette.gd")

const AMBIENT_COUNT := 56

var _t: float = 0.0
var _menu_box: VBoxContainer
var _settings_panel: PanelContainer
var _begin_btn: Button
var _vol_slider: HSlider
var _title: Label


func _unhandled_input(event: InputEvent) -> void:
	# B / Esc backs out of settings (Deck convention)
	if event.is_action_pressed("ui_cancel") and _settings_panel != null and _settings_panel.visible:
		_on_settings_back()


func _ready() -> void:
	GS.apply_saved()
	TP.apply_saved()

	var cam := Camera2D.new()
	add_child(cam)

	var env := Environment.new()
	TP.apply_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var grid := preload("res://scripts/grid_background.gd").new()
	add_child(grid)

	_build_ui()


func _process(delta: float) -> void:
	_t += delta
	# Title breathes gently in the bloom, in the theme's accent
	if _title != null:
		var pulse: float = 1.0 + sin(_t * 1.3) * 0.10
		var ac: Color = TP.P["ui_accent"]
		_title.modulate = Color(ac.r * pulse * 1.1, ac.g * pulse * 1.1, ac.b * pulse * 1.1)
	queue_redraw()


func _draw() -> void:
	# Ambient murmuration: deterministic per-index orbits with sine wobble
	var c: Color = TP.P["swarm_body"]
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
	UIS.add_vignette(layer, 0.4)

	_title = Label.new()
	_title.text = "MURMURATION"
	_title.add_theme_font_size_override("font_size", 64)
	_title.modulate = Color(0.6, 2.6, 1.5)
	UIS.outline(_title, 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# NOTE: size BEFORE the center preset, or the anchor math centers the
	# label's pre-size min-width and everything lands ~100px off-center
	_title.size = Vector2(900.0, 80.0)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	_title.position += Vector2(0.0, -220.0)
	layer.add_child(_title)

	var tag := Label.new()
	tag.text = "lead the flock  ·  crack the whip"
	tag.add_theme_font_size_override("font_size", 17)
	tag.modulate = Color(0.7, 0.8, 0.9, 0.85)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(900.0, 26.0)
	tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	tag.position += Vector2(0.0, -128.0)
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
		best.size = Vector2(900.0, 22.0)
		best.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
		best.position += Vector2(0.0, -98.0)
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
	_settings_panel = UIS.centered_panel(UIS.MINT)
	_settings_panel.visible = false
	layer.add_child(_settings_panel)

	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 14)
	settings_box.custom_minimum_size = Vector2(340.0, 0.0)
	_settings_panel.add_child(settings_box)

	var st_title := Label.new()
	st_title.text = "SETTINGS"
	st_title.add_theme_font_size_override("font_size", 24)
	st_title.modulate = UIS.MINT
	st_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_box.add_child(st_title)

	var vol_label := Label.new()
	vol_label.text = "Volume"
	vol_label.modulate = UIS.TEXT
	settings_box.add_child(vol_label)

	_vol_slider = HSlider.new()
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 1.0
	_vol_slider.step = 0.05
	_vol_slider.value = cfg.get_value("settings", "volume", 1.0)
	_vol_slider.custom_minimum_size = Vector2(320.0, 24.0)
	UIS.style_slider(_vol_slider, UIS.MINT)
	_vol_slider.value_changed.connect(_on_volume)
	settings_box.add_child(_vol_slider)

	var fs := CheckBox.new()
	fs.text = "Fullscreen"
	fs.button_pressed = cfg.get_value("settings", "fullscreen", false)
	fs.add_theme_color_override("font_color", UIS.TEXT)
	fs.toggled.connect(_on_fullscreen)
	settings_box.add_child(fs)

	var vs := CheckBox.new()
	vs.text = "VSync"
	vs.button_pressed = cfg.get_value("settings", "vsync", true)
	vs.add_theme_color_override("font_color", UIS.TEXT)
	vs.toggled.connect(_on_vsync)
	settings_box.add_child(vs)

	var theme_label := Label.new()
	theme_label.text = "Theme"
	theme_label.modulate = UIS.TEXT
	settings_box.add_child(theme_label)

	var theme_opt := OptionButton.new()
	var theme_names: Array = TP.names()
	for n in theme_names:
		theme_opt.add_item(String(n).capitalize())
	theme_opt.select(theme_names.find(TP.current_name))
	theme_opt.item_selected.connect(func(idx: int) -> void:
		TP.set_theme(theme_names[idx])
		get_tree().reload_current_scene())   # restyle everything in the new identity
	settings_box.add_child(theme_opt)

	var back := Button.new()
	back.text = "BACK"
	UIS.style_button(back, UIS.MINT, 18)
	back.pressed.connect(_on_settings_back)
	settings_box.add_child(back)


func _menu_button(label: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	UIS.style_button(btn, UIS.MINT, 22)
	btn.custom_minimum_size = Vector2(280.0, 50.0)
	btn.pressed.connect(handler)
	_menu_box.add_child(btn)
	return btn


func _on_begin() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_settings() -> void:
	_menu_box.visible = false
	_settings_panel.visible = true
	if _vol_slider != null:
		_vol_slider.grab_focus()   # stick/dpad lands inside the panel immediately


func _on_settings_back() -> void:
	_settings_panel.visible = false
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
