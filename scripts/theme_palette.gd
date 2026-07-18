extends RefCounted

# Murmuration's visual identities. Every procedurally-drawn color in the game
# reads from the active palette `P`, so switching themes reskins the world,
# flock, enemies, and UI accents in one call.
# Switch via: Settings dropdown, or T in-game (desktop). Persisted as settings/theme.

const SAVE_PATH := "user://save.cfg"

const THEMES := {
	"neon": {
		"bg": Color(0.02, 0.03, 0.06),
		"grid_line": Color(0.10, 0.14, 0.22), "grid_axis": Color(0.16, 0.22, 0.34),
		"stray_body": Color(0.16, 0.34, 0.26), "stray_rim": Color(0.38, 0.85, 0.58), "stray_hi": Color(0.45, 0.90, 0.65, 0.30),
		"swarm_body": Color(0.55, 2.40, 1.30), "swarm_rim": Color(0.90, 3.00, 1.80), "swarm_hi": Color(1.40, 2.80, 2.00, 0.30),
		"player_core": Color(1.55, 1.05, 1.85), "player_rim": Color(2.6, 1.8, 3.0),
		"player_hi": Color(2.2, 1.9, 2.4, 0.4), "player_halo": Color(1.2, 0.7, 1.5, 0.10),
		"glow_intensity": 1.0, "glow_strength": 1.05, "glow_bloom": 0.05,
		"ui_accent": Color(0.55, 2.4, 1.3),
		"chaser_body": Color(1.8, 0.5, 0.4), "chaser_rim": Color(2.6, 0.8, 0.5),
		"biter_body": Color(1.4, 0.35, 1.6), "biter_rim": Color(2.2, 0.6, 2.6),
		"interceptor_body": Color(1.7, 1.5, 0.35), "interceptor_rim": Color(2.4, 2.2, 0.6),
		"tank_body": Color(1.1, 0.60, 0.25), "tank_rim": Color(1.8, 1.0, 0.4),
	},
	"abyss": {
		"bg": Color(0.008, 0.015, 0.03),
		"grid_line": Color(0.04, 0.08, 0.13), "grid_axis": Color(0.07, 0.13, 0.19),
		"stray_body": Color(0.06, 0.18, 0.26), "stray_rim": Color(0.18, 0.50, 0.65), "stray_hi": Color(0.25, 0.60, 0.75, 0.30),
		"swarm_body": Color(0.30, 1.60, 2.20), "swarm_rim": Color(0.50, 2.40, 3.00), "swarm_hi": Color(0.90, 2.40, 2.80, 0.30),
		"player_core": Color(1.15, 0.95, 2.10), "player_rim": Color(1.8, 1.6, 3.0),
		"player_hi": Color(1.8, 1.7, 2.6, 0.4), "player_halo": Color(0.6, 0.7, 1.8, 0.12),
		"glow_intensity": 1.15, "glow_strength": 1.10, "glow_bloom": 0.08,
		"ui_accent": Color(0.5, 2.2, 2.6),
		"chaser_body": Color(1.8, 0.45, 0.5), "chaser_rim": Color(2.4, 0.7, 0.8),
		"biter_body": Color(1.5, 0.4, 1.8), "biter_rim": Color(2.2, 0.7, 2.6),
		"interceptor_body": Color(1.1, 1.9, 2.0), "interceptor_rim": Color(1.5, 2.6, 2.8),
		"tank_body": Color(1.0, 0.5, 0.3), "tank_rim": Color(1.6, 0.85, 0.5),
	},
	"synthwave": {
		"bg": Color(0.03, 0.01, 0.06),
		"grid_line": Color(0.16, 0.05, 0.22), "grid_axis": Color(0.30, 0.08, 0.38),
		"stray_body": Color(0.16, 0.10, 0.30), "stray_rim": Color(0.50, 0.30, 0.80), "stray_hi": Color(0.60, 0.40, 0.90, 0.30),
		"swarm_body": Color(0.40, 2.20, 2.60), "swarm_rim": Color(0.60, 3.00, 3.40), "swarm_hi": Color(1.20, 2.80, 3.00, 0.30),
		"player_core": Color(2.00, 0.60, 1.80), "player_rim": Color(3.0, 0.9, 2.6),
		"player_hi": Color(2.6, 1.4, 2.4, 0.4), "player_halo": Color(1.5, 0.4, 1.2, 0.12),
		"glow_intensity": 1.25, "glow_strength": 1.10, "glow_bloom": 0.15,
		"ui_accent": Color(2.2, 0.5, 1.8),
		"chaser_body": Color(2.4, 1.0, 0.3), "chaser_rim": Color(3.0, 1.5, 0.5),
		"biter_body": Color(2.2, 0.4, 1.6), "biter_rim": Color(3.0, 0.7, 2.2),
		"interceptor_body": Color(2.4, 2.0, 0.4), "interceptor_rim": Color(3.0, 2.6, 0.6),
		"tank_body": Color(1.8, 0.4, 0.4), "tank_rim": Color(2.6, 0.7, 0.7),
	},
	"pastel": {
		"bg": Color(0.13, 0.11, 0.16),
		"grid_line": Color(0.19, 0.165, 0.23), "grid_axis": Color(0.24, 0.21, 0.29),
		"stray_body": Color(0.42, 0.38, 0.48), "stray_rim": Color(0.68, 0.60, 0.74), "stray_hi": Color(0.75, 0.68, 0.80, 0.30),
		"swarm_body": Color(1.30, 1.05, 0.70), "swarm_rim": Color(1.60, 1.30, 0.90), "swarm_hi": Color(1.70, 1.50, 1.10, 0.30),
		"player_core": Color(1.40, 0.90, 0.95), "player_rim": Color(1.70, 1.20, 1.30),
		"player_hi": Color(1.70, 1.40, 1.45, 0.4), "player_halo": Color(1.0, 0.7, 0.75, 0.10),
		"glow_intensity": 0.55, "glow_strength": 1.02, "glow_bloom": 0.02,
		"ui_accent": Color(1.5, 1.2, 0.95),
		"chaser_body": Color(1.30, 0.60, 0.55), "chaser_rim": Color(1.55, 0.80, 0.75),
		"biter_body": Color(1.00, 0.70, 1.30), "biter_rim": Color(1.25, 0.90, 1.55),
		"interceptor_body": Color(0.90, 1.10, 0.70), "interceptor_rim": Color(1.10, 1.35, 0.90),
		"tank_body": Color(0.90, 0.70, 0.55), "tank_rim": Color(1.15, 0.92, 0.75),
	},
	"ink": {
		"bg": Color(0.0, 0.0, 0.0),
		"grid_line": Color(0.045, 0.045, 0.045), "grid_axis": Color(0.08, 0.08, 0.08),
		"stray_body": Color(0.16, 0.16, 0.155), "stray_rim": Color(0.50, 0.50, 0.48), "stray_hi": Color(0.60, 0.60, 0.58, 0.30),
		"swarm_body": Color(1.80, 1.75, 1.60), "swarm_rim": Color(2.60, 2.50, 2.30), "swarm_hi": Color(2.60, 2.55, 2.40, 0.30),
		"player_core": Color(2.20, 2.15, 2.00), "player_rim": Color(3.0, 2.95, 2.8),
		"player_hi": Color(2.8, 2.75, 2.6, 0.4), "player_halo": Color(1.4, 1.38, 1.3, 0.08),
		"glow_intensity": 0.9, "glow_strength": 1.05, "glow_bloom": 0.05,
		"ui_accent": Color(1.9, 1.9, 1.8),
		"chaser_body": Color(2.0, 0.35, 0.3), "chaser_rim": Color(2.8, 0.55, 0.5),
		"biter_body": Color(2.0, 0.35, 0.3), "biter_rim": Color(2.8, 0.55, 0.5),
		"interceptor_body": Color(2.0, 0.35, 0.3), "interceptor_rim": Color(2.8, 0.55, 0.5),
		"tank_body": Color(1.4, 0.30, 0.25), "tank_rim": Color(2.2, 0.45, 0.4),
	},
}

