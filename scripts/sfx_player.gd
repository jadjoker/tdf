extends Node

# Pooled SFX playback. All streams are procedurally generated originals
# (scratchpad gen_sfx.py) — no licensing baggage, ship-safe.
# Runs PROCESS_MODE_ALWAYS so the gameover sting plays while the tree pauses.

const POOL_SIZE := 8

const STREAMS := {
	"collect": preload("res://assets/sfx/collect.wav"),
	"kill": preload("res://assets/sfx/kill.wav"),
	"whip": preload("res://assets/sfx/whip.wav"),
	"gulp": preload("res://assets/sfx/gulp.wav"),
	"lunge": preload("res://assets/sfx/lunge.wav"),
	"gameover": preload("res://assets/sfx/gameover.wav"),
}

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_pool.append(p)


func play(sfx_name: String, pitch: float = 1.0) -> void:
	if not STREAMS.has(sfx_name):
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = STREAMS[sfx_name]
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()
