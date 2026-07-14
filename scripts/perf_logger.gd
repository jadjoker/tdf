extends Node

# Buffered per-frame CSV performance logger.
# Writes to user://perf_logs/perf_<timestamp>.csv
# (user:// = %APPDATA%\Godot\app_userdata\TowerDefense on Windows)
#
# Buffering matters: writing lines to disk every frame would create the exact
# hitches we're hunting, so lines accumulate in memory and flush every ~5s.

const FLUSH_INTERVAL := 300   # frames between flushes (~5s at 60 Hz)

var _lines: PackedStringArray = []
var _file: FileAccess = null
var _t0: int = 0


func _ready() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("perf_logs"):
		dir.make_dir("perf_logs")
	var ts: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "user://perf_logs/perf_%s.csv" % ts
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("PerfLogger: could not open %s" % path)
		return
	_file.store_line("t_ms,units,fps,process_ms,physics_ms,sim_us,sep_us,slots_reassigned")
	_t0 = Time.get_ticks_msec()
	print("Perf log: ", ProjectSettings.globalize_path(path))


func record(units: int, sim_us: int, sep_us: int, slots_reassigned: bool) -> void:
	if _file == null:
		return
	_lines.append("%d,%d,%.0f,%.2f,%.2f,%d,%d,%d" % [
		Time.get_ticks_msec() - _t0,
		units,
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		sim_us,
		sep_us,
		1 if slots_reassigned else 0,
	])
	if _lines.size() >= FLUSH_INTERVAL:
		_flush()


func _flush() -> void:
	if _file == null:
		return
	for l in _lines:
		_file.store_line(l)
	_lines.clear()
	_file.flush()


func _exit_tree() -> void:
	_flush()