static var current_name: String = "neon"
static var P: Dictionary = THEMES["neon"]
static var _locked: bool = false   # screenshot tool pins a theme for capture


static func names() -> Array:
	return THEMES.keys()


static func apply_saved() -> void:
	if _locked:
		_apply_side_effects()
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	set_theme(cfg.get_value("settings", "theme", "neon"), false)


static func lock_theme(theme_name: String) -> void:
	set_theme(theme_name, false)
	_locked = true


static func set_theme(theme_name: String, persist: bool = true) -> void:
	if not THEMES.has(theme_name):
		theme_name = "neon"
	current_name = theme_name
	P = THEMES[theme_name]
	_apply_side_effects()
	if persist:
		var cfg := ConfigFile.new()
		cfg.load(SAVE_PATH)
		cfg.set_value("settings", "theme", theme_name)
		cfg.save(SAVE_PATH)


static func _apply_side_effects() -> void:
	RenderingServer.set_default_clear_color(P["bg"])
	# UI accent follows the theme (GOLD/VIOLET stay semantic)
	preload("res://scripts/ui_style.gd").MINT = P["ui_accent"]


static func apply_environment(env: Environment) -> void:
	env.glow_enabled = true
	env.glow_intensity = P["glow_intensity"]
	env.glow_strength = P["glow_strength"]
	env.glow_bloom = P["glow_bloom"]
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.1
