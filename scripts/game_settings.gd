extends RefCounted

# Shared load/apply for user settings, stored in the same save.cfg as run bests.
# Static so any scene can `preload(...).apply_saved()` without an autoload.

const PATH := "user://save.cfg"


static func load_all() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # missing file is fine — defaults below
	return cfg


static func apply_saved() -> void:
	apply(load_all())


static func apply(cfg: ConfigFile) -> void:
	var vol: float = cfg.get_value("settings", "volume", 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(vol, 0.0001, 1.0)))

	if DisplayServer.get_name() == "headless":
		return
	var fs: bool = cfg.get_value("settings", "fullscreen", false)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
	var vs: bool = cfg.get_value("settings", "vsync", true)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vs else DisplayServer.VSYNC_DISABLED)


static func save_setting(key: String, value) -> void:
	# Load-modify-save so run bests in the same file are never clobbered
	var cfg := load_all()
	cfg.set_value("settings", key, value)
	cfg.save(PATH)
